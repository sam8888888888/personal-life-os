/// Uji unit Modul 0 (FR-60 … FR-63) — tanpa Flutter, tanpa basis data.
///
/// Fokus: aturan warna, batas 6 baris, batas 5 butir Perhatian, teks alasan
/// berangka, dan bahasa yang aman (III-11).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/hari_ini/model_hari_ini.dart';
import 'package:personal_life_os/core/hari_ini/penyusun_briefing.dart';
import 'package:personal_life_os/core/hari_ini/penyusun_hari_ini.dart';
import 'package:personal_life_os/core/hari_ini/tagihan_ringkas.dart';

final sekarang = DateTime(2026, 9, 13); // Ahad, 13 Sep 2026

TagihanRingkas tgh(
  int id,
  String nama,
  DateTime jatuhTempo, {
  int? jumlahSen = 45000000, // Rp450.000
  String jenis = 'tagihan',
  bool lunas = false,
  bool aktif = true,
}) =>
    TagihanRingkas(
      id: id,
      nama: nama,
      jatuhTempo: jatuhTempo,
      jumlahSen: jumlahSen,
      jenis: jenis,
      lunas: lunas,
      statusAktif: aktif,
    );

List<TagihanRingkas> contohTagihan() => [
      tgh(1, 'Listrik PLN', DateTime(2026, 9, 8), jumlahSen: 45000000), // lewat 5 hari
      tgh(2, 'BPJS', DateTime(2026, 9, 13), jumlahSen: 15000000), // hari ini
      tgh(3, 'Internet', DateTime(2026, 9, 14), jumlahSen: 30000000), // besok
      tgh(4, 'PDAM', DateTime(2026, 9, 16), jumlahSen: 12000000), // 3 hari
      tgh(5, 'Sekolah', DateTime(2026, 9, 18), jumlahSen: 50000000), // 5 hari
      tgh(6, 'Asuransi', DateTime(2026, 9, 21), jumlahSen: 25000000), // 8 hari
      tgh(7, 'STNK', DateTime(2026, 10, 3), jumlahSen: null, jenis: 'dokumen'), // 20 hari
      tgh(8, 'Tagihan lunas', DateTime(2026, 9, 12), lunas: true), // sudah dibayar
      tgh(9, 'Tagihan nonaktif', DateTime(2026, 9, 12), aktif: false),
    ];

/// Kumpulan teks yang tampil ke pengguna (untuk uji bahasa).
List<String> semuaTeks(RingkasanHariIni r, IsiBriefing b, {required bool daring}) {
  final daftar = <String>[];
  for (final p in r.pilar) {
    daftar.add(p.pilar.label);
    daftar.add(p.angka);
    daftar.add(p.keterangan);
  }
  for (final a in r.agenda) {
    daftar.add(a.judul);
    daftar.add(a.alasan);
  }
  for (final p in r.perhatian) {
    daftar.add(p.judul);
    daftar.add(p.alasan);
    daftar.add(p.labelTombol);
  }
  daftar.addAll(barisBriefing(b, daring: daring));
  return daftar;
}

