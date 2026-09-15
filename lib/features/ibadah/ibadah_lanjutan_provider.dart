/// Provider untuk layar ibadah lanjutan (FR-91/92/93/95/100).
///
/// Berkas ini hanya MEMBACA provider yang sudah ada (`databaseProvider`,
/// `pengaturanRepoProvider`) — tidak mengubahnya. Rute GoRouter tidak
/// disambungkan di sini (itu tugas Dinda di `lib/app_router.dart`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../data/repository/ibadah_lanjutan_repository.dart';
import 'pengaturan_ibadah.dart';
import 'setelan_ibadah_lanjutan.dart';

/// Repositori ibadah lanjutan (satu instance untuk seluruh aplikasi).
final ibadahLanjutanRepoProvider = Provider<IbadahLanjutanRepository>(
    (ref) => IbadahLanjutanRepository(ref.watch(databaseProvider)));

/// Setelan ibadah bersama (satu pintu dengan layar Jadwal Sholat).
final setelanIbadahProvider = Provider<PengaturanIbadah>(
    (ref) => PengaturanIbadah.dariRepository(ref.watch(pengaturanRepoProvider)));

/// Setelan tambahan khusus ibadah lanjutan.
final setelanIbadahLanjutanProvider = Provider<SetelanIbadahLanjutan>(
    (ref) => SetelanIbadahLanjutan(ref.watch(setelanIbadahProvider).simpanan));
