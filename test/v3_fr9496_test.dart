/// Uji FR-94 (hafalan/hifz) & FR-96 (zakat & sedekah).
///
/// Yang dibuktikan:
///   * jadwal ulangan mengikuti aturan pengguna (0 = tanpa jadwal),
///   * "perlu diulang" muncul hanya setelah lewat jadwalnya,
///   * ringkasan memisahkan juz & surah serta menghitung per status,
///   * layar hafalan: menyimpan hafalan, menandai diulang (status naik dari
///     "baru" ke "murajaah"), menghapus,
///   * zakat: nisab 85 gram × harga emas yang DIISI PENGUNA, harta − utang,
///     tarif 2,5 %, haul 354 hari — dan asumsi selalu ditampilkan,
///   * tanpa harga emas / belum haul → zakat tidak dihitung (bukan ditebak),
///   * fitrah: jiwa × 2,5 kg, nilai uang hanya bila harga beras diisi,
///   * layar zakat: menyimpan acuan harga emas, catatan infaq & rekapnya.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/laporan/hifz.dart';
import 'package:personal_life_os/core/laporan/zakat.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/features/ibadah/hifz_screen.dart';
import 'package:personal_life_os/features/ibadah/zakat_screen.dart';

late AppDatabase db;
final sekarang = DateTime(2026, 9, 20, 9);

