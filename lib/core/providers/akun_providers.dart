/// Provider akun (klien API, penyimpanan sesi, status masuk).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/akun_repository.dart';
import '../platform/brankas_rahasia.dart';
import '../sinkron/sinkron_semua.dart';
import '../sinkron/kunci_sinkron.dart';
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

/// Mesin sinkron SEMUA MODUL (FR-150). Dipakai tombol "Sinkron sekarang".
final sinkronSemuaProvider = Provider<SinkronSemua>(
  (ref) => SinkronSemua(
    db: ref.watch(databaseProvider),
    klien: ref.watch(klienAkunProvider),
    pengaturan: ref.watch(pengaturanRepoProvider),
  ),
);

/// S-13 — pengelola kunci data sinkron (data disandikan sebelum naik ke server).
final kunciSinkronProvider = Provider<KunciSinkron>(
  (ref) => KunciSinkron(PenyimpanRahasia(ref.watch(pengaturanRepoProvider))),
);

/// Nama untuk sapaan: isian Pengaturan → nama akun → 'Anda'.
final namaPanggilanProvider = FutureProvider<String>((ref) async {
  final sesi = await ref.watch(sesiAkunProvider.future);
  return ref
      .watch(namaPenggunaProvider)
      .baca(namaAkun: sesi?.nama);
});
