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

  /// Kunci tetap antar perangkat (sinkron FR-150). Nullable supaya baris lama
  /// bisa diisi saat migrasi tanpa mengganggu data pengguna.
  TextColumn get uid => text().nullable()();
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


// ---------------------------------------------------------------------------
// SKEMA v4 — PILAR KEHIDUPAN (V2), ditambahkan Dinda 15 Sep 2026
// ---------------------------------------------------------------------------
//
// Aturan yang dipegang di seluruh blok ini:
//  1. Tabel BARU saja — tidak ada kolom tabel lama yang diubah, jadi migrasi
//     v3 -> v4 tidak pernah menyentuh data pengguna.
//  2. Tidak ada tabel yang menyimpan nilai turunan yang bisa dihitung
//     (mis. durasi tidur, total air harian) kecuali bila nilainya ditulis
//     pengguna sendiri dan harus bertahan apa adanya (mis. `durasiMenit` tidur
//     disimpan karena jam tidur bisa lintas tengah malam & pengguna boleh
//     mengoreksi hasil hitungan).
//  3. Nilai uang selalu bilangan bulat dalam satuan terkecil (sen).
//  4. Nilai kesehatan memakai `real` supaya berat 72,5 kg tidak dibulatkan.
//  5. Setiap kolom yang dipakai untuk "satu baris per kunci bisnis" diberi
//     indeks UNIK lewat SQL di `database.dart` (gaya PB-05/PB-07), bukan
//     anotasi tabel, supaya jaminan tetap ada walau `database.g.dart`
//     diregenerasi.

// =========================== AKSI & TUJUAN (FR-78/79/80/83) ================

/// Visi (FR-82) — puncak rantai: Visi -> Area hidup -> Tujuan -> Proyek -> Tugas.
///
/// Vision boleh kosong: aplikasi tidak memaksa pengguna menulis visi dulu
/// sebelum bisa mencatat tujuan. Menghapus visi **tidak** menghapus isi di
/// bawahnya (area hanya dilepas) — itu yang dijaga repository.
class Visi extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Pengenal stabil untuk impor/ekspor & sinkron. Unik.
  TextColumn get idVisi => text()();
  TextColumn get nama => text().withLength(min: 1, max: 160)();
  TextColumn get keterangan => text().nullable()();
  /// aktif / tercapai / arsip.
  TextColumn get status => text().withDefault(const Constant('aktif'))();
  IntColumn get urutan => integer().withDefault(const Constant(0))();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (id_visi) lewat indeks SQL di `database.dart`.
}

/// Area hidup (FR-82) — lapisan antara visi dan tujuan.
///
/// `visiId` boleh null: area bisa berdiri tanpa visi, dan melepas visi tidak
/// menghapus area.
class AreaHidup extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get idArea => text()();
  IntColumn get visiId => integer().nullable().references(Visi, #id)();
  TextColumn get nama => text().withLength(min: 1, max: 120)();
  TextColumn get keterangan => text().nullable()();
  BoolColumn get aktif => boolean().withDefault(const Constant(true))();
  IntColumn get urutan => integer().withDefault(const Constant(0))();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (id_area) lewat indeks SQL di `database.dart`.
}

/// Tujuan (FR-78) — puncak rantai Goal -> Project -> Task.
///
/// `targetAngka` + `satuan` dipakai untuk tujuan terukur (mis. 12 buku/bulan);
/// `targetTeks` untuk tujuan yang tidak berupa angka. Keduanya boleh kosong:
/// aplikasi tidak memaksa pengguna mengukur hidupnya dengan angka.
class Tujuan extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Pengenal stabil untuk impor/ekspor & sinkron. Unik.
  TextColumn get idTujuan => text()();
  TextColumn get nama => text().withLength(min: 1, max: 120)();
  /// Area hidup: pribadi / keluarga / kerja / keuangan / ibadah / kesehatan.
  TextColumn get area => text().withDefault(const Constant('pribadi'))();
  /// Penyambung ke tabel `area_hidup` (FR-82). null = belum disambungkan;
  /// tujuan lama tidak kehilangan apa pun saat kolom ini ditambahkan.
  IntColumn get areaId => integer().nullable().references(AreaHidup, #id)();
  TextColumn get targetTeks => text().nullable()();
  IntColumn get targetAngka => integer().nullable()();
  TextColumn get satuan => text().nullable()();
  DateTimeColumn get tanggalTarget => dateTime().nullable()();
  /// aktif / tercapai / dijeda / arsip.
  TextColumn get status => text().withDefault(const Constant('aktif'))();
  IntColumn get urutan => integer().withDefault(const Constant(0))();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get selesaiPada => dateTime().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (id_tujuan) lewat indeks SQL di `database.dart`.
}

