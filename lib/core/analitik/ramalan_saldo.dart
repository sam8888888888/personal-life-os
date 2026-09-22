/// FR-143 — Forecast: proyeksi saldo beberapa bulan.
///
/// Kriteria terima PRD: "Proyeksi menampilkan **asumsi & rentang** (bukan satu
/// angka mutlak)". Karena itu keluaran di sini selalu berisi:
///   1. tiga angka per bulan (pesimis · tengah · optimis),
///   2. daftar [asumsi] yang menyebut dari mana setiap angka berasal,
///   3. daftar [belumBisa] bila catatan belum cukup untuk meramal.
///
/// Bagian "keluar tetap" (tagihan & langganan berulang) TIDAK dihitung ulang di
/// sini — ia memakai mesin FR-30 `proyeksiArusKas`, mesin yang sama dengan
/// pengingat, supaya tidak ada dua jadwal berbeda di aplikasi.
library;

import '../utils/tanggal_utils.dart';
import '../utils/uang_utils.dart';
import '../laporan/proyeksi_arus_kas.dart';
import 'temuan_pintar.dart' show TagihanJatuhTempo;

/// Satu bulan dalam ramalan saldo.
class BulanRamalan {
  const BulanRamalan({
    required this.bulan,
    required this.masukSen,
    required this.keluarTetapSen,
    required this.keluarVariabelSen,
    required this.saldoPesimisSen,
    required this.saldoTengahSen,
    required this.saldoOptimisSen,
  });

  final DateTime bulan;
  final int masukSen;
  final int keluarTetapSen;
  final int keluarVariabelSen;
  final int saldoPesimisSen;
  final int saldoTengahSen;
  final int saldoOptimisSen;

  int get keluarTotalSen => keluarTetapSen + keluarVariabelSen;
  int get arusBersihSen => masukSen - keluarTotalSen;
  String get label => fmtBulanAman(bulan);
}

/// Beberapa tagihan jatuh pada hari yang sama.
class TabrakanTenggat {
  const TabrakanTenggat({
    required this.tanggal,
    required this.nama,
    required this.totalSen,
  });

  final DateTime tanggal;
  final List<String> nama;
  final int totalSen;
}

/// Hasil ramalan.
class RamalanSaldo {
  const RamalanSaldo({
    required this.saldoAwalSen,
    required this.bulan,
    required this.tabrakan,
    required this.asumsi,
    required this.belumBisa,
  });

  final int saldoAwalSen;
  final List<BulanRamalan> bulan;
  final List<TabrakanTenggat> tabrakan;
  final List<String> asumsi;
  final List<String> belumBisa;

  /// Bulan pertama yang saldo pesimisnya minus (null bila aman).
  BulanRamalan? get bulanPertamaMinus {
    for (final b in bulan) {
      if (b.saldoPesimisSen < 0) return b;
    }
    return null;
  }
}

/// Cari hari yang kedatangan ≥[minimal] tagihan dalam [hariKeDepan] hari.
List<TabrakanTenggat> cariTabrakan(
  List<TagihanJatuhTempo> tagihan, {
  required DateTime sekarang,
  int hariKeDepan = 120,
  int minimal = 2,
}) {
  final batas = sekarang.add(Duration(days: hariKeDepan));
  final peta = <String, List<TagihanJatuhTempo>>{};
  for (final t in tagihan) {
    if (t.jatuhTempo.isBefore(DateTime(sekarang.year, sekarang.month, sekarang.day))) {
      continue;
    }
    if (t.jatuhTempo.isAfter(batas)) continue;
    final kunci = '${t.jatuhTempo.year}-${t.jatuhTempo.month}-${t.jatuhTempo.day}';
    peta.putIfAbsent(kunci, () => []).add(t);
  }
  final hasil = <TabrakanTenggat>[];
  peta.forEach((_, daftar) {
    if (daftar.length < minimal) return;
    daftar.sort((a, b) => a.nama.compareTo(b.nama));
    hasil.add(TabrakanTenggat(
      tanggal: daftar.first.jatuhTempo,
      nama: daftar.map((t) => t.nama).toList(),
      totalSen: daftar.fold<int>(0, (a, b) => a + b.nominalSen),
    ));
  });
  hasil.sort((a, b) => a.tanggal.compareTo(b.tanggal));
  return hasil;
}

