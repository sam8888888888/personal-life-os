/// Provider modul uang lanjutan (FR-74 catat pembayaran & jadwal, FR-75
/// strategi pelunasan, plus pengeluaran terencana sebagai fitur tambahan).
///
/// Sengaja ditaruh di folder fitur ini - bukan di `lib/core/providers/` -
/// supaya berkas bersama tidak perlu disentuh saat modul ini bertambah.
library;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../data/database/database.dart';
import '../../../data/repository/pembayaran_kewajiban_repository.dart';
import '../../../data/repository/pengeluaran_terencana_repository.dart';

/// Pencatatan pembayaran kewajiban + sisa utang.
final pembayaranKewajibanRepoProvider = Provider<PembayaranKewajibanRepository>(
  (ref) => PembayaranKewajibanRepository(ref.watch(databaseProvider)),
);

/// Pengeluaran terencana (uang yang disiapkan sebelum tanggal tertentu).
final pengeluaranTerencanaRepoProvider =
    Provider<PengeluaranTerencanaRepository>(
  (ref) => PengeluaranTerencanaRepository(ref.watch(databaseProvider)),
);

/// Kategori arus kas untuk formulir pengeluaran terencana.
final kategoriTransaksiUangLanjutanProvider =
    StreamProvider.autoDispose<List<KategoriTransaksiData>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.kategoriTransaksi)
        ..orderBy([
          (k) => OrderingTerm.asc(k.urutan),
          (k) => OrderingTerm.asc(k.nama),
        ]))
      .watch();
});
