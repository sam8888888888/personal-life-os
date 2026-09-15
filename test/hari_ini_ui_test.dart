/// Uji UI Modul 0 (FR-60 … FR-63) + tab V1.5, ukuran layar ponsel 420x900.
///
/// Catatan teknis: data uji disiapkan di `setUp` (zona async nyata) supaya
/// widget test (zona waktu palsu) tidak menunggu IO.
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/app_router.dart';
import 'package:personal_life_os/core/hari_ini/model_hari_ini.dart';
import 'dart:convert';
import 'dart:io';

import 'package:personal_life_os/core/ibadah/penyimpanan_jadwal.dart';
import 'package:personal_life_os/core/ibadah/penyimpanan_log_sholat.dart';
import 'package:personal_life_os/core/notifikasi/layanan_notifikasi.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/utils/waktu.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/hari_ini/briefing_pagi_screen.dart';
import 'package:personal_life_os/features/hari_ini/hari_ini_screen.dart';
import 'package:personal_life_os/features/hari_ini/ibadah_hub_screen.dart';
import 'package:personal_life_os/features/hari_ini/kerja_screen.dart';
import 'package:personal_life_os/features/ibadah/pelacakan_sholat_screen.dart';
import 'package:personal_life_os/features/pengaturan/backup_screen.dart';
import 'package:personal_life_os/features/hari_ini/lainnya_screen.dart';
import 'package:personal_life_os/features/uang/uang_hub_screen.dart';

late AppDatabase db;
late bool izinUji;

/// Waktu patok uji: 13 September 2026, 09.00 (sebelum tengah hari).
final jamPagi = DateTime(2026, 9, 13, 9);
final jamMalam = DateTime(2026, 9, 13, 20);

Future<void> tambah({
  required String nama,
  required DateTime jatuhTempo,
  int? jumlahSen = 45000000,
  String jenis = 'tagihan',
  bool lunas = false,
  bool aktif = true,
}) async {
  await TagihanRepository(db).tambah(TagihanCompanion.insert(
    nama: nama,
    jumlahSen: Value(jumlahSen),
    jatuhTempo: jatuhTempo,
    jenis: Value(jenis),
    lunas: Value(lunas),
    statusAktif: Value(aktif),
  ));
}

