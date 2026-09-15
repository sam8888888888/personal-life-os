/// Uji V2 — modul "Aksi & Tujuan" (FR-78, FR-79, FR-80, FR-83).
///
/// Kriteria terima yang dibuktikan:
/// * FR-78 rantai tujuan -> proyek -> tugas: progres dihitung dari tugas
///   langsung + tugas proyeknya, dan MENGHAPUS tujuan/proyek TIDAK menghapus
///   tugas — tautannya saja yang dilepas (proyek_id / tujuan_id jadi null);
/// * FR-79 "Tugas cepat": tugas berdiri sendiri tanpa proyek, muncul di daftar
///   tugas cepat hari ini, dan bisa disimpan dalam dua ketukan;
/// * FR-80 mesin kebiasaan: promosi ke Hari Ini paling banyak 5 (yang ke-6
///   ditolak tanpa mengubah data), catatan harian 0..1 (setengah diizinkan),
///   ringkasan 7/30 hari bersifat netral (tanpa skor/hukuman);
/// * FR-83 perawatan berkala: 6 template bawaan ada, jadwal berikutnya =
///   terakhir dilakukan + interval, dan "sudah dilakukan hari ini" menggeser
///   jadwal serta menyorot yang jatuh tempo <= 30 hari;
/// * keadaan kosong menulis "Belum ada data" (bukan 0 yang menyesatkan);
/// * bahasa aman pasal III-11 (tanpa kata kamu, gagal, skor, berdosa, malas,
///   rajin, "wajib anda", "belum sholat", diagnosis).
///
/// Waktu uji dikunci: "sekarang" = Selasa, 15 September 2026 08.00
/// (`pakaiSumberWaktu`), sehingga tanggal tidak berubah mengikuti jam mesin.
///
/// Catatan pola: data uji disiapkan di `setUp`/sebelum `pumpWidget`, dan di
/// dalam `testWidgets` hasilnya diperiksa lewat tampilan (tanpa `await`
/// langsung ke database setelah layar dirender).
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/core/utils/tanggal_utils.dart';
import 'package:personal_life_os/core/utils/waktu.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/aksi_repository.dart';
import 'package:personal_life_os/data/repository/kebiasaan_repository.dart';
import 'package:personal_life_os/data/repository/perawatan_repository.dart';
import 'package:personal_life_os/features/aksi/aksi_hub_screen.dart';
import 'package:personal_life_os/features/aksi/kebiasaan_screen.dart';
import 'package:personal_life_os/features/aksi/perawatan_screen.dart';
import 'package:personal_life_os/features/aksi/tugas_screen.dart';
import 'package:personal_life_os/features/aksi/tujuan_screen.dart';

late AppDatabase db;
late AksiRepository aksi;
late KebiasaanRepository kebiasaan;
late PerawatanRepository perawatan;

/// Waktu patok uji: Selasa, 15 September 2026 08.00.
final jamUji = DateTime(2026, 9, 15, 8, 0);

/// Tanggal relatif terhadap hari uji (0 = hari ini).
DateTime hari(int selisih) => DateTime(2026, 9, 15).add(Duration(days: selisih));

