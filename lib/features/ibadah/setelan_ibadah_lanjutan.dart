/// Setelan tambahan untuk ibadah lanjutan (FR-91/92/93/95).
///
/// Semua kunci penyimpanan didefinisikan SEKALI di sini, lalu dipakai lewat
/// [PengaturanIbadah.simpanan] — jadi setelan tetap satu pintu dengan layar
/// Jadwal Sholat & Pengingat Ibadah (kota, metode, ihtiyati, dsb).
///
/// Semua nilai punya bawaan yang aman: isi yang hilang atau tidak sah kembali
/// ke bawaan, tidak pernah menghasilkan galat.
library;

import '../../core/ibadah/kalender_hijriah.dart';
import '../../data/repository/ibadah_lanjutan_repository.dart';
import 'logika_ramadan.dart';
import 'pengaturan_ibadah.dart';

/// FR-91: selisih imsak dari Subuh (menit).
const String kunciImsakMenit = 'ibadah.ramadan.imsak_menit';

/// FR-91: pengingat sahur — bawaan **mati**.
const String kunciPengingatSahur = 'ibadah.ramadan.pengingat_sahur';

/// FR-91: pengingat iftar (maghrib) — bawaan **mati**.
const String kunciPengingatIftar = 'ibadah.ramadan.pengingat_iftar';

/// FR-91: acuan perhitungan Hijriah (kode [AcuanHijriah]).
const String kunciAcuanHijriah = 'ibadah.ramadan.acuan_hijriah';

/// FR-91: koreksi hari Hijriah (-2..+2).
const String kunciKoreksiHijriah = 'ibadah.ramadan.koreksi_hijriah';

/// FR-92: target qadha yang DIISI SENDIRI pengguna (0 = belum diisi).
const String kunciTargetQadha = 'ibadah.puasa.target_qadha';

/// FR-93: target harian Quran (angka, satuan lihat [kunciSatuanQuran]).
const String kunciTargetQuranHarian = 'ibadah.quran.target_harian';

/// FR-93: target mingguan Quran.
const String kunciTargetQuranMingguan = 'ibadah.quran.target_mingguan';

/// FR-93: satuan target Quran (kode [SatuanQuran]).
const String kunciSatuanQuran = 'ibadah.quran.satuan';

/// FR-95: target bawaan penghitung dzikir.
const String kunciTargetDzikir = 'ibadah.dzikir.target';

/// FR-95: nama dzikir terakhir yang dipakai.
const String kunciNamaDzikir = 'ibadah.dzikir.nama';

/// Batas koreksi hari Hijriah (sama dengan layar Kalender Hijriah).
const int koreksiHijriahMaksimal = 2;

/// Target Quran terbesar yang diterima antarmuka (menjaga salah ketik).
const double targetQuranMaksimal = 1000;

/// Target dzikir terbesar yang diterima antarmuka.
const int targetDzikirMaksimal = 10000;

/// Ubah teks angka menjadi `double` (menerima koma maupun titik).
double? angkaDesimal(String? teks) {
  if (teks == null) return null;
  final String bersih = teks.trim().replaceAll(',', '.');
  if (bersih.isEmpty) return null;
  return double.tryParse(bersih);
}

/// Tulis angka desimal tanpa ekor nol yang mengganggu (1.0 -> "1").
String teksAngkaDesimal(double nilai) {
  if (nilai == nilai.roundToDouble() && nilai.abs() < 1e15) {
    return nilai.round().toString();
  }
  return nilai.toString();
}

/// Setelan ibadah lanjutan (pembungkus tipis di atas penyimpanan kunci-nilai).
class SetelanIbadahLanjutan {
  SetelanIbadahLanjutan(this.simpanan);

  final PenyimpananSetelan simpanan;

  // --- FR-91 Ramadan -----------------------------------------------------

  Future<int> imsakMenit() async {
    final int nilai = await simpanan.bacaAngka(kunciImsakMenit, imsakMenitBawaan);
    return nilai.clamp(imsakMenitMinimal, imsakMenitMaksimal);
  }

  Future<void> simpanImsakMenit(int menit) => simpanan.simpan(kunciImsakMenit,
      '${menit.clamp(imsakMenitMinimal, imsakMenitMaksimal)}');

  /// Bawaan **mati**: pengingat sahur hanya berbunyi setelah pengguna
  /// menyalakannya sendiri.
  Future<bool> pengingatSahurAktif() =>
      simpanan.bacaSaklar(kunciPengingatSahur, bawaan: false);

