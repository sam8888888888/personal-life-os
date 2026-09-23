/// Konfigurasi uji bersama — dijalankan `flutter test` sekali sebelum SETIAP
/// berkas uji di folder ini.
///
/// KENAPA ADA BERKAS INI
/// Kanal platform (`lifeos/rahasia`, brankas Keystore) diuji dengan brankas
/// tiruan yang hidup di memori. Di dalam uji widget, panggilan kanal SUNGGUHAN
/// tidak pernah selesai di dalam `pumpAndSettle` (jawabannya dikirim lewat
/// gelung peristiwa asli, sedangkan uji berjalan di waktu tiruan) — akibatnya
/// layar tampak "berputar selamanya" dan uji gagal karena waktu habis, bukan
/// karena ada kerusakan aplikasi.
///
/// ATURAN (pelajaran 23 Sep 2026 — uji layar akun menggantung 3 menit)
/// Uji **widget** TIDAK boleh bergantung pada kanal ini. Untuk itu
/// `PenyimpanRahasia` menerima gudang yang DISUNTIK
/// (`PenyimpanRahasia(pengaturan, gudang: …)`); uji widget menyuntik gudang
/// dalam memori. Tiruan kanal di berkas ini hanya menolong `test()` biasa
/// (waktu nyata).
///
/// YANG DITIRUKAN
/// 1. Brankas: perangkat yang PUNYA Keystore (`didukung` = true), isi disimpan
///    di peta memori.
/// 2. Enkripsi berkas cadangan (`enkripsiSandi`/`dekripsiSandi`) ditirukan
///    dengan **XOR + HMAC-SHA256** — BUKAN AES-256-GCM. Enkripsi sungguhan ada
///    di sisi Android (`BrankasRahasia.kt`, Keystore) dan hanya bisa dibuktikan
///    di perangkat. Tiruan ini tetap punya sifat penting yang diuji: hasilnya
///    tidak terbaca sebagai teks biasa, sandi salah ditolak, dan amplop yang
///    diubah (dirusak) juga ditolak.
///
/// Berkas ini TIDAK boleh dipakai untuk mengklaim apa pun sebagai "aman".
library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _kanalRahasia = MethodChannel('lifeos/rahasia');

/// Isi brankas tiruan (nama → nilai).
final Map<String, String> _isiBrankas = <String, String>{};

// ── Tiruan enkripsi cadangan (bukan AES-GCM) ────────────────────────────────

const String _penanda = 'UJIENC1:';

List<int> _aliranKunci(Hmac hmac, List<int> garam, int panjang) {
  final List<int> keluar = <int>[];
  for (int blok = 0; keluar.length < panjang; blok++) {
    keluar.addAll(
        hmac.convert(<int>[...garam, ...utf8.encode('blok$blok')]).bytes);
  }
  return keluar.sublist(0, panjang);
}

String _enkripsiUji(String teks, String sandi) {
  final Hmac hmac = Hmac(sha256, utf8.encode(sandi));
  final List<int> garam =
      List<int>.generate(16, (int i) => (i * 31 + sandi.length * 7) % 256);
  final List<int> isi = utf8.encode(teks);
  final List<int> aliran = _aliranKunci(hmac, garam, isi.length);
  final List<int> tersandi = <int>[
    for (int i = 0; i < isi.length; i++) isi[i] ^ aliran[i],
  ];
  final List<int> tag =
      hmac.convert(<int>[...garam, ...tersandi]).bytes.sublist(0, 16);
  return _penanda + base64Url.encode(<int>[...garam, ...tag, ...tersandi]);
}

String? _dekripsiUji(String amplop, String sandi) {
  if (!amplop.startsWith(_penanda)) return null;
  final List<int> mentah =
      base64Url.decode(amplop.substring(_penanda.length));
  if (mentah.length < 32) return null;
  final List<int> garam = mentah.sublist(0, 16);
  final List<int> tag = mentah.sublist(16, 32);
  final List<int> tersandi = mentah.sublist(32);
  final Hmac hmac = Hmac(sha256, utf8.encode(sandi));
  final List<int> tagHarus =
      hmac.convert(<int>[...garam, ...tersandi]).bytes.sublist(0, 16);
  for (int i = 0; i < tag.length; i++) {
    // Sama seperti GCM: sandi salah atau berkas diubah → ditolak.
    if (tag[i] != tagHarus[i]) return null;
  }
  final List<int> aliran = _aliranKunci(hmac, garam, tersandi.length);
  final List<int> isi = <int>[
    for (int i = 0; i < tersandi.length; i++) tersandi[i] ^ aliran[i],
  ];
  try {
    return utf8.decode(isi);
  } catch (_) {
    return null;
  }
}

Future<Object?> _jawabRahasia(MethodCall panggilan) async {
  switch (panggilan.method) {
    case 'didukung':
      return true;
    case 'simpan':
      _isiBrankas[panggilan.arguments['nama'] as String] =
          panggilan.arguments['nilai'] as String;
      return true;
    case 'baca':
      return _isiBrankas[panggilan.arguments['nama'] as String];
    case 'hapus':
      _isiBrankas.remove(panggilan.arguments['nama'] as String);
      return true;
    case 'ada':
      return _isiBrankas.containsKey(panggilan.arguments['nama'] as String);
    case 'enkripsiSandi':
      return _enkripsiUji(
        panggilan.arguments['teks'] as String,
        panggilan.arguments['sandi'] as String,
      );
    case 'dekripsiSandi':
      return _dekripsiUji(
        panggilan.arguments['amplop'] as String,
        panggilan.arguments['sandi'] as String,
      );
  }
  return null;
}

/// Dipanggil oleh `flutter test` sebelum berkas uji mana pun berjalan.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  _isiBrankas.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_kanalRahasia, _jawabRahasia);

  // Catatan: addTearDown() TIDAK boleh dipanggil di sini (di luar sebuah uji)
  // — pernah membuat seluruh berkas uji gagal dimuat ("may only be called
  // within a test"). Pembersihan cukup dilakukan saat awal.
  await testMain();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_kanalRahasia, null);
  _isiBrankas.clear();
}
