/// FR-108 — enkripsi berkas brankas medis lewat Android Keystore.
///
/// Tanpa paket Dart pihak ketiga: aplikasi memanggil kanal `lifeos/berkas_medis`
/// yang ditangani `KanalMedia.kt` (AES/GCM 256-bit, kunci disimpan di Android
/// Keystore — tidak pernah keluar dari perangkat).
///
/// Aturan yang dijaga:
/// 1. Bila perangkat/kanal tidak mendukung, [enkripsiBerkas] mengembalikan
///    false dan **berkas mentah TIDAK disimpan** — layar wajib mengatakan apa
///    adanya, bukan menyimpan rahasia tanpa perlindungan.
/// 2. [perangkatTerkunci] dipakai kartu darurat (FR-117) untuk memutuskan
///    apakah rincian sensitif boleh ditampilkan.
library;

import 'package:flutter/services.dart';

/// Nama kanal — dipakai bersama Dart dan `KanalMedia.kt`.
const String kanalBerkasMedis = 'lifeos/berkas_medis';

/// Apakah enkripsi tersedia di perangkat ini.
Future<bool> enkripsiDidukung() async {
  try {
    final hasil = await const MethodChannel(kanalBerkasMedis)
        .invokeMethod<bool>('didukung');
    return hasil ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

/// Enkripsi [sumber] menjadi berkas [tujuan] (AES/GCM, kunci di Keystore).
///
/// Mengembalikan true hanya bila berkas hasil benar-benar ada dan terenkripsi.
Future<bool> enkripsiBerkas({
  required String sumber,
  required String tujuan,
}) async {
  try {
    final hasil = await const MethodChannel(kanalBerkasMedis)
        .invokeMethod<bool>('enkripsi', {'sumber': sumber, 'tujuan': tujuan});
    return hasil ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

/// Dekripsi [sumber] menjadi berkas sementara [tujuan] (untuk dibuka/dibagikan).
Future<bool> dekripsiBerkas({
  required String sumber,
  required String tujuan,
}) async {
  try {
    final hasil = await const MethodChannel(kanalBerkasMedis)
        .invokeMethod<bool>('dekripsi', {'sumber': sumber, 'tujuan': tujuan});
    return hasil ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

/// Apakah layar perangkat sedang terkunci (dipakai kartu darurat FR-117).
///
/// Bila kanal tidak ada (mis. pengujian di desktop), dianggap **terkunci**
/// supaya rincian sensitif TIDAK tampil karena ragu-ragu — pilihan yang aman.
Future<bool> perangkatTerkunci() async {
  try {
    final hasil = await const MethodChannel(kanalBerkasMedis)
        .invokeMethod<bool>('terkunci');
    return hasil ?? true;
  } on MissingPluginException {
    return true;
  } on PlatformException {
    return true;
  }
}
