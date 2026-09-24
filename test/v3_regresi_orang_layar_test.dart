import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/features/orang/orang_screen.dart';

void main() {
  testWidgets('layar Orang menyimpan kontak ke SQLite pada layar HP', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 600));
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await db.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: const OrangScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('orang_nama')), 'Kontak Uji');
    await tester.ensureVisible(find.byKey(const Key('orang_simpan')));
    await tester.tap(find.byKey(const Key('orang_simpan')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final List<OrangData> tersimpan = await db.select(db.orang).get();
    expect(tersimpan, hasLength(1));
    expect(tersimpan.single.nama, 'Kontak Uji');
    expect(find.text('Tersimpan.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  });
}
