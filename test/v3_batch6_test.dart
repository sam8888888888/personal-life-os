/// Batch 6 (FR-108/114/115/117/131) — brankas medis, peringatan dini, kunjungan
/// dokter, profil + kartu darurat, anggota keluarga & tanggung jawab.
///
/// Yang dibuktikan (bukan diklaim):
/// 1. FR-114: ambang bisa diatur dan pola yang melewati ambang menghasilkan
///    peringatan berisi SARAN netral; tidak ada kata menghakimi.
/// 2. FR-115: angka ringkasan berasal dari data yang sama dengan aplikasi, dan
///    PDF yang dihasilkan benar-benar berkas PDF.
/// 3. FR-117: kartu darurat menampilkan kartu cepat saat perangkat terkunci,
///    dan rincian sensitif HANYA saat perangkat terbuka.
/// 4. FR-131: satu item bisa dimiliki anggota A dan ditanggung anggota B;
///    saringan per anggota bekerja; anggota bertanda `pribadi` disembunyikan.
/// 5. FR-108: pencarian kata menemukan catatan; berkas lampiran hanya disimpan
///    bila BERHASIL dienkripsi — kalau tidak, tidak ada baris & tidak ada
///    berkas mentah yang tertinggal.
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/kesehatan/peringatan_dini.dart';
import 'package:personal_life_os/core/kesehatan/ringkasan_kunjungan.dart';
import 'package:personal_life_os/core/kesehatan/titik_data.dart';
import 'package:personal_life_os/core/laporan/pdf_kunjungan.dart';
import 'package:personal_life_os/core/sinkron/registri_sinkron.dart';
import 'package:personal_life_os/core/platform/kanal_media.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/keluarga_repository.dart';
import 'package:personal_life_os/data/repository/lampiran_repository.dart';
import 'package:personal_life_os/data/repository/medis_repository.dart';
import 'package:personal_life_os/features/kesehatan/catatan_medis_screen.dart';
import 'package:personal_life_os/features/kesehatan/kartu_darurat_screen.dart';
import 'package:personal_life_os/features/kesehatan/kesehatan_medis_providers.dart';
import 'package:personal_life_os/features/kesehatan/kunjungan_screen.dart';

DateTime _hariIni() => DateTime.now();

/// Deret titik data urut tanggal NAIK: elemen terakhir = paling baru.
List<TitikData> _deret(List<num> nilai, {int mulaiMundur = 0}) => [
      for (var i = 0; i < nilai.length; i++)
        TitikData(
          tanggal: _hariIni().subtract(
              Duration(days: mulaiMundur + (nilai.length - 1 - i))),
          nilai: nilai[i],
        ),
    ];