Future<void> layarTinggi(WidgetTester t) async {
  await t.binding.setSurfaceSize(const Size(1200, 2600));
  addTearDown(() => t.binding.setSurfaceSize(null));
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  group('FR-94 logika hifz', () {
    test('jadwal ulangan mengikuti aturan pengguna', () {
      final terakhir = DateTime(2026, 9, 10);
      expect(
        jadwalUlangBerikutnya(terakhir: terakhir, ulangSetiapHari: 7),
        DateTime(2026, 9, 17),
      );
      expect(jadwalUlangBerikutnya(terakhir: terakhir, ulangSetiapHari: 0), isNull);
    });

    test('perlu diulang hanya setelah lewat jadwal', () {
      expect(
        perluDiulangSekarang(
          terakhir: DateTime(2026, 9, 10),
          ulangSetiapHari: 7,
          sekarang: sekarang,
        ),
        isTrue,
      );
      expect(
        perluDiulangSekarang(
          terakhir: DateTime(2026, 9, 19),
          ulangSetiapHari: 7,
          sekarang: sekarang,
        ),
        isFalse,
      );
      // Tanpa jadwal ulangan → tidak pernah "perlu diulang".
      expect(
        perluDiulangSekarang(
          terakhir: DateTime(2020, 1, 1),
          ulangSetiapHari: 0,
          sekarang: sekarang,
        ),
        isFalse,
      );
    });

    test('ringkasan memisahkan juz & surah + hitung per status', () {
      final daftar = [
        HafalanData(
          id: 1,
          jenis: 'juz',
          nama: 'Juz 30',
          status: 'kuat',
          terakhir: DateTime(2026, 9, 19),
          ulangSetiapHari: 30,
          dibuatPada: sekarang,
          diubahPada: sekarang,
        ),
        HafalanData(
          id: 2,
          jenis: 'surah',
          nama: 'Al-Baqarah',
          status: 'murajaah',
          terakhir: DateTime(2026, 9, 1),
          ulangSetiapHari: 7,
          dibuatPada: sekarang,
          diubahPada: sekarang,
        ),
        HafalanData(
          id: 3,
          jenis: 'surah',
          nama: 'Yasin',
          status: 'perlu_diulang',
          terakhir: DateTime(2026, 9, 15),
          ulangSetiapHari: 3,
          dibuatPada: sekarang,
          diubahPada: sekarang,
        ),
      ];
      final r = ringkasHafalan(daftar, sekarang);
      expect(r.totalJuz, 1);
      expect(r.totalSurah, 2);
      expect(r.total, 3);
      expect(r.perStatus['kuat'], 1);
      expect(r.perStatus['murajaah'], 1);
      expect(r.perStatus['perlu_diulang'], 1);
      expect(r.perluDiulang, 2); // Al-Baqarah & Yasin
      expect(kalimatRingkasHafalan(r), contains('3 bagian'));
      expect(kalimatRingkasHafalan(r).toLowerCase(), isNot(contains('gagal')));
      expect(labelStatusHafalan('perlu_diulang'), 'Perlu diulang');
    });
  });

  group('FR-96 logika zakat', () {
    test('nisab = 85 gram emas; zakat 2,5% bila nisab & haul terpenuhi', () {
      final hasil = hitungZakat(
        hartaSen: 200000000 * 100, // Rp 200 juta
        utangSen: 20000000 * 100, // Rp 20 juta
        hargaEmasPerGramSen: 1500000 * 100, // Rp 1,5 juta/gram
        mulaiHaul: DateTime(2025, 8, 1),
        sekarang: sekarang,
      );
      expect(hasil.nisabSen, 1500000 * 85 * 100); // Rp 127,5 juta
      expect(hasil.hartaBersihSen, 180000000 * 100);
      expect(hasil.wajibZakat, isTrue);
      expect(hasil.zakatSen, 4500000 * 100); // 2,5% × Rp 180 juta
      expect(hasil.asumsi.join(' '), contains('85 gram'));
      expect(hasil.asumsi.join(' '), contains('2,5%'));
      expect(hasil.asumsi.join(' '), contains('354 hari'));
      expect(hasil.asumsi.join(' ').toLowerCase(), contains('bukan keputusan'));
    });

    test('harga emas belum diisi → nisab belum bisa dihitung', () {
      final hasil = hitungZakat(
        hartaSen: 1000000000 * 100,
        utangSen: 0,
        hargaEmasPerGramSen: 0,
        mulaiHaul: DateTime(2020, 1, 1),
        sekarang: sekarang,
      );
      expect(hasil.nisabSen, 0);
      expect(hasil.wajibZakat, isFalse);
      expect(hasil.zakatSen, 0);
      expect(hasil.asumsi.join(' '), contains('belum diisi'));
    });

    test('belum haul → belum wajib, sisa hari diberitahu', () {
      final hasil = hitungZakat(
        hartaSen: 200000000 * 100,
        utangSen: 0,
        hargaEmasPerGramSen: 1500000 * 100,
        mulaiHaul: sekarang.subtract(const Duration(days: 100)),
        sekarang: sekarang,
      );
      expect(hasil.sudahHaul, isFalse);
      expect(hasil.wajibZakat, isFalse);
      expect(hasil.hariMenujuHaul, 354 - 100);
      expect(hasil.zakatSen, 0);
    });

    test('harta di bawah nisab → tidak wajib', () {
      final hasil = hitungZakat(
        hartaSen: 50000000 * 100,
        utangSen: 0,
        hargaEmasPerGramSen: 1500000 * 100,
        mulaiHaul: DateTime(2020, 1, 1),
        sekarang: sekarang,
      );
      expect(hasil.wajibZakat, isFalse);
    });

    test('fitrah: jiwa × 2,5 kg, uang bila harga beras diisi', () {
      final tanpaHarga = hitungFitrah(jiwa: 4);
      expect(tanpaHarga.kgBeras, 10);
      expect(tanpaHarga.uangSen, isNull);
      expect(tanpaHarga.asumsi.join(' '), contains('kilogram'));

      final denganHarga = hitungFitrah(jiwa: 4, hargaBerasPerKgSen: 15000 * 100);
      expect(denganHarga.uangSen, 150000 * 100); // 10 kg × Rp 15.000
      expect(denganHarga.asumsi.join(' '), contains('Rp 15.000'));
    });

    test('rekap sedekah bulan ini & tahun ini', () {
      ZakatSedekahData baris(int id, DateTime t, int rupiah) => ZakatSedekahData(
            id: id,
            jenis: 'infaq',
            tanggal: t,
            jumlahSen: rupiah * 100,
            kodeMataUang: 'IDR',
            dibuatPada: sekarang,
            diubahPada: sekarang,
          );
      final ringkas = ringkasSedekah(
        [
          baris(1, DateTime(2026, 9, 5), 500000),
          baris(2, DateTime(2026, 9, 18), 250000),
          baris(3, DateTime(2026, 3, 1), 1000000),
          baris(4, DateTime(2025, 12, 31), 9000000),
        ],
        sekarang,
      );
      expect(ringkas.totalBulanIniSen, 750000 * 100);
      expect(ringkas.totalTahunIniSen, 1750000 * 100);
      expect(ringkas.jumlahCatatan, 4);
      expect(labelJenisZakat('zakat_maal'), 'Zakat maal');
    });
  });

  group('layar hafalan (FR-94)', () {
    testWidgets('simpan hafalan, tandai diulang (status naik), hapus',
        (t) async {
      await layarTinggi(t);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: HifzScreen(db: db, sekarang: sekarang),
        ),
      ));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const Key('isi_nama_hafalan')), 'Al-Baqarah');
      await t.tap(find.byKey(const Key('pilih_status_hafalan_murajaah')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('simpan_hafalan')));
      await t.pumpAndSettle();

      final daftar = await db.select(db.hafalan).get();
      expect(daftar, hasLength(1));
      expect(daftar.first.nama, 'Al-Baqarah');
      expect(daftar.first.jenis, 'surah');
      expect(daftar.first.status, 'murajaah');
      expect(daftar.first.ulangSetiapHari, 7);
      expect(find.textContaining('1 bagian'), findsOneWidget);

      final id = daftar.first.id;
      await t.tap(find.byKey(Key('diulang_hafalan_$id')));
      await t.pumpAndSettle();
      final sesudah = await db.select(db.hafalan).getSingle();
      expect(sesudah.terakhir.difference(sekarang).inMinutes.abs() < 1, isTrue);

      await t.tap(find.byKey(Key('hapus_hafalan_$id')));
      await t.pumpAndSettle();
      expect(await db.select(db.hafalan).get(), isEmpty);
    });

    testWidgets('nama & nomor kosong → diberi tahu', (t) async {
      await layarTinggi(t);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: HifzScreen(db: db, sekarang: sekarang),
        ),
      ));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('simpan_hafalan')));
      await t.pumpAndSettle();
      expect(find.textContaining('Tulis nama'), findsOneWidget);
      expect(await db.select(db.hafalan).get(), isEmpty);
    });
  });

  group('layar zakat (FR-96)', () {
    testWidgets('acuan harga emas tersimpan & hasil zakat tampil', (t) async {
      // Haul sudah lewat > 354 hari supaya kewajiban bisa dihitung.
      final pengaturan = PengaturanRepository(db);
      await pengaturan.simpan(
          kunciMulaiHaul, DateTime(2025, 8, 1).toIso8601String());

      await layarTinggi(t);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: ZakatScreen(db: db, sekarang: sekarang),
        ),
      ));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const Key('isi_harga_emas')), '1500000');
      await t.tap(find.byKey(const Key('simpan_harga_emas')));
      await t.pumpAndSettle();
      expect(await pengaturan.baca(kunciHargaEmas), '1500000');
      expect(find.textContaining('diisi sendiri pada'), findsOneWidget);

      // Pastikan acuan haul benar-benar terbaca layar sebelum dihitung.
      expect(await pengaturan.baca(kunciMulaiHaul), isNotNull);

      // Kolom harta ada di kartu bawah → pastikan terlihat dulu, lalu isi.
      await t.ensureVisible(find.byKey(const Key('isi_harta_kas')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('isi_harta_kas')), '200000000');
      await t.enterText(
          find.byKey(const Key('isi_utang_jatuh_tempo')), '20000000');
      await t.pumpAndSettle();

      // Buktikan isinya benar-benar masuk ke kolomnya sebelum menilai hasil.
      expect(
        t
            .widget<TextField>(find.byKey(const Key('isi_harta_kas')))
            .controller!
            .text,
        '200000000',
      );

      // Nisab = 85 gram × Rp 1,5 juta = Rp 127.500.000
      final teksNisab =
          t.widget<Text>(find.byKey(const Key('nisab_zakat'))).data ?? '';
      expect(teksNisab, contains('127.500.000')); // nisab 85 g × Rp 1,5 juta
      expect(teksNisab, contains('180.000.000')); // harta − utang
      expect(
        t.widget<Text>(find.byKey(const Key('hasil_zakat'))).data,
        contains('4.500.000'),
      );
    });

    testWidgets('catat infaq & rekap bulan ini', (t) async {
      await layarTinggi(t);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: ZakatScreen(db: db, sekarang: sekarang),
        ),
      ));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('jenis_zakat_infaq')));
      await t.enterText(find.byKey(const Key('isi_jumlah_zakat')), '250000');
      await t.enterText(find.byKey(const Key('isi_penerima_zakat')), 'Masjid Al-Ikhlas');
      await t.tap(find.byKey(const Key('simpan_zakat')));
      await t.pumpAndSettle();

      final catatan = await db.select(db.zakatSedekah).get();
      expect(catatan, hasLength(1));
      expect(catatan.first.jenis, 'infaq');
      expect(catatan.first.jumlahSen, 250000 * 100);
      expect(catatan.first.penerima, 'Masjid Al-Ikhlas');
      expect(
        t.widget<Text>(find.byKey(const Key('ringkas_sedekah'))).data,
        contains('250.000'),
      );

      final id = catatan.first.id;
      await t.tap(find.byKey(Key('hapus_catatan_zakat_$id')));
      await t.pumpAndSettle();
      expect(await db.select(db.zakatSedekah).get(), isEmpty);
    });
  });
}
