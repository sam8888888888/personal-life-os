/// Provider khusus modul kesehatan (FR-101/102/103/106/111).
///
/// Sengaja ditaruh di folder fitur ini — bukan di `lib/core/providers/` —
/// supaya berkas bersama tidak perlu disentuh saat modul kesehatan bertambah.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../data/repository/kesehatan_repository.dart';
import '../../data/repository/obat_repository.dart';

/// Penyimpanan & hitungan kesehatan (ukuran tubuh, aktivitas, tidur, air).
final kesehatanRepoProvider = Provider<KesehatanRepository>(
  (ref) => KesehatanRepository(ref.watch(databaseProvider)),
);

/// Penyimpanan obat, jadwal minum & catatan minum.
final obatRepoProvider = Provider<ObatRepository>(
  (ref) => ObatRepository(ref.watch(databaseProvider)),
);
