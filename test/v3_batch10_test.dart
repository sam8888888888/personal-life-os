/// Uji Batch 10 — FR-98 (kiblat), FR-133 (rumah tangga), FR-134 (perjalanan),
/// FR-135 (jurnal perjalanan), FR-152 (bahasa & kurs).
///
/// Aturan yang dipegang: setiap harapan mengacu ke keluaran nyata; jendela
/// waktu uji boleh dilebarkan, harapan tidak boleh dilonggarkan.
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/ibadah/kiblat.dart';
import 'package:personal_life_os/core/perjalanan/jurnal_perjalanan.dart';
import 'package:personal_life_os/core/perjalanan/perjalanan.dart';
import 'package:personal_life_os/core/platform/kanal_kompas.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/rumah/tanggung_jawab_rumah.dart';
import 'package:personal_life_os/core/sinkron/registri_sinkron.dart';
import 'package:personal_life_os/core/utils/bahasa.dart';
import 'package:personal_life_os/core/utils/kurs.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/jurnal_perjalanan_repository.dart';
import 'package:personal_life_os/data/repository/kurs_repository.dart';
import 'package:personal_life_os/data/repository/masjid_repository.dart';
import 'package:personal_life_os/data/repository/perjalanan_repository.dart';
import 'package:personal_life_os/data/repository/tanggung_jawab_repository.dart';
import 'package:personal_life_os/features/ibadah/kiblat_screen.dart';
import 'package:personal_life_os/features/perjalanan/perjalanan_screen.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

/// Tunggu sampai [syarat] benar (melebarkan jendela waktu, bukan harapan).
Future<void> _tungguSampai(WidgetTester t, bool Function() syarat,
    {int putaran = 40}) async {
  for (var i = 0; i < putaran; i++) {
    if (syarat()) return;
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump(const Duration(milliseconds: 50));
  }
}

