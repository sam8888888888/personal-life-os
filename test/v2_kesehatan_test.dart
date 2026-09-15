/// Uji V2 — kesehatan dasar: FR-101 (dasbor), FR-102 (aktivitas),
/// FR-103 (tidur), FR-106 (obat & vitamin), FR-111 (pencatat air).
///
/// Kriteria terima PRD yang diuji:
/// * durasi tidur dihitung benar melewati tengah malam (uji khusus FR-103);
/// * total menit aktivitas 7/30 hari & total air harian sesuai angka catatan;
/// * satu catatan per malam (tanggal = hari bangun) — menyimpan lagi
///   memperbarui, bukan menambah baris;
/// * kalimat obat berbentuk laporan angka ("3 dari 5 tercatat diminum hari
///   ini") dan dosis disimpan apa adanya;
/// * keadaan kosong menulis "Belum ada data" (bukan 0 yang menyesatkan);
/// * bahasa aman pasal III-11 (tanpa kata: kamu, gagal, skor, berdosa, malas,
///   rajin, wajib anda, belum sholat, diagnosis).
///
/// Waktu uji dikunci: "sekarang" = Selasa, 15 September 2026 08.00.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/kesehatan_repository.dart';
import 'package:personal_life_os/data/repository/obat_repository.dart';
import 'package:personal_life_os/features/kesehatan/aktivitas_screen.dart';
import 'package:personal_life_os/features/kesehatan/air_screen.dart';
import 'package:personal_life_os/features/kesehatan/kesehatan_hub_screen.dart';
import 'package:personal_life_os/features/kesehatan/label_hari.dart';
import 'package:personal_life_os/features/kesehatan/obat_screen.dart';
import 'package:personal_life_os/features/kesehatan/provider_kesehatan.dart';
import 'package:personal_life_os/features/kesehatan/tidur_screen.dart';

late AppDatabase db;
late KesehatanRepository kesehatan;
late ObatRepository obat;

/// Waktu patok uji: Selasa, 15 September 2026 08.00.
final jamUji = DateTime(2026, 9, 15, 8);

/// Tanggal relatif terhadap hari uji (0 = hari ini).
DateTime hari(int selisih) =>
    DateTime(2026, 9, 15).add(Duration(days: selisih));

/// Kata yang dilarang pasal III-11.
const List<String> kataTerlarang = [
  'kamu',
  'gagal',
  'skor',
  'berdosa',
  'malas',
  'rajin',
  'wajib anda',
  'belum sholat',
  'diagnosis',
];

