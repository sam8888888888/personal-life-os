/// Grafik tren kekayaan bersih (FR-76).
///
/// Digambar sendiri dengan CustomPaint — tanpa paket grafik tambahan.
/// Sumbu X = bulan (label singkat), batang = nilai bersih (aset - kewajiban).
/// Batang warna utama = bulan bernilai positif, warna galat = negatif. Nilai
/// bulan terakhir juga ditulis sebagai angka di kanan atas agar tetap terbaca
/// walau layar sempit.
///
/// Berkas ini juga memiliki dua pencetak label bulan TANPA data locale intl
/// ([labelBulanSingkat] dan [labelBulanPanjang]) yang dipakai layar kekayaan,
/// supaya label bulan tetap benar walau `initializeDateFormatting` belum
/// dijalankan (mis. pada pengujian widget).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/uang_utils.dart';
import '../../../data/repository/aset_repository.dart';

const List<String> _namaBulanSingkat = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

const List<String> _namaBulanPanjang = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// Nomor bulan (1-12) dari kunci `YYYY-MM`; null bila kunci tidak sah.
int? _bulanKe(String kunci) {
  final bagian = kunci.trim().split('-');
  if (bagian.length != 2 || bagian[1].length != 2) return null;
  final b = int.tryParse(bagian[1]);
  return (b != null && b >= 1 && b <= 12) ? b : null;
}

/// Label sumbu X dari kunci `YYYY-MM`: "Sep". Bulan Januari menulis
/// "Jan 2027" supaya pergantian tahun tetap terlihat.
String labelBulanSingkat(String kunci) {
  final b = _bulanKe(kunci);
  if (b == null) return kunci;
  final nama = _namaBulanSingkat[b - 1];
  final tahun = kunci.trim().split('-').first;
  return b == 1 ? '$nama $tahun' : nama;
}

/// Label panjang dari kunci `YYYY-MM`: "September 2026".
String labelBulanPanjang(String kunci) {
  final b = _bulanKe(kunci);
  if (b == null) return kunci;
  final tahun = kunci.trim().split('-').first;
  return '${_namaBulanPanjang[b - 1]} $tahun';
}

/// Grafik batang tren nilai bersih bulanan.
class GrafikTrenKekayaan extends StatelessWidget {
  const GrafikTrenKekayaan({super.key, required this.tren, this.tinggi = 170});

  /// Riwayat bulanan (urut menaik menurut bulan).
  final List<NilaiBersih> tren;

  /// Tinggi area gambar (tanpa label).
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final judul = Row(
      children: [
        Expanded(
          child: Text('Tren nilai bersih bulanan',
              style: tema.textTheme.titleSmall),
        ),
        if (tren.isNotEmpty)
          Text('Terakhir: ${fmtRpDariSen(tren.last.bersihSen)}',
              key: const Key('nilai_terakhir_grafik'),
              style: tema.textTheme.bodySmall),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: tema.colorScheme.surface,
        border: Border.all(color: tema.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          judul,
          const SizedBox(height: 8),
          if (tren.isEmpty)
            Text(
              'Belum ada riwayat bulanan. Isi nilai bulan ini untuk memulai '
              'pencatatan.',
              style: tema.textTheme.bodySmall,
            )
          else
            SizedBox(
              width: double.infinity,
              height: tinggi,
              child: CustomPaint(
                painter: _PelukisTren(
                  titik: [
                    for (final n in tren)
                      (label: labelBulanSingkat(n.bulan), nilai: n.bersihSen),
                  ],
                  warnaPositif: tema.colorScheme.primary,
                  warnaNegatif: tema.colorScheme.error,
                  warnaGaris: tema.colorScheme.outlineVariant,
                  warnaTeks: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Satu batang: label bulan + nilai bersih (sen).
typedef _Titik = ({String label, int nilai});

class _PelukisTren extends CustomPainter {
  _PelukisTren({
    required this.titik,
    required this.warnaPositif,
    required this.warnaNegatif,
    required this.warnaGaris,
    required this.warnaTeks,
  });

  final List<_Titik> titik;
  final Color warnaPositif;
  final Color warnaNegatif;
  final Color warnaGaris;
  final Color warnaTeks;

  /// Tinggi pita label bulan di bawah batang.
  static const double _tinggiLabel = 16;

  @override
  void paint(Canvas canvas, Size size) {
    if (titik.isEmpty) return;
    final area = Rect.fromLTWH(0, 2, size.width, size.height - _tinggiLabel - 2);
    if (area.height <= 0 || area.width <= 0) return;

    var maks = 0;
    var min = 0;
    for (final t in titik) {
      maks = math.max(maks, t.nilai);
      min = math.min(min, t.nilai);
    }
    // Rentang minimal 1 sen supaya pembagian tidak nol saat semua nilai sama.
    final rentang = (maks - min) == 0 ? 1 : (maks - min);

    double y(int nilai) =>
        area.bottom - (nilai - min) / rentang * (area.height - 4) - 2;

    // Garis nol hanya perlu bila ada nilai negatif.
    if (min < 0) {
      canvas.drawLine(
        Offset(0, y(0)),
        Offset(size.width, y(0)),
        Paint()
          ..color = warnaGaris
          ..strokeWidth = 1,
      );
    }

    final lebarSlot = size.width / titik.length;
    final lebarBatang = (lebarSlot * 0.5).clamp(4.0, 26.0);
    for (var i = 0; i < titik.length; i++) {
      final pusat = lebarSlot * i + lebarSlot / 2;
      final nilai = titik[i].nilai;
      final puncak = y(nilai);
      final dasar = y(0);
      final atas = math.min(puncak, dasar);
      final bawah = math.max(puncak, dasar);
      final batang = Rect.fromLTRB(
        pusat - lebarBatang / 2,
        atas,
        pusat + lebarBatang / 2,
        // Batang bernilai 0 tetap terlihat sebagai garis tipis.
        bawah - atas < 1 ? atas + 1 : bawah,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(batang, const Radius.circular(3)),
        Paint()..color = nilai >= 0 ? warnaPositif : warnaNegatif,
      );

      final teks = TextPainter(
        text: TextSpan(
          text: titik[i].label,
          style: TextStyle(fontSize: 10, color: warnaTeks),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      teks.paint(
        canvas,
        Offset(pusat - teks.width / 2, area.bottom + 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PelukisTren lama) =>
      !listEquals(lama.titik, titik) ||
      lama.warnaPositif != warnaPositif ||
      lama.warnaNegatif != warnaNegatif;
}
