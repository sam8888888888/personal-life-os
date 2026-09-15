/// Uji FR-72 "Anggaran vs realisasi per kategori".
///
/// Cakupan:
/// (a) realisasi = jumlah transaksi kategori itu pada bulan itu saja;
/// (b) persen & selisih benar dengan angka eksplisit (termasuk tepat 80% dan
///     tepat 100%);
/// (c) kategori tanpa anggaran tidak hilang dari daftar;
/// (d) pemakaian melewati batas 100% menampilkan sisa negatif;
/// (e) peringatan 80% dan 100% benar-benar muncul di layar;
/// (f) mengubah anggaran mengubah persen.
///
/// Catatan teknis: data uji disiapkan di `setUp` (zona async nyata), sedangkan
/// di dalam `testWidgets` tidak ada `await` langsung ke database — hasilnya
/// diperiksa lewat tampilan (pola sama dengan test/hari_ini_ui_test.dart).
library;

// `hide Column`: drift juga punya nama `Column` (definisi kolom), sedangkan
// uji ini memakai Column milik Flutter.
import 'package:drift/drift.dart' hide isNull, Column;
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
import 'package:personal_life_os/data/repository/anggaran_repository.dart';
import 'package:personal_life_os/data/repository/kategori_transaksi_repository.dart';
import 'package:personal_life_os/data/repository/transaksi_repository.dart';
import 'package:personal_life_os/features/uang/anggaran/anggaran_screen.dart';
import 'package:personal_life_os/features/uang/anggaran/bilah_anggaran.dart';
import 'package:personal_life_os/features/uang/anggaran/form_anggaran_screen.dart';

late AppDatabase db;
late TransaksiRepository trx;
late AnggaranRepository anggaran;
late KategoriTransaksiRepository kategori;

/// Waktu uji dikunci: "sekarang" = 15 Sep 2026 → bulan berjalan 2026-09.
final jamUji = DateTime(2026, 9, 15, 8, 0);
const bulanUji = '2026-09';

/// Angka uang ditulis dalam rupiah (dibaca manusia), disimpan dalam sen.
int rp(num nominal) => rupiahKeSen(nominal);