/// Ramalkan saldo [jumlahBulan] ke depan.
///
/// [tetap] = hasil `proyeksiArusKas` (keluar tetap per bulan).
/// [pengeluaranHarianSen] & [simpanganHarianSen] = dari rata-rata catatan
/// transaksi harian; [simpanganHarianSen] menentukan lebar rentang.
RamalanSaldo ramalSaldo({
  required int saldoAwalSen,
  required List<BarisProyeksi> tetap,
  required int pemasukanBulananSen,
  required int pengeluaranHarianSen,
  int simpanganHarianSen = 0,
  List<TabrakanTenggat> tabrakan = const <TabrakanTenggat>[],
  int hariCatatanPengeluaran = 0,
  int bulanCatatanPemasukan = 0,
}) {
  final asumsi = <String>[];
  final belumBisa = <String>[];

  if (pengeluaranHarianSen <= 0) {
    belumBisa.add(
        'Pengeluaran harian belum pernah tercatat, jadi bagian "pengeluaran variabel" belum bisa diramal (dihitung 0).');
  } else {
    asumsi.add(
        'Pengeluaran variabel ${fmtRpDariSen(pengeluaranHarianSen)} per hari — dari rata-rata $hariCatatanPengeluaran hari catatan transaksi.');
  }
  if (pemasukanBulananSen <= 0) {
    belumBisa.add(
        'Pemasukan bulanan belum pernah dicatat, jadi sisi pemasukan dihitung 0.');
  } else {
    asumsi.add(
        'Pemasukan ${fmtRpDariSen(pemasukanBulananSen)} per bulan — rata-rata $bulanCatatanPemasukan bulan catatan.');
  }
  asumsi.add(
      'Tagihan & langganan berulang dihitung mengikuti jadwalnya (mesin yang sama dengan pengingat aplikasi).');
  if (simpanganHarianSen > 0) {
    asumsi.add(
        'Rentang: pesimis = pengeluaran harian +${fmtRpDariSen(simpanganHarianSen)}, '
        'optimis = pengeluaran harian −${fmtRpDariSen(simpanganHarianSen)}. '
        'Bukan satu angka mutlak.');
  } else {
    asumsi.add(
        'Catatan pengeluaran masih terlalu sedikit untuk menghitung rentang; ketiga angka masih sama.');
  }

  final hasil = <BulanRamalan>[];
  var saldoPesimis = saldoAwalSen;
  var saldoTengah = saldoAwalSen;
  var saldoOptimis = saldoAwalSen;

  for (final baris in tetap) {
    final hari = DateTime(baris.bulan.year, baris.bulan.month + 1, 0).day;
    final variabel = pengeluaranHarianSen * hari;
    final pesimis = (pengeluaranHarianSen + simpanganHarianSen) * hari;
    final harianOptimis =
        (pengeluaranHarianSen - simpanganHarianSen) < 0 ? 0 : pengeluaranHarianSen - simpanganHarianSen;
    final optimis = harianOptimis * hari;

    saldoPesimis += pemasukanBulananSen - baris.totalSen - pesimis;
    saldoTengah += pemasukanBulananSen - baris.totalSen - variabel;
    saldoOptimis += pemasukanBulananSen - baris.totalSen - optimis;

    hasil.add(BulanRamalan(
      bulan: baris.bulan,
      masukSen: pemasukanBulananSen,
      keluarTetapSen: baris.totalSen,
      keluarVariabelSen: variabel,
      saldoPesimisSen: saldoPesimis,
      saldoTengahSen: saldoTengah,
      saldoOptimisSen: saldoOptimis,
    ));
  }

  if (hasil.isEmpty) {
    belumBisa.add('Belum ada bulan yang bisa diramal.');
  }

  return RamalanSaldo(
    saldoAwalSen: saldoAwalSen,
    bulan: hasil,
    tabrakan: tabrakan,
    asumsi: asumsi,
    belumBisa: belumBisa,
  );
}
