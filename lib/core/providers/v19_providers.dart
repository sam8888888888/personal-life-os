/// Provider "jaringan ikat" v19 (SDD v19 Gelombang 1): kotak masuk, catatan
/// harian, tautan, sorotan.
///
/// Dipisah sebagai provider supaya layar tidak menyentuh tabel langsung dan
/// bisa diganti saat diuji.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../data/repository/catatan_harian_repository.dart';
import '../../data/repository/kotak_masuk_repository.dart';
import '../../data/repository/sorotan_repository.dart';
import '../../data/repository/tautan_repository.dart';
import 'app_providers.dart';

final repoKotakMasukProvider = Provider<KotakMasukRepository>(
    (ref) => KotakMasukRepository(ref.watch(databaseProvider)));

final repoCatatanHarianProvider = Provider<CatatanHarianRepository>(
    (ref) => CatatanHarianRepository(ref.watch(databaseProvider)));

final repoTautanProvider = Provider<TautanRepository>(
    (ref) => TautanRepository(ref.watch(databaseProvider)));

final repoSorotanProvider = Provider<SorotanRepository>(
    (ref) => SorotanRepository(ref.watch(databaseProvider)));

/// Jumlah tangkapan yang belum disortir — dipakai lencana di menu.
final jumlahKotakMasukProvider = FutureProvider<int>(
    (ref) => ref.watch(repoKotakMasukProvider).jumlahBaru());

/// Antrean kotak masuk (belum disortir), terbaru dulu.
final antreanKotakMasukProvider =
    FutureProvider<List<KotakMasukData>>((ref) async {
  return ref.watch(repoKotakMasukProvider).antrean();
});
