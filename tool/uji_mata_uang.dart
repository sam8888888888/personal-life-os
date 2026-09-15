// Skrip bantu pemeriksaan manual (bukan bagian aplikasi).
// Jalankan: dart run tool/uji_mata_uang.dart
// ignore_for_file: avoid_print

import 'package:personal_life_os/core/utils/mata_uang.dart';

void main() {
  for (final m in MataUang.values) {
    print('${m.kode}: ${fmtUangDariSen(45000000, mataUang: m)} | '
        '${fmtUang(1250000, mataUang: m)} | '
        'nol = ${fmtUangDariSen(0, mataUang: m)}');
  }
}
