/// Daftar kategori kas bawaan (FR-71/FR-72) — satu sumber untuk seed database.
///
/// Sumber isi: `rancangan/KATEGORI_KEUANGAN_ID.md` (Dinda) — 11 kategori
/// pengeluaran wajib FR-71 + 12 kategori pemasukan, berikut ikon Material dan
/// warna palet Material 600 yang sudah ia verifikasi ke SDK Flutter.
///
/// SUB-KATEGORI (130 butir di rancangan) **belum** di-seed di V1.5: kolom
/// `KategoriTransaksi.indukKode` sudah siap, dan daftar sub bisa ditambahkan
/// tanpa migrasi baru karena seed bersifat idempoten (kunci = `kode`).
library;

class TemplateKategoriTransaksi {
  const TemplateKategoriTransaksi({
    required this.kode,
    required this.nama,
    required this.jenis,
    required this.ikon,
    required this.warna,
    required this.sifatArus,
    required this.urutan,
  });

  /// Kunci stabil (mis. `kel_makan`) — juga dipakai impor/ekspor.
  final String kode;
  final String nama;

  /// `pengeluaran` / `pemasukan` (nilai `JenisArus`).
  final String jenis;

  /// Nama ikon Material.
  final String ikon;

  /// Heks warna.
  final String warna;

  /// `berulang` / `sekali` / `campuran` (nilai `SifatArus`).
  final String sifatArus;
  final int urutan;
}

