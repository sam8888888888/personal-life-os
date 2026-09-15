/// Skema tabel Drift — Personal Life OS (skema v1).
/// Kolom sengaja memakai teks untuk enum & nilai masa depan (PRD §10):
/// kodeMataUang (default 'IDR') & kanalPengingat (default 'push') sudah
/// disiapkan agar ekspansi multi-mata uang & kanal notifikasi murah (F7).
///
/// Skema v3 (Aaron, 15 Sep 2026 — fondasi V1.5): tabel kas & kekayaan untuk
/// FR-68 (Langganan), FR-71 (Transaksi), FR-72 (AnggaranBulanan) dan FR-76
/// (Aset/Kewajiban + riwayat nilai bulanan). Rancangan kolom mengikuti
/// `rancangan/TABEL_DB_V1_5.md` milik Dinda; keputusan yang saya ambil
/// dicatat di komentar tiap tabel + HANDOVER_V15_DATA_AARON.md.
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

  // PB-05: jaminan "satu periode = satu pembayaran" dipasang lewat indeks unik
  // di `database.dart` (migrasi). Anotasi `uniqueKeys` butuh regenerasi
  // database.g.dart (build_runner) yang belum dipakai proyek ini.
}

/// Pemasukan bulanan (untuk "uang tersisa" / dasbor — FR-33).
class PemasukanBulanan extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Bulan "YYYY-MM" (satu baris per bulan, mudah di-query).
  TextColumn get bulan => text()();
  IntColumn get jumlahSen => integer().withDefault(const Constant(0))();
  TextColumn get sumber => text().withDefault(const Constant('Gaji'))();

  // PB-07: jaminan "satu bulan = satu baris" dipasang lewat indeks unik di
  // `database.dart` (migrasi).
}

/// Pengaturan aplikasi (kunci-nilai).
class Pengaturan extends Table {
  TextColumn get kunci => text()();
  TextColumn get nilai => text()();
  @override
  Set<Column> get primaryKey => {kunci};
}

// ---------------------------------------------------------------------------
// SKEMA v3 — kas, anggaran, langganan, kekayaan (FR-68/71/72/76)
// ---------------------------------------------------------------------------

/// Kategori kas (FR-71/FR-72) — tabel BARU, terpisah dari [Kategori] milik
/// mesin tagihan.
///
/// Keputusan (rancangan Dinda §4.1 Opsi A): kategori tagihan ("PLN", "BPJS")
/// dan kategori kas ("Makan & Minum", "Transportasi") punya arti berbeda,
/// jadi tidak digabung. Tidak ada tabel lama yang diubah.
class KategoriTransaksi extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Kunci stabil (mis. `kel_makan`) — dipakai seed ulang & impor/ekspor.
  /// Tanpa kolom ini, kategori berganda setiap kali nama diubah pengguna.
  TextColumn get kode => text().withLength(min: 1, max: 60)();
  /// Kode induk untuk sub-kategori; null = kategori tingkat atas.
  /// (Sub-kategori belum di-seed di V1.5 — kolom ini menyiapkannya.)
  TextColumn get indukKode => text().nullable()();
  TextColumn get nama => text().withLength(min: 1, max: 60)();
  /// `pengeluaran` / `pemasukan` (JenisArus di lib/data/model/enums.dart).
  TextColumn get jenis => text().withDefault(const Constant('pengeluaran'))();
  TextColumn get ikon => text().withDefault(const Constant('category'))();
  TextColumn get warna => text().withDefault(const Constant('#4A90D9'))();
  IntColumn get urutan => integer().withDefault(const Constant(0))();
  /// `berulang` / `sekali` / `campuran` — bahan awal FR-68 (pemilihan
  /// kategori berulang). Nilai mengikuti daftar kategori Indonesia.
  TextColumn get sifatArus => text().withDefault(const Constant('campuran'))();
  /// true = kategori bawaan: tidak boleh dihapus, hanya bisa disembunyikan.
  BoolColumn get bawaanSistem => boolean().withDefault(const Constant(false))();
  /// true = disembunyikan dari daftar tanpa menghapus riwayat transaksi.
  BoolColumn get arsip => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (kode) & (jenis, nama) dipasang lewat indeks SQL di `database.dart`.
  // CATATAN KEPUTUSAN: kolom usulan `perlakuanKas` (pemisahan "pinjaman
  // diterima" dari pendapatan) DITUNDA sampai FR-74 (Debt Manager) dikerjakan
  // — agar tidak ada kolom yang belum punya perilaku teruji.
}

