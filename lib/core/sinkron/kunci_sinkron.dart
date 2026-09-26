/// S-13 — pengelola kunci data sinkron (bungkus, simpan lokal, ambil dari server).
///
/// Kunci data disimpan TERENKRIPSI kunci Android Keystore lewat
/// [PenyimpanRahasia] (brankas `lifeos/rahasia`) — jadi salinan basis data HP
/// saja tidak cukup untuk membacanya. Yang beredar di server hanya **amplop**
/// kunci (dibungkus sandi akun), sehingga server tetap tidak bisa membaca isi
/// data pengguna.
///
/// Alur satu kali penyiapan (dipanggil sesudah masuk/daftar berhasil, saat
/// sandi masih ada di tangan):
///   1. Kunci sudah pernah dibuka di HP ini → pakai (tanpa jaringan).
///   2. Belum → tarik catatan penanda dari server. Ada amplop → buka dengan
///      sandi akun.
///   3. Amplop belum ada (perangkat pertama) → buat kunci baru, bungkus, kirim.
///
/// Sandi tidak cocok dengan amplop di server → **dilaporkan apa adanya**, tidak
/// dibuatkan kunci baru (membuat kunci baru berarti data lama tidak terbaca).
library;

import 'dart:convert';

import '../akun/klien_akun.dart';
import '../platform/brankas_rahasia.dart';
import 'enkripsi_sinkron.dart';

class KunciSinkron {
  KunciSinkron(this.rahasia);

  /// Brankas rahasia perangkat (Keystore Android; tabel `pengaturan` hanya bila
  /// perangkat tidak punya keystore — lihat [PenyimpanRahasia]).
  final PenyimpanRahasia rahasia;

  /// Nama rahasia per akun — dua akun di satu HP tidak pernah bertukar kunci.
  static String namaRahasia(String email) =>
      'sinkron.kunci.${email.trim().toLowerCase()}';

  /// Kunci yang sudah tersimpan di HP ini (null = belum ada).
  Future<List<int>?> kunciTersimpan(String email) async {
    final teks = await rahasia.baca(namaRahasia(email));
    if (teks == null || teks.isEmpty) return null;
    try {
      final kunci = base64Decode(teks);
      return kunci.length == 32 ? kunci : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> simpanKunci(String email, List<int> kunci) =>
      rahasia.simpan(namaRahasia(email), base64Encode(kunci));

  Future<void> lupakanKunci(String email) =>
      rahasia.hapus(namaRahasia(email));

  /// Pastikan ada kunci data untuk akun ini lalu simpan di brankas HP.
  ///
  /// [sandi] hanya dipakai di memori proses ini (tidak disimpan di mana pun).
  Future<List<int>> siapkan({
    required KlienAkun klien,
    required String token,
    required String email,
    required String sandi,
  }) async {
    final tersimpan = await kunciTersimpan(email);
    if (tersimpan != null) return tersimpan;

    final jawab =
        await klien.sinkron(token: token, sejak: 0, perubahan: const []);
    final amplop = amplopDariJawaban(jawab);
    if (amplop != null) {
      final kunci = bukaBungkusKunci(amplop, sandi);
      if (kunci == null) {
        throw AkunGagal(
            'Kunci data di server dibuat dengan sandi lain. Masuk memakai sandi '
            'yang benar untuk membuka data Anda.');
      }
      await simpanKunci(email, kunci);
      return kunci;
    }

    // Perangkat pertama untuk akun ini: buat kunci baru & kirim amplopnya.
    final kunciBaru = kunciDataBaru();
    await kirimAmplop(
      klien: klien,
      token: token,
      kunci: kunciBaru,
      sandi: sandi,
    );
    await simpanKunci(email, kunciBaru);
    return kunciBaru;
  }

  /// Kirim amplop kunci (dibungkus [sandi]) sebagai satu catatan sinkron.
  Future<void> kirimAmplop({
    required KlienAkun klien,
    required String token,
    required List<int> kunci,
    required String sandi,
  }) =>
      klien.sinkron(
        token: token,
        sejak: 0,
        perubahan: <Map<String, dynamic>>[
          <String, dynamic>{
            'tabel': tabelAmplopKunci,
            'id_lokal': idAmplopKunci,
            'waktu_klien': DateTime.now().toUtc().toIso8601String(),
            'dihapus': false,
            'isi': <String, dynamic>{'bungkus': bungkusKunci(kunci, sandi)},
          },
        ],
      );

  /// Amplop kunci dari jawaban `/sinkron` (null bila belum ada).
  static String? amplopDariJawaban(Map<String, dynamic> jawab) {
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
}
