/// Provider modul Rumah & Aset (FR-124…FR-127).
///
/// Ditaruh di folder fitur ini — bukan di `lib/core/providers/app_providers.dart`
/// — supaya berkas bersama itu tidak perlu disentuh.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/repository/rumah_repository.dart';

/// Repositori aset fisik, garansi, dan perawatan aset.
final repoRumahProvider = Provider<RumahRepository>(
    (ref) => RumahRepository(ref.watch(databaseProvider)));

/// Aset yang garansinya berakhir ≤ 30 hari (FR-126) — untuk Perhatian Today.
final garansiDekatProvider = FutureProvider<List<AsetData>>(
    (ref) => ref.watch(repoRumahProvider).garansiDekat(waktuSekarang()));

/// Jadwal perawatan yang jatuh tempo ≤ 14 hari (FR-125).
final perawatanDekatProvider = FutureProvider<List<PerawatanData>>((ref) =>
    ref.watch(repoRumahProvider).perawatanJatuhTempo(waktuSekarang(),
        hariKeDepan: 14));
