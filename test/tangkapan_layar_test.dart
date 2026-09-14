/// Pembuat tangkapan layar demo (F2) — merender aplikasi sungguhan pada ukuran
/// ponsel 420x900 dengan font Roboto asli dari Flutter SDK.
///
/// Jalankan:  flutter test test/tangkapan_layar_test.dart --update-goldens
/// Hasil PNG muncul di test/goldens/, lalu disalin ke folder demo/.
library;

import 'dart:convert';
import 'package:personal_life_os/core/utils/waktu.dart';
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
import 'package:personal_life_os/core/ibadah/penyimpanan_log_sholat.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/features/ibadah/jadwal_sholat_screen.dart';
import 'package:personal_life_os/features/hari_ini/briefing_pagi_screen.dart';
import 'package:personal_life_os/features/ibadah/kalender_hijriah_screen.dart';
import 'package:personal_life_os/features/ibadah/pelacakan_sholat_screen.dart';

/// Font Roboto dari Flutter SDK. Dicari di beberapa lokasi agar uji
/// tangkapan layar tetap bisa jalan di mesin build mana pun.
String _cariFontDasar() {
  const kandidat = [
    '/workspace/tools/flutter/bin/cache/artifacts/material_fonts/',
    '/opt/tools/flutter/bin/cache/artifacts/material_fonts/',
  ];
  for (final p in kandidat) {
    if (Directory(p).existsSync()) return p;
  }
  return kandidat.first;
}

final String _fontDasar = _cariFontDasar();

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

/// Waktu dikunci supaya tangkapan layar tidak berubah saat tanggal berganti
/// (kalender menandai "hari ini", label "besok"/"N hari lagi").
final DateTime _waktuUji = DateTime(2026, 9, 10, 9, 0);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    pakaiSumberWaktu(() => _waktuUji);
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
    await PengaturanRepository(db).isiContohData(acuan: _waktuUji);
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

  tearDownAll(pakaiWaktuAsli);

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

  testWidgets('tangkapan layar ringkasan',
      (t) => potret(t, 'ringkasan', '/ringkasan'),
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

  // ---- V1.5 Modul 0: 5 TAB + Ringkasan pagi + Pelacakan sholat -------------
  // Tangkapan tab memakai rute sungguhan lewat [potret]; tanggal mengikuti hari
  // berjalan, jadi tangkapan ini harus dibuat ulang bila ganti hari/UI:
  //   flutter test test/tangkapan_layar_test.dart --update-goldens
  testWidgets('tangkapan layar tab hari ini',
      (t) => potret(t, 'today', '/today', prefiks: 'f5'),
      skip: !_fontTersedia);
  testWidgets('tangkapan layar tab uang',
      (t) => potret(t, 'uang', '/uang', prefiks: 'f5'),
      skip: !_fontTersedia);
  testWidgets('tangkapan layar tab kerja',
      (t) => potret(t, 'kerja', '/kerja', prefiks: 'f5'),
      skip: !_fontTersedia);
  testWidgets('tangkapan layar tab ibadah',
      (t) => potret(t, 'ibadah', '/ibadah', prefiks: 'f5'),
      skip: !_fontTersedia);
  testWidgets('tangkapan layar tab lainnya',
      (t) => potret(t, 'lainnya', '/lainnya', prefiks: 'f5'),
      skip: !_fontTersedia);
  // Ringkasan pagi memuat hitung mundur waktu sholat, jadi jamnya DIPATOK;
  // kalau memakai rute biasa isinya berubah setiap menit dan uji emas gagal.
  Future<void> potretBriefing(WidgetTester tester, String nama) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(_db)],
      child: MaterialApp(
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
        home: BriefingPagiScreen(jamSekarang: () => DateTime(2026, 9, 13, 9)),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/f5_$nama.png'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('tangkapan layar ringkasan pagi',
      (t) => potretBriefing(t, 'briefing'),
      skip: !_fontTersedia);

  // FR-88: layar pelacakan sholat, sudah berisi 3 dari 5 waktu tercatat.
  // Jam dipatok (bukan DateTime.now) supaya isi tangkapan layar tetap sama.
  Future<void> potretPelacakan(WidgetTester tester, String nama) async {
    final Directory dir = Directory.systemTemp.createTempSync('demo_log_');
    File('${dir.path}/log_sholat.json').writeAsStringSync(jsonEncode(<String, dynamic>{
      'versi': 1,
      'diubah': '2026-09-13T00:00:00.000Z',
      'hari': <String, dynamic>{
        '2026-09-13': <String>['subuh', 'dzuhur', 'ashar'],
      },
    }));
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
      home: PelacakanSholatScreen(
        // 13 Sep 2026, 03.00 WIB -> tanggal sipil kota 2026-09-13.
        jamSekarang: () => DateTime.utc(2026, 9, 12, 20, 0),
        penyimpanan: PenyimpananJadwal(
          penentuFolder: () => Future.value(dir),
        ),
        penyimpananLog: PenyimpananLogSholat(
          penentuFolder: () => Future.value(dir),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/f5_$nama.png'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('tangkapan layar pelacakan sholat',
      (t) => potretPelacakan(t, 'pelacakan_sholat'),
      skip: !_fontTersedia);
}

/// Layanan notifikasi contoh: hasil tetap agar tangkapan layar stabil.
class _LayananDemo implements LayananNotifikasi {
  // PB-09/PB-10: bagian diagnostik antarmuka (nilai bawaan untuk uji).
  @override
  HasilPasang? get hasilPasangTerakhir => null;

  @override
  bool get siap => true;

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
        (id: 1, judul: 'Listrik PLN — 3 hari lagi', waktu: waktuSekarang().add(const Duration(days: 3))),
        (id: 2, judul: 'Internet IndiHome — besok', waktu: waktuSekarang().add(const Duration(days: 1))),
      ];
}

late AppDatabase _db;