/// Proyek (FR-78) — kumpulan tugas di bawah satu tujuan.
///
/// `tujuanId` boleh null: proyek boleh berdiri sendiri. Menghapus tujuan tidak
/// menghapus proyek (kolom ini disetel null oleh repository), supaya pekerjaan
/// pengguna tidak hilang karena satu salah ketuk.
class Proyek extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get idProyek => text()();
  IntColumn get tujuanId => integer().nullable().references(Tujuan, #id)();
  TextColumn get nama => text().withLength(min: 1, max: 120)();
  TextColumn get catatan => text().nullable()();
  /// aktif / selesai / dijeda / arsip.
  TextColumn get status => text().withDefault(const Constant('aktif'))();
  DateTimeColumn get tenggat => dateTime().nullable()();
  IntColumn get urutan => integer().withDefault(const Constant(0))();
  DateTimeColumn get selesaiPada => dateTime().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (id_proyek) lewat indeks SQL di `database.dart`.
}

/// Tugas (FR-78/79) — satuan pekerjaan terkecil; boleh menempel ke proyek,
/// langsung ke tujuan, atau berdiri sendiri (tugas cepat FR-79).
class Tugas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get idTugas => text()();
  IntColumn get tujuanId => integer().nullable().references(Tujuan, #id)();
  IntColumn get proyekId => integer().nullable().references(Proyek, #id)();
  TextColumn get nama => text().withLength(min: 1, max: 200)();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get jatuhTempo => dateTime().nullable()();
  /// Jam pengingat "HH:mm"; null = tanpa jam (pengingat memakai jam bawaan).
  TextColumn get jamPengingat => text().nullable()();
  /// sekali / harian / mingguan / bulanan / kustom_hari (memakai mesin
  /// tagihan agar tidak ada dua mesin pengulangan di aplikasi).
  TextColumn get frekuensi => text().withDefault(const Constant('sekali'))();
  IntColumn get kustomHariN => integer().nullable()();
  TextColumn get prioritas => text().withDefault(const Constant('biasa'))();
  /// Lead days notifikasi, teks "1,0". "0" = pada hari itu.
  TextColumn get pengingatLeadHari => text().withDefault(const Constant('1'))();
  TextColumn get kanalPengingat => text().withDefault(const Constant('push'))();
  BoolColumn get selesai => boolean().withDefault(const Constant(false))();
  DateTimeColumn get selesaiPada => dateTime().nullable()();
  IntColumn get urutan => integer().withDefault(const Constant(0))();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (id_tugas) lewat indeks SQL di `database.dart`.
}

/// Kebiasaan (FR-80) — maksimal 5 yang dipromosikan ke Today (dijaga di
/// lapisan fitur, bukan di basis data, supaya pengguna tidak terkunci).
class Kebiasaan extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get idKebiasaan => text()();
  TextColumn get nama => text().withLength(min: 1, max: 120)();
  TextColumn get ikon => text().withDefault(const Constant('repeat'))();
  TextColumn get warna => text().withDefault(const Constant('#4A90D9'))();
  /// Target berapa kali per minggu (1–7). Bukan hukuman bila tidak tercapai.
  IntColumn get targetPerMinggu => integer().withDefault(const Constant(7))();
  /// true = tampil di Today (maksimal 5 baris, diatur lapisan fitur).
  BoolColumn get dipromosikan => boolean().withDefault(const Constant(false))();
  BoolColumn get aktif => boolean().withDefault(const Constant(true))();
  IntColumn get urutan => integer().withDefault(const Constant(0))();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (id_kebiasaan) lewat indeks SQL di `database.dart`.
}

