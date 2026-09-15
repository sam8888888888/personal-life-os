/// Repositori aset, kewajiban & nilai bersih (FR-76 Net Worth Tracker).
///
/// Kriteria terima FR-76:
/// * nilai bersih = aset − kewajiban (ada uji hitungnya),
/// * grafik menyimpan riwayat bulanan dan **tidak berubah retroaktif**.
///
/// Karena itu nilai bulan yang sudah lewat ditandai `terkunci`. Mengubahnya
/// hanya bisa dengan permintaan eksplisit ([paksa] + [alasan]) dan meninggalkan
/// jejak `dibukaKunciPada`/`alasanBukaKunci` — supaya salah ketik tetap bisa
/// diperbaiki, tetapi tidak ada angka masa lalu yang berubah diam-diam.
///
/// Nilai bersih bulanan TIDAK disimpan di tabel: selalu dihitung dari
/// `NilaiAsetBulanan` − `NilaiKewajibanBulanan`, jadi tidak ada dua angka yang
/// bisa tidak sinkron (keputusan rancangan §4.8).
library;

import 'package:drift/drift.dart';

import '../../core/utils/waktu.dart';
import '../database/database.dart';
import '../model/enums.dart';
import 'periode.dart';

class AsetRepository {
  AsetRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? waktuSekarang;

  final AppDatabase db;
  final DateTime Function() _jam;

  // -------------------------------------------------------------------------
  // Aset
  // -------------------------------------------------------------------------

  static String idAsetBaru() => 'ast_${DateTime.now().microsecondsSinceEpoch}';
  static String idKewajibanBaru() =>
      'kew_${DateTime.now().microsecondsSinceEpoch}';

  Stream<List<AsetData>> watchAset() => (db.select(db.aset)
        ..where((a) => a.arsip.equals(false))
        ..orderBy([(a) => OrderingTerm.asc(a.nama)]))
      .watch();

  Stream<List<AsetData>> watchSemuaAset() => (db.select(db.aset)
        ..orderBy([(a) => OrderingTerm.asc(a.nama)]))
      .watch();

  Future<List<AsetData>> ambilAset({bool sertakanArsip = false}) {
    final q = db.select(db.aset)..orderBy([(a) => OrderingTerm.asc(a.nama)]);
    if (!sertakanArsip) q.where((a) => a.arsip.equals(false));
    return q.get();
  }

