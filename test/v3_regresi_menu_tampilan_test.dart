import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/app_router.dart';
import 'package:personal_life_os/core/providers/akun_providers.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';

void main() {
  testWidgets('Semua Fitur terbuka dari menu Lainnya', (tester) async {
    final router = buatRouter(awal: '/lainnya');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sesiAkunProvider.overrideWith((ref) async => null)],
        child: MaterialApp.router(
          theme: AppTema.terang(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('buka_peta_fitur')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peta_ringkas')), findsOneWidget);
    expect(find.text('Semua Fitur'), findsOneWidget);
    router.dispose();
  });

  testWidgets('Akun & Sinkron terbuka dari menu Lainnya', (tester) async {
    final router = buatRouter(awal: '/lainnya');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sesiAkunProvider.overrideWith((ref) async => null)],
        child: MaterialApp.router(
          theme: AppTema.terang(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('buka_akun')));
    await tester.pumpAndSettle();

    expect(find.text('Akun & Sinkron'), findsOneWidget);
    expect(find.text('Belum masuk'), findsOneWidget);
    router.dispose();
  });

  testWidgets('menu Lainnya merapikan subjudul dan memberi petunjuk gulir', (
    tester,
  ) async {
    final router = buatRouter(awal: '/lainnya');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sesiAkunProvider.overrideWith((ref) async => null)],
        child: MaterialApp.router(
          theme: AppTema.terang(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scrollbar), findsWidgets);
    double? tinggiReferensi;
    for (final Key key in const <Key>[
      Key('buka_peta_fitur'),
      Key('buka_kotak_masuk'),
      Key('buka_catatan_harian'),
      Key('buka_orang'),
      Key('buka_akun'),
    ]) {
      expect(find.byKey(key), findsOneWidget);
      final List<Text> teks = tester
          .widgetList<Text>(
            find.descendant(of: find.byKey(key), matching: find.byType(Text)),
          )
          .toList();
      expect(teks.last.maxLines, 1, reason: '$key');
      final double tinggi = tester.getSize(find.byKey(key)).height;
      tinggiReferensi ??= tinggi;
      expect(tinggi, tinggiReferensi, reason: 'tinggi menu $key');
    }
    router.dispose();
  });

  testWidgets('Ringkasan pagi bisa digulir pada layar pendek tanpa overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 600));
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final router = buatRouter(awal: '/briefing');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          theme: AppTema.terang(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ringkasan pagi'), findsOneWidget);
    expect(find.byType(Scrollbar), findsWidgets);
    final Finder adhkar = find.byKey(const ValueKey('adhkar_ayat_kursi'));
    await tester.ensureVisible(adhkar);
    await tester.pumpAndSettle();
    expect(adhkar, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await db.close();
    router.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}
