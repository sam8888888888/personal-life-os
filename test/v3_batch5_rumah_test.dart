/// Batch 5 (FR-124/125/126/127/130) — Home & Asset OS + bagikan tersamar.
///
/// Yang dibuktikan (bukan diklaim):
/// 1. FR-124: aset fisik tersimpan; **total nilai tampil** dan masuk ke
///    Kekayaan Bersih (FR-76) TANPA input nilai bulanan (kriteria terima PRD).
/// 2. FR-125: jadwal perawatan terikat aset; menandai selesai memajukan jadwal;
///    riwayat menyimpan biaya + rata-rata per tahun; pengingat dibuat dengan ID
///    di rentang cadangan (tidak bentrok dengan tagihan/briefing/sholat/dokumen).
/// 3. FR-126: garansi dinilai (aktif / segera berakhir / berakhir) dan aset yang
///    garansinya dekat muncul di daftar `garansiDekat` untuk Perhatian Today.
/// 4. FR-127: perkiraan umur pakai menampilkan DASAR perhitungan, bukan klaim.
/// 5. FR-130: nomor disamarkan; berkas asli TIDAK ikut kecuali pengguna
///    mencentangnya DAN berkasnya ada.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/dokumen/samar_dokumen.dart';
import 'package:personal_life_os/core/notifikasi/perencana_pengingat.dart';
import 'package:personal_life_os/core/rumah/aset_fisik.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/aset_repository.dart';
import 'package:personal_life_os/data/repository/rumah_repository.dart';
import 'package:personal_life_os/features/rumah/aset_detail_screen.dart';
import 'package:personal_life_os/features/rumah/aset_fisik_screen.dart';
import 'package:personal_life_os/features/rumah/pengingat_perawatan.dart';
import 'package:personal_life_os/features/rumah/rumah_providers.dart';

