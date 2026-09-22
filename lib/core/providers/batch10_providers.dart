/// Provider batch 10 (FR-98/133/134/135/152).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/jurnal_perjalanan_repository.dart';
import '../../data/repository/kurs_repository.dart';
import '../../data/repository/masjid_repository.dart';
import '../../data/repository/perjalanan_repository.dart';
import '../../data/repository/tanggung_jawab_repository.dart';
import 'app_providers.dart';

final repoPerjalananProvider = Provider<PerjalananRepository>(
    (ref) => PerjalananRepository(ref.watch(databaseProvider)));

final repoJurnalPerjalananProvider = Provider<JurnalPerjalananRepository>(
    (ref) => JurnalPerjalananRepository(ref.watch(databaseProvider)));

final repoTanggungJawabProvider = Provider<TanggungJawabRepository>(
    (ref) => TanggungJawabRepository(ref.watch(databaseProvider)));

final repoMasjidProvider = Provider<MasjidRepository>(
    (ref) => MasjidRepository(ref.watch(databaseProvider)));

final repoKursProvider =
    Provider<KursRepository>((ref) => KursRepository(ref.watch(databaseProvider)));
