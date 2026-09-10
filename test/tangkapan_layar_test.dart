/// Pembuat tangkapan layar demo (F2) — merender aplikasi sungguhan pada ukuran
/// ponsel 420x900 dengan font Roboto asli dari Flutter SDK.
///
/// Jalankan:  flutter test test/tangkapan_layar_test.dart --update-goldens
/// Hasil PNG muncul di test/goldens/, lalu disalin ke folder demo/.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/app_router.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';

const _fontDasar =
    '/workspace/tools/flutter/bin/cache/artifacts/material_fonts/';

Future<void> _muatFont(String nama, List<String> berkas) async {
  final loader = FontLoader(nama);
  for (final b in berkas) {
    final data = File('$_fontDasar$b').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(data.buffer)));
  }
  await loader.load();
}

/// Uji ini butuh font asli dari Flutter SDK; dilewati bila tidak tersedia
/// (mis. di mesin lain) agar rangkaian uji biasa tetap hijau.
final bool _fontTersedia =
    File('${_fontDasar}Roboto-Regular.ttf').existsSync();

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await _muatFont('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Light.ttf',
      'Roboto-Black.ttf',
    ]);
    await _muatFont('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });

  setUp(() async {
    // Data contoh: 7 template + pemasukan Rp 12.000.000 + satu sudah dibayar.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await PengaturanRepository(db).isiContohData();
    final daftar = await (db.select(db.tagihan)
          ..orderBy([(t) => OrderingTerm.asc(t.jatuhTempo)]))
        .get();
    await (db.update(db.tagihan)..where((t) => t.id.equals(daftar[0].id)))
        .write(const TagihanCompanion(lunas: Value(true)));
    // dikunci lewat variabel global agar dipakai pengujian berikutnya
    _db = db;
  });

  tearDown(() async {
    await _db.close();
  });

  Future<void> potret(WidgetTester tester, String nama, String rute) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(_db)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTema.terang().copyWith(
          textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Roboto'),
        ),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: buatRouter(awal: rute),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/f2_$nama.png'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('tangkapan layar ringkasan', (t) => potret(t, 'ringkasan', '/'),
      skip: !_fontTersedia);
  testWidgets('tangkapan layar tagihan', (t) => potret(t, 'tagihan', '/tagihan'),
      skip: !_fontTersedia);
  testWidgets('tangkapan layar kalender',
      (t) => potret(t, 'kalender', '/kalender'),
      skip: !_fontTersedia);
  testWidgets('tangkapan layar pengaturan',
      (t) => potret(t, 'pengaturan', '/pengaturan'),
      skip: !_fontTersedia);
  testWidgets('tangkapan layar form', (t) => potret(t, 'form_tambah', '/tambah'),
      skip: !_fontTersedia);
}

late AppDatabase _db;
