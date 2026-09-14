// Skrip bantu pemeriksaan manual (bukan bagian aplikasi).
// Jalankan: flutter pub run dart run tool/<berkas>.dart
// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings


import 'package:hijri_core/hijri_core.dart';
void main() {
  final d = DateTime.utc(2026, 2, 18);
  for (final cal in ['uaq', 'fcna']) {
    final h = toHijri(d, options: ConversionOptions(calendar: cal));
    print('$cal 2026-02-18 -> $h');
  }
  for (final cal in ['uaq','fcna']) {
    final h = toHijri(DateTime.utc(2026,9,13), options: ConversionOptions(calendar: cal));
    print('$cal 2026-09-13 -> $h');
  }
  for (final cal in ['uaq','fcna']) {
    final g = toGregorian(1447, 9, 1, options: ConversionOptions(calendar: cal));
    print('$cal 1 Ramadhan 1447 -> ${g?.toIso8601String()}');
  }
  print('jumlah hari Ramadhan 1447 UAQ: ' + daysInHijriMonth(1447, 9).toString());
  print('kalender terdaftar: ' + listCalendars().join(','));
}
