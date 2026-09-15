/// Repositori transaksi kas (FR-71) — sumber tunggal arus kas.
///
/// Idempotensi (pelajaran PB-05/PB-06/PB-07): setiap baris punya
/// `idTransaksi` stabil, dan penulisan selalu lewat UPSERT pada kolom itu.
/// Impor ulang berkas cadangan karena itu **tidak menggandakan** baris.
library;

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../model/enums.dart';
import 'periode.dart';

class TransaksiRepository {
  TransaksiRepository(this.db);

  final AppDatabase db;

  /// Simpan/ubah satu transaksi secara idempoten (kunci: `idTransaksi`).
  ///
  /// UPSERT diarahkan ke indeks unik `transaksi(id_transaksi)` yang dipasang
  /// di `database.dart` — jadi baris dengan kunci sama akan diperbarui, bukan
  /// digandakan.
  Future<TransaksiData> simpan(TransaksiCompanion c) async {
    final kunci = c.idTransaksi.present ? c.idTransaksi.value.trim() : '';
    if (kunci.isEmpty) {
      throw ArgumentError('idTransaksi wajib diisi (kunci idempotensi).');
    }
    if (c.jumlahSen.present && c.jumlahSen.value < 0) {
      throw ArgumentError(
          'jumlahSen harus positif — arah arus ditentukan oleh kolom jenis.');
    }
    final isi = c.copyWith(diubahPada: Value(DateTime.now()));
    await db.into(db.transaksi).insert(
          isi,
          onConflict: DoUpdate((_) => isi, target: [db.transaksi.idTransaksi]),
        );
    return (db.select(db.transaksi)
          ..where((t) => t.idTransaksi.equals(kunci)))
        .getSingle();
  }

  /// Transaksi satu bulan, urut tanggal lalu id.
  Stream<List<TransaksiData>> watchBulan(DateTime bulan) {
    final r = rentangBulan(bulan);
    return (db.select(db.transaksi)
          ..where((t) =>
              t.tanggal.isBiggerOrEqualValue(r.awal) &
              // Batas atas EKSKLUSIF: awal bulan berikutnya. Memakai tengah
              // malam hari terakhir akan membuang transaksi hari itu.
              t.tanggal.isSmallerThanValue(r.akhirEksklusif))
          ..orderBy([
            (t) => OrderingTerm.asc(t.tanggal),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  Future<List<TransaksiData>> ambilBulan(DateTime bulan) {
    final r = rentangBulan(bulan);
    return (db.select(db.transaksi)
          ..where((t) =>
              t.tanggal.isBiggerOrEqualValue(r.awal) &
              // Batas atas EKSKLUSIF (lihat `rentangBulan`).
              t.tanggal.isSmallerThanValue(r.akhirEksklusif))
          ..orderBy([
            (t) => OrderingTerm.asc(t.tanggal),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  Future<TransaksiData?> ambilSatu(int id) =>
      (db.select(db.transaksi)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> hapus(int id) =>
      (db.delete(db.transaksi)..where((t) => t.id.equals(id))).go();

  /// Ringkasan bulan: pemasukan, pengeluaran, arus kas bersih (kriteria FR-71).
  Future<RingkasanArusKas> ringkasanBulan(DateTime bulan) async {
    final baris = await ambilBulan(bulan);
    var masuk = 0;
    var keluar = 0;
    for (final t in baris) {
      if (JenisArus.dariDb(t.jenis) == JenisArus.pemasukan) {
        masuk += t.jumlahSen;
      } else {
        keluar += t.jumlahSen;
      }
    }
    return RingkasanArusKas(pemasukanSen: masuk, pengeluaranSen: keluar);
  }

  /// Total per kategori untuk satu bulan (bahan realisasi anggaran FR-72).
  Future<List<TotalKategori>> totalPerKategori(
    DateTime bulan, {
    JenisArus jenis = JenisArus.pengeluaran,
  }) async {
    final baris = await ambilBulan(bulan);
    final peta = <int?, int>{};
    for (final t in baris) {
      if (JenisArus.dariDb(t.jenis) != jenis) continue;
      peta.update(t.kategoriId, (v) => v + t.jumlahSen, ifAbsent: () => t.jumlahSen);
    }
    final hasil = [
      for (final e in peta.entries)
        TotalKategori(kategoriId: e.key, totalSen: e.value),
    ]..sort((a, b) => b.totalSen.compareTo(a.totalSen));
    return hasil;
  }
}

/// Angka ringkas arus kas satu bulan (selalu dalam sen).
class RingkasanArusKas {
  const RingkasanArusKas({
    required this.pemasukanSen,
    required this.pengeluaranSen,
  });

  final int pemasukanSen;
  final int pengeluaranSen;

  /// Arus kas bersih: pemasukan − pengeluaran (boleh negatif).
  int get bersihSen => pemasukanSen - pengeluaranSen;
}

/// Total satu kategori pada satu bulan (kategoriId null = tanpa kategori).
class TotalKategori {
  const TotalKategori({required this.kategoriId, required this.totalSen});

  final int? kategoriId;
  final int totalSen;
}
