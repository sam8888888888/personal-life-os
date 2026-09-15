/// Uji FR-28 — Grafik sederhana beban tagihan per bulan (total & per kategori).
///
/// Yang diuji keras:
/// 1. Angka beban dihitung ULANG dari data mentah (bukan memakai kelas yang
///    diuji) untuk: tiga bulan berisi tagihan, bulan tanpa tagihan, kategori
///    tanpa tagihan, dan tagihan lintas batas tahun (Des -> Jan).
/// 2. Aturan inti: tagihan dihitung pada bulan JATUH TEMPONYA, dan tagihan yang
///    sudah lunas TETAP ikut (ini beban, bukan sisa utang).
/// 3. Bahasa layar bebas kata menghakimi (PRD §III-11).
/// 4. Layar: grafik dirender, ganti bulan mengganti angka, keadaan kosong jujur.
///
/// Waktu uji dikunci: "sekarang" = 15 September 2026, jadi bulan berjalan
/// 2026-09 dan jendela 6 bulan = 2026-04 .. 2026-09.
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/laporan/beban_tagihan.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/core/utils/mata_uang.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/laporan/beban_tagihan_screen.dart';

/// Waktu patok uji: 15 September 2026.
final DateTime jamUji = DateTime(2026, 9, 15, 8);

// ---------------------------------------------------------------------------
// Data MENTAH — sengaja berbentuk peta, bukan kelas inti, supaya angka
// pembanding dihitung ulang tanpa memakai kelas yang sedang diuji.
// 'sen' = satuan terkecil (Rp 150.000 -> 15000000 sen).
// ---------------------------------------------------------------------------

const String kunciApr = '2026-04';
const String kunciMei = '2026-05';
const String kunciJun = '2026-06';
const String kunciJul = '2026-07';
const String kunciAgu = '2026-08';
const String kunciSep = '2026-09';

List<Map<String, Object?>> dataMentah() => <Map<String, Object?>>[
      // Di luar jendela (Maret) — harus diabaikan.
      {'nama': 'PDAM lama', 'sen': 99000000, 'tgl': '2026-03-15', 'kategori': 'PDAM'},
      // April 2026 — 2 tagihan, 2 kategori.
      {'nama': 'Listrik PLN', 'sen': 15000000, 'tgl': '2026-04-10', 'kategori': 'PLN'},
      {'nama': 'Internet & TV', 'sen': 30000000, 'tgl': '2026-04-20', 'kategori': 'Internet & TV'},
      // Mei 2026 — 1 tagihan.
      {'nama': 'BPJS', 'sen': 10000000, 'tgl': '2026-05-05', 'kategori': 'BPJS'},
      // Juni 2026 — sengaja KOSONG (bulan tanpa tagihan).
      // Juli 2026 — 3 tagihan, salah satunya tanpa kategori & satu nonaktif.
      {'nama': 'Listrik PLN', 'sen': 17500000, 'tgl': '2026-07-12', 'kategori': 'PLN'},
      {'nama': 'Ponsel', 'sen': 5000000, 'tgl': '2026-07-18', 'kategori': null},
      {'nama': 'Kendaraan (berhenti)', 'sen': 6000000, 'tgl': '2026-07-25', 'kategori': 'Kendaraan', 'aktif': false},
      // Agustus 2026 — sudah dibayar, tetap ikut dihitung.
      {'nama': 'Internet rumah', 'sen': 30000000, 'tgl': '2026-08-03', 'kategori': 'Internet & TV', 'lunas': true},
      // September 2026 — 3 baris: 2 bernominal + 1 bernominal nol.
      {'nama': 'BPJS', 'sen': 10000000, 'tgl': '2026-09-01', 'kategori': 'BPJS'},
      {'nama': 'Cek gratis', 'sen': 0, 'tgl': '2026-09-05', 'kategori': 'BPJS'},
      {'nama': 'Sekolah anak', 'sen': 25000000, 'tgl': '2026-09-20', 'kategori': 'Sekolah'},
      // Kategori yang sudah tidak ada di daftar -> kelompok "Tanpa kategori".
      {'nama': 'Iuran lama', 'sen': 4000000, 'tgl': '2026-09-22', 'kategori': 'Kategori lama', 'kategoriHilang': true},
      // Di luar jendela (Oktober, bulan depan) — harus diabaikan.
      {'nama': 'Bayar nanti', 'sen': 70000000, 'tgl': '2026-10-01', 'kategori': 'PLN'},
    ];

