/// Provider modul Pengetahuan (FR-118…FR-123) & catatan makan/suasana hati
/// (FR-110/FR-112).
///
/// Ditaruh di folder fitur (bukan `lib/core/providers/`) mengikuti aturan
/// proyek: berkas bersama tidak perlu disentuh saat modul bertambah.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../data/repository/kesehatan_ringkas_repository.dart';
import '../../data/repository/pengetahuan_repository.dart';

/// Penyimpanan modul pengetahuan (catatan, keputusan, pembelajaran, kartu
/// ulangan, bacaan, tautan).
final pengetahuanRepoProvider = Provider<PengetahuanRepository>(
  (ref) => PengetahuanRepository(ref.watch(databaseProvider)),
);

/// Penyimpanan catatan makan & suasana hati.
final kesehatanRingkasRepoProvider = Provider<KesehatanRingkasRepository>(
  (ref) => KesehatanRingkasRepository(ref.watch(databaseProvider)),
);
