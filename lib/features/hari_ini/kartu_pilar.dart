/// Kartu Pilar Harian (FR-61).
///
/// Aturan III-11: kartu kosong WAJIB menulis "Belum ada data" — bukan "0",
/// bukan angka contoh. Kartu Ibadah tidak pernah berwarna merah.
library;

import 'package:flutter/material.dart';

import '../../core/hari_ini/model_hari_ini.dart';
import 'warna_tingkat.dart';

class KartuPilar extends StatelessWidget {
  const KartuPilar({super.key, required this.nilai, this.onTap});

  final NilaiPilar nilai;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final warna = warnaTingkat(nilai.tingkat, tema);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(ikonPilar(nilai.pilar), size: 18, color: warna),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      nilai.pilar.label,
                      style: tema.textTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                nilai.angka,
                style: tema.textTheme.titleSmall?.copyWith(
                  color: nilai.belumAdaData ? tema.colorScheme.outline : null,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 3,
              ),
              if (nilai.keterangan.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  nilai.keterangan,
                  style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.outline),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
