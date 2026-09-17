/// Uji FR-73 - Kalender keuangan bulanan.
///
/// Kriteria yang diuji:
/// * (a) fungsi murni: pengelompokan per tanggal, ringkasan bulan
///   (masuk/keluar/terlewat), dan urutan peristiwa - angka dihitung sendiri;
/// * (b) repositori: `bulan()` memuat HANYA tanggal di bulan itu - batas atas
///   EKSKLUSIF (tanggal 1 bulan berikutnya tidak ikut), baris pukul 08:00 di
///   hari terakhir bulan tetap ikut, dan satu sumber yang tidak terbaca tidak
///   menggagalkan seluruh bulan;
/// * (c) layar: grid tampil, ketuk tanggal 20 menampilkan peristiwa tagihan,
///   pindah bulan mengubah label, keadaan kosong menulis "Belum ada data";
/// * (d) bahasa aman pasal III-11 (tanpa kata menghakimi).
///
/// Waktu uji dikunci: Selasa, 15 September 2026 pukul 08.00.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/kalender_keuangan/peristiwa_keuangan.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/core/utils/waktu.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/kalender_keuangan_repository.dart';
import 'package:personal_life_os/data/repository/pengeluaran_terencana_repository.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/data/repository/transaksi_repository.dart';
import 'package:personal_life_os/features/kalender/kalender_keuangan_screen.dart';

late AppDatabase db;
late KalenderKeuanganRepository repo;

/// Waktu patok uji: Selasa, 15 September 2026 pukul 08.00.
final jamUji = DateTime(2026, 9, 15, 8);

/// Kata yang dilarang pasal III-11.
const List<String> kataTerlarang = <String>[
  'kamu',
  'gagal',
  'skor',
  'nilai',
  'malas',
  'rajin',
  'pelit',
  'buruk',
  'berdosa',
  'wajib anda',
];

void periksaBahasaAman(Iterable<String> teks, String bagian) {
  final gabung = teks.join(' | ').toLowerCase();
  for (final kata in kataTerlarang) {
    expect(gabung.contains(kata), isFalse,
        reason: '$bagian memuat kata terlarang "$kata".');
  }
}