/// Kategori uji. Dua di antaranya sengaja tanpa tagihan di dalam jendela:
/// 'Kesehatan' tidak dipakai sama sekali, 'PDAM' hanya punya tagihan Maret
/// 2026 (di luar jendela) — keduanya tidak boleh muncul sebagai baris nol.
const List<KategoriBeban> kategoriUji = <KategoriBeban>[
  KategoriBeban(id: 1, nama: 'PLN'),
  KategoriBeban(id: 2, nama: 'PDAM'),
  KategoriBeban(id: 3, nama: 'BPJS'),
  KategoriBeban(id: 4, nama: 'Internet & TV'),
  KategoriBeban(id: 5, nama: 'Sekolah'),
  KategoriBeban(id: 6, nama: 'Kendaraan'),
  KategoriBeban(id: 7, nama: 'Kesehatan'),
];

final Map<String, int> idKategoriUji = <String, int>{
  for (final KategoriBeban k in kategoriUji) k.nama: k.id,
};

/// Ubah data mentah menjadi model masukan inti (pemetaan mekanis saja).
List<TagihanBeban> keModel(List<Map<String, Object?>> data) {
  var id = 0;
  return <TagihanBeban>[
    for (final Map<String, Object?> d in data)
      TagihanBeban(
        id: ++id,
        nama: d['nama']! as String,
        nominalSen: d['sen']! as int,
        jatuhTempo: DateTime.parse(d['tgl']! as String),
        kategoriId: d['kategoriHilang'] == true
            ? 999
            : (d['kategori'] == null ? null : idKategoriUji[d['kategori'] as String]),
        status: d['lunas'] == true ? TagihanBeban.lunas : TagihanBeban.belumLunas,
        aktif: d['aktif'] != false,
      ),
  ];
}

/// Hitung ulang satu bulan dari data mentah TANPA memakai kelas inti.
///
/// Bulan diambil dari potongan teks tanggal (`YYYY-MM-DD`), jadi tidak ada
/// rumus bulan dari modul yang diuji. Baris nonaktif ikut (`hanyaAktif`
/// menyaring sesudahnya) supaya sama dengan aturan bawaan inti.
({int total, int jumlah, int sudah, int nonaktif, Map<String, int> perKategori})
    hitungSendiri(List<Map<String, Object?>> data, String kunci) {
  var total = 0;
  var jumlah = 0;
  var sudah = 0;
  var nonaktif = 0;
  final Map<String, int> perKategori = <String, int>{};
  for (final Map<String, Object?> d in data) {
    final List<String> tgl = (d['tgl']! as String).split('-');
    if ('${tgl[0]}-${tgl[1]}' != kunci) continue;
    final int sen = d['sen']! as int;
    total += sen;
    jumlah += 1;
    if (d['lunas'] == true) sudah += 1;
    if (d['aktif'] == false) nonaktif += 1;
    final String kelompok = (d['kategori'] == null || d['kategoriHilang'] == true)
        ? BebanTagihan.tanpaKategori
        : d['kategori']! as String;
    perKategori[kelompok] = (perKategori[kelompok] ?? 0) + sen;
  }
  return (total: total, jumlah: jumlah, sudah: sudah, nonaktif: nonaktif, perKategori: perKategori);
}

/// Angka dari teks persen tampilan, mis. "33,3%" -> 33.3.
double angkaDariTeksBagian(String teks) =>
    double.parse(teks.replaceAll('%', '').replaceAll(',', '.'));

