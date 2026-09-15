/// Peta nama ikon & warna kategori tagihan (FR-08).
///
/// Nilai disimpan sebagai teks di tabel `kategori` (`ikon`, `warna`) — ikon
/// disimpan sebagai NAMA ikon Material (mis. `bolt`), warna sebagai teks heks
/// `#RRGGBB`. Berkas ini yang menerjemahkannya ke [IconData] dan [Color]
/// untuk layar.
///
/// AMAN TERHADAP NILAI TAK DIKENAL: selalu ada nilai cadangan
/// ([ikonTagihanBawaan] & [warnaTagihanBawaan]) supaya layar tidak rusak kalau
/// ada nama ikon/warna baru di database yang belum didaftarkan di sini.
library;

import 'package:flutter/material.dart';

/// Nama ikon Material yang dikenal (urutan = urutan tampil di pemilih ikon).
/// Dipilih dari kebutuhan tagihan rumah tangga Indonesia.
const Map<String, IconData> petaIkonTagihan = {
  'receipt': Icons.receipt,
  'receipt_long': Icons.receipt_long,
  'bolt': Icons.bolt,
  'water_drop': Icons.water_drop,
  'local_fire_department': Icons.local_fire_department,
  'wifi': Icons.wifi,
  'smartphone': Icons.smartphone,
  'phone_android': Icons.phone_android,
  'credit_card': Icons.credit_card,
  'subscriptions': Icons.subscriptions,
  'directions_car': Icons.directions_car,
  'two_wheeler': Icons.two_wheeler,
  'local_gas_station': Icons.local_gas_station,
  'school': Icons.school,
  'home': Icons.home,
  'health_and_safety': Icons.health_and_safety,
  'medical_services': Icons.medical_services,
  'pets': Icons.pets,
  'movie': Icons.movie,
  'music_note': Icons.music_note,
  'sports_esports': Icons.sports_esports,
  'fitness_center': Icons.fitness_center,
  'shopping_bag': Icons.shopping_bag,
  'shopping_cart': Icons.shopping_cart,
  'restaurant': Icons.restaurant,
  'flight': Icons.flight,
  'card_giftcard': Icons.card_giftcard,
  'savings': Icons.savings,
  'business_center': Icons.business_center,
  'family_restroom': Icons.family_restroom,
  'park': Icons.park,
  'security': Icons.security,
  'cleaning_services': Icons.cleaning_services,
  'book': Icons.book,
  'laptop_mac': Icons.laptop_mac,
  'volunteer_activism': Icons.volunteer_activism,
};

/// Pilihan ikon untuk pengguna — urut seperti [petaIkonTagihan].
final List<String> pilihanIkonTagihan =
    petaIkonTagihan.keys.toList(growable: false);

/// Ikon cadangan: dipakai bila nama ikon kosong / belum dikenal.
const IconData ikonTagihanBawaan = Icons.receipt_long;

/// Ikon dari nama; [ikonTagihanBawaan] bila kosong atau tidak dikenal.
IconData ikonTagihan(String? nama) {
  final kunci = nama?.trim() ?? '';
  if (kunci.isEmpty) return ikonTagihanBawaan;
  return petaIkonTagihan[kunci] ?? ikonTagihanBawaan;
}

/// Apakah [nama] termasuk daftar ikon yang dikenal?
bool namaIkonTagihanDikenal(String? nama) =>
    petaIkonTagihan.containsKey(nama?.trim() ?? '');

/// Warna heks yang dikenal (urutan = urutan tampil di pemilih warna).
/// Memuat seluruh warna kategori bawaan supaya tampilan awal tidak berubah.
const Map<String, Color> petaWarnaTagihan = {
  '#4A90D9': Color(0xFF4A90D9),
  '#F5A623': Color(0xFFF5A623),
  '#4CAF50': Color(0xFF4CAF50),
  '#7B68EE': Color(0xFF7B68EE),
  '#F06292': Color(0xFFF06292),
  '#9E9E9E': Color(0xFF9E9E9E),
  '#00ACC1': Color(0xFF00ACC1),
  '#5C6BC0': Color(0xFF5C6BC0),
  '#FFB74D': Color(0xFFFFB74D),
  '#8D6E63': Color(0xFF8D6E63),
  '#E53935': Color(0xFFE53935),
  '#8E24AA': Color(0xFF8E24AA),
  '#00897B': Color(0xFF00897B),
  '#546E7A': Color(0xFF546E7A),
};

/// Pilihan warna untuk pengguna — urut seperti [petaWarnaTagihan].
final List<String> pilihanWarnaTagihan =
    petaWarnaTagihan.keys.toList(growable: false);

/// Warna cadangan — sama dengan nilai bawaan kolom `warna` di database.
const Color warnaTagihanBawaan = Color(0xFF4A90D9);

/// Teks heks bawaan yang disimpan ke database.
const String heksWarnaTagihanBawaan = '#4A90D9';

/// Warna dari teks heks `#RRGGBB` (juga `RRGGBB` atau `#AARRGGBB`).
/// Kembali ke [warnaTagihanBawaan] bila kosong / tidak sah — tidak pernah
/// melempar galat.
Color warnaTagihan(String? heks) {
  final teks = heks?.trim().toUpperCase() ?? '';
  if (teks.isEmpty) return warnaTagihanBawaan;
  final dikenal = petaWarnaTagihan[teks];
  if (dikenal != null) return dikenal;
  final angka = teks.startsWith('#') ? teks.substring(1) : teks;
  if (angka.length != 6 && angka.length != 8) return warnaTagihanBawaan;
  final nilai = int.tryParse(angka, radix: 16);
  if (nilai == null) return warnaTagihanBawaan;
  return Color(angka.length == 8 ? nilai : 0xFF000000 | nilai);
}

/// Apakah [heks] termasuk daftar warna yang dikenal?
bool heksWarnaTagihanDikenal(String? heks) =>
    petaWarnaTagihan.containsKey(heks?.trim().toUpperCase() ?? '');

/// [Color] -> teks heks `#RRGGBB` (bentuk yang disimpan di kolom `warna`).
String heksDariWarnaTagihan(Color c) {
  String dua(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${dua(c.r)}${dua(c.g)}${dua(c.b)}';
}
