/// Repositori kebiasaan (FR-80) — daftar kebiasaan, promosi ke Hari Ini, dan
/// catatan harian.
///
/// Aturan yang dijaga di sini (bukan di layar) supaya semua pemanggil sama:
///
/// * **Promosi paling banyak 5 baris** (`maksDipromosikan`). Batas ini dijaga
///   saat menyalakan promosi ([setDipromosikan]) — bila kuota penuh, metode
///   mengembalikan `false` dan **tidak menyentuh data apa pun**. Baris lama
///   tidak pernah dihapus atau dimatikan diam-diam.
/// * **Satu baris log per kebiasaan per hari**. Tanggal selalu dinormalkan ke
///   hari-saja, dan nilai dijepit ke rentang 0,0–1,0, sehingga kebiasaan
///   bertahap (mis. "minum 8 gelas") bisa dicatat setengah jalan.
/// * **Ringkasan bersifat netral**: yang dilaporkan hanya "hari tercatat" dan
///   "hari penuh", tanpa rentetan yang menghakimi. Tidak ada penilaian baik
///   atau buruk atas capaian pengguna.
///
/// Nada bahasa mengikuti PRD III-11.
library;

import 'package:drift/drift.dart';

import '../../core/utils/waktu.dart';
import '../database/database.dart';

/// Ringkasan capaian satu kebiasaan pada satu rentang hari.
///
/// Semua angka netral dan hanya melaporkan apa yang sudah tercatat.
class RingkasanKebiasaan {
  const RingkasanKebiasaan({
    required this.jumlahHari,
    required this.hariTercatat,
    required this.hariPenuh,
    required this.totalNilai,
  });

  /// Panjang rentang yang dihitung (mis. 7 atau 30).
  final int jumlahHari;

  /// Jumlah hari pada rentang itu yang nilainya lebih dari 0.
  final int hariTercatat;

  /// Jumlah hari pada rentang itu yang nilainya mencapai 1,0 (penuh).
  final int hariPenuh;

  /// Jumlah seluruh nilai pada rentang itu (bilangan pecahan).
  final double totalNilai;

  /// Ringkasan kosong untuk [jumlahHari] — dipakai saat belum ada catatan.
  static RingkasanKebiasaan kosong(int jumlahHari) => RingkasanKebiasaan(
        jumlahHari: jumlahHari,
        hariTercatat: 0,
        hariPenuh: 0,
        totalNilai: 0,
      );
}

class KebiasaanRepository {
  KebiasaanRepository(this.db);

  final AppDatabase db;

  /// Promosi paling banyak yang boleh tampil di Hari Ini.
  static const int maksDipromosikan = 5;

  /// Kalimat yang dipakai saat kuota promosi sudah penuh.
  static const String pesanPenuh =
      'Hari Ini paling banyak memuat 5 kebiasaan. Matikan promosi satu kebiasaan dulu supaya yang baru bisa tampil.';

  /// Pengenal stabil baru (`kbs_<microseconds>`), dipakai bila pemanggil tidak
  /// memberi `idKebiasaan` sendiri.
  static String idBaru() => 'kbs_${DateTime.now().microsecondsSinceEpoch}';

  /// Simpan baris kebiasaan: baris baru bila [id] kosong, ubah baris bila [id]
  /// diisi.
  ///
  /// `ArgumentError` dilempar bila nama kosong atau target di luar 1–7.
  ///
  /// Catatan: batas 5 promosi dijaga di [setDipromosikan], bukan di sini,
  /// supaya "menyimpan" dan "menyalakan promosi" tetap dua hal yang terpisah.
  Future<KebiasaanData> simpan({
    int? id,
    String? idKebiasaan,
    required String nama,
    String ikon = 'repeat',
    String warna = '#4A90D9',
    int targetPerMinggu = 7,
    bool dipromosikan = false,
    bool aktif = true,
    int urutan = 0,
    String? catatan,
  }) async {
    final bersih = nama.trim();
    if (bersih.isEmpty) {
      throw ArgumentError('Nama kebiasaan belum diisi.');
    }
    if (targetPerMinggu < 1 || targetPerMinggu > 7) {
      throw ArgumentError('Target per minggu harus antara 1 sampai 7.');
    }

    if (id != null) {
      await (db.update(db.kebiasaan)..where((k) => k.id.equals(id)))
          .write(KebiasaanCompanion(
        idKebiasaan:
            idKebiasaan == null ? const Value.absent() : Value(idKebiasaan),
        nama: Value(bersih),
        ikon: Value(ikon),
        warna: Value(warna),
        targetPerMinggu: Value(targetPerMinggu),
        dipromosikan: Value(dipromosikan),
        aktif: Value(aktif),
        urutan: Value(urutan),
        catatan: Value(catatan),
      ));
      final baris = await (db.select(db.kebiasaan)
            ..where((k) => k.id.equals(id)))
          .getSingle();
      return baris;
    }

    return db.into(db.kebiasaan).insertReturning(KebiasaanCompanion.insert(
          idKebiasaan: idKebiasaan ?? idBaru(),
          nama: bersih,
          ikon: Value(ikon),
          warna: Value(warna),
          targetPerMinggu: Value(targetPerMinggu),
          dipromosikan: Value(dipromosikan),
          aktif: Value(aktif),
          urutan: Value(urutan),
          catatan: Value(catatan),
        ));
  }

