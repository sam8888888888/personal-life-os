/// Repositori pembayaran kewajiban/utang — FR-69 (catat pembayaran utang)
/// dan FR-74 (prioritas & jadwal pembayaran).
///
/// Aturan hitung yang dipegang berkas ini (semuanya diuji di
/// `test/v2_uang_lanjutan_test.dart`):
///
/// * **Sisa utang = pokok acuan - jumlah bagian pokok yang sudah dibayar.**
///   Bagian bunga TIDAK mengurangi sisa utang.
/// * **Pokok acuan** diambil dari `saldoAwalSen` bila diisi (sisa saat
///   kewajiban didaftarkan), dan dari `pokokSen` bila `saldoAwalSen` nol.
///   Keduanya disiapkan sejak skema v3; berkas ini hanya memilih salah satu
///   supaya angkanya tidak pernah dibaca dari kolom yang kosong.
/// * **jumlahSen = pokokSen + bungaSen.** Baris yang tidak konsisten ditolak
///   dengan galat jelas, bukan diperbaiki diam-diam.
/// * **Bagian pokok tidak boleh melebihi sisa utang.** Pengguna diminta
///   memperbaiki angkanya daripada aplikasi menyimpan sisa negatif.
/// * **Hapus kewajiban ikut menghapus pembayarannya** — aturan hapus
///   berdampingan ada di repositori ini, bukan di layar.
///
/// Waktu dicatat lewat `dicatatPada` yang memakai sumber waktu tunggal
/// (`lib/core/utils/waktu.dart`), sehingga uji dapat mengunci jam.
library;

import 'package:drift/drift.dart';

import '../../core/utils/waktu.dart';
import '../database/database.dart';

/// Pokok acuan untuk menghitung sisa utang. Lihat catatan di atas.
int hitungPokokAcuanSen(KewajibanData k) =>
    k.saldoAwalSen > 0 ? k.saldoAwalSen : k.pokokSen;

/// Sisa utang dari pokok acuan (fungsi murni). Tidak pernah negatif.
int sisaUtangSen({required int pokokAcuan, required int totalPokokDibayar}) {
  final sisa = pokokAcuan - totalPokokDibayar;
  return sisa < 0 ? 0 : sisa;
}

/// Ringkasan satu kewajiban dari barisnya + seluruh pembayarannya.
class RingkasanKewajiban {
  const RingkasanKewajiban({
    required this.kewajiban,
    required this.pokokAcuanSen,
    required this.totalPokokDibayarSen,
    required this.totalBungaDibayarSen,
    required this.jumlahPembayaran,
    required this.terakhirDibayarPada,
  });

  /// Baris kewajiban apa adanya (nama, jenis, jadwal, catatan).
  final KewajibanData kewajiban;

  /// Pokok acuan (lihat [hitungPokokAcuanSen]).
  final int pokokAcuanSen;

  /// Jumlah seluruh bagian pokok yang sudah dibayar (sen).
  final int totalPokokDibayarSen;

  /// Jumlah seluruh bagian bunga yang sudah dibayar (sen).
  final int totalBungaDibayarSen;

  final int jumlahPembayaran;

  /// Tanggal pembayaran terakhir, null bila belum ada pembayaran.
  final DateTime? terakhirDibayarPada;

  /// Sisa utang yang masih perlu dibayar.
  int get sisaSen => sisaUtangSen(
        pokokAcuan: pokokAcuanSen,
        totalPokokDibayar: totalPokokDibayarSen,
      );

  /// Seluruh uang yang sudah keluar untuk kewajiban ini.
  int get totalDibayarSen => totalPokokDibayarSen + totalBungaDibayarSen;

  /// true = sisa utang nol atau kurang (kewajiban sudah tuntas).
  bool get lunas => sisaSen <= 0;

  /// Bagian pokok acuan yang sudah dibayar, 0.0-1.0 (bahan bilah kemajuan).
  double get bagianPokokTerbayar {
    if (pokokAcuanSen <= 0) return lunas ? 1 : 0;
    return (totalPokokDibayarSen / pokokAcuanSen).clamp(0.0, 1.0);
  }
}

