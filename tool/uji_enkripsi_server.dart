// Alat CLI uji nyata — keluaran memang lewat print (bukan kode produksi).
// ignore_for_file: avoid_print

/// Uji nyata S-13 — buktikan data yang tersimpan di SERVER sudah tersandi.
///
/// Dijalankan dari mesin uji (Austria) ke server akun sungguhan:
///   dart run tool/uji_enkripsi_server.dart http://127.0.0.1:3500
///
/// Yang dibuktikan (memakai kode aplikasi yang sama, bukan tiruan):
///   1. Daftar akun uji → dapat token.
///   2. Kunci data dibuat & dibungkus sandi akun, amplopnya dikirim.
///   3. Satu catatan ("tagihan") berisi nama & nominal DIKIRIM TERSANDI.
///   4. Jawaban server saat ditarik **tidak memuat teks polos** (uji mencari
///      nama tagihan di seluruh jawaban: harus TIDAK ketemu).
///   5. Amplop dibuka sandi akun → kunci sama; isi catatan dibuka → sama persis.
///   6. Sandi salah → tidak bisa membuka apa pun (bukan data palsu).
library;

import 'dart:convert';
import 'dart:io';

import 'package:personal_life_os/core/akun/klien_akun.dart';
import 'package:personal_life_os/core/sinkron/enkripsi_sinkron.dart';

/// Amplop kunci dari jawaban `/sinkron` — sengaja ditulis di sini (tidak
/// memanggil `kunci_sinkron.dart`) supaya alat ini tetap bebas-Flutter dan bisa
/// dijalankan dengan `dart run`.
String? amplopDariJawaban(Map<String, dynamic> jawab) {
  final daftar = jawab['perubahan'];
  if (daftar is! List) return null;
  for (final butir in daftar) {
    if (butir is! Map) continue;
    if ('${butir['tabel']}' != tabelAmplopKunci) continue;
    if ('${butir['id_lokal']}' != idAmplopKunci) continue;
    final isi = butir['isi'];
    if (isi is! Map) continue;
    final bungkus = isi['bungkus'];
    if (bungkus is String && bungkus.isNotEmpty) return bungkus;
  }
  return null;
}

/// Buang akun uji dari server (endpoint `DELETE /akun`) supaya tidak menumpuk.
Future<void> _hapusAkun(String alamat, String token) async {
  final klien = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final permintaan = await klien.deleteUrl(Uri.parse('$alamat/akun'));
    permintaan.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    await permintaan.close();
  } catch (_) {
    print('  (catatan: akun uji tidak bisa dibuang, hapus manual bila perlu)');
  } finally {
    klien.close(force: true);
  }
}

