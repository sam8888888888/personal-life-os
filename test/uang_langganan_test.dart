/// Uji FR-68 — manajer langganan berulang (recurring & subscription).
///
/// Dua lapis:
///  1. mesin angka & aturan status (repository + helper tampilan) — `test()`;
///  2. layar daftar & form — `testWidgets()` pada layar 420x900.
///
/// Kriteria terima: daftar punya filter aktif/pause; "pause" menghentikan
/// pengingat (Tagihan.statusAktif = false) tanpa menghapus riwayat.
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
import 'package:personal_life_os/features/uang/langganan/form_langganan_screen.dart';
import 'package:personal_life_os/features/uang/langganan/langganan_screen.dart';

late AppDatabase db;
late LanggananRepository repo;
late TagihanRepository repoT;

/// Waktu uji dikunci: 15 September 2026, 09.00.
final jamUji = DateTime(2026, 9, 15, 9);

/// Tagihan uji (mesin pengingat lama) — jumlah eksplisit Rp 186.000.
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
      tanggalMulai: mulai ?? DateTime(2026, 1, 1),
      siklus: siklus,
      tagihanId: tagihanId,
      status: status,
    );

Future<TagihanData> bacaTagihan(int id) =>
    (db.select(db.tagihan)..where((t) => t.id.equals(id))).getSingle();

