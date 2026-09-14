/// Antarmuka layanan notifikasi — dipisah dari plugin agar dapat diuji
/// tanpa perangkat (uji unit memakai implementasi palsu).
library;

import 'model_pengingat.dart';

/// Ringkasan status izin yang dibutuhkan pengingat (FR-13).
class StatusIzinPengingat {
  const StatusIzinPengingat({
    required this.notifikasiDiizinkan,
    required this.alarmTepatDiizinkan,
    this.catatan = const [],
  });

  final bool notifikasiDiizinkan;
  final bool alarmTepatDiizinkan;
  final List<String> catatan;

  bool get siap => notifikasiDiizinkan;
}

/// Hasil satu kali sinkronisasi jadwal (PB-09) — dipakai untuk memberi tahu
/// pengguna secara jujur apakah seluruh jadwal benar-benar terpasang.
class HasilPasang {
  const HasilPasang({
    required this.direncanakan,
    required this.terpasang,
    required this.idGagal,
    required this.waktu,
  });

  final int direncanakan;
  final int terpasang;
  final List<int> idGagal;
  final DateTime waktu;

  bool get lengkap => idGagal.isEmpty;

  String get ringkas => lengkap
      ? '$terpasang dari $direncanakan jadwal terpasang'
      : '${idGagal.length} dari $direncanakan jadwal GAGAL terpasang';
}

abstract class LayananNotifikasi {
  /// Hasil sinkronisasi terakhir (null = belum pernah).
  HasilPasang? get hasilPasangTerakhir => null;

  /// Apakah penjadwal benar-benar siap dipakai (PB-10: jujur walau init gagal).
  bool get siap => false;

  /// Siapkan plugin, kanal, dan zona waktu. Aman dipanggil berulang.
  Future<void> siapkan();

  /// Baca status izin saat ini (tanpa memunculkan dialog).
  Future<StatusIzinPengingat> statusIzin();

  /// Minta izin notifikasi (Android 13+). Mengembalikan true bila diizinkan.
  Future<bool> mintaIzinNotifikasi();

  /// Minta izin alarm tepat (Android 12+). Mengembalikan true bila diizinkan.
  Future<bool> mintaIzinAlarmTepat();

  /// Ganti seluruh jadwal: batalkan semua lalu pasang [daftar].
  Future<void> pasangJadwal(List<Pengingat> daftar);

  /// Batalkan semua pengingat aplikasi (tidak menyentuh notifikasi lain).
  Future<void> batalkanSemua();

  /// Jadwalkan satu pengingat (dipakai untuk "Tunda 1 jam").
  Future<void> jadwalkanSatu(Pengingat p);

  /// Tampilkan notifikasi uji setelah [tunda] (untuk verifikasi pengguna).
  Future<void> tampilkanUji({Duration tunda = const Duration(seconds: 10)});

  /// Daftar pengingat yang benar-benar tertunda di sistem (bukti nyata).
  ///
  /// PB-12: [waktu] BOLEH null — Android tidak selalu memberi waktu eksekusi
  /// pasti untuk jadwal tertunda. Pemanggil tidak boleh menampilkan waktu yang
  /// tidak benar-benar diketahui.
  Future<List<({int id, String? judul, DateTime? waktu})>> tertunda();
}
