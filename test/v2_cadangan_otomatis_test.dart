/// Uji FR-137 — cadangan otomatis, rotasi, dan pemeriksaan keutuhan.
///
/// Uji ini memakai folder sementara sendiri, jadi TIDAK menyentuh folder
/// dokumen aplikasi yang sebenarnya.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/backup/cadangan_otomatis.dart';
import 'package:personal_life_os/core/backup/ekspor_impor.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/features/ibadah/pengaturan_ibadah.dart';
import 'package:personal_life_os/features/pengaturan/backup_screen.dart';
import 'package:personal_life_os/features/pengaturan/cadangan_otomatis_layanan.dart';

void main() {
  group('FR-137 hitungan murni', () {
    test('keputusan perlu cadangan otomatis', () {
      final DateTime t0 = DateTime(2026, 9, 17, 8);
      expect(
          perluCadanganOtomatis(
              aktif: false, terakhir: null, sekarang: t0, jedaHari: 7),
          isFalse);
      expect(
          perluCadanganOtomatis(
              aktif: true, terakhir: null, sekarang: t0, jedaHari: 7),
          isTrue);
      expect(
          perluCadanganOtomatis(
              aktif: true,
              terakhir: DateTime(2026, 9, 15, 8),
              sekarang: t0,
              jedaHari: 7),
          isFalse);
      expect(
          perluCadanganOtomatis(
              aktif: true,
              terakhir: DateTime(2026, 9, 10, 8),
              sekarang: t0,
              jedaHari: 7),
          isTrue);
      expect(batasiJedaCadangan(0), 1);
      expect(batasiJedaCadangan(500), 90);
    });

    test('rotasi hanya memutar berkas di luar jumlah simpan', () {
      expect(namaKedaluwarsa(<String>[], simpan: 3), isEmpty);
      expect(namaKedaluwarsa(<String>['a', 'b', 'c'], simpan: 3), isEmpty);
      expect(namaKedaluwarsa(<String>['a', 'b', 'c', 'd'], simpan: 3),
          <String>['a']);
      expect(
          namaKedaluwarsa(
              <String>['a', 'a', '', 'b', 'c', 'd', 'e'], simpan: 3),
          <String>['a', 'b']);
      // Jumlah simpan 0 tetap berarti menyimpan 1 berkas terbaru.
      expect(namaKedaluwarsa(<String>['a'], simpan: 0), isEmpty);
      expect(namaKedaluwarsa(<String>['a', 'b'], simpan: 0), <String>['a']);
    });

    test('nama berkas cadangan otomatis', () {
      expect(namaBerkasCadanganOtomatis(DateTime(2026, 9, 17, 8, 5)),
          'plo_auto_20260917_0805.json');
    });

    test('sisa waktu cadangan', () {
      expect(
          sisaWaktuCadangan(
              aktif: false,
              terakhir: DateTime(2026, 9, 10),
              sekarang: DateTime(2026, 9, 17),
              jedaHari: 7),
          isNull);
      expect(
          sisaWaktuCadangan(
              aktif: true,
              terakhir: DateTime(2026, 9, 16, 9),
              sekarang: DateTime(2026, 9, 17, 9),
              jedaHari: 7),
          const Duration(days: 6));
      expect(
          sisaWaktuCadangan(
              aktif: true,
              terakhir: DateTime(2026, 9, 1),
              sekarang: DateTime(2026, 9, 17),
              jedaHari: 7),
          Duration.zero);
    });
  });

  group('FR-137 layanan cadangan otomatis', () {
    late AppDatabase db;
    late Directory dir;
    late DateTime jam;
    late LayananCadangan cadangan;
    late LayananCadanganOtomatis otomatis;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dir = Directory.systemTemp.createTempSync('uji_auto_');
      jam = DateTime(2026, 9, 17, 9);
      cadangan = LayananCadangan(
          db: db, penentuFolder: () async => dir, jam: () => jam);
      otomatis = LayananCadanganOtomatis(
        setelan: SetelanBasisData(PengaturanRepository(db)),
        cadangan: cadangan,
        jam: () => jam,
      );
    });

    tearDown(() async {
      await db.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    List<String> berkasCadangan() => dir
        .listSync()
        .whereType<File>()
        .map((File f) => f.uri.pathSegments.last)
        .toList()
      ..sort();

    test('bawaan MATI: cadangan otomatis tidak berjalan sendiri', () async {
      expect(await otomatis.aktif(), isFalse);
      final HasilCadanganOtomatis hasil = await otomatis.jalankan();
      expect(hasil.dijalankan, isFalse);
      expect(berkasCadangan(), isEmpty);
    });

    test('menyala: cadangan dibuat, terakhir dicatat, keutuhan diperiksa',
        () async {
      await otomatis.setAktif(true);
      expect(await otomatis.aktif(), isTrue);
      final HasilCadanganOtomatis hasil = await otomatis.jalankan();
      expect(hasil.dijalankan, isTrue);
      expect(hasil.namaBerkas, isNotNull);
      expect(hasil.totalBaris > 0, isTrue, reason: 'cadangan kosong?');
      expect(berkasCadangan(), contains(hasil.namaBerkas));
      expect(await otomatis.terakhir(), jam);
      expect(await otomatis.daftar(), <String>[hasil.namaBerkas!]);

      final HasilPeriksaKeutuhan? periksa = hasil.keutuhan;
      expect(periksa == null, isFalse);
      expect(periksa!.utuh, isTrue);
      expect(periksa.versiSkema, db.schemaVersion);
      expect(await otomatis.periksaTersimpan() == null, isFalse);

      // Isi berkas benar-benar cadangan JSON yang bisa dibaca.
      final Map<String, Object?> isi =
          jsonDecode(File('${dir.path}/${hasil.namaBerkas}').readAsStringSync())
              as Map<String, Object?>;
      expect(isi['format'], 'plo-backup');
      expect(isi['versiSkema'], db.schemaVersion);

      // Belum waktunya: jalan kedua tidak membuat berkas baru.
      final HasilCadanganOtomatis kedua = await otomatis.jalankan();
      expect(kedua.dijalankan, isFalse);
      expect(berkasCadangan().length, 1);
    });

    test('rotasi menyimpan 3 berkas terbaru dan tidak menyentuh berkas lain',
        () async {
      await otomatis.setAktif(true);
      // Berkas cadangan buatan pengguna (pengaman sebelum impor) tidak boleh
      // ikut terhapus meski ada di folder yang sama.
      File('${dir.path}/plo_backup_pengaman_20260901_070000.json')
          .writeAsStringSync('{"format":"plo-backup"}');

      for (int i = 0; i < 4; i++) {
        jam = DateTime(2026, 9, 1 + i, 8 + i);
        final HasilCadanganOtomatis h = await otomatis.jalankan(paksa: true);
        expect(h.dijalankan, isTrue, reason: 'jalan ke-$i gagal: ${h.pesan}');
      }

      final List<String> sisa = berkasCadangan();
      expect(sisa.length, 4,
          reason: '3 cadangan otomatis + 1 cadangan pengaman: $sisa');
      expect(sisa.contains('plo_backup_pengaman_20260901_070000.json'), isTrue);
      expect(await otomatis.daftar(), hasLength(3));
    });

    test('berkas rusak: pemeriksaan keutuhan melaporkan apa adanya', () async {
      final String rusak = '${dir.path}/plo_auto_20260901_0800.json';
      File(rusak).writeAsStringSync('{ bukan json }');
      final HasilPeriksaKeutuhan hasil = await otomatis
          .periksaKeutuhan(namaBerkas: 'plo_auto_20260901_0800.json', path: rusak);
      expect(hasil.utuh, isFalse);
      expect(hasil.pesan.isNotEmpty, isTrue);
      final HasilPeriksaKeutuhan? tersimpan = await otomatis.periksaTersimpan();
      expect(tersimpan == null, isFalse);
      expect(tersimpan!.utuh, isFalse);
    });

    test('periksa keutuhan tanpa berkas: keterangan jujur', () async {
      final HasilPeriksaKeutuhan hasil = await otomatis.periksaKeutuhan();
      expect(hasil.utuh, isFalse);
      expect(hasil.pesan, contains('Belum ada berkas cadangan'));
    });
  });

  group('FR-137 layar cadangan', () {
    testWidgets('saklar cadangan otomatis tersimpan', (t) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      final Directory dir = Directory.systemTemp.createTempSync('uji_auto_ui_');
      final DateTime jam = DateTime(2026, 9, 17, 9);
      final LayananCadangan cadangan = LayananCadangan(
          db: db, penentuFolder: () async => dir, jam: () => jam);
      final LayananCadanganOtomatis otomatis = LayananCadanganOtomatis(
        setelan: SetelanBasisData(PengaturanRepository(db)),
        cadangan: cadangan,
        jam: () => jam,
      );

      // Layar memakai ListView (item dibangun malas) dan kartu "Cadangan
      // otomatis" ada di bawah kartu ekspor. Layar diperpanjang (lebar tetap
      // 420 = ukuran HP) supaya seluruh kartu benar-benar terpasang. Cara ini
      // dipakai berkas ini sejak awal (setSurfaceSize) — menulis langsung ke
      // t.view.physicalSize TIDAK berpengaruh karena tertimpa di baris atas.
      await t.binding.setSurfaceSize(const Size(420, 2400));

      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: BackupScreen(
            layanan: cadangan,
            layananOtomatis: otomatis,
            folderCadangan: () async => dir,
            jamSekarang: () => jam,
          ),
        ),
      ));
      for (int i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Cadangan otomatis'), findsOneWidget);
      expect(find.byKey(const Key('saklar_cadangan_otomatis')), findsOneWidget);
      expect(find.byKey(const Key('jeda_cadangan_otomatis')), findsOneWidget);
      expect(find.textContaining('belum pernah dijalankan'), findsOneWidget);

      await t.tap(find.byKey(const Key('saklar_cadangan_otomatis')));
      for (int i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      final bool? aktif = await t.runAsync(() => otomatis.aktif());
      expect(aktif, isTrue);
      expect(find.text('Menyala'), findsOneWidget);

      // Tombol "Jalankan sekarang" membuat berkas cadangan nyata.
      // ListView itu malas: gulir dulu sampai tombolnya masuk pohon widget.
      final Finder tombol = find.byKey(const Key('jalankan_cadangan_otomatis'));
      for (int i = 0; i < 8 && tombol.evaluate().isEmpty; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await t.pump(const Duration(milliseconds: 50));
      }
      await t.ensureVisible(tombol);
      await t.pump(const Duration(milliseconds: 50));
      await t.tap(tombol);
      // Kanal platform (brankas Keystore + enkripsi berkas cadangan) tidak
      // selesai di dalam waktu TIRUAN: jawabannya baru sampai saat uji
      // menyerahkan kendali ke gelung peristiwa asli. `runAsync` melakukan itu,
      // jadi beri waktu nyata sesaat sebelum memeriksa hasilnya.
      await t.runAsync(() async {
        for (int i = 0; i < 40; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      for (int i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      final List<String> berkas = dir
          .listSync()
          .whereType<File>()
          .map((File f) => f.uri.pathSegments.last)
          .toList();
      expect(berkas.length, 1, reason: 'berkas cadangan tidak dibuat: $berkas');
      expect(find.byKey(const Key('status_cadangan_otomatis')), findsOneWidget);

      await t.binding.setSurfaceSize(null);
      await db.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  });
}
