/// FR-45 — Bagikan berkas lewat lembar berbagi Android (WhatsApp, email, dsb).
///
/// Tanpa paket pihak ketiga: aplikasi memanggil kanal `lifeos/bagikan` yang
/// ditangani MainActivity.kt (ACTION_SEND + FileProvider).
library;

import 'package:flutter/services.dart';

/// Nama kanal — dipakai bersama oleh Dart dan MainActivity.kt.
const String kanalBagikan = 'lifeos/bagikan';

/// Minta sistem membagikan [jalur]. Mengembalikan true bila lembar berbagi
/// benar-benar terbuka; false bila tidak didukung/berkas hilang — pemanggil
/// wajib memberi tahu pengguna apa adanya, bukan menganggap berhasil.
Future<bool> bagikanBerkas({
  required String jalur,
  String judul = 'Bagikan berkas',
  String jenis = 'application/pdf',
}) async {
  try {
    final hasil = await const MethodChannel(kanalBagikan).invokeMethod<bool>(
      'bagikan',
      {'jalur': jalur, 'judul': judul, 'jenis': jenis},
    );
    return hasil ?? false;
  } on MissingPluginException {
    // Lingkungan tanpa penangan (mis. uji di desktop).
    return false;
  } on PlatformException {
    return false;
  }
}
