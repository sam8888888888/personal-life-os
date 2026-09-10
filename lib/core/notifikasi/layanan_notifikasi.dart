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

abstract class LayananNotifikasi {
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
  Future<List<({int id, String? judul, DateTime? waktu})>> tertunda();
}