/// Riwayat kebiasaan per hari (FR-80) — satu baris per kebiasaan per tanggal.
///
/// `nilai` berupa pecahan (0,0–1,0) supaya kebiasaan "minum 8 gelas" bisa
/// dicatat setengah jalan tanpa memaksa selesai/belum.
class LogKebiasaan extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get kebiasaanId => integer().references(Kebiasaan, #id)();
  DateTimeColumn get tanggal => dateTime()();
  RealColumn get nilai => real().withDefault(const Constant(1))();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dicatatPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (kebiasaan_id, tanggal) lewat indeks SQL di `database.dart`.
}

/// Perawatan berkala (FR-83) — oli, servis AC, pajak, filter, ulang tahun.
///
/// `berikutnya` disimpan (bukan selalu dihitung) karena pengguna boleh
/// menetapkan tanggal yang berbeda dari hasil hitungan interval.
class Perawatan extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nama => text().withLength(min: 1, max: 120)();
  /// kendaraan / rumah / dokumen / keluarga / perangkat / lain.
  TextColumn get kategori => text().withDefault(const Constant('lain'))();
  IntColumn get intervalHari => integer().withDefault(const Constant(365))();
  DateTimeColumn get terakhirDilakukan => dateTime().nullable()();
  DateTimeColumn get berikutnya => dateTime()();
  /// Kode template bawaan (mis. `oli_mobil`); null = dibuat pengguna sendiri.
  TextColumn get templateKode => text().nullable()();
  /// Lead days notifikasi, teks "7,1".
  TextColumn get leadHari => text().withDefault(const Constant('7,1'))();
  IntColumn get urutan => integer().withDefault(const Constant(0))();
  TextColumn get kanalPengingat => text().withDefault(const Constant('push'))();
  BoolColumn get aktif => boolean().withDefault(const Constant(true))();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();
}

// =========================== KESEHATAN (FR-101/102/103/106/111) ===========
//
// Prinsip modul (PRD §7.4): aplikasi MENCATAT & MENUNJUKKAN TREN, tidak
// mendiagnosis. Tidak ada kolom "status bahaya", tidak ada saran dosis.

/// Satu angka tubuh yang dicatat pengguna (FR-101): berat, tekanan darah,
/// lingkar perut, gula darah, dst. Satuan disimpan apa adanya.
class UkuranTubuh extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// berat / sistolik / diastolik / lingkar_perut / gula_darah / suhu / lain.
  TextColumn get jenis => text()();
  RealColumn get nilai => real()();
  TextColumn get satuan => text().withDefault(const Constant('kg'))();
  DateTimeColumn get tanggal => dateTime()();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dicatatPada => dateTime().withDefault(currentDateAndTime)();
}

/// Aktivitas fisik (FR-102).
class Aktivitas extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// jalan / lari / sepeda / renang / gym / peregangan / olahraga / rumah.
  TextColumn get jenis => text()();
  IntColumn get durasiMenit => integer()();
  /// Jarak dalam km; boleh kosong untuk aktivitas tanpa jarak.
  RealColumn get jarakKm => real().nullable()();
  /// ringan / sedang / berat.
  TextColumn get intensitas => text().withDefault(const Constant('sedang'))();
  DateTimeColumn get tanggal => dateTime()();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dicatatPada => dateTime().withDefault(currentDateAndTime)();
}

/// Tidur (FR-103) — satu baris per "malam" (tanggal bangun).
///
/// `durasiMenit` disimpan karena dihitung sekali dari jam tidur & jam bangun
/// (termasuk lintas tengah malam) lalu boleh dikoreksi pengguna.
class Tidur extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Tanggal (hari bangun) — kunci "satu catatan per malam".
  DateTimeColumn get tanggal => dateTime()();
  DateTimeColumn get jamTidur => dateTime()();
  DateTimeColumn get jamBangun => dateTime()();
  IntColumn get durasiMenit => integer()();
  /// Kualitas 1–5 (persepsi pengguna, bukan penilaian aplikasi); null = tidak diisi.
  IntColumn get kualitas => integer().nullable()();
  IntColumn get tidurSiangMenit => integer().withDefault(const Constant(0))();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dicatatPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (tanggal) lewat indeks SQL di `database.dart`.
}

