/// Kalender Hijriah (FR-90) — konversi dua arah, acuan dapat dipilih,
/// koreksi manual, dan penanda hari besar.
///
/// Pustaka: `hijri_core` 1.1.0 (MIT, tanpa dependensi). Dua mesin bawaan:
/// - `uaq`  : tabel Umm al-Qura (dipakai Arab Saudi)
/// - `fcna` : aritmetik FCNA (Islamic Society of North America)
///
/// JUJUR KE PENGGUNA: penetapan resmi di Indonesia (Kemenag) bisa berbeda
/// 1 hari dari kedua mesin di atas. Karena itu disediakan [koreksiHari]
/// (-2..+2) dan kalimat penjelas di antarmuka. Kami TIDAK mengklaim tanggal
/// resmi; aplikasi hanya menyebut "perhitungan".
library;

import 'package:hijri_core/hijri_core.dart';

/// Nama bulan Hijriah dalam Bahasa Indonesia (12 bulan, urut).
const List<String> namaBulanHijriah = <String>[
  'Muharram',
  'Safar',
  'Rabiul Awal',
  'Rabiul Akhir',
  'Jumadil Awal',
  'Jumadil Akhir',
  'Rajab',
  'Syaban',
  'Ramadhan',
  'Syawal',
  'Dzulqadah',
  'Dzulhijjah',
];

/// Nama hari (0 = Senin ... 6 = Ahad), sesuai `DateTime.weekday`.
const List<String> namaHariSingkat = <String>[
  'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Ahd',
];

/// Acuan perhitungan Hijriah yang dapat dipilih pengguna.
enum AcuanHijriah {
  ummAlQura('Umm al-Qura', 'uaq', 'Tabel resmi Arab Saudi.'),
  fcna('FCNA (aritmetik)', 'fcna', 'Hitungan aritmetik, tanpa tabel.');

  const AcuanHijriah(this.label, this.kode, this.keterangan);

  final String label;
  final String kode;
  final String keterangan;
}

/// Catatan wajib yang ikut ditampilkan di antarmuka (bagian III-11 PRD).
const String catatanPenetapan =
    'Tanggal ini hasil perhitungan, bukan penetapan resmi. '
    'Pemerintah (Kemenag) bisa menetapkan tanggal yang berbeda 1 hari.';

/// Tanggal Hijriah sederhana (tidak bergantung tipe pustaka).
class TanggalHijriah implements Comparable<TanggalHijriah> {
  const TanggalHijriah(this.tahun, this.bulan, this.hari);

  final int tahun;
  final int bulan; // 1..12
  final int hari; // 1..29/30

  String get namaBulan =>
      (bulan >= 1 && bulan <= 12) ? namaBulanHijriah[bulan - 1] : '?';

  String get label => '$hari $namaBulan $tahun H';

  String get labelPendek => '$hari $namaBulan';

  bool get valid => tahun > 0 && bulan >= 1 && bulan <= 12 && hari >= 1 && hari <= 30;

  @override
  int compareTo(TanggalHijriah other) {
    if (tahun != other.tahun) return tahun.compareTo(other.tahun);
    if (bulan != other.bulan) return bulan.compareTo(other.bulan);
    return hari.compareTo(other.hari);
  }

  @override
  bool operator ==(Object other) =>
      other is TanggalHijriah &&
      other.tahun == tahun &&
      other.bulan == bulan &&
      other.hari == hari;

  @override
  int get hashCode => Object.hash(tahun, bulan, hari);

  @override
  String toString() => label;
}

/// Ubah tanggal Masehi -> Hijriah.
///
/// [koreksiHari] positif = tanggal Hijriah lebih maju (lebih cepat) 1 hari;
/// negatif = lebih mundur. Dipakai bila pengguna ingin mengikuti penetapan
/// resmi yang berbeda dari mesin hitung.
TanggalHijriah? hijriahDariMasehi(
  DateTime tanggal, {
  AcuanHijriah acuan = AcuanHijriah.ummAlQura,
  int koreksiHari = 0,
}) {
  final DateTime d = DateTime.utc(tanggal.year, tanggal.month, tanggal.day)
      .add(Duration(days: koreksiHari));
  final HijriDate? h =
      toHijri(d, options: ConversionOptions(calendar: acuan.kode));
  if (h == null) return null;
  return TanggalHijriah(h.hy, h.hm, h.hd);
}

