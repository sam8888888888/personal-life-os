/// Provider batch 9 (FR-84/97/142/143/146).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/energi_repository.dart';
import '../../data/repository/pintar_repository.dart';
import '../../data/repository/rencana_ibadah_repository.dart';
import 'app_providers.dart';

final repoPintarProvider = Provider<PintarRepository>(
    (ref) => PintarRepository(ref.watch(databaseProvider)));

final repoEnergiProvider = Provider<EnergiRepository>(
    (ref) => EnergiRepository(ref.watch(databaseProvider)));

final repoRencanaIbadahProvider = Provider<RencanaIbadahRepository>(
    (ref) => RencanaIbadahRepository(ref.watch(databaseProvider)));
