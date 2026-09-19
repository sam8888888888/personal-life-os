/// Mata uang aplikasi (FR-67): Rupiah (Indonesia) & Ringgit (Malaysia).
///
/// Satu sumber kebenaran untuk pemformatan uang. Semua layar memakai
/// [fmtUangDariSen], jadi mengganti mata uang di Pengaturan cukup sekali.
library;

import 'package:intl/intl.dart';

enum MataUang {
  idr('IDR', 'Rp ', 'id_ID', 0, 'Rupiah (Rp)'),
  myr('MYR', 'RM ', 'ms_MY', 2, 'Ringgit (RM)');

  const MataUang(
      this.kode, this.simbol, this.locale, this.desimal, this.label);

  final String kode;
  final String simbol;
  final String locale;
  final int desimal;
  final String label;
}

MataUang _aktif = MataUang.idr;

/// Mata uang yang sedang dipakai aplikasi (bawaan: Rupiah).
MataUang get mataUangAktif => _aktif;

/// Locale untuk format tanggal & waktu (FR-67).
///
/// Satu saklar untuk dua hal: mengganti mata uang ke Ringgit juga memakai
/// format tanggal Malaysia — bukan cuma simbol uangnya.
String get localeTanggalAktif => _aktif.locale;

/// Ganti mata uang aktif — dipanggil saat aplikasi mulai dan dari Pengaturan.
void pakaiMataUang(MataUang m) => _aktif = m;

/// Kode teks ('IDR'/'MYR') menjadi enum; kode tak dikenal kembali ke Rupiah.
MataUang mataUangDariKode(String? kode) {
  if (kode == null) return MataUang.idr;
  final k = kode.trim().toUpperCase();
  for (final m in MataUang.values) {
    if (m.kode == k) return m;
  }
  return MataUang.idr;
}

String _format(num jumlah, MataUang m) => NumberFormat.currency(
      locale: m.locale,
      symbol: m.simbol,
      decimalDigits: m.desimal,
    ).format(jumlah);

/// 1250000 -> "Rp 1.250.000" (atau "RM 12,500.00" saat mata uang Ringgit).
String fmtUang(num jumlah, {MataUang? mataUang}) =>
    _format(jumlah, mataUang ?? _aktif);

/// 45000000 sen -> "Rp 450.000"
String fmtUangDariSen(int sen, {MataUang? mataUang}) =>
    fmtUang(sen / 100, mataUang: mataUang);
