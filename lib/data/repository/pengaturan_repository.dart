/// Repositori pengaturan: pemasukan bulanan, contoh data, hapus data.
library;

import 'package:drift/drift.dart';

import '../../core/notifikasi/jejak.dart';
import '../../core/notifikasi/layanan_notifikasi.dart';
import '../database/database.dart';
import 'template_tagihan.dart';

class PengaturanRepository {
  PengaturanRepository(this.db);
  final AppDatabase db;

  Stream<List<PemasukanBulananData>> watchPemasukan(DateTime bulan) {
    final kunci = '${bulan.year}-${bulan.month.toString().padLeft(2, '0')}';
    return (db.select(db.pemasukanBulanan)..where((p) => p.bulan.equals(kunci)))
        .watch();
  }

  /// Simpan/ubah pemasukan bulan (upsert sederhana).
  Future<void> simpanPemasukan(DateTime bulan, int jumlahSen,
      {String sumber = 'Gaji'}) async {
    final kunci = '${bulan.year}-${bulan.month.toString().padLeft(2, '0')}';
    // PB-07: upsert atomic — satu bulan = satu baris, aman dari dua proses
    // yang menyimpan bersamaan (indeks unik `bulan` menjaminnya di database).
    await db.into(db.pemasukanBulanan).insert(
          PemasukanBulananCompanion.insert(
            bulan: kunci,
            jumlahSen: Value(jumlahSen),
            sumber: Value(sumber),
          ),
          onConflict: DoUpdate(
            (_) => PemasukanBulananCompanion(
              jumlahSen: Value(jumlahSen),
              sumber: Value(sumber),
            ),
            target: [db.pemasukanBulanan.bulan],
          ),
        );
  }

  /// Baca satu nilai pengaturan (null = belum pernah diisi).
  ///
  /// Dipakai saklar & pilihan pengguna yang tidak butuh tabel sendiri, mis.
  /// "briefing pagi aktif" (FR-63) dan mode pengingat per waktu sholat (FR-87).
  Future<String?> baca(String kunci) async {
    final baris = await (db.select(db.pengaturan)
          ..where((p) => p.kunci.equals(kunci)))
        .getSingleOrNull();
    return baris?.nilai;
  }

  /// Simpan (upsert) satu nilai pengaturan.
  Future<void> simpan(String kunci, String nilai) async {
    await db.into(db.pengaturan).insert(
          PengaturanCompanion.insert(kunci: kunci, nilai: nilai),
          onConflict: DoUpdate(
            (_) => PengaturanCompanion(nilai: Value(nilai)),
            target: [db.pengaturan.kunci],
          ),
        );
  }

  /// Hapus satu pengaturan (kembali ke nilai bawaan aplikasi).
  Future<void> hapusPengaturan(String kunci) async {
    await (db.delete(db.pengaturan)..where((p) => p.kunci.equals(kunci))).go();
  }

  /// Baca teks dengan nilai bawaan bila kosong/tidak ada.
  Future<String> bacaTeks(String kunci, String bawaan) async {
    final teks = (await baca(kunci))?.trim() ?? '';
    return teks.isEmpty ? bawaan : teks;
  }

  /// Baca angka dengan nilai bawaan bila kosong/tidak sah.
  Future<int> bacaAngka(String kunci, int bawaan) async =>
      int.tryParse((await baca(kunci))?.trim() ?? '') ?? bawaan;

  /// Baca saklar: "true"/"1"/"ya" = aktif; kosong = [bawaan]; selain itu mati.
  Future<bool> bacaSaklar(String kunci, {bool bawaan = false}) async {
    final teks = (await baca(kunci))?.trim().toLowerCase() ?? '';
    if (teks.isEmpty) return bawaan;
    return teks == 'true' || teks == '1' || teks == 'ya';
  }

  /// Isi contoh data untuk demo/uji: 7 template + pemasukan bulan ini.
  Future<int> isiContohData({DateTime? acuan}) async {
    final tgl = acuan ?? DateTime.now();
    final n = await db.isiDariTemplate(daftarTemplate, tanggalAwal: tgl);
    await simpanPemasukan(DateTime(tgl.year, tgl.month), 1200000000); // Rp 12.000.000
    return n;
  }

  /// Hapus seluruh data (dipakai untuk pengaturan ulang / uji).
  ///
  /// PB-11: sekaligus membatalkan notifikasi yang masih terjadwal. Tanpa ini ada
  /// jendela waktu di mana data sudah kosong tetapi pengingat lama masih hidup
  /// (mis. aplikasi ditutup tepat setelah penghapusan).
  ///
  /// Skema v3: tabel kas & kekayaan ikut dikosongkan supaya "hapus semua data"
  /// benar-benar bersih (tidak menyisakan transaksi/aset/laporan lama).
  /// Kategori bawaan (`bawaanSistem = true`) tetap disisakan — sama seperti
  /// kategori tagihan bawaan yang tidak pernah dihapus.
  Future<void> hapusSemuaData({LayananNotifikasi? layanan}) async {
    await db.transaction(() async {
      await db.delete(db.riwayatPembayaran).go();
      await db.delete(db.tagihan).go();
      await db.delete(db.pemasukanBulanan).go();
      // Skema v3 — urutan: riwayat nilai dulu, baru induknya.
      await db.delete(db.nilaiAsetBulanan).go();
      await db.delete(db.nilaiKewajibanBulanan).go();
      await db.delete(db.transaksi).go();
      await db.delete(db.anggaranBulanan).go();
      await db.delete(db.langganan).go();
      await db.delete(db.aset).go();
      await db.delete(db.kewajiban).go();
      await (db.delete(db.kategoriTransaksi)
            ..where((k) => k.bawaanSistem.equals(false)))
          .go();
    });
    try {
      await layanan?.batalkanSemua();
    } catch (e) {
      await catatJejak({'jenis': 'hapus_data', 'galat': 'batalkan notifikasi: $e'});
    }
  }
}
