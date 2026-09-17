/// FR-137 — penjaga cadangan otomatis.
///
/// Dipasang di paling atas pohon widget (`main.dart`). Sesudah tampilan pertama
/// muncul, ia memeriksa setelan: bila cadangan otomatis menyala dan jedanya
/// sudah lewat, cadangan dijalankan di latar belakang tanpa menghalangi
/// layar.
///
/// Jujur soal batas: penjadwal tingkat sistem belum dipakai, jadi cadangan
/// otomatis berjalan SAAT APLIKASI DIBUKA. Bila aplikasi lama tidak dibuka,
/// cadangan berikutnya menunggu sampai aplikasi dibuka lagi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backup/cadangan_otomatis.dart';
import '../../core/backup/ekspor_impor.dart';
import '../../core/providers/app_providers.dart';
import '../ibadah/pengaturan_ibadah.dart';
import 'cadangan_otomatis_layanan.dart';

class PenjagaCadanganOtomatis extends ConsumerStatefulWidget {
  const PenjagaCadanganOtomatis({
    super.key,
    required this.child,
    this.layananOtomatis,
  });

  final Widget child;

  /// Layanan yang bisa disuntik saat pengujian.
  final LayananCadanganOtomatis? layananOtomatis;

  @override
  ConsumerState<PenjagaCadanganOtomatis> createState() =>
      PenjagaCadanganOtomatisState();
}

class PenjagaCadanganOtomatisState
    extends ConsumerState<PenjagaCadanganOtomatis> {
  /// Hasil penjalanan terakhir (dipakai uji; pengguna melihatnya di layar
  /// Cadangan & Pemulihan).
  HasilCadanganOtomatis? hasil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => jalankan());
  }

  Future<void> jalankan() async {
    try {
      final LayananCadanganOtomatis layanan = widget.layananOtomatis ??
          LayananCadanganOtomatis(
            setelan: SetelanBasisData(ref.read(pengaturanRepoProvider)),
            cadangan: LayananCadangan(db: ref.read(databaseProvider)),
          );
      final HasilCadanganOtomatis h = await layanan
          .jalankan()
          .timeout(batasCadanganOtomatis * 3);
      if (!mounted) return;
      setState(() => hasil = h);
    } catch (e) {
      // Cadangan otomatis tidak boleh menjatuhkan aplikasi.
      if (!mounted) return;
      setState(() => hasil = HasilCadanganOtomatis(
          dijalankan: false, pesan: 'Cadangan otomatis dilewati: $e'));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
