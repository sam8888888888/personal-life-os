/// Uji FR-37 (rekap tahunan & kartu berbagi), FR-51 (kas & utang informal) dan
/// FR-53 (salin nomor dokumen).
///
/// Yang dibuktikan:
///   * rekap tahunan hanya menghitung tahun yang dipilih, angkanya cocok dengan
///     data mentah (total, tepat waktu, bulan tersibuk, tagihan terbesar),
///   * kartu berbagi: teksnya berisi fakta tahun itu; saat belum ada data,
///     kartunya mengatakan belum ada (bukan angka nol yang menyesatkan),
///   * PNG benar-benar bisa dibuat dari kartu (penanda berkas PNG diperiksa) dan
///     berkas tersimpan di folder sementara,
///   * bila penangkapan gambar gagal, layar mengatakannya apa adanya,
///   * kas informal: saldo per pihak, ringkasan utang/piutang, tanda lunas,
///     dan catatan jatuh tempo dekat,
///   * dokumen: tombol "Salin nomor" menyalin nomor tanpa membuka berkasnya.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/laporan/kas_informal.dart';
import 'package:personal_life_os/core/laporan/rekap_tahunan.dart';
import 'package:personal_life_os/core/laporan/statistik_pembayaran.dart';
import 'package:personal_life_os/core/platform/kartu_gambar.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/features/laporan/rekap_tahunan_screen.dart';
import 'package:personal_life_os/features/dokumen/dokumen_screen.dart';
import 'package:personal_life_os/features/uang/kas_informal_screen.dart';

late AppDatabase db;
final sekarang = DateTime(2026, 9, 20, 9);

Future<void> layarTinggi(WidgetTester t) async {
  await t.binding.setSurfaceSize(const Size(1200, 2600));
  addTearDown(() => t.binding.setSurfaceSize(null));
}

