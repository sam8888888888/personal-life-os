/// Uji V2 — modul Dokumen: FR-128 (daftar & pengelola dokumen penting) dan
/// FR-129 (pengingat berlapis masa berlaku).
///
/// Kriteria terima yang diuji:
/// * lead hari disimpan ternormalisasi ("90,30,7,1") dan teks lead tidak sah
///   ditolak dengan `ArgumentError` (bukan diam-diam diabaikan);
/// * ID notifikasi dokumen stabil, unik antar dokumen/slot, dan selalu di atas
///   `batasIdKhusus` (1999000000) sehingga tidak bentrok dengan pengingat tagihan;
/// * `segera_berakhir` = dokumen aktif tanpa arsip yang tersisa <= 90 hari,
///   termasuk yang sudah lewat, urut paling dekat;
/// * dokumen arsip disembunyikan dari daftar bawaan dan tidak dibuatkan pengingat;
/// * menghapus dokumen membuang penundaan pengingatnya di repositori (cascade),
///   tetapi tidak menghapus riwayat notifikasi/catatan aktivitas;
/// * pengingat dibuat satu per lead hari yang jatuh tempo, lead yang sudah lewat
///   lebih dari 3 hari dilewati, dan `tagihanId` = 0 (tidak ada tombol "Sudah bayar");
/// * catatan jujur soal berkas tampil di layar: aplikasi hanya mencatat nama &
///   tanggal, berkas asli tidak disalin dan belum dienkripsi;
/// * keadaan kosong menulis "Belum ada data" (bukan angka nol yang menyesatkan);
/// * bahasa aman PRD §III-11 (tanpa kata: kamu, gagal, skor, nilai, malas, rajin,
///   pelit, buruk, berdosa, diagnosis).
///
/// Waktu uji dikunci: "sekarang" = Selasa, 15 September 2026 pukul 08.00.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/audit/audit_log.dart';
import 'package:personal_life_os/core/notifikasi/model_pengingat.dart';
import 'package:personal_life_os/core/notifikasi/perencana_pengingat.dart'
    show batasIdKhusus, idBriefingPagiKe, idSholatKe;
import 'package:personal_life_os/core/notifikasi/sumber_pengingat_tambahan.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/core/utils/waktu.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/dokumen_repository.dart';
import 'package:personal_life_os/features/dokumen/dokumen_form_screen.dart';
import 'package:personal_life_os/features/dokumen/dokumen_providers.dart';
import 'package:personal_life_os/features/dokumen/dokumen_screen.dart';
import 'package:personal_life_os/features/dokumen/pengingat_dokumen.dart';
import 'package:personal_life_os/features/dokumen/teks_dokumen.dart';

late AppDatabase db;
late DokumenRepository repo;

/// Waktu patok uji: Selasa, 15 September 2026 pukul 08.00.
final jamUji = DateTime(2026, 9, 15, 8);

/// Tanggal relatif terhadap hari uji (0 = hari ini).
DateTime hari(int selisih) => DateTime(2026, 9, 15).add(Duration(days: selisih));

/// Kata yang dilarang PRD §III-11.
const List<String> kataTerlarang = [
  'kamu',
  'gagal',
  'skor',
  'berdosa',
  'malas',
  'rajin',
  'pelit',
  'buruk',
  'nilai',
  'wajib anda',
  'belum sholat',
  'diagnosis',
];

void periksaBahasaAman(Iterable<String> teks, String bagian) {
  final gabung = teks.join(' | ').toLowerCase();
  for (final kata in kataTerlarang) {
    expect(gabung.contains(kata), isFalse,
        reason: '$bagian memuat kata terlarang "$kata".');
  }
}

