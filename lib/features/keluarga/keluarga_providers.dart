/// Provider modul Keluarga (FR-131).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../data/repository/keluarga_repository.dart';

/// Repositori anggota keluarga & tanggung jawab.
final repoKeluargaProvider = Provider<KeluargaRepository>(
    (ref) => KeluargaRepository(ref.watch(databaseProvider)));
