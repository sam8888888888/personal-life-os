/// Uji FR-89 — Riwayat & konsistensi sholat.
///
/// Dua hal yang diuji keras:
/// 1. Angka rekap HARUS cocok dengan data mentah (dihitung ulang dari berkas).
/// 2. Bahasa layar memakai "tercatat" dan bebas kata menghakimi (PRD III-11).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/ibadah/model_log_sholat.dart';
import 'package:personal_life_os/core/ibadah/model_sholat.dart';
import 'package:personal_life_os/core/ibadah/penyimpanan_log_sholat.dart';
import 'package:personal_life_os/core/ibadah/rekap_sholat.dart';
import 'package:personal_life_os/features/ibadah/rekap_sholat_screen.dart';

/// Data mentah contoh: 7 hari (1–7 Sep 2026) dengan pola yang diketahui.
Map<String, CatatanSholat> dataMentah() {
  Set<WaktuSholat> s(List<WaktuSholat> daftar) => daftar.toSet();
  return <String, CatatanSholat>{
    '2026-09-01': CatatanSholat.penuh('2026-09-01'),
    '2026-09-02': CatatanSholat(
        tanggal: '2026-09-02',
        tercatat: s(<WaktuSholat>[WaktuSholat.subuh, WaktuSholat.dzuhur])),
    '2026-09-03': CatatanSholat(
        tanggal: '2026-09-03',
        tercatat: s(<WaktuSholat>[WaktuSholat.subuh, WaktuSholat.maghrib, WaktuSholat.isya])),
    '2026-09-04': CatatanSholat(tanggal: '2026-09-04', tercatat: s(<WaktuSholat>[])),
    '2026-09-05': CatatanSholat(
        tanggal: '2026-09-05', tercatat: s(<WaktuSholat>[WaktuSholat.subuh])),
    '2026-09-06': CatatanSholat(
        tanggal: '2026-09-06',
        tercatat: s(<WaktuSholat>[WaktuSholat.subuh, WaktuSholat.ashar])),
    '2026-09-07': CatatanSholat(
        tanggal: '2026-09-07',
        tercatat: s(<WaktuSholat>[WaktuSholat.subuh, WaktuSholat.dzuhur, WaktuSholat.ashar, WaktuSholat.maghrib])),
  };
}