void main() {
  group('Aturan warna & selisih hari', () {
    test('tingkat jatuh tempo: lewat merah, 0-3 oranye, 4-7 kuning, >7 hijau', () {
      expect(tingkatJatuhTempo(-1), TingkatPrioritas.merah);
      expect(tingkatJatuhTempo(-30), TingkatPrioritas.merah);
      expect(tingkatJatuhTempo(0), TingkatPrioritas.oranye);
      expect(tingkatJatuhTempo(3), TingkatPrioritas.oranye);
      expect(tingkatJatuhTempo(4), TingkatPrioritas.kuning);
      expect(tingkatJatuhTempo(7), TingkatPrioritas.kuning);
      expect(tingkatJatuhTempo(8), TingkatPrioritas.hijau);
    });

    test('selisih hari dihitung dari tanggal sipil (aman lintas bulan)', () {
      expect(sisaHariKe(sekarang, DateTime(2026, 9, 13)), 0);
      expect(sisaHariKe(sekarang, DateTime(2026, 10, 3)), 20);
      expect(sisaHariKe(DateTime(2026, 9, 13, 23, 59), DateTime(2026, 9, 14, 0, 1)), 1);
      expect(sisaHariKe(sekarang, DateTime(2026, 9, 8)), -5);
    });

    test('urutan tingkat: merah paling mendesak, netral paling akhir', () {
      expect(TingkatPrioritas.merah.urutan < TingkatPrioritas.oranye.urutan, isTrue);
      expect(TingkatPrioritas.oranye.urutan < TingkatPrioritas.kuning.urutan, isTrue);
      expect(TingkatPrioritas.kuning.urutan < TingkatPrioritas.hijau.urutan, isTrue);
      expect(TingkatPrioritas.hijau.urutan < TingkatPrioritas.netral.urutan, isTrue);
      expect(TingkatPrioritas.merah.mendesak, isTrue);
      expect(TingkatPrioritas.netral.mendesak, isFalse);
    });
  });

  group('Teks alasan berangka', () {
    test('lewat, hari ini, besok, dan beberapa hari lagi', () {
      expect(teksAlasanTagihan(contohTagihan()[0], sekarang),
          'Tagihan Listrik PLN Rp 450.000 terlambat 5 hari');
      expect(teksAlasanTagihan(contohTagihan()[1], sekarang),
          'Tagihan BPJS Rp 150.000 jatuh tempo hari ini (13 Sep)');
      expect(teksAlasanTagihan(contohTagihan()[2], sekarang),
          'Tagihan Internet Rp 300.000 jatuh tempo besok (14 Sep)');
      expect(teksAlasanTagihan(contohTagihan()[4], sekarang),
          'Tagihan Sekolah Rp 500.000 jatuh tempo 5 hari lagi (18 Sep)');
    });

    test('dokumen tanpa nominal tidak menampilkan Rp0', () {
      final teks = teksAlasanTagihan(contohTagihan()[6], sekarang);
      expect(teks.startsWith('Dokumen STNK'), isTrue);
      expect(teks.contains('Rp'), isFalse);
      expect(teks.contains('20 hari lagi'), isTrue);
    });
  });

  group('FR-60 agenda: batas 6 baris', () {
    test('agenda hari ini memuat yang lewat, <=3 hari, dan dokumen <=30 hari', () {
      final a = agendaHariIni(contohTagihan(), sekarang);
      final id = a.map((x) => x.id).toSet();
      expect(id.contains('tagihan-1'), isTrue); // lewat
      expect(id.contains('tagihan-2'), isTrue); // hari ini
      expect(id.contains('tagihan-4'), isTrue); // 3 hari
      expect(id.contains('tagihan-7'), isTrue); // dokumen 20 hari
      expect(id.contains('tagihan-5'), isFalse); // 5 hari -> bukan agenda hari ini
      expect(id.contains('tagihan-8'), isFalse); // sudah dibayar
      expect(id.contains('tagihan-9'), isFalse); // nonaktif
    });

    test('peringkat mengambil maksimal 6 baris dan menaruh yang paling mendesak di atas', () {
      // 9 dokumen (jatuh tempo 7-15 hari lagi, semua <=30 hari -> masuk agenda).
      final banyak = [
        for (var i = 0; i < 9; i++)
          tgh(100 + i, 'Dokumen $i', DateTime(2026, 9, 20 + i),
              jumlahSen: null, jenis: 'dokumen'),
      ];
      final agenda = agendaHariIni(banyak, sekarang);
      expect(agenda.length, 9); // semuanya memang layak masuk agenda
      final hasil = peringkatEnamBaris(agenda);
      expect(hasil.length, maksBarisAgenda); // tampil dibatasi 6 baris

      // Tagihan yang jatuh tempo >3 hari BUKAN agenda hari ini.
      final jauh = [tgh(300, 'Tahunan', DateTime(2026, 9, 20))];
      expect(agendaHariIni(jauh, sekarang), isEmpty);
    });

    test('urutan: yang lewat lebih dulu daripada yang belum jatuh tempo', () {
      final a = peringkatEnamBaris(agendaHariIni(contohTagihan(), sekarang));
      expect(a.first.id, 'tagihan-1');
      expect(a.first.tingkat, TingkatPrioritas.merah);
    });

    test('daftar kosong tetap aman', () {
      expect(agendaHariIni(const [], sekarang), isEmpty);
      expect(peringkatEnamBaris(const []), isEmpty);
    });
  });

  group('FR-61 angka kartu pilar', () {
    final data = DataHariIni(sekarang: sekarang, tagihan: contohTagihan());

    test('Kesehatan & Keluarga selalu "Belum ada data" (tidak ada angka contoh)', () {
      for (final p in [Pilar.health, Pilar.family]) {
        final n = angkaPilar(p, data);
        expect(n.angka, 'Belum ada data');
        expect(n.belumAdaData, isTrue);
        expect(n.tingkat, TingkatPrioritas.netral);
      }
    });

    test('Uang: jumlah <=7 hari, nominal belum dibayar, dan warna merah saat ada yang lewat', () {
      final n = angkaPilar(Pilar.money, data);
      // <=7 hari: BPJS(0) + Internet(1) + PDAM(3) + Sekolah(5) = 4 tagihan.
      expect(n.angka.contains('Jatuh tempo ≤7 hari: 4'), isTrue);
      // Belum dibayar = 450.000 + 150.000 + 300.000 + 120.000 + 500.000.
      expect(n.angka.contains('Rp 1.520.000'), isTrue);
      expect(n.keterangan.contains('1 tagihan lewat jatuh tempo'), isTrue);
      expect(n.tingkat, TingkatPrioritas.merah);
      expect(n.rute, '/uang');
    });

    test('Uang: tanpa tagihan aktif -> netral & "Belum ada tagihan"', () {
      final n = angkaPilar(Pilar.money, DataHariIni(sekarang: sekarang));
      expect(n.angka, 'Belum ada tagihan');
      expect(n.belumAdaData, isTrue);
      expect(n.tingkat, TingkatPrioritas.netral);
    });

    test('Uang: hanya tagihan jauh -> hijau', () {
      final d = DataHariIni(
        sekarang: sekarang,
        tagihan: [tgh(1, 'Tahunan', DateTime(2026, 11, 1))],
      );
      final n = angkaPilar(Pilar.money, d);
      expect(n.tingkat, TingkatPrioritas.hijau);
      expect(n.angka.contains('Jatuh tempo ≤7 hari: 0'), isTrue);
    });

    test('Produktivitas memakai agenda hari ini dan menulis asal angkanya', () {
      final n = angkaPilar(Pilar.productivity, data);
      expect(n.angka.startsWith('Agenda hari ini: '), isTrue);
      expect(n.angka.contains('butir'), isTrue);
      expect(n.keterangan, 'termasuk tagihan & janji');
    });

    test('Produktivitas tanpa butir -> "Belum ada data"', () {
      final n = angkaPilar(Pilar.productivity, DataHariIni(sekarang: sekarang));
      expect(n.angka, 'Belum ada data');
      expect(n.belumAdaData, isTrue);
    });

    test('Ibadah: belum ada catatan -> netral, 1-4 -> kuning, 5 -> hijau', () {
      final kosong = angkaPilar(Pilar.ibadah, data);
      expect(kosong.angka, 'Belum ada catatan hari ini');
      expect(kosong.belumAdaData, isTrue);
      final tiga = angkaPilar(
          Pilar.ibadah, DataHariIni(sekarang: sekarang, jumlahSholatTercatat: 3));
      expect(tiga.angka, '3 dari 5 waktu tercatat');
      expect(tiga.tingkat, TingkatPrioritas.kuning);
      final lima = angkaPilar(
          Pilar.ibadah, DataHariIni(sekarang: sekarang, jumlahSholatTercatat: 5));
      expect(lima.tingkat, TingkatPrioritas.hijau);
    });

    test('Ibadah TIDAK PERNAH merah atau oranye (III-11)', () {
      for (var i = 0; i <= 5; i++) {
        final n = angkaPilar(
            Pilar.ibadah, DataHariIni(sekarang: sekarang, jumlahSholatTercatat: i));
        expect(n.tingkat, isNot(TingkatPrioritas.merah));
        expect(n.tingkat, isNot(TingkatPrioritas.oranye));
      }
    });

    test('urutan lima kartu pilar tetap', () {
      final r = susunHariIni(data);
      expect(r.pilar.map((p) => p.pilar).toList(), Pilar.values);
      expect(r.pilar.length, 5);
    });
  });

  group('FR-62 Perhatian', () {
    test('urutan prioritas: tagihan lewat, lalu hambatan sistem, lalu tenggat dekat', () {
      final d = DataHariIni(
        sekarang: sekarang,
        tagihan: [
          tgh(1, 'Listrik PLN', DateTime(2026, 9, 8)), // lewat
          tgh(2, 'BPJS', DateTime(2026, 9, 13)), // hari ini
          tgh(7, 'STNK', DateTime(2026, 10, 3), jumlahSen: null, jenis: 'dokumen'),
        ],
        statusIzinPengingat: 'belum',
      );
      final p = susunPerhatian(d);
      expect(p.first.jenis, JenisPerhatian.tagihanTerlambat);
      expect(p[1].jenis, JenisPerhatian.hambatanSistem);
      expect(p.any((b) => b.jenis == JenisPerhatian.tenggatDekat), isTrue);
      expect(p.any((b) => b.jenis == JenisPerhatian.dokumenKedaluwarsa), isTrue);
      // Jenis yang lebih mendesak selalu di depan (urutan prioritas §5.1).
      final urut = p.map((b) => b.jenis.prioritas).toList();
      expect(urut, List<int>.from(urut)..sort());
    });

    test('maksimal 5 butir walau masalahnya banyak', () {
      final banyak = [
        for (var i = 0; i < 7; i++)
          tgh(200 + i, 'Lewat $i', DateTime(2026, 9, 1 + i), jumlahSen: 1000000),
      ];
      final p = susunPerhatian(DataHariIni(sekarang: sekarang, tagihan: banyak));
      expect(p.length, maksButirPerhatian);
    });

    test('setiap butir punya alasan berangka, judul singkat, dan satu tombol', () {
      final d = DataHariIni(
        sekarang: sekarang,
        tagihan: contohTagihan(),
        statusIzinPengingat: 'belum',
      );
      for (final b in susunPerhatian(d)) {
        expect(b.alasan.trim(), isNotEmpty);
        expect(b.judul.trim(), isNotEmpty);
        expect(b.judul.length <= 40, isTrue);
        expect(b.labelTombol.isNotEmpty, isTrue);
        if (b.jenis != JenisPerhatian.hambatanSistem) {
          // Butir tagihan/dokumen wajib menyebut angka nyata (jumlah & tanggal).
          expect(b.alasan.contains(RegExp(r'\d')), isTrue, reason: b.alasan);
        } else {
          // Hambatan sistem menyebut berapa item yang menunggu.
          expect(b.alasan.contains('item menunggu'), isTrue, reason: b.alasan);
        }
      }
    });

    test('izin sudah menyala -> butir hambatan sistem tidak muncul', () {
      final d = DataHariIni(
        sekarang: sekarang,
        tagihan: contohTagihan(),
        statusIzinPengingat: 'diizinkan',
      );
      expect(susunPerhatian(d).any((b) => b.jenis == JenisPerhatian.hambatanSistem),
          isFalse);
    });

    test('tanpa masalah -> daftar Perhatian kosong', () {
      final d = DataHariIni(
          sekarang: sekarang, statusIzinPengingat: 'diizinkan');
      expect(susunPerhatian(d), isEmpty);
    });
  });

  group('FR-63 Morning Briefing', () {
    final data = DataHariIni(
      sekarang: sekarang,
      tagihan: contohTagihan(),
      namaPanggilan: 'Boss',
      cuaca: 'cerah 31 C',
      sumberCuaca: 'contoh',
    );

    test('isi briefing: sapaan, agenda maksimal 4, tagihan 7 hari maksimal 3', () {
      final b = susunBriefing(data, hijriah: '2 Rabiul Akhir 1448 H');
      expect(b.sapaan, 'Assalamualaikum, Boss');
      expect(b.agenda.length <= maksAgendaBriefing, isTrue);
      expect(b.tagihanTujuhHari.length <= maksTagihanBriefing, isTrue);
      expect(b.totalTagihanSen > 0, isTrue);
      expect(b.hijriah, '2 Rabiul Akhir 1448 H');
    });

    test('saat daring, blok cuaca tampil', () {
      final b = susunBriefing(data, hijriah: 'x');
      final baris = barisBriefing(b, daring: true);
      expect(baris.any((l) => l.startsWith('Cuaca:')), isTrue);
      expect(baris.any((l) => l == teksCuacaOffline), isFalse);
    });

    test('saat offline, blok cuaca dihilangkan dan diganti keterangan jujur', () {
      final b = susunBriefing(data, hijriah: 'x');
      final baris = barisBriefing(b, daring: false);
      expect(baris.any((l) => l.startsWith('Cuaca:')), isFalse);
      expect(baris.contains(teksCuacaOffline), isTrue);
    });

    test('waktu sholat berikutnya hanya muncul bila ada nilainya', () {
      final b = susunBriefing(data, hijriah: 'x');
      expect(barisBriefing(b, daring: true)
          .any((l) => l.startsWith('Waktu sholat berikutnya')), isFalse);
      final b2 = susunBriefing(data, hijriah: 'x', sholatBerikutnya: 'Dzuhur 11:49 · 3 jam 4 menit lagi');
      expect(barisBriefing(b2, daring: true)
          .any((l) => l.contains('Dzuhur 11:49')), isTrue);
    });

    test('briefing tanpa agenda & tagihan tetap jujur, bukan angka nol', () {
      final kosong = susunBriefing(
        DataHariIni(sekarang: sekarang),
        hijriah: 'x',
      );
      final baris = barisBriefing(kosong, daring: true);
      expect(baris.contains('Agenda hari ini: belum ada butir'), isTrue);
      expect(baris.contains('Tagihan 7 hari ke depan: belum ada'), isTrue);
    });

    test('disesuaikanJaringan menghapus cuaca tanpa mengubah bagian lain', () {
      final b = susunBriefing(data, hijriah: 'x');
      final o = disesuaikanJaringan(b, daring: false);
      expect(o.cuaca, isNull);
      expect(o.daring, isFalse);
      expect(o.agenda.length, b.agenda.length);
      expect(o.sapaan, b.sapaan);
    });
  });

  group('Bahasa aman (III-11)', () {
    const terlarang = [
      'skor iman',
      'anda gagal',
      'kamu',
      'berdosa',
      'kafir',
      'belum sholat',
      'wajib anda',
      'gagal',
    ];

    test('seluruh teks Modul 0 bebas kata menghakimi', () {
      final d = DataHariIni(
        sekarang: sekarang,
        tagihan: contohTagihan(),
        statusIzinPengingat: 'belum',
        jumlahSholatTercatat: 2,
      );
      final r = susunHariIni(d);
      final b = susunBriefing(d, hijriah: '2 Rabiul Akhir 1448 H');
      for (final teks in semuaTeks(r, b, daring: false)) {
        for (final kata in terlarang) {
          expect(teks.toLowerCase().contains(kata), isFalse,
              reason: '"$teks" memuat kata terlarang "$kata"');
        }
      }
    });

    test('kartu kosong memakai "Belum ada data", bukan angka 0', () {
      final r = susunHariIni(DataHariIni(sekarang: sekarang));
      for (final p in r.pilar.where((p) => p.belumAdaData)) {
        expect(p.angka.contains('Belum ada'), isTrue);
        expect(p.angka.trim(), isNot('0'));
      }
    });
  });
}
