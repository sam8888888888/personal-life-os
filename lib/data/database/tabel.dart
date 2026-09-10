/// Skema tabel Drift — Personal Life OS (skema v1).
/// Kolom sengaja memakai teks untuk enum & nilai masa depan (PRD §10):
/// kodeMataUang (default 'IDR') & kanalPengingat (default 'push') sudah
/// disiapkan agar ekspansi multi-mata uang & kanal notifikasi murah (F7).
library;

import 'package:drift/drift.dart';

/// Kategori tagihan: PLN, PDAM, BPJS, internet, dll. Boleh kosong.
class Kategori extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nama => text().withLength(min: 1, max: 60)();
  TextColumn get ikon => text().withDefault(const Constant('receipt'))();
  TextColumn get warna => text().withDefault(const Constant('#4A90D9'))();
  IntColumn get urutan => integer().withDefault(const Constant(0))();
}

/// Tagihan/langganan berulang + dokumen bermasa berlaku memakai tabel sama
/// dengan jenis='tagihan'|'dokumen' (FR-53 memakai engine yang sama).
class Tagihan extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get jenis => text().withDefault(const Constant('tagihan'))();
  TextColumn get nama => text().withLength(min: 1, max: 120)();
  /// Jumlah dalam satuan terkecil mata uang; null untuk dokumen/non-moneter.
  IntColumn get jumlahSen => integer().nullable()();
  TextColumn get kodeMataUang => text().withDefault(const Constant('IDR'))();
  IntColumn get kategoriId => integer().nullable().references(Kategori, #id)();
  /// Tanggal jatuh tempo / masa berlaku.
  DateTimeColumn get jatuhTempo => dateTime()();
  TextColumn get frekuensi => text().withDefault(const Constant('bulanan'))();
  /// Untuk frekuensi kustom_hari.
  IntColumn get kustomHariN => integer().nullable()();
  /// Lead days notifikasi, teks "7,3,1".
  TextColumn get pengingatLeadHari => text().withDefault(const Constant('7,3,1'))();
  /// Jam notifikasi HH:mm.
  TextColumn get pengingatJam => text().withDefault(const Constant('09:00'))();
  TextColumn get kanalPengingat => text().withDefault(const Constant('push'))();
  TextColumn get prioritas => text().withDefault(const Constant('biasa'))();
  TextColumn get catatan => text().nullable()();
  /// URL/tautan pembayaran (FR-42 pusat bayar).
  TextColumn get tautanBayar => text().nullable()();
  /// false = nonaktif (sementara/berhenti), bukan hapus riwayat.
  BoolColumn get statusAktif => boolean().withDefault(const Constant(true))();
  /// false = sudah dibayar di periode berjalan.
  BoolColumn get lunas => boolean().withDefault(const Constant(false))();
  DateTimeColumn get tanggalLunas => dateTime().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();
}

/// Riwayat pembayaran — bukti audit & statistik (FR-08 rekap tahunan).
class RiwayatPembayaran extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tagihanId => integer().references(Tagihan, #id)();
  /// Periode jatuh tempo yang dibayar.
  DateTimeColumn get periodeJatuhTempo => dateTime()();
  IntColumn get jumlahSen => integer()();
  TextColumn get kodeMataUang => text().withDefault(const Constant('IDR'))();
  DateTimeColumn get tanggalBayar => dateTime()();
  IntColumn get telatHari => integer().nullable()();
  TextColumn get via => text().withDefault(const Constant('manual'))();
}

/// Pemasukan bulanan (untuk "uang tersisa" / dasbor — FR-33).
class PemasukanBulanan extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Bulan "YYYY-MM" (satu baris per bulan, mudah di-query).
  TextColumn get bulan => text()();
  IntColumn get jumlahSen => integer().withDefault(const Constant(0))();
  TextColumn get sumber => text().withDefault(const Constant('Gaji'))();
}

/// Pengaturan aplikasi (kunci-nilai).
class Pengaturan extends Table {
  TextColumn get kunci => text()();
  TextColumn get nilai => text()();
  @override
  Set<Column> get primaryKey => {kunci};
}
