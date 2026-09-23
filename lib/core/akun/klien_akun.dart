/// Klien API akun & sinkron — Personal Life OS.
///
/// Sengaja TIDAK memakai paket tambahan: cukup `dart:io` + `dart:convert`.
/// Pengiriman HTTP bisa diganti (disuntik) supaya bisa diuji tanpa jaringan.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Alamat server akun (server sendiri, lewat HTTPS).
///
/// Alamatnya TIDAK ditulis tetap di kode supaya snapshot publik tidak
/// memuat alamat server pribadi (hasil audit 23 Sep 2026, P2-4). Saat
/// membangun untuk perangkat, arahkan lewat:
///
/// ```
/// flutter build apk --release \
///   --dart-define=LIFEOS_API=https://server-anda.example/lifeos-api
/// ```
///
/// Tanpa `--dart-define`, nilai bawaan di bawah yang dipakai.
const String alamatServerBawaan = String.fromEnvironment(
  'LIFEOS_API',
  defaultValue: 'https://coder.sam.university/lifeos-api',
);

/// Sesi akun yang tersimpan di perangkat.
class AkunSesi {
  const AkunSesi({required this.token, required this.email, required this.nama});

  final String token;
  final String email;
  final String nama;

  Map<String, dynamic> keJson() => {'token': token, 'email': email, 'nama': nama};

  static AkunSesi? dariJson(Map<String, dynamic> j) {
    final token = j['token'] as String?;
    final email = j['email'] as String?;
    final nama = j['nama'] as String?;
    if (token == null || token.isEmpty || email == null) return null;
    return AkunSesi(token: token, email: email, nama: nama ?? email);
  }

  @override
  String toString() => 'AkunSesi($email)';
}

/// Kegagalan yang pesannya sudah ramah untuk pengguna.
class AkunGagal implements Exception {
  AkunGagal(this.pesan, {this.kode});

  final String pesan;
  final int? kode;

  @override
  String toString() => pesan;
}

/// Bentuk pengiriman: metode, jalur, isi, token → balasan JSON.
typedef Pengirim = Future<Map<String, dynamic>> Function(
  String metode,
  String jalur, {
  Map<String, dynamic>? isi,
  String? token,
});

class KlienAkun {
  KlienAkun({
    this.alamat = alamatServerBawaan,
    this.namaPerangkat = '',
    Pengirim? pengirim,
  }) {
    _pengirim = pengirim ?? _kirimLewatInternet;
  }

  final String alamat;
  final String namaPerangkat;
  late final Pengirim _pengirim;

  Future<AkunSesi> daftar({
    required String email,
    required String nama,
    required String sandi,
  }) async {
    final data = await _pengirim('POST', '/daftar', isi: {
      'email': email.trim(),
      'nama': nama.trim(),
      'sandi': sandi,
      'perangkat': namaPerangkat,
    });
    return _sesi(data);
  }

  Future<AkunSesi> masuk({required String email, required String sandi}) async {
    final data = await _pengirim('POST', '/masuk', isi: {
      'email': email.trim(),
      'sandi': sandi,
      'perangkat': namaPerangkat,
    });
    return _sesi(data);
  }

  Future<void> keluar(String token) =>
      _pengirim('POST', '/keluar', isi: const {}, token: token);

  /// Info akun + jumlah catatan & revisi tertinggi di server.
  Future<Map<String, dynamic>> infoAkun(String token) =>
      _pengirim('GET', '/akun', token: token);

  /// Sinkron dua arah (dipakai tahap berikutnya: isi data).
  Future<Map<String, dynamic>> sinkron({
    required String token,
    int sejak = 0,
    List<Map<String, dynamic>> perubahan = const [],
  }) =>
      _pengirim('POST', '/sinkron',
          isi: {'sejak': sejak, 'perubahan': perubahan}, token: token);

  AkunSesi _sesi(Map<String, dynamic> data) {
    final akun = data['akun'] as Map<String, dynamic>? ?? const {};
    final sesi = AkunSesi.dariJson({
      'token': data['token'],
      'email': akun['email'],
      'nama': akun['nama'],
    });
    if (sesi == null) {
      throw AkunGagal('Jawaban server tidak dikenali.');
    }
    return sesi;
  }

  // --------------------------------------------------------------- pengiriman
  Future<Map<String, dynamic>> _kirimLewatInternet(
    String metode,
    String jalur, {
    Map<String, dynamic>? isi,
    String? token,
  }) async {
    final uri = Uri.parse('$alamat$jalur');
    final klien = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final permintaan = await klien
          .openUrl(metode, uri)
          .timeout(const Duration(seconds: 20));
      permintaan.headers.contentType = ContentType.json;
      permintaan.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null && token.isNotEmpty) {
        permintaan.headers.set(
            HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (isi != null) permintaan.write(jsonEncode(isi));
      final balasan =
          await permintaan.close().timeout(const Duration(seconds: 30));
      final teks = await balasan.transform(utf8.decoder).join();
      Map<String, dynamic> data = const {};
      if (teks.isNotEmpty) {
        final terurai = jsonDecode(teks);
        if (terurai is Map<String, dynamic>) data = terurai;
      }
      if (balasan.statusCode >= 400) {
        throw AkunGagal(
          _pesanRamah(data['detail'], balasan.statusCode),
          kode: balasan.statusCode,
        );
      }
      return data;
    } on SocketException {
      throw AkunGagal('Tidak bisa menghubungi server. Periksa koneksi internet.');
    } on TimeoutException {
      throw AkunGagal('Server tidak menjawab. Coba lagi sebentar.');
    } on FormatException {
      throw AkunGagal('Jawaban server tidak dikenali.');
    } finally {
      klien.close(force: true);
    }
  }

  /// Pesan dari server diteruskan bila ada; kalau tidak, dipetakan ke bahasa Indonesia.
  static String _pesanRamah(Object? detail, int kode) {
    if (detail is String && detail.isNotEmpty) return detail;
    switch (kode) {
      case 400:
        return 'Data yang dikirim belum benar.';
      case 401:
        return 'Email atau sandi salah.';
      case 409:
        return 'Email ini sudah terdaftar. Silakan masuk.';
      case 429:
        return 'Terlalu banyak percobaan. Tunggu beberapa menit.';
      default:
        return 'Terjadi gangguan di server ($kode). Coba lagi.';
    }
  }
}