/// Satu baris arus kas (FR-71; dipakai FR-72 realisasi & FR-73 kalender).
class Transaksi extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Pengenal stabil (`trx_<uuid>` / `tagihan:<id>:<YYYY-MM>`) — kunci
  /// idempotensi impor & sinkron (pola PB-05/06/07).
  TextColumn get idTransaksi => text()();
  /// `pengeluaran` / `pemasukan`.
  TextColumn get jenis => text().withDefault(const Constant('pengeluaran'))();
  /// Tanggal kejadian; jam diabaikan (disimpan tengah malam lokal).
  DateTimeColumn get tanggal => dateTime()();
  /// Selalu positif; arah ditentukan [jenis]. Satuan sen.
  IntColumn get jumlahSen => integer()();
  TextColumn get kodeMataUang => text().withDefault(const Constant('IDR'))();
  IntColumn get kategoriId =>
      integer().nullable().references(KategoriTransaksi, #id)();
  TextColumn get catatan => text().nullable()();
  /// `manual` / `impor` / `dari_tagihan` / `berulang`.
  TextColumn get sumber => text().withDefault(const Constant('manual'))();
  /// Tautan ke pelunasan tagihan (bahan FR-73). Tanpa cascade: transaksi
  /// tetap ada walau tagihannya dihapus (nilai dikosongkan, riwayat utuh).
  IntColumn get tagihanId => integer().nullable().references(Tagihan, #id)();
  /// 'YYYY-MM' periode tagihan yang dibayar, bila [tagihanId] terisi.
  TextColumn get periodeTagihan => text().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (id_transaksi) lewat indeks SQL di `database.dart`.
}

/// Batas anggaran per kategori per bulan (FR-72).
class AnggaranBulanan extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// 'YYYY-MM'.
  TextColumn get periode => text()();
  /// KEPUTUSAN (rancangan §4.3): 0 = anggaran TOTAL bulan itu, selain 0 = id
  /// kategori. Nilai 0 dipakai karena SQLite menganggap NULL berbeda-beda pada
  /// indeks unik — dengan 0 jaminan "satu baris per periode+kategori" tetap
  /// berlaku, dan validitas id diperiksa di repository.
  IntColumn get kategoriId => integer().withDefault(const Constant(0))();
  IntColumn get batasSen => integer().withDefault(const Constant(0))();
  /// Ambang peringatan (%), gaya sama seperti `pengingatLeadHari`: "80,100".
  TextColumn get ambangPeringatan => text().withDefault(const Constant('80,100'))();
  BoolColumn get terkunci => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dikunciPada => dateTime().nullable()();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (periode, kategori_id) lewat indeks SQL di `database.dart`.
}

/// Langganan berulang (FR-68; dipakai FR-69 di V2).
///
/// TIDAK ada mesin pengingat baru: [tagihanId] menautkan langganan ke mesin
/// tagihan yang sudah ada (FR-03/FR-16). Menandai `pause` = mematikan
/// `Tagihan.statusAktif` pada tagihan tertaut, sehingga pengingat berhenti
/// tanpa menghapus riwayat.
class Langganan extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Unik. Pengenal stabil (`lgn_<microseconds>`), dipakai sebagai bagian
  /// payload notifikasi + kunci impor/ekspor.
  TextColumn get idLangganan => text()();
  /// Tagihan tertaut (opsional). Satu tagihan dipakai paling banyak satu
  /// langganan (indeks unik parsial di `database.dart`).
  IntColumn get tagihanId => integer().nullable().references(Tagihan, #id)();
  TextColumn get nama => text().withLength(min: 1, max: 120)();
  IntColumn get nominalSen => integer().withDefault(const Constant(0))();
  TextColumn get kodeMataUang => text().withDefault(const Constant('IDR'))();
  IntColumn get kategoriId =>
      integer().nullable().references(KategoriTransaksi, #id)();
  /// Nilai Frekuensi.nilaiDb: bulanan, tahunan, mingguan, …
  TextColumn get siklus => text().withDefault(const Constant('bulanan'))();
  DateTimeColumn get tanggalMulai => dateTime()();
  BoolColumn get perpanjangOtomatis => boolean().withDefault(const Constant(true))();
  /// `aktif` / `pause` / `berhenti` (StatusLangganan).
  TextColumn get status => text().withDefault(const Constant('aktif'))();
  DateTimeColumn get pauseSejak => dateTime().nullable()();
  DateTimeColumn get pauseSampai => dateTime().nullable()();
  TextColumn get metodeBayar => text().nullable()();
  TextColumn get tautanBayar => text().nullable()();
  DateTimeColumn get terakhirDipakaiPada => dateTime().nullable()();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (id_langganan) & unik (tagihan_id) lewat indeks SQL di `database.dart`.
}

/// Aset milik pengguna (FR-76). Hanya menyimpan angka pengguna; tidak ada
/// saran/produk keuangan di lapisan data (PRD §III-11).
class Aset extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Unik. Pengenal stabil untuk impor/ekspor & sinkron.
  TextColumn get idAset => text()();
  TextColumn get nama => text().withLength(min: 1, max: 120)();
  /// JenisAset: kas / bank / investasi / properti / kendaraan / emas /
  /// kripto / bisnis / lain.
  TextColumn get jenis => text().withDefault(const Constant('kas'))();
  TextColumn get institusi => text().nullable()();
  TextColumn get kodeMataUang => text().withDefault(const Constant('IDR'))();
  /// Nilai saat aset didaftarkan (sen) — dipakai bila belum ada nilai bulanan.
  IntColumn get nilaiAwalSen => integer().withDefault(const Constant(0))();
  /// true = dana siap pakai.
  BoolColumn get likuid => boolean().withDefault(const Constant(true))();
  /// true = disembunyikan; riwayat nilai tetap ada. Dipakai sebagai ganti
  /// hapus selama riwayat masih ada (keputusan rancangan §4.6).
  BoolColumn get arsip => boolean().withDefault(const Constant(false))();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (id_aset) lewat indeks SQL di `database.dart`.
}