/// Obat/vitamin (FR-106). `dosisTeks` diambil apa adanya dari label/kemasan —
/// aplikasi TIDAK menghitung atau menyarankan dosis.
class Obat extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nama => text().withLength(min: 1, max: 120)();
  TextColumn get dosisTeks => text().nullable()();
  IntColumn get jumlahPerMinum => integer().withDefault(const Constant(1))();
  /// tablet / kapsul / ml / tetes / sachet / lain.
  TextColumn get satuan => text().withDefault(const Constant('tablet'))();
  DateTimeColumn get mulai => dateTime().nullable()();
  DateTimeColumn get selesai => dateTime().nullable()();
  BoolColumn get aktif => boolean().withDefault(const Constant(true))();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();
  /// FR-107: sisa obat di rumah (dalam satuan di atas). null = belum diisi.
  IntColumn get sisa => integer().nullable()();
  DateTimeColumn get sisaDiperbaruiPada => dateTime().nullable()();
}

/// Jam minum obat (FR-106) — satu baris per jam, mis. 08:00 dan 20:00.
class JadwalObat extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get obatId => integer().references(Obat, #id)();
  /// "HH:mm".
  TextColumn get jam => text()();
  BoolColumn get aktif => boolean().withDefault(const Constant(true))();
  IntColumn get urutan => integer().withDefault(const Constant(0))();
}

/// Catatan "sudah diminum" (FR-106) — satu baris per jadwal per waktu rencana.
class MinumObat extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get obatId => integer().references(Obat, #id)();
  IntColumn get jadwalId => integer().nullable().references(JadwalObat, #id)();
  DateTimeColumn get waktuRencana => dateTime()();
  DateTimeColumn get waktuMinum => dateTime().nullable()();
  /// diminum / ditunda / dilewati. Bukan penilaian: hanya keadaan catatan.
  TextColumn get status => text().withDefault(const Constant('diminum'))();
  TextColumn get catatan => text().nullable()();

  // Unik (obat_id, waktu_rencana) lewat indeks SQL di `database.dart`.
}

/// Pencatat air (FR-111) — satu baris per gelas/botol; total harian dihitung.
class CatatanAir extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get waktu => dateTime()();
  IntColumn get jumlahMl => integer().withDefault(const Constant(250))();
  TextColumn get catatan => text().nullable()();
}

// =========================== DOKUMEN (FR-128/129) =========================

/// Brankas dokumen (FR-128) + masa berlaku (FR-129).
///
/// `berkasNama` = nama berkas DI DALAM folder aplikasi (bukan path penuh),
/// supaya cadangan/pemulihan di perangkat lain tetap bisa menemukannya.
class Dokumen extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get idDokumen => text()();
  TextColumn get nama => text().withLength(min: 1, max: 120)();
  /// ktp / kk / paspor / sim / stnk / sertifikat / ijazah / kontrak / polis /
  /// anak / lain.
  TextColumn get jenis => text().withDefault(const Constant('lain'))();
  TextColumn get nomor => text().nullable()();
  /// Nama pemilik dokumen (untuk dokumen anggota keluarga).
  TextColumn get pemilik => text().nullable()();
  DateTimeColumn get terbit => dateTime().nullable()();
  DateTimeColumn get berlakuSampai => dateTime().nullable()();
  TextColumn get berkasNama => text().nullable()();
  TextColumn get catatan => text().nullable()();
  /// Lead days berlapis FR-129, teks "90,30,7,1".
  TextColumn get leadHari => text().withDefault(const Constant('90,30,7,1'))();
  TextColumn get kanalPengingat => text().withDefault(const Constant('push'))();
  BoolColumn get aktif => boolean().withDefault(const Constant(true))();
  BoolColumn get arsip => boolean().withDefault(const Constant(false))();
  /// Kapan terakhir ditandai "sudah diperpanjang" (jejak, bukan penilaian).
  DateTimeColumn get diperpanjangPada => dateTime().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (id_dokumen) lewat indeks SQL di `database.dart`.
}

