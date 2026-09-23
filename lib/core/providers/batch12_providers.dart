/// Provider batch 12 (FR-39/43/56/58).
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../data/repository/rumah_tangga_repository.dart';
import '../../data/repository/sub_akses_repository.dart';
import 'app_providers.dart';

final repoRumahTanggaProvider = Provider<RumahTanggaRepository>(
    (ref) => RumahTanggaRepository(ref.watch(databaseProvider)));

final repoSubAksesProvider = Provider<SubAksesRepository>(
    (ref) => SubAksesRepository(ref.watch(databaseProvider)));


/// Daftar anggota keluarga (FR-56) sebagai sumber nama anggota rumah tangga.
///
/// Dipisah sebagai provider supaya layar tidak menyentuh tabel langsung dan
/// bisa diganti saat diuji.
final sumberNamaAnggotaKeluargaProvider =
    Provider<Future<List<AnggotaKeluargaData>> Function()>((ref) {
  final db = ref.watch(databaseProvider);
  return () => (db.select(db.anggotaKeluarga)
        ..where((t) => t.arsip.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.nama)]))
      .get();
});
