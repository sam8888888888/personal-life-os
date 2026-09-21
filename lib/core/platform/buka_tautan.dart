/// FR-49 — Membuka tautan aplikasi lain (WhatsApp / SMS / Telegram).
///
/// Tanpa paket pihak ketiga: Dart memanggil kanal `lifeos/buka` yang ditangani
/// MainActivity.kt dengan Intent ACTION_VIEW.
library;

import 'package:flutter/services.dart';

/// Nama kanal — dipakai bersama oleh Dart dan MainActivity.kt.
const String kanalBukaTautan = 'lifeos/buka';

/// Minta Android membuka [tautan]. true = ada aplikasi yang menanganinya.
/// false = tidak ada (mis. WhatsApp belum dipasang) — pemanggil wajib bilang
/// apa adanya ke pengguna.
Future<bool> bukaTautan(String tautan) async {
  try {
    final hasil = await const MethodChannel(kanalBukaTautan)
        .invokeMethod<bool>('bukaTautan', {'tautan': tautan});
    return hasil ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}