/// Dokumen contoh untuk uji murni (tanpa basis data).
DokumenData dokumenContoh({
  int id = 1,
  String nama = 'KTP',
  String jenis = 'ktp',
  DateTime? berlakuSampai,
  String leadHari = leadDokumenBawaan,
  bool aktif = true,
  bool arsip = false,
  String? pemilik,
}) =>
    DokumenData(
      id: id,
      idDokumen: 'DOK-UJI-$id',
      nama: nama,
      jenis: jenis,
      nomor: null,
      pemilik: pemilik,
      terbit: null,
      berlakuSampai: berlakuSampai,
      berkasNama: null,
      catatan: null,
      leadHari: leadHari,
      kanalPengingat: 'push',
      aktif: aktif,
      arsip: arsip,
      diperpanjangPada: null,
      dibuatPada: jamUji,
      diubahPada: jamUji,
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DokumenRepository(db, jamSekarang: () => jamUji);
    pakaiSumberWaktu(() => jamUji);
  });

  tearDown(() async {
    pakaiWaktuAsli();
    await db.close();
  });

  // =========================================================================
  // Hitungan murni
  // =========================================================================

  group('hitungan murni', () {
    test('(1) lead hari dinormalkan & teks lead tidak sah ditolak', () async {
      final a = await repo.simpan(
        nama: 'KTP',
        leadHari: ' 90, 30,30,7,1 ',
      );
      expect(a.leadHari, '90,30,7,1');
      expect(DokumenRepository.leadDokumen(a), [90, 30, 7, 1]);

      await expectLater(
        repo.simpan(nama: 'KK', leadHari: 'tidak ada angkanya'),
        throwsArgumentError,
      );
      await expectLater(
        repo.simpan(nama: '   '),
        throwsArgumentError,
      );
      expect(await repo.ambilSemua(), hasLength(1));
    });

    test('(2) sisaHari & status masa berlaku', () {
      expect(DokumenRepository.sisaHari(dokumenContoh(), jamUji), isNull);
      expect(DokumenRepository.status(dokumenContoh(), jamUji),
          StatusMasaBerlaku.tanpaBatas);

      expect(
          DokumenRepository.status(
              dokumenContoh(berlakuSampai: hari(91)), jamUji),
          StatusMasaBerlaku.jauh);
      expect(
          DokumenRepository.status(
              dokumenContoh(berlakuSampai: hari(90)), jamUji),
          StatusMasaBerlaku.dekat);
      expect(
          DokumenRepository.status(dokumenContoh(berlakuSampai: hari(0)), jamUji),
          StatusMasaBerlaku.hariIni);
      expect(
          DokumenRepository.status(
              dokumenContoh(berlakuSampai: hari(-3)), jamUji),
          StatusMasaBerlaku.sudahLewat);
      expect(
          DokumenRepository.sisaHari(
              dokumenContoh(berlakuSampai: hari(-3)), jamUji),
          -3);
    });

    test('(3) waktuPengingat memakai jam yang sama & menjepit lead negatif', () {
      final w = DokumenRepository.waktuPengingat(hari(30), 30);
      expect(w, DateTime(2026, 9, 15, 8));
      expect(DokumenRepository.waktuPengingat(hari(7), 7, jam: 6),
          DateTime(2026, 9, 15, 6));
      expect(DokumenRepository.waktuPengingat(hari(1), -5),
          DateTime(2026, 9, 16, 8));
    });

    test('(4) ID pengingat dokumen stabil, unik, & di atas batasIdKhusus', () {
      expect(idPengingatDokumen(3, 0), idPengingatDokumen(3, 0));
      expect(idPengingatDokumen(3, 0), isNot(idPengingatDokumen(3, 1)));
      expect(idPengingatDokumen(3, 0), isNot(idPengingatDokumen(4, 0)));
      expect(idPengingatDokumen(3, 0), greaterThanOrEqualTo(batasIdKhusus));
      expect(idPengingatDokumen(-3, 0), idPengingatDokumen(3, 0),
          reason: 'ID baris negatif tetap aman');

      final blok = rentangIdPengingatDokumen(3);
      expect(blok, hasLength(maksLeadPerDokumen));
      expect(blok.toSet(), hasLength(maksLeadPerDokumen));

      // Tidak boleh bertabrakan dengan ID briefing pagi / sholat.
      final idBriefing = {for (var i = 0; i < 7; i++) idBriefingPagiKe(i)};
      final idSholat = {for (var i = 0; i < 35; i++) idSholatKe(i)};
      for (final id in blok) {
        expect(idBriefing.contains(id), isFalse);
        expect(idSholat.contains(id), isFalse);
      }
    });

    test('(5) kalimat teks dokumen menyebut keadaan apa adanya', () {
      expect(kalimatMasaBerlaku(null, jamUji), 'Tanggal berakhir belum dicatat');
      expect(kalimatMasaBerlaku(hari(12), jamUji), 'Berakhir 12 hari lagi');
      expect(kalimatMasaBerlaku(hari(0), jamUji), 'Berakhir hari ini');
      expect(kalimatMasaBerlaku(hari(-4), jamUji), 'Sudah lewat 4 hari');
      expect(teksTanggalIsian(DateTime(2026, 9, 5)), '05/09/2026');
      expect(kalimatTanggalBerlaku(hari(5), jamUji),
          'Berlaku sampai 20 September 2026 · Berakhir 5 hari lagi');
      periksaBahasaAman([
        kalimatMasaBerlaku(null, jamUji),
        kalimatMasaBerlaku(hari(5), jamUji),
        kalimatMasaBerlaku(hari(-5), jamUji),
        kalimatTanggalBerlaku(hari(5), jamUji),
      ], 'kalimat masa berlaku');
    });
  });

  // =========================================================================
  // Repository
  // =========================================================================

  group('FR-128 repository', () {
    test('(6) simpan dokumen baru: id dibuat, kolom tersimpan, audit tercatat',
        () async {
      final d = await repo.simpan(
        nama: '  KTP Budi  ',
        jenis: 'ktp',
        nomor: '3201 1234',
        pemilik: 'Budi',
        terbit: DateTime(2020, 1, 2),
        berlakuSampai: hari(45),
        berkasNama: 'ktp-2026.pdf',
        catatan: 'di lemari berkas',
      );
      expect(d.nama, 'KTP Budi');
      expect(d.idDokumen, startsWith('DOK-'));
      expect(d.jenis, 'ktp');
      expect(d.nomor, '3201 1234');
      expect(d.pemilik, 'Budi');
      expect(d.terbit, DateTime(2020, 1, 2));
      expect(d.berlakuSampai, hari(45));
      expect(d.berkasNama, 'ktp-2026.pdf');
      expect(d.aktif, isTrue);
      expect(d.arsip, isFalse);
      expect(d.diperpanjangPada, isNull);
      expect(d.dibuatPada, jamUji);

      final audit = await db.select(db.auditLog).get();
      expect(audit, hasLength(1));
      expect(audit.single.modul, ModulAudit.dokumen);
      expect(audit.single.aksi, 'buat');
      expect(audit.single.ringkas, contains('KTP Budi'));
    });

    test('(7) dua dokumen pada jam yang sama tetap punya id berbeda', () async {
      final a = await repo.simpan(nama: 'KTP');
      final b = await repo.simpan(nama: 'SIM');
      expect(a.idDokumen, isNot(b.idDokumen));
      // Kolom kosong disimpan sebagai null, bukan teks kosong.
      expect(a.nomor, isNull);
      expect(a.berkasNama, isNull);
    });

    test('(8) ubah dokumen: id tetap, arsip tetap, terbit null diisi apa adanya',
        () async {
      final awal = await repo.simpan(nama: 'KTP', berlakuSampai: hari(10));
      await repo.tandaiArsip(awal.id);
      final baru = await repo.simpan(
        id: awal.id,
        nama: 'KTP (baru)',
        jenis: 'ktp',
        berlakuSampai: hari(400),
      );
      expect(baru.id, awal.id);
      expect(baru.idDokumen, awal.idDokumen);
      expect(baru.nama, 'KTP (baru)');
      expect(baru.berlakuSampai, hari(400));
      expect(baru.arsip, isTrue, reason: 'arsip hanya diubah lewat tandaiArsip');
      expect(baru.dibuatPada, awal.dibuatPada);
      expect(baru.terbit, isNull);

      final audit = await db.select(db.auditLog).get();
      expect(audit.map((a) => a.aksi), contains('ubah'));
    });

    test('(9) daftar bawaan menyembunyikan arsip & urut yang paling dekat',
        () async {
      final a = await repo.simpan(nama: 'Polis', berlakuSampai: hari(40));
      final b = await repo.simpan(nama: 'Ijazah', berlakuSampai: hari(5));
      final c = await repo.simpan(nama: 'Kontrak kerja');
      final d = await repo.simpan(nama: 'SIM lama', berlakuSampai: hari(900));
      await repo.tandaiArsip(d.id);

      final bawaan = await repo.ambilSemua();
      expect(bawaan.map((e) => e.nama), ['Ijazah', 'Polis', 'Kontrak kerja']);

      final semua = await repo.ambilSemua(termasukArsip: true);
      expect(semua.map((e) => e.nama),
          ['Ijazah', 'Polis', 'SIM lama', 'Kontrak kerja']);

      final tersembunyi = await repo.ambilSemua();
      expect(tersembunyi.any((e) => e.id == a.id), isTrue);
      expect(tersembunyi.any((e) => e.id == b.id), isTrue);
      expect(tersembunyi.any((e) => e.id == c.id), isTrue);
      expect(tersembunyi.any((e) => e.id == d.id), isFalse);
    });

    test('(10) segeraBerakhir <= 90 hari & membuang arsip/nonaktif/tanpa tanggal',
        () async {
      await repo.simpan(nama: 'Paspor', berlakuSampai: hari(20));
      await repo.simpan(nama: 'STNK', berlakuSampai: hari(90));
      final lewat = await repo.simpan(nama: 'KK', berlakuSampai: hari(-7));
      final jauh = await repo.simpan(nama: 'Sertifikat', berlakuSampai: hari(91));
      final kosong = await repo.simpan(nama: 'Catatan rumah');
      final diarsip =
          await repo.simpan(nama: 'SIM', berlakuSampai: hari(3));
      await repo.tandaiArsip(diarsip.id);
      final nonaktif =
          await repo.simpan(nama: 'Ijazah', berlakuSampai: hari(2));
      await repo.tandaiAktif(nonaktif.id, aktif: false);

      final sorotan = await repo.segeraBerakhir(sekarang: jamUji);
      expect(sorotan.map((e) => e.nama), ['KK', 'Paspor', 'STNK']);
      expect(sorotan.any((e) => e.id == jauh.id), isFalse);
      expect(sorotan.any((e) => e.id == kosong.id), isFalse);
      expect(sorotan.any((e) => e.id == diarsip.id), isFalse);
      expect(sorotan.any((e) => e.id == nonaktif.id), isFalse);

      expect((await repo.ambilUntukPengingat()).any((e) => e.id == lewat.id),
          isTrue);
      expect((await repo.ambilUntukPengingat()).any((e) => e.id == nonaktif.id),
          isFalse);
    });

    test('(11) tandaiDiperpanjang: tanggal baru, jejak waktu, arsip dibuka',
        () async {
      final d = await repo.simpan(nama: 'SIM', berlakuSampai: hari(-2));
      await repo.tandaiArsip(d.id);
      await repo.tandaiAktif(d.id, aktif: false);

      final baru = await repo.tandaiDiperpanjang(
        d.id,
        berlakuSampaiBaru: hari(365),
        kapan: jamUji,
      );
      expect(baru.diperpanjangPada, jamUji);
      expect(baru.berlakuSampai, hari(365));
      expect(baru.arsip, isFalse);
      expect(baru.aktif, isTrue);

      // Tanpa tanggal baru: tanggal berakhir lama dipertahankan.
      final lagi = await repo.tandaiDiperpanjang(d.id);
      expect(lagi.berlakuSampai, hari(365));

      final audit = await db.select(db.auditLog).get();
      expect(audit.where((a) => a.aksi == 'tandai'), isNotEmpty);
      expect(audit.last.ringkas, contains('diperpanjang'));
    });

    test('(12) hapus dokumen: baris hilang & penundaan pengingatnya dibuang',
        () async {
      final a = await repo.simpan(nama: 'KTP', berlakuSampai: hari(10));
      final b = await repo.simpan(nama: 'KK', berlakuSampai: hari(10));

      // Dua baris penundaan: satu milik dokumen a, satu milik pengingat lain.
      await db.into(db.tundaPengingat).insert(TundaPengingatCompanion.insert(
            pengingatId: idPengingatDokumen(a.id, 2),
            kapan: jamUji,
          ));
      await db.into(db.tundaPengingat).insert(TundaPengingatCompanion.insert(
            pengingatId: 12345,
            kapan: jamUji,
          ));

      final jumlahTunda = await repo.hapus(a.id);
      expect(jumlahTunda, 1);
      expect(await repo.ambilSatu(a.id), isNull);
      expect(await repo.ambilSatu(b.id), isNotNull);

      final tunda = await db.select(db.tundaPengingat).get();
      expect(tunda, hasLength(1));
      expect(tunda.single.pengingatId, 12345);

      final audit = await db.select(db.auditLog).get();
      expect(audit.last.aksi, 'hapus');
      expect(audit.last.ringkas, contains('KTP'));
    });
  });

  // =========================================================================
  // FR-129 pengingat berlapis
  // =========================================================================

  group('FR-129 pengingat', () {
    test('(13) satu pengingat per lead hari yang jatuh tempo hari ini', () {
      // Dokumen berakhir 90 hari lagi → hanya lead 90 yang jatuh tempo hari ini.
      final a = dokumenContoh(id: 5, berlakuSampai: hari(90));
      final hasil = pengingatDokumenUntuk([a], jamUji);
      expect(hasil, hasLength(1));
      final p = hasil.single;
      expect(p.id, idPengingatDokumen(5, 0));
      expect(p.tagihanId, 0);
      expect(p.waktu, DateTime(2026, 9, 15, 8));
      expect(p.judul, contains('KTP'));
      expect(p.isi, contains('90 hari lagi'));

      // Dua lead yang sama-sama jatuh tempo hari ini → dua pengingat.
      // Berakhir besok: lead 2 jatuh kemarin, lead 1 jatuh hari ini.
      final b = dokumenContoh(
          id: 6, nama: 'Paspor', berlakuSampai: hari(1), leadHari: '2,1');
      final dua = pengingatDokumenUntuk([b], jamUji);
      expect(dua, hasLength(2));
      expect(dua.map((e) => e.id).toSet(),
          {idPengingatDokumen(6, 0), idPengingatDokumen(6, 1)});
      expect(dua.map((e) => e.waktu).toSet(),
          {DateTime(2026, 9, 14, 8), DateTime(2026, 9, 15, 8)});
    });

    test('(14) lead yang lewat lebih dari 3 hari dilewati', () {
      final a = dokumenContoh(id: 7, berlakuSampai: hari(1), leadHari: '30,3');
      final hasil = pengingatDokumenUntuk([a], jamUji);
      expect(hasil, hasLength(1));
      expect(hasil.single.id, idPengingatDokumen(7, 1),
          reason: 'lead 30 jatuh 29 hari lalu, hanya lead 3 yang dibuat');

      final terlaluTua =
          dokumenContoh(id: 8, berlakuSampai: hari(-10), leadHari: '1');
      expect(pengingatDokumenUntuk([terlaluTua], jamUji), isEmpty);

      // Batas 3 hari bisa diubah pemanggil.
      final tepi = dokumenContoh(id: 9, berlakuSampai: hari(-4), leadHari: '0');
      expect(pengingatDokumenUntuk([tepi], jamUji), isEmpty);
      expect(
          pengingatDokumenUntuk([tepi], jamUji, hariKeBelakangMaks: 5),
          hasLength(1));

      // Lebih dari 8 lead: yang dibuang adalah lead terjauh, bukan terdekat.
      final banyak = dokumenContoh(
          id: 17, berlakuSampai: hari(1), leadHari: '9,8,7,6,5,4,3,2,1');
      final potong = pengingatDokumenUntuk(
        [banyak],
        jamUji,
        hariKeBelakangMaks: 30,
      );
      expect(potong, hasLength(maksLeadPerDokumen));
      expect(potong.first.waktu, DateTime(2026, 9, 8, 8),
          reason: 'lead terdekat (1..8) yang dipakai, lead 9 dibuang');
      expect(
          potong.map((e) => e.waktu),
          isNot(contains(DateTime(2026, 9, 7, 8))));
    });

    test('(15) dokumen yang sudah lewat & tanpa tanggal berakhir', () {
      final lewat = dokumenContoh(
          id: 10, nama: 'STNK', berlakuSampai: hari(-1), leadHari: '1');
      final hasil = pengingatDokumenUntuk([lewat], jamUji);
      expect(hasil, hasLength(1));
      expect(hasil.single.isi, contains('sudah lewat 1 hari'));
      expect(hasil.single.isi, contains('STNK'));
      expect(hasil.single.waktu, DateTime(2026, 9, 13, 8));

      expect(
          pengingatDokumenUntuk(
              [dokumenContoh(id: 11, berlakuSampai: null)], jamUji),
          isEmpty);
    });

    test('(16) dokumen arsip / nonaktif tidak menghasilkan pengingat', () {
      final arsip = dokumenContoh(
          id: 12, berlakuSampai: hari(30), arsip: true, leadHari: '30');
      final nonaktif = dokumenContoh(
          id: 13, berlakuSampai: hari(30), aktif: false, leadHari: '30');
      expect(pengingatDokumenUntuk([arsip, nonaktif], jamUji), isEmpty);
      expect(pengingatDokumenUntuk(const [], jamUji), isEmpty);
    });

    test('(17) bahasa semua teks pengingat aman', () {
      final daftar = [
        dokumenContoh(id: 14, berlakuSampai: hari(90), pemilik: 'Budi'),
        dokumenContoh(id: 15, berlakuSampai: hari(0), leadHari: '0'),
        dokumenContoh(id: 16, berlakuSampai: hari(-1), leadHari: '1'),
      ];
      final hasil = pengingatDokumenUntuk(daftar, jamUji);
      expect(hasil, isNotEmpty);
      periksaBahasaAman(
        [
          ...hasil.map((p) => p.judul),
          ...hasil.map((p) => p.isi),
        ],
        'teks pengingat dokumen',
      );
    });

    test('(18) SumberPengingatDokumen membaca data nyata & terdaftar di registri',
        () async {
      final sumber = SumberPengingatDokumen(
        pembukaBasisData: () => db,
        tutupBasisData: false,
      );
      expect(await sumber.pengingatTambahan(jamUji), isEmpty);

      await repo.simpan(nama: 'Paspor', berlakuSampai: hari(7));
      final hasil = await sumber.pengingatTambahan(jamUji);
      expect(hasil, hasLength(1));
      expect(hasil.single.judul, contains('Paspor'));

      // Kontrak registri: pendaftaran ganda tidak menggandakan, dan sumber yang
      // melempar galat tidak mematikan sumber lain.
      RegistriSumberPengingat.kosongkan();
      RegistriSumberPengingat.daftarkan(sumber);
      RegistriSumberPengingat.daftarkan(sumber);
      expect(RegistriSumberPengingat.daftar, hasLength(1));

      RegistriSumberPengingat.daftarkan(SumberGalatUji());
      final galat = <String>[];
      final kumpulan = await RegistriSumberPengingat.kumpulkan(
        jamUji,
        catatGalat: galat.add,
      );
      expect(kumpulan, hasLength(1),
          reason: 'pengingat dokumen tetap dikumpulkan');
      expect(kumpulan.single.judul, contains('Paspor'));
      expect(galat, hasLength(1));
      RegistriSumberPengingat.kosongkan();
    });
  });

  // =========================================================================
  // Ekspor
  // =========================================================================

  group('ekspor', () {
    test('(19) ekspor teks & JSON memuat isi tanpa data berkas', () async {
      await repo.simpan(
        nama: 'KTP',
        jenis: 'ktp',
        nomor: '123',
        berlakuSampai: hari(30),
        berkasNama: 'ktp.pdf',
      );
      await repo.simpan(nama: 'KK', jenis: 'kk', berlakuSampai: hari(400));

      final daftar = await repo.ambilSemua();
      final teks = DokumenRepository.eksporTeks(daftar);
      expect(teks, contains('KTP'));
      expect(teks, contains('berlaku sampai 15 Oktober 2026'));
      expect(teks, contains('ktp.pdf'));

      final json = DokumenRepository.eksporJson(daftar);
      final peta = jsonDecode(json) as Map<String, dynamic>;
      expect(peta['jenis'], 'daftar_dokumen');
      expect(peta['jumlah'], 2);
      final isi = (peta['dokumen'] as List).cast<Map<String, dynamic>>();
      expect(isi.first['nama'], 'KTP');
      expect(isi.first['berlakuSampai'], hari(30).toIso8601String());
      periksaBahasaAman([teks, json], 'teks ekspor');
    });
  });

  // =========================================================================
  // Layar (widget)
  // =========================================================================

  group('layar dokumen', () {
    Future<void> tampilkan(WidgetTester t, Widget layar) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      await t.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repoDokumenProvider.overrideWithValue(repo),
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

    /// Gulir daftar/kolom halaman yang sedang tampil.
    ///
    /// Setiap `TextField` juga memuat `Scrollable` sendiri (mendatar, jangkauan
    /// nol). Sasaran dipilih dari jangkauan gulir terbesar supaya yang digulir
    /// benar-benar daftar halaman, bukan isi kolom teks.
    Future<void> gulir(WidgetTester t, double jarak) async {
      final kandidat = find
          .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
          .evaluate()
          .map((e) => (e as StatefulElement).state as ScrollableState)
          .toList();
      if (kandidat.isEmpty) return;
      kandidat.sort((a, b) =>
          b.position.maxScrollExtent.compareTo(a.position.maxScrollExtent));
      final pos = kandidat.first.position;
      pos.jumpTo((pos.pixels + jarak).clamp(0.0, pos.maxScrollExtent));
      await t.pump(const Duration(milliseconds: 50));
    }

    /// Gulir dari atas sampai widget [target] benar-benar dibangun (ListView
    /// hanya membangun anak yang terlihat).
    Future<void> gulirKe(WidgetTester t, Finder target,
        {int langkah = 40, double jarak = 200}) async {
      if (target.evaluate().isNotEmpty) return;
      await gulir(t, -100000);
      for (var i = 0; i < langkah; i++) {
        if (target.evaluate().isNotEmpty) return;
        await gulir(t, jarak);
      }
    }

    Future<void> tekan(WidgetTester t, Finder target) async {
      await gulirKe(t, target);
      await t.ensureVisible(target);
      await t.pump(const Duration(milliseconds: 120));
      await t.tap(target);
      await t.pump(const Duration(milliseconds: 200));
      await t.pump(const Duration(milliseconds: 300));
    }

    /// Teks yang sedang tampil, termasuk yang perlu digulir dulu.
    Future<Set<String>> semuaTeks(WidgetTester t) async {
      final kumpulan = <String>{};
      void kumpulkan() => kumpulan.addAll(t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .where((s) => s.isNotEmpty));
      kumpulkan();
      await gulir(t, -100000);
      for (var i = 0; i < 16; i++) {
        await gulir(t, 240);
        kumpulkan();
      }
      return kumpulan;
    }

    testWidgets('(20) layar tanpa data: "Belum ada data" + catatan jujur',
        (t) async {
      await tampilkan(t, DokumenScreen(jamSekarang: () => jamUji));
      final teks = await semuaTeks(t);
      expect(teks.any((s) => s.contains('Belum ada data')), isTrue);
      expect(teks.any((s) => s.contains('tidak disalin dan belum dienkripsi')),
          isTrue);
      expect(find.byKey(const Key('tombol_dokumen_baru')), findsOneWidget);
      expect(find.byKey(const Key('ekspor_dokumen')), findsOneWidget);
      periksaBahasaAman(teks, 'layar dokumen kosong');
      await tutup(t);
    });

    testWidgets('(21) daftar: kartu masa berlaku, arsip disembunyikan',
        (t) async {
      await repo.simpan(
        nama: 'Paspor',
        jenis: 'paspor',
        nomor: 'X123',
        pemilik: 'Budi',
        berlakuSampai: hari(20),
        berkasNama: 'paspor.pdf',
      );
      await repo.simpan(nama: 'Kontrak kerja');
      final diarsip = await repo.simpan(nama: 'SIM lama', berlakuSampai: hari(5));
      await repo.tandaiArsip(diarsip.id);

      await tampilkan(t, DokumenScreen(jamSekarang: () => jamUji));
      final teks = await semuaTeks(t);
      expect(teks.any((s) => s.contains('Masa berlaku dekat ini')), isTrue);
      expect(teks.any((s) => s.contains('Paspor')), isTrue);
      expect(teks.any((s) => s.contains('Nomor: X123')), isTrue);
      expect(teks.any((s) => s.contains('Milik: Budi')), isTrue);
      expect(teks.any((s) => s.contains('Berakhir 20 hari lagi')), isTrue);
      expect(teks.any((s) => s.contains('Tanggal berakhir belum dicatat')), isTrue);
      expect(teks.any((s) => s.contains('SIM lama')), isFalse,
          reason: 'dokumen arsip disembunyikan');
      periksaBahasaAman(teks, 'layar dokumen berisi');
      await tutup(t);
    });

    testWidgets('(22) saklar arsip menampilkan dokumen yang diarsipkan',
        (t) async {
      final diarsip =
          await repo.simpan(nama: 'SIM lama', berlakuSampai: hari(5));
      await repo.tandaiArsip(diarsip.id);

      await tampilkan(t, DokumenScreen(jamSekarang: () => jamUji));
      expect((await semuaTeks(t)).any((s) => s.contains('SIM lama')), isFalse);

      await tekan(t, find.byKey(const Key('tampilkan_arsip')));
      await t.pump(const Duration(milliseconds: 300));
      final teks = await semuaTeks(t);
      expect(teks.any((s) => s.contains('SIM lama')), isTrue);
      expect(teks.any((s) => s.contains('Di arsip')), isTrue);
      periksaBahasaAman(teks, 'layar dokumen arsip');
      await tutup(t);
    });

    testWidgets('(23) form tambah menyimpan dokumen baru', (t) async {
      await tampilkan(t, DokumenScreen(jamSekarang: () => jamUji));
      await tekan(t, find.byKey(const Key('tombol_dokumen_baru')));
      await t.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('form_dokumen_nama')), findsOneWidget);
      expect(find.byKey(const Key('catatan_berkas_form')), findsOneWidget);
      final kolomNama = find.byKey(const Key('form_dokumen_nama'));
      await gulirKe(t, kolomNama);
      await t.enterText(kolomNama, 'KTP Budi');
      final kolomLead = find.byKey(const Key('form_dokumen_lead'));
      await gulirKe(t, kolomLead);
      await t.enterText(kolomLead, '30,7');
      await tekan(t, find.byKey(const Key('simpan_dokumen')));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));

      final tersimpan = await repo.ambilSemua();
      expect(tersimpan, hasLength(1));
      expect(tersimpan.single.nama, 'KTP Budi');
      expect(tersimpan.single.leadHari, '30,7');
      expect(tersimpan.single.jenis, 'lain');
      expect((await semuaTeks(t)).any((s) => s.contains('KTP Budi')), isTrue);
      periksaBahasaAman(await semuaTeks(t), 'layar setelah simpan');
      await tutup(t);
    });

    testWidgets('(24) form ubah: tanggal berakhir bisa diketik', (t) async {
      final d = await repo.simpan(nama: 'STNK', berlakuSampai: hari(30));
      await tampilkan(t, DokumenScreen(jamSekarang: () => jamUji));
      await tekan(t, find.byKey(Key('ubah_dokumen_${d.id}')));
      await t.pump(const Duration(milliseconds: 400));

      final kolomTanggal = find.byKey(const Key('form_dokumen_berlaku'));
      await gulirKe(t, kolomTanggal);
      await t.enterText(kolomTanggal, '31/12/2027');
      await tekan(t, find.byKey(const Key('simpan_dokumen')));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));

      final baru = await repo.ambilSatu(d.id);
      expect(baru, isNotNull);
      expect(baru!.berlakuSampai, DateTime(2027, 12, 31));
      expect(baru.nama, 'STNK');
      await tutup(t);
    });

    testWidgets('(25) tindakan tiap baris: perpanjang, arsip, hapus', (t) async {
      final d = await repo.simpan(nama: 'SIM', berlakuSampai: hari(10));
      await tampilkan(t, DokumenScreen(jamSekarang: () => jamUji));

      // Tandai sudah diperpanjang dengan tanggal baru.
      await tekan(t, find.byKey(Key('diperpanjang_${d.id}')));
      expect(find.byKey(const Key('perpanjang_tanggal')), findsOneWidget);
      await t.enterText(
          find.byKey(const Key('perpanjang_tanggal')), '01/01/2028');
      await tekan(t, find.byKey(const Key('simpan_perpanjang')));
      await t.pump(const Duration(milliseconds: 500));
      var baris = await repo.ambilSatu(d.id);
      expect(baris!.berlakuSampai, DateTime(2028, 1, 1));
      expect(baris.diperpanjangPada, jamUji);

      // Arsipkan lalu kembalikan.
      await tekan(t, find.byKey(Key('arsip_dokumen_${d.id}')));
      await t.pump(const Duration(milliseconds: 400));
      expect((await repo.ambilSatu(d.id))!.arsip, isTrue);

      // Hapus: batal dulu, lalu setujui.
      await tekan(t, find.byKey(const Key('tampilkan_arsip')));
      await t.pump(const Duration(milliseconds: 300));
      await tekan(t, find.byKey(Key('hapus_dokumen_${d.id}')));
      expect(find.byKey(const Key('konfirmasi_hapus')), findsOneWidget);
      await tekan(t, find.byKey(const Key('batal_hapus')));
      await t.pump(const Duration(milliseconds: 300));
      expect(await repo.ambilSatu(d.id), isNotNull,
          reason: 'Batal tidak menghapus apa pun');

      await tekan(t, find.byKey(Key('hapus_dokumen_${d.id}')));
      await tekan(t, find.byKey(const Key('hapus_hapus')));
      await t.pump(const Duration(milliseconds: 500));
      expect(await repo.ambilSatu(d.id), isNull);
      final teks = await semuaTeks(t);
      expect(teks.any((s) => s.contains('Belum ada data')), isTrue);
      periksaBahasaAman(teks, 'layar setelah hapus');
      await tutup(t);
    });

    testWidgets('(26) dialog ekspor menampilkan teks & JSON', (t) async {
      await repo.simpan(nama: 'KTP', berlakuSampai: hari(30));
      await tampilkan(t, DokumenScreen(jamSekarang: () => jamUji));
      await tekan(t, find.byKey(const Key('ekspor_dokumen')));
      await t.pump(const Duration(milliseconds: 300));

      final isiTeks = t
          .widget<SelectableText>(find.byKey(const Key('teks_ekspor_dokumen')))
          .data;
      expect(isiTeks, contains('KTP'));

      await tekan(t, find.text('JSON'));
      await t.pump(const Duration(milliseconds: 300));
      final isiJson = t
          .widget<SelectableText>(find.byKey(const Key('teks_ekspor_dokumen')))
          .data;
      expect(isiJson, contains('daftar_dokumen'));

      await tekan(t, find.byKey(const Key('tutup_ekspor')));
      await t.pump(const Duration(milliseconds: 300));
      await tutup(t);
    });

    testWidgets('(27) form menolak nama kosong & tanggal yang tidak terbaca',
        (t) async {
      await tampilkan(t, DokumenScreen(jamSekarang: () => jamUji));
      await tekan(t, find.byKey(const Key('tombol_dokumen_baru')));
      await t.pump(const Duration(milliseconds: 400));

      await tekan(t, find.byKey(const Key('simpan_dokumen')));
      await t.pump(const Duration(milliseconds: 200));
      expect((await semuaTeks(t)).any((s) => s.contains('belum diisi')), isTrue);
      expect(await repo.ambilSemua(), isEmpty);

      final kolomNama = find.byKey(const Key('form_dokumen_nama'));
      await gulirKe(t, kolomNama);
      await t.enterText(kolomNama, 'KTP');
      final kolomTanggal = find.byKey(const Key('form_dokumen_berlaku'));
      await gulirKe(t, kolomTanggal);
      await t.enterText(kolomTanggal, '31/31/2027');
      await tekan(t, find.byKey(const Key('simpan_dokumen')));
      await t.pump(const Duration(milliseconds: 200));
      expect((await semuaTeks(t)).any((s) => s.contains('belum terbaca')), isTrue);
      expect(await repo.ambilSemua(), isEmpty);
      periksaBahasaAman(await semuaTeks(t), 'form dokumen');
      await tutup(t);
    });

    testWidgets('(28) layar form berdiri sendiri: ada AppBar & judulnya',
        (t) async {
      await tampilkan(t, const DokumenFormScreen());
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Dokumen baru'), findsOneWidget);
      await tutup(t);
    });
  });

  // =========================================================================
  // Catatan pemilik berkas (dipakai uji 6) — dijaga tetap sinkron dengan core.
  // =========================================================================

  test('(29) catatan jujur menyebut tidak ada enkripsi', () {
    expect(catatanBerkasJujur, contains('tidak disalin'));
    expect(catatanBerkasJujur, contains('belum dienkripsi'));
    periksaBahasaAman([catatanBerkasJujur], 'catatan berkas');
    expect(labelJenisDokumen['ktp'], 'KTP');
    expect(labelJenisDokumen.length, greaterThanOrEqualTo(10));
  });
}

/// Sumber pengingat yang selalu melempar galat, untuk menguji registri.
class SumberGalatUji implements SumberPengingatTambahan {
  @override
  Future<List<Pengingat>> pengingatTambahan(DateTime sekarang) async =>
      throw StateError('basis data tidak tersedia');
}