/// Kata yang dilarang pasal III-11 (plus kata menghakimi sejenis).
const List<String> kataTerlarang = <String>[
  'kamu',
  'gagal',
  'skor',
  'berdosa',
  'malas',
  'rajin',
  'wajib anda',
  'belum sholat',
  'diagnos',
  'hukuman',
  'penalti',
  'pujian',
];

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    // Kunci waktu lebih dulu: seed perawatan & semua tulisan memakai ini.
    pakaiSumberWaktu(() => jamUji);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    aksi = AksiRepository(db);
    kebiasaan = KebiasaanRepository(db);
    perawatan = PerawatanRepository(db);
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() async {
    pakaiWaktuAsli();
    await db.close();
  });

  /// Hapus 6 baris perawatan hasil seed supaya angka uji bersih.
  Future<void> kosongkanPerawatan() async {
    for (final p in await perawatan.ambilSemua()) {
      await perawatan.hapus(p.id);
    }
  }

  // =========================================================================
  // FR-78 — Tujuan -> Proyek -> Tugas
  // =========================================================================

  group('FR-78 tujuan, proyek, tugas', () {
    test('(a) progres tujuan = tugas langsung + tugas proyeknya', () async {
      final t = await aksi.simpanTujuan(
        nama: 'Rapikan keuangan',
        area: 'keuangan',
        targetAngka: 12,
        satuan: 'bulan',
      );
      final p = await aksi.simpanProyek(
        tujuanId: t.id,
        nama: 'Dana darurat',
        tenggat: hari(90),
      );

      // Dua tugas proyek selesai, satu belum.
      final t1 = await aksi.simpanTugas(nama: 'Hitung pengeluaran', proyekId: p.id);
      await aksi.simpanTugas(nama: 'Buka rekening', proyekId: p.id);
      await aksi.simpanTugas(nama: 'Pasang transfer otomatis', proyekId: p.id);
      await aksi.tandaiSelesai(t1.id);

      // Satu tugas langsung di tujuan, belum selesai.
      await aksi.simpanTugas(nama: 'Baca buku keuangan', tujuanId: t.id);

      // Tugas berdiri sendiri + tugas tujuan lain: TIDAK ikut dihitung.
      await aksi.simpanTugasCepat('Telepon tukang servis');
      final lain = await aksi.simpanTujuan(nama: 'Belajar bahasa', area: 'pribadi');
      await aksi.simpanTugas(nama: 'Hafal 10 kata', tujuanId: lain.id);

      final progres = await aksi.progresTujuan(t.id);
      expect(progres.totalTugas, 4);
      expect(progres.tugasSelesai, 1);
      expect(progres.totalProyek, 1);
      expect(progres.proyekSelesai, 0);
      expect(progres.persen, 25);
      expect(progres.adaTugas, isTrue);

      // Tujuan tanpa tugas: persen 0 TAPI adaTugas false (layar menulis
      // "Belum ada tugas", bukan "0%").
      final kosong = await aksi.progresTujuan(lain.id);
      expect(kosong.totalTugas, 1);
      final tanpaTugas = await aksi.simpanTujuan(nama: 'Belajar gitar', area: 'pribadi');
      final progresKosong = await aksi.progresTujuan(tanpaTugas.id);
      expect(progresKosong.totalTugas, 0);
      expect(progresKosong.persen, 0);
      expect(progresKosong.adaTugas, isFalse);

      // Ringkasan target jujur: angka + satuan ikut terbaca.
      final tersimpan = await aksi.ambilTujuanSatu(t.id);
      expect(AksiRepository.ringkasTarget(tersimpan!), '12 bulan');
      final teksKosong = await aksi.ambilTujuanSatu(tanpaTugas.id);
      expect(AksiRepository.ringkasTarget(teksKosong!), 'Tanpa target angka');
    });

    test('(b) jumlah tugas per proyek dihitung benar', () async {
      final p1 = await aksi.simpanProyek(nama: 'Proyek A');
      final p2 = await aksi.simpanProyek(nama: 'Proyek B');
      final a = await aksi.simpanTugas(nama: 'Satu', proyekId: p1.id);
      await aksi.simpanTugas(nama: 'Dua', proyekId: p1.id);
      await aksi.simpanTugas(nama: 'Tiga', proyekId: p1.id);
      await aksi.tandaiSelesai(a.id);
      await aksi.simpanTugas(nama: 'Empat', proyekId: p2.id);
      // Tugas tanpa proyek tidak dihitung.
      await aksi.simpanTugasCepat('Tugas lepas');

      final peta = await aksi.jumlahTugasPerProyek();
      expect(peta[p1.id]!.total, 3);
      expect(peta[p1.id]!.selesai, 1);
      expect(peta[p1.id]!.persen, 33);
      expect(peta[p2.id]!.total, 1);
      expect(peta[p2.id]!.selesai, 0);
      expect(peta[p2.id]!.persen, 0);
      expect(peta.length, 2);
    });

    test('(c) hapus tujuan TIDAK menghapus tugas & proyek', () async {
      final t = await aksi.simpanTujuan(nama: 'Renovasi dapur',
        area: 'keluarga');
      final p = await aksi.simpanProyek(tujuanId: t.id, nama: 'Ganti keramik');
      final tugasProyek =
          await aksi.simpanTugas(nama: 'Ukur lantai', proyekId: p.id);
      final tugasLangsung =
          await aksi.simpanTugas(nama: 'Hubungi tukang', tujuanId: t.id);

      final jumlahTerhapus = await aksi.hapusTujuan(t.id);
      expect(jumlahTerhapus, 1);
      expect(await aksi.ambilTujuanSatu(t.id), isNull, reason: 'Tujuan harus terhapus.');
      expect(await aksi.ambilTujuan(), isEmpty);

      // Proyek masih ada, tautannya dilepas.
      final proyekSisa = await aksi.ambilProyekSatu(p.id);
      expect(proyekSisa, isNotNull, reason: 'Proyek tidak boleh ikut terhapus.');
      expect(proyekSisa!.tujuanId, isNull);
      expect(proyekSisa.nama, 'Ganti keramik');

      // Kedua tugas masih ada; tugas proyek tetap menempel ke proyeknya.
      final sisa = await aksi.ambilTugas();
      expect(sisa.length, 2, reason: 'Tugas tidak boleh ikut terhapus.');
      final dariProyek = sisa.firstWhere((g) => g.id == tugasProyek.id);
      expect(dariProyek.proyekId, p.id);
      expect(dariProyek.tujuanId, isNull);
      final langsung = sisa.firstWhere((g) => g.id == tugasLangsung.id);
      expect(langsung.proyekId, isNull);
      expect(langsung.tujuanId, isNull);
      expect(langsung.selesai, isFalse);
    });

    test('(d) hapus proyek TIDAK menghapus tugas (proyek_id jadi null)', () async {
      final t = await aksi.simpanTujuan(nama: 'Kursus online', area: 'pribadi');
      final p = await aksi.simpanProyek(tujuanId: t.id, nama: 'Modul dasar');
      final g = await aksi.simpanTugas(nama: 'Tonton bab 1', proyekId: p.id);

      expect(await aksi.hapusProyek(p.id), 1);
      expect(await aksi.ambilProyekSatu(p.id), isNull);
      expect(await aksi.ambilProyek(), isEmpty);

      final sisa = await aksi.ambilTugas();
      expect(sisa.length, 1, reason: 'Tugas tidak boleh ikut terhapus.');
      expect(sisa.single.id, g.id);
      expect(sisa.single.proyekId, isNull);
      expect(sisa.single.tujuanId, t.id, reason: 'Tautan tujuan tetap utuh.');
      expect(await aksi.ambilTujuanSatu(t.id), isNotNull);
    });

    test('(e) validasi tujuan & status tercapai mengisi selesai_pada', () async {
      expect(
        () => aksi.simpanTujuan(nama: '   ', area: 'pribadi'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => aksi.simpanTujuan(nama: 'Uji', area: 'entah'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => aksi.simpanTujuan(nama: 'Uji', status: 'entah'),
        throwsA(isA<ArgumentError>()),
      );

      final t = await aksi.simpanTujuan(
        nama: 'Turun 4 kg',
        area: 'kesehatan',
        targetAngka: 4,
        satuan: 'kg',
        tanggalTarget: hari(30),
      );
      expect(t.status, 'aktif');
      expect(t.selesaiPada, isNull);

      final tercapai = await aksi.ubahStatusTujuan(t.id, 'tercapai');
      expect(tercapai.status, 'tercapai');
      expect(tercapai.selesaiPada, isNotNull);
      expect(await aksi.ambilTujuan(status: 'tercapai'), hasLength(1));
      expect(await aksi.ambilTujuan(status: 'aktif'), isEmpty);

      final dijeda = await aksi.ubahStatusTujuan(t.id, 'dijeda');
      expect(dijeda.status, 'dijeda');
      expect(await aksi.ambilTujuan(status: 'aktif'), isEmpty);

      // Kalimat tanggal target bersifat laporan, tanpa menegur.
      expect(AksiRepository.teksTanggalTarget(hari(30), jamUji), 'Sisa 30 hari');
      expect(AksiRepository.teksTanggalTarget(hari(1), jamUji), 'Besok');
      expect(AksiRepository.teksTanggalTarget(hari(0), jamUji), 'Hari ini');
      expect(AksiRepository.teksTanggalTarget(hari(-3), jamUji),
          '3 hari setelah tanggal target');
      expect(AksiRepository.teksTanggalTarget(null, jamUji),
          'Tanpa tanggal target');
    });
  });

  // =========================================================================
  // FR-79 — Tugas cepat
  // =========================================================================

  group('FR-79 tugas cepat', () {
    test('tugas cepat berdiri sendiri & hanya hari ini yang masuk daftar',
        () async {
      final sekarang = await aksi.simpanTugasCepat('Telepon tukang servis');
      expect(sekarang.proyekId, isNull);
      expect(sekarang.tujuanId, isNull);
      expect(sekarang.selesai, isFalse);

      await aksi.simpanTugasCepat('Belanja sabun', jatuhTempo: hari(1));
      final tanpaTanggal = await aksi.simpanTugasCepat('Tulis ide artikel');
      final besok = await aksi.simpanTugasCepat('Bayar listrik', jatuhTempo: hari(2));
      await aksi.simpanTugasCepat('Lewat sudah', jatuhTempo: hari(-4));
      final telat = await aksi.simpanTugasCepat('Telat tapi belum selesai', jatuhTempo: hari(-1));

      // Tugas lengkap (punya proyek) bukan tugas cepat.
      final p = await aksi.simpanProyek(nama: 'Proyek rumah');
      await aksi.simpanTugas(nama: 'Beli cat', proyekId: p.id, jatuhTempo: hari(0));

      // Tugas cepat yang sudah selesai keluar dari daftar.
      final selesaiCepat = await aksi.simpanTugasCepat('Matikan lampu');
      await aksi.tandaiSelesai(selesaiCepat.id);

      final daftar = await aksi.tugasCepatHariIni();
      final nama = daftar.map((t) => t.nama).toList();
      expect(nama.contains('Telepon tukang servis'), isTrue,
          reason: 'Tugas cepat hari ini harus muncul.');
      expect(nama.contains('Telat tapi belum selesai'), isTrue,
          reason: 'Jatuh tempo yang sudah lewat tetap ditampilkan apa adanya.');
      expect(nama.contains('Tulis ide artikel'), isTrue,
          reason: 'Tanpa tanggal berarti masih berlaku hari ini.');
      expect(nama.contains('Lewat sudah'), isTrue,
          reason: 'Tugas cepat yang tanggalnya sudah lewat tetap berlaku '
              'sampai ditandai selesai.');
      expect(nama.contains('Belanja sabun'), isFalse,
          reason: 'Jatuh tempo besok tidak masuk daftar hari ini.');
      expect(nama.contains('Beli cat'), isFalse,
          reason: 'Tugas berproyek bukan tugas cepat.');
      expect(nama.contains('Matikan lampu'), isFalse,
          reason: 'Tugas selesai tidak lagi didaftarkan.');
      expect(daftar.every((t) => t.proyekId == null && t.tujuanId == null), isTrue);
      expect(sekarang.id, isNot(tanpaTanggal.id));
      expect(besok.jatuhTempo, hari(2));
      expect(telat.jatuhTempo, hari(-1));
    });
  });

  // =========================================================================
  // FR-80 — Mesin kebiasaan
  // =========================================================================

  group('FR-80 kebiasaan', () {
    test('(a) promosi paling banyak 5; yang ke-6 ditolak tanpa ubah data',
        () async {
      expect(KebiasaanRepository.maksDipromosikan, 5);
      final daftar = <KebiasaanData>[];
      for (var i = 0; i < 6; i++) {
        daftar.add(await kebiasaan.simpan(
          nama: 'Kebiasaan $i',
          targetPerMinggu: 7,
          urutan: i,
        ));
      }
      for (var i = 0; i < 5; i++) {
        expect(await kebiasaan.setDipromosikan(daftar[i].id, true), isTrue);
      }
      expect(await kebiasaan.jumlahDipromosikan(), 5);

      // Ke-6: ditolak, data tidak berubah.
      expect(await kebiasaan.setDipromosikan(daftar[5].id, true), isFalse);
      expect(await kebiasaan.jumlahDipromosikan(), 5);
      final keenam = await (db.select(db.kebiasaan)
            ..where((k) => k.id.equals(daftar[5].id)))
          .getSingle();
      expect(keenam.dipromosikan, isFalse);
      expect(await kebiasaan.ambilDipromosikan(), hasLength(5));

      // Matikan satu, slot ke-6 jadi tersedia.
      expect(await kebiasaan.setDipromosikan(daftar[0].id, false), isTrue);
      expect(await kebiasaan.setDipromosikan(daftar[5].id, true), isTrue);
      expect(await kebiasaan.jumlahDipromosikan(), 5);

      // Menyalakan ulang yang sudah menyala tidak menambah kuota.
      expect(await kebiasaan.setDipromosikan(daftar[5].id, true), isTrue);
      expect(await kebiasaan.jumlahDipromosikan(), 5);
    });

    test('(b) catatan harian: satu baris per hari, nilai dijepit 0..1',
        () async {
      final k = await kebiasaan.simpan(nama: 'Minum air', targetPerMinggu: 7);

      await kebiasaan.catat(k.id, jamUji, 0.5);
      expect((await kebiasaan.logHari(k.id, jamUji))!.nilai, 0.5,
          reason: 'Setengah hari harus diizinkan.');

      // Menyimpan lagi di hari yang sama = memperbarui, bukan menambah baris.
      await kebiasaan.catat(k.id, DateTime(2026, 9, 15, 21, 30), 1.0);
      final semua = await (db.select(db.logKebiasaan)).get();
      expect(semua, hasLength(1));
      expect(semua.single.nilai, 1.0);
      expect(semua.single.tanggal, hari(0),
          reason: 'Tanggal disimpan sebagai hari saja.');

      // Nilai di luar 0..1 dijepit.
      await kebiasaan.catat(k.id, hari(-1), 3.0);
      expect((await kebiasaan.logHari(k.id, hari(-1)))!.nilai, 1.0);
      await kebiasaan.catat(k.id, hari(-2), -5.0);
      expect((await kebiasaan.logHari(k.id, hari(-2)))!.nilai, 0.0);

      final peta = await kebiasaan.nilaiHari(hari(0));
      expect(peta[k.id], 1.0);
      expect((await kebiasaan.nilaiHari(hari(-9))).containsKey(k.id), isFalse);
    });

    test('(c) ringkasan 7 & 30 hari bersifat laporan, tanpa skor', () async {
      final k = await kebiasaan.simpan(nama: 'Jalan pagi', targetPerMinggu: 5);
      await kebiasaan.catat(k.id, hari(0), 1.0);
      await kebiasaan.catat(k.id, hari(-1), 0.5);
      await kebiasaan.catat(k.id, hari(-3), 1.0);
      await kebiasaan.catat(k.id, hari(-8), 1.0); // di luar 7 hari, di dalam 30

      final r7 = await kebiasaan.ringkasan(k.id, hari: 7);
      expect(r7.jumlahHari, 7);
      expect(r7.hariTercatat, 3);
      expect(r7.hariPenuh, 2);
      expect(r7.totalNilai, 2.5);

      final r30 = await kebiasaan.ringkasan(k.id, hari: 30);
      expect(r30.jumlahHari, 30);
      expect(r30.hariTercatat, 4);
      expect(r30.hariPenuh, 3);
      expect(r30.totalNilai, 3.5);

      // Kebiasaan tanpa catatan tetap punya baris ringkasan berisi nol.
      final k2 = await kebiasaan.simpan(nama: 'Baca buku');
      final semua = await kebiasaan.ringkasanSemua(hari: 7);
      expect(semua[k2.id]!.hariTercatat, 0);
      expect(semua[k2.id]!.totalNilai, 0);
      expect(semua.length, 2);

      // Ringkasan kosong tidak menghakimi: hanya angka hari.
      final kosong = RingkasanKebiasaan.kosong(7);
      expect(kosong.hariTercatat, 0);
      expect(kosong.jumlahHari, 7);
    });

    test('(d) menghapus kebiasaan ikut membuang catatannya', () async {
      final k = await kebiasaan.simpan(nama: 'Dzikir pagi');
      await kebiasaan.catat(k.id, hari(0), 1.0);
      await kebiasaan.catat(k.id, hari(-1), 0.5);
      expect(await (db.select(db.logKebiasaan)).get(), hasLength(2));

      expect(await kebiasaan.hapus(k.id), 1);
      expect(await kebiasaan.ambilSemua(), isEmpty);
      expect(await (db.select(db.logKebiasaan)).get(), isEmpty);
      expect(await kebiasaan.logHari(k.id, hari(0)), isNull);
    });
  });

  // =========================================================================
  // FR-83 — Perawatan berkala
  // =========================================================================

  group('FR-83 perawatan berkala', () {
    test('(a) enam template bawaan sudah ter-seed + hitungan murni', () async {
      final template = await perawatan.ambilTemplateBawaan();
      expect(template, hasLength(6));
      expect(
        template.map((p) => p.templateKode).toList(),
        PerawatanRepository.kodeTemplateBawaan,
      );
      expect(template.every((p) => p.intervalHari >= 1), isTrue);
      expect(template.every((p) => p.aktif), isTrue, reason: 'Seed aktif.');
      // Jadwal seed = hari pembuatan + interval.
      for (final p in template) {
        expect(p.berikutnya, hari(p.intervalHari));
      }

      // Hitungan murni (tanpa I/O): berikutnya = dilakukan + interval.
      expect(PerawatanRepository.hitungBerikutnya(hari(0), 30), hari(30));
      expect(PerawatanRepository.hitungBerikutnya(hari(0), 1), hari(1));
      expect(PerawatanRepository.hitungBerikutnya(hari(0), 0), hari(0),
          reason: 'Interval tidak boleh memundurkan tanggal.');

      final contoh = template.firstWhere((p) => p.templateKode == 'cadangan_data');
      expect(PerawatanRepository.sisaHari(contoh, jamUji), 30);
      expect(PerawatanRepository.kunciJatuhTempo(contoh), 'dekat');
      final pajak = template.firstWhere((p) => p.templateKode == 'pajak_kendaraan');
      expect(PerawatanRepository.sisaHari(pajak, jamUji), 365);
      expect(PerawatanRepository.kunciJatuhTempo(pajak), 'jauh');
    });

    test('(b) sudah dilakukan hari ini menggeser jadwal sejauh interval',
        () async {
      await kosongkanPerawatan();
      final p = await perawatan.simpan(nama: 'Servis AC', intervalHari: 90);
      expect(p.terakhirDilakukan, isNull);
      expect(p.berikutnya, hari(90));

      final sesudah = await perawatan.tandaiDilakukan(p.id);
      // Kolom terakhir_dilakukan menyimpan waktu aksi apa adanya; jadwal
      // berikutnya selalu tanggal hari-saja.
      expect(AksiRepository.hariSaja(sesudah.terakhirDilakukan!), hari(0));
      expect(sesudah.berikutnya, hari(90));

      // Mengerjakan mundur (mis. baru dicatat) tetap dihitung dari tanggal itu.
      final mundur = await perawatan.tandaiDilakukan(p.id, kapan: hari(-5));
      expect(mundur.terakhirDilakukan, hari(-5));
      expect(mundur.berikutnya, hari(85));
      expect(PerawatanRepository.sisaHari(mundur, jamUji), 85);

      expect(
        () => perawatan.simpan(nama: '   ', intervalHari: 10),
        throwsA(isA<ArgumentError>()),
        reason: 'Nama kosong tidak boleh dipakai sebagai nama perawatan.',
      );
      expect(
        () => perawatan.simpan(nama: 'Interval nol', intervalHari: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('(c) sorotan jatuh tempo: termasuk yang sudah lewat, nonaktif lewat',
        () async {
      await kosongkanPerawatan();
      final a = await perawatan.simpan(
          nama: 'Terlambat 4 hari', intervalHari: 30, berikutnya: hari(-4));
      final b = await perawatan.simpan(
          nama: 'Hari ini', intervalHari: 7, berikutnya: hari(0));
      final c = await perawatan.simpan(
          nama: 'Sepuluh hari lagi', intervalHari: 30, berikutnya: hari(10));
      await perawatan.simpan(
          nama: 'Tepat 30 hari', intervalHari: 30, berikutnya: hari(30));
      await perawatan.simpan(
          nama: 'Tiga puluh satu hari', intervalHari: 60, berikutnya: hari(31));
      await perawatan.simpan(
          nama: 'Nonaktif', intervalHari: 30, berikutnya: hari(5), aktif: false);

      final sorot = await perawatan.sorotanJatuhTempo();
      expect(sorot, hasLength(4));
      expect(sorot.map((p) => p.nama).toList(), [
        'Terlambat 4 hari',
        'Hari ini',
        'Sepuluh hari lagi',
        'Tepat 30 hari',
      ], reason: 'Urut dari yang paling dekat, termasuk yang sudah lewat.');

      expect(PerawatanRepository.sisaHari(a, jamUji), -4);
      expect(PerawatanRepository.kunciJatuhTempo(a), 'terlambat');
      expect(PerawatanRepository.kunciJatuhTempo(b), 'hari_ini');
      expect(PerawatanRepository.kunciJatuhTempo(c), 'dekat');
      expect(PerawatanRepository.maksSorotanHari, 30);

      // Batas bisa digeser; yang nonaktif tetap tidak ikut.
      final lebar = await perawatan.sorotanJatuhTempo(maksHari: 31);
      expect(lebar, hasLength(5));
      expect(lebar.every((p) => p.aktif), isTrue);
    });
  });

  // =========================================================================
  // Layar (widget)
  // =========================================================================

  group('layar Aksi', () {
    Future<void> tampilkan(WidgetTester t, Widget layar) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
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

    /// Gulir daftar supaya kunci tertentu ikut dibangun.
    Future<void> gulirSampai(WidgetTester t, Key kunci) async {
      final cari = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      for (var i = 0; i < 16; i++) {
        if (find.byKey(kunci).evaluate().isNotEmpty) return;
        if (cari.evaluate().isEmpty) return;
        final pos = t.state<ScrollableState>(cari.first).position;
        if (pos.pixels >= pos.maxScrollExtent) return;
        pos.jumpTo((pos.pixels + 240).clamp(0.0, pos.maxScrollExtent));
        await t.pump(const Duration(milliseconds: 60));
      }
    }

    Future<void> tekan(WidgetTester t, Finder target) async {
      await t.ensureVisible(target);
      await t.pump(const Duration(milliseconds: 120));
      await t.tap(target);
      await t.pump(const Duration(milliseconds: 200));
      await t.pump(const Duration(milliseconds: 300));
    }

    String? teksKunci(WidgetTester t, Key kunci) {
      final f = find.byKey(kunci);
      if (f.evaluate().isEmpty) return null;
      return t.widget<Text>(f).data;
    }

    testWidgets('(a) halaman masuk: empat pintu + angka apa adanya',
        (t) async {
      // Satu tujuan aktif (satu lagi tercapai), satu proyek, dua tugas belum
      // selesai (satu jatuh tempo hari ini), dua kebiasaan dipromosikan,
      // satu perawatan jatuh tempo.
      final t1 = await aksi.simpanTujuan(nama: 'Rapikan keuangan', area: 'keuangan');
      await aksi.simpanTujuan(nama: 'Lulus kursus', area: 'pribadi', status: 'tercapai');
      final p1 = await aksi.simpanProyek(tujuanId: t1.id, nama: 'Dana darurat');
      await aksi.simpanTugas(nama: 'Hitung pengeluaran', proyekId: p1.id,
          jatuhTempo: hari(0));
      await aksi.simpanTugas(nama: 'Buka rekening', tujuanId: t1.id);
      final selesai = await aksi.simpanTugas(nama: 'Sudah beres', proyekId: p1.id);
      await aksi.tandaiSelesai(selesai.id);
      await kebiasaan.simpan(nama: 'Minum air', dipromosikan: true, urutan: 0);
      await kebiasaan.simpan(nama: 'Jalan pagi', dipromosikan: true, urutan: 1);
      await kebiasaan.simpan(nama: 'Baca buku', urutan: 2);
      await kosongkanPerawatan();
      await perawatan.simpan(nama: 'Servis AC', intervalHari: 180, berikutnya: hari(5));
      await perawatan.simpan(nama: 'Pajak kendaraan', intervalHari: 365,
          berikutnya: hari(200));

      await tampilkan(t, const AksiHubScreen());
      for (final kunci in const [
        'buka_tujuan',
        'buka_tugas',
        'buka_kebiasaan',
        'buka_perawatan',
      ]) {
        expect(find.byKey(Key(kunci)), findsOneWidget, reason: 'Pintu $kunci ada.');
      }
      expect(teksKunci(t, const Key('ringkas_tujuan')),
          '1 tujuan aktif · 1 proyek');
      expect(teksKunci(t, const Key('ringkas_tugas')),
          '2 belum selesai · 1 jatuh tempo hari ini');
      expect(teksKunci(t, const Key('ringkas_kebiasaan')),
          '2 dari 5 kebiasaan tampil di Hari Ini');
      expect(teksKunci(t, const Key('ringkas_perawatan')),
          '1 jatuh tempo dalam 30 hari');

      // Pintu Tujuan benar-benar membuka layar Tujuan.
      await tekan(t, find.byKey(const Key('buka_tujuan')));
      await t.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.byType(TujuanScreen), findsOneWidget);
      await tutup(t);
    });

    testWidgets('(b) tujuan: kosong menulis "Belum ada data", lalu bisa ditambah',
        (t) async {
      await tampilkan(t, const TujuanScreen());
      expect(find.byKey(const Key('tujuan_kosong')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('tujuan_kosong'))).data,
          'Belum ada data');

      await tekan(t, find.byKey(const Key('tombol_tujuan_baru')));
      await t.enterText(
          find.byKey(const Key('form_nama_tujuan')), 'Belajar bahasa Inggris');
      await t.enterText(find.byKey(const Key('form_target_angka')), '12');
      await t.enterText(find.byKey(const Key('form_satuan_tujuan')), 'bulan');
      await tekan(t, find.byKey(const Key('simpan_tujuan')));

      expect(find.text('Belajar bahasa Inggris'), findsOneWidget);
      expect(find.text('Pribadi · 12 bulan'), findsOneWidget);
      expect(find.text('Belum ada tugas di tujuan ini'), findsOneWidget,
          reason: 'Tujuan tanpa tugas dilaporkan apa adanya, bukan "0%".');
      expect(find.byKey(const Key('tujuan_kosong')), findsNothing);
      await tutup(t);
    });

    testWidgets('(c) tugas: tugas cepat tersimpan dalam dua ketukan',
        (t) async {
      await tampilkan(t, const TugasScreen());
      expect(find.byKey(const Key('tugas_cepat_kosong')), findsOneWidget);

      // Ketukan 1: buka lembar. Ketukan 2: tulis nama lalu Simpan.
      await tekan(t, find.byKey(const Key('tombol_tugas_cepat')));
      expect(find.byKey(const Key('form_nama_cepat')), findsOneWidget);
      await t.enterText(
          find.byKey(const Key('form_nama_cepat')), 'Telepon tukang servis');
      await tekan(t, find.byKey(const Key('simpan_tugas_cepat')));

      expect(find.text('Telepon tukang servis'), findsOneWidget);
      expect(find.byKey(const Key('tugas_cepat_kosong')), findsNothing,
          reason: 'Daftar tugas cepat hari ini terisi.');

      // Menandai selesai mengeluarkan tugas dari daftar "Belum selesai".
      await tekan(t, find.byType(Checkbox).first);
      expect(find.text('Telepon tukang servis'), findsNothing);
      expect(find.byKey(const Key('tugas_cepat_kosong')), findsOneWidget);
      await tutup(t);
    });

    testWidgets('(d) kebiasaan: promosi ke-6 ditolak dengan pesan kuota penuh',
        (t) async {
      final daftar = <KebiasaanData>[];
      for (var i = 0; i < 6; i++) {
        daftar.add(await kebiasaan.simpan(
          nama: 'Kebiasaan $i',
          dipromosikan: i < 5,
          urutan: i,
        ));
      }
      expect(await kebiasaan.jumlahDipromosikan(), 5);

      await tampilkan(t, const KebiasaanScreen());
      final saklar = Key('saklar_promosi_${daftar[5].id}');
      await gulirSampai(t, saklar);
      await tekan(t, find.byKey(saklar));

      expect(find.text(KebiasaanRepository.pesanPenuh), findsOneWidget,
          reason: 'Kuota penuh harus dijelaskan, bukan diam-diam ditolak.');
      // Saklar kembali mati: baris kelima tetap satu-satunya sumber angka
      // (perubahan data dibuktikan di uji repositori bagian (a)).
      final saklarTerakhir = t.widget<Switch>(find.byKey(saklar));
      expect(saklarTerakhir.value, isFalse);
      await tutup(t);
    });

    testWidgets('(e) kebiasaan: catat setengah hari terbaca di ringkasan',
        (t) async {
      final k = await kebiasaan.simpan(nama: 'Minum air', targetPerMinggu: 7);
      await tampilkan(t, const KebiasaanScreen());

      final setengah = Key('catat_setengah_${k.id}');
      await gulirSampai(t, setengah);
      await tekan(t, find.byKey(setengah));
      expect(find.text('7 hari terakhir: 1 dari 7 hari tercatat'), findsOneWidget);
      expect(find.text('30 hari terakhir: 1 dari 30 hari tercatat'), findsOneWidget);
      expect(find.text('Hari ini tercatat setengah jalan.'), findsOneWidget);

      // Mencatat penuh di hari yang sama tidak menggandakan hari.
      final penuh = Key('catat_penuh_${k.id}');
      await gulirSampai(t, penuh);
      await tekan(t, find.byKey(penuh));
      expect(find.text('7 hari terakhir: 1 dari 7 hari tercatat'), findsOneWidget);
      expect(find.text('Hari ini tercatat penuh.'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('(f) perawatan: kosong, lalu tambah & geser jadwal',
        (t) async {
      await kosongkanPerawatan();
      await tampilkan(t, const PerawatanScreen());
      expect(find.text('Belum ada data'), findsOneWidget);
      expect(find.text('Jatuh tempo dalam 30 hari'), findsNothing);
      await tutup(t);

      // Baris dengan jadwal yang sudah lewat disiapkan di repositori: lewat
      // dialog, jadwal selalu mulai hari ini sehingga pergeseran jadwal tidak
      // bisa dibedakan dari keadaan awal.
      final p = await perawatan.simpan(
          nama: 'Ganti filter air', intervalHari: 7, berikutnya: hari(-3));
      await tampilkan(t, const PerawatanScreen());
      expect(find.text('Jatuh tempo dalam 30 hari'), findsOneWidget,
          reason: 'Jadwal yang sudah lewat tetap masuk sorotan.');
      expect(find.text('Berikutnya: ${fmtTanggalId(hari(-3))}'), findsOneWidget);
      expect(find.text('Jadwal ini sudah lewat 3 hari'), findsOneWidget);

      final tombol = Key('sudah_dilakukan_${p.id}');
      await gulirSampai(t, tombol);
      await tekan(t, find.byKey(tombol));
      expect(find.text('Berikutnya: ${fmtTanggalId(hari(7))}'), findsOneWidget,
          reason: 'Jadwal digeser dari hari pengerjaan + interval 7 hari.');
      expect(find.text('Jadwal ini sudah lewat 3 hari'), findsNothing);

      // Dialog tambah tetap bisa dipakai di halaman yang sudah berisi.
      await tekan(t, find.byKey(const Key('tombol_perawatan_baru')));
      await t.enterText(find.byKey(const Key('perawatan_nama')), 'Servis AC');
      await t.enterText(find.byKey(const Key('perawatan_interval')), '30');
      await tekan(t, find.byKey(const Key('simpan_perawatan')));
      expect(find.text('Berikutnya: ${fmtTanggalId(hari(30))}'), findsOneWidget,
          reason: 'Perawatan baru dijadwalkan dari hari ini + interval.');
      await tutup(t);
    });
  });

  // =========================================================================
  // Bahasa aman pasal III-11
  // =========================================================================

  test('bahasa aman III-11 pada 12 berkas modul aksi', () {
    final berkas = <String>[
      for (final f in Directory('lib/features/aksi').listSync())
        if (f is File && f.path.endsWith('.dart')) f.path,
      'lib/data/repository/aksi_repository.dart',
      'lib/data/repository/kebiasaan_repository.dart',
      'lib/data/repository/perawatan_repository.dart',
    ];
    expect(berkas.length, greaterThanOrEqualTo(12));
    for (final path in berkas) {
      final isi = File(path).readAsStringSync().toLowerCase();
      for (final kata in kataTerlarang) {
        expect(isi.contains(kata), isFalse,
            reason: 'Berkas $path memuat kata terlarang "$kata".');
      }
    }
  });
}
