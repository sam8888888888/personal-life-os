/// FR-29 — Riwayat pembayaran & statistik (pure, tanpa I/O → mudah diuji).
///
/// Yang dihitung dari riwayat pembayaran yang sudah ada:
///   * jumlah pembayaran, total uang, rata-rata, terbesar & terkecil
///   * berapa yang tepat waktu / terlambat + rata-rata hari keterlambatan
///   * tren per bulan (12 bulan terakhir) untuk grafik batang sederhana
///   * peringkat tagihan yang paling sering & paling besar dibayar
///
/// Catatan bahasa: tidak ada kata menghakimi ("gagal", "buruk"). Yang terlambat
/// disebut apa adanya: "lewat jatuh tempo", dengan jumlah harinya.
library;

import '../../data/database/database.dart';

/// Statistik keseluruhan dari seluruh riwayat pembayaran.
class StatistikPembayaran {
  const StatistikPembayaran({
    required this.jumlahPembayaran,
    required this.totalSen,
    required this.rataRataSen,
    required this.tepatWaktu,
    required this.lewatJatuhTempo,
    required this.totalHariTelat,
    required this.terbesarSen,
    required this.terkecilSen,
  });

  final int jumlahPembayaran;
  final int totalSen;
  final int rataRataSen;
  final int tepatWaktu;
  final int lewatJatuhTempo;
  final int totalHariTelat;
  final int terbesarSen;
  final int terkecilSen;

  bool get kosong => jumlahPembayaran == 0;

  /// Persentase pembayaran tepat waktu (0–100, dibulatkan).
  int get persenTepatWaktu =>
      jumlahPembayaran == 0 ? 0 : ((tepatWaktu * 100) / jumlahPembayaran).round();

  /// Rata-rata hari keterlambatan pada pembayaran yang lewat jatuh tempo.
  int get rataHariTelat =>
      lewatJatuhTempo == 0 ? 0 : (totalHariTelat / lewatJatuhTempo).round();
}

/// Statistik satu bulan (untuk tren).
class StatistikBulan {
  const StatistikBulan({
    required this.bulan,
    required this.jumlahPembayaran,
    required this.totalSen,
    required this.tepatWaktu,
  });

  final DateTime bulan;
  final int jumlahPembayaran;
  final int totalSen;
  final int tepatWaktu;
}

/// Ringkasan per tagihan (untuk daftar "paling sering dibayar").
class StatistikPerTagihan {
  const StatistikPerTagihan({
    required this.nama,
    required this.jumlahPembayaran,
    required this.totalSen,
    required this.rataRataSen,
    required this.tepatWaktu,
  });

  final String nama;
  final int jumlahPembayaran;
  final int totalSen;
  final int rataRataSen;
  final int tepatWaktu;
}

/// Satu baris riwayat yang sudah dinormalkan (dipakai statistik & ekspor CSV).
class PembayaranRingkas {
  const PembayaranRingkas({
    required this.namaTagihan,
    required this.tanggalBayar,
    required this.jumlahSen,
    this.telatHari = 0,
  });

  final String namaTagihan;
  final DateTime tanggalBayar;
  final int jumlahSen;
  final int telatHari;

  bool get tepatWaktu => telatHari <= 0;
}

/// Ambil riwayat dari basis data menjadi baris ringkas.
List<PembayaranRingkas> ringkasRiwayat(
    List<RiwayatPembayaranData> riwayat,
    {Map<int, String> namaTagihan = const <int, String>{}}) {
  return riwayat
      .map((r) => PembayaranRingkas(
            namaTagihan: namaTagihan[r.tagihanId] ?? 'Tagihan #${r.tagihanId}',
            tanggalBayar: r.tanggalBayar,
            jumlahSen: r.jumlahSen,
            telatHari: r.telatHari ?? 0,
          ))
      .toList();
}

/// Hitung statistik keseluruhan.
StatistikPembayaran hitungStatistikPembayaran(List<PembayaranRingkas> baris) {
  if (baris.isEmpty) {
    return const StatistikPembayaran(
      jumlahPembayaran: 0,
      totalSen: 0,
      rataRataSen: 0,
      tepatWaktu: 0,
      lewatJatuhTempo: 0,
      totalHariTelat: 0,
      terbesarSen: 0,
      terkecilSen: 0,
    );
  }
  var total = 0;
  var terbesar = baris.first.jumlahSen;
  var terkecil = baris.first.jumlahSen;
  var tepat = 0;
  var telat = 0;
  var hariTelat = 0;
  for (final b in baris) {
    total += b.jumlahSen;
    if (b.jumlahSen > terbesar) terbesar = b.jumlahSen;
    if (b.jumlahSen < terkecil) terkecil = b.jumlahSen;
    if (b.tepatWaktu) {
      tepat++;
    } else {
      telat++;
      hariTelat += b.telatHari;
    }
  }
  return StatistikPembayaran(
    jumlahPembayaran: baris.length,
    totalSen: total,
    rataRataSen: (total / baris.length).round(),
    tepatWaktu: tepat,
    lewatJatuhTempo: telat,
    totalHariTelat: hariTelat,
    terbesarSen: terbesar,
    terkecilSen: terkecil,
  );
}

/// Tren [jumlahBulan] bulan terakhir (bulan terlama di depan, supaya grafiknya
/// terbaca dari kiri ke kanan).
List<StatistikBulan> statistikPerBulan(List<PembayaranRingkas> baris,
    {int jumlahBulan = 12, DateTime? acuan}) {
  final kini = acuan ?? DateTime.now();
  final daftar = <StatistikBulan>[];
  for (var i = jumlahBulan - 1; i >= 0; i--) {
    final bulan = DateTime(kini.year, kini.month - i, 1);
    final isi = baris.where((b) =>
        b.tanggalBayar.year == bulan.year && b.tanggalBayar.month == bulan.month);
    var total = 0;
    var tepat = 0;
    for (final b in isi) {
      total += b.jumlahSen;
      if (b.tepatWaktu) tepat++;
    }
    daftar.add(StatistikBulan(
      bulan: bulan,
      jumlahPembayaran: isi.length,
      totalSen: total,
      tepatWaktu: tepat,
    ));
  }
  return daftar;
}

/// Ringkasan per tagihan, diurutkan dari total terbesar.
List<StatistikPerTagihan> statistikPerTagihan(List<PembayaranRingkas> baris) {
  final peta = <String, List<PembayaranRingkas>>{};
  for (final b in baris) {
    peta.putIfAbsent(b.namaTagihan, () => <PembayaranRingkas>[]).add(b);
  }
  final hasil = peta.entries.map((e) {
    final total = e.value.fold<int>(0, (a, b) => a + b.jumlahSen);
    return StatistikPerTagihan(
      nama: e.key,
      jumlahPembayaran: e.value.length,
      totalSen: total,
      rataRataSen: (total / e.value.length).round(),
      tepatWaktu: e.value.where((b) => b.tepatWaktu).length,
    );
  }).toList();
  hasil.sort((a, b) => b.totalSen.compareTo(a.totalSen));
  return hasil;
}