  /// Seluruh kebiasaan, aktif maupun tidak, urut menurut `urutan` lalu nama.
  Future<List<KebiasaanData>> ambilSemua() => (db.select(db.kebiasaan)
        ..orderBy([
          (k) => OrderingTerm.asc(k.urutan),
          (k) => OrderingTerm.asc(k.nama),
        ]))
      .get();

  /// Kebiasaan yang tampil di Hari Ini: aktif **dan** dipromosikan.
  Future<List<KebiasaanData>> ambilDipromosikan() => (db.select(db.kebiasaan)
        ..where((k) => k.aktif.equals(true) & k.dipromosikan.equals(true))
        ..orderBy([
          (k) => OrderingTerm.asc(k.urutan),
          (k) => OrderingTerm.asc(k.nama),
        ]))
      .get();

  /// Berapa baris yang saat ini tampil di Hari Ini (aktif dan dipromosikan).
  Future<int> jumlahDipromosikan() async {
    final q = db.selectOnly(db.kebiasaan)
      ..addColumns([db.kebiasaan.id.count()])
      ..where(db.kebiasaan.aktif.equals(true) &
          db.kebiasaan.dipromosikan.equals(true));
    final baris = await q.getSingle();
    return baris.read(db.kebiasaan.id.count()) ?? 0;
  }

  /// Nyalakan atau matikan promosi satu kebiasaan.
  ///
  /// Mengembalikan `false` bila promosi **tidak jadi dinyalakan** karena kuota
  /// [maksDipromosikan] sudah penuh. Dalam hal itu data tidak berubah sama
  /// sekali: baris lain tetap seperti semula. Mematikan promosi selalu berhasil.
  Future<bool> setDipromosikan(int id, bool nilai) async {
    final baris = await (db.select(db.kebiasaan)..where((k) => k.id.equals(id)))
        .getSingleOrNull();
    if (baris == null) return !nilai;
    if (!nilai) {
      if (baris.dipromosikan) {
        await (db.update(db.kebiasaan)..where((k) => k.id.equals(id)))
            .write(const KebiasaanCompanion(dipromosikan: Value(false)));
      }
      return true;
    }
    if (baris.dipromosikan) return true; // sudah menyala, kuota tidak bertambah
    if (await jumlahDipromosikan() >= maksDipromosikan) return false;
    await (db.update(db.kebiasaan)..where((k) => k.id.equals(id)))
        .write(const KebiasaanCompanion(dipromosikan: Value(true)));
    return true;
  }

  /// Catat capaian satu kebiasaan pada satu tanggal.
  ///
  /// Upsert menurut pasangan (kebiasaan, hari): memanggil ulang pada hari yang
  /// sama akan memperbarui barisnya, bukan menambah baris baru. [nilai] dijepit
  /// ke 0,0–1,0 dan [tanggal] dinormalkan ke hari-saja.
  Future<void> catat(
    int kebiasaanId,
    DateTime tanggal,
    double nilai, {
    String? catatan,
  }) async {
    final hari = hariSaja(tanggal);
    final angka = nilai.isNaN ? 0.0 : nilai.clamp(0.0, 1.0).toDouble();
    final ada = await logHari(kebiasaanId, hari);
    if (ada == null) {
      await db.into(db.logKebiasaan).insert(LogKebiasaanCompanion.insert(
            kebiasaanId: kebiasaanId,
            tanggal: hari,
            nilai: Value(angka),
            catatan: Value(catatan),
          ));
      return;
    }
    await (db.update(db.logKebiasaan)..where((l) => l.id.equals(ada.id)))
        .write(LogKebiasaanCompanion(
      nilai: Value(angka),
      catatan: Value(catatan),
    ));
  }

  /// Baris catatan satu kebiasaan pada satu hari (null bila belum tercatat).
  Future<LogKebiasaanData?> logHari(int kebiasaanId, DateTime tanggal) =>
      (db.select(db.logKebiasaan)
            ..where((l) =>
                l.kebiasaanId.equals(kebiasaanId) &
                l.tanggal.equals(hariSaja(tanggal))))
          .getSingleOrNull();

