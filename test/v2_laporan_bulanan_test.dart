/// Uji FR-77 — laporan keuangan bulanan (ekspor PDF & CSV).
///
/// Yang diuji di sini, dengan angka yang dihitung sendiri di dalam uji:
/// 1. hitungan murni `hitungRingkasanBulanan` (pemasukan 5.000.000 sen +
///    pengeluaran 1.250.000 sen -> selisih 3.750.000 sen);
/// 2. CSV memuat header `tanggal;kategori;jenis;jumlah;catatan` + satu baris
///    data, dengan escape tanda kutip ganda;
/// 3. `bangunPdfLaporanBulanan` menghasilkan byte diawali `%PDF-` dan lebih
///    dari 1.000 byte;
/// 4. repositori membaca baris dalam bulan dengan batas atas EKSKLUSIF (baris
///    tanggal 1 bulan berikutnya tidak ikut);
/// 5. layar: ringkasan tampil, rincian kategori ber-Kunci, tombol `unduh_pdf`
///    benar-benar menulis berkas PDF ke folder sementara, dan PDF-nya diawali
///    `%PDF-`; berkas dibersihkan lagi di akhir uji.
///
/// Waktu uji dikunci: Selasa, 15 September 2026 08.00.
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:personal_life_os/core/laporan/pdf_laporan_bulanan.dart';
import 'package:personal_life_os/core/laporan/ringkasan_bulanan.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/core/utils/uang_utils.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/model/enums.dart';
import 'package:personal_life_os/data/repository/laporan_bulanan_repository.dart';
import 'package:personal_life_os/features/laporan/laporan_bulanan_screen.dart';

late AppDatabase db;
late LaporanBulananRepository laporan;

/// Waktu patok uji: Selasa, 15 September 2026 08.00.
final jamUji = DateTime(2026, 9, 15, 8);

/// Bulan laporan uji.
final september = DateTime(2026, 9, 1);

/// Kata yang dilarang PRD §III-11 (tanpa kata menghakimi).
const List<String> kataTerlarang = [
  'kamu',
  'gagal',
  'skor',
  'peringkat',
  'penilaian',
  'malas',
  'pelit',
  'buruk',
  'nilai',
  'berdosa',
  'wajib anda',
];

BarisTransaksiBulanan baris(
  int id,
  DateTime tanggal,
  String kategori,
  JenisArus jenis,
  int jumlahSen, {
  String? catatan,
}) =>
    BarisTransaksiBulanan(
      id: id,
      tanggal: tanggal,
      kategori: kategori,
      jenis: jenis,
      jumlahSen: jumlahSen,
      catatan: catatan,
    );

/// Id kategori bawaan (seed bawaan aplikasi) lewat kode stabilnya.
///
/// Uji memakai kategori bawaan — bukan membuat kategori baru — supaya tidak
/// berbenturan dengan seed dan supaya angka uji bisa ditelusuri di aplikasi.
Future<int> idKategori(String kode) async {
  final barisKategori = await (db.select(db.kategoriTransaksi)
        ..where((k) => k.kode.equals(kode)))
      .getSingle();
  return barisKategori.id;
}

Future<int> tambahTransaksi({
  required String idTransaksi,
  required DateTime tanggal,
  required int jumlahSen,
  JenisArus jenis = JenisArus.pengeluaran,
  int? kategoriId,
  String? catatan,
}) async {
  final barisBaru = await db.into(db.transaksi).insertReturning(
        TransaksiCompanion.insert(
          idTransaksi: idTransaksi,
          jenis: Value(jenis.nilaiDb),
          tanggal: tanggal,
          jumlahSen: jumlahSen,
          kategoriId: Value(kategoriId),
          catatan: Value(catatan),
        ),
      );
  return barisBaru.id;
}

Future<int> tambahTagihan({
  required String nama,
  required DateTime jatuhTempo,
  int? jumlahSen,
  bool lunas = false,
}) async {
  final barisBaru = await db.into(db.tagihan).insertReturning(
        TagihanCompanion.insert(
          nama: nama,
          jumlahSen: Value(jumlahSen),
          jatuhTempo: jatuhTempo,
          lunas: Value(lunas),
        ),
      );
  return barisBaru.id;
}

Future<void> tambahRiwayat({
  required int tagihanId,
  required DateTime periodeJatuhTempo,
  required int jumlahSen,
  DateTime? tanggalBayar,
}) async {
  await db.into(db.riwayatPembayaran).insert(
        RiwayatPembayaranCompanion.insert(
          tagihanId: tagihanId,
          periodeJatuhTempo: periodeJatuhTempo,
          jumlahSen: jumlahSen,
          tanggalBayar: tanggalBayar ?? periodeJatuhTempo,
        ),
      );
}

