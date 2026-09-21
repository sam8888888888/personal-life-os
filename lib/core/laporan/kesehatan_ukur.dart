/// FR-104 & FR-105 — logika ukuran tubuh & jurnal angka kesehatan.
///
/// Murni (tanpa I/O) supaya angkanya bisa diuji langsung. Prinsip modul
/// kesehatan: aplikasi MENCATAT & MENUNJUKKAN TREN, bukan mendiagnosis. Tidak
/// ada kalimat "Anda kena penyakit X"; ambang yang dipakai selalu disebut
/// sebagai ambang umum, bukan vonis.
library;

/// Satu baris angka kesehatan (dipakai bersama FR-104 & FR-105).
class BarisUkur {
  const BarisUkur({
    required this.jenis,
    required this.nilai,
    required this.waktu,
    this.nilaiKedua,
  });

  final String jenis;
  final double nilai;
  final double? nilaiKedua;
  final DateTime waktu;
}

/// Ringkasan satu jenis angka dalam rentang hari terakhir.
class RingkasJenis {
  const RingkasJenis({
    required this.jenis,
    required this.jumlah,
    required this.terakhir,
    required this.waktuTerakhir,
    required this.rataRata,
    required this.terendah,
    required this.tertinggi,
    this.sebelumnya,
    this.nilaiKeduaTerakhir,
  });

  final String jenis;
  final int jumlah;
  final double terakhir;
  final DateTime waktuTerakhir;
  final double rataRata;
  final double terendah;
  final double tertinggi;
  final double? sebelumnya;
  final double? nilaiKeduaTerakhir;

  /// Arah perubahan dibanding catatan sebelumnya (ambang 0 = tidak berubah).
  ArahTren get arah {
    final s = sebelumnya;
    if (s == null) return ArahTren.baru;
    final selisih = terakhir - s;
    if (selisih.abs() < 0.0001) return ArahTren.tetap;
    return selisih > 0 ? ArahTren.naik : ArahTren.turun;
  }
}

enum ArahTren { baru, naik, turun, tetap }

String labelArah(ArahTren a) => switch (a) {
      ArahTren.baru => 'catatan pertama',
      ArahTren.naik => 'naik',
      ArahTren.turun => 'turun',
      ArahTren.tetap => 'sama',
    };

/// Hitung ringkasan per jenis dari baris mentah (hanya yang dalam [hari]).
List<RingkasJenis> ringkasPerJenis(
  List<BarisUkur> baris, {
  required DateTime sekarang,
  int hari = 30,
}) {
  final batas = sekarang.subtract(Duration(days: hari));
  final kelompok = <String, List<BarisUkur>>{};
  for (final b in baris) {
    if (b.waktu.isBefore(batas)) continue;
    kelompok.putIfAbsent(b.jenis, () => []).add(b);
  }

  final hasil = <RingkasJenis>[];
  kelompok.forEach((jenis, daftar) {
    final urut = [...daftar]..sort((a, b) => a.waktu.compareTo(b.waktu));
    final nilai = urut.map((e) => e.nilai).toList();
    final total = nilai.fold<double>(0, (a, b) => a + b);
    hasil.add(RingkasJenis(
      jenis: jenis,
      jumlah: urut.length,
      terakhir: nilai.last,
      waktuTerakhir: urut.last.waktu,
      rataRata: total / nilai.length,
      terendah: nilai.reduce((a, b) => a < b ? a : b),
      tertinggi: nilai.reduce((a, b) => a > b ? a : b),
      sebelumnya: nilai.length > 1 ? nilai[nilai.length - 2] : null,
      nilaiKeduaTerakhir: urut.last.nilaiKedua,
    ));
  });
  hasil.sort((a, b) => a.jenis.compareTo(b.jenis));
  return hasil;
}

/// Indeks Massa Tubuh = berat (kg) / tinggi (m)². null bila datanya belum lengkap.
double? imt(double? beratKg, double? tinggiCm) {
  if (beratKg == null || tinggiCm == null) return null;
  if (beratKg <= 0 || tinggiCm <= 0) return null;
  final meter = tinggiCm / 100;
  return beratKg / (meter * meter);
}

/// Sebutan IMT memakai ambang umum Kementerian Kesehatan RI (Asia-Pasifik):
/// <18,5 kurang · 18,5–22,9 normal · 23–24,9 berlebih · ≥25 obesitas.
/// Ini sebutan ambang umum, BUKAN diagnosis — itu sebabnya kalimatnya
/// menyebut "ambang umum".
String labelImt(double? nilai) {
  if (nilai == null) return 'Belum bisa dihitung';
  if (nilai < 18.5) return 'Di bawah ambang umum (18,5)';
  if (nilai < 23) return 'Dalam rentang umum (18,5–22,9)';
  if (nilai < 25) return 'Di atas ambang umum (23–24,9)';
  return 'Jauh di atas ambang umum (≥25)';
}

