/// Uji V2 uang lanjutan: FR-74 (catat pembayaran utang), pengeluaran
/// terencana), FR-74 (prioritas & jadwal pembayaran), FR-75 (strategi
/// pelunasan).
///
/// Kriteria terima PRD yang diuji di sini:
/// * sisa utang = pokok acuan - jumlah bagian pokok yang dibayar; bagian bunga
///   tidak mengurangi sisa utang;
/// * baris pembayaran yang tidak konsisten (jumlah bukan pokok + bunga) dan
///   bagian pokok yang melebihi sisa utang ditolak dengan galat jelas;
/// * hapus kewajiban ikut menghapus seluruh pembayarannya (hapus berdampingan
///   ada di repositori, bukan di layar);
/// * urutan pelunasan bola salju = utang terkecil dulu; longsor = bunga
///   tertinggi dulu; simulasi melaporkan bulan ke berapa tuntas + total bunga,
///   dan berhenti apa adanya bila setoran tidak cukup;
/// * pengeluaran terencana: batas atas rentang EKSKLUSIF, `sudahTerjadi` dan
///   baris yang dimatikan tidak ikut dihitung;
/// * keadaan kosong menulis "Belum ada data" (bukan angka nol yang menyesatkan);
/// * bahasa aman pasal III-11 (tanpa kata menghakimi).
///
/// Waktu uji dikunci: "sekarang" = Selasa, 15 September 2026 08.00.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/core/uang/jadwal_kewajiban.dart';
import 'package:personal_life_os/core/uang/strategi_pelunasan.dart';
import 'package:personal_life_os/core/utils/tanggal_utils.dart';
import 'package:personal_life_os/core/utils/uang_utils.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/aset_repository.dart';
import 'package:personal_life_os/data/repository/pembayaran_kewajiban_repository.dart';
import 'package:personal_life_os/data/repository/pengeluaran_terencana_repository.dart';
import 'package:personal_life_os/features/uang/kewajiban/detail_kewajiban_screen.dart';
import 'package:personal_life_os/features/uang/kewajiban/kewajiban_screen.dart';
import 'package:personal_life_os/features/uang/pengeluaran_terencana/pengeluaran_terencana_screen.dart';
import 'package:personal_life_os/features/uang/strategi_pelunasan/strategi_pelunasan_screen.dart';

late AppDatabase db;
late PembayaranKewajibanRepository bayar;
late PengeluaranTerencanaRepository terencana;
late AsetRepository aset;

/// Waktu patok uji: Selasa, 15 September 2026 08.00.
final jamUji = DateTime(2026, 9, 15, 8);

/// Tanggal hari uji (tanpa jam).
final hariUji = DateTime(2026, 9, 15);

/// Kata yang dilarang pasal III-11 (tanpa kata menghakimi/skor).
const List<String> kataTerlarang = [
  'kamu',
  'gagal',
  'skor',
  'malas',
  'pelit',
  'buruk',
  'nilai',
  'berdosa',
  'wajib anda',
];

/// Kewajiban uji; angka dalam sen supaya langsung terbaca.
Future<KewajibanData> kewajiban(
  String nama, {
  int saldoSen = 0,
  int pokokSen = 0,
  double? bunga,
  int? minimumSen,
  int? jatuhTempoHari,
}) =>
    aset.tambahKewajiban(
      nama: nama,
      pokokSen: pokokSen,
      saldoAwalSen: saldoSen,
      sukuBungaPersenTahun: bunga,
      minimumBayarSen: minimumSen,
      tanggalJatuhTempoHari: jatuhTempoHari,
    );

/// Pengeluaran terencana uji.
Future<PengeluaranTerencanaData> rencana(
  String nama, {
  required int jumlahSen,
  required DateTime tanggal,
  bool aktif = true,
  bool sudahTerjadi = false,
}) =>
    terencana
        .tambah(
      nama: nama,
      jumlahSen: jumlahSen,
      tanggal: tanggal,
      aktif: aktif,
    )
        .then((baris) async {
      if (!sudahTerjadi) return baris;
      await terencana.tandaiSudahTerjadi(baris.id);
      return (await terencana.ambilSatu(baris.id))!;
    });

