/// Uji FR-29 (statistik pembayaran) & FR-30 (proyeksi arus kas).
///
/// Dua lapis:
///   * perhitungan murni (angka & tanggal) — kasus tepi: riwayat kosong, telat,
///     lintas bulan, tagihan lampau yang harus maju, frekuensi mingguan/tahunan,
///     langganan pause,
///   * layar — angka yang tampil cocok dengan data yang dimasukkan.
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/laporan/proyeksi_arus_kas.dart';
import 'package:personal_life_os/core/laporan/statistik_pembayaran.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/laporan/proyeksi_arus_kas_screen.dart';
import 'package:personal_life_os/features/laporan/statistik_pembayaran_screen.dart';

late AppDatabase db;

TagihanData tagihanUji({
  int id = 1,
  String nama = 'Listrik',
  DateTime? jatuhTempo,
  String frekuensi = 'bulanan',
  int? jumlahSen = 100000,
  bool aktif = true,
  bool lunas = false,
}) {
  final t = jatuhTempo ?? DateTime(2026, 9, 25);
  return TagihanData(
    id: id,
    jenis: 'tagihan',
    nama: nama,
    jumlahSen: jumlahSen,
    kodeMataUang: 'IDR',
    jatuhTempo: t,
    frekuensi: frekuensi,
    pengingatLeadHari: '7,3,1',
    pengingatJam: '09:00',
    kanalPengingat: 'push',
    prioritas: 'biasa',
    statusAktif: aktif,
    lunas: lunas,
    dibuatPada: DateTime(2026, 1, 1),
    diubahPada: DateTime(2026, 1, 1),
  );
}

LanggananData langgananUji({
  int id = 1,
  String nama = 'Netflix',
  int nominalSen = 200000,
  String siklus = 'bulanan',
  DateTime? mulai,
  String status = 'aktif',
}) {
  final m = mulai ?? DateTime(2026, 9, 10);
  return LanggananData(
    id: id,
    idLangganan: 'lgn_$id',
    nama: nama,
    nominalSen: nominalSen,
    kodeMataUang: 'IDR',
    siklus: siklus,
    tanggalMulai: m,
    perpanjangOtomatis: true,
    status: status,
    dibuatPada: DateTime(2026, 1, 1),
    diubahPada: DateTime(2026, 1, 1),
  );
}

