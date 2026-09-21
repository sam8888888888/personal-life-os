/// Uji FR-104 (berat & ukuran tubuh) & FR-105 (jurnal angka kesehatan).
///
/// Yang dibuktikan:
///   * IMT dihitung dengan rumus yang benar & sebutannya memakai ambang umum
///     (bukan diagnosis); data belum lengkap → tidak menghitung apa pun,
///   * progres menuju target benar (termasuk saat bergerak menjauh = 0 %),
///   * ringkasan 30 hari: rata-rata, terendah/tertinggi, arah tren,
///   * layar FR-104: mencatat berat benar-benar menambah baris di tabel
///     ukuran_tubuh; tinggi & target tersimpan; IMT & progres tampil,
///   * layar FR-105: tekanan darah butuh DUA angka; satuan per jenis diingat;
///     rata-rata & tren 30 hari tampil; catatan bisa dihapus.
library;

import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/laporan/kesehatan_ukur.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/features/kesehatan/jurnal_angka_screen.dart';
import 'package:personal_life_os/features/kesehatan/ukuran_tubuh_screen.dart';

late AppDatabase db;

/// Waktu patok uji: 20 September 2026, 09.00.
final sekarang = DateTime(2026, 9, 20, 9);

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  group('logika', () {
    test('IMT: rumus benar, data tak lengkap tidak dihitung', () {
      // 70 kg, 170 cm → 70 / 1,7² = 24,2
      expect(imt(70, 170)!.toStringAsFixed(1), '24.2');
      expect(imt(null, 170), isNull);
      expect(imt(70, null), isNull);
      expect(imt(0, 170), isNull);
      expect(imt(70, 0), isNull);
    });

    test('sebutan IMT memakai ambang umum, bukan diagnosis', () {
      expect(labelImt(null), contains('Belum bisa'));
      expect(labelImt(17), contains('18,5'));
      expect(labelImt(21), contains('rentang umum'));
      expect(labelImt(24), contains('23–24,9'));
      expect(labelImt(30), contains('≥25'));
      for (final v in [17.0, 21.0, 24.0, 30.0]) {
        expect(labelImt(v).toLowerCase(), isNot(contains('diagnosis')));
      }
    });

    test('progres menuju target', () {
      // Turun dari 80 → target 70; sekarang 75 = setengah jalan.
      expect(persenProgres(titikAwal: 80, target: 70, sekarang: 75), 50);
      // Sudah lewat target → dibatasi 100.
      expect(persenProgres(titikAwal: 80, target: 70, sekarang: 68), 100);
      // Bergerak menjauh → 0.
      expect(persenProgres(titikAwal: 80, target: 70, sekarang: 85), 0);
      expect(persenProgres(titikAwal: null, target: 70, sekarang: 75), isNull);
      expect(persenProgres(titikAwal: 80, target: 80, sekarang: 75), isNull);
    });

    test('ringkasan 30 hari: rata-rata, rentang, arah', () {
      final ringkas = ringkasPerJenis(
        [
          BarisUkur(jenis: 'berat', nilai: 80, waktu: DateTime(2026, 9, 1)),
          BarisUkur(jenis: 'berat', nilai: 79, waktu: DateTime(2026, 9, 10)),
          BarisUkur(jenis: 'berat', nilai: 78, waktu: DateTime(2026, 9, 18)),
          // Di luar rentang 30 hari → tidak dihitung.
          BarisUkur(jenis: 'berat', nilai: 95, waktu: DateTime(2026, 7, 1)),
          BarisUkur(jenis: 'lingkar_perut', nilai: 92, waktu: DateTime(2026, 9, 18)),
        ],
        sekarang: sekarang,
      );
      final berat = ringkas.firstWhere((r) => r.jenis == 'berat');
      expect(berat.jumlah, 3);
      expect(berat.terakhir, 78);
      expect(berat.rataRata.toStringAsFixed(2), '79.00');
      expect(berat.terendah, 78);
      expect(berat.tertinggi, 80);
      expect(berat.arah, ArahTren.turun);
      expect(labelArah(berat.arah), 'turun');
      expect(labelArah(ArahTren.baru), 'catatan pertama');
    });

    test('tekanan darah: jenis berpasangan & satuan saran tersedia', () {
      final td = jenisCatatan('tekanan_darah')!;
      expect(td.berpasangan, isTrue);
      expect(td.labelKedua, 'Diastolik');
      expect(jenisCatatan('tidak_ada'), isNull);
      expect(jenisCatatan('gula_darah')!.saranSatuan, contains('mmol/L'));
    });
  });

  group('layar FR-104', () {
    testWidgets('catat berat, simpan tinggi & target, IMT + progres tampil',
        (t) async {
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: UkuranTubuhScreen(db: db, sekarang: sekarang),
        ),
      ));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const Key('isi_tinggi')), '170');
      await t.enterText(find.byKey(const Key('isi_target_berat')), '70');
      await t.tap(find.byKey(const Key('simpan_pengaturan_ukuran')));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const Key('isi_berat')), '85');
      await t.tap(find.byKey(const Key('simpan_berat')));
      await t.pumpAndSettle();

      final baris = await db.select(db.ukuranTubuh).get();
      expect(baris, hasLength(1));
      expect(baris.first.jenis, 'berat');
      expect(baris.first.nilai, 85);
      expect(baris.first.satuan, 'kg');

      // Pengaturan tinggi & target benar-benar tersimpan.
      final pengaturan = PengaturanRepository(db);
      expect(await pengaturan.baca('tinggi_badan_cm'), '170');
      expect(await pengaturan.baca('target_berat_kg'), '70');

      // IMT = 85 / 1,7² = 29,4 → di atas ambang umum (bukan diagnosis).
      expect(find.byKey(const Key('nilai_imt')), findsOneWidget);
      expect(
        (t.widget<Text>(find.byKey(const Key('nilai_imt'))).data ?? ''),
        contains('29'),
      );
      expect(find.byKey(const Key('progres_target')), findsOneWidget);
    });

    testWidgets('angka kosong → diberi tahu, tidak ada baris tersimpan',
        (t) async {
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: UkuranTubuhScreen(db: db, sekarang: sekarang),
        ),
      ));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('simpan_berat')));
      await t.pumpAndSettle();

      // pesan ada di bawah daftar jenis → gulir dulu (ListView memasang anak
      // hanya yang terlihat).
      await t.scrollUntilVisible(
        find.byKey(const Key('pesan_ukuran')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Isi angkanya dulu'), findsOneWidget);
      expect(await db.select(db.ukuranTubuh).get(), isEmpty);
    });
  });

  group('layar FR-105', () {
    testWidgets('tekanan darah butuh dua angka; satuan diingat; tren tampil',
        (t) async {
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: JurnalAngkaScreen(db: db, sekarang: sekarang),
        ),
      ));
      await t.pumpAndSettle();

      // Jenis bawaan adalah tekanan darah (butuh dua angka).
      await t.enterText(find.byKey(const Key('isi_nilai_utama')), '120');
      await t.tap(find.byKey(const Key('simpan_catatan_kesehatan')));
      await t.pumpAndSettle();
      expect(find.textContaining('kedua angkanya'), findsOneWidget);
      expect(await db.select(db.catatanKesehatan).get(), isEmpty);

      await t.enterText(find.byKey(const Key('isi_nilai_kedua')), '80');
      await t.tap(find.byKey(const Key('simpan_catatan_kesehatan')));
      await t.pumpAndSettle();

      final baris = await db.select(db.catatanKesehatan).get();
      expect(baris, hasLength(1));
      expect(baris.first.jenis, 'tekanan_darah');
      expect(baris.first.nilai, 120);
      expect(baris.first.nilaiKedua, 80);
      expect(baris.first.satuan, 'mmHg');

      // Ringkasan 30 hari muncul setelah ada catatan.
      expect(find.byKey(const Key('angka_ringkas_30_hari')), findsOneWidget);
      expect(find.textContaining('rata-rata'), findsWidgets);

      // Pindah ke gula darah, satuan bawaan mengikuti jenisnya.
      await t.tap(find.byKey(const Key('jenis_catatan_gula_darah')));
      await t.pumpAndSettle();
      final satuan = t.widget<TextField>(find.byKey(const Key('isi_satuan')));
      expect(satuan.controller!.text, 'mg/dL');

      await t.enterText(find.byKey(const Key('isi_nilai_utama')), '110');
      await t.tap(find.byKey(const Key('simpan_catatan_kesehatan')));
      await t.pumpAndSettle();
      expect(await db.select(db.catatanKesehatan).get(), hasLength(2));

      // Satuan per jenis diingat di pengaturan.
      final peta = await SatuanTersimpan(PengaturanRepository(db)).semua();
      expect(peta['gula_darah'], 'mg/dL');
      expect(peta['tekanan_darah'], 'mmHg');
    });

    testWidgets('hapus catatan menghilangkan barisnya', (t) async {
      await db.into(db.catatanKesehatan).insert(CatatanKesehatanCompanion.insert(
            jenis: 'suhu',
            waktu: sekarang,
            nilai: 37.5,
            satuan: const Value('°C'),
          ));

      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: JurnalAngkaScreen(db: db, sekarang: sekarang),
        ),
      ));
      await t.pumpAndSettle();

      expect(find.textContaining('Suhu tubuh: 38'), findsOneWidget);
      final id = (await db.select(db.catatanKesehatan).get()).first.id;
      await t.tap(find.byKey(Key('hapus_catatan_kesehatan_$id')));
      await t.pumpAndSettle();
      expect(await db.select(db.catatanKesehatan).get(), isEmpty);
    });
  });
}
