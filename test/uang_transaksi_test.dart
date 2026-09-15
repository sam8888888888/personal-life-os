/// Uji FR-71 "Arus kas" — lapisan data + layar daftar/form/kelola kategori.
///
/// Data uji dibuat lewat repository langsung ke database memori (pola sama
/// seperti `test/v15_data_test.dart`). Nominal selalu EKSPLISIT (satuan sen),
/// jadi angka ringkasan bisa diperiksa tepat.
///
/// Catatan teknis: operasi database di dalam `testWidgets` memakai await biasa
/// (drift memori selesai di zona waktu palsu) dan selalu diakhiri `pump` +
/// `tutup()` supaya timer stream drift tuntas.
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/core/utils/uang_utils.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/model/enums.dart';
import 'package:personal_life_os/data/repository/transaksi_repository.dart';
import 'package:personal_life_os/features/uang/transaksi/daftar_transaksi_screen.dart';
import 'package:personal_life_os/features/uang/transaksi/form_transaksi_screen.dart';
import 'package:personal_life_os/features/uang/transaksi/kelola_kategori_screen.dart';
import 'package:personal_life_os/features/uang/transaksi/warna_ikon_kategori.dart';

late AppDatabase db;
late TransaksiRepository trx;

/// Waktu uji dikunci: 15 September 2026 → bulan berjalan 2026-09.
final jamUji = DateTime(2026, 9, 15, 9, 0);
final bulanSeptember = DateTime(2026, 9, 15);

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    trx = TransaksiRepository(db);
    TestWidgetsFlutterBinding.ensureInitialized();
  });
  tearDown(() => db.close());

  Future<int> idKategori(String kode) async {
    final k = await (db.select(db.kategoriTransaksi)
          ..where((x) => x.kode.equals(kode)))
        .getSingle();
    return k.id;
  }

  Future<TransaksiData> catat({
    required String id,
    required JenisArus jenis,
    required int sen,
    required DateTime tanggal,
    int? kategoriId,
    String? catatan,
  }) =>
      trx.simpan(TransaksiCompanion.insert(
        idTransaksi: id,
        jenis: Value(jenis.nilaiDb),
        tanggal: tanggal,
        jumlahSen: sen,
        kategoriId: Value(kategoriId),
        catatan: Value(catatan),
      ));

  /// Data bulan September 2026 (nominal eksplisit) + satu baris bulan Agustus.
  ///
  ///   Gaji September   : pemasukan   Rp 5.000.000 (500.000.000 sen)
  ///   Belanja bulanan  : pengeluaran Rp 1.250.000 (125.000.000 sen)
  ///   Bensin           : pengeluaran Rp   250.000 ( 25.000.000 sen)
  ///   Pengeluaran Agustus: pengeluaran Rp 777.000 (77.700.000 sen) — 20 Agu
  ///
  /// Ringkasan September: masuk Rp 5.000.000 · keluar Rp 1.500.000 ·
  /// bersih Rp 3.500.000.
  Future<void> isiDataSeptember() async {
    final masuk = await idKategori('masuk_gaji');
    final makan = await idKategori('kel_makan');
    final transport = await idKategori('kel_transportasi');
    await catat(
        id: 'trx_gaji',
        jenis: JenisArus.pemasukan,
        sen: 500000000,
        tanggal: DateTime(2026, 9, 1),
        kategoriId: masuk,
        catatan: 'Gaji September');
    await catat(
        id: 'trx_makan',
        jenis: JenisArus.pengeluaran,
        sen: 125000000,
        tanggal: DateTime(2026, 9, 5),
        kategoriId: makan,
        catatan: 'Belanja bulanan');
    await catat(
        id: 'trx_bensin',
        jenis: JenisArus.pengeluaran,
        sen: 25000000,
        tanggal: DateTime(2026, 9, 5),
        kategoriId: transport,
        catatan: 'Bensin');
    await catat(
        id: 'trx_agustus',
        jenis: JenisArus.pengeluaran,
        sen: 77700000,
        tanggal: DateTime(2026, 8, 20),
        kategoriId: makan,
        catatan: 'Pengeluaran Agustus');
  }

  // -------------------------------------------------------------------------
  // Perkakas uji layar
  // -------------------------------------------------------------------------

  Future<void> tampilkan(WidgetTester t, Widget layar) async {
    await t.binding.setSurfaceSize(const Size(420, 900));
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTema.terang(),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: layar,
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
  }

  Future<void> tutup(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 50));
    await t.binding.setSurfaceSize(null);
  }

  Future<void> ketukTerlihat(WidgetTester t, Finder target) async {
    await t.ensureVisible(target);
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(target);
    await t.pump();
  }

  /// Gulir sampai target terlihat (ListView hanya membangun baris terlihat).
  Future<void> gulirKe(WidgetTester t, Finder target, {int maks = 8}) async {
    for (var i = 0; i < maks; i++) {
      if (target.evaluate().isNotEmpty) return;
      await t.drag(find.byType(Scrollable).first, const Offset(0, -220));
      await t.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> tampilkanDaftar(WidgetTester t) async {
    await tampilkan(t, DaftarTransaksiScreen(jamSekarang: () => jamUji));
  }

  // =========================================================================
  // Lapisan data
  // =========================================================================
  group('FR-71 lapisan data', () {
    test('ringkasan bulan: pemasukan - pengeluaran = arus kas bersih', () async {
      final masuk = await idKategori('masuk_gaji');
      final makan = await idKategori('kel_makan');
      await catat(
          id: 't1',
          jenis: JenisArus.pemasukan,
          sen: 500000000,
          tanggal: DateTime(2026, 9, 1),
          kategoriId: masuk);
      await catat(
          id: 't2',
          jenis: JenisArus.pemasukan,
          sen: 125000000,
          tanggal: DateTime(2026, 9, 10));
      await catat(
          id: 't3',
          jenis: JenisArus.pengeluaran,
          sen: 187500000,
          tanggal: DateTime(2026, 9, 5),
          kategoriId: makan);

      final r = await trx.ringkasanBulan(bulanSeptember);
      expect(r.pemasukanSen, 625000000);
      expect(r.pengeluaranSen, 187500000);
      expect(r.bersihSen, 437500000); // 6.250.000 - 1.875.000
      expect(fmtRpDariSen(r.pemasukanSen), 'Rp 6.250.000');
      expect(fmtRpDariSen(r.pengeluaranSen), 'Rp 1.875.000');
      expect(fmtRpDariSen(r.bersihSen), 'Rp 4.375.000');
    });

    test('transaksi bulan lain tidak ikut terhitung (batas bulan ketat)',
        () async {
      await catat(
          id: 'sep_awal',
          jenis: JenisArus.pengeluaran,
          sen: 10000000,
          tanggal: DateTime(2026, 9, 1));
      await catat(
          id: 'sep_akhir',
          jenis: JenisArus.pengeluaran,
          sen: 20000000,
          tanggal: DateTime(2026, 9, 30));
      await catat(
          id: 'agu_akhir',
          jenis: JenisArus.pengeluaran,
          sen: 77700000,
          tanggal: DateTime(2026, 8, 31));
      await catat(
          id: 'okt_awal',
          jenis: JenisArus.pengeluaran,
          sen: 55500000,
          tanggal: DateTime(2026, 10, 1));

      final r = await trx.ringkasanBulan(bulanSeptember);
      expect(r.pengeluaranSen, 30000000); // hanya 1 & 30 September
      expect(r.pemasukanSen, 0);
      // Pengeluaran saja → arus kas bersih negatif (bukan nol).
      expect(r.bersihSen, -30000000);
    });

    test('ambilBulan memuat hanya bulan itu, urut tanggal', () async {
      await catat(
          id: 'trx_20',
          jenis: JenisArus.pengeluaran,
          sen: 1000,
          tanggal: DateTime(2026, 9, 20));
      await catat(
          id: 'trx_03',
          jenis: JenisArus.pengeluaran,
          sen: 2000,
          tanggal: DateTime(2026, 9, 3));
      await catat(
          id: 'trx_agustus',
          jenis: JenisArus.pengeluaran,
          sen: 3000,
          tanggal: DateTime(2026, 8, 3));

      final daftar = await trx.ambilBulan(bulanSeptember);
      expect(daftar.map((t) => t.idTransaksi).toList(), ['trx_03', 'trx_20']);
    });

    test('simpan idempoten: idTransaksi sama tidak menggandakan baris',
        () async {
      final a = await catat(
          id: 'trx_idem',
          jenis: JenisArus.pengeluaran,
          sen: 15000000,
          tanggal: DateTime(2026, 9, 3));
      final b = await catat(
          id: 'trx_idem',
          jenis: JenisArus.pengeluaran,
          sen: 17500000,
          tanggal: DateTime(2026, 9, 4));

      expect(b.id, a.id); // baris yang sama, bukan baris baru
      expect(b.jumlahSen, 17500000); // nilai diperbarui
      expect((await trx.ambilBulan(bulanSeptember)).length, 1);
      expect((await trx.ringkasanBulan(bulanSeptember)).pengeluaranSen,
          17500000);
    });

    test('simpan menolak nominal negatif dan idTransaksi kosong', () async {
      await expectLater(
        catat(
            id: 'trx_neg',
            jenis: JenisArus.pengeluaran,
            sen: -1,
            tanggal: DateTime(2026, 9, 5)),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        catat(
            id: '   ',
            jenis: JenisArus.pengeluaran,
            sen: 1000,
            tanggal: DateTime(2026, 9, 5)),
        throwsA(isA<ArgumentError>()),
      );
      expect((await trx.ambilBulan(bulanSeptember)), isEmpty);
    });

    test('total per kategori hanya menghitung bulan itu', () async {
      final makan = await idKategori('kel_makan');
      final transport = await idKategori('kel_transportasi');
      await catat(
          id: 't1',
          jenis: JenisArus.pengeluaran,
          sen: 10000000,
          tanggal: DateTime(2026, 9, 2),
          kategoriId: makan);
      await catat(
          id: 't2',
          jenis: JenisArus.pengeluaran,
          sen: 25000000,
          tanggal: DateTime(2026, 9, 9),
          kategoriId: makan);
      await catat(
          id: 't3',
          jenis: JenisArus.pengeluaran,
          sen: 5000000,
          tanggal: DateTime(2026, 9, 9),
          kategoriId: transport);
      await catat(
          id: 't4',
          jenis: JenisArus.pengeluaran,
          sen: 99000000,
          tanggal: DateTime(2026, 8, 9),
          kategoriId: makan);

      final total = await trx.totalPerKategori(bulanSeptember);
      expect(total.length, 2);
      expect(total.first.kategoriId, makan); // terbesar lebih dulu
      expect(total.first.totalSen, 35000000);
      expect(total.fold<int>(0, (a, b) => a + b.totalSen), 40000000);
    });

    test('hapus transaksi mengurangi total bulan', () async {
      await catat(
          id: 't1',
          jenis: JenisArus.pengeluaran,
          sen: 125000000,
          tanggal: DateTime(2026, 9, 5));
      await catat(
          id: 't2',
          jenis: JenisArus.pengeluaran,
          sen: 25000000,
          tanggal: DateTime(2026, 9, 6));

      final sebelum = await trx.ringkasanBulan(bulanSeptember);
      final baris = await trx.ambilBulan(bulanSeptember);
      await trx.hapus(baris.first.id);

      final sesudah = await trx.ringkasanBulan(bulanSeptember);
      expect(sesudah.pengeluaranSen,
          sebelum.pengeluaranSen - baris.first.jumlahSen);
      expect(sesudah.pengeluaranSen, 25000000);
      expect((await trx.ambilBulan(bulanSeptember)).length, 1);
    });
  });

  // =========================================================================
  // Peta ikon & warna
  // =========================================================================
  group('peta ikon & warna kategori', () {
    test('ikon dikenal dipetakan; kosong/tak dikenal memakai cadangan', () {
      expect(ikonKategori('home'), Icons.home);
      expect(ikonKategori('makan'), Icons.category); // tidak dikenal
      expect(ikonKategori(''), Icons.category);
      expect(ikonKategori(null), Icons.category);
      expect(pilihanIkon, isNotEmpty);
      for (final nama in pilihanIkon) {
        expect(petaIkonKategori.containsKey(nama), isTrue,
            reason: 'ikon pilihan "$nama" tidak ada di peta');
      }
    });

    test('warna heks dikenal & heks baru terbaca; tak sah memakai cadangan',
        () {
      expect(warnaKategori('#F4511E'), const Color(0xFFF4511E));
      expect(warnaKategori('#00ff00'), const Color(0xFF00FF00)); // heks baru
      expect(warnaKategori('bukan-warna'), warnaKategoriBawaan);
      expect(warnaKategori(''), warnaKategoriBawaan);
      expect(warnaKategori(null), warnaKategoriBawaan);
      expect(heksDariWarna(const Color(0xFFF4511E)), '#F4511E');
      expect(heksDariWarna(warnaKategori('#00ACC1')), '#00ACC1');
      expect(pilihanWarna, isNotEmpty);
      for (final heks in pilihanWarna) {
        expect(petaWarnaKategori.containsKey(heks), isTrue);
      }
    });
  });

  // =========================================================================
  // Layar arus kas
  // =========================================================================
  group('layar arus kas', () {
    testWidgets('daftar tampil: ringkasan, kunci wajib, dan baris transaksi',
        (t) async {
      await isiDataSeptember();
      await tampilkanDaftar(t);

      expect(find.text('Arus Kas'), findsOneWidget);
      expect(find.byKey(const Key('ringkasan_arus_kas')), findsOneWidget);
      expect(find.byKey(const Key('tambah_transaksi')), findsOneWidget);
      expect(find.byKey(const Key('pilih_kategori')), findsOneWidget);
      expect(find.text('Ringkasan September 2026'), findsOneWidget);
      expect(find.text('Pemasukan'), findsWidgets);
      expect(find.text('Pengeluaran'), findsWidgets);
      expect(find.text('Arus kas bersih'), findsOneWidget);
      // Baris transaksi bulan itu (judul = catatan, subjudul = kategori).
      expect(find.text('Belanja bulanan'), findsOneWidget);
      expect(find.text('Bensin'), findsOneWidget);
      expect(find.text('- Rp 250.000'), findsOneWidget); // tanda pengeluaran
      // Baris 1 September ada di bawah; gulir dulu sebelum diperiksa.
      await gulirKe(t, find.text('Gaji September'));
      expect(find.text('Gaji September'), findsOneWidget);
      expect(find.text('+ Rp 5.000.000'), findsOneWidget); // tanda pemasukan
      await tutup(t);
    });

    testWidgets('ringkasan memakai angka transaksi bulan itu', (t) async {
      await isiDataSeptember();
      await tampilkanDaftar(t);

      final kartu = find.byKey(const Key('ringkasan_arus_kas'));
      expect(kartu, findsOneWidget);
      expect(
          find.descendant(of: kartu, matching: find.text('Rp 5.000.000')),
          findsOneWidget); // pemasukan
      expect(
          find.descendant(of: kartu, matching: find.text('Rp 1.500.000')),
          findsOneWidget); // pengeluaran
      expect(
          find.descendant(of: kartu, matching: find.text('Rp 3.500.000')),
          findsOneWidget); // arus kas bersih
      await tutup(t);
    });

    testWidgets('total per kategori tampil (pemasukan & pengeluaran)',
        (t) async {
      await isiDataSeptember();
      await tampilkanDaftar(t);

      await gulirKe(t, find.byKey(const Key('total_per_kategori')));
      expect(find.byKey(const Key('total_per_kategori')), findsOneWidget);
      expect(find.text('Total Pengeluaran per kategori'), findsOneWidget);
      expect(find.text('Total Pemasukan per kategori'), findsOneWidget);
      // Makan & Minum = Rp 1.250.000 (hanya September, bukan 777.000 Agustus).
      expect(find.text('Rp 1.250.000'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('transaksi bulan lain tidak ikut tampil', (t) async {
      await isiDataSeptember();
      await tampilkanDaftar(t);

      expect(find.text('Pengeluaran Agustus'), findsNothing);
      expect(find.text('Rp 777.000'), findsNothing);
      await tutup(t);
    });

    testWidgets('pemilih bulan: mundur satu bulan lalu bulan kosong',
        (t) async {
      await isiDataSeptember();
      await tampilkanDaftar(t);

      await t.tap(find.byKey(const Key('bulan_sebelumnya')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Ringkasan Agustus 2026'), findsOneWidget);
      expect(find.text('Pengeluaran Agustus'), findsOneWidget);
      expect(find.text('Gaji September'), findsNothing);

      await t.tap(find.byKey(const Key('bulan_sebelumnya')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Ringkasan Juli 2026'), findsOneWidget);
      expect(find.text('Belum ada transaksi di bulan ini.'), findsOneWidget);

      await t.tap(find.byKey(const Key('bulan_berikutnya')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Ringkasan Agustus 2026'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('tombol tambah membuka form transaksi', (t) async {
      await isiDataSeptember();
      await tampilkanDaftar(t);

      await t.tap(find.byKey(const Key('tambah_transaksi')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Tambah Transaksi'), findsOneWidget);
      expect(find.byKey(const Key('nominal_transaksi')), findsOneWidget);
      expect(find.byKey(const Key('pilih_kategori_transaksi')), findsOneWidget);
      await tutup(t);
    });

    testWidgets('ketuk baris membuka form ubah dengan isi yang sama',
        (t) async {
      await isiDataSeptember();
      await tampilkanDaftar(t);

      await t.tap(find.text('Bensin'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));

      expect(find.text('Ubah Transaksi'), findsOneWidget);
      final nominal = t.widget<TextFormField>(
          find.byKey(const Key('nominal_transaksi')));
      expect(nominal.controller!.text, '250000'); // Rp 250.000
      final catatan = t.widget<TextFormField>(
          find.byKey(const Key('catatan_transaksi')));
      expect(catatan.controller!.text, 'Bensin');
      await tutup(t);
    });

    testWidgets('simpan lewat form menambah satu baris', (t) async {
      await isiDataSeptember();
      await tampilkanDaftar(t);

      await t.tap(find.byKey(const Key('tambah_transaksi')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));

      // Pilih kategori pengeluaran lewat dropdown.
      await t.tap(find.byKey(const Key('pilih_kategori_transaksi')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Makan & Minum').last);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      await t.enterText(find.byKey(const Key('nominal_transaksi')), '275rb');
      await t.pump();
      await ketukTerlihat(t, find.byKey(const Key('simpan_transaksi')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));

      // Form tertutup & baris baru muncul di daftar bulan ini.
      expect(find.text('Tambah Transaksi'), findsNothing);
      expect(find.text('- Rp 275.000'), findsOneWidget);
      // Ringkasan ikut berubah: pengeluaran 1.500.000 + 275.000.
      final kartu = find.byKey(const Key('ringkasan_arus_kas'));
      expect(
          find.descendant(of: kartu, matching: find.text('Rp 1.775.000')),
          findsOneWidget);
      expect(
          find.descendant(of: kartu, matching: find.text('Rp 3.225.000')),
          findsOneWidget); // bersih 5.000.000 - 1.775.000
      await tutup(t);
    });

    testWidgets('form menolak nominal kosong dan kategori kosong', (t) async {
      await isiDataSeptember();
      await tampilkan(t, FormTransaksiScreen(jamSekarang: () => jamUji));

      await ketukTerlihat(t, find.byKey(const Key('simpan_transaksi')));
      await t.pump(const Duration(milliseconds: 300));

      expect(find.text('Nominal wajib diisi'), findsOneWidget);
      expect(find.text('Pilih kategori dulu'), findsOneWidget);
      expect(find.text('Tambah Transaksi'), findsOneWidget); // form tetap terbuka
      expect((await trx.ambilBulan(bulanSeptember)).length, 3); // tidak menulis
      await tutup(t);
    });

    testWidgets('hapus lewat tahan lama mengurangi total', (t) async {
      await isiDataSeptember();
      await tampilkanDaftar(t);

      await t.longPress(find.text('Bensin'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Hapus transaksi ini?'), findsOneWidget);

      await t.tap(find.text('Hapus'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(milliseconds: 600));

      expect(find.text('Bensin'), findsNothing);
      final kartu = find.byKey(const Key('ringkasan_arus_kas'));
      expect(
          find.descendant(of: kartu, matching: find.text('Rp 3.750.000')),
          findsOneWidget); // 5.000.000 - 1.250.000
      await tutup(t);
    });

    testWidgets('geser baris ke kiri meminta konfirmasi (batal = tetap ada)',
        (t) async {
      await isiDataSeptember();
      await tampilkanDaftar(t);

      await t.drag(find.text('Bensin'), const Offset(-400, 0));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Hapus transaksi ini?'), findsOneWidget);

      await t.tap(find.text('Batal'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Bensin'), findsOneWidget);
      expect((await trx.ambilBulan(bulanSeptember)).length, 3);
      await tutup(t);
    });

    testWidgets('tombol Kategori membuka layar kelola kategori', (t) async {
      await isiDataSeptember();
      await tampilkanDaftar(t);

      await t.tap(find.byKey(const Key('pilih_kategori')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Kelola Kategori'), findsOneWidget);
      expect(find.byKey(const Key('tambah_kategori')), findsOneWidget);
      await tutup(t);
    });
  });

  // =========================================================================
  // Layar kelola kategori (kategori bisa diubah pengguna)
  // =========================================================================
  group('kelola kategori', () {
    testWidgets('kategori bisa ditambah pengguna', (t) async {
      await tampilkan(t, const KelolaKategoriScreen());

      await t.tap(find.byKey(const Key('tambah_kategori')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Tambah kategori'), findsOneWidget);

      await t.enterText(find.byKey(const Key('nama_kategori')), 'Hobi Laut');
      await t.pump();
      await t.tap(find.byKey(const Key('simpan_kategori')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));

      // Kategori baru ditaruh di urutan terakhir → gulir sampai terlihat.
      await gulirKe(t, find.text('Hobi Laut'));
      expect(find.text('Hobi Laut'), findsOneWidget);
      final semua = await (db.select(db.kategoriTransaksi)..where(
              (x) => x.nama.equals('Hobi Laut')))
          .get();
      expect(semua.length, 1);
      expect(semua.first.bawaanSistem, isFalse); // kategori buatan pengguna
      await tutup(t);
    });

    testWidgets('kategori bisa disembunyikan lalu ditampilkan kembali',
        (t) async {
      final id = await idKategori('kel_makan');
      await tampilkan(t, const KelolaKategoriScreen());
      expect(find.text('Disembunyikan'), findsNothing);

      await ketukTerlihat(t, find.byKey(ValueKey('arsip_$id')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Disembunyikan'), findsOneWidget);

      await ketukTerlihat(t, find.byKey(ValueKey('arsip_$id')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Disembunyikan'), findsNothing);
      await tutup(t);
    });

    testWidgets('nama kategori kosong ditolak di dialog', (t) async {
      await tampilkan(t, const KelolaKategoriScreen());

      await t.tap(find.byKey(const Key('tambah_kategori')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(const Key('simpan_kategori')));
      await t.pump(const Duration(milliseconds: 300));

      expect(find.text('Nama kategori wajib diisi'), findsOneWidget);
      expect(find.text('Tambah kategori'), findsOneWidget); // dialog tetap ada
      await tutup(t);
    });
  });

  // =========================================================================
  // Bahasa layar (PRD §III-11)
  // =========================================================================
  testWidgets('bahasa layar arus kas & kategori bebas kata menghakimi',
      (t) async {
    const terlarang = [
      'skor',
      'anda gagal',
      'kamu',
      'berdosa',
      'belum sholat',
      'wajib anda',
    ];

    await isiDataSeptember();
    await tampilkanDaftar(t);
    var teks = t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .join(' ')
        .toLowerCase();
    for (final kata in terlarang) {
      expect(teks.contains(kata), isFalse, reason: 'kata "$kata" muncul');
    }

    await tampilkan(t, const KelolaKategoriScreen());
    teks = t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .join(' ')
        .toLowerCase();
    for (final kata in terlarang) {
      expect(teks.contains(kata), isFalse, reason: 'kata "$kata" muncul');
    }
    await tutup(t);
  });
}
