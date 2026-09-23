/// Logika Ramadan Mode (FR-91) — hitung hari menuju 1 Ramadan & 1 Syawal serta
/// waktu imsak/sahur dan maghrib (iftar).
///
/// **Sumber angka (tidak ada yang dikarang):**
/// * Tanggal Hijriah memakai `hijri_core` lewat [kalender_hijriah.dart]
///   (dua acuan: Umm al-Qura & FCNA) + koreksi hari milik pengguna.
/// * Waktu imsak/sahur & maghrib dihitung mesin [penghitung_sholat.dart]
///   (pustaka `adhan_dart`), memakai kota, metode, madzhab Ashar, dan koreksi
///   ihtiyati dari [PengaturanIbadah] — jadi sama dengan layar Jadwal Sholat.
/// * Imsak = Subuh − [imsakMenit] menit (bawaan 10 menit, bisa diubah).
///
/// **Jujur ke pengguna:** semua ini PERHITUNGAN, bukan jadwal resmi, dan awal
/// bulan Hijriah bisa berbeda dari penetapan pemerintah. Dua kalimat itu
/// ditampilkan di layar ([labelPerhitungan], [labelHijriahBisaBeda]).
library;

import '../../core/ibadah/kalender_hijriah.dart';
import '../../core/utils/tanggal_utils.dart' as tanggal;
import '../../core/ibadah/model_sholat.dart';
import '../../core/ibadah/penghitung_sholat.dart';

/// Label kejujuran wajib pada layar Ramadan (PRD bagian III-11 & pasal data).
const String labelPerhitungan = 'Perhitungan, bukan jadwal resmi';

/// Label kejujuran wajib untuk tanggal Hijriah.
const String labelHijriahBisaBeda =
    'Awal bulan Hijriah bisa berbeda dari penetapan pemerintah';

/// Selisih bawaan imsak dari waktu Subuh (menit).
const int imsakMenitBawaan = 10;

/// Batas imsak yang ditawarkan antarmuka (menit sebelum Subuh).
const int imsakMenitMinimal = 0;
const int imsakMenitMaksimal = 30;

/// Nomor bulan Hijriah Ramadan & Syawal (1..12).
const int bulanHijriahRamadan = 9;
const int bulanHijriahSyawal = 10;

/// Hasil hitung Ramadan untuk satu hari.
class RencanaRamadan {
  const RencanaRamadan({
    required this.hijriahHariIni,
    required this.tahunHijriahRamadan,
    required this.tanggalAwalRamadan,
    required this.tanggalIdulFitri,
    required this.hariMenujuRamadan,
    required this.hariMenujuSyawal,
    required this.sedangRamadan,
    required this.hariKeRamadan,
    required this.jumlahHariRamadan,
  });

  /// Tanggal Hijriah hari ini (null bila di luar jangkauan pustaka).
  final TanggalHijriah? hijriahHariIni;

  /// Tahun Hijriah Ramadan yang sedang dihitung.
  final int tahunHijriahRamadan;

  /// Tanggal Masehi 1 Ramadan (tanggal sipil, jam 00:00 lokal).
  final DateTime? tanggalAwalRamadan;

  /// Tanggal Masehi 1 Syawal (Idul Fitri menurut perhitungan).
  final DateTime? tanggalIdulFitri;

  /// Sisa hari menuju 1 Ramadan (0 = hari ini 1 Ramadan).
  final int? hariMenujuRamadan;

  /// Sisa hari menuju 1 Syawal (0 = hari ini 1 Syawal menurut perhitungan).
  final int? hariMenujuSyawal;

  /// Apakah hari ini berada di bulan Ramadan menurut perhitungan.
  final bool sedangRamadan;

  /// Hari ke berapa di bulan Ramadan (1..30); null bila tidak sedang Ramadan.
  final int? hariKeRamadan;

  /// Jumlah hari bulan Ramadan menurut perhitungan (29 atau 30).
  final int? jumlahHariRamadan;

  /// Sisa hari puasa termasuk hari ini; null bila tidak sedang Ramadan.
  int? get sisaHariPuasa {
    final int? ke = hariKeRamadan;
    final int? total = jumlahHariRamadan;
    if (ke == null || total == null) return null;
    final int sisa = total - ke + 1;
    return sisa < 0 ? 0 : sisa;
  }

  /// Benar bila hari ini 1 Syawal (Idul Fitri) menurut perhitungan.
  bool get hariIdulFitri => hariMenujuSyawal == 0;

  /// Apakah tanggal-tanggal penting berhasil dihitung.
  bool get lengkap =>
      tanggalAwalRamadan != null && tanggalIdulFitri != null;
}

/// Nama acuan Hijriah yang dipakai (untuk ditampilkan apa adanya).
String labelAcuan(AcuanHijriah acuan) => acuan.label;

/// Berapa hari lagi menuju tanggal sipil [target] dari [hariIni] (0 = hari ini).
int selisihHari(DateTime hariIni, DateTime target) =>
    tanggal.selisihHari(hariIni, target);

