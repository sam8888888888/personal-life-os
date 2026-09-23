/// Sisi Dart paket ini hanya berisi penanda: seluruh kerjanya ada di Android
/// (`BrankasRahasiaPlugin.kt`), dan aplikasi memanggilnya lewat kanal
/// `lifeos/rahasia` dari `lib/core/platform/brankas_rahasia.dart`.
///
/// KENAPA JADI PAKET PLUGIN (bukan ditempel di `MainActivity`):
/// pekerja latar (Workmanager) menjalankan kode Dart di MESIN Flutter
/// tersendiri. Kanal yang didaftarkan di `MainActivity` HANYA ada di mesin
/// utama, sehingga di pekerja latar pemanggilannya gagal. Paket plugin
/// didaftarkan otomatis di setiap mesin, jadi brankas (dan kunci basis data
/// terenkripsi) bisa dibuka juga saat aplikasi sedang tertutup.
library;

/// Nama kanal — dipakai bersama Dart dan Android.
const String kanalBrankasRahasia = 'lifeos/rahasia';