// =========================== PLATFORM (FR-136/137/138/139/147/148) ========

/// Audit log lokal (FR-138) — mencatat perubahan angka penting.
///
/// Lokal, tanpa telemetri. `nilaiSebelum`/`nilaiSesudah` disimpan sebagai teks
/// supaya bisa memuat nominal, tanggal, atau status tanpa kolom tambahan.
class AuditLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get waktu => dateTime()();
  /// tagihan / transaksi / langganan / aset / kewajiban / tugas / kesehatan /
  /// dokumen / pengaturan / notifikasi / lain.
  TextColumn get modul => text()();
  /// buat / ubah / hapus / tandai / tunda / pulihkan / ekspor / impor.
  TextColumn get aksi => text()();
  TextColumn get entitas => text().nullable()();
  TextColumn get entitasId => text().nullable()();
  TextColumn get nilaiSebelum => text().nullable()();
  TextColumn get nilaiSesudah => text().nullable()();
  /// Kalimat siap tampil, mis. "Tagihan #18 ditandai lunas".
  TextColumn get ringkas => text()();
  /// sumber: layar / pengingat / kerja_latar / impor.
  TextColumn get sumber => text().withDefault(const Constant('layar'))();
}

/// Riwayat notifikasi (FR-147) — untuk Notification Center.
class NotifikasiRiwayat extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pengingatId => integer().nullable()();
  DateTimeColumn get waktu => dateTime()();
  /// mendesak / penting / biasa.
  TextColumn get tingkat => text().withDefault(const Constant('biasa'))();
  TextColumn get kanal => text().withDefault(const Constant('push'))();
  TextColumn get judul => text()();
  TextColumn get isi => text()();
  /// baru / dibaca / selesai / ditunda.
  TextColumn get status => text().withDefault(const Constant('baru'))();
  DateTimeColumn get selesaiPada => dateTime().nullable()();
  /// Modul asal: tagihan / sholat / briefing / tugas / obat / dokumen / lain.
  TextColumn get sumber => text().withDefault(const Constant('lain'))();
}

/// Penundaan pengingat (FR-148).
///
/// **Jatuh tempo asli tidak pernah diubah** oleh tabel ini — hanya waktu
/// pengingat yang ditunda. Satu baris per pengingat (ditunda lagi = diperbarui).
class TundaPengingat extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pengingatId => integer()();
  DateTimeColumn get kapan => dateTime()();
  TextColumn get alasan => text().nullable()();
  /// Berapa kali pengingat ini sudah ditunda (batas dijaga lapisan fitur).
  IntColumn get jumlahTunda => integer().withDefault(const Constant(1))();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (pengingat_id) lewat indeks SQL di `database.dart`.
}

// =========================== UANG LANJUTAN (FR-73/74/75/77) ===============

/// Pembayaran kewajiban/utang (FR-74) — memisahkan pokok & bunga.
class PembayaranKewajiban extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get kewajibanId => integer().references(Kewajiban, #id)();
  DateTimeColumn get tanggal => dateTime()();
  IntColumn get jumlahSen => integer()();
  /// Bagian pokok (mengurangi sisa utang) — boleh 0 bila skema bunga dulu.
  IntColumn get pokokSen => integer().withDefault(const Constant(0))();
  IntColumn get bungaSen => integer().withDefault(const Constant(0))();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dicatatPada => dateTime().withDefault(currentDateAndTime)();
}