/// Ubah tanggal Hijriah -> Masehi (jam 00:00 UTC sebagai penanda tanggal).
DateTime? masehiDariHijriah(
  TanggalHijriah h, {
  AcuanHijriah acuan = AcuanHijriah.ummAlQura,
  int koreksiHari = 0,
}) {
  final DateTime? g = toGregorian(h.tahun, h.bulan, h.hari,
      options: ConversionOptions(calendar: acuan.kode));
  if (g == null) return null;
  return DateTime.utc(g.year, g.month, g.day).subtract(Duration(days: koreksiHari));
}

/// Jumlah hari pada satu bulan Hijriah (29 atau 30). Null bila di luar jangkauan.
int? jumlahHariBulanHijriah(
  int tahun,
  int bulan, {
  AcuanHijriah acuan = AcuanHijriah.ummAlQura,
}) {
  if (bulan < 1 || bulan > 12) return null;
  try {
    final int n = daysInHijriMonth(tahun, bulan,
        options: ConversionOptions(calendar: acuan.kode));
    return (n == 29 || n == 30) ? n : null;
  } catch (_) {
    return null;
  }
}

/// "Hari besar" yang lazim. Semua tanggal HIJRIAH, jadi peringatannya
/// bergeser mengikuti kalender.
class HariPentingHijriah {
  const HariPentingHijriah(this.bulan, this.hari, this.nama, this.keterangan);

  final int bulan;
  final int hari;
  final String nama;
  final String keterangan;

  bool cocok(TanggalHijriah t) => t.bulan == bulan && t.hari == hari;

  bool padaBulan(int bulanHijriah) => bulan == bulanHijriah;
}

/// Daftar hari besar Islam yang umum diperingati di Indonesia.
const List<HariPentingHijriah> hariPentingHijriah = <HariPentingHijriah>[
  HariPentingHijriah(1, 1, 'Tahun Baru Hijriah',
      'Awal tahun menurut kalender Hijriah.'),
  HariPentingHijriah(1, 9, 'Puasa Asyura',
      'Puasa sunah pada 9 Muharram (lazim dilanjutkan 10 Muharram).'),
  HariPentingHijriah(1, 10, 'Hari Asyura', 'Hari ke-10 Muharram.'),
  HariPentingHijriah(3, 12, 'Maulid Nabi Muhammad SAW',
      'Kelahiran Nabi Muhammad SAW.'),
  HariPentingHijriah(7, 27, 'Isra Mikraj', 'Perjalanan malam Nabi Muhammad SAW.'),
  HariPentingHijriah(8, 15, 'Nisfu Syaban', 'Pertengahan bulan Syaban.'),
  HariPentingHijriah(9, 1, 'Awal Ramadhan', 'Hari pertama puasa Ramadhan.'),
  HariPentingHijriah(9, 17, 'Nuzulul Quran',
      'Turunnya Al-Qur\u2019an menurut keterangan yang lazim.'),
  HariPentingHijriah(9, 27, 'Malam 27 Ramadhan',
      'Salah satu malam ganjil di sepuluh hari terakhir Ramadhan.'),
  HariPentingHijriah(10, 1, 'Idul Fitri', 'Hari raya setelah Ramadhan.'),
  HariPentingHijriah(12, 9, 'Hari Arafah', 'Puasa sunah bagi yang tidak berhaji.'),
  HariPentingHijriah(12, 10, 'Idul Adha', 'Hari raya kurban.'),
];