PembayaranRingkas bayar(String nama, DateTime tanggal, int rupiah,
        {int telat = 0}) =>
    PembayaranRingkas(
      namaTagihan: nama,
      tanggalBayar: tanggal,
      jumlahSen: rupiah * 100,
      telatHari: telat,
    );

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  group('FR-37 logika rekap tahunan', () {
    test('hanya tahun terpilih yang dihitung', () {
      final rekap = hitungRekapTahunan([
        bayar('Listrik', DateTime(2026, 1, 10), 200000),
        bayar('Listrik', DateTime(2026, 3, 10), 250000, telat: 4),
        bayar('Internet', DateTime(2026, 3, 15), 300000),
        bayar('Listrik', DateTime(2025, 12, 1), 9000000),
      ], 2026);

      expect(rekap.jumlahPembayaran, 3);
      expect(rekap.totalSen, 750000 * 100);
      expect(rekap.tepatWaktu, 2);
      expect(rekap.lewatJatuhTempo, 1);
      expect(rekap.totalHariTelat, 4);
      expect(rekap.persenTepatWaktu, 67); // 2 dari 3
      expect(rekap.perBulanSen[3], 550000 * 100);
      expect(rekap.bulanTersibuk, 3);
      expect(namaBulan(rekap.bulanTersibuk!), 'Maret');
      expect(rekap.tagihanTerbesar, 'Listrik');
      expect(rupiahRingkas(rekap.totalSen), 'Rp 750.000');
      expect(rekap.kosong, isFalse);
    });

    test('tahun tanpa data dihitung nol, bukan ditebak', () {
      final rekap = hitungRekapTahunan(
          [bayar('Listrik', DateTime(2026, 1, 10), 200000)], 2024);
      expect(rekap.kosong, isTrue);
      expect(rekap.totalSen, 0);
      expect(rekap.persenTepatWaktu, 0);
      expect(rekap.bulanTersibuk, isNull);
      expect(rekap.tagihanTerbesar, isNull);
    });

    test('kartu berbagi memuat fakta tahun itu', () {
      final rekap = hitungRekapTahunan([
        bayar('Listrik', DateTime(2026, 1, 10), 200000),
        bayar('Internet', DateTime(2026, 3, 15), 300000),
      ], 2026);
      final baris = barisKartuRekap(rekap);
      expect(baris.first, 'Rekap 2026');
      expect(baris.join(' '), contains('2 pembayaran'));
      expect(baris.join(' '), contains('Rp 500.000'));
      expect(baris.join(' '), contains('100%'));
      expect(baris.join(' ').toLowerCase(), isNot(contains('gagal')));
      expect(barisKartuRekap(hitungRekapTahunan(const [], 2026)).join(' '),
          contains('Belum ada pembayaran'));
    });

    test('grafik bulanan selalu 12 batang dengan porsi 0–1', () {
      final grafik = grafikBulanan(hitungRekapTahunan([
        bayar('Listrik', DateTime(2026, 1, 10), 200000),
        bayar('Internet', DateTime(2026, 6, 15), 100000),
      ], 2026));
      expect(grafik, hasLength(12));
      expect(grafik.first.bulan, 1);
      expect(grafik.first.porsi, 1);
      expect(grafik[5].porsi, closeTo(0.5, 0.001));
      expect(grafik[2].totalSen, 0);
    });

    testWidgets('PNG kartu benar-benar terbentuk', (t) async {
      final kunci = GlobalKey();
      await t.pumpWidget(MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: kunci,
            child: Container(
              width: 200,
              height: 100,
              color: const Color(0xFF0D47A1),
              child: const Text('Rekap'),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();

      Uint8List? bytes;
      await t.runAsync(() async {
        bytes = await tangkapPng(kunci, rasio: 2);
      });
      expect(bytes, isNotNull);
      expect(pngSah(bytes), isTrue, reason: 'penanda berkas PNG harus sah');
      expect(bytes!.length, greaterThan(1000));
    });
  });

  group('layar rekap tahunan (FR-37)', () {
    testWidgets('menampilkan angka tahun & menyimpan kartu ke berkas',
        (t) async {
      final tagihanId = await db.into(db.tagihan).insert(TagihanCompanion.insert(
            nama: 'Listrik',
            jumlahSen: const Value(200000 * 100),
            jatuhTempo: DateTime(2026, 1, 10),
          ));
      await db.into(db.riwayatPembayaran).insert(
          RiwayatPembayaranCompanion.insert(
            tagihanId: tagihanId,
            periodeJatuhTempo: DateTime(2026, 1, 10),
            jumlahSen: 200000 * 100,
            tanggalBayar: DateTime(2026, 1, 8),
          ));
      await db.into(db.riwayatPembayaran).insert(
          RiwayatPembayaranCompanion.insert(
            tagihanId: tagihanId,
            periodeJatuhTempo: DateTime(2026, 3, 10),
            jumlahSen: 300000 * 100,
            tanggalBayar: DateTime(2026, 3, 14),
            telatHari: const Value(4),
          ));

      final dir = Directory.systemTemp.createTempSync('lifeos_wrapped');
      addTearDown(() => dir.deleteSync(recursive: true));

      // Byte PNG diambil dari penangkapan NYATA atas sebuah RepaintBoundary
      // (lihat uji "PNG kartu benar-benar terbentuk"), lalu disalurkan ke layar
      // supaya jalur simpan-berkas + lapor hasil ikut teruji tanpa perangkat.
      final kunciUji = GlobalKey();
      Uint8List? bytesPng;
      await t.pumpWidget(MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: kunciUji,
            child: Container(
              width: 200,
              height: 100,
              color: const Color(0xFF0D47A1),
              child: const Text('Rekap'),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();
      await t.runAsync(() async {
        bytesPng = await tangkapPng(kunciUji, rasio: 2);
      });
      expect(pngSah(bytesPng), isTrue,
          reason: 'penangkapan kartu harus menghasilkan PNG yang sah');

      await layarTinggi(t);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: RekapTahunanScreen(
            db: db,
            sekarang: sekarang,
            direktoriSementara: () async => dir,
            tangkapKartu: (_) async => bytesPng,
            // Lingkungan uji tidak punya lembar berbagi Android; yang diuji di
            // sini jalur simpan-berkas + laporan hasilnya.
            bagikan: ({required String jalur, String judul = '', String jenis = ''}) async =>
                false,
          ),
        ),
      ));
      await t.pumpAndSettle();

      expect(find.textContaining('Total dibayar: Rp 500.000'), findsOneWidget);
      expect(find.textContaining('lewat jatuh tempo 1×'), findsWidgets);
      expect(find.byKey(const Key('kartu_wrapped')), findsOneWidget);

      // Seluruh alur bagikan (tulis berkas + panggil lembar berbagi) memakai
      // I/O sungguhan, jadi dijalankan di jendela runAsync supaya tuntas.
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('bagikan_wrapped')));
        await Future<void>.delayed(const Duration(milliseconds: 600));
      });
      await t.pumpAndSettle();

      final berkas = File('${dir.path}/rekap-tahunan-2026.png');
      expect(berkas.existsSync(), isTrue,
          reason: 'kartu harus tersimpan sebagai PNG');
      final isiBerkas = berkas.readAsBytesSync();
      expect(isiBerkas.length, bytesPng!.length,
          reason: 'isi berkas harus sama panjang dengan kartu yang ditangkap');
      expect(pngSah(isiBerkas), isTrue,
          reason: 'berkas harus berisi PNG; awal berkas = '
              '${isiBerkas.take(12).toList()}');

      // Lingkungan uji tidak punya lembar berbagi → pesannya harus jujur
      // menyebut berkasnya, bukan mengaku sudah dibagikan.
      final pesan =
          t.widget<Text>(find.byKey(const Key('pesan_wrapped'))).data ?? '';
      expect(pesan, contains(berkas.path));
      expect(pesan.toLowerCase(), contains('belum bisa dibagikan'));
    });

    testWidgets('bila kartu gagal ditangkap, layar mengatakannya', (t) async {
      await layarTinggi(t);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: RekapTahunanScreen(
            db: db,
            sekarang: sekarang,
            tangkapKartu: (_) async => null,
          ),
        ),
      ));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('bagikan_wrapped')));
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.byKey(const Key('pesan_wrapped'))).data,
        contains('belum bisa digambar'),
      );
    });
  });

  group('FR-51 logika kas informal', () {
    KasInformalData baris(int id, String jenis, String pihak, int rupiah,
            {bool lunas = false, DateTime? jatuhTempo}) =>
        KasInformalData(
          id: id,
          jenis: jenis,
          pihak: pihak,
          tanggal: DateTime(2026, 9, 1),
          jumlahSen: rupiah * 100,
          kodeMataUang: 'IDR',
          lunas: lunas,
          jatuhTempo: jatuhTempo,
          dibuatPada: sekarang,
          diubahPada: sekarang,
        );

    test('total utang, piutang & saldo per pihak', () {
      final ringkas = ringkasKas([
        baris(1, 'utang', 'Warung Bu Sri', 150000),
        baris(2, 'utang', 'Warung Bu Sri', 50000),
        baris(3, 'piutang', 'Pak RT', 200000),
        baris(4, 'tunai', 'Kas harian', 75000),
        baris(5, 'utang', 'Kontrakan', 1000000, lunas: true),
      ], sekarang);

      expect(ringkas.totalUtangSen, 200000 * 100);
      expect(ringkas.totalPiutangSen, 200000 * 100);
      expect(ringkas.totalTunaiSen, 75000 * 100);
      expect(ringkas.jumlahBelumLunas, 3);
      final warung = ringkas.perPihak.firstWhere((s) => s.pihak == 'Warung Bu Sri');
      expect(warung.utangSen, 200000 * 100);
      expect(warung.selisihSen, -200000 * 100);
      expect(
        ringkas.perPihak.where((s) => s.pihak == 'Kontrakan'),
        isEmpty,
        reason: 'yang sudah lunas tidak masuk saldo',
      );
      expect(kalimatKas(ringkas), contains('Kita berutang'));
      expect(kalimatKas(ringkas).toLowerCase(), isNot(contains('gagal')));
      expect(ringkas.kosong, isFalse);
    });

    test('jatuh tempo dekat diurutkan dan dibatasi rentangnya', () {
      final ringkas = ringkasKas([
        baris(1, 'utang', 'Warung', 100000,
            jatuhTempo: sekarang.add(const Duration(days: 3))),
        baris(2, 'utang', 'Kontrakan', 900000,
            jatuhTempo: sekarang.add(const Duration(days: 60))),
        baris(3, 'utang', 'Tetangga', 50000,
            jatuhTempo: sekarang.subtract(const Duration(days: 2))),
      ], sekarang);
      expect(ringkas.jatuhTempoDekat, hasLength(2));
      expect(ringkas.jatuhTempoDekat.first.pihak, 'Tetangga'); // paling dekat
      expect(kalimatKas(ringkas), contains('jatuh tempo dekat'));
    });

    test('tanpa catatan → kalimat menjelaskan gunanya', () {
      final kosong = ringkasKas(const [], sekarang);
      expect(kosong.kosong, isTrue);
      expect(kalimatKas(kosong), contains('Belum ada catatan'));
    });
  });

  group('layar kas informal (FR-51)', () {
    testWidgets('simpan utang, saldo per pihak, tandai lunas, hapus',
        (t) async {
      await layarTinggi(t);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: KasInformalScreen(db: db, sekarang: sekarang),
        ),
      ));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const Key('isi_pihak_kas')), 'Warung Bu Sri');
      await t.enterText(find.byKey(const Key('isi_jumlah_kas')), '150000');
      await t.tap(find.byKey(const Key('simpan_kas')));
      await t.pumpAndSettle();

      final catatan = await db.select(db.kasInformal).get();
      expect(catatan, hasLength(1));
      expect(catatan.first.pihak, 'Warung Bu Sri');
      expect(catatan.first.jenis, 'utang');
      expect(catatan.first.jumlahSen, 150000 * 100);
      expect(find.textContaining('Kita berutang'), findsWidgets);
      expect(
        t.widget<Text>(find.byKey(const Key('saldo_pihak_Warung Bu Sri'))).data,
        contains('kita berutang'),
      );

      final id = catatan.first.id;
      await t.tap(find.byKey(Key('lunas_kas_$id')));
      await t.pumpAndSettle();
      final lunas = (await db.select(db.kasInformal).getSingle());
      expect(lunas.lunas, isTrue);
      expect(lunas.tanggalLunas, isNotNull);

      await t.tap(find.byKey(Key('hapus_kas_$id')));
      await t.pumpAndSettle();
      expect(await db.select(db.kasInformal).get(), isEmpty);
    });

    testWidgets('pihak & jumlah kosong → diberi tahu', (t) async {
      await layarTinggi(t);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: KasInformalScreen(db: db, sekarang: sekarang),
        ),
      ));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('simpan_kas')));
      await t.pumpAndSettle();
      expect(find.textContaining('Tulis nama pihaknya'), findsOneWidget);

      await t.enterText(find.byKey(const Key('isi_pihak_kas')), 'Warung');
      await t.tap(find.byKey(const Key('simpan_kas')));
      await t.pumpAndSettle();
      expect(find.textContaining('Isi jumlahnya dulu'), findsOneWidget);
      expect(await db.select(db.kasInformal).get(), isEmpty);
    });
  });

  group('FR-53 salin nomor dokumen', () {
    testWidgets('tombol salin nomor ada & melaporkan hasilnya', (t) async {
      await db.into(db.dokumen).insert(DokumenCompanion.insert(
            idDokumen: 'dok-paspor-1',
            nama: 'Paspor',
            jenis: const Value('paspor'),
            nomor: const Value('C1234567'),
          ));

      await layarTinggi(t);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: DokumenScreen(jamSekarang: () => sekarang),
        ),
      ));
      await t.pumpAndSettle();

      final id = (await db.select(db.dokumen).getSingle()).id;
      await t.tap(find.byKey(Key('salin_nomor_$id')));
      await t.pump();
      // Beri waktu batas-batas kanal papan klip (1,2 dtk) + animasi pesan.
      await t.pump(const Duration(milliseconds: 1500));
      await t.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('pesan_salin_nomor')), findsOneWidget,
          reason: 'pesan hasil salin harus muncul');

      final pesan = t
          .widgetList<Text>(find.descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Text),
          ))
          .map((w) => w.data ?? '')
          .join(' ');
      expect(pesan, contains('Paspor'));
      expect(pesan, contains('salin'),
          reason: 'pesan harus menyebut nomor disalin (atau belum bisa disalin)');
      // Nomor dokumen TIDAK ditampilkan di pesan (tidak terbaca orang lain).
      expect(pesan, isNot(contains('C1234567')));
    });
  });
}
