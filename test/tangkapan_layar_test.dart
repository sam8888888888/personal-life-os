/// Pembuat tangkapan layar demo (F2) — merender aplikasi sungguhan pada ukuran
/// ponsel 420x900 dengan font Roboto asli dari Flutter SDK.
///
/// Jalankan:  flutter test test/tangkapan_layar_test.dart --update-goldens
/// Hasil PNG muncul di test/goldens/, lalu disalin ke folder demo/.
library;

import 'dart:convert';
import 'package:personal_life_os/core/utils/waktu.dart';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/app_router.dart';
import 'package:personal_life_os/core/ibadah/model_sholat.dart';
import 'package:personal_life_os/core/ibadah/penghitung_sholat.dart';
import 'package:personal_life_os/core/notifikasi/jejak.dart';
import 'package:personal_life_os/core/notifikasi/perencana_pengingat.dart';
import 'package:personal_life_os/data/repository/dokumen_repository.dart';
import 'package:personal_life_os/features/ibadah/pengaturan_ibadah.dart';
import 'package:personal_life_os/core/notifikasi/layanan_notifikasi.dart';
import 'package:personal_life_os/core/notifikasi/model_pengingat.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/ibadah/penyimpanan_jadwal.dart';
import 'package:personal_life_os/features/ibadah/rekap_sholat_screen.dart';
import 'package:personal_life_os/core/ibadah/penyimpanan_log_sholat.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/anggaran_repository.dart';
import 'package:personal_life_os/data/repository/aset_repository.dart';
import 'package:personal_life_os/data/repository/kategori_transaksi_repository.dart';
import 'package:personal_life_os/data/repository/langganan_repository.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/data/repository/transaksi_repository.dart';
import 'package:personal_life_os/data/model/enums.dart';
import 'package:personal_life_os/features/ibadah/jadwal_sholat_screen.dart';
import 'package:personal_life_os/features/pengaturan/backup_screen.dart';
import 'package:personal_life_os/features/hari_ini/briefing_pagi_screen.dart';
import 'package:personal_life_os/features/ibadah/kalender_hijriah_screen.dart';
import 'package:personal_life_os/features/ibadah/pelacakan_sholat_screen.dart';

/// Font Roboto dari Flutter SDK. Dicari di beberapa lokasi agar uji
/// tangkapan layar tetap bisa jalan di mesin build mana pun.
String _cariFontDasar() {
  // FLUTTER_ROOT diisi oleh `flutter test` — jadi lokasi SDK tidak lagi
  // ditulis mati (dulu '/workspace/tools/flutter', yang tidak ada di Austria
  // sehingga seluruh uji tangkapan layar gugur di setUpAll).
  final String? akar = Platform.environment['FLUTTER_ROOT'];
  final String relatif = '/bin/cache/artifacts/material_fonts/';
  final List<String> kandidat = <String>[
    if (akar != null && akar.isNotEmpty) '$akar$relatif',
    '/opt/flutter$relatif',
    '/opt/tools/flutter$relatif',
    '/workspace/tools/flutter$relatif',
    '/usr/local/flutter$relatif',
  ];
  for (final p in kandidat) {
    if (Directory(p).existsSync()) return p;
  }
  return kandidat.first;
}

final String _fontDasar = _cariFontDasar();

Future<void> _muatFont(String nama, List<String> berkas) async {
  final loader = FontLoader(nama);
  for (final b in berkas) {
    final data = File('$_fontDasar$b').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(data.buffer)));
  }
  await loader.load();
}

/// Uji ini butuh font asli dari Flutter SDK; dilewati bila tidak tersedia
/// (mis. di mesin lain) agar rangkaian uji biasa tetap hijau.
final bool _fontTersedia =
    File('${_fontDasar}Roboto-Regular.ttf').existsSync();