void main() {
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    kesehatan = KesehatanRepository(db, jamSekarang: () => jamUji);
    obat = ObatRepository(db, jamSekarang: () => jamUji);
  });

  tearDown(() async => db.close());

  // =========================================================================
  // Pembantu teks
  // =========================================================================

  test('pembantu teks: durasi, ml, angka & jam', () {
    expect(formatDurasiMenit(450), '7 jam 30 menit');
    expect(formatDurasiMenit(45), '45 menit');
    expect(formatDurasiMenit(480), '8 jam');
    expect(formatMl(1250), '1.250 ml');
    expect(formatMl(250), '250 ml');
    expect(formatAngkaDesimal(68.5), '68,5');
    expect(formatAngkaDesimal(70), '70');
    expect(parseJamHHmm('08:00'), (jam: 8, menit: 0));
    expect(parseJamHHmm('8:5'), isNull);
    expect(parseJamHHmm('25:00'), isNull);
    expect(labelHariSingkat(hari(0)), 'Sel');
    expect(labelHariSingkat(hari(-1)), 'Sen');
    expect(labelTanggalSedang(hari(1)), '16 Sep 2026');
  });

  // =========================================================================
  // FR-103 Tidur
  // =========================================================================

  group('FR-103 tidur', () {
    test('(a) durasi dihitung benar melewati tengah malam', () {
      expect(
        KesehatanRepository.hitungDurasiMenit(
          DateTime(2026, 9, 14, 23, 0),
          DateTime(2026, 9, 15, 6, 30),
        ),
        450,
      );
      expect(
        KesehatanRepository.hitungDurasiMenit(
          DateTime(2026, 9, 14, 22, 15),
          DateTime(2026, 9, 15, 5, 45),
        ),
        450,
      );
      expect(
        KesehatanRepository.hitungDurasiMenit(
          DateTime(2026, 9, 15, 0, 30),
          DateTime(2026, 9, 15, 6, 0),
        ),
        330,
      );
      // Bangun pada hari yang sama (mis. tidur larut dini hari).
      expect(
        KesehatanRepository.hitungDurasiMenit(
          DateTime(2026, 9, 15, 1, 0),
          DateTime(2026, 9, 15, 4, 30),
        ),
        210,
      );
      // Jam sama persis tidak bisa dihitung.
      expect(
        KesehatanRepository.hitungDurasiMenit(
          DateTime(2026, 9, 15, 6, 0),
          DateTime(2026, 9, 15, 6, 0),
        ),
        0,
      );
    });

    test('(b) satu catatan per malam: menyimpan lagi memperbarui baris', () async {
      await kesehatan.simpanTidur(
        tanggal: hari(0),
        jamTidur: DateTime(2026, 9, 14, 23, 0),
        jamBangun: DateTime(2026, 9, 15, 6, 30),
      );
      await kesehatan.simpanTidur(
        tanggal: hari(0),
        jamTidur: DateTime(2026, 9, 14, 22, 0),
        jamBangun: DateTime(2026, 9, 15, 5, 0),
        kualitas: 4,
        tidurSiangMenit: 20,
        catatan: 'Bangun sekali untuk minum',
      );

      final semua = await db.select(db.tidur).get();
      expect(semua.length, 1, reason: 'satu malam hanya satu baris');
      final baris = semua.single;
      expect(baris.tanggal, awalHari(hari(0)));
      expect(baris.durasiMenit, 420);
      expect(baris.kualitas, 4);
      expect(baris.tidurSiangMenit, 20);
      // Jam tidur disimpan pada hari sebelumnya (lintas tengah malam).
      expect(baris.jamTidur, DateTime(2026, 9, 14, 22, 0));
      expect(baris.jamBangun, DateTime(2026, 9, 15, 5, 0));
    });

    test('(c) durasi boleh dikoreksi pengguna, kualitas boleh kosong', () async {
      final baris = await kesehatan.simpanTidur(
        tanggal: hari(-1),
        jamTidur: DateTime(2026, 9, 13, 23, 0),
        jamBangun: DateTime(2026, 9, 14, 6, 30),
        durasiMenit: 400, // koreksi pengguna
      );
      expect(baris.durasiMenit, 400);
      expect(baris.kualitas, isNull);

      await expectLater(
        kesehatan.simpanTidur(
          tanggal: hari(-2),
          jamTidur: DateTime(2026, 9, 12, 23, 0),
          jamBangun: DateTime(2026, 9, 13, 6, 0),
          kualitas: 6,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await kesehatan.tidurMalam(hari(-1)), isNotNull);
      expect(await kesehatan.tidurMalam(hari(-5)), isNull);
    });

    test('(d) rata-rata 7/30 hari hanya memakai malam yang tercatat', () async {
      expect(await kesehatan.rataRataDurasiMenit(hari: 7), isNull);
      final kosong = await kesehatan.ringkasanTidur(acuan: jamUji);
      expect(kosong.rataRata7HariMenit, isNull);
      expect(kosong.adaCatatan, isFalse);

      // 3 malam dalam 7 hari terakhir: 480 + 420 + 450 = 1350 -> 450 menit.
      await kesehatan.simpanTidur(
        tanggal: hari(0),
        jamTidur: DateTime(2026, 9, 14, 23, 0),
        jamBangun: DateTime(2026, 9, 15, 7, 0),
      );
      await kesehatan.simpanTidur(
        tanggal: hari(-1),
        jamTidur: DateTime(2026, 9, 13, 23, 0),
        jamBangun: DateTime(2026, 9, 14, 6, 0),
      );
      await kesehatan.simpanTidur(
        tanggal: hari(-3),
        jamTidur: DateTime(2026, 9, 11, 22, 30),
        jamBangun: DateTime(2026, 9, 12, 6, 0),
      );
      // Malam lama (10 hari lalu) hanya ikut hitungan 30 hari.
      await kesehatan.simpanTidur(
        tanggal: hari(-10),
        jamTidur: DateTime(2026, 9, 4, 23, 0),
        jamBangun: DateTime(2026, 9, 5, 5, 30),
      );

      final r = await kesehatan.ringkasanTidur(acuan: jamUji);
      expect(r.jumlahMalam7Hari, 3);
      expect(r.rataRata7HariMenit, 450);
      expect(r.jumlahMalam30Hari, 4);
      expect(r.rataRata30HariMenit, 435);
      expect(await kesehatan.rataRataDurasiMenit(hari: 7), 450);
    });
  });

  // =========================================================================
  // FR-102 Aktivitas
  // =========================================================================

  group('FR-102 aktivitas', () {
    test('(e) total menit hari ini, 7 hari & 30 hari sesuai angka catatan',
        () async {
      await kesehatan.catatAktivitas(
          jenis: 'Jalan', durasiMenit: 30, tanggal: hari(0));
      await kesehatan.catatAktivitas(
          jenis: 'Lari', durasiMenit: 45, tanggal: hari(-1));
      await kesehatan.catatAktivitas(
          jenis: 'Sepeda', durasiMenit: 60, tanggal: hari(-3));
      await kesehatan.catatAktivitas(
          jenis: 'Renang', durasiMenit: 120, tanggal: hari(-10));

      final r = await kesehatan.ringkasanAktivitas(acuan: jamUji);
      expect(r.menitHariIni, 30);
      expect(r.menit7Hari, 135);
      expect(r.menit30Hari, 255);
      expect(r.jumlahCatatan7Hari, 3);
      expect(r.adaCatatan, isTrue);

      // Dua catatan pada hari yang sama dijumlahkan.
      await kesehatan.catatAktivitas(
          jenis: 'Peregangan', durasiMenit: 10, tanggal: hari(0));
      final r2 = await kesehatan.ringkasanAktivitas(acuan: jamUji);
      expect(r2.menitHariIni, 40);
      expect(r2.menit7Hari, 145);
    });

    test('(f) grafik 7 hari: 7 batang, hari tanpa catatan bernilai 0', () async {
      await kesehatan.catatAktivitas(
          jenis: 'Gym', durasiMenit: 50, tanggal: hari(0));
      await kesehatan.catatAktivitas(
          jenis: 'Jalan', durasiMenit: 20, tanggal: hari(-2));

      final batang = await kesehatan.batangAktivitas(hari: 7, sampai: jamUji);
      expect(batang.length, 7);
      expect(batang.first.tanggal, hari(-6));
      expect(batang.last.tanggal, hari(0));
      expect(batang.last.nilai, 50);
      expect(batang[4].tanggal, hari(-2));
      expect(batang[4].nilai, 20);
      expect(batang[3].nilai, 0, reason: 'hari tanpa catatan = 0 menit');
    });

    test('(g) jarak boleh kosong, intensitas tersimpan & isian tidak sah ditolak',
        () async {
      final a = await kesehatan.catatAktivitas(
        jenis: 'Jalan',
        durasiMenit: 40,
        intensitas: IntensitasAktivitas.ringan,
        tanggal: hari(0),
      );
      expect(a.jarakKm, isNull);
      expect(a.intensitas, 'ringan');

      final b = await kesehatan.catatAktivitas(
        jenis: 'Lari',
        durasiMenit: 25,
        jarakKm: 4.2,
        intensitas: IntensitasAktivitas.berat,
        tanggal: hari(0),
      );
      expect(b.jarakKm, 4.2);
      expect(b.intensitas, 'berat');

      await expectLater(
        kesehatan.catatAktivitas(jenis: 'Lari', durasiMenit: 0),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        kesehatan.catatAktivitas(jenis: '  ', durasiMenit: 30),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // =========================================================================
  // FR-101 angka tubuh
  // =========================================================================

  group('FR-101 ukuran tubuh', () {
    test('(h) berat terakhir = catatan pada tanggal terbaru', () async {
      await kesehatan.catatUkuran(
          jenis: JenisUkuran.berat, nilai: 69, tanggal: hari(-3));
      await kesehatan.catatUkuran(
          jenis: JenisUkuran.berat, nilai: 70, tanggal: hari(-2));
      await kesehatan.catatUkuran(
          jenis: JenisUkuran.berat, nilai: 68.5, tanggal: hari(-1));

      final terakhir = await kesehatan.ukuranTerbaru(JenisUkuran.berat);
      expect(terakhir, isNotNull);
      expect(terakhir!.nilai, 68.5);
      expect(terakhir.satuan, 'kg');
      expect(terakhir.tanggal, hari(-1));
      expect(await kesehatan.ukuranTerbaru(JenisUkuran.lingkarPerut), isNull);
    });

    test('(i) tekanan darah dipasangkan pada hari yang sama', () async {
      await kesehatan.catatTekananDarah(
          sistolik: 120, diastolik: 80, tanggal: hari(-2));
      await kesehatan.catatTekananDarah(
          sistolik: 130, diastolik: 85, tanggal: hari(0));

      final td = await kesehatan.tekananDarahTerakhir();
      expect(td, isNotNull);
      expect(td!.teks, '130 / 85 mmHg');
      expect(td.tanggal, hari(0));

      await expectLater(
        kesehatan.catatTekananDarah(sistolik: 0, diastolik: 80),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('(j) hanya satu angka tekanan darah: belum bisa ditampilkan', () async {
      await kesehatan.catatUkuran(
        jenis: JenisUkuran.sistolik,
        nilai: 118,
        satuan: 'mmHg',
        tanggal: hari(0),
      );
      expect(await kesehatan.tekananDarahTerakhir(), isNull);
    });
  });

  // =========================================================================
  // FR-111 Air
  // =========================================================================

  group('FR-111 air', () {
    test('(k) total hari ini, target bisa diatur & riwayat 7 hari', () async {
      await kesehatan.catatAir(
          jumlahMl: 250, waktu: DateTime(2026, 9, 15, 7));
      await kesehatan.catatAir(
          jumlahMl: 500, waktu: DateTime(2026, 9, 15, 9, 30));
      await kesehatan.catatAir(
          jumlahMl: 300, waktu: DateTime(2026, 9, 14, 20));

      final r = await kesehatan.ringkasanAir(acuan: jamUji);
      expect(r.totalMl, 750, reason: 'catatan hari kemarin tidak ikut');
      expect(r.jumlahCatatan, 2);
      expect(r.targetMl, 2000, reason: 'target bawaan');
      expect(r.sisaMl, 1250);
      expect(await kesehatan.ukuranGelasMl(), 250);

      await kesehatan.simpanTargetAirMl(2500);
      await kesehatan.simpanUkuranGelasMl(300);
      final r2 = await kesehatan.ringkasanAir(acuan: jamUji);
      expect(r2.targetMl, 2500);
      expect(r2.sisaMl, 1750);
      expect(await kesehatan.ukuranGelasMl(), 300);

      await expectLater(
        kesehatan.simpanTargetAirMl(100),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        kesehatan.catatAir(jumlahMl: 0),
        throwsA(isA<ArgumentError>()),
      );

      final riwayat = await kesehatan.riwayatAirHarian(hari: 7, sampai: jamUji);
      expect(riwayat.length, 7);
      expect(riwayat.last.tanggal, hari(0));
      expect(riwayat.last.totalMl, 750);
      expect(riwayat[5].totalMl, 300, reason: 'kemarin 300 ml');
      expect(riwayat[4].totalMl, 0);
    });
  });

  // =========================================================================
  // FR-106 Obat
  // =========================================================================

  group('FR-106 obat', () {
    test('(l) tambah obat: jam dinormalkan, dosis teks apa adanya', () async {
      final o = await obat.tambahObat(
        nama: 'Vitamin D',
        dosisTeks: '2 tablet, sesuai tulisan di kemasan',
        jumlahPerMinum: 2,
        satuan: 'tablet',
        jamMinum: ['8:00', '20:00', '08:00'],
      );
      expect(o.dosisTeks, '2 tablet, sesuai tulisan di kemasan');
      expect(o.jumlahPerMinum, 2);

      final jadwal = await obat.jadwalObat(o.id);
      expect(jadwal.map((j) => j.jam).toList(), ['08:00', '20:00'],
          reason: 'jam ganda tidak dibuat dua kali');
      expect(ObatRepository.normalisasiJam('7:5'), isNull);
      expect(ObatRepository.normalisasiJam('07:05'), '07:05');
      expect(await obat.daftarObat(), hasLength(1));
    });

    test('(m) catatan minum: satu jam satu baris, status terbaru dipakai',
        () async {
      final o = await obat.tambahObat(nama: 'Amlodipine', jamMinum: ['08:00']);
      final jadwal = (await obat.jadwalObat(o.id)).single;
      final rencana = DateTime(2026, 9, 15, 8);

      await obat.catatMinum(
        obatId: o.id,
        jadwalId: jadwal.id,
        waktuRencana: rencana,
        status: StatusMinum.diminum,
      );
      await obat.catatMinum(
        obatId: o.id,
        jadwalId: jadwal.id,
        waktuRencana: rencana,
        status: StatusMinum.ditunda,
        catatan: 'diminum setelah sarapan',
      );

      final semua = await db.select(db.minumObat).get();
      expect(semua.length, 1, reason: 'satu (obat, waktu rencana) satu baris');
      expect(semua.single.status, 'ditunda');
      expect(semua.single.waktuMinum, isNull);
      expect(semua.single.catatan, 'diminum setelah sarapan');

      final tercatat = await obat.catatanMinum(
        obatId: o.id,
        waktuRencana: rencana,
      );
      expect(tercatat, isNotNull);
      expect(StatusMinum.dariDb(tercatat!.status), StatusMinum.ditunda);
    });

    test('(n) kalimat hari ini berbentuk laporan angka: 3 dari 5', () async {
      final o = await obat.tambahObat(
        nama: 'Metformin',
        jamMinum: ['07:00', '12:00', '17:00', '20:00', '22:00'],
      );
      final jadwal = await obat.jadwalObat(o.id);
      expect(jadwal.length, 5);

      for (final j in jadwal.take(3)) {
        await obat.catatMinum(
          obatId: o.id,
          jadwalId: j.id,
          waktuRencana: DateTime(2026, 9, 15, int.parse(j.jam.substring(0, 2)),
              int.parse(j.jam.substring(3))),
          status: StatusMinum.diminum,
        );
      }

      final r = await obat.ringkasanHariIni(hari: jamUji);
      expect(r.jumlahJadwal, 5);
      expect(r.jumlahDiminum, 3);
      expect(r.jumlahBelum, 2);
      expect(r.kalimatTercatat, '3 dari 5 tercatat diminum hari ini');
      expect(r.jadwal.first.jam, '07:00');
      expect(r.jadwal.first.sudahDicatat, isTrue);
      expect(r.jadwal.last.sudahDicatat, isFalse);
      expect(r.jadwal.last.status, isNull);

      // Obat yang saklarnya dimatikan tidak masuk hitungan hari ini.
      await obat.ubahObat(o.id, aktif: false);
      final r2 = await obat.ringkasanHariIni(hari: jamUji);
      expect(r2.adaJadwal, isFalse);
    });

    test('(o) riwayat 7 hari memuat nama obat & keadaan catatan', () async {
      final o = await obat.tambahObat(nama: 'Vitamin C', jamMinum: ['09:00']);
      final jadwal = (await obat.jadwalObat(o.id)).single;

      await obat.catatMinum(
        obatId: o.id,
        jadwalId: jadwal.id,
        waktuRencana: DateTime(2026, 9, 15, 9),
        status: StatusMinum.diminum,
      );
      await obat.catatMinum(
        obatId: o.id,
        jadwalId: jadwal.id,
        waktuRencana: DateTime(2026, 9, 12, 9),
        status: StatusMinum.dilewati,
      );
      // Catatan di luar 7 hari tidak ikut.
      await obat.catatMinum(
        obatId: o.id,
        jadwalId: jadwal.id,
        waktuRencana: DateTime(2026, 9, 1, 9),
        status: StatusMinum.diminum,
      );

      final riwayat = await obat.riwayatMinum(hari: 7, sampai: jamUji);
      expect(riwayat.length, 2);
      expect(riwayat.first.namaObat, 'Vitamin C');
      expect(riwayat.first.status, StatusMinum.diminum);
      expect(riwayat.last.status, StatusMinum.dilewati);

      final hariIni = await obat.riwayatMinumHari(hari(0));
      expect(hariIni.length, 1);
      expect(hariIni.single.catatan.waktuMinum, isNotNull);
    });
  });

  // =========================================================================
  // Layar (widget)
  // =========================================================================

  group('layar kesehatan', () {
    Future<void> tampilkan(WidgetTester t, Widget layar) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      await t.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          kesehatanRepoProvider.overrideWithValue(kesehatan),
          obatRepoProvider.overrideWithValue(obat),
        ],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: layar,
        ),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 300));
    }

    Future<void> tutup(WidgetTester t) async {
      await t.pump(const Duration(seconds: 5));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.binding.setSurfaceSize(null);
    }

    /// Gulir daftar vertikal (bukan scroll di dalam kolom isian).
    Future<void> gulir(WidgetTester t, double jarak) async {
      final cari = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      if (cari.evaluate().isEmpty) return;
      final pos = t.state<ScrollableState>(cari.first).position;
      pos.jumpTo((pos.pixels + jarak).clamp(0.0, pos.maxScrollExtent));
      await t.pump(const Duration(milliseconds: 50));
    }

    /// Teks yang sedang tampil (tanpa menggulir).
    Set<String> teksLayar(WidgetTester t) => t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .where((s) => s.isNotEmpty)
        .toSet();

    /// Semua teks yang pernah tampil, termasuk yang perlu digulir dulu.
    Future<Set<String>> semuaTeks(WidgetTester t) async {
      final kumpulan = <String>{};
      void kumpulkan() => kumpulan.addAll(teksLayar(t));
      kumpulkan();
      for (var i = 0; i < 14; i++) {
        await gulir(t, 260);
        kumpulkan();
      }
      return kumpulan;
    }

    Future<void> tekan(WidgetTester t, Finder target) async {
      await t.ensureVisible(target);
      await t.pump(const Duration(milliseconds: 120));
      await t.tap(target);
      await t.pump(const Duration(milliseconds: 200));
      await t.pump(const Duration(milliseconds: 300));
    }

    void periksaBahasaAman(Iterable<String> teks, String namaLayar) {
      final gabung = teks.join(' | ').toLowerCase();
      for (final kata in kataTerlarang) {
        expect(gabung.contains(kata), isFalse,
            reason: 'Layar $namaLayar memuat kata terlarang "$kata".');
      }
    }

    testWidgets('(p) lima layar tanpa data: "Belum ada data" & bahasa aman',
        (t) async {
      final layar = <String, Widget>{
        'dasbor': KesehatanHubScreen(jamSekarang: () => jamUji),
        'aktivitas': AktivitasScreen(jamSekarang: () => jamUji),
        'tidur': TidurScreen(jamSekarang: () => jamUji),
        'obat': ObatScreen(jamSekarang: () => jamUji),
        'air': AirScreen(jamSekarang: () => jamUji),
      };
      for (final bagian in layar.entries) {
        await tampilkan(t, bagian.value);
        final teks = await semuaTeks(t);
        expect(teks.contains('Belum ada data'), isTrue,
            reason: 'Layar ${bagian.key} harus menulis "Belum ada data".');
        expect(
          teks.any((s) => s.contains('0 menit')),
          isFalse,
          reason: 'Layar ${bagian.key} tidak boleh menampilkan 0 yang menyesatkan.',
        );
        periksaBahasaAman(teks, bagian.key);
        await tutup(t);
      }
    });

    testWidgets('(q) dasbor menampilkan angka catatan apa adanya', (t) async {
      await kesehatan.catatUkuran(
          jenis: JenisUkuran.berat, nilai: 68.5, tanggal: hari(-1));
      await kesehatan.catatTekananDarah(
          sistolik: 120, diastolik: 80, tanggal: hari(-1));
      await kesehatan.catatAktivitas(
          jenis: 'Jalan', durasiMenit: 30, tanggal: hari(0));
      await kesehatan.catatAktivitas(
          jenis: 'Lari', durasiMenit: 45, tanggal: hari(-2));
      await kesehatan.simpanTidur(
        tanggal: hari(-1),
        jamTidur: DateTime(2026, 9, 13, 23, 0),
        jamBangun: DateTime(2026, 9, 14, 6, 30),
      );
      await kesehatan.catatAir(
          jumlahMl: 250, waktu: DateTime(2026, 9, 15, 7));
      await kesehatan.catatAir(
          jumlahMl: 500, waktu: DateTime(2026, 9, 15, 10));
      final o = await obat.tambahObat(
          nama: 'Vitamin D', jamMinum: ['08:00', '20:00']);
      final jadwal = await obat.jadwalObat(o.id);
      await obat.catatMinum(
        obatId: o.id,
        jadwalId: jadwal.first.id,
        waktuRencana: DateTime(2026, 9, 15, 8),
        status: StatusMinum.diminum,
      );

      await tampilkan(t, KesehatanHubScreen(jamSekarang: () => jamUji));
      // Grafik & kartu aktivitas ada dekat bagian atas: periksa sebelum
      // menggulir, karena daftar membuang widget yang sudah jauh di atas.
      expect(find.byKey(const Key('grafik_aktivitas_7_hari')), findsOneWidget);

      final teks = await semuaTeks(t);

      expect(teks.contains('68,5 kg · 14 Sep 2026'), isTrue);
      expect(teks.contains('120 / 80 mmHg · 14 Sep 2026'), isTrue);
      expect(teks.contains('Total 75 menit dalam 7 hari terakhir · hari ini 30 menit'),
          isTrue);
      expect(teks.contains('Rata-rata 7 jam 30 menit dari 1 malam tercatat'),
          isTrue);
      expect(teks.contains('750 ml dari target 2.000 ml'), isTrue);
      expect(teks.contains('1 dari 2 tercatat diminum hari ini'), isTrue);
      // Pintu menuju pencatat (bagian paling bawah) juga terpasang.
      expect(find.byKey(const Key('buka_air')), findsOneWidget);
      periksaBahasaAman(teks, 'dasbor');

      await tutup(t);
    });

    testWidgets('(r) layar aktivitas & air menyimpan dari isian', (t) async {
      await tampilkan(t, AktivitasScreen(jamSekarang: () => jamUji));
      await t.enterText(
          find.byKey(const Key('input_jenis_aktivitas')), 'Jalan');
      await t.enterText(find.byKey(const Key('input_durasi_menit')), '45');
      await t.enterText(find.byKey(const Key('input_jarak_km')), '3,5');
      await tekan(t, find.byKey(const Key('pilih_intensitas_ringan')));
      await tekan(t, find.byKey(const Key('simpan_aktivitas')));
      await t.pump(const Duration(milliseconds: 300));

      final baris = await db.select(db.aktivitas).get();
      expect(baris.length, 1);
      expect(baris.single.jenis, 'Jalan');
      expect(baris.single.durasiMenit, 45);
      expect(baris.single.jarakKm, 3.5);
      expect(baris.single.intensitas, 'ringan');
      expect(baris.single.tanggal, awalHari(jamUji));
      final teksAktivitas = await semuaTeks(t);
      expect(teksAktivitas.contains('7 hari terakhir: 45 menit'), isTrue);
      expect(
        teksAktivitas.contains('45 menit · 3,5 km · Ringan · 15 Sep 2026'),
        isTrue,
        reason: 'riwayat menampilkan durasi, jarak & intensitas',
      );
      periksaBahasaAman(teksAktivitas, 'aktivitas');
      await tutup(t);

      await tampilkan(t, AirScreen(jamSekarang: () => jamUji));
      await tekan(t, find.byKey(const Key('tambah_gelas')));
      await tekan(t, find.byKey(const Key('tambah_botol')));
      final air = await db.select(db.catatanAir).get();
      expect(air.length, 2);
      expect(air.map((c) => c.jumlahMl).toList()..sort(), [250, 500]);
      final teksAir = await semuaTeks(t);
      expect(teksAir.contains('750 ml'), isTrue);
      expect(teksAir.contains('Sisa menuju target: 1.250 ml'), isTrue);
      periksaBahasaAman(teksAir, 'air');
      await tutup(t);
    });

    testWidgets('(s) layar tidur: durasi terhitung lalu tersimpan', (t) async {
      await tampilkan(t, TidurScreen(jamSekarang: () => jamUji));

      await t.enterText(find.byKey(const Key('input_jam_tidur')), '23:00');
      await t.enterText(find.byKey(const Key('input_jam_bangun')), '06:30');
      await t.pump(const Duration(milliseconds: 100));
      expect(
        t.widget<Text>(find.byKey(const Key('durasi_terhitung'))).data,
        'Durasi terhitung: 7 jam 30 menit',
      );

      await t.enterText(find.byKey(const Key('input_durasi_koreksi')), '400');
      await t.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Dipakai: 400 menit'), findsOneWidget);
      await t.enterText(find.byKey(const Key('input_durasi_koreksi')), '');
      await t.pump(const Duration(milliseconds: 100));

      await tekan(t, find.byKey(const Key('pilih_kualitas_4')));
      await tekan(t, find.byKey(const Key('simpan_tidur')));
      await t.pump(const Duration(milliseconds: 300));

      final baris = await db.select(db.tidur).get();
      expect(baris.length, 1);
      expect(baris.single.tanggal, awalHari(jamUji));
      expect(baris.single.durasiMenit, 450);
      expect(baris.single.kualitas, 4);
      expect(baris.single.jamTidur, DateTime(2026, 9, 14, 23, 0));
      expect(baris.single.jamBangun, DateTime(2026, 9, 15, 6, 30));

      final teks = await semuaTeks(t);
      expect(teks.contains('7 hari terakhir: 7 jam 30 menit dari 1 malam tercatat'),
          isTrue);
      expect(teks.contains('Sudah ada catatan untuk tanggal ini. Menyimpan akan '
          'memperbarui catatan malam itu.'), isTrue);
      periksaBahasaAman(teks, 'tidur');
      await tutup(t);
    });

    testWidgets('(t) layar obat: tombol "sudah diminum" mencatat waktu',
        (t) async {
      final o = await obat.tambahObat(
        nama: 'Amlodipine',
        dosisTeks: '1 tablet, sesuai kemasan',
        jamMinum: ['08:00', '20:00'],
      );

      await tampilkan(t, ObatScreen(jamSekarang: () => jamUji));
      // Kartu "Hari ini" ada di bagian atas layar: periksa & tekan dulu,
      // sebelum daftar digulir (widget yang jauh di atas akan dibuang).
      var teks = teksLayar(t);
      expect(teks.contains('0 dari 2 tercatat diminum hari ini'), isTrue);

      await tekan(t, find.byKey(Key('minum_${o.id}_08:00')));

      final catatan = await db.select(db.minumObat).get();
      expect(catatan.length, 1);
      expect(catatan.single.status, 'diminum');
      expect(catatan.single.waktuRencana, DateTime(2026, 9, 15, 8));
      expect(catatan.single.waktuMinum, DateTime(2026, 9, 15, 8),
          reason: 'waktu minum memakai jam saat tombol ditekan');

      teks = teksLayar(t);
      expect(teks.contains('1 dari 2 tercatat diminum hari ini'), isTrue);
      expect(
        teks.any((s) => s.startsWith('Sudah diminum pukul 08:00')),
        isTrue,
        reason: 'waktu minum tercatat pada status jadwal',
      );

      await tekan(t, find.byKey(Key('lewati_${o.id}_20:00')));
      final semua = await db.select(db.minumObat).get();
      expect(semua.length, 2);
      expect(
        semua.map((m) => m.status).toList()..sort(),
        ['dilewati', 'diminum'],
      );
      teks = teksLayar(t);
      expect(teks.contains('Ditunda 0 · dilewati 1'), isTrue);

      // Sisa halaman (dosis apa adanya, jam minum, riwayat) perlu digulir.
      final lengkap = await semuaTeks(t);
      expect(
        lengkap.contains('1 tablet, sesuai kemasan · 1 tablet per minum'),
        isTrue,
      );
      expect(lengkap.contains('Jam minum: 08:00, 20:00'), isTrue);
      expect(lengkap.contains('Belum ada data'), isFalse,
          reason: 'semua bagian sudah punya data');
      periksaBahasaAman(lengkap, 'obat');
      await tutup(t);
    });
  });
}
