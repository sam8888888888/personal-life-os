/// Brankas rahasia perangkat (temuan audit 23 Sep 2026: P0-3 & P1-2).
///
/// Dua hal yang dijaga berkas ini:
///
/// 1. **Rahasia tidak lagi polos di basis data.** Token sesi akun, kunci API
///    Copilot, dan turunan PIN disimpan lewat kanal `lifeos/rahasia` —
///    dienkripsi AES-256-GCM dengan kunci yang dibuat di Android Keystore dan
///    TIDAK BISA DIEKSPOR. Salinan basis data (cadangan, Google Drive, HP yang
///    di-root) menjadi tidak cukup untuk membaca isinya.
/// 2. **Ada jalur mundur yang jujur.** Bila perangkat tidak punya keystore
///    (mis. pengujian di desktop), nilai disimpan seperti sebelumnya di tabel
///    `pengaturan` — dan [PenyimpanRahasia.tersedia] menjawab `false` supaya
///    layar bisa mengatakan apa adanya, bukan mengklaim aman.
library;

import 'package:flutter/services.dart';

import '../../data/repository/pengaturan_repository.dart';

/// Nama kanal — dipakai bersama Dart dan `BrankasRahasia.kt`.
const String kanalBrankasRahasia = 'lifeos/rahasia';

/// Cara mengambil rahasia: kanal Keystore di perangkat (produksi), gudang dalam
/// memori di uji. Dipakai lewat [PenyimpanRahasia] — **disuntik**, bukan global,
/// supaya uji widget tidak menunggu kanal platform (kanal tidak pernah selesai
/// di dalam `pumpAndSettle`; uji berjalan di waktu tiruan).
abstract class GudangRahasia {
  Future<bool> didukung();
  Future<String?> baca(String nama);
  Future<bool> simpan(String nama, String nilai);
  Future<bool> hapus(String nama);
  Future<String?> enkripsiSandi(String teks, String sandi);
  Future<String?> dekripsiSandi(String amplop, String sandi);
}

/// Apakah brankas Keystore tersedia di perangkat ini.
Future<bool> brankasDidukung() async {
  try {
    final hasil = await const MethodChannel(kanalBrankasRahasia)
        .invokeMethod<bool>('didukung');
    return hasil ?? false;
  } catch (_) {
    // Apa pun yang gagal (kanal belum terpasang, binding belum siap, keystore
    // rusak) diperlakukan sebagai "brankas tidak tersedia". Ini PROBE
    // kemampuan, bukan penelanan galat data: pemanggilnya selalu punya jalur
    // mundur yang jujur (nilai disimpan di tabel `pengaturan` seperti dulu),
    // dan `tersedia()` menjawab false supaya layar tidak mengklaim aman.
    return false;
  }
}

/// Simpan nilai rahasia (terenkripsi kunci Keystore). `false` = gagal.
Future<bool> simpanRahasiaPerangkat(String nama, String nilai) async {
  try {
    final hasil = await const MethodChannel(kanalBrankasRahasia)
        .invokeMethod<bool>('simpan', {'nama': nama, 'nilai': nilai});
    return hasil ?? false;
  } catch (_) {
    // Apa pun yang gagal (kanal belum terpasang, binding belum siap, keystore
    // rusak) diperlakukan sebagai "brankas tidak tersedia". Ini PROBE
    // kemampuan, bukan penelanan galat data: pemanggilnya selalu punya jalur
    // mundur yang jujur (nilai disimpan di tabel `pengaturan` seperti dulu),
    // dan `tersedia()` menjawab false supaya layar tidak mengklaim aman.
    return false;
  }
}

/// Baca nilai rahasia. `null` = belum ada / tidak bisa dibuka.
Future<String?> bacaRahasiaPerangkat(String nama) async {
  try {
    return await const MethodChannel(kanalBrankasRahasia)
        .invokeMethod<String>('baca', {'nama': nama});
  } catch (_) {
    // Lihat catatan di [brankasDidukung]: probe kemampuan, bukan penelanan
    // galat data. null = belum ada / tidak bisa dibuka.
    return null;
  }
}

/// Hapus nilai rahasia dari brankas.
Future<bool> hapusRahasiaPerangkat(String nama) async {
  try {
    final hasil = await const MethodChannel(kanalBrankasRahasia)
        .invokeMethod<bool>('hapus', {'nama': nama});
    return hasil ?? false;
  } catch (_) {
    // Apa pun yang gagal (kanal belum terpasang, binding belum siap, keystore
    // rusak) diperlakukan sebagai "brankas tidak tersedia". Ini PROBE
    // kemampuan, bukan penelanan galat data: pemanggilnya selalu punya jalur
    // mundur yang jujur (nilai disimpan di tabel `pengaturan` seperti dulu),
    // dan `tersedia()` menjawab false supaya layar tidak mengklaim aman.
    return false;
  }
}

