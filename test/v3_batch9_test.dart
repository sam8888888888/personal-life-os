/// Uji Batch 9 — FR-84 (energi & jam produktif), FR-97 (rencana haji/umrah),
/// FR-142 (temuan pintar), FR-143 (ramalan saldo), FR-146 (tinjauan tahun).
///
/// Aturan yang dipegang di berkas ini:
///   * mesin diuji lewat `test()` biasa (tanpa widget) — waktu nyata,
///   * pekerjaan berkas/basis data nyata di `testWidgets` selalu lewat
///     `t.runAsync(...)`, karena di uji widget jam dipalsukan,
///   * setiap penolakan ("data belum cukup") diuji sebagai perilaku yang BENAR,
///     bukan sebagai kegagalan.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/analitik/bahan_analitik.dart';
import 'package:personal_life_os/core/analitik/ramalan_saldo.dart';
import 'package:personal_life_os/core/analitik/temuan_pintar.dart';
import 'package:personal_life_os/core/analitik/tinjauan_tahun.dart';
import 'package:personal_life_os/core/ibadah/rencana_ibadah.dart';
import 'package:personal_life_os/core/kesehatan/energi_tidur.dart';
import 'package:personal_life_os/core/laporan/proyeksi_arus_kas.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/sinkron/registri_sinkron.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/energi_repository.dart';
import 'package:personal_life_os/data/repository/pintar_repository.dart';
import 'package:personal_life_os/data/repository/rencana_ibadah_repository.dart';
import 'package:personal_life_os/features/ibadah/rencana_ibadah_screen.dart';
import 'package:personal_life_os/features/kesehatan/energi_tidur_screen.dart';
import 'package:personal_life_os/features/ritme/ramalan_saldo_screen.dart';
import 'package:personal_life_os/features/ritme/temuan_pintar_screen.dart';
import 'package:personal_life_os/features/ritme/tinjauan_tahun_screen.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

final DateTime _kini = DateTime(2026, 9, 22, 10);

/// Tunggu sampai [syarat] benar (memakai runAsync supaya pekerjaan nyata jalan).
Future<void> _tungguSampai(WidgetTester t, bool Function() syarat,
    {int putaran = 80}) async {
  for (var i = 0; i < putaran; i++) {
    if (syarat()) return;
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await t.pump(const Duration(milliseconds: 25));
  }
}

Future<void> _trx(AppDatabase db, DateTime tanggal, int sen, String jenis) =>
    db.into(db.transaksi).insert(TransaksiCompanion.insert(
          idTransaksi: 'trx_${tanggal.millisecondsSinceEpoch}_${jenis}_$sen',
          tanggal: tanggal,
          jumlahSen: sen,
          jenis: Value(jenis),
        ));

