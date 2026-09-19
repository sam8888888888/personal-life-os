/// Uji FR-21 — mode gelap/terang/ikut sistem.
///
/// Yang dibuktikan: pilihan tersimpan di basis data, `MaterialApp.themeMode`
/// benar-benar mengikuti pilihan itu (brightness terang vs gelap), dan saklar di
/// layar Pengaturan bisa dipakai.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/features/pengaturan/mode_tema_pengaturan.dart';
import 'package:personal_life_os/features/pengaturan/pengaturan_screen.dart';

late AppDatabase db;

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() async => db.close());

  group('FR-21 pilihan tema', () {
    test('kode tersimpan dikenali; kode asing kembali ke "ikuti sistem"', () {
      expect(modeTemaDariKode('gelap'), ModeTema.gelap);
      expect(modeTemaDariKode('TERANG'), ModeTema.terang);
      expect(modeTemaDariKode('sistem'), ModeTema.sistem);
      expect(modeTemaDariKode(null), ModeTema.sistem);
      expect(modeTemaDariKode('biru-neon'), ModeTema.sistem);
    });

    test('tema gelap benar-benar gelap, tema terang benar-benar terang', () {
      expect(AppTema.gelap().colorScheme.brightness, Brightness.dark);
      expect(AppTema.terang().colorScheme.brightness, Brightness.light);
      // Warna dasar tetap sama supaya identitas visual tidak berubah.
      expect(AppTema.gelap().colorScheme.primary,
          isNot(AppTema.terang().colorScheme.primary));
    });

    test('bawaan sebelum ada pilihan = ikuti sistem', () async {
      expect(await bacaModeTema(db), ModeTema.sistem);
    });

    test('pilihan tersimpan & terbaca kembali', () async {
      await simpanModeTema(db, ModeTema.gelap);
      expect(await bacaModeTema(db), ModeTema.gelap);

      final baris = (await db.select(db.pengaturan).get())
          .where((p) => p.kunci == kunciModeTema)
          .toList();
      expect(baris, hasLength(1));
      expect(baris.first.nilai, 'gelap');

      // Ganti lagi tidak membuat baris ganda (kunci unik).
      await simpanModeTema(db, ModeTema.terang);
      expect(await bacaModeTema(db), ModeTema.terang);
      expect(
          (await db.select(db.pengaturan).get())
              .where((p) => p.kunci == kunciModeTema)
              .length,
          1);
    });
  });

  // ------------------------------------------------------------------
  // Layar
  // ------------------------------------------------------------------

  /// Kerangka kecil: MaterialApp yang memakai themeMode dari provider —
  /// sama seperti `PersonalLifeOsApp`.
  Future<void> tampilkanHarness(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(420, 900));
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: Consumer(builder: (context, ref, _) {
        final mode = ref.watch(modeTemaProvider).value ?? ModeTema.sistem;
        return MaterialApp(
          theme: AppTema.terang(),
          darkTheme: AppTema.gelap(),
          themeMode: mode.mode,
          locale: const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (c) => Scaffold(
              key: const Key('isi_uji'),
              body: Text('terang? ${Theme.of(c).brightness}',
                  key: const Key('teks_brightness')),
            ),
          ),
        );
      }),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  Future<void> tutup(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 50));
    await t.binding.setSurfaceSize(null);
  }

  testWidgets('themeMode benar-benar mengikuti pilihan tersimpan',
      (t) async {
    // 1. Belum ada pilihan → ikut sistem (di uji = terang).
    await tampilkanHarness(t);
    expect(t.widget<Text>(find.byKey(const Key('teks_brightness'))).data,
        contains('light'), reason: 'bawaan (ikuti sistem) = terang di uji');
    await tutup(t);

    // 2. Pengguna memilih gelap → simpan.
    await simpanModeTema(db, ModeTema.gelap);

    // 3. Aplikasi dibuka lagi: tema benar-benar gelap.
    await tampilkanHarness(t);
    expect(t.widget<Text>(find.byKey(const Key('teks_brightness'))).data,
        contains('dark'),
        reason: 'pilihan tersimpan harus dipakai saat aplikasi dibuka');
    await tutup(t);

    // 4. Kembali ke terang juga bekerja.
    await simpanModeTema(db, ModeTema.terang);
    await tampilkanHarness(t);
    expect(t.widget<Text>(find.byKey(const Key('teks_brightness'))).data,
        contains('light'));
    await tutup(t);
  });

  testWidgets('saklar di layar Pengaturan menyimpan pilihan tema',
      (t) async {
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
        // Layar Pengaturan mengembalikan ListView (tanpa Scaffold) karena
        // dipasang di dalam kerangka aplikasi; untuk uji dibungkus Scaffold.
        home: const Scaffold(body: PengaturanScreen()),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));

    // Layar Pengaturan panjang: gulir dulu sampai saklar tema terbangun.
    final pilih = find.byKey(const Key('pilih_mode_tema'));
    for (var i = 0; i < 12 && pilih.evaluate().isEmpty; i++) {
      await t.dragFrom(const Offset(210, 500), const Offset(0, -220));
      await t.pump(const Duration(milliseconds: 150));
    }
    await t.ensureVisible(pilih);
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(pilih);
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    await t.tap(find.text('Gelap').last);
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 400));

    expect(await bacaModeTema(db), ModeTema.gelap);
    await tutup(t);
  });
}
