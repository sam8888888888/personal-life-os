/// Uji FR-67 — format tanggal & waktu mengikuti locale mata uang.
///
/// Satu saklar (mata uang) menentukan dua hal: simbol uang **dan** nama bulan /
/// hari yang dipakai aplikasi. IDR → Indonesia, MYR → Malaysia.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/utils/mata_uang.dart';
import 'package:personal_life_os/core/utils/tanggal_utils.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await initializeDateFormatting('ms_MY');
  });

  tearDown(() => pakaiMataUang(MataUang.idr));

  test('bawaan Rupiah: nama bulan & hari Indonesia', () {
    pakaiMataUang(MataUang.idr);

    expect(localeTanggalAktif, 'id_ID');
    // 20 Agustus 2026 (Kamis).
    expect(fmtTanggalAman(DateTime(2026, 8, 20)), '20 Agustus 2026');
    expect(fmtTanggalPendekAman(DateTime(2026, 8, 20)),
        'Kam, 20 Agu 2026');
    expect(fmtTanggalId(DateTime(2026, 8, 20)), '20 Agustus 2026');
    expect(fmtBulanId(DateTime(2026, 8, 20)), 'Agustus 2026');
    expect(fmtBulanPendekId(DateTime(2026, 8, 20)), 'Agu 2026');
  });

  test('Ringgit: nama bulan & hari Malaysia — bukan cuma simbol uang', () {
    pakaiMataUang(MataUang.myr);

    expect(localeTanggalAktif, 'ms_MY');
    // Malay: Agustus → Ogos, Agustus singkat → Ogo.
    expect(fmtTanggalAman(DateTime(2026, 8, 20)), '20 Ogos 2026');
    expect(fmtTanggalPendekAman(DateTime(2026, 8, 20)),
        'Kha, 20 Ogo 2026');
    expect(fmtTanggalId(DateTime(2026, 8, 20)), '20 Ogos 2026');
    expect(fmtBulanId(DateTime(2026, 8, 20)), 'Ogos 2026');
    expect(fmtBulanPendekId(DateTime(2026, 8, 20)), 'Ogo 2026');

    // Hari Ahad juga beda: Indonesia "Min", Malaysia "Ahd".
    expect(fmtTanggalPendekAman(DateTime(2026, 9, 13)), 'Ahd, 13 Sep 2026');
    // Uang ikut berubah simbolnya (kode tetap sama-sama Ringgit).
    expect(fmtUangDariSen(1250000), contains('12,500'));
  });

  test('ganti mata uang kembali ke Rupiah memulihkan format Indonesia', () {
    pakaiMataUang(MataUang.myr);
    expect(fmtTanggalAman(DateTime(2026, 12, 1)), '1 Disember 2026');

    pakaiMataUang(MataUang.idr);
    expect(fmtTanggalAman(DateTime(2026, 12, 1)), '1 Desember 2026');
    expect(fmtTanggalPendekAman(DateTime(2026, 12, 1)), 'Sel, 1 Des 2026');
  });

  test('parse tanggal tetap bekerja pada kedua locale', () {
    pakaiMataUang(MataUang.idr);
    expect(parseTanggal('20 Agustus 2026'), DateTime(2026, 8, 20));

    pakaiMataUang(MataUang.myr);
    expect(parseTanggal('20 Ogos 2026'), DateTime(2026, 8, 20));
  });
}
