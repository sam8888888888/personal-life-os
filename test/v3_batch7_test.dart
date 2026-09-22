/// Batch 7 (FR-132/140/141/144/145) — kalender keluarga, lini masa hidup,
/// analitik pribadi, tinjauan pekan, laporan bulanan.
///
/// Yang dibuktikan (bukan diklaim):
/// 1. FR-132: satu tampilan memuat agenda semua anggota dan warna tiap anggota
///    BERBEDA (kriteria terima PRD) — diuji pada logika & pada layar.
/// 2. FR-140: lini masa tersusun dari data nyata, bisa dicari & disaring per
///    modul, dan ada rangkuman "apa yang terjadi bulan ini".
/// 3. FR-141: SETIAP angka menyebut sumbernya (tidak ada angka misterius).
/// 4. FR-144: rekap pekan per pilar membandingkan pekan ini vs pekan lalu, bisa
///    disimpan, dan pengingat mingguan DILEWATI bila sudah diisi.
/// 5. FR-145: laporan bulanan memuat bagian yang diminta PRD, tiga kelompok
///    (membaik/berubah/perlu perhatian), bisa diarsipkan, dan PDF-nya benar
///    berkas PDF.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/analitik/analitik_hidup.dart';
import 'package:personal_life_os/core/analitik/bahan_analitik.dart';
import 'package:personal_life_os/core/keluarga/kalender_keluarga.dart';
import 'package:personal_life_os/core/laporan/laporan_hidup_bulanan.dart';
import 'package:personal_life_os/core/laporan/pdf_laporan_hidup.dart';
import 'package:personal_life_os/core/laporan/ringkas_pekan.dart';
import 'package:personal_life_os/core/notifikasi/perencana_pengingat.dart';
import 'package:personal_life_os/core/notifikasi/sumber_pengingat_tambahan.dart';
import 'package:personal_life_os/core/sinkron/registri_sinkron.dart';
import 'package:personal_life_os/core/timeline/lini_masa.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/hidup_repository.dart';
import 'package:personal_life_os/data/repository/tinjauan_repository.dart';
import 'package:personal_life_os/features/keluarga/kalender_keluarga_screen.dart';
import 'package:personal_life_os/features/ritme/analitik_screen.dart';
import 'package:personal_life_os/features/ritme/laporan_bulanan_screen.dart';
import 'package:personal_life_os/features/ritme/lini_masa_screen.dart';
import 'package:personal_life_os/features/ritme/pengingat_tinjauan_pekan.dart';
import 'package:personal_life_os/features/ritme/ritme_providers.dart';
import 'package:personal_life_os/features/ritme/tinjauan_pekan_screen.dart';

/// Selasa, 22 Sep 2026 pukul 09:00 — pekan berjalan = 21–27 Sep.
final DateTime _kini = DateTime(2026, 9, 22, 9);

DateTime _hari(int hariMundur) =>
    DateTime(_kini.year, _kini.month, _kini.day - hariMundur, 10);

AgendaKeluarga _agenda({
  required DateTime tanggal,
  required String judul,
  required String modul,
  int? anggotaId,
  String keterangan = '',
}) =>
    AgendaKeluarga(
      tanggal: tanggal,
      judul: judul,
      modul: modul,
      anggotaId: anggotaId,
      keterangan: keterangan,
    );

/// Gulir sampai [target] benar-benar terbangun di layar.
///
/// Daftar di layar-layar ini panjang (bagian laporan & kartu pilar), dan
/// ListView membangun isinya secara malas — tanpa gulir, widget di bawah
/// lipatan tidak ada sehingga uji gagal karena alasan yang salah.
Future<void> _gulirKe(WidgetTester t, Finder target) async {
  await t.dragUntilVisible(
    target,
    find.byType(Scrollable).first,
    const Offset(0, -220),
  );
  await t.pumpAndSettle();
}

