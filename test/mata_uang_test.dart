/// FR-67: format mata uang lokal (Rupiah & Ringgit) dan bahasa layar.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/utils/mata_uang.dart';
import 'package:personal_life_os/core/utils/uang_utils.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/features/pengaturan/mata_uang_pengaturan.dart';
import 'package:personal_life_os/features/pengaturan/pengaturan_screen.dart';

/// Istilah Inggris yang tidak perlu di layar berbahasa Indonesia.
const _kataInggris = [
  'save',
  'cancel',
  'delete',
  'edit',
  'settings',
  'search',
  'bills',
  'monthly',
  'expense',
  'income',
  'cash flow',
  'net worth',
  'add new',
];

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  tearDown(() => pakaiMataUang(MataUang.idr));

  group('FR-67 format uang', () {
    test('bawaan Rupiah memakai format Indonesia (tanpa desimal)', () {
      pakaiMataUang(MataUang.idr);
      expect(mataUangAktif, MataUang.idr);
      expect(fmtRpDariSen(45000000), 'Rp 450.000');
      expect(fmtUang(1250000), 'Rp 1.250.000');
      expect(fmtRpDariSen(0), 'Rp 0');
    });

    test('Ringgit memakai format Malaysia (dua desimal)', () {
      pakaiMataUang(MataUang.myr);
      expect(fmtRpDariSen(45000000), startsWith('RM '));
      expect(fmtRpDariSen(45000000), contains('450,000.00'));
      // fmtRpDariSen tetap menghormati mata uang aktif, bukan Rp tetap.
      expect(fmtRpDariSen(45000000).contains('Rp'), isFalse);
    });

    test('parameter mataUang tidak mengubah pilihan aktif', () {
      pakaiMataUang(MataUang.idr);
      expect(fmtUangDariSen(100, mataUang: MataUang.myr), contains('RM'));
      expect(mataUangAktif, MataUang.idr);
    });

    test('kode tak dikenal kembali ke Rupiah', () {
      expect(mataUangDariKode('MYR'), MataUang.myr);
      expect(mataUangDariKode('idr'), MataUang.idr);
      expect(mataUangDariKode('USD'), MataUang.idr);
      expect(mataUangDariKode(null), MataUang.idr);
      expect(mataUangDariKode(''), MataUang.idr);
    });
  });

  group('FR-67 pilihan mata uang di Pengaturan', () {
    late AppDatabase db;

    Future<void> tampilkan(WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: PengaturanScreen())),
      ));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> tutup(WidgetTester t) async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await db.close();
      await t.binding.setSurfaceSize(null);
    }

    testWidgets('bawaan tertulis Rupiah (Rp) di layar Pengaturan',
        (t) async {
      await tampilkan(t);
      expect(find.text('Mata uang'), findsWidgets);
      expect(find.text('Rupiah (Rp)'), findsWidgets);
      await tutup(t);
    });

    testWidgets('memilih Ringgit tersimpan di tabel pengaturan & langsung dipakai',
        (t) async {
      await tampilkan(t);
      final tuj = find.byKey(const Key('pilih_mata_uang'));
      await t.ensureVisible(tuj);
      await t.pump(const Duration(milliseconds: 50));
      await t.tap(tuj);
      await t.pumpAndSettle(const Duration(milliseconds: 50));
      await t.tap(find.text('Ringgit (RM)').last);
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(mataUangAktif, MataUang.myr);
      expect(find.text('Ringgit (RM)'), findsWidgets);

      // Tersimpan permanen (dibaca ulang dari database yang sama).
      final baca = await t.runAsync(() => bacaMataUang(db));
      expect(baca, MataUang.myr);

      // Dibuka ulang: pilihan tidak hilang.
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: PengaturanScreen())),
      ));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Ringgit (RM)'), findsWidgets);
      await tutup(t);
    });

    testWidgets('tidak ada istilah Inggris yang tidak perlu (FR-67)',
        (t) async {
      await tampilkan(t);
      final teks = t
          .widgetList<Text>(find.byType(Text))
          .map((w) => (w.data ?? '').toLowerCase())
          .toList();
      final gabung = teks.join(' | ');
      for (final kata in _kataInggris) {
        expect(gabung.contains(kata), isFalse,
            reason: 'layar memuat istilah Inggris "$kata"');
      }
      await tutup(t);
    });
  });
}