/// Tiga tagihan uji dengan nominal EKSPLISIT (jangan bergantung nilai bawaan).
///   Listrik PLN : lewat 5 hari · Rp 450.000
///   BPJS        : jatuh tempo hari ini · Rp 150.000
///   STNK        : dokumen, 18 hari lagi · tanpa nominal
Future<void> isiTigaTagihan() async {
  await tambah(nama: 'Listrik PLN', jatuhTempo: DateTime(2026, 9, 8),
      jumlahSen: 45000000);
  await tambah(nama: 'BPJS', jatuhTempo: DateTime(2026, 9, 13),
      jumlahSen: 15000000);
  await tambah(nama: 'STNK', jatuhTempo: DateTime(2026, 10, 1),
      jumlahSen: null, jenis: 'dokumen');
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    izinUji = true;
    TestWidgetsFlutterBinding.ensureInitialized();
  });
  tearDown(() => db.close());

  /// Menampilkan satu layar langsung (tanpa router) + jam yang disuntik.
  Future<void> tampilkan(WidgetTester t, Widget layar) async {
    await t.binding.setSurfaceSize(const Size(420, 900));
    await t.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        statusIzinPengingatProvider.overrideWith((ref) async =>
            StatusIzinPengingat(
                notifikasiDiizinkan: izinUji, alarmTepatDiizinkan: izinUji)),
      ],
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

  /// Buka lewat router (untuk uji pindah tab & tombol navigasi).
  Future<void> bukaRouter(WidgetTester t, {String awal = '/today'}) async {
    await t.binding.setSurfaceSize(const Size(420, 900));
    await t.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        statusIzinPengingatProvider.overrideWith((ref) async =>
            StatusIzinPengingat(notifikasiDiizinkan: true, alarmTepatDiizinkan: true)),
      ],
      child: MaterialApp.router(
        theme: AppTema.terang(),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: buatRouter(awal: awal),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
  }

  /// Gulir daftar ke bawah sampai target terlihat (ListView hanya membangun
  /// baris yang terlihat).
  Future<void> gulirKe(WidgetTester t, Finder target, {int maks = 8}) async {
    for (var i = 0; i < maks; i++) {
      if (target.evaluate().isNotEmpty) break;
      await t.drag(find.byType(Scrollable).first, const Offset(0, -220));
      await t.pump(const Duration(milliseconds: 120));
    }
    // Widget bisa sudah dibangun tetapi masih di bawah lipatan; ketukan ke
    // widget di luar layar akan meleset, jadi pastikan terlihat dulu.
    if (target.evaluate().isNotEmpty) {
      await t.ensureVisible(target);
      await t.pump(const Duration(milliseconds: 120));
    }
  }

  List<String> teksTampil(WidgetTester t) => t
      .widgetList<Text>(find.byType(Text))
      .map((w) => w.data ?? '')
      .where((s) => s.isNotEmpty)
      .toList();

  group('FR-60/61 Hari Ini', () {
    testWidgets('kepala layar: sapaan, tanggal, Hijriah, catatan perhitungan',
        (t) async {
      await tampilkan(t, HariIniScreen(jamSekarang: () => jamPagi));
      expect(find.text('Assalamualaikum, Anda'), findsOneWidget);
      expect(find.textContaining('perhitungan, bukan penetapan resmi'), findsOneWidget);
      expect(find.textContaining('H'), findsWidgets); // label Hijriah
      await tutup(t);
    });

    testWidgets('lima kartu pilar tampil dengan nama tetap', (t) async {
      await tampilkan(t, HariIniScreen(jamSekarang: () => jamPagi));
      for (final p in Pilar.values) {
        expect(find.text(p.label), findsOneWidget, reason: p.label);
      }
      expect(find.text('Pilar hari ini'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('tanpa data: 3 kartu menulis "Belum ada data", bukan angka 0',
        (t) async {
      await tampilkan(t, HariIniScreen(jamSekarang: () => jamPagi));
      expect(find.text('Belum ada data'), findsNWidgets(3)); // kesehatan, keluarga, produktivitas
      expect(find.text('Belum ada tagihan'), findsOneWidget);
      expect(find.text('Belum ada catatan hari ini'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      await tutup(t);
    });

    testWidgets('dengan tagihan: angka uang nyata + Perhatian menampilkan tombol Bayar',
        (t) async {
      await isiTigaTagihan();
      await tampilkan(t, HariIniScreen(jamSekarang: () => jamPagi));
      // Yang dihitung "≤7 hari" hanya yang belum jatuh tempo (BPJS = 1);
      // nominal belum dibayar mencakup yang lewat: 450rb + 150rb = Rp 600.000.
      expect(find.textContaining('Jatuh tempo ≤7 hari: 1'), findsOneWidget);
      expect(find.textContaining('Rp 600.000'), findsOneWidget);
      await gulirKe(t, find.text('Tagihan terlambat'));
      expect(find.text('Tagihan terlambat'), findsOneWidget);
      expect(find.text('Bayar'), findsWidgets);
      await tutup(t);
    });

    testWidgets('kartu Ringkasan pagi hanya muncul sebelum tengah hari',
        (t) async {
      await tampilkan(t, HariIniScreen(jamSekarang: () => jamPagi));
      expect(find.text('Ringkasan pagi'), findsOneWidget);
      await tutup(t);

      await tampilkan(t, HariIniScreen(jamSekarang: () => jamMalam));
      expect(find.text('Ringkasan pagi'), findsNothing);
      await tutup(t);
    });

    testWidgets('pilar Ibadah memakai catatan FR-88 yang disuntik', (t) async {
      await tampilkan(
        t,
        HariIniScreen(jamSekarang: () => jamPagi, ambilJumlahSholatTercatat: () async => 3),
      );
      await t.pump(const Duration(milliseconds: 100));
      await gulirKe(t, find.text('3 dari 5 waktu tercatat'));
      expect(find.text('3 dari 5 waktu tercatat'), findsOneWidget);
      expect(find.textContaining('Belum tercatat bukan berarti'), findsWidgets);
      await tutup(t);
    });

    testWidgets('agenda dibatasi 6 baris dan menawarkan "Lihat semua (N)"',
        (t) async {
      for (var i = 0; i < 8; i++) {
        await tambah(
            nama: 'Dokumen $i',
            jatuhTempo: DateTime(2026, 9, 20 + i),
            jumlahSen: null,
            jenis: 'dokumen');
      }
      await tampilkan(t, HariIniScreen(jamSekarang: () => jamPagi));
      await gulirKe(t, find.text('Lihat semua (8)'));
      expect(find.text('Lihat semua (8)'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('bahasa layar bebas kata menghakimi (III-11)', (t) async {
      await isiTigaTagihan();
      izinUji = false; // izin mati -> butir hambatan sistem ikut diuji
      await tampilkan(
        t,
        HariIniScreen(jamSekarang: () => jamPagi, ambilJumlahSholatTercatat: () async => 2),
      );
      // buka juga seluruh blok dengan menggulir ke bawah
      for (var i = 0; i < 6; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -260));
        await t.pump(const Duration(milliseconds: 100));
      }
      const terlarang = [
        'skor iman', 'anda gagal', 'kamu', 'berdosa', 'kafir',
        'belum sholat', 'wajib anda', 'gagal',
      ];
      for (final teks in teksTampil(t)) {
        for (final kata in terlarang) {
          expect(teks.toLowerCase().contains(kata), isFalse,
              reason: '"$teks" memuat "$kata"');
        }
      }
      expect(find.text('Izin notifikasi mati'), findsWidgets);
      await tutup(t);
    });
  });

  group('Tab V1.5 (Kerja, Ibadah, Lainnya, Uang)', () {
    testWidgets('Kerja: agenda 7 hari + keadaan kosong jujur', (t) async {
      await tampilkan(t, KerjaScreen(jamSekarang: () => jamPagi));
      expect(find.text('Agenda 7 hari ke depan'), findsOneWidget);
      expect(find.text('Belum ada agenda 7 hari ke depan'), findsOneWidget);
      await gulirKe(t, find.text('Belum ada data — modul tugas menyusul'));
      expect(find.text('Belum ada data — modul tugas menyusul'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('Kerja: tagihan terdekat muncul di agenda', (t) async {
      await isiTigaTagihan();
      await tampilkan(t, KerjaScreen(jamSekarang: () => jamPagi));
      expect(find.text('BPJS'), findsOneWidget);
      await tutup(t);
    });

    testWidgets(
        'Ibadah hub: pintu jadwal, pelacakan, riwayat, kalender + catatan jujur',
        (t) async {
      await tampilkan(t, const IbadahHubScreen());
      expect(find.text('Jadwal sholat'), findsOneWidget);
      expect(find.text('Pelacakan 5 waktu'), findsOneWidget);
      expect(find.text('Riwayat & konsistensi'), findsOneWidget);
      expect(find.text('Kalender Hijriah'), findsOneWidget);
      await gulirKe(t, find.textContaining('bukan jadwal resmi'));
      expect(find.textContaining('bukan jadwal resmi'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('Lainnya: pengingat, pengaturan, ringkasan pagi', (t) async {
      await tampilkan(t, const LainnyaScreen());
      expect(find.text('Ringkasan pagi'), findsOneWidget);
      expect(find.text('Pengingat & Izin'), findsOneWidget);
      expect(find.text('Pengaturan'), findsOneWidget);
      await gulirKe(t, find.textContaining('versi 0.5.0'));
      expect(find.textContaining('versi 0.5.0'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('Uang hub: dasbor/daftar/kalender + pintu 4 modul V1.5 aktif',
        (t) async {
      await isiTigaTagihan();
      await tampilkan(t, UangHubScreen(jamSekarang: () => jamPagi));
      expect(find.text('Dasbor uang'), findsOneWidget);
      expect(find.text('Daftar tagihan'), findsOneWidget);
      expect(find.text('Kalender uang'), findsOneWidget);
      await gulirKe(t, find.text('Kekayaan bersih'));
      expect(find.text('Arus kas'), findsOneWidget);
      expect(find.text('Anggaran bulanan'), findsOneWidget);
      expect(find.text('Langganan'), findsOneWidget);
      expect(find.text('Kekayaan bersih'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('rute 4 modul uang V1.5 bisa dibuka lewat router', (t) async {
      const tujuan = {
        '/uang/transaksi': 'Arus Kas',
        '/uang/anggaran': 'Anggaran bulanan',
        '/uang/langganan': 'Langganan',
        '/uang/kekayaan': 'Kekayaan Bersih',
      };
      for (final r in tujuan.entries) {
        await bukaRouter(t, awal: r.key);
        await t.pumpAndSettle(const Duration(milliseconds: 50));
        expect(find.text(r.value), findsWidgets,
            reason: 'judul ${r.value} tidak muncul di ${r.key}');
        expect(t.takeException(), isNull);
        await tutup(t);
      }
    });
  });

  group('FR-63 Ringkasan pagi', () {
    testWidgets('blok utama tampil + tombol Mulai hari & Tutup', (t) async {
      await tampilkan(t, BriefingPagiScreen(jamSekarang: () => jamPagi));
      expect(find.text('Assalamualaikum, Anda'), findsOneWidget);
      expect(find.textContaining('Agenda hari ini'), findsOneWidget);
      expect(find.textContaining('Tagihan 7 hari ke depan'), findsOneWidget);
      expect(find.text('Mulai hari'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('daring: cuaca belum ada sumber -> ditulis apa adanya', (t) async {
      await tampilkan(t, BriefingPagiScreen(jamSekarang: () => jamPagi));
      expect(find.text('Belum ada data cuaca — modul cuaca menyusul'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('offline: blok cuaca diganti keterangan offline', (t) async {
      await tampilkan(
          t, BriefingPagiScreen(jamSekarang: () => jamPagi, daring: false));
      expect(find.text('Offline — cuaca tidak tersedia'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('dengan tagihan: total 7 hari tampil', (t) async {
      await isiTigaTagihan();
      await tampilkan(t, BriefingPagiScreen(jamSekarang: () => jamPagi));
      // Yang lewat tidak masuk blok "7 hari ke depan": hanya BPJS Rp 150.000.
      await gulirKe(t, find.textContaining('Total Rp 150.000'));
      expect(find.textContaining('Total Rp 150.000'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('waktu sholat berikutnya dihitung untuk kota bawaan', (t) async {
      await tampilkan(t, BriefingPagiScreen(jamSekarang: () => jamPagi));
      await gulirKe(t, find.text('Waktu sholat berikutnya'));
      expect(find.text('Waktu sholat berikutnya'), findsOneWidget);
      expect(find.textContaining('lagi'), findsWidgets);
      await tutup(t);
    });
  });

  group('FR-88 Pelacakan sholat dari tab Ibadah', () {
    testWidgets('catatan tersimpan di berkas dibaca dan ditampilkan',
        (t) async {
      // Folder sementara + berkas catatan disiapkan SINKRON (aturan uji widget).
      final dir = Directory.systemTemp.createTempSync('uji_log_');
      File('${dir.path}/log_sholat.json').writeAsStringSync(jsonEncode({
        'versi': 1,
        'diubah': '2026-09-13T00:00:00.000Z',
        'hari': {
          '2026-09-13': ['subuh', 'dzuhur', 'ashar'],
        },
      }));
      await tampilkan(
        t,
        PelacakanSholatScreen(
          jamSekarang: () => DateTime.utc(2026, 9, 12, 20, 0), // 13 Sep WIB
          penyimpanan: PenyimpananJadwal(penentuFolder: () => Future.value(dir)),
          penyimpananLog:
              PenyimpananLogSholat(penentuFolder: () => Future.value(dir)),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await gulirKe(t, find.text('3 dari 5 waktu tercatat hari ini'));
      expect(find.text('3 dari 5 waktu tercatat hari ini'), findsOneWidget);
      // Bahasa netral: tidak ada skor/penilaian (III-11)
      for (final s in teksTampil(t)) {
        expect(s.toLowerCase().contains('skor'), isFalse, reason: s);
      }
      await tutup(t);
    });
  });

  group('Navigasi 5 tab', () {
    testWidgets('tab bawah memuat 5 tujuan dan bisa berpindah', (t) async {
      await bukaRouter(t);
      expect(find.text('Pilar hari ini'), findsOneWidget);

      Finder tabIkon(IconData i) => find.descendant(
          of: find.byType(NavigationBar), matching: find.byIcon(i));

      await t.tap(tabIkon(Icons.account_balance_wallet_outlined));
      await t.pumpAndSettle(const Duration(milliseconds: 50));
      expect(find.text('Dasbor uang'), findsOneWidget);

      await t.tap(tabIkon(Icons.work_outline));
      await t.pumpAndSettle(const Duration(milliseconds: 50));
      expect(find.text('Agenda 7 hari ke depan'), findsOneWidget);

      await t.tap(tabIkon(Icons.mosque_outlined));
      await t.pumpAndSettle(const Duration(milliseconds: 50));
      expect(find.text('Jadwal sholat'), findsOneWidget);

      await t.tap(tabIkon(Icons.more_horiz_outlined));
      await t.pumpAndSettle(const Duration(milliseconds: 50));
      expect(find.text('Pengingat & Izin'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('dari tab Ibadah bisa membuka pelacakan sholat (FR-88)', (t) async {
      await bukaRouter(t, awal: '/ibadah');
      await t.tap(find.text('Pelacakan 5 waktu'));
      await t.pumpAndSettle(const Duration(milliseconds: 50));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      // Isi bergantung pembacaan berkas catatan; yang dipastikan di sini:
      // layar FR-88 benar-benar terbuka lewat tab Ibadah.
      expect(find.text('Pelacakan Sholat'), findsOneWidget);
      expect(find.text('Jadwal sholat'), findsNothing); // sudah pindah layar
      await tutup(t);
    });

    testWidgets('dari tab Ibadah bisa membuka riwayat rekap (FR-89)',
        (t) async {
      await bukaRouter(t, awal: '/ibadah');
      await t.tap(find.text('Riwayat & konsistensi'));
      await t.pump();
      for (var i = 0; i < 55; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      // Layar FR-89 terbuka lewat tab Ibadah. Isi angka bergantung berkas
      // catatan di perangkat, jadi yang dipastikan di sini judul + kalimat
      // netralnya (bahasa "tercatat", bukan penilaian).
      expect(find.text('Riwayat sholat'), findsOneWidget);
      expect(find.textContaining('bukan berarti tidak dikerjakan'),
          findsOneWidget);
      await tutup(t);
    });

    testWidgets('rute /ibadah/rekap membuka layar riwayat (FR-89)', (t) async {
      await bukaRouter(t, awal: '/ibadah/rekap');
      // Tanpa penyimpanan yang disuntik, berkas catatan tidak bisa dibaca di
      // lingkungan uji; layar harus tetap tenang (tidak berputar selamanya)
      // dan menampilkan kalimat jujur.
      for (var i = 0; i < 55; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Riwayat sholat'), findsOneWidget);
      expect(find.byKey(const Key('pilih_7')), findsOneWidget);
      expect(find.byKey(const Key('pilih_30')), findsOneWidget);
      await tutup(t);
    });

    testWidgets('dari tab Ibadah bisa membuka Pengingat Ibadah (FR-63 & FR-87)',
        (t) async {
      await bukaRouter(t, awal: '/ibadah');
      await t.tap(find.byKey(const Key('buka_pengingat_ibadah')));
      await t.pump();
      for (var i = 0; i < 55; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Pengingat Ibadah'), findsOneWidget);
      expect(find.text('Ringkasan pagi'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('rute /ibadah/pengingat membuka setelan pengingat (FR-63 & FR-87)',
        (t) async {
      await bukaRouter(t, awal: '/ibadah/pengingat');
      for (var i = 0; i < 55; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      // Pembacaan setelan boleh lambat/gagal di lingkungan uji; layar tetap
      // harus tenang (tidak berputar selamanya) dan menampilkan pilihannya.
      expect(find.text('Pengingat Ibadah'), findsOneWidget);
      expect(find.byKey(const Key('saklar_briefing')), findsOneWidget);
      expect(find.byKey(const Key('saklar_sholat')), findsOneWidget);
      await tutup(t);
    });

    testWidgets('Uang hub punya pintu grafik beban tagihan (FR-28)', (t) async {
      await bukaRouter(t, awal: '/uang');
      await gulirKe(t, find.byKey(const Key('buka_beban_tagihan')));
      expect(find.byKey(const Key('buka_beban_tagihan')), findsOneWidget);
      await t.tap(find.byKey(const Key('buka_beban_tagihan')));
      await t.pump();
      for (var i = 0; i < 40; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Beban tagihan'), findsWidgets);
      expect(t.takeException(), isNull);
      await tutup(t);
    });

    testWidgets('rute /laporan/beban-tagihan bisa dibuka (FR-28)', (t) async {
      await bukaRouter(t, awal: '/laporan/beban-tagihan');
      for (var i = 0; i < 40; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Beban tagihan'), findsWidgets);
      expect(find.byKey(const Key('grafik_beban')), findsOneWidget);
      await tutup(t);
    });

    testWidgets('rute /tagihan/kategori membuka kelola kategori (FR-08)',
        (t) async {
      await bukaRouter(t, awal: '/tagihan/kategori');
      for (var i = 0; i < 40; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Kategori tagihan'), findsWidgets);
      expect(find.byKey(const Key('tambah_kategori_tagihan')), findsOneWidget);
      expect(t.takeException(), isNull);
      await tutup(t);
    });

    testWidgets('Pengaturan punya pintu cadangan & rute /cadangan (FR-24)',
        (t) async {
      await bukaRouter(t, awal: '/pengaturan');
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await gulirKe(t, find.byKey(const Key('buka_cadangan')));
      expect(find.byKey(const Key('buka_cadangan')), findsOneWidget);
      await t.tap(find.byKey(const Key('buka_cadangan')));
      await t.pump();
      for (var i = 0; i < 70; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      // Layar cadangan menunggu folder dokumen dari lapisan platform; di
      // dalam uji lapisan itu tidak menjawab sehingga baru selesai setelah
      // batas waktu 5 detik. Lihat cacat 17 di laporan.
      expect(find.byKey(const Key('ekspor_sekarang')), findsOneWidget);
      expect(t.takeException(), isNull);
      await tutup(t);
    });

    testWidgets('rute /cadangan bisa dibuka langsung (FR-24)', (t) async {
      await bukaRouter(t, awal: '/cadangan');
      for (var i = 0; i < 70; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(BackupScreen), findsOneWidget);
      expect(find.text('Cadangan & Pemulihan'), findsWidgets);
      expect(find.byKey(const Key('ekspor_sekarang')), findsOneWidget);
      await tutup(t);
    });

    testWidgets('tombol tambah membuka form tagihan', (t) async {
      await bukaRouter(t);
      await t.tap(find.byType(FloatingActionButton));
      await t.pumpAndSettle(const Duration(milliseconds: 50));
      expect(find.text('Tambah Tagihan'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('halaman Ringkasan lama masih bisa dibuka lewat /ringkasan',
        (t) async {
      await bukaRouter(t, awal: '/ringkasan');
      expect(find.text('Uang tersisa bulan ini'), findsOneWidget);
      await tutup(t);
    });
  });

  // ---- FR-65: Today dan Kalender membaca satu sumber data -------------------
  // Kriteria PRD: "Menambah item di satu tempat langsung tampil di tempat lain
  // (uji: tambah -> muncul di dua tempat)".
  group('FR-65 sinkron Today <-> Kalender', () {
    testWidgets('tagihan baru langsung tampil di Today lalu terlihat di Kalender',
        (t) async {
      pakaiSumberWaktu(() => jamPagi);
      addTearDown(pakaiWaktuAsli);

      await bukaRouter(t, awal: '/today');
      expect(find.text('Listrik PLN'), findsNothing);

      // Ditambah lewat repository (bukan lewat layar): membuktikan Today
      // mengikuti data bersama, bukan salinan sendiri.
      await t.runAsync(() => tambah(
          nama: 'Listrik PLN',
          jatuhTempo: DateTime(2026, 9, 13),
          jumlahSen: 45000000));
      // Aliran Drift butuh beberapa siklus pump sebelum baris dibangun.
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await gulirKe(t, find.text('Listrik PLN'));
      expect(find.text('Listrik PLN'), findsWidgets);
      await tutup(t);

      await bukaRouter(t, awal: '/kalender');
      expect(find.text('Listrik PLN'), findsWidgets);
      await tutup(t);
    });

    testWidgets(
        'tagihan yang sudah dibayar keluar dari Today, tetap tercatat di Kalender',
        (t) async {
      pakaiSumberWaktu(() => jamPagi);
      addTearDown(pakaiWaktuAsli);
      await tambah(
          nama: 'BPJS', jatuhTempo: DateTime(2026, 9, 13), jumlahSen: 15000000);
      await t.runAsync(() async {
        final repo = TagihanRepository(db);
        final id = (await repo.ambilSemua()).first.id;
        await repo.tandaiLunas(id, tanggalBayar: DateTime(2026, 9, 13));
      });

      await bukaRouter(t, awal: '/today');
      expect(find.text('BPJS'), findsNothing);
      await tutup(t);

      // PB-08: kalender menggabungkan catatan pembayaran + tagihan belum lunas,
      // jadi pembayaran masa lalu tidak hilang dari tanggalnya.
      await bukaRouter(t, awal: '/kalender');
      expect(find.text('BPJS'), findsWidgets);
      await tutup(t);
    });
  });
}
