/// FR-35 — Deteksi kenaikan tagihan (pure, tanpa I/O).
///
/// Tagihan dibandingkan dengan rata-rata 3 pembayaran sebelumnya. Kalau
/// kenaikannya melewati ambang, tagihan itu ditandai beserta BUKTINYA
/// (nominal terakhir, rata-rata sebelumnya, tanggal) — bukan cuma "harga naik".
///
/// Butuh minimal 4 pembayaran (3 untuk pembanding + 1 terakhir) agar
/// perbandingannya bermakna; yang kurang dari itu dilewati.
library;

/// Satu temuan kenaikan.
class KenaikanTagihan {
  const KenaikanTagihan({
    required this.nama,
    required this.nominalTerakhirSen,
    required this.rataRataSebelumnyaSen,
    required this.persenNaik,
    required this.tanggalTerakhir,
    required this.tigaTerakhirSen,
  });

  final String nama;
  final int nominalTerakhirSen;
  final int rataRataSebelumnyaSen;
  final int persenNaik;
  final DateTime tanggalTerakhir;
  final List<int> tigaTerakhirSen;

  int get selisihSen => nominalTerakhirSen - rataRataSebelumnyaSen;
}

/// Cari tagihan yang nominal terakhirnya naik dibanding rata-rata 3 sebelumnya.
///
/// [ambangPersen] bawaan 10%. Kenaikan kecil (di bawah [ambangSelisihSen])
/// diabaikan supaya tidak berisik.
List<KenaikanTagihan> deteksiKenaikanTagihan({
  required List<({String nama, DateTime tanggalBayar, int nominalSen})> riwayat,
  int ambangPersen = 10,
  int ambangSelisihSen = 100000,
}) {
  final perNama = <String, List<({DateTime tanggalBayar, int nominalSen})>>{};
  for (final r in riwayat) {
    perNama.putIfAbsent(r.nama, () => []).add(
        (tanggalBayar: r.tanggalBayar, nominalSen: r.nominalSen));
  }

  final temuan = <KenaikanTagihan>[];
  perNama.forEach((nama, daftar) {
    if (daftar.length < 4) return;
    daftar.sort((a, b) => a.tanggalBayar.compareTo(b.tanggalBayar));
    final terakhir = daftar.last;
    final sebelumnya = daftar.sublist(daftar.length - 4, daftar.length - 1);
    final rata = sebelumnya.fold<int>(0, (a, b) => a + b.nominalSen) ~/
        sebelumnya.length;
    if (rata <= 0) return;
    final selisih = terakhir.nominalSen - rata;
    final persen = ((selisih * 100) / rata).round();
    if (persen < ambangPersen || selisih < ambangSelisihSen) return;
    temuan.add(KenaikanTagihan(
      nama: nama,
      nominalTerakhirSen: terakhir.nominalSen,
      rataRataSebelumnyaSen: rata,
      persenNaik: persen,
      tanggalTerakhir: terakhir.tanggalBayar,
      tigaTerakhirSen: sebelumnya.map((b) => b.nominalSen).toList(),
    ));
  });

  temuan.sort((a, b) => b.persenNaik.compareTo(a.persenNaik));
  return temuan;
}
