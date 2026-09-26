/// PBKDF2-HMAC-SHA256 — sengaja dipisah dari `kunci_aplikasi.dart` supaya bisa
/// dipakai modul yang **tidak bergantung Flutter** (mis. alat uji jaringan
/// `tool/uji_enkripsi_server.dart`, yang dijalankan dengan `dart run`).
///
/// Dipakai oleh: PIN kunci aplikasi (FR-26) dan pembungkus kunci data sinkron
/// (S-13). Murni `package:crypto` — tanpa pustaka tambahan.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Putaran PBKDF2 bawaan. Uji memakai angka kecil supaya cepat.
const int kunciIterasiBawaan = 600000;

/// PBKDF2-HMAC-SHA256 (dipakai PIN aplikasi & pembungkus kunci data sinkron).
List<int> hitungPbkdf2(String sandi, List<int> garam,
    {int iterasi = kunciIterasiBawaan, int panjang = 32}) {
  final hmac = Hmac(sha256, utf8.encode(sandi));
  final keluaran = <int>[];
  var blokKe = 1;
  while (keluaran.length < panjang) {
    final awal = <int>[
      ...garam,
      (blokKe >> 24) & 0xff,
      (blokKe >> 16) & 0xff,
      (blokKe >> 8) & 0xff,
      blokKe & 0xff,
    ];
    var u = hmac.convert(awal).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iterasi; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    keluaran.addAll(t);
    blokKe++;
  }
  return keluaran.sublist(0, panjang);
}