  /// Seluruh catatan pada satu hari: `kebiasaanId` -> jumlah nilai hari itu.
  ///
  /// Satu hari hanya dihitung sekali walau nilainya pecahan (0,5).
  Future<Map<int, double>> nilaiHari(DateTime tanggal) async {
    final hari = hariSaja(tanggal);
    final q = db.selectOnly(db.logKebiasaan)
      ..addColumns([db.logKebiasaan.kebiasaanId, db.logKebiasaan.nilai.sum()])
      ..where(db.logKebiasaan.tanggal.equals(hari))
      ..groupBy([db.logKebiasaan.kebiasaanId]);
    final baris = await q.get();
    return {
      for (final b in baris)
        b.read(db.logKebiasaan.kebiasaanId)!:
            b.read(db.logKebiasaan.nilai.sum()) ?? 0,
    };
  }

  /// Ringkasan satu kebiasaan selama [hari] hari terakhir sampai [sampai].
  ///
  /// `sampai` bawaan = [waktuSekarang] (bukan `DateTime.now()`) supaya uji dan
  /// tangkapan layar bisa mengunci tanggal. Rentangnya inklusif: untuk
  /// `hari: 7` dan `sampai: T`, yang dihitung adalah T-6 sampai T.
  Future<RingkasanKebiasaan> ringkasan(
    int kebiasaanId, {
    int hari = 7,
    DateTime? sampai,
  }) async {
    final panjang = _panjangRentang(hari);
    final akhir = hariSaja(sampai ?? waktuSekarang());
    final awal = akhir.subtract(Duration(days: panjang - 1));
    final q = db.selectOnly(db.logKebiasaan)
      ..addColumns([db.logKebiasaan.tanggal, db.logKebiasaan.nilai.sum()])
      ..where(db.logKebiasaan.kebiasaanId.equals(kebiasaanId) &
          db.logKebiasaan.tanggal.isBetweenValues(awal, akhir))
      ..groupBy([db.logKebiasaan.tanggal]);
    final baris = await q.get();
    return _rangkum(
      panjang,
      baris.map((b) => b.read(db.logKebiasaan.nilai.sum()) ?? 0),
    );
  }

  /// Ringkasan semua kebiasaan untuk rentang yang sama.
  ///
  /// Setiap kebiasaan pada [ambilSemua] selalu punya entri — kebiasaan tanpa
  /// catatan mendapat ringkasan nol, jadi layar tidak perlu menebak.
  Future<Map<int, RingkasanKebiasaan>> ringkasanSemua({
    int hari = 7,
    DateTime? sampai,
  }) async {
    final panjang = _panjangRentang(hari);
    final akhir = hariSaja(sampai ?? waktuSekarang());
    final awal = akhir.subtract(Duration(days: panjang - 1));
    final q = db.selectOnly(db.logKebiasaan)
      ..addColumns([
        db.logKebiasaan.kebiasaanId,
        db.logKebiasaan.tanggal,
        db.logKebiasaan.nilai.sum(),
      ])
      ..where(db.logKebiasaan.tanggal.isBetweenValues(awal, akhir))
      ..groupBy([db.logKebiasaan.kebiasaanId, db.logKebiasaan.tanggal]);
    final baris = await q.get();

    final perKebiasaan = <int, List<double>>{};
    for (final b in baris) {
      final id = b.read(db.logKebiasaan.kebiasaanId)!;
      final nilai = b.read(db.logKebiasaan.nilai.sum()) ?? 0;
      (perKebiasaan[id] ??= <double>[]).add(nilai);
    }

    final hasil = <int, RingkasanKebiasaan>{};
    for (final k in await ambilSemua()) {
      hasil[k.id] = _rangkum(panjang, perKebiasaan[k.id] ?? const <double>[]);
    }
    return hasil;
  }

  /// Hapus satu kebiasaan beserta catatannya.
  ///
  /// Urutannya jelas: baris log dibuang lebih dulu supaya tidak ada catatan
  /// yatim. Mengembalikan jumlah baris kebiasaan yang terhapus (0 atau 1).
  Future<int> hapus(int id) async {
    return db.transaction(() async {
      await (db.delete(db.logKebiasaan)
            ..where((l) => l.kebiasaanId.equals(id)))
          .go();
      return (db.delete(db.kebiasaan)..where((k) => k.id.equals(id))).go();
    });
  }

  // -------------------------------------------------------------------------
  // Pembantu murni
  // -------------------------------------------------------------------------

  /// Tanggal tanpa jam — kunci harian catatan kebiasaan.
  static DateTime hariSaja(DateTime t) => DateTime(t.year, t.month, t.day);

  static int _panjangRentang(int hari) => hari < 1 ? 1 : hari;

  /// Ubah daftar nilai per hari menjadi ringkasan netral.
  static RingkasanKebiasaan _rangkum(
    int jumlahHari,
    Iterable<double> nilaiPerHari,
  ) {
    var tercatat = 0;
    var penuh = 0;
    var total = 0.0;
    for (final n in nilaiPerHari) {
      total += n;
      if (n > 0) tercatat++;
      if (n >= 1) penuh++;
    }
    return RingkasanKebiasaan(
      jumlahHari: jumlahHari,
      hariTercatat: tercatat,
      hariPenuh: penuh,
      totalNilai: total,
    );
  }
}
