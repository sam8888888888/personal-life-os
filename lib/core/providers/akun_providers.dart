/// Provider akun (klien API, penyimpanan sesi, status masuk).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/akun_repository.dart';
import '../../data/repository/tagihan_repository.dart';
import '../sinkron/sinkron_tagihan.dart';
import '../akun/klien_akun.dart';
import 'app_providers.dart';

/// Klien API — pengiriman bisa diganti saat uji (tanpa jaringan).
final klienAkunProvider = Provider<KlienAkun>((ref) => KlienAkun());

final akunRepoProvider = Provider<AkunRepository>(
    (ref) => AkunRepository(ref.watch(pengaturanRepoProvider)));

/// Sesi akun yang tersimpan di perangkat (null = belum masuk).
final sesiAkunProvider =
    FutureProvider<AkunSesi?>((ref) => ref.watch(akunRepoProvider).sesiTersimpan());

/// Mesin sinkron tagihan (tahap 2). Satu instance per pemakaian.
final sinkronTagihanProvider = Provider<SinkronTagihan>(
  (ref) => SinkronTagihan(
    db: ref.watch(databaseProvider),
    tagihan: ref.watch(tagihanRepoProvider),
    pengaturan: ref.watch(pengaturanRepoProvider),
    klien: ref.watch(klienAkunProvider),
  ),
);
