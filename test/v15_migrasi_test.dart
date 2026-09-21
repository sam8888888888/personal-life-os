/// Uji MIGRASI skema v2 → v3 (fondasi V1.5).
///
/// Sengaja terpisah dari `v15_data_test.dart`: berkas ini membuat database
/// lama (v2) di berkas sementara — seperti yang ada di perangkat pengguna
/// sekarang — lalu membuka [AppDatabase] di atasnya untuk memastikan:
/// 1. tabel baru v3 dibuat,
/// 2. kategori kas bawaan ikut terisi,
/// 3. **data lama tidak hilang** (tagihan, riwayat pembayaran, pemasukan),
/// 4. indeks unik lama (PB-05/PB-07) tetap berlaku.
///
/// Catatan teknis: dipakai berkas sementara (bukan SQLite in-memory) karena
/// drift hanya menjalankan `onUpgrade` saat membuka database — database
/// in-memory tidak bisa ditutup lalu dibuka ulang untuk perjalanan migrasi.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/data/database/database.dart';

/// Pengguna executor minimal: memberi tahu bahwa berkas lama memakai skema v2,
/// supaya drift menjalankan `onUpgrade` saat [AppDatabase] membukanya.
class _SkemaLamaV2 extends QueryExecutorUser {
  @override
  int get schemaVersion => 2;

  @override
  Future<void> beforeOpen(
      QueryExecutor executor, OpeningDetails details) async {}
}

/// DDL skema v2 (sesuai tabel yang sudah ada sebelum fondasi V1.5).
const List<String> _ddlV2 = [
  "CREATE TABLE kategori (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "
      "nama TEXT NOT NULL, ikon TEXT NOT NULL DEFAULT 'receipt', "
      "warna TEXT NOT NULL DEFAULT '#4A90D9', urutan INTEGER NOT NULL DEFAULT 0)",
  "CREATE TABLE tagihan (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "
      "jenis TEXT NOT NULL DEFAULT 'tagihan', nama TEXT NOT NULL, "
      "jumlah_sen INTEGER, kode_mata_uang TEXT NOT NULL DEFAULT 'IDR', "
      "kategori_id INTEGER REFERENCES kategori (id), jatuh_tempo INTEGER NOT NULL, "
      "frekuensi TEXT NOT NULL DEFAULT 'bulanan', kustom_hari_n INTEGER, "
      "pengingat_lead_hari TEXT NOT NULL DEFAULT '7,3,1', "
      "pengingat_jam TEXT NOT NULL DEFAULT '09:00', "
      "kanal_pengingat TEXT NOT NULL DEFAULT 'push', "
      "prioritas TEXT NOT NULL DEFAULT 'biasa', catatan TEXT, tautan_bayar TEXT, "
      "status_aktif INTEGER NOT NULL DEFAULT 1, lunas INTEGER NOT NULL DEFAULT 0, "
      "tanggal_lunas INTEGER, dibuat_pada INTEGER NOT NULL, "
      "diubah_pada INTEGER NOT NULL)",
  "CREATE TABLE riwayat_pembayaran (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "
      "tagihan_id INTEGER NOT NULL REFERENCES tagihan (id), "
      "periode_jatuh_tempo INTEGER NOT NULL, jumlah_sen INTEGER NOT NULL, "
      "kode_mata_uang TEXT NOT NULL DEFAULT 'IDR', tanggal_bayar INTEGER NOT NULL, "
      "telat_hari INTEGER, via TEXT NOT NULL DEFAULT 'manual')",
  "CREATE TABLE pemasukan_bulanan (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "
      "bulan TEXT NOT NULL, jumlah_sen INTEGER NOT NULL DEFAULT 0, "
      "sumber TEXT NOT NULL DEFAULT 'Gaji')",
  'CREATE TABLE pengaturan (kunci TEXT NOT NULL PRIMARY KEY, nilai TEXT NOT NULL)',
  'CREATE UNIQUE INDEX idx_riwayat_periode '
      'ON riwayat_pembayaran(tagihan_id, periode_jatuh_tempo)',
  'CREATE UNIQUE INDEX idx_pemasukan_bulan ON pemasukan_bulanan(bulan)',
];

