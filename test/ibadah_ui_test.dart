import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/ibadah/kalender_hijriah.dart';
import 'package:personal_life_os/core/ibadah/kota_indonesia.dart';
import 'package:personal_life_os/core/ibadah/penghitung_sholat.dart';
import 'package:personal_life_os/core/ibadah/penyimpanan_jadwal.dart';
import 'package:personal_life_os/features/ibadah/jadwal_sholat_screen.dart';
import 'package:personal_life_os/features/ibadah/kalender_hijriah_screen.dart';

/// Jam tetap untuk pengujian: satu titik waktu (instan) = 13 Sep 2026 03.00 WIB.
final DateTime instanUji = DateTime.utc(2026, 9, 12, 20, 0);

late Directory dirUji;

Widget bungkus(Widget isi) => MaterialApp(home: isi);

/// Folder sementara dibuat SINKRON: operasi berkas asinkron di dalam
/// testWidgets masuk zona waktu palsu dan membuat uji menggantung.
PenyimpananJadwal penyimpananUji() =>
    PenyimpananJadwal(penentuFolder: () => Future<Directory>.value(dirUji));

Future<void> siapkan(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 900));
  dirUji = Directory.systemTemp.createTempSync('uji_ui_ibadah_');
}

Widget layarSholat() => bungkus(JadwalSholatScreen(
      jamSekarang: () => instanUji,
      penyimpanan: penyimpananUji(),
    ));

