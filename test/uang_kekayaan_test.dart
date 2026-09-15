/// Uji FR-76 Pelacak kekayaan bersih (net worth).
///
/// Kriteria terima PRD yang diuji di sini:
/// * nilai bersih = aset - kewajiban (uji hitung dengan angka eksplisit),
/// * grafik menyimpan riwayat bulanan dan tidak berubah retroaktif (bulan
///   lampau terkunci; membukanya wajib memakai alasan).
///
/// Waktu uji dikunci: "sekarang" = 15 September 2026, jadi bulan berjalan
/// adalah 2026-09 dan bulan lampau (terkunci) contohnya 2026-08.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/core/utils/uang_utils.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/model/enums.dart';
import 'package:personal_life_os/data/repository/aset_repository.dart';
import 'package:personal_life_os/features/uang/kekayaan/grafik_tren_kekayaan.dart';
import 'package:personal_life_os/features/uang/kekayaan/kekayaan_screen.dart';

late AppDatabase db;
late AsetRepository repo;

/// Waktu patok uji: 15 Sep 2026 08.00 -> bulan berjalan '2026-09'.
final jamUji = DateTime(2026, 9, 15, 8);

const bulanIni = '2026-09';
const bulanLampau = '2026-08';

/// Aset uji dengan nilai awal dalam RUPIAH (dikonversi ke sen).
Future<AsetData> asetBaru(
  String nama,
  num rupiah, {
  bool likuid = true,
  JenisAset jenis = JenisAset.kas,
  String? institusi,
}) =>
    repo.tambahAset(
      nama: nama,
      jenis: jenis,
      nilaiAwalSen: rupiahKeSen(rupiah),
      likuid: likuid,
      institusi: institusi,
    );

/// Kewajiban uji dengan saldo awal dalam RUPIAH.
Future<KewajibanData> kewajibanBaru(String nama, num rupiah) =>
    repo.tambahKewajiban(
      nama: nama,
      jenis: JenisKewajiban.lain,
      saldoAwalSen: rupiahKeSen(rupiah),
    );

Future<NilaiAsetBulananData> barisAset(int asetId) async {
  final semua = await db.select(db.nilaiAsetBulanan).get();
  return semua.singleWhere((n) => n.asetId == asetId);
}

Future<NilaiKewajibanBulananData> barisKewajiban(int kewajibanId) async {
  final semua = await db.select(db.nilaiKewajibanBulanan).get();
  return semua.singleWhere((n) => n.kewajibanId == kewajibanId);
}