void main() {
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));

  tearDown(() => db.close());

  group('FR-29 · Statistik pembayaran', () {
    test('riwayat kosong → semua nol, tanpa pembagian nol', () {
      final s = hitungStatistikPembayaran(const []);
      expect(s.kosong, isTrue);
      expect(s.totalSen, 0);
      expect(s.rataRataSen, 0);
      expect(s.persenTepatWaktu, 0);
      expect(s.rataHariTelat, 0);
    });

    test('total, rata-rata, terbesar/terkecil, tepat waktu & telat', () {
      final s = hitungStatistikPembayaran([
        PembayaranRingkas(
            namaTagihan: 'Listrik',
            tanggalBayar: DateTime(2026, 9, 20),
            jumlahSen: 250000),
        PembayaranRingkas(
            namaTagihan: 'Internet',
            tanggalBayar: DateTime(2026, 9, 5),
            jumlahSen: 350000,
            telatHari: 3),
        PembayaranRingkas(
            namaTagihan: 'Air',
            tanggalBayar: DateTime(2026, 9, 2),
            jumlahSen: 150000),
      ]);
      expect(s.jumlahPembayaran, 3);
      expect(s.totalSen, 750000);
      expect(s.rataRataSen, 250000);
      expect(s.terbesarSen, 350000);
      expect(s.terkecilSen, 150000);
      expect(s.tepatWaktu, 2);
      expect(s.lewatJatuhTempo, 1);
      expect(s.persenTepatWaktu, 67);
      expect(s.rataHariTelat, 3);
    });

    test('tren 12 bulan: bulan kosong tetap muncul, terurut lama→baru', () {
      final baris = [
        PembayaranRingkas(
            namaTagihan: 'Listrik',
            tanggalBayar: DateTime(2026, 9, 20),
            jumlahSen: 250000),
        PembayaranRingkas(
            namaTagihan: 'Listrik',
            tanggalBayar: DateTime(2026, 7, 20),
            jumlahSen: 200000),
      ];
      final tren = statistikPerBulan(baris, acuan: DateTime(2026, 9, 21));
      expect(tren, hasLength(12));
      expect(tren.first.bulan, DateTime(2025, 10, 1));
      expect(tren.last.bulan, DateTime(2026, 9, 1));
      expect(tren.last.totalSen, 250000);
      expect(tren.last.jumlahPembayaran, 1);
      expect(tren[9].bulan, DateTime(2026, 7, 1));
      expect(tren[9].totalSen, 200000);
      expect(tren[10].totalSen, 0, reason: 'Agustus belum ada pembayaran');
    });

    test('per tagihan: diurutkan dari total terbesar + rata-rata benar', () {
      final hasil = statistikPerTagihan([
        PembayaranRingkas(
            namaTagihan: 'Air',
            tanggalBayar: DateTime(2026, 9, 1),
            jumlahSen: 100000),
        PembayaranRingkas(
            namaTagihan: 'Listrik',
            tanggalBayar: DateTime(2026, 8, 1),
            jumlahSen: 300000),
        PembayaranRingkas(
            namaTagihan: 'Listrik',
            tanggalBayar: DateTime(2026, 9, 1),
            jumlahSen: 500000),
      ]);
      expect(hasil.first.nama, 'Listrik');
      expect(hasil.first.jumlahPembayaran, 2);
      expect(hasil.first.totalSen, 800000);
      expect(hasil.first.rataRataSen, 400000);
      expect(hasil.last.nama, 'Air');
    });

    testWidgets('layar menampilkan angka sesuai data yang dimasukkan',
        (t) async {
      final repo = TagihanRepository(db);
      await repo.tambah(TagihanCompanion.insert(
        nama: 'Listrik',
        jatuhTempo: DateTime(2026, 9, 20),
        jumlahSen: const Value(250000),
      ));
      final listrik = (await db.select(db.tagihan).get()).single;
      await repo.tandaiLunas(listrik.id, tanggalBayar: DateTime(2026, 9, 20));

      await t.binding.setSurfaceSize(const Size(430, 1400));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: StatistikPembayaranScreen(acuan: DateTime(2026, 9, 21)),
        ),
      ));
      // Tunggu pemuatan data (kueri basis data) selesai.
      await t.pumpAndSettle();

      expect(find.byKey(const Key('stat_total')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('stat_total'))).data,
          'Rp 2.500');
      expect(t.widget<Text>(find.byKey(const Key('stat_tepat'))).data,
          '100% (1 dari 1)');
      expect(find.byKey(const Key('per_tagihan_Listrik')), findsOneWidget);

      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('layar ramah saat riwayat masih kosong', (t) async {
      await t.binding.setSurfaceSize(const Size(430, 950));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: StatistikPembayaranScreen()),
      ));
      await t.pumpAndSettle();
      expect(find.textContaining('Belum ada riwayat pembayaran'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });
  });

  group('FR-30 · Proyeksi arus kas', () {
    test('bulanan: muncul di tiap bulan dalam rentang', () {
      final hasil = proyeksiArusKas(
        tagihan: [tagihanUji(jatuhTempo: DateTime(2026, 9, 25))],
        mulai: DateTime(2026, 9, 1),
      );
      expect(hasil, hasLength(3));
      expect(hasil.map((b) => b.bulan).toList(),
          [DateTime(2026, 9, 1), DateTime(2026, 10, 1), DateTime(2026, 11, 1)]);
      expect(hasil.map((b) => b.totalSen).toList(), [100000, 100000, 100000]);
      expect(totalProyeksiSen(hasil), 300000);
    });

    test('jatuh tempo lampau dimajukan ke jadwal berikutnya', () {
      final hasil = proyeksiArusKas(
        tagihan: [tagihanUji(jatuhTempo: DateTime(2026, 3, 10))],
        mulai: DateTime(2026, 9, 21),
      );
      expect(hasil[0].totalSen, 0, reason: '10 Sep sudah lewat dari 21 Sep');
      expect(hasil[1].totalSen, 100000, reason: 'jadwal berikutnya 10 Okt');
      expect(hasil[2].totalSen, 100000, reason: 'lalu 10 Nov');
    });

    test('sekali: dihitung hanya bila jatuh tempo di dalam rentang', () {
      final dalam = proyeksiArusKas(
        tagihan: [
          tagihanUji(frekuensi: 'sekali', jatuhTempo: DateTime(2026, 10, 5))
        ],
        mulai: DateTime(2026, 9, 21),
      );
      expect(dalam[0].totalSen, 0);
      expect(dalam[1].totalSen, 100000);

      final luar = proyeksiArusKas(
        tagihan: [
          tagihanUji(frekuensi: 'sekali', jatuhTempo: DateTime(2027, 5, 5))
        ],
        mulai: DateTime(2026, 9, 21),
      );
      expect(totalProyeksiSen(luar), 0);
    });

    test('mingguan: beberapa kali dalam satu bulan', () {
      final hasil = proyeksiArusKas(
        tagihan: [tagihanUji(frekuensi: 'mingguan', jatuhTempo: DateTime(2026, 9, 1))],
        mulai: DateTime(2026, 9, 1),
      );
      expect(hasil.first.jumlahTagihan, greaterThanOrEqualTo(4));
      expect(hasil.first.totalSen, hasil.first.jumlahTagihan * 100000);
    });

    test('nonaktif tidak dihitung; langganan pause juga tidak', () {
      final hasil = proyeksiArusKas(
        tagihan: [tagihanUji(aktif: false)],
        langganan: [langgananUji(status: 'pause')],
        mulai: DateTime(2026, 9, 1),
      );
      expect(totalProyeksiSen(hasil), 0);
    });

    test('langganan aktif ikut dihitung, tahunan hanya sekali dalam rentang', () {
      final hasil = proyeksiArusKas(
        tagihan: [tagihanUji()],
        langganan: [
          langgananUji(id: 1, siklus: 'bulanan', nominalSen: 200000),
          langgananUji(id: 2, nama: 'Hosting', siklus: 'tahunan', nominalSen: 1200000,
              mulai: DateTime(2026, 9, 5)),
        ],
        mulai: DateTime(2026, 9, 1),
      );
      expect(hasil[0].jumlahLangganan, 2);
      expect(hasil[0].totalLanggananSen, 1400000);
      expect(hasil[1].jumlahLangganan, 1, reason: 'tahunan jatuh tempo Sep saja');
      expect(hasil[1].totalLanggananSen, 200000);
      expect(hasil.first.totalSen, 100000 + 1400000);
    });

    test('bulanTerberat memilih bulan dengan total tertinggi', () {
      final hasil = proyeksiArusKas(
        tagihan: [
          tagihanUji(id: 1, nama: 'Listrik', jatuhTempo: DateTime(2026, 10, 3)),
          tagihanUji(id: 2, nama: 'Air', frekuensi: 'tahunan',
              jatuhTempo: DateTime(2026, 10, 4), jumlahSen: 500000),
        ],
        mulai: DateTime(2026, 9, 1),
      );
      expect(bulanTerberat(hasil)!.bulan, DateTime(2026, 10, 1));
    });

    testWidgets('layar menampilkan total per bulan & bulan terberat', (t) async {
      await TagihanRepository(db).tambah(TagihanCompanion.insert(
        nama: 'Listrik',
        jatuhTempo: DateTime(2026, 9, 25),
        jumlahSen: const Value(250000),
      ));
      await t.binding.setSurfaceSize(const Size(430, 1100));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: ProyeksiArusKasScreen(acuan: DateTime(2026, 9, 21)),
        ),
      ));
      await t.pumpAndSettle();

      expect(t.widget<Text>(find.byKey(const Key('proyeksi_total'))).data,
          'Rp 7.500');
      expect(find.byKey(const Key('proyeksi_2026-9')), findsOneWidget);
      expect(find.byKey(const Key('proyeksi_2026-11')), findsOneWidget);
      expect(find.textContaining('Bulan paling berat'), findsOneWidget);

      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });
  });
}