/// Pengeluaran terencana (FR-73) — uang yang HARUS tersedia sebelum tanggal
/// tertentu, tetapi belum menjadi transaksi.
class PengeluaranTerencana extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nama => text().withLength(min: 1, max: 120)();
  IntColumn get jumlahSen => integer()();
  DateTimeColumn get tanggal => dateTime()();
  IntColumn get kategoriId => integer().nullable()();
  TextColumn get catatan => text().nullable()();
  BoolColumn get aktif => boolean().withDefault(const Constant(true))();
  BoolColumn get sudahTerjadi => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
}

// =========================== IBADAH LANJUTAN (FR-91/92/93/95/100) =========

/// Pelacakan puasa (FR-92) — satu baris per tanggal per jenis puasa.
class LogPuasa extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get tanggal => dateTime()();
  /// ramadan / senin_kamis / ayyamul_bidh / sunnah / qadha / custom.
  TextColumn get jenis => text()();
  /// puasa / tidak. "tidak" dicatat apa adanya, tanpa penilaian.
  TextColumn get status => text().withDefault(const Constant('puasa'))();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dicatatPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (tanggal, jenis) lewat indeks SQL di `database.dart`.
}

/// Pelacakan Quran (FR-93) — baca, dengar, hafal baru, murajaah.
class LogQuran extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get tanggal => dateTime()();
  /// baca / dengar / hafal / murajaah.
  TextColumn get jenis => text()();
  RealColumn get jumlah => real().withDefault(const Constant(0))();
  /// halaman / ayat / menit / juz.
  TextColumn get satuan => text().withDefault(const Constant('halaman'))();
  /// Surah/ayat bila pengguna mengisi (mis. "Al-Baqarah 1-5").
  TextColumn get bagian => text().nullable()();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dicatatPada => dateTime().withDefault(currentDateAndTime)();
}

/// Dzikir & doa (FR-95) — penghitung per sesi.
class LogDzikir extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get tanggal => dateTime()();
  /// pagi / petang / sebelum_tidur / custom.
  TextColumn get jenis => text()();
  TextColumn get nama => text().withLength(min: 1, max: 120)();
  IntColumn get target => integer().withDefault(const Constant(33))();
  IntColumn get tercatat => integer().withDefault(const Constant(0))();
  DateTimeColumn get selesaiPada => dateTime().nullable()();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dicatatPada => dateTime().withDefault(currentDateAndTime)();
}

/// Refleksi malam / muhasabah (FR-100) — satu baris per tanggal.
///
/// Semua kolom bernilai "sudah/belum saya lakukan hari ini" dari sudut pandang
/// pengguna, BUKAN penilaian aplikasi. Tidak ada kolom skor.
class RefleksiMuhasabah extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get tanggal => dateTime()();
  /// Lima daftar refleksi bawaan PRD; null = tidak diisi (bukan berarti tidak).
  BoolColumn get sholatTerjaga => boolean().nullable()();
  BoolColumn get mengingatAllah => boolean().nullable()();
  BoolColumn get membantuOrang => boolean().nullable()();
  BoolColumn get menghindariDisesali => boolean().nullable()();
  BoolColumn get belajar => boolean().nullable()();
  BoolColumn get bersyukur => boolean().nullable()();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dicatatPada => dateTime().withDefault(currentDateAndTime)();

  // Unik (tanggal) lewat indeks SQL di `database.dart`.
}


/// Catatan perubahan lokal yang belum terkirim (pola "outbox", FR-150).
///
/// Setiap tambah/ubah/hapus mencatatkan satu penanda. Penanda dibersihkan
/// HANYA setelah server menerima, jadi tidak ada perubahan yang bisa terlewat
/// — dan baris yang sudah dihapus tidak mungkin "hidup lagi" di HP lain.
class SinkronKotor extends Table {
  TextColumn get tabel => text()();
  TextColumn get uid => text()();

  /// true = baris ini dihapus di perangkat ini.
  BoolColumn get hapus => boolean().withDefault(const Constant(false))();
  DateTimeColumn get waktu => dateTime()();

  @override
  Set<Column> get primaryKey => {tabel, uid};
}

