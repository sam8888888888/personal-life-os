/// FR-39 — Kanal SMS Android (hanya baca, hanya bank, hanya bila diizinkan).
///
/// Prinsipnya:
///   * [izinDiberikan] menanyakan izin READ_SMS ke sistem; aplikasi TIDAK
///     pernah meminta izin diam-diam di latar belakang;
///   * [bacaSejak] hanya mengembalikan pengirim + isi + waktu — tidak ada
///     yang dikirim ke jaringan oleh kanal ini;
///   * kalau perangkat/uji tidak punya plugin-nya, [KanalGagal] dilempar
///     dengan pesan ramah supaya layar bisa mengatakan apa adanya.
library;

import 'package:flutter/services.dart';

import 'kanal_media.dart' show KanalGagal;

/// Satu pesan dari kotak masuk SMS.
class PesanSms {
  const PesanSms({
    required this.id,
    required this.pengirim,
    required this.isi,
    required this.waktu,
  });

  final int id;
  final String pengirim;
  final String isi;
  final DateTime waktu;
}

class KanalSms {
  KanalSms({MethodChannel? kanal})
      : _kanal = kanal ?? const MethodChannel('lifeos/sms');

  final MethodChannel _kanal;

  /// Apakah perangkat ini bisa membaca SMS (Android & plugin terpasang).
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

  /// Apakah izin baca SMS sudah diberikan.
  Future<bool> izinDiberikan() async {
    try {
      final hasil = await _kanal.invokeMethod<bool>('izinDiberikan');
      return hasil ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Minta izin baca SMS (dialog sistem). Mengembalikan true bila disetujui.
  Future<bool> mintaIzin() async {
    try {
      final hasil = await _kanal.invokeMethod<bool>('mintaIzin');
      return hasil ?? false;
    } on MissingPluginException {
      throw KanalGagal('Fitur baca SMS tidak tersedia di perangkat ini.');
    } on PlatformException catch (e) {
      throw KanalGagal('Izin baca SMS gagal diminta (${e.code}).');
    }
  }

  /// Baca SMS sejak [sejak] (batas [batas] pesan terakhir).
  ///
  /// Penyaringan bank dilakukan di Dart (`saringPesanBank`) supaya aturan yang
  /// diuji sama dengan yang dipakai di layar.
  Future<List<PesanSms>> bacaSejak(DateTime sejak, {int batas = 200}) async {
    try {
      final hasil = await _kanal.invokeMethod<List<dynamic>>('bacaSejak', {
        'sejakMs': sejak.millisecondsSinceEpoch,
        'batas': batas,
      });
      if (hasil == null) return const [];
      final pesan = <PesanSms>[];
      for (final baris in hasil) {
        if (baris is! Map) continue;
        final id = baris['id'];
        final isi = baris['isi'];
        final pengirim = baris['pengirim'];
        final waktu = baris['waktuMs'];
        if (id is! int || isi is! String || pengirim is! String) continue;
        pesan.add(PesanSms(
          id: id,
          pengirim: pengirim,
          isi: isi,
          waktu: waktu is int
              ? DateTime.fromMillisecondsSinceEpoch(waktu)
              : DateTime.now(),
        ));
      }
      return pesan;
    } on MissingPluginException {
      throw KanalGagal('Fitur baca SMS tidak tersedia di perangkat ini.');
    } on PlatformException catch (e) {
      if (e.code == 'izin_ditolak') {
        throw KanalGagal('Izin baca SMS belum diberikan.');
      }
      throw KanalGagal('Gagal membaca SMS (${e.code}).');
    }
  }
}