/// Enkripsi [teks] dengan kunci turunan [sandi] (PBKDF2 600.000 putaran +
/// AES-256-GCM). Hasilnya amplop base64 yang bisa dibawa ke HP lain.
Future<String?> enkripsiDenganSandi({
  required String teks,
  required String sandi,
}) async {
  try {
    return await const MethodChannel(kanalBrankasRahasia).invokeMethod<String>(
      'enkripsiSandi',
      {'teks': teks, 'sandi': sandi},
    );
  } catch (_) {
    // Lihat catatan di [brankasDidukung]: probe kemampuan, bukan penelanan
    // galat data. null = belum ada / tidak bisa dibuka.
    return null;
  }
}

/// Kebalikan [enkripsiDenganSandi]. `null` = sandi salah atau berkas rusak.
Future<String?> dekripsiDenganSandi({
  required String amplop,
  required String sandi,
}) async {
  try {
    return await const MethodChannel(kanalBrankasRahasia).invokeMethod<String>(
      'dekripsiSandi',
      {'amplop': amplop, 'sandi': sandi},
    );
  } catch (_) {
    // Lihat catatan di [brankasDidukung]: probe kemampuan, bukan penelanan
    // galat data. null = belum ada / tidak bisa dibuka.
    return null;
  }
}

/// Penyimpan nilai rahasia: brankas Keystore bila ada, kalau tidak → tabel
/// `pengaturan` seperti sebelumnya (tanpa mengubah perilaku uji/lama).
///
/// [gudang] hanya diisi oleh uji (gudang dalam memori). Di produksi dibiarkan
/// kosong → [GudangKanal] (Keystore Android).
class PenyimpanRahasia {
  PenyimpanRahasia(this.pengaturan, {GudangRahasia? gudang})
      : _gudang = gudang ?? const GudangKanal();

  final PengaturanRepository pengaturan;
  final GudangRahasia _gudang;
  bool? _tersedia;

  /// Apakah nilai benar-benar tersimpan TERENKRIPSI di perangkat ini.
  Future<bool> tersedia() async => _tersedia ??= await _gudang.didukung();

  Future<String?> baca(String nama) async {
    if (await tersedia()) {
      final nilai = await _gudang.baca(nama);
      if (nilai != null) return nilai;
    }
    return pengaturan.baca(nama);
  }

  Future<void> simpan(String nama, String nilai) async {
    if (await tersedia()) {
      final ok = await _gudang.simpan(nama, nilai);
      if (ok) {
        // Nilai polos di basis data TIDAK boleh tertinggal.
        await pengaturan.hapusPengaturan(nama);
        return;
      }
    }
    await pengaturan.simpan(nama, nilai);
  }

  Future<void> hapus(String nama) async {
    if (await tersedia()) await _gudang.hapus(nama);
    await pengaturan.hapusPengaturan(nama);
  }

  /// Pindahkan nilai yang sudah ada di basis data ke brankas Keystore.
  ///
  /// Dipakai untuk data lama (mis. turunan PIN yang sudah terlanjur tersimpan
  /// polos): setelah nilai berhasil masuk brankas, salinan polosnya dihapus.
  /// Mengembalikan true bila nilai sekarang berada di brankas.
  Future<bool> pindahkanKeBrankas(String nama) async {
    if (!await tersedia()) return false;
    final polos = await pengaturan.baca(nama);
    if (polos == null || polos.isEmpty) return false;
    final ok = await _gudang.simpan(nama, polos);
    if (!ok) return false;
    await pengaturan.hapusPengaturan(nama);
    return true;
  }
}

/// Gudang produksi — meneruskan ke kanal `lifeos/rahasia` (Keystore Android).
class GudangKanal implements GudangRahasia {
  const GudangKanal();

  @override
  Future<bool> didukung() => brankasDidukung();

  @override
  Future<String?> baca(String nama) => bacaRahasiaPerangkat(nama);

  @override
  Future<bool> simpan(String nama, String nilai) =>
      simpanRahasiaPerangkat(nama, nilai);

  @override
  Future<bool> hapus(String nama) => hapusRahasiaPerangkat(nama);

  @override
  Future<String?> enkripsiSandi(String teks, String sandi) =>
      enkripsiDenganSandi(teks: teks, sandi: sandi);

  @override
  Future<String?> dekripsiSandi(String amplop, String sandi) =>
      dekripsiDenganSandi(amplop: amplop, sandi: sandi);
}
