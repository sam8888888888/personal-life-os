/// Kanal Android untuk lampiran (FR-118: foto & rekaman suara) dan pemilih
/// berkas (FR-27: sinkron lewat berkas).
///
/// Sengaja tanpa paket tambahan — cukup MethodChannel ke KanalMedia.kt.
/// Kalau kanal tidak tersedia (uji/desktop), pemanggilan melempar
/// [KanalGagal] dengan pesan ramah supaya layar bisa mengatakannya apa adanya.
library;

import 'dart:io';

import 'package:flutter/services.dart';

class KanalGagal implements Exception {
  KanalGagal(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}

class KanalMedia {
  KanalMedia({MethodChannel? kanal}) : _kanal = kanal ?? const MethodChannel('lifeos/media');

  final MethodChannel _kanal;

  /// Ada di Android & kanal tersedia = fitur kamera/mikrofon bisa dipakai.
  static bool get didukung => Platform.isAndroid;

  Future<String?> _panggil(String metode, [Map<String, dynamic>? argumen]) async {
    try {
      final hasil = await _kanal.invokeMethod<String?>(metode, argumen);
      return hasil;
    } on PlatformException catch (e) {
      final pesan = switch (e.code) {
        'izin_ditolak' => 'Izin tidak diberikan — buka Pengaturan HP lalu izinkan '
            'kamera/mikrofon untuk Personal Life OS.',
        'tidak_ada' => 'Berkasnya tidak ditemukan di HP ini.',
        'tidak_merekam' => 'Tidak ada rekaman yang sedang berjalan.',
        'gagal_rekam' => 'Gagal merekam suara: ${e.message ?? "sebab tidak diketahui"}',
        _ => 'Gagal: ${e.message ?? e.code}',
      };
      throw KanalGagal(pesan);
    } on MissingPluginException {
      throw KanalGagal('Fitur ini hanya tersedia di aplikasi Android.');
    }
  }

  /// Foto baru dari kamera. Mengembalikan jalur berkas sementara (null = batal).
  Future<String?> ambilFoto() => _panggil('ambilFoto');

  /// Foto yang sudah ada di galeri/penyimpanan.
  Future<String?> pilihFoto() => _panggil('pilihFoto');

  /// Berkas apa pun (dipakai sinkron lewat berkas, FR-27).
  Future<String?> pilihBerkas({String mime = '*/*'}) =>
      _panggil('pilihBerkas', <String, dynamic>{'mime': mime});

  /// Mulai merekam suara. Mengembalikan "mulai".
  Future<String?> mulaiRekam() => _panggil('mulaiRekam');

  /// Hentikan rekaman. Mengembalikan jalur berkas suara (null = kosong).
  Future<String?> hentikanRekam() => _panggil('hentikanRekam');

  Future<bool> putarSuara(String jalur) async =>
      (await _panggil('putarSuara', <String, dynamic>{'jalur': jalur})) != null;

  Future<bool> hentikanSuara() async =>
      (await _panggil('hentikanSuara')) != null;
}