/// Waktu dikunci supaya tangkapan layar tidak berubah saat tanggal berganti
/// (kalender menandai "hari ini", label "besok"/"N hari lagi").
final DateTime _waktuUji = DateTime(2026, 9, 10, 9, 0);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    pakaiSumberWaktu(() => _waktuUji);
    await _muatFont('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Light.ttf',
      'Roboto-Black.ttf',
    ]);
    await _muatFont('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });

  setUp(() async {
    penentuJejak = () async => null; // tanpa berkas jejak saat merender
    // Data contoh: 7 template + pemasukan Rp 12.000.000 + satu sudah dibayar.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await PengaturanRepository(db).isiContohData(acuan: _waktuUji);
    final daftar = await (db.select(db.tagihan)
          ..orderBy([(t) => OrderingTerm.asc(t.jatuhTempo)]))
        .get();
    await (db.update(db.tagihan)..where((t) => t.id.equals(daftar[0].id)))
        .write(const TagihanCompanion(lunas: Value(true)));
    // dikunci lewat variabel global agar dipakai pengujian berikutnya
    _db = db;
  });

  tearDown(() async {
    await _db.close();
  });

  tearDownAll(pakaiWaktuAsli);

  // ---- Data contoh modul uang V1.5 (FR-68/71/72/76) -----------------------
  // Hanya dipakai oleh tangkapan layar modul uang, supaya tangkapan layar
  // lama (F2/F3/F4/F5) tidak ikut berubah.
  Future<void> isiUangDemo() async {
    int rp(int n) => n * 100; // rupiah -> sen
    final kat = await KategoriTransaksiRepository(_db).ambilSemua();
    int idKategori(String kode) => kat.firstWhere((k) => k.kode == kode).id;

    final trx = TransaksiRepository(_db);
    Future<void> tulis(String id, String jenis, int hari, int sen, String kode,
            String catatan) =>
        trx.simpan(TransaksiCompanion.insert(
          idTransaksi: id,
          jenis: Value(jenis),
          tanggal: DateTime(2026, 9, hari),
          jumlahSen: sen,
          kategoriId: Value(idKategori(kode)),
          catatan: Value(catatan),
        ));
    await tulis('demo-1', 'pemasukan', 1, rp(12000000), 'masuk_gaji', 'Gaji September');
    await tulis('demo-2', 'pemasukan', 9, rp(2500000), 'masuk_freelance', 'Proyek situs');
    await tulis('demo-3', 'pengeluaran', 3, rp(45000), 'kel_makan', 'Sarapan & kopi');
    await tulis('demo-4', 'pengeluaran', 5, rp(78500), 'kel_makan', 'Makan keluarga');
    await tulis('demo-5', 'pengeluaran', 4, rp(25000), 'kel_transportasi', 'Ojek online');
    await tulis('demo-6', 'pengeluaran', 6, rp(120000), 'kel_hiburan', 'Bioskop');
    await tulis('demo-7', 'pengeluaran', 8, rp(350000), 'kel_belanja', 'Belanja bulanan');

    final ang = AnggaranRepository(_db);
    await ang.simpan(periode: '2026-09', kategoriId: 0, batasSen: rp(5000000));
    await ang.simpan(
        periode: '2026-09',
        kategoriId: idKategori('kel_makan'),
        batasSen: rp(900000));
    await ang.simpan(
        periode: '2026-09',
        kategoriId: idKategori('kel_transportasi'),
        batasSen: rp(600000));
    // Sengaja di bawah realisasi (Rp 120.000) supaya peringatan 100% terlihat.
    await ang.simpan(
        periode: '2026-09',
        kategoriId: idKategori('kel_hiburan'),
        batasSen: rp(100000));

    final lang = LanggananRepository(_db);
    await lang.tambah(
        nama: 'Netflix Premium',
        nominalSen: rp(186000),
        tanggalMulai: DateTime(2026, 9, 5),
        kategoriId: idKategori('kel_hiburan'));
    await lang.tambah(
        nama: 'Spotify Family',
        nominalSen: rp(86900),
        tanggalMulai: DateTime(2026, 9, 12),
        kategoriId: idKategori('kel_hiburan'));
    final berhenti = await lang.tambah(
        nama: 'Gym (berhenti)',
        nominalSen: rp(350000),
        tanggalMulai: DateTime(2026, 8, 1));
    await lang.hentikan(berhenti.id);

    final aset = AsetRepository(_db);
    final tabungan = await aset.tambahAset(
        nama: 'Tabungan BCA', jenis: JenisAset.bank, nilaiAwalSen: rp(25000000));
    final reksa = await aset.tambahAset(
        nama: 'Reksa Dana Pasar Uang',
        jenis: JenisAset.investasi,
        nilaiAwalSen: rp(10000000));
    await aset.tambahAset(
        nama: 'Emas Antam 10 g', jenis: JenisAset.emas, nilaiAwalSen: rp(14500000));
    final kk = await aset.tambahKewajiban(
        nama: 'Kartu Kredit BCA',
        jenis: JenisKewajiban.kartuKredit,
        saldoAwalSen: rp(3500000));
    await aset.tambahKewajiban(
        nama: 'Cicilan motor',
        jenis: JenisKewajiban.cicilan,
        saldoAwalSen: rp(8000000));

    // Riwayat nilai 3 bulan supaya grafik tren punya isi.
    for (final (bulan, faktor) in const [
      ('2026-07', 0.9),
      ('2026-08', 0.95),
      ('2026-09', 1.0),
    ]) {
      final lampau = bulan != '2026-09';
      await aset.simpanNilaiAset(
          asetId: tabungan.id,
          bulan: bulan,
          nilaiSen: rp((25000000 * faktor).round()),
          paksa: lampau,
          alasan: lampau ? 'contoh data demo' : null);
      await aset.simpanNilaiAset(
          asetId: reksa.id,
          bulan: bulan,
          nilaiSen: rp((10000000 * faktor).round()),
          paksa: lampau,
          alasan: lampau ? 'contoh data demo' : null);
      await aset.simpanNilaiKewajiban(
          kewajibanId: kk.id,
          bulan: bulan,
          nilaiSen: rp((3500000 * faktor).round()),
          paksa: lampau,
          alasan: lampau ? 'contoh data demo' : null);
    }
  }

  /// [pumpLanjutan] menambah pump sebelum pengambilan gambar — dipakai layar
  /// yang datanya datang dari basis data (butuh beberapa pump, bukan sekali).
  /// [periksa] dipanggil sebelum gambar diambil, selagi pohon widget masih ada.
  Future<void> potret(WidgetTester tester, String nama, String rute,
      {bool layananDemo = false,
      String prefiks = 'f2',
      int pumpLanjutan = 0,
      void Function(WidgetTester)? periksa}) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(_db),
        // Layar F3 memakai layanan contoh agar tangkapan layar stabil.
        if (layananDemo)
          layananNotifikasiProvider.overrideWithValue(_LayananDemo()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTema.terang().copyWith(
          textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Roboto'),
        ),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: buatRouter(awal: rute),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    for (int i = 0; i < pumpLanjutan; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    periksa?.call(tester);

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/${prefiks}_$nama.png'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.binding.setSurfaceSize(null);
  }

  // ---- Tangkapan layar P0 (FR-28) & V1.5 pengingat ibadah (FR-63/87) ------

  /// Tambah tagihan contoh pada beberapa bulan supaya grafik beban berisi.
  Future<void> isiBebanDemo() async {
    final DateTime acuan = _waktuUji;
    Future<void> tambah(String nama, int bulanLalu, int nominalRp) async {
      await _db.into(_db.tagihan).insert(TagihanCompanion.insert(
            nama: nama,
            jumlahSen: Value(nominalRp * 100),
            jatuhTempo:
                DateTime(acuan.year, acuan.month - bulanLalu, 5, 9),
          ));
    }

    await tambah('PLN rumah', 0, 450000);
    await tambah('IndiHome', 0, 395000);
    await tambah('BPJS keluarga', 1, 300000);
    await tambah('Air PDAM', 2, 180000);
    await tambah('Netflix', 3, 186000);
  }

  testWidgets('tangkapan layar beban tagihan (FR-28)', (t) async {
    // Data disiapkan di luar zona waktu palsu supaya basis data selesai dibaca.
    await t.runAsync(isiBebanDemo);
    await potret(t, 'beban_tagihan', '/laporan/beban-tagihan',
        prefiks: 'f8',
        pumpLanjutan: 40,
        periksa: (WidgetTester t) {
          // Pastikan yang tertangkap bukan layar "memuat" (bukan berputar).
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.byKey(const Key('grafik_beban')), findsOneWidget);
          expect(find.text('Beban tagihan'), findsWidgets);
          expect(find.textContaining('termasuk yang sudah dibayar'),
              findsOneWidget);
        });
  }, skip: !_fontTersedia);

  testWidgets('tangkapan layar pengingat ibadah (FR-63 & FR-87)', (t) async {
    await t.runAsync(() async {
      final setelan =
          PengaturanIbadah.dariRepository(PengaturanRepository(_db));
      await setelan.simpanBriefingAktif(true);
      await setelan.simpanJamBriefing('06:30');
      await setelan.simpanPengingatSholatAktif(true);
      await setelan.simpanMode(WaktuSholat.subuh, ModePengingatSholat.sebelum);
      await setelan.simpanGeser(WaktuSholat.subuh, 10);
      await setelan.simpanMetode(MetodeHitungSholat.kemenag);
    });
    await potret(t, 'pengingat_ibadah', '/ibadah/pengingat',
        prefiks: 'f9',
        pumpLanjutan: 40,
        periksa: (WidgetTester t) {
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.text('Pengingat Ibadah'), findsOneWidget);
          expect(find.byKey(const Key('saklar_briefing')), findsOneWidget);
          expect(find.byKey(const Key('saklar_sholat')), findsOneWidget);
          // Satu pintu: layar ini tidak lagi punya pemilih kota/metode.
          expect(find.byKey(const Key('pilih_kota')), findsNothing);
          expect(t.takeException() == null, isTrue);
        });
  }, skip: !_fontTersedia);

  testWidgets('tangkapan layar ringkasan',
      (t) => potret(t, 'ringkasan', '/ringkasan'),
      skip: !_fontTersedia);
  testWidgets('tangkapan layar tagihan', (t) => potret(t, 'tagihan', '/tagihan'),
      skip: !_fontTersedia);
  testWidgets('tangkapan layar kalender',
      (t) => potret(t, 'kalender', '/kalender'),
      skip: !_fontTersedia);
  testWidgets('tangkapan layar pengaturan',
      (t) => potret(t, 'pengaturan', '/pengaturan'),
      skip: !_fontTersedia);
  testWidgets('tangkapan layar form', (t) => potret(t, 'form_tambah', '/tambah'),
      skip: !_fontTersedia);

  // ---- F3: layar pengingat & izin -----------------------------------------
  testWidgets('tangkapan layar pengingat',
      (t) => potret(t, 'pengingat', '/pengingat',
          layananDemo: true, prefiks: 'f3'),
      skip: !_fontTersedia);

  // ---- V1.5: layar ibadah (FR-86 & FR-90) ---------------------------------
  // Jam dipatok (bukan DateTime.now) supaya tangkapan layar tidak berubah
  // setiap hari. Layar ibadah tidak memakai Riverpod, jadi dipanggil langsung.
  Future<void> potretIbadah(WidgetTester tester, String nama, Widget layar) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTema.terang().copyWith(
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Roboto'),
      ),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: layar,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/f4_$nama.png'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets(
      'tangkapan layar jadwal sholat',
      (t) => potretIbadah(
            t,
            'jadwal_sholat',
            JadwalSholatScreen(
              // 13 Sep 2026, 03.00 WIB -> Subuh 04:30 tampil sebagai berikutnya.
              jamSekarang: () => DateTime.utc(2026, 9, 12, 20, 0),
              penyimpanan: PenyimpananJadwal(
                penentuFolder: () =>
                    Future.value(Directory.systemTemp.createTempSync('demo_ibadah_')),
              ),
            ),
          ),
      skip: !_fontTersedia);

  testWidgets(
      'tangkapan layar kalender hijriah',
      (t) => potretIbadah(
            t,
            'kalender_hijriah',
            KalenderHijriahScreen(jamSekarang: () => DateTime(2026, 9, 13)),
          ),
      skip: !_fontTersedia);

  // ---- V1.5 Modul 0: 5 TAB + Ringkasan pagi + Pelacakan sholat -------------
  // Tangkapan tab memakai rute sungguhan lewat [potret]; tanggal mengikuti hari
  // berjalan, jadi tangkapan ini harus dibuat ulang bila ganti hari/UI:
  //   flutter test test/tangkapan_layar_test.dart --update-goldens
  testWidgets('tangkapan layar tab hari ini',
      (t) => potret(t, 'today', '/today', prefiks: 'f5'),
      skip: !_fontTersedia);
  testWidgets('tangkapan layar tab uang',
      (t) => potret(t, 'uang', '/uang', prefiks: 'f5'),
      skip: !_fontTersedia);
  testWidgets('tangkapan layar tab kerja',
      (t) => potret(t, 'kerja', '/kerja', prefiks: 'f5'),
      skip: !_fontTersedia);
  testWidgets('tangkapan layar tab ibadah',
      (t) => potret(t, 'ibadah', '/ibadah', prefiks: 'f5'),
      skip: !_fontTersedia);
  testWidgets('tangkapan layar tab lainnya',
      (t) => potret(t, 'lainnya', '/lainnya', prefiks: 'f5'),
      skip: !_fontTersedia);
  // FR-101: dasbor kesehatan — kalimat pembuka, angka terakhir, pintu pencatat.
  testWidgets('tangkapan layar tab kesehatan',
      (t) => potret(t, 'kesehatan', '/kesehatan', prefiks: 'f6'),
      skip: !_fontTersedia);
  // Ringkasan pagi memuat hitung mundur waktu sholat, jadi jamnya DIPATOK;
  // kalau memakai rute biasa isinya berubah setiap menit dan uji emas gagal.
  Future<void> potretBriefing(WidgetTester tester, String nama) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(_db)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTema.terang().copyWith(
          textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Roboto'),
        ),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: BriefingPagiScreen(jamSekarang: () => DateTime(2026, 9, 13, 9)),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/f5_$nama.png'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('tangkapan layar ringkasan pagi',
      (t) => potretBriefing(t, 'briefing'),
      skip: !_fontTersedia);

  // FR-88: layar pelacakan sholat, sudah berisi 3 dari 5 waktu tercatat.
  // Jam dipatok (bukan DateTime.now) supaya isi tangkapan layar tetap sama.
  Future<void> potretPelacakan(WidgetTester tester, String nama) async {
    final Directory dir = Directory.systemTemp.createTempSync('demo_log_');
    File('${dir.path}/log_sholat.json').writeAsStringSync(jsonEncode(<String, dynamic>{
      'versi': 1,
      'diubah': '2026-09-13T00:00:00.000Z',
      'hari': <String, dynamic>{
        '2026-09-13': <String>['subuh', 'dzuhur', 'ashar'],
      },
    }));
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTema.terang().copyWith(
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Roboto'),
      ),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: PelacakanSholatScreen(
        // 13 Sep 2026, 03.00 WIB -> tanggal sipil kota 2026-09-13.
        jamSekarang: () => DateTime.utc(2026, 9, 12, 20, 0),
        penyimpanan: PenyimpananJadwal(
          penentuFolder: () => Future.value(dir),
        ),
        penyimpananLog: PenyimpananLogSholat(
          penentuFolder: () => Future.value(dir),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/f5_$nama.png'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('tangkapan layar pelacakan sholat',
      (t) => potretPelacakan(t, 'pelacakan_sholat'),
      skip: !_fontTersedia);

  // ---- Modul uang V1.5 (FR-68/71/72/76) -----------------------------------
  /// Contoh dokumen penting untuk tangkapan layar FR-128/129.
  Future<void> isiDokumenDemo() async {
    final repo = DokumenRepository(_db, jamSekarang: () => _waktuUji);
    await repo.simpan(
        nama: 'KTP',
        jenis: 'ktp',
        nomor: '3171xxxxxxxx0001',
        berlakuSampai: DateTime(2026, 11, 30),
        berkasNama: 'ktp.jpg');
    await repo.simpan(
        nama: 'Paspor Indonesia',
        jenis: 'paspor',
        nomor: 'B1234567',
        berlakuSampai: DateTime(2029, 4, 17),
        berkasNama: 'paspor.pdf');
    await repo.simpan(
        nama: 'SIM A',
        jenis: 'sim',
        nomor: 'SIM-2233',
        berlakuSampai: DateTime(2026, 9, 14),
        berkasNama: 'sim.jpg');
    await repo.simpan(
        nama: 'Asuransi Kesehatan',
        jenis: 'polis',
        nomor: 'PLS-8899',
        berlakuSampai: DateTime(2027, 1, 31),
        berkasNama: 'polis.pdf');
  }

  testWidgets('tangkapan layar arus kas', (t) async {
    await isiUangDemo();
    await potret(t, 'arus_kas', '/uang/transaksi', prefiks: 'f6');
  }, skip: !_fontTersedia);

  testWidgets('tangkapan layar anggaran', (t) async {
    await isiUangDemo();
    await potret(t, 'anggaran', '/uang/anggaran', prefiks: 'f6');
  }, skip: !_fontTersedia);

  testWidgets('tangkapan layar langganan', (t) async {
    await isiUangDemo();
    await potret(t, 'langganan', '/uang/langganan', prefiks: 'f6');
  }, skip: !_fontTersedia);

  testWidgets('tangkapan layar kekayaan', (t) async {
    await isiUangDemo();
    await potret(t, 'kekayaan', '/uang/kekayaan', prefiks: 'f6');
  }, skip: !_fontTersedia);

  testWidgets('tangkapan layar cadangan (FR-24)',
      (t) => potretCadangan(t, 'cadangan'),
      skip: !_fontTersedia);

  // ---- FR-08: kelola kategori tagihan --------------------------------------
  testWidgets('tangkapan layar kelola kategori (FR-08)', (t) async {
    await potret(t, 'kategori_tagihan', '/tagihan/kategori',
        prefiks: 'f11',
        pumpLanjutan: 40,
        periksa: (WidgetTester t) {
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.byKey(const Key('tambah_kategori_tagihan')),
              findsOneWidget);
          expect(find.text('Kategori tagihan'), findsWidgets);
        });
  }, skip: !_fontTersedia);

  // ---- Batch 3 V2: kalender keuangan, laporan bulanan, dokumen -------------
  testWidgets('tangkapan layar kalender keuangan (FR-73)', (t) async {
    await isiUangDemo();
    await potret(t, 'kalender_keuangan', '/kalender-keuangan',
        prefiks: 'f12',
        pumpLanjutan: 30,
        periksa: (WidgetTester t) {
          expect(find.text('Kalender Keuangan'), findsOneWidget);
          expect(find.byKey(const Key('daftar_hari')), findsOneWidget);
          expect(find.byKey(const Key('total_keluar')), findsOneWidget);
          // Kalender harus benar-benar berisi: minimal satu titik peristiwa.
          expect(
              find.byWidgetPredicate((w) =>
                  w.key is ValueKey<String> &&
                  (w.key as ValueKey<String>).value.startsWith('titik_')),
              findsWidgets,
              reason: 'kalender kosong bukan bukti yang jujur');
        });
  }, skip: !_fontTersedia);

  testWidgets('tangkapan layar laporan bulanan (FR-77)', (t) async {
    await isiUangDemo();
    await potret(t, 'laporan_bulanan', '/laporan/bulanan',
        prefiks: 'f12',
        pumpLanjutan: 30,
        periksa: (WidgetTester t) {
          expect(find.text('Laporan Bulanan'), findsOneWidget);
          // Tombol unduh ada di bawah daftar (di luar viewport), jadi yang
          // dipastikan di sini adalah ringkasan bulan yang terlihat.
          expect(find.byKey(const Key('label_bulan')), findsOneWidget);
          expect(find.byKey(const Key('ringkasan_bulanan')), findsOneWidget);
        });
  }, skip: !_fontTersedia);

  testWidgets('tangkapan layar dokumen (FR-128/129)', (t) async {
    await isiDokumenDemo();
    await potret(t, 'dokumen', '/dokumen',
        prefiks: 'f12',
        pumpLanjutan: 30,
        periksa: (WidgetTester t) {
          expect(find.text('Dokumen penting'), findsWidgets);
          expect(find.textContaining('KTP'), findsWidgets);
        });
  }, skip: !_fontTersedia);
}

