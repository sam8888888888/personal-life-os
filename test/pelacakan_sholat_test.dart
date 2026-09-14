// Uji FR-88 (Pelacakan 5 Waktu Sholat): model, penyimpanan, dan layar.
//
// Catatan teknik (dari pengalaman proyek ini):
// - Folder sementara dibuat SINKRON (`createTempSync`) dan disuntik lewat
//   `penentuFolder: () => Future<Directory>.value(dirUji)`. Operasi berkas
//   asinkron di dalam `testWidgets` masuk zona waktu palsu dan menggantung.
// - Uji widget memakai ukuran layar HP, dan menggulir dengan `tester.drag`
//   karena ListView hanya membangun baris yang terlihat.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/ibadah/kalender_hijriah.dart';
import 'package:personal_life_os/core/ibadah/kota_indonesia.dart';
import 'package:personal_life_os/core/ibadah/model_log_sholat.dart';
import 'package:personal_life_os/core/ibadah/model_sholat.dart';
import 'package:personal_life_os/core/ibadah/penghitung_sholat.dart';
import 'package:personal_life_os/core/ibadah/penyimpanan_jadwal.dart';
import 'package:personal_life_os/core/ibadah/penyimpanan_log_sholat.dart';
import 'package:personal_life_os/features/ibadah/pelacakan_sholat_screen.dart';

/// Satu instan tetap: 13 September 2026 jam 03.00 WIB.
final DateTime instanUji = DateTime.utc(2026, 9, 12, 20, 0);

/// Tanggal sipil kota untuk [instanUji] di WIB/WITA/WIT.
final String tanggalUji = '2026-09-13';

late Directory dirUji;

KotaSholat kotaBernama(String nama) =>
    daftarKotaIndonesia.firstWhere((KotaSholat k) => k.nama == nama);

PenyimpananLogSholat logUji() =>
    PenyimpananLogSholat(penentuFolder: () => Future<Directory>.value(dirUji));

PenyimpananJadwal jadwalUji() =>
    PenyimpananJadwal(penentuFolder: () => Future<Directory>.value(dirUji));

Widget layarUji({KotaSholat? kota}) => MaterialApp(
      home: PelacakanSholatScreen(
        jamSekarang: () => instanUji,
        kotaAwal: kota,
        penyimpanan: jadwalUji(),
        penyimpananLog: logUji(),
      ),
    );

