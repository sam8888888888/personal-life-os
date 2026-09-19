/// Pilihan tema (FR-21): Terang / Gelap / Ikuti sistem.
///
/// Pola sama seperti pilihan mata uang: disimpan di tabel `pengaturan`, dibaca
/// sekali saat aplikasi mulai, lalu dipakai `MaterialApp.themeMode`.
///
/// Ukuran teks tidak diatur di sini: aplikasi mengikuti pengaturan ukuran teks
/// sistem perangkat (bawaan Flutter), jadi tidak ada saklar kedua yang bisa
/// bertentangan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../data/database/database.dart';

/// Kunci baris di tabel `pengaturan`.
const String kunciModeTema = 'mode_tema';

/// Tiga pilihan tema yang dikenali aplikasi.
enum ModeTema {
  sistem('sistem', 'Ikuti sistem', ThemeMode.system),
  terang('terang', 'Terang', ThemeMode.light),
  gelap('gelap', 'Gelap', ThemeMode.dark);

  const ModeTema(this.kode, this.label, this.mode);

  /// Nilai yang disimpan di basis data.
  final String kode;

  /// Teks yang tampil di Pengaturan.
  final String label;

  /// Terjemahan ke `MaterialApp.themeMode`.
  final ThemeMode mode;
}

/// Kode teks menjadi enum; kode tak dikenal kembali ke "Ikuti sistem".
ModeTema modeTemaDariKode(String? kode) {
  if (kode == null) return ModeTema.sistem;
  final k = kode.trim().toLowerCase();
  for (final m in ModeTema.values) {
    if (m.kode == k) return m;
  }
  return ModeTema.sistem;
}

/// Baca pilihan tersimpan; gagal baca = ikuti sistem (tidak menghalangi app).
Future<ModeTema> bacaModeTema(AppDatabase db) async {
  try {
    final baris = await (db.select(db.pengaturan)
          ..where((p) => p.kunci.equals(kunciModeTema)))
        .getSingleOrNull();
    return modeTemaDariKode(baris?.nilai);
  } catch (_) {
    return ModeTema.sistem;
  }
}

/// Simpan pilihan tema.
Future<void> simpanModeTema(AppDatabase db, ModeTema m) async {
  await db.into(db.pengaturan).insertOnConflictUpdate(
      PengaturanCompanion.insert(kunci: kunciModeTema, nilai: m.kode));
}

/// Pilihan tema aktif (dibaca dari basis data, lalu dipakai layar).
final modeTemaProvider = FutureProvider<ModeTema>(
    (ref) => bacaModeTema(ref.watch(databaseProvider)));

/// Pembungkus kecil: memuat pilihan tema saat aplikasi dibuka.
class MuatModeTema extends ConsumerWidget {
  const MuatModeTema({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(modeTemaProvider);
    return child;
  }
}
