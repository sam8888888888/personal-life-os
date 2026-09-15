/// Provider modul Aksi & Tujuan (FR-78/79).
///
/// Sengaja diletakkan di berkas fitur ini (bukan di
/// `lib/core/providers/app_providers.dart`) supaya berkas bersama itu tidak
/// perlu disentuh oleh modul ini.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../data/repository/aksi_repository.dart';

/// Repositori rantai tujuan -> proyek -> tugas.
final repoAksiProvider = Provider<AksiRepository>(
    (ref) => AksiRepository(ref.watch(databaseProvider)));