/// Warna yang dipakai aturan ambang (sama dengan bilah_anggaran.dart).
const kuning = Color(0xFFF9A825);
const merah = Color(0xFFC62828);
const hijau = Color(0xFF2E7D32);

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    trx = TransaksiRepository(db);
    anggaran = AnggaranRepository(db, transaksi: trx);
    kategori = KategoriTransaksiRepository(db);
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() => db.close());

  Future<int> idKategori(String kode) async {
    final k = await (db.select(db.kategoriTransaksi)
          ..where((x) => x.kode.equals(kode)))
        .getSingle();
    return k.id;
  }

  Future<void> catat({
    required String id,
    required int sen,
    required DateTime tanggal,
    int? kategoriId,
    JenisArus jenis = JenisArus.pengeluaran,
  }) =>
      trx.simpan(TransaksiCompanion.insert(
        idTransaksi: id,
        jenis: Value(jenis.nilaiDb),
        tanggal: tanggal,
        jumlahSen: sen,
        kategoriId: Value(kategoriId),
      ));

  /// Baris siap tampil (fungsi murni layar) untuk satu periode.
  Future<List<BarisAnggaran>> barisTampil(DateTime bulan) async {
    final kunci = '${bulan.year}-${bulan.month.toString().padLeft(2, '0')}';
    final total =
        await trx.totalPerKategori(bulan, jenis: JenisArus.pengeluaran);
    return susunBarisAnggaran(
      kategori: await kategori.ambilSemua(jenis: JenisArus.pengeluaran),
      barisAnggaran: await anggaran.ambilPeriode(kunci),
      realisasi: await anggaran.realisasi(kunci),
      terpakaiPerKategori: {
        for (final t in total)
          if (t.kategoriId != null) t.kategoriId!: t.totalSen,
      },
      totalPengeluaranSen: total.fold<int>(0, (a, b) => a + b.totalSen),
    );
  }

  RealisasiAnggaran rr({
    int kategoriId = 1,
    String nama = 'Uji',
    required int batas,
    required int terpakai,
    List<int> ambang = ambangAnggaranBawaan,
  }) =>
      RealisasiAnggaran(
        kategoriId: kategoriId,
        nama: nama,
        batasSen: batas,
        terpakaiSen: terpakai,
        ambang: ambang,
      );

  group('realisasi & penyusun baris (angka eksplisit)', () {
    test('(a) realisasi = transaksi kategori itu pada bulan itu saja',
        () async {
      final makan = await idKategori('kel_makan');
      final transport = await idKategori('kel_transportasi');
      await anggaran.simpan(
          periode: bulanUji, kategoriId: makan, batasSen: rp(1000000));
      await catat(
          id: 'a1',
          sen: rp(400000),
          tanggal: DateTime(2026, 9, 3),
          kategoriId: makan);
      await catat(
          id: 'a2',
          sen: rp(200000),
          tanggal: DateTime(2026, 9, 28),
          kategoriId: makan);
      // Bulan lain tidak ikut.
      await catat(
          id: 'a3',
          sen: rp(999000),
          tanggal: DateTime(2026, 8, 31),
          kategoriId: makan);
      // Kategori lain tidak ikut.
      await catat(
          id: 'a4',
          sen: rp(50000),
          tanggal: DateTime(2026, 9, 4),
          kategoriId: transport);

      final r = (await anggaran.realisasi(bulanUji))
          .firstWhere((x) => x.kategoriId == makan);
      expect(r.terpakaiSen, rp(600000));
      expect(r.batasSen, rp(1000000));
      expect(r.persen, 60);
      expect(r.selisihSen, rp(400000));
      expect(persenSelisih(r), 40);
    });

    test('(a) pemasukan pada kategori yang sama tidak menambah realisasi',
        () async {
      final makan = await idKategori('kel_makan');
      await anggaran.simpan(
          periode: bulanUji, kategoriId: makan, batasSen: rp(1000000));
      await catat(
          id: 'b1',
          sen: rp(700000),
          tanggal: DateTime(2026, 9, 5),
          kategoriId: makan);
      await catat(
          id: 'b2',
          sen: rp(900000),
          tanggal: DateTime(2026, 9, 6),
          kategoriId: makan,
          jenis: JenisArus.pemasukan);

      final r = (await anggaran.realisasi(bulanUji)).single;
      expect(r.terpakaiSen, rp(700000));
      expect(r.persen, 70);
      expect(r.status, StatusAnggaran.aman);
    });

    test('(b) persen & selisih: 250rb dari 1jt = 25% / sisa Rp 750.000',
        () async {
      final makan = await idKategori('kel_makan');
      await anggaran.simpan(
          periode: bulanUji, kategoriId: makan, batasSen: rp(1000000));
      await catat(
          id: 'c1',
          sen: rp(250000),
          tanggal: DateTime(2026, 9, 7),
          kategoriId: makan);

      final r = (await anggaran.realisasi(bulanUji)).single;
      expect(r.persen, 25);
      expect(r.selisihSen, rp(750000));
      expect(persenSelisih(r), 75);
      expect(teksSelisihRp(r), 'Rp 750.000');
      expect(warnaStatusAnggaran(r.status), hijau);
    });

    test('(b) tepat 80% -> tanda kuning "Mendekati batas 80%"', () async {
      final makan = await idKategori('kel_makan');
      await anggaran.simpan(
          periode: bulanUji, kategoriId: makan, batasSen: rp(1000000));
      await catat(
          id: 'd1',
          sen: rp(800000),
          tanggal: DateTime(2026, 9, 8),
          kategoriId: makan);

      final r = (await anggaran.realisasi(bulanUji)).single;
      expect(r.persen, 80, reason: 'tepat 80% harus dihitung menyentuh ambang');
      expect(r.status, StatusAnggaran.mendekati);
      expect(r.selisihSen, rp(200000));
      expect(persenSelisih(r), 20);
      expect(warnaStatusAnggaran(r.status), kuning);
      expect((await anggaran.peringatan(bulanUji)).length, 1);
    });

    test('(b) tepat 100% -> status lewat, sisa Rp 0 (bukan hijau)', () async {
      final makan = await idKategori('kel_makan');
      await anggaran.simpan(
          periode: bulanUji, kategoriId: makan, batasSen: rp(1000000));
      await catat(
          id: 'e1',
          sen: rp(1000000),
          tanggal: DateTime(2026, 9, 9),
          kategoriId: makan);

      final r = (await anggaran.realisasi(bulanUji)).single;
      expect(r.persen, 100);
      expect(r.selisihSen, 0);
      expect(persenSelisih(r), 0);
      expect(r.status, StatusAnggaran.lewat);
      expect(warnaStatusAnggaran(r.status), merah);
    });

    test('(d) 130% -> sisa negatif & persen selisih negatif', () async {
      final makan = await idKategori('kel_makan');
      await anggaran.simpan(
          periode: bulanUji, kategoriId: makan, batasSen: rp(500000));
      await catat(
          id: 'f1',
          sen: rp(650000),
          tanggal: DateTime(2026, 9, 10),
          kategoriId: makan);

      final r = (await anggaran.realisasi(bulanUji)).single;
      expect(r.persen, 130);
      expect(r.selisihSen, -rp(150000));
      expect(persenSelisih(r), -30);
      expect(teksSelisihRp(r), '-Rp 150.000');
      expect(nilaiBilah(r), 1.0, reason: 'bilah berhenti di 100%, arah meluber '
          'dibaca dari angka Selisih');
    });

    test('(b) persen dibulatkan ke bilangan bulat terdekat (250rb/300rb = 83%)',
        () async {
      final makan = await idKategori('kel_makan');
      await anggaran.simpan(
          periode: bulanUji, kategoriId: makan, batasSen: rp(300000));
      await catat(
          id: 'g1',
          sen: rp(250000),
          tanggal: DateTime(2026, 9, 11),
          kategoriId: makan);

      final r = (await anggaran.realisasi(bulanUji)).single;
      expect(r.persen, 83);
      expect(r.status, StatusAnggaran.mendekati);
    });

    test('(c) kategori tanpa anggaran tetap ada; baris Total bulan di atas',
        () async {
      final makan = await idKategori('kel_makan');
      final transport = await idKategori('kel_transportasi');
      await anggaran.simpan(
          periode: bulanUji, kategoriId: makan, batasSen: rp(1000000));
      await catat(
          id: 'h1',
          sen: rp(400000),
          tanggal: DateTime(2026, 9, 5),
          kategoriId: makan);
      await catat(
          id: 'h2',
          sen: rp(70000),
          tanggal: DateTime(2026, 9, 6),
          kategoriId: transport);

      final baris = await barisTampil(DateTime(2026, 9));
      expect(baris.length, 12, reason: '1 total + 11 kategori pengeluaran');
      expect(baris.first.kategoriId, AnggaranRepository.kategoriTotal);
      expect(baris.first.nama, 'Total bulan');

      final tanpaAnggaran = baris.where((b) => !b.punyaAnggaran).toList();
      expect(tanpaAnggaran.length, 11,
          reason: '12 baris (1 total + 11 kategori) − 1 yang sudah diatur');
      final transportBaris =
          baris.firstWhere((b) => b.kategoriId == transport);
      expect(transportBaris.punyaAnggaran, isFalse);
      expect(transportBaris.realisasi.terpakaiSen, rp(70000));
      expect(transportBaris.realisasi.persen, isNull);
      expect(transportBaris.realisasi.status, StatusAnggaran.aman);
      expect(transportBaris.realisasi.batasSen, 0);
    });

    test('(c) tanpa satu pun baris anggaran: semua kategori tetap tampil',
        () async {
      final makan = await idKategori('kel_makan');
      await catat(
          id: 'i1',
          sen: rp(120000),
          tanggal: DateTime(2026, 9, 5),
          kategoriId: makan);

      final baris = await barisTampil(DateTime(2026, 9));
      expect(baris.length, 12);
      expect(baris.every((b) => !b.punyaAnggaran), isTrue);
      expect(
          baris.map((b) => b.realisasi.persen).every((p) => p == null), isTrue);
    });

    test('total bulan = seluruh pengeluaran, termasuk transaksi tanpa kategori',
        () async {
      final makan = await idKategori('kel_makan');
      final transport = await idKategori('kel_transportasi');
      await anggaran.simpan(
        periode: bulanUji,
        kategoriId: AnggaranRepository.kategoriTotal,
        batasSen: rp(1000000),
      );
      await catat(
          id: 'j1',
          sen: rp(400000),
          tanggal: DateTime(2026, 9, 5),
          kategoriId: makan);
      await catat(
          id: 'j2',
          sen: rp(700000),
          tanggal: DateTime(2026, 9, 6),
          kategoriId: transport);
      await catat(id: 'j3', sen: rp(300000), tanggal: DateTime(2026, 9, 7));

      final baris = await barisTampil(DateTime(2026, 9));
      final total = baris.first;
      expect(total.realisasi.terpakaiSen, rp(1400000));
      expect(total.realisasi.selisihSen, -rp(400000));
      expect(total.realisasi.persen, 140);
      expect(total.realisasi.status, StatusAnggaran.lewat);
      expect(persenSelisih(total.realisasi), -40);
    });

    test('anggaran kategori yang sudah diarsipkan tetap tampil (tidak raib)',
        () async {
      final baru = await kategori.tambah(
          nama: 'Hobi Laut', jenis: JenisArus.pengeluaran);
      await anggaran.simpan(
          periode: bulanUji, kategoriId: baru.id, batasSen: rp(200000));
      await kategori.sembunyikan(baru.id);

      final baris = await barisTampil(DateTime(2026, 9));
      final diarsip = baris.firstWhere((b) => b.kategoriId == baru.id);
      expect(diarsip.nama, 'Hobi Laut');
      expect(diarsip.punyaAnggaran, isTrue);
      expect(diarsip.realisasi.batasSen, rp(200000));
    });
  });

  group('bilah & warna ambang', () {
    test('warna: hijau < 80%, kuning >= 80%, merah >= 100%', () {
      expect(warnaStatusAnggaran(rr(batas: 1000, terpakai: 500).status), hijau);
      expect(warnaStatusAnggaran(rr(batas: 1000, terpakai: 800).status), kuning);
      expect(
          warnaStatusAnggaran(rr(batas: 1000, terpakai: 1000).status), merah);
      expect(
          warnaStatusAnggaran(rr(batas: 1000, terpakai: 1500).status), merah);
    });

    test('nilaiBilah dibatasi 0..1 dan nol bila batas belum diisi', () {
      expect(nilaiBilah(rr(batas: 1000, terpakai: 500)), 0.5);
      expect(nilaiBilah(rr(batas: 1000, terpakai: 1500)), 1.0);
      expect(nilaiBilah(rr(batas: 0, terpakai: 999)), 0.0);
      expect(persenSelisih(rr(batas: 0, terpakai: 999)), isNull);
    });

    testWidgets('widget BilahAnggaran: warna & panjang ikut ambang',
        (t) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            BilahAnggaran(realisasi: rr(batas: 1000, terpakai: 800)),
            BilahAnggaran(realisasi: rr(batas: 1000, terpakai: 1000)),
          ]),
        ),
      ));
      final bilah = t
          .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator))
          .toList();
      expect(bilah.length, 2);
      expect(bilah[0].value, 0.8);
      expect(bilah[0].color, kuning);
      expect(bilah[1].value, 1.0);
      expect(bilah[1].color, merah);
    });
  });

  // ------------------------------------------------------------------------
  // Lapisan UI. Data disiapkan di setUp (zona async nyata).
  // ------------------------------------------------------------------------
  group('layar anggaran', () {
    late int idTinggal;
    late int idMakan;
    late int idTransport;

    setUp(() async {
      idTinggal = await idKategori('kel_tempat_tinggal');
      idMakan = await idKategori('kel_makan');
      idTransport = await idKategori('kel_transportasi');
      // Tempat Tinggal: 300rb / 2jt = 15% (dalam batas)
      await anggaran.simpan(
          periode: bulanUji, kategoriId: idTinggal, batasSen: rp(2000000));
      await catat(
          id: 'u1',
          sen: rp(300000),
          tanggal: DateTime(2026, 9, 2),
          kategoriId: idTinggal);
      // Makan & Minum: 800rb / 1jt = tepat 80% -> kuning
      await anggaran.simpan(
          periode: bulanUji, kategoriId: idMakan, batasSen: rp(1000000));
      await catat(
          id: 'u2',
          sen: rp(800000),
          tanggal: DateTime(2026, 9, 3),
          kategoriId: idMakan);
      // Transportasi: 650rb / 500rb = 130% -> merah, sisa negatif
      await anggaran.simpan(
          periode: bulanUji, kategoriId: idTransport, batasSen: rp(500000));
      await catat(
          id: 'u3',
          sen: rp(650000),
          tanggal: DateTime(2026, 9, 4),
          kategoriId: idTransport);
    });

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
      await t.pump(const Duration(milliseconds: 600));
    }

    Future<void> tutup(WidgetTester t) async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.binding.setSurfaceSize(null);
    }

    /// Gulir daftar sampai target terbangun, lalu ketuk (ListView itu malas).
    Future<void> gulirKe(WidgetTester t, Finder target, {int maks = 8}) async {
      for (var i = 0; i < maks; i++) {
        if (target.evaluate().isNotEmpty) return;
        await t.drag(find.byType(Scrollable).first, const Offset(0, -200));
        await t.pump(const Duration(milliseconds: 120));
      }
    }

    Future<void> ketukTerlihat(WidgetTester t, Finder target) async {
      await t.ensureVisible(target);
      await t.pumpAndSettle(const Duration(milliseconds: 50));
      await t.tap(target);
      await t.pump();
    }

    Finder isiBaris(int kategoriId, String teks) => find.descendant(
          of: find.byKey(ValueKey('baris_$kategoriId')),
          matching: find.text(teks),
        );

    testWidgets('(e) peringatan 80% kuning & 100% merah muncul di layar',
        (t) async {
      await tampilkan(t, AnggaranScreen(jamSekarang: () => jamUji));

      await gulirKe(t, find.byKey(const Key('peringatan_80')));
      expect(find.byKey(const Key('peringatan_80')), findsOneWidget);
      expect(find.text('Mendekati batas 80%'), findsOneWidget);
      expect(isiBaris(idMakan, 'Rp 1.000.000'), findsOneWidget);
      expect(isiBaris(idMakan, 'Rp 800.000'), findsOneWidget);
      expect(isiBaris(idMakan, '80%'), findsOneWidget);
      expect(isiBaris(idMakan, 'Rp 200.000'), findsOneWidget);
      expect(isiBaris(idMakan, '20%'), findsOneWidget);

      await gulirKe(t, find.byKey(const Key('peringatan_100')));
      expect(find.byKey(const Key('peringatan_100')), findsOneWidget);
      expect(find.text('Melewati batas 100%'), findsOneWidget);
      expect(isiBaris(idTransport, '130%'), findsOneWidget);
      expect(isiBaris(idTransport, '-Rp 150.000'), findsOneWidget);
      expect(isiBaris(idTransport, '-30%'), findsOneWidget);

      // Kalimat ringkas menyebut jumlah baris, tanpa menghakimi.
      await gulirKe(t, find.textContaining('2 baris anggaran sudah menyentuh'));
      expect(find.textContaining('2 baris anggaran sudah menyentuh'),
          findsOneWidget);
      await tutup(t);
    });

    testWidgets('(c) kategori tanpa anggaran tetap tampil + tombol "Atur anggaran"',
        (t) async {
      await tampilkan(t, AnggaranScreen(jamSekarang: () => jamUji));

      // Baris Total bulan ada di paling atas (kategori_id = 0).
      final total = find.byKey(const Key('total_bulan'));
      expect(total, findsOneWidget);
      expect(find.descendant(of: total, matching: find.text('Total bulan')),
          findsOneWidget);
      expect(
          find.descendant(of: total, matching: find.text('Rp 1.750.000')),
          findsOneWidget,
          reason: 'total = 300rb + 800rb + 650rb');

      // Kategori jauh di bawah (Pendidikan) tetap ada walau belum diatur.
      await gulirKe(t, find.text('Pendidikan'));
      expect(find.text('Pendidikan'), findsOneWidget);
      expect(find.text('Belum diatur'), findsWidgets);
      await gulirKe(t, find.byKey(const Key('tambah_anggaran')));
      expect(find.byKey(const Key('tambah_anggaran')), findsWidgets);
      expect(find.text('Atur anggaran'), findsWidgets);
      await tutup(t);
    });

    testWidgets('(b)(d) baris menampilkan Anggaran / Terpakai / Selisih (%)',
        (t) async {
      await tampilkan(t, AnggaranScreen(jamSekarang: () => jamUji));
      await gulirKe(t, find.text('Tempat Tinggal'));
      expect(isiBaris(idTinggal, 'Anggaran'), findsOneWidget);
      expect(isiBaris(idTinggal, 'Terpakai'), findsOneWidget);
      expect(isiBaris(idTinggal, 'Selisih'), findsOneWidget);
      expect(isiBaris(idTinggal, 'Rp 2.000.000'), findsOneWidget);
      expect(isiBaris(idTinggal, 'Rp 300.000'), findsOneWidget);
      expect(isiBaris(idTinggal, '15%'), findsOneWidget);
      expect(isiBaris(idTinggal, 'Rp 1.700.000'), findsOneWidget);
      expect(isiBaris(idTinggal, '85%'), findsOneWidget);
      expect(isiBaris(idTinggal, 'Mendekati batas 80%'), findsNothing);
      await tutup(t);
    });

    testWidgets('(f) tekan baris -> ubah nominal -> persen ikut berubah',
        (t) async {
      await tampilkan(t, AnggaranScreen(jamSekarang: () => jamUji));
      await gulirKe(t, find.byKey(ValueKey('baris_$idMakan')));
      expect(isiBaris(idMakan, '80%'), findsOneWidget);

      await ketukTerlihat(t, find.text('Makan & Minum'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Ubah anggaran'), findsOneWidget);

      final kolom = find.byKey(const Key('batas_anggaran'));
      await t.ensureVisible(kolom);
      await t.enterText(kolom, '2000000');
      await t.pump();
      await ketukTerlihat(t, find.text('Simpan perubahan'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));

      expect(find.text('Ubah anggaran'), findsNothing); // form tertutup
      await gulirKe(t, find.byKey(ValueKey('baris_$idMakan')));
      expect(isiBaris(idMakan, 'Rp 2.000.000'), findsOneWidget);
      expect(isiBaris(idMakan, 'Rp 800.000'), findsOneWidget);
      expect(isiBaris(idMakan, '40%'), findsOneWidget,
          reason: '800rb dari 2jt = 40%');
      expect(isiBaris(idMakan, '60%'), findsOneWidget,
          reason: 'sisa 1,2jt dari 2jt = 60%');
      expect(isiBaris(idMakan, '80%'), findsNothing);
      expect(find.byKey(const Key('peringatan_80')), findsNothing);
      await tutup(t);
    });

    testWidgets('hapus anggaran lewat konfirmasi -> baris jadi "Belum diatur"',
        (t) async {
      await tampilkan(t, AnggaranScreen(jamSekarang: () => jamUji));
      await gulirKe(t, find.byKey(ValueKey('baris_$idTransport')));
      await ketukTerlihat(t, find.text('Transportasi'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Ubah anggaran'), findsOneWidget);

      // Batalkan dulu: data harus tetap ada.
      await ketukTerlihat(t, find.byKey(const Key('hapus_anggaran')));
      await t.pump();
      expect(find.text('Hapus anggaran ini?'), findsOneWidget);
      await t.tap(find.text('Batal'));
      await t.pump();
      expect(find.text('Ubah anggaran'), findsOneWidget);

      // Baru benar-benar dihapus.
      await ketukTerlihat(t, find.byKey(const Key('hapus_anggaran')));
      await t.pump();
      await t.tap(find.byKey(const Key('konfirmasi_hapus')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));

      expect(find.text('Ubah anggaran'), findsNothing);
      await gulirKe(t, find.byKey(ValueKey('baris_$idTransport')));
      expect(isiBaris(idTransport, 'Belum diatur'), findsOneWidget);
      expect(isiBaris(idTransport, 'Rp 650.000'), findsOneWidget);
      expect(isiBaris(idTransport, '130%'), findsNothing);
      expect(find.byKey(const Key('peringatan_100')), findsNothing);
      await ketukTerlihat(t, find.byKey(const Key('tambah_anggaran')).first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Atur anggaran'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('form menolak kategori kosong & batas nol / bukan angka',
        (t) async {
      await tampilkan(
          t, const FormAnggaranScreen(periode: bulanUji, kategoriId: null));
      await ketukTerlihat(t, find.text('Simpan anggaran'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Kategori wajib dipilih'), findsOneWidget);
      expect(find.text('Batas anggaran tidak valid (harus lebih dari 0)'),
          findsOneWidget);
      expect(find.text('Atur anggaran'), findsOneWidget,
          reason: 'form tidak boleh tertutup saat validasi gagal');

      // Kategori dipilih + batas "0" -> tetap ditolak.
      await t.tap(find.byKey(const Key('pilih_kategori')));
      await t.pumpAndSettle(const Duration(milliseconds: 50));
      await t.tap(find.text('Makan & Minum').last);
      await t.pumpAndSettle(const Duration(milliseconds: 50));
      await t.enterText(find.byKey(const Key('batas_anggaran')), '0');
      await ketukTerlihat(t, find.text('Simpan anggaran'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Batas anggaran tidak valid (harus lebih dari 0)'),
          findsOneWidget);
      await tutup(t);
    });

    testWidgets('pemilih bulan: Agustus 2026 kosong, "Bulan ini" kembali',
        (t) async {
      await tampilkan(t, AnggaranScreen(jamSekarang: () => jamUji));
      expect(find.text('September 2026'), findsOneWidget);

      await t.tap(find.byKey(const Key('bulan_sebelum')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Agustus 2026'), findsOneWidget);
      expect(find.byKey(const Key('peringatan_80')), findsNothing);
      expect(find.byKey(const Key('peringatan_100')), findsNothing);
      expect(find.text('Belum diatur'), findsWidgets);

      await t.tap(find.byKey(const Key('ke_bulan_ini')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('September 2026'), findsOneWidget);
      await gulirKe(t, find.byKey(const Key('peringatan_80')));
      expect(find.byKey(const Key('peringatan_80')), findsOneWidget);
      await tutup(t);
    });
  });
}
