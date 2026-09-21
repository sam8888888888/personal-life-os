/// Uji FR-45 — tombol "Bagikan" laporan bulanan (PDF & CSV).
///
/// Yang dibuktikan:
///   * menekan "Bagikan PDF" benar-benar membuat berkas PDF nyata lebih dulu,
///     lalu memanggil kanal `lifeos/bagikan` dengan jalur berkas itu,
///   * kanal menerima judul & jenis berkas yang benar,
///   * bila perangkat tidak mendukung (kanal menjawab false / tidak ada
///     penangan), pengguna diberi tahu apa adanya beserta lokasi berkasnya —
///     tidak ada klaim "terkirim" palsu,
///   * jembatan Dart mengembalikan false (bukan melempar galat) saat kanal
///     tidak tersedia.
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:personal_life_os/core/platform/bagikan.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/core/utils/uang_utils.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/features/laporan/laporan_bulanan_screen.dart';

late AppDatabase db;
late Directory folder;

/// Waktu patok uji: Selasa, 15 September 2026 08.00.
final jamUji = DateTime(2026, 9, 15, 8);

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    folder = Directory.systemTemp.createTempSync('lifeos_bagikan_');
  });

  tearDown(() async {
    await db.close();
    if (folder.existsSync()) folder.deleteSync(recursive: true);
  });

  Future<void> isiData(WidgetTester t) async {
    await t.runAsync(() async {
      await db.batch((b) {
        b.insertAll(db.transaksi, [
          TransaksiCompanion.insert(
            idTransaksi: 'trx_gaji_sep',
            jenis: const Value('pemasukan'),
            tanggal: DateTime(2026, 9, 1),
            jumlahSen: rupiahKeSen(5000000),
          ),
          TransaksiCompanion.insert(
            idTransaksi: 'trx_makan_sep',
            tanggal: DateTime(2026, 9, 5),
            jumlahSen: rupiahKeSen(400000),
          ),
        ]);
      });
    });
  }

  Future<void> tampilkan(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(420, 900));
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTema.terang(),
        home: LaporanBulananScreen(
          jamSekarang: () => jamUji,
          folderLaporan: () async => folder,
        ),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> gulirKe(WidgetTester t, Finder target) async {
    await t.scrollUntilVisible(
      target,
      260,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 40,
    );
    await t.pump(const Duration(milliseconds: 100));
  }

  Future<void> tekan(WidgetTester t, Key kunci) async {
    final target = find.byKey(kunci);
    await gulirKe(t, target);
    await t.tap(target);
    await t.pump(const Duration(milliseconds: 150));
  }

  /// Beri kesempatan I/O nyata (bangun PDF, tulis berkas, panggil kanal).
  Future<void> tungguMuncul(WidgetTester t, Key kunci) async {
    for (var putaran = 0; putaran < 40; putaran++) {
      if (find.byKey(kunci).evaluate().isNotEmpty) break;
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)));
      await t.pump(const Duration(milliseconds: 40));
    }
  }

  Future<void> tutup(WidgetTester t) async {
    await t.pump(const Duration(seconds: 10));
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 50));
    await t.binding.setSurfaceSize(null);
  }

  testWidgets('Bagikan PDF: berkas dibuat dulu lalu kanal dipanggil', (t) async {
    final panggilan = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(kanalBagikan), (c) async {
      panggilan.add(c);
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(kanalBagikan), null));

    await isiData(t);
    await tampilkan(t);
    await tekan(t, const Key('bagikan_pdf'));
    await tungguMuncul(t, const Key('hasil_bagikan'));

    // Kanal dipanggil dengan berkas yang benar-benar ada di disk.
    expect(panggilan, hasLength(1));
    expect(panggilan.first.method, 'bagikan');
    final argumen = panggilan.first.arguments as Map;
    final jalur = argumen['jalur'] as String;
    expect(jalur, endsWith(p.join('', 'plo_laporan_202609.pdf')));
    expect(argumen['jenis'], 'application/pdf');
    expect(argumen['judul'], contains('September 2026'));

    final berkas = File(jalur);
    expect(berkas.existsSync(), isTrue);
    expect(berkas.lengthSync(), greaterThan(1000));
    expect(String.fromCharCodes(berkas.readAsBytesSync().sublist(0, 5)), '%PDF-');

    final snack = t.widget<SnackBar>(find.byKey(const Key('hasil_bagikan')));
    expect((snack.content as Text).data, contains('dikirim ke aplikasi lain'));
    await tutup(t);
  });

  testWidgets('Bagikan CSV: jenis berkas text/csv & isinya berkepala kolom',
      (t) async {
    final panggilan = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(kanalBagikan), (c) async {
      panggilan.add(c);
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(kanalBagikan), null));

    await isiData(t);
    await tampilkan(t);
    await tekan(t, const Key('bagikan_csv'));
    await tungguMuncul(t, const Key('hasil_bagikan'));

    final argumen = panggilan.first.arguments as Map;
    expect(argumen['jenis'], 'text/csv');
    final berkas = File(argumen['jalur'] as String);
    expect(berkas.existsSync(), isTrue);
    expect(berkas.readAsStringSync(),
        startsWith('tanggal;kategori;jenis;jumlah;catatan'));
    await tutup(t);
  });

  testWidgets('Perangkat tak mendukung: pesan jujur + lokasi berkas', (t) async {
    // Kanal sengaja menjawab false (mis. tidak ada aplikasi penerima).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(kanalBagikan),
            (c) async => false);
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(kanalBagikan), null));

    await isiData(t);
    await tampilkan(t);
    await tekan(t, const Key('bagikan_pdf'));
    await tungguMuncul(t, const Key('hasil_bagikan'));

    final snack = t.widget<SnackBar>(find.byKey(const Key('hasil_bagikan')));
    final teks = (snack.content as Text).data ?? '';
    expect(teks, contains('Belum bisa dibagikan otomatis'));
    expect(teks, contains('plo_laporan_202609.pdf'));
    await tutup(t);
  });

  test('jembatan Dart: kanal tidak tersedia → false, tidak melempar galat',
      () async {
    // Tanpa mock: di lingkungan uji kanal tidak punya penangan.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(kanalBagikan),
            (c) async => throw MissingPluginException('tidak ada kanal'));
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(kanalBagikan), null));

    final hasil = await bagikanBerkas(jalur: '/tmp/tidak-ada.pdf');
    expect(hasil, isFalse);
  });
}
