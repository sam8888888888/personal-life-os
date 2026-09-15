/// Bilah kemajuan anggaran (FR-72) — satu tempat untuk aturan warna ambang.
///
/// Dipisah dari layar supaya aturan 80%/100% bisa diuji sendiri tanpa membuka
/// layar penuh: hijau = dalam batas, kuning = sudah menyentuh ambang pertama
/// (80%), merah = sudah menyentuh ambang terakhir (100%).
library;

import 'package:flutter/material.dart';

import '../../../core/utils/uang_utils.dart';
import '../../../data/repository/anggaran_repository.dart';

/// Ambang peringatan bawaan (%) — sama dengan nilai bawaan kolom
/// `anggaran_bulanan.ambang_peringatan` ("80,100").
const List<int> ambangAnggaranBawaan = [80, 100];

/// Hijau (dalam batas), kuning (menyentuh 80%), merah (menyentuh 100%).
Color warnaStatusAnggaran(StatusAnggaran status) => switch (status) {
      StatusAnggaran.aman => const Color(0xFF2E7D32),
      StatusAnggaran.mendekati => const Color(0xFFF9A825),
      StatusAnggaran.lewat => const Color(0xFFC62828),
    };

/// Bagian bilah yang terisi (0..1). Dibatasi supaya bilah tidak meluber saat
/// pemakaian sudah melewati batas — kelebihannya tetap terbaca di angka
/// "Selisih" (boleh negatif), bukan di panjang bilah.
double nilaiBilah(RealisasiAnggaran realisasi) {
  if (realisasi.batasSen <= 0) return 0;
  return (realisasi.terpakaiSen / realisasi.batasSen).clamp(0.0, 1.0);
}

/// Persentase sisa anggaran (boleh negatif bila melewati batas); null bila
/// batas belum diisi. 100% berarti belum terpakai sama sekali.
int? persenSelisih(RealisasiAnggaran realisasi) {
  final p = realisasi.persen;
  return p == null ? null : 100 - p;
}

/// Teks selisih dalam Rupiah. Tanda minus ditulis di depan "Rp" supaya
/// hasilnya sama di semua locale (tidak menggantungkan format negatif intl).
String teksSelisihRp(RealisasiAnggaran realisasi) {
  final s = realisasi.selisihSen;
  if (s < 0) return '-${fmtRpDariSen(-s)}';
  return fmtRpDariSen(s);
}

/// Bilah kemajuan anggaran dengan warna mengikuti status pemakaian.
class BilahAnggaran extends StatelessWidget {
  const BilahAnggaran({super.key, required this.realisasi, this.tinggi = 10});

  final RealisasiAnggaran realisasi;
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    final warna = warnaStatusAnggaran(realisasi.status);
    final persen = realisasi.persen;
    return Semantics(
      label: persen == null
          ? 'Anggaran belum diisi'
          : 'Terpakai $persen persen dari anggaran',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tinggi / 2),
        child: LinearProgressIndicator(
          value: nilaiBilah(realisasi),
          minHeight: tinggi,
          color: warna,
          backgroundColor: warna.withValues(alpha: 0.16),
        ),
      ),
    );
  }
}
