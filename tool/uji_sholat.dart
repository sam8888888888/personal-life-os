// Skrip bantu pemeriksaan manual (bukan bagian aplikasi).
// Jalankan: flutter pub run dart run tool/<berkas>.dart
// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings


import 'package:adhan_dart/adhan_dart.dart';

void main() {
  final kota = {
    'Jakarta': [-6.2088, 106.8456],
    'Makassar': [-5.1477, 119.4327],
  };
  final metode = {
    'KEMENAG': CalculationMethodParameters.indonesian(),
    'MWL': CalculationMethodParameters.muslimWorldLeague(),
  };
  final tanggal = DateTime(2026, 9, 13);
  for (final k in kota.entries) {
    for (final m in metode.entries) {
      final pt = PrayerTimes(
        date: tanggal,
        coordinates: Coordinates(k.value[0], k.value[1]),
        calculationParameters: m.value,
      );
      String f(DateTime d) => d.isUtc
          ? 'UTC ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'
          : 'LCL ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      print('${k.key}|${m.key}|${f(pt.fajr)}|${f(pt.dhuhr)}|${f(pt.asr)}|${f(pt.maghrib)}|${f(pt.isha)}');
    }
  }
  // uji madzhab Hanafi
  final paramHanafi = CalculationMethodParameters.indonesian()..madhab = Madhab.hanafi;
  final ptH = PrayerTimes(
    date: tanggal,
    coordinates: Coordinates(-6.2088, 106.8456),
    calculationParameters: paramHanafi,
  );
  print('JAKARTA_HANAFI_ASHAR|${ptH.asr.hour}:${ptH.asr.minute}');
}