/// Hitung ulang dari data mentah tanpa memakai kelas RekapSholat — pembanding
/// independen supaya angkanya benar-benar diperiksa, bukan dipercaya.
int hitungSendiri(List<String> tanggal, Map<String, CatatanSholat> data,
    WaktuSholat w) {
  int n = 0;
  for (final String k in tanggal) {
    final CatatanSholat? c = data[k];
    if (c == null) continue;
    if (c.kodeTercatat.contains(w.name)) n++;
  }
  return n;
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('FR-89 perhitungan rekap', () {
    final List<String> rentang =
        RekapSholat.rentangTanggal(DateTime(2026, 9, 7), jumlahHari: 7);

    test('rentang 7 hari berakhir pada hari itu, urut naik', () {
      expect(rentang.length, 7);
      expect(rentang.first, '2026-09-01');
      expect(rentang.last, '2026-09-07');
    });

    test('rentang 30 hari melewati batas bulan dengan benar', () {
      final List<String> r30 =
          RekapSholat.rentangTanggal(DateTime(2026, 9, 5), jumlahHari: 30);
      expect(r30.length, 30);
      expect(r30.last, '2026-09-05');
      expect(r30.first, '2026-08-07');
    });

    test('angka per waktu cocok dengan data mentah', () {
      final RekapSholat r =
          RekapSholat.hitung(tanggal: rentang, catatan: dataMentah());
      for (final WaktuSholat w in WaktuSholat.wajibSaja) {
        expect(r.rekapWaktu(w)!.tercatat, hitungSendiri(rentang, dataMentah(), w),
            reason: 'waktu ${w.label}');
      }
      // Diketahui dari data mentah di atas.
      expect(r.rekapWaktu(WaktuSholat.subuh)!.tercatat, 6);
      expect(r.rekapWaktu(WaktuSholat.dzuhur)!.tercatat, 3);
      expect(r.rekapWaktu(WaktuSholat.ashar)!.tercatat, 3);
      expect(r.rekapWaktu(WaktuSholat.maghrib)!.tercatat, 3);
      expect(r.rekapWaktu(WaktuSholat.isya)!.tercatat, 2);
    });

    test('total & jumlah harian cocok dengan data mentah', () {
      final RekapSholat r =
          RekapSholat.hitung(tanggal: rentang, catatan: dataMentah());
      expect(r.totalTercatat, 6 + 3 + 3 + 3 + 2);
      expect(r.totalKemungkinan, 35);
      expect(r.jumlahHari, 7);
      expect(r.jumlahPerHari,
          <int>[5, 2, 3, 0, 1, 2, 4]);
      expect(r.hariPenuh(dataMentah()), 1);
      expect(r.rekapWaktu(WaktuSholat.subuh)!.kalimat, '6 dari 7 hari tercatat');
    });

    test('hari di luar rentang tidak ikut dihitung', () {
      final Map<String, CatatanSholat> data = dataMentah()
        ..['2026-08-31'] = CatatanSholat.penuh('2026-08-31')
        ..['2026-09-08'] = CatatanSholat.penuh('2026-09-08');
      final RekapSholat r = RekapSholat.hitung(tanggal: rentang, catatan: data);
      expect(r.rekapWaktu(WaktuSholat.subuh)!.tercatat, 6);
      expect(r.jumlahHari, 7);
    });

    test('syuruq tidak pernah dihitung walau tertulis di berkas', () {
      final Map<String, CatatanSholat> data = <String, CatatanSholat>{
        '2026-09-07': CatatanSholat.fromJson(<String, dynamic>{
          'tanggal': '2026-09-07',
          'tercatat': <String>['syuruq', 'subuh'],
        }),
      };
      final RekapSholat r = RekapSholat.hitung(
          tanggal: RekapSholat.rentangTanggal(DateTime(2026, 9, 7), jumlahHari: 1),
          catatan: data);
      expect(r.totalTercatat, 1);
      expect(r.jumlahPerHari.single, 1);
      expect(r.rekapWaktu(WaktuSholat.syuruq), isNull);
    });

    test('rentang tanpa catatan: nol, tanpa galat', () {
      final RekapSholat r = RekapSholat.hitung(
          tanggal: rentang, catatan: <String, CatatanSholat>{});
      expect(r.totalTercatat, 0);
      expect(r.jumlahPerHari, everyElement(0));
      expect(r.rekapWaktu(WaktuSholat.subuh)!.bagian, 0);
      expect(r.jumlahHariKe(99), 0);
      expect(r.jumlahHariKe(-1), 0);
    });

    test('jumlahHari 0 memberi bagian null (tidak dibagi nol)', () {
      final RekapSholat r = RekapSholat.hitung(
          tanggal: <String>[], catatan: <String, CatatanSholat>{});
      expect(r.rekapWaktu(WaktuSholat.isya)!.bagian, isNull);
      expect(r.totalKemungkinan, 0);
    });

    test('kalimat rekap tidak memakai kata menghakimi (III-11)', () {
      const List<String> dilarang = <String>[
        'skor', 'nilai', 'peringkat', 'gagal', 'berdosa', 'rajin', 'malas',
        'kamu', 'wajib anda',
      ];
      final RekapSholat r =
          RekapSholat.hitung(tanggal: rentang, catatan: dataMentah());
      final List<String> teks = <String>[
        r.kalimatTotal,
        for (final RekapWaktu w in r.perWaktu) w.kalimat,
        for (final RekapWaktu w in r.perWaktu) w.waktu.label,
      ];
      for (final String t in teks) {
        for (final String k in dilarang) {
          expect(t.toLowerCase(), isNot(contains(k)),
              reason: 'teks "$t" memuat "$k"');
        }
      }
    });
  });

  group('FR-89 layar riwayat', () {
    late Directory dirUji;

    setUp(() {
      dirUji = Directory.systemTemp.createTempSync('rekap_sholat_');
      // Data mentah ditulis ke berkas dengan format penyimpanan sungguhan.
      File('${dirUji.path}${Platform.pathSeparator}log_sholat.json')
          .writeAsStringSync(jsonEncode(<String, Object>{
        'versi': 1,
        'diubah': '2026-09-07T00:00:00.000Z',
        'hari': <String, Object>{
          for (final MapEntry<String, CatatanSholat> e in dataMentah().entries)
            e.key: e.value.kodeTercatat,
        },
      }));
    });

    tearDown(() => dirUji.deleteSync(recursive: true));

    Future<void> buka(WidgetTester t, {DateTime? sekarang}) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      await t.pumpWidget(MaterialApp(
        home: RekapSholatScreen(
          penyimpananLog: PenyimpananLogSholat(
              penentuFolder: () => Future<Directory>.value(dirUji)),
          jamSekarang: () => sekarang ?? DateTime(2026, 9, 7, 9, 0),
        ),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
    }

    testWidgets('layar menampilkan angka yang cocok dengan data mentah',
        (t) async {
      await buka(t);
      expect(find.text('Riwayat sholat'), findsOneWidget);
      expect(find.text('1 Sep – 7 Sep'), findsOneWidget);
      expect(find.text('17 dari 35 waktu tercatat'), findsOneWidget);
      expect(find.byKey(const Key('rekap_subuh')), findsOneWidget);
      expect(find.text('6 dari 7 hari tercatat'), findsOneWidget);
      expect(find.text('2 dari 7 hari tercatat'), findsOneWidget); // Isya
      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('tombol 30 hari mengganti rentang dan angkanya', (t) async {
      await buka(t);
      await t.tap(find.byKey(const Key('pilih_30')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('9 Agu – 7 Sep'), findsOneWidget);
      expect(find.text('17 dari 150 waktu tercatat'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('rentang tanpa catatan menampilkan kalimat jujur', (t) async {
      await buka(t, sekarang: DateTime(2027, 1, 10, 9, 0));
      expect(find.text('Belum ada catatan pada rentang ini'), findsOneWidget);
      expect(find.text('Belum tercatat bukan berarti tidak dikerjakan — hanya '
          'berarti tidak ditandai di aplikasi.'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('layar bebas kata menghakimi (III-11)', (t) async {
      await buka(t);
      final Iterable<Text> semua = t.widgetList<Text>(find.byType(Text));
      final String gabung =
          semua.map((Text e) => e.data ?? '').join(' ').toLowerCase();
      for (final String k in <String>['skor', 'peringkat', 'gagal', 'kamu', 'rajin', 'malas']) {
        expect(gabung, isNot(contains(k)), reason: 'layar memuat "$k"');
      }
      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });
  });
}
