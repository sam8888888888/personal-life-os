/// FR-58 — Kanal suara Android (SpeechRecognizer bawaan, tanpa paket tambahan).
///
/// Kejujuran yang dipegang kanal ini:
///   * hanya MENGEMBALIKAN teks hasil pengenalan — rekaman tidak pernah
///     disimpan atau dikirim ke luar perangkat oleh aplikasi;
///   * kanal tersedia ditanyakan lebih dulu ([tersedia]) supaya layar bisa
///     memberi tahu apa adanya kalau perangkat/uji tidak mendukung;
///   * kalau gagal, [KanalGagal] dilempar dengan pesan ramah, bukan diam-diam.
///
/// Pengenalan suara Android sendiri bisa memakai model di perangkat atau
/// layanan Google sesuai setelan HP pengguna — itu di luar kendali aplikasi,
/// dan disebutkan di layar.
library;

import 'package:flutter/services.dart';

import 'kanal_media.dart' show KanalGagal;

/// Satu hasil pengenalan suara.
class HasilSuara {
  const HasilSuara({required this.teks, this.alternatif = const []});

  /// Teks terbaik menurut pengenal suara.
  final String teks;

  /// Teks alternatif (kalau ada) — dipakai pengguna bila yang utama salah.
  final List<String> alternatif;

  bool get ada => teks.trim().isNotEmpty;
}

class KanalSuara {
  KanalSuara({MethodChannel? kanal})
      : _kanal = kanal ?? const MethodChannel('lifeos/suara');

  final MethodChannel _kanal;

  /// Bahasa pengenalan (Indonesia).
  static const String bahasa = 'id-ID';

  /// Apakah perangkat punya pengenal suara.
  Future<bool> tersedia() async {
    try {
      final hasil = await _kanal.invokeMethod<bool>('tersedia');
      return hasil ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Mulai mendengar satu kalimat. Hasil berupa teks; durasi maksimum 15 detik.
  Future<HasilSuara> dengar({String locale = bahasa, int detikMaks = 15}) async {
    try {
      final hasil = await _kanal.invokeMethod<Map<dynamic, dynamic>>('dengar', {
        'locale': locale,
        'detikMaks': detikMaks,
      });
      if (hasil == null) {
        throw KanalGagal('Pengenalan suara tidak mengembalikan hasil.');
      }
      final teks = (hasil['teks'] ?? '').toString();
      final alt = <String>[];
      final mentah = hasil['alternatif'];
      if (mentah is List) {
        for (final a in mentah) {
          final s = a.toString().trim();
          if (s.isNotEmpty) alt.add(s);
        }
      }
      return HasilSuara(teks: teks.trim(), alternatif: alt);
    } on MissingPluginException {
      throw KanalGagal(
          'Perangkat ini belum mendukung pengenalan suara lewat aplikasi.');
    } on PlatformException catch (e) {
      throw KanalGagal(_pesan(e));
    }
  }

  String _pesan(PlatformException e) {
    switch (e.code) {
      case 'izin_ditolak':
        return 'Izin mikrofon tidak diberikan, jadi suara belum bisa direkam. '
            'Anda masih bisa menuliskan kalimatnya langsung.';
      case 'tidak_tersedia':
        return 'Pengenal suara tidak ditemukan di perangkat ini. '
            'Anda masih bisa menuliskan kalimatnya langsung.';
      case 'kosong':
        return 'Suara tidak terdengar jelas. Coba lagi atau tuliskan '
            'kalimatnya.';
      default:
        return 'Pengenalan suara gagal (${e.code}). Anda masih bisa menuliskan '
            'kalimatnya langsung.';
    }
  }
}

/// Kalimat jujur tentang batas fitur suara (ditampilkan di layar).
const String catatanKanalSuara =
    'Suara diproses oleh fitur pengenalan bawaan Android — aplikasi ini hanya '
    'menerima teksnya dan tidak menyimpan rekaman. Beberapa HP memakai model '
    'di perangkat, sebagian memakai layanan Google sesuai setelan Anda. Tidak '
    'ada hasil yang langsung tersimpan: semuanya masih berupa draf yang harus '
    'Anda setujui.';
