/// Pilihan mata uang (FR-67): simpan ke tabel pengaturan (kunci-nilai) dan
/// muat sekali saat aplikasi mulai.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/mata_uang.dart';
import '../../data/database/database.dart';

/// Kunci baris di tabel `pengaturan`.
const kunciMataUang = 'mata_uang';

/// Baca pilihan tersimpan; gagal baca = Rupiah (jangan menghalangi aplikasi).
Future<MataUang> bacaMataUang(AppDatabase db) async {
  try {
    final baris = await (db.select(db.pengaturan)
          ..where((p) => p.kunci.equals(kunciMataUang)))
        .getSingleOrNull();
    return mataUangDariKode(baris?.nilai);
  } catch (e) {
    return MataUang.idr;
  }
}

/// Simpan pilihan dan langsung pakai di seluruh aplikasi.
Future<void> simpanMataUang(AppDatabase db, MataUang m) async {
  await db.into(db.pengaturan).insertOnConflictUpdate(
      PengaturanCompanion.insert(kunci: kunciMataUang, nilai: m.kode));
  pakaiMataUang(m);
}

/// Pilihan mata uang aktif (dibaca dari database sekali, lalu di-cache).
final mataUangProvider = FutureProvider<MataUang>((ref) async {
  final m = await bacaMataUang(ref.watch(databaseProvider));
  pakaiMataUang(m);
  return m;
});

/// Pembungkus kecil: memuat pilihan mata uang saat aplikasi dibuka.
class MuatMataUang extends ConsumerWidget {
  const MuatMataUang({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(mataUangProvider);
    return child;
  }
}
