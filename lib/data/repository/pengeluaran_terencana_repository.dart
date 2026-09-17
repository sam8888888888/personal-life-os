/// Repositori pengeluaran terencana — FR-70.
///
/// "Pengeluaran terencana" = uang yang HARUS tersedia sebelum tanggal tertentu,
/// tetapi belum menjadi transaksi. Berkas ini sengaja tidak menyentuh tabel
/// `transaksi`: menandai `sudahTerjadi` hanyalah catatan tanda, bukan
/// pembuatan transaksi (agar tidak ada dua catatan uang untuk satu kejadian).
///
/// Aturan rentang tanggal yang dipegang berkas ini:
///
/// * Tanggal selalu dinormalkan ke pukul 00:00 hari itu — pengeluaran
///   terencana punya tanggal, bukan jam.
/// * Batas atas **eksklusif** (`akhirEksklusif`): baris dihitung bila
///   `tanggal < batas`. Dengan begitu satu hari tidak pernah terhitung dua
///   kali, termasuk saat ada baris bertanda pukul 00:00.
library;

import 'package:drift/drift.dart';

import '../../core/utils/waktu.dart';
import '../database/database.dart';

/// Buang bagian jam: 2026-09-15 14:30 -> 2026-09-15 00:00 (fungsi murni).
DateTime tanggalSaja(DateTime t) => DateTime(t.year, t.month, t.day);

/// true = baris ini masih perlu disiapkan sampai [batasEksklusif].
///
/// Syaratnya: `aktif`, belum ditandai `sudahTerjadi`, dan tanggalnya
/// **lebih awal** dari batas (batas tidak ikut dihitung).
bool perluDisiapkan(PengeluaranTerencanaData baris, DateTime batasEksklusif) =>
    baris.aktif &&
    !baris.sudahTerjadi &&
    tanggalSaja(baris.tanggal).isBefore(tanggalSaja(batasEksklusif));

/// Total uang yang harus disiapkan sampai [batasEksklusif] (fungsi murni).
int hitungTotalPersiapanSen(
  Iterable<PengeluaranTerencanaData> daftar,
  DateTime batasEksklusif,
) {
  var total = 0;
  for (final b in daftar) {
    if (perluDisiapkan(b, batasEksklusif)) total += b.jumlahSen;
  }
  return total;
}

/// Ringkasan persiapan sampai satu tanggal.
class RingkasanPersiapan {
  const RingkasanPersiapan({
    required this.batasEksklusif,
    required this.totalSen,
    required this.jumlahBaris,
    required this.jumlahTerlewat,
  });

  /// Pukul 00:00 hari setelah tanggal yang dipilih (batas atas eksklusif).
  final DateTime batasEksklusif;

  final int totalSen;
  final int jumlahBaris;

  /// Jumlah baris yang tanggalnya sudah lewat hari ini tetapi belum ditandai
  /// terjadi. Uangnya tetap perlu disiapkan, jadi ikut dihitung di [totalSen].
  final int jumlahTerlewat;

  bool get kosong => jumlahBaris == 0;
}

/// Penyimpanan pengeluaran terencana + ringkasan persiapan.
class PengeluaranTerencanaRepository {
  PengeluaranTerencanaRepository(this.db, {DateTime Function()? jamSekarang})
      : jam = jamSekarang ?? waktuSekarang;

  final AppDatabase db;

  /// Sumber waktu (bisa dikunci uji).
  final DateTime Function() jam;

  // -------------------------------------------------------------------------
  // Baca
  // -------------------------------------------------------------------------

  /// Semua baris urut tanggal menaik; tanggal sama urut nama.
  ///
  /// Urutan kedua memakai `id` agar urutan tidak berubah setiap dibaca.
  Future<List<PengeluaranTerencanaData>> ambilSemua() => (db
          .select(db.pengeluaranTerencana)
        ..orderBy([
          (p) => OrderingTerm.asc(p.tanggal),
          (p) => OrderingTerm.asc(p.id),
        ]))
      .get();

  Stream<List<PengeluaranTerencanaData>> watchSemua() => (db
          .select(db.pengeluaranTerencana)
        ..orderBy([
          (p) => OrderingTerm.asc(p.tanggal),
          (p) => OrderingTerm.asc(p.id),
        ]))
      .watch();

  Future<PengeluaranTerencanaData?> ambilSatu(int id) =>
      (db.select(db.pengeluaranTerencana)..where((p) => p.id.equals(id)))
          .getSingleOrNull();