/// Tangkapan layar FR-24. Folder dokumen disuntik ke folder sementara supaya
/// daftar berkas cadangan pasti terbaca dan hasil gambar stabil.
Future<void> potretCadangan(WidgetTester tester, String nama) async {
  final Directory dir = Directory.systemTemp.createTempSync('potret_cadangan_');
  File('${dir.path}${Platform.pathSeparator}plo_backup_20260910_0900.json')
      .writeAsStringSync(jsonEncode(<String, Object>{
    'format': 'plo-backup',
    'versiSkema': 3,
    'versiAplikasi': '1.0.0+1',
    'dibuatPada': '2026-09-10T09:00:00.000Z',
    'tabel': <String, Object>{
      'tagihan': <Object>[],
      'kategori': <Object>[],
    },
  }));
  // Waktu ubah berkas dibekukan: layar menampilkan "Diubah <tanggal>", dan
  // waktu berkas asli ikut berubah tiap kali uji dijalankan sehingga gambar
  // emas tidak akan pernah cocok.
  File('${dir.path}${Platform.pathSeparator}plo_backup_20260910_0900.json')
      .setLastModifiedSync(DateTime(2026, 9, 10, 9, 0));

  // 420x1500: layar Cadangan kini memuat baris keadaan enkripsi basis data,
  // jadi seluruh kartu (ekspor - otomatis - impor) perlu ikut tertangkap.
  await tester.binding.setSurfaceSize(const Size(420, 1500));
  await tester.pumpWidget(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(_db)],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTema.terang().copyWith(
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Roboto'),
      ),
      locale: const Locale('id', 'ID'),
      supportedLocales: const <Locale>[Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: BackupScreen(
        folderCadangan: () => Future<Directory>.value(dir),
        jamSekarang: () => DateTime(2026, 9, 10, 9, 0),
      ),
    ),
  ));
  await tester.pump();
  for (int i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.byType(CircularProgressIndicator), findsNothing);
  expect(find.byKey(const Key('ekspor_sekarang')), findsOneWidget);
  expect(find.byKey(const Key('impor_berkas_plo_backup_20260910_0900.json')),
      findsOneWidget);

  await expectLater(
      find.byType(MaterialApp), matchesGoldenFile('goldens/f10_$nama.png'));

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  await tester.binding.setSurfaceSize(null);
  dir.deleteSync(recursive: true);
}

