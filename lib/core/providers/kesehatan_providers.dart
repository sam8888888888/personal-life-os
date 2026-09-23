/// Provider kesehatan (SDD v19 Gelombang 2): hasil lab, gejala, imunisasi,
/// tumbuh kembang.
///
/// Dipisah dari layar supaya layar tidak menyentuh tabel langsung, dan supaya
/// uji bisa mengganti sumber datanya lewat `ProviderScope.overrides`.
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../data/repository/gejala_repository.dart';
import '../../data/repository/hasil_lab_repository.dart';
import '../../data/repository/imunisasi_repository.dart';
import '../../data/repository/tumbuh_kembang_repository.dart';
import 'app_providers.dart';

final repoHasilLabProvider = Provider<HasilLabRepository>(
  (ref) => HasilLabRepository(ref.watch(databaseProvider)),
);

final repoGejalaProvider = Provider<GejalaRepository>(
  (ref) => GejalaRepository(ref.watch(databaseProvider)),
);

final repoImunisasiProvider = Provider<ImunisasiRepository>(
  (ref) => ImunisasiRepository(ref.watch(databaseProvider)),
);

final repoTumbuhKembangProvider = Provider<TumbuhKembangRepository>(
  (ref) => TumbuhKembangRepository(ref.watch(databaseProvider)),
);

/// Anggota keluarga yang belum diarsipkan — dipakai pemilih di layar kesehatan.
final daftarAnggotaProvider = FutureProvider<List<AnggotaKeluargaData>>(
  (ref) async {
    final AppDatabase db = ref.watch(databaseProvider);
    return (db.select(db.anggotaKeluarga)
          ..where((t) => t.arsip.equals(false))
          ..orderBy(<OrderingTerm Function($AnggotaKeluargaTable)>[
            ($AnggotaKeluargaTable t) => OrderingTerm.asc(t.nama),
          ]))
        .get();
  },
);
