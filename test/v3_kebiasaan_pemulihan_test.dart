/// Uji FR-81 (metrik pemulihan) & FR-85 (konsistensi tanpa skor moral).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/aksi/pemulihan_kebiasaan.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/features/aksi/kebiasaan_screen.dart';

late AppDatabase db;

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() async => db.close());

  // ------------------------------------------------------------------
  // Hitungan murni
  // ------------------------------------------------------------------

  group('FR-81 pemulihan kebiasaan', () {
    test('menghitung jeda, hari tercatat, dan catatan berturut di ujung', () {
      // 7 hari, lama → baru: ada, ada, kosong, kosong, ada, ada, ada.
      final p = hitungPemulihan(
          [1, 1, 0, 0, 1, 0.5, 1]);

      expect(p.rentangHari, 7);
      expect(p.hariTercatat, 5);
      expect(p.jedaTerpanjang, 2);
      expect(p.hariSejakCatatanTerakhir, 0);
      expect(p.hariBerturutAkhir, 3);
      expect(p.persenTercatat, 71);
    });

    test('tanpa catatan sama sekali tetap netral, tanpa kata menghakimi', () {
      final p = hitungPemulihan(List<double>.filled(7, 0));
      expect(p.adaCatatan, isFalse);
      expect(p.jedaTerpanjang, 7);
      expect(p.kalimat, contains('Menandai bisa dimulai kapan saja'));

      final terlarang = ['gagal', 'hukuman', 'malas', 'putus', 'buruk'];
      final teks = [
        p.kalimat,
        hitungPemulihan([1, 0, 0, 1, 1, 1, 1]).kalimat,
        hitungPemulihan([0, 0, 0, 0, 0, 0, 1]).kalimat,
        kalimatKonsistensi(3, 7),
        kalimatKonsistensi(0, 7),
      ].join(' ').toLowerCase();
      for (final kata in terlarang) {
        expect(teks.contains(kata), isFalse, reason: kata);
      }
    });

    test('catatan yang kembali muncul setelah jeda menyebut pemulihan', () {
      final p = hitungPemulihan([1, 1, 0, 0, 0, 1, 1]);
      expect(p.hariBerturutAkhir, 2);
      expect(p.kalimat, contains('catatan muncul kembali pada 2 hari terakhir'));
    });

    test('grafik mingguan menghitung berapa kebiasaan tercatat per hari', () {
      final perHari = jumlahTercatatPerHari([
        [1, 0, 1, 0, 1, 1, 0],
        [0, 0, 1, 0, 0, 1, 0],
      ], rentangHari: 7);
      expect(perHari, [1, 0, 2, 0, 1, 2, 0]);
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

  testWidgets('layar Kebiasaan: kartu konsistensi + baris pemulihan tampil, '
      'dan ikut berubah setelah ditandai', (t) async {
    final k = await db.into(db.kebiasaan).insertReturning(
        KebiasaanCompanion.insert(
            idKebiasaan: 'kbs_uji',
            nama: 'Jalan Pagi',
            targetPerMinggu: const Value(7)));

    await tampilkan(t, const KebiasaanScreen());

    expect(find.byKey(const Key('kartu_konsistensi')), findsOneWidget);
    expect(find.text('Konsistensi 7 hari'), findsOneWidget);

    // Awalnya belum ada catatan: kalimatnya netral, tanpa menghakimi.
    final sebelum =
        t.widget<Text>(find.byKey(Key('pemulihan_${k.id}'))).data!;
    expect(sebelum, contains('Belum ada catatan pada 7 hari terakhir'));

    await t.tap(find.byKey(Key('catat_penuh_${k.id}')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));

    final sesudah = t.widget<Text>(find.byKey(Key('pemulihan_${k.id}'))).data!;
    expect(sesudah, contains('Tercatat 1 dari 7 hari'));
    expect(sesudah, contains('catatan terakhir hari ini'));
    // Catatannya benar-benar tersimpan.
    expect(await db.select(db.logKebiasaan).get(), hasLength(1));
    await tutup(t);
  });
}