/// Tangkapan layar FR-89. Berkas log ditulis ke folder sementara (IO sinkron),
/// lalu layar dibangun langsung dengan jam tetap supaya hasilnya stabil.
Future<void> potretRekap(WidgetTester tester, String nama) async {
  final Directory dir = Directory.systemTemp.createTempSync('potret_rekap_');
  File('${dir.path}${Platform.pathSeparator}log_sholat.json')
      .writeAsStringSync(jsonEncode(<String, Object>{
    'versi': 1,
    'diubah': '2026-09-07T00:00:00.000Z',
    'hari': <String, Object>{
      '2026-09-01': <String>['subuh', 'dzuhur', 'ashar', 'maghrib', 'isya'],
      '2026-09-02': <String>['subuh', 'dzuhur'],
      '2026-09-03': <String>['subuh', 'maghrib', 'isya'],
      '2026-09-04': <String>[],
      '2026-09-05': <String>['subuh'],
      '2026-09-06': <String>['subuh', 'ashar'],
      '2026-09-07': <String>['subuh', 'dzuhur', 'ashar', 'maghrib'],
    },
  }));

  await tester.binding.setSurfaceSize(const Size(420, 900));
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTema.terang().copyWith(
      textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Roboto'),
    ),
    locale: const Locale('id', 'ID'),
    supportedLocales: const <Locale>[Locale('id', 'ID'), Locale('en', 'US')],
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: RekapSholatScreen(
      penyimpananLog: PenyimpananLogSholat(
          penentuFolder: () => Future<Directory>.value(dir)),
      jamSekarang: () => DateTime(2026, 9, 7, 9, 0),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));

  await expectLater(
      find.byType(MaterialApp), matchesGoldenFile('goldens/f7_$nama.png'));

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  await tester.binding.setSurfaceSize(null);
  dir.deleteSync(recursive: true);
}

