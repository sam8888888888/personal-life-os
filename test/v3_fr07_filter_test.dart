/// Uji FR-07 — pencarian & filter tagihan (kategori, status, bulan, terlambat).
///
/// Diuji lewat LAYAR: Ron mengisi kotak pencarian dan memilih saringan seperti
/// pengguna, lalu memeriksa tagihan mana yang tampil.
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/tagihan/daftar_tagihan_screen.dart';

late AppDatabase db;

/// Waktu uji: 15 Sep 2026 → "terlambat" = jatuh tempo sebelum hari itu.
final DateTime waktuUji = DateTime(2026, 9, 15, 10);

Future<int> tambah(AppDatabase db, String nama, DateTime jatuhTempo,
    {String? catatan, int? jumlahSen}) async {
  final t = await TagihanRepository(db).tambah(TagihanCompanion.insert(
    nama: nama,
    jatuhTempo: jatuhTempo,
    catatan: Value(catatan),
    jumlahSen: Value(jumlahSen ?? 100000),
  ));
  return t.id;
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() async => db.close());

  Future<void> tampilkan(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(430, 950));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          // Layar ini mengembalikan Column (dipasang di dalam kerangka aplikasi),
          // jadi saat diuji perlu dibungkus Scaffold supaya Material tersedia.
          builder: (c, s) => Scaffold(
              body: DaftarTagihanScreen(sekarang: () => waktuUji)),
        ),
        GoRoute(path: '/ubah/:id', builder: (c, s) => const Scaffold()),
      ],
    );
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ));
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> tutup(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 50));
    await t.binding.setSurfaceSize(null);
  }

  testWidgets('pencarian menyaring menurut nama & catatan', (t) async {
    await tambah(db, 'Listrik PLN', DateTime(2026, 9, 20));
    await tambah(db, 'Internet Indihome', DateTime(2026, 9, 21),
        catatan: 'paket 50 Mbps');
    await tampilkan(t);

    expect(find.text('Listrik PLN'), findsOneWidget);
    expect(find.text('Internet Indihome'), findsOneWidget);

    await t.enterText(find.byKey(const Key('cari_tagihan')), 'listrik');
    await t.pumpAndSettle();
    expect(find.text('Listrik PLN'), findsOneWidget);
    expect(find.text('Internet Indihome'), findsNothing);

    // Pencarian juga menembus catatan.
    await t.enterText(find.byKey(const Key('cari_tagihan')), '50 mbps');
    await t.pumpAndSettle();
    expect(find.text('Internet Indihome'), findsOneWidget);
    expect(find.text('Listrik PLN'), findsNothing);

    // Kosongkan → semua tampil lagi.
    await t.enterText(find.byKey(const Key('cari_tagihan')), '');
    await t.pumpAndSettle();
    expect(find.text('Listrik PLN'), findsOneWidget);
    expect(find.text('Internet Indihome'), findsOneWidget);
    await tutup(t);
  });

  testWidgets('saringan bulan hanya menampilkan bulan yang dipilih', (t) async {
    await tambah(db, 'Tagihan September', DateTime(2026, 9, 20));
    await tambah(db, 'Tagihan Oktober', DateTime(2026, 10, 5));
    await tampilkan(t);
    expect(find.text('Tagihan September'), findsOneWidget);
    expect(find.text('Tagihan Oktober'), findsOneWidget);

    await t.ensureVisible(find.byKey(const Key('pilih_bulan_tagihan')));
    await t.tap(find.byKey(const Key('pilih_bulan_tagihan')));
    await t.pumpAndSettle();
    await t.tap(find.text('Okt 2026').last);
    await t.pumpAndSettle();

    expect(find.text('Tagihan Oktober'), findsOneWidget);
    expect(find.text('Tagihan September'), findsNothing);
    await tutup(t);
  });

  testWidgets('saringan "Terlambat" hanya menampilkan yang lewat jatuh tempo',
      (t) async {
    await tambah(db, 'Sudah lewat', DateTime(2026, 9, 1)); // sebelum 15 Sep
    await tambah(db, 'Masih jauh', DateTime(2026, 9, 28));
    await tampilkan(t);

    await t.ensureVisible(find.byKey(const Key('chip_terlambat')));
    await t.tap(find.byKey(const Key('chip_terlambat')));
    await t.pumpAndSettle();
    expect(find.text('Sudah lewat'), findsOneWidget);
    expect(find.text('Masih jauh'), findsNothing);

    // Yang sudah lunas tidak lagi dihitung terlambat.
    final idLunas = (await (db.select(db.tagihan)
              ..where((x) => x.nama.equals('Sudah lewat')))
            .getSingle())
        .id;
    await TagihanRepository(db).tandaiLunas(idLunas,
        tanggalBayar: DateTime(2026, 9, 2));
    await t.pumpAndSettle();
    expect(find.text('Sudah lewat'), findsNothing,
        reason: 'sudah dibayar → tidak terlambat lagi');
    await tutup(t);
  });

  testWidgets('kombinasi pencarian + kategori + bulan bekerja bersama',
      (t) async {
    final kategori = await db.into(db.kategori).insertReturning(
        KategoriCompanion.insert(nama: 'Rumah'));
    await tambah(db, 'Listrik Rumah', DateTime(2026, 9, 22),
        catatan: 'rumah utama');
    await db.into(db.tagihan).insert(TagihanCompanion.insert(
          nama: 'Air Rumah',
          jatuhTempo: DateTime(2026, 10, 22),
          kategoriId: Value(kategori.id),
        ));
    await db.into(db.tagihan).insert(TagihanCompanion.insert(
          nama: 'Listrik Kantor',
          jatuhTempo: DateTime(2026, 9, 23),
          kategoriId: Value(kategori.id),
        ));
    await tampilkan(t);

    await t.enterText(find.byKey(const Key('cari_tagihan')), 'listrik');
    await t.pumpAndSettle();
    await t.tap(find.byKey(ValueKey('kategori_chip_${kategori.id}')));
    await t.pumpAndSettle();

    expect(find.text('Listrik Rumah'), findsOneWidget);
    expect(find.text('Listrik Kantor'), findsOneWidget);
    expect(find.text('Air Rumah'), findsNothing);

    await t.ensureVisible(find.byKey(const Key('pilih_bulan_tagihan')));
    await t.tap(find.byKey(const Key('pilih_bulan_tagihan')));
    await t.pumpAndSettle();
    await t.tap(find.text('Okt 2026').last);
    await t.pumpAndSettle();
    // Tidak ada yang cocok: Oktober tidak punya tagihan "listrik" ber-kategori Rumah.
    expect(find.textContaining('Tidak ada tagihan'), findsOneWidget);
    await tutup(t);
  });
}