void main() {
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    bayar = PembayaranKewajibanRepository(db, jamSekarang: () => jamUji);
    terencana = PengeluaranTerencanaRepository(db, jamSekarang: () => jamUji);
    aset = AsetRepository(db, jamSekarang: () => jamUji);
  });

  tearDown(() async => db.close());

  // =========================================================================
  // FR-74 — catat pembayaran utang
  // =========================================================================
  group('FR-74 catat pembayaran utang', () {
    test('sisa utang = pokok acuan - bagian pokok yang dibayar; bunga tidak '
        'mengurangi sisa', () async {
      final k = await kewajiban('Kartu kredit',
          saldoSen: rupiahKeSen(10000000), bunga: 24, minimumSen: 500000);
      final p = await bayar.catatPembayaran(
        kewajibanId: k.id,
        tanggal: jamUji,
        jumlahSen: rupiahKeSen(1000000),
        pokokSen: rupiahKeSen(800000),
      );
      expect(p.bungaSen, rupiahKeSen(200000));

      final r = (await bayar.ambilRingkasanSatu(k.id))!;
      expect(r.pokokAcuanSen, rupiahKeSen(10000000));
      expect(r.totalPokokDibayarSen, rupiahKeSen(800000));
      expect(r.totalBungaDibayarSen, rupiahKeSen(200000));
      expect(r.sisaSen, rupiahKeSen(9200000));
      expect(r.totalDibayarSen, rupiahKeSen(1000000));
      expect(r.lunas, isFalse);
    });

    test('pokok acuan memakai saldo awal; bila saldo awal nol memakai pokok',
        () async {
      final a = await kewajiban('Utang A',
          pokokSen: rupiahKeSen(3000000), saldoSen: rupiahKeSen(2500000));
      final b = await kewajiban('Utang B', pokokSen: rupiahKeSen(4000000));
      expect((await bayar.ambilRingkasanSatu(a.id))!.pokokAcuanSen,
          rupiahKeSen(2500000));
      expect((await bayar.ambilRingkasanSatu(b.id))!.pokokAcuanSen,
          rupiahKeSen(4000000));
    });

    test('bagian pokok bawaan = seluruh jumlah bila tidak diisi', () async {
      final k = await kewajiban('Sepeda', saldoSen: rupiahKeSen(2000000));
      final p = await bayar.catatPembayaran(
        kewajibanId: k.id,
        tanggal: jamUji,
        jumlahSen: rupiahKeSen(500000),
      );
      expect(p.pokokSen, rupiahKeSen(500000));
      expect(p.bungaSen, 0);
      expect((await bayar.ambilRingkasanSatu(k.id))!.sisaSen,
          rupiahKeSen(1500000));
    });

    test('bagian pokok kosong dibatasi sisa utang; selebihnya jadi bunga',
        () async {
      final k = await kewajiban('Utang kecil', saldoSen: rupiahKeSen(1000000));
      final p = await bayar.catatPembayaran(
        kewajibanId: k.id,
        tanggal: jamUji,
        jumlahSen: rupiahKeSen(1500000),
      );
      expect(p.pokokSen, rupiahKeSen(1000000));
      expect(p.bungaSen, rupiahKeSen(500000));
      expect((await bayar.ambilRingkasanSatu(k.id))!.sisaSen, 0);
      expect((await bayar.ambilRingkasanSatu(k.id))!.lunas, isTrue);
    });

    test('bagian pokok tidak boleh melebihi sisa utang', () async {
      final k = await kewajiban('Utang kecil', saldoSen: rupiahKeSen(1000000));
      await expectLater(
        bayar.catatPembayaran(
          kewajibanId: k.id,
          tanggal: jamUji,
          jumlahSen: rupiahKeSen(1500000),
          pokokSen: rupiahKeSen(1500000),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await bayar.ambilPembayaran(k.id), isEmpty);
      expect((await bayar.ambilRingkasanSatu(k.id))!.sisaSen,
          rupiahKeSen(1000000));
    });

    test('jumlah pembayaran wajib sama dengan pokok + bunga', () async {
      final k = await kewajiban('Utang D', saldoSen: rupiahKeSen(1000000));
      await expectLater(
        bayar.catatPembayaran(
          kewajibanId: k.id,
          tanggal: jamUji,
          jumlahSen: rupiahKeSen(500000),
          pokokSen: rupiahKeSen(400000),
          bungaSen: rupiahKeSen(50000),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await bayar.ambilPembayaran(k.id), isEmpty);
    });

    test('menolak jumlah nol, jumlah negatif, pokok negatif, dan kewajiban '
        'yang tidak ada', () async {
      final k = await kewajiban('Utang E', saldoSen: rupiahKeSen(1000000));
      await expectLater(
        bayar.catatPembayaran(
            kewajibanId: k.id, tanggal: jamUji, jumlahSen: 0),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        bayar.catatPembayaran(
            kewajibanId: k.id, tanggal: jamUji, jumlahSen: -1000),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        bayar.catatPembayaran(
          kewajibanId: k.id,
          tanggal: jamUji,
          jumlahSen: rupiahKeSen(100000),
          pokokSen: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        bayar.catatPembayaran(
            kewajibanId: 99999, tanggal: jamUji, jumlahSen: rupiahKeSen(1000)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('tanggal pembayaran dinormalkan ke pukul 00:00 dan riwayat urut '
        'terbaru lebih dulu', () async {
      final k = await kewajiban('Kredit motor', saldoSen: rupiahKeSen(6000000));
      await bayar.catatPembayaran(
        kewajibanId: k.id,
        tanggal: DateTime(2026, 9, 3, 21, 45),
        jumlahSen: rupiahKeSen(300000),
      );
      await bayar.catatPembayaran(
        kewajibanId: k.id,
        tanggal: DateTime(2026, 9, 10, 6, 5),
        jumlahSen: rupiahKeSen(200000),
      );
      await bayar.catatPembayaran(
        kewajibanId: k.id,
        tanggal: DateTime(2026, 9, 10, 23, 59),
        jumlahSen: rupiahKeSen(100000),
      );
      final riwayat = await bayar.ambilPembayaran(k.id);
      expect(riwayat.length, 3);
      expect(riwayat.first.tanggal, DateTime(2026, 9, 10));
      expect(riwayat.first.jumlahSen, rupiahKeSen(100000));
      expect(riwayat.last.tanggal, DateTime(2026, 9, 3));
      for (final p in riwayat) {
        expect(p.tanggal.hour, 0);
        expect(p.tanggal.minute, 0);
      }
      final r = (await bayar.ambilRingkasanSatu(k.id))!;
      expect(r.jumlahPembayaran, 3);
      expect(r.terakhirDibayarPada, DateTime(2026, 9, 10));
      expect(r.sisaSen, rupiahKeSen(5400000));
    });

    test('hapus pembayaran mengembalikan sisa utang', () async {
      final k = await kewajiban('Utang F', saldoSen: rupiahKeSen(1000000));
      final p = await bayar.catatPembayaran(
        kewajibanId: k.id,
        tanggal: jamUji,
        jumlahSen: rupiahKeSen(400000),
      );
      expect((await bayar.ambilRingkasanSatu(k.id))!.sisaSen,
          rupiahKeSen(600000));
      await bayar.hapusPembayaran(p.id);
      final r = (await bayar.ambilRingkasanSatu(k.id))!;
      expect(r.sisaSen, rupiahKeSen(1000000));
      expect(r.jumlahPembayaran, 0);
      expect(r.terakhirDibayarPada, isNull);
    });

    test('menandai tuntas bila sisa utang mencapai nol', () async {
      final k = await kewajiban('Utang G', saldoSen: rupiahKeSen(1000000));
      await bayar.catatPembayaran(
        kewajibanId: k.id,
        tanggal: jamUji,
        jumlahSen: rupiahKeSen(1000000),
      );
      final r = (await bayar.ambilRingkasanSatu(k.id))!;
      expect(r.sisaSen, 0);
      expect(r.lunas, isTrue);
      expect(r.bagianPokokTerbayar, 1.0);
    });

    test('hapus kewajiban ikut menghapus seluruh pembayarannya', () async {
      final k = await kewajiban('Utang H', saldoSen: rupiahKeSen(2000000));
      await bayar.catatPembayaran(
          kewajibanId: k.id, tanggal: jamUji, jumlahSen: rupiahKeSen(100000));
      await bayar.catatPembayaran(
          kewajibanId: k.id, tanggal: jamUji, jumlahSen: rupiahKeSen(200000));
      expect(await bayar.ambilPembayaran(k.id), hasLength(2));

      await bayar.hapusKewajiban(k.id);

      expect(await bayar.ambilKewajibanSatu(k.id), isNull);
      expect(await db.select(db.pembayaranKewajiban).get(), isEmpty);
      expect(await bayar.ambilRingkasan(), isEmpty);
    });

    test('total sisa utang hanya menjumlahkan kewajiban aktif', () async {
      final a = await kewajiban('Utang I', saldoSen: rupiahKeSen(1000000));
      final b = await kewajiban('Utang J', saldoSen: rupiahKeSen(2500000));
      expect(await bayar.totalSisaSen(), rupiahKeSen(3500000));
      await aset.ubahKewajiban(a.id, arsip: true);
      expect(await bayar.totalSisaSen(), rupiahKeSen(2500000));
      expect(await bayar.totalSisaSen(sertakanArsip: true),
          rupiahKeSen(3500000));
      expect((await bayar.ambilRingkasan()).single.kewajiban.id, b.id);
    });
  });

  // =========================================================================
  // FR-74 — prioritas & jadwal pembayaran
  // =========================================================================
  group('FR-74 jadwal pembayaran kewajiban', () {
    test('jatuh tempo berikutnya: hari ini tetap hari ini, lewat hari ini '
        'pindah bulan depan', () {
      expect(
        jatuhTempoBerikutnya(hariJatuhTempo: 15, sejak: jamUji),
        DateTime(2026, 9, 15),
      );
      expect(
        jatuhTempoBerikutnya(hariJatuhTempo: 20, sejak: jamUji),
        DateTime(2026, 9, 20),
      );
      expect(
        jatuhTempoBerikutnya(hariJatuhTempo: 10, sejak: jamUji),
        DateTime(2026, 10, 10),
      );
      expect(
        jatuhTempoBerikutnya(hariJatuhTempo: 10, sejak: DateTime(2026, 12, 20)),
        DateTime(2027, 1, 10),
      );
    });

    test('tanggal 31 dipindahkan ke hari terakhir bulan yang lebih pendek', () {
      expect(tanggalJatuhTempoBulan(2026, 2, 31), DateTime(2026, 2, 28));
      expect(tanggalJatuhTempoBulan(2026, 4, 31), DateTime(2026, 4, 30));
      expect(tanggalJatuhTempoBulan(2028, 2, 31), DateTime(2028, 2, 29));
      expect(jumlahHariBulan(2026, 9), 30);
    });

    test('jadwal kosong bila tanggal jatuh tempo belum diisi atau di luar 1-31',
        () {
      expect(jatuhTempoBerikutnya(hariJatuhTempo: null, sejak: jamUji), isNull);
      expect(jatuhTempoBerikutnya(hariJatuhTempo: 0, sejak: jamUji), isNull);
      expect(jatuhTempoBerikutnya(hariJatuhTempo: 32, sejak: jamUji), isNull);
      expect(selisihHariTanggal(jamUji, DateTime(2026, 9, 20, 23, 30)), 5);
    });

    test('kalimat jatuh tempo tenang dan tanpa penilaian', () {
      expect(
        kalimatJatuhTempo(
            hariJatuhTempo: null, sekarang: jamUji, formatTanggal: fmtTanggalAman),
        'Tanggal jatuh tempo belum diisi',
      );
      expect(
        kalimatJatuhTempo(
            hariJatuhTempo: 15, sekarang: jamUji, formatTanggal: fmtTanggalAman),
        'Jatuh tempo 15 September 2026 (hari ini)',
      );
      expect(
        kalimatJatuhTempo(
            hariJatuhTempo: 20, sekarang: jamUji, formatTanggal: fmtTanggalAman),
        'Jatuh tempo 20 September 2026 (5 hari lagi)',
      );
    });

    test('urutan jadwal terdekat: yang belum diisi paling akhir, daftar asal '
        'tidak berubah', () {
      final daftar = [
        const JadwalKewajiban(
            id: 1, nama: 'Jauh', tanggalJatuhTempoHari: 28, sisaSen: 100),
        const JadwalKewajiban(
            id: 2, nama: 'Kosong', tanggalJatuhTempoHari: null, sisaSen: 200),
        const JadwalKewajiban(
            id: 3, nama: 'Dekat', tanggalJatuhTempoHari: 16, sisaSen: 300),
      ];
      final urut = urutJadwalTerdekat(daftar, jamUji);
      expect(urut.map((j) => j.id).toList(), [3, 1, 2]);
      expect(daftar.map((j) => j.id).toList(), [1, 2, 3]);
    });
  });

  // =========================================================================
  // FR-75 — strategi pelunasan (mesin simulasi, pure Dart)
  // =========================================================================
  group('FR-75 simulasi strategi pelunasan', () {
    const a = KewajibanRingkas(id: 1, nama: 'A', sisaSen: 800000);
    const b = KewajibanRingkas(id: 2, nama: 'B', sisaSen: 500000);
    const c = KewajibanRingkas(id: 3, nama: 'C', sisaSen: 1700000);

    test('bunga bulanan = sisa x persen / 1200 dibulatkan', () {
      expect(bungaBulanSen(1000000, 12), 10000);
      expect(bungaBulanSen(1000000, 0), 0);
      expect(bungaBulanSen(0, 24), 0);
      expect(bungaBulanSen(150000, 36), 4500);
    });

    test('bola salju = sisa terkecil dulu; longsor = bunga tertinggi dulu',
        () {
      const c1 = KewajibanRingkas(
          id: 7, nama: 'Besar bunga kecil', sisaSen: 900000, bungaPersenTahun: 6);
      const c2 = KewajibanRingkas(
          id: 8, nama: 'Besar bunga besar', sisaSen: 900000, bungaPersenTahun: 24);
      const c3 = KewajibanRingkas(id: 9, nama: 'Kecil', sisaSen: 100000);

      expect(
        urutkanPelunasan([c1, c2, c3], MetodePelunasan.bolaSalju)
            .map((k) => k.nama)
            .toList(),
        ['Kecil', 'Besar bunga besar', 'Besar bunga kecil'],
      );
      expect(
        urutkanPelunasan([c3, c2, c1], MetodePelunasan.longsor)
            .map((k) => k.nama)
            .toList(),
        ['Besar bunga besar', 'Besar bunga kecil', 'Kecil'],
      );
      expect(
        urutkanPelunasan([a, b], MetodePelunasan.bolaSalju).map((k) => k.id),
        [2, 1],
      );
    });

    test('urutan pelunasan tidak mengubah daftar masukan', () {
      final asal = [a, b, c];
      urutkanPelunasan(asal, MetodePelunasan.longsor);
      expect(asal.map((k) => k.id).toList(), [1, 2, 3]);
    });

    test('satu utang tanpa bunga: 10 bulan, tanpa bunga, semua terbayar',
        () async {
      const u = KewajibanRingkas(id: 1, nama: 'Tanpa bunga', sisaSen: 1000000);
      final h = simulasiPelunasan(
        kewajiban: const [u],
        setoranBulananSen: 100000,
      );
      expect(h.jumlahBulan, 10);
      expect(h.totalBungaSen, 0);
      expect(h.totalDibayarSen, 1000000);
      expect(h.sisaAkhirSen, 0);
      expect(h.lunasSemua, isTrue);
      expect(h.langkah.single.sudahTuntas, isTrue);
      expect(h.langkah.single.bulanKe, 10);
    });

    test('satu utang berbunga 12 persen setahun, setoran besar: tuntas satu '
        'bulan dengan bunga 10.000 sen', () {
      const u = KewajibanRingkas(
          id: 1, nama: 'Berbunga', sisaSen: 1000000, bungaPersenTahun: 12);
      final h = simulasiPelunasan(
        kewajiban: const [u],
        setoranBulananSen: 2000000,
      );
      expect(h.jumlahBulan, 1);
      expect(h.totalBungaSen, 10000);
      expect(h.totalDibayarSen, 1010000);
      expect(h.sisaAkhirSen, 0);
      expect(h.lunasSemua, isTrue);
    });

    test('tiga utang tanpa bunga, bola salju: tuntas berurutan bulan 1, 2, 3',
        () {
      final h = simulasiPelunasan(
        kewajiban: const [a, b, c],
        setoranBulananSen: 1000000,
      );
      expect(h.urutan.map((k) => k.id).toList(), [2, 1, 3]);
      expect(h.jumlahBulan, 3);
      expect(h.totalBungaSen, 0);
      expect(h.totalDibayarSen, 3000000);
      expect(h.lunasSemua, isTrue);
      expect(h.langkah.map((l) => l.kewajibanId).toList(), [2, 1, 3]);
      expect(h.langkah.map((l) => l.bulanKe).toList(), [1, 2, 3]);
      expect(h.jumlahTuntas, 3);
    });

    test('minimum bayar dibayar lebih dulu dari setoran ekstra', () {
      const besar = KewajibanRingkas(
          id: 1, nama: 'Minimum besar', sisaSen: 1000000, minimumBayarSen: 500000);
      const kecil = KewajibanRingkas(
          id: 2, nama: 'Tanpa minimum', sisaSen: 100000);
      final h = simulasiPelunasan(
        kewajiban: const [besar, kecil],
        setoranBulananSen: 600000,
      );
      expect(h.jumlahBulan, 2);
      expect(h.langkah.firstWhere((l) => l.kewajibanId == 2).bulanKe, 1);
      expect(h.langkah.firstWhere((l) => l.kewajibanId == 1).bulanKe, 2);
      expect(h.totalDibayarSen, 1100000);
      expect(h.lunasSemua, isTrue);
    });

    test('berhenti apa adanya bila setoran tidak menutup bunga', () {
      const u = KewajibanRingkas(
          id: 1, nama: 'Bunga tinggi', sisaSen: 1000000, bungaPersenTahun: 100);
      final h = simulasiPelunasan(
        kewajiban: const [u],
        setoranBulananSen: 10000,
        batasBulan: 12,
      );
      expect(h.jumlahBulan, 12);
      expect(h.lunasSemua, isFalse);
      expect(h.jumlahTuntas, 0);
      expect(h.sisaAkhirSen, greaterThan(1000000));
      expect(h.totalBungaSen, greaterThan(0));
    });

    test('setoran nol, setoran negatif, dan batas bulan nol ditolak', () {
      expect(
        () => simulasiPelunasan(kewajiban: const [a], setoranBulananSen: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => simulasiPelunasan(kewajiban: const [a], setoranBulananSen: -5000),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => simulasiPelunasan(
            kewajiban: const [a], setoranBulananSen: 100000, batasBulan: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('daftar kosong: nol bulan, tanpa sisa, dianggap tuntas', () {
      final h = simulasiPelunasan(kewajiban: const [], setoranBulananSen: 50000);
      expect(h.jumlahBulan, 0);
      expect(h.jumlahKewajiban, 0);
      expect(h.totalDibayarSen, 0);
      expect(h.totalBungaSen, 0);
      expect(h.sisaAkhirSen, 0);
      expect(h.lunasSemua, isTrue);
    });

    test('uang kekal: total dibayar + sisa akhir = sisa awal + total bunga',
        () {
      const campuran = [
        KewajibanRingkas(
            id: 1, nama: 'Satu', sisaSen: 800000, bungaPersenTahun: 18, minimumBayarSen: 200000),
        KewajibanRingkas(
            id: 2, nama: 'Dua', sisaSen: 500000, bungaPersenTahun: 6),
        KewajibanRingkas(
            id: 3, nama: 'Tiga', sisaSen: 1700000, bungaPersenTahun: 30, minimumBayarSen: 300000),
      ];
      for (final metode in MetodePelunasan.values) {
        final h = simulasiPelunasan(
          kewajiban: campuran,
          setoranBulananSen: 700000,
          metode: metode,
          batasBulan: 24,
        );
        final sisaAwal = campuran.fold<int>(0, (s, k) => s + k.sisaSen);
        expect(h.totalDibayarSen + h.sisaAkhirSen,
            sisaAwal + h.totalBungaSen,
            reason: 'metode ${metode.label}');
      }
    });

    test('utang yang sudah nol sisa dianggap tuntas sebelum bulan pertama', () {
      const nol = KewajibanRingkas(id: 1, nama: 'Sudah nol', sisaSen: 0);
      final h = simulasiPelunasan(kewajiban: const [nol], setoranBulananSen: 50000);
      expect(h.jumlahBulan, 0);
      expect(h.lunasSemua, isTrue);
      expect(h.langkah.single.bulanKe, 0);
      expect(h.langkah.single.sudahTuntas, isTrue);
      expect(h.totalDibayarSen, 0);
    });
  });

  // =========================================================================
  // pengeluaran terencana (tambahan)
  // =========================================================================
  group('pengeluaran terencana (tambahan)', () {
    test('tambah: tanggal dinormalkan ke 00:00 dan daftar urut tanggal', () async {
      final c = await rencana('Liburan',
          jumlahSen: rupiahKeSen(2000000), tanggal: DateTime(2026, 10, 1, 7, 30));
      final a = await rencana('Servis motor',
          jumlahSen: rupiahKeSen(400000), tanggal: DateTime(2026, 9, 10));
      final b = await rencana('Pajak motor',
          jumlahSen: rupiahKeSen(300000), tanggal: DateTime(2026, 9, 20));

      expect(c.tanggal, DateTime(2026, 10, 1));
      expect((await terencana.ambilSemua()).map((r) => r.id).toList(),
          [a.id, b.id, c.id]);
    });

    test('menolak nama kosong dan jumlah nol atau negatif', () async {
      await expectLater(
        terencana.tambah(nama: '   ', jumlahSen: 1000, tanggal: jamUji),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        terencana.tambah(nama: 'X', jumlahSen: 0, tanggal: jamUji),
        throwsA(isA<ArgumentError>()),
      );
      // `ubah` memeriksa lebih dulu lalu melempar langsung (bukan lewat
      // Future), jadi pemanggilannya dibungkus closure.
      expect(() => terencana.ubah(1, nama: '  '),
          throwsA(isA<ArgumentError>()));
      expect(() => terencana.ubah(1, jumlahSen: -5),
          throwsA(isA<ArgumentError>()));
      expect(await terencana.ambilSemua(), isEmpty);
    });

    test('perlu disiapkan: batas atas eksklusif, baris tepat di batas tidak '
        'dihitung', () async {
      final baris = await rencana('Tepat batas',
          jumlahSen: 1000, tanggal: DateTime(2026, 9, 22));
      expect(perluDisiapkan(baris, DateTime(2026, 9, 22)), isFalse);
      expect(perluDisiapkan(baris, DateTime(2026, 9, 23)), isTrue);
      expect(perluDisiapkan(baris, DateTime(2026, 9, 22, 23, 59)), isFalse);
    });

    test('baris yang sudah terjadi atau dimatikan tidak dihitung, tanggal '
        'lewat tetap dihitung', () async {
      final lewat = await rencana('Sudah lewat',
          jumlahSen: rupiahKeSen(400000), tanggal: DateTime(2026, 9, 10));
      final sudah = await rencana('Sudah dibayar',
          jumlahSen: rupiahKeSen(500000),
          tanggal: DateTime(2026, 9, 12),
          sudahTerjadi: true);
      final mati = await rencana('Dimatikan',
          jumlahSen: rupiahKeSen(600000),
          tanggal: DateTime(2026, 9, 14),
          aktif: false);

      final r = terencana.ringkasanDari(
          await terencana.ambilSemua(), DateTime(2026, 9, 16));
      expect(r.totalSen, rupiahKeSen(400000));
      expect(r.jumlahBaris, 1);
      expect(r.jumlahTerlewat, 1);
      expect(r.kosong, isFalse);

      await terencana.setAktif(mati.id, aktif: true);
      final r2 = terencana.ringkasanDari(
          await terencana.ambilSemua(), DateTime(2026, 9, 16));
      expect(r2.totalSen, rupiahKeSen(1000000));
      expect(r2.jumlahBaris, 2);
      expect(sudah.sudahTerjadi, isTrue);
      expect(lewat.id, isNot(mati.id));
    });

    test('ringkasanSampai memakai batas tanggal + 1 hari', () async {
      await rencana('Hari ini',
          jumlahSen: rupiahKeSen(100000), tanggal: hariUji);
      await rencana('Besok',
          jumlahSen: rupiahKeSen(200000), tanggal: DateTime(2026, 9, 16));
      await rencana('Lusa',
          jumlahSen: rupiahKeSen(400000), tanggal: DateTime(2026, 9, 17));

      final hariIni = await terencana.ringkasanSampai(hariUji);
      expect(hariIni.totalSen, rupiahKeSen(100000));
      expect(hariIni.jumlahBaris, 1);
      expect(hariIni.batasEksklusif, DateTime(2026, 9, 16));

      final duaHari = await terencana.ringkasanSampai(DateTime(2026, 9, 16, 21));
      expect(duaHari.totalSen, rupiahKeSen(300000));
      expect(duaHari.jumlahBaris, 2);
      expect(duaHari.jumlahTerlewat, 0);
    });

    test('ubah, tandai sudah terjadi, kembalikan, dan hapus', () async {
      final baris = await rencana('Servis motor',
          jumlahSen: rupiahKeSen(400000), tanggal: DateTime(2026, 9, 20));

      await terencana.ubah(baris.id,
          nama: 'Servis motor besar', jumlahSen: rupiahKeSen(450000));
      var ulang = (await terencana.ambilSatu(baris.id))!;
      expect(ulang.nama, 'Servis motor besar');
      expect(ulang.jumlahSen, rupiahKeSen(450000));

      await terencana.tandaiSudahTerjadi(baris.id);
      ulang = (await terencana.ambilSatu(baris.id))!;
      expect(ulang.sudahTerjadi, isTrue);

      await terencana.tandaiSudahTerjadi(baris.id, sudahTerjadi: false);
      ulang = (await terencana.ambilSatu(baris.id))!;
      expect(ulang.sudahTerjadi, isFalse);

      await terencana.hapus(baris.id);
      expect(await terencana.ambilSatu(baris.id), isNull);
      expect(await terencana.ambilSemua(), isEmpty);
    });

    test('tanpa data: ringkasan kosong, bukan angka nol yang menyesatkan',
        () async {
      final r = await terencana.ringkasanSampai(hariUji);
      expect(r.kosong, isTrue);
      expect(r.totalSen, 0);
      expect(r.jumlahBaris, 0);
      expect(r.jumlahTerlewat, 0);
    });
  });

  // =========================================================================
  // Layar
  // =========================================================================
  group('layar kewajiban (FR-74)', () {
    /// Menampilkan layar daftar kewajiban dengan jam uji 15 Sep 2026.
    Future<void> tampilkan(WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: KewajibanScreen(jamSekarang: () => jamUji),
        ),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
    }

    /// Menampilkan detail kewajiban di atas satu halaman pembuka (supaya
    /// tombol "kembali" punya tempat mendarat).
    Future<void> tampilkanDetail(WidgetTester t, int id) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: Builder(
            builder: (c) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const Key('buka_detail'),
                  onPressed: () => Navigator.of(c).push(MaterialPageRoute(
                    builder: (_) => DetailKewajibanScreen(
                      kewajibanId: id,
                      jamSekarang: () => jamUji,
                    ),
                  )),
                  child: const Text('buka detail'),
                ),
              ),
            ),
          ),
        ),
      ));
      await t.pump();
      await t.tap(find.byKey(const Key('buka_detail')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
    }

    /// Isi teks sebuah widget ber-Kunci (harus tepat satu).
    String teksKunci(WidgetTester t, String kunci) =>
        t.widget<Text>(find.byKey(Key(kunci))).data ?? '';

    Future<void> tutup(WidgetTester t) async {
      await t.pump(const Duration(seconds: 5));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.binding.setSurfaceSize(null);
    }

    Future<void> gulirKe(WidgetTester t, Finder target, {int maks = 8}) async {
      for (var i = 0; i < maks; i++) {
        if (target.evaluate().isNotEmpty) return;
        await t.drag(find.byType(Scrollable).first, const Offset(0, -200));
        await t.pump(const Duration(milliseconds: 120));
      }
    }

    Future<void> tekan(WidgetTester t, Finder target) async {
      await t.ensureVisible(target);
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(target);
      await t.pump(const Duration(milliseconds: 150));
    }

    testWidgets('daftar menampilkan total sisa utang, sisa per kewajiban, dan '
        'jadwal berikutnya', (t) async {
      final kartu = await kewajiban('Kartu kredit',
          saldoSen: rupiahKeSen(5000000), jatuhTempoHari: 20);
      await kewajiban('KPR rumah',
          saldoSen: rupiahKeSen(10000000), minimumSen: rupiahKeSen(1500000));
      await bayar.catatPembayaran(
        kewajibanId: kartu.id,
        tanggal: DateTime(2026, 9, 5),
        jumlahSen: rupiahKeSen(1000000),
      );

      await tampilkan(t);

      expect(teksKunci(t, 'total_sisa_utang'), 'Rp 14.000.000');
      await gulirKe(t, find.byKey(Key('sisa_utang_${kartu.id}')));
      expect(teksKunci(t, 'sisa_utang_${kartu.id}'), 'Rp 4.000.000');
      expect(find.textContaining('Jatuh tempo 20 September 2026'), findsOneWidget);
      expect(find.textContaining('5 hari lagi'), findsOneWidget);
      expect(find.textContaining('Minimum bayar Rp 1.500.000'), findsOneWidget);

      await tutup(t);
    });

    testWidgets('tanpa kewajiban: menulis "Belum ada data", bukan Rp 0',
        (t) async {
      await tampilkan(t);

      expect(teksKunci(t, 'total_sisa_utang'), 'Belum ada data');
      expect(find.byKey(const Key('kosong_kewajiban')), findsOneWidget);
      expect(find.text('Rp 0'), findsNothing);

      await tutup(t);
    });

    testWidgets('catat pembayaran dari detail mengurangi sisa utang dan '
        'menambah riwayat', (t) async {
      final k = await kewajiban('Kartu kredit', saldoSen: rupiahKeSen(10000000));
      await tampilkanDetail(t, k.id);

      expect(teksKunci(t, 'angka_sisa_utang'), 'Rp 10.000.000');
      expect(find.byKey(const Key('kosong_riwayat')), findsOneWidget);

      await tekan(t, find.byKey(const Key('catat_pembayaran')));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('jumlah_pembayaran')), findsOneWidget);

      await t.enterText(find.byKey(const Key('jumlah_pembayaran')), '1000000');
      await t.enterText(find.byKey(const Key('pokok_pembayaran')), '800000');
      await tekan(t, find.byKey(const Key('simpan_pembayaran')));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));

      expect(teksKunci(t, 'angka_sisa_utang'), 'Rp 9.200.000');
      expect(find.byKey(const Key('kosong_riwayat')), findsNothing);
      expect(find.textContaining('pokok Rp 800.000'), findsOneWidget);
      expect(find.textContaining('bunga Rp 200.000'), findsOneWidget);

      // Angka yang sama harus terbaca di basis data.
      final r = (await bayar.ambilRingkasanSatu(k.id))!;
      expect(r.sisaSen, rupiahKeSen(9200000));
      expect(r.totalBungaDibayarSen, rupiahKeSen(200000));

      await tutup(t);
    });

    testWidgets('form pembayaran menolak bagian pokok yang melebihi sisa '
        'utang', (t) async {
      final k = await kewajiban('Utang kecil', saldoSen: rupiahKeSen(500000));
      await tampilkanDetail(t, k.id);
      await tekan(t, find.byKey(const Key('catat_pembayaran')));
      await t.pump(const Duration(milliseconds: 400));

      await t.enterText(find.byKey(const Key('jumlah_pembayaran')), '1000000');
      await t.enterText(find.byKey(const Key('pokok_pembayaran')), '1000000');
      await tekan(t, find.byKey(const Key('simpan_pembayaran')));
      await t.pump(const Duration(milliseconds: 400));

      expect(find.text('Bagian pokok melebihi sisa utang'), findsOneWidget);
      expect(await bayar.ambilPembayaran(k.id), isEmpty);

      await tutup(t);
    });

    testWidgets('hapus pembayaran: batal tidak mengubah apa pun, konfirmasi '
        'mengembalikan sisa utang', (t) async {
      final k = await kewajiban('Kredit motor', saldoSen: rupiahKeSen(6000000));
      final p = await bayar.catatPembayaran(
        kewajibanId: k.id,
        tanggal: DateTime(2026, 9, 8),
        jumlahSen: rupiahKeSen(1000000),
      );
      await tampilkanDetail(t, k.id);
      expect(teksKunci(t, 'angka_sisa_utang'), 'Rp 5.000.000');

      await gulirKe(t, find.byKey(Key('hapus_pembayaran_${p.id}')));
      await tekan(t, find.byKey(Key('hapus_pembayaran_${p.id}')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('dialog_hapus_pembayaran')), findsOneWidget);
      await tekan(t, find.text('Batal'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(Key('pembayaran_${p.id}')), findsOneWidget);
      expect(await bayar.ambilPembayaran(k.id), hasLength(1));

      await tekan(t, find.byKey(Key('hapus_pembayaran_${p.id}')));
      await t.pump(const Duration(milliseconds: 300));
      await tekan(t, find.byKey(const Key('konfirmasi_hapus_pembayaran')));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));

      expect(find.byKey(Key('pembayaran_${p.id}')), findsNothing);
      expect(teksKunci(t, 'angka_sisa_utang'), 'Rp 6.000.000');
      expect(await bayar.ambilPembayaran(k.id), isEmpty);

      await tutup(t);
    });

    testWidgets('hapus kewajiban dari detail ikut menghapus pembayarannya',
        (t) async {
      final k = await kewajiban('Utang lama', saldoSen: rupiahKeSen(2000000));
      await bayar.catatPembayaran(
        kewajibanId: k.id,
        tanggal: DateTime(2026, 9, 8),
        jumlahSen: rupiahKeSen(500000),
      );
      await tampilkanDetail(t, k.id);

      await gulirKe(t, find.byKey(const Key('hapus_kewajiban')));
      await tekan(t, find.byKey(const Key('hapus_kewajiban')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('dialog_hapus_kewajiban')), findsOneWidget);
      await tekan(t, find.byKey(const Key('konfirmasi_hapus_kewajiban')));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('buka_detail')), findsOneWidget);
      expect(await bayar.ambilKewajibanSatu(k.id), isNull);
      expect(await db.select(db.pembayaranKewajiban).get(), isEmpty);
      expect(await bayar.ambilRingkasan(), isEmpty);

      await tutup(t);
    });
  });

  group('layar pengeluaran terencana (tambahan)', () {
    Future<void> tampilkan(WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: PengeluaranTerencanaScreen(jamSekarang: () => jamUji),
        ),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
    }

    String teksKunci(WidgetTester t, String kunci) =>
        t.widget<Text>(find.byKey(Key(kunci))).data ?? '';

    Future<void> tutup(WidgetTester t) async {
      await t.pump(const Duration(seconds: 5));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.binding.setSurfaceSize(null);
    }

    Future<void> gulirKe(WidgetTester t, Finder target, {int maks = 8}) async {
      for (var i = 0; i < maks; i++) {
        if (target.evaluate().isNotEmpty) return;
        await t.drag(find.byType(Scrollable).first, const Offset(0, -200));
        await t.pump(const Duration(milliseconds: 120));
      }
    }

    Future<void> tekan(WidgetTester t, Finder target) async {
      await t.ensureVisible(target);
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(target);
      await t.pump(const Duration(milliseconds: 150));
    }

    /// Buka menu tiga titik satu baris lalu pilih salah satu judulnya.
    Future<void> pilihMenu(WidgetTester t, int id, String judul) async {
      await gulirKe(t, find.byKey(Key('menu_pengeluaran_$id')));
      await tekan(t, find.byKey(Key('menu_pengeluaran_$id')));
      await t.pump(const Duration(milliseconds: 300));
      await tekan(t, find.text(judul).last);
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
    }

    testWidgets('total persiapan mengikuti tanggal batas yang dipilih',
        (t) async {
      await rencana('Servis motor',
          jumlahSen: rupiahKeSen(4000), tanggal: DateTime(2026, 9, 10));
      await rencana('Pajak motor',
          jumlahSen: rupiahKeSen(1000), tanggal: DateTime(2026, 9, 18));
      await rencana('Liburan',
          jumlahSen: rupiahKeSen(2000), tanggal: DateTime(2026, 9, 30));
      await rencana('Sudah dibayar',
          jumlahSen: rupiahKeSen(500),
          tanggal: DateTime(2026, 9, 1),
          sudahTerjadi: true);

      await tampilkan(t);

      expect(teksKunci(t, 'total_persiapan'), 'Rp 4.000');
      expect(find.textContaining('Sampai 15 September 2026'), findsOneWidget);
      expect(find.textContaining('1 pengeluaran belum terjadi'), findsOneWidget);
      expect(find.textContaining('1 tanggalnya sudah lewat'), findsOneWidget);

      await tekan(t, find.byKey(const Key('batas_7_hari')));
      await t.pump(const Duration(milliseconds: 200));
      expect(teksKunci(t, 'total_persiapan'), 'Rp 5.000');
      expect(find.textContaining('Sampai 22 September 2026'), findsOneWidget);

      await tekan(t, find.byKey(const Key('batas_30_hari')));
      await t.pump(const Duration(milliseconds: 200));
      expect(teksKunci(t, 'total_persiapan'), 'Rp 7.000');
      expect(find.textContaining('3 pengeluaran belum terjadi'), findsOneWidget);

      await tekan(t, find.byKey(const Key('batas_hari_ini')));
      await t.pump(const Duration(milliseconds: 200));
      expect(teksKunci(t, 'total_persiapan'), 'Rp 4.000');

      await tutup(t);
    });

    testWidgets('menandai sudah terjadi dan menghapus mengubah total',
        (t) async {
      await rencana('Servis motor',
          jumlahSen: rupiahKeSen(4000), tanggal: DateTime(2026, 9, 10));
      final pajak = await rencana('Pajak motor',
          jumlahSen: rupiahKeSen(1000), tanggal: DateTime(2026, 9, 18));
      await rencana('Liburan',
          jumlahSen: rupiahKeSen(2000), tanggal: DateTime(2026, 9, 30));

      await tampilkan(t);
      await tekan(t, find.byKey(const Key('batas_30_hari')));
      await t.pump(const Duration(milliseconds: 200));
      expect(teksKunci(t, 'total_persiapan'), 'Rp 7.000');

      await pilihMenu(t, pajak.id, 'Tandai sudah terjadi');
      expect(teksKunci(t, 'total_persiapan'), 'Rp 6.000');
      expect(find.textContaining('2 pengeluaran belum terjadi'), findsOneWidget);

      await pilihMenu(t, pajak.id, 'Kembalikan ke rencana');
      expect(teksKunci(t, 'total_persiapan'), 'Rp 7.000');

      await pilihMenu(t, pajak.id, 'Hapus');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('dialog_hapus_pengeluaran')), findsOneWidget);
      await tekan(t, find.byKey(const Key('konfirmasi_hapus_pengeluaran')));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));

      expect(teksKunci(t, 'total_persiapan'), 'Rp 6.000');
      expect(await terencana.ambilSatu(pajak.id), isNull);

      await tutup(t);
    });

    testWidgets('menambah pengeluaran lewat form tampil di daftar dan masuk '
        'hitungan', (t) async {
      await rencana('Servis motor',
          jumlahSen: rupiahKeSen(4000), tanggal: DateTime(2026, 9, 10));
      await tampilkan(t);
      expect(teksKunci(t, 'total_persiapan'), 'Rp 4.000');

      await tekan(t, find.byKey(const Key('tambah_pengeluaran')));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('nama_pengeluaran')), findsOneWidget);

      await t.enterText(find.byKey(const Key('nama_pengeluaran')), 'Servis baru');
      await t.enterText(
          find.byKey(const Key('jumlah_pengeluaran')), '1500000');
      await tekan(t, find.byKey(const Key('simpan_pengeluaran')));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));

      // Tanggal bawaan form = hari ini, jadi ikut hitungan batas hari ini.
      expect(teksKunci(t, 'total_persiapan'), 'Rp 1.504.000');
      await gulirKe(t, find.text('Servis baru'));
      expect(find.text('Servis baru'), findsOneWidget);
      expect(await terencana.ambilSemua(), hasLength(2));

      await tutup(t);
    });

    testWidgets('tanpa data: menulis "Belum ada data"', (t) async {
      await tampilkan(t);

      expect(teksKunci(t, 'total_persiapan'), 'Belum ada data');
      expect(find.byKey(const Key('kosong_pengeluaran')), findsOneWidget);

      await tutup(t);
    });
  });

  group('layar strategi pelunasan (FR-75)', () {
    Future<void> tampilkan(WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: StrategiPelunasanScreen(jamSekarang: () => jamUji),
        ),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
    }

    String teksKunci(WidgetTester t, String kunci) =>
        t.widget<Text>(find.byKey(Key(kunci))).data ?? '';

    Future<void> tutup(WidgetTester t) async {
      await t.pump(const Duration(seconds: 5));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.binding.setSurfaceSize(null);
    }

    Future<void> tekan(WidgetTester t, Finder target) async {
      await t.ensureVisible(target);
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(target);
      await t.pump(const Duration(milliseconds: 150));
    }

    testWidgets('menghitung simulasi bola salju lalu longsor', (t) async {
      final kartu = await kewajiban('Utang kartu',
          saldoSen: rupiahKeSen(200000), bunga: 24);
      final motor = await kewajiban('Kredit motor',
          saldoSen: rupiahKeSen(1000000), bunga: 6);

      await tampilkan(t);
      expect(find.byKey(const Key('belum_dihitung')), findsOneWidget);

      await t.enterText(find.byKey(const Key('setoran_bulanan')), '400000');
      await tekan(t, find.byKey(const Key('hitung_simulasi')));
      await t.pump(const Duration(milliseconds: 400));

      final harapan = simulasiPelunasan(
        kewajiban: [
          KewajibanRingkas(
              id: kartu.id, nama: kartu.nama, sisaSen: rupiahKeSen(200000),
              bungaPersenTahun: 24),
          KewajibanRingkas(
              id: motor.id, nama: motor.nama, sisaSen: rupiahKeSen(1000000),
              bungaPersenTahun: 6),
        ],
        setoranBulananSen: rupiahKeSen(400000),
        metode: MetodePelunasan.bolaSalju,
      );
      expect(find.byKey(const Key('belum_dihitung')), findsNothing);
      expect(teksKunci(t, 'jumlah_bulan'),
          contains('Tuntas dalam ${harapan.jumlahBulan} bulan'));
      expect(find.textContaining('Total bunga '), findsOneWidget);
      expect(teksKunci(t, 'urutan_${kartu.id}').startsWith('1.'), isTrue);

      // Ganti ke longsor: utang berbunga tertinggi jadi nomor satu.
      await tekan(t, find.byKey(const Key('metode_pelunasan')));
      await t.pump(const Duration(milliseconds: 400));
      await tekan(t, find.textContaining('Longsor').last);
      await t.pump(const Duration(milliseconds: 400));
      await tekan(t, find.byKey(const Key('hitung_simulasi')));
      await t.pump(const Duration(milliseconds: 400));

      expect(teksKunci(t, 'urutan_${kartu.id}').startsWith('1.'), isTrue);
      expect(teksKunci(t, 'urutan_${motor.id}').startsWith('2.'), isTrue);
      expect(find.byKey(const Key('hasil_simulasi')), findsOneWidget);
      expect(find.textContaining('bukan nasihat keuangan'), findsOneWidget);
      expect(find.byKey(const Key('catatan_simulasi')), findsOneWidget);

      await tutup(t);
    });

    testWidgets('tanpa kewajiban: tombol hitung mati dan layar jujur',
        (t) async {
      await tampilkan(t);

      expect(find.byKey(const Key('kosong_kewajiban')), findsOneWidget);
      expect(find.textContaining('Belum ada data'), findsWidgets);
      final tombol = t.widget<FilledButton>(find.byWidgetPredicate(
          (w) => w is FilledButton && w.key == const Key('hitung_simulasi')));
      expect(tombol.onPressed, isNull);

      await tutup(t);
    });
  });

  // =========================================================================
  // Bahasa aman (PRD III-11)
  // =========================================================================
  group('bahasa aman di layar uang lanjutan', () {
    List<String> langgar(WidgetTester t) {
      final pelanggaran = <String>[];
      for (final w in t.widgetList<Text>(find.byType(Text))) {
        final teks = (w.data ?? '').toLowerCase();
        if (teks.isEmpty) continue;
        for (final kata in kataTerlarang) {
          if (teks.contains(kata)) pelanggaran.add('$kata -> ${w.data}');
        }
      }
      return pelanggaran;
    }

    testWidgets('daftar kewajiban, pengeluaran terencana, dan strategi '
        'pelunasan bebas kata menghakimi', (t) async {
      await kewajiban('Kartu kredit', saldoSen: rupiahKeSen(1000000));
      await rencana('Servis motor',
          jumlahSen: rupiahKeSen(4000), tanggal: DateTime(2026, 9, 10));

      await t.binding.setSurfaceSize(const Size(420, 900));
      for (final layar in [
        KewajibanScreen(jamSekarang: () => jamUji),
        PengeluaranTerencanaScreen(jamSekarang: () => jamUji),
        StrategiPelunasanScreen(jamSekarang: () => jamUji),
      ]) {
        await t.pumpWidget(ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(theme: AppTema.terang(), home: layar),
        ));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await t.pump(const Duration(milliseconds: 400));
        expect(langgar(t), isEmpty, reason: '${layar.runtimeType}');
      }

      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.binding.setSurfaceSize(null);
    });
  });
}
