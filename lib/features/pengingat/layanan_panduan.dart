/// Panduan izin pengingat per merek HP (FR-13).
/// Teks langkah disimpan sebagai data agar mudah diperbarui & diuji.
library;

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class PanduanMerek {
  const PanduanMerek({
    required this.nama,
    required this.langkah,
    this.kunci = const [],
  });

  final String nama;
  final List<String> langkah;

  /// Kata kunci nama model/manufaktur yang cocok (huruf kecil).
  final List<String> kunci;
}

/// Panduan umum bila merek tidak dikenali.
const panduanUmum = PanduanMerek(
  nama: 'Umum (Android)',
  langkah: [
    'Buka Pengaturan HP → Aplikasi → Personal Life OS.',
    'Buka "Notifikasi" lalu izinkan semua kanal pengingat.',
    'Buka "Baterai" lalu pilih "Tidak dibatasi" / "Unrestricted".',
    'Aktifkan "Autostart" bila tersedia di HP Anda.',
  ],
);

/// Panduan khusus merek yang dikenal sering mematikan aplikasi latar.
const List<PanduanMerek> daftarPanduan = [
  PanduanMerek(
    nama: 'Xiaomi / Redmi / POCO (MIUI/HyperOS)',
    kunci: ['xiaomi', 'redmi', 'poco', 'mi'],
    langkah: [
      'Pengaturan → Aplikasi → Kelola aplikasi → Personal Life OS → Autostart: aktifkan.',
      'Pengaturan → Aplikasi → Personal Life OS → Penghemat baterai: "Tanpa batasan".',
      'Buka "Izin lainnya" → "Tampilkan di latar belakang": izinkan.',
      'Di layar terakhir (recent apps): kunci aplikasi (ikon gembok) agar tidak dibersihkan.',
    ],
  ),
  PanduanMerek(
    nama: 'OPPO / Realme (ColorOS)',
    kunci: ['oppo', 'realme'],
    langkah: [
      'Pengaturan → Baterai → Penggunaan latar belakang: pilih "Izinkan".',
      'Pengaturan → Aplikasi → Personal Life OS → Autostart: aktifkan.',
      'Optimasi baterai: matikan untuk Personal Life OS.',
      'Recent apps → kunci aplikasi agar tidak tertutup saat "bersihkan".',
    ],
  ),
  PanduanMerek(
    nama: 'Vivo / iQOO (OriginOS/Funtouch)',
    kunci: ['vivo', 'iqoo'],
    langkah: [
      'Pengaturan → Baterai → Konsumsi latar belakang tinggi: izinkan.',
      'Pengaturan → Aplikasi → Autostart → aktifkan Personal Life OS.',
      'Pengaturan → Aplikasi → Izin → Notifikasi: aktifkan semua kanal.',
    ],
  ),
  PanduanMerek(
    nama: 'Samsung (One UI)',
    kunci: ['samsung'],
    langkah: [
      'Pengaturan → Baterai & perawatan perangkat → Baterai → Batas penggunaan latar belakang → '
          'pilih "Aplikasi yang tidak pernah tidur" → tambahkan Personal Life OS.',
      'Pengaturan → Notifikasi → Pengaturan lanjutan → aktifkan izin notifikasi aplikasi.',
      'Matikan "Tidurkan aplikasi" untuk Personal Life OS.',
    ],
  ),
  PanduanMerek(
    nama: 'Huawei / Honor (EMUI/MagicOS)',
    kunci: ['huawei', 'honor'],
    langkah: [
      'Pengaturan → Baterai → Peluncuran aplikasi → kelola manual: aktifkan Autostart, '
          'jalankan sekunder, dan jalankan di latar belakang.',
      'Pengaturan → Notifikasi → Personal Life OS: izinkan semua.',
      'Pengaturan → Aplikasi → Personal Life OS → Konsumsi daya: pilih '
          '"Kelola secara manual" lalu aktifkan ketiga opsi.',
      'Kunci aplikasi di daftar tugas terakhir (geser ke bawah pada kartu aplikasi) '
          'agar sistem tidak menutupnya.',
    ],
  ),
  PanduanMerek(
    nama: 'Asus / Nokia / Infinix / Tecno / Itel',
    kunci: ['asus', 'nokia', 'infinix', 'tecno', 'itel'],
    langkah: [
      'Pengaturan → Baterai → Penghemat daya otomatis: matikan untuk Personal Life OS.',
      'Pengaturan → Aplikasi → Personal Life OS → Baterai: "Tidak dibatasi".',
      'Aktifkan Autostart bila ada.',
    ],
  ),
];

/// Pilih panduan dari nama manufaktur/model perangkat.
PanduanMerek panduanUntuk(String? manufaktur, String? model) {
  final teks = '${manufaktur ?? ''} ${model ?? ''}'.toLowerCase();
  if (teks.trim().isEmpty) return panduanUmum;
  for (final p in daftarPanduan) {
    for (final k in p.kunci) {
      if (teks.contains(k)) return p;
    }
  }
  return panduanUmum;
}

/// Deteksi merek perangkat (aman dijalankan di semua platform).
Future<({String merek, String model, String android})> infoPerangkat() async {
  if (!Platform.isAndroid) {
    return (merek: Platform.operatingSystem, model: '-', android: '-');
  }
  try {
    final a = await DeviceInfoPlugin().androidInfo;
    return (merek: a.manufacturer, model: a.model, android: 'Android ${a.version.release}');
  } catch (_) {
    return (merek: 'Tidak diketahui', model: '-', android: '-');
  }
}
