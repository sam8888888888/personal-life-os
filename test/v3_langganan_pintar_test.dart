/// Uji FR-69 & FR-70 — "langganan pintar": analitik + deteksi.
///
/// Dua lapis:
///  1. mesin angka PURE (`analitik_langganan.dart`, `deteksi_langganan.dart`);
///  2. layar Langganan (kartu analitik + panel perhatian) pada 420x900.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/core/utils/uang_utils.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/model/enums.dart';
import 'package:personal_life_os/data/repository/langganan_repository.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/uang/langganan/analitik_langganan.dart';
import 'package:personal_life_os/features/uang/langganan/deteksi_langganan.dart';
import 'package:personal_life_os/features/uang/langganan/langganan_screen.dart';

late AppDatabase db;
late LanggananRepository repo;
late TagihanRepository repoT;

/// Waktu uji dikunci: 15 September 2026, 09.00.
final jamUji = DateTime(2026, 9, 15, 9);

Future<TagihanData> tagihanBaru(String nama, {int jumlahSen = 18600000}) =>
    repoT.tambah(TagihanCompanion.insert(
      nama: nama,
      jumlahSen: Value(jumlahSen),
      jatuhTempo: DateTime(2026, 9, 20),
    ));

Future<LanggananData> tambahL({
  required String nama,
  required int nominalSen,
  Frekuensi siklus = Frekuensi.bulanan,
  DateTime? mulai,
  int? tagihanId,
  StatusLangganan status = StatusLangganan.aktif,
}) =>
    repo.tambah(
      nama: nama,
      nominalSen: nominalSen,
      tanggalMulai: mulai ?? DateTime(2026, 1, 20),
      siklus: siklus,
      tagihanId: tagihanId,
      status: status,
    );

Future<LanggananData> bacaL(int id) async => (await repo.ambilSatu(id))!;

Future<List<LanggananData>> semuaBarisL() => db.select(db.langganan).get();