/// Sisipkan satu tagihan uji; mengembalikan id-nya.
Future<int> tambahTagihan(
  String nama,
  DateTime jatuhTempo, {
  int sen = 0,
  bool aktif = true,
  bool lunas = false,
}) async {
  final t = await TagihanRepository(db).tambah(TagihanCompanion.insert(
    nama: nama,
    jumlahSen: Value<int>(sen),
    jatuhTempo: jatuhTempo,
    lunas: Value<bool>(lunas),
    statusAktif: Value<bool>(aktif),
  ));
  return t.id;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = KalenderKeuanganRepository(db, jamSekarang: () => jamUji);
    pakaiSumberWaktu(() => jamUji);
  });

  tearDown(() async {
    pakaiWaktuAsli();
    await db.close();
  });

  // =========================================================================
  // (a) Fungsi murni
  // =========================================================================

  group('fungsi murni peristiwa keuangan', () {
    test('(1) kelompokPerTanggal mengabaikan jam & urutannya tetap', () {
      final daftar = <PeristiwaKeuangan>[
        PeristiwaKeuangan(
          tanggal: DateTime(2026, 9, 21, 13, 30),
          judul: 'Rencana: Servis motor',
          nominalSen: -40000000,
          jenis: JenisPeristiwa.pengeluaranTerencana,
          rujukan: 'terencana:1',
        ),
        PeristiwaKeuangan(
          tanggal: DateTime(2026, 9, 20, 23, 59),
          judul: 'Transaksi Gaji',
          nominalSen: 5000000,
          jenis: JenisPeristiwa.transaksi,
          sudahTerjadi: true,
        ),
        PeristiwaKeuangan(
          tanggal: DateTime(2026, 9, 20, 8),
          judul: 'Tagihan: Listrik PLN',
          nominalSen: -18600000,
          jenis: JenisPeristiwa.tagihan,
          rujukan: 'tagihan:7',
        ),
      ];

      final peta = kelompokPerTanggal(daftar);

      // Kunci selalu pukul 00:00 dan urut tanggal menaik.
      expect(peta.keys.toList(),
          <DateTime>[DateTime(2026, 9, 20), DateTime(2026, 9, 21)]);
      // Tagihan lebih dulu daripada transaksi, walau jamnya lebih awal.
      expect(
        peta[DateTime(2026, 9, 20)]!.map((e) => e.judul).toList(),
        <String>['Tagihan: Listrik PLN', 'Transaksi Gaji'],
      );
      expect(peta[DateTime(2026, 9, 21)]!.single.judul, 'Rencana: Servis motor');
      // Jam pada kunci tidak berpengaruh.
      expect(peta.containsKey(DateTime(2026, 9, 21)), isTrue);

      // Daftar masukan tidak diubah urutannya oleh fungsi pengelompokan.
      expect(daftar.first.judul, 'Rencana: Servis motor');
    });

    test('(2) ringkasBulan hanya menghitung bulan itu, arah uang dari tanda', () {
      final nyata = <PeristiwaKeuangan>[
        PeristiwaKeuangan(
          tanggal: DateTime(2026, 9, 20),
          judul: 'Tagihan: Listrik PLN',
          nominalSen: -18600000,
          jenis: JenisPeristiwa.tagihan,
        ),
        PeristiwaKeuangan(
          tanggal: DateTime(2026, 9, 5),
          judul: 'Tagihan: Internet',
          nominalSen: -3000000,
          jenis: JenisPeristiwa.jatuhTempoTerlewat,
        ),
        PeristiwaKeuangan(
          tanggal: DateTime(2026, 9, 25),
          judul: 'Gaji',
          nominalSen: 5000000,
          jenis: JenisPeristiwa.transaksi,
          sudahTerjadi: true,
        ),
        PeristiwaKeuangan(
          tanggal: DateTime(2026, 9, 16),
          judul: 'Makan',
          nominalSen: -2500000,
          jenis: JenisPeristiwa.transaksi,
          sudahTerjadi: true,
        ),
        PeristiwaKeuangan(
          tanggal: DateTime(2026, 9, 30),
          judul: 'Dokumen: SIM berakhir',
          nominalSen: 0,
          jenis: JenisPeristiwa.dokumen,
        ),
        // Bulan lain: tidak boleh ikut dihitung.
        PeristiwaKeuangan(
          tanggal: DateTime(2026, 10, 1),
          judul: 'Tagihan: Sekolah anak',
          nominalSen: -99999999,
          jenis: JenisPeristiwa.tagihan,
        ),
      ];

      final r = ringkasBulan(nyata, 9, 2026);

      expect(r.totalMasukSen, 5000000);
      expect(r.totalKeluarSen, 18600000 + 3000000 + 2500000);
      expect(r.totalTerlewatSen, 3000000);
      expect(r.jumlahPeristiwa, 5);
      expect(r.jumlahTerlewat, 1);
      expect(r.bersihSen, 5000000 - 24100000);
      expect(r.kosong, isFalse);

      // Bulan tanpa peristiwa: kosong, bukan angka nol yang menyesatkan.
      final kosong = ringkasBulan(nyata, 8, 2026);
      expect(kosong.kosong, isTrue);
      expect(kosong.jumlahPeristiwa, 0);
      expect(kosong.totalKeluarSen, 0);

      // Ringkasan memakai parameter (bulan, tahun), bukan urutan daftar.
      expect(ringkasBulan(nyata, 10, 2026).totalKeluarSen, 99999999);
    });

    test('(3) urutPeristiwa: tanggal, lalu jenis, lalu judul', () {
      final daftar = <PeristiwaKeuangan>[
        PeristiwaKeuangan(
          tanggal: DateTime(2026, 9, 20),
          judul: 'Transaksi Makan',
          nominalSen: -1000,
          jenis: JenisPeristiwa.transaksi,
          sudahTerjadi: true,
        ),
        PeristiwaKeuangan(
          tanggal: DateTime(2026, 9, 20),
          judul: 'Angsuran: Motor',
          nominalSen: -2000,
          jenis: JenisPeristiwa.angsuran,
        ),
        PeristiwaKeuangan(
          tanggal: DateTime(2026, 9, 20),
          judul: 'Tagihan: Listrik',
          nominalSen: -3000,
          jenis: JenisPeristiwa.tagihan,
        ),
        PeristiwaKeuangan(
          tanggal: DateTime(2026, 9, 21),
          judul: 'Tagihan: Air',
          nominalSen: -4000,
          jenis: JenisPeristiwa.tagihan,
        ),
      ];

      expect(
        urutPeristiwa(daftar).map((e) => e.judul).toList(),
        <String>[
          'Tagihan: Listrik',
          'Angsuran: Motor',
          'Transaksi Makan',
          'Tagihan: Air',
        ],
      );
      // Fungsi murni: daftar masukan tidak diubah.
      expect(daftar.first.judul, 'Transaksi Makan');
    });

    test('(4) kunciTanggal & diBulan memakai hari kalender', () {
      expect(kunciTanggal(DateTime(2026, 9, 5, 23, 59)), '2026-09-05');
      expect(kunciTanggal(DateTime(2026, 12, 31)), '2026-12-31');
      expect(diBulan(DateTime(2026, 9, 30, 8), 2026, 9), isTrue);
      expect(diBulan(DateTime(2026, 10, 1), 2026, 9), isFalse);
      expect(samaHari(DateTime(2026, 9, 15, 8), DateTime(2026, 9, 15)), isTrue);
      expect(hariSaja(DateTime(2026, 9, 15, 8)), DateTime(2026, 9, 15));
    });
  });

  // =========================================================================
  // (b) Repositori - batas bulan
  // =========================================================================

  group('repositori kalender keuangan', () {
    test('(5) bulan() memuat bulan itu saja; tanggal 1 bulan berikutnya TIDAK '
        'ikut (batas atas eksklusif)', () async {
      await tambahTagihan('Listrik PLN', DateTime(2026, 9, 20), sen: 18600000);
      await PengeluaranTerencanaRepository(db, jamSekarang: () => jamUji).tambah(
        nama: 'Servis motor',
        jumlahSen: 40000000,
        tanggal: DateTime(2026, 9, 21),
      );
      // Pukul 08:00 di hari terakhir bulan -> harus IKUT (bukan tengah malam).
      await tambahTagihan('Air PDAM', DateTime(2026, 9, 30, 8), sen: 15000000);
      // Tanggal 1 bulan berikutnya -> TIDAK ikut.
      await tambahTagihan('Sekolah anak', DateTime(2026, 10, 1), sen: 25000000);

      final september = await repo.bulan(2026, 9);
      expect(
        september.map((p) => kunciTanggal(p.tanggal)).toSet(),
        <String>{'2026-09-20', '2026-09-21', '2026-09-30'},
      );
      expect(september.any((p) => p.judul.contains('Sekolah anak')), isFalse);
      expect(september.map((p) => p.judul).toList(), <String>[
        'Tagihan: Listrik PLN',
        'Rencana: Servis motor',
        'Tagihan: Air PDAM',
      ]);
      // Urut tanggal; nominal keluar bernilai negatif.
      expect(september.first.nominalSen, -18600000);
      expect(september.last.nominalSen, -15000000);
      expect(september.first.rujukan, startsWith('tagihan:'));

      final oktober = await repo.bulan(2026, 10);
      expect(oktober.map((p) => p.judul).toList(),
          <String>['Tagihan: Sekolah anak']);

      final agustus = await repo.bulan(2026, 8);
      expect(agustus, isEmpty);
    });

    test('(6) kejadian yang tanggalnya sudah lewat ditandai jatuhTempoTerlewat',
        () async {
      // Sudah lewat (5 dan 10 September), belum ditandai terjadi.
      await tambahTagihan('Internet', DateTime(2026, 9, 5), sen: 3000000);
      await PengeluaranTerencanaRepository(db, jamSekarang: () => jamUji).tambah(
        nama: 'Servis motor',
        jumlahSen: 40000000,
        tanggal: DateTime(2026, 9, 10),
      );
      // Sudah lewat tetapi sudah ditandai terjadi -> bukan terlewat.
      final sudah = await PengeluaranTerencanaRepository(db, jamSekarang: () => jamUji)
          .tambah(
        nama: 'Pajak motor',
        jumlahSen: 20000000,
        tanggal: DateTime(2026, 9, 12),
      );
      await PengeluaranTerencanaRepository(db, jamSekarang: () => jamUji)
          .tandaiSudahTerjadi(sudah.id);
      // Transaksi nyata: sudah terjadi, tidak pernah dihitung terlewat.
      await TransaksiRepository(db).simpan(TransaksiCompanion.insert(
        idTransaksi: 'trx_uji_1',
        jenis: const Value<String>('pengeluaran'),
        tanggal: DateTime(2026, 9, 8),
        jumlahSen: 10000000,
        catatan: const Value<String?>('Belanja pasar'),
      ));

      final hasil = await repo.bulan(2026, 9);
      final terlewat = hasil
          .where((p) => p.jenis == JenisPeristiwa.jatuhTempoTerlewat)
          .toList();
      expect(terlewat.map((p) => p.judul).toList(),
          <String>['Tagihan: Internet', 'Rencana: Servis motor']);
      expect(terlewat.every((p) => p.tanggal.isBefore(DateTime(2026, 9, 15))),
          isTrue);

      final pajak = hasil.firstWhere((p) => p.judul.contains('Pajak motor'));
      expect(pajak.jenis, JenisPeristiwa.pengeluaranTerencana);
      expect(pajak.sudahTerjadi, isTrue);

      final transaksi = hasil.firstWhere((p) => p.judul == 'Belanja pasar');
      expect(transaksi.jenis, JenisPeristiwa.transaksi);
      expect(transaksi.nominalSen, -10000000);
      expect(transaksi.sudahTerjadi, isTrue);

      final r = ringkasBulan(hasil, 9, 2026);
      expect(r.totalKeluarSen, 3000000 + 40000000 + 20000000 + 10000000);
      expect(r.totalTerlewatSen, 43000000);
      expect(r.jumlahTerlewat, 2);
    });

    test('(7) transaksi pemasukan bernilai positif (arah uang dari jenis)',
        () async {
      await TransaksiRepository(db).simpan(TransaksiCompanion.insert(
        idTransaksi: 'trx_uji_2',
        jenis: const Value<String>('pemasukan'),
        tanggal: DateTime(2026, 9, 25),
        jumlahSen: 7000000,
      ));
      final hasil = await repo.bulan(2026, 9);
      expect(hasil.single.judul, 'Transaksi Pemasukan');
      expect(hasil.single.nominalSen, 7000000);
      expect(hasil.single.uangMasuk, isTrue);
      expect(ringkasBulan(hasil, 9, 2026).totalMasukSen, 7000000);
    });

    test('(8) satu sumber tidak terbaca: sumber itu dilewati, bulan tetap ada',
        () async {
      await tambahTagihan('Listrik PLN', DateTime(2026, 9, 20), sen: 18600000);
      // Rusak satu sumber saja: tabel dokumen dibuang.
      await db.customStatement('DROP TABLE dokumen');

      final hasil = await repo.bulan(2026, 9);

      expect(hasil.map((p) => p.judul).toList(),
          <String>['Tagihan: Listrik PLN']);
      expect(repo.sumberTerbaca, contains('tagihan'));
      expect(repo.sumberTerbaca, isNot(contains('dokumen')));
      expect(repo.sumberDilewati, hasLength(1));
      expect(repo.sumberDilewati.single, startsWith('dokumen:'));
      // Sumber lain tetap terbaca seluruhnya.
      expect(repo.sumberTerbaca.toSet(),
          <String>{'tagihan', 'langganan', 'angsuran', 'pengeluaranTerencana', 'transaksi'});
    });

    test('(9) seluruh sumber terbaca saat data sehat', () async {
      await repo.bulan(2026, 9);
      expect(repo.sumberTerbaca.toSet(), sumberKalenderKeuangan.toSet());
      expect(repo.sumberDilewati, isEmpty);
    });
  });

  // =========================================================================
  // (c) Layar
  // =========================================================================

  group('layar kalender keuangan (FR-73)', () {
    Future<void> tampilkan(WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: KalenderKeuanganScreen(jamSekarang: () => jamUji),
        ),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
    }

    /// Satu tulisan basis data saja per panggilan (ditunggu lewat runAsync),
    /// supaya uji tidak menggantung.
    Future<void> tulis(WidgetTester t, Future<void> Function() aksi) async {
      await t.runAsync(aksi);
    }

    String teksKunci(WidgetTester t, String kunci) =>
        t.widget<Text>(find.byKey(Key(kunci))).data ?? '';

    Future<void> tekan(WidgetTester t, Finder target) async {
      await t.ensureVisible(target);
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(target);
      await t.pump(const Duration(milliseconds: 150));
      await t.pump(const Duration(milliseconds: 400));
    }

    Future<void> tutup(WidgetTester t) async {
      await t.pump(const Duration(seconds: 5));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.binding.setSurfaceSize(null);
    }

    testWidgets('grid tampil, ketuk tanggal 20 menampilkan peristiwa tagihan, '
        'pindah bulan mengubah label', (t) async {
      await tulis(t, () async {
        await tambahTagihan('Listrik PLN', DateTime(2026, 9, 20), sen: 18600000);
      });

      await tampilkan(t);

      expect(teksKunci(t, 'label_bulan'), 'September 2026');
      expect(find.byKey(const Key('sel_2026-09-20')), findsOneWidget);
      expect(find.byKey(const Key('sel_2026-09-01')), findsOneWidget);
      expect(find.byKey(const Key('sel_2026-09-30')), findsOneWidget);
      // Tanggal 31 tidak ada di September.
      expect(find.byKey(const Key('sel_2026-09-31')), findsNothing);
      // Hari ini (15 September 2026) ditandai tepat satu kali.
      expect(find.byKey(const Key('hari_ini')), findsOneWidget);
      expect(find.byKey(const Key('legenda_jenis')), findsOneWidget);
      expect(find.byKey(const Key('daftar_hari')), findsOneWidget);

      // Sebelum diketik, tanggal hari ini belum punya peristiwa.
      expect(find.byKey(const Key('kosong_hari')), findsOneWidget);

      await tekan(t, find.byKey(const Key('sel_2026-09-20')));

      expect(find.text('Tagihan: Listrik PLN'), findsOneWidget);
      expect(find.byKey(const Key('kosong_hari')), findsNothing);
      expect(teksKunci(t, 'total_keluar'), 'Rp 186.000');
      expect(teksKunci(t, 'total_terlewat'), 'Rp 0');
      expect(teksKunci(t, 'total_masuk'), 'Rp 0');
      // Penanda titik jenis tagihan pada sel tanggal 20.
      expect(find.byKey(const Key('titik_2026-09-20_tagihan')), findsOneWidget);

      // Pindah bulan: label berubah dan pilihan tanggal direset.
      await tekan(t, find.byKey(const Key('bulan_berikut')));
      expect(teksKunci(t, 'label_bulan'), 'Oktober 2026');
      expect(find.byKey(const Key('sel_2026-10-20')), findsOneWidget);
      expect(find.text('Tagihan: Listrik PLN'), findsNothing);
      expect(teksKunci(t, 'total_keluar'), 'Belum ada data');

      await tekan(t, find.byKey(const Key('bulan_sebelum')));
      expect(teksKunci(t, 'label_bulan'), 'September 2026');

      await tutup(t);
    });

    testWidgets('tanpa data: menulis "Belum ada data", bukan Rp 0', (t) async {
      await tampilkan(t);

      expect(teksKunci(t, 'total_keluar'), 'Belum ada data');
      expect(teksKunci(t, 'total_terlewat'), 'Belum ada data');
      expect(teksKunci(t, 'total_masuk'), 'Belum ada data');
      expect(find.text('Rp 0'), findsNothing);
      expect(find.byKey(const Key('sumber_dilewati')), findsNothing);

      await tutup(t);
    });

    testWidgets('(d) bahasa layar aman pasal III-11', (t) async {
      await tulis(t, () async {
        await tambahTagihan('Listrik PLN', DateTime(2026, 9, 20), sen: 18600000);
        await tambahTagihan('Internet', DateTime(2026, 9, 5), sen: 3000000);
      });

      await tampilkan(t);
      await tekan(t, find.byKey(const Key('sel_2026-09-05')));

      final teks = <String>[
        for (final w in t.widgetList<Text>(find.byType(Text)))
          if (w.data != null) w.data!,
        for (final j in JenisPeristiwa.values) j.label,
        ...namaHariGrid,
      ];
      periksaBahasaAman(teks, 'layar kalender keuangan');

      // Jenis "terlewat" terlihat pada tanggal 5 September.
      expect(find.text('Jatuh tempo terlewat · Tanggal sudah lewat'),
          findsOneWidget);

      await tutup(t);
    });
  });
}