/// Progres menuju target (0–100 %). null bila target/awal belum ada, atau bila
/// target = titik awal (tidak bisa dihitung persentasenya).
double? persenProgres({
  required double? titikAwal,
  required double? target,
  required double? sekarang,
}) {
  if (titikAwal == null || target == null || sekarang == null) return null;
  final total = (target - titikAwal).abs();
  if (total < 0.0001) return null;
  final maju = (sekarang - titikAwal).abs();
  final arahBenar = (sekarang - titikAwal).sign == (target - titikAwal).sign;
  final nilai = arahBenar ? (maju / total) * 100 : 0.0;
  return nilai.clamp(0, 100).toDouble();
}

/// Satu jenis jurnal angka kesehatan (FR-105).
class JenisCatatan {
  const JenisCatatan({
    required this.nilaiDb,
    required this.label,
    required this.satuanBawaan,
    this.berpasangan = false,
    this.labelKedua = '',
    this.saranSatuan = const [],
  });

  final String nilaiDb;
  final String label;
  final String satuanBawaan;

  /// Tekanan darah butuh dua angka (sistolik & diastolik).
  final bool berpasangan;
  final String labelKedua;

  /// Pilihan satuan yang lazim (pengguna boleh menulis sendiri).
  final List<String> saranSatuan;
}

/// Jenis jurnal angka yang didukung FR-105.
const List<JenisCatatan> jenisCatatanKesehatan = [
  JenisCatatan(
    nilaiDb: 'tekanan_darah',
    label: 'Tekanan darah',
    satuanBawaan: 'mmHg',
    berpasangan: true,
    labelKedua: 'Diastolik',
    saranSatuan: ['mmHg'],
  ),
  JenisCatatan(
    nilaiDb: 'detak_jantung',
    label: 'Detak jantung',
    satuanBawaan: 'bpm',
    saranSatuan: ['bpm'],
  ),
  JenisCatatan(
    nilaiDb: 'gula_darah',
    label: 'Gula darah',
    satuanBawaan: 'mg/dL',
    saranSatuan: ['mg/dL', 'mmol/L'],
  ),
  JenisCatatan(
    nilaiDb: 'suhu',
    label: 'Suhu tubuh',
    satuanBawaan: '°C',
    saranSatuan: ['°C'],
  ),
  JenisCatatan(
    nilaiDb: 'saturasi',
    label: 'Saturasi oksigen',
    satuanBawaan: '%',
    saranSatuan: ['%'],
  ),
  JenisCatatan(
    nilaiDb: 'kolesterol',
    label: 'Kolesterol',
    satuanBawaan: 'mg/dL',
    saranSatuan: ['mg/dL', 'mmol/L'],
  ),
  JenisCatatan(
    nilaiDb: 'lab',
    label: 'Hasil lab lain',
    satuanBawaan: '',
    saranSatuan: [],
  ),
];

JenisCatatan? jenisCatatan(String nilaiDb) {
  for (final j in jenisCatatanKesehatan) {
    if (j.nilaiDb == nilaiDb) return j;
  }
  return null;
}

/// Kalimat netral yang dipakai bila angka berubah dibanding catatan sebelumnya.
const String kalimatPerubahanNetral =
    'Angka ini berbeda dari catatan sebelumnya — pertimbangkan membicarakannya '
    'dengan tenaga kesehatan. Aplikasi hanya mencatat, tidak menilai.';

/// Jenis ukuran tubuh untuk FR-104 (memakai tabel ukuran_tubuh yang sudah ada).
class JenisUkuran {
  const JenisUkuran({
    required this.nilaiDb,
    required this.label,
    required this.satuan,
    this.labelLain = '',
  });

  final String nilaiDb;
  final String label;
  final String satuan;
  final String labelLain;
}

const List<JenisUkuran> jenisUkuranTubuh = [
  JenisUkuran(nilaiDb: 'berat', label: 'Berat badan', satuan: 'kg'),
  JenisUkuran(nilaiDb: 'lingkar_perut', label: 'Lingkar perut', satuan: 'cm'),
  JenisUkuran(nilaiDb: 'lemak_tubuh', label: 'Lemak tubuh', satuan: '%'),
  JenisUkuran(nilaiDb: 'massa_otot', label: 'Massa otot', satuan: 'kg'),
  JenisUkuran(
      nilaiDb: 'detak_istirahat', label: 'Detak jantung istirahat', satuan: 'bpm'),
];
