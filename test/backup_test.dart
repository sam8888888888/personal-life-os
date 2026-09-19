/// Uji FR-24 — ekspor cadangan JSON & impor restore (pindah HP).
///
/// PRD: "Ekspor cadangan JSON + impor restore (termasuk migrasi antar HP)."
///
/// Dua lapis:
///  1. layanan inti (`LayananCadangan`) pada database IN-MEMORY;
///  2. layar "Cadangan & Pemulihan" pada ukuran 420x900 (pekerjaan berkas
///     dijalankan lewat `runAsync`, lihat [ketukNyata]).
///
/// Setiap angka di laporan bisa diulang dari berkas ini.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/backup/ekspor_impor.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/model/enums.dart';
import 'package:personal_life_os/data/repository/anggaran_repository.dart';
import 'package:personal_life_os/data/repository/aset_repository.dart';
import 'package:personal_life_os/data/repository/kategori_transaksi_repository.dart';
import 'package:personal_life_os/data/repository/langganan_repository.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/data/repository/transaksi_repository.dart';
import 'package:personal_life_os/features/pengaturan/backup_screen.dart';

late AppDatabase db;
late LayananCadangan cadangan;
late Directory folderUji;

/// Waktu uji dikunci: 15 September 2026, 08.00.
final jamUji = DateTime(2026, 9, 15, 8, 0);

/// Kata yang dilarang tampil ke pengguna (PRD §III-11).
const List<String> kataTerlarang = <String>[
  'gagal',
  'boros',
  'disiplin',
  'kamu',
  'skor',
  'menakut',
];

/// Pesan berkas yang ditolak, dikumpulkan untuk uji bahasa.
final List<String> pesanDitolak = <String>[];

/// Tabel skema v3 (fondasi kas & kekayaan).
const List<String> tabelV3 = <String>[
  'kategori_transaksi',
  'transaksi',
  'anggaran_bulanan',
  'langganan',
  'aset',
  'kewajiban',
  'nilai_aset_bulanan',
  'nilai_kewajiban_bulanan',
];

/// Isi tabel inti (13 tabel skema v3) dengan data nyata (sebagian lewat
/// repositori asli). Tabel skema v4 ikut ter-ekspor walau kosong.
Future<void> isiData() async {
  final tagihan = TagihanRepository(db);
  final t = await tagihan.tambah(TagihanCompanion.insert(
    nama: 'Listrik PLN',
    jumlahSen: const Value(18600000),
    jatuhTempo: DateTime(2026, 9, 20),
    catatan: const Value('Rumah Bandung'),
    prioritas: const Value('penting'),
  ));
  await db.into(db.riwayatPembayaran).insert(
        RiwayatPembayaranCompanion.insert(
          tagihanId: t.id,
          periodeJatuhTempo: DateTime(2026, 8, 20),
          jumlahSen: 17000000,
          tanggalBayar: DateTime(2026, 8, 18),
          telatHari: const Value(0),
        ),
      );

  final pengaturan = PengaturanRepository(db);
  await pengaturan.simpanPemasukan(DateTime(2026, 9), 1200000000);
  await pengaturan.simpan('briefing_pagi', 'true');

  final kategori = KategoriTransaksiRepository(db);
  await kategori.tambah(nama: 'Pulsa & Paket Data', jenis: JenisArus.pengeluaran);
  final KategoriTransaksiData makan = await (db.select(db.kategoriTransaksi)
        ..where((k) => k.kode.equals('kel_makan')))
      .getSingle();

  final trx = TransaksiRepository(db);
  await trx.simpan(TransaksiCompanion.insert(
    idTransaksi: 'trx_uji_1',
    tanggal: DateTime(2026, 9, 14),
    jumlahSen: 4500000,
    kategoriId: Value(makan.id),
    catatan: const Value('Makan siang'),
  ));
  await AnggaranRepository(db, transaksi: trx).simpan(
    periode: '2026-09',
    kategoriId: makan.id,
    batasSen: 150000000,
  );
  await LanggananRepository(db).tambah(
    nama: 'Netflix',
    nominalSen: 18600000,
    tanggalMulai: DateTime(2026, 1, 1),
    tagihanId: t.id,
  );

  final kekayaan = AsetRepository(db, jamSekarang: () => jamUji);
  final aset = await kekayaan.tambahAset(
    nama: 'Tabungan BCA',
    nilaiAwalSen: 500000000,
    institusi: 'BCA',
  );
  await kekayaan.simpanNilaiAset(
      asetId: aset.id, bulan: '2026-09', nilaiSen: 510000000);
  final kewajiban = await kekayaan.tambahKewajiban(
    nama: 'KPR rumah',
    pokokSen: 400000000,
    saldoAwalSen: 250000000,
    tanggalJatuhTempoHari: 5,
  );
  await kekayaan.simpanNilaiKewajiban(
      kewajibanId: kewajiban.id, bulan: '2026-09', nilaiSen: 248000000);
}

/// Berkas sementara berisi teks apa pun (untuk uji berkas ditolak).
File berkasUji(String nama, String isi) {
  final f = File('${folderUji.path}${Platform.pathSeparator}$nama');
  f.writeAsStringSync(isi);
  return f;
}

/// Buang seluruh baris semua tabel (meniru HP baru / data kosong).
Future<void> kosongkanSemua() async {
  for (final t in db.allTables) {
    await db.customStatement('DELETE FROM "${t.actualTableName}"');
  }
}

// ---------------------------------------------------------------------------
// Pembantu uji widget
// ---------------------------------------------------------------------------

