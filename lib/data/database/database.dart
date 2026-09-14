/// Koneksi database utama — Drift + SQLite lokal (offline-first, PRD §8.2).
library;

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tabel.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Kategori,
  Tagihan,
  RiwayatPembayaran,
  PemasukanBulanan,
  Pengaturan,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_buka());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _pasangIndeksUnik();
          await _seedKategori();
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

  static QueryExecutor _buka() =>
      driftDatabase(name: 'personal_life_os', native: const DriftNativeOptions());
}
