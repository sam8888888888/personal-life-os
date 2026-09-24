/// Uji jalur menu "Lainnya" → layar tujuan (regresi 24 Sep 2026).
///
/// Yang dibuktikan: setiap butir menu benar-benar MEMBUKA layarnya lewat
/// router yang sama seperti di HP (bukan hanya widget layarnya dipanggil
/// langsung), dan dua layar simpan (Catat Cepat, Catatan Harian) serta
/// Orang & Kontak benar-benar menulis ke SQLite dari jalur itu.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/app_router.dart';
import 'package:personal_life_os/core/providers/akun_providers.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/catatan_harian_repository.dart';
import 'package:personal_life_os/data/repository/kotak_masuk_repository.dart';

void main() {
  late AppDatabase db;
  late KotakMasukRepository kotakMasuk;
  late CatatanHarianRepository catatan;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    kotakMasuk = KotakMasukRepository(db);
    catatan = CatatanHarianRepository(db);
  });

  tearDown(() async => db.close());

  /// Buka menu Lainnya lewat router sungguhan — `context.push` di layar menu
  /// butuh GoRouter, jadi layar tidak boleh dipanggil tanpa router.
  Future<void> bukaMenu(WidgetTester t) async {
    final router = buatRouter(awal: '/lainnya');
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sesiAkunProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          theme: AppTema.terang(),
          routerConfig: router,
        ),
      ),
    );
    await t.pumpAndSettle();
    addTearDown(router.dispose);
  }

  Future<void> tulis(WidgetTester t, Key isi, Key simpan, String teks) async {
    await t.enterText(find.byKey(isi), teks);
    await t.ensureVisible(find.byKey(simpan));
    await t.tap(find.byKey(simpan));
    // Penulisan basis data butuh waktu nyata (waktu uji dipalsukan).
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }

  group('jalur menu Lainnya', () {
    testWidgets('Semua Fitur membuka peta fitur, bukan layar kosong',
        (t) async {
      await bukaMenu(t);

      await t.tap(find.byKey(const Key('buka_peta_fitur')));
      await t.pumpAndSettle();

      expect(find.text('Semua Fitur'), findsWidgets);
      expect(find.byKey(const Key('peta_ringkas')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Catat Cepat membuka layarnya dan menyimpan isian', (t) async {
      await bukaMenu(t);

      await t.tap(find.byKey(const Key('buka_kotak_masuk')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('km_judul_antrean')), findsOneWidget);

      await tulis(t, const Key('km_isi'), const Key('km_simpan'), 'beli galon');

      expect(await kotakMasuk.jumlahBaru(), 1);
      expect(find.textContaining('beli galon'), findsWidgets);
      expect(t.takeException(), isNull);
    });

    testWidgets('Catatan Harian membuka layarnya dan menyimpan tulisan',
        (t) async {
      await bukaMenu(t);

      await t.tap(find.byKey(const Key('buka_catatan_harian')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ch_tanggal')), findsOneWidget);

      await tulis(
        t,
        const Key('ch_isi'),
        const Key('ch_simpan'),
        'hari yang tenang',
      );

      final CatatanHarianData baris = await catatan.halaman(DateTime.now());
      expect(baris.isi, 'hari yang tenang');
      expect(t.takeException(), isNull);
    });

    testWidgets('Orang & Kontak membuka layarnya dan menyimpan kontak',
        (t) async {
      await bukaMenu(t);

      await t.tap(find.byKey(const Key('buka_orang')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('orang_nama')), findsOneWidget);

      await tulis(
        t,
        const Key('orang_nama'),
        const Key('orang_simpan'),
        'Kontak Uji',
      );

      final List<OrangData> baris = await db.select(db.orang).get();
      expect(baris, hasLength(1));
      expect(baris.single.nama, 'Kontak Uji');
      expect(t.takeException(), isNull);
    });
  });

  group('jalur router langsung', () {
    testWidgets('Akun & Sinkron terbuka tanpa layar kosong', (t) async {
      final router = buatRouter(awal: '/akun');
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sesiAkunProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp.router(
            theme: AppTema.terang(),
            routerConfig: router,
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('Akun & Sinkron'), findsWidgets);
      expect(t.takeException(), isNull);
      router.dispose();
    });

    testWidgets('Semua Fitur terbuka tanpa layar kosong', (t) async {
      final router = buatRouter(awal: '/peta-fitur');
      await t.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            theme: AppTema.terang(),
            routerConfig: router,
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(find.byKey(const Key('peta_ringkas')), findsOneWidget);
      expect(t.takeException(), isNull);
      router.dispose();
    });
  });
}
