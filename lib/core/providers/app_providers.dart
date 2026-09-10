/// Provider global: database, repositori, pemasukan bulanan, statistik dasbor.
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../data/repository/pengaturan_repository.dart';
import '../../data/repository/tagihan_repository.dart';

/// Satu instance database untuk seluruh aplikasi.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final tagihanRepoProvider =
    Provider<TagihanRepository>((ref) => TagihanRepository(ref.watch(databaseProvider)));

final pengaturanRepoProvider = Provider<PengaturanRepository>(
    (ref) => PengaturanRepository(ref.watch(databaseProvider)));

/// Daftar tagihan aktif (stream).
final tagihanAktifProvider = StreamProvider.autoDispose<List<TagihanData>>(
    (ref) => ref.watch(tagihanRepoProvider).watchAktif());

/// Semua tagihan termasuk nonaktif.
final semuaTagihanProvider = StreamProvider.autoDispose<List<TagihanData>>(
    (ref) => ref.watch(tagihanRepoProvider).watchSemua());

/// Kategori (stream).
final kategoriProvider = StreamProvider.autoDispose<List<KategoriData>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.kategori)..orderBy([(k) => OrderingTerm.asc(k.urutan)]))
      .watch();
});

/// Pemasukan bulan berjalan. Format kunci: "YYYY-MM".
String kunciBulan(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}';

final pemasukanBulanIniProvider =
    StreamProvider.autoDispose<int>((ref) {
  final db = ref.watch(databaseProvider);
  final bulan = kunciBulan(DateTime.now());
  return (db.select(db.pemasukanBulanan)
        ..where((p) => p.bulan.equals(bulan)))
      .watch()
      .map((rows) => rows.isEmpty ? 0 : rows.first.jumlahSen);
});
