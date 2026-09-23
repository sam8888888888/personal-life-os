/// FR-45 — Bagikan berkas lewat lembar berbagi Android (WhatsApp, email, dsb).
///
/// Tanpa paket pihak ketiga: aplikasi memanggil kanal `lifeos/bagikan` yang
/// ditangani MainActivity.kt (ACTION_SEND + FileProvider).
///
/// AUDIT 23 Sep 2026 (P2-1): `res/xml/berkas_paths.xml` dulu membuka SELURUH
/// folder dokumen/cache/berkas eksternal ke FileProvider. Sekarang FileProvider
/// hanya boleh menerbitkan URI untuk folder `cache/bagikan/`, jadi fungsi ini
/// menyalin berkasnya lebih dulu ke situ — berkas asli (cadangan JSON, lampiran
/// medis, dokumen keluarga) tidak pernah punya URI yang bisa diminta aplikasi
/// lain.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Nama kanal — dipakai bersama oleh Dart dan MainActivity.kt.
const String kanalBagikan = 'lifeos/bagikan';

/// Berapa salinan terakhir yang disimpan di folder bagikan.
const int batasSalinanBagikan = 6;

/// Minta sistem membagikan [jalur]. Mengembalikan true bila lembar berbagi
/// benar-benar terbuka; false bila tidak didukung/berkas hilang — pemanggil
/// wajib memberi tahu pengguna apa adanya, bukan menganggap berhasil.
Future<bool> bagikanBerkas({
  required String jalur,
  String judul = 'Bagikan berkas',
  String jenis = 'application/pdf',
}) async {
  final siapDibagikan = await salinanUntukBagikan(jalur);
  try {
    final hasil = await const MethodChannel(kanalBagikan).invokeMethod<bool>(
      'bagikan',
      {'jalur': siapDibagikan, 'judul': judul, 'jenis': jenis},
    );
    return hasil ?? false;
  } on MissingPluginException {
    // Lingkungan tanpa penangan (mis. uji di desktop).
    return false;
  } on PlatformException {
    return false;
  }
}

/// Salin [jalur] ke `cache/bagikan/` — satu-satunya folder yang boleh
/// diterbitkan URI-nya oleh FileProvider.
///
/// Bila lingkungan tidak punya `path_provider` (uji di desktop) atau
/// penyalinan gagal, jalur asli dikembalikan supaya perilaku lama tetap
/// berjalan dan galatnya tidak disembunyikan.
Future<String> salinanUntukBagikan(String jalur) async {
  try {
    final asal = File(jalur);
    if (!asal.existsSync()) return jalur;
    final folderSementara = await getTemporaryDirectory();
    final folder = Directory(
        '${folderSementara.path}${Platform.pathSeparator}bagikan');
    if (!folder.existsSync()) folder.createSync(recursive: true);
    final nama = jalur.split(Platform.pathSeparator).last;
    final tujuan = File('${folder.path}${Platform.pathSeparator}$nama');
    await asal.copy(tujuan.path);
    await bersihkanSalinanBagikan(folder);
    return tujuan.path;
  } catch (_) {
    return jalur;
  }
}

/// Sisakan beberapa salinan terbaru saja supaya folder cache tidak menumpuk
/// (isi berkas bisa berisi data pribadi — tidak perlu disimpan lama).
Future<void> bersihkanSalinanBagikan(Directory folder) async {
  try {
    final berkas = folder
        .listSync()
        .whereType<File>()
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    for (final f in berkas.skip(batasSalinanBagikan)) {
      try {
        f.deleteSync();
      } catch (_) {
        // Tidak bisa dihapus: biarkan, bukan kegagalan yang perlu dilaporkan.
      }
    }
  } catch (_) {
    // Folder tidak terbaca: tidak menggagalkan pembagian berkas.
  }
}
