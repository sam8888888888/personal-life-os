/// Provider modul Dokumen (FR-128/129).
///
/// Ditaruh di folder fitur ini — bukan di `lib/core/providers/app_providers.dart`
/// — supaya berkas bersama itu tidak perlu disentuh modul dokumen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../data/repository/dokumen_repository.dart';

/// Repositori dokumen penting & masa berlakunya.
final repoDokumenProvider = Provider<DokumenRepository>(
    (ref) => DokumenRepository(ref.watch(databaseProvider)));