/// Satu pembayaran nyata pada riwayat (bukti terbaru untuk FR-70).
Future<void> bayar(int tagihanId, int jumlahSen, DateTime kapan,
        {DateTime? periode}) =>
    db.into(db.riwayatPembayaran).insert(RiwayatPembayaranCompanion.insert(
          tagihanId: tagihanId,
          periodeJatuhTempo: periode ?? DateTime(2026, 8, 20),
          jumlahSen: jumlahSen,
          tanggalBayar: kapan,
        ));

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = LanggananRepository(db);
    repoT = TagihanRepository(db);
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() async => db.close());

  // ------------------------------------------------------------------
  // FR-69 — analitik
  // ------------------------------------------------------------------

  group('FR-69 analitik langganan', () {
    test('total tahunan = total bulanan x 12', () async {
      await tambahL(nama: 'Bulanan', nominalSen: 5000000);
      await tambahL(
          nama: 'Tahunan', nominalSen: 2400000, siklus: Frekuensi.tahunan);

      final r = hitungRingkasanLangganan(await semuaBarisL(), jamUji);

      // 5.000.000 + (2.400.000 / 12 = 200.000) = 5.200.000 sen.
      expect(r.totalBulananSen, 5200000);
      expect(r.totalTahunanSen, 62400000);
      expect(r.jumlahAktif, 2);
    });

    test('lima terbesar: urut menurun, hanya aktif, maksimal lima', () async {
      for (final n in [1000000, 9000000, 3000000, 7000000, 5000000]) {
        await tambahL(nama: 'L$n', nominalSen: n);
      }
      await tambahL(nama: 'Keenam', nominalSen: 4000000);
      final pause = await tambahL(nama: 'PauseBesar', nominalSen: 99000000);
      await repo.pause(pause.id);

      final r = hitungRingkasanLangganan(await semuaBarisL(), jamUji);

      expect(r.limaTerbesar, hasLength(5));
      expect(r.limaTerbesar.map((e) => e.bulananSen).toList(),
          [9000000, 7000000, 5000000, 4000000, 3000000]);
      expect(r.limaTerbesar.any((e) => e.langganan.nama == 'PauseBesar'), isFalse,
          reason: 'baris pause tidak menagih, jadi tidak masuk peringkat');
    });

    test('proyeksi 12 bulan mengikuti siklus dan mengabaikan yang pause',
        () async {
      await tambahL(
          nama: 'Bulanan', nominalSen: 5000000, mulai: DateTime(2026, 1, 20));
      await tambahL(
          nama: 'Tahunan',
          nominalSen: 1200000,
          siklus: Frekuensi.tahunan,
          mulai: DateTime(2026, 1, 1));
      final pause = await tambahL(nama: 'PauseBesar', nominalSen: 9999999);
      await repo.pause(pause.id, sampai: DateTime(2026, 12, 31));

      final r = hitungRingkasanLangganan(await semuaBarisL(), jamUji);

      expect(r.proyeksi12Bulan, hasLength(12));
      final sep = r.proyeksi12Bulan.first;
      expect(sep.bulan, DateTime(2026, 9, 1));
      // Bulanan jatuh tempo 20 Sep 2026 (>= 15 Sep 2026) = 5.000.000 sen.
      expect(sep.totalSen, 5000000);
      expect(sep.jumlah, 1);
      final jan = r.proyeksi12Bulan
          .firstWhere((b) => b.bulan == DateTime(2027, 1, 1));
      // Januari 2027: bulanan + tahunan (2.400.000 / 12 x 12 = 1.200.000).
      expect(jan.totalSen, 6200000);
      expect(jan.jumlah, 2);
      expect(r.proyeksi12Bulan.last.bulan, DateTime(2027, 8, 1));
    });
  });

  // ------------------------------------------------------------------
  // FR-70 — deteksi
  // ------------------------------------------------------------------

  group('FR-70 deteksi langganan', () {
    test('nama hampir sama + siklus sama dianggap duplikat', () async {
      await tambahL(nama: 'Netflix', nominalSen: 5000000);
      await tambahL(nama: ' netflix+ ', nominalSen: 3000000);
      await tambahL(nama: 'Netflix', nominalSen: 1000000,
          siklus: Frekuensi.tahunan);

      final temuan = deteksiLangganan(
          daftar: await semuaBarisL(), sekarang: jamUji);

      final dup = temuan
          .where((t) => t.jenis == JenisTemuanLangganan.duplikat)
          .toList();
      expect(dup, hasLength(1));
      expect(dup.first.baris, hasLength(2));
      expect(dup.first.totalBulananSen, 8000000);
    });

    test('tarif naik terbaca dari pembayaran terakhir, bukan dari tebakan',
        () async {
      final tid = (await tagihanBaru('Netflix', jumlahSen: 18600000)).id;
      final l = await tambahL(
          nama: 'Netflix', nominalSen: 18600000, tagihanId: tid);

      // Belum ada bukti lebih besar -> tidak ada temuan.
      var temuan = deteksiLangganan(
          daftar: await semuaBarisL(), sekarang: jamUji);
      expect(
          temuan.where((t) => t.jenis == JenisTemuanLangganan.tarifNaik),
          isEmpty);

      // Rp 200.000 dibayar = Rp 186.000 + 7,5% -> naik 8% (dibulatkan).
      await bayar(tid, 20000000, DateTime(2026, 8, 20));
      temuan = deteksiLangganan(
        daftar: await semuaBarisL(),
        sekarang: jamUji,
        pembayaranTerakhirSen: await repo.pembayaranTerakhirPerTagihan(),
      );
      final naik = temuan
          .where((t) => t.jenis == JenisTemuanLangganan.tarifNaik)
          .toList();
      expect(naik, hasLength(1));
      expect(naik.first.naikPersen, 8);
      expect(naik.first.nominalAcuanSen, 20000000);

      // Naik 3% saja -> di bawah batas 5%, tidak dilaporkan.
      await bayar(tid, 19158000, DateTime(2026, 9, 1),
          periode: DateTime(2026, 9, 20));
      final temuanKecil = deteksiLangganan(
        daftar: await semuaBarisL(),
        sekarang: jamUji,
        pembayaranTerakhirSen: await repo.pembayaranTerakhirPerTagihan(),
      );
      expect(
          temuanKecil.where((t) => t.jenis == JenisTemuanLangganan.tarifNaik),
          isEmpty);
      expect((await bacaL(l.id)).nominalSen, 18600000,
          reason: 'deteksi tidak boleh mengubah data sendiri');
    });

    test('jarang dipakai dihitung dari tanggal mulai, dan sembuh setelah '
        'ditandai', () async {
      final l = await tambahL(
          nama: 'Gym', nominalSen: 5000000, mulai: DateTime(2026, 1, 1));

      var temuan = deteksiLangganan(
          daftar: await semuaBarisL(), sekarang: jamUji);
      final jarang = temuan
          .where((t) => t.jenis == JenisTemuanLangganan.jarangDipakai)
          .toList();
      expect(jarang, hasLength(1));
      expect(jarang.first.hariSejakDipakai, 257);

      await repo.tandaiDipakai(l.id, kapan: DateTime(2026, 9, 10));
      temuan = deteksiLangganan(
          daftar: await semuaBarisL(), sekarang: jamUji);
      expect(
          temuan.where((t) => t.jenis == JenisTemuanLangganan.jarangDipakai),
          isEmpty);

      // Batas hari bisa diatur: 3 hari -> langsung muncul lagi.
      temuan = deteksiLangganan(
          daftar: await semuaBarisL(),
          sekarang: jamUji,
          batasJarangHari: 3);
      expect(
          temuan.where((t) => t.jenis == JenisTemuanLangganan.jarangDipakai),
          hasLength(1));
    });
  });

  // ------------------------------------------------------------------
  // Layar
  // ------------------------------------------------------------------

  Future<void> tampilkan(WidgetTester t, Widget layar) async {
    await t.binding.setSurfaceSize(const Size(420, 900));
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTema.terang(),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: layar,
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  Future<void> tutup(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 50));
    await t.binding.setSurfaceSize(null);
  }

  Future<void> gulirKe(WidgetTester t, Finder target, {int maks = 14}) async {
    for (var i = 0; i < maks; i++) {
      if (target.evaluate().isNotEmpty) return;
      // Titik tetap di badan daftar supaya gulir tidak bergantung hit-test
      // pusat Scrollable (layar tinggi karena kartu tambahan).
      await t.dragFrom(const Offset(210, 500), const Offset(0, -220));
      await t.pump(const Duration(milliseconds: 150));
    }
  }

  group('Layar langganan pintar', () {
    testWidgets('kartu analitik: total tahunan, lima terbesar, proyeksi 12 bulan',
        (t) async {
      await tambahL(
          nama: 'Netflix', nominalSen: 18600000, mulai: DateTime(2026, 1, 20));
      await tambahL(
          nama: 'Majalah',
          nominalSen: 1200000,
          siklus: Frekuensi.tahunan,
          mulai: DateTime(2026, 1, 1));
      await tampilkan(t, LanggananScreen(jamSekarang: () => jamUji));

      // Kartu analitik ada di bawah daftar: gulir dulu.
      await gulirKe(t, find.byKey(const Key('kartu_analitik')));
      expect(find.byKey(const Key('kartu_analitik')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('total_tahunan'))).data,
          'Setara ${fmtRpDariSen(18700000 * 12)} per tahun');
      expect(
          t.widget<Text>(find.byKey(const Key('analitik_total_tahunan'))).data,
          'Setara ${fmtRpDariSen(18700000 * 12)} per tahun');
      expect(find.byKey(const Key('analitik_proyeksi')), findsOneWidget);

      // Buka proyeksi: 12 baris bulan + baris pertama Sep 2026.
      await gulirKe(t, find.byKey(const Key('analitik_proyeksi')));
      await t.ensureVisible(find.byKey(const Key('analitik_proyeksi')));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.byKey(const Key('analitik_proyeksi')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await gulirKe(t, find.byKey(const Key('proyeksi_2026-09')));
      expect(find.byKey(const Key('proyeksi_2026-09')), findsOneWidget);
      expect(find.byKey(const Key('proyeksi_2027-08')), findsOneWidget);
      await tutup(t);
    });

    testWidgets('panel perhatian: temuan tampil, tombolnya benar-benar bekerja',
        (t) async {
      final tid = (await tagihanBaru('Netflix', jumlahSen: 18600000)).id;
      final netflix = await tambahL(
          nama: 'Netflix', nominalSen: 18600000, tagihanId: tid);
      final gym = await tambahL(
          nama: 'Gym', nominalSen: 5000000, mulai: DateTime(2026, 1, 1));
      await bayar(tid, 20000000, DateTime(2026, 8, 20));

      await tampilkan(t, LanggananScreen(jamSekarang: () => jamUji));
      await gulirKe(t, find.byKey(const Key('panel_perhatian')));

      expect(find.byKey(const Key('panel_perhatian')), findsOneWidget);
      expect(find.textContaining('Tarif mungkin sudah berubah'), findsOneWidget);
      expect(find.textContaining('terakhir ditandai dipakai'), findsNothing);
      // Dua baris memang belum pernah ditandai dipakai: Gym dan Netflix.
      expect(find.textContaining('belum pernah ditandai dipakai sejak'),
          findsNWidgets(2));

      // Tombol "Masih dipakai" benar-benar menulis ke database.
      // Panel bisa lebih panjang dari layar: pakai ensureVisible supaya
      // tombolnya benar-benar terlihat sebelum ditekan.
      final tombolTandai = find.byKey(Key('tandai_dipakai_${gym.id}'));
      await gulirKe(t, tombolTandai);
      await t.ensureVisible(tombolTandai);
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(tombolTandai);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect((await bacaL(gym.id)).terakhirDipakaiPada, isNotNull);

      // Tombol "Sesuaikan nominal" -> dialog -> nominal ikut berubah.
      final tombol = find.byKey(Key('sesuaikan_nominal_${netflix.id}'));
      await gulirKe(t, tombol);
      await t.ensureVisible(tombol);
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(tombol);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('sesuaikan_simpan')), findsOneWidget);
      await t.tap(find.byKey(const Key('sesuaikan_simpan')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect((await bacaL(netflix.id)).nominalSen, 20000000);
      await tutup(t);
    });
  });
}