/// Hitung ringkasan dari baris kewajiban + daftar pembayarannya
/// (fungsi murni: tidak menyentuh basis data, mudah diuji).
RingkasanKewajiban ringkasKewajiban(
  KewajibanData kewajiban,
  List<PembayaranKewajibanData> pembayaran,
) {
  var pokok = 0;
  var bunga = 0;
  DateTime? terakhir;
  for (final p in pembayaran) {
    pokok += p.pokokSen;
    bunga += p.bungaSen;
    if (terakhir == null || p.tanggal.isAfter(terakhir)) terakhir = p.tanggal;
  }
  return RingkasanKewajiban(
    kewajiban: kewajiban,
    pokokAcuanSen: hitungPokokAcuanSen(kewajiban),
    totalPokokDibayarSen: pokok,
    totalBungaDibayarSen: bunga,
    jumlahPembayaran: pembayaran.length,
    terakhirDibayarPada: terakhir,
  );
}

/// Pembayaran kewajiban: pencatatan, riwayat, dan hapus berdampingan.
class PembayaranKewajibanRepository {
  PembayaranKewajibanRepository(this.db, {DateTime Function()? jamSekarang})
      : jam = jamSekarang ?? waktuSekarang;

  final AppDatabase db;

  /// Sumber waktu (bisa dikunci uji).
  final DateTime Function() jam;

  // -------------------------------------------------------------------------
  // Kewajiban
  // -------------------------------------------------------------------------

  /// Daftar kewajiban urut nama (bawaan: tanpa yang diarsipkan).
  Future<List<KewajibanData>> ambilKewajiban({bool sertakanArsip = false}) {
    final q = db.select(db.kewajiban)
      ..orderBy([(k) => OrderingTerm.asc(k.nama), (k) => OrderingTerm.asc(k.id)]);
    if (!sertakanArsip) q.where((k) => k.arsip.equals(false));
    return q.get();
  }

  Stream<List<KewajibanData>> watchKewajiban({bool sertakanArsip = false}) {
    final q = db.select(db.kewajiban)
      ..orderBy([(k) => OrderingTerm.asc(k.nama), (k) => OrderingTerm.asc(k.id)]);
    if (!sertakanArsip) q.where((k) => k.arsip.equals(false));
    return q.watch();
  }

  Future<KewajibanData?> ambilKewajibanSatu(int id) =>
      (db.select(db.kewajiban)..where((k) => k.id.equals(id)))
          .getSingleOrNull();

  /// Semua kewajiban beserta sisa utangnya, urut nama.
  Future<List<RingkasanKewajiban>> ambilRingkasan(
      {bool sertakanArsip = false}) async {
    final daftar = await ambilKewajiban(sertakanArsip: sertakanArsip);
    final semua = await db.select(db.pembayaranKewajiban).get();
    return [
      for (final k in daftar)
        ringkasKewajiban(
          k,
          semua.where((p) => p.kewajibanId == k.id).toList(growable: false),
        ),
    ];
  }

  /// Ringkasan satu kewajiban; null bila barisnya tidak ada.
  Future<RingkasanKewajiban?> ambilRingkasanSatu(int kewajibanId) async {
    final k = await ambilKewajibanSatu(kewajibanId);
    if (k == null) return null;
    final p = await ambilPembayaran(kewajibanId);
    return ringkasKewajiban(k, p);
  }

  /// Jumlah sisa utang seluruh kewajiban aktif (sen).
  Future<int> totalSisaSen({bool sertakanArsip = false}) async {
    final ringkasan = await ambilRingkasan(sertakanArsip: sertakanArsip);
    var total = 0;
    for (final r in ringkasan) {
      total += r.sisaSen;
    }
    return total;
  }

  // -------------------------------------------------------------------------
  // Pembayaran
  // -------------------------------------------------------------------------

  /// Riwayat pembayaran satu kewajiban: terbaru lebih dulu.
  ///
  /// Urutan kedua memakai `id` supaya dua pembayaran bertanggal sama tetap
  /// punya urutan tetap (tidak berubah-ubah setiap dibaca).
  Future<List<PembayaranKewajibanData>> ambilPembayaran(int kewajibanId) =>
      (db.select(db.pembayaranKewajiban)
            ..where((p) => p.kewajibanId.equals(kewajibanId))
            ..orderBy([
              (p) => OrderingTerm.desc(p.tanggal),
              (p) => OrderingTerm.desc(p.id),
            ]))
          .get();