Future<void> tampilkan(WidgetTester t, Widget layar) async {
  // WAJIB di-await; ukuran layar jenis HP yang dipakai proyek ini.
  await t.binding.setSurfaceSize(const Size(420, 900));
  await t.pumpWidget(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      theme: AppTema.terang(),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: layar,
    ),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

/// Pembaruan Drift butuh pompa berulang (12x100ms) — jangan menunggu stream.
Future<void> majukan(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Ketuk dan selesaikan pekerjaan berkas NYATA.
///
/// Catatan penting (terbukti dari uji): di Windows, `readAsString`/
/// `writeAsString` TIDAK pernah selesai di dalam jam palsu pengujian widget —
/// berkasnya terbentuk tapi isinya kosong. Karena itu ketukan yang memicu
/// pekerjaan berkas dijalankan lewat `tester.runAsync` (cara resmi
/// flutter_test), lalu layar digambar ulang dengan `pump`.
Future<void> ketukNyata(WidgetTester t, Finder f, {int milidetik = 700}) async {
  await t.runAsync(() async {
    await t.tap(f);
    await Future<void>.delayed(Duration(milliseconds: milidetik));
  });
  await majukan(t);
}

/// Gulirkan daftar sampai [f] terlihat (naik dulu, lalu turun).
///
/// ListView bisa sudah membangun widget di luar layar (`cacheExtent`), jadi
/// setelah ditemukan widget tetap digeser masuk lewat `ensureVisible`.
Future<void> gulirKe(WidgetTester t, Finder f, {int langkah = 8}) async {
  for (var i = 0; i < langkah && f.evaluate().isEmpty; i++) {
    await t.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await t.pump(const Duration(milliseconds: 120));
  }
  for (var i = 0; i < langkah * 2 && f.evaluate().isEmpty; i++) {
    await t.drag(find.byType(Scrollable).first, const Offset(0, 200));
    await t.pump(const Duration(milliseconds: 120));
  }
  if (f.evaluate().isNotEmpty) {
    await t.ensureVisible(f);
    await t.pump(const Duration(milliseconds: 120));
  }
}

Future<void> tutup(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(milliseconds: 50));
  await t.binding.setSurfaceSize(null);
}

/// Semua teks yang benar-benar tampil di layar.
Set<String> teksTampil(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data ?? '')
    .where((s) => s.isNotEmpty)
    .toSet();

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    folderUji = Directory.systemTemp.createTempSync('plo_cadangan_uji_');
    cadangan = LayananCadangan(
      db: db,
      penentuFolder: () async => folderUji,
      jam: () => jamUji,
    );
    pesanDitolak.clear();
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() async {
    await db.close();
    if (folderUji.existsSync()) folderUji.deleteSync(recursive: true);
  });

  // ------------------------------------------------------------------
  // 1. EKSPOR
  // ------------------------------------------------------------------

  group('FR-24 ekspor cadangan', () {
    test('menulis satu berkas JSON lengkap dengan penanda format & skema',
        () async {
      await isiData();
      final hasil = await cadangan.ekspor();

      expect(hasil.namaBerkas, 'plo_backup_20260915_0800.json');
      expect(File(hasil.path).existsSync(), isTrue);
      expect(File(hasil.path).lengthSync(), greaterThan(0));
      expect(hasil.totalBaris, 51,
          reason: '45 baris (13 tabel inti) + 6 template perawatan (skema v4)');

      final Map<String, dynamic> isi =
          jsonDecode(File(hasil.path).readAsStringSync()) as Map<String, dynamic>;
      expect(isi['format'], 'plo-backup');
      expect(isi['versiSkema'], 4);
      expect(isi['versiAplikasi'], versiAplikasiCadangan);
      expect(DateTime.tryParse(isi['dibuatPada'] as String), jamUji);

      final Map<String, dynamic> tabel = isi['tabel'] as Map<String, dynamic>;
      expect(tabel.length, db.allTables.length,
          reason: 'SEMUA tabel Drift ikut ter-ekspor (v3 maupun v4)');
      expect(tabel.length, 38,
          reason: '13 tabel v3 + 23 tabel v4 + 2 tabel v5 (visi, area_hidup) '
              '= 38');
      expect(tabel.keys, contains('tagihan'));
      expect(tabel.keys, contains('pengaturan'));
      for (final t in tabelV3) {
        expect(tabel.keys, contains(t), reason: 'tabel v3 $t ikut ter-ekspor');
      }

      // Nilai DateTime ditulis sebagai teks ISO 8601, bukan angka.
      final barisTagihan =
          (tabel['tagihan'] as List<dynamic>).first as Map<String, dynamic>;
      expect(barisTagihan['jatuh_tempo'], isA<String>());
      expect(DateTime.parse(barisTagihan['jatuh_tempo'] as String),
          DateTime(2026, 9, 20));
      expect(DateTime.parse(barisTagihan['dibuat_pada'] as String), isA<DateTime>());
      expect(barisTagihan['nama'], 'Listrik PLN');
      expect(barisTagihan['jumlah_sen'], 18600000);
      expect(barisTagihan['lunas'], false, reason: 'bool dibaca sebagai bool');
      expect(barisTagihan['pengingat_lead_hari'], '7,3,1');
    });

    test('jumlah baris ekspor = jumlah baris nyata tiap tabel', () async {
      await isiData();
      final sebelum = await cadangan.jumlahBarisSemuaTabel();
      final hasil = await cadangan.ekspor();

      expect(hasil.jumlahBaris, sebelum);
      expect(hasil.jumlahBaris['tagihan'], 1);
      expect(hasil.jumlahBaris['riwayat_pembayaran'], 1);
      expect(hasil.jumlahBaris['pemasukan_bulanan'], 1);
      expect(hasil.jumlahBaris['pengaturan'], 1);
      expect(hasil.jumlahBaris['kategori_transaksi'], 24,
          reason: '23 kategori bawaan + 1 kategori buatan pengguna');
      expect(hasil.jumlahBaris['kategori'], 10);
      expect(hasil.totalBaris,
          sebelum.values.fold<int>(0, (a, b) => a + b));
    });

    test('minimal 3 tabel skema v3 berisi setelah impor', () async {
      await isiData();
      final hasil = await cadangan.ekspor();
      final v3Berisi = tabelV3
          .where((t) => (hasil.jumlahBaris[t] ?? 0) > 0)
          .toList();
      expect(v3Berisi.length, greaterThanOrEqualTo(3),
          reason: 'terbukti berisi: $v3Berisi');
      expect(v3Berisi.length, 8, reason: 'semua tabel v3 terisi di uji ini');

      await kosongkanSemua();
      final impor = await cadangan.impor(hasil.path, sudahDikonfirmasi: true);
      expect(impor.berhasil, isTrue, reason: impor.pesan);

      final setelah = await cadangan.jumlahBarisSemuaTabel();
      for (final t in tabelV3) {
        expect(setelah[t], greaterThan(0), reason: 'tabel v3 $t kosong lagi');
      }
    });
  });

  // ------------------------------------------------------------------
  // 2. IMPOR PENUH (ekspor -> kosongkan -> impor)
  // ------------------------------------------------------------------

  group('FR-24 impor restore', () {
    test('ekspor -> kosongkan -> impor: jumlah baris sama & nilai kunci sama',
        () async {
      await isiData();
      final TagihanData lama = await db.select(db.tagihan).getSingle();
      final sebelum = await cadangan.jumlahBarisSemuaTabel();
      final hasil = await cadangan.ekspor();

      await kosongkanSemua();
      final saatKosong = await cadangan.jumlahBarisSemuaTabel();
      expect(saatKosong.values.every((v) => v == 0), isTrue);

      final impor = await cadangan.impor(hasil.path, sudahDikonfirmasi: true);
      expect(impor.berhasil, isTrue, reason: impor.pesan);
      expect(impor.tabelTidakCocok, isEmpty);
      expect(impor.hitunganCocok, isTrue);
      expect(impor.pesan, contains('jumlah barisnya sudah diperiksa ulang'));

      // (a) jumlah baris per tabel persis sama
      final sesudah = await cadangan.jumlahBarisSemuaTabel();
      expect(sesudah, sebelum);
      expect(impor.jumlahBarisTerbaca, sebelum);

      // (b) nilai kunci sama — tagihan (nama + nominal + tanggal + teks)
      final tagihan = await db.select(db.tagihan).getSingle();
      expect(tagihan.id, lama.id);
      expect(tagihan.nama, 'Listrik PLN');
      expect(tagihan.jumlahSen, 18600000);
      expect(tagihan.jatuhTempo, DateTime(2026, 9, 20));
      expect(tagihan.catatan, 'Rumah Bandung');
      expect(tagihan.prioritas, 'penting');
      expect(tagihan.dibuatPada, lama.dibuatPada,
          reason: 'tanggal tersimpan kembali dengan nilai yang sama');

      // riwayat pembayaran
      final riwayat = await db.select(db.riwayatPembayaran).getSingle();
      expect(riwayat.tagihanId, tagihan.id);
      expect(riwayat.jumlahSen, 17000000);
      expect(riwayat.tanggalBayar, DateTime(2026, 8, 18));

      // transaksi + anggaran
      final trx = await db.select(db.transaksi).getSingle();
      expect(trx.idTransaksi, 'trx_uji_1');
      expect(trx.jumlahSen, 4500000);
      expect(trx.jenis, 'pengeluaran');
      expect(trx.tanggal, DateTime(2026, 9, 14));
      final anggaran = await db.select(db.anggaranBulanan).getSingle();
      expect(anggaran.periode, '2026-09');
      expect(anggaran.batasSen, 150000000);
      expect(anggaran.ambangPeringatan, '80,100');

      // langganan (tautan ke tagihan tetap utuh)
      final langganan = await db.select(db.langganan).getSingle();
      expect(langganan.nama, 'Netflix');
      expect(langganan.nominalSen, 18600000);
      expect(langganan.tagihanId, tagihan.id);
      expect(langganan.siklus, 'bulanan');

      // aset & kewajiban + riwayat nilainya
      final aset = await db.select(db.aset).getSingle();
      expect(aset.nama, 'Tabungan BCA');
      expect(aset.institusi, 'BCA');
      expect(aset.nilaiAwalSen, 500000000);
      final nilaiAset = await db.select(db.nilaiAsetBulanan).getSingle();
      expect(nilaiAset.asetId, aset.id);
      expect(nilaiAset.bulan, '2026-09');
      expect(nilaiAset.nilaiSen, 510000000);
      final kewajiban = await db.select(db.kewajiban).getSingle();
      expect(kewajiban.nama, 'KPR rumah');
      expect(kewajiban.saldoAwalSen, 250000000);
      final nilaiKewajiban = await db.select(db.nilaiKewajibanBulanan).getSingle();
      expect(nilaiKewajiban.kewajibanId, kewajiban.id);
      expect(nilaiKewajiban.nilaiSen, 248000000);

      // pengaturan & pemasukan
      final pengaturan = await (db.select(db.pengaturan)
            ..where((p) => p.kunci.equals('briefing_pagi')))
          .getSingle();
      expect(pengaturan.nilai, 'true');
      final pemasukan = await db.select(db.pemasukanBulanan).getSingle();
      expect(pemasukan.bulan, '2026-09');
      expect(pemasukan.jumlahSen, 1200000000);

      // kategori (bawaan & buatan pengguna)
      expect((await db.select(db.kategoriTransaksi).get()).length, 24);
      expect((await db.select(db.kategori).get()).length, 10);
    });

    test('impor tanpa konfirmasi tidak menyentuh data', () async {
      await isiData();
      final hasil = await cadangan.ekspor();
      final sebelum = await cadangan.jumlahBarisSemuaTabel();
      await kosongkanSemua();

      final impor = await cadangan.impor(hasil.path);
      expect(impor.berhasil, isFalse);
      expect(impor.pesan, contains('belum dikonfirmasi'));
      final sesudah = await cadangan.jumlahBarisSemuaTabel();
      expect(sesudah.values.every((v) => v == 0), isTrue,
          reason: 'tanpa konfirmasi tidak ada yang ditulis');
      expect(sebelum.isNotEmpty, isTrue);
    });

    test('impor dua kali berturut-turut tetap sama (tidak menggandakan)',
        () async {
      await isiData();
      final sebelum = await cadangan.jumlahBarisSemuaTabel();
      final hasil = await cadangan.ekspor();

      await cadangan.impor(hasil.path, sudahDikonfirmasi: true);
      final sekali = await cadangan.jumlahBarisSemuaTabel();
      await cadangan.impor(hasil.path, sudahDikonfirmasi: true);
      final duaKali = await cadangan.jumlahBarisSemuaTabel();

      expect(sekali, sebelum);
      expect(duaKali, sebelum);
    });
  });

  // ------------------------------------------------------------------
  // 3. PRATINJAU
  // ------------------------------------------------------------------

  group('FR-24 pratinjau', () {
    test('pratinjau menghitung jumlah baris dengan benar', () async {
      await isiData();
      final nyata = await cadangan.jumlahBarisSemuaTabel();
      final hasil = await cadangan.ekspor();

      final lihat = await cadangan.pratinjau(hasil.path);
      expect(lihat.namaBerkas, hasil.namaBerkas);
      expect(lihat.versiSkema, 4);
      expect(lihat.versiAplikasi, versiAplikasiCadangan);
      expect(lihat.dibuatPada, jamUji);
      expect(lihat.diubahBerkasPada, isA<DateTime>());
      expect(lihat.jumlahBaris, nyata);
      expect(lihat.jumlahBaris['kategori_transaksi'], 24);
      expect(lihat.totalBaris, nyata.values.fold<int>(0, (a, b) => a + b));
      expect(lihat.catatanMigrasi, isEmpty);
      expect(lihat.tabelTanpaCadangan, isEmpty);
      expect(lihat.tabelTidakDikenal, isEmpty);
      expect(lihat.adaCatatan, isFalse);
    });

    test('berkas skema v1 tetap diterima + catatan migrasi', () async {
      final isi = jsonEncode(<String, Object?>{
        'format': 'plo-backup',
        'versiSkema': 1,
        'versiAplikasi': '0.1.0',
        'dibuatPada': '2026-01-02T03:04:05.000',
        'tabel': <String, Object?>{
          'tagihan': <Map<String, Object?>>[
            <String, Object?>{
              'id': 1,
              'jenis': 'tagihan',
              'nama': 'PDAM',
              'jumlah_sen': 9500000,
              'jatuh_tempo': '2026-02-10T00:00:00.000',
            },
          ],
        },
      });
      final f = berkasUji('plo_backup_20260102_0304.json', isi);

      final lihat = await cadangan.pratinjau(f.path);
      expect(lihat.versiSkema, 1);
      expect(lihat.catatanMigrasi, hasLength(1));
      expect(lihat.catatanMigrasi.first, contains('skema versi 1'));
      expect(lihat.tabelTanpaCadangan, contains('transaksi'));
      expect(lihat.totalBaris, 1);

      // Impor berkas lama: kolom yang tidak ada memakai nilai bawaan.
      final impor = await cadangan.impor(f.path, sudahDikonfirmasi: true);
      expect(impor.berhasil, isTrue, reason: impor.pesan);
      final tagihan = await db.select(db.tagihan).getSingle();
      expect(tagihan.nama, 'PDAM');
      expect(tagihan.jumlahSen, 9500000);
      expect(tagihan.jatuhTempo, DateTime(2026, 2, 10));
      expect(tagihan.pengingatLeadHari, '7,3,1', reason: 'nilai bawaan kolom');
      expect(tagihan.lunas, isFalse);
      expect(impor.tabelTidakCocok, isEmpty);
      // Tabel yang tidak ada di berkas menjadi kosong (dinyatakan di pratinjau).
      expect((await db.select(db.transaksi).get()), isEmpty);
    });
  });

  // ------------------------------------------------------------------
  // 4. BERKAS DITOLAK — data tidak boleh berubah
  // ------------------------------------------------------------------

  group('FR-24 berkas bermasalah ditolak tanpa mengubah data', () {
    Future<void> tolakBerkas(String nama, String isi, List<String> harusMemuat,
        {required String label}) async {
      await isiData();
      final sebelum = await cadangan.jumlahBarisSemuaTabel();
      final f = berkasUji(nama, isi);

      // Pratinjau menolak lebih dulu, dengan pesan yang jelas.
      try {
        await cadangan.pratinjau(f.path);
        fail('pratinjau seharusnya menolak berkas: $label');
      } on GalatCadangan catch (e) {
        pesanDitolak.add(e.pesan);
        for (final s in harusMemuat) {
          expect(e.pesan, contains(s), reason: '$label: ${e.pesan}');
        }
      }

      final impor = await cadangan.impor(f.path, sudahDikonfirmasi: true);
      expect(impor.berhasil, isFalse, reason: label);
      pesanDitolak.add(impor.pesan);
      for (final s in harusMemuat) {
        expect(impor.pesan, contains(s), reason: '$label: ${impor.pesan}');
      }
      expect(impor.jumlahBaris, isEmpty);
      expect(impor.jumlahBarisTerbaca, isEmpty);
      expect(impor.pathCadanganPengaman, isNull,
          reason: 'berkas ditolak: tidak perlu cadangan pengaman');

      // Inti: data lama tidak berubah sama sekali.
      expect(await cadangan.jumlahBarisSemuaTabel(), sebelum);
      final tagihan = await db.select(db.tagihan).getSingle();
      expect(tagihan.nama, 'Listrik PLN');
      expect(tagihan.jumlahSen, 18600000);
    }

    test('berkas kosong', () async {
      await tolakBerkas('plo_backup_kosong.json', '',
          <String>['kosong', 'tidak diubah'],
          label: 'berkas kosong');
    });

    test('bukan JSON sama sekali', () async {
      await tolakBerkas('plo_backup_teks.json', 'ini catatan biasa, bukan JSON',
          <String>['bukan JSON yang sah', 'tidak diubah'],
          label: 'berkas teks');
    });

    test('JSON rusak (terpotong)', () async {
      await tolakBerkas('plo_backup_rusak.json',
          '{"format":"plo-backup","versiSkema":3,"tabel":{"tagihan":[',
          <String>['bukan JSON yang sah', 'tidak diubah'],
          label: 'JSON terpotong');
    });

    test('JSON sah tapi bukan berkas cadangan (format salah)', () async {
      await tolakBerkas('plo_backup_format.json',
          jsonEncode(<String, Object?>{'format': 'lain', 'versiSkema': 3, 'tabel': <String, Object?>{}}),
          <String>['bukan cadangan Personal Life OS', 'tidak diubah'],
          label: 'format salah');
    });

    test('versi skema 5 (lebih baru dari aplikasi)', () async {
      await tolakBerkas('plo_backup_v5.json',
          jsonEncode(<String, Object?>{
            'format': 'plo-backup',
            'versiSkema': 5,
            'versiAplikasi': '9.9.9',
            'tabel': <String, Object?>{},
          }),
          <String>['versi 5', 'Perbarui aplikasi', 'tidak diubah'],
          label: 'versiSkema 5');
    });

    test('versi skema hilang', () async {
      await tolakBerkas('plo_backup_tanpaversi.json',
          jsonEncode(<String, Object?>{'format': 'plo-backup', 'tabel': <String, Object?>{}}),
          <String>['versi skema yang sah', 'tidak diubah'],
          label: 'versi hilang');
    });

    test('bagian tabel bukan objek', () async {
      await tolakBerkas('plo_backup_tabelrusak.json',
          jsonEncode(<String, Object?>{'format': 'plo-backup', 'versiSkema': 3, 'tabel': 5}),
          <String>['tidak memuat bagian "tabel"', 'tidak diubah'],
          label: 'tabel bukan objek');
    });

    test('baris tabel isinya bukan objek', () async {
      await tolakBerkas('plo_backup_barisrusak.json',
          jsonEncode(<String, Object?>{
            'format': 'plo-backup',
            'versiSkema': 3,
            'tabel': <String, Object?>{
              'tagihan': <Object?>['bukan objek'],
            },
          }),
          <String>['bukan objek', 'tidak diubah'],
          label: 'baris bukan objek');
    });

    test('berkas tidak ada', () async {
      await isiData();
      final sebelum = await cadangan.jumlahBarisSemuaTabel();
      final hasil = await cadangan.impor(
          '${folderUji.path}${Platform.pathSeparator}tidak_ada.json',
          sudahDikonfirmasi: true);
      expect(hasil.berhasil, isFalse);
      expect(hasil.pesan, contains('tidak ditemukan'));
      pesanDitolak.add(hasil.pesan);
      expect(await cadangan.jumlahBarisSemuaTabel(), sebelum);
    });
  });

  // ------------------------------------------------------------------
  // 5. ROLLBACK (satu baris rusak membatalkan seluruh impor)
  // ------------------------------------------------------------------

  group('FR-24 rollback impor', () {
    test('satu baris rusak -> seluruh impor dibatalkan, data lama utuh',
        () async {
      await isiData();
      final hasil = await cadangan.ekspor();
      final sebelum = await cadangan.jumlahBarisSemuaTabel();

      // Rusakkan berkas: id tagihan digandakan (melanggar PRIMARY KEY).
      final Map<String, dynamic> isi =
          jsonDecode(File(hasil.path).readAsStringSync()) as Map<String, dynamic>;
      final List<dynamic> barisTagihan =
          (isi['tabel'] as Map<String, dynamic>)['tagihan'] as List<dynamic>;
      barisTagihan.add(Map<String, dynamic>.from(barisTagihan.first as Map));
      final rusak = berkasUji(
          'plo_backup_rusakbaris.json', const JsonEncoder.withIndent('  ').convert(isi));

      final impor = await cadangan.impor(rusak.path, sudahDikonfirmasi: true);
      expect(impor.berhasil, isFalse);
      expect(impor.pesan, contains('seluruh perubahan dibatalkan'));
      pesanDitolak.add(impor.pesan);

      final sesudah = await cadangan.jumlahBarisSemuaTabel();
      expect(sesudah, sebelum, reason: 'rollback: data lama tetap utuh');
      final tagihan = await db.select(db.tagihan).getSingle();
      expect(tagihan.nama, 'Listrik PLN');
      expect(tagihan.jumlahSen, 18600000);
      expect(tagihan.jatuhTempo, DateTime(2026, 9, 20));
      expect((await db.select(db.langganan).get()).length, 1);
      expect((await db.select(db.aset).get()).length, 1);
    });

    test('tanggal tidak sah ditolak dan data lama utuh', () async {
      await isiData();
      final sebelum = await cadangan.jumlahBarisSemuaTabel();
      final isi = jsonEncode(<String, Object?>{
        'format': 'plo-backup',
        'versiSkema': 3,
        'tabel': <String, Object?>{
          'tagihan': <Map<String, Object?>>[
            <String, Object?>{
              'id': 1,
              'nama': 'Listrik PLN',
              'jumlah_sen': 18600000,
              'jatuh_tempo': 'bukan tanggal',
            },
          ],
        },
      });
      final f = berkasUji('plo_backup_tanggalrusak.json', isi);

      final impor = await cadangan.impor(f.path, sudahDikonfirmasi: true);
      expect(impor.berhasil, isFalse);
      expect(impor.pesan, contains('bukan teks ISO 8601 yang sah'));
      pesanDitolak.add(impor.pesan);
      expect(await cadangan.jumlahBarisSemuaTabel(), sebelum);
      expect((await db.select(db.tagihan).get()).length, 1);
    });
  });

  // ------------------------------------------------------------------
  // 6. CADANGAN PENGAMAN
  // ------------------------------------------------------------------

  group('FR-24 cadangan pengaman', () {
    test('cadangan pengaman otomatis dibuat sebelum data diubah', () async {
      await isiData();
      final hasil = await cadangan.ekspor();
      expect(await cadangan.daftarBerkas(), hasLength(1));

      await (db.delete(db.tagihan)).go();
      final impor = await cadangan.impor(hasil.path, sudahDikonfirmasi: true);
      expect(impor.berhasil, isTrue, reason: impor.pesan);
      expect(impor.pathCadanganPengaman, isNotNull);

      final daftar = await cadangan.daftarBerkas();
      expect(daftar, hasLength(2));
      final pengaman = daftar.firstWhere(
          (b) => b.nama.startsWith('${awalanBerkasCadangan}_pengaman_'));
      expect(pengaman.nama, endsWith('.json'));
      expect(pengaman.ukuranByte, greaterThan(0));

      // Isi cadangan pengaman = keadaan SEBELUM impor (tagihan sudah kosong).
      final Map<String, dynamic> isiPengaman =
          jsonDecode(File(pengaman.path).readAsStringSync()) as Map<String, dynamic>;
      final tabel = isiPengaman['tabel'] as Map<String, dynamic>;
      expect((tabel['tagihan'] as List<dynamic>), isEmpty);
      expect((tabel['kategori'] as List<dynamic>).length, 10);
      expect(isiPengaman['versiSkema'], 4);

      // Daftar berkas: terbaru lebih dahulu.
      expect(daftar.first.diubahPada.isAfter(daftar.last.diubahPada) ||
          daftar.first.diubahPada.isAtSameMomentAs(daftar.last.diubahPada), isTrue);
    });

    test('cadangan pengaman bisa dipakai memulihkan keadaan sebelumnya',
        () async {
      await isiData();
      final hasil = await cadangan.ekspor();
      final sebelum = await cadangan.jumlahBarisSemuaTabel();

      await kosongkanSemua();
      final impor1 = await cadangan.impor(hasil.path, sudahDikonfirmasi: true);
      expect(impor1.berhasil, isTrue);
      expect(impor1.pathCadanganPengaman, isNotNull);

      // Kembalikan dari cadangan pengaman (keadaan kosong) lalu pulihkan lagi.
      final balik = await cadangan.impor(impor1.pathCadanganPengaman!,
          sudahDikonfirmasi: true);
      expect(balik.berhasil, isTrue, reason: balik.pesan);
      final kosong = await cadangan.jumlahBarisSemuaTabel();
      expect(kosong.values.every((v) => v == 0), isTrue);

      final ulang = await cadangan.impor(hasil.path, sudahDikonfirmasi: true);
      expect(ulang.berhasil, isTrue);
      expect(await cadangan.jumlahBarisSemuaTabel(), sebelum);
    });

    test('daftar berkas kosong saat folder belum punya cadangan', () async {
      expect(await cadangan.daftarBerkas(), isEmpty);
      // Berkas lain di folder tidak ikut terdaftar.
      berkasUji('catatan_lain.txt', 'bukan cadangan');
      expect(await cadangan.daftarBerkas(), isEmpty);
    });
  });

  // ------------------------------------------------------------------
  // 7. BAHASA (PRD §III-11)
  // ------------------------------------------------------------------

  group('FR-136 cadangan memuat tabel pilar V2 (skema v4)', () {
    test('data tabel v4 ikut ter-ekspor & pulih utuh', () async {
      await isiData();
      // Data pada tabel skema v4 (Pilar Kehidupan).
      final tujuanId = await db.into(db.tujuan).insert(TujuanCompanion.insert(
          idTujuan: 'tj_uji',
          nama: 'Sehat bugar',
          area: const Value('kesehatan')));
      await db.into(db.tugas).insert(TugasCompanion.insert(
          idTugas: 'tg_uji',
          nama: 'Olahraga pagi',
          tujuanId: Value(tujuanId),
          jatuhTempo: Value(DateTime(2026, 9, 16))));
      final kebiasaanId = await db.into(db.kebiasaan).insert(
          KebiasaanCompanion.insert(idKebiasaan: 'kb_uji', nama: 'Minum air'));
      await db.into(db.logKebiasaan).insert(LogKebiasaanCompanion.insert(
          kebiasaanId: kebiasaanId, tanggal: DateTime(2026, 9, 15)));
      await db.into(db.catatanAir).insert(CatatanAirCompanion.insert(
          waktu: DateTime(2026, 9, 15, 7), jumlahMl: const Value(300)));

      final hasil = await cadangan.ekspor();

      final Map<String, dynamic> isi =
          jsonDecode(File(hasil.path).readAsStringSync()) as Map<String, dynamic>;
      final Map<String, dynamic> tabel = isi['tabel'] as Map<String, dynamic>;
      expect(
          tabel.keys,
          containsAll(<String>[
            'tujuan',
            'proyek',
            'tugas',
            'kebiasaan',
            'log_kebiasaan',
            'perawatan',
            'ukuran_tubuh',
            'tidur',
            'obat',
            'catatan_air',
            'dokumen',
            'audit_log',
            'notifikasi_riwayat',
            'tunda_pengingat',
            'log_puasa',
            'log_quran',
            'log_dzikir',
            'refleksi_muhasabah',
          ]),
          reason: 'seluruh tabel pilar V2 harus ada di berkas cadangan');
      expect((tabel['tugas'] as List<dynamic>), hasLength(1));
      expect((tabel['catatan_air'] as List<dynamic>), hasLength(1));

      // HP baru: seluruh tabel dikosongkan, lalu dipulihkan dari berkas.
      await kosongkanSemua();
      expect(await db.select(db.tugas).get(), isEmpty);

      final impor = await cadangan.impor(hasil.path, sudahDikonfirmasi: true);
      expect(impor.berhasil, isTrue, reason: impor.pesan);
      expect(impor.tabelTidakCocok, isEmpty);

      final tugas = await db.select(db.tugas).get();
      expect(tugas, hasLength(1));
      expect(tugas.single.idTugas, 'tg_uji');
      expect(tugas.single.nama, 'Olahraga pagi');
      expect(tugas.single.tujuanId, tujuanId);
      expect(await db.select(db.logKebiasaan).get(), hasLength(1));
      expect((await db.select(db.catatanAir).get()).single.jumlahMl, 300);
      expect(await db.select(db.tujuan).get(), hasLength(1));
      // Template perawatan bawaan juga pulih dari berkas (bukan seed ulang).
      expect(await db.select(db.perawatan).get(), hasLength(6));
    });
  });

  group('Bahasa III-11', () {
    test('pesan layanan pada keadaan sulit tidak memakai kata terlarang',
        () async {
      // Kumpulkan pesan dari semua jalur: berkas ditolak, tanpa konfirmasi,
      // alur sukses, dan hambatan tulis.
      final kosong = berkasUji('plo_backup_kosong2.json', '');
      final hasilKosong = await cadangan.impor(kosong.path, sudahDikonfirmasi: true);
      final tanpaKonfirmasi = await cadangan.impor(kosong.path);
      final tidakAda = await cadangan.impor(
          '${folderUji.path}${Platform.pathSeparator}bukan_ada.json',
          sudahDikonfirmasi: true);

      await isiData();
      final hasil = await cadangan.ekspor();
      final sukses = await cadangan.impor(hasil.path, sudahDikonfirmasi: true);

      final semuaPesan = <String>[
        ...pesanDitolak,
        hasilKosong.pesan,
        tanpaKonfirmasi.pesan,
        tidakAda.pesan,
        sukses.pesan,
      ];
      expect(semuaPesan, isNotEmpty);
      for (final p in semuaPesan) {
        for (final kata in kataTerlarang) {
          expect(p.toLowerCase().contains(kata), isFalse,
              reason: '"$p" memuat kata terlarang "$kata"');
        }
      }
    });
  });

  // ------------------------------------------------------------------
  // 8. LAYAR
  // ------------------------------------------------------------------

  group('FR-24 layar Cadangan & Pemulihan', () {
    testWidgets('keadaan kosong ditampilkan dengan jujur', (t) async {
      await tampilkan(t, BackupScreen(layanan: cadangan, jamSekarang: () => jamUji));
      // Tombol ekspor ada di bagian atas; periksa SEBELUM menggulir karena
      // ListView hanya membangun baris yang terlihat.
      expect(find.byKey(const Key('ekspor_sekarang')), findsOneWidget);

      await gulirKe(t, find.byKey(const Key('cadangan_kosong')));
      expect(find.byKey(const Key('cadangan_kosong')), findsOneWidget);
      expect(find.textContaining('Belum ada berkas cadangan'), findsOneWidget);
      // Tidak ada baris berkas palsu: baris berkas selalu berawalan
      // "impor_berkas_". (Baris setelan lain seperti saklar cadangan otomatis
      // memang ada dan bukan baris berkas.)
      expect(
          find.byWidgetPredicate((w) =>
              w is ListTile &&
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('impor_berkas_')),
          findsNothing,
          reason: 'tidak ada berkas -> tidak ada baris palsu');
      await tutup(t);
    });

    testWidgets('alur ekspor membuat berkas nyata & menampilkan jumlah baris',
        (t) async {
      await isiData();
      await tampilkan(t, BackupScreen(layanan: cadangan, jamSekarang: () => jamUji));

      await ketukNyata(t, find.byKey(const Key('ekspor_sekarang')));

      // Bukti nyata: satu berkas JSON di folder dokumen (folder uji).
      final File berkas = File(
          '${folderUji.path}${Platform.pathSeparator}plo_backup_20260915_0800.json');
      expect(berkas.existsSync(), isTrue, reason: 'berkas cadangan dibuat');
      expect(berkas.lengthSync(), greaterThan(0), reason: 'berkas tidak kosong');
      final Map<String, dynamic> isi =
          jsonDecode(berkas.readAsStringSync()) as Map<String, dynamic>;
      expect(isi['format'], 'plo-backup');
      expect(isi['versiSkema'], 4);
      expect((isi['tabel'] as Map<String, dynamic>)['tagihan'], hasLength(1));

      await gulirKe(t, find.byKey(const Key('jumlah_baris_tagihan')));
      expect(find.byKey(const Key('hasil_ekspor')), findsOneWidget);
      expect(find.byKey(const Key('nama_berkas_cadangan')), findsOneWidget);
      expect(find.text('tagihan: 1 baris'), findsOneWidget);
      expect(find.text('kategori_transaksi: 24 baris'), findsOneWidget);

      // Berkas hasil ekspor langsung bisa dipilih untuk pemulihan.
      const Key kunciBerkas = Key('impor_berkas_plo_backup_20260915_0800.json');
      await gulirKe(t, find.byKey(kunciBerkas));
      expect(find.byKey(kunciBerkas), findsOneWidget);
      expect(find.byKey(const Key('cadangan_kosong')), findsNothing);
      await tutup(t);
    });

    testWidgets('impor: pratinjau -> batal (data tetap), lalu konfirmasi',
        (t) async {
      await isiData();
      final HasilEkspor hasil = (await t.runAsync(() => cadangan.ekspor()))!;
      final Finder kunciBerkas =
          find.byKey(Key('impor_berkas_${hasil.namaBerkas}'));

      await tampilkan(t, BackupScreen(layanan: cadangan, jamSekarang: () => jamUji));

      // 1. Pratinjau tampil sebelum ada data yang berubah.
      await gulirKe(t, kunciBerkas);
      await ketukNyata(t, kunciBerkas);
      await gulirKe(t, find.byKey(const Key('pratinjau_impor')));
      expect(find.byKey(const Key('pratinjau_impor')), findsOneWidget);
      expect(find.textContaining('Versi skema: 4'), findsOneWidget);
      expect(find.textContaining('Dibuat: 15 September 2026'), findsOneWidget);
      expect(find.byKey(const Key('pratinjau_baris_tagihan')), findsOneWidget);
      expect(find.text('tagihan: 1 baris'), findsOneWidget);

      // 2. Tombol Batal: tidak ada pemulihan yang jalan.
      await gulirKe(t, find.byKey(const Key('pulihkan_berkas')));
      await t.tap(find.byKey(const Key('pulihkan_berkas')));
      await majukan(t);
      expect(find.byKey(const Key('konfirmasi_impor')), findsOneWidget);
      expect(find.byKey(const Key('batal_impor')), findsOneWidget);
      await t.tap(find.byKey(const Key('batal_impor')));
      await majukan(t);
      expect(find.byKey(const Key('hasil_impor')), findsNothing);
      expect(await db.select(db.tagihan).get(), hasLength(1));

      // 3. Data dikosongkan, lalu dipulihkan setelah konfirmasi.
      await (db.delete(db.tagihan)).go();
      expect(await db.select(db.tagihan).get(), isEmpty);

      await gulirKe(t, kunciBerkas);
      await ketukNyata(t, kunciBerkas);
      await gulirKe(t, find.byKey(const Key('pulihkan_berkas')));
      await t.tap(find.byKey(const Key('pulihkan_berkas')));
      await majukan(t);
      expect(find.byKey(const Key('konfirmasi_impor')), findsOneWidget);
      await ketukNyata(t, find.byKey(const Key('konfirmasi_impor')),
          milidetik: 1200);

      await gulirKe(t, find.byKey(const Key('hasil_impor')));
      expect(find.byKey(const Key('hasil_impor')), findsOneWidget);
      expect(find.textContaining('Pemulihan selesai'), findsOneWidget);
      expect(find.textContaining('sudah diperiksa ulang'), findsOneWidget);

      final List<TagihanData> tagihan = await db.select(db.tagihan).get();
      expect(tagihan, hasLength(1));
      expect(tagihan.single.nama, 'Listrik PLN');
      expect(tagihan.single.jumlahSen, 18600000);
      expect(await db.select(db.transaksi).get(), hasLength(1));
      expect(await db.select(db.langganan).get(), hasLength(1));

      // Cadangan pengaman tampil juga di daftar berkas.
      final List<BerkasCadangan> daftar = await cadangan.daftarBerkas();
      expect(daftar, hasLength(2));
      final String namaPengaman = daftar
          .firstWhere(
              (b) => b.nama.startsWith('${awalanBerkasCadangan}_pengaman_'))
          .nama;
      await gulirKe(t, find.byKey(Key('impor_berkas_$namaPengaman')));
      expect(find.byKey(Key('impor_berkas_$namaPengaman')), findsOneWidget);
      await tutup(t);
    });

    testWidgets('berkas rusak: layar menjelaskan & data tidak berubah',
        (t) async {
      await isiData();
      berkasUji('plo_backup_rusakui.json', '{"format":"plo-backup"');
      await tampilkan(t, BackupScreen(layanan: cadangan, jamSekarang: () => jamUji));

      final Finder kunci = find.byKey(const Key('impor_berkas_plo_backup_rusakui.json'));
      await gulirKe(t, kunci);
      await ketukNyata(t, kunci);

      await gulirKe(t, find.byKey(const Key('pesan_pratinjau')));
      expect(find.byKey(const Key('pesan_pratinjau')), findsOneWidget);
      expect(find.textContaining('bukan JSON yang sah'), findsOneWidget);
      expect(find.textContaining('tidak diubah'), findsOneWidget);
      expect(find.byKey(const Key('pratinjau_impor')), findsNothing);
      expect(await db.select(db.tagihan).get(), hasLength(1));
      await tutup(t);
    });

    testWidgets('bahasa layar bebas kata terlarang (PRD §III-11)', (t) async {
      await isiData();
      await tampilkan(t, BackupScreen(layanan: cadangan, jamSekarang: () => jamUji));

      await ketukNyata(t, find.byKey(const Key('ekspor_sekarang')));

      final List<String> namaBerkas = folderUji
          .listSync()
          .whereType<File>()
          .map((File f) => f.uri.pathSegments.last)
          .toList();
      expect(namaBerkas, hasLength(1));

      final Finder kunciBerkas = find.byKey(Key('impor_berkas_${namaBerkas.first}'));
      final Set<String> kumpulanAwal = <String>{...teksTampil(t)};
      await gulirKe(t, kunciBerkas);
      await ketukNyata(t, kunciBerkas);

      // Kumpulkan teks mulai dari posisi paling atas (bagian atas layar bisa
      // terlewat kalau langsung menggulir ke bawah). Catatan: daftar tabel di
      // layar ini bertambah setiap skema baru, jadi jumlah gulir dibuat lega.
      final Set<String> kumpulan = <String>{...kumpulanAwal, ...teksTampil(t)};
      for (var i = 0; i < 6; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -220));
        await t.pump(const Duration(milliseconds: 120));
        kumpulan.addAll(teksTampil(t));
      }
      for (var i = 0; i < 14; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, 400));
        await t.pump(const Duration(milliseconds: 120));
        kumpulan.addAll(teksTampil(t));
      }

      expect(kumpulan, isNotEmpty);
      for (final String teks in kumpulan) {
        for (final String kata in kataTerlarang) {
          expect(teks.toLowerCase().contains(kata), isFalse,
              reason: '"$teks" memuat kata terlarang "$kata"');
        }
      }
      expect(kumpulan.any((s) => s.contains('Buat cadangan sekarang')), isTrue);
      expect(kumpulan.any((s) => s.contains('Versi skema')), isTrue);
      await tutup(t);
    });
  });
}