void main() {
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AsetRepository(db, jamSekarang: () => jamUji);
  });

  tearDown(() async => db.close());

  // -------------------------------------------------------------------------
  // Hitung nilai bersih (a, b)
  // -------------------------------------------------------------------------

  group('nilai bersih = aset - kewajiban', () {
    test('(a) angka eksplisit: aset 10 juta - kewajiban 3 juta = 7 juta',
        () async {
      await asetBaru('Tabungan BCA', 8000000);
      await asetBaru('Emas Antam', 2000000);
      await kewajibanBaru('KPR rumah', 3000000);

      final n = await repo.nilaiBersih(bulanIni);
      expect(n.bulan, bulanIni);
      expect(n.totalAsetSen, rupiahKeSen(10000000));
      expect(n.totalKewajibanSen, rupiahKeSen(3000000));
      expect(n.bersihSen, rupiahKeSen(7000000));
      expect(fmtRpDariSen(n.bersihSen), 'Rp 7.000.000');
    });

    test('nilai bersih boleh negatif bila kewajiban lebih besar', () async {
      await asetBaru('Kas', 1000000);
      await kewajibanBaru('Kartu kredit', 2500000);
      final n = await repo.nilaiBersih(bulanIni);
      expect(n.bersihSen, rupiahKeSen(-1500000));
      expect(fmtRpDariSen(n.bersihSen), '-Rp 1.500.000');
    });

    test('dipakai catatan bulan terakhir yang <= bulan yang diminta', () async {
      final a = await asetBaru('Reksa dana', 1000000);
      await repo.simpanNilaiAset(
          asetId: a.id, bulan: '2026-07', nilaiSen: rupiahKeSen(1200000), paksa: true);
      await repo.simpanNilaiAset(
          asetId: a.id, bulan: bulanLampau, nilaiSen: rupiahKeSen(1500000),
          paksa: true);

      expect((await repo.nilaiBersih(bulanLampau)).totalAsetSen, rupiahKeSen(1500000));
      expect((await repo.nilaiBersih(bulanIni)).totalAsetSen, rupiahKeSen(1500000));
      // Sebelum catatan bulanan pertama: kembali ke nilai awal.
      expect((await repo.nilaiBersih('2026-06')).totalAsetSen, rupiahKeSen(1000000));
    });

    test('(b) aset/kewajiban yang diarsipkan tidak ikut hitung '
        '(sertakanArsip: false)', () async {
      await asetBaru('Kas aktif', 5000000);
      final arsip = await asetBaru('Motor (dijual)', 2000000);
      await kewajibanBaru('Cicilan aktif', 1000000);
      final kArsip = await kewajibanBaru('Utang lama', 3000000);

      await repo.arsipkanAset(arsip.id);
      await repo.arsipkanKewajiban(kArsip.id);

      final n = await repo.nilaiBersih(bulanIni);
      expect(n.totalAsetSen, rupiahKeSen(5000000));
      expect(n.totalKewajibanSen, rupiahKeSen(1000000));
      expect(n.bersihSen, rupiahKeSen(4000000));

      // Bila memang diminta, yang diarsipkan ikut dihitung lagi.
      final semua = await repo.nilaiBersih(bulanIni, sertakanArsip: true);
      expect(semua.totalAsetSen, rupiahKeSen(7000000));
      expect(semua.totalKewajibanSen, rupiahKeSen(4000000));
      expect(semua.bersihSen, rupiahKeSen(3000000));

      expect((await repo.ambilAset()).length, 1);
      expect((await repo.ambilKewajiban()).length, 1);
    });

    test('(e) aset tanpa catatan bulan memakai nilai awal, bukan nol', () async {
      final a = await asetBaru('Deposito', 5000000, jenis: JenisAset.bank);
      await kewajibanBaru('Pinjaman', 2000000);

      expect(await repo.ambilAset(), isNotEmpty);
      final n = await repo.nilaiBersih(bulanIni);
      expect(n.totalAsetSen, rupiahKeSen(5000000));
      expect(n.bersihSen, rupiahKeSen(3000000));
      // Nilai awal aset tersimpan apa adanya.
      expect((await repo.ambilAsetSatu(a.id))?.nilaiAwalSen, rupiahKeSen(5000000));
    });
  });

  // -------------------------------------------------------------------------
  // Kunci bulan lampau (c) & tren (d)
  // -------------------------------------------------------------------------

  group('bulan lampau terkunci (tidak berubah retroaktif)', () {
    test('(c) simpan tanpa paksa ditolak dan angka lama tidak berubah',
        () async {
      final a = await asetBaru('Kas', 0);
      await repo.simpanNilaiAset(
          asetId: a.id, bulan: bulanLampau, nilaiSen: rupiahKeSen(1000000));

      final sebelum = await barisAset(a.id);
      expect(sebelum.terkunci, isTrue);
      expect(sebelum.dikunciPada, isNotNull);
      expect(sebelum.alasanBukaKunci, isNull);

      await expectLater(
        repo.simpanNilaiAset(
            asetId: a.id, bulan: bulanLampau, nilaiSen: rupiahKeSen(2000000)),
        throwsA(isA<StateError>()),
      );

      final sesudah = await barisAset(a.id);
      expect(sesudah.nilaiSen, rupiahKeSen(1000000));
      expect((await repo.nilaiBersih(bulanLampau)).totalAsetSen, rupiahKeSen(1000000));
    });

    test('(c) paksa tanpa alasan tetap ditolak (alasan wajib)', () async {
      final a = await asetBaru('Kas', 0);
      await repo.simpanNilaiAset(
          asetId: a.id, bulan: bulanLampau, nilaiSen: rupiahKeSen(1000000));

      await expectLater(
        repo.simpanNilaiAset(
            asetId: a.id,
            bulan: bulanLampau,
            nilaiSen: rupiahKeSen(2000000),
            paksa: true),
        throwsA(isA<ArgumentError>()),
      );
      expect((await barisAset(a.id)).nilaiSen, rupiahKeSen(1000000));
    });

    test('(c) paksa + alasan berhasil dan jejak alasan tersimpan', () async {
      final a = await asetBaru('Kas', 0);
      await repo.simpanNilaiAset(
          asetId: a.id, bulan: bulanLampau, nilaiSen: rupiahKeSen(1000000));

      await repo.simpanNilaiAset(
        asetId: a.id,
        bulan: bulanLampau,
        nilaiSen: rupiahKeSen(2000000),
        paksa: true,
        alasan: 'salah ketik nominal',
      );

      final b = await barisAset(a.id);
      expect(b.nilaiSen, rupiahKeSen(2000000));
      expect(b.terkunci, isTrue);
      expect(b.dibukaKunciPada, isNotNull);
      expect(b.alasanBukaKunci, 'salah ketik nominal');
      expect((await repo.nilaiBersih(bulanLampau)).totalAsetSen, rupiahKeSen(2000000));
    });

    test('(c) aturan kunci juga berlaku untuk kewajiban', () async {
      final k = await kewajibanBaru('KPR', 0);
      await repo.simpanNilaiKewajiban(
          kewajibanId: k.id, bulan: bulanLampau, nilaiSen: rupiahKeSen(500000));
      expect((await barisKewajiban(k.id)).terkunci, isTrue);

      await expectLater(
        repo.simpanNilaiKewajiban(
            kewajibanId: k.id, bulan: bulanLampau, nilaiSen: rupiahKeSen(400000)),
        throwsA(isA<StateError>()),
      );
      await repo.simpanNilaiKewajiban(
        kewajibanId: k.id,
        bulan: bulanLampau,
        nilaiSen: rupiahKeSen(400000),
        paksa: true,
        alasan: 'pelunasan tercatat mundur',
      );
      final b = await barisKewajiban(k.id);
      expect(b.nilaiSen, rupiahKeSen(400000));
      expect(b.alasanBukaKunci, 'pelunasan tercatat mundur');
    });

    test('bulan berjalan tidak terkunci: penyimpanan kedua menimpa', () async {
      final a = await asetBaru('Kas', 0);
      await repo.simpanNilaiAset(
          asetId: a.id, bulan: bulanIni, nilaiSen: rupiahKeSen(3000000));
      await repo.simpanNilaiAset(
          asetId: a.id, bulan: bulanIni, nilaiSen: rupiahKeSen(3500000));

      final b = await barisAset(a.id);
      expect(b.terkunci, isFalse);
      expect(b.nilaiSen, rupiahKeSen(3500000));
      expect((await repo.nilaiBersih(bulanIni)).totalAsetSen, rupiahKeSen(3500000));
    });
  });

  group('tren bulanan', () {
    test('(d) urutan bulan menaik dan nilai tiap bulan benar', () async {
      final a = await asetBaru('Bank', 1000000);
      final k = await kewajibanBaru('Kartu kredit', 400000);
      await repo.simpanNilaiAset(
          asetId: a.id, bulan: '2026-07', nilaiSen: rupiahKeSen(1000000), paksa: true);
      await repo.simpanNilaiAset(
          asetId: a.id, bulan: bulanLampau, nilaiSen: rupiahKeSen(2000000), paksa: true);
      await repo.simpanNilaiAset(
          asetId: a.id, bulan: bulanIni, nilaiSen: rupiahKeSen(2500000));
      await repo.simpanNilaiKewajiban(
          kewajibanId: k.id, bulan: bulanIni, nilaiSen: rupiahKeSen(300000));

      final t = await repo.tren(dari: '2026-07', sampai: bulanIni);
      expect(t.map((e) => e.bulan).toList(), ['2026-07', bulanLampau, bulanIni]);
      expect(t[0].bersihSen, rupiahKeSen(600000)); // aset 1 jt - kewajiban 400 rb
      expect(t[1].bersihSen, rupiahKeSen(1600000)); // aset 2 jt - kewajiban 400 rb
      expect(t[2].bersihSen, rupiahKeSen(2200000)); // aset 2,5 jt - kewajiban 300 rb
      // Urut menaik: tiap bulan berikutnya lebih besar kuncinya.
      for (var i = 1; i < t.length; i++) {
        expect(t[i].bulan.compareTo(t[i - 1].bulan) > 0, isTrue);
      }
    });

    test('(d) mencatat bulan baru tidak mengubah angka bulan sebelumnya',
        () async {
      final a = await asetBaru('Bank', 1000000);
      await repo.simpanNilaiAset(
          asetId: a.id, bulan: bulanLampau, nilaiSen: rupiahKeSen(1100000), paksa: true);

      final sebelum = await repo.tren(dari: '2026-07', sampai: bulanLampau);
      await repo.simpanNilaiAset(
          asetId: a.id, bulan: bulanIni, nilaiSen: rupiahKeSen(5000000));
      final sesudah = await repo.tren(dari: '2026-07', sampai: bulanLampau);

      expect(sesudah.length, sebelum.length);
      for (var i = 0; i < sebelum.length; i++) {
        expect(sesudah[i].bersihSen, sebelum[i].bersihSen);
        expect(sesudah[i].bulan, sebelum[i].bulan);
      }
      // Bulan berjalan tetap memakai angka terbaru.
      expect((await repo.nilaiBersih(bulanIni)).totalAsetSen, rupiahKeSen(5000000));
    });

    test('(d) rentang mundur / kunci bulan salah ditolak', () async {
      await expectLater(
        repo.tren(dari: bulanIni, sampai: bulanLampau),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repo.tren(dari: 'September', sampai: bulanIni),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('tren ikut menghitung kewajiban yang diarsipkan (sertakanArsip)',
        () async {
      final k = await kewajibanBaru('Utang lama', 1000000);
      await repo.arsipkanKewajiban(k.id);
      expect((await repo.tren(dari: bulanLampau, sampai: bulanIni))
              .last
              .totalKewajibanSen,
          0);
      expect(
        (await repo.tren(dari: bulanLampau, sampai: bulanIni, sertakanArsip: true))
            .last
            .totalKewajibanSen,
        rupiahKeSen(1000000),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Grafik (widget mandiri)
  // -------------------------------------------------------------------------

  group('grafik tren kekayaan', () {
    testWidgets('menampilkan label bulan dan nilai terakhir', (t) async {
      await t.binding.setSurfaceSize(const Size(420, 300));
      await t.pumpWidget(MaterialApp(
        theme: AppTema.terang(),
        home: Scaffold(
          body: GrafikTrenKekayaan(
            key: const Key('grafik_tren'),
            tren: [
              NilaiBersih(
                  bulan: '2026-07',
                  totalAsetSen: rupiahKeSen(1000000),
                  totalKewajibanSen: rupiahKeSen(400000)),
              NilaiBersih(
                  bulan: '2026-08',
                  totalAsetSen: rupiahKeSen(2000000),
                  totalKewajibanSen: rupiahKeSen(400000)),
              NilaiBersih(
                  bulan: '2026-09',
                  totalAsetSen: rupiahKeSen(2500000),
                  totalKewajibanSen: rupiahKeSen(300000)),
            ],
          ),
        ),
      ));
      await t.pump();

      expect(find.byKey(const Key('grafik_tren')), findsOneWidget);
      expect(find.text('Tren nilai bersih bulanan'), findsOneWidget);
      // Batang dan label bulan digambar lewat CustomPaint (bukan widget Text),
      // jadi yang diperiksa: pelukis tren benar-benar dipasang.
      final pelukis = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<CustomPainter>()
          .where((p) => p.runtimeType.toString().contains('PelukisTren'))
          .toList();
      expect(pelukis.length, 1);
      expect(find.text('Terakhir: Rp 2.200.000'), findsOneWidget);

      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('tanpa riwayat: menulis ajakan mengisi, bukan angka nol',
        (t) async {
      await t.binding.setSurfaceSize(const Size(420, 300));
      await t.pumpWidget(MaterialApp(
        theme: AppTema.terang(),
        home: const Scaffold(body: GrafikTrenKekayaan(tren: [])),
      ));
      await t.pump();

      expect(find.textContaining('Belum ada riwayat bulanan'), findsOneWidget);
      expect(find.textContaining('Terakhir:'), findsNothing);
      expect(find.text('Rp 0'), findsNothing);

      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.binding.setSurfaceSize(null);
    });

    test('label bulan dibuat tanpa data locale intl', () {
      expect(labelBulanSingkat('2026-09'), 'Sep');
      expect(labelBulanPanjang('2026-09'), 'September 2026');
      expect(labelBulanSingkat('2027-01'), 'Jan 2027');
      expect(labelBulanPanjang('2026-12'), 'Desember 2026');
      expect(labelBulanSingkat('entah'), 'entah');
    });
  });

  // -------------------------------------------------------------------------
  // Layar (f)
  // -------------------------------------------------------------------------

  group('layar Kekayaan Bersih', () {
    /// Menampilkan layar dengan jam uji 15 Sep 2026.
    Future<void> tampilkan(WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: KekayaanScreen(jamSekarang: () => jamUji),
        ),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 300));
    }

    /// Habiskan SnackBar, lepas layar, kembalikan ukuran permukaan.
    Future<void> tutup(WidgetTester t) async {
      await t.pump(const Duration(seconds: 5));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.binding.setSurfaceSize(null);
    }

    /// Gulir sampai target terlihat (ListView hanya membangun baris terlihat).
    Future<void> gulirKe(WidgetTester t, Finder target, {int maks = 8}) async {
      for (var i = 0; i < maks; i++) {
        if (target.evaluate().isNotEmpty) return;
        await t.drag(find.byType(Scrollable).first, const Offset(0, -200));
        await t.pump(const Duration(milliseconds: 120));
      }
    }

    /// Pastikan tombol baris benar-benar terlihat sebelum ditekan (ListView
    /// hanya menyusun baris yang tampak di layar).
    Future<void> tekan(WidgetTester t, Finder target) async {
      await t.ensureVisible(target);
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(target);
      await t.pump(const Duration(milliseconds: 150));
    }

    /// Tunggu sampai SnackBar hilang supaya tidak menutupi tombol di bawah.
    Future<void> tungguSnackBar(WidgetTester t) =>
        t.pump(const Duration(seconds: 5));

    List<String> teksTampil(WidgetTester t) => t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    testWidgets('(f) kartu nilai bersih tampil dan grafik dirender',
        (t) async {
      await asetBaru('Tabungan BCA', 8000000, institusi: 'BCA');
      await asetBaru('Emas Antam', 2000000, jenis: JenisAset.emas);
      await kewajibanBaru('KPR rumah', 3000000);

      await tampilkan(t);

      expect(find.byKey(const Key('nilai_bersih')), findsOneWidget);
      expect(find.text('Nilai bersih bulan ini'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const Key('angka_nilai_bersih'))).data,
        'Rp 7.000.000',
      );
      expect(find.textContaining('Aset Rp 10.000.000'), findsOneWidget);
      expect(find.byKey(const Key('grafik_tren')), findsOneWidget);
      expect(find.byKey(const Key('label_bulan')), findsOneWidget);
      expect(find.text('September 2026'), findsOneWidget);

      await tutup(t);
    });

    testWidgets('daftar aset: nilai, lencana likuid, subtotal; kewajiban: '
        'sisa pokok', (t) async {
      final kas = await asetBaru('Kas di rumah', 5000000, likuid: true);
      final motor = await asetBaru('Motor', 15000000,
          likuid: false, jenis: JenisAset.kendaraan);
      final kpr = await kewajibanBaru('KPR rumah', 200000000);

      await tampilkan(t);

      expect(find.text('Kas di rumah'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(Key('nilai_aset_${kas.id}'))).data,
        'Rp 5.000.000',
      );
      expect(find.text('Likuid'), findsOneWidget);
      expect(find.text('Tidak likuid'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(Key('nilai_aset_${motor.id}'))).data,
        'Rp 15.000.000',
      );
      expect(
        t.widget<Text>(find.byKey(const Key('subtotal_aset'))).data,
        'Subtotal Rp 20.000.000',
      );

      await gulirKe(t, find.byKey(Key('nilai_kewajiban_${kpr.id}')));
      expect(find.text('KPR rumah'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(Key('nilai_kewajiban_${kpr.id}'))).data,
        'Rp 200.000.000',
      );
      expect(find.textContaining('sisa pokok'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const Key('subtotal_kewajiban'))).data,
        'Subtotal Rp 200.000.000',
      );

      await tutup(t);
    });

    testWidgets('(e) aset tanpa catatan bulan: layar memakai nilai awal, '
        'tidak kosong', (t) async {
      final deposito = await asetBaru('Deposito', 5000000, jenis: JenisAset.bank);

      await tampilkan(t);

      expect(find.text('Deposito'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(Key('nilai_aset_${deposito.id}'))).data,
        'Rp 5.000.000',
      );
      expect(
        t.widget<Text>(find.byKey(const Key('angka_nilai_bersih'))).data,
        'Rp 5.000.000',
      );
      expect(
        t.widget<Text>(find.byKey(const Key('subtotal_aset'))).data,
        'Subtotal Rp 5.000.000',
      );
      expect(find.textContaining('Belum ada aset'), findsNothing);

      await tutup(t);
    });

    testWidgets('bulan berjalan: isi nilai tersimpan tanpa dialog kunci',
        (t) async {
      final a = await asetBaru('Kas', 1000000);
      await tampilkan(t);

      await tekan(t, find.byKey(Key('isi_nilai_aset_${a.id}')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('input_nilai')), findsOneWidget);

      await t.enterText(find.byKey(const Key('input_nilai')), '3000000');
      await t.tap(find.byKey(const Key('simpan_nilai')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('dialog_alasan')), findsNothing);
      final b = await barisAset(a.id);
      expect(b.bulan, bulanIni);
      expect(b.nilaiSen, rupiahKeSen(3000000));
      expect(b.terkunci, isFalse);
      expect(
        t.widget<Text>(find.byKey(const Key('angka_nilai_bersih'))).data,
        'Rp 3.000.000',
      );

      await tutup(t);
    });

    testWidgets('bulan lampau: penjelasan tampil dan nilai wajib pakai alasan',
        (t) async {
      final a = await asetBaru('Kas', 1000000);
      await repo.simpanNilaiAset(
          asetId: a.id, bulan: bulanLampau, nilaiSen: rupiahKeSen(1000000));

      await tampilkan(t);

      // Pindah ke bulan lampau -> penjelasan kunci muncul.
      await t.tap(find.byKey(const Key('bulan_sebelum')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('catatan_bulan_lampau')), findsOneWidget);
      expect(find.text('Agustus 2026 sudah lewat dan terkunci'), findsOneWidget);
      expect(find.textContaining('tidak berubah retroaktif'), findsOneWidget);
      expect(find.text('Nilai bersih Agustus 2026'), findsOneWidget);

      // Coba isi nilai bulan lampau -> dialog alasan wajib.
      await tekan(t, find.byKey(Key('isi_nilai_aset_${a.id}')));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(find.byKey(const Key('input_nilai')), '2000000');
      await t.tap(find.byKey(const Key('simpan_nilai')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('dialog_alasan')), findsOneWidget);
      expect(find.text('Bulan Agustus 2026 sudah terkunci'), findsOneWidget);

      // Alasan kosong ditolak.
      await t.tap(find.byKey(const Key('simpan_alasan')));
      await t.pump();
      expect(find.textContaining('Alasan perlu diisi'), findsOneWidget);
      expect((await barisAset(a.id)).nilaiSen, rupiahKeSen(1000000));

      // Dengan alasan: tersimpan + jejak alasan tercatat.
      await t.enterText(
          find.byKey(const Key('input_alasan')), 'salah ketik nominal');
      await t.tap(find.byKey(const Key('simpan_alasan')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 300));

      final b = await barisAset(a.id);
      expect(b.nilaiSen, rupiahKeSen(2000000));
      expect(b.terkunci, isTrue);
      expect(b.alasanBukaKunci, 'salah ketik nominal');
      expect(b.dibukaKunciPada, isNotNull);

      await tutup(t);
    });

    testWidgets('tombol "Tambah aset" membuka form dan menyimpannya',
        (t) async {
      await tampilkan(t);
      expect(find.textContaining('Belum ada aset'), findsOneWidget);

      await t.tap(find.byKey(const Key('tambah_aset')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('nama_aset')), findsOneWidget);

      await t.enterText(find.byKey(const Key('nama_aset')), 'Tabungan BNI');
      await t.enterText(find.byKey(const Key('nilai_aset')), '4000000');
      await t.tap(find.byKey(const Key('simpan_aset')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('nama_aset')), findsNothing);
      expect(find.text('Tabungan BNI'), findsOneWidget);
      final tersimpan = await repo.ambilAset();
      expect(tersimpan.length, 1);
      expect(tersimpan.single.nilaiAwalSen, rupiahKeSen(4000000));
      expect(
        t.widget<Text>(find.byKey(const Key('angka_nilai_bersih'))).data,
        'Rp 4.000.000',
      );

      await tutup(t);
    });

    testWidgets('tombol "Tambah kewajiban" membuka form kewajiban', (t) async {
      await tampilkan(t);

      await t.tap(find.byKey(const Key('tambah_kewajiban')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('nama_kewajiban')), findsOneWidget);

      await t.enterText(find.byKey(const Key('nama_kewajiban')), 'KPR rumah');
      await t.enterText(find.byKey(const Key('sisa_kewajiban')), '150000000');
      await t.tap(find.byKey(const Key('simpan_kewajiban')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('nama_kewajiban')), findsNothing);
      final daftar = await repo.ambilKewajiban();
      expect(daftar.length, 1);
      expect(daftar.single.saldoAwalSen, rupiahKeSen(150000000));
      expect(
        t.widget<Text>(find.byKey(const Key('angka_nilai_bersih'))).data,
        '-Rp 150.000.000',
      );

      await tutup(t);
    });

    testWidgets('arsipkan aset: keluar dari hitungan dan bisa dikembalikan',
        (t) async {
      final a = await asetBaru('Motor', 15000000, likuid: false);
      await tampilkan(t);
      expect(
        t.widget<Text>(find.byKey(const Key('subtotal_aset'))).data,
        'Subtotal Rp 15.000.000',
      );

      await t.tap(find.byKey(Key('menu_aset_${a.id}')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Arsipkan'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));

      expect((await repo.ambilAset()).isEmpty, isTrue);
      expect(
        t.widget<Text>(find.byKey(const Key('subtotal_aset'))).data,
        'Subtotal Rp 0',
      );

      // Buka bagian arsip, lalu kembalikan asetnya.
      await tungguSnackBar(t); // SnackBar menutupi tombol di bagian bawah.
      await tekan(t, find.text('Aset diarsipkan (1)'));
      await t.pump(const Duration(milliseconds: 300));
      await tekan(t, find.byKey(Key('kembalikan_aset_${a.id}')));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));

      expect((await repo.ambilAset()).length, 1);

      await tutup(t);
    });

    testWidgets('hapus aset meminta konfirmasi lebih dulu', (t) async {
      final a = await asetBaru('Kas kecil', 500000);
      await tampilkan(t);

      await t.tap(find.byKey(Key('menu_aset_${a.id}')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Hapus'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Hapus aset "Kas kecil"?'), findsOneWidget);

      // Batal: data tetap ada.
      await t.tap(find.text('Batal'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect((await repo.ambilAset()).length, 1);

      // Konfirmasi: data terhapus.
      await t.tap(find.byKey(Key('menu_aset_${a.id}')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Hapus'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(const Key('konfirmasi_hapus')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));

      expect(await repo.ambilAset(), isEmpty);
      expect(find.textContaining('Belum ada aset'), findsOneWidget);

      await tutup(t);
    });

    testWidgets('kewajiban juga bisa diisi nilai dan diarsipkan', (t) async {
      final k = await kewajibanBaru('Kartu kredit', 5000000);
      await tampilkan(t);
      await tekan(t, find.byKey(Key('isi_nilai_kewajiban_${k.id}')));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(find.byKey(const Key('input_nilai')), '4500000');
      await t.tap(find.byKey(const Key('simpan_nilai')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 300));

      expect((await barisKewajiban(k.id)).nilaiSen, rupiahKeSen(4500000));
      expect(
        t.widget<Text>(find.byKey(const Key('angka_nilai_bersih'))).data,
        '-Rp 4.500.000',
      );

      // Arsipkan kewajiban -> nilai bersih kembali Rp 0.
      await tungguSnackBar(t); // SnackBar menutupi tombol di bagian bawah.
      await tekan(t, find.byKey(Key('menu_kewajiban_${k.id}')));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Arsipkan'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      expect(
        t.widget<Text>(find.byKey(const Key('angka_nilai_bersih'))).data,
        'Rp 0',
      );
      expect((await repo.ambilKewajiban()).isEmpty, isTrue);

      await tutup(t);
    });

    testWidgets('bahasa layar bebas kata yang dilarang (PRD III-11)', (t) async {
      await asetBaru('Tabungan BCA', 5000000, institusi: 'BCA');
      await kewajibanBaru('KPR rumah', 2000000);
      await tampilkan(t);
      // Buka juga seluruh blok dengan menggulir ke bawah.
      for (var i = 0; i < 4; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -240));
        await t.pump(const Duration(milliseconds: 100));
      }

      const terlarang = [
        'skor',
        'anda gagal',
        'kamu',
        'berdosa',
        'belum sholat',
        'wajib anda',
      ];
      for (final teks in teksTampil(t)) {
        for (final kata in terlarang) {
          expect(teks.toLowerCase().contains(kata), isFalse,
              reason: '"$teks" memuat "$kata"');
        }
      }
      expect(teksTampil(t), isNotEmpty);

      await tutup(t);
    });
  });
}
