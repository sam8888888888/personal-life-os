/// FR-37 — Rekap tahunan ala "Wrapped": logika murni.
///
/// Menghitung dari riwayat pembayaran yang sudah ada: total uang, jumlah
/// pembayaran, yang tepat waktu, sebaran per bulan, tagihan terbesar, dan
/// bulan tersibuk. Tidak ada peringkat pujian atau hukuman — hanya fakta.
library;

import 'statistik_pembayaran.dart';

/// Ringkasan satu tahun.
class RekapTahunan {
  const RekapTahunan({
    required this.tahun,
    required this.jumlahPembayaran,
    required this.totalSen,
    required this.tepatWaktu,
    required this.lewatJatuhTempo,
    required this.totalHariTelat,
    required this.perBulanSen,
    required this.perTagihanSen,
  });

  final int tahun;
  final int jumlahPembayaran;
  final int totalSen;
  final int tepatWaktu;
  final int lewatJatuhTempo;
  final int totalHariTelat;

  /// Total per bulan (kunci 1–12).
  final Map<int, int> perBulanSen;

  /// Total per nama tagihan (untuk "tagihan terbesar").
  final Map<String, int> perTagihanSen;

  bool get kosong => jumlahPembayaran == 0;

  /// Persentase tepat waktu (dibulatkan). 0 bila belum ada data.
  int get persenTepatWaktu => jumlahPembayaran == 0
      ? 0
      : ((tepatWaktu / jumlahPembayaran) * 100).round();

  int get rataRataSen =>
      jumlahPembayaran == 0 ? 0 : (totalSen / jumlahPembayaran).round();

  /// Nomor bulan dengan total terbesar (null bila belum ada data).
  int? get bulanTersibuk {
    int? puncak;
    var nilai = -1;
    perBulanSen.forEach((bulan, total) {
      if (total > nilai) {
        nilai = total;
        puncak = bulan;
      }
    });
    return nilai <= 0 ? null : puncak;
  }

  /// Nama tagihan dengan total terbesar (null bila belum ada data).
  String? get tagihanTerbesar {
    String? nama;
    var nilai = -1;
    perTagihanSen.forEach((n, total) {
      if (total > nilai) {
        nilai = total;
        nama = n;
      }
    });
    return nilai <= 0 ? null : nama;
  }
}

/// Hitung rekap tahun [tahun] dari baris pembayaran.
RekapTahunan hitungRekapTahunan(List<PembayaranRingkas> baris, int tahun) {
  var jumlah = 0;
  var total = 0;
  var tepat = 0;
  var lewat = 0;
  var telat = 0;
  final perBulan = <int, int>{};
  final perTagihan = <String, int>{};

  for (final b in baris) {
    if (b.tanggalBayar.year != tahun) continue;
    jumlah++;
    total += b.jumlahSen;
    if (b.tepatWaktu) {
      tepat++;
    } else {
      lewat++;
      telat += b.telatHari;
    }
    perBulan.update(b.tanggalBayar.month, (v) => v + b.jumlahSen,
        ifAbsent: () => b.jumlahSen);
    perTagihan.update(b.namaTagihan, (v) => v + b.jumlahSen,
        ifAbsent: () => b.jumlahSen);
  }

  return RekapTahunan(
    tahun: tahun,
    jumlahPembayaran: jumlah,
    totalSen: total,
    tepatWaktu: tepat,
    lewatJatuhTempo: lewat,
    totalHariTelat: telat,
    perBulanSen: perBulan,
    perTagihanSen: perTagihan,
  );
}

/// Nama bulan Indonesia (tanpa `intl`, aman dipakai di mana saja).
const List<String> namaBulanId = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String namaBulan(int bulan) =>
    bulan >= 1 && bulan <= 12 ? namaBulanId[bulan - 1] : 'Bulan $bulan';

/// Baris teks kartu berbagi (fakta, tanpa nada menghakimi).
List<String> barisKartuRekap(RekapTahunan r) {
  if (r.kosong) {
    return [
      'Rekap ${r.tahun}',
      'Belum ada pembayaran yang tercatat di tahun ini.',
      'Catat pembayaran pertama, lalu rekapnya muncul di sini.',
    ];
  }
  final puncak = r.bulanTersibuk;
  return [
    'Rekap ${r.tahun}',
    '${r.jumlahPembayaran} pembayaran tercatat',
    'Total dibayar ${rupiahRingkas(r.totalSen)}',
    'Tepat waktu ${r.persenTepatWaktu}% · lewat jatuh tempo ${r.lewatJatuhTempo}×',
    if (puncak != null) 'Bulan tersibuk: ${namaBulan(puncak)}',
    if (r.tagihanTerbesar != null) 'Terbesar: ${r.tagihanTerbesar}',
  ];
}

/// Rupiah ringkas tanpa data locale (mis. "Rp 1.500.000").
String rupiahRingkas(int sen) {
  final teks = (sen / 100).round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < teks.length; i++) {
    if (i > 0 && (teks.length - i) % 3 == 0) buf.write('.');
    buf.write(teks[i]);
  }
  return 'Rp ${buf.toString()}';
}

/// Bulan-bulan yang punya data, urut 1–12 (untuk grafik batang sederhana).
List<({int bulan, String label, int totalSen, double porsi})> grafikBulanan(
    RekapTahunan r) {
  final tertinggi = r.perBulanSen.values.isEmpty
      ? 0
      : r.perBulanSen.values.reduce((a, b) => a > b ? a : b);
  return [
    for (var b = 1; b <= 12; b++)
      (
        bulan: b,
        label: namaBulanId[b - 1].substring(0, 3),
        totalSen: r.perBulanSen[b] ?? 0,
        porsi: tertinggi == 0 ? 0 : ((r.perBulanSen[b] ?? 0) / tertinggi),
      ),
  ];
}
