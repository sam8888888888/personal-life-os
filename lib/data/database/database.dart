/// Koneksi database utama — Drift + SQLite lokal (offline-first, PRD §8.2).
library;

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../repository/template_kategori_transaksi.dart';
import 'tabel.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Kategori,
  Tagihan,
  RiwayatPembayaran,
  PemasukanBulanan,
  Pengaturan,
  // Skema v3 — fondasi V1.5 (FR-68/71/72/76), ditambahkan Aaron 15 Sep 2026.
  KategoriTransaksi,
  Transaksi,
  AnggaranBulanan,
  Langganan,
  Aset,
  Kewajiban,
  NilaiAsetBulanan,
  NilaiKewajibanBulanan,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_buka());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _pasangIndeksUnik();
          await _pasangIndeksUnikV3();
          await _seedKategori();
          await seedKategoriTransaksi();
        },
        onUpgrade: (m, dari, ke) async {
          if (dari < 2) {
            // PB-05/PB-07: rapikan data lama SEBELUM indeks unik dibuat,
            // supaya migrasi tidak gagal di perangkat yang sudah punya duplikat.
            final hapusRiwayat = await customUpdate('''
DELETE FROM riwayat_pembayaran WHERE id NOT IN (
  SELECT MIN(id) FROM riwayat_pembayaran GROUP BY tagihan_id, periode_jatuh_tempo
)''');
            final hapusPemasukan = await customUpdate('''
DELETE FROM pemasukan_bulanan WHERE id NOT IN (
  SELECT MAX(id) FROM pemasukan_bulanan GROUP BY bulan
)''');
            await _pasangIndeksUnik();
            debugPrint('migrasi v2 selesai (baris dibersihkan: '
                '$hapusRiwayat riwayat / $hapusPemasukan pemasukan)');
          }
          if (dari < 3) {
            // v3: tabel BARU saja — tidak ada kolom tabel lama yang diubah,
            // jadi data pengguna tidak tersentuh oleh migrasi ini.
            await _buatTabelV3(m);
            await _pasangIndeksUnikV3();
            await seedKategoriTransaksi();
            final jml = await (selectOnly(kategoriTransaksi)
                  ..addColumns([kategoriTransaksi.id]))
                .get();
            debugPrint('migrasi v3 selesai (tabel kas & kekayaan dibuat, '
                'kategori transaksi: ${jml.length})');
          }
        },
      );

  /// PB-05 & PB-07: indeks unik penjaga integritas.
  ///
  /// Dipasang lewat SQL (bukan anotasi tabel) karena `database.g.dart` dilacak
  /// git dan proyek ini belum memakai build_runner — dengan cara ini jaminan
  /// tetap berlaku tanpa regenerasi kode.
  Future<void> _pasangIndeksUnik() async {
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_riwayat_periode '
        'ON riwayat_pembayaran(tagihan_id, periode_jatuh_tempo)');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_pemasukan_bulan '
        'ON pemasukan_bulanan(bulan)');
  }

  /// Skema v3: tabel baru dibuat di sini (urutan tidak penting, tidak ada FK
  /// yang ditegakkan SQLite secara default di proyek ini).
  Future<void> _buatTabelV3(Migrator m) async {
    await m.createTable(kategoriTransaksi);
    await m.createTable(transaksi);
    await m.createTable(anggaranBulanan);
    await m.createTable(langganan);
    await m.createTable(aset);
    await m.createTable(kewajiban);
    await m.createTable(nilaiAsetBulanan);
    await m.createTable(nilaiKewajibanBulanan);
  }

  /// Skema v3: indeks unik — jaminan "satu baris per kunci bisnis"
  /// (mengikuti gaya PB-05/PB-07: SQL, bukan anotasi tabel).
  ///
  /// Catatan: indeks unik pada kolom nullable (mis. `langganan(tagihan_id)`)
  /// tetap mengizinkan banyak NULL di SQLite — itu yang diinginkan (banyak
  /// langganan tanpa tagihan tertaut).
  Future<void> _pasangIndeksUnikV3() async {
    // Kategori transaksi
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_kt_kode '
        'ON kategori_transaksi(kode)');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_kt_jenis_nama '
        'ON kategori_transaksi(jenis, nama)');
    // Transaksi
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_trx_id '
        'ON transaksi(id_transaksi)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_trx_tanggal '
        'ON transaksi(tanggal)');
    // Anggaran
    await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_anggaran_periode_kategori '
        'ON anggaran_bulanan(periode, kategori_id)');
    // Langganan
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_langganan_id '
        'ON langganan(id_langganan)');
    await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_langganan_tagihan '
        'ON langganan(tagihan_id)');
    // Aset & kewajiban
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_aset_id '
        'ON aset(id_aset)');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_kewajiban_id '
        'ON kewajiban(id_kewajiban)');
    // Riwayat nilai bulanan
    await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_nilai_aset_bulan '
        'ON nilai_aset_bulanan(aset_id, bulan)');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_nilai_aset_idem '
        'ON nilai_aset_bulanan(idempotensi)');
    await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_nilai_kewajiban_bulan '
        'ON nilai_kewajiban_bulanan(kewajiban_id, bulan)');
    await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_nilai_kewajiban_idem '
        'ON nilai_kewajiban_bulanan(idempotensi)');
  }

  /// Kategori bawaan penyedia layanan Indonesia (FR-05 template lokal).
  Future<void> _seedKategori() async {
    final seed = [
      ('PLN', 'bolt', '#F5A623'),
      ('PDAM', 'water_drop', '#4A90D9'),
      ('BPJS', 'health_and_safety', '#4CAF50'),
      ('Internet & TV', 'wifi', '#7B68EE'),
      ('Ponsel', 'smartphone', '#F06292'),
      ('Kartu kredit', 'credit_card', '#9E9E9E'),
      ('Langganan', 'subscriptions', '#00ACC1'),
      ('Kendaraan', 'directions_car', '#5C6BC0'),
      ('Sekolah', 'school', '#FFB74D'),
      ('Rumah tangga', 'home', '#8D6E63'),
    ];
    final ada = await (selectOnly(kategori)..addColumns([kategori.id])).get();
    if (ada.isNotEmpty) return;
    for (final (i, s) in seed.indexed) {
      await into(kategori).insert(KategoriCompanion.insert(
        nama: s.$1,
        ikon: Value(s.$2),
        warna: Value(s.$3),
        urutan: Value(i),
      ));
    }
  }

  /// Kategori kas bawaan (FR-71/FR-72) — 11 pengeluaran + 12 pemasukan,
  /// mengikuti `KATEGORI_KEUANGAN_ID.md` (rancangan Dinda).
  ///
  /// Idempoten: `INSERT OR IGNORE` + indeks unik `kode`, jadi aman dipanggil
  /// saat migrasi maupun saat pengguna mengganti nama kategori (kode tetap,
  /// kategori tidak berganda). BOLEH dipanggil ulang kapan pun.
  Future<void> seedKategoriTransaksi() async {
    for (final t in daftarKategoriTransaksi) {
      await into(kategoriTransaksi).insert(
        KategoriTransaksiCompanion.insert(
          kode: t.kode,
          nama: t.nama,
          jenis: Value(t.jenis),
          ikon: Value(t.ikon),
          warna: Value(t.warna),
          urutan: Value(t.urutan),
          sifatArus: Value(t.sifatArus),
          bawaanSistem: const Value(true),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  static QueryExecutor _buka() =>
      driftDatabase(name: 'personal_life_os', native: const DriftNativeOptions());
}
