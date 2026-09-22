/// FR-135 — Jurnal Perjalanan (mesin hitung, tanpa basis data).
///
/// Kriteria terima PRD: "Pengeluaran perjalanan masuk laporan keuangan TANPA
/// input ulang" — karena itu setiap catatan dengan pengeluaran menyimpan
/// `transaksiId` (tautan ke baris keuangan), dan mesin ini melaporkan tautan
/// yang belum ada supaya tidak dihitung dua kali / hilang diam-diam.
library;

import 'perjalanan.dart';

/// Satu catatan jurnal (foto disimpan lewat tabel `lampiran`, bukan di sini).
class CatatanJurnal {
  const CatatanJurnal({
    required this.tanggal,
    required this.judul,
    this.tempat,
    this.cerita,
    this.penilaian,
    this.pengeluaranSen = 0,
    this.transaksiId,
    this.jumlahFoto = 0,
  });

  final DateTime tanggal;
  final String judul;
  final String? tempat;
  final String? cerita;

  /// 1–5; null = belum dinilai (tidak ditebak jadi 3).
  final int? penilaian;
  final int pengeluaranSen;

  /// Tautan ke baris transaksi keuangan; null = belum tercatat di keuangan.
  final int? transaksiId;
  final int jumlahFoto;

  /// Penilaian yang salah (di luar 1–5) dianggap belum dinilai.
  int? get penilaianSah =>
      (penilaian != null && penilaian! >= 1 && penilaian! <= 5)
          ? penilaian
          : null;

  /// Sudah masuk keuangan?
  bool get masukKeuangan => pengeluaranSen <= 0 || transaksiId != null;
}

/// Rekap jurnal satu perjalanan.
class RekapJurnal {
  const RekapJurnal({required this.catatan, required this.namaPerjalanan});

  final List<CatatanJurnal> catatan;
  final String namaPerjalanan;

  int get jumlahCatatan => catatan.length;

  /// Total pengeluaran yang DICATAT di jurnal (semua nilai).
  int get totalPengeluaranSen =>
      catatan.fold<int>(0, (a, b) => a + b.pengeluaranSen);

  /// Total yang benar-benar sudah ada di keuangan (punya tautan transaksi).
  int get totalMasukKeuanganSen => catatan
      .where((c) => c.masukKeuangan && c.pengeluaranSen > 0)
      .fold<int>(0, (a, b) => a + b.pengeluaranSen);

  /// Pengeluaran yang belum tercatat di keuangan (harus 0 kalau normal).
  int get totalBelumKeuanganSen =>
      catatan
          .where((c) => !c.masukKeuangan)
          .fold<int>(0, (a, b) => a + b.pengeluaranSen);

  /// Rata-rata penilaian dari yang benar-benar dinilai; null bila belum ada.
  double? get rataPenilaian {
    final dinilai = catatan.map((c) => c.penilaianSah).whereType<int>().toList();
    if (dinilai.isEmpty) return null;
    final total = dinilai.fold<int>(0, (a, b) => a + b);
    return total / dinilai.length;
  }

  int get jumlahFoto => catatan.fold<int>(0, (a, b) => a + b.jumlahFoto);

  /// Tempat yang paling sering muncul (kenangan). Null bila tidak ada tempat.
  String? get tempatTersering {
    final hitung = <String, int>{};
    for (final c in catatan) {
      final t = c.tempat?.trim();
      if (t == null || t.isEmpty) continue;
      hitung[t] = (hitung[t] ?? 0) + 1;
    }
    if (hitung.isEmpty) return null;
    final urut = hitung.entries.toList()
      ..sort((a, b) => b.value != a.value
          ? b.value.compareTo(a.value)
          : a.key.compareTo(b.key));
    return urut.first.key;
  }

  /// Dasar data supaya angka bisa ditelusuri (aturan PRD FR-141/142).
  String get dasar =>
      '$jumlahCatatan catatan · ${fmtRingkasRp(totalPengeluaranSen)} total · '
      '${fmtRingkasRp(totalMasukKeuanganSen)} sudah ada di laporan keuangan.';

  List<String> get belumBisa {
    final hasil = <String>[];
    if (jumlahCatatan == 0) {
      hasil.add('Belum ada catatan jurnal untuk perjalanan ini.');
    }
    if (totalBelumKeuanganSen > 0) {
      hasil.add(
          'Ada ${fmtRingkasRp(totalBelumKeuanganSen)} pengeluaran jurnal yang belum '
          'bertautan ke transaksi keuangan.');
    }
    if (rataPenilaian == null && jumlahCatatan > 0) {
      hasil.add('Belum ada catatan yang diberi penilaian 1–5.');
    }
    return hasil;
  }
}

RekapJurnal rekapJurnal({
  required String namaPerjalanan,
  required List<CatatanJurnal> catatan,
}) =>
    RekapJurnal(catatan: catatan, namaPerjalanan: namaPerjalanan);

/// Waktu catatan jurnal: bila jam tidak diisi, dilekatkan ke tengah hari
/// (bukan tengah malam supaya tidak "lompat hari" saat format jam).
DateTime waktuJurnal(DateTime tanggal, {int jam = 12, int menit = 0}) =>
    DateTime(tanggal.year, tanggal.month, tanggal.day, jam, menit);

/// Kunci idempotensi transaksi dari catatan jurnal — supaya menekan simpan dua
/// kali tidak membuat dua pengeluaran (pola PB-05/06/07).
String idTransaksiJurnal(String idPerjalanan, int nomorCatatan) =>
    'jurnal:$idPerjalanan:$nomorCatatan';
