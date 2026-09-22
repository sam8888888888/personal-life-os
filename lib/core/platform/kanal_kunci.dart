/// FR-26 — jembatan ke kunci perangkat (PIN/pola/sidik jari HP).
///
/// Kalau perangkat tidak punya kunci sama sekali, atau Android menolak, jawaban
/// yang dikembalikan adalah `false` — bukan galat — supaya layar kunci bisa
/// berkata apa adanya kepada pengguna.
library;

import 'package:flutter/services.dart';

const String namaKanalKunci = 'lifeos/kunci';

class KunciPerangkat {
  const KunciPerangkat({this.kanal});

  /// Kanal uji boleh disuntikkan; bawaan = kanal Android sungguhan.
  final MethodChannel? kanal;

  MethodChannel get _kanal => kanal ?? const MethodChannel(namaKanalKunci);

  /// Apakah perangkat punya kunci (PIN/pola/kata sandi/sidik jari).
  Future<bool> tersedia() async {
    try {
      return await _kanal.invokeMethod<bool>('tersedia') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Minta Android memverifikasi pemilik perangkat.
  Future<bool> buka() async {
    try {
      return await _kanal.invokeMethod<bool>('buka') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
