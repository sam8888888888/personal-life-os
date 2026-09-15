/// Saluran bagi modul fitur yang ingin menambah pengingatnya sendiri
/// (FR-63 briefing pagi, FR-87 adzan / pengingat waktu sholat).
///
/// **Kenapa dibuat begini:** berkas `lib/core/notifikasi/**` sengaja dijaga satu
/// pemilik supaya jadwal tagihan (FR-10…FR-16) tidak rusak. Modul fitur (mis.
/// Ibadah) menyimpan datanya sendiri (kota, jadwal sholat, pilihan mode) dan
/// hanya menyerahkan **hasil** berupa daftar [Pengingat] lewat antarmuka ini.
///
/// Kontrak untuk pelaksana:
/// 1. [pengingatTambahan] harus **murni** — hanya membaca data, tidak mengubah
///    apa pun — dan aman dipanggil berulang (dipanggil tiap sinkronisasi).
/// 2. Boleh melempar galat: [PenyinkronPengingat] menangkapnya, mencatatnya di
///    jejak, dan **pengingat tagihan tetap terpasang**. Jangan menelan galat
///    sendiri tanpa jejak.
/// 3. ID notifikasi wajib memakai rentang cadangan di `perencana_pengingat.dart`
///    (`idBriefingPagiKe`, `idSholatKe`) supaya tidak bentrok dengan tagihan.
library;

import 'package:flutter/foundation.dart';

import 'model_pengingat.dart';

/// Sumber pengingat tambahan. Implementasinya milik modul fitur.
abstract class SumberPengingatTambahan {
  /// Pengingat tambahan yang ingin dipasang pada/untuk waktu [sekarang].
  Future<List<Pengingat>> pengingatTambahan(DateTime sekarang);
}

/// Registri sumber yang aktif.
///
/// Modul fitur mendaftar **di isolate utama** (mis. dari `main.dart`) dengan
/// [daftarkan]. Pekerja latar (Workmanager) berjalan di isolate sendiri yang
/// tidak mewarisi apa pun — pendaftaran untuk latar dilakukan di
/// `kerja_latar.dart` (fungsi `daftarkanSumberPengingatLatar`).
class RegistriSumberPengingat {
  RegistriSumberPengingat._();

  static final List<SumberPengingatTambahan> _daftar = [];

  static List<SumberPengingatTambahan> get daftar => List.unmodifiable(_daftar);

  static bool get kosong => _daftar.isEmpty;

  /// Daftarkan satu sumber. Aman dipanggil berulang (jenis sama tidak dobel).
  static void daftarkan(SumberPengingatTambahan sumber) {
    if (_daftar.any((s) => s.runtimeType == sumber.runtimeType)) return;
    _daftar.add(sumber);
  }

  /// Hapus semua sumber (dipakai pengujian & pengaturan ulang).
  @visibleForTesting
  static void kosongkan() => _daftar.clear();

  /// Kumpulkan pengingat dari sumber.
  ///
  /// [sumber] `null` = pakai registri; daftar eksplisit dipakai pengujian atau
  /// pemanggil yang menyalurkan sumbernya sendiri.
  ///
  /// Satu sumber gagal **tidak** menggagalkan yang lain; pesan galatnya
  /// dikembalikan lewat [catatGalat] supaya bisa dicatat di jejak.
  static Future<List<Pengingat>> kumpulkan(
    DateTime sekarang, {
    List<SumberPengingatTambahan>? sumber,
    void Function(String pesan)? catatGalat,
  }) async {
    final hasil = <Pengingat>[];
    for (final s in sumber ?? _daftar) {
      try {
        hasil.addAll(await s.pengingatTambahan(sekarang));
      } catch (e) {
        catatGalat?.call('${s.runtimeType}: $e');
      }
    }
    return hasil;
  }
}