/// Cari kemunculan berikutnya (termasuk hari ini) tanggal Hijriah
/// [bulan]/[hari] menurut [acuan] & [koreksiHari].
///
/// Cara ini dipakai agar "hari menuju" selalu benar walau pengguna baru
/// membuka aplikasi setelah Ramadan lewat.
({int tahun, DateTime tanggal})? _berikutnyaHijriah(
  DateTime hariIni,
  int bulan,
  int hari, {
  required AcuanHijriah acuan,
  required int koreksiHari,
}) {
  final TanggalHijriah? h = hijriahDariMasehi(hariIni,
      acuan: acuan, koreksiHari: koreksiHari);
  if (h == null) return null;
  final DateTime hariIniSipil = DateTime(hariIni.year, hariIni.month, hariIni.day);
  for (int tahun = h.tahun; tahun <= h.tahun + 3; tahun++) {
    final DateTime? g = masehiDariHijriah(TanggalHijriah(tahun, bulan, hari),
        acuan: acuan, koreksiHari: koreksiHari);
    if (g == null) continue;
    final DateTime sipil = DateTime(g.year, g.month, g.day);
    if (!sipil.isBefore(hariIniSipil)) {
      return (tahun: tahun, tanggal: sipil);
    }
  }
  return null;
}

/// Hitung rencana Ramadan untuk [hariIni].
///
/// [hariIni] dipakai hanya YEAR/MONTH/DAY-nya (tanggal sipil).
RencanaRamadan hitungRamadan(
  DateTime hariIni, {
  AcuanHijriah acuan = AcuanHijriah.ummAlQura,
  int koreksiHari = 0,
}) {
  final TanggalHijriah? h =
      hijriahDariMasehi(hariIni, acuan: acuan, koreksiHari: koreksiHari);
  final ({int tahun, DateTime tanggal})? ramadan = _berikutnyaHijriah(
      hariIni, bulanHijriahRamadan, 1,
      acuan: acuan, koreksiHari: koreksiHari);
  final ({int tahun, DateTime tanggal})? syawal = _berikutnyaHijriah(
      hariIni, bulanHijriahSyawal, 1,
      acuan: acuan, koreksiHari: koreksiHari);

  final bool sedangRamadan =
      h != null && h.bulan == bulanHijriahRamadan;
  final int? jumlahHari = h == null
      ? null
      : jumlahHariBulanHijriah(h.tahun, bulanHijriahRamadan, acuan: acuan);

  return RencanaRamadan(
    hijriahHariIni: h,
    tahunHijriahRamadan: ramadan?.tahun ?? h?.tahun ?? 0,
    tanggalAwalRamadan: ramadan?.tanggal,
    tanggalIdulFitri: syawal?.tanggal,
    hariMenujuRamadan: ramadan == null
        ? null
        : selisihHari(hariIni, ramadan.tanggal),
    hariMenujuSyawal:
        syawal == null ? null : selisihHari(hariIni, syawal.tanggal),
    sedangRamadan: sedangRamadan,
    hariKeRamadan: sedangRamadan ? h.hari : null,
    jumlahHariRamadan:
        sedangRamadan ? (jumlahHari ?? 30) : null,
  );
}

/// Waktu sahur & iftar satu hari (jam dinding kota, ditulis `HH:mm`).
class WaktuSahurIftar {
  const WaktuSahurIftar({
    required this.imsak,
    required this.subuh,
    required this.maghrib,
    required this.namaKota,
    required this.labelZona,
    required this.namaMetode,
    required this.imsakMenit,
  });

  /// Jam dinding kota (angka jam/menit = waktu setempat kota).
  final DateTime imsak;
  final DateTime subuh;
  final DateTime maghrib;

  final String namaKota;
  final String labelZona;
  final String namaMetode;

  /// Selisih imsak dari Subuh (menit) yang dipakai.
  final int imsakMenit;
}

/// Imsak = Subuh − [imsakMenit] menit.
DateTime hitungImsak(DateTime subuhLokal, int imsakMenit) =>
    subuhLokal.subtract(Duration(minutes: imsakMenit < 0 ? 0 : imsakMenit));

/// Ambil waktu sahur/imsak & maghrib dari hasil [hitungJadwal].
WaktuSahurIftar waktuSahurIftar(
  JadwalSholatHarian jadwal, {
  required int imsakMenit,
}) {
  final DateTime subuh = jadwal.waktuLokal(WaktuSholat.subuh);
  final DateTime maghrib = jadwal.waktuLokal(WaktuSholat.maghrib);
  return WaktuSahurIftar(
    imsak: hitungImsak(subuh, imsakMenit),
    subuh: subuh,
    maghrib: maghrib,
    namaKota: jadwal.kota.nama,
    labelZona: jadwal.kota.zona.label,
    namaMetode: jadwal.namaMetode,
    imsakMenit: imsakMenit,
  );
}