Future<void> main(List<String> argumen) async {
  final alamat = argumen.isNotEmpty ? argumen.first : 'http://127.0.0.1:3500';
  final cap = argumen.length > 1 ? argumen[1] : DateTime.now().microsecondsSinceEpoch.toString();
  final email = 'uji-enkripsi-$cap@contoh.id';
  const sandi = 'sandi-uji-enkripsi-1';
  const sandiSalah = 'sandi-uji-yang-salah-9';

  var lulus = 0;
  var gagal = 0;
  void periksa(String judul, bool syarat, [String? catatan]) {
    if (syarat) {
      lulus++;
      print('  OK   $judul');
    } else {
      gagal++;
      print('  GAGAL $judul${catatan == null ? '' : ' — $catatan'}');
    }
  }

  final klien = KlienAkun(alamat: alamat, namaPerangkat: 'uji-enkripsi');
  print('Server: $alamat');
  print('Akun uji: $email\n');

  print('1. Daftar akun uji & kirim amplop kunci');
  final sesi = await klien.daftar(email: email, nama: 'Uji Enkripsi', sandi: sandi);
  periksa('daftar akun berhasil', sesi.token.isNotEmpty);

  final kunci = kunciDataBaru();
  final bungkus = bungkusKunci(kunci, sandi);

  const namaTagihan = 'Listrik Uji Enkripsi';
  const nominalSen = 25000000;
  final isiPolos = <String, Object?>{
    'nama': namaTagihan,
    'nominal_sen': nominalSen,
    'jatuh_tempo': '2026-09-30',
  };

  final jawabKirim = await klien.sinkron(
    token: sesi.token,
    sejak: 0,
    perubahan: <Map<String, dynamic>>[
      <String, dynamic>{
        'tabel': tabelAmplopKunci,
        'id_lokal': idAmplopKunci,
        'waktu_klien': DateTime.now().toUtc().toIso8601String(),
        'dihapus': false,
        'isi': <String, dynamic>{'bungkus': bungkus},
      },
      <String, dynamic>{
        'tabel': 'tagihan',
        'id_lokal': 'uji-enkripsi-1',
        'waktu_klien': DateTime.now().toUtc().toIso8601String(),
        'dihapus': false,
        'isi': sandikanPeta(kunci, isiPolos),
      },
    ],
  );
  periksa('server menerima 2 catatan', (jawabKirim['diterima'] as num?) == 2,
      'diterima=${jawabKirim['diterima']}');

  print('\n2. Tarik dari server & periksa apa yang benar-benar tersimpan');
  final tarikan = await klien.sinkron(token: sesi.token, sejak: 0, perubahan: const []);
  final teksJawaban = jsonEncode(tarikan);
  periksa('jawaban TIDAK memuat nama tagihan polos',
      !teksJawaban.contains(namaTagihan),
      'teks polos ditemukan di jawaban server');
  periksa('jawaban TIDAK memuat nominal polos',
      !teksJawaban.contains('$nominalSen'));

  final daftar = (tarikan['perubahan'] as List?) ?? const [];
  Map<String, dynamic>? rekaman;
  for (final b in daftar) {
    if (b is Map && '${b['tabel']}' == 'tagihan') {
      rekaman = b.cast<String, dynamic>();
    }
  }
  periksa('catatan tagihan ada di server', rekaman != null);
  final isiTersimpan = (rekaman?['isi'] as Map?)?.cast<String, Object?>() ?? const {};
  periksa('isi tersimpan berbentuk penanda tersandi',
      isiTersimpan.keys.length == 1 && isiTersimpan.containsKey(kunciIsiTersandi),
      'kunci isi: ${isiTersimpan.keys.toList()}');
  print('     bentuk isi di server: ${jsonEncode(isiTersimpan).substring(0, 60)}…');

  print('\n3. Buka dengan sandi akun (seperti HP kedua)');
  final amplop = amplopDariJawaban(tarikan);
  periksa('amplop kunci ketemu di tarikan server', amplop != null);
  final kunciDibuka = amplop == null ? null : bukaBungkusKunci(amplop, sandi);
  periksa('amplop terbuka dengan sandi akun', kunciDibuka != null);
  periksa('kunci hasil buka SAMA dengan kunci asal',
      kunciDibuka != null && '$kunciDibuka' == '$kunci');
  final kembali = kunciDibuka == null
      ? null
      : bukaPetaTersandi(kunciDibuka, isiTersimpan);
  periksa('isi catatan kembali utuh', kembali != null && kembali['nama'] == namaTagihan);
  periksa('nominal kembali utuh', kembali != null && kembali['nominal_sen'] == nominalSen);

  print('\n4. Sandi salah tidak membuka apa pun');
  periksa('amplop dengan sandi salah → null',
      amplop != null && bukaBungkusKunci(amplop, sandiSalah) == null);

  print('\n5. Bersihkan akun uji');
  await klien.sinkron(
    token: sesi.token,
    sejak: 0,
    perubahan: <Map<String, dynamic>>[
      <String, dynamic>{
        'tabel': 'tagihan',
        'id_lokal': 'uji-enkripsi-1',
        'waktu_klien': DateTime.now().toUtc().toIso8601String(),
        'dihapus': true,
        'isi': const <String, dynamic>{},
      },
    ],
  );
  await klien.keluar(sesi.token);
  await _hapusAkun(alamat, sesi.token);
  print('  data uji dihapus & akun uji dibuang dari server');

  print('\nHASIL: $lulus lulus, $gagal gagal');
  if (gagal > 0) exitCode = 1;
}