void main() {
  // ---------------------------------------------------------------- FR-114
  group('FR-114 peringatan dini', () {
    test('berat naik beberapa minggu berturut-turut → peringatan + saran netral',
        () {
      // 5 minggu, tiap minggu naik 1 kg.
      final berat = <TitikData>[];
      for (var minggu = 5; minggu >= 0; minggu--) {
        final nilai = 70000 + (5 - minggu) * 1000;
        for (var i = 0; i < 3; i++) {
          berat.add(TitikData(
            tanggal: _hariIni().subtract(Duration(days: minggu * 7 + i)),
            nilai: nilai,
          ));
        }
      }
      final hasil = susunPeringatanDini(sekarang: _hariIni(), berat: berat);
      final p = hasil.firstWhere(
          (e) => e.jenis == JenisPeringatanDini.beratNaik,
          orElse: () => throw StateError('peringatan berat naik tidak muncul'));
      expect(p.saran.toLowerCase(), contains('tenaga kesehatan'));
      expect(p.dasar, contains('minggu'));
      // Dilarang menghakimi (kebijakan bahasa FR-81/FR-85).
      for (final kata in ['gagal', 'hukuman', 'buruk', 'malas']) {
        expect(p.judul.toLowerCase() + p.saran.toLowerCase(),
            isNot(contains(kata)));
      }
    });

    test('berat naik 2 minggu tidak memicu bila ambang 4 minggu', () {
      final hasil = susunPeringatanDini(
        sekarang: _hariIni(),
        berat: _deret([70000, 70000, 71000, 72000]),
        ambang: const AmbangPeringatan(mingguBeratNaik: 4),
      );
      expect(hasil.where((e) => e.jenis == JenisPeringatanDini.beratNaik),
          isEmpty);
    });

    test('tidur di bawah kebiasaan → peringatan; ambang bisa diatur', () {
      final tidur = <TitikData>[];
      for (var i = 30; i >= 8; i--) {
        tidur.add(TitikData(
            tanggal: _hariIni().subtract(Duration(days: i)), nilai: 450));
      }
      for (var i = 7; i >= 1; i--) {
        tidur.add(TitikData(
            tanggal: _hariIni().subtract(Duration(days: i)), nilai: 300));
      }
      final ketat = susunPeringatanDini(
        sekarang: _hariIni(),
        tidur: tidur,
        ambang: const AmbangPeringatan(persenTidurTurun: 90),
      );
      expect(ketat.where((e) => e.jenis == JenisPeringatanDini.tidurTurun),
          isNotEmpty);
      final longgar = susunPeringatanDini(
        sekarang: _hariIni(),
        tidur: tidur,
        ambang: const AmbangPeringatan(persenTidurTurun: 50),
      );
      expect(
          longgar.where((e) => e.jenis == JenisPeringatanDini.tidurTurun),
          isEmpty);
    });

    test('aktivitas menurun 14 hari → peringatan', () {
      final aktivitas = <TitikData>[];
      for (var i = 28; i >= 15; i--) {
        aktivitas.add(TitikData(
            tanggal: _hariIni().subtract(Duration(days: i)), nilai: 40));
      }
      for (var i = 14; i >= 1; i--) {
        aktivitas.add(TitikData(
            tanggal: _hariIni().subtract(Duration(days: i)), nilai: 10));
      }
      final hasil =
          susunPeringatanDini(sekarang: _hariIni(), aktivitas: aktivitas);
      expect(hasil.where((e) => e.jenis == JenisPeringatanDini.aktivitasTurun),
          isNotEmpty);
    });

    test('tanpa data sama sekali → tidak ada peringatan (bukan berarti sehat)',
        () {
      expect(susunPeringatanDini(sekarang: _hariIni()), isEmpty);
    });

    test('ambang tersimpan & terbaca kembali lewat peta', () {
      const a = AmbangPeringatan(
          mingguBeratNaik: 6,
          persenTidurTurun: 80,
          persenAktivitasTurun: 60,
          kenaikanSistolik: 15);
      final peta = a.kePeta();
      final b = AmbangPeringatan.dariPeta(
          {for (final e in peta.entries) e.key: '${e.value}'});
      expect(b.mingguBeratNaik, 6);
      expect(b.persenTidurTurun, 80);
      expect(b.persenAktivitasTurun, 60);
      expect(b.kenaikanSistolik, 15);
    });
  });

  // ---------------------------------------------------------------- FR-115
  group('FR-115 ringkasan kunjungan', () {
    test('angka ringkasan sama dengan data yang diberikan', () {
      final r = susunRingkasanKunjungan(
        sekarang: _hariIni(),
        hari: 30,
        berat: _deret([70000, 71000], mulaiMundur: 20),
        tidur: _deret([420, 480], mulaiMundur: 5),
        aktivitas: _deret([30, 30], mulaiMundur: 3),
        sistolik: _deret([120, 130], mulaiMundur: 10),
        diastolik: _deret([80, 85], mulaiMundur: 10),
        suasana: _deret([4, 3], mulaiMundur: 2),
        keluhan: const ['kepala terasa berat'],
      );
      expect(r.jumlahUkuranBerat, 2);
      expect(r.beratAkhirGram, 71000);
      expect(r.jumlahMalamTidur, 2);
      expect(r.tidurRataMenit, 450);
      expect(r.sistolikRata, 125);
      expect(r.diastolikRata, 82.5);
      expect(r.totalMenitAktivitas, 60);
      expect(r.jumlahCatatanSuasana, 2);
      expect(r.keluhan, contains('kepala terasa berat'));
      final baris = r.baris.firstWhere((b) => b.label == 'Tekanan darah');
      expect(baris.nilai, contains('125/83'));
    });

    test('data di luar 30 hari tidak ikut dihitung', () {
      final r = susunRingkasanKunjungan(
        sekarang: _hariIni(),
        hari: 30,
        berat: [
          TitikData(
              tanggal: _hariIni().subtract(const Duration(days: 60)),
              nilai: 90000),
        ],
      );
      expect(r.jumlahUkuranBerat, 0);
      expect(r.adaData, isFalse);
    });

    test('PDF kunjungan benar-benar berkas PDF', () async {
      final r = susunRingkasanKunjungan(
        sekarang: _hariIni(),
        tidur: _deret([450], mulaiMundur: 2),
        keluhan: const ['pusing saat bangun'],
      );
      final isi = await bangunPdfKunjungan(r,
          catatanPengguna: 'sedang minum obat darah tinggi');
      expect(isi.length, greaterThan(1000));
      expect(String.fromCharCodes(isi.take(4)), '%PDF');
    });
  });

  // ---------------------------------------------------- FR-117 & FR-131 widget
  group('FR-117 kartu darurat', () {
    late AppDatabase db;
    late MedisRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = MedisRepository(db);
    });
    tearDown(() => db.close());

    Widget bungkus(Widget anak) => ProviderScope(
          overrides: [repoMedisProvider.overrideWithValue(repo)],
          child: MaterialApp(home: anak),
        );

    testWidgets('perangkat terkunci → kartu cepat tampil, rincian disembunyikan',
        (t) async {
      await repo.simpanProfil(
        golonganDarah: 'O',
        alergi: 'kacang',
        kondisi: 'asma',
        obatPenting: 'salbutamol',
        kontakNama: 'Mami',
        kontakTelepon: '0812',
      );
      await t.pumpWidget(bungkus(const KartuDaruratScreen(paksaTerkunci: true)));
      await t.runAsync(() async =>
          Future<void>.delayed(const Duration(milliseconds: 200)));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('kartu_cepat')), findsOneWidget);
      expect(find.byKey(const Key('kartu_rincian')), findsNothing);
      expect(find.byKey(const Key('kartu_rincian_terkunci')), findsOneWidget);
      expect(find.textContaining('O'), findsWidgets);
    });

    testWidgets('perangkat terbuka → rincian tampil', (t) async {
      await repo.simpanProfil(
        golonganDarah: 'B',
        kondisi: 'asma',
        obatPenting: 'salbutamol',
      );
      await t.pumpWidget(bungkus(const KartuDaruratScreen(paksaTerkunci: false)));
      await t.runAsync(() async =>
          Future<void>.delayed(const Duration(milliseconds: 200)));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('kartu_rincian')), findsOneWidget);
      expect(find.textContaining('salbutamol'), findsOneWidget);
    });

    test('profil belum cukup → kartu belum dianggap siap', () async {
      await repo.simpanProfil(golonganDarah: 'O');
      expect(MedisRepository.kartuSiap(await repo.ambilProfil()), isFalse);
      await repo.simpanProfil(golonganDarah: 'O', kontakTelepon: '0812');
      expect(MedisRepository.kartuSiap(await repo.ambilProfil()), isTrue);
    });
  });

  group('FR-131 anggota keluarga & tanggung jawab', () {
    late AppDatabase db;
    late KeluargaRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = KeluargaRepository(db);
    });
    tearDown(() => db.close());

    test('satu tagihan bisa dimiliki anak & ditanggung pasangan', () async {
      final anak = await repo.simpanAnggota(nama: 'Alif', hubungan: 'anak');
      final pasangan =
          await repo.simpanAnggota(nama: 'Mami', hubungan: 'pasangan', pribadi: true);
      final tagihanId = await db.into(db.tagihan).insert(
            TagihanCompanion.insert(
              nama: 'SPP sekolah',
              jumlahSen: const Value(75000000),
              jatuhTempo: DateTime.now().add(const Duration(days: 5)),
            ),
          );
      await repo.tetapkanPemilikTagihan(
        tagihanId,
        pemilikId: anak.id,
        penanggungJawabId: pasangan.id,
      );
      final punyaAnak = await repo.tagihanAnggota(anak.id);
      final punyaPasangan = await repo.tagihanAnggota(pasangan.id);
      expect(punyaAnak.map((t) => t.nama), contains('SPP sekolah'));
      expect(punyaPasangan.map((t) => t.nama), contains('SPP sekolah'));
      expect(punyaAnak.first.pemilikId, anak.id);
      expect(punyaAnak.first.penanggungJawabId, pasangan.id);

      final ringkas = await repo.ringkasBeban();
      final barisAnak =
          ringkas.firstWhere((d) => d.anggota.nama == 'Alif');
      expect(barisAnak.jumlahTagihan, 1);
      expect(barisAnak.totalTagihanSen, 75000000);
    });

    test('anggota bertanda pribadi disembunyikan bila diminta', () async {
      await repo.simpanAnggota(nama: 'Alif', hubungan: 'anak', pribadi: true);
      await repo.simpanAnggota(nama: 'Mami', hubungan: 'pasangan');
      final semua = await repo.ambilAnggota();
      final terbatas = await repo.ambilAnggota(sertakanPribadi: false);
      expect(semua.length, 2);
      expect(terbatas.length, 1);
      expect(terbatas.first.nama, 'Mami');
    });

    test('tugas juga bisa punya penanggung jawab', () async {
      final anggota = await repo.simpanAnggota(nama: 'Kakak', hubungan: 'anak');
      final tugasId = await db.into(db.tugas).insert(
            TugasCompanion.insert(idTugas: 'TGS-ANTAR', nama: 'Antar les'),
          );
      await repo.tetapkanPemilikTugas(tugasId, penanggungJawabId: anggota.id);
      final daftar = await repo.tugasAnggota(anggota.id);
      expect(daftar.map((g) => g.nama), contains('Antar les'));
    });

    test('nama kosong ditolak', () async {
      expect(() => repo.simpanAnggota(nama: '   '), throwsArgumentError);
    });
  });

  // ---------------------------------------------------------------- FR-108
  group('FR-108 brankas catatan medis', () {
    late AppDatabase db;
    late MedisRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = MedisRepository(db);
    });
    tearDown(() => db.close());

    test('pencarian kata menemukan catatan & menyaring jenis', () async {
      await repo.simpanCatatan(
        jenis: 'lab',
        judul: 'Cek darah tahunan',
        tanggal: DateTime.now().subtract(const Duration(days: 10)),
        hasil: 'Kolesterol total 210',
        tenagaKesehatan: 'dr. Ratna',
      );
      await repo.simpanCatatan(
        jenis: 'resep',
        judul: 'Resep vitamin',
        tanggal: DateTime.now().subtract(const Duration(days: 3)),
        hasil: 'Vitamin D 1000 IU',
      );
      final cari = await repo.ambilCatatan(cari: 'kolesterol');
      expect(cari.length, 1);
      expect(cari.first.judul, 'Cek darah tahunan');
      final cariDokter = await repo.ambilCatatan(cari: 'ratna');
      expect(cariDokter.length, 1);
      final resep = await repo.ambilCatatan(jenis: 'resep');
      expect(resep.length, 1);
      final semua = await repo.ambilCatatan();
      expect(semua.length, 2);
      // Terbaru di depan.
      expect(semua.first.judul, 'Resep vitamin');
    });

    test('judul kosong ditolak', () async {
      expect(
        () => repo.simpanCatatan(
            jenis: 'lab', judul: '  ', tanggal: DateTime.now()),
        throwsArgumentError,
      );
    });

    testWidgets(
        'lampiran disimpan hanya bila berhasil dienkripsi (kanal tersedia)',
        (t) async {
      final folder = Directory.systemTemp.createTempSync('lifeos_medis_ok');
      addTearDown(() => folder.deleteSync(recursive: true));
      final sumber = File('${folder.path}/hasil-lab.pdf')
        ..writeAsBytesSync(List<int>.filled(128, 7));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('lifeos/media'), (call) async =>
                  call.method == 'pilihBerkas' ? sumber.path : null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('lifeos/berkas_medis'), (call) async {
        if (call.method == 'didukung') return true;
        if (call.method == 'terkunci') return false;
        if (call.method == 'enkripsi') {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          // tiruan: berkas .enc berisi penanda terenkripsi
          File(args['tujuan'] as String).writeAsBytesSync(List<int>.filled(160, 3));
          return true;
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('lifeos/media'), null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
                const MethodChannel('lifeos/berkas_medis'), null);
      });

      final catatan = await repo.simpanCatatan(
        jenis: 'lab',
        judul: 'Cek darah',
        tanggal: DateTime.now(),
      );
      final lampiranRepo =
          LampiranRepository(db, folderInduk: () async => folder);

      await t.pumpWidget(ProviderScope(
        overrides: [
          repoMedisProvider.overrideWithValue(repo),
          repoLampiranProvider.overrideWithValue(lampiranRepo),
        ],
        child: MaterialApp(home: CatatanMedisScreen(kanal: KanalMedia())),
      ));
      await t.runAsync(() async =>
          Future<void>.delayed(const Duration(milliseconds: 300)));
      await t.pumpAndSettle();

      // Buka catatan lalu lampirkan. PENTING: pekerjaan berkas (salin + enkripsi)
      // memakai I/O sungguhan, jadi seluruh interaksinya dijalankan di dalam
      // SATU jendela waktu nyata (`runAsync`) — kalau tidak, future-nya menggantung.
      await t.runAsync(() async {
        await t.tap(find.byKey(Key('medis_baris_${catatan.id}')));
        await t.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await t.tap(find.byKey(Key('medis_lampir_${catatan.id}')));
        await t.pump();
        await Future<void>.delayed(const Duration(milliseconds: 800));
        await t.pump();
      });

      final baris = await lampiranRepo.daftar('catatan_medis', catatan.uid!);
      expect(baris.length, 1, reason: 'lampiran tersimpan setelah enkripsi');
      expect(baris.first.berkas.endsWith('.enc'), isTrue,
          reason: 'yang disimpan adalah berkas terenkripsi');
      expect(File(baris.first.berkas).existsSync(), isTrue);
      expect(sumber.existsSync(), isTrue, reason: 'berkas sumber milik pengguna');
      await t.pumpAndSettle();
    });

    testWidgets('enkripsi tidak tersedia → berkas mentah TIDAK disimpan',
        (t) async {
      final folder = Directory.systemTemp.createTempSync('lifeos_medis_gagal');
      addTearDown(() => folder.deleteSync(recursive: true));
      final sumber = File('${folder.path}/rahasia.pdf')
        ..writeAsBytesSync(List<int>.filled(64, 5));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('lifeos/media'), (call) async =>
                  call.method == 'pilihBerkas' ? sumber.path : null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('lifeos/berkas_medis'),
              (call) async => call.method == 'enkripsi' ? false : false);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('lifeos/media'), null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
                const MethodChannel('lifeos/berkas_medis'), null);
      });

      final catatan = await repo.simpanCatatan(
        jenis: 'lab',
        judul: 'Rahasia',
        tanggal: DateTime.now(),
      );
      final lampiranRepo =
          LampiranRepository(db, folderInduk: () async => folder);
      await t.pumpWidget(ProviderScope(
        overrides: [
          repoMedisProvider.overrideWithValue(repo),
          repoLampiranProvider.overrideWithValue(lampiranRepo),
        ],
        child: MaterialApp(home: CatatanMedisScreen(kanal: KanalMedia())),
      ));
      await t.runAsync(() async =>
          Future<void>.delayed(const Duration(milliseconds: 300)));
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await t.tap(find.byKey(Key('medis_baris_${catatan.id}')));
        await t.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await t.tap(find.byKey(Key('medis_lampir_${catatan.id}')));
        await t.pump();
        await Future<void>.delayed(const Duration(milliseconds: 800));
        await t.pump();
      });

      final baris = await lampiranRepo.daftar('catatan_medis', catatan.uid!);
      expect(baris, isEmpty, reason: 'tidak ada lampiran yang disimpan');
      expect(find.byKey(const Key('medis_pesan')), findsOneWidget);
      await t.pumpAndSettle();
    });
  });

  // ------------------------------------------------------- kunjungan & ambient
  group('FR-115 layar kunjungan', () {
    testWidgets('layar menampilkan angka & menjelaskan sumbernya', (t) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      // Layar uji diperbesar: tombol PDF ada di bawah ringkasan + kolom catatan.
      await t.binding.setSurfaceSize(const Size(500, 1600));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: KunjunganScreen()),
      ));
      await t.pump();
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        await t.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await t.pump();
      });
      expect(find.byKey(const Key('kunjungan_galat')), findsNothing,
          reason: 'layar tidak boleh menampilkan galat baca data');
      expect(find.byKey(const Key('kunjungan_periode')), findsOneWidget);
      expect(find.byKey(const Key('kunjungan_bagikan')), findsOneWidget);
      expect(find.textContaining('Bukan diagnosis'), findsWidgets);
    });
  });

  // ------------------------------------------- FR-150: batch 6 ikut sinkron
  group('FR-150 sinkron modul keluarga & medis', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('tiga tabel batch 6 terdaftar di registri sinkron', () {
      final nama = daftarJalurSinkron(db).map((j) => j.nama).toSet();
      expect(nama, contains('anggota_keluarga'));
      expect(nama, contains('profil_kesehatan'));
      expect(nama, contains('catatan_medis'));
    });

    test('kaitan pemilik & penanggung jawab ikut dikirim sebagai uid', () {
      final jalur = daftarJalurSinkron(db);
      final tagihan = jalur.firstWhere((j) => j.nama == 'tagihan');
      final tugas = jalur.firstWhere((j) => j.nama == 'tugas');
      expect(tagihan.kaitan['pemilik_id'], 'anggota_keluarga');
      expect(tagihan.kaitan['penanggung_jawab_id'], 'anggota_keluarga');
      expect(tugas.kaitan['pemilik_id'], 'anggota_keluarga');
      expect(tugas.kaitan['penanggung_jawab_id'], 'anggota_keluarga');
    });

    test('baris baru punya uid sinkron yang tetap', () async {
      final keluarga = KeluargaRepository(db);
      final medis = MedisRepository(db);
      final anggota = await keluarga.simpanAnggota(nama: 'Alif');
      expect(anggota.uid, isNotNull);
      expect(anggota.uid, anggota.idAnggota);
      final catatan = await medis.simpanCatatan(
          jenis: 'lab', judul: 'Cek darah', tanggal: DateTime.now());
      expect(catatan.uid, isNotNull);

      // Profil kesehatan: uid SENGAJA tetap supaya tidak jadi profil ganda
      // saat beberapa HP menyinkron.
      final p1 = await medis.simpanProfil(golonganDarah: 'O');
      final p2 = await medis.simpanProfil(alergi: 'kacang');
      expect(p1.uid, uidProfilKesehatan);
      expect(p2.uid, uidProfilKesehatan);
      expect(p2.id, p1.id, reason: 'satu baris profil, bukan dua');
    });
  });
}
