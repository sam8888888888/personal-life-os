/// Pintasan navigasi antar-layar Aksi & Tujuan.
///
/// Bila [rute] diisi DAN aplikasi berjalan di dalam GoRouter, layar dibuka
/// lewat rute resmi (agar tombol kembali dan tautan langsung konsisten).
/// Selain itu — termasuk untuk layar rinci yang tidak punya rute sendiri —
/// layar didorong lewat Navigator biasa.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Buka [layar] sebagai halaman baru.
void bukaLayarAksi(BuildContext context, Widget layar, {String? rute}) {
  final router = rute == null ? null : GoRouter.maybeOf(context);
  if (router != null) {
    router.push(rute!);
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => layar),
  );
}