void main() {
  late Directory folder;
  late File berkas;

  setUp(() async {
    folder = Directory.systemTemp.createTempSync('plo_migrasi_v3');
    berkas = File('${folder.path}/personal_life_os.sqlite');

    // Bangun database lama (v2) + isi data pengguna, lalu tutup.
    final lama = NativeDatabase(berkas);
    await lama.ensureOpen(_SkemaLamaV2());
    for (final ddl in _ddlV2) {
      await lama.runCustom(ddl, const []);
    }
    await lama.runCustom(
      "INSERT INTO tagihan (nama, jumlah_sen, jatuh_tempo, dibuat_pada, "
      "diubah_pada) VALUES ('Internet', 3000000, 1789000000, 1789000000, 1789000000)",
      const [],
    );
    await lama.runCustom(
      "INSERT INTO riwayat_pembayaran (tagihan_id, periode_jatuh_tempo, "
      "jumlah_sen, tanggal_bayar) VALUES (1, 1789000000, 3000000, 1789000000)",
      const [],
    );
    await lama.runCustom(
      "INSERT INTO pemasukan_bulanan (bulan, jumlah_sen) VALUES ('2026-09', 1200000000)",
      const [],
    );
    await lama.runCustom('PRAGMA user_version = 2', const []);
    await lama.close();
  });

  tearDown(() {
    if (folder.existsSync()) folder.deleteSync(recursive: true);
  });

  test('migrasi v2 → v3: tabel baru dibuat, data lama selamat', () async {
    final db = AppDatabase.forTesting(NativeDatabase(berkas));
    addTearDown(db.close);

    // 1. Membaca tabel baru memaksa migrasi berjalan (onUpgrade dari 2 ke 3).
    final kategori = await db.select(db.kategoriTransaksi).get();
    expect(kategori.length, 23, reason: 'kategori kas bawaan harus terisi');
    expect(await db.select(db.transaksi).get(), isEmpty);
    expect(await db.select(db.anggaranBulanan).get(), isEmpty);
    expect(await db.select(db.langganan).get(), isEmpty);
    expect(await db.select(db.aset).get(), isEmpty);
    expect(await db.select(db.kewajiban).get(), isEmpty);
    expect(await db.select(db.nilaiAsetBulanan).get(), isEmpty);
    expect(await db.select(db.nilaiKewajibanBulanan).get(), isEmpty);

    // 2. Data lama utuh.
    final tagihan = await db.select(db.tagihan).get();
    expect(tagihan.length, 1);
    expect(tagihan.single.nama, 'Internet');
    expect(tagihan.single.jumlahSen, 3000000);
    final riwayat = await db.select(db.riwayatPembayaran).get();
    expect(riwayat.length, 1);
    expect(riwayat.single.jumlahSen, 3000000);
    final pemasukan = await db.select(db.pemasukanBulanan).get();
    expect(pemasukan.single.bulan, '2026-09');
    expect(pemasukan.single.jumlahSen, 1200000000);

    // 3. Versi skema di database naik ke versi terakhir aplikasi:
    //    v2 -> v3 -> v4 -> v5 -> v6 -> v7 -> v8 -> v9 (v4 menambah 23 tabel
    //    pilar kehidupan, v5 visi & area hidup + tujuan.area_id, v6-v8 tabel
    //    kesehatan/dokumen/sinkron, v9 delapan tabel modul Pengetahuan).
    final versi = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versi.data.values.first, 9);
    final tabel = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final nama = tabel.map((r) => r.data['name'] as String).toSet();
    expect(nama, containsAll(<String>['tujuan', 'tugas', 'audit_log']));
  });

  test('indeks unik lama & baru tetap berlaku setelah migrasi', () async {
    final db = AppDatabase.forTesting(NativeDatabase(berkas));
    addTearDown(db.close);

    // Paksa migrasi selesai lebih dulu.
    await db.select(db.kategoriTransaksi).get();

    // Indeks BARU: satu kode kategori = satu baris.
    await expectLater(
      db.customStatement("INSERT INTO kategori_transaksi (kode, nama, jenis, "
          "ikon, warna, urutan, sifat_arus, bawaan_sistem, arsip, dibuat_pada, "
          "diubah_pada) VALUES ('kel_makan', 'Kembar', 'pengeluaran', 'x', '#000000', "
          "99, 'campuran', 0, 0, 0, 0)"),
      throwsA(anything),
    );

    // Indeks LAMA (PB-07): satu bulan = satu baris pemasukan.
    await expectLater(
      db.customStatement(
          "INSERT INTO pemasukan_bulanan (bulan, jumlah_sen) VALUES ('2026-09', 1)"),
      throwsA(anything),
    );
  });
}