  /// Catat satu pembayaran kewajiban.
  ///
  /// [jumlahSen] = uang yang benar-benar keluar; [pokokSen] = bagian yang
  /// mengurangi sisa utang; bagian bunga dihitung sebagai
  /// `jumlahSen - pokokSen` bila [bungaSen] tidak diisi.
  ///
  /// [pokokSen] boleh tidak diisi (null): seluruh pembayaran dianggap pokok,
  /// dibatasi sisa utang — selebihnya menjadi bagian bunga. Jadi
  /// `catatPembayaran(jumlahSen: x)` selalu berarti "saya bayar x untuk
  /// mengurangi utang".
  ///
  /// Galat yang dilempar:
  /// * [ArgumentError] bila kewajiban tidak punya baris, jumlah <= 0,
  ///   pokok < 0, atau `jumlahSen != pokokSen + bungaSen`;
  /// * [ArgumentError] bila bagian pokok melebihi sisa utang (disebutkan
  ///   angka sisanya supaya pengguna tahu batas amannya).
  Future<PembayaranKewajibanData> catatPembayaran({
    required int kewajibanId,
    required DateTime tanggal,
    required int jumlahSen,
    int? pokokSen,
    int? bungaSen,
    String? catatan,
  }) async {
    final k = await ambilKewajibanSatu(kewajibanId);
    if (k == null) {
      throw ArgumentError('Kewajiban itu tidak ditemukan.');
    }
    if (jumlahSen <= 0) {
      throw ArgumentError('Jumlah pembayaran perlu lebih dari nol.');
    }

    final ringkasan = await ambilRingkasanSatu(kewajibanId);
    final sisa = ringkasan?.sisaSen ?? 0;

    // Bagian pokok tidak diisi = seluruh pembayaran dianggap pokok, dibatasi
    // sisa utang; selebihnya menjadi bagian bunga. Aturan ini sengaja
    // ditaruh di sini supaya layar tidak perlu mengulang hitungan yang sama.
    final pokok = pokokSen ?? (jumlahSen > sisa ? sisa : jumlahSen);
    if (pokok < 0) {
      throw ArgumentError('Bagian pokok tidak boleh negatif.');
    }
    if (pokok > jumlahSen) {
      throw ArgumentError('Bagian pokok tidak boleh lebih besar dari jumlah '
          'pembayaran.');
    }
    final bunga = bungaSen ?? (jumlahSen - pokok);
    if (bunga < 0) {
      throw ArgumentError('Bagian bunga tidak boleh negatif.');
    }
    if (pokok + bunga != jumlahSen) {
      throw ArgumentError('Jumlah pembayaran harus sama dengan bagian pokok '
          'ditambah bagian bunga.');
    }
    if (pokok > sisa) {
      throw ArgumentError('Bagian pokok melebihi sisa utang. Sisa utang '
          'sekarang lebih kecil dari yang Anda isi. Isi bagian pokok paling '
          'besar sebesar sisa utang itu, lalu tandai sisanya sebagai bagian '
          'bunga.');
    }

    return db.into(db.pembayaranKewajiban).insertReturning(
          PembayaranKewajibanCompanion.insert(
            kewajibanId: kewajibanId,
            tanggal: DateTime(tanggal.year, tanggal.month, tanggal.day),
            jumlahSen: jumlahSen,
            pokokSen: Value(pokok),
            bungaSen: Value(bunga),
            catatan: Value(catatan),
            dicatatPada: Value(jam()),
          ),
        );
  }

  /// Hapus satu baris pembayaran. Tidak ada baris lain yang bergantung
  /// padanya, jadi cukup satu baris yang dihapus.
  Future<int> hapusPembayaran(int id) =>
      (db.delete(db.pembayaranKewajiban)..where((p) => p.id.equals(id))).go();

  // -------------------------------------------------------------------------
  // Hapus berdampingan
  // -------------------------------------------------------------------------

  /// Hapus kewajiban BESERTA seluruh pembayaran dan catatan nilai bulanannya,
  /// dalam satu transaksi. Bila satu langkah gagal, tidak ada yang terhapus
  /// separuh.
  ///
  /// Catatan: `AsetRepository.hapusKewajiban` (FR-76) hanya menghapus
  /// nilai bulanan + baris kewajiban. Karena skema v4 menambahkan tabel
  /// pembayaran, jalur hapus di modul ini yang dipakai layar hutang.
  Future<void> hapusKewajiban(int kewajibanId) => db.transaction(() async {
        await (db.delete(db.pembayaranKewajiban)
              ..where((p) => p.kewajibanId.equals(kewajibanId)))
            .go();
        await (db.delete(db.nilaiKewajibanBulanan)
              ..where((n) => n.kewajibanId.equals(kewajibanId)))
            .go();
        await (db.delete(db.kewajiban)..where((k) => k.id.equals(kewajibanId)))
            .go();
      });
}
