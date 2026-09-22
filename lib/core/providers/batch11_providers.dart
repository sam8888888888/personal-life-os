/// Provider batch 11 (FR-47/48/54/55/149).
///
/// FR-54 tidak punya provider sendiri: modul obat memakai `obatRepoProvider`
/// (FR-106) — lihat `lib/features/kesehatan/provider_kesehatan.dart`.
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../data/repository/copilot_repository.dart';
import '../../data/repository/dana_persiapan_repository.dart';
import '../../data/repository/delegasi_repository.dart';
import '../../data/repository/patungan_repository.dart';
import 'app_providers.dart';

final repoDanaPersiapanProvider = Provider<DanaPersiapanRepository>(
    (ref) => DanaPersiapanRepository(ref.watch(databaseProvider)));

final repoPatunganProvider = Provider<PatunganRepository>(
    (ref) => PatunganRepository(ref.watch(databaseProvider)));

final repoDelegasiProvider = Provider<DelegasiRepository>(
    (ref) => DelegasiRepository(ref.watch(databaseProvider)));

final repoCopilotProvider = Provider<CopilotRepository>(
    (ref) => CopilotRepository(ref.watch(databaseProvider)));

/// Sumber pilihan untuk delegasi: tagihan yang belum lunas & masih aktif.
///
/// Dipisah sebagai provider supaya bisa diganti di uji, dan supaya layar
/// tidak menyentuh tabel tagihan secara langsung.
final repoDelegasiSumberTagihanProvider =
    Provider<Future<List<TagihanData>> Function()>((ref) {
  final db = ref.watch(databaseProvider);
  return () => (db.select(db.tagihan)
        ..where((t) => t.lunas.equals(false) & t.statusAktif.equals(true))
        ..orderBy([(t) => OrderingTerm.asc(t.jatuhTempo)])
        ..limit(20))
      .get();
});