/// Hari besar yang jatuh di bulan Hijriah tertentu (untuk ditampilkan di daftar).
List<HariPentingHijriah> hariPentingDiBulan(int bulan) =>
    hariPentingHijriah.where((HariPentingHijriah h) => h.bulan == bulan).toList();

/// Satu sel pada tampilan kalender bulanan.
class SelKalenderHijriah {
  const SelKalenderHijriah({
    required this.hijriah,
    required this.masehi,
    required this.hariPenting,
  });

  final TanggalHijriah hijriah;
  final DateTime masehi; // jam 00:00 UTC sebagai penanda tanggal
  final List<HariPentingHijriah> hariPenting;

  bool get adaPeringatan => hariPenting.isNotEmpty;

  /// Indeks kolom 0..6 dengan 0 = Senin.
  int get kolom => (masehi.weekday + 6) % 7;
}

/// Satu bulan kalender Hijriah lengkap dengan pemetaan ke Masehi.
class BulanHijriah {
  const BulanHijriah({
    required this.tahun,
    required this.bulan,
    required this.acuan,
    required this.sel,
  });

  final int tahun;
  final int bulan;
  final AcuanHijriah acuan;
  final List<SelKalenderHijriah> sel;

  String get namaBulan =>
      (bulan >= 1 && bulan <= 12) ? namaBulanHijriah[bulan - 1] : '?';

  String get label => '$namaBulan $tahun H';

  int get jumlahHari => sel.length;

  SelKalenderHijriah? selHari(int hari) {
    for (final SelKalenderHijriah s in sel) {
      if (s.hijriah.hari == hari) return s;
    }
    return null;
  }

  /// Hari besar yang jatuh pada bulan ini, lengkap dengan tanggal Masehi.
  List<({HariPentingHijriah hari, DateTime masehi})> get peringatan =>
      <({HariPentingHijriah hari, DateTime masehi})>[
        for (final HariPentingHijriah h in hariPentingDiBulan(bulan))
          if (selHari(h.hari) != null)
            (hari: h, masehi: selHari(h.hari)!.masehi),
      ];
}

/// Susun kalender satu bulan Hijriah.
///
/// Cara kerja: mulai dari tanggal Masehi perkiraan hari ke-1, lalu periksa
/// 45 hari ke depan dan ambil yang bulan Hijriahnya cocok. Cara ini dipakai
/// supaya sel kalender selalu konsisten dengan fungsi konversi (tidak ada
/// tabel kedua yang bisa berbeda).
BulanHijriah susunBulanHijriah(
  int tahun,
  int bulan, {
  AcuanHijriah acuan = AcuanHijriah.ummAlQura,
  int koreksiHari = 0,
}) {
  if (bulan < 1 || bulan > 12) {
    throw ArgumentError('Bulan Hijriah harus 1..12, bukan $bulan');
  }
  final DateTime? awal =
      masehiDariHijriah(TanggalHijriah(tahun, bulan, 1), acuan: acuan, koreksiHari: koreksiHari);
  if (awal == null) {
    throw ArgumentError('Tahun Hijriah $tahun di luar jangkauan acuan ${acuan.label}');
  }
  final List<SelKalenderHijriah> sel = <SelKalenderHijriah>[];
  for (int i = -3; i < 45; i++) {
    final DateTime m = awal.add(Duration(days: i));
    final TanggalHijriah? h =
        hijriahDariMasehi(m, acuan: acuan, koreksiHari: koreksiHari);
    if (h == null || h.tahun != tahun || h.bulan != bulan) continue;
    sel.add(SelKalenderHijriah(
      hijriah: h,
      masehi: m,
      hariPenting: hariPentingHijriah
          .where((HariPentingHijriah p) => p.cocok(h))
          .toList(),
    ));
  }
  sel.sort((SelKalenderHijriah a, SelKalenderHijriah b) =>
      a.hijriah.hari.compareTo(b.hijriah.hari));
  return BulanHijriah(tahun: tahun, bulan: bulan, acuan: acuan, sel: sel);
}