String teksKunci(WidgetTester t, String kunci) =>
    t.widget<Text>(find.byKey(Key(kunci))).data ?? '';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    laporan = LaporanBulananRepository(db);
  });

  tearDown(() async => db.close());

  // =========================================================================
  // 1. Hitungan murni
  // =========================================================================
  group('hitungan murni RingkasanBulanan', () {
    test('pemasukan 5.000.000 sen + pengeluaran 1.250.000 sen -> selisih '
        '3.750.000 sen', () {
      final r = hitungRingkasanBulanan(
        bulan: september,
        transaksi: [
          baris(1, DateTime(2026, 9, 1), 'Gaji', JenisArus.pemasukan, 5000000),
          baris(2, DateTime(2026, 9, 5), 'Makan', JenisArus.pengeluaran, 1250000),
        ],
      );

      expect(r.totalPemasukanSen, 5000000);
      expect(r.totalPengeluaranSen, 1250000);
      expect(r.selisihSen, 3750000);
      expect(r.jumlahTransaksi, 2);
      expect(r.adaTransaksi, isTrue);
      expect(r.kosong, isFalse);
      expect(r.bulan, september);
    });

    test('selisih boleh negatif dan tetap dihitung apa adanya', () {
      final r = hitungRingkasanBulanan(
        bulan: september,
        transaksi: [
          baris(1, DateTime(2026, 9, 3), 'Belanja', JenisArus.pengeluaran, 900000),
          baris(2, DateTime(2026, 9, 4), 'Bonus', JenisArus.pemasukan, 400000),
        ],
      );
      expect(r.selisihSen, -500000);
    });

    test('rincian per kategori: nama sama beda jenis tidak digabung, dan baris '
        'tanpa kategori tetap dihitung', () {
      final r = hitungRingkasanBulanan(
        bulan: september,
        transaksi: [
          baris(1, DateTime(2026, 9, 2), 'Makan', JenisArus.pengeluaran, 300000),
          baris(2, DateTime(2026, 9, 6), 'Makan', JenisArus.pengeluaran, 200000),
          baris(3, DateTime(2026, 9, 7), 'Makan', JenisArus.pemasukan, 50000),
          baris(4, DateTime(2026, 9, 8), kategoriTanpaNama,
              JenisArus.pengeluaran, 120000),
        ],
      );

      final pengeluaran = r.rincianKategori
          .where((k) => k.jenis == JenisArus.pengeluaran)
          .toList();
      final pemasukan = r.rincianKategori
          .where((k) => k.jenis == JenisArus.pemasukan)
          .toList();

      expect(r.rincianKategori, hasLength(3));
      expect(pengeluaran.first.nama, 'Makan');
      expect(pengeluaran.first.jumlahSen, 500000);
      expect(pengeluaran.first.jumlahTransaksi, 2);
      expect(pengeluaran[1].nama, kategoriTanpaNama);
      expect(pengeluaran[1].jumlahSen, 120000);
      expect(pemasukan.single.nama, 'Makan');
      expect(pemasukan.single.jumlahSen, 50000);
      expect(r.totalPemasukanSen, 50000);
      expect(r.totalPengeluaranSen, 620000);
    });

    test('rincian kategori: pengeluaran lebih dulu, lalu nominal terbesar', () {
      final r = hitungRingkasanBulanan(
        bulan: september,
        transaksi: [
          baris(1, DateTime(2026, 9, 2), 'Gaji', JenisArus.pemasukan, 9000000),
          baris(2, DateTime(2026, 9, 3), 'Kecil', JenisArus.pengeluaran, 10000),
          baris(3, DateTime(2026, 9, 4), 'Besar', JenisArus.pengeluaran, 900000),
        ],
      );
      expect(
        r.rincianKategori.map((k) => k.nama).toList(),
        ['Besar', 'Kecil', 'Gaji'],
      );
    });

    test('lima pengeluaran terbesar: urut menurun, tanpa pemasukan, dan '
        'berhenti di lima', () {
      final r = hitungRingkasanBulanan(
        bulan: september,
        transaksi: [
          baris(1, DateTime(2026, 9, 2), 'Gaji', JenisArus.pemasukan, 9999999),
          baris(2, DateTime(2026, 9, 3), 'A', JenisArus.pengeluaran, 100000),
          baris(3, DateTime(2026, 9, 4), 'B', JenisArus.pengeluaran, 600000),
          baris(4, DateTime(2026, 9, 5), 'C', JenisArus.pengeluaran, 300000),
          baris(5, DateTime(2026, 9, 6), 'D', JenisArus.pengeluaran, 500000),
          baris(6, DateTime(2026, 9, 7), 'E', JenisArus.pengeluaran, 200000),
          baris(7, DateTime(2026, 9, 8), 'F', JenisArus.pengeluaran, 400000),
        ],
      );

      expect(r.limaPengeluaranTerbesar, hasLength(5));
      expect(r.limaPengeluaranTerbesar.map((t) => t.id).toList(),
          [3, 5, 7, 4, 6]);
      expect(r.limaPengeluaranTerbesar.every(
          (t) => t.jenis == JenisArus.pengeluaran), isTrue);
    });

    test('bulan tanpa catatan: nol yang jujur + teks kosong', () {
      final r = hitungRingkasanBulanan(bulan: september, transaksi: const []);

      expect(r.totalPemasukanSen, 0);
      expect(r.totalPengeluaranSen, 0);
      expect(r.selisihSen, 0);
      expect(r.jumlahTransaksi, 0);
      expect(r.adaTransaksi, isFalse);
      expect(r.kosong, isTrue);
      expect(r.rincianKategori, isEmpty);
      expect(r.limaPengeluaranTerbesar, isEmpty);
      expect(r.teksRingkasan,
          'Belum ada catatan transaksi maupun tagihan untuk September 2026.');
    });

    test('tidak ada transaksi tetapi ada tagihan: teks menyebut tagihannya', () {
      final r = hitungRingkasanBulanan(
        bulan: september,
        transaksi: const [],
        tagihan: [
          TagihanBulanan(
            nama: 'Listrik',
            jumlahSen: 250000,
            jatuhTempo: DateTime(2026, 9, 20),
            lunas: false,
          ),
        ],
      );
      expect(r.kosong, isFalse);
      expect(r.teksRingkasan, contains('1 tagihan'));
      expect(r.teksRingkasan, contains('Rp 2.500'));
    });

    test('tagihan: jumlah, total, dan pisahan lunas/belum lunas', () {
      final r = hitungRingkasanBulanan(
        bulan: september,
        transaksi: [
          baris(1, DateTime(2026, 9, 1), 'Gaji', JenisArus.pemasukan, 5000000),
          baris(2, DateTime(2026, 9, 5), 'Makan', JenisArus.pengeluaran, 1250000),
        ],
        tagihan: [
          TagihanBulanan(
            nama: 'Listrik',
            jumlahSen: 250000,
            jatuhTempo: DateTime(2026, 9, 20),
            lunas: false,
          ),
          TagihanBulanan(
            nama: 'Internet',
            jumlahSen: 350000,
            jatuhTempo: DateTime(2026, 9, 10),
            lunas: true,
          ),
        ],
      );

      expect(r.jumlahTagihan, 2);
      expect(r.totalTagihanSen, 600000);
      expect(r.jumlahTagihanLunas, 1);
      expect(r.jumlahTagihanBelumLunas, 1);
      expect(r.nominalTagihanLunasSen, 350000);
      expect(r.nominalTagihanBelumLunasSen, 250000);
      expect(r.teksRingkasan, contains('Rp 50.000'));
      expect(r.teksRingkasan, contains('Rp 12.500'));
      expect(r.teksRingkasan, contains('Rp 37.500'));
      expect(r.teksRingkasan, contains('1 di antaranya sudah lunas'));
    });

    test('teks ringkasan paling banyak dua kalimat dan bebas kata terlarang',
        () {
      final r = hitungRingkasanBulanan(
        bulan: september,
        transaksi: [
          baris(1, DateTime(2026, 9, 1), 'Gaji', JenisArus.pemasukan, 5000000),
        ],
        tagihan: [
          TagihanBulanan(
            nama: 'Listrik',
            jumlahSen: 250000,
            jatuhTempo: DateTime(2026, 9, 20),
            lunas: false,
          ),
        ],
      );
      // Titik ribuan ("Rp 50.000") tidak dihitung sebagai akhir kalimat.
      final kalimat = r.teksRingkasan
          .split(RegExp(r'\.\s'))
          .where((s) => s.trim().isNotEmpty)
          .toList();
      expect(kalimat, hasLength(2));
      for (final kata in kataTerlarang) {
        expect(r.teksRingkasan.toLowerCase().contains(kata), isFalse,
            reason: 'teks ringkasan memuat kata terlarang "$kata"');
      }
    });

    test('bulan pada argumen dinormalkan ke tanggal 1', () {
      final r = hitungRingkasanBulanan(
        bulan: DateTime(2026, 9, 28, 23, 30),
        transaksi: const [],
      );
      expect(r.bulan, DateTime(2026, 9, 1));
    });

    test('label bulan & kode berkas tidak butuh data locale', () {
      expect(namaBulanTahunId(september), 'September 2026');
      expect(kunciBulanLaporan(september), '2026-09');
      expect(kodeBerkasBulan(september), '202609');
      expect(namaBulanIndonesia, hasLength(12));
    });
  });

  // =========================================================================
  // 2. CSV
  // =========================================================================
  group('ringkasanKeCsv', () {
    test('header + satu baris data, pemisah titik koma', () {
      final r = hitungRingkasanBulanan(
        bulan: september,
        transaksi: [
          baris(1, DateTime(2026, 9, 1), 'Gaji', JenisArus.pemasukan, 5000000),
          baris(2, DateTime(2026, 9, 5), 'Makan', JenisArus.pengeluaran, 1250000),
        ],
      );
      final csv = ringkasanKeCsv(r);
      final barisCsv = csv.split('\n');

      expect(barisCsv.first, 'tanggal;kategori;jenis;jumlah;catatan');
      expect(barisCsv[1], '2026-09-01;Gaji;pemasukan;5000000;');
      expect(barisCsv[2], '2026-09-05;Makan;pengeluaran;1250000;');
      expect(csv, contains('# Blok ringkasan'));
      expect(csv, contains('periode;2026-09'));
      expect(csv, contains('total_pemasukan;5000000'));
      expect(csv, contains('total_pengeluaran;1250000'));
      expect(csv, contains('selisih;3750000'));
      expect(csv, contains('jumlah_transaksi;2'));
    });

    test('tanda kutip ganda di-escape dan sel berpemisah dibungkus kutip', () {
      final r = hitungRingkasanBulanan(
        bulan: september,
        transaksi: [
          baris(1, DateTime(2026, 9, 2), 'Makan', JenisArus.pengeluaran, 250000,
              catatan: 'Bayar "nasi"; dan sambal'),
        ],
      );
      final csv = ringkasanKeCsv(r);
      expect(
        csv,
        contains('2026-09-02;Makan;pengeluaran;250000;'
            '"Bayar ""nasi""; dan sambal"'),
      );
    });

    test('bulan kosong tetap menghasilkan header dan blok ringkasan nol', () {
      final csv = ringkasanKeCsv(
          hitungRingkasanBulanan(bulan: september, transaksi: const []));
      expect(csv.split('\n').first, 'tanggal;kategori;jenis;jumlah;catatan');
      expect(csv, contains('total_pemasukan;0'));
      expect(csv, contains('jumlah_transaksi;0'));
    });
  });

  // =========================================================================
  // 3. PDF
  // =========================================================================
  group('bangunPdfLaporanBulanan', () {
    test('byte diawali %PDF- dan lebih dari 1.000 byte', () async {
      final r = hitungRingkasanBulanan(
        bulan: september,
        transaksi: [
          baris(1, DateTime(2026, 9, 1), 'Gaji', JenisArus.pemasukan, 500000000,
              catatan: 'Gaji bulan September'),
          baris(2, DateTime(2026, 9, 5), 'Makan', JenisArus.pengeluaran, 125000000),
        ],
        tagihan: [
          TagihanBulanan(
            nama: 'Listrik',
            jumlahSen: 25000000,
            jatuhTempo: DateTime(2026, 9, 20),
            lunas: false,
          ),
        ],
      );

      final byte = await bangunPdfLaporanBulanan(r,
          catatan: 'Contoh catatan pemilik laporan.');

      expect(byte.length, greaterThan(1000));
      expect(String.fromCharCodes(byte.sublist(0, 5)), '%PDF-');
      expect(String.fromCharCodes(byte.sublist(byte.length - 6)).trim(),
          endsWith('%%EOF'));
      // ignore: avoid_print
      print('Ukuran PDF contoh: ${byte.length} byte');
    });

    test('bulan kosong: PDF tetap sah dan tetap memuat kalimat jujur', () async {
      final r = hitungRingkasanBulanan(bulan: september, transaksi: const []);
      final byte = await bangunPdfLaporanBulanan(r);
      expect(byte.length, greaterThan(1000));
      expect(String.fromCharCodes(byte.sublist(0, 5)), '%PDF-');
    });

    test('banyak baris: PDF tetap sah (halaman tambahan)', () async {
      final r = hitungRingkasanBulanan(
        bulan: september,
        transaksi: [
          for (var i = 1; i <= 60; i++)
            baris(i, DateTime(2026, 9, 1 + (i % 28)),
                'Kategori ${i % 7}', JenisArus.pengeluaran, 100000 * i),
        ],
      );
      final byte = await bangunPdfLaporanBulanan(r);
      expect(byte.length, greaterThan(1000));
      expect(String.fromCharCodes(byte.sublist(0, 5)), '%PDF-');
    });

    test('catatan kaki & pengingat asal angka tersedia sebagai teks tetap', () {
      expect(catatanKakiLaporan, contains('Personal Life OS'));
      expect(pengingatAsalAngka, contains('catatan yang Anda isi sendiri'));
    });
  });

  // =========================================================================
  // 4. Repositori (hanya baca)
  // =========================================================================
  group('LaporanBulananRepository', () {
    test('batas atas EKSKLUSIF: baris 1 Oktober tidak ikut, baris 30 September '
        'malam tetap ikut', () async {
      final makan = await idKategori('kel_makan');
      await tambahTransaksi(
        idTransaksi: 'trx_agu',
        tanggal: DateTime(2026, 8, 31, 12),
        jumlahSen: 900000,
        kategoriId: makan,
      );
      await tambahTransaksi(
        idTransaksi: 'trx_sep_awal',
        tanggal: DateTime(2026, 9, 1),
        jumlahSen: 1000000,
        kategoriId: makan,
      );
      await tambahTransaksi(
        idTransaksi: 'trx_sep_akhir',
        tanggal: DateTime(2026, 9, 30, 23, 59),
        jumlahSen: 200000,
        kategoriId: makan,
      );
      await tambahTransaksi(
        idTransaksi: 'trx_okt',
        tanggal: DateTime(2026, 10, 1),
        jumlahSen: 7770000,
        kategoriId: makan,
      );

      final r = await laporan.bulan(september);

      expect(r.totalPengeluaranSen, 1200000);
      expect(r.jumlahTransaksi, 2);
      expect(r.transaksi.map((t) => t.id).length, 2);
      expect(r.rincianKategori.single.nama, 'Makan & Minum');
      expect(r.rincianKategori.single.jumlahSen, 1200000);
    });

    test('baris tanpa kategori masuk "Tanpa kategori" dan jenis dibaca dari '
        'kolomnya', () async {
      await tambahTransaksi(
        idTransaksi: 'trx_gaji',
        tanggal: DateTime(2026, 9, 1),
        jumlahSen: 500000000,
        jenis: JenisArus.pemasukan,
      );
      final r = await laporan.bulan(september);
      expect(r.transaksi.single.kategori, kategoriTanpaNama);
      expect(r.transaksi.single.jenis, JenisArus.pemasukan);
      expect(r.totalPemasukanSen, 500000000);
      expect(r.totalPengeluaranSen, 0);
    });

    test('tanggal dari kolom dateTime() terbaca sebagai hari yang sama', () async {
      await tambahTransaksi(
        idTransaksi: 'trx_hari',
        tanggal: DateTime(2026, 9, 9),
        jumlahSen: 1000,
      );
      final r = await laporan.bulan(september);
      expect(r.transaksi.single.tanggal.year, 2026);
      expect(r.transaksi.single.tanggal.month, 9);
      expect(r.transaksi.single.tanggal.day, 9);
      // Satuan penyimpanan = detik Unix; konversinya dijaga satu pintu.
      expect(dariDetikUnix(1789000000).isAfter(DateTime(2026, 1, 1)), isTrue);
    });

    test('tagihan jatuh tempo bulan itu + riwayat periode yang sudah bergeser',
        () async {
      final listrik = await tambahTagihan(
        nama: 'Listrik',
        jatuhTempo: DateTime(2026, 9, 20),
        jumlahSen: 25000000,
      );
      await tambahTagihan(
        nama: 'Internet',
        jatuhTempo: DateTime(2026, 10, 1),
        jumlahSen: 35000000,
      );
      // Tagihan yang periodenya sudah bergeser ke Oktober karena sudah dibayar:
      // baris September-nya hanya tersisa di riwayat pembayaran.
      final air = await tambahTagihan(
        nama: 'Air',
        jatuhTempo: DateTime(2026, 10, 5),
        jumlahSen: 15000000,
      );
      await tambahRiwayat(
        tagihanId: air,
        periodeJatuhTempo: DateTime(2026, 9, 25),
        jumlahSen: 15000000,
      );
      await tambahTransaksi(
        idTransaksi: 'trx_listrik',
        tanggal: DateTime(2026, 9, 20),
        jumlahSen: 25000000,
      );

      final r = await laporan.bulan(september);

      expect(r.jumlahTagihan, 2,
          reason: 'Internet (1 Oktober) tidak ikut; Air terbaca dari riwayat');
      expect(r.totalTagihanSen, 40000000);
      expect(r.jumlahTagihanLunas, 1);
      expect(r.jumlahTagihanBelumLunas, 1);
      expect(r.tagihan.map((t) => t.nama).toSet(), {'Listrik', 'Air'});
      expect(r.tagihan.firstWhere((t) => t.nama == 'Air').lunas, isTrue);
      expect(r.tagihan.firstWhere((t) => t.nama == 'Listrik').lunas, isFalse);
      expect(listrik, greaterThan(0));
      expect(r.transaksi.single.tanggal.day, 20);
    });

    test('bulan tanpa baris sama sekali: ringkasan nol, bukan galat', () async {
      final r = await laporan.bulan(DateTime(2026, 1, 1));
      expect(r.adaTransaksi, isFalse);
      expect(r.kosong, isTrue);
      expect(r.selisihSen, 0);
      expect(r.teksRingkasan, contains('Januari 2026'));
    });

    test('bulanTersedia: bulan unik dari transaksi, tagihan, dan riwayat, urut '
        'terbaru lebih dulu', () async {
      await tambahTransaksi(
        idTransaksi: 'trx_a',
        tanggal: DateTime(2026, 8, 10),
        jumlahSen: 1000,
      );
      await tambahTransaksi(
        idTransaksi: 'trx_b',
        tanggal: DateTime(2026, 9, 10),
        jumlahSen: 1000,
      );
      final tag = await tambahTagihan(
        nama: 'Sewa',
        jatuhTempo: DateTime(2026, 7, 5),
        jumlahSen: 1000,
      );
      await tambahRiwayat(
        tagihanId: tag,
        periodeJatuhTempo: DateTime(2026, 6, 5),
        jumlahSen: 1000,
      );

      expect(await laporan.bulanTersedia(), [
        DateTime(2026, 9, 1),
        DateTime(2026, 8, 1),
        DateTime(2026, 7, 1),
        DateTime(2026, 6, 1),
      ]);
    });

    test('namaBulanTahun memakai nama bulan tetap, bukan data locale', () async {
      expect(laporan.namaBulanTahun(september), 'September 2026');
      expect(laporan.namaBulanTahun(DateTime(2026, 12, 31)), 'Desember 2026');
    });

    test('laporan membaca seluruh data bulan dan cocok dengan PDF yang dibuat',
        () async {
      await tambahTransaksi(
        idTransaksi: 'trx_masuk',
        tanggal: DateTime(2026, 9, 1),
        jumlahSen: 5000000,
        jenis: JenisArus.pemasukan,
      );
      await tambahTransaksi(
        idTransaksi: 'trx_keluar',
        tanggal: DateTime(2026, 9, 5),
        jumlahSen: 1250000,
      );

      final r = await laporan.bulan(september);
      expect(r.selisihSen, 3750000);

      final csv = ringkasanKeCsv(r);
      expect(csv, contains('selisih;3750000'));
      final pdf = await bangunPdfLaporanBulanan(r);
      expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
    });
  });

  // =========================================================================
  // 5. Layar
  // =========================================================================
  group('layar laporan bulanan', () {
    late Directory folder;

    setUp(() {
      folder = Directory.systemTemp.createTempSync('plo_laporan_uji_');
    });

    tearDown(() {
      if (folder.existsSync()) folder.deleteSync(recursive: true);
    });

    /// Isi basis data uji: 1 pemasukan, 2 pengeluaran berkategori, 1 tagihan.
    ///
    /// Ditulis lewat SATU batch di dalam satu `runAsync` — aturan uji drift:
    /// hanya satu tulisan yang ditunggu per `runAsync`.
    Future<void> isiData(WidgetTester t) async {
      await t.runAsync(() async {
        final idMakan = await idKategori('kel_makan');
        final idGaji = await idKategori('masuk_gaji');
        await db.batch((b) {
          b.insertAll(db.transaksi, [
            TransaksiCompanion.insert(
              idTransaksi: 'trx_gaji_sep',
              jenis: const Value('pemasukan'),
              tanggal: DateTime(2026, 9, 1),
              jumlahSen: rupiahKeSen(5000000),
              kategoriId: Value(idGaji),
            ),
            TransaksiCompanion.insert(
              idTransaksi: 'trx_makan_1',
              tanggal: DateTime(2026, 9, 5),
              jumlahSen: rupiahKeSen(400000),
              kategoriId: Value(idMakan),
            ),
            TransaksiCompanion.insert(
              idTransaksi: 'trx_makan_2',
              tanggal: DateTime(2026, 9, 12),
              jumlahSen: rupiahKeSen(850000),
              kategoriId: Value(idMakan),
              catatan: const Value('Belanja bulanan'),
            ),
          ]);
          b.insertAll(db.tagihan, [
            TagihanCompanion.insert(
              nama: 'Listrik',
              jumlahSen: Value(rupiahKeSen(250000)),
              jatuhTempo: DateTime(2026, 9, 20),
            ),
          ]);
        });
      });
    }

    Future<void> tampilkan(WidgetTester t, {FolderLaporan? ambilFolder}) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: LaporanBulananScreen(
            jamSekarang: () => jamUji,
            folderLaporan: ambilFolder ?? () async => folder,
          ),
        ),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
    }

    /// Daftar memuat anaknya secara bertahap, jadi target harus digulir dulu.
    Future<void> gulirKe(WidgetTester t, Finder target) async {
      await t.scrollUntilVisible(
        target,
        260,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
      await t.pump(const Duration(milliseconds: 100));
    }

    Future<void> tekan(WidgetTester t, Key kunci) async {
      final target = find.byKey(kunci);
      await gulirKe(t, target);
      await t.tap(target);
      await t.pump(const Duration(milliseconds: 150));
    }

    /// Beri kesempatan pekerjaan I/O nyata (bangun PDF, tulis berkas) selesai.
    ///
    /// Tiap jeda nyata hanya memajukan satu langkah `await`, jadi jeda diulang
    /// sampai penanda yang ditunggu muncul (atau menyerah setelah 25 putaran).
    Future<void> tungguMuncul(WidgetTester t, Key kunci) async {
      for (var putaran = 0; putaran < 25; putaran++) {
        if (find.byKey(kunci).evaluate().isNotEmpty) break;
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 120)));
        await t.pump(const Duration(milliseconds: 40));
      }
    }

    Future<void> tutup(WidgetTester t) async {
      await t.pump(const Duration(seconds: 10));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.binding.setSurfaceSize(null);
    }

    testWidgets('menampilkan ringkasan, tagihan, rincian kategori, dan tombol '
        'unduh', (t) async {
      await isiData(t);
      await tampilkan(t);

      expect(teksKunci(t, 'label_bulan'), 'September 2026');
      expect(find.byKey(const Key('ringkasan_bulanan')), findsOneWidget);
      expect(teksKunci(t, 'total_pemasukan'), 'Rp 5.000.000');
      expect(teksKunci(t, 'total_pengeluaran'), 'Rp 1.250.000');
      expect(teksKunci(t, 'selisih'), 'Rp 3.750.000');
      expect(find.byKey(const Key('laporan_kosong')), findsNothing);

      await gulirKe(t, find.textContaining('1 tagihan, total Rp 250.000'));
      expect(find.textContaining('1 tagihan, total Rp 250.000'), findsOneWidget);
      expect(find.textContaining('1 belum lunas'), findsOneWidget);

      await gulirKe(t, find.byKey(const Key('kategori_bulanan_Makan & Minum')));
      expect(find.byKey(const Key('kategori_bulanan_Makan & Minum')),
          findsOneWidget);
      expect(find.text('Makan & Minum · 2 transaksi'), findsOneWidget);

      await gulirKe(t, find.byKey(const Key('kategori_bulanan_Gaji')));
      expect(find.byKey(const Key('kategori_bulanan_Gaji')), findsOneWidget);
      expect(find.text('Gaji · 1 transaksi'), findsOneWidget);

      await gulirKe(t, find.byKey(const Key('unduh_pdf')));
      expect(find.byKey(const Key('unduh_pdf')), findsOneWidget);
      expect(find.byKey(const Key('unduh_csv')), findsOneWidget);

      await tutup(t);
    });

    testWidgets('pindah bulan: Agustus kosong menampilkan teks jujur, kembali '
        'ke September lagi', (t) async {
      await isiData(t);
      await tampilkan(t);

      await tekan(t, const Key('bulan_sebelum'));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));

      expect(teksKunci(t, 'label_bulan'), 'Agustus 2026');
      expect(find.byKey(const Key('laporan_kosong')), findsOneWidget);
      expect(teksKunci(t, 'total_pemasukan'), 'Belum ada data');

      await tekan(t, const Key('bulan_berikut'));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));

      expect(teksKunci(t, 'label_bulan'), 'September 2026');
      expect(find.byKey(const Key('laporan_kosong')), findsNothing);
      expect(teksKunci(t, 'selisih'), 'Rp 3.750.000');

      await tutup(t);
    });

    testWidgets('tekan unduh_pdf menulis berkas PDF nyata ke folder sementara',
        (t) async {
      await isiData(t);
      await tampilkan(t);

      await tekan(t, const Key('unduh_pdf'));
      await tungguMuncul(t, const Key('hasil_unduh'));

      expect(find.byKey(const Key('hasil_unduh')), findsOneWidget);
      final snack = t.widget<SnackBar>(find.byKey(const Key('hasil_unduh')));
      final teksSnack = (snack.content as Text).data ?? '';
      expect(teksSnack, contains('plo_laporan_202609.pdf'));
      expect(teksSnack, matches(RegExp(r'\((?:[0-9]+ byte|[0-9,]+ KB)\)')));

      final berkas = File(p.join(folder.path, 'plo_laporan_202609.pdf'));
      expect(berkas.existsSync(), isTrue);
      final isi = berkas.readAsBytesSync();
      expect(isi.length, greaterThan(1000));
      expect(String.fromCharCodes(isi.sublist(0, 5)), '%PDF-');
      // ignore: avoid_print
      print('PDF dari layar: ${isi.length} byte');

      await tutup(t);
    });

    testWidgets('tekan unduh_csv menulis berkas CSV nyata dengan header',
        (t) async {
      await isiData(t);
      await tampilkan(t);

      await tekan(t, const Key('unduh_csv'));
      await tungguMuncul(t, const Key('hasil_unduh'));

      expect(find.byKey(const Key('hasil_unduh')), findsOneWidget);
      final berkas = File(p.join(folder.path, 'plo_laporan_202609.csv'));
      expect(berkas.existsSync(), isTrue);
      final isi = berkas.readAsStringSync();
      expect(isi, startsWith('tanggal;kategori;jenis;jumlah;catatan'));
      expect(isi, contains('2026-09-05;Makan & Minum;pengeluaran;40000000;'));
      expect(isi, contains('selisih;375000000'));

      await tutup(t);
    });

    testWidgets('bulan kosong: teks jujur tampil dan PDF tetap bisa diunduh '
        'berisi ringkasan nol', (t) async {
      await tampilkan(t);

      expect(find.byKey(const Key('laporan_kosong')), findsOneWidget);
      expect(find.textContaining('Belum ada catatan transaksi'), findsWidgets);

      await tekan(t, const Key('unduh_pdf'));
      await tungguMuncul(t, const Key('hasil_unduh'));

      expect(find.byKey(const Key('hasil_unduh')), findsOneWidget);
      final berkas = File(p.join(folder.path, 'plo_laporan_202609.pdf'));
      expect(berkas.existsSync(), isTrue);
      expect(String.fromCharCodes(berkas.readAsBytesSync().sublist(0, 5)),
          '%PDF-');

      await tutup(t);
    });

    testWidgets('teks layar bebas kata terlarang (PRD III-11)', (t) async {
      await isiData(t);
      await tampilkan(t);

      String kumpulkan() => t
          .widgetList<Text>(find.byType(Text))
          .map((w) => (w.data ?? '').toLowerCase())
          .join(' | ');
      final atas = kumpulkan();
      await gulirKe(t, find.byKey(const Key('unduh_pdf')));
      final semuaTeks = '$atas | ${kumpulkan()}';
      for (final kata in kataTerlarang) {
        expect(semuaTeks.contains(kata), isFalse,
            reason: 'layar memuat kata terlarang "$kata" pada: $semuaTeks');
      }

      await tutup(t);
    });

    testWidgets('kegagalan folder: pesan jujur tampil dan tidak ada berkas',
        (t) async {
      await isiData(t);
      await tampilkan(t,
          ambilFolder: () async =>
              throw const FileSystemException('folder tidak bisa dibuka'));

      await tekan(t, const Key('unduh_pdf'));
      await tungguMuncul(t, const Key('pesan_laporan'));

      expect(find.byKey(const Key('hasil_unduh')), findsNothing);
      expect(find.byKey(const Key('pesan_laporan')), findsOneWidget);
      expect(find.textContaining('belum bisa disimpan'), findsOneWidget);
      expect(folder.listSync(), isEmpty);

      await tutup(t);
    });
  });
}
