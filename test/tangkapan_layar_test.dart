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
import 'package:personal_life_os/core/notifikasi/jejak.dart';
import 'package:personal_life_os/core/notifikasi/layanan_notifikasi.dart';
import 'package:personal_life_os/core/notifikasi/model_pengingat.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/ibadah/penyimpanan_jadwal.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/features/ibadah/jadwal_sholat_screen.dart';
import 'package:personal_life_os/features/ibadah/kalender_hijriah_screen.dart';

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
    penentuJejak = () async => null; // tanpa berkas jejak saat merender
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

  Future<void> potret(WidgetTester tester, String nama, String rute,
      {bool layananDemo = false, String prefiks = 'f2'}) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(_db),
        // Layar F3 memakai layanan contoh agar tangkapan layar stabil.
        if (layananDemo)
          layananNotifikasiProvider.overrideWithValue(_LayananDemo()),
      ],
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
        matchesGoldenFile('goldens/${prefiks}_$nama.png'));

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

  // ---- F3: layar pengingat & izin -----------------------------------------
  testWidgets('tangkapan layar pengingat',
      (t) => potret(t, 'pengingat', '/pengingat',
          layananDemo: true, prefiks: 'f3'),
      skip: !_fontTersedia);

  // ---- V1.5: layar ibadah (FR-86 & FR-90) ---------------------------------
  // Jam dipatok (bukan DateTime.now) supaya tangkapan layar tidak berubah
  // setiap hari. Layar ibadah tidak memakai Riverpod, jadi dipanggil langsung.
  Future<void> potretIbadah(WidgetTester tester, String nama, Widget layar) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
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
      home: layar,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/f4_$nama.png'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets(
      'tangkapan layar jadwal sholat',
      (t) => potretIbadah(
            t,
            'jadwal_sholat',
            JadwalSholatScreen(
              // 13 Sep 2026, 03.00 WIB -> Subuh 04:30 tampil sebagai berikutnya.
              jamSekarang: () => DateTime.utc(2026, 9, 12, 20, 0),
              penyimpanan: PenyimpananJadwal(
                penentuFolder: () =>
                    Future.value(Directory.systemTemp.createTempSync('demo_ibadah_')),
              ),
            ),
          ),
      skip: !_fontTersedia);

  testWidgets(
      'tangkapan layar kalender hijriah',
      (t) => potretIbadah(
            t,
            'kalender_hijriah',
            KalenderHijriahScreen(jamSekarang: () => DateTime(2026, 9, 13)),
          ),
      skip: !_fontTersedia);
}

/// Layanan notifikasi contoh: hasil tetap agar tangkapan layar stabil.
class _LayananDemo implements LayananNotifikasi {
  @override
  Future<void> siapkan() async {}

  @override
  Future<StatusIzinPengingat> statusIzin() async =>
      const StatusIzinPengingat(notifikasiDiizinkan: true, alarmTepatDiizinkan: false);

  @override
  Future<bool> mintaIzinNotifikasi() async => true;

  @override
  Future<bool> mintaIzinAlarmTepat() async => true;

  @override
  Future<void> pasangJadwal(List<Pengingat> daftar) async {}

  @override
  Future<void> batalkanSemua() async {}

  @override
  Future<void> jadwalkanSatu(Pengingat p) async {}

  @override
  Future<void> tampilkanUji({Duration tunda = const Duration(seconds: 10)}) async {}

  @override
  Future<List<({int id, String? judul, DateTime? waktu})>> tertunda() async => [
        (id: 1, judul: 'Listrik PLN — 3 hari lagi', waktu: DateTime.now().add(const Duration(days: 3))),
        (id: 2, judul: 'Internet IndiHome — besok', waktu: DateTime.now().add(const Duration(days: 1))),
      ];
}

late AppDatabase _db;
