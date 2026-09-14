import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/ibadah/kalender_hijriah.dart';
import 'package:personal_life_os/core/ibadah/kota_indonesia.dart';
import 'package:personal_life_os/core/ibadah/model_sholat.dart';
import 'package:personal_life_os/core/ibadah/penghitung_sholat.dart';
import 'package:personal_life_os/core/ibadah/penyimpanan_jadwal.dart';

/// Jadwal acuan dari Aladhan API (https://api.aladhan.com), diambil
/// 13 September 2026, jam lokal kota. Dipakai HANYA untuk membandingkan hasil
/// hitung sendiri; toleransi 2 menit karena pembulatan & selisih versi rumus.
const Map<String, Map<String, Map<WaktuSholat, String>>> acuan = <String, Map<String, Map<WaktuSholat, String>>>{
  'Jakarta': <String, Map<WaktuSholat, String>>{
    'kemenag': <WaktuSholat, String>{
      WaktuSholat.subuh: '04:30',
      WaktuSholat.dzuhur: '11:49',
      WaktuSholat.ashar: '15:03',
      WaktuSholat.maghrib: '17:50',
      WaktuSholat.isya: '18:59',
    },
    'mwl': <WaktuSholat, String>{
      WaktuSholat.subuh: '04:38',
      WaktuSholat.dzuhur: '11:49',
      WaktuSholat.ashar: '15:03',
      WaktuSholat.maghrib: '17:50',
      WaktuSholat.isya: '18:55',
    },
  },
  'Makassar': <String, Map<WaktuSholat, String>>{
    'kemenag': <WaktuSholat, String>{
      WaktuSholat.subuh: '04:39',
      WaktuSholat.dzuhur: '11:58',
      WaktuSholat.ashar: '15:11',
      WaktuSholat.maghrib: '18:00',
      WaktuSholat.isya: '19:09',
    },
    'mwl': <WaktuSholat, String>{
      WaktuSholat.subuh: '04:47',
      WaktuSholat.dzuhur: '11:58',
      WaktuSholat.ashar: '15:11',
      WaktuSholat.maghrib: '18:00',
      WaktuSholat.isya: '19:05',
    },
  },
};

final DateTime ujiTanggal = DateTime.utc(2026, 9, 13);

int menitDari(String jam) {
  final List<String> b = jam.split(':');
  return int.parse(b[0]) * 60 + int.parse(b[1]);
}

KotaSholat kota(String nama) =>
    daftarKotaIndonesia.firstWhere((KotaSholat k) => k.nama == nama);

