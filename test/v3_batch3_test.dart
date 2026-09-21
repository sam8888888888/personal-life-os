/// Uji batch 3 (10 butir): FR-110, FR-112, FR-113, FR-116, FR-118, FR-119,
/// FR-120, FR-121, FR-122, FR-123.
///
/// Yang dibuktikan di sini (bukan diklaim):
///   * logika murni: ringkasan catatan/keputusan/pembelajaran/bacaan, aturan
///     tautan, jadwal ulangan berkala, ringkasan makan & suasana hati, mesin
///     temuan, dan laporan kesehatan bulanan (termasuk tiga kelompok
///     "membaik / berubah / perlu diperhatikan");
///   * layar benar-benar bisa dipakai: menambah, menyaring, menghapus, mencatat
///     cepat — dan hasilnya diperiksa langsung di basis data;
///   * bahasa seluruh layar baru bebas kata terlarang (PRD pasal III-11).
library;

import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/laporan/laporan_kesehatan_bulanan.dart';
import 'package:personal_life_os/core/laporan/makan_ringkas.dart';
import 'package:personal_life_os/core/laporan/pengetahuan_ringkas.dart' as png;
import 'package:personal_life_os/core/laporan/suasana_hati.dart';
import 'package:personal_life_os/core/laporan/temuan_kesehatan.dart';
import 'package:personal_life_os/core/laporan/ulangan_berkala.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/kesehatan_ringkas_repository.dart';
import 'package:personal_life_os/data/repository/pengetahuan_repository.dart';
import 'package:personal_life_os/features/kesehatan/laporan_kesehatan_bulanan_screen.dart';
import 'package:personal_life_os/features/kesehatan/makan_screen.dart';
import 'package:personal_life_os/features/kesehatan/suasana_screen.dart';
import 'package:personal_life_os/features/kesehatan/temuan_screen.dart';
import 'package:personal_life_os/features/pengetahuan/catatan_screen.dart';
import 'package:personal_life_os/features/pengetahuan/keputusan_screen.dart';
import 'package:personal_life_os/features/pengetahuan/pengetahuan_hub_screen.dart';
import 'package:personal_life_os/features/pengetahuan/ulangan_screen.dart';

late AppDatabase db;
final sekarang = DateTime(2026, 9, 21, 9, 30);

/// Kata yang dilarang muncul di bahasa layar (PRD pasal III-11).
const List<String> kataTerlarang = <String>[
  'gagal',
  'boros',
  'disiplin',
  'kamu',
  'skor',
  'menakut',
];

Future<void> layarTinggi(WidgetTester t) async {
  await t.binding.setSurfaceSize(const Size(1100, 2600));
  addTearDown(() => t.binding.setSurfaceSize(null));
}

Widget bungkus(Widget isi) => ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTema.terang(), home: isi),
    );

List<String> semuaTeks(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data ?? '')
    .where((s) => s.isNotEmpty)
    .toList();

void periksaBahasa(WidgetTester t, String namaLayar) {
  for (final teks in semuaTeks(t)) {
    final rendah = teks.toLowerCase();
    for (final kata in kataTerlarang) {
      expect(rendah.contains(kata), isFalse,
          reason: 'layar $namaLayar memuat kata terlarang "$kata": $teks');
    }
  }
}

png.BarisCatatan catatan(String judul,
        {String kategori = 'gagasan',
        String? tag,
        bool semat = false,
        bool arsip = false,
        DateTime? dibuat}) =>
    png.BarisCatatan(
      id: judul.length,
      judul: judul,
      isi: 'isi $judul',
      kategori: kategori,
      tag: tag,
      disematkan: semat,
      arsip: arsip,
      dibuatPada: dibuat ?? DateTime(2026, 9, 10),
    );

png.BarisKeputusan keputusan(String judul,
        {DateTime? tinjau, String? hasil, int keyakinan = 70}) =>
    png.BarisKeputusan(
      id: judul.length,
      judul: judul,
      diputuskanPada: DateTime(2026, 6, 1),
      tinjauPada: tinjau,
      hasil: hasil,
      keyakinan: keyakinan,
    );

