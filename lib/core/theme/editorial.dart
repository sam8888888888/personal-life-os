/// Komponen bersama untuk arah desain "Editorial Modern".
///
/// Kecil dan dipakai ulang: kartu bagian, judul bagian, kartu utama (sorotan),
/// dan bilah progres. Tujuannya supaya layar tidak lagi menyusun sendiri-sendiri
/// gaya kartu, jarak, dan warna — satu tempat, satu hasil.
library;

import 'package:flutter/material.dart';

import 'app_tema.dart';

/// Warna yang punya ARTI, seragam di seluruh aplikasi.
///
/// [positif] = kemajuan/beres, [perhatian] = pilih-pilih sebelum lewat,
/// [urgensi] = sudah dekat/terlewat, [tenang] = belum ada data (bukan buruk).
class WarnaEditorial {
  const WarnaEditorial._({
    required this.positif,
    required this.perhatian,
    required this.urgensi,
    required this.tenang,
  });

  final Color positif;
  final Color perhatian;
  final Color urgensi;
  final Color tenang;

  static WarnaEditorial dari(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    return WarnaEditorial._(
      positif: gelap ? AppTema.positifGelap : AppTema.positif,
      perhatian: gelap ? AppTema.perhatianGelap : AppTema.perhatian,
      urgensi: gelap ? AppTema.urgensiGelap : AppTema.urgensi,
      tenang: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

/// Judul bagian: huruf kecil semua dengan jarak huruf, bisa diberi aksi di kanan.
class JudulSeksi extends StatelessWidget {
  const JudulSeksi(this.label, {super.key, this.aksi, this.padding});

  final String label;
  final Widget? aksi;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 22, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: tema.textTheme.labelSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?aksi,
        ],
      ),
    );
  }
}

/// Kartu isi biasa: latar permukaan, garis tipis, sudut 18.
class KartuEditorial extends StatelessWidget {
  const KartuEditorial({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.warna,
    this.kunci,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? warna;
  final Key? kunci;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Container(
      key: kunci,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: warna ?? skema.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: skema.outlineVariant),
      ),
      child: child,
    );
  }
}

/// Kartu sorotan (satu hal terpenting di layar): latar aksen lembut.
class KartuUtama extends StatelessWidget {
  const KartuUtama({
    super.key,
    required this.label,
    required this.judul,
    this.anak,
    this.kunci,
  });

  final String label;
  final String judul;
  final Widget? anak;
  final Key? kunci;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      key: kunci,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: tema.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tema.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: tema.textTheme.labelSmall?.copyWith(
            color: tema.colorScheme.onPrimaryContainer.withValues(alpha: 0.75),
          )),
          const SizedBox(height: 10),
          Text(judul, style: tema.textTheme.titleLarge?.copyWith(
            fontSize: 17,
            color: tema.colorScheme.onPrimaryContainer,
          )),
          if (anak != null) ...[const SizedBox(height: 10), anak!],
        ],
      ),
    );
  }
}

/// Bilah progres sederhana: [nilai] 0..1.
class BilahProgres extends StatelessWidget {
  const BilahProgres(this.nilai, {super.key, this.warna, this.tinggi = 8});

  final double nilai;
  final Color? warna;
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final bersih = nilai.isFinite ? nilai.clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(tinggi),
      child: LinearProgressIndicator(
        value: bersih,
        minHeight: tinggi,
        backgroundColor: skema.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(warna ?? skema.primary),
      ),
    );
  }
}

/// Baris "label — nilai" untuk ringkasan angka.
class BarisAngka extends StatelessWidget {
  const BarisAngka({
    super.key,
    required this.label,
    required this.nilai,
    this.warnaNilai,
    this.tebal = false,
  });

  final String label;
  final String nilai;
  final Color? warnaNilai;
  final bool tebal;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: tebal ? tema.textTheme.titleSmall : tema.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            nilai,
            style: tema.textTheme.titleSmall?.copyWith(
              fontWeight: tebal ? FontWeight.w800 : FontWeight.w700,
              color: warnaNilai ?? tema.colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
