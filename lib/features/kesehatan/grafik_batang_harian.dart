/// Grafik batang harian sederhana (FR-101/102/111).
///
/// Hanya menggambar angka yang dicatat pengguna. Tidak ada ambang batas, tidak
/// ada warna "baik/buruk", dan tidak ada kesimpulan "sehat/tidak sehat".
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_tema.dart';
import '../../data/repository/kesehatan_repository.dart';
import 'label_hari.dart';

class GrafikBatangHarian extends StatelessWidget {
  const GrafikBatangHarian({
    super.key,
    required this.batang,
    this.satuan = '',
    this.tinggi = 110,
    this.warna,
  });

  /// Data per hari, urut dari yang paling lama ke yang terbaru.
  final List<BatangHarian> batang;

  /// Satuan untuk keterangan pembaca layar, mis. "menit" atau "ml".
  final String satuan;

  final double tinggi;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (batang.isEmpty) {
      return const Text('Belum ada data');
    }
    final maks = batang.fold<int>(0, (s, b) => b.nilai > s ? b.nilai : s);
    final color = warna ?? AppTema.seed;

    return Semantics(
      label: 'Grafik batang harian, satuan $satuan',
      child: SizedBox(
        height: tinggi + 52,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final b in batang)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        b.nilai == 0 ? '–' : '${b.nilai}',
                        style: tema.textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        key: Key(
                          'batang_${b.tanggal.year}-'
                          '${b.tanggal.month.toString().padLeft(2, '0')}-'
                          '${b.tanggal.day.toString().padLeft(2, '0')}',
                        ),
                        height: maks == 0 ? 2 : (b.nilai / maks) * tinggi,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labelHariSingkat(b.tanggal),
                        style: tema.textTheme.labelSmall,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