void main() {
  // ------------------------------------------------------------------ logika
  group('FR-130 penyamaran nomor & bagikan terkendali', () {
    test('nomor panjang: 4 karakter awal tetap tampak', () {
      final h = samarNomor('A1234567');
      expect(h.teks, 'A123••••');
      expect(h.panjangAsli, 8);
    });

    test('pemisah spasi & tanda hubung dipertahankan', () {
      expect(samarNomor('AB 12-3456').teks, 'AB 12-••••');
    });

    test('nomor pendek: hanya 1 karakter tampak', () {
      expect(samarNomor('AB1').teks, 'A••');
    });

    test('nomor kosong tetap kosong', () {
      expect(samarNomor('   ').teks, '');
      expect(samarNomor('   ').panjangAsli, 0);
    });

    test('bawaan: berkas asli TIDAK ikut & teks menyebutkannya', () {
      final isi = susunBagikanTersamar(
        nama: 'KTP',
        jenisDokumen: 'ktp',
        nomor: 'A1234567',
        berkasNama: 'ktp.pdf',
      );
      expect(isi.berkasIkut, isFalse);
      expect(isi.jalurBerkas, isNull);
      expect(isi.teks, contains('A123••••'));
      expect(isi.teks, contains('TIDAK diikutkan'));
    });

    test('centang berkas TANPA berkas nyata → tetap tidak ikut', () {
      final isi = susunBagikanTersamar(
        nama: 'KTP',
        jenisDokumen: 'ktp',
        nomor: 'A1234567',
        berkasNama: 'ktp.pdf',
        sertakanBerkas: true,
        jalurBerkas: null,
      );
      expect(isi.berkasIkut, isFalse);
    });

    test('centang + berkas ada → berkas ikut', () {
      final isi = susunBagikanTersamar(
        nama: 'KTP',
        jenisDokumen: 'ktp',
        nomor: 'A1234567',
        berkasNama: 'ktp.pdf',
        sertakanBerkas: true,
        jalurBerkas: '/tmp/ktp.pdf',
      );
      expect(isi.berkasIkut, isTrue);
      expect(isi.jalurBerkas, '/tmp/ktp.pdf');
      expect(isi.jenis, 'text/plain');
    });

    test('nama berkas hasil penyamaran aman dari spasi', () {
      expect(namaBerkasBagikan('KTP Papi'), 'bagikan-ktp-papi.txt');
      expect(namaBerkasBagikan('   '), 'bagikan-dokumen.txt');
    });
  });

  group('FR-126 garansi', () {
    final sekarang = DateTime(2026, 9, 22);

    test('belum diisi', () {
      final h = periksaGaransi(null, sekarang);
      expect(h.status, StatusGaransi.tidakAda);
      expect(h.perluPerhatian, isFalse);
      expect(h.keterangan, contains('belum diisi'));
    });

    test('masih jauh = aktif', () {
      final h = periksaGaransi(DateTime(2027, 1, 1), sekarang);
      expect(h.status, StatusGaransi.aktif);
      expect(h.sisaHari, 101);
      expect(h.perluPerhatian, isFalse);
    });

    test('10 hari lagi = segera berakhir (ambang 30)', () {
      final h = periksaGaransi(DateTime(2026, 10, 2), sekarang);
      expect(h.status, StatusGaransi.segeraBerakhir);
      expect(h.sisaHari, 10);
      expect(h.perluPerhatian, isTrue);
      expect(h.keterangan, contains('10 hari lagi'));
    });

    test('sudah lewat = berakhir', () {
      final h = periksaGaransi(DateTime(2026, 9, 17), sekarang);
      expect(h.status, StatusGaransi.berakhir);
      expect(h.sisaHari, 5);
      expect(h.keterangan, contains('5 hari lalu'));
    });
  });

  group('FR-127 perkiraan umur pakai', () {
    test('hitung ganti, sisa bulan, dana sisih, dan dasar perhitungan', () {
      final u = perkiraanUmurPakai(
        tanggalBeli: DateTime(2023, 1, 10),
        masaPakaiBulan: 60,
        hargaBeliSen: 150000000,
        sekarang: DateTime(2026, 1, 10),
      )!;
      expect(u.perkiraanGanti, DateTime(2028, 1, 10));
      expect(u.sisaBulan, 24);
      expect(u.sudahLewat, isFalse);
      // Rp 1.500.000 / 60 bulan = Rp 25.000
      expect(u.danaSisihPerBulanSen, 2500000);
      expect(u.dasar, contains('masa pakai 60 bulan'));
      expect(u.dasar, contains('perkiraan ganti'));
    });

    test('data belum cukup → null (bukan angka karangan)', () {
      expect(
        perkiraanUmurPakai(
            tanggalBeli: DateTime(2023, 1, 1), sekarang: DateTime(2026, 1, 1)),
        isNull,
      );
      expect(
        perkiraanUmurPakai(
            masaPakaiBulan: 12, sekarang: DateTime(2026, 1, 1)),
        isNull,
      );
      expect(
        perkiraanUmurPakai(
          tanggalBeli: DateTime(2023, 1, 1),
          masaPakaiBulan: 0,
          sekarang: DateTime(2026, 1, 1),
        ),
        isNull,
      );
    });

    test('31 hari dijepit ke akhir bulan', () {
      final u = perkiraanUmurPakai(
        tanggalBeli: DateTime(2026, 1, 31),
        masaPakaiBulan: 1,
        sekarang: DateTime(2026, 1, 31),
      )!;
      expect(u.perkiraanGanti, DateTime(2026, 2, 28));
    });
  });

  group('FR-125 ringkasan biaya perawatan', () {
    test('total, jumlah, tertaut, dan rata-rata per tahun', () {
      final r = ringkasBiayaPerawatan([
        CatatanBiaya(
            tanggal: DateTime(2025, 1, 1), biayaSen: 10000000, tertaut: true),
        CatatanBiaya(tanggal: DateTime(2025, 7, 1), biayaSen: 5000000),
        CatatanBiaya(
            tanggal: DateTime(2026, 1, 1), biayaSen: 5000000, tertaut: true),
      ]);
      expect(r.totalSen, 20000000);
      expect(r.jumlahCatatan, 3);
      expect(r.tertautPengeluaran, 2);
      // 200.000 selama 365 hari → rata-rata ≈ 200.000 per tahun
      expect(r.rataPerTahunSen, 20000000);
      expect(r.keterangan, contains('3 catatan'));
    });

    test('kosong', () {
      final r = ringkasBiayaPerawatan(const []);
      expect(r.totalSen, 0);
      expect(r.rataPerTahunSen, isNull);
      expect(r.keterangan, 'Belum ada catatan perawatan');
    });
  });

  // ----------------------------------------------------------- basis data
  group('FR-124/125/126 basis data', () {
    late AppDatabase db;
    late RumahRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = RumahRepository(db, jamSekarang: () => DateTime(2026, 9, 22, 9));
    });

    tearDown(() => db.close());

    test('aset fisik tersimpan & total nilai benar', () async {
      await repo.simpanAsetFisik(
        nama: 'Honda Vario',
        jenis: JenisAsetFisik.kendaraan,
        tanggalBeli: DateTime(2024, 3, 1),
        hargaBeliSen: 2500000000,
        nomorSeri: 'B1234XYZ',
        garansiSampai: DateTime(2027, 3, 1),
        masaPakaiBulan: 96,
      );
      await repo.simpanAsetFisik(
        nama: 'Kulkas',
        jenis: JenisAsetFisik.elektronik,
        hargaBeliSen: 500000000,
      );
      final daftar = await repo.ambilAsetFisik();
      expect(daftar.length, 2);
      expect(await repo.totalNilaiAsetFisikSen(), 3000000000);
      final vario = daftar.firstWhere((a) => a.nama == 'Honda Vario');
      expect(vario.nomorSeri, 'B1234XYZ');
      expect(vario.masaPakaiBulan, 96);
    });

    test('KRITERIA TERIMA FR-124: masuk Kekayaan Bersih tanpa nilai bulanan',
        () async {
      await repo.simpanAsetFisik(
        nama: 'Rumah',
        jenis: JenisAsetFisik.rumah,
        hargaBeliSen: 90000000000,
      );
      final asetRepo = AsetRepository(db);
      final bersih = await asetRepo.nilaiBersih('2026-09');
      expect(bersih.totalAsetSen, 90000000000);
      expect(bersih.bersihSen, 90000000000);
    });

    test('jenis aset keuangan tidak ikut daftar aset fisik', () async {
      await AsetRepository(db).tambahAset(nama: 'Tabungan', nilaiAwalSen: 1000);
      await repo.simpanAsetFisik(
          nama: 'Laptop', jenis: JenisAsetFisik.perangkat);
      final daftar = await repo.ambilAsetFisik();
      expect(daftar.map((a) => a.nama), ['Laptop']);
    });

    test('jadwal perawatan terikat aset & selesai memajukan jadwal', () async {
      final aset = await repo.simpanAsetFisik(
          nama: 'Mobil', jenis: JenisAsetFisik.kendaraan);
      final jadwal = await repo.tambahJadwalAset(
        asetId: aset.id,
        nama: 'Ganti oli',
        intervalHari: 180,
        berikutnya: DateTime(2026, 10, 1),
      );
      expect((await repo.jadwalAset(aset.id)).length, 1);

      await repo.tandaiJadwalSelesai(jadwal.id, tanggal: DateTime(2026, 10, 1));
      final sesudah = (await repo.jadwalAset(aset.id)).single;
      expect(sesudah.terakhirDilakukan, DateTime(2026, 10, 1));
      expect(sesudah.berikutnya, DateTime(2027, 3, 30));
    });

    test('riwayat perbaikan menyimpan biaya & dirangkum', () async {
      final aset = await repo.simpanAsetFisik(
          nama: 'AC', jenis: JenisAsetFisik.elektronik);
      await repo.tambahRiwayat(
        asetId: aset.id,
        uraian: 'Servis + isi freon',
        tanggal: DateTime(2026, 2, 1),
        biayaSen: 45000000,
        transaksiId: 7,
      );
      await repo.tambahRiwayat(
        asetId: aset.id,
        uraian: 'Cuci AC',
        tanggal: DateTime(2026, 8, 1),
        biayaSen: 15000000,
      );
      final riwayat = await repo.riwayatAset(aset.id);
      expect(riwayat.length, 2);
      expect(riwayat.first.uraian, 'Cuci AC'); // terbaru di atas
      final ringkas = await repo.ringkasBiayaAset(aset.id);
      expect(ringkas.totalSen, 60000000);
      expect(ringkas.tertautPengeluaran, 1);
      expect(ringkas.rataPerTahunSen, isNotNull);
    });

    test('uraian kosong & biaya negatif ditolak jujur', () async {
      final aset = await repo.simpanAsetFisik(
          nama: 'TV', jenis: JenisAsetFisik.elektronik);
      expect(
        () => repo.tambahRiwayat(
            asetId: aset.id, uraian: '  ', tanggal: DateTime(2026, 1, 1)),
        throwsArgumentError,
      );
      expect(
        () => repo.tambahRiwayat(
            asetId: aset.id,
            uraian: 'Servis',
            tanggal: DateTime(2026, 1, 1),
            biayaSen: -1),
        throwsArgumentError,
      );
    });

    test('FR-126: garansi dekat terdeteksi, yang jauh tidak', () async {
      await repo.simpanAsetFisik(
        nama: 'Dekat',
        jenis: JenisAsetFisik.elektronik,
        garansiSampai: DateTime(2026, 10, 5),
      );
      await repo.simpanAsetFisik(
        nama: 'Jauh',
        jenis: JenisAsetFisik.elektronik,
        garansiSampai: DateTime(2028, 1, 1),
      );
      await repo.simpanAsetFisik(
          nama: 'Tanpa garansi', jenis: JenisAsetFisik.elektronik);
      final dekat = await repo.garansiDekat(DateTime(2026, 9, 22));
      expect(dekat.map((a) => a.nama), ['Dekat']);
    });

    test('arsip menyembunyikan aset dari daftar & total', () async {
      final aset = await repo.simpanAsetFisik(
          nama: 'Sepeda', jenis: JenisAsetFisik.lain, hargaBeliSen: 300000000);
      await repo.arsipkanAset(aset.id);
      expect((await repo.ambilAsetFisik()).length, 0);
      expect((await repo.ambilAsetFisik(sertakanArsip: true)).length, 1);
      expect(await repo.totalNilaiAsetFisikSen(), 0);
    });

    test('perawatan yang sudah lewat tetap ikut jatuh tempo', () async {
      await repo.tambahJadwalAset(
        asetId: 1,
        nama: 'Servis AC',
        intervalHari: 180,
        berikutnya: DateTime(2026, 8, 1),
      );
      final daftar = await repo.perawatanJatuhTempo(DateTime(2026, 9, 22));
      // Template bawaan (FR-83) juga terbaca — yang dibuktikan: jadwal yang
      // sudah LEWAT tidak dibuang, dan semua yang masuk memang ≤ batas.
      expect(daftar.any((p) => p.nama == 'Servis AC'), isTrue);
      expect(daftar.every((p) => !p.berikutnya.isAfter(DateTime(2026, 10, 22))),
          isTrue);
    });
  });

  group('FR-125 pengingat perawatan', () {
    test('pengingat memakai ID rentang cadangan & menyebut sisa hari', () {
      final perawatan = PerawatanData(
        id: 5,
        nama: 'Ganti oli',
        kategori: 'kendaraan',
        intervalHari: 180,
        berikutnya: DateTime(2026, 9, 27),
        leadHari: '7,1',
        urutan: 0,
        kanalPengingat: 'push',
        aktif: true,
        dibuatPada: DateTime(2026, 1, 1),
        diubahPada: DateTime(2026, 1, 1),
        asetId: 9,
      );
      final hasil = pengingatPerawatanUntuk(
        [perawatan],
        DateTime(2026, 9, 22, 7),
        namaAset: const {9: 'Honda Vario'},
      );
      expect(hasil.length, 1);
      expect(hasil.single.id, greaterThanOrEqualTo(batasIdKhusus + 200));
      expect(hasil.single.id, idPerawatanKe(0));
      expect(hasil.single.hariSebelum, 5);
      expect(hasil.single.terlambat, isFalse);
      expect(hasil.single.isi, contains('Honda Vario'));
      expect(hasil.single.isi, contains('5 hari lagi'));
    });

    test('jadwal yang lewat ditandai terlambat, bukan dibuang', () {
      final perawatan = PerawatanData(
        id: 6,
        nama: 'Servis AC',
        kategori: 'rumah',
        intervalHari: 365,
        berikutnya: DateTime(2026, 9, 1),
        leadHari: '7,1',
        urutan: 0,
        kanalPengingat: 'push',
        aktif: true,
        dibuatPada: DateTime(2026, 1, 1),
        diubahPada: DateTime(2026, 1, 1),
      );
      final hasil =
          pengingatPerawatanUntuk([perawatan], DateTime(2026, 9, 22, 10));
      expect(hasil.single.terlambat, isTrue);
      expect(hasil.single.isi, contains('lewat 21 hari'));
    });

    test('jadwal lebih dari 30 hari tidak dipasang pengingat', () {
      final perawatan = PerawatanData(
        id: 7,
        nama: 'Pajak',
        kategori: 'kendaraan',
        intervalHari: 365,
        berikutnya: DateTime(2026, 12, 1),
        leadHari: '7,1',
        urutan: 0,
        kanalPengingat: 'push',
        aktif: true,
        dibuatPada: DateTime(2026, 1, 1),
        diubahPada: DateTime(2026, 1, 1),
      );
      expect(pengingatPerawatanUntuk([perawatan], DateTime(2026, 9, 22)), isEmpty);
    });

    test('ID tidak bentrok dengan rentang briefing/sholat/dokumen', () {
      expect(idPerawatanKe(0), batasIdKhusus + 200);
      expect(idPerawatanKe(0), isNot(idBriefingPagiKe(0)));
      expect(idPerawatanKe(0), isNot(idSholatKe(0)));
    });
  });

  // -------------------------------------------------------------- layar
  group('Layar aset', () {
    late AppDatabase db;
    late RumahRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = RumahRepository(db, jamSekarang: () => DateTime(2026, 9, 22, 9));
    });

    tearDown(() => db.close());

    Widget bungkus(Widget anak) => ProviderScope(
          overrides: [repoRumahProvider.overrideWithValue(repo)],
          child: MaterialApp(home: anak),
        );

    testWidgets('daftar aset menampilkan total & status garansi',
        (t) async {
      await repo.simpanAsetFisik(
        nama: 'Honda Vario',
        jenis: JenisAsetFisik.kendaraan,
        hargaBeliSen: 2500000000,
        // tanggal relatif supaya uji tidak rusak saat hari berganti
        garansiSampai: DateTime.now().add(const Duration(days: 10)),
      );
      await t.pumpWidget(bungkus(const RumahAsetScreen()));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('aset_total')), findsOneWidget);
      expect(find.text('Rp 25.000.000'), findsOneWidget);
      expect(find.text('Honda Vario'), findsOneWidget);
      expect(find.textContaining('Garansi berakhir 10 hari lagi'), findsOneWidget);
    });

    testWidgets('rincian aset menampilkan dasar perhitungan umur pakai',
        (t) async {
      final aset = await repo.simpanAsetFisik(
        nama: 'Laptop',
        jenis: JenisAsetFisik.perangkat,
        tanggalBeli: DateTime(2023, 1, 10),
        masaPakaiBulan: 60,
        hargaBeliSen: 150000000,
        garansiSampai: DateTime.now().add(const Duration(days: 9)),
      );
      await t.pumpWidget(bungkus(AsetDetailScreen(id: aset.id)));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('aset_garansi_kartu')), findsOneWidget);
      expect(find.textContaining('Garansi berakhir 9 hari lagi'), findsOneWidget);
      expect(find.textContaining('perkiraan ganti'), findsOneWidget);
      expect(find.textContaining('saran sisihkan'), findsOneWidget);
      expect(find.textContaining('Belum ada jadwal perawatan'), findsOneWidget);
    });
  });
}
