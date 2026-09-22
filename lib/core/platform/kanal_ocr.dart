/// FR-38 & FR-50 — Kanal OCR Android (ML Kit, model terbundel di APK).
///
/// Kejujuran yang dipegang:
///   * foto diproses di perangkat; aplikasi tidak mengirim gambar/teks ke
///     server mana pun;
///   * model terbundel sehingga OCR tetap bekerja tanpa internet;
///   * kanal hanya mengembalikan teks + posisi baris — tafsir (nominal,
///     tanggal) ada di `core/parsing/ocr_tagihan.dart` supaya bisa diuji.
library;

import 'package:flutter/services.dart';

import 'kanal_media.dart' show KanalGagal;

/// Satu baris teks hasil OCR beserta posisinya (bila ada).
class BarisOcr {
  const BarisOcr({required this.teks, this.kotak});

  final String teks;

  /// [kiri, atas, kanan, bawah] dalam piksel gambar.
  final List<int>? kotak;
}

/// Hasil satu pembacaan OCR.
class HasilOcr {
  const HasilOcr({required this.teks, this.baris = const []});

  final String teks;
  final List<BarisOcr> baris;

  bool get ada => teks.trim().isNotEmpty;
}

class KanalOcr {
  KanalOcr({MethodChannel? kanal})
      : _kanal = kanal ?? const MethodChannel('lifeos/ocr');

  final MethodChannel _kanal;

  /// Apakah perangkat bisa membaca teks dari gambar.
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

  /// Baca teks dari berkas gambar di [jalur] (hasil pemilih foto/kamera).
  Future<HasilOcr> bacaTeks(String jalur) async {
    if (jalur.trim().isEmpty) {
      throw KanalGagal('Belum ada gambar yang dipilih.');
    }
    try {
      final hasil =
          await _kanal.invokeMethod<Map<dynamic, dynamic>>('bacaTeks', {
        'jalur': jalur,
      });
      if (hasil == null) {
        throw KanalGagal('Pembacaan gambar tidak mengembalikan hasil.');
      }
      final daftar = <BarisOcr>[];
      final mentah = hasil['baris'];
      if (mentah is List) {
        for (final b in mentah) {
          if (b is! Map) continue;
          final teks = (b['teks'] ?? '').toString();
          if (teks.trim().isEmpty) continue;
          List<int>? kotak;
          if (b['kiri'] is int && b['atas'] is int && b['kanan'] is int &&
              b['bawah'] is int) {
            kotak = [
              b['kiri'] as int,
              b['atas'] as int,
              b['kanan'] as int,
              b['bawah'] as int,
            ];
          }
          daftar.add(BarisOcr(teks: teks, kotak: kotak));
        }
      }
      return HasilOcr(teks: (hasil['teks'] ?? '').toString(), baris: daftar);
    } on MissingPluginException {
      throw KanalGagal(
          'Perangkat ini tidak menyediakan pembacaan teks dari gambar.');
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'berkas_tidak_ada':
          throw KanalGagal('Gambar tidak ditemukan — pilih ulang fotonya.');
        case 'berkas_kosong':
          throw KanalGagal('Belum ada gambar yang dipilih.');
        case 'gagal_baca':
          throw KanalGagal(
              'Gambar ini belum bisa dibaca (${e.message ?? 'tidak jelas'}). '
              'Coba foto yang lebih terang dan tidak miring.');
        default:
          throw KanalGagal('Pembacaan gambar gagal (${e.code}).');
      }
    }
  }
}

/// Kalimat jujur tentang batas fitur OCR (ditampilkan di layar).
const String catatanKanalOcr =
    'Foto dibaca di perangkat ini dengan model yang sudah tertanam di aplikasi '
    '(ML Kit) — jadi tetap jalan tanpa internet dan tidak ada gambar yang '
    'dikirim ke server mana pun. Hasil bacaannya masih berupa DRAF: periksa '
    'dulu angkanya, baru disimpan.';
