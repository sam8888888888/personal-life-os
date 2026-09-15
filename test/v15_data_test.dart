/// Uji fondasi data V1.5 (skema v3) — FR-68, FR-71, FR-72, FR-76.
///
/// Yang diuji di sini hanya lapisan data (repository + database) — bukan UI.
/// Setiap klaim di laporan harus bisa diulang dari berkas ini.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/model/enums.dart';
import 'package:personal_life_os/data/repository/anggaran_repository.dart';
import 'package:personal_life_os/data/repository/aset_repository.dart';
import 'package:personal_life_os/data/repository/kategori_transaksi_repository.dart';
import 'package:personal_life_os/data/repository/langganan_repository.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/data/repository/periode.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/data/repository/transaksi_repository.dart';

void main() {
  late AppDatabase db;
  late TransaksiRepository trx;
  late AnggaranRepository anggaran;
  late LanggananRepository langganan;
  late AsetRepository kekayaan;
  late KategoriTransaksiRepository kategori;
  late TagihanRepository tagihan;

  /// Waktu uji dikunci: "sekarang" = 15 Sep 2026 → bulan berjalan 2026-09.
  final jamUji = DateTime(2026, 9, 15, 8, 0);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    trx = TransaksiRepository(db);
    anggaran = AnggaranRepository(db, transaksi: trx);
    langganan = LanggananRepository(db);
    kekayaan = AsetRepository(db, jamSekarang: () => jamUji);
    kategori = KategoriTransaksiRepository(db);
    tagihan = TagihanRepository(db);
  });

  tearDown(() async => db.close());

  Future<int> idKategori(String kode) async {
    final k = await (db.select(db.kategoriTransaksi)
          ..where((x) => x.kode.equals(kode)))
        .getSingle();
    return k.id;
  }

  Future<TransaksiData> catat({
    required String id,
    required JenisArus jenis,
    required int sen,
    required DateTime tanggal,
    int? kategoriId,
  }) =>
      trx.simpan(TransaksiCompanion.insert(
        idTransaksi: id,
        jenis: Value(jenis.nilaiDb),
        tanggal: tanggal,
        jumlahSen: sen,
        kategoriId: Value(kategoriId),
      ));

  Future<int> tagihanBaru(String nama) async {
    final t = await tagihan.tambah(TagihanCompanion.insert(
      nama: nama,
      jumlahSen: const Value(5000000),
      jatuhTempo: DateTime(2026, 9, 20),
    ));
    return t.id;
  }

  group('skema v3 & seed kategori transaksi', () {
    test('skema v3: 11 kategori pengeluaran + 12 pemasukan (semua bawaan)',
        () async {
      final semua = await db.select(db.kategoriTransaksi).get();
      expect(semua.length, 23);
      expect(
          semua.where((k) => k.jenis == JenisArus.pengeluaran.nilaiDb).length, 11);
      expect(
          semua.where((k) => k.jenis == JenisArus.pemasukan.nilaiDb).length, 12);
      expect(semua.every((k) => k.bawaanSistem), isTrue);
      expect(semua.map((k) => k.nama), contains('Makan & Minum'));
      expect(semua.map((k) => k.nama), contains('Gaji'));
    });

    test('seed idempoten: dipanggil ulang tidak menggandakan kategori', () async {
      await db.seedKategoriTransaksi();
      await db.seedKategoriTransaksi();
      expect((await db.select(db.kategoriTransaksi).get()).length, 23);
    });

    test('kode kategori unik (indeks SQL) — tidak ada kode kembar', () async {
      final semua = await db.select(db.kategoriTransaksi).get();
      expect(semua.map((k) => k.kode).toSet().length, semua.length);
    });

    test('kategori bawaan tidak bisa dihapus, hanya disembunyikan', () async {
      final id = await idKategori('kel_makan');
      await expectLater(kategori.hapus(id), throwsA(isA<StateError>()));
      await kategori.sembunyikan(id);
      final k = await kategori.ambilSatu(id);
      expect(k?.arsip, isTrue);
      expect(k?.bawaanSistem, isTrue);
    });

    test('kategori pengguna: tambah → sembunyikan → hapus', () async {
      final baru = await kategori.tambah(
          nama: 'Pulsa & Paket Data', jenis: JenisArus.pengeluaran);
      expect(baru.kode.startsWith('usr_'), isTrue);
      expect((await kategori.ambilSemua()).length, 24);
      await kategori.sembunyikan(baru.id);
      expect((await kategori.ambilSemua()).length, 23);
      await kategori.hapus(baru.id);
      expect((await db.select(db.kategoriTransaksi).get()).length, 23);
    });

    test('kategori yang dipakai transaksi tidak bisa dihapus', () async {
      final baru = await kategori.tambah(
          nama: 'Hobi Laut', jenis: JenisArus.pengeluaran);
      await catat(
        id: 'trx_1',
        jenis: JenisArus.pengeluaran,
        sen: 100000,
        tanggal: DateTime(2026, 9, 5),
        kategoriId: baru.id,
      );
      final pakai = await kategori.pemakaian(baru.id);
      expect(pakai.transaksi, 1);
      await expectLater(kategori.hapus(baru.id), throwsA(isA<StateError>()));
    });

    test('nama kategori kosong ditolak', () async {
      await expectLater(
        kategori.tambah(nama: '   ', jenis: JenisArus.pengeluaran),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('FR-71 transaksi & arus kas', () {
    test('idTransaksi = kunci idempotensi (impor ulang tidak menggandakan)',
        () async {
      final a = await catat(
        id: 'tagihan:9:2026-09',
        jenis: JenisArus.pengeluaran,
        sen: 15000000,
        tanggal: DateTime(2026, 9, 3),
      );
      final b = await catat(
        id: 'tagihan:9:2026-09',
        jenis: JenisArus.pengeluaran,
        sen: 17500000,
        tanggal: DateTime(2026, 9, 4),
      );
      expect(b.id, a.id);
      expect(b.jumlahSen, 17500000);
      expect((await db.select(db.transaksi).get()).length, 1);
    });

    test('tolak jumlah negatif dan idTransaksi kosong', () async {
      await expectLater(
        catat(
          id: 'trx_neg',
          jenis: JenisArus.pengeluaran,
          sen: -1,
          tanggal: DateTime(2026, 9, 5),
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        catat(
          id: '   ',
          jenis: JenisArus.pengeluaran,
          sen: 1000,
          tanggal: DateTime(2026, 9, 5),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('ringkasan bulan: masuk − keluar = arus kas bersih', () async {
      final makan = await idKategori('kel_makan');
      await catat(
          id: 't1',
          jenis: JenisArus.pemasukan,
          sen: 500000000,
          tanggal: DateTime(2026, 9, 1));
      await catat(
          id: 't2',
          jenis: JenisArus.pemasukan,
          sen: 100000000,
          tanggal: DateTime(2026, 9, 10));
      await catat(
          id: 't3',
          jenis: JenisArus.pengeluaran,
          sen: 200000000,
          tanggal: DateTime(2026, 9, 5),
          kategoriId: makan);
      await catat(
          id: 't4',
          jenis: JenisArus.pengeluaran,
          sen: 50000000,
          tanggal: DateTime(2026, 9, 6),
          kategoriId: makan);
      // Bulan lain tidak ikut terhitung.
      await catat(
          id: 't5',
          jenis: JenisArus.pengeluaran,
          sen: 990000000,
          tanggal: DateTime(2026, 8, 31));

      final r = await trx.ringkasanBulan(DateTime(2026, 9, 15));
      expect(r.pemasukanSen, 600000000);
      expect(r.pengeluaranSen, 250000000);
      expect(r.bersihSen, 350000000);
    });

    test('total per kategori (bahan FR-72)', () async {
      final makan = await idKategori('kel_makan');
      final transport = await idKategori('kel_transportasi');
      await catat(
          id: 'k1',
          jenis: JenisArus.pengeluaran,
          sen: 400000,
          tanggal: DateTime(2026, 9, 2),
          kategoriId: makan);
      await catat(
          id: 'k2',
          jenis: JenisArus.pengeluaran,
          sen: 200000,
          tanggal: DateTime(2026, 9, 3),
          kategoriId: makan);
      await catat(
          id: 'k3',
          jenis: JenisArus.pengeluaran,
          sen: 500000,
          tanggal: DateTime(2026, 9, 4),
          kategoriId: transport);
      final total = await trx.totalPerKategori(DateTime(2026, 9, 15));
      expect(total.length, 2);
      // Urut menurun: makan (600rb) lebih dulu, lalu transportasi (500rb).
      expect(total.first.kategoriId, makan);
      expect(total.first.totalSen, 600000);
      expect(total.last.kategoriId, transport);
      expect(total.last.totalSen, 500000);
    });

    test('hapus transaksi', () async {
      final t = await catat(
          id: 'hapus_1',
          jenis: JenisArus.pengeluaran,
          sen: 1000,
          tanggal: DateTime(2026, 9, 5));
      expect(await trx.hapus(t.id), 1);
      expect((await db.select(db.transaksi).get()), isEmpty);
    });
  });

  group('FR-72 anggaran bulanan', () {
    test('satu periode + satu kategori = satu baris (upsert)', () async {
      final makan = await idKategori('kel_makan');
      await anggaran.simpan(periode: '2026-09', kategoriId: makan, batasSen: 3000000);
      await anggaran.simpan(periode: '2026-09', kategoriId: makan, batasSen: 3500000);
      final baris = await anggaran.ambilPeriode('2026-09');
      expect(baris.length, 1);
      expect(baris.first.batasSen, 3500000);
    });

    test('periode harus YYYY-MM', () async {
      await expectLater(
        anggaran.simpan(periode: 'September', kategoriId: 1, batasSen: 1000),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('realisasi: anggaran / terpakai / selisih / persen', () async {
      final makan = await idKategori('kel_makan');
      await anggaran.simpan(periode: '2026-09', kategoriId: makan, batasSen: 1000000);
      await catat(
          id: 'a1',
          jenis: JenisArus.pengeluaran,
          sen: 600000,
          tanggal: DateTime(2026, 9, 5),
          kategoriId: makan);
      final r = (await anggaran.realisasi('2026-09')).single;
      expect(r.nama, 'Makan & Minum');
      expect(r.batasSen, 1000000);
      expect(r.terpakaiSen, 600000);
      expect(r.selisihSen, 400000);
      expect(r.persen, 60);
      expect(r.status, StatusAnggaran.aman);
      expect(r.kalimat(), 'Anggaran Makan & Minum terpakai 60% bulan ini.');
    });

    test('peringatan muncul pada 80% (mendekati) dan 100% (lewat)', () async {
      final makan = await idKategori('kel_makan');
      final transport = await idKategori('kel_transportasi');
      await anggaran.simpan(periode: '2026-09', kategoriId: makan, batasSen: 1000000);
      await anggaran.simpan(
          periode: '2026-09', kategoriId: transport, batasSen: 1000000);
      await catat(
          id: 'p1',
          jenis: JenisArus.pengeluaran,
          sen: 800000,
          tanggal: DateTime(2026, 9, 5),
          kategoriId: makan);
      await catat(
          id: 'p2',
          jenis: JenisArus.pengeluaran,
          sen: 1000000,
          tanggal: DateTime(2026, 9, 6),
          kategoriId: transport);

      final r = await anggaran.realisasi('2026-09');
      final a = r.firstWhere((x) => x.kategoriId == makan);
      final b = r.firstWhere((x) => x.kategoriId == transport);
      expect(a.persen, 80);
      expect(a.status, StatusAnggaran.mendekati);
      expect(b.persen, 100);
      expect(b.status, StatusAnggaran.lewat);

      final ingat = await anggaran.peringatan('2026-09');
      expect(ingat.length, 2);
    });

    test('anggaran total (kategoriId 0) memakai seluruh pengeluaran bulan',
        () async {
      final makan = await idKategori('kel_makan');
      final transport = await idKategori('kel_transportasi');
      await anggaran.simpan(
          periode: '2026-09', kategoriId: AnggaranRepository.kategoriTotal, batasSen: 1000000);
      await catat(
          id: 'tot1',
          jenis: JenisArus.pengeluaran,
          sen: 400000,
          tanggal: DateTime(2026, 9, 5),
          kategoriId: makan);
      await catat(
          id: 'tot2',
          jenis: JenisArus.pengeluaran,
          sen: 700000,
          tanggal: DateTime(2026, 9, 6),
          kategoriId: transport);
      final r = (await anggaran.realisasi('2026-09')).single;
      expect(r.nama, 'Total bulan');
      expect(r.terpakaiSen, 1100000);
      expect(r.selisihSen, -100000);
      expect(r.status, StatusAnggaran.lewat);
    });

    test('ambang kustom diurai naik & di luar 1-100 diabaikan', () {
      expect(teksKeAmbang('90,50'), [50, 90]);
      expect(teksKeAmbang('80,abc,100,0'), [80, 100]);
      expect(teksKeAmbang(null), [80, 100]);
    });
  });

  group('FR-68 langganan', () {
    test('pause mematikan pengingat tagihan tertaut, aktifkan menghidupkan lagi',
        () async {
      final tid = await tagihanBaru('Netflix');
      final l = await langganan.tambah(
        nama: 'Netflix',
        nominalSen: 18600000,
        tanggalMulai: DateTime(2026, 1, 1),
        tagihanId: tid,
      );
      expect(l.status, StatusLangganan.aktif.nilaiDb);

      await langganan.pause(l.id);
      var t = await (db.select(db.tagihan)..where((x) => x.id.equals(tid)))
          .getSingle();
      expect(t.statusAktif, isFalse, reason: 'pause harus menghentikan pengingat');

      await langganan.aktifkan(l.id);
      t = await (db.select(db.tagihan)..where((x) => x.id.equals(tid))).getSingle();
      expect(t.statusAktif, isTrue);
      final lagi = await langganan.ambilSatu(l.id);
      expect(lagi?.status, StatusLangganan.aktif.nilaiDb);
      expect(lagi?.pauseSejak, isNull);
    });

    test('hentikan: status berhenti + pengingat mati, riwayat tidak dihapus',
        () async {
      final tid = await tagihanBaru('Spotify');
      final l = await langganan.tambah(
        nama: 'Spotify',
        nominalSen: 5490000,
        tanggalMulai: DateTime(2026, 2, 1),
        tagihanId: tid,
      );
      await langganan.hentikan(l.id);
      expect((await langganan.ambilAktif()), isEmpty);
      final t = await (db.select(db.tagihan)..where((x) => x.id.equals(tid)))
          .getSingle();
      expect(t.statusAktif, isFalse);
      expect((await db.select(db.tagihan).get()).length, 1);
    });

    test('satu tagihan hanya boleh dipakai satu langganan', () async {
      final tid = await tagihanBaru('Bundling');
      await langganan.tambah(
        nama: 'A',
        nominalSen: 1000,
        tanggalMulai: DateTime(2026, 1, 1),
        tagihanId: tid,
      );
      await expectLater(
        langganan.tambah(
          nama: 'B',
          nominalSen: 1000,
          tanggalMulai: DateTime(2026, 1, 1),
          tagihanId: tid,
        ),
        throwsA(anything),
      );
    });

    test('lepas tautan menghidupkan kembali tagihan (pengingat tidak mati diam)',
        () async {
      final tid = await tagihanBaru('Streaming');
      final l = await langganan.tambah(
        nama: 'Streaming',
        nominalSen: 1000,
        tanggalMulai: DateTime(2026, 1, 1),
        tagihanId: tid,
      );
      await langganan.pause(l.id);
      await langganan.lepasTautan(l.id);
      final t = await (db.select(db.tagihan)..where((x) => x.id.equals(tid)))
          .getSingle();
      expect(t.statusAktif, isTrue);
      expect((await langganan.ambilSatu(l.id))?.tagihanId, isNull);
    });

    test('total biaya bulanan: siklus tahunan dinormalkan ke bulan', () async {
      await langganan.tambah(
        nama: 'Tahunan',
        nominalSen: 1200000,
        tanggalMulai: DateTime(2026, 1, 1),
        siklus: Frekuensi.tahunan,
      );
      await langganan.tambah(
        nama: 'Bulanan',
        nominalSen: 100000,
        tanggalMulai: DateTime(2026, 1, 1),
      );
      expect(await langganan.totalBulananSen(), 200000);
    });

    test('idLangganan unik & status tidak dikenal jadi aktif', () {
      final a = LanggananRepository.idBaru();
      final b = LanggananRepository.idBaru();
      expect(a == b, isFalse);
      expect(a.startsWith('lgn_'), isTrue);
      expect(StatusLangganan.dariDb('entah').name, 'aktif');
    });
  });

  group('FR-76 kekayaan bersih', () {
    test('nilai bersih = aset − kewajiban (dari nilai awal)', () async {
      await kekayaan.tambahAset(nama: 'Tabungan BCA', nilaiAwalSen: 500000000);
      await kekayaan.tambahAset(nama: 'Emas', nilaiAwalSen: 100000000);
      await kekayaan.tambahKewajiban(nama: 'KPR', saldoAwalSen: 200000000);
      final n = await kekayaan.nilaiBersih('2026-09');
      expect(n.totalAsetSen, 600000000);
      expect(n.totalKewajibanSen, 200000000);
      expect(n.bersihSen, 400000000);
    });

    test('memakai nilai bulan terakhir yang tersedia (≤ bulan diminta)',
        () async {
      final a = await kekayaan.tambahAset(nama: 'Reksa dana', nilaiAwalSen: 1000000);
      await kekayaan.simpanNilaiAset(
          asetId: a.id, bulan: '2026-07', nilaiSen: 1200000, paksa: true);
      await kekayaan.simpanNilaiAset(
          asetId: a.id, bulan: '2026-08', nilaiSen: 1500000, paksa: true);
      expect((await kekayaan.nilaiBersih('2026-08')).totalAsetSen, 1500000);
      expect((await kekayaan.nilaiBersih('2026-09')).totalAsetSen, 1500000);
      expect((await kekayaan.nilaiBersih('2026-06')).totalAsetSen, 1000000);
    });

    test('bulan lampau terkunci; perubahan butuh paksa + alasan', () async {
      final a = await kekayaan.tambahAset(nama: 'Kas', nilaiAwalSen: 0);
      await kekayaan.simpanNilaiAset(
          asetId: a.id, bulan: '2026-08', nilaiSen: 100000);
      final baris = await (db.select(db.nilaiAsetBulanan)
            ..where((n) => n.asetId.equals(a.id)))
          .getSingle();
      expect(baris.terkunci, isTrue);
      expect(baris.dikunciPada, isNotNull);

      await expectLater(
        kekayaan.simpanNilaiAset(asetId: a.id, bulan: '2026-08', nilaiSen: 200000),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        kekayaan.simpanNilaiAset(
            asetId: a.id, bulan: '2026-08', nilaiSen: 200000, paksa: true),
        throwsA(isA<ArgumentError>()),
      );
      await kekayaan.simpanNilaiAset(
        asetId: a.id,
        bulan: '2026-08',
        nilaiSen: 200000,
        paksa: true,
        alasan: 'salah ketik nominal',
      );
      final baru = await (db.select(db.nilaiAsetBulanan)
            ..where((n) => n.asetId.equals(a.id)))
          .getSingle();
      expect(baru.nilaiSen, 200000);
      expect(baru.terkunci, isTrue);
      expect(baru.dibukaKunciPada, isNotNull);
      expect(baru.alasanBukaKunci, 'salah ketik nominal');
      // Bulan berjalan tidak terkunci.
      await kekayaan.simpanNilaiAset(
          asetId: a.id, bulan: '2026-09', nilaiSen: 300000);
      await kekayaan.simpanNilaiAset(
          asetId: a.id, bulan: '2026-09', nilaiSen: 350000);
      expect((await kekayaan.nilaiBersih('2026-09')).totalAsetSen, 350000);
    });

    test('tren bulanan urut & ikut menghitung kewajiban', () async {
      final a = await kekayaan.tambahAset(nama: 'Bank', nilaiAwalSen: 1000000);
      final k = await kekayaan.tambahKewajiban(nama: 'Kartu kredit', saldoAwalSen: 400000);
      await kekayaan.simpanNilaiAset(
          asetId: a.id, bulan: '2026-08', nilaiSen: 2000000, paksa: true);
      await kekayaan.simpanNilaiAset(
          asetId: a.id, bulan: '2026-09', nilaiSen: 2500000);
      await kekayaan.simpanNilaiKewajiban(
          kewajibanId: k.id, bulan: '2026-09', nilaiSen: 300000);

      final t = await kekayaan.tren(dari: '2026-08', sampai: '2026-09');
      expect(t.length, 2);
      expect(t.first.bulan, '2026-08');
      expect(t.first.totalAsetSen, 2000000);
      expect(t.first.totalKewajibanSen, 400000);
      expect(t.first.bersihSen, 1600000);
      expect(t.last.bulan, '2026-09');
      expect(t.last.bersihSen, 2500000 - 300000);
    });

    test('aset diarsipkan tidak dihitung, kecuali diminta', () async {
      await kekayaan.tambahAset(nama: 'Motor', nilaiAwalSen: 15000000);
      final m = await kekayaan.ambilAset();
      await kekayaan.arsipkanAset(m.single.id);
      expect((await kekayaan.nilaiBersih('2026-09')).totalAsetSen, 0);
      expect(
        (await kekayaan.nilaiBersih('2026-09', sertakanArsip: true)).totalAsetSen,
        15000000,
      );
    });

    test('hapus aset menghapus riwayat nilainya (satu transaksi)', () async {
      final a = await kekayaan.tambahAset(nama: 'Deposito', nilaiAwalSen: 1000000);
      await kekayaan.simpanNilaiAset(
          asetId: a.id, bulan: '2026-09', nilaiSen: 1100000);
      await kekayaan.hapusAset(a.id);
      expect(await db.select(db.aset).get(), isEmpty);
      expect(await db.select(db.nilaiAsetBulanan).get(), isEmpty);
    });

    test('validasi: nama kosong, nilai negatif, bulan salah', () async {
      await expectLater(
        kekayaan.tambahAset(nama: '  '),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        kekayaan.tambahAset(nama: 'Kas minus', nilaiAwalSen: -1),
        throwsA(isA<ArgumentError>()),
      );
      final a = await kekayaan.tambahAset(nama: 'Kas kecil');
      await expectLater(
        kekayaan.simpanNilaiAset(asetId: a.id, bulan: '2026-9', nilaiSen: 1000),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        kekayaan.tambahKewajiban(nama: 'Cicilan', tanggalJatuhTempoHari: 40),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('integrasi antar tabel (skema v3)', () {
    test('hapus tagihan: langganan berhenti, transaksi tetap ada', () async {
      final tid = await tagihanBaru('Internet');
      final l = await langganan.tambah(
        nama: 'Internet',
        nominalSen: 3000000,
        tanggalMulai: DateTime(2026, 1, 1),
        tagihanId: tid,
      );
      await catat(
        id: 'tagihan:$tid:2026-09',
        jenis: JenisArus.pengeluaran,
        sen: 3000000,
        tanggal: DateTime(2026, 9, 20),
      );
      await (db.update(db.transaksi)
            ..where((t) => t.idTransaksi.equals('tagihan:$tid:2026-09')))
          .write(TransaksiCompanion(tagihanId: Value(tid)));

      await tagihan.hapus(tid);

      final l2 = await langganan.ambilSatu(l.id);
      expect(l2?.status, StatusLangganan.berhenti.nilaiDb);
      expect(l2?.tagihanId, isNull);
      final t = await db.select(db.transaksi).get();
      expect(t.length, 1, reason: 'riwayat kas tidak boleh hilang');
      expect(t.single.tagihanId, isNull);
      expect(t.single.jumlahSen, 3000000);
    });

    test('hapus semua data: tabel kas kosong, kategori bawaan tetap', () async {
      final pengaturan = PengaturanRepository(db);
      final makan = await idKategori('kel_makan');
      await catat(
          id: 'h1',
          jenis: JenisArus.pengeluaran,
          sen: 1000,
          tanggal: DateTime(2026, 9, 5),
          kategoriId: makan);
      await anggaran.simpan(periode: '2026-09', kategoriId: makan, batasSen: 1000);
      await langganan.tambah(
          nama: 'L', nominalSen: 1000, tanggalMulai: DateTime(2026, 1, 1));
      final a = await kekayaan.tambahAset(nama: 'Kas', nilaiAwalSen: 1000);
      await kekayaan.simpanNilaiAset(
          asetId: a.id, bulan: '2026-09', nilaiSen: 1200);
      await kekayaan.tambahKewajiban(nama: 'K', saldoAwalSen: 100);
      final katUser = await kategori.tambah(
          nama: 'Kategori Sendiri', jenis: JenisArus.pengeluaran);

      await pengaturan.hapusSemuaData();

      expect(await db.select(db.transaksi).get(), isEmpty);
      expect(await db.select(db.anggaranBulanan).get(), isEmpty);
      expect(await db.select(db.langganan).get(), isEmpty);
      expect(await db.select(db.aset).get(), isEmpty);
      expect(await db.select(db.kewajiban).get(), isEmpty);
      expect(await db.select(db.nilaiAsetBulanan).get(), isEmpty);
      expect(await db.select(db.nilaiKewajibanBulanan).get(), isEmpty);
      final sisaKategori = await db.select(db.kategoriTransaksi).get();
      expect(sisaKategori.length, 23);
      expect(sisaKategori.any((k) => k.id == katUser.id), isFalse);
    });

    test('kunci periode: YYYY-MM, rentang bulan, bulan berikutnya', () {
      expect(kunciBulan(DateTime(2026, 9, 15)), '2026-09');
      expect(kunciBulanSah('2026-09'), isTrue);
      expect(kunciBulanSah('2026-13'), isFalse);
      expect(kunciBulanSah('September'), isFalse);
      expect(kunciBulanBerikutnya('2026-12'), '2027-01');
      final r = rentangBulan(DateTime(2026, 2, 10));
      expect(r.awal, DateTime(2026, 2, 1));
      expect(r.akhir, DateTime(2026, 2, 28));
    });
  });
}
