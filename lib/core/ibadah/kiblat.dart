/// FR-98 — Arah Kiblat (mesin hitung, tanpa sensor & tanpa jaringan).
///
/// Kriteria terima PRD: "Kompas menampilkan peringatan kalibrasi; saat sensor/
/// izin tidak ada, aplikasi menampilkan arah alternatif, BUKAN angka palsu."
///
/// Karena itu mesin ini selalu bisa memberi jawaban tanpa sensor: arah kiblat
/// dihitung dari koordinat (lintang/bujur) + arah mata angin. Sudut kompas
/// hanya ditambahkan bila perangkat BENAR-BENAR melaporkan arah hadap.
library;

import 'dart:math' as math;

/// Koordinat Ka'bah (Makkah) — sumber: nilai geodesi umum yang dipakai
/// perhitungan qibla; sama dengan yang dipakai mesin jadwal sholat.
const double kaLintang = 21.4224779;
const double kaBujur = 39.8251832;

/// Arah kiblat dari sebuah titik, dalam derajat dari Utara searah jarum jam
/// (0° = Utara, 90° = Timur). Rumus great-circle bearing.
double arahKiblatDerajat(double lintang, double bujur) {
  final phi1 = _rad(lintang);
  final phi2 = _rad(kaLintang);
  final dLambda = _rad(kaBujur - bujur);
  final y = math.sin(dLambda);
  final x = math.cos(phi1) * math.tan(phi2) - math.sin(phi1) * math.cos(dLambda);
  final sudut = math.atan2(y, x) * 180 / math.pi;
  return (sudut + 360) % 360;
}

double _rad(double derajat) => derajat * math.pi / 180;

/// Nama arah mata angin (8 penjuru) untuk sudut 0–360.
String arahMataAngin(double derajat) {
  const nama = <String>[
    'Utara',
    'Timur Laut',
    'Timur',
    'Tenggara',
    'Selatan',
    'Barat Daya',
    'Barat',
    'Barat Laut',
  ];
  final d = (derajat % 360 + 360) % 360;
  final idx = ((d + 22.5) ~/ 45) % 8;
  return nama[idx];
}

/// Singkatan 8 penjuru (untuk tampilan sempit).
String singkatanMataAngin(double derajat) {
  const nama = <String>['U', 'TL', 'T', 'TG', 'S', 'BD', 'B', 'BL'];
  final d = (derajat % 360 + 360) % 360;
  return nama[((d + 22.5) ~/ 45) % 8];
}

/// Ambang akurasi sensor (derajat). Di atas ini kompas dianggap perlu
/// dikalibrasi — angka tetap ditampilkan dengan peringatan, bukan disembunyikan.
const double ambangAkurasiKompas = 15.0;

/// Hasil lengkap untuk layar kiblat.
class HasilKiblat {
  const HasilKiblat({
    required this.lintang,
    required this.bujur,
    required this.derajatKiblat,
    this.headingDerajat,
    this.akurasiDerajat,
    this.sensorAda = false,
  });

  final double lintang;
  final double bujur;

  /// Arah kiblat dari Utara (derajat).
  final double derajatKiblat;

  /// Arah hadap perangkat; null = sensor tidak melaporkan apa pun.
  final double? headingDerajat;
  final double? akurasiDerajat;
  final bool sensorAda;

  /// Kompas benar-benar bisa dipakai?
  bool get kompasSiap => sensorAda && headingDerajat != null;

  /// Sudut putaran untuk piringan kompas (heading - kiblat) bila kompas siap.
  double? get putaranPiringan {
    if (!kompasSiap) return null;
    return (derajatKiblat - headingDerajat!) % 360;
  }

  bool get perluKalibrasi =>
      kompasSiap && akurasiDerajat != null && akurasiDerajat! > ambangAkurasiKompas;

  String get arahKiblatTeks => arahMataAngin(derajatKiblat);

  /// Derajat dibulatkan ke bilangan bulat untuk tampilan.
  int get derajatKiblatBulat => derajatKiblat.round() % 360;

  String get pesan {
    if (!kompasSiap) {
      return 'Sensor kompas tidak tersedia (atau izin sensor dimatikan). '
          'Pakai arah mata angin: kiblat $derajatKiblatBulat° '
          '($arahKiblatTeks). Tidak ada angka palsu yang ditampilkan.';
    }
    if (perluKalibrasi) {
      return 'Akurasi kompas rendah (${akurasiDerajat!.round()}°). Kalibrasi: '
          'gerakkan HP membentuk angka 8 beberapa kali, lalu diamkan.';
    }
    return 'Pegang HP mendatar, jauhkan dari logam/magnet. Putar sampai '
        'penanda sejajar dengan arah $derajatKiblatBulat° ($arahKiblatTeks).';
  }

  /// Dasar data (koordinat & sumbernya) — aturan "tidak ada angka misterius".
  String get dasar {
    final ls = lintang.toStringAsFixed(4);
    final bs = bujur.toStringAsFixed(4);
    final dasar = 'Dihitung dari koordinat $ls°, $bs° ke Ka\'bah '
        '(${kaLintang.toStringAsFixed(4)}°, ${kaBujur.toStringAsFixed(4)}°)';
    if (kompasSiap) {
      return '$dasar + arah hadap perangkat '
          '${headingDerajat!.round()}°${akurasiDerajat == null ? '' : ' (akurasi ±${akurasiDerajat!.round()}°)'}.';
    }
    return '$dasar. Arah hadap perangkat tidak tersedia.';
  }

  /// Ringkas untuk lencana/notifikasi.
  String get ringkas => 'Kiblat $derajatKiblatBulat° ($arahKiblatTeks)';
}

/// Susun hasil kiblat. [headingDerajat] null atau di luar 0–360 dianggap
/// "sensor tidak melaporkan" (tidak dipakai diam-diam).
HasilKiblat hitungKiblat({
  required double lintang,
  required double bujur,
  double? headingDerajat,
  double? akurasiDerajat,
  bool sensorAda = false,
}) {
  final headingSah = (headingDerajat != null &&
          headingDerajat >= 0 &&
          headingDerajat <= 360)
      ? headingDerajat
      : null;
  return HasilKiblat(
    lintang: lintang,
    bujur: bujur,
    derajatKiblat: arahKiblatDerajat(lintang, bujur),
    headingDerajat: headingSah,
    akurasiDerajat: akurasiDerajat,
    sensorAda: sensorAda && headingSah != null,
  );
}

/// Jarak dua koordinat dalam kilometer (haversine) — dipakai daftar masjid.
double jarakKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0088;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Arah menuju sebuah titik dari titik lain (derajat dari Utara).
double arahKe(double dariLat, double dariLon, double keLat, double keLon) {
  final phi1 = _rad(dariLat);
  final phi2 = _rad(keLat);
  final dLambda = _rad(keLon - dariLon);
  final y = math.sin(dLambda) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
  final sudut = math.atan2(y, x) * 180 / math.pi;
  return (sudut + 360) % 360;
}