  /// Ringkasan "total yang harus disiapkan sampai [tanggal]" (batas inklusif
  /// pada hari yang dipilih).
  Future<RingkasanPersiapan> ringkasanSampai(DateTime tanggal) async {
    final batas = tanggalSaja(tanggal).add(const Duration(days: 1));
    final semua = await ambilSemua();
    return ringkasanDari(semua, batas);
  }

  /// Hitung ringkasan dari daftar yang sudah ada (fungsi murni terhadap daftar).
  RingkasanPersiapan ringkasanDari(
    List<PengeluaranTerencanaData> semua,
    DateTime batasEksklusif,
  ) {
    final hariIni = tanggalSaja(jam());
    var total = 0;
    var baris = 0;
    var terlewat = 0;
    for (final b in semua) {
      if (!perluDisiapkan(b, batasEksklusif)) continue;
      total += b.jumlahSen;
      baris += 1;
      if (tanggalSaja(b.tanggal).isBefore(hariIni)) terlewat += 1;
    }
    return RingkasanPersiapan(
      batasEksklusif: batasEksklusif,
      totalSen: total,
      jumlahBaris: baris,
      jumlahTerlewat: terlewat,
    );
  }

  // -------------------------------------------------------------------------
  // Tulis
  // -------------------------------------------------------------------------

  /// Tambah satu pengeluaran terencana.
  ///
  /// [aktif] = false menyembunyikannya dari ringkasan tanpa menghapus barisnya.
  Future<PengeluaranTerencanaData> tambah({
    required String nama,
    required int jumlahSen,
    required DateTime tanggal,
    int? kategoriId,
    String? catatan,
    bool aktif = true,
  }) async {
    final bersih = nama.trim();
    if (bersih.isEmpty) {
      throw ArgumentError('Nama pengeluaran perlu diisi.');
    }
    if (jumlahSen <= 0) {
      throw ArgumentError('Jumlah pengeluaran perlu lebih dari nol.');
    }
    return db.into(db.pengeluaranTerencana).insertReturning(
          PengeluaranTerencanaCompanion.insert(
            nama: bersih,
            jumlahSen: jumlahSen,
            tanggal: tanggalSaja(tanggal),
            kategoriId: Value(kategoriId),
            catatan: Value(catatan),
            aktif: Value(aktif),
            dibuatPada: Value(jam()),
          ),
        );
  }

  /// Ubah sebagian kolom. Argumen null berarti "biarkan seperti semula"
  /// (pola `Value.absent` yang sama dengan repositori lain di repo ini).
  Future<int> ubah(
    int id, {
    String? nama,
    int? jumlahSen,
    DateTime? tanggal,
    int? kategoriId,
    String? catatan,
    bool? aktif,
    bool? sudahTerjadi,
  }) {
    if (nama != null && nama.trim().isEmpty) {
      throw ArgumentError('Nama pengeluaran perlu diisi.');
    }
    if (jumlahSen != null && jumlahSen <= 0) {
      throw ArgumentError('Jumlah pengeluaran perlu lebih dari nol.');
    }
    return (db.update(db.pengeluaranTerencana)..where((p) => p.id.equals(id)))
        .write(PengeluaranTerencanaCompanion(
      nama: nama == null ? const Value.absent() : Value(nama.trim()),
      jumlahSen: jumlahSen == null ? const Value.absent() : Value(jumlahSen),
      tanggal: tanggal == null ? const Value.absent() : Value(tanggalSaja(tanggal)),
      kategoriId: kategoriId == null ? const Value.absent() : Value(kategoriId),
      catatan: catatan == null ? const Value.absent() : Value(catatan),
      aktif: aktif == null ? const Value.absent() : Value(aktif),
      sudahTerjadi:
          sudahTerjadi == null ? const Value.absent() : Value(sudahTerjadi),
    ));
  }

  /// Tandai sudah terjadi (atau kembalikan ke rencana).
  Future<int> tandaiSudahTerjadi(int id, {bool sudahTerjadi = true}) =>
      ubah(id, sudahTerjadi: sudahTerjadi);

  /// Sembunyikan / tampilkan lagi dari ringkasan.
  Future<int> setAktif(int id, {required bool aktif}) => ubah(id, aktif: aktif);

  /// Hapus satu baris pengeluaran terencana. Tidak ada baris lain yang
  /// bergantung padanya, jadi cukup satu baris.
  Future<int> hapus(int id) =>
      (db.delete(db.pengeluaranTerencana)..where((p) => p.id.equals(id))).go();
}