/// FR-105 — Jurnal kesehatan berbentuk angka (tekanan darah, gula darah, dst).
///
/// Menyimpan ANGKA apa adanya + satuan yang dipakai pengguna. Aplikasi hanya
/// menampilkan tren, tidak menafsirkan sebagai diagnosis.
class CatatanKesehatan extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// tekanan_darah · detak_jantung · gula_darah · suhu · saturasi · kolesterol · lab
  TextColumn get jenis => text()();
  DateTimeColumn get waktu => dateTime()();

  /// Nilai utama (mis. sistolik, atau angka tunggal).
  RealColumn get nilai => real()();

  /// Nilai kedua bila jenisnya berpasangan (mis. diastolik).
  RealColumn get nilaiKedua => real().nullable()();

  /// Satuan yang dipakai pengguna (mis. mmHg, mg/dL) — disimpan apa adanya.
  TextColumn get satuan => text().withDefault(const Constant(''))();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
}

/// FR-109 — Janji dokter / tes lab / kontrol, dengan pengingat 7 hari, 1 hari,
/// dan 2 jam sebelum jadwal.
class JanjiKesehatan extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get judul => text()();

  /// kontrol · lab · vaksin · gigi · lain
  TextColumn get jenis => text().withDefault(const Constant('kontrol'))();
  DateTimeColumn get waktu => dateTime()();
  TextColumn get tempat => text().nullable()();
  TextColumn get catatan => text().nullable()();
  BoolColumn get selesai => boolean().withDefault(const Constant(false))();

  /// Lead hari yang dipakai (mis. "7,1"); 2 jam sebelum diatur lewat saklar.
  TextColumn get pengingatHari => text().withDefault(const Constant('7,1'))();
  BoolColumn get ingatkanDuaJam =>
      boolean().withDefault(const Constant(true))();
  TextColumn get jamPengingat => text().withDefault(const Constant('08:00'))();

  /// Pengenal stabil untuk sinkron antar perangkat.
  TextColumn get uid => text().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();
}

/// FR-51 — Catatan kas & utang informal (warung, kontrakan, utang-piutang, COD).
class KasInformal extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// utang (kita berutang) · piutang (orang berutang) · tunai (catatan kas)
  TextColumn get jenis => text()();

  /// Nama warung/orang tempat berutang.
  TextColumn get pihak => text()();
  DateTimeColumn get tanggal => dateTime()();
  IntColumn get jumlahSen => integer()();
  TextColumn get kodeMataUang => text().withDefault(const Constant('IDR'))();
  BoolColumn get lunas => boolean().withDefault(const Constant(false))();
  DateTimeColumn get tanggalLunas => dateTime().nullable()();
  DateTimeColumn get jatuhTempo => dateTime().nullable()();
  TextColumn get catatan => text().nullable()();
  TextColumn get uid => text().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();
}

/// FR-94 — Pelacakan hafalan (hifz): baru, murajaah, perlu diulang.
class Hafalan extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// juz · surah
  TextColumn get jenis => text().withDefault(const Constant('surah'))();
  TextColumn get nama => text()();
  IntColumn get nomor => integer().nullable()();

  /// baru · murajaah · perlu_diulang · kuat
  TextColumn get status => text().withDefault(const Constant('baru'))();
  DateTimeColumn get terakhir => dateTime()();

  /// Aturan ulangan pilihan pengguna (hari). 0 = tidak dijadwalkan ulang.
  IntColumn get ulangSetiapHari => integer().withDefault(const Constant(7))();
  TextColumn get catatan => text().nullable()();
  TextColumn get uid => text().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();
}

/// FR-96 — Zakat & sedekah: catatan infaq/sedekah (perhitungan zakat memakai
/// aset yang sudah ada + acuan nisab yang diisi pengguna).
class ZakatSedekah extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// zakat_maal · zakat_fitrah · infaq · sedekah · wakaf
  TextColumn get jenis => text()();
  DateTimeColumn get tanggal => dateTime()();
  IntColumn get jumlahSen => integer()();
  TextColumn get kodeMataUang => text().withDefault(const Constant('IDR'))();
  TextColumn get penerima => text().nullable()();
  TextColumn get catatan => text().nullable()();
  TextColumn get uid => text().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();
}