/// 23 kategori bawaan: 11 pengeluaran (urutan 0–10) + 12 pemasukan (0–11).
const List<TemplateKategoriTransaksi> daftarKategoriTransaksi = [
  // --- Pengeluaran (11) — wajib FR-71 ---
  TemplateKategoriTransaksi(
      kode: 'kel_tempat_tinggal',
      nama: 'Tempat Tinggal',
      jenis: 'pengeluaran',
      ikon: 'home',
      warna: '#6D4C41',
      sifatArus: 'berulang',
      urutan: 0),
  TemplateKategoriTransaksi(
      kode: 'kel_makan',
      nama: 'Makan & Minum',
      jenis: 'pengeluaran',
      ikon: 'restaurant',
      warna: '#F4511E',
      sifatArus: 'campuran',
      urutan: 1),
  TemplateKategoriTransaksi(
      kode: 'kel_transportasi',
      nama: 'Transportasi',
      jenis: 'pengeluaran',
      ikon: 'directions_bus',
      warna: '#43A047',
      sifatArus: 'campuran',
      urutan: 2),
  TemplateKategoriTransaksi(
      kode: 'kel_pendidikan',
      nama: 'Pendidikan',
      jenis: 'pengeluaran',
      ikon: 'school',
      warna: '#7CB342',
      sifatArus: 'campuran',
      urutan: 3),
  TemplateKategoriTransaksi(
      kode: 'kel_keluarga',
      nama: 'Keluarga',
      jenis: 'pengeluaran',
      ikon: 'family_restroom',
      warna: '#D81B60',
      sifatArus: 'campuran',
      urutan: 4),
  TemplateKategoriTransaksi(
      kode: 'kel_hiburan',
      nama: 'Hiburan',
      jenis: 'pengeluaran',
      ikon: 'movie',
      warna: '#8E24AA',
      sifatArus: 'campuran',
      urutan: 5),
  TemplateKategoriTransaksi(
      kode: 'kel_kesehatan',
      nama: 'Kesehatan',
      jenis: 'pengeluaran',
      ikon: 'health_and_safety',
      warna: '#E53935',
      sifatArus: 'campuran',
      urutan: 6),
  TemplateKategoriTransaksi(
      kode: 'kel_utang',
      nama: 'Utang & Cicilan',
      jenis: 'pengeluaran',
      ikon: 'credit_card',
      warna: '#546E7A',
      sifatArus: 'berulang',
      urutan: 7),
  TemplateKategoriTransaksi(
      kode: 'kel_belanja',
      nama: 'Belanja',
      jenis: 'pengeluaran',
      ikon: 'shopping_bag',
      warna: '#3949AB',
      sifatArus: 'campuran',
      urutan: 8),
  TemplateKategoriTransaksi(
      kode: 'kel_bisnis',
      nama: 'Bisnis',
      jenis: 'pengeluaran',
      ikon: 'business_center',
      warna: '#1E88E5',
      sifatArus: 'campuran',
      urutan: 9),
  TemplateKategoriTransaksi(
      kode: 'kel_lain',
      nama: 'Pengeluaran Lain',
      jenis: 'pengeluaran',
      ikon: 'receipt_long',
      warna: '#757575',
      sifatArus: 'campuran',
      urutan: 10),

  // --- Pemasukan (12) ---
  TemplateKategoriTransaksi(
      kode: 'masuk_gaji',
      nama: 'Gaji',
      jenis: 'pemasukan',
      ikon: 'payments',
      warna: '#1E88E5',
      sifatArus: 'berulang',
      urutan: 0),
  TemplateKategoriTransaksi(
      kode: 'masuk_thr_bonus',
      nama: 'THR & Bonus',
      jenis: 'pemasukan',
      ikon: 'card_giftcard',
      warna: '#5E35B1',
      sifatArus: 'sekali',
      urutan: 1),
  TemplateKategoriTransaksi(
      kode: 'masuk_usaha',
      nama: 'Usaha',
      jenis: 'pemasukan',
      ikon: 'storefront',
      warna: '#FB8C00',
      sifatArus: 'campuran',
      urutan: 2),
  TemplateKategoriTransaksi(
      kode: 'masuk_freelance',
      nama: 'Freelance & Proyek',
      jenis: 'pemasukan',
      ikon: 'laptop_mac',
      warna: '#00897B',
      sifatArus: 'campuran',
      urutan: 3),
  TemplateKategoriTransaksi(
      kode: 'masuk_investasi',
      nama: 'Hasil Investasi',
      jenis: 'pemasukan',
      ikon: 'trending_up',
      warna: '#3949AB',
      sifatArus: 'campuran',
      urutan: 4),
  TemplateKategoriTransaksi(
      kode: 'masuk_sewa',
      nama: 'Sewa & Kontrakan',
      jenis: 'pemasukan',
      ikon: 'home_work',
      warna: '#6D4C41',
      sifatArus: 'berulang',
      urutan: 5),
  TemplateKategoriTransaksi(
      kode: 'masuk_hadiah',
      nama: 'Hadiah & Pemberian',
      jenis: 'pemasukan',
      ikon: 'redeem',
      warna: '#D81B60',
      sifatArus: 'sekali',
      urutan: 6),
  TemplateKategoriTransaksi(
      kode: 'masuk_jual_aset',
      nama: 'Penjualan Aset',
      jenis: 'pemasukan',
      ikon: 'sell',
      warna: '#FFB300',
      sifatArus: 'sekali',
      urutan: 7),
  TemplateKategoriTransaksi(
      kode: 'masuk_pinjaman',
      nama: 'Pinjaman Diterima',
      jenis: 'pemasukan',
      ikon: 'account_balance',
      warna: '#546E7A',
      sifatArus: 'sekali',
      urutan: 8),
  TemplateKategoriTransaksi(
      kode: 'masuk_beasiswa',
      nama: 'Beasiswa & Bantuan',
      jenis: 'pemasukan',
      ikon: 'volunteer_activism',
      warna: '#7CB342',
      sifatArus: 'campuran',
      urutan: 9),
  TemplateKategoriTransaksi(
      kode: 'masuk_pencairan',
      nama: 'Pencairan Dana',
      jenis: 'pemasukan',
      ikon: 'account_balance_wallet',
      warna: '#00ACC1',
      sifatArus: 'sekali',
      urutan: 10),
  TemplateKategoriTransaksi(
      kode: 'masuk_lain',
      nama: 'Pemasukan Lain',
      jenis: 'pemasukan',
      ikon: 'category',
      warna: '#757575',
      sifatArus: 'campuran',
      urutan: 11),
];
