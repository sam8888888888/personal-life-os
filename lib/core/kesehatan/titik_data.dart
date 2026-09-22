/// Satu titik data (tanggal + angka) yang dipakai bersama modul kesehatan
/// lanjutan: Peringatan Dini (FR-114) dan Ringkasan Kunjungan (FR-115).
///
/// Dibuat satu tipe saja supaya kedua modul tidak punya tipe kembar dan
/// pemetaan dari basis data cukup sekali.
library;

class TitikData {
  const TitikData({required this.tanggal, required this.nilai});

  final DateTime tanggal;
  final num nilai;
}