Future<void> _tidur(AppDatabase db, DateTime tanggal,
    {int menit = 420, int? energi, int? fokus, int? jamProduktif}) =>
    db.into(db.tidur).insert(TidurCompanion.insert(
          tanggal: tanggal,
          jamTidur: DateTime(tanggal.year, tanggal.month, tanggal.day - 1, 23),
          jamBangun: DateTime(tanggal.year, tanggal.month, tanggal.day, 6),
          durasiMenit: menit,
          energi: Value(energi),
          fokus: Value(fokus),
          jamProduktifMenit: Value(jamProduktif),
        ));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // ══════════════════════════════════════════════════════════ FR-142 mesin
  group('FR-142 temuan pintar', () {
    test('pengeluaran menyimpang muncul lengkap dengan dasar & angkanya', () {
      final hasil = susunTemuan(BahanTemuan(
        pengeluaranBulanan: const [
          PengeluaranBulan(periode: '2026-06', sen: 5000000),
          PengeluaranBulan(periode: '2026-07', sen: 5000000),
          PengeluaranBulan(periode: '2026-08', sen: 5000000),
          PengeluaranBulan(periode: '2026-09', sen: 8000000),
        ],
      ));
      final t = hasil.temuan.firstWhere((e) => e.kode == 'pengeluaran_menyimpang');
      expect(t.angka, '+60%');
      expect(t.dasar, contains('tabel transaksi'));
      expect(t.dasar, contains('Sep'));
      expect(t.rincian, contains('Rp'));
      expect(t.penting, isTrue);
    });

    test('data kurang → TIDAK dibuat temuan, tapi alasannya disebut', () {
      final hasil = susunTemuan(const BahanTemuan(
        pengeluaranBulanan: [
          PengeluaranBulan(periode: '2026-08', sen: 5000000),
          PengeluaranBulan(periode: '2026-09', sen: 8000000),
        ],
      ));
      expect(hasil.temuan.map((e) => e.kode),
          isNot(contains('pengeluaran_menyimpang')));
      expect(hasil.belumBisa.any((b) => b.contains('4 bulan catatan')), isTrue);
    });

    test('sebaran jatuh tempo: 73% di 7 hari terakhir bulan', () {
      final tagihan = <TagihanJatuhTempo>[];
      for (var i = 1; i <= 6; i++) {
        tagihan.add(TagihanJatuhTempo(
            nama: 'Tagihan $i', jatuhTempo: DateTime(2026, 9, 25 + i % 3)));
      }
      tagihan.add(TagihanJatuhTempo(nama: 'Awal', jatuhTempo: DateTime(2026, 9, 2)));
      final hasil = susunTemuan(BahanTemuan(tagihanAktif: tagihan));
      final t = hasil.temuan.firstWhere((e) => e.kode == 'sebaran_jatuh_tempo');
      expect(t.angka, '86%');
      expect(t.dasar, contains('7 tagihan aktif'));
    });

    test('langganan jarang dipakai menghitung potensi hemat', () {
      final hasil = susunTemuan(BahanTemuan(langganan: [
        LanggananRingkas(
            nama: 'Streaming',
            nominalSen: 200000,
            terakhirDipakai:
                DateTime.now().subtract(const Duration(days: 90))),
        LanggananRingkas(nama: 'Kopi', nominalSen: 100000),
      ]));
      final t =
          hasil.temuan.firstWhere((e) => e.kode == 'langganan_jarang_dipakai');
      expect(t.rincian, contains('Streaming'));
      expect(t.rincian, contains('Rp'));
      expect(t.angka, '1');
    });

    test('titik saldo terendah dari saldo harian', () {
      final titik = <TitikSaldo>[];
      for (var i = 0; i < 20; i++) {
        titik.add(TitikSaldo(
            tanggal: DateTime(2026, 9, 1 + i),
            saldoSen: i == 5 ? -500000 : 1000000));
      }
      final hasil = susunTemuan(BahanTemuan(saldoHarian: titik));
      final t = hasil.temuan.firstWhere((e) => e.kode == 'titik_saldo_terendah');
      expect(t.rincian, contains('6 September 2026'));
      expect(t.rincian, contains('1 hari saldo minus'));
      expect(t.penting, isTrue);
    });

    test('tanpa catatan sama sekali: tidak ada temuan, semua alasan disebut',
        () {
      final hasil = susunTemuan(const BahanTemuan());
      expect(hasil.kosong, isTrue);
      expect(hasil.belumBisa.length, 4);
    });
  });

  // ══════════════════════════════════════════════════════════ FR-143 mesin
  group('FR-143 ramalan saldo', () {
    List<BarisProyeksi> tetap({int sen = 3000000}) => List.generate(
          3,
          (i) => BarisProyeksi(
            bulan: DateTime(2026, 10 + i, 1),
            jumlahTagihan: 1,
            jumlahLangganan: 1,
            totalTagihanSen: sen,
            totalLanggananSen: 0,
          ),
        );

    test('tiga angka (pesimis · tengah · optimis) dan asumsinya', () {
      final r = ramalSaldo(
        saldoAwalSen: 10000000,
        tetap: tetap(),
        pemasukanBulananSen: 8000000,
        pengeluaranHarianSen: 100000,
        simpanganHarianSen: 20000,
        hariCatatanPengeluaran: 90,
        bulanCatatanPemasukan: 3,
      );
      expect(r.bulan.length, 3);
      final b = r.bulan.first;
      expect(b.saldoPesimisSen < b.saldoTengahSen, isTrue);
      expect(b.saldoTengahSen < b.saldoOptimisSen, isTrue);
      expect(r.asumsi.any((a) => a.contains('Rentang: pesimis')), isTrue);
      expect(r.asumsi.any((a) => a.contains('mesin yang sama dengan pengingat')),
          isTrue);
      expect(r.belumBisa, isEmpty);
    });

    test('belum ada catatan → diramal 0 TAPI dikatakan apa adanya', () {
      final r = ramalSaldo(
        saldoAwalSen: 0,
        tetap: tetap(sen: 0),
        pemasukanBulananSen: 0,
        pengeluaranHarianSen: 0,
      );
      expect(r.belumBisa.length, 2);
      expect(r.asumsi.any((a) => a.contains('terlalu sedikit untuk menghitung rentang')),
          isTrue);
    });

    test('cariTabrakan menemukan hari dengan ≥2 tagihan', () {
      final t = cariTabrakan(
        [
          TagihanJatuhTempo(
              nama: 'Sekolah', jatuhTempo: DateTime(2026, 10, 5), nominalSen: 100),
          TagihanJatuhTempo(
              nama: 'Listrik', jatuhTempo: DateTime(2026, 10, 5), nominalSen: 200),
          TagihanJatuhTempo(
              nama: 'Air', jatuhTempo: DateTime(2026, 10, 20), nominalSen: 300),
        ],
        sekarang: _kini,
      );
      expect(t.length, 1);
      expect(t.first.nama, ['Listrik', 'Sekolah']);
      expect(t.first.totalSen, 300);
    });
  });

  // ══════════════════════════════════════════════════════════ FR-146 mesin
  group('FR-146 tinjauan tahun', () {
    test('data < 6 bulan → menolak tampil dengan pesan jujur', () {
      final h = susunTinjauanTahun(
        tahun: 2026,
        bahan: BahanAnalitik(
          dari: DateTime(2026, 1, 1),
          sampai: DateTime(2026, 12, 31),
          pengeluaranSen: 1000000,
        ),
        bulanTercatat: 3,
      );
      expect(h.cukupData, isFalse);
      expect(h.pilar, isEmpty);
      expect(h.pesan, contains('baru 3 bulan'));
    });

    test('data cukup → pilar & angkanya muncul', () {
      final h = susunTinjauanTahun(
        tahun: 2026,
        bahan: BahanAnalitik(
          dari: DateTime(2026, 1, 1),
          sampai: DateTime(2026, 12, 31),
          pengeluaranSen: 12000000,
        ),
        bulanTercatat: 8,
      );
      expect(h.cukupData, isTrue);
      final keuangan = h.pilar.firstWhere((p) => p.nama == 'Keuangan');
      final rata = keuangan.fakta
          .firstWhere((f) => f.label.contains('rata-rata per bulan'));
      expect(rata.satuanUangSen, 1500000);
    });
  });

  // ══════════════════════════════════════════════════════════ FR-84 mesin
  group('FR-84 pola energi', () {
    List<CatatanEnergiHari> hari(int jumlah,
            {bool denganEnergi = true, bool denganProduktif = true}) =>
        List.generate(
          jumlah,
          (i) => CatatanEnergiHari(
            tanggal: DateTime(2026, 8, 1 + i),
            menitTidur: 400 + i,
            energi: denganEnergi ? 3 + (i % 3) : null,
            fokus: denganEnergi ? 2 + (i % 3) : null,
            jamProduktifMenit: denganProduktif ? 510 + (i % 4) * 15 : null,
          ),
        );

    test('belum 14 hari → cukupData false & pesannya jelas', () {
      final p = hitungPolaEnergi(hari(10));
      expect(p.cukupData, isFalse);
      expect(p.jamProduktif, isNull);
      expect(p.pesan, contains('baru 10 malam'));
    });

    test('≥14 hari dan ada jam produktif → rentangnya muncul + dasar', () {
      final p = hitungPolaEnergi(hari(16));
      expect(p.cukupData, isTrue);
      expect(p.jamProduktif, '08.30–09.15');
      expect(p.dasar, contains('tabel tidur'));
      expect(p.dasar, contains('16 malam tercatat'));
      expect(p.rataEnergi, isNotNull);
    });

    test('tidur cukup tapi jam produktif belum diisi → dikatakan belum bisa',
        () {
      final p = hitungPolaEnergi(hari(16, denganProduktif: false));
      expect(p.cukupData, isTrue);
      expect(p.jamProduktif, isNull);
      expect(p.pesan, contains('jam paling produktif'));
    });

    test('tanpa catatan sama sekali', () {
      final p = hitungPolaEnergi(const []);
      expect(p.cukupData, isFalse);
      expect(p.jumlahHari, 0);
      expect(p.pesan, contains('Belum ada catatan tidur'));
    });
  });

  // ══════════════════════════════════════════════════════════ FR-97 mesin
  group('FR-97 progres rencana ibadah', () {
    RencanaIbadahRingkas rencana({
      int target = 45000000,
      int terkumpul = 15000000,
      DateTime? tanggal,
      int butir = 4,
      int selesai = 2,
    }) =>
        RencanaIbadahRingkas(
          id: 1,
          jenis: JenisRencanaIbadah.haji,
          nama: 'Haji keluarga',
          targetSen: target,
          terkumpulSen: terkumpul,
          targetTanggal: tanggal ?? DateTime(2028, 5, 1),
          persiapan: List.generate(
              butir,
              (i) => ButirPersiapan(
                  nama: 'Butir $i', selesai: i < selesai)),
        );

    test('persen, sisa, dan sisihan per bulan', () {
      final p = hitungProgresRencana(rencana(), sekarang: _kini);
      expect((p.persen * 100).toStringAsFixed(1), '33.3');
      expect(p.sisaSen, 30000000);
      expect(p.bulanTersisa, 20);
      expect(p.setoranPerBulanSen, 1500000);
      expect(p.status, 'berjalan');
      expect(p.dasar, contains('2/4 persiapan selesai'));
    });

    test('target tercapai → status tercapai & tanpa sisihan', () {
      final p = hitungProgresRencana(rencana(terkumpul: 45000000),
          sekarang: _kini);
      expect(p.status, 'tercapai');
      expect(p.setoranPerBulanSen, isNull);
    });

    test('tanggal target sudah lewat → peringatan jujur', () {
      final p = hitungProgresRencana(rencana(tanggal: DateTime(2026, 1, 1)),
          sekarang: _kini);
      expect(p.bulanTersisa, 0);
      expect(p.peringatan, contains('sudah lewat'));
      expect(p.setoranPerBulanSen, 30000000);
    });

    test('target belum diisi → dikatakan, bukan dibagi nol', () {
      final p = hitungProgresRencana(rencana(target: 0), sekarang: _kini);
      expect(p.persen, 0);
      expect(p.peringatan, contains('Target dana belum diisi'));
    });

    test('daftar persiapan bawaan tersedia & bisa dibedakan haji/umrah', () {
      expect(persiapanBawaan(JenisRencanaIbadah.haji).length, 8);
      expect(persiapanBawaan(JenisRencanaIbadah.umrah).length, 7);
    });
  });

  // ══════════════════════════════════════════════════════════ Repositori
  group('repositori batch 9', () {
    test('FR-97: tambah rencana + persiapan bawaan, dana, tandai, hapus',
        () async {
      final db = _db();
      addTearDown(db.close);
      final repo = RencanaIbadahRepository(db);

      final id = await repo.tambahRencana(
        jenis: JenisRencanaIbadah.umrah,
        nama: 'Umrah Desember',
        targetSen: 30000000,
        terkumpulSen: 5000000,
        targetTanggal: DateTime(2027, 12, 10),
      );
      var daftar = await repo.semua();
      expect(daftar.length, 1);
      expect(daftar.first.jumlahPersiapan, persiapanBawaan(JenisRencanaIbadah.umrah).length);

      await repo.tambahDana(id, 2500000);
      daftar = await repo.semua();
      expect(daftar.first.terkumpulSen, 7500000);

      final butir = await repo.butirMentah(id);
      await repo.tandaiPersiapan(butir.first.id, true);
      daftar = await repo.semua();
      expect(daftar.first.persiapanSelesai, 1);

      await repo.tambahPersiapan(id, 'Surat keterangan sehat');
      expect((await repo.butirMentah(id)).length, butir.length + 1);

      await repo.hapusRencana(id);
      expect(await repo.semua(), isEmpty);
      expect(await repo.butirMentah(id), isEmpty);
    });

    test('FR-97: tabel baru ikut mesin sinkron FR-150 (multi-HP)', () async {
      final db = _db();
      addTearDown(db.close);
      final nama = daftarJalurSinkron(db).map((j) => j.nama).toSet();
      expect(nama, contains('rencana_ibadah'));
      expect(nama, contains('persiapan_ibadah'));
      final induk = daftarJalurSinkron(db)
          .firstWhere((j) => j.nama == 'persiapan_ibadah');
      expect(induk.kaitan['rencana_id'], 'rencana_ibadah');
    });

    test('FR-97: setoran nol/negatif & nama kosong ditolak', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = RencanaIbadahRepository(db);
      final id = await repo.tambahRencana(
        jenis: JenisRencanaIbadah.haji,
        nama: 'Haji',
        targetSen: 1000,
        targetTanggal: DateTime(2030, 1, 1),
        denganPersiapanBawaan: false,
      );
      await expectLater(repo.tambahDana(id, 0), throwsA(isA<ArgumentError>()));
      await expectLater(
        repo.tambahRencana(
          jenis: JenisRencanaIbadah.haji,
          nama: '   ',
          targetSen: 1,
          targetTanggal: DateTime(2030, 1, 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('FR-84: energi hanya bisa diisi setelah tidur malam itu tercatat',
        () async {
      final db = _db();
      addTearDown(db.close);
      final repo = EnergiRepository(db);

      await expectLater(
        repo.simpanEnergi(tanggal: DateTime(2026, 9, 20), energi: 4),
        throwsA(isA<StateError>()),
      );

      await _tidur(db, DateTime(2026, 9, 20));
      await repo.simpanEnergi(
          tanggal: DateTime(2026, 9, 20), energi: 4, fokus: 3, jamProduktifMenit: 510);
      final catatan = await repo.catatan(hari: 60);
      expect(catatan.single.energi, 4);
      expect(catatan.single.fokus, 3);
      expect(catatan.single.jamProduktifMenit, 510);

      await expectLater(
        repo.simpanEnergi(tanggal: DateTime(2026, 9, 20), energi: 9),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repo.simpanEnergi(tanggal: DateTime(2026, 9, 20), jamProduktifMenit: 1500),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('FR-142 & FR-143: bahan diambil dari data nyata', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = PintarRepository(db, jamSekarang: () => _kini);

      await _trx(db, DateTime(2026, 9, 1), 10000000, 'pemasukan');
      await _trx(db, DateTime(2026, 9, 5), 3000000, 'pengeluaran');
      await db.into(db.tagihan).insert(TagihanCompanion.insert(
            nama: 'Listrik',
            jatuhTempo: DateTime(2026, 9, 28),
            jumlahSen: const Value(500000),
          ));

      final bahan = await repo.bahanTemuan(bulanPengeluaran: 3, hariSaldo: 10);
      expect(bahan.pengeluaranBulanan.single.sen, 3000000);
      expect(bahan.tagihanAktif.single.nama, 'Listrik');
      expect(bahan.saldoHarian.length, 11);
      expect(bahan.saldoHarian.last.saldoSen, 7000000);

      final ramalan = await repo.ramalan(jumlahBulan: 3, hariPengeluaran: 30);
      expect(ramalan.saldoAwalSen, 7000000);
      expect(ramalan.bulan.length, 3);
      expect(ramalan.bulan.first.keluarTetapSen, 500000);
    });

    test('FR-146: bulan tercatat dihitung dari transaksi/pembayaran/tidur',
        () async {
      final db = _db();
      addTearDown(db.close);
      final repo = PintarRepository(db, jamSekarang: () => _kini);
      await _trx(db, DateTime(2026, 3, 4), 100000, 'pengeluaran');
      await _trx(db, DateTime(2026, 4, 4), 100000, 'pengeluaran');
      await _tidur(db, DateTime(2026, 5, 4));

      final h = await repo.tinjauanTahun(tahun: 2026);
      expect(h.bulanTercatat, 3);
      expect(h.cukupData, isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════ Layar
  group('layar batch 9', () {
    /// Kanvas tinggi: `ListView` membangun anaknya secara malas, jadi kartu di
    /// bawah "belum terlihat" != "tidak ada". Uji ini memakai layar tinggi
    /// supaya yang diperiksa memang isinya, bukan posisi gulir.
    void layarTinggi(WidgetTester t) {
      t.view.physicalSize = const Size(1200, 3200);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
    }

    testWidgets('FR-142: temuan yang data kurang menyebut alasannya', (t) async {
      layarTinggi(t);
      final db = _db();
      addTearDown(db.close);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: TemuanPintarScreen()),
      ));
      await _tungguSampai(t, () =>
          find.byKey(const Key('temuan_belum_bisa')).evaluate().isNotEmpty);
      expect(find.byKey(const Key('temuan_belum_bisa')), findsOneWidget);
      expect(find.byKey(const Key('temuan_kosong')), findsOneWidget);
    });

    testWidgets('FR-143: layar ramalan menampilkan asumsi & belum bisa',
        (t) async {
      layarTinggi(t);
      final db = _db();
      addTearDown(db.close);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: RamalanSaldoScreen()),
      ));
      await _tungguSampai(t, () =>
          find.byKey(const Key('ramalan_asumsi')).evaluate().isNotEmpty);
      expect(find.byKey(const Key('ramalan_asumsi')), findsOneWidget);
      expect(find.byKey(const Key('ramalan_belum_bisa')), findsOneWidget);
    });

    testWidgets('FR-146: data belum cukup → kartu "belum cukup"', (t) async {
      final db = _db();
      addTearDown(db.close);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: TinjauanTahunScreen(tahunAwal: 2026)),
      ));
      await _tungguSampai(t, () =>
          find.byKey(const Key('tinjauan_belum_cukup')).evaluate().isNotEmpty);
      expect(find.byKey(const Key('tinjauan_belum_cukup')), findsOneWidget);
      expect(find.byKey(const Key('tinjauan_tahun_2026')), findsOneWidget);
    });

    testWidgets('FR-84: layar energi menjelaskan kenapa belum bisa', (t) async {
      final db = _db();
      addTearDown(db.close);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: EnergiTidurScreen()),
      ));
      await _tungguSampai(t, () =>
          find.byKey(const Key('energi_pola')).evaluate().isNotEmpty);
      expect(find.byKey(const Key('energi_kosong')), findsOneWidget);
      expect(find.textContaining('Belum ada catatan tidur'), findsWidgets);
    });

    testWidgets('FR-97: tambah rencana lewat dialog lalu muncul di daftar',
        (t) async {
      final db = _db();
      addTearDown(db.close);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: RencanaIbadahScreen()),
      ));
      await _tungguSampai(t, () =>
          find.byKey(const Key('ibadah_kosong')).evaluate().isNotEmpty);

      // FAB berada di atas daftar yang menggulir: hit-test bisa meleset walau
      // widget-nya jelas ada, jadi aksinya dipanggil langsung.
      t.widget<FloatingActionButton>(find.byKey(const Key('ibadah_tambah')))
          .onPressed!();
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('ibadah_nama')), findsOneWidget);

      await t.tap(find.byKey(const Key('ibadah_jenis_umrah')));
      await t.pump();
      await t.enterText(find.byKey(const Key('ibadah_nama')), 'Umrah keluarga');
      await t.enterText(find.byKey(const Key('ibadah_target')), '30.000.000');
      await t.enterText(find.byKey(const Key('ibadah_terkumpul')), '5.000.000');
      await t.enterText(
          find.byKey(const Key('ibadah_tanggal')), '2027-12-10');
      await t.tap(find.byKey(const Key('ibadah_simpan')));
      await _tungguSampai(
          t, () => find.textContaining('Umrah keluarga').evaluate().isNotEmpty);

      expect(find.textContaining('Umrah keluarga'), findsWidgets);
      // Beri waktu sejenak supaya seluruh baris butir persiapan selesai ditulis
      // (penyimpanan di layar berjalan sebagai rangkaian await).
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await t.pump(const Duration(milliseconds: 100));

      final rencana = await db.select(db.rencanaIbadah).getSingle();
      // '30.000.000' rupiah = 3.000.000.000 sen.
      expect(rencana.targetSen, 3000000000);
      expect(rencana.jenis, 'umrah');
      final butir = await db.select(db.persiapanIbadah).get();
      expect(butir.length, persiapanBawaan(JenisRencanaIbadah.umrah).length,
          reason: 'butir tersimpan: ${butir.map((b) => b.nama).join(' | ')}');
    });

    testWidgets('FR-97: ketikan rupiah dibaca apa adanya', (t) async {
      expect(bacaRupiahKeSen('1.500.000'), 150000000);
      expect(bacaRupiahKeSen('Rp 30 000 000'), 3000000000);
      expect(bacaRupiahKeSen(''), isNull);
      expect(bacaRupiahKeSen('abc'), isNull);
    }, skip: false);
  });
}
