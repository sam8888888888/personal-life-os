/// Repositori pengaturan: pemasukan bulanan, contoh data, hapus data.
library;

import 'package:drift/drift.dart';

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

  /// Isi contoh data untuk demo/uji: 7 template + pemasukan bulan ini.
  Future<int> isiContohData({DateTime? acuan}) async {
    final tgl = acuan ?? DateTime.now();
    final n = await db.isiDariTemplate(daftarTemplate, tanggalAwal: tgl);
    await simpanPemasukan(DateTime(tgl.year, tgl.month), 1200000000); // Rp 12.000.000
    return n;
  }

  /// Hapus seluruh data (dipakai untuk pengaturan ulang / uji).
  Future<void> hapusSemuaData() async {
    await db.transaction(() async {
      await db.delete(db.riwayatPembayaran).go();
      await db.delete(db.tagihan).go();
      await db.delete(db.pemasukanBulanan).go();
    });
  }
}
