/// FR-22 — lencana angka di ikon peluncur (badge).
library;

import 'package:flutter/services.dart';

const String namaKanalLencana = 'lifeos/lencana';

class LencanaIkon {
  const LencanaIkon({this.kanal});

  final MethodChannel? kanal;

  MethodChannel get _kanal => kanal ?? const MethodChannel(namaKanalLencana);

  /// Pasang angka di ikon aplikasi. Angka 0 = hapus lencana.
  ///
  /// Jawaban `false` berarti peluncur HP ini tidak mendukung lencana — bukan
  /// kegagalan aplikasi.
  Future<bool> pasang(int jumlah) async {
    try {
      return await _kanal.invokeMethod<bool>('pasang', {'jumlah': jumlah}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
