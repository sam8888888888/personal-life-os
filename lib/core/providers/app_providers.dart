/// Provider global: database, repositori, pemasukan bulanan, statistik dasbor.
library;

import '../utils/waktu.dart';
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifikasi/layanan_notifikasi.dart';
import '../notifikasi/layanan_notifikasi_lokal.dart';
import '../notifikasi/model_pengingat.dart';
import '../notifikasi/perencana_pengingat.dart';
import '../notifikasi/penyinkron_pengingat.dart';
import '../../data/database/database.dart';
import '../../data/repository/pengaturan_repository.dart';
import '../../data/repository/tagihan_repository.dart';

/// Satu instance database untuk seluruh aplikasi.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final tagihanRepoProvider =
    Provider<TagihanRepository>((ref) => TagihanRepository(ref.watch(databaseProvider)));

final pengaturanRepoProvider = Provider<PengaturanRepository>(
    (ref) => PengaturanRepository(ref.watch(databaseProvider)));

/// Daftar tagihan aktif (stream).
final tagihanAktifProvider = StreamProvider.autoDispose<List<TagihanData>>(
    (ref) => ref.watch(tagihanRepoProvider).watchAktif());

/// Semua tagihan termasuk nonaktif.
final semuaTagihanProvider = StreamProvider.autoDispose<List<TagihanData>>(
    (ref) => ref.watch(tagihanRepoProvider).watchSemua());

/// Kategori (stream).
final kategoriProvider = StreamProvider.autoDispose<List<KategoriData>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.kategori)..orderBy([(k) => OrderingTerm.asc(k.urutan)]))
      .watch();
});

// ---------------------------------------------------------------------------
// Pengingat (F3)
// ---------------------------------------------------------------------------

/// Layanan notifikasi nyata (plugin Android).
final layananNotifikasiProvider = Provider<LayananNotifikasi>((ref) {
  final l = LayananNotifikasiLokal();
  unawaited(l.siapkan());
  return l;
});

/// Penyinkron jadwal pengingat.
final penyinkronPengingatProvider = Provider<PenyinkronPengingat>(
    (ref) => PenyinkronPengingat(
          repo: ref.watch(tagihanRepoProvider),
          layanan: ref.watch(layananNotifikasiProvider),
        ));

/// Perencana murni (dipakai uji & pratinjau).
final perencanaPengingatProvider =
    Provider<PerencanaPengingat>((ref) => const PerencanaPengingat());

/// Pengingat berikutnya menurut data tagihan saat ini.
final pengingatBerikutnyaProvider =
    FutureProvider.autoDispose<List<Pengingat>>((ref) async {
  final tagihan = await ref.watch(semuaTagihanProvider.future);
  final daftar = ref
      .watch(perencanaPengingatProvider)
      .rencanakan(tagihan: tagihan, sekarang: waktuSekarang());
  return daftar.take(20).toList(growable: false);
});

/// Ringkasan izin & jumlah pengingat (untuk badge di Pengaturan).
final statusIzinPengingatProvider =
    FutureProvider.autoDispose<StatusIzinPengingat>((ref) async {
  final l = ref.watch(layananNotifikasiProvider);
  return l.statusIzin();
});

/// Pemasukan bulan berjalan. Format kunci: "YYYY-MM".
String kunciBulan(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}';

/// PB-08: angka ringkas bulan berjalan = catatan pembayaran + tagihan belum lunas.
/// Ikut dihitung ulang setiap data tagihan berubah (mis. setelah menandai lunas).
final ringkasanBulanProvider =
    FutureProvider.autoDispose<RingkasanBulan>((ref) async {
  ref.watch(tagihanAktifProvider);
  final repo = ref.watch(tagihanRepoProvider);
  return repo.ringkasanBulan(waktuSekarang());
});

/// PB-08: daftar periode satu bulan (dipakai kalender).
final periodeBulanProvider = FutureProvider.autoDispose
    .family<List<BarisPeriode>, ({int tahun, int bulan})>((ref, kunci) async {
  ref.watch(tagihanAktifProvider);
  final repo = ref.watch(tagihanRepoProvider);
  return repo.periodeBulan(DateTime(kunci.tahun, kunci.bulan));
});

final pemasukanBulanIniProvider =
    StreamProvider.autoDispose<int>((ref) {
  final db = ref.watch(databaseProvider);
  final bulan = kunciBulan(waktuSekarang());
  return (db.select(db.pemasukanBulanan)
        ..where((p) => p.bulan.equals(bulan)))
      .watch()
      .map((rows) => rows.isEmpty ? 0 : rows.first.jumlahSen);
});