/// Rumus uang uji (rupiah -> sen) tanpa memakai fmtUang/format rupiah sendiri.
int sen(num rupiah) => (rupiah * 100).round();

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  // -------------------------------------------------------------------------
  // Inti: angka per bulan
  // -------------------------------------------------------------------------

  group('FR-28 hitung beban per bulan', () {
    BebanTagihan hitung({bool hanyaAktif = false, int jumlahBulan = 6}) =>
        BebanTagihan.hitung(
          tagihan: keModel(dataMentah()),
          kategori: kategoriUji,
          acuan: jamUji,
          jumlahBulan: jumlahBulan,
          hanyaAktif: hanyaAktif,
        );

    test('jendela 6 bulan berakhir di bulan berjalan, urut lama -> baru', () {
      final BebanTagihan b = hitung();
      expect(b.jumlahBulan, 6);
      expect(b.bulan.map((e) => e.kunci).toList(),
          <String>[kunciApr, kunciMei, kunciJun, kunciJul, kunciAgu, kunciSep]);
      expect(b.bulanTerbaru.kunci, kunciSep);
      // Urut menaik (paling lama -> paling baru).
      for (var i = 1; i < b.bulan.length; i++) {
        expect(b.bulan[i].kunci.compareTo(b.bulan[i - 1].kunci) > 0, isTrue);
      }
    });

    test('tagihan di luar jendela tidak ikut dihitung', () {
      final BebanTagihan b = hitung();
      // Maret (2026-03) & Oktober (2026-10) tidak ada di jendela.
      expect(b.bulanKe('2026-03'), isNull);
      expect(b.bulanKe('2026-10'), isNull);
      var totalMentah = 0;
      for (final String k in <String>[
        kunciApr, kunciMei, kunciJun, kunciJul, kunciAgu, kunciSep,
      ]) {
        totalMentah += hitungSendiri(dataMentah(), k).total;
      }
      expect(b.totalSen, totalMentah);
    });

    test('tiga bulan berisi tagihan: total & jumlah cocok data mentah', () {
      final BebanTagihan b = hitung();
      for (final String k in <String>[kunciApr, kunciMei, kunciSep]) {
        final hasilMentah = hitungSendiri(dataMentah(), k);
        final BulanBeban bulan = b.bulanKe(k)!;
        expect(bulan.totalSen, hasilMentah.total, reason: 'total $k');
        expect(bulan.jumlah, hasilMentah.jumlah, reason: 'jumlah $k');
        expect(bulan.kosong, isFalse, reason: 'kosong $k');
      }
      // Angka eksplisit dari data mentah: April = 15 jt + 30 jt sen.
      expect(b.bulanKe(kunciApr)!.totalSen, 15000000 + 30000000);
      expect(b.bulanKe(kunciApr)!.jumlah, 2);
      // September = 10 jt + 0 + 25 jt + 4 jt sen (4 baris, satu bernilai nol).
      expect(b.bulanKe(kunciSep)!.totalSen, 10000000 + 25000000 + 4000000);
      expect(b.bulanKe(kunciSep)!.jumlah, 4);
    });

    test('bulan tanpa tagihan: total 0, kosong, tanpa rincian', () {
      final BebanTagihan b = hitung();
      final BulanBeban jun = b.bulanKe(kunciJun)!;
      expect(jun.jumlah, 0);
      expect(jun.totalSen, 0);
      expect(jun.kosong, isTrue);
      expect(jun.perKategori, isEmpty);
      expect(hitungSendiri(dataMentah(), kunciJun).total, 0);
      // Bulan berjalan tetap punya data -> keadaan "belum ada data" tidak aktif.
      expect(b.adaData, isTrue);
      expect(b.bulanKe(kunciJul)!.kosong, isFalse);
    });

    test('kategori tanpa tagihan tidak dibuatkan baris nol', () {
      final BebanTagihan b = hitung();
      for (final BulanBeban bulan in b.bulan) {
        final List<String> nama = bulan.perKategori.map((e) => e.nama).toList();
        // 'Kesehatan' tidak dipakai sama sekali; 'PDAM' hanya di Maret 2026
        // (di luar jendela) — jangan sampai muncul sebagai baris Rp 0.
        expect(nama, isNot(contains('Kesehatan')), reason: bulan.kunci);
        expect(nama, isNot(contains('PDAM')), reason: bulan.kunci);
      }
      // Kategorinya tetap dikenal (tidak dihapus dari daftar masukan).
      expect(b.kategori.map((e) => e.nama),
          containsAll(<String>['Kesehatan', 'PDAM', 'Kendaraan']));
      // Di jendela 12 bulan, Maret masuk -> PDAM baru punya baris.
      expect(
        hitung(jumlahBulan: 12)
            .bulanKe('2026-03')!
            .perKategori
            .map((e) => e.nama),
        contains('PDAM'),
      );
    });

    test('rincian kategori cocok data mentah (total & jumlah)', () {
      final BebanTagihan b = hitung();
      for (final String k in <String>[kunciApr, kunciJul, kunciSep]) {
        final hasilMentah = hitungSendiri(dataMentah(), k);
        final Map<String, int> dariInti = <String, int>{
          for (final BagianKategori g in b.bulanKe(k)!.perKategori) g.nama: g.totalSen,
        };
        expect(dariInti, hasilMentah.perKategori, reason: 'rincian $k');
      }
      // Juli: PLN 17,5 jt + Ponsel 5 jt (tanpa kategori) + Kendaraan 6 jt.
      final BulanBeban jul = b.bulanKe(kunciJul)!;
      expect(jul.totalSen, 17500000 + 5000000 + 6000000);
      expect(jul.jumlah, 3);
      expect(jul.perKategori.map((e) => e.nama).toList(),
          <String>['PLN', 'Kendaraan', BebanTagihan.tanpaKategori]);
    });

    test('tagihan tanpa kategori (dan kategori hilang) masuk "Tanpa kategori"', () {
      final BebanTagihan b = hitung();
      final BulanBeban jul = b.bulanKe(kunciJul)!;
      final BagianKategori tanpaKategoriJul = jul.perKategori
          .firstWhere((e) => e.nama == BebanTagihan.tanpaKategori);
      expect(tanpaKategoriJul.totalSen, 5000000);
      expect(tanpaKategoriJul.jumlah, 1);
      expect(tanpaKategoriJul.kategoriId, isNull);

      final BulanBeban sep = b.bulanKe(kunciSep)!;
      final BagianKategori tanpaKategoriSep = sep.perKategori
          .firstWhere((e) => e.nama == BebanTagihan.tanpaKategori);
      expect(tanpaKategoriSep.totalSen, 4000000);
      expect(tanpaKategoriSep.jumlah, 1);
      expect(sep.perKategori.map((e) => e.nama),
          isNot(contains('Kategori lama')));
      expect(sep.perKategori.map((e) => e.nama),
          <String>['Sekolah', 'BPJS', BebanTagihan.tanpaKategori]);
    });

    test('bagian persen benar dan jumlahnya 100% (toleransi 0,1)', () {
      final BebanTagihan b = hitung();
      for (final String k in <String>[kunciApr, kunciJul, kunciSep]) {
        final BulanBeban bulan = b.bulanKe(k)!;
        final Map<String, int> mentah = hitungSendiri(dataMentah(), k).perKategori;
        var jumlahPersen = 0.0;
        var jumlahTeks = 0.0;
        for (final BagianKategori g in bulan.perKategori) {
          final double harapan = mentah[g.nama]! / bulan.totalSen * 100;
          expect(g.bagianPersen, closeTo(harapan, 1e-9), reason: '${g.nama} $k');
          jumlahPersen += g.bagianPersen;
          jumlahTeks += angkaDariTeksBagian(g.bagianTeks);
        }
        expect(jumlahPersen, closeTo(100, 0.1), reason: 'jumlah bagian $k');
        // Yang terbaca pengguna juga tetap 100,0% (sisa pembulatan diserap
        // kategori terbesar).
        expect(jumlahTeks, closeTo(100, 0.01), reason: 'jumlah teks $k');
      }
      // Contoh angka mentah: April 15/45 = 33,3% dan 30/45 = 66,7%.
      final BulanBeban apr = b.bulanKe(kunciApr)!;
      expect(apr.perKategori.first.nama, 'Internet & TV');
      expect(apr.perKategori.first.bagianTeks, '66,7%');
      expect(apr.perKategori.last.nama, 'PLN');
      expect(apr.perKategori.last.bagianTeks, '33,3%');
    });

    test('tagihan yang sudah lunas tetap ikut dihitung', () {
      final BebanTagihan b = hitung();
      final BulanBeban agu = b.bulanKe(kunciAgu)!;
      final hasilMentah = hitungSendiri(dataMentah(), kunciAgu);
      expect(agu.totalSen, hasilMentah.total);
      expect(agu.totalSen, 30000000, reason: 'tagihan lunas tetap jadi beban');
      expect(agu.jumlah, 1);
      expect(agu.jumlahSudahDibayar, 1);
      expect(agu.jumlahBelumDibayar, 0);
      expect(b.bulanKe(kunciSep)!.jumlahSudahDibayar, 0);
      expect(b.bulanKe(kunciSep)!.jumlahBelumDibayar, 4);
    });

    test('tagihan nonaktif tetap ikut; hanyaAktif menyaringnya', () {
      final BebanTagihan semua = hitung();
      final BebanTagihan hanyaAktif = hitung(hanyaAktif: true);
      final hasilMentah = hitungSendiri(dataMentah(), kunciJul);
      expect(semua.bulanKe(kunciJul)!.totalSen, hasilMentah.total);
      expect(hasilMentah.nonaktif, 1);
      expect(
        hanyaAktif.bulanKe(kunciJul)!.totalSen,
        hasilMentah.total - 6000000,
      );
      expect(hanyaAktif.bulanKe(kunciJul)!.jumlah, 2);
      // Bulan lain tidak terpengaruh.
      expect(hanyaAktif.bulanKe(kunciSep)!.totalSen,
          semua.bulanKe(kunciSep)!.totalSen);
    });

    test('jendela dipotong persis: 3 bulan, 1 bulan, dan 12 bulan', () {
      expect(hitung(jumlahBulan: 3).bulan.map((e) => e.kunci).toList(),
          <String>[kunciJul, kunciAgu, kunciSep]);
      expect(hitung(jumlahBulan: 1).bulan.map((e) => e.kunci).toList(),
          <String>[kunciSep]);
      final BebanTagihan setahun = hitung(jumlahBulan: 12);
      expect(setahun.jumlahBulan, 12);
      expect(setahun.bulan.first.kunci, '2025-10');
      // Jendela 12 bulan kini memuat Maret 2026 yang tadinya di luar jendela.
      expect(setahun.bulanKe('2026-03')!.totalSen, 99000000);
      // Tagihan Oktober 2026 tetap di luar (bulan depan).
      expect(setahun.bulanKe('2026-10'), isNull);
    });

    test('jumlahBulan < 1 ditolak', () {
      expect(
        () => BebanTagihan.hitung(tagihan: const <TagihanBeban>[], jumlahBulan: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('belum ada data ditulis jelas, bukan angka nol palsu', () {
      final BebanTagihan kosong = BebanTagihan.hitung(
        tagihan: const <TagihanBeban>[],
        kategori: kategoriUji,
        acuan: jamUji,
      );
      expect(kosong.adaData, isFalse);
      expect(kosong.totalSen, 0);
      expect(kosong.jumlahBulan, 6);
      expect(kosong.bulanTerbaru.kosong, isTrue);
      expect(BebanTagihan.pesanBelumAdaData,
          'Belum ada tagihan pada rentang ini');
      expect(BebanTagihan.pesanBulanKosong,
          'Belum ada tagihan pada bulan ini');
      expect(BebanTagihan.tanpaKategori, 'Tanpa kategori');
      expect(BebanTagihan.catatanTermasukDibayar,
          'termasuk yang sudah dibayar');
    });

    test('bagian 0% saat total bulan nol (hanya tagihan bernominal nol)', () {
      final BebanTagihan b = BebanTagihan.hitung(
        tagihan: <TagihanBeban>[
          TagihanBeban(
            id: 1,
            nama: 'Cek gratis',
            nominalSen: 0,
            jatuhTempo: DateTime(2026, 9, 5),
            kategoriId: 3,
          ),
        ],
        kategori: kategoriUji,
        acuan: jamUji,
      );
      final BulanBeban sep = b.bulanKe(kunciSep)!;
      expect(sep.jumlah, 1, reason: 'baris bernominal nol tetap dihitung');
      expect(sep.totalSen, 0);
      expect(sep.kosong, isFalse);
      expect(sep.perKategori.single.bagianPersen, 0);
      expect(sep.perKategori.single.bagianTeks, '0,0%');
    });
  });

  // -------------------------------------------------------------------------
  // Lintas batas tahun
  // -------------------------------------------------------------------------

  group('FR-28 lintas batas tahun (Des -> Jan)', () {
    // "Sekarang" = 15 Januari 2027; jendela 3 bulan = Nov 2026 .. Jan 2027.
    final DateTime januari = DateTime(2027, 1, 15);
    List<TagihanBeban> dataDesJan() => <TagihanBeban>[
          TagihanBeban(
              id: 1,
              nama: 'Listrik Desember',
              nominalSen: 10000000,
              jatuhTempo: DateTime(2026, 12, 31),
              kategoriId: 1,
              status: TagihanBeban.lunas),
          TagihanBeban(
              id: 2,
              nama: 'Listrik Januari',
              nominalSen: 12000000,
              jatuhTempo: DateTime(2027, 1, 5),
              kategoriId: 1),
          TagihanBeban(
              id: 3,
              nama: 'Internet Januari',
              nominalSen: 30000000,
              jatuhTempo: DateTime(2027, 1, 20),
              kategoriId: 4),
        ];

    test('jendela melintasi tahun dengan kunci bulan yang benar', () {
      final BebanTagihan b = BebanTagihan.hitung(
        tagihan: dataDesJan(),
        kategori: kategoriUji,
        acuan: januari,
        jumlahBulan: 3,
      );
      expect(b.bulan.map((e) => e.kunci).toList(),
          <String>['2026-11', '2026-12', '2027-01']);
      expect(b.bulan.first.kosong, isTrue, reason: 'November kosong');
      expect(b.adaData, isTrue);
    });

    test('tagihan 31 Des masuk Desember, bukan Januari', () {
      final BebanTagihan b = BebanTagihan.hitung(
        tagihan: dataDesJan(),
        kategori: kategoriUji,
        acuan: januari,
        jumlahBulan: 3,
      );
      final BulanBeban des = b.bulanKe('2026-12')!;
      final BulanBeban jan = b.bulanKe('2027-01')!;
      expect(des.totalSen, 10000000);
      expect(des.jumlah, 1);
      expect(des.jumlahSudahDibayar, 1);
      expect(jan.totalSen, 12000000 + 30000000);
      expect(jan.jumlah, 2);
      expect(jan.perKategori.map((e) => e.nama).toList(),
          <String>['Internet & TV', 'PLN']);
      expect(jan.perKategori.first.bagianTeks, '71,4%');
      expect(jan.perKategori.last.bagianTeks, '28,6%');
    });

    test('label bulan lintas tahun tetap terbaca', () {
      expect(labelSumbuBulan('2027-01'), 'Jan 2027');
      expect(labelSumbuBulan('2026-12'), 'Des');
      expect(labelBulanPendek('2027-01'), 'Jan 2027');
      expect(labelBulanPanjang('2026-12'), 'Desember 2026');
      expect(labelSumbuBulan('entah'), 'entah');
      expect(labelBulanPanjang('entah'), 'entah');
    });
  });

  // -------------------------------------------------------------------------
  // Label grafik
  // -------------------------------------------------------------------------

  group('FR-28 batang grafik', () {
    test('nominal memakai fmtUangDariSen & label nama bulan singkat', () {
      final BebanTagihan b = BebanTagihan.hitung(
        tagihan: keModel(dataMentah()),
        kategori: kategoriUji,
        acuan: jamUji,
      );
      final List<BatangBeban> batang = daftarBatangBeban(b, kunciJul);
      expect(batang.length, 6);
      expect(batang.first.label, 'Apr');
      expect(batang.last.label, 'Sep');
      expect(batang.first.nominal, fmtUangDariSen(45000000));
      expect(batang.first.nominal, 'Rp 450.000');
      expect(batang[3].kunci, kunciJul);
      expect(batang[3].terpilih, isTrue);
      expect(batang[3].nominal, fmtUangDariSen(28500000));
      expect(batang.where((e) => e.terpilih).length, 1);
      // Bulan tanpa tagihan tetap punya batang bernilai 0.
      expect(batang[2].kunci, kunciJun);
      expect(batang[2].nilai, 0);
      expect(batang[2].nominal, fmtUangDariSen(0));
    });

    testWidgets('kartu grafik menggambar CustomPaint dan bukan nol palsu',
        (WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      final BebanTagihan b = BebanTagihan.hitung(
        tagihan: keModel(dataMentah()),
        kategori: kategoriUji,
        acuan: jamUji,
      );
      await t.pumpWidget(MaterialApp(
        theme: AppTema.terang(),
        home: Scaffold(
          body: GrafikBebanTagihan(
            key: const Key('grafik_uji'),
            beban: b,
            dipilih: kunciSep,
          ),
        ),
      ));
      await t.pump();

      expect(find.byKey(const Key('grafik_uji')), findsOneWidget);
      expect(find.text('Grafik beban per bulan'), findsOneWidget);
      expect(find.textContaining('Tertinggi Rp 450.000'), findsOneWidget);
      final List<CustomPainter> pelukis = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((CustomPaint w) => w.painter)
          .whereType<CustomPainter>()
          .where((CustomPainter p) => p.runtimeType.toString().contains('PelukisBeban'))
          .toList();
      expect(pelukis.length, 1);

      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('tanpa data: kartu grafik jujur, bukan batang kosong',
        (WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      final BebanTagihan b = BebanTagihan.hitung(
        tagihan: const <TagihanBeban>[],
        acuan: jamUji,
      );
      await t.pumpWidget(MaterialApp(
        theme: AppTema.terang(),
        home: Scaffold(
          body: GrafikBebanTagihan(beban: b, dipilih: b.bulanTerbaru.kunci),
        ),
      ));
      await t.pump();

      expect(find.text(BebanTagihan.pesanBelumAdaData), findsOneWidget);
      expect(find.textContaining('Belum ada angka untuk digambar'), findsOneWidget);
      final List<CustomPainter> pelukis = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((CustomPaint w) => w.painter)
          .whereType<CustomPainter>()
          .where((CustomPainter p) => p.runtimeType.toString().contains('PelukisBeban'))
          .toList();
      expect(pelukis, isEmpty);

      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.binding.setSurfaceSize(null);
    });
  });

  // -------------------------------------------------------------------------
  // Layar
  // -------------------------------------------------------------------------

  group('FR-28 layar Beban tagihan', () {
    late AppDatabase db;
    late TagihanRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = TagihanRepository(db);
    });

    tearDown(() async => db.close());

    Future<int?> idKategori(String nama) async {
      final List<KategoriData> semua = await db.select(db.kategori).get();
      for (final KategoriData k in semua) {
        if (k.nama == nama) return k.id;
      }
      return null;
    }

    Future<void> tambahTagihan({
      required String nama,
      required DateTime jatuhTempo,
      num rupiah = 0,
      int? kategoriId,
      bool lunas = false,
      bool aktif = true,
      bool tanpaNominal = false,
    }) async {
      await repo.tambah(TagihanCompanion.insert(
        nama: nama,
        jumlahSen:
            tanpaNominal ? const Value<int?>(null) : Value<int>(sen(rupiah)),
        jatuhTempo: jatuhTempo,
        kategoriId: Value<int?>(kategoriId),
        lunas: Value<bool>(lunas),
        statusAktif: Value<bool>(aktif),
      ));
    }

    /// Isi contoh: September (bulan berjalan) = Rp 1.750.000 dari 2 tagihan.
    Future<void> isiData() async {
      final int? pln = await idKategori('PLN');
      final int? sekolah = await idKategori('Sekolah');
      final int? internet = await idKategori('Internet & TV');
      await tambahTagihan(
          nama: 'Listrik PLN',
          rupiah: 500000,
          jatuhTempo: DateTime(2026, 9, 10),
          kategoriId: pln);
      await tambahTagihan(
          nama: 'Sekolah anak',
          rupiah: 1250000,
          jatuhTempo: DateTime(2026, 9, 20),
          kategoriId: sekolah,
          lunas: true);
      await tambahTagihan(
          nama: 'Dokumen asuransi',
          jatuhTempo: DateTime(2026, 9, 25),
          tanpaNominal: true);
      await tambahTagihan(
          nama: 'Internet rumah',
          rupiah: 300000,
          jatuhTempo: DateTime(2026, 7, 5),
          kategoriId: internet);
      await tambahTagihan(
          nama: 'PDAM',
          rupiah: 200000,
          jatuhTempo: DateTime(2026, 6, 10));
      // Di luar jendela 6 bulan (Maret 2026) — tidak boleh muncul.
      await tambahTagihan(
          nama: 'PDAM lama', rupiah: 999000, jatuhTempo: DateTime(2026, 3, 10));
    }

    Future<void> tampilkan(WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: BebanTagihanScreen(jamSekarang: () => jamUji),
        ),
      ));
      // Pembaruan drift butuh pump berulang.
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> tutup(WidgetTester t) async {
      await t.pump(const Duration(milliseconds: 200));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.binding.setSurfaceSize(null);
    }

    /// Gulir sampai target terlihat (ListView hanya membangun baris terlihat).
    Future<void> gulirKe(WidgetTester t, Finder target, {int maks = 8}) async {
      for (var i = 0; i < maks; i++) {
        if (target.evaluate().isNotEmpty) return;
        await t.drag(find.byType(Scrollable).first, const Offset(0, -220));
        await t.pump(const Duration(milliseconds: 150));
      }
    }

    /// Gulir kembali ke puncak daftar (pemilih bulan ada di sana).
    Future<void> keAtas(WidgetTester t) async {
      for (var i = 0; i < 6; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, 300));
        await t.pump(const Duration(milliseconds: 120));
      }
    }

    /// Seluruh teks yang tampil, sambil digulir sampai bawah.
    Future<String> teksSeluruhLayar(WidgetTester t) async {
      final List<String> kumpulan = <String>[];
      for (var i = 0; i < 6; i++) {
        kumpulan.addAll(t
            .widgetList<Text>(find.byType(Text))
            .map((Text w) => w.data ?? '')
            .where((String s) => s.isNotEmpty));
        await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await t.pump(const Duration(milliseconds: 150));
      }
      return kumpulan.join(' ').toLowerCase();
    }

    testWidgets('grafik, total bulan berjalan, dan rincian kategori tampil',
        (WidgetTester t) async {
      await isiData();
      await tampilkan(t);

      // Kartu pemilih bulan: 6 bulan jendela, terakhir = bulan berjalan.
      for (final String k in <String>[
        '2026-04', '2026-05', '2026-06', '2026-07', '2026-08', '2026-09',
      ]) {
        expect(find.byKey(Key('pilih_bulan_$k')), findsOneWidget, reason: k);
      }
      // Kartu total bulan terpilih (September = Rp 500.000 + Rp 1.250.000).
      expect(t.widget<Text>(find.byKey(const Key('total_bulan'))).data,
          'Rp 1.750.000');
      expect(t.widget<Text>(find.byKey(const Key('judul_bulan'))).data,
          'Beban bulan September 2026');
      // Tagihan tanpa nominal (dokumen) tidak dihitung; 2 tagihan, 1 lunas.
      expect(find.textContaining('2 tagihan jatuh tempo bulan ini'),
          findsOneWidget);
      expect(find.textContaining('1 sudah dibayar'), findsOneWidget);
      // Alasan aturan FR-28 ditulis di layar.
      expect(find.textContaining('termasuk yang sudah dibayar'), findsOneWidget);
      // Daerah grafik benar-benar ada dan memakai pelukis kita.
      expect(find.byKey(const Key('grafik_beban')), findsOneWidget);
      final List<CustomPainter> pelukis = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((CustomPaint w) => w.painter)
          .whereType<CustomPainter>()
          .where((CustomPainter p) => p.runtimeType.toString().contains('PelukisBeban'))
          .toList();
      expect(pelukis.length, 1);

      // Rincian kategori bulan berjalan.
      await gulirKe(t, find.byKey(const Key('kategori_PLN')));
      expect(find.byKey(const Key('kategori_PLN')), findsOneWidget);
      expect(find.byKey(const Key('kategori_Sekolah')), findsOneWidget);
      expect(find.byKey(const Key('kategori_Tanpa kategori')), findsNothing);
      // PLN Rp 500.000 dari total Rp 1.750.000 = 28,6%.
      expect(find.text('28,6%'), findsOneWidget);
      expect(find.text('71,4%'), findsOneWidget);

      await tutup(t);
    });

    testWidgets('ganti bulan mengganti angka total & rincian', (WidgetTester t) async {
      await isiData();
      await tampilkan(t);

      expect(t.widget<Text>(find.byKey(const Key('total_bulan'))).data,
          'Rp 1.750.000');

      // Ke Juli 2026: hanya Internet rumah Rp 300.000.
      await t.tap(find.byKey(const Key('pilih_bulan_2026-07')));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(t.widget<Text>(find.byKey(const Key('total_bulan'))).data,
          'Rp 300.000');
      expect(t.widget<Text>(find.byKey(const Key('judul_bulan'))).data,
          'Beban bulan Juli 2026');
      expect(find.textContaining('1 tagihan jatuh tempo bulan ini'),
          findsOneWidget);
      await gulirKe(t, find.byKey(const Key('kategori_Internet & TV')));
      expect(find.byKey(const Key('kategori_Internet & TV')), findsOneWidget);
      expect(find.text('100,0%'), findsOneWidget);

      // Ke Mei 2026 (bulan tanpa tagihan di jendela ini): kembali ke puncak dulu.
      await keAtas(t);
      await t.tap(find.byKey(const Key('pilih_bulan_2026-05')));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(t.widget<Text>(find.byKey(const Key('total_bulan'))).data, 'Rp 0');
      expect(t.widget<Text>(find.byKey(const Key('judul_bulan'))).data,
          'Beban bulan Mei 2026');
      expect(find.text(BebanTagihan.pesanBulanKosong), findsWidgets);
      expect(find.text('0,0%'), findsNothing);

      // Kembali ke bulan berjalan.
      await keAtas(t);
      await t.tap(find.byKey(const Key('pilih_bulan_2026-09')));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(t.widget<Text>(find.byKey(const Key('total_bulan'))).data,
          'Rp 1.750.000');

      await tutup(t);
    });

    testWidgets('keadaan kosong tampil jujur (tanpa data sama sekali)',
        (WidgetTester t) async {
      await tampilkan(t);

      expect(t.widget<Text>(find.byKey(const Key('total_bulan'))).data, 'Rp 0');
      expect(find.text(BebanTagihan.pesanBulanKosong), findsWidgets);
      // Kartu grafik tetap ada, tetapi tidak menggambar batang kosong.
      expect(find.byKey(const Key('grafik_beban')), findsOneWidget);
      expect(find.byKey(const Key('grafik_kosong')), findsOneWidget);
      expect(find.text(BebanTagihan.pesanBelumAdaData), findsOneWidget);
      // Tidak ada baris kategori sama sekali (baris kategori memakai bilah).
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Tanpa kategori'), findsNothing);
      expect(find.text('NaN%'), findsNothing);

      await tutup(t);
    });

    testWidgets('bahasa layar bebas kata menghakimi (PRD §III-11)',
        (WidgetTester t) async {
      const List<String> terlarang = <String>[
        'boros',
        'pemborosan',
        'gagal',
        'kamu',
        'tidak disiplin',
        'skor',
        'menghakimi',
        'menakut',
        'salah anda',
        'dosa',
      ];
      await isiData();
      await tampilkan(t);

      final String teks = await teksSeluruhLayar(t);
      for (final String kata in terlarang) {
        expect(teks.contains(kata), isFalse, reason: 'kata "$kata" muncul');
      }
      // Kata yang menghibur/menjelaskan memang ada.
      expect(teks.contains('termasuk yang sudah dibayar'), isTrue);

      await tutup(t);
    });
  });
}
