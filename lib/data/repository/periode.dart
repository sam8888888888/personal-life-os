/// Perkakas periode untuk lapisan data kas (FR-71/FR-72/FR-76).
///
/// Sengaja berdiri sendiri di `lib/data/**` (bukan di `lib/core/utils/**`)
/// supaya jalur data tidak bergantung pada berkas milik jalur fitur.
library;

/// Kunci periode `YYYY-MM` dari sebuah tanggal.
String kunciBulan(DateTime tanggal) =>
    '${tanggal.year}-${tanggal.month.toString().padLeft(2, '0')}';

/// Rentang satu bulan kalender: [awal] pukul 00:00 tanggal 1 dan [akhir]
/// tanggal terakhir bulan itu (jam 00:00, batas inklusif untuk perbandingan
/// tanggal-tengah-malam).
({DateTime awal, DateTime akhir}) rentangBulan(DateTime bulan) => (
      awal: DateTime(bulan.year, bulan.month, 1),
      akhir: DateTime(bulan.year, bulan.month + 1, 0),
    );

/// Bulan (tengah malam tanggal 1) dari kunci `YYYY-MM`; null bila tidak sah.
///
/// Ketat: tahun 4 angka, bulan 2 angka (`2026-09`, bukan `2026-9`) — supaya
/// tidak ada dua kunci berbeda untuk bulan yang sama (yang akan membuat
/// anggaran/riwayat terbelah dua).
DateTime? bulanDariKunci(String kunci) {
  final bagian = kunci.trim().split('-');
  if (bagian.length != 2) return null;
  if (bagian[0].length != 4 || bagian[1].length != 2) return null;
  final tahun = int.tryParse(bagian[0]);
  final bulan = int.tryParse(bagian[1]);
  if (tahun == null || bulan == null) return null;
  if (tahun < 1900 || tahun > 2200 || bulan < 1 || bulan > 12) return null;
  return DateTime(tahun, bulan, 1);
}

/// true = format kunci `YYYY-MM` yang sah.
bool kunciBulanSah(String kunci) => bulanDariKunci(kunci) != null;

/// Kunci bulan berikutnya (`2026-09` → `2026-10`).
String kunciBulanBerikutnya(String kunci) {
  final bulan = bulanDariKunci(kunci);
  if (bulan == null) throw ArgumentError('Kunci bulan tidak sah: "$kunci"');
  return kunciBulan(DateTime(bulan.year, bulan.month + 1, 1));
}
