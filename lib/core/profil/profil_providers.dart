/// Penghubung profil (FR-44) — Riverpod.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profil.dart';

/// Layanan profil. Diisi `main()` dengan folder dokumen aplikasi
/// (`overrideWithValue`); bawaan ini hanya jaring pengaman.
final profilLayananProvider = Provider<ProfilLayanan>(
    (ref) => ProfilLayanan(folder: Directory.systemTemp));

/// Daftar profil saat aplikasi dimulai. `main()` membacanya sekali sebelum
/// `runApp` supaya basis data profil yang benar dibuka sejak awal.
final profilAwalProvider =
    Provider<DaftarProfil>((ref) => DaftarProfil.bawaan);

/// Profil yang sedang dipakai. Mengubahnya langsung mengganti basis data
/// (karena `databaseProvider` mengawasi nilai ini).
class ProfilAktifNotifier extends Notifier<DaftarProfil> {
  @override
  DaftarProfil build() => ref.watch(profilAwalProvider);

  ProfilLayanan get _layanan => ref.read(profilLayananProvider);

  Future<void> ganti(String id) async => state = await _layanan.ganti(id);

  Future<void> tambah(String nama, JenisProfil jenis) async =>
      state = await _layanan.tambah(nama, jenis);

  Future<void> gantiNama(String id, String nama) async =>
      state = await _layanan.gantiNama(id, nama);

  Future<void> hapus(String id) async => state = await _layanan.hapus(id);

  Future<void> muatUlang() async => state = await _layanan.muat();
}

final profilAktifProvider =
    NotifierProvider<ProfilAktifNotifier, DaftarProfil>(ProfilAktifNotifier.new);