  Future<AsetData?> ambilAsetSatu(int id) =>
      (db.select(db.aset)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<AsetData> tambahAset({
    required String nama,
    JenisAset jenis = JenisAset.kas,
    int nilaiAwalSen = 0,
    bool likuid = true,
    String? institusi,
    String? catatan,
    String? idAset,
  }) async {
    final bersih = nama.trim();
    if (bersih.isEmpty) {
      throw ArgumentError('Nama aset tidak boleh kosong.');
    }
    if (nilaiAwalSen < 0) {
      throw ArgumentError('Nilai aset tidak boleh negatif.');
    }
    return db.into(db.aset).insertReturning(AsetCompanion.insert(
          idAset: idAset ?? idAsetBaru(),
          nama: bersih,
          jenis: Value(jenis.nilaiDb),
          nilaiAwalSen: Value(nilaiAwalSen),
          likuid: Value(likuid),
          institusi: Value(institusi),
          catatan: Value(catatan),
        ));
  }

  Future<int> ubahAset(
    int id, {
    String? nama,
    JenisAset? jenis,
    int? nilaiAwalSen,
    bool? likuid,
    String? institusi,
    String? catatan,
    bool? arsip,
  }) {
    if (nilaiAwalSen != null && nilaiAwalSen < 0) {
      throw ArgumentError('Nilai aset tidak boleh negatif.');
    }
    return (db.update(db.aset)..where((a) => a.id.equals(id)))
        .write(AsetCompanion(
      nama: nama == null ? const Value.absent() : Value(nama.trim()),
      jenis: jenis == null ? const Value.absent() : Value(jenis.nilaiDb),
      nilaiAwalSen:
          nilaiAwalSen == null ? const Value.absent() : Value(nilaiAwalSen),
      likuid: likuid == null ? const Value.absent() : Value(likuid),
      institusi: institusi == null ? const Value.absent() : Value(institusi),
      catatan: catatan == null ? const Value.absent() : Value(catatan),
      arsip: arsip == null ? const Value.absent() : Value(arsip),
      diubahPada: Value(DateTime.now()),
    ));
  }

  /// Sembunyikan aset tanpa menghapus riwayat nilainya (keputusan §4.6).
  Future<int> arsipkanAset(int id, {bool arsip = true}) => ubahAset(id, arsip: arsip);

  /// Hapus aset BESERTA seluruh riwayat nilainya, dalam satu transaksi.
  /// (Hapus aset yang masih punya riwayat = tindakan sadar; UI sebaiknya
  /// menawarkan [arsipkanAset] lebih dulu.)
  Future<void> hapusAset(int id) => db.transaction(() async {
        await (db.delete(db.nilaiAsetBulanan)
              ..where((n) => n.asetId.equals(id)))
            .go();
        await (db.delete(db.aset)..where((a) => a.id.equals(id))).go();
      });

  // -------------------------------------------------------------------------
  // Kewajiban
  // -------------------------------------------------------------------------

  Stream<List<KewajibanData>> watchKewajiban() => (db.select(db.kewajiban)
        ..where((k) => k.arsip.equals(false))
        ..orderBy([(k) => OrderingTerm.asc(k.nama)]))
      .watch();

  Future<List<KewajibanData>> ambilKewajiban({bool sertakanArsip = false}) {
    final q = db.select(db.kewajiban)
      ..orderBy([(k) => OrderingTerm.asc(k.nama)]);
    if (!sertakanArsip) q.where((k) => k.arsip.equals(false));
    return q.get();
  }

  Future<KewajibanData?> ambilKewajibanSatu(int id) =>
      (db.select(db.kewajiban)..where((k) => k.id.equals(id))).getSingleOrNull();

  Future<KewajibanData> tambahKewajiban({
    required String nama,
    JenisKewajiban jenis = JenisKewajiban.lain,
    int pokokSen = 0,
    int saldoAwalSen = 0,
    double? sukuBungaPersenTahun,
    int? minimumBayarSen,
    int? tanggalJatuhTempoHari,
    String? catatan,
    String? idKewajiban,
  }) async {
    final bersih = nama.trim();
    if (bersih.isEmpty) {
      throw ArgumentError('Nama kewajiban tidak boleh kosong.');
    }
    if (pokokSen < 0 || saldoAwalSen < 0) {
      throw ArgumentError('Nilai kewajiban tidak boleh negatif.');
    }
    if (tanggalJatuhTempoHari != null &&
        (tanggalJatuhTempoHari < 1 || tanggalJatuhTempoHari > 31)) {
      throw ArgumentError('Tanggal jatuh tempo harus 1–31.');
    }
    return db.into(db.kewajiban).insertReturning(KewajibanCompanion.insert(
          idKewajiban: idKewajiban ?? idKewajibanBaru(),
          nama: bersih,
          jenis: Value(jenis.nilaiDb),
          pokokSen: Value(pokokSen),
          saldoAwalSen: Value(saldoAwalSen),
          sukuBungaPersenTahun: Value(sukuBungaPersenTahun),
          minimumBayarSen: Value(minimumBayarSen),
          tanggalJatuhTempoHari: Value(tanggalJatuhTempoHari),
          catatan: Value(catatan),
        ));
  }

  Future<int> ubahKewajiban(
    int id, {
    String? nama,
    JenisKewajiban? jenis,
    int? pokokSen,
    int? saldoAwalSen,
    double? sukuBungaPersenTahun,
    int? minimumBayarSen,
    int? tanggalJatuhTempoHari,
    String? catatan,
    bool? arsip,
  }) {
    if ((pokokSen != null && pokokSen < 0) ||
        (saldoAwalSen != null && saldoAwalSen < 0)) {
      throw ArgumentError('Nilai kewajiban tidak boleh negatif.');
    }
    return (db.update(db.kewajiban)..where((k) => k.id.equals(id)))
        .write(KewajibanCompanion(
      nama: nama == null ? const Value.absent() : Value(nama.trim()),
      jenis: jenis == null ? const Value.absent() : Value(jenis.nilaiDb),
      pokokSen: pokokSen == null ? const Value.absent() : Value(pokokSen),
      saldoAwalSen:
          saldoAwalSen == null ? const Value.absent() : Value(saldoAwalSen),
      sukuBungaPersenTahun: sukuBungaPersenTahun == null
          ? const Value.absent()
          : Value(sukuBungaPersenTahun),
      minimumBayarSen: minimumBayarSen == null
          ? const Value.absent()
          : Value(minimumBayarSen),
      tanggalJatuhTempoHari: tanggalJatuhTempoHari == null
          ? const Value.absent()
          : Value(tanggalJatuhTempoHari),
      catatan: catatan == null ? const Value.absent() : Value(catatan),
      arsip: arsip == null ? const Value.absent() : Value(arsip),
      diubahPada: Value(DateTime.now()),
    ));
  }

  Future<int> arsipkanKewajiban(int id, {bool arsip = true}) =>
      ubahKewajiban(id, arsip: arsip);

  Future<void> hapusKewajiban(int id) => db.transaction(() async {
        await (db.delete(db.nilaiKewajibanBulanan)
              ..where((n) => n.kewajibanId.equals(id)))
            .go();
        await (db.delete(db.kewajiban)..where((k) => k.id.equals(id))).go();
      });

  // -------------------------------------------------------------------------
  // Riwayat nilai bulanan
  // -------------------------------------------------------------------------

  /// Simpan nilai aset satu bulan (idempoten: kunci `aset_id` + `bulan`).
  ///
  /// Bulan yang sudah lewat dikunci otomatis. Mengubah baris terkunci wajib
  /// memakai [paksa] = true **dan** [alasan]; jejaknya disimpan.
  Future<void> simpanNilaiAset({
    required int asetId,
    required String bulan,
    required int nilaiSen,
    bool paksa = false,
    String? alasan,
    String sumber = 'manual',
  }) async {
    if (await ambilAsetSatu(asetId) == null) {
      throw StateError('Aset tidak ditemukan.');
    }
    final lama = await _nilaiAset(asetId, bulan);
    final isi = _siapkanNilai(
      bulan: bulan,
      nilaiSen: nilaiSen,
      lama: lama,
      paksa: paksa,
      alasan: alasan,
      sumber: sumber,
    );
    await db.into(db.nilaiAsetBulanan).insert(
          NilaiAsetBulananCompanion.insert(
            asetId: asetId,
            bulan: bulan,
            nilaiSen: nilaiSen,
            sumber: Value(sumber),
            idempotensi: 'aset:$asetId:$bulan',
            terkunci: Value(isi.terkunci),
            dikunciPada: Value(isi.dikunciPada),
            dibukaKunciPada: Value(isi.dibukaKunciPada),
            alasanBukaKunci: Value(isi.alasanBukaKunci),
            diubahPada: Value(DateTime.now()),
          ),
          onConflict: DoUpdate(
            (_) => NilaiAsetBulananCompanion(
              nilaiSen: Value(nilaiSen),
              sumber: Value(sumber),
              terkunci: Value(isi.terkunci),
              dikunciPada: Value(isi.dikunciPada),
              dibukaKunciPada: Value(isi.dibukaKunciPada),
              alasanBukaKunci: Value(isi.alasanBukaKunci),
              diubahPada: Value(DateTime.now()),
            ),
            target: [db.nilaiAsetBulanan.asetId, db.nilaiAsetBulanan.bulan],
          ),
        );
  }

  /// Simpan nilai kewajiban satu bulan (aturan kunci sama seperti aset).
  Future<void> simpanNilaiKewajiban({
    required int kewajibanId,
    required String bulan,
    required int nilaiSen,
    bool paksa = false,
    String? alasan,
    String sumber = 'manual',
  }) async {
    if (await ambilKewajibanSatu(kewajibanId) == null) {
      throw StateError('Kewajiban tidak ditemukan.');
    }
    final lama = await _nilaiKewajiban(kewajibanId, bulan);
    final isi = _siapkanNilai(
      bulan: bulan,
      nilaiSen: nilaiSen,
      lama: lama,
      paksa: paksa,
      alasan: alasan,
      sumber: sumber,
    );
    await db.into(db.nilaiKewajibanBulanan).insert(
          NilaiKewajibanBulananCompanion.insert(
            kewajibanId: kewajibanId,
            bulan: bulan,
            nilaiSen: nilaiSen,
            sumber: Value(sumber),
            idempotensi: 'kewajiban:$kewajibanId:$bulan',
            terkunci: Value(isi.terkunci),
            dikunciPada: Value(isi.dikunciPada),
            dibukaKunciPada: Value(isi.dibukaKunciPada),
            alasanBukaKunci: Value(isi.alasanBukaKunci),
            diubahPada: Value(DateTime.now()),
          ),
          onConflict: DoUpdate(
            (_) => NilaiKewajibanBulananCompanion(
              nilaiSen: Value(nilaiSen),
              sumber: Value(sumber),
              terkunci: Value(isi.terkunci),
              dikunciPada: Value(isi.dikunciPada),
              dibukaKunciPada: Value(isi.dibukaKunciPada),
              alasanBukaKunci: Value(isi.alasanBukaKunci),
              diubahPada: Value(DateTime.now()),
            ),
            target: [
              db.nilaiKewajibanBulanan.kewajibanId,
              db.nilaiKewajibanBulanan.bulan,
            ],
          ),
        );
  }

  /// Nilai bersih satu bulan: aset − kewajiban.
  ///
  /// Untuk tiap aset/kewajiban dipakai nilai bulanan **terakhir yang ≤ bulan
  /// itu**; bila belum ada sama sekali, dipakai nilai awal (`nilaiAwalSen` /
  /// `saldoAwalSen`). Baris yang diarsipkan tidak dihitung (kecuali
  /// [sertakanArsip]).
  Future<NilaiBersih> nilaiBersih(String bulan, {bool sertakanArsip = false}) async {
    final daftarAset = await ambilAset(sertakanArsip: sertakanArsip);
    final daftarKewajiban = await ambilKewajiban(sertakanArsip: sertakanArsip);

    var totalAset = 0;
    for (final a in daftarAset) {
      totalAset += await _nilaiAsetPada(a, bulan);
    }
    var totalKewajiban = 0;
    for (final k in daftarKewajiban) {
      totalKewajiban += await _nilaiKewajibanPada(k, bulan);
    }
    return NilaiBersih(
      bulan: bulan,
      totalAsetSen: totalAset,
      totalKewajibanSen: totalKewajiban,
    );
  }

  /// Tren bulanan dari [dari] sampai [sampai] (keduanya `YYYY-MM`, inklusif).
  Future<List<NilaiBersih>> tren({
    required String dari,
    required String sampai,
    bool sertakanArsip = false,
  }) async {
    final awal = bulanDariKunci(dari);
    if (awal == null || bulanDariKunci(sampai) == null) {
      throw ArgumentError('Rentang tren harus berformat YYYY-MM.');
    }
    if (sampai.compareTo(dari) < 0) {
      throw ArgumentError('Bulan akhir tidak boleh sebelum bulan awal.');
    }
    final hasil = <NilaiBersih>[];
    var kunci = dari;
    // Batas aman: rentang maksimum 120 bulan (10 tahun) supaya tidak ada
    // perulangan tak berujung karena salah masukan.
    for (var i = 0; i <= 120; i++) {
      hasil.add(await nilaiBersih(kunci, sertakanArsip: sertakanArsip));
      if (kunci == sampai) break;
      if (i == 120) break;
      kunci = kunciBulanBerikutnya(kunci);
      if (kunci.compareTo(sampai) > 0) break;
    }
    return hasil;
  }

  Future<NilaiAsetBulananData?> _nilaiAset(int asetId, String bulan) =>
      (db.select(db.nilaiAsetBulanan)
            ..where((n) => n.asetId.equals(asetId) & n.bulan.equals(bulan)))
          .getSingleOrNull();

  Future<NilaiKewajibanBulananData?> _nilaiKewajiban(
          int kewajibanId, String bulan) =>
      (db.select(db.nilaiKewajibanBulanan)
            ..where((n) =>
                n.kewajibanId.equals(kewajibanId) & n.bulan.equals(bulan)))
          .getSingleOrNull();

  Future<int> _nilaiAsetPada(AsetData a, String bulan) async {
    final baris = await (db.select(db.nilaiAsetBulanan)
          ..where((n) => n.asetId.equals(a.id) & n.bulan.isSmallerOrEqualValue(bulan))
          ..orderBy([(n) => OrderingTerm.desc(n.bulan)])
          ..limit(1))
        .getSingleOrNull();
    return baris?.nilaiSen ?? a.nilaiAwalSen;
  }

  Future<int> _nilaiKewajibanPada(KewajibanData k, String bulan) async {
    final baris = await (db.select(db.nilaiKewajibanBulanan)
          ..where((n) =>
              n.kewajibanId.equals(k.id) & n.bulan.isSmallerOrEqualValue(bulan))
          ..orderBy([(n) => OrderingTerm.desc(n.bulan)])
          ..limit(1))
        .getSingleOrNull();
    return baris?.nilaiSen ?? k.saldoAwalSen;
  }

  /// Aturan kunci bulan + validasi, dipakai aset maupun kewajiban.
  ({
    bool terkunci,
    DateTime? dikunciPada,
    DateTime? dibukaKunciPada,
    String? alasanBukaKunci,
  }) _siapkanNilai({
    required String bulan,
    required int nilaiSen,
    required Object? lama,
    required bool paksa,
    required String? alasan,
    required String sumber,
  }) {
    if (!kunciBulanSah(bulan)) {
      throw ArgumentError('Bulan harus berformat YYYY-MM, mis. 2026-09.');
    }
    if (nilaiSen < 0) {
      throw ArgumentError('Nilai tidak boleh negatif.');
    }
    final terkunciLama = switch (lama) {
      NilaiAsetBulananData d => d.terkunci,
      NilaiKewajibanBulananData d => d.terkunci,
      _ => false,
    };
    final dikunciPadaLama = switch (lama) {
      NilaiAsetBulananData d => d.dikunciPada,
      NilaiKewajibanBulananData d => d.dikunciPada,
      _ => null,
    };
    if (terkunciLama && !paksa) {
      throw StateError(
          'Nilai bulan $bulan sudah terkunci supaya riwayat tidak berubah. '
          'Kirim ulang dengan paksa = true dan alasan bila memang perlu '
          'diperbaiki.');
    }
    final alasanBersih = (alasan ?? '').trim();
    if (terkunciLama && paksa && alasanBersih.isEmpty) {
      throw ArgumentError('Membuka kunci bulan $bulan wajib memakai alasan.');
    }
    final bulanSekarang = kunciBulan(_jam());
    final lampau = bulan.compareTo(bulanSekarang) < 0;
    return (
      terkunci: lampau,
      dikunciPada: lampau ? (dikunciPadaLama ?? _jam()) : null,
      dibukaKunciPada: terkunciLama ? _jam() : null,
      alasanBukaKunci: terkunciLama ? alasanBersih : null,
    );
  }
}

/// Nilai bersih satu bulan (sen).
class NilaiBersih {
  const NilaiBersih({
    required this.bulan,
    required this.totalAsetSen,
    required this.totalKewajibanSen,
  });

  /// 'YYYY-MM'.
  final String bulan;
  final int totalAsetSen;
  final int totalKewajibanSen;

  /// Nilai bersih = aset − kewajiban (boleh negatif).
  int get bersihSen => totalAsetSen - totalKewajibanSen;
}
