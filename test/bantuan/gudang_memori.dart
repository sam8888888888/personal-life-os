/// Brankas dalam memori untuk uji — dipakai bersama oleh berkas uji yang perlu
/// menyuntik gudang rahasia (bukan lewat kanal platform).
///
/// KENAPA WAJIB DISUNTIK, BUKAN LEWAT KANAL
/// Kanal `lifeos/rahasia` (Keystore Android) tidak pernah menjawab di dalam
/// waktu tiruan `pumpAndSettle` pada uji widget: jawabannya dikirim lewat gelung
/// peristiwa nyata, sedangkan uji widget memakai waktu tiruan. Akibatnya layar
/// tampak berputar selamanya lalu uji gagal karena batas waktu — bukan karena
/// aplikasi rusak. Jalur kanal sungguhan (Keystore) hanya bisa dibuktikan di HP.
library;

import 'package:personal_life_os/core/platform/brankas_rahasia.dart';

class GudangMemori implements GudangRahasia {
  final Map<String, String> isi = <String, String>{};

  @override
  Future<bool> didukung() async => true;

  @override
  Future<String?> baca(String nama) async => isi[nama];

  @override
  Future<bool> simpan(String nama, String nilai) async {
    isi[nama] = nilai;
    return true;
  }

  @override
  Future<bool> hapus(String nama) async {
    isi.remove(nama);
    return true;
  }

  @override
  Future<String?> enkripsiSandi(String teks, String sandi) =>
      throw UnimplementedError('enkripsi sandi tidak dipakai di gudang memori');

  @override
  Future<String?> dekripsiSandi(String amplop, String sandi) =>
      throw UnimplementedError('dekripsi sandi tidak dipakai di gudang memori');
}
