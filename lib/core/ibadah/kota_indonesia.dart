/// Daftar kota Indonesia + koordinat, untuk FR-86 (Jadwal Sholat).
///
/// SUMBER KOORDINAT: Open-Meteo Geocoding API (https://geocoding-api.open-meteo.com),
/// diambil 13 September 2026, dibulatkan 4 angka di belakang koma (presisi ~11 m —
/// jauh di bawah kebutuhan hitung sudut matahari). Kolom `provinsi` berasal dari
/// field `admin1`. Zona waktu dari field `timezone` (IANA).
///
/// CATATAN: koordinat ini pusat kota, bukan lokasi Anda. Selisih ~0,1 derajat
/// menggeser waktu sekitar 1 menit. Untuk presisi lebih tinggi, pengguna dapat
/// mengisi lintang/bujur sendiri (lihat KotaSholat.kustom).
library;

import 'model_sholat.dart';

/// 49 kota besar Indonesia, diurutkan menurut abjad.
const List<KotaSholat> daftarKotaIndonesia = <KotaSholat>[
  KotaSholat(nama: 'Ambon', provinsi: 'Maluku', lintang: -3.6958, bujur: 128.1833, zona: ZonaIndonesia.wit),
  KotaSholat(nama: 'Balikpapan', provinsi: 'Kalimantan Timur', lintang: -1.2675, bujur: 116.8289, zona: ZonaIndonesia.wita),
  KotaSholat(nama: 'Banda Aceh', provinsi: 'Aceh', lintang: 5.5417, bujur: 95.3333, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Bandarlampung', provinsi: 'Lampung', lintang: -5.4292, bujur: 105.2611, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Bandung', provinsi: 'Jawa Barat', lintang: -6.9222, bujur: 107.6069, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Banjarmasin', provinsi: 'Kalimantan Selatan', lintang: -3.3199, bujur: 114.5907, zona: ZonaIndonesia.wita),
  KotaSholat(nama: 'Batam', provinsi: 'Riau', lintang: 1.1494, bujur: 104.0249, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Bekasi', provinsi: 'Jawa Barat', lintang: -6.2349, bujur: 106.9896, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Bengkulu', provinsi: 'Propinsi Bengkulu', lintang: -3.8004, bujur: 102.2655, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Bogor', provinsi: 'Jawa Barat', lintang: -6.5944, bujur: 106.7892, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Cilegon', provinsi: 'Banten', lintang: -6.0144, bujur: 106.0542, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Cirebon', provinsi: 'Jawa Barat', lintang: -6.7063, bujur: 108.557, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'DI Yogyakarta', provinsi: 'Yogyakarta', lintang: -7.8014, bujur: 110.3647, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Denpasar', provinsi: 'Bali', lintang: -8.65, bujur: 115.2167, zona: ZonaIndonesia.wita),
  KotaSholat(nama: 'Depok', provinsi: 'Jawa Barat', lintang: -6.4, bujur: 106.8186, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Gorontalo', provinsi: 'Propinsi Gorontalo', lintang: 0.5375, bujur: 123.0625, zona: ZonaIndonesia.wita),
  KotaSholat(nama: 'Jakarta', provinsi: 'Jakarta', lintang: -6.2146, bujur: 106.8451, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Jambi', provinsi: 'Jambi', lintang: -1.6, bujur: 103.6167, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Jayapura', provinsi: 'Papua', lintang: -2.5337, bujur: 140.7181, zona: ZonaIndonesia.wit),
  KotaSholat(nama: 'Jember', provinsi: 'Jawa Timur', lintang: -8.1721, bujur: 113.6995, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Kediri', provinsi: 'Jawa Timur', lintang: -7.8167, bujur: 112.0167, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Kendari', provinsi: 'Sulawesi Tenggara', lintang: -3.9778, bujur: 122.5151, zona: ZonaIndonesia.wita),
  KotaSholat(nama: 'Kupang', provinsi: 'Daerah Tingkat I Nusa Tenggara Timur', lintang: -10.1708, bujur: 123.6069, zona: ZonaIndonesia.wita),
  KotaSholat(nama: 'Madiun', provinsi: 'Jawa Timur', lintang: -7.6298, bujur: 111.5239, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Makassar', provinsi: 'Sulawesi Selatan', lintang: -5.1486, bujur: 119.4319, zona: ZonaIndonesia.wita),
  KotaSholat(nama: 'Malang', provinsi: 'Jawa Timur', lintang: -7.9797, bujur: 112.6304, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Manado', provinsi: 'Sulawesi Utara', lintang: 1.4822, bujur: 124.8489, zona: ZonaIndonesia.wita),
  KotaSholat(nama: 'Mataram', provinsi: 'Propinsi Nusa Tenggara Barat', lintang: -8.5833, bujur: 116.1167, zona: ZonaIndonesia.wita),
  KotaSholat(nama: 'Medan', provinsi: 'Daerah Tingkat I Sumatera Utara', lintang: 3.5833, bujur: 98.6667, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Merauke', provinsi: 'Papua Selatan', lintang: -8.4996, bujur: 140.4061, zona: ZonaIndonesia.wit),
  KotaSholat(nama: 'Padang', provinsi: 'Sumatera Barat', lintang: -0.9492, bujur: 100.3543, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Palangka Raya', provinsi: 'Kalimantan Tengah', lintang: -2.2083, bujur: 113.9167, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Palembang', provinsi: 'Sumatera Selatan', lintang: -2.9167, bujur: 104.7458, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Palu', provinsi: 'Sulawesi Tengah', lintang: -0.9083, bujur: 119.8708, zona: ZonaIndonesia.wita),
  KotaSholat(nama: 'Pangkalpinang', provinsi: 'Kepulauan Bangka Belitung', lintang: -2.1291, bujur: 106.1138, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Pekanbaru', provinsi: 'Riau', lintang: 0.5167, bujur: 101.4417, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Pontianak', provinsi: 'Kalimantan Barat', lintang: -0.0319, bujur: 109.325, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Purwokerto', provinsi: 'Jawa Tengah', lintang: -7.4214, bujur: 109.2344, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Samarinda', provinsi: 'Kalimantan Timur', lintang: -0.4917, bujur: 117.1458, zona: ZonaIndonesia.wita),
  KotaSholat(nama: 'Semarang', provinsi: 'Jawa Tengah', lintang: -6.9931, bujur: 110.4208, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Serang', provinsi: 'Banten', lintang: -6.1153, bujur: 106.1542, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Sorong', provinsi: 'Papua Barat Daya', lintang: -0.8796, bujur: 131.2611, zona: ZonaIndonesia.wit),
  KotaSholat(nama: 'Surabaya', provinsi: 'Jawa Timur', lintang: -7.2492, bujur: 112.7508, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Surakarta', provinsi: 'Jawa Tengah', lintang: -7.5561, bujur: 110.8317, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Tangerang', provinsi: 'Banten', lintang: -6.1781, bujur: 106.63, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Tanjungpinang', provinsi: 'Kalimantan Timur', lintang: -2.2553, bujur: 115.9022, zona: ZonaIndonesia.wita),
  KotaSholat(nama: 'Tasikmalaya', provinsi: 'Jawa Barat', lintang: -7.3274, bujur: 108.2207, zona: ZonaIndonesia.wib),
  KotaSholat(nama: 'Ternate', provinsi: 'Maluku Utara', lintang: 0.7906, bujur: 127.3842, zona: ZonaIndonesia.wit),
];

/// Pencarian kota menurut nama (tanpa memperhatikan huruf besar/kecil).
List<KotaSholat> cariKota(String kata) {
  final k = kata.trim().toLowerCase();
  if (k.isEmpty) return daftarKotaIndonesia;
  return daftarKotaIndonesia
      .where((KotaSholat kota) =>
          kota.nama.toLowerCase().contains(k) ||
          kota.provinsi.toLowerCase().contains(k))
      .toList();
}
