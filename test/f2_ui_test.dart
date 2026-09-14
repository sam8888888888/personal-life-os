/// Uji UI Fase 2 — gate: UC-1 (tambah tagihan), UC-2 (daftar + kalender),
/// UC-5 (uang tersisa).
///
/// Catatan teknis: data uji disiapkan di `setUp` (zona async nyata) dan
/// diverifikasi lewat tampilan UI, bukan `await` langsung ke database, karena
/// widget test memakai zon waktu palsu.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/app_router.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/core/utils/uang_utils.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';

late AppDatabase db;
late DateTime kini;

Future<void> isiDuaTagihan() async {
  final repo = TagihanRepository(db);
  await repo.tambah(TagihanCompanion.insert(
      nama: 'Internet IndiHome',
      jumlahSen: const Value(38500000),
      jatuhTempo: DateTime(kini.year, kini.month, 15, 9)));
  await repo.tambah(TagihanCompanion.insert(
      nama: 'PDAM Surabaya',
      jumlahSen: const Value(12500000),
      jatuhTempo: DateTime(kini.year, kini.month, 20, 9)));
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    kini = DateTime.now();
    TestWidgetsFlutterBinding.ensureInitialized(); // dipakai uji tata letak
  });
  tearDown(() => db.close());

  // Semua uji dijalankan pada ukuran layar ponsel (bukan 800x600 bawaan),
  // supaya tata letak yang diuji sama seperti perangkat sungguhan.
  Future<void> layarPonsel(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(420, 900));
  }

  /// Gulir sampai target benar-benar terlihat, baru ketuk.
  /// (Tap pada widget di luar area terlihat tidak akan diterima.)
  Future<void> ketukTerlihat(WidgetTester t, Finder target) async {
    await t.ensureVisible(target);
    // tunggu animasi gulir selesai: selama menggulir, Scrollable mengabaikan
    // sentuhan sehingga ketukan bisa meleset
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    await t.tap(target);
    await t.pump();
  }

  Future<void> buka(WidgetTester t, {String awal = '/'}) async {
    await layarPonsel(t);
    await t.pumpWidget(ProviderScope(
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
        routerConfig: buatRouter(awal: awal),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  /// Bongkar pohon widget lalu majukan waktu agar timer drift tuntas.
  Future<void> tutup(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 50));
    await t.binding.setSurfaceSize(null); // kembalikan ukuran layar uji
  }

  testWidgets('UC-1: isi form dari nol lalu simpan (alur aplikasi nyata)',
      (tester) async {
    await buka(tester);
    expect(find.text('Belum ada tagihan tercatat.'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Tambah Tagihan'), findsOneWidget);

    final kolom = find.byType(TextFormField);
    await tester.enterText(kolom.at(0), 'Listrik PLN');
    await tester.enterText(kolom.at(1), '250rb');
    await tester.pump();
    await ketukTerlihat(tester, find.text('Simpan tagihan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Tambah Tagihan'), findsNothing); // form sudah tertutup
    expect(find.text('Listrik PLN'), findsWidgets);
    expect(find.text(fmtRp(250000)), findsWidgets);
    await tutup(tester);
  });

  testWidgets('UC-1: chip template mengisi nama & jumlah otomatis',
      (tester) async {
    await buka(tester, awal: '/tambah');
    await tester.tap(find.widgetWithText(ActionChip, 'Listrik PLN').first);
    await tester.pump();

    final nama = tester.widget<TextFormField>(find.byType(TextFormField).at(0));
    expect(nama.controller!.text, 'Listrik PLN');
    final jumlah = tester.widget<TextFormField>(find.byType(TextFormField).at(1));
    expect(int.parse(jumlah.controller!.text), greaterThan(100000));
    await tutup(tester);
  });

  testWidgets('UC-1: form menolak nama kosong & jumlah tidak valid',
      (tester) async {
    await buka(tester, awal: '/tambah');
    final kolom = find.byType(TextFormField);
    await tester.enterText(kolom.at(1), 'abc'); // jumlah tidak valid
    await ketukTerlihat(tester, find.text('Simpan tagihan'));
    await tester.pump(const Duration(milliseconds: 300));

    // form tidak tertutup => penyimpanan ditolak
    expect(find.text('Tambah Tagihan'), findsOneWidget);

    // pesan galat harus ada pada kedua kolom
    expect(find.text('Nama tagihan wajib diisi'), findsOneWidget);
    expect(find.text('Jumlah tidak valid'), findsOneWidget);
    await tutup(tester);
  });

  group('dengan dua tagihan bulan ini', () {
    setUp(() async => isiDuaTagihan());

    testWidgets('UC-2: daftar tagihan menampilkan tagihan & total belum dibayar',
        (tester) async {
      await buka(tester, awal: '/tagihan');
      expect(find.text('Internet IndiHome'), findsOneWidget);
      expect(find.text('PDAM Surabaya'), findsOneWidget);
      expect(find.textContaining('Rp 510.000'), findsWidgets);
      expect(find.textContaining('2 tagihan'), findsWidgets);
      await tutup(tester);
    });

    testWidgets('UC-2: filter "Sudah dibayar" kosong sebelum ada pelunasan',
        (tester) async {
      await buka(tester, awal: '/tagihan');
      await tester.tap(find.widgetWithText(FilterChip, 'Sudah dibayar'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Tidak ada tagihan di filter ini.'), findsOneWidget);
      await tutup(tester);
    });

    testWidgets('UC-2: kalender menampilkan tagihan per tanggal', (tester) async {
      await buka(tester, awal: '/kalender');
      expect(find.textContaining('2 tagihan'), findsOneWidget);

      await tester.tap(find.text('15'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Internet IndiHome'), findsOneWidget);
      expect(find.text('PDAM Surabaya'), findsNothing);

      await tester.tap(find.text('20'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('PDAM Surabaya'), findsOneWidget);
      await tutup(tester);
    });
  });

  testWidgets('UC-5: uang tersisa = pemasukan - tagihan belum dibayar',
      (tester) async {
    final repo = TagihanRepository(db);
    await repo.tambah(TagihanCompanion.insert(
        nama: 'Cicilan motor',
        jumlahSen: const Value(70000000),
        jatuhTempo: DateTime(kini.year, kini.month, 25, 9)));
    await PengaturanRepository(db).simpanPemasukan(DateTime.now(), 1200000000);

    await buka(tester);
    expect(find.text('Rp 11.300.000'), findsOneWidget); // 12jt - 700rb
    expect(find.textContaining('Rp 700.000'), findsWidgets);
    await tutup(tester);
  });

  testWidgets('Pengaturan: pemasukan tersimpan & terpakai di dasbor',
      (tester) async {
    await buka(tester, awal: '/pengaturan');
    await tester.enterText(find.byType(TextField).first, '8jt');
    await tester.tap(find.text('Simpan pemasukan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // pindah ke dasbor: uang tersisa = Rp 8.000.000
    await tester.tap(find.byIcon(Icons.dashboard_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Rp 8.000.000'), findsWidgets);
    await tutup(tester);
  });
}
