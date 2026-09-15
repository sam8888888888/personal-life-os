/// Komponen bersama layar ibadah lanjutan (FR-91/92/93/95/100).
///
/// Tujuannya menjaga tiga hal tetap sama di semua layar:
/// 1. bahasa netral (tanpa skor, tanpa tuduhan, tanpa diagnosis),
/// 2. keadaan kosong selalu berbunyi "Belum ada data" — bukan angka 0 yang
///    bisa disalahartikan sebagai "tidak ada aktivitas sama sekali",
/// 3. grafik sederhana tanpa pustaka luar (proyek ini tidak memakai fl_chart).
library;

import 'package:flutter/material.dart';

import '../../core/ibadah/kalender_hijriah.dart';

/// Kalimat baku untuk keadaan kosong.
const String teksBelumAdaData = 'Belum ada data';

/// Tanggal ringkas `dd-MM-yyyy` (sama dengan layar Jadwal Sholat).
String teksTanggal(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

/// Nama hari singkat Bahasa Indonesia (Sen, Sel, ...).
String teksHari(DateTime d) => namaHariSingkat[(d.weekday - 1) % 7];

/// Kartu bagian dengan judul.
class KartuBagian extends StatelessWidget {
  const KartuBagian({super.key, required this.judul, required this.isi, this.ikon});

  final String judul;
  final Widget isi;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (ikon != null) ...<Widget>[
                  Icon(ikon, size: 18, color: tema.colorScheme.primary),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    judul,
                    style: tema.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            isi,
          ],
        ),
      ),
    );
  }
}

/// Baris "belum ada data" yang seragam.
class BarisKosong extends StatelessWidget {
  const BarisKosong({super.key, this.keterangan});

  /// Keterangan tambahan (opsional), mis. "Catat lewat tombol di bawah."
  final String? keterangan;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(teksBelumAdaData, style: tema.textTheme.bodyMedium),
        if (keterangan != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            keterangan!,
            style: tema.textTheme.bodySmall
                ?.copyWith(color: tema.colorScheme.outline),
          ),
        ],
      ],
    );
  }
}

/// Catatan kejujuran data (mis. "Perhitungan, bukan jadwal resmi").
class CatatanJujur extends StatelessWidget {
  const CatatanJujur({super.key, required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        teks,
        style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.outline),
      ),
    );
  }
}

/// Satu batang grafik sederhana: tinggi mengikuti nilai terbesar.
class GrafikBatang extends StatelessWidget {
  const GrafikBatang({
    super.key,
    required this.nilai,
    this.tinggi = 110,
    this.satuanTeks,
  });

  /// Nilai per tanggal (urut bebas; grafik mengurutkan sendiri).
  final Map<DateTime, double> nilai;
  final double tinggi;

  /// Teks satuan untuk ringkasan di bawah grafik (mis. "halaman").
  final String? satuanTeks;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    if (nilai.isEmpty) return const BarisKosong();

    final List<DateTime> tanggal = nilai.keys.toList()..sort();
    final double maks = nilai.values.fold<double>(
        0, (double a, double b) => b > a ? b : a);
    final double puncak = maks <= 0 ? 1 : maks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: tinggi,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (final DateTime t in tanggal)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        // Tinggi batang memakai sisa ruang (Expanded), bukan
                        // angka tetap, supaya label hari tetap muat di layar
                        // sempit dan tidak ada luapan tata letak.
                        Expanded(
                          child: FractionallySizedBox(
                            alignment: Alignment.bottomCenter,
                            heightFactor:
                                ((nilai[t] ?? 0) / puncak).clamp(0.0, 1.0),
                            child: Container(
                              key: Key('batang_${teksTanggal(t)}'),
                              decoration: BoxDecoration(
                                color: (nilai[t] ?? 0) > 0
                                    ? tema.colorScheme.primary
                                    : tema.colorScheme.surfaceContainerHighest,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tanggal.length > 10
                              ? '${t.day}'
                              : teksHari(t),
                          style: tema.textTheme.labelSmall
                              ?.copyWith(color: tema.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tertinggi: ${teksAngkaBatang(maks)}${satuanTeks == null ? '' : ' $satuanTeks'}'
          ' · ${tanggal.length} hari ditampilkan',
          style: tema.textTheme.bodySmall
              ?.copyWith(color: tema.colorScheme.outline),
        ),
      ],
    );
  }
}

/// Angka grafik tanpa ekor nol (7.0 -> "7", 1.5 -> "1,5").
String teksAngkaBatang(double nilai) {
  if (nilai == nilai.roundToDouble()) return nilai.round().toString();
  return nilai.toStringAsFixed(1).replaceAll('.', ',');
}

/// Baris ringkasan "label — nilai" yang rapi.
class BarisRingkasan extends StatelessWidget {
  const BarisRingkasan({super.key, required this.label, required this.nilai, this.tebal = false});

  final String label;
  final String nilai;
  final bool tebal;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextStyle? gaya = tebal
        ? tema.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
        : tema.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label, style: gaya)),
          const SizedBox(width: 8),
          Text(nilai, style: gaya),
        ],
      ),
    );
  }
}
