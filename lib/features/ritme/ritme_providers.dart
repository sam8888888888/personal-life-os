/// Provider batch 7 — ritme hidup (FR-132/140/141/144/145).
///
/// Catatan: versi riverpod proyek ini tidak menyediakan `StateProvider`, jadi
/// pilihan rentang/tanggal disimpan sebagai keadaan layar (bukan provider).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../data/repository/hidup_repository.dart';
import '../../data/repository/tinjauan_repository.dart';

final repoHidupProvider = Provider<HidupRepository>(
    (ref) => HidupRepository(ref.watch(databaseProvider)));

final repoTinjauanProvider = Provider<TinjauanRepository>(
    (ref) => TinjauanRepository(ref.watch(databaseProvider)));
