/// S-13 (audit keamanan 26 Sep 2026) — enkripsi isi data sinkron.
///
/// Masalah yang ditutup berkas ini: data yang naik ke server (keuangan,
/// kesehatan, catatan pribadi) tersimpan **apa adanya** di basis data server.
/// Siapa pun yang bisa membaca berkas basis data server (salinan cadangan,
/// penyedia server, atau penyerang) bisa membaca seluruh isi data pengguna.
///
/// Cara kerja:
/// * Setiap pengguna punya **kunci data** acak 32 byte (`kunciDataBaru`).
/// * Kunci data TIDAK PERNAH dikirim ke server apa adanya. Ia dibungkus
///   (`bungkusKunci`) memakai kunci turunan sandi akun
///   (PBKDF2-HMAC-SHA256, putaran seperti OWASP 2023) lalu amplopnya
///   disimpan sebagai satu catatan sinkron biasa. Tanpa sandi akun, amplop
///   itu tidak ada gunanya bagi server.
/// * Tiap catatan yang dikirim disandikan (`sandikan`) memakai kunci data:
///   AES-256-GCM (terotentikasi — perubahan sekecil apa pun membuat
///   pembukaan gagal, tidak diam-diam menghasilkan data palsu).
///
/// Sengaja MURNI Dart (bukan kanal Android/Keystore) supaya jalur
/// penyandian yang dipakai di HP adalah jalur yang sama dengan yang diuji —
/// uji di komputer menjalankan kode produksi, bukan tiruan.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../kunci/pbkdf2.dart';

/// Penanda isi catatan yang tersandi (kunci di dalam peta `isi`).
const String kunciIsiTersandi = 'terenkripsi';

/// Penanda versi amplop kunci data.
const String awalanAmplopKunci = 'plok1:';

/// Penanda versi teks tersandi.
const String awalanTeksTersandi = 'plo1:';

/// Putaran PBKDF2 untuk membungkus kunci data (selaras OWASP 2023 untuk
/// PBKDF2-HMAC-SHA256 — sama seperti PIN aplikasi).
const int putaranBungkusKunci = 600000;

/// Nama tabel penanda tempat amplop kunci data disimpan di server.
///
/// Tabel ini BUKAN tabel data: sync mengenalnya sebagai catatan biasa lalu
/// mengabaikannya, sedangkan [KunciSinkron] membacanya untuk membuka kunci.
const String tabelAmplopKunci = '__kunci_sinkron__';

/// Id catatan amplop (satu per akun).
const String idAmplopKunci = 'utama';

const int _panjangKunci = 32; // AES-256
const int _panjangNonce = 12; // GCM
const int _panjangGaram = 16;
const int _panjangTag = 16;
final Random _acak = Random.secure();

/// Kunci data baru (32 byte acak dari sumber acak aman).
List<int> kunciDataBaru() =>
    List<int>.generate(_panjangKunci, (_) => _acak.nextInt(256));

List<int> _nonceAcak() =>
    List<int>.generate(_panjangNonce, (_) => _acak.nextInt(256));

List<int> _garamAcak() =>
    List<int>.generate(_panjangGaram, (_) => _acak.nextInt(256));

/// AES-256-GCM. `null` bila kunci/tag tidak cocok atau data rusak.
Uint8List? _gcm(List<int> kunci, List<int> nonce, List<int> masukan, {required bool enkripsi}) {
  try {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        enkripsi,
        AEADParameters(
          KeyParameter(Uint8List.fromList(kunci)),
          128,
          Uint8List.fromList(nonce),
          Uint8List(0),
        ),
      );
    return cipher.process(Uint8List.fromList(masukan));
  } catch (_) {
    // Kunci salah / tag rusak / panjang tidak sah semuanya berarti "tidak bisa
    // dibuka". Pemanggil wajib memperlakukannya sebagai gagal, bukan data kosong.
    return null;
  }
}

/// Sandikan satu teks: `plo1:` + base64(nonce ‖ ciphertext ‖ tag).
String sandikan(List<int> kunci, String teks) {
  final nonce = _nonceAcak();
  final keluaran = _gcm(kunci, nonce, utf8.encode(teks), enkripsi: true);
  if (keluaran == null) {
    throw StateError('Gagal menyandikan data.');
  }
  return '$awalanTeksTersandi${base64Encode(<int>[...nonce, ...keluaran])}';
}