/// Semua baris langganan lewat Future (BUKAN stream): di dalam testWidgets
/// menunggu stream Drift akan menggantung, jadi selalu pakai query ini.
Future<List<LanggananData>> semuaBarisL() => db.select(db.langganan).get();

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
  // 1. Angka & aturan status
  // ------------------------------------------------------------------

  group('FR-68 nominal bulanan per siklus', () {
    test('bulanan/tahunan/mingguan dinormalkan dengan angka eksplisit',
        () async {
      // Rp 50.000 / bulan -> tetap 5000000 sen.
      final bulanan =
          await tambahL(nama: 'Bulanan', nominalSen: 5000000);
      // Rp 12.000 / tahun -> 1200000 / 12 = 100000 sen per bulan.
      final tahunan = await tambahL(
          nama: 'Tahunan', nominalSen: 1200000, siklus: Frekuensi.tahunan);
      // Rp 300 / minggu -> 30000 * 52 / 12 = 130000 sen per bulan.
      final mingguan = await tambahL(
          nama: 'Mingguan', nominalSen: 30000, siklus: Frekuensi.mingguan);

      expect(LanggananRepository.nominalBulananSen(bulanan), 5000000);
      expect(LanggananRepository.nominalBulananSen(tahunan), 100000);
      expect(LanggananRepository.nominalBulananSen(mingguan), 130000);
      expect(await repo.totalBulananSen(), 5000000 + 100000 + 130000);
    });

    test('total bulanan = jumlah nominal bulanan langganan aktif saja',
        () async {
      // 1.000.000 sen + 200.000 sen (tahunan 2.400.000/12) = 1.200.000 sen.
      await tambahL(nama: 'A', nominalSen: 1000000);
      await tambahL(
          nama: 'B', nominalSen: 2400000, siklus: Frekuensi.tahunan);
      final c = await tambahL(nama: 'C', nominalSen: 9000000);
      await repo.pause(c.id, sampai: DateTime(2026, 12, 31));

      expect(await repo.totalBulananSen(), 1200000);
      // Baris pause tetap ada => riwayat tidak hilang.
      final semua = await semuaBarisL();
      expect(semua.length, 3);
      expect(semua.firstWhere((l) => l.id == c.id).status,
          StatusLangganan.pause.nilaiDb);
      // Helper tampilan harus sepakat dengan repository.
      expect(totalBulananAktifSen(semua), await repo.totalBulananSen());
    });
  });

  group('FR-68 status: pause / aktifkan / berhenti', () {
    test('pause mematikan pengingat tagihan tertaut, baris langganan tetap ada',
        () async {
      final tid = (await tagihanBaru('Netflix')).id;
      final l = await tambahL(nama: 'Netflix', nominalSen: 18600000, tagihanId: tid);

      await repo.pause(l.id, sampai: DateTime(2026, 10, 31));

      expect((await bacaTagihan(tid)).statusAktif, isFalse,
          reason: 'pause harus menghentikan pengingat');
      final lagi = await repo.ambilSatu(l.id);
      expect(lagi, isNotNull, reason: 'baris langganan tidak boleh hilang');
      expect(lagi!.status, StatusLangganan.pause.nilaiDb);
      expect(lagi.pauseSejak, isNotNull);
      expect(lagi.pauseSampai, DateTime(2026, 10, 31));
      // Riwayat pembayaran tidak disentuh — tabelnya tetap bisa dibaca.
      expect(await db.select(db.riwayatPembayaran).get(), isEmpty);
    });

    test('aktifkan menghidupkan pengingat lagi dan membersihkan kolom pause',
        () async {
      final tid = (await tagihanBaru('Spotify')).id;
      final l = await tambahL(nama: 'Spotify', nominalSen: 5490000, tagihanId: tid);
      await repo.pause(l.id, sampai: DateTime(2026, 10, 31));

      await repo.aktifkan(l.id);

      expect((await bacaTagihan(tid)).statusAktif, isTrue);
      final lagi = await repo.ambilSatu(l.id);
      expect(lagi!.status, StatusLangganan.aktif.nilaiDb);
      expect(lagi.pauseSejak, isNull);
      expect(lagi.pauseSampai, isNull);
    });

    test('hentikan: keluar dari total bulanan, riwayat baris tetap ada',
        () async {
      final tid = (await tagihanBaru('Majalah')).id;
      final l = await tambahL(nama: 'Majalah', nominalSen: 5000000, tagihanId: tid);
      await tambahL(nama: 'Netflix', nominalSen: 1000000);

      await repo.hentikan(l.id);

      expect(await repo.totalBulananSen(), 1000000);
      expect(await repo.ambilAktif(), hasLength(1));
      final lagi = await repo.ambilSatu(l.id);
      expect(lagi!.status, StatusLangganan.berhenti.nilaiDb);
      expect((await bacaTagihan(tid)).statusAktif, isFalse);
      expect(await db.select(db.langganan).get(), hasLength(2));
    });

    test('lepas tautan menghidupkan kembali tagihan (pengingat tidak mati diam)',
        () async {
      final tid = (await tagihanBaru('Streaming')).id;
      final l = await tambahL(nama: 'Streaming', nominalSen: 1000, tagihanId: tid);
      await repo.pause(l.id);

      await repo.lepasTautan(l.id);

      expect((await bacaTagihan(tid)).statusAktif, isTrue);
      expect((await repo.ambilSatu(l.id))!.tagihanId, isNull);
      // Status langganan tetap pause (hanya tautannya yang dilepas).
      expect((await repo.ambilSatu(l.id))!.status,
          StatusLangganan.pause.nilaiDb);
    });

    test('satu tagihan hanya untuk satu langganan', () async {
      final tid = (await tagihanBaru('Bundling')).id;
      final a = await tambahL(nama: 'A', nominalSen: 1000);
      final b = await tambahL(nama: 'B', nominalSen: 1000);
      await repo.tautkanKeTagihan(a.id, tid);

      await expectLater(
        repo.tautkanKeTagihan(b.id, tid),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('FR-68 validasi & helper tampilan', () {
    test('nama kosong dan nominal negatif ditolak', () async {
      await expectLater(
        tambahL(nama: '   ', nominalSen: 1000),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        tambahL(nama: 'Minus', nominalSen: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('tanggalBerikutnya: bulanan, mingguan, dan berhenti', () async {
      final bulanan = await tambahL(
          nama: 'Bulanan', nominalSen: 1000, mulai: DateTime(2026, 1, 1));
      final mingguan = await tambahL(
        nama: 'Mingguan',
        nominalSen: 1000,
        siklus: Frekuensi.mingguan,
        mulai: DateTime(2026, 9, 1),
      );
      final mati = await tambahL(
          nama: 'Mati', nominalSen: 1000, status: StatusLangganan.berhenti);

      expect(tanggalBerikutnya(bulanan, jamUji), DateTime(2026, 10, 1));
      expect(tanggalBerikutnya(mingguan, jamUji), DateTime(2026, 9, 15));
      expect(tanggalBerikutnya(mati, jamUji), isNull);
    });

    test('cocokFilter dan kalimatPause jujur', () async {
      final aktif = await tambahL(nama: 'Aktif', nominalSen: 1000);
      final pause = await tambahL(nama: 'Pause', nominalSen: 1000);
      await repo.pause(pause.id, sampai: DateTime(2026, 10, 31));
      final mati = await tambahL(
          nama: 'Mati', nominalSen: 1000, status: StatusLangganan.berhenti);

      // Baris pause dibaca ulang: objek hasil `tambah` masih menyimpan status
      // lama (aktif) karena itu potret saat penyisipan.
      final pauseBaru = (await repo.ambilSatu(pause.id))!;
      expect(cocokFilter(aktif, FilterLangganan.aktif), isTrue);
      expect(cocokFilter(aktif, FilterLangganan.pause), isFalse);
      expect(cocokFilter(pauseBaru, FilterLangganan.pause), isTrue);
      expect(cocokFilter(mati, FilterLangganan.berhenti), isTrue);
      expect(cocokFilter(mati, FilterLangganan.semua), isTrue);

      final lagi = (await repo.ambilSatu(pause.id))!;
      final kalimat = kalimatPause(lagi);
      expect(kalimat, contains('Pause sejak'));
      expect(kalimat, contains('sampai 31 Oktober 2026'));
      expect(kalimat, contains('pengingat berhenti'));
      expect(kalimat, contains('riwayat tetap ada'));
    });

    test('label siklus & ubah nominal lewat repository', () async {
      expect(labelSiklusLangganan(Frekuensi.bulanan), 'Bulanan');
      expect(labelSiklusLangganan(Frekuensi.tahunan), 'Tahunan');
      expect(labelSiklusLangganan(Frekuensi.mingguan), 'Mingguan');

      final l = await tambahL(nama: 'Netflix', nominalSen: 5000000);
      expect(await repo.ubah(l.id, nominalSen: 7500000), 1);
      expect((await repo.ambilSatu(l.id))!.nominalSen, 7500000);
    });
  });

  // ------------------------------------------------------------------
  // 2. Layar
  // ------------------------------------------------------------------

  /// Tampilkan layar langsung (tanpa router) pada ukuran ponsel 420x900.
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

  /// Tutup layar: pompa SizedBox lalu bersihkan, hindari stream Drift menggantung.
  Future<void> tutup(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 50));
    await t.binding.setSurfaceSize(null);
  }

  /// ListView itu malas: gulir sampai target terlihat.
  ///
  /// Memakai titik tetap di badan daftar (210, 500) — bukan pusat `Scrollable` —
  /// supaya gulir tetap bekerja walau layar bertambah tinggi oleh kartu baru
  /// (FR-69/FR-70) dan sebagian isi menutupi pusat viewport.
  Future<void> gulirKe(WidgetTester t, Finder target, {int maks = 10}) async {
    for (var i = 0; i < maks; i++) {
      if (target.evaluate().isNotEmpty) return;
      await t.dragFrom(const Offset(210, 500), const Offset(0, -220));
      await t.pump(const Duration(milliseconds: 150));
    }
  }

  /// Isi standar: 2 aktif (1 tertaut tagihan), 1 pause, 1 berhenti.
  /// Mengembalikan barisnya supaya uji memakai id nyata, bukan tebakan.
  Future<List<LanggananData>> isiEmpat() async {
    final tid = (await tagihanBaru('Netflix')).id;
    final netflix =
        await tambahL(nama: 'Netflix', nominalSen: 18600000, tagihanId: tid);
    final majalah = await tambahL(
        nama: 'Majalah Digital', nominalSen: 1200000, siklus: Frekuensi.tahunan);
    final spotify = await tambahL(nama: 'Spotify', nominalSen: 3000000);
    await repo.pause(spotify.id, sampai: DateTime(2026, 10, 31));
    final gym = await tambahL(
        nama: 'Gym Lama', nominalSen: 5000000, status: StatusLangganan.berhenti);
    return [netflix, majalah, spotify, gym];
  }

  group('Layar daftar langganan', () {
    testWidgets('kartu total = totalBulananSen repository, filter pause jujur',
        (t) async {
      await isiEmpat();
      await tampilkan(t, LanggananScreen(jamSekarang: () => jamUji));

      expect(find.text('Langganan'), findsWidgets);
      final totalSen = await repo.totalBulananSen();
      // 18.600.000 + 100.000 (tahunan 1.200.000/12) = 18.700.000 sen.
      expect(totalSen, 18700000);
      expect(find.byKey(const Key('total_bulanan')), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const Key('total_bulanan'))).data,
        fmtRpDariSen(totalSen),
      );
      expect(find.text('Rp 187.000'), findsOneWidget);
      expect(find.textContaining('2 aktif · 1 pause (tidak dihitung)'),
          findsOneWidget);

      // Kartu FR-69/FR-70 menambah tinggi layar: gulir dulu ke saringan.
      await gulirKe(t, find.byKey(const Key('filter_semua')));
      // Semua tombol saringan tersedia.
      for (final k in ['filter_semua', 'filter_aktif', 'filter_pause', 'filter_berhenti']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      await tutup(t);
    });

    testWidgets('filter pause hanya menampilkan baris pause', (t) async {
      await isiEmpat();
      await tampilkan(t, LanggananScreen(jamSekarang: () => jamUji));

      await gulirKe(t, find.byKey(const Key('filter_pause')));
      await t.tap(find.byKey(const Key('filter_pause')));
      await t.pump(const Duration(milliseconds: 200));
      await gulirKe(t, find.text('Spotify'));
      expect(find.text('Spotify'), findsOneWidget);
      expect(find.text('Netflix'), findsNothing);
      expect(find.text('Gym Lama'), findsNothing);
      expect(find.textContaining('riwayat tetap ada'), findsOneWidget);

      await gulirKe(t, find.byKey(const Key('filter_aktif')));
      await t.tap(find.byKey(const Key('filter_aktif')));
      await t.pump(const Duration(milliseconds: 200));
      await gulirKe(t, find.text('Netflix'));
      expect(find.text('Spotify'), findsNothing);
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Gym Lama'), findsNothing);

      await gulirKe(t, find.byKey(const Key('filter_berhenti')));
      await t.tap(find.byKey(const Key('filter_berhenti')));
      await t.pump(const Duration(milliseconds: 200));
      await gulirKe(t, find.text('Gym Lama'));
      expect(find.text('Gym Lama'), findsOneWidget);
      expect(find.text('Netflix'), findsNothing);

      await gulirKe(t, find.byKey(const Key('filter_semua')));
      await t.tap(find.byKey(const Key('filter_semua')));
      await t.pump(const Duration(milliseconds: 200));
      await gulirKe(t, find.text('4 dari 4 langganan tampil'));
      expect(find.text('4 dari 4 langganan tampil'), findsOneWidget);
      await gulirKe(t, find.text('Netflix'));
      expect(find.text('Netflix'), findsOneWidget);
      // Baris ke-4 hanya dibangun setelah digulir (ListView malas).
      await gulirKe(t, find.text('Gym Lama'));
      expect(find.text('Gym Lama'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('baris memuat nominal, siklus, tanggal, lencana, dan tautan',
        (t) async {
      final baris = await isiEmpat();
      await tampilkan(t, LanggananScreen(jamSekarang: () => jamUji));

      await gulirKe(t, find.text('Rp 186.000 · Bulanan'));
      expect(find.text('Rp 186.000 · Bulanan'), findsOneWidget);
      expect(find.text('Mulai 1 Januari 2026'), findsWidgets);
      expect(find.text('Berikutnya 1 Oktober 2026'), findsWidgets);
      expect(find.text('Tertaut tagihan: Netflix'), findsOneWidget);
      expect(find.text('Belum tertaut tagihan — belum masuk pengingat'),
          findsWidgets);
      Future<String> lencana(LanggananData l) async {
        final kunci = find.byKey(Key('lencana_${l.id}'));
        await gulirKe(t, kunci);
        return t
            .widget<Text>(
                find.descendant(of: kunci, matching: find.byType(Text)))
            .data!;
      }

      expect(await lencana(baris[0]), 'Aktif'); // Netflix
      expect(await lencana(baris[2]), 'Pause'); // Spotify
      expect(await lencana(baris[3]), 'Berhenti'); // Gym Lama
      // Baris tahunan menuliskan setara bulanannya (sen 1.200.000/12 = 100.000
      // sen = Rp 1.000). Digulir dulu: ListView hanya membangun baris terlihat.
      await gulirKe(t, find.text('Setara Rp 1.000 per bulan'));
      expect(find.text('Setara Rp 1.000 per bulan'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('tekan Pause -> dialog -> pengingat mati, riwayat tetap',
        (t) async {
      final tid = (await tagihanBaru('Netflix')).id;
      final l = await tambahL(
          nama: 'Netflix', nominalSen: 18600000, tagihanId: tid);
      await tampilkan(t, LanggananScreen(jamSekarang: () => jamUji));

      final tombolPause = find.byKey(Key('aksi_pause_${l.id}'));
      await gulirKe(t, tombolPause);
      await t.ensureVisible(tombolPause);
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(tombolPause);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Pause "Netflix" sampai kapan?'), findsOneWidget);

      await t.tap(find.byKey(const Key('pause_1_bulan')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      expect((await bacaTagihan(tid)).statusAktif, isFalse);
      // Pilihan "Pause 1 bulan" = 2026-09-15 + 1 bulan = 2026-10-15
      // (tambahBulan() mengembalikan tengah malam).
      expect((await repo.ambilSatu(l.id))!.pauseSampai,
          DateTime(2026, 10, 15));
      expect(
        t.widget<Text>(find.descendant(
                of: find.byKey(Key('lencana_${l.id}')),
                matching: find.byType(Text)))
            .data,
        'Pause',
      );
      expect(find.byKey(Key('catatan_pause_${l.id}')), findsOneWidget);
      expect(find.textContaining('pengingat berhenti sampai tanggal itu'),
          findsOneWidget);
      expect(find.textContaining('riwayat tetap ada'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('tekan Aktifkan -> pengingat hidup lagi', (t) async {
      final tid = (await tagihanBaru('Spotify')).id;
      final l = await tambahL(
          nama: 'Spotify', nominalSen: 3000000, tagihanId: tid);
      await repo.pause(l.id, sampai: DateTime(2026, 10, 31));
      await tampilkan(t, LanggananScreen(jamSekarang: () => jamUji));

      final tombolAktifkan = find.byKey(Key('aksi_aktifkan_${l.id}'));
      await gulirKe(t, tombolAktifkan);
      await t.ensureVisible(tombolAktifkan);
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(tombolAktifkan);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      expect((await bacaTagihan(tid)).statusAktif, isTrue);
      expect((await repo.ambilSatu(l.id))!.status,
          StatusLangganan.aktif.nilaiDb);
      expect(
        t.widget<Text>(find.descendant(
                of: find.byKey(Key('lencana_${l.id}')),
                matching: find.byType(Text)))
            .data,
        'Aktif',
      );
      await tutup(t);
    });

    testWidgets('tekan Berhenti -> konfirmasi -> keluar dari total bulanan',
        (t) async {
      final l = await tambahL(nama: 'Majalah', nominalSen: 5000000);
      await tampilkan(t, LanggananScreen(jamSekarang: () => jamUji));
      expect(t.widget<Text>(find.byKey(const Key('total_bulanan'))).data,
          'Rp 50.000');

      final tombolBerhenti = find.byKey(Key('aksi_berhenti_${l.id}'));
      await gulirKe(t, tombolBerhenti);
      await t.ensureVisible(tombolBerhenti);
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(tombolBerhenti);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Tandai berhenti?'), findsOneWidget);

      await t.tap(find.widgetWithText(FilledButton, 'Berhenti'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      expect((await repo.ambilSatu(l.id))!.status,
          StatusLangganan.berhenti.nilaiDb);
      expect(t.widget<Text>(find.byKey(const Key('total_bulanan'))).data,
          'Rp 0');
      await tutup(t);
    });

    testWidgets('tekan Hapus -> konfirmasi -> baris hilang, tagihan hidup lagi',
        (t) async {
      final tid = (await tagihanBaru('Hapus Uji')).id;
      final l = await tambahL(
          nama: 'Akan Dihapus', nominalSen: 1000000, tagihanId: tid);
      await repo.pause(l.id);
      await tampilkan(t, LanggananScreen(jamSekarang: () => jamUji));

      final tombolHapus = find.byKey(Key('aksi_hapus_${l.id}'));
      await gulirKe(t, tombolHapus);
      await t.ensureVisible(tombolHapus);
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(tombolHapus);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Hapus baris langganan?'), findsOneWidget);

      await t.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      expect(await repo.ambilSatu(l.id), isNull);
      expect(find.byKey(Key('baris_langganan_${l.id}')), findsNothing);
      expect((await bacaTagihan(tid)).statusAktif, isTrue);
      await tutup(t);
    });

    testWidgets('form tambah: simpan "150rb" jadi Rp 150.000 di daftar',
        (t) async {
      await tampilkan(t, LanggananScreen(jamSekarang: () => jamUji));
      expect(find.textContaining('Belum ada langganan'), findsOneWidget);

      await t.tap(find.byKey(const Key('tambah_langganan')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Langganan baru'), findsOneWidget);

      await t.enterText(find.byKey(const Key('form_nama')), 'iCloud');
      await t.enterText(find.byKey(const Key('form_nominal')), '150rb');
      await t.tap(find.byKey(const Key('form_simpan')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));

      final semua = await semuaBarisL();
      expect(semua, hasLength(1));
      expect(semua.first.nama, 'iCloud');
      expect(semua.first.nominalSen, 15000000);
      expect(find.text('iCloud'), findsOneWidget);
      await gulirKe(t, find.text('Rp 150.000 · Bulanan'));
      expect(find.text('Rp 150.000 · Bulanan'), findsOneWidget);
      expect(find.byKey(const Key('total_bulanan')), findsOneWidget);
      await tutup(t);
    });

    testWidgets('form ubah: nominal baru langsung terlihat di daftar',
        (t) async {
      final l = await tambahL(nama: 'Netflix', nominalSen: 5000000);
      await tampilkan(t, LanggananScreen(jamSekarang: () => jamUji));

      final tombolUbah = find.byKey(Key('aksi_ubah_${l.id}'));
      await gulirKe(t, tombolUbah);
      await t.ensureVisible(tombolUbah);
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(tombolUbah);
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Ubah langganan'), findsOneWidget);
      expect(t.widget<TextFormField>(find.byKey(const Key('form_nama'))).controller?.text,
          'Netflix');

      await t.enterText(find.byKey(const Key('form_nominal')), '200000');
      await t.tap(find.byKey(const Key('form_simpan')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));

      expect((await repo.ambilSatu(l.id))!.nominalSen, 20000000);
      await gulirKe(t, find.text('Rp 200.000 · Bulanan'));
      expect(find.text('Rp 200.000 · Bulanan'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('bahasa layar bebas kata menghakimi (III-11)', (t) async {
      await isiEmpat();
      await tampilkan(t, LanggananScreen(jamSekarang: () => jamUji));

      final teks = <String>{};
      void kumpulkan() {
        teks.addAll(t
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? '')
            .where((s) => s.isNotEmpty));
      }

      kumpulkan();
      for (var i = 0; i < 6; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -260));
        await t.pump(const Duration(milliseconds: 120));
        kumpulkan();
      }

      const terlarang = [
        'skor',
        'anda gagal',
        'kamu',
        'berdosa',
        'belum sholat',
        'wajib anda',
        'gagal',
      ];
      for (final s in teks) {
        for (final kata in terlarang) {
          expect(s.toLowerCase().contains(kata), isFalse,
              reason: '"$s" memuat "$kata"');
        }
      }
      expect(teks.any((s) => s.contains('riwayat tetap ada')), isTrue);
      await tutup(t);
    });
  });
}
