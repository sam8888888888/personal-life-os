/// FR-37 — `tangkapPng`: ubah widget menjadi gambar PNG.
///
/// Dipakai kartu berbagi rekap tahunan (menggambar kartu, lalu dibagikan lewat
/// lembar berbagi Android — kanal `lifeos/bagikan`). Dipisah dari layar supaya
/// bisa diuji tanpa perangkat.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Tangkap widget yang dibungkus [RepaintBoundary] dengan kunci [kunci].
///
/// Mengembalikan null bila widgetnya belum tergambar atau bukan RepaintBoundary
/// — pemanggil wajib memberi tahu pengguna apa adanya, bukan menganggap sukses.
Future<Uint8List?> tangkapPng(GlobalKey kunci, {double rasio = 3}) async {
  final objek = kunci.currentContext?.findRenderObject();
  if (objek is! RenderRepaintBoundary) return null;
  final ui.Image gambar = await objek.toImage(pixelRatio: rasio);
  try {
    final data = await gambar.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    return data.buffer.asUint8List();
  } finally {
    gambar.dispose();
  }
}

/// Penanda awal berkas PNG (dipakai uji & pemeriksaan cepat).
bool pngSah(Uint8List? bytes) {
  if (bytes == null || bytes.length < 8) return false;
  const penanda = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < penanda.length; i++) {
    if (bytes[i] != penanda[i]) return false;
  }
  return true;
}
