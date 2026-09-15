/// Bagian tampilan yang dipakai ulang seluruh layar kesehatan.
///
/// Kondisi kosong selalu ditulis "Belum ada data" (aturan proyek: jangan
/// menampilkan 0 yang bisa menyesatkan).
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_tema.dart';

/// Kartu bagian dengan judul + ikon kecil.
class KartuBagian extends StatelessWidget {
  const KartuBagian({
    super.key,
    required this.judul,
    required this.anak,
    this.ikon,
  });

  final String judul;
  final IconData? ikon;
  final List<Widget> anak;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (ikon != null) ...[
                  Icon(ikon, size: 20, color: AppTema.seed),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Text(judul, style: tema.textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: 6),
            ...anak,
          ],
        ),
      ),
    );
  }
}

/// Tulisan baku untuk bagian yang belum punya catatan.
class TeksBelumAdaData extends StatelessWidget {
  const TeksBelumAdaData({super.key});

  @override
  Widget build(BuildContext context) => const Text('Belum ada data');
}

/// Tombol kecil pilihan cepat (mis. jenis aktivitas atau kualitas tidur).
class PilihanCepat extends StatelessWidget {
  const PilihanCepat({
    super.key,
    required this.label,
    required this.terpilih,
    required this.onPilih,
    this.kunci,
  });

  final String label;
  final bool terpilih;
  final VoidCallback onPilih;
  final Key? kunci;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        key: kunci,
        label: Text(label),
        selected: terpilih,
        onSelected: (_) => onPilih(),
      );
}