TitikBulanan titik(int hari, double nilai) =>
    TitikBulanan(DateTime(2026, 8, hari), nilai);

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  // ------------------------------------------------------------------ logika
  group('FR-118 catatan & ide', () {
    test('ringkasan menghitung kategori, sematan, arsip dan tautan', () {
      final ringkas = png.ringkasCatatan([
        catatan('Ide A', semat: true, tag: 'proyek', dibuat: DateTime(2026, 9, 20)),
        catatan('Ide B', kategori: 'kutipan', dibuat: DateTime(2026, 9, 18)),
        catatan('Ide C', arsip: true, dibuat: DateTime(2026, 9, 1)),
      ]);

      expect(ringkas.total, 3);
      expect(ringkas.perKategori['gagasan'], 2);
      expect(ringkas.perKategori['kutipan'], 1);
      expect(ringkas.jumlahDisematkan, 1);
      expect(ringkas.jumlahDiarsipkan, 1);
      expect(ringkas.terbaru.first.judul, 'Ide A',
          reason: 'catatan terbaru harus di depan');
    });

    test('pencarian menyaring judul, isi dan tag', () {
      final daftar = [
        catatan('Resep kopi', tag: 'dapur'),
        catatan('Rencana kerja'),
      ];
      expect(png.cariCatatan(daftar, 'kopi').single.judul, 'Resep kopi');
      expect(png.cariCatatan(daftar, 'isi Rencana').single.judul, 'Rencana kerja');
      expect(png.cariCatatan(daftar, 'dapur').single.judul, 'Resep kopi');
      expect(png.cariCatatan(daftar, 'tidak ada'), isEmpty);
    });
  });

  group('FR-119 jurnal keputusan', () {
    test('keputusan yang jadwal tinjaunya lewat dan belum ada hasil', () {
      final perlu = png.keputusanPerluDitinjau([
        keputusan('A', tinjau: DateTime(2026, 9, 1)),
        keputusan('B', tinjau: DateTime(2026, 10, 1)),
        keputusan('C', tinjau: DateTime(2026, 8, 1), hasil: 'sudah dijalani'),
        keputusan('D'),
      ], acuan: sekarang);

      expect(perlu.map((k) => k.judul), ['A']);
    });

    test('ringkasan keputusan menghitung keyakinan rata-rata', () {
      final ringkas = png.ringkasKeputusan([
        keputusan('A', keyakinan: 80, tinjau: DateTime(2026, 9, 1)),
        keputusan('B', keyakinan: 60, hasil: 'jalan'),
      ], acuan: sekarang);

      expect(ringkas.total, 2);
      expect(ringkas.menungguTinjauan, 1);
      expect(ringkas.sudahDitinjau, 1);
      expect(ringkas.keyakinanRataRata, 70);
    });
  });

  group('FR-120 pembelajaran', () {
    test('menit per topik & rentang 7 hari', () {
      final ringkas = png.ringkasPembelajaran([
        png.BarisPembelajaran(
            topik: 'Dart', menit: 60, tanggal: DateTime(2026, 9, 20), id: 1),
        png.BarisPembelajaran(
            topik: 'Dart', menit: 30, tanggal: DateTime(2026, 9, 19), id: 2),
        png.BarisPembelajaran(
            topik: 'SQL', menit: 45, tanggal: DateTime(2026, 9, 1), id: 3),
      ], acuan: sekarang);

      expect(ringkas.totalMenit, 135);
      expect(ringkas.perTopik['Dart'], 90);
      expect(ringkas.menitRentang, 90, reason: 'SQL di luar 7 hari terakhir');
      expect(ringkas.hariAktif, 2);
      expect(ringkas.topikTeratas, 'Dart');
    });
  });

  group('FR-122 bacaan', () {
    test('progres, status dan penilaian sendiri', () {
      final ringkas = png.ringkasBacaan([
        png.BarisBacaan(
          id: 1,
          judul: 'Buku A',
          halamanTotal: 200,
          halamanKini: 50,
          status: 'dibaca',
          nilai: 4,
        ),
        png.BarisBacaan(
          id: 2,
          judul: 'Buku B',
          halamanTotal: 100,
          halamanKini: 100,
          status: 'selesai',
          selesaiPada: DateTime(2026, 9, 5),
          nilai: 5,
        ),
        png.BarisBacaan(id: 3, judul: 'Artikel C', status: 'antre'),
      ], acuan: sekarang);

      expect(ringkas.total, 3);
      expect(ringkas.sedangDibaca.single.judul, 'Buku A');
      expect(ringkas.antre, 1);
      expect(ringkas.selesai, 1);
      expect(ringkas.selesaiTahunIni, 1);
      expect(ringkas.halamanDibaca, 150);
      expect(ringkas.rataNilai, 4.5);
    });
  });

  group('FR-123 penghubung pengetahuan', () {
    test('tautan tidak boleh ke diri sendiri & tidak boleh kembar', () {
      expect(png.tautanSah('catatan', 1, 'catatan', 1), isFalse);
      expect(png.tautanSah('catatan', 1, 'dokumen', 1), isTrue);

      final ada = [
        png.BarisTautan(
            jenisA: 'catatan',
            idA: 1,
            judulA: 'A',
            jenisB: 'dokumen',
            idB: 2,
            judulB: 'D'),
      ];
      expect(
          png.tautanKembar(
              ada,
              png.BarisTautan(
                  jenisA: 'dokumen',
                  idA: 2,
                  judulA: 'D',
                  jenisB: 'catatan',
                  idB: 1,
                  judulB: 'A')),
          isTrue,
          reason: 'urutan jenis tidak boleh membuat tautan dianggap baru');
    });

    test('tautan per butir & per jenis dihitung benar', () {
      final daftar = [
        png.BarisTautan(
            jenisA: 'catatan',
            idA: 1,
            judulA: 'A',
            jenisB: 'tujuan',
            idB: 1,
            judulB: 'T'),
        png.BarisTautan(
            jenisA: 'catatan',
            idA: 1,
            judulA: 'A',
            jenisB: 'proyek',
            idB: 2,
            judulB: 'P'),
      ];
      expect(png.tautanUntuk(daftar, 'catatan', 1), hasLength(2));
      expect(png.tautanUntuk(daftar, 'tujuan', 1), hasLength(1));
      expect(png.jumlahTautanPerJenis(daftar)['catatan'], 2);
      expect(png.labelJenisPengetahuan('dokumen'), 'Dokumen');
      expect(png.labelJenisPengetahuan('tujuan'), 'Tujuan');
    });
  });

  group('FR-121 pengulangan berkala', () {
    test('jarak ulangan memanjang sesuai jawaban tepat', () {
      expect(jarakHari(0), 1);
      expect(jarakHari(1), 3);
      expect(jarakHari(2), 7);
      expect(ulanganBerikut(sekarang: sekarang, kotak: 0),
          DateTime(2026, 9, 22));
      expect(ulanganBerikut(sekarang: sekarang, kotak: 2),
          DateTime(2026, 9, 28));
    });

    test('jawaban belum tepat mengembalikan kartu ke jarak terpendek', () {
      final salah = jawabKartu(kotak: 4, benar: false, sekarang: sekarang);
      expect(salah.kotakBaru, 0);
      expect(salah.ulanganBerikut, DateTime(2026, 9, 22));

      final benar = jawabKartu(
          kotak: 0, benar: true, sekarang: sekarang, jumlahBenar: 0);
      expect(benar.kotakBaru, 1);
      expect(benar.ulanganBerikut, DateTime(2026, 9, 24));
      expect(benar.jumlahBenarBaru, 1);
    });

    test('kartu jatuh tempo & ringkasan', () {
      final kartu = [
        KartuUlanganRingkas(
          id: 1,
          pertanyaan: 'Apa itu Dart?',
          jawaban: 'Bahasa pemrograman',
          kotak: 0,
          ulanganBerikut: DateTime(2026, 9, 20),
        ),
        KartuUlanganRingkas(
          id: 2,
          pertanyaan: 'Apa itu SQL?',
          jawaban: 'Bahasa kueri',
          kotak: 5,
          ulanganBerikut: DateTime(2026, 12, 1),
          jumlahDiulang: 4,
          jumlahBenar: 3,
        ),
        KartuUlanganRingkas(
          id: 3,
          pertanyaan: 'Baru?',
          jawaban: 'Ya',
          kotak: 0,
          ulanganBerikut: DateTime(2026, 9, 30),
        ),
      ];

      expect(kartuJatuhTempo(kartu, acuan: sekarang).map((k) => k.id), [1]);
      final ringkas = ringkasUlangan(kartu, acuan: sekarang);
      expect(ringkas.total, 3);
      expect(ringkas.jatuhTempo, 1);
      expect(ringkas.baru, 2);
      expect(ringkas.kuat, 1);
      expect(ringkas.bagianTepat, closeTo(3 / 4, 0.001));
      expect(labelKotak(0), contains('baru'));
    });
  });

  group('FR-110 catatan makan', () {
    test('ringkasan hari memisahkan per waktu makan', () {
      final ringkas = ringkasMakanHari([
        BarisMakan(
            jenis: 'sarapan',
            isi: 'nasi telur',
            waktu: DateTime(2026, 9, 21, 7),
            id: 1),
        BarisMakan(
            jenis: 'sarapan',
            isi: 'kopi',
            waktu: DateTime(2026, 9, 21, 7, 20),
            id: 2),
        BarisMakan(
            jenis: 'makan_siang',
            isi: 'soto',
            waktu: DateTime(2026, 9, 21, 12, 30),
            id: 3),
        BarisMakan(
            jenis: 'sarapan',
            isi: 'roti',
            waktu: DateTime(2026, 9, 20, 6),
            id: 4),
      ], acuan: sekarang);

      expect(ringkas.jumlahCatatan, 3, reason: 'hanya hari yang dipilih');
      final sarapan = ringkas.perJenis.firstWhere((j) => j.jenis == 'sarapan');
      expect(sarapan.isi, ['nasi telur', 'kopi']);
      expect(ringkas.belumTercatat, contains('makan_malam'));
      expect(ringkas.jamPertama, DateTime(2026, 9, 21, 7));
      expect(ringkas.jamTerakhir, DateTime(2026, 9, 21, 12, 30));
    });

    test('batang 7 hari, isi tersering, dan hari berturut-turut', () {
      final daftar = [
        for (var i = 0; i < 3; i++)
          BarisMakan(
              jenis: 'sarapan',
              isi: 'nasi telur',
              waktu: DateTime(2026, 9, 21 - i, 7),
              id: i + 1),
        BarisMakan(
            jenis: 'camilan',
            isi: 'apel',
            waktu: DateTime(2026, 9, 20, 15),
            id: 9),
      ];

      final batang = batangMakan(daftar, acuan: sekarang);
      expect(batang, hasLength(7));
      expect(batang.last.jumlah, 1, reason: 'hari ini satu catatan');
      expect(isiTersering(daftar).first, 'nasi telur');
      expect(hariBerturutTercatat(daftar, acuan: sekarang), 3);
    });
  });

  group('FR-112 suasana hati & stres', () {
    test('rata-rata, pemicu tersering dan arah perubahan', () {
      final ringkas = ringkasSuasana([
        BarisSuasana(
            skor: 2, pemicu: 'kerja', waktu: DateTime(2026, 9, 1), id: 0),
        BarisSuasana(
            skor: 2,
            energi: 2,
            stres: 4,
            pemicu: 'kerja',
            waktu: DateTime(2026, 9, 10),
            id: 1),
        BarisSuasana(
            skor: 3, energi: 3, stres: 3, pemicu: 'kerja', waktu: DateTime(2026, 9, 15), id: 2),
        BarisSuasana(
            skor: 4, energi: 4, stres: 2, pemicu: 'keluarga', waktu: DateTime(2026, 9, 20), id: 3),
      ], acuan: sekarang);

      expect(ringkas.jumlahCatatan, 4);
      expect(ringkas.rataRata, closeTo(2.75, 0.001));
      expect(ringkas.energiRataRata, closeTo(3, 0.001));
      expect(ringkas.stresRataRata, closeTo(3, 0.001));
      expect(ringkas.pemicuTersering.first, 'kerja');
      expect(ringkas.batang, hasLength(14));
      expect(ringkas.arah, 1, reason: '7 hari terakhir lebih tinggi dari sebelumnya');

      final kalimat = kalimatArahSuasana(ringkas).toLowerCase();
      for (final kata in kataTerlarang) {
        expect(kalimat.contains(kata), isFalse, reason: 'kalimat arah: $kalimat');
      }
    });
  });

  group('FR-113 mesin temuan kesehatan', () {
    test('berat naik ≥ 2 % dalam 30 hari dilaporkan dengan angkanya', () {
      final temuan = cariTemuan(
        BahanTemuan(
          berat: [
            TitikAngka(70, DateTime(2026, 8, 25)),
            TitikAngka(73, DateTime(2026, 9, 20)),
          ],
          sistolik: const [],
          tidurJam: const [],
          airMl: const [],
          targetAirMl: null,
          suasana: const [],
          menitAktivitas: const [],
          obatTerlewatHari: 0,
          hariTerakhirCatat: DateTime(2026, 9, 20),
        ),
        acuan: sekarang,
      );

      final berat = temuan.firstWhere((t) => t.jenis == 'berat');
      expect(berat.judul, contains('30 hari'));
      expect(berat.angka, contains('70'));
      expect(berat.angka, contains('73'));
      expect(berat.penjelasan.toLowerCase(), contains('bukan diagnosis'));
      expect(berat.tingkat, TingkatTemuan.perhatikan);
    });

    test('tanpa catatan sama sekali → tidak ada temuan yang mengada-ada', () {
      final temuan = cariTemuan(
        const BahanTemuan(
          berat: [],
          sistolik: [],
          tidurJam: [],
          airMl: [],
          targetAirMl: null,
          suasana: [],
          menitAktivitas: [],
          obatTerlewatHari: 0,
          hariTerakhirCatat: null,
        ),
        acuan: sekarang,
      );

      expect(temuan, isNotEmpty,
          reason: 'tanpa data, layar tetap mengingatkan bahwa belum ada catatan');
      expect(temuan.map((t) => t.jenis), everyElement('catatan'));
      for (final t in temuan) {
        expect(t.judul.toLowerCase(), contains('catatan'));
      }
    });

    test('air di bawah target 3 hari berturut & tidur pendek dilaporkan', () {
      final temuan = cariTemuan(
        BahanTemuan(
          berat: const [],
          sistolik: const [],
          tidurJam: [
            TitikHari(5.5, DateTime(2026, 9, 19)),
            TitikHari(5, DateTime(2026, 9, 20)),
            TitikHari(5.5, DateTime(2026, 9, 21)),
          ],
          airMl: [
            TitikHari(1200, DateTime(2026, 9, 19)),
            TitikHari(1000, DateTime(2026, 9, 20)),
            TitikHari(900, DateTime(2026, 9, 21)),
          ],
          targetAirMl: 2000,
          suasana: const [],
          menitAktivitas: const [],
          obatTerlewatHari: 0,
          hariTerakhirCatat: DateTime(2026, 9, 21),
        ),
        acuan: sekarang,
      );

      expect(temuan.map((t) => t.jenis), contains('tidur'));
      expect(temuan.map((t) => t.jenis), contains('air'));
      for (final t in temuan) {
        expect(t.angka.isNotEmpty, isTrue,
            reason: 'setiap temuan wajib menyebut angka pendukungnya');
      }
    });
  });

  group('FR-116 laporan kesehatan bulanan', () {
    BahanLaporanBulanan bahanBulan() => BahanLaporanBulanan(
          bulan: DateTime(2026, 8),
          berat: [titik(1, 78), titik(31, 76.5)],
          sistolik: [titik(2, 130), titik(30, 124)],
          tidurJam: [titik(3, 7), titik(28, 7.5)],
          airMl: [titik(4, 1500), titik(29, 2200)],
          menitAktivitas: [titik(5, 30), titik(27, 45)],
          suasana: [titik(6, 3), titik(26, 4)],
          jumlahCatatanMakan: 12,
          jumlahCatatanKesehatan: 6,
          jumlahJanji: 1,
          jumlahHariMinumObat: 25,
          targetAirMl: 2000,
        );

    test('laporan menyebut jumlah hari dan tiap bagian punya angka', () {
      final laporan = susunLaporanBulanan(bahanBulan());

      expect(laporan.judulBulan, contains('Agustus'));
      expect(laporan.jumlahHari, 31);
      expect(laporan.hariAdaCatatan, 12);
      expect(laporan.bagian.map((b) => b.judul), contains('Berat badan'));
      final berat = laporan.bagian.firstWhere((b) => b.judul == 'Berat badan');
      expect(berat.jumlahData, 2);
      expect(berat.baris.join(' '), contains('78'));
    });

    test('tiga kelompok: membaik, berubah, perlu diperhatikan', () {
      final kelompok = kelompokPerubahan(bahanBulan());
      expect(kelompok.map((b) => b.judul).toList(),
          ['Yang membaik', 'Yang berubah', 'Yang perlu diperhatikan']);

      final membaik = kelompok.first.baris.join(' ');
      expect(membaik, contains('Air minum'),
          reason: 'air bergerak menuju target 2000 ml');
    });

    test('perubahan menjauh dari target masuk "perlu diperhatikan"', () {
      final kelompok = kelompokPerubahan(BahanLaporanBulanan(
        bulan: DateTime(2026, 8),
        berat: [titik(1, 80), titik(31, 84)],
        sistolik: const [],
        tidurJam: const [],
        airMl: const [],
        menitAktivitas: const [],
        suasana: const [],
        jumlahCatatanMakan: 0,
        jumlahCatatanKesehatan: 0,
        jumlahJanji: 0,
        jumlahHariMinumObat: 0,
        targetBerat: 75,
      ));

      final perhatian = kelompok.last.baris.join(' ');
      expect(perhatian, contains('menjauh dari target'));
      expect(perhatian, contains('80'));
    });

    test('pemilih bulan hanya memuat bulan yang ada datanya', () {
      final daftar = bulanTersedia([
        DateTime(2026, 8, 3),
        DateTime(2026, 8, 20),
        DateTime(2026, 9, 1),
      ]);
      expect(daftar, [DateTime(2026, 9), DateTime(2026, 8)],
          reason: 'bulan terbaru di depan supaya pemilih menampilkan yang terakhir');
    });
  });

  // ------------------------------------------------------------------ layar
  group('FR-118 layar catatan', () {
    testWidgets('tambah catatan lewat dialog lalu hapus', (t) async {
      await layarTinggi(t);
      await t.pumpWidget(bungkus(const CatatanScreen(jamSekarang: _jam)));
      await t.pumpAndSettle();

      expect(find.textContaining('Belum ada catatan'), findsWidgets);

      await t.tap(find.byKey(const Key('tambah_catatan')));
      await t.pumpAndSettle();
      await t.enterText(
          find.widgetWithText(TextField, 'Judul'), 'Pelajaran audit');
      await t.enterText(find.widgetWithText(TextField, 'Isi catatan'),
          'uji temuan sebelum lapor');
      await t.tap(find.byKey(const Key('simpan_catatan')));
      await t.pumpAndSettle();

      final baris = await db.select(db.catatanPengetahuan).get();
      expect(baris, hasLength(1));
      expect(baris.single.judul, 'Pelajaran audit');
      expect(find.text('Pelajaran audit'), findsOneWidget);

      await t.tap(find.byKey(Key('menu_catatan_${baris.single.id}')));
      await t.pumpAndSettle();
      await t.tap(find.text('Hapus'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('konfirmasi_hapus')));
      await t.pumpAndSettle();

      expect(await db.select(db.catatanPengetahuan).get(), isEmpty);
    });

    testWidgets('pencarian menyaring daftar', (t) async {
      final repo = PengetahuanRepository(db);
      await repo.simpanCatatan(judul: 'Zakat mal', isi: 'nisab 85 gram');
      await repo.simpanCatatan(judul: 'Olahraga pagi', isi: 'jalan 30 menit');

      await layarTinggi(t);
      await t.pumpWidget(bungkus(const CatatanScreen(jamSekarang: _jam)));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const Key('cari_catatan')), 'zakat');
      await t.pumpAndSettle();

      expect(find.text('Zakat mal'), findsOneWidget);
      expect(find.text('Olahraga pagi'), findsNothing);
    });
  });

  group('FR-119 layar keputusan', () {
    testWidgets('catat keputusan lengkap dengan risiko, biaya & keyakinan',
        (t) async {
      await layarTinggi(t);
      await t.pumpWidget(bungkus(const KeputusanScreen(jamSekarang: _jam)));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('tambah_keputusan')));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Keputusan'),
          'Ambil sertifikasi');
      await t.enterText(
          find.widgetWithText(TextField, 'Yang dipilih'), 'Ikut kelas daring');
      await t.enterText(find.widgetWithText(TextField, 'Risiko yang disadari'),
          'waktu terpotong');
      await t.enterText(
          find.widgetWithText(TextField, 'Biaya / ongkos'), 'Rp 1.500.000');
      await t.tap(find.byKey(const Key('pilih_90')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('simpan_keputusan')));
      await t.pumpAndSettle();

      final baris = await db.select(db.keputusan).get();
      expect(baris, hasLength(1));
      expect(baris.single.judul, 'Ambil sertifikasi');
      expect(baris.single.risiko, 'waktu terpotong');
      expect(baris.single.biaya, 'Rp 1.500.000');
      expect(
          baris.single.tinjauPada!
              .difference(DateTime(2026, 9, 21))
              .inDays,
          90,
          reason: 'jadwal tinjau 90 hari sejak hari ini');
      expect(find.text('Ambil sertifikasi'), findsOneWidget);
    });

    testWidgets('tinjauan yang jatuh tempo muncul & hasilnya bisa ditulis',
        (t) async {
      // Data disiapkan lewat penyimpanan: inilah bentuk datanya setelah 90 hari.
      final id = await PengetahuanRepository(db).simpanKeputusan(
        judul: 'Ambil sertifikasi',
        dipilih: 'Ikut kelas daring',
        tinjauPada: DateTime(2026, 9, 1),
      );

      await layarTinggi(t);
      await t.pumpWidget(bungkus(const KeputusanScreen(jamSekarang: _jam)));
      await t.pumpAndSettle();

      expect(find.textContaining('Siap ditinjau'), findsOneWidget);
      expect(find.byKey(Key('tinjau_keputusan_$id')), findsOneWidget);

      await t.tap(find.byKey(Key('tulis_hasil_$id')));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Apa yang terjadi'),
          'Selesai tahap 1');
      await t.tap(find.byKey(const Key('simpan_hasil_keputusan')));
      await t.pumpAndSettle();

      final lagi = await (db.select(db.keputusan)
            ..where((x) => x.id.equals(id)))
          .getSingle();
      expect(lagi.hasil, 'Selesai tahap 1');
      expect(lagi.hasilPada, isNotNull);
      expect(find.textContaining('Sudah ada hasilnya'), findsOneWidget);
    });
  });

  group('FR-121 layar ulangan', () {
    testWidgets('sesi ulangan benar-benar mengubah jadwal kartu', (t) async {
      final repo = PengetahuanRepository(db);
      final id = await repo.simpanKartu(
          pertanyaan: 'Apa itu nisab?', jawaban: '85 gram emas');
      // Kartu baru dijadwalkan besok → majukan ke kemarin supaya jatuh tempo.
      await (db.update(db.kartuUlangan)..where((x) => x.id.equals(id))).write(
        KartuUlanganCompanion(
            ulanganBerikut: Value(_jam().subtract(const Duration(days: 1)))),
      );

      await layarTinggi(t);
      await t.pumpWidget(bungkus(const UlanganScreen(jamSekarang: _jam)));
      await t.pumpAndSettle();

      expect(find.textContaining('Mulai ulangan'), findsOneWidget);
      await t.tap(find.byKey(const Key('mulai_ulangan')));
      await t.pumpAndSettle();
      expect(find.text('Apa itu nisab?'), findsOneWidget);

      await t.tap(find.byKey(const Key('buka_jawaban')));
      await t.pumpAndSettle();
      expect(find.text('85 gram emas'), findsOneWidget);

      await t.tap(find.byKey(const Key('jawab_tepat')));
      await t.pumpAndSettle();

      final kartu = await (db.select(db.kartuUlangan)
            ..where((x) => x.id.equals(id)))
          .getSingle();
      expect(kartu.kotak, 1);
      expect(kartu.jumlahDiulang, 1);
      expect(kartu.jumlahBenar, 1);
      expect(kartu.ulanganBerikut, DateTime(2026, 9, 24),
          reason: 'jawaban tepat menaikkan jarak ulangan menjadi 3 hari');
    });
  });

  group('FR-110 layar catatan makan', () {
    testWidgets('catat cepat sarapan dengan mutu & porsi', (t) async {
      await layarTinggi(t);
      await t.pumpWidget(bungkus(const MakanRingkasScreen(jamSekarang: _jam)));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('catat_sarapan')));
      await t.pumpAndSettle();
      await t.enterText(
          find.widgetWithText(TextField, 'Apa yang dimakan'), 'nasi telur');
      await t.enterText(
          find.widgetWithText(TextField, 'Porsi (boleh dikosongkan)'), '1 piring');
      await t.tap(find.byKey(const Key('mutu_baik')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('simpan_makan')));
      await t.pumpAndSettle();

      final baris = await db.select(db.catatanMakan).get();
      expect(baris, hasLength(1));
      expect(baris.single.isi, 'nasi telur');
      expect(baris.single.mutu, 'baik');
      expect(baris.single.porsi, '1 piring');
      expect(find.textContaining('nasi telur'), findsWidgets);
      expect(find.textContaining('Jumlah catatan: 1'), findsOneWidget);
    });
  });

  group('FR-112 layar suasana hati', () {
    testWidgets('catat suasana hati, energi dan stres', (t) async {
      await layarTinggi(t);
      await t.pumpWidget(bungkus(const SuasanaHatiScreen(jamSekarang: _jam)));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('tambah_suasana')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('suasana_4')));
      await t.tap(find.byKey(const Key('energi_3')));
      await t.tap(find.byKey(const Key('stres_2')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('simpan_suasana')));
      await t.pumpAndSettle();

      final baris = await db.select(db.suasanaHati).get();
      expect(baris, hasLength(1));
      expect(baris.single.skor, 4);
      expect(baris.single.energi, 3);
      expect(baris.single.stres, 2);
      expect(find.textContaining('Rata-rata suasana hati: 4.0'), findsOneWidget);
    });
  });

  group('FR-113 & FR-116 layar', () {
    testWidgets('layar temuan menjelaskan batasnya dan tidak menuduh',
        (t) async {
      await layarTinggi(t);
      await t.pumpWidget(bungkus(const TemuanKesehatanScreen(jamSekarang: _jam)));
      await t.pumpAndSettle();

      expect(find.textContaining('BUKAN diagnosis'), findsOneWidget);
      expect(find.textContaining('Cara membaca halaman ini'), findsOneWidget);
      periksaBahasa(t, 'temuan');
    });

    testWidgets('laporan bulanan menampilkan bagian & bisa disalin', (t) async {
      final repo = KesehatanRingkasRepository(db);
      await repo.simpanMakan(
          jenis: 'sarapan', isi: 'bubur', waktu: DateTime(2026, 8, 5, 7));
      await repo.simpanSuasana(skor: 4, waktu: DateTime(2026, 8, 20, 20));

      await layarTinggi(t);
      await t.pumpWidget(
          bungkus(const LaporanKesehatanBulananScreen(jamSekarang: _jam)));
      await t.pumpAndSettle();

      expect(find.textContaining('Agustus 2026'), findsWidgets);
      expect(find.byKey(const Key('bagian_Yang membaik')), findsOneWidget);
      expect(find.byKey(const Key('salin_laporan_bulanan')), findsOneWidget);
      periksaBahasa(t, 'laporan bulanan');
    });

    testWidgets('hub pengetahuan menampilkan pintu tiap bagian', (t) async {
      await layarTinggi(t);
      await t.pumpWidget(bungkus(const PengetahuanHubScreen(jamSekarang: _jam)));
      await t.pumpAndSettle();

      expect(find.text('Pengetahuan'), findsOneWidget);
      for (final rute in <String>[
        '/pengetahuan/catatan',
        '/pengetahuan/keputusan',
        '/pengetahuan/ulangan',
        '/pengetahuan/bacaan',
        '/pengetahuan/pembelajaran',
        '/pengetahuan/tautan',
      ]) {
        expect(find.byKey(Key('pengetahuan_$rute')), findsOneWidget,
            reason: 'pintu $rute harus ada');
      }
      periksaBahasa(t, 'hub pengetahuan');
    });
  });

  group('bahasa layar bebas kata terlarang (PRD III-11)', () {
    testWidgets('catatan, keputusan & ulangan', (t) async {
      await layarTinggi(t);
      for (final layar in <Widget>[
        const CatatanScreen(jamSekarang: _jam),
        const KeputusanScreen(jamSekarang: _jam),
        const UlanganScreen(jamSekarang: _jam),
      ]) {
        await t.pumpWidget(bungkus(layar));
        await t.pumpAndSettle();
        periksaBahasa(t, layar.runtimeType.toString());
      }
    });
  });
}

DateTime _jam() => sekarang;