  Future<void> simpanPengingatSahur(bool aktif) =>
      simpanan.simpan(kunciPengingatSahur, aktif ? 'true' : 'false');

  /// Bawaan **mati** — sama seperti pengingat sahur.
  Future<bool> pengingatIftarAktif() =>
      simpanan.bacaSaklar(kunciPengingatIftar, bawaan: false);

  Future<void> simpanPengingatIftar(bool aktif) =>
      simpanan.simpan(kunciPengingatIftar, aktif ? 'true' : 'false');

  Future<AcuanHijriah> acuanHijriah() async {
    final String kode = await simpanan.bacaTeks(
        kunciAcuanHijriah, AcuanHijriah.ummAlQura.kode);
    return AcuanHijriah.values.firstWhere(
      (AcuanHijriah a) => a.kode == kode,
      orElse: () => AcuanHijriah.ummAlQura,
    );
  }

  Future<void> simpanAcuanHijriah(AcuanHijriah acuan) =>
      simpanan.simpan(kunciAcuanHijriah, acuan.kode);

  Future<int> koreksiHijriah() async {
    final int nilai = await simpanan.bacaAngka(kunciKoreksiHijriah, 0);
    return nilai.clamp(-koreksiHijriahMaksimal, koreksiHijriahMaksimal);
  }

  Future<void> simpanKoreksiHijriah(int hari) => simpanan.simpan(
      kunciKoreksiHijriah,
      '${hari.clamp(-koreksiHijriahMaksimal, koreksiHijriahMaksimal)}');

  // --- FR-92 puasa -------------------------------------------------------

  /// Target qadha dari pengguna. 0 = pengguna belum mengisi target; aplikasi
  /// TIDAK menetapkan kewajiban apa pun.
  Future<int> targetQadha() async {
    final int nilai = await simpanan.bacaAngka(kunciTargetQadha, 0);
    return nilai < 0 ? 0 : nilai;
  }

  Future<void> simpanTargetQadha(int hari) =>
      simpanan.simpan(kunciTargetQadha, '${hari < 0 ? 0 : hari}');

  // --- FR-93 Quran -------------------------------------------------------

  Future<double> targetQuranHarian() async {
    final double nilai = angkaDesimal(
            await simpanan.bacaTeks(kunciTargetQuranHarian, '1')) ??
        1;
    return nilai.clamp(0, targetQuranMaksimal);
  }

  Future<void> simpanTargetQuranHarian(double nilai) => simpanan.simpan(
      kunciTargetQuranHarian, teksAngkaDesimal(nilai.clamp(0, targetQuranMaksimal)));

  Future<double> targetQuranMingguan() async {
    final double nilai = angkaDesimal(
            await simpanan.bacaTeks(kunciTargetQuranMingguan, '7')) ??
        7;
    return nilai.clamp(0, targetQuranMaksimal);
  }

  Future<void> simpanTargetQuranMingguan(double nilai) => simpanan.simpan(
      kunciTargetQuranMingguan,
      teksAngkaDesimal(nilai.clamp(0, targetQuranMaksimal)));

  Future<SatuanQuran> satuanQuran() async {
    final String kode =
        await simpanan.bacaTeks(kunciSatuanQuran, SatuanQuran.halaman.nilaiDb);
    return SatuanQuran.values.firstWhere(
      (SatuanQuran s) => s.nilaiDb == kode,
      orElse: () => SatuanQuran.halaman,
    );
  }

  Future<void> simpanSatuanQuran(SatuanQuran satuan) =>
      simpanan.simpan(kunciSatuanQuran, satuan.nilaiDb);

  // --- FR-95 dzikir ------------------------------------------------------

  Future<int> targetDzikir() async {
    final int nilai = await simpanan.bacaAngka(kunciTargetDzikir, 33);
    return nilai <= 0 ? 33 : nilai.clamp(1, targetDzikirMaksimal);
  }

  Future<void> simpanTargetDzikir(int target) => simpanan.simpan(
      kunciTargetDzikir, '${target.clamp(1, targetDzikirMaksimal)}');

  Future<String> namaDzikir() async {
    final String teks = await simpanan.bacaTeks(kunciNamaDzikir, 'Subhanallah');
    return teks.trim().isEmpty ? 'Subhanallah' : teks.trim();
  }

  Future<void> simpanNamaDzikir(String nama) => simpanan.simpan(
      kunciNamaDzikir, nama.trim().isEmpty ? 'Subhanallah' : nama.trim());
}