/// Gulir daftar utama sampai target terlihat. Dipakai karena layar HP hanya
/// membangun kartu yang terlihat (ListView malas bangun).
Future<void> gulirKe(WidgetTester tester, Finder target) async {
  final Finder daftar = find.byType(Scrollable).first;
  for (int i = 0; i < 30; i++) {
    if (target.evaluate().isNotEmpty) return;
    await tester.drag(daftar, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
  throw StateError('target tidak ditemukan setelah menggulir: $target');
}

/// Gulir balik ke atas sampai target (mis. tombol di kepala layar) terlihat.
Future<void> gulirKeAtas(WidgetTester tester, Finder target) async {
  final Finder daftar = find.byType(Scrollable).first;
  for (int i = 0; i < 30; i++) {
    if (target.evaluate().isNotEmpty) return;
    await tester.drag(daftar, const Offset(0, 200));
    await tester.pumpAndSettle();
  }
  throw StateError('target tidak ditemukan setelah menggulir ke atas: $target');
}

List<String> teksTampil(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .where((String s) => s.isNotEmpty)
    .toList();

void main() {
  tearDown(() {
    if (dirUji.existsSync()) dirUji.deleteSync(recursive: true);
  });

  group('Layar Jadwal Sholat (FR-86)', () {
    testWidgets('menampilkan tanggal Hijriah, waktu berikutnya, dan penanda sumber',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(layarSholat());
      await tester.pumpAndSettle();

      expect(find.text('Jadwal Sholat'), findsOneWidget);
      expect(find.text('Berikutnya'), findsOneWidget);
      expect(find.textContaining('Subuh 04:30'), findsOneWidget);
      expect(find.textContaining('Sisa 1 jam 30 menit'), findsOneWidget);
      expect(find.text('2 Rabiul Akhir 1448 H'), findsOneWidget);
      expect(find.text('13-09-2026'), findsOneWidget);
      expect(find.textContaining('bukan penetapan resmi'), findsOneWidget);

      await gulirKe(tester, find.textContaining('Dihitung untuk Jakarta'));
      expect(find.textContaining('Dihitung untuk Jakarta'), findsOneWidget);
      expect(find.textContaining('WIB'), findsWidgets);

      // Enam waktu tampil, termasuk Syuruq sebagai penanda.
      for (final String label in <String>[
        'Subuh', 'Syuruq', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya',
      ]) {
        await gulirKe(tester, find.text(label));
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('18:59'), findsOneWidget);
      await gulirKe(tester, find.textContaining('Perhitungan, bukan jadwal resmi'));
      expect(find.textContaining('Perhitungan, bukan jadwal resmi'), findsOneWidget);
      expect(find.textContaining('tetap jalan tanpa internet'), findsOneWidget);
    });

    testWidgets('ganti metode mengubah waktu Isya', (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(layarSholat());
      await tester.pumpAndSettle();

      await gulirKe(tester, find.text('Metode perhitungan'));
      await tester.tap(find.byType(DropdownButtonFormField<MetodeHitungSholat>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Muslim World League').last);
      await tester.pumpAndSettle();

      await gulirKe(tester, find.text('Isya'));
      expect(find.text('18:55'), findsOneWidget);
      expect(find.text('18:59'), findsNothing);
      expect(find.text('Muslim World League'), findsWidgets);
    });

    testWidgets('ganti kota lewat pencarian mengubah zona ke WITA',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(layarSholat());
      await tester.pumpAndSettle();

      await gulirKe(tester, find.text('Kota'));
      await tester.tap(find.text('Kota'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Makassar');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Makassar').last);
      await tester.pumpAndSettle();

      await gulirKe(tester, find.textContaining('Dihitung untuk Makassar'));
      expect(find.textContaining('Dihitung untuk Makassar'), findsOneWidget);
      expect(find.textContaining('WITA'), findsWidgets);
      await gulirKe(tester, find.text('Subuh'));
      expect(find.text('04:39'), findsOneWidget);
    });

    testWidgets('koreksi kehati-hatian menggeser semua waktu',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(layarSholat());
      await tester.pumpAndSettle();

      await gulirKe(tester, find.byTooltip('Tambah satu menit'));
      await tester.tap(find.byTooltip('Tambah satu menit'));
      await tester.pumpAndSettle();
      expect(find.text('+1 menit untuk semua waktu'), findsOneWidget);

      await gulirKe(tester, find.text('Subuh'));
      expect(find.text('04:31'), findsOneWidget);

      await gulirKe(tester, find.byTooltip('Kurangi satu menit'));
      await tester.tap(find.byTooltip('Kurangi satu menit'));
      await tester.pumpAndSettle();
      expect(find.text('Tanpa koreksi'), findsOneWidget);
      await gulirKe(tester, find.text('Subuh'));
      expect(find.text('04:30'), findsOneWidget);
    });

    testWidgets('saklar madzhab Hanafi memundurkan Ashar',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(layarSholat());
      await tester.pumpAndSettle();

      await gulirKe(tester, find.text('Ashar'));
      expect(find.text('15:04'), findsOneWidget);

      await gulirKe(tester, find.text('Ashar madzhab Hanafi'));
      await tester.tap(find.text('Ashar madzhab Hanafi'));
      await tester.pumpAndSettle();

      await gulirKe(tester, find.text('Ashar'));
      expect(find.text('16:07'), findsOneWidget);
    });

    testWidgets('daftar kota lengkap bisa dicari', (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(layarSholat());
      await tester.pumpAndSettle();

      await gulirKe(tester, find.text('Kota'));
      await tester.tap(find.text('Kota'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih kota'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Papua');
      await tester.pumpAndSettle();
      expect(find.text('Jayapura'), findsOneWidget);
      expect(cariKota('Papua').length, greaterThanOrEqualTo(1));
    });
  });

  group('Layar Kalender Hijriah (FR-90)', () {
    testWidgets('menampilkan bulan berjalan dan hari ini',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(bungkus(
          KalenderHijriahScreen(jamSekarang: () => DateTime(2026, 9, 13))));
      await tester.pumpAndSettle();

      expect(find.text('Kalender Hijriah'), findsOneWidget);
      expect(find.text('Rabiul Akhir 1448 H'), findsOneWidget);
      expect(find.textContaining('Hari ini: 2 Rabiul Akhir 1448 H'), findsOneWidget);
      for (final String h in <String>['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Ahd']) {
        expect(find.text(h), findsOneWidget, reason: h);
      }
      await gulirKe(tester, find.textContaining('Umm al-Qura'));
      expect(find.text('Umm al-Qura'), findsWidgets);
      expect(find.textContaining('bukan penetapan resmi'), findsOneWidget);
      // Rabiul Akhir tidak punya hari besar pada daftar kami.
      await gulirKe(
          tester, find.text('Belum ada data hari besar pada bulan ini'));
      expect(find.text('Belum ada data hari besar pada bulan ini'), findsOneWidget);
    });

    testWidgets('pindah bulan dan daftar hari besar Ramadhan',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(bungkus(
          KalenderHijriahScreen(jamSekarang: () => DateTime(2026, 3, 10))));
      await tester.pumpAndSettle();
      expect(find.text('Ramadhan 1447 H'), findsOneWidget);

      for (final String hari in <String>[
        'Awal Ramadhan', 'Nuzulul Quran', 'Malam 27 Ramadhan',
      ]) {
        await gulirKe(tester, find.text(hari));
        expect(find.text(hari), findsOneWidget, reason: hari);
      }
      expect(find.textContaining('18-02-2026'), findsWidgets);

      await gulirKeAtas(tester, find.byTooltip('Bulan berikutnya'));
      await tester.tap(find.byTooltip('Bulan berikutnya'));
      await tester.pumpAndSettle();
      expect(find.text('Syawal 1447 H'), findsOneWidget);
      await gulirKe(tester, find.text('Idul Fitri'));
      expect(find.text('Idul Fitri'), findsOneWidget);
      expect(find.textContaining('20-03-2026'), findsWidgets);

      await gulirKeAtas(tester, find.byTooltip('Bulan sebelumnya'));
      await tester.tap(find.byTooltip('Bulan sebelumnya'));
      await tester.pumpAndSettle();
      expect(find.text('Ramadhan 1447 H'), findsOneWidget);
      expect(find.textContaining('Hari ini: 21 Ramadhan 1447 H'), findsOneWidget);
    });

    testWidgets('ganti acuan ke FCNA menggeser tanggal Hijriah',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(bungkus(
          KalenderHijriahScreen(jamSekarang: () => DateTime(2026, 2, 18))));
      await tester.pumpAndSettle();
      expect(find.text('Ramadhan 1447 H'), findsOneWidget);
      expect(find.textContaining('Hari ini: 1 Ramadhan 1447 H'), findsOneWidget);

      await gulirKe(tester, find.textContaining('Acuan perhitungan'));
      await tester.tap(find.byType(DropdownButtonFormField<AcuanHijriah>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FCNA (aritmetik)').last);
      await tester.pumpAndSettle();
      // Bulan yang sedang dibuka tidak berpindah (tidak melompat), tetapi
      // tanggal Hijriah "hari ini" dan hari besar ikut acuan baru.
      expect(find.text('Ramadhan 1447 H'), findsOneWidget);
      expect(find.textContaining('Hari ini: 30 Syaban 1447 H'), findsOneWidget);
      await gulirKe(tester, find.text('Awal Ramadhan'));
      expect(find.textContaining('19-02-2026'), findsWidgets);
    });

    testWidgets('koreksi hari mengikuti penetapan resmi',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(bungkus(
          KalenderHijriahScreen(jamSekarang: () => DateTime(2026, 2, 19))));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hari ini: 2 Ramadhan 1447 H'), findsOneWidget);

      await gulirKe(tester, find.byTooltip('Mundurkan satu hari'));
      await tester.tap(find.byTooltip('Mundurkan satu hari'));
      await tester.pumpAndSettle();
      expect(find.text('-1 hari'), findsOneWidget);
      expect(find.textContaining('Hari ini: 1 Ramadhan 1447 H'), findsOneWidget);

      await gulirKe(tester, find.text('Awal Ramadhan'));
      expect(find.text('Awal Ramadhan'), findsOneWidget);

      await gulirKe(tester, find.byTooltip('Majukan satu hari'));
      await tester.tap(find.byTooltip('Majukan satu hari'));
      await tester.pumpAndSettle();
      expect(find.text('Tanpa koreksi'), findsOneWidget);
    });
  });

  group('Batas bahasa III-11 pada layar', () {
    testWidgets('tidak ada kata menghakimi yang tampil',
        (WidgetTester tester) async {
      await siapkan(tester);
      final List<String> semua = <String>[];

      await tester.pumpWidget(layarSholat());
      await tester.pumpAndSettle();
      for (int i = 0; i < 8; i++) {
        semua.addAll(teksTampil(tester));
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(bungkus(
          KalenderHijriahScreen(jamSekarang: () => DateTime(2026, 9, 13))));
      await tester.pumpAndSettle();
      for (int i = 0; i < 8; i++) {
        semua.addAll(teksTampil(tester));
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pumpAndSettle();
      }

      final List<String> terlarang = <String>[
        'skor iman', 'anda gagal', 'kamu', 'berdosa', 'kafir',
        'belum sholat', 'wajib anda',
      ];
      for (final String t in semua) {
        for (final String kata in terlarang) {
          expect(t.toLowerCase().contains(kata), isFalse,
              reason: 'teks "$t" memuat "$kata"');
        }
      }
      expect(semua, isNotEmpty);
    });
  });
}
