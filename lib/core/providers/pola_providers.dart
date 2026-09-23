/// Provider Gelombang 3 (SDD v19): orang & temuan pola.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/orang_repository.dart';
import '../../data/repository/temuan_repository.dart';
import 'app_providers.dart';

final repoOrangProvider = Provider<OrangRepository>(
  (ref) => OrangRepository(ref.watch(databaseProvider)),
);

final repoTemuanProvider = Provider<TemuanRepository>(
  (ref) => TemuanRepository(ref.watch(databaseProvider)),
);
