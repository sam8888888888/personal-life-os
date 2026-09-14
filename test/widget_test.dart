/// Uji asap (smoke test): aplikasi utama bisa dijalankan dan menampilkan
/// empat tab navigasi utama.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/app_router.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  testWidgets('Aplikasi tampil dengan 4 tab utama', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await db.close();
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(
        theme: AppTema.terang(),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: buatRouter(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Ringkasan'), findsWidgets);
    expect(find.text('Tagihan'), findsWidgets);
    expect(find.text('Kalender'), findsWidgets);
    expect(find.text('Pengaturan'), findsWidgets);
    expect(find.text('Uang tersisa bulan ini'), findsOneWidget);

    // timer drift dituntaskan sebelum pohon widget dibongkar
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
