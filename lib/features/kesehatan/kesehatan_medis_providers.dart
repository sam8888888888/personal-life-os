/// Provider modul kesehatan lanjutan (FR-108, FR-114, FR-115, FR-117).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../data/repository/kesehatan_pemantau_repository.dart';
import '../../data/repository/lampiran_repository.dart';
import '../../data/repository/medis_repository.dart';

final repoMedisProvider = Provider<MedisRepository>(
    (ref) => MedisRepository(ref.watch(databaseProvider)));

final repoPemantauProvider = Provider<KesehatanPemantauRepository>(
    (ref) => KesehatanPemantauRepository(ref.watch(databaseProvider)));

final repoLampiranProvider = Provider<LampiranRepository>(
    (ref) => LampiranRepository(ref.watch(databaseProvider)));

/// Induk lampiran catatan medis (dipakai bersama layar & uji).
const String indukTabelCatatanMedis = 'catatan_medis';