/// Layanan notifikasi contoh: hasil tetap agar tangkapan layar stabil.
class _LayananDemo implements LayananNotifikasi {
  // PB-09/PB-10: bagian diagnostik antarmuka (nilai bawaan untuk uji).
  @override
  HasilPasang? get hasilPasangTerakhir => null;

  @override
  bool get siap => true;

  @override
  Future<void> siapkan() async {}

  @override
  Future<StatusIzinPengingat> statusIzin() async =>
      const StatusIzinPengingat(notifikasiDiizinkan: true, alarmTepatDiizinkan: false);

  @override
  Future<bool> mintaIzinNotifikasi() async => true;

  @override
  Future<bool> mintaIzinAlarmTepat() async => true;

  @override
  Future<void> pasangJadwal(List<Pengingat> daftar) async {}

  @override
  Future<void> batalkanSemua() async {}

  @override
  Future<void> jadwalkanSatu(Pengingat p) async {}

  @override
  Future<void> tampilkanUji({Duration tunda = const Duration(seconds: 10)}) async {}

  @override
  Future<List<({int id, String? judul, DateTime? waktu})>> tertunda() async => [
        (id: 1, judul: 'Listrik PLN — 3 hari lagi', waktu: waktuSekarang().add(const Duration(days: 3))),
        (id: 2, judul: 'Internet IndiHome — besok', waktu: waktuSekarang().add(const Duration(days: 1))),
      ];
}

late AppDatabase _db;
