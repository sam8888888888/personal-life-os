/// Utilitas uang — PURE. Format Rupiah & parsing input cepat.
library;

import 'package:intl/intl.dart';

final _fmtRp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

/// 1250000 -> "Rp 1.250.000"
String fmtRp(num jumlah) => _fmtRp.format(jumlah);

/// "Rp 1.250.000" / "1.250.000" / "1,250,000" -> 1250000
num? parseRupiah(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  var v = s.trim().toLowerCase();
  num pengali = 1;
  if (v.endsWith('rb') || v.endsWith('k')) {
    pengali = 1000;
    v = v.substring(0, v.length - (v.endsWith('rb') ? 2 : 1));
  } else if (v.endsWith('jt') || v.endsWith('juta')) {
    pengali = 1000000;
    v = v.endsWith('juta') ? v.substring(0, v.length - 4) : v.substring(0, v.length - 2);
  }
  v = v.replaceAll('rp', '').replaceAll(' ', '');
  if (v.isEmpty) return null;
  String v2;
  if (v.contains(',') && v.contains('.')) {
    // Format Indonesia: '1.250,5' -> ribuan '.', desimal ','
    v2 = v.replaceAll('.', '').replaceAll(',', '.');
  } else if (v.contains(',')) {
    // '1,250,000' (gaya US) atau '150,5'
    v2 = RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(v)
        ? v.replaceAll(',', '')
        : v.replaceAll(',', '.');
  } else if (v.contains('.')) {
    // '150.000' / '1.250.000' = ribuan; '150.5' = desimal
    v2 = RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(v) ? v.replaceAll('.', '') : v;
  } else {
    v2 = v;
  }
  final angka = double.tryParse(v2);
  if (angka == null) return null;
  return angka * pengali;
}

/// Rp 150.000 -> 15000000 sen (satuan terkecil; IDR tanpa desimal).
int rupiahKeSen(num jumlah) => (jumlah * 100).round();

/// 15000000 sen -> "Rp 150.000"
String fmtRpDariSen(int sen) => fmtRp(sen / 100);