/// Gulir daftar utama ke bawah sampai target terlihat.
Future<void> gulirKe(WidgetTester tester, Finder target) async {
  final Finder daftar = find.byType(Scrollable).first;
  for (int i = 0; i < 30; i++) {
    if (target.evaluate().isNotEmpty) return;
    await tester.drag(daftar, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
  throw StateError('target tidak ditemukan setelah menggulir: $target');
}

/// Gulir balik ke atas sampai target terlihat.
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

/// Warna merah (atau merah tua) yang dipakai eksplisit.
bool merahDominan(Color? c) {
  if (c == null) return false;
  final int r = (c.r * 255).round();
  final int g = (c.g * 255).round();
  final int b = (c.b * 255).round();
  return r > 140 && r - g > 60 && r - b > 60;
}

Future<void> siapkan(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  setUp(() {
    dirUji = Directory.systemTemp.createTempSync('uji_log_sholat_');
  });

  tearDown(() {
    if (dirUji.existsSync()) dirUji.deleteSync(recursive: true);
  });

  group('Model catatan sholat', () {
    test('tanggalKunci memakai nol depan dan kosongPada berjumlah 0', () {
      expect(tanggalKunci(DateTime.utc(2026, 9, 3)), '2026-09-03');
      expect(tanggalKunci(DateTime.utc(2026, 12, 13)), '2026-12-13');
      expect(tanggalDariKunci('2026-09-03'), DateTime.utc(2026, 9, 3));
      expect(kunciSah('2026-9-3'), isFalse);
      expect(kunciSah('bukan-tanggal'), isFalse);

      final CatatanSholat kosong = kosongPada(tanggalUji);
      expect(kosong.jumlah, 0);
      expect(kosong.lengkap, isFalse);
      expect(kosong.tercatatPada(WaktuSholat.subuh), isFalse);
      expect(kosong.kodeTercatat, isEmpty);

      final CatatanSholat penuh = CatatanSholat.penuh(tanggalUji);
      expect(penuh.jumlah, 5);
      expect(penuh.lengkap, isTrue);
      // Syuruq tidak pernah dihitung walau ikut dimasukkan.
      final CatatanSholat syuruqSaja = CatatanSholat(
        tanggal: tanggalUji,
        tercatat: <WaktuSholat>{WaktuSholat.syuruq},
      );
      expect(syuruqSaja.jumlah, 0);
      expect(syuruqSaja.tercatatPada(WaktuSholat.syuruq), isFalse);
    });

    test('salinDengan dan dengan mengubah penanda tanpa mengubah aslinya', () {
      final CatatanSholat awal = kosongPada(tanggalUji);
      final CatatanSholat satu = awal.dengan(WaktuSholat.ashar, true);
      expect(satu.tercatatPada(WaktuSholat.ashar), isTrue);
      expect(awal.jumlah, 0, reason: 'objek asli tidak boleh berubah');
      expect(satu.tanggal, tanggalUji);

      final CatatanSholat batal = satu.dengan(WaktuSholat.ashar, false);
      expect(batal.jumlah, 0);

      final CatatanSholat penuh =
          awal.salinDengan(tercatat: WaktuSholat.wajibSaja.toSet());
      expect(penuh.lengkap, isTrue);
      expect(penuh.toJson()['tercatat'], <String>[
        'subuh', 'dzuhur', 'ashar', 'maghrib', 'isya',
      ]);
      expect(CatatanSholat.fromJson(penuh.toJson()), penuh);
    });
  });

  group('FR-88 penyimpanan catatan', () {
    test('menyimpan dan membaca penanda beberapa waktu', () async {
      final PenyimpananLogSholat p = logUji();
      expect((await p.ambil(tanggalUji)).jumlah, 0,
          reason: 'berkas belum ada harus dianggap hari kosong');

      await p.tandai(tanggalUji, WaktuSholat.subuh);
      await p.tandai(tanggalUji, WaktuSholat.dzuhur);
      final CatatanSholat c = await p.ambil(tanggalUji);
      expect(c.jumlah, 2);
      expect(c.tercatatPada(WaktuSholat.subuh), isTrue);
      expect(c.tercatatPada(WaktuSholat.dzuhur), isTrue);
      expect(c.tercatatPada(WaktuSholat.isya), isFalse);
      expect(c.lengkap, isFalse);
      expect(c.tanggal, tanggalUji);

      // Hari lain tidak ikut terisi.
      expect((await p.ambil('2026-09-14')).jumlah, 0);
    });

    test('membatalkan penanda dan mengabaikan Syuruq', () async {
      final PenyimpananLogSholat p = logUji();
      await p.tandai(tanggalUji, WaktuSholat.maghrib);
      expect((await p.ambil(tanggalUji)).tercatatPada(WaktuSholat.maghrib), isTrue);

      await p.tandai(tanggalUji, WaktuSholat.maghrib, tercatat: false);
      expect((await p.ambil(tanggalUji)).jumlah, 0);

      await p.tandai(tanggalUji, WaktuSholat.syuruq);
      expect((await p.ambil(tanggalUji)).jumlah, 0,
          reason: 'Syuruq bukan sholat wajib');

      // Kunci tanggal salah diabaikan, bukan melempar.
      await p.tandai('bukan-tanggal', WaktuSholat.subuh);
      expect((await p.ambil('bukan-tanggal')).jumlah, 0);
    });

    test('kosongkanHari membuang semua penanda hari itu saja', () async {
      final PenyimpananLogSholat p = logUji();
      for (final WaktuSholat w in WaktuSholat.wajibSaja) {
        await p.tandai(tanggalUji, w);
      }
      await p.tandai('2026-09-14', WaktuSholat.subuh);
      expect((await p.ambil(tanggalUji)).lengkap, isTrue);

      await p.kosongkanHari(tanggalUji);
      expect((await p.ambil(tanggalUji)).jumlah, 0);
      expect((await p.ambil('2026-09-14')).jumlah, 1,
          reason: 'hari lain tidak boleh ikut dikosongkan');
    });

    test('salinHari menyalin penanda ke tanggal lain', () async {
      final PenyimpananLogSholat p = logUji();
      await p.tandai(tanggalUji, WaktuSholat.subuh);
      await p.tandai(tanggalUji, WaktuSholat.isya);

      await p.salinHari(tanggalUji, '2026-09-20');
      final CatatanSholat salinan = await p.ambil('2026-09-20');
      expect(salinan.jumlah, 2);
      expect(salinan.tercatatPada(WaktuSholat.subuh), isTrue);
      expect(salinan.tercatatPada(WaktuSholat.isya), isTrue);
      expect(salinan.tercatatPada(WaktuSholat.ashar), isFalse);

      // Sumber belum ada -> tidak ada yang diubah.
      await p.salinHari('2026-09-25', '2026-09-26');
      expect(File('${dirUji.path}/log_sholat.json').existsSync(), isTrue);
      expect((await p.ambil('2026-09-26')).jumlah, 0);
    });

    test('ambilRentang hanya mengembalikan hari di dalam rentang', () async {
      final PenyimpananLogSholat p = logUji();
      await p.tandai('2026-09-11', WaktuSholat.subuh);
      await p.tandai('2026-09-13', WaktuSholat.dzuhur);
      await p.tandai('2026-09-15', WaktuSholat.ashar);

      final Map<String, CatatanSholat> r = await p.ambilRentang(
        '2026-09-12',
        '2026-09-14',
      );
      expect(r.keys.toList(), <String>['2026-09-13']);
      expect(r['2026-09-13']!.tercatatPada(WaktuSholat.dzuhur), isTrue);

      final Map<String, CatatanSholat> semua =
          await p.ambilRentang('2026-09-01', '2026-09-30');
      expect(semua.length, 3);
      expect(semua.keys.toList(), <String>[
        '2026-09-11', '2026-09-13', '2026-09-15',
      ]);

      // Rentang terbalik & kunci salah -> peta kosong, tidak melempar.
      expect((await p.ambilRentang('2026-09-20', '2026-09-01')).isEmpty, isTrue);
      expect((await p.ambilRentang('x', '2026-09-30')).isEmpty, isTrue);
    });

    test('bersihkanSebelum membuang hari lama dan menyimpan hari ini', () async {
      final PenyimpananLogSholat p = logUji();
      await p.tandai('2026-01-01', WaktuSholat.subuh);
      await p.tandai('2026-09-12', WaktuSholat.dzuhur);
      await p.tandai('2026-09-13', WaktuSholat.ashar);

      await p.bersihkanSebelum('2026-09-13');

      expect((await p.ambil('2026-01-01')).jumlah, 0);
      expect((await p.ambil('2026-09-12')).jumlah, 0);
      expect((await p.ambil('2026-09-13')).jumlah, 1,
          reason: 'hari ini (batas) tidak boleh terhapus');

      // Batas tidak sah -> tidak menghapus apa pun.
      await p.bersihkanSebelum('salah');
      expect((await p.ambil('2026-09-13')).jumlah, 1);
    });

    test('berkas rusak tidak melempar dan bisa ditulis ulang', () async {
      final PenyimpananLogSholat p = logUji();
      File('${dirUji.path}/log_sholat.json').writeAsStringSync('{bukan json!');

      final CatatanSholat c = await p.ambil(tanggalUji);
      expect(c.jumlah, 0);

      await p.tandai(tanggalUji, WaktuSholat.isya);
      expect((await p.ambil(tanggalUji)).tercatatPada(WaktuSholat.isya), isTrue);

      // Isi berbentuk JSON tapi struktur salah juga harus aman.
      File('${dirUji.path}/log_sholat.json')
          .writeAsStringSync('[1, 2, 3]');
      expect((await p.ambil(tanggalUji)).jumlah, 0);
      await p.tandai(tanggalUji, WaktuSholat.subuh);
      expect((await p.ambil(tanggalUji)).jumlah, 1);

      // Baris dengan kunci tanggal salah & penanda tidak dikenal dilewati.
      File('${dirUji.path}/log_sholat.json').writeAsStringSync(
        '{"versi":1,"hari":{"salah":["subuh"],"2026-09-13":["subuh","ngawur"]}}',
      );
      final CatatanSholat campur = await p.ambil(tanggalUji);
      expect(campur.kodeTercatat, <String>['subuh']);
    });

    test('folder tidak bisa dipakai -> catatan kosong, tanpa galat', () async {
      final PenyimpananLogSholat p = PenyimpananLogSholat(
        penentuFolder: () async => throw StateError('folder tidak tersedia'),
        namaBerkas: 'log_sholat_gagal.json',
      );
      expect((await p.ambil(tanggalUji)).jumlah, 0);
      await p.tandai(tanggalUji, WaktuSholat.subuh);
      await p.kosongkanHari(tanggalUji);
      await p.bersihkanSebelum('2026-09-13');
      await p.salinHari(tanggalUji, '2026-09-14');
      expect((await p.ambilRentang('2026-09-01', '2026-09-30')).isEmpty, isTrue);
      expect(await p.berkas(), isNull);
    });
  });

  group('FR-88 layar pelacakan sholat', () {
    testWidgets('kepala: tanggal Masehi, Hijriah, kota, dan zona',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(layarUji());
      await tester.pumpAndSettle();

      expect(find.text('Pelacakan Sholat'), findsOneWidget);
      expect(find.textContaining('13-09-2026'), findsWidgets);
      final String hijriah =
          hijriahDariMasehi(DateTime.utc(2026, 9, 13))!.label;
      expect(find.text(hijriah), findsOneWidget);
      expect(find.text('Jakarta — WIB'), findsOneWidget);
      expect(find.textContaining('Waktu Indonesia Barat'), findsOneWidget);
    });

    testWidgets('keadaan kosong jujur: "Belum ada catatan hari ini"',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(layarUji());
      await tester.pumpAndSettle();

      expect(find.text('Belum ada catatan hari ini'), findsOneWidget);
      expect(find.text('Catatan hari ini'), findsOneWidget);
      expect(find.textContaining('dari 5 waktu tercatat'), findsNothing,
          reason: 'hari kosong tidak ditampilkan sebagai angka saja');
    });

    testWidgets('lima waktu wajib tampil dengan jam dari hitungJadwal',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(layarUji());
      await tester.pumpAndSettle();

      final JadwalSholatHarian acuan = hitungJadwal(
        kota: kotaBernama('Jakarta'),
        tanggal: DateTime.utc(2026, 9, 13),
      );
      for (final WaktuSholat w in WaktuSholat.wajibSaja) {
        await gulirKe(tester, find.text(w.label));
        expect(find.text(w.label), findsOneWidget, reason: w.label);
        expect(
          find.text('Jam ${jamMenit(acuan.waktuLokal(w))} WIB'),
          findsOneWidget,
          reason: '${w.label} harus menampilkan jam dari jadwal hari itu',
        );
      }
      expect(find.text('Syuruq'), findsNothing,
          reason: 'Syuruq bukan waktu wajib, tidak dicatat di layar ini');
    });

    testWidgets('mengetuk tombol status mengubah tercatat dan hitungannya',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(layarUji());
      await tester.pumpAndSettle();

      await gulirKe(tester, find.byKey(const Key('status_subuh')));
      expect(find.text('Tercatat'), findsNothing);

      await tester.tap(find.byKey(const Key('status_subuh')));
      await tester.pumpAndSettle();
      expect(find.text('Tercatat'), findsOneWidget);
      expect(find.text('1 dari 5 waktu tercatat hari ini'), findsOneWidget);

      await tester.tap(find.byKey(const Key('status_dzuhur')));
      await tester.pumpAndSettle();
      expect(find.text('2 dari 5 waktu tercatat hari ini'), findsOneWidget);

      // Ketuk lagi = batal.
      await tester.tap(find.byKey(const Key('status_subuh')));
      await tester.pumpAndSettle();
      expect(find.text('1 dari 5 waktu tercatat hari ini'), findsOneWidget);

      // Catatan bertahan di berkas (dibaca ulang dari perangkat).
      expect((await logUji().ambil(tanggalUji)).tercatatPada(WaktuSholat.dzuhur),
          isTrue);
    });

    testWidgets('tombol "Tandai semua tercatat" menandai lima waktu',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(layarUji());
      await tester.pumpAndSettle();

      await gulirKe(tester, find.byKey(const Key('tandai_semua')));
      await tester.tap(find.byKey(const Key('tandai_semua')));
      await tester.pumpAndSettle();

      expect(find.text('5 dari 5 waktu tercatat hari ini'), findsOneWidget);
      expect(find.text('Lima waktu sudah tercatat hari ini.'), findsOneWidget);

      // ListView hanya membangun baris yang terlihat, jadi tiap baris
      // diperiksa setelah digulir ke posisinya.
      for (final WaktuSholat w in WaktuSholat.wajibSaja) {
        final Finder chip = find.byKey(Key('status_${w.name}'));
        await gulirKe(tester, chip);
        expect(find.descendant(of: chip, matching: find.text('Tercatat')),
            findsOneWidget,
            reason: w.label);
        expect(
            find.descendant(of: chip, matching: find.text('Belum tercatat')),
            findsNothing,
            reason: w.label);
      }
      expect((await logUji().ambil(tanggalUji)).lengkap, isTrue);
    });

    testWidgets('tombol "Kosongkan catatan hari ini" mengembalikan keadaan kosong',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(layarUji());
      await tester.pumpAndSettle();

      await gulirKe(tester, find.byKey(const Key('tandai_semua')));
      await tester.tap(find.byKey(const Key('tandai_semua')));
      await tester.pumpAndSettle();
      expect(find.text('5 dari 5 waktu tercatat hari ini'), findsOneWidget);

      await gulirKeAtas(tester, find.byKey(const Key('kosongkan_hari')));
      await tester.tap(find.byKey(const Key('kosongkan_hari')));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada catatan hari ini'), findsOneWidget);
      expect(find.text('Tercatat'), findsNothing);
      expect((await logUji().ambil(tanggalUji)).jumlah, 0);
    });

    testWidgets('catatan kaki jujur tampil di bawah daftar',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(layarUji());
      await tester.pumpAndSettle();

      await gulirKe(
          tester,
          find.textContaining(
              'Catatan ini hanya untuk Anda sendiri. Aplikasi tidak memberi'));
      expect(
        find.textContaining(
            'Catatan ini hanya untuk Anda sendiri. Aplikasi tidak memberi'),
        findsOneWidget,
      );
      await gulirKe(tester, find.text('Perhitungan waktu, bukan jadwal resmi.'));
      expect(find.text('Perhitungan waktu, bukan jadwal resmi.'), findsOneWidget);
      expect(find.textContaining('Dihitung untuk Jakarta'), findsOneWidget);
    });

    testWidgets('kota lain (Makassar) memakai zona dan jam WITA',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(layarUji(kota: kotaBernama('Makassar')));
      await tester.pumpAndSettle();

      expect(find.text('Makassar — WITA'), findsOneWidget);
      final JadwalSholatHarian acuan = hitungJadwal(
        kota: kotaBernama('Makassar'),
        tanggal: DateTime.utc(2026, 9, 13),
      );
      await gulirKe(tester, find.text('Subuh'));
      expect(
        find.text('Jam ${jamMenit(acuan.waktuLokal(WaktuSholat.subuh))} WITA'),
        findsOneWidget,
      );
    });

    testWidgets('bahasa III-11: tidak ada kata menghakimi dan tidak ada merah',
        (WidgetTester tester) async {
      await siapkan(tester);
      await tester.pumpWidget(layarUji());
      await tester.pumpAndSettle();

      // Semua teks (setelah semua bagian dibangun, jadi digulir sampai bawah).
      await gulirKe(tester, find.text('Perhitungan waktu, bukan jadwal resmi.'));
      final List<String> teks = teksTampil(tester);
      expect(teks.length, greaterThan(10));
      const List<String> kataTerlarang = <String>[
        'skor', 'gagal', 'berdosa', 'kafir', 'belum sholat', 'tidak sholat',
        'dosa', 'malas', 'hukuman', 'sanksi', 'tidak lulus',
      ];
      for (final String isi in teks) {
        final String rendah = isi.toLowerCase();
        for (final String kata in kataTerlarang) {
          expect(rendah.contains(kata), isFalse,
              reason: 'teks "$isi" tidak boleh memuat "$kata"');
        }
      }

      // Tidak ada warna merah untuk catatan ini.
      for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
        expect(merahDominan(t.style?.color), isFalse,
            reason: 'teks "${t.data}" memakai warna merah');
      }
      for (final Icon i in tester.widgetList<Icon>(find.byType(Icon))) {
        expect(merahDominan(i.color), isFalse,
            reason: 'ikon ${i.icon} memakai warna merah');
      }
    });
  });
}
