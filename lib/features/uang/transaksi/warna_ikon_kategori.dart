/// Peta nama ikon & warna kategori arus kas (FR-71).
///
/// Nilai disimpan sebagai teks di tabel `kategori_transaksi` (`ikon`, `warna`),
/// jadi berkas ini menerjemahkannya ke [IconData] dan [Color] untuk layar.
///
/// AMAN KALAU KOSONG / TIDAK DIKENAL: selalu ada nilai cadangan
/// ([Icons.category] dan [warnaKategoriBawaan]) supaya layar tidak rusak saat
/// nama ikon baru dipakai seed tanpa didaftarkan di sini.
library;

import 'package:flutter/material.dart';

/// Nama ikon Material yang dikenal (urutan = urutan tampil di pemilih ikon).
const Map<String, IconData> petaIkonKategori = {
  'category': Icons.category,
  'home': Icons.home,
  'restaurant': Icons.restaurant,
  'directions_bus': Icons.directions_bus,
  'directions_car': Icons.directions_car,
  'school': Icons.school,
  'family_restroom': Icons.family_restroom,
  'movie': Icons.movie,
  'health_and_safety': Icons.health_and_safety,
  'medical_services': Icons.medical_services,
  'shopping_bag': Icons.shopping_bag,
  'shopping_cart': Icons.shopping_cart,
  'credit_card': Icons.credit_card,
  'receipt_long': Icons.receipt_long,
  'payments': Icons.payments,
  'business_center': Icons.business_center,
  'storefront': Icons.storefront,
  'sell': Icons.sell,
  'account_balance': Icons.account_balance,
  'account_balance_wallet': Icons.account_balance_wallet,
  'card_giftcard': Icons.card_giftcard,
  'redeem': Icons.redeem,
  'trending_up': Icons.trending_up,
  'savings': Icons.savings,
  'subscriptions': Icons.subscriptions,
  'laptop_mac': Icons.laptop_mac,
  'work': Icons.work,
  'home_work': Icons.home_work,
  'wifi': Icons.wifi,
  'phone_android': Icons.phone_android,
  'bolt': Icons.bolt,
  'water_drop': Icons.water_drop,
  'coffee': Icons.coffee,
  'pets': Icons.pets,
  'fitness_center': Icons.fitness_center,
  'book': Icons.book,
  'music_note': Icons.music_note,
  'flight': Icons.flight,
  'sports_esports': Icons.sports_esports,
  'checkroom': Icons.checkroom,
  'celebration': Icons.celebration,
  'volunteer_activism': Icons.volunteer_activism,
};

/// Pilihan ikon untuk pengguna — seluruh isi [petaIkonKategori], jadi tidak
/// mungkin ada nama ikon yang tidak dikenal.
final List<String> pilihanIkon =
    petaIkonKategori.keys.toList(growable: false);

/// Ikon dari nama; [Icons.category] bila kosong atau tidak dikenal.
IconData ikonKategori(String? nama) {
  final kunci = nama?.trim() ?? '';
  if (kunci.isEmpty) return Icons.category;
  return petaIkonKategori[kunci] ?? Icons.category;
}

/// Warna cadangan bila nama warna kosong atau tidak sah.
const Color warnaKategoriBawaan = Color(0xFF4A90D9);

/// Warna heks yang dikenal (urutan = urutan tampil di pemilih warna).
const Map<String, Color> petaWarnaKategori = {
  '#6D4C41': Color(0xFF6D4C41),
  '#F4511E': Color(0xFFF4511E),
  '#43A047': Color(0xFF43A047),
  '#7CB342': Color(0xFF7CB342),
  '#D81B60': Color(0xFFD81B60),
  '#8E24AA': Color(0xFF8E24AA),
  '#E53935': Color(0xFFE53935),
  '#546E7A': Color(0xFF546E7A),
  '#3949AB': Color(0xFF3949AB),
  '#1E88E5': Color(0xFF1E88E5),
  '#757575': Color(0xFF757575),
  '#4A90D9': Color(0xFF4A90D9),
  '#00897B': Color(0xFF00897B),
  '#00ACC1': Color(0xFF00ACC1),
  '#5E35B1': Color(0xFF5E35B1),
  '#FB8C00': Color(0xFFFB8C00),
  '#FFB300': Color(0xFFFFB300),
};

/// Pilihan warna untuk pengguna — seluruh isi [petaWarnaKategori].
final List<String> pilihanWarna =
    petaWarnaKategori.keys.toList(growable: false);

/// Warna dari teks heks `#RRGGBB` (juga menerima heks baru yang belum ada di
/// peta). Kembali ke [warnaKategoriBawaan] bila kosong / tidak sah.
Color warnaKategori(String? heks) {
  final teks = heks?.trim().toUpperCase() ?? '';
  if (teks.isEmpty) return warnaKategoriBawaan;
  final dikenal = petaWarnaKategori[teks];
  if (dikenal != null) return dikenal;
  final angka = teks.startsWith('#') ? teks.substring(1) : teks;
  if (angka.length != 6) return warnaKategoriBawaan;
  final nilai = int.tryParse(angka, radix: 16);
  if (nilai == null) return warnaKategoriBawaan;
  return Color(0xFF000000 | nilai);
}

/// [Color] -> teks heks `#RRGGBB` (bentuk yang disimpan di database).
String heksDariWarna(Color c) {
  String dua(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${dua((c.r * 255).round())}${dua((c.g * 255).round())}'
      '${dua((c.b * 255).round())}';
}