void main() {
  // ══════════════════════════════════════════════════════════════ FR-132
  group('FR-132 kalender keluarga — logika', () {
    test('warna tiap anggota BERBEDA (kriteria terima PRD)', () {
      final agenda = [
        _agenda(tanggal: _hari(0), judul: 'SPP', modul: 'tagihan', anggotaId: 1),
        _agenda(tanggal: _hari(0), judul: 'Antar les', modul: 'tugas', anggotaId: 2),
        _agenda(tanggal: _hari(1), judul: 'Periksa gigi', modul: 'janji', anggotaId: 3),
      ];
      final peta = warnaAnggotaUntuk(agenda);
      final warna = [1, 2, 3].map((id) => warnaUntukAnggota(id, peta)).toList();
      expect(warna.toSet().length, 3, reason: 'tiga anggota = tiga warna beda');
      // agenda bersama (tanpa anggota) punya warna netral sendiri
      expect(warnaUntukAnggota(null, peta), isNot(warna.first));
    });

    test('agenda dikelompokkan per hari dan urut tanggal', () {
      final hari = susunKalenderKeluarga(
        agenda: [
          _agenda(tanggal: _hari(0), judul: 'B', modul: 'tugas'),
          _agenda(tanggal: _hari(2), judul: 'A', modul: 'tagihan'),
          _agenda(tanggal: _hari(0), judul: 'C', modul: 'janji'),
        ],
        dari: _hari(7),
        sampai: _kini,
      );
      expect(hari.length, 2);
      expect(hari.first.tanggal.isBefore(hari.last.tanggal), isTrue);
      expect(hari.last.agenda.length, 2);
    });

    test('saringan anggota menyisakan agenda anggota itu saja', () {
      final hari = susunKalenderKeluarga(
        agenda: [
          _agenda(tanggal: _hari(0), judul: 'Anak', modul: 'tugas', anggotaId: 7),
          _agenda(tanggal: _hari(0), judul: 'Pasangan', modul: 'tugas', anggotaId: 8),
        ],
        dari: _hari(7),
        sampai: _kini,
        saringAnggota: 7,
      );
      expect(hari.single.agenda.single.judul, 'Anak');
    });

    test('ulang tahun dihitung dari tanggal lahir + umurnya', () {
      final hari = ulangTahunAnggota(
        anggota: [
          (id: 1, nama: 'Nadine', lahir: DateTime(2015, 9, 25)),
          (id: 2, nama: 'Tanpa tanggal', lahir: null),
        ],
        tahun: 2026,
      );
      expect(hari.length, 1);
      expect(hari.single.judul, contains('Nadine'));
      expect(hari.single.keterangan, 'ke-11');
      expect(hari.single.tanggal, DateTime(2026, 9, 25));
    });
  });

  group('FR-132 kalender keluarga — layar', () {
    late AppDatabase db;
    late HidupRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = HidupRepository(db, jamSekarang: () => _kini);
    });

    tearDown(() => db.close());

    Widget bungkus(Widget anak) => ProviderScope(
          overrides: [repoHidupProvider.overrideWithValue(repo)],
          child: MaterialApp(home: anak),
        );

    testWidgets('menampilkan bulan, agenda hari ini, dan warna per anggota',
        (t) async {
      final anggota = await db.into(db.anggotaKeluarga).insert(
            AnggotaKeluargaCompanion.insert(
              uid: const Value('ang_1'),
              idAnggota: 'ang_1',
              nama: 'Nadine',
            ),
          );
      final pasangan = await db.into(db.anggotaKeluarga).insert(
            AnggotaKeluargaCompanion.insert(
              uid: const Value('ang_2'),
              idAnggota: 'ang_2',
              nama: 'Pasangan',
            ),
          );
      await db.into(db.tagihan).insert(TagihanCompanion.insert(
            uid: const Value('tg_1'),
            nama: 'SPP sekolah',
            jumlahSen: const Value(1500000),
            jatuhTempo: DateTime(_kini.year, _kini.month, _kini.day, 8),
            pemilikId: Value(anggota),
          ));
      await db.into(db.tugas).insert(TugasCompanion.insert(
            uid: const Value('tg_2'),
            idTugas: 'tg_2',
            nama: 'Antar les',
            jatuhTempo: Value(DateTime(_kini.year, _kini.month, _kini.day, 15)),
            penanggungJawabId: Value(pasangan),
          ));

      await t.pumpWidget(bungkus(const KalenderKeluargaScreen()));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('kalender_bulan')), findsOneWidget);
      expect(find.byKey(const Key('kalender_ringkas')), findsOneWidget);
      expect(find.textContaining('SPP sekolah'), findsOneWidget);
      expect(find.textContaining('Antar les'), findsOneWidget);

      // warna chip kedua anggota harus berbeda
      await _gulirKe(t, find.byKey(Key('kalender_warna_$anggota')));
      final chip1 = t.widget<Chip>(find.byKey(Key('kalender_warna_$anggota')));
      final chip2 = t.widget<Chip>(find.byKey(Key('kalender_warna_$pasangan')));
      final w1 = (chip1.avatar! as CircleAvatar).backgroundColor;
      final w2 = (chip2.avatar! as CircleAvatar).backgroundColor;
      expect(w1, isNot(w2));
      expect(find.byKey(Key('kalender_saring_$anggota')), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════ FR-140
  group('FR-140 lini masa hidup — logika', () {
    test('dikelompokkan per bulan, terbaru di atas, urut tanggal', () {
      final bulan = susunLiniMasa(peristiwa: [
        PeristiwaHidup(
            tanggal: DateTime(2026, 9, 20),
            modul: 'uang',
            judul: 'Tagihan dibayar',
            rujukan: 'tagihan#1'),
        PeristiwaHidup(
            tanggal: DateTime(2026, 8, 5),
            modul: 'kesehatan',
            judul: 'Catatan medis',
            rujukan: 'catatan_medis#2'),
        PeristiwaHidup(
            tanggal: DateTime(2026, 9, 25),
            modul: 'tugas',
            judul: 'Tugas selesai',
            rujukan: 'tugas#3'),
      ]);
      expect(bulan.length, 2);
      expect(bulan.first.kunci, '2026-09');
      expect(bulan.first.peristiwa.first.tanggal, DateTime(2026, 9, 25));
    });

    test('saringan modul & pencarian kata bekerja', () {
      final daftar = [
        PeristiwaHidup(
            tanggal: DateTime(2026, 9, 20),
            modul: 'uang',
            judul: 'Bayar SPP',
            rujukan: 'tagihan#1'),
        PeristiwaHidup(
            tanggal: DateTime(2026, 9, 21),
            modul: 'kesehatan',
            judul: 'Periksa gigi',
            rujukan: 'janji#2'),
      ];
      expect(susunLiniMasa(peristiwa: daftar, modul: 'kesehatan').single
          .peristiwa.single.judul, 'Periksa gigi');
      expect(susunLiniMasa(peristiwa: daftar, cari: 'spp').single.peristiwa
          .single.modul, 'uang');
      expect(susunLiniMasa(peristiwa: daftar, cari: 'tidak ada'), isEmpty);
    });

    test('rangkuman bulan ini menyebut jumlah kejadian dari data nyata', () {
      final daftar = [
        for (var i = 0; i < 3; i++)
          PeristiwaHidup(
              tanggal: DateTime(2026, 9, 10 + i),
              modul: 'uang',
              judul: 'x',
              rujukan: 'transaksi#$i'),
        PeristiwaHidup(
            tanggal: DateTime(2026, 8, 1),
            modul: 'tugas',
            judul: 'y',
            rujukan: 'tugas#9'),
      ];
      final teks = ringkasBulanIni(daftar, DateTime(2026, 9, 15));
      expect(teks, contains('3 kejadian'));
      expect(teks, contains('Uang'));
    });

    test('labelBulan memakai nama bulan Indonesia', () {
      expect(labelBulan('2026-09'), 'September 2026');
      expect(labelBulan('rusak'), 'rusak');
    });
  });

  group('FR-140 lini masa hidup — layar', () {
    late AppDatabase db;
    late HidupRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = HidupRepository(db, jamSekarang: () => _kini);
    });

    tearDown(() => db.close());

    testWidgets('menampilkan kejadian nyata beserta sumber datanya',
        (t) async {
      await db.into(db.tugas).insert(TugasCompanion.insert(
            uid: const Value('t1'),
            idTugas: 't1',
            nama: 'Bayar SPP',
            jatuhTempo: Value(_hari(1)),
            selesai: const Value(true),
            selesaiPada: Value(_hari(1)),
          ));

      await t.pumpWidget(ProviderScope(
        overrides: [repoHidupProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: LiniMasaScreen()),
      ));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('lini_ringkas')), findsOneWidget);
      expect(find.byKey(const Key('lini_cari')), findsOneWidget);
      expect(find.textContaining('Bayar SPP'), findsOneWidget);
      expect(find.textContaining('sumber: tugas#'), findsOneWidget);
      expect(find.byKey(const Key('lini_saring_kesehatan')), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════ FR-141
  group('FR-141 analitik — logika', () {
    test('SETIAP angka menyebut sumbernya (kriteria terima PRD)', () {
      final bahan = BahanAnalitik(
        dari: DateTime(2026, 8, 24),
        sampai: DateTime(2026, 9, 22),
        hari: 30,
        tagihanLunas: 4,
        totalBayarSen: 40000000,
        transaksiBaru: 12,
        pengeluaranSen: 30000000,
        pemasukanSen: 50000000,
        tugasSelesai: 7,
        tugasBaru: 5,
        tugasTerbuka: 3,
        hariAktivitas: 10,
        menitAktivitas: 300,
        menitTidur: 2400,
        malamTidurTercatat: 6,
        ukuranTubuh: 4,
        catatanMedis: 2,
        catatanPengetahuan: 6,
        keputusanBaru: 1,
        bacaanSelesai: 1,
        kartuDiulang: 30,
        hafalanBaru: 3,
        zakatSen: 500000,
        perawatanAset: 1,
        langgananAktif: 2,
        kekayaanBersihSen: 100000000,
      );
      final metrik = susunAnalitik(bahan);
      expect(metrik, isNotEmpty);
      for (final m in metrik) {
        expect(m.sumber.trim(), isNotEmpty,
            reason: 'metrik "${m.nama}" wajib menyebut sumbernya');
        // Sumber harus menunjuk asal datanya (tabel atau perhitungan antar tabel)
        expect(
          m.sumber.contains('tabel') ||
              m.sumber.contains('aset') ||
              m.sumber.contains('transaksi'),
          isTrue,
          reason: 'sumber "${m.sumber}" harus menyebut tabel asalnya',
        );
      }
      // penyaring kelompok
      final hanyaUang = susunAnalitik(bahan, saringKelompok: {'Uang'});
      expect(hanyaUang.every((m) => m.kelompok == 'Uang'), isTrue);
    });

    test('rentang yang disediakan PRD: 7/30/90 hari & 1 tahun', () {
      expect(rentangAnalitik, [7, 30, 90, 365]);
      expect(labelRentang(365), '1 tahun');
      expect(labelRentang(7), '7 hari');
    });

    test('bahan kosong → tidak ada angka karangan', () {
      final metrik = susunAnalitik(
          BahanAnalitik.kosong(DateTime(2026, 9, 1), DateTime(2026, 9, 22), hari: 30));
      expect(metrik, isEmpty);
    });
  });

  group('FR-141 analitik — layar', () {
    late AppDatabase db;
    late HidupRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = HidupRepository(db, jamSekarang: () => _kini);
    });

    tearDown(() => db.close());

    testWidgets('menampilkan angka beserta baris sumbernya', (t) async {
      await db.into(db.transaksi).insert(TransaksiCompanion.insert(
            uid: const Value('trx_1'),
            idTransaksi: 'trx_1',
            jenis: const Value('pengeluaran'),
            tanggal: _hari(1),
            jumlahSen: 250000,
          ));
      await t.pumpWidget(ProviderScope(
        overrides: [repoHidupProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: AnalitikScreen()),
      ));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('analitik_rentang_30')), findsOneWidget);
      expect(
          find.byKey(const Key('analitik_metrik_Catatan_transaksi')),
          findsOneWidget);
      final sumber = t.widget<Text>(
          find.byKey(const Key('analitik_sumber_Catatan_transaksi')));
      expect(sumber.data, contains('tabel transaksi'));
      expect((sumber.data ?? ''), contains('30 hari'));
    });
  });

  // ══════════════════════════════════════════════════════════════ FR-144
  group('FR-144 tinjauan pekan — logika', () {
    BahanAnalitik bahan(int minggu, {int tugas = 0, int aktivitas = 0, int kas = 0}) =>
        BahanAnalitik(
          dari: _kini.subtract(Duration(days: 7 * minggu)),
          sampai: _kini.subtract(Duration(days: 7 * minggu - 6)),
          hari: 7,
          tugasSelesai: tugas,
          hariAktivitas: aktivitas,
          pemasukanSen: kas,
          tugasTerbuka: 2,
        );

    test('naik = membaik, turun = perlu perhatian (dengan angkanya)', () {
      final r = susunRingkasPekan(
        ini: bahan(0, tugas: 6, aktivitas: 5, kas: 1000000),
        lalu: bahan(1, tugas: 3, aktivitas: 2, kas: 500000),
      );
      final tugas =
          r.pilar.firstWhere((p) => p.pilar == 'Tujuan & tugas');
      expect(tugas.membaik.join(), contains('Tugas selesai 6 (pekan lalu 3)'));
      final kes = r.pilar.firstWhere((p) => p.pilar == 'Kesehatan');
      expect(kes.membaik.join(), contains('Hari beraktivitas 5 (pekan lalu 2)'));
    });

    test('penurunan tercatat sebagai perlu perhatian', () {
      final r = susunRingkasPekan(
        ini: bahan(0, tugas: 1),
        lalu: bahan(1, tugas: 8),
      );
      final tugas = r.pilar.firstWhere((p) => p.pilar == 'Tujuan & tugas');
      expect(tugas.perluPerhatian.join(), contains('Tugas selesai 1 (pekan lalu 8)'));
    });

    test('teks notifikasi ringkas memuat membaik & fokus', () {
      final r = susunRingkasPekan(
        ini: bahan(0, tugas: 6),
        lalu: bahan(1, tugas: 3),
        tugasPenting: ['Bayar SPP (2 hari lagi)'],
        tujuanTerdekat: ['Dana pendidikan (30 hari lagi)'],
      );
      final teks = r.ringkasNotifikasi;
      expect(teks, contains('Membaik'));
      expect(teks, contains('Fokus pekan depan'));
      expect(teks.length, lessThan(400), reason: 'notifikasi harus ringkas');
    });

    test('enam pilar diuji semuanya', () {
      expect(pilarPekan().length, 6);
      final r = susunRingkasPekan(ini: bahan(0), lalu: bahan(1));
      expect(r.pilar.map((p) => p.pilar).toList(), pilarPekan());
    });

    test('awalPekan = Senin dan label pekan benar', () {
      expect(awalPekan(DateTime(2026, 9, 22)).weekday, DateTime.monday);
      expect(awalPekan(DateTime(2026, 9, 22)), DateTime(2026, 9, 21));
      expect(labelPekan(DateTime(2026, 9, 21)), '21–27 Sep 2026');
    });
  });

  group('FR-144 tinjauan pekan — simpan & pengingat', () {
    late AppDatabase db;
    late TinjauanRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = TinjauanRepository(db, jamSekarang: () => _kini);
    });

    tearDown(() => db.close());

    test('simpan dua kali tidak menggandakan baris (uid stabil)', () async {
      final senin = DateTime(2026, 9, 21);
      await repo.simpanPekan(pekanMulai: senin, membaik: 'Olahraga rutin');
      await repo.simpanPekan(
          pekanMulai: senin, membaik: 'Olahraga rutin', perluPerhatian: 'Tidur');
      final semua = await repo.riwayatPekan();
      expect(semua.length, 1);
      expect(semua.single.perluPerhatian, 'Tidur');
      expect(semua.single.uid, 'tw_2026-09-21');
    });

    test('pengingat dijadwalkan Minggu 20:00 dan DILEWATI bila sudah diisi',
        () async {
      final senin = DateTime(2026, 9, 21);
      expect(idTinjauanPekanKe(0), greaterThan(batasIdKhusus));
      expect(idTinjauanPekanKe(0),
          isNot(anyOf(idBriefingPagiKe(0), idSholatKe(0), idRingkasanMingguan)));

      // Senin 22 Sep (sebelum Minggu 27 Sep) → jatuh pada pekan ini
      final p = pengingatTinjauanPekanUntuk(DateTime(2026, 9, 22, 9));
      expect(p.length, 1);
      expect(p.single.waktu, DateTime(2026, 9, 27, jamTinjauanPekan));
      expect(p.single.isi.toLowerCase(), contains('tinjauan'));

      // setelah diisi → tidak ada pengingat
      expect(pengingatTinjauanPekanUntuk(DateTime(2026, 9, 22, 9), sudahSelesai: true),
          isEmpty);

      await repo.simpanPekan(pekanMulai: senin, membaik: 'x', selesai: true);
      final SumberPengingatTambahan sumber = SumberPengingatTinjauanPekan(
        pembukaBasisData: () => db,
        tutupBasisData: false,
        jam: jamTinjauanPekan,
      );
      // sumber wajib menyanggupi kontrak mesin pengingat (bukan tipe lain)
      expect(sumber, isA<SumberPengingatTambahan>());
      expect(await sumber.pengingatTambahan(DateTime(2026, 9, 22, 9)), isEmpty);
    });

    test('pengingat lewat waktunya pekan ini → pindah ke pekan depan', () {
      // Minggu 27 Sep 21:00 (sudah lewat jam 20:00) → minggu berikutnya
      final p = pengingatTinjauanPekanUntuk(DateTime(2026, 9, 27, 21));
      expect(p.single.waktu, DateTime(2026, 10, 4, jamTinjauanPekan));
    });
  });

  group('FR-144 tinjauan pekan — layar', () {
    late AppDatabase db;
    late HidupRepository hidup;
    late TinjauanRepository tinjauan;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      hidup = HidupRepository(db, jamSekarang: () => _kini);
      tinjauan = TinjauanRepository(db, jamSekarang: () => _kini);
    });

    tearDown(() => db.close());

    testWidgets('rekap pekan tampil dan dapat disimpan', (t) async {
      // tugas selesai pekan ini dan pekan lalu (agar ada pembanding)
      for (var i = 0; i < 3; i++) {
        await db.into(db.tugas).insert(TugasCompanion.insert(
              uid: Value('t_now_$i'),
              idTugas: 't_now_$i',
              nama: 'Tugas $i',
              jatuhTempo: Value(_hari(i)),
              selesai: const Value(true),
              selesaiPada: Value(_hari(i)),
            ));
      }
      await db.into(db.tugas).insert(TugasCompanion.insert(
            uid: const Value('t_lalu'),
            idTugas: 't_lalu',
            nama: 'Tugas lama',
            jatuhTempo: Value(_hari(9)),
            selesai: const Value(true),
            selesaiPada: Value(_hari(9)),
          ));

      await t.pumpWidget(ProviderScope(
        overrides: [
          repoHidupProvider.overrideWithValue(hidup),
          repoTinjauanProvider.overrideWithValue(tinjauan),
        ],
        child: const MaterialApp(home: TinjauanPekanScreen()),
      ));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('tinjauan_pekan_label')), findsOneWidget);
      expect(find.byKey(const Key('tinjauan_pekan_ringkas_notifikasi')),
          findsOneWidget);
      expect(find.byKey(const Key('tinjauan_pilar_Tujuan_&_tugas')),
          findsOneWidget);

      await _gulirKe(t, find.byKey(const Key('tinjauan_pekan_membaik')));
      await t.enterText(find.byKey(const Key('tinjauan_pekan_membaik')),
          'Lebih rutin olahraga');
      await _gulirKe(t, find.byKey(const Key('tinjauan_pekan_fokus')));
      await t.enterText(
          find.byKey(const Key('tinjauan_pekan_fokus')), 'Selesaikan SPP');
      await _gulirKe(t, find.byKey(const Key('tinjauan_pekan_simpan')));
      await t.tap(find.byKey(const Key('tinjauan_pekan_simpan')));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('tinjauan_pekan_pesan')), findsOneWidget);
      final tersimpan = await tinjauan.riwayatPekan();
      expect(tersimpan.length, 1);
      expect(tersimpan.single.membaik, 'Lebih rutin olahraga');
      expect(tersimpan.single.fokusPekanDepan, 'Selesaikan SPP');
      expect(tersimpan.single.selesai, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════ FR-145
  group('FR-145 laporan bulanan — logika', () {
    BahanAnalitik bulan(String kunci, {
      int tagihanLunas = 0,
      int bayarSen = 0,
      int masukSen = 0,
      int keluarSen = 0,
      int tugasSelesai = 0,
      int tugasTerbuka = 0,
      int kekayaanSen = 0,
      int transaksi = 0,
      int aktivitas = 0,
      int catatan = 0,
      int perawatan = 0,
    }) {
      final r = rentangBulan(kunci);
      return BahanAnalitik(
        dari: r.dari,
        sampai: r.sampai,
        tagihanLunas: tagihanLunas,
        totalBayarSen: bayarSen,
        pemasukanSen: masukSen,
        pengeluaranSen: keluarSen,
        tugasSelesai: tugasSelesai,
        tugasTerbuka: tugasTerbuka,
        kekayaanBersihSen: kekayaanSen,
        totalAsetSen: kekayaanSen,
        totalKewajibanSen: 0,
        transaksiBaru: transaksi,
        hariAktivitas: aktivitas,
        catatanPengetahuan: catatan,
        perawatanAset: perawatan,
        langgananAktif: 2,
        biayaLanggananSen: 150000,
      );
    }

    test('memuat semua bagian yang diminta PRD', () {
      final l = susunLaporanHidupBulanan(
        ini: bulan('2026-09',
            tagihanLunas: 3,
            bayarSen: 30000000,
            masukSen: 50000000,
            keluarSen: 20000000,
            tugasSelesai: 5,
            kekayaanSen: 100000000,
            transaksi: 9,
            aktivitas: 8,
            catatan: 4,
            perawatan: 1),
        lalu: bulan('2026-08', tagihanLunas: 2, bayarSen: 10000000, masukSen: 30000000, keluarSen: 25000000, tugasSelesai: 3),
      );
      expect(l.bulan, '2026-09');
      expect(l.label, 'September 2026');
      final judul = l.bagian.map((b) => b.judul).toList();
      for (final wajib in bagianLaporanWajib()) {
        expect(judul, contains(wajib));
      }
      // tiap baris punya sumber
      for (final b in l.bagian) {
        for (final baris in b.baris) {
          expect(baris.sumber.trim(), isNotEmpty);
        }
      }
    });

    test('tiga kelompok: membaik / berubah / perlu perhatian', () {
      final l = susunLaporanHidupBulanan(
        ini: bulan('2026-09',
            masukSen: 50000000, keluarSen: 10000000, tugasSelesai: 8, transaksi: 12),
        lalu: bulan('2026-08',
            masukSen: 30000000, keluarSen: 25000000, tugasSelesai: 2, transaksi: 30),
      );
      // arus kas naik = membaik; pengeluaran turun = membaik
      expect(l.membaik.join(), contains('Arus kas'));
      expect(l.membaik.join(), contains('Pengeluaran'));
      // jumlah catatan transaksi berubah (netral)
      expect(l.berubah.join(), contains('Jumlah catatan transaksi'));
      expect(l.membaik.length + l.berubah.length + l.perluPerhatian.length,
          greaterThan(0));
    });

    test('penurunan tercatat di perlu perhatian', () {
      final l = susunLaporanHidupBulanan(
        ini: bulan('2026-09', masukSen: 10000000, keluarSen: 20000000, tugasSelesai: 1),
        lalu: bulan('2026-08', masukSen: 40000000, keluarSen: 10000000, tugasSelesai: 9),
      );
      expect(l.perluPerhatian.join(), contains('Arus kas'));
      expect(l.perluPerhatian.join(), contains('Tugas selesai'));
    });

    test('teks & angka kunci siap diarsipkan', () {
      final l = susunLaporanHidupBulanan(
        ini: bulan('2026-09', tagihanLunas: 2, bayarSen: 5000000, masukSen: 9000000),
        lalu: bulan('2026-08'),
        langgananDekat: ['Netflix (30/09)'],
        asetTerbesar: ['Rumah (Rp500.000.000)'],
      );
      final teks = l.teksLengkap();
      expect(teks, contains('LAPORAN BULANAN — SEPTEMBER 2026'));
      expect(teks, contains('TAGIHAN'));
      expect(teks, contains('bukan perkiraan'));
      final angka = l.angkaKunci();
      expect(angka['bulan'], '2026-09');
      expect(angka['tagihan_lunas'], 2);
      expect(angka['arus_kas_sen'], 9000000);
    });

    test('utilitas bulan: rentang, bulan sebelumnya, pilihan', () {
      final r = rentangBulan('2026-02');
      expect(r.dari, DateTime(2026, 2, 1));
      expect(r.sampai.day, 28);
      expect(bulanSebelum('2026-01'), '2025-12');
      expect(pilihanBulan(DateTime(2026, 9, 22)).first, '2026-09');
      expect(pilihanBulan(DateTime(2026, 9, 22)).length, 12);
    });
  });

  group('FR-145 laporan bulanan — arsip, PDF, layar', () {
    late AppDatabase db;
    late HidupRepository hidup;
    late TinjauanRepository tinjauan;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      hidup = HidupRepository(db, jamSekarang: () => _kini);
      tinjauan = TinjauanRepository(db, jamSekarang: () => _kini);
    });

    tearDown(() => db.close());

    test('arsip laporan disimpan sekali per bulan & angkanya terbaca', () async {
      await tinjauan.simpanLaporan(
        bulan: '2026-09',
        ringkasTeks: 'teks pertama',
        angka: {'bulan': '2026-09', 'tugas_selesai': 5},
      );
      await tinjauan.simpanLaporan(
        bulan: '2026-09',
        ringkasTeks: 'teks kedua',
        angka: {'bulan': '2026-09', 'tugas_selesai': 7},
      );
      final arsip = await tinjauan.riwayatLaporan();
      expect(arsip.length, 1);
      expect(arsip.single.ringkasTeks, 'teks kedua');
      expect(TinjauanRepository.bacaAngka(arsip.single)['tugas_selesai'], 7);
      expect(arsip.single.uid, 'lb_2026-09');
    });

    test('PDF yang dihasilkan benar-benar berkas PDF', () async {
      final l = susunLaporanHidupBulanan(
        ini: BahanAnalitik(
          dari: DateTime(2026, 9, 1),
          sampai: DateTime(2026, 9, 30, 23, 59),
          tagihanLunas: 2,
          totalBayarSen: 5000000,
          pemasukanSen: 9000000,
          pengeluaranSen: 4000000,
          tugasSelesai: 4,
          tugasTerbuka: 3,
          langgananAktif: 2,
          biayaLanggananSen: 150000,
          kekayaanBersihSen: 100000000,
        ),
        lalu: BahanAnalitik(
          dari: DateTime(2026, 8, 1),
          sampai: DateTime(2026, 8, 31, 23, 59),
          pemasukanSen: 8000000,
          pengeluaranSen: 6000000,
        ),
        langgananDekat: ['Netflix (30/09)'],
        asetTerbesar: ['Rumah (Rp500.000.000)'],
      );
      final bytes = await bangunPdfLaporanHidup(l, dicetak: _kini);
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    testWidgets('layar menampilkan bagian + sumber, bisa diarsipkan',
        (t) async {
      await db.into(db.transaksi).insert(TransaksiCompanion.insert(
            uid: const Value('trx_1'),
            idTransaksi: 'trx_1',
            jenis: const Value('pengeluaran'),
            tanggal: _hari(1),
            jumlahSen: 250000,
          ));
      await t.pumpWidget(ProviderScope(
        overrides: [
          repoHidupProvider.overrideWithValue(hidup),
          repoTinjauanProvider.overrideWithValue(tinjauan),
        ],
        child: const MaterialApp(home: LaporanHidupScreen()),
      ));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('laporan_bulan')), findsOneWidget);
      expect(find.byKey(const Key('laporan_bagian_Keuangan')), findsOneWidget);
      expect(find.textContaining('sumber: tabel transaksi'), findsWidgets);

      await _gulirKe(
          t, find.byKey(const Key('laporan_bagian_Kekayaan_bersih')));
      expect(find.byKey(const Key('laporan_bagian_Kekayaan_bersih')),
          findsOneWidget);

      await _gulirKe(t, find.byKey(const Key('laporan_simpan')));
      await t.tap(find.byKey(const Key('laporan_simpan')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('laporan_pesan')), findsOneWidget);
      final arsip = await tinjauan.riwayatLaporan();
      expect(arsip.length, 1);
      expect(arsip.single.ringkasTeks, contains('LAPORAN BULANAN'));
    });
  });

  // ══════════════════════════════════════════════════════════════ skema
  group('Skema v14 & sinkron', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('schemaVersion 15 dan tabel batch 7 masih ada', () async {
      // Batch 9 menaikkan skema ke 15 (energi harian FR-84 & rencana ibadah
      // FR-97); dua tabel batch 7 tetap harus ada.
      expect(db.schemaVersion, 15);
      final tinjauan = await db.select(db.tinjauanMingguan).get();
      final arsip = await db.select(db.arsipLaporanBulanan).get();
      expect(tinjauan, isEmpty);
      expect(arsip, isEmpty);
    });

    test('dua tabel batch 7 terdaftar di mesin sinkron (FR-150)', () async {
      final jalur = daftarJalurSinkron(db);
      final nama = jalur.map((j) => j.nama).toSet();
      expect(nama, contains('tinjauan_mingguan'));
      expect(nama, contains('arsip_laporan_bulanan'));
    });

    test('hidup_repository membaca data nyata dari beberapa modul', () async {
      await db.into(db.tugas).insert(TugasCompanion.insert(
            uid: const Value('t1'),
            idTugas: 't1',
            nama: 'Bayar SPP',
            jatuhTempo: Value(DateTime(_kini.year, _kini.month, _kini.day + 1)),
          ));
      await db.into(db.transaksi).insert(TransaksiCompanion.insert(
            uid: const Value('x1'),
            idTransaksi: 'x1',
            jenis: const Value('pengeluaran'),
            tanggal: _hari(2),
            jumlahSen: 500000,
          ));

      final repo = HidupRepository(db, jamSekarang: () => _kini);
      final agenda = await repo.agendaKeluarga(
        dari: DateTime(_kini.year, _kini.month, 1),
        sampai: DateTime(_kini.year, _kini.month + 1, 0),
      );
      expect(agenda.any((a) => a.judul.contains('Bayar SPP')), isTrue);

      final kejadian = await repo.peristiwa(dari: _hari(30), sampai: _kini);
      expect(kejadian.any((p) => p.modul == 'uang'), isTrue);

      final bahan = await repo.bahan(
          dari: _hari(30), sampai: _kini, hari: 30);
      expect(bahan.transaksiBaru, 1);
      expect(bahan.pengeluaranSen, 500000);
      expect(bahan.tugasTerbuka, 1);
      expect((await repo.tugasPenting()).length, 1);
    });
  });
}
