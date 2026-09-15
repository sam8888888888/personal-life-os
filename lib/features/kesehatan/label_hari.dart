/// Label hari Bahasa Indonesia untuk grafik & riwayat.
library;

const List<String> _namaHari = [
  'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min',
];

/// "Sen" untuk 2026-09-14 (Senin).
String labelHariSingkat(DateTime t) => _namaHari[t.weekday - 1];

/// "Senin" untuk 2026-09-14.
String labelHariPanjang(DateTime t) => const [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
    ][t.weekday - 1];

/// "14/09" — tanggal ringkas tanpa pustaka locale.
String labelTanggalPendek(DateTime t) =>
    '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}';

/// "14 Sep 2026" — bulan disingkat Bahasa Indonesia.
String labelTanggalSedang(DateTime t) => '${t.day} ${bulanSingkat(t.month)} ${t.year}';

/// "Sep" untuk bulan 9.
String bulanSingkat(int bulan) => const [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ][(bulan - 1).clamp(0, 11)];