/// Kewajiban/utang milik pengguna (FR-76; kolom bunga disiapkan untuk FR-74).
class Kewajiban extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get idKewajiban => text()();
  TextColumn get nama => text().withLength(min: 1, max: 120)();
  /// JenisKewajiban: kartu_kredit / kpr / pinjaman / cicilan / lain.
  TextColumn get jenis => text().withDefault(const Constant('lain'))();
  IntColumn get pokokSen => integer().withDefault(const Constant(0))();
  /// Sisa saat didaftarkan (sen) — dipakai bila belum ada nilai bulanan.
  IntColumn get saldoAwalSen => integer().withDefault(const Constant(0))();
  /// Bukan nilai uang; null = belum diketahui. Tidak dipakai sebelum FR-74.
  RealColumn get sukuBungaPersenTahun => real().nullable()();
  IntColumn get minimumBayarSen => integer().nullable()();
  /// Hari 1–31 dalam bulan (bahan pengingat cicilan, FR-74).
  IntColumn get tanggalJatuhTempoHari => integer().nullable()();
  TextColumn get kodeMataUang => text().withDefault(const Constant('IDR'))();
  BoolColumn get arsip => boolean().withDefault(const Constant(false))();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (id_kewajiban) lewat indeks SQL di `database.dart`.
}

/// Riwayat nilai aset per bulan (FR-76: grafik tren tidak berubah retroaktif).
class NilaiAsetBulanan extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get asetId => integer().references(Aset, #id)();
  /// 'YYYY-MM'.
  TextColumn get bulan => text()();
  IntColumn get nilaiSen => integer()();
  /// `manual` / `dihitung` / `impor`.
  TextColumn get sumber => text().withDefault(const Constant('manual'))();
  /// Unik, mis. `aset:7:2026-09`.
  TextColumn get idempotensi => text()();
  /// true = bulan yang sudah lewat: tidak berubah tanpa permintaan eksplisit.
  BoolColumn get terkunci => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dikunciPada => dateTime().nullable()();
  TextColumn get catatan => text().nullable()();
  /// Jejak bila pengguna membuka kunci (anti kehilangan data: salah ketik
  /// pada bulan lalu tetap bisa diperbaiki, tetapi meninggalkan jejak).
  DateTimeColumn get dibukaKunciPada => dateTime().nullable()();
  TextColumn get alasanBukaKunci => text().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (aset_id, bulan) & unik (idempotensi) lewat indeks SQL.
}

/// Riwayat nilai kewajiban per bulan (bentuk sama dengan [NilaiAsetBulanan]).
///
/// Nilai bersih bulanan TIDAK disimpan — selalu dihitung (aset − kewajiban)
/// pada bulan yang sama, supaya tidak ada dua angka yang bisa tidak sinkron.
class NilaiKewajibanBulanan extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get kewajibanId => integer().references(Kewajiban, #id)();
  TextColumn get bulan => text()();
  IntColumn get nilaiSen => integer()();
  TextColumn get sumber => text().withDefault(const Constant('manual'))();
  /// Unik, mis. `kewajiban:3:2026-09`.
  TextColumn get idempotensi => text()();
  BoolColumn get terkunci => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dikunciPada => dateTime().nullable()();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dibukaKunciPada => dateTime().nullable()();
  TextColumn get alasanBukaKunci => text().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (kewajiban_id, bulan) & unik (idempotensi) lewat indeks SQL.
}