/// Buka teks tersandi. `null` = bukan bentuk tersandi, kunci salah, atau rusak.
String? bukaSandian(List<int> kunci, String teks) {
  if (!teks.startsWith(awalanTeksTersandi)) return null;
  List<int> mentah;
  try {
    mentah = base64Decode(teks.substring(awalanTeksTersandi.length));
  } on FormatException {
    return null;
  }
  if (mentah.length <= _panjangNonce + _panjangTag) return null;
  final nonce = mentah.sublist(0, _panjangNonce);
  final isi = mentah.sublist(_panjangNonce);
  final keluaran = _gcm(kunci, nonce, isi, enkripsi: false);
  if (keluaran == null) return null;
  try {
    return utf8.decode(keluaran);
  } on FormatException {
    return null;
  }
}

/// Bungkus kunci data dengan sandi akun:
/// `plok1:` + base64(garam ‖ putaran ‖ nonce ‖ ciphertext ‖ tag).
///
/// Jumlah putaran IKUT disimpan di dalam amplop (seperti bentuk hash sandi di
/// server) supaya putaran bisa dinaikkan kelak tanpa membuat amplop lama tidak
/// terbaca.
///
/// [garam] boleh diserahkan pada uji supaya hasilnya bisa diulang; di
/// produksi dibiarkan kosong (acak).
String bungkusKunci(
  List<int> kunciData,
  String sandi, {
  List<int>? garam,
  int putaran = putaranBungkusKunci,
}) {
  final garamDipakai = garam ?? _garamAcak();
  final kunciBungkus = hitungPbkdf2(sandi, garamDipakai, iterasi: putaran);
  final nonce = _nonceAcak();
  final keluaran = _gcm(kunciBungkus, nonce, kunciData, enkripsi: true);
  if (keluaran == null) {
    throw StateError('Gagal membungkus kunci data.');
  }
  final kepala = <int>[
    ...garamDipakai,
    (putaran >> 24) & 0xff,
    (putaran >> 16) & 0xff,
    (putaran >> 8) & 0xff,
    putaran & 0xff,
  ];
  return '$awalanAmplopKunci${base64Encode(<int>[...kepala, ...nonce, ...keluaran])}';
}

/// Putaran paling sedikit & paling banyak yang diterima dari amplop, supaya
/// amplop palsu tidak bisa memaksa perangkat menghitung selama-lamanya.
const int putaranBungkusMinimum = 1000;
const int putaranBungkusMaksimum = 5000000;

/// Buka amplop kunci data dengan sandi akun. `null` = sandi salah atau rusak.
List<int>? bukaBungkusKunci(String amplop, String sandi) {
  if (!amplop.startsWith(awalanAmplopKunci)) return null;
  List<int> mentah;
  try {
    mentah = base64Decode(amplop.substring(awalanAmplopKunci.length));
  } on FormatException {
    return null;
  }
  const kepalaPanjang = _panjangGaram + 4;
  if (mentah.length <= kepalaPanjang + _panjangNonce + _panjangTag) return null;
  final garam = mentah.sublist(0, _panjangGaram);
  var putaran = 0;
  for (var i = 0; i < 4; i++) {
    putaran = (putaran << 8) | mentah[_panjangGaram + i];
  }
  if (putaran < putaranBungkusMinimum || putaran > putaranBungkusMaksimum) {
    return null;
  }
  final nonce = mentah.sublist(kepalaPanjang, kepalaPanjang + _panjangNonce);
  final isi = mentah.sublist(kepalaPanjang + _panjangNonce);
  final kunciBungkus = hitungPbkdf2(sandi, garam, iterasi: putaran);
  final keluaran = _gcm(kunciBungkus, nonce, isi, enkripsi: false);
  if (keluaran == null || keluaran.length != _panjangKunci) return null;
  return keluaran;
}

/// Sandikan peta isi catatan. Bentuk yang dikirim ke server:
/// `{'terenkripsi': 'plo1:...'}` — server tidak pernah melihat isinya.
Map<String, dynamic> sandikanPeta(List<int> kunci, Map<String, Object?> peta) =>
    <String, dynamic>{
      kunciIsiTersandi: sandikan(kunci, jsonEncode(peta)),
    };

/// Buka peta isi catatan.
///
/// * Peta tanpa penanda `terenkripsi` = catatan lama (sebelum versi ini) →
///   dikembalikan apa adanya supaya data lama tidak hilang.
/// * Peta bertanda tetapi gagal dibuka → `null` (pemanggil harus MELEWATI
///   catatan itu, bukan memasang data kosong).
Map<String, Object?>? bukaPetaTersandi(List<int> kunci, Map<String, Object?> isi) {
  final tersandi = isi[kunciIsiTersandi];
  if (tersandi == null) return isi;
  if (tersandi is! String) return null;
  final teks = bukaSandian(kunci, tersandi);
  if (teks == null) return null;
  try {
    final dibaca = jsonDecode(teks);
    if (dibaca is! Map) return null;
    return dibaca.cast<String, Object?>();
  } on FormatException {
    return null;
  }
}