void main() {
  group('FR-86 hitung jadwal sholat', () {
    for (final String namaKota in <String>['Jakarta', 'Makassar']) {
      for (final MetodeHitungSholat m in <MetodeHitungSholat>[
        MetodeHitungSholat.kemenag,
        MetodeHitungSholat.mwl,
      ]) {
        test('$namaKota/${m.label} cocok dengan jadwal acuan (toleransi 2 menit)', () {
          final JadwalSholatHarian j = hitungJadwal(
            kota: kota(namaKota),
            tanggal: ujiTanggal,
            metode: m,
          );
          final Map<WaktuSholat, String> ref = acuan[namaKota]![m.kode]!;
          ref.forEach((WaktuSholat w, String jam) {
            final String hasil = jamMenit(j.waktuLokal(w));
            final int selisih =
                (menitDari(hasil) - menitDari(jam)).abs();
            expect(selisih, lessThanOrEqualTo(2),
                reason: '$namaKota ${m.kode} ${w.label}: hitung $hasil vs acuan $jam');
          });
        });
      }
    }

    test('urutan waktu wajib masuk akal dan berurutan', () {
      final JadwalSholatHarian j = hitungJadwal(
        kota: kota('Jakarta'),
        tanggal: ujiTanggal,
      );
      final List<DateTime> urut = <DateTime>[
        j.waktuUtc[WaktuSholat.subuh]!,
        j.waktuUtc[WaktuSholat.syuruq]!,
        j.waktuUtc[WaktuSholat.dzuhur]!,
        j.waktuUtc[WaktuSholat.ashar]!,
        j.waktuUtc[WaktuSholat.maghrib]!,
        j.waktuUtc[WaktuSholat.isya]!,
      ];
      for (int i = 1; i < urut.length; i++) {
        expect(urut[i].isAfter(urut[i - 1]), isTrue,
            reason: 'waktu ke-$i harus setelah waktu sebelumnya');
      }
      // Syuruq di antara Subuh dan Dzuhur (penanda, bukan sholat).
      expect(j.waktuUtc[WaktuSholat.syuruq]!.isAfter(j.waktuUtc[WaktuSholat.subuh]!), isTrue);
      expect(WaktuSholat.syuruq.wajib, isFalse);
      expect(WaktuSholat.wajibSaja.length, 5);
    });

    test('Ashar madzhab Hanafi lebih akhir daripada Syafii', () {
      final JadwalSholatHarian syafii = hitungJadwal(
        kota: kota('Jakarta'),
        tanggal: ujiTanggal,
      );
      final JadwalSholatHarian hanafi = hitungJadwal(
        kota: kota('Jakarta'),
        tanggal: ujiTanggal,
        asharHanafi: true,
      );
      final int beda = hanafi.waktuUtc[WaktuSholat.ashar]!
          .difference(syafii.waktuUtc[WaktuSholat.ashar]!)
          .inMinutes;
      expect(beda, greaterThan(30));
      expect(beda, lessThan(90));
      expect(jamMenit(syafii.waktuLokal(WaktuSholat.ashar)), '15:04');
      expect(jamMenit(hanafi.waktuLokal(WaktuSholat.ashar)), '16:07');
    });

    test('koreksi menit menggeser waktu tepat sebesar koreksi', () {
      final JadwalSholatHarian polos =
          hitungJadwal(kota: kota('Jakarta'), tanggal: ujiTanggal);
      final JadwalSholatHarian koreksi = hitungJadwal(
        kota: kota('Jakarta'),
        tanggal: ujiTanggal,
        koreksiMenit: <WaktuSholat, int>{WaktuSholat.subuh: 3, WaktuSholat.isya: -2},
      );
      expect(
        koreksi.waktuUtc[WaktuSholat.subuh]!
            .difference(polos.waktuUtc[WaktuSholat.subuh]!)
            .inMinutes,
        3,
      );
      expect(
        polos.waktuUtc[WaktuSholat.isya]!
            .difference(koreksi.waktuUtc[WaktuSholat.isya]!)
            .inMinutes,
        2,
      );
      expect(koreksi.koreksiMenit[WaktuSholat.subuh], 3);
    });

    test('instan absolut tidak bergantung zona perangkat (WITA benar)', () {
      final JadwalSholatHarian j = hitungJadwal(
        kota: kota('Makassar'),
        tanggal: ujiTanggal,
      );
      expect(j.kota.zona, ZonaIndonesia.wita);
      // 04:39 WITA = 20:39 UTC hari sebelumnya
      expect(j.waktuUtc[WaktuSholat.subuh]!, DateTime.utc(2026, 9, 12, 20, 39));
      expect(jamMenit(j.waktuLokal(WaktuSholat.subuh)), '04:39');
      expect(j.waktuLokal(WaktuSholat.subuh).isUtc, isTrue,
          reason: 'jam dinding disimpan sebagai penanda UTC agar bebas zona');
    });

    test('waktu berikutnya: sebelum Subuh dan sesudah Isya', () {
      final List<JadwalSholatHarian> rentang = hitungRentang(
        kota: kota('Jakarta'),
        tanggalMulai: ujiTanggal,
        jumlahHari: 3,
      );
      final WaktuBerikutnya? pagi = cariWaktuBerikutnya(
        jadwal: rentang,
        sekarang: DateTime.utc(2026, 9, 12, 20, 0), // 03:00 WIB
      );
      expect(pagi!.waktu, WaktuSholat.subuh);
      expect(jamMenit(pagi.jamLokal), '04:30');
      expect(pagi.besok, isFalse);

      final WaktuBerikutnya? malam = cariWaktuBerikutnya(
        jadwal: rentang,
        sekarang: DateTime.utc(2026, 9, 13, 13, 0), // 20:00 WIB, sesudah Isya
      );
      expect(malam!.waktu, WaktuSholat.subuh);
      expect(malam.besok, isTrue);
      // Subuh bergeser ~1 menit per hari, jadi 14 Sep bisa 04:29 atau 04:30.
      expect(jamMenit(malam.jamLokal), anyOf('04:29', '04:30'));
      expect(jamMenit(malam.jamLokal).startsWith('04:'), isTrue);
    });

    test('hitungRentang: jumlah hari, urut, dan argumen tidak wajar ditolak', () {
      final List<JadwalSholatHarian> r = hitungRentang(
        kota: kota('Bandung'),
        tanggalMulai: ujiTanggal,
        jumlahHari: 7,
      );
      expect(r.length, 7);
      for (int i = 1; i < r.length; i++) {
        expect(r[i].tanggalKota.isAfter(r[i - 1].tanggalKota), isTrue);
      }
      expect(r.first.waktuUtc.length, 6);
      expect(() => hitungRentang(kota: kota('Bandung'), tanggalMulai: ujiTanggal, jumlahHari: 0),
          throwsArgumentError);
      expect(
        () => hitungJadwal(
          kota: KotaSholat.kustom(lintang: 200, bujur: 0, zona: ZonaIndonesia.wib),
          tanggal: ujiTanggal,
        ),
        throwsArgumentError,
      );
    });

    test('penanda sumber menyebut kota, zona, dan tanggal', () {
      final JadwalSholatHarian j =
          hitungJadwal(kota: kota('Makassar'), tanggal: ujiTanggal);
      expect(j.penandaSumber, contains('Makassar'));
      expect(j.penandaSumber, contains('WITA'));
      expect(j.penandaSumber, contains('13-09-2026'));
      expect(j.kota.labelLengkap, contains('WITA'));
    });
  });

  group('Daftar kota', () {
    test('minimal 40 kota, nama unik, koordinat wajar', () {
      expect(daftarKotaIndonesia.length, greaterThanOrEqualTo(40));
      final Set<String> nama = <String>{};
      for (final KotaSholat k in daftarKotaIndonesia) {
        expect(nama.add(k.nama), isTrue, reason: 'nama ganda: ${k.nama}');
        expect(k.koordinatWajar, isTrue, reason: k.nama);
        expect(k.lintang, inInclusiveRange(-11.5, 6.5), reason: k.nama);
        expect(k.bujur, inInclusiveRange(94.5, 141.5), reason: k.nama);
      }
    });

    test('zona waktu kota kunci benar', () {
      expect(kota('Jakarta').zona, ZonaIndonesia.wib);
      expect(kota('Pontianak').zona, ZonaIndonesia.wib);
      expect(kota('Makassar').zona, ZonaIndonesia.wita);
      expect(kota('Denpasar').zona, ZonaIndonesia.wita);
      expect(kota('Jayapura').zona, ZonaIndonesia.wit);
      expect(kota('Ambon').zona, ZonaIndonesia.wit);
    });

    test('pencarian kota tidak peka huruf besar/kecil', () {
      expect(cariKota('bandung').first.nama, 'Bandung');
      expect(cariKota('Maluku').length, greaterThanOrEqualTo(1));
      expect(cariKota('').length, daftarKotaIndonesia.length);
    });
  });

  group('Cache jadwal (offline)', () {
    late Directory dir;
    late PenyimpananJadwal simpan;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('uji_jadwal_');
      simpan = PenyimpananJadwal(penentuFolder: () async => dir);
    });

    tearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    test('simpan lalu ambil kembali utuh', () async {
      final List<JadwalSholatHarian> r = hitungRentang(
        kota: kota('Jakarta'),
        tanggalMulai: ujiTanggal,
        jumlahHari: 3,
      );
      final int jumlah = await simpan.simpanBanyak(r, sekarang: DateTime(2026, 9, 13));
      expect(jumlah, 3);

      final JadwalSholatHarian? satu = await simpan.ambil(
        tanggal: ujiTanggal,
        kota: kota('Jakarta'),
        kodeMetode: 'kemenag',
      );
      expect(satu, isNotNull);
      expect(jamMenit(satu!.waktuLokal(WaktuSholat.subuh)), '04:30');
      expect(satu.waktuUtc.length, 6);

      final List<JadwalSholatHarian> semua = await simpan.ambilRentang(kota('Jakarta'));
      expect(semua.length, 3);
      expect(semua.first.tanggalKota.isBefore(semua.last.tanggalKota), isTrue);
    });

    test('kunci membedakan metode, madzhab, dan koreksi', () async {
      final JadwalSholatHarian a =
          hitungJadwal(kota: kota('Jakarta'), tanggal: ujiTanggal);
      final JadwalSholatHarian b = hitungJadwal(
        kota: kota('Jakarta'),
        tanggal: ujiTanggal,
        metode: MetodeHitungSholat.mwl,
      );
      final JadwalSholatHarian c = hitungJadwal(
        kota: kota('Jakarta'),
        tanggal: ujiTanggal,
        asharHanafi: true,
      );
      final JadwalSholatHarian d = hitungJadwal(
        kota: kota('Jakarta'),
        tanggal: ujiTanggal,
        koreksiMenit: <WaktuSholat, int>{WaktuSholat.subuh: 2},
      );
      final Set<String> kunci = <String>{
        PenyimpananJadwal.kunci(a),
        PenyimpananJadwal.kunci(b),
        PenyimpananJadwal.kunci(c),
        PenyimpananJadwal.kunci(d),
      };
      expect(kunci.length, 4);
      await simpan.simpanBanyak(<JadwalSholatHarian>[a, b, c, d],
          sekarang: DateTime(2026, 9, 13));
      final JadwalSholatHarian? mwl = await simpan.ambil(
        tanggal: ujiTanggal,
        kota: kota('Jakarta'),
        kodeMetode: 'mwl',
      );
      expect(jamMenit(mwl!.waktuLokal(WaktuSholat.isya)), '18:55');
    });

    test('cache lama dipangkas (bergulir)', () async {
      final JadwalSholatHarian tua = hitungJadwal(
        kota: kota('Jakarta'),
        tanggal: DateTime.utc(2026, 1, 5),
      );
      final JadwalSholatHarian baru = hitungJadwal(
        kota: kota('Jakarta'),
        tanggal: ujiTanggal,
      );
      await simpan.simpanBanyak(<JadwalSholatHarian>[tua, baru],
          sekarang: DateTime(2026, 9, 13));
      final List<JadwalSholatHarian> sisa = await simpan.ambilRentang(kota('Jakarta'));
      expect(sisa.length, 1, reason: 'entri Januari harus dibuang');
      expect(jamMenit(sisa.first.waktuLokal(WaktuSholat.subuh)), '04:30');
    });

    test('berkas rusak tidak membuat aplikasi galat', () async {
      final File f = File('${dir.path}${Platform.pathSeparator}jadwal_sholat.json');
      await f.writeAsString('{ ini bukan json ');
      expect(await simpan.ambilRentang(kota('Jakarta')), isEmpty);
      expect(
        await simpan.ambil(
          tanggal: ujiTanggal,
          kota: kota('Jakarta'),
          kodeMetode: 'kemenag',
        ),
        isNull,
      );
      expect(await simpan.simpanBanyak(<JadwalSholatHarian>[hitungJadwal(kota: kota('Jakarta'), tanggal: ujiTanggal)]), 1);
    });

    test('bersihkan menghapus berkas', () async {
      await simpan.simpanBanyak(<JadwalSholatHarian>[
        hitungJadwal(kota: kota('Jakarta'), tanggal: ujiTanggal),
      ]);
      await simpan.bersihkan();
      expect(await simpan.ambilRentang(kota('Jakarta')), isEmpty);
    });

    test('berkas JSON berisi versi dan daftar hari', () async {
      await simpan.simpanBanyak(<JadwalSholatHarian>[
        hitungJadwal(kota: kota('Jakarta'), tanggal: ujiTanggal),
      ]);
      final File f = File('${dir.path}${Platform.pathSeparator}jadwal_sholat.json');
      final Map<String, dynamic> j =
          (jsonDecode(await f.readAsString()) as Map).cast<String, dynamic>();
      expect(j['versi'], 1);
      expect((j['hari'] as List).length, 1);
    });
  });

  group('FR-90 kalender Hijriah', () {
    test('1 Ramadhan 1447 H menurut dua acuan', () {
      final TanggalHijriah? uaq = hijriahDariMasehi(DateTime.utc(2026, 2, 18));
      expect(uaq!.label, '1 Ramadhan 1447 H');
      expect(uaq.bulan, 9);
      expect(uaq.hari, 1);

      final TanggalHijriah? fcna = hijriahDariMasehi(DateTime.utc(2026, 2, 19),
          acuan: AcuanHijriah.fcna);
      expect(fcna!.label, '1 Ramadhan 1447 H');

      // Bukti mesin berbeda: tanggal yang sama bisa berbeda 1 hari.
      final TanggalHijriah? uaqSama = hijriahDariMasehi(DateTime.utc(2026, 2, 18));
      final TanggalHijriah? fcnaSama = hijriahDariMasehi(DateTime.utc(2026, 2, 18),
          acuan: AcuanHijriah.fcna);
      expect(uaqSama!.hari == fcnaSama!.hari, isFalse);
    });

    test('konversi balik Hijriah -> Masehi', () {
      final DateTime? g = masehiDariHijriah(const TanggalHijriah(1447, 9, 1));
      expect(g, DateTime.utc(2026, 2, 18));
      final DateTime? fcnaMasehi = masehiDariHijriah(const TanggalHijriah(1447, 9, 1),
          acuan: AcuanHijriah.fcna);
      expect(fcnaMasehi, DateTime.utc(2026, 2, 19));
    });

    test('koreksi hari menggeser tanggal Hijriah', () {
      final TanggalHijriah? biasa = hijriahDariMasehi(DateTime.utc(2026, 2, 18));
      final TanggalHijriah? mundur =
          hijriahDariMasehi(DateTime.utc(2026, 2, 18), koreksiHari: -1);
      expect(biasa!.hari, 1);
      expect(mundur!.bulan, 8, reason: 'mundur 1 hari = akhir Syaban');
      final TanggalHijriah? maju =
          hijriahDariMasehi(DateTime.utc(2026, 2, 18), koreksiHari: 1);
      expect(maju!.hari, 2);
    });

    test('jumlah hari bulan Hijriah hanya 29 atau 30', () {
      for (int b = 1; b <= 12; b++) {
        final int? n = jumlahHariBulanHijriah(1447, b);
        expect(n, isNotNull);
        expect(n == 29 || n == 30, isTrue, reason: 'bulan $b = $n');
      }
      expect(jumlahHariBulanHijriah(1447, 9), 30);
      expect(jumlahHariBulanHijriah(1447, 13), isNull);
    });

    test('penyusunan bulan: jumlah sel, urut, dan hari besar', () {
      final BulanHijriah b = susunBulanHijriah(1447, 9);
      expect(b.label, 'Ramadhan 1447 H');
      expect(b.jumlahHari, 30);
      expect(b.sel.first.hijriah.hari, 1);
      expect(b.sel.last.hijriah.hari, 30);
      for (final SelKalenderHijriah s in b.sel) {
        expect(s.hijriah.bulan, 9);
        expect(s.kolom, inInclusiveRange(0, 6));
      }
      final SelKalenderHijriah? awal = b.selHari(1);
      expect(awal!.hariPenting.first.nama, 'Awal Ramadhan');
      expect(tanggalPendek(awal.masehi), '18-02-2026');
      expect(b.peringatan.length, greaterThanOrEqualTo(3));
    });

    test('Idul Fitri ada di 1 Syawal', () {
      final BulanHijriah b = susunBulanHijriah(1447, 10);
      expect(b.selHari(1)!.adaPeringatan, isTrue);
      expect(b.selHari(1)!.hariPenting.first.nama, 'Idul Fitri');
    });

    test('nama bulan & hari berbahasa Indonesia', () {
      expect(namaBulanHijriah.length, 12);
      expect(namaBulanHijriah[0], 'Muharram');
      expect(namaBulanHijriah[8], 'Ramadhan');
      expect(namaBulanHijriah[11], 'Dzulhijjah');
      expect(namaHariSingkat.length, 7);
      expect(const TanggalHijriah(1448, 4, 2).label, '2 Rabiul Akhir 1448 H');
      expect(hijriahDariMasehi(ujiTanggal)!.label, '2 Rabiul Akhir 1448 H');
    });

    test('bulan tidak wajar ditolak', () {
      expect(() => susunBulanHijriah(1447, 13), throwsArgumentError);
      // Koreksi -1 (mengikuti penetapan resmi yang 1 hari lebih mundur).
      final BulanHijriah koreksi = susunBulanHijriah(1447, 9, koreksiHari: -1);
      expect(tanggalPendek(koreksi.selHari(1)!.masehi), '19-02-2026');
    });
  });

  group('Batas bahasa (bagian III-11 PRD)', () {
    test('teks yang tampil tidak memakai kata terlarang', () {
      final List<String> kumpulanTeks = <String>[
        for (final WaktuSholat w in WaktuSholat.values) ...<String>[w.label, w.keterangan],
        for (final MetodeHitungSholat m in MetodeHitungSholat.values) ...<String>[m.label, m.keterangan],
        for (final ZonaIndonesia z in ZonaIndonesia.values) ...<String>[z.label, z.namaPanjang],
        for (final AcuanHijriah a in AcuanHijriah.values) ...<String>[a.label, a.keterangan],
        for (final HariPentingHijriah h in hariPentingHijriah) ...<String>[h.nama, h.keterangan],
        catatanPenetapan,
        ...namaBulanHijriah,
      ];
      final List<String> terlarang = <String>[
        'skor iman', 'anda gagal', 'kamu', 'berdosa', 'kafir', 'belum sholat',
      ];
      for (final String t in kumpulanTeks) {
        for (final String kata in terlarang) {
          expect(t.toLowerCase().contains(kata), isFalse,
              reason: 'teks "$t" memuat kata terlarang "$kata"');
        }
      }
    });

    test('catatan jujur tersedia untuk ditampilkan', () {
      expect(catatanPenetapan, contains('bukan penetapan resmi'));
      expect(MetodeHitungSholat.kemenag.keterangan, contains('Kementerian Agama'));
    });
  });
}