void layarTinggi(WidgetTester t) {
  t.view.physicalSize = const Size(1200, 3200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // FR-134 — mesin perjalanan
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-134 mesin perjalanan', () {
    test('anggaran: persen, sisa, dan peringatan lewat anggaran', () {
      final r = ringkasPerjalanan(
        dari: DateTime(2026, 10, 5),
        sampai: DateTime(2026, 10, 12),
        anggaranSen: 5000000, // Rp 50.000
        realisasiSen: 6000000, // Rp 60.000 → lewat 10.000
        sekarang: DateTime(2026, 10, 1),
        items: const [
          ItemPerjalanan(
              jenis: JenisItemPerjalanan.tiket, judul: 'Pesawat', biayaSen: 2000000),
          ItemPerjalanan(
              jenis: JenisItemPerjalanan.bawaan, judul: 'Paspor', selesai: true),
          ItemPerjalanan(jenis: JenisItemPerjalanan.bawaan, judul: 'Sunscreen'),
        ],
      );
      expect(r.persenAnggaran, 120);
      expect(r.sisaAnggaranSen, -1000000);
      expect(r.hariLagi, 4);
      expect(r.jumlahBawaan, 2);
      expect(r.bawaanSiap, 1);
      expect(r.persenBawaan, 50);
      expect(r.rencanaSen, 2000000);
      expect(r.peringatan.first, contains('lewat anggaran'));
    });

    test('anggaran kosong: tidak ditebak, masuk daftar belum bisa', () {
      final r = ringkasPerjalanan(
        dari: DateTime(2026, 10, 5),
        sampai: DateTime(2026, 10, 12),
        anggaranSen: 0,
        sekarang: DateTime(2026, 9, 20),
        items: const [],
      );
      expect(r.persenAnggaran, isNull);
      expect(r.dasarAnggaran, 'Anggaran belum diisi.');
      expect(r.belumBisa.any((b) => b.contains('Anggaran belum diisi')), isTrue);
      expect(r.peringatan.any((p) => p.contains('Keberangkatan')), isFalse);
    });

    test('pengingat keberangkatan hanya untuk waktu yang masih di depan', () {
      final waktu = jadwalPengingatKeberangkatan(
        DateTime(2026, 10, 10),
        sekarang: DateTime(2026, 10, 9, 7),
      );
      // H-7 sudah lewat (3 Okt), H-1 (9 Okt 08:00) & H-0 (10 Okt 08:00) tersisa.
      expect(waktu.length, 2);
      expect(waktu.first, DateTime(2026, 10, 9, 8));
      expect(waktu.last, DateTime(2026, 10, 10, 8));
      // Bila pukul 08:00 di hari H-1 sudah lewat, pengingat H-1 TIDAK
      // dijadwalkan (sisa H-0 saja) — bukan alarm basi.
      expect(
          jadwalPengingatKeberangkatan(DateTime(2026, 10, 10),
              sekarang: DateTime(2026, 10, 9, 9)).length,
          1);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // FR-135 — mesin jurnal
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-135 mesin jurnal', () {
    test('rekap: total, yang sudah masuk keuangan, penilaian, tempat', () {
      final r = rekapJurnal(namaPerjalanan: 'Bali', catatan: [
        CatatanJurnal(
            tanggal: DateTime(2026, 10, 6),
            judul: 'Pantai',
            tempat: 'Kuta',
            penilaian: 5,
            pengeluaranSen: 30000,
            transaksiId: 11,
            jumlahFoto: 2),
        CatatanJurnal(
            tanggal: DateTime(2026, 10, 7),
            judul: 'Makan',
            tempat: 'Kuta',
            penilaian: 3,
            pengeluaranSen: 20000,
            transaksiId: 12),
        CatatanJurnal(tanggal: DateTime(2026, 10, 8), judul: 'Jalan'),
      ]);
      expect(r.jumlahCatatan, 3);
      expect(r.totalPengeluaranSen, 50000);
      expect(r.totalMasukKeuanganSen, 50000);
      expect(r.totalBelumKeuanganSen, 0);
      expect(r.rataPenilaian, 4.0);
      expect(r.tempatTersering, 'Kuta');
      expect(r.jumlahFoto, 2);
      expect(r.dasar, contains('3 catatan'));
    });

    test('pengeluaran tanpa tautan transaksi dilaporkan, bukan disembunyikan',
        () {
      final r = rekapJurnal(namaPerjalanan: 'Bali', catatan: [
        CatatanJurnal(
            tanggal: DateTime(2026, 10, 6),
            judul: 'Taksi',
            pengeluaranSen: 15000),
      ]);
      expect(r.totalBelumKeuanganSen, 15000);
      expect(r.belumBisa.join(' '),
          contains('belum bertautan ke transaksi keuangan'));
    });

    test('penilaian di luar 1-5 dianggap belum dinilai', () {
      final c = CatatanJurnal(
        tanggal: DateTime(2026, 10, 1),
        judul: 'x',
        penilaian: 9,
        pengeluaranSen: 0,
      );
      expect(c.penilaianSah, isNull);
      expect(c.masukKeuangan, isTrue);
    });

    test('kunci transaksi jurnal stabil & idempoten', () {
      expect(idTransaksiJurnal('prj_1', 7), 'jurnal:prj_1:7');
      expect(idTransaksiJurnal('prj_1', 7), idTransaksiJurnal('prj_1', 7));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // FR-133 — mesin rumah tangga
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-133 mesin rumah tangga', () {
    final items = [
      KewajibanRumah(
          nama: 'SPP',
          jumlahSen: 5000000,
          jatuhTempo: DateTime(2026, 9, 25),
          pemilikNama: 'Anak',
          penanggungJawabNama: 'Papi'),
      KewajibanRumah(
          nama: 'Listrik',
          jumlahSen: 3000000,
          jatuhTempo: DateTime(2026, 9, 20),
          penanggungJawabNama: 'Mami',
          lunas: true,
          tanggalBayar: DateTime(2026, 9, 19),
          catatanPelunasan: 'bayar tunai'),
      KewajibanRumah(
          nama: 'Air',
          jumlahSen: 2000000,
          jatuhTempo: DateTime(2026, 10, 30),
          penanggungJawabNama: 'Papi'),
    ];

    test('siapa bayar apa dijumlahkan per penanggung jawab', () {
      final r = ringkasRumahTangga(items, sekarang: DateTime(2026, 9, 22));
      expect(r.totalSen, 10000000);
      expect(r.sudahBayarSen, 3000000);
      expect(r.sisaSen, 7000000);
      expect(r.jumlahLunas, 1);
      final papi = r.perAnggota.firstWhere((a) => a.nama == 'Papi');
      expect(papi.totalSen, 7000000);
      expect(papi.jumlahItem, 2);
      expect(papi.jumlahLunas, 0);
      expect(papi.persenLunas, 0);
      // 'Listrik' sudah lunas & jatuh temponya sudah lewat → tidak masuk
      // daftar "dekat jatuh tempo" (yang ditagih hanya yang belum dibayar).
      expect(r.jatuhTempoDekat(hari: 7).map((i) => i.nama).toList(), ['SPP']);
      expect(r.riwayatPelunasan().single.catatanPelunasan, 'bayar tunai');
      // Ketiga kewajiban di data uji sudah punya penanggung jawab → tidak ada
      // yang perlu dilaporkan "belum bisa".
      expect(r.belumBisa, isEmpty);
    });

    test('kewajiban tanpa penanggung jawab dilaporkan apa adanya', () {
      final r = ringkasRumahTangga([
        KewajibanRumah(
            nama: 'Internet',
            jumlahSen: 400000,
            jatuhTempo: DateTime(2026, 10, 5)),
      ], sekarang: DateTime(2026, 9, 22));
      expect(r.belumBisa.join(' '),
          contains('penanggung jawabnya belum ditentukan'));
    });

    test('pengingat halus: tanpa izin tidak boleh dikirim', () {
      final alasan = alasanTidakBolehDiingatkan(
        items.first,
        sekarang: DateTime(2026, 9, 22, 10),
        persetujuanMenyala: false,
      );
      expect(alasan.any((a) => a.contains('belum diizinkan')), isTrue);
      expect(
        bolehDiingatkan(items.first,
            sekarang: DateTime(2026, 9, 22, 10), persetujuanMenyala: false),
        isFalse,
      );
    });

    test('pengingat halus: dibatasi jam wajar & sekali sehari', () {
      expect(
        alasanTidakBolehDiingatkan(items.first,
            sekarang: DateTime(2026, 9, 22, 4), persetujuanMenyala: true),
        anyElement(contains('jam wajar')),
      );
      final sudah = KewajibanRumah(
        nama: 'SPP',
        jumlahSen: 1,
        jatuhTempo: DateTime(2026, 9, 25),
        diingatkanPada: DateTime(2026, 9, 22, 9),
      );
      expect(
        alasanTidakBolehDiingatkan(sudah,
            sekarang: DateTime(2026, 9, 22, 10), persetujuanMenyala: true),
        anyElement(contains('sekali sehari')),
      );
      expect(
        bolehDiingatkan(items.first,
            sekarang: DateTime(2026, 9, 22, 10), persetujuanMenyala: true),
        isTrue,
      );
    });

    test('teks pengingat halus menyebut nominal & penanggung jawab', () {
      final teks = teksPengingatHalus(items.first, sekarang: DateTime(2026, 9, 22));
      expect(teks, contains('SPP'));
      expect(teks, contains('Rp 50.000'));
      expect(teks, contains('Papi'));
      expect(teks, contains('3 hari lagi'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // FR-98 — kiblat
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-98 kiblat', () {
    test('arah kiblat kota-kota Indonesia mendekati barat-barat laut', () {
      // Jakarta, Surabaya, Medan, Makassar — nilai acuan perhitungan qibla.
      expect(arahKiblatDerajat(-6.2088, 106.8456), closeTo(295.1, 0.6));
      expect(arahKiblatDerajat(-7.2575, 112.7521), closeTo(294.0, 0.6));
      expect(arahKiblatDerajat(3.5952, 98.6722), closeTo(292.8, 0.8));
      expect(arahKiblatDerajat(-5.1477, 119.4327), closeTo(292.7, 0.8));
    });

    test('tanpa sensor: mode mata angin, tanpa angka palsu', () {
      final h = hitungKiblat(lintang: -6.2088, bujur: 106.8456);
      expect(h.kompasSiap, isFalse);
      expect(h.putaranPiringan, isNull);
      expect(h.pesan, contains('Sensor kompas tidak tersedia'));
      expect(h.pesan, contains('Tidak ada angka palsu'));
      expect(h.derajatKiblatBulat, 295);
      expect(h.arahKiblatTeks, 'Barat Laut');
      expect(h.dasar, contains('-6.2088'));
    });

    test('dengan sensor: piringan berputar, akurasi rendah minta kalibrasi', () {
      final h = hitungKiblat(
        lintang: -6.2088,
        bujur: 106.8456,
        headingDerajat: 100,
        akurasiDerajat: 30,
        sensorAda: true,
      );
      expect(h.kompasSiap, isTrue);
      expect(h.putaranPiringan, closeTo(195.1, 0.6));
      expect(h.perluKalibrasi, isTrue);
      expect(h.pesan, contains('Kalibrasi'));
    });

    test('heading di luar 0-360 dianggap sensor tidak melaporkan', () {
      final h = hitungKiblat(
          lintang: 0, bujur: 0, headingDerajat: 999, sensorAda: true);
      expect(h.kompasSiap, isFalse);
    });

    test('arah mata angin & jarak', () {
      expect(arahMataAngin(0), 'Utara');
      expect(arahMataAngin(45), 'Timur Laut');
      expect(arahMataAngin(180), 'Selatan');
      expect(arahMataAngin(359), 'Utara');
      expect(singkatanMataAngin(90), 'T');
      // Jakarta → Bandung ≈ 120 km; arah tenggara.
      final km = jarakKm(-6.2088, 106.8456, -6.9175, 107.6191);
      expect(km, closeTo(118, 8));
      expect(arahKe(-6.2088, 106.8456, -6.9175, 107.6191), closeTo(130, 12));
    });

    test('uraiOverpass: menyaring titik tanpa koordinat & mengurutkan jarak', () {
      const jawaban = '''
{"elements":[
 {"type":"node","lat":-6.20,"lon":106.85,"tags":{"name":"Masjid A"}},
 {"type":"node","lat":-6.19,"lon":106.84,"tags":{"name":"Masjid B"}},
 {"type":"node","tags":{"name":"Tanpa koordinat"}},
 {"type":"node","lat":-6.21,"lon":106.86,"tags":{}}
]}''';
      final daftar =
          uraiOverpass(jawaban, lintang: -6.2088, bujur: 106.8456);
      expect(daftar.length, 3);
      // Menyaring yang tanpa koordinat; yang tanpa nama tetap ditampilkan
      // dengan sebutan jujur, dan urutan mengikuti jarak sebenarnya dari
      // titik pengguna: A (±1,1 km) < tanpa nama (±1,6 km) < B (±2,2 km).
      expect(daftar.first.nama, 'Masjid A');
      expect(daftar[1].nama, 'Masjid (tanpa nama di peta)');
      expect(daftar.last.nama, 'Masjid B');
      expect(daftar.first.jarakKm <= daftar.last.jarakKm, isTrue);
      expect(daftar.first.jarakTeks, contains('km'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // FR-152 — kurs & bahasa
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-152 kurs', () {
    test('urai jawaban open.er-api menjadi Rupiah per unit', () {
      final kurs = kursDariErApi(
        '{"result":"success","time_last_update_utc":"Mon, 22 Sep 2026 00:02:31 +0000",'
        '"rates":{"USD":0.0000615,"MYR":0.0002602}}',
        sekarang: DateTime(2026, 9, 22),
      );
      expect(kurs.nilai('USD')!.round(), 16260);
      expect(kurs.nilai('MYR')!.round(), 3843);
      expect(kurs.nilai('IDR'), 1);
      expect(kurs.teksSumber, contains('open.er-api.com'));
      expect(kurs.teksSumber, contains('22 Sep 2026'));
    });

    test('jawaban rusak ditolak dengan alasan, bukan kurs karangan', () {
      expect(() => kursDariErApi('bukan json'), throwsA(isA<KursGagal>()));
      expect(() => kursDariErApi('{"rates":{}}'), throwsA(isA<KursGagal>()));
    });

    test('konversi: tanpa kurs → alasan jelas; dengan kurs → nilai', () {
      final tanpa = konversiDariSen(1500000, 'USD', kurs: null);
      expect(tanpa.berhasil, isFalse);
      expect(tanpa.alasan, contains('belum pernah diambil'));
      expect(tanpa.teks, contains('Belum bisa dikonversi'));

      final kurs = Kurs(
        perRupiah: const {'IDR': 1, 'USD': 16000},
        sumber: 'uji',
        waktu: DateTime(2026, 9, 22, 10),
      );
      final hasil = konversiDariSen(1600000, 'USD', kurs: kurs); // Rp 16.000
      expect(hasil.nilai, closeTo(1.0, 0.0001));
      expect(hasil.dasar, contains('1 USD = Rp 16.000'));
      expect(konversiDariSen(250000, 'IDR', kurs: kurs).nilai, closeTo(2500, 0.001));
    });

    test('kurs manual diperiksa kewajarannya', () {
      expect(periksaKursManual('USD', 16250), isNull);
      expect(periksaKursManual('USD', 0), contains('lebih dari 0'));
      expect(periksaKursManual('USD', 5), contains('kewajaran'));
      expect(periksaKursManual('IDR', 1), isNull);
    });

    test('kurs bisa disimpan & dibaca kembali (JSON)', () {
      final kurs = Kurs(
        perRupiah: const {'IDR': 1, 'MYR': 3450, 'USD': 16250},
        sumber: 'uji simpan',
        waktu: DateTime(2026, 9, 22, 9, 30),
      );
      final lagi = Kurs.dariJson(jsonEncode(kurs.keJson()))!;
      expect(lagi.perRupiah['USD'], 16250);
      expect(lagi.sumber, 'uji simpan');
      expect(lagi.waktu.hour, 9);
      expect(lagi.teksSumber, contains('diperbarui'));
      expect(lagi.perluDiperbarui(DateTime(2026, 9, 22, 12)), isFalse);
      expect(lagi.perluDiperbarui(DateTime(2026, 9, 25)), isTrue);
      expect(Kurs.dariJson('{rusak'), isNull);
      expect(Kurs.dariJson(null), isNull);
    });
  });

  group('FR-152 bahasa', () {
    test('kamus Bahasa Indonesia/Melayu/Inggris lengkap & berbeda', () {
      expect(jumlahKunciKamus > 40, isTrue);
      for (final kunci in semuaKunciKamus) {
        for (final b in Bahasa.values) {
          pakaiBahasa(b);
          final teks = tr(kunci);
          expect(teks.isNotEmpty, isTrue, reason: '$kunci kosong di ${b.kode}');
          expect(teks, isNot(kunci), reason: '$kunci tidak diterjemahkan');
        }
      }
      pakaiBahasa(Bahasa.indonesia);
      expect(tr('tab.hariIni'), 'Hari Ini');
      pakaiBahasa(Bahasa.inggris);
      expect(tr('tab.hariIni'), 'Today');
      pakaiBahasa(Bahasa.melayu);
      expect(tr('tab.uang'), 'Wang');
      pakaiBahasa(Bahasa.indonesia);
    });

    test('kode bahasa tak dikenal kembali ke Indonesia (tidak error)', () {
      expect(bahasaDariKode('xx'), Bahasa.indonesia);
      expect(bahasaDariKode(null), Bahasa.indonesia);
      expect(bahasaDariKode('EN'), Bahasa.inggris);
      expect(Bahasa.inggris.locale.languageCode, 'en');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Repositori (basis data in-memory)
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-134/135 repositori perjalanan', () {
    test('tambah perjalanan, isi, dan hitung realisasi dari keuangan', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = PerjalananRepository(db, jamSekarang: () => DateTime(2026, 10, 1));
      final id = await repo.tambah(
        nama: 'Bali',
        tujuan: 'Denpasar',
        mulai: DateTime(2026, 10, 5),
        sampai: DateTime(2026, 10, 12),
        anggaranSen: 10000000,
      );
      final p = (await repo.satu(id))!;
      await repo.tambahItem(
        perjalananUid: p.uid!,
        jenis: JenisItemPerjalanan.tiket,
        judul: 'Pesawat',
        biayaSen: 2000000,
      );
      await repo.tambahItem(
        perjalananUid: p.uid!,
        jenis: JenisItemPerjalanan.bawaan,
        judul: 'Paspor',
        selesai: true,
      );
      // Pengeluaran nyata di laporan keuangan, bertaut perjalanan ini.
      await db.into(db.transaksi).insert(TransaksiCompanion.insert(
            idTransaksi: 'trx_prj_1',
            tanggal: DateTime(2026, 10, 6),
            jumlahSen: 3000000,
            perjalananUid: Value(p.uid!),
          ));
      await db.into(db.transaksi).insert(TransaksiCompanion.insert(
            idTransaksi: 'trx_prj_2',
            tanggal: DateTime(2026, 10, 7),
            jumlahSen: 500000,
            jenis: const Value('pemasukan'),
            perjalananUid: Value(p.uid!),
          ));
      final r = await repo.ringkasan(p);
      expect(await repo.realisasiSen(p.uid!), 2500000);
      expect(r.persenAnggaran, 25);
      expect(r.rencanaSen, 2000000);
      expect(r.bawaanSiap, 1);
      expect(r.hariLagi, 4);
      expect(r.peringatan.any((x) => x.contains('Keberangkatan 4 hari')), isTrue);
    });

    test('hapus perjalanan juga menghapus isi & jurnalnya', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = PerjalananRepository(db);
      final jurnal = JurnalPerjalananRepository(db);
      final id = await repo.tambah(
        nama: 'Bandung',
        tujuan: 'Bandung',
        mulai: DateTime(2026, 11, 1),
        sampai: DateTime(2026, 11, 3),
      );
      final p = (await repo.satu(id))!;
      await repo.tambahItem(
          perjalananUid: p.uid!, jenis: JenisItemPerjalanan.agenda, judul: 'Kopi');
      await jurnal.tambah(
        perjalananUid: p.uid!,
        idPerjalanan: p.idPerjalanan,
        tanggal: DateTime(2026, 11, 1),
        judul: 'Sampai',
      );
      await repo.hapus(id);
      expect(await repo.semua(), isEmpty);
      expect(await repo.items(p.uid!), isEmpty);
      expect(await jurnal.daftar(p.uid!), isEmpty);
    });

    test('nama kosong & tanggal terbalik ditolak', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = PerjalananRepository(db);
      expect(
        () => repo.tambah(
            nama: '  ',
            tujuan: 'x',
            mulai: DateTime(2026, 1, 1),
            sampai: DateTime(2026, 1, 2)),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repo.tambah(
            nama: 'x',
            tujuan: 'y',
            mulai: DateTime(2026, 1, 5),
            sampai: DateTime(2026, 1, 2)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('pengeluaran jurnal otomatis jadi transaksi keuangan (tanpa input ulang)',
        () async {
      final db = _db();
      addTearDown(db.close);
      final repo = PerjalananRepository(db);
      final jurnal = JurnalPerjalananRepository(db);
      final id = await repo.tambah(
        nama: 'Jogja',
        tujuan: 'Yogyakarta',
        mulai: DateTime(2026, 12, 1),
        sampai: DateTime(2026, 12, 4),
      );
      final p = (await repo.satu(id))!;
      final idCatatan = await jurnal.tambah(
        perjalananUid: p.uid!,
        idPerjalanan: p.idPerjalanan,
        tanggal: DateTime(2026, 12, 2),
        judul: 'Makan malam',
        tempat: 'Malioboro',
        penilaian: 5,
        pengeluaranSen: 75000,
      );
      final catatan = (await jurnal.daftar(p.uid!)).single;
      expect(catatan.transaksiId, isNotNull);
      final trx = await (db.select(db.transaksi)
            ..where((t) => t.id.equals(catatan.transaksiId!)))
          .getSingle();
      expect(trx.jumlahSen, 75000);
      expect(trx.perjalananUid, p.uid);
      expect(trx.jenis, 'pengeluaran');
      expect(trx.catatan, contains('Makan malam'));
      final kategori = await (db.select(db.kategoriTransaksi)
            ..where((k) => k.kode.equals(JurnalPerjalananRepository.kodeKategoriPerjalanan)))
          .getSingle();
      expect(kategori.nama, 'Perjalanan');
      expect(trx.kategoriId, kategori.id);
      // Anggaran perjalanan melihat pengeluaran itu.
      expect(await repo.realisasiSen(p.uid!), 75000);
      final rekap = await jurnal.rekap(p.uid!, p.nama);
      expect(rekap.totalMasukKeuanganSen, 75000);
      expect(rekap.totalBelumKeuanganSen, 0);
      expect(rekap.rataPenilaian, 5.0);
      expect(await jurnal.uidCatatan(idCatatan), catatan.uid);

      // Hapus catatan → transaksinya ikut hilang (laporan tidak menyimpan uang
      // yang sudah dibatalkan).
      await jurnal.hapus(idCatatan);
      expect(await db.select(db.transaksi).get(), isEmpty);
    });

    test('catatan tanpa pengeluaran tidak membuat transaksi', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = PerjalananRepository(db);
      final jurnal = JurnalPerjalananRepository(db);
      final id = await repo.tambah(
          nama: 'Solo', tujuan: 'Solo',
          mulai: DateTime(2026, 12, 10), sampai: DateTime(2026, 12, 11));
      final p = (await repo.satu(id))!;
      await jurnal.tambah(
        perjalananUid: p.uid!,
        idPerjalanan: p.idPerjalanan,
        tanggal: DateTime(2026, 12, 10),
        judul: 'Jalan pagi',
      );
      expect(await db.select(db.transaksi).get(), isEmpty);
    });
  });

  group('FR-133 repositori rumah tangga', () {
    test('tambah, ringkasan, dan alur izin pengingat', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = TanggungJawabRepository(db, jamSekarang: () => DateTime(2026, 9, 22, 10));
      expect(await repo.persetujuanMenyala(), isFalse);
      await repo.setPersetujuan(true);
      expect(await repo.persetujuanMenyala(), isTrue);

      final id = await repo.tambah(
        nama: 'SPP',
        jumlahSen: 5000000,
        jatuhTempo: DateTime(2026, 9, 25),
        pemilikNama: 'Anak',
        penanggungJawabNama: 'Papi',
      );
      final r = await repo.ringkasan();
      expect(r.items.single.nama, 'SPP');
      expect(r.perAnggota.single.nama, 'Papi');
      await repo.catatDiingatkan(id, DateTime(2026, 9, 22, 10, 5));
      expect((await repo.satu(id))!.diingatkanPada, isNotNull);

      await repo.tandaiLunas(id, catatanPelunasan: 'tunai');
      final sesudah = (await repo.satu(id))!;
      expect(sesudah.lunas, isTrue);
      expect(sesudah.catatanPelunasan, 'tunai');
      expect((await repo.ringkasan()).riwayatPelunasan().single.nama, 'SPP');
      await repo.batalkanLunas(id);
      expect((await repo.satu(id))!.lunas, isFalse);
    });

    test('nama kosong ditolak', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = TanggungJawabRepository(db);
      expect(
        () => repo.tambah(nama: ' ', jumlahSen: 1, jatuhTempo: DateTime(2026, 1, 1)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('FR-98 repositori masjid', () {
    test('tanpa simpanan: pesan jujur, tidak ada daftar karangan', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = MasjidRepository(db);
      final hasil = await repo.dariSimpanan();
      expect(hasil.daftar, isEmpty);
      expect(hasil.dariSimpanan, isTrue);
      expect(hasil.teksAsal, contains('Belum ada daftar masjid'));
    });

    test('gagal jaringan: simpanan lama tetap dipakai + galat dilaporkan',
        () async {
      final db = _db();
      addTearDown(db.close);
      final repo = MasjidRepository(db, jamSekarang: () => DateTime(2026, 9, 22, 8));
      // Simpan dulu satu daftar (meniru hasil sukses sebelumnya).
      await (db.into(db.pengaturan)).insert(PengaturanCompanion.insert(
            kunci: MasjidRepository.kunciSimpanan,
            nilai:
                '{"waktu":"2026-09-21T08:00:00.000","masjid":[{"nama":"Masjid Lama",'
                '"lintang":-6.2,"bujur":106.85,"jarakKm":0.4,"arah":100.0}]}',
          ));
      final hasil = await repo.sekitar(
        lintang: -6.2088,
        bujur: 106.8456,
        batasWaktu: const Duration(milliseconds: 300),
      );
      expect(hasil.daftar.single.nama, 'Masjid Lama');
      expect(hasil.dariSimpanan, isTrue);
      expect(hasil.galat, isNotNull);
      expect(hasil.teksAsal, contains('data tersimpan'));
    });
  });

  group('FR-152 repositori kurs', () {
    test('isi manual tersimpan bersama sumber & waktu', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = KursRepository(db, jamSekarang: () => DateTime(2026, 9, 22, 7, 15));
      final kurs = await repo.isiManual('USD', 16250);
      expect(kurs.nilai('USD'), 16250);
      expect(kurs.sumber, 'diisi manual oleh pengguna');
      final lagi = (await repo.muat())!;
      expect(lagi.nilai('USD'), 16250);
      expect(lagi.teksSumber, contains('diisi manual'));
      expect(lagi.teksSumber, contains('22 Sep 2026 07:15'));
      expect(() => repo.isiManual('USD', 3), throwsA(isA<KursGagal>()));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Skema & sinkron
  // ══════════════════════════════════════════════════════════════════════════
  group('skema v16 & sinkron', () {
    test('basis data baru: skema 16, tabel batch 10 ada, kolom baru ada', () async {
      final db = _db();
      addTearDown(db.close);
      expect(db.schemaVersion, 18);
      final baris = await db.customSelect(
          "SELECT name FROM sqlite_master WHERE type='table'").get();
      final nama = baris.map((r) => r.data['name'] as String).toSet();
      expect(nama.contains('perjalanan'), isTrue);
      expect(nama.contains('item_perjalanan'), isTrue);
      expect(nama.contains('catatan_perjalanan'), isTrue);
      expect(nama.contains('tanggung_jawab_rumah'), isTrue);
      final kolom =
          await db.customSelect('PRAGMA table_info(transaksi)').get();
      expect(kolom.any((k) => k.data['name'] == 'perjalanan_uid'), isTrue);
    });

    test('tabel batch 10 ikut mesin sinkron FR-150 (induk dulu, baru anak)',
        () async {
      final db = _db();
      addTearDown(db.close);
      final jalur = daftarJalurSinkron(db);
      final nama = jalur.map((j) => j.nama).toList();
      expect(nama, contains('perjalanan'));
      expect(nama, contains('item_perjalanan'));
      expect(nama, contains('catatan_perjalanan'));
      expect(nama, contains('tanggung_jawab_rumah'));
      expect(nama.indexOf('perjalanan') < nama.indexOf('item_perjalanan'), isTrue);
      expect(
        jalur.firstWhere((j) => j.nama == 'item_perjalanan').kaitan['perjalanan_uid'],
        'perjalanan',
      );
      expect(
        jalur
            .firstWhere((j) => j.nama == 'catatan_perjalanan')
            .kaitan['perjalanan_uid'],
        'perjalanan',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Layar
  // ══════════════════════════════════════════════════════════════════════════
  group('layar batch 10', () {
    testWidgets('FR-134: layar perjalanan menjelaskan saat masih kosong',
        (t) async {
      layarTinggi(t);
      final db = _db();
      addTearDown(db.close);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: PerjalananScreen()),
      ));
      await _tungguSampai(
          t, () => find.byKey(const Key('perjalanan_kosong')).evaluate().isNotEmpty);
      expect(find.byKey(const Key('perjalanan_kosong')), findsOneWidget);
      expect(find.textContaining('Belum ada'), findsWidgets);
      final tombol = t.widget<FloatingActionButton>(
          find.byKey(const Key('perjalanan_tambah')));
      expect(tombol, isNotNull);
    });

    testWidgets('FR-134: perjalanan yang dibuat muncul dengan ringkasannya',
        (t) async {
      layarTinggi(t);
      final db = _db();
      addTearDown(db.close);
      final repo = PerjalananRepository(db);
      // Layar menghitung "hari lagi" dari jam perangkat, jadi tanggal uji
      // dibuat relatif hari ini (bukan tanggal mati).
      final kini = DateTime.now();
      final hariIni = DateTime(kini.year, kini.month, kini.day);
      await repo.tambah(
        nama: 'Bali',
        tujuan: 'Denpasar',
        mulai: hariIni.add(const Duration(days: 4)),
        sampai: hariIni.add(const Duration(days: 11)),
        anggaranSen: 10000000,
      );
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: PerjalananScreen()),
      ));
      await _tungguSampai(
          t, () => find.textContaining('hari lagi').evaluate().isNotEmpty);
      expect(find.text('Bali'), findsOneWidget);
      expect(find.text('4 hari lagi'), findsOneWidget);
      expect(find.textContaining('Keberangkatan 4 hari lagi.'), findsOneWidget);
      expect(find.textContaining('Anggaran Rp 100.000'), findsWidgets);
    });

    testWidgets('FR-98: layar kiblat menyebut sensor tidak ada (tanpa angka palsu)',
        (t) async {
      layarTinggi(t);
      final db = _db();
      addTearDown(db.close);
      KanalKompas.pakaiTiruan(null);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: KiblatScreen(aliranUji: const Stream.empty())),
      ));
      await _tungguSampai(
          t, () => find.byKey(const Key('kiblat_derajat')).evaluate().isNotEmpty);
      expect(find.byKey(const Key('kiblat_tanpa_sensor')), findsOneWidget);
      expect(find.textContaining('Tidak ada angka palsu'), findsWidgets);
      // Kota bawaan: Jakarta (dipakai untuk hitungan arah).
      expect(find.textContaining('Jakarta'), findsWidgets);
    });

    testWidgets('FR-98: dengan sensor tiruan, arah hadap ditampilkan',
        (t) async {
      layarTinggi(t);
      final db = _db();
      addTearDown(db.close);
      final aliran = StreamController<HeadingKompas?>();
      addTearDown(aliran.close);
      KanalKompas.pakaiTiruan(aliran.stream);
      addTearDown(() => KanalKompas.pakaiTiruan(null));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: KiblatScreen(aliranUji: aliran.stream)),
      ));
      await _tungguSampai(t, () => find.byKey(const Key('kiblat_derajat')).evaluate().isNotEmpty);
      aliran.add(const HeadingKompas(derajat: 100, akurasi: 5));
      await _tungguSampai(t, () => find.textContaining('Arah hadap HP').evaluate().isNotEmpty);
      expect(find.textContaining('Arah hadap HP: 100'), findsOneWidget);
      expect(find.byKey(const Key('kiblat_tanpa_sensor')), findsNothing);
    });
  });
}

