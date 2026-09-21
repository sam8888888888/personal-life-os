/// FR-40 & FR-17 — Pembelajaran pola bayar (pure, tanpa I/O).
///
/// Dari riwayat pembayaran, aplikasi mempelajari:
///   * hari dalam bulan yang biasanya dipakai membayar (mis. selalu tgl 20),
///   * berapa hari sebelum/sesudah jatuh tempo tagihan itu biasanya dibayar,
///   * seberapa kuat polanya (jumlah bukti + kerapatannya → "keyakinan").
///
/// Hasilnya dipakai untuk dua hal:
///   * FR-40: USUL penyesuaian pengingat (ditampilkan ke pengguna, tinggal
///     diterapkan — aplikasi tidak mengubah jadwal diam-diam),
///   * FR-17: bila saklar "pengingat menyesuaikan pola" menyala, satu pengingat
///     tambahan dipasang pada hari yang biasanya dipakai membayar.
library;

/// Satu catatan pembayaran yang dipakai untuk belajar.
class CatatanBayar {
  const CatatanBayar({
    required this.tagihanId,
    required this.namaTagihan,
    required this.tanggalBayar,
    required this.jatuhTempoPeriode,
  });

  final int tagihanId;
  final String namaTagihan;
  final DateTime tanggalBayar;

  /// Jatuh tempo periode yang dibayar (dari riwayat, bukan jatuh tempo sekarang).
  final DateTime jatuhTempoPeriode;
}

/// Hasil pembelajaran satu tagihan.
class PolaBayar {
  const PolaBayar({
    required this.tagihanId,
    required this.namaTagihan,
    required this.jumlahPembayaran,
    required this.hariKhasDalamBulan,
    required this.selisihHariKhas,
    required this.keyakinan,
  });

  final int tagihanId;
  final String namaTagihan;
  final int jumlahPembayaran;

  /// Hari dalam bulan yang paling sering dipakai (1–31); null bila belum ada.
  final int? hariKhasDalamBulan;

  /// Median selisih hari: positif = biasanya dibayar SEBELUM jatuh tempo,
  /// negatif = biasanya setelah jatuh tempo.
  final int? selisihHariKhas;

  /// 0–100: makin banyak bukti & makin rapat polanya, makin tinggi.
  final int keyakinan;

  /// Bukti cukup untuk dipakai menyesuaikan pengingat.
  bool get cukupBukti => jumlahPembayaran >= 3 && keyakinan >= 60;

  /// Kalimat penjelas untuk layar (tanpa istilah teknis).
  String get ringkasan {
    if (jumlahPembayaran < 2) {
      return 'Baru $jumlahPembayaran pembayaran — belum terlihat polanya.';
    }
    final hari = hariKhasDalamBulan == null ? '—' : 'tanggal $hariKhasDalamBulan';
    final s = selisihHariKhas;
    final kebiasaan = s == null
        ? ''
        : s > 0
            ? ' · biasanya $s hari sebelum jatuh tempo'
            : s < 0
                ? ' · biasanya ${-s} hari setelah jatuh tempo'
                : ' · biasanya tepat pada jatuh tempo';
    return 'Biasanya bayar $hari$kebiasaan (dari $jumlahPembayaran pembayaran).';
  }
}

/// Median dari daftar angka (mengembalikan null bila kosong).
int? median(List<int> angka) {
  if (angka.isEmpty) return null;
  final urut = [...angka]..sort();
  final tengah = urut.length ~/ 2;
  if (urut.length.isOdd) return urut[tengah];
  return ((urut[tengah - 1] + urut[tengah]) / 2).round();
}

/// Nilai yang paling sering muncul (null bila kosong). Bila seri, diambil yang
/// lebih kecil supaya hasilnya tetap sama setiap dijalankan.
int? modus(List<int> angka) {
  if (angka.isEmpty) return null;
  final hitung = <int, int>{};
  for (final a in angka) {
    hitung[a] = (hitung[a] ?? 0) + 1;
  }
  var terbaik = angka.first;
  var terbanyak = 0;
  hitung.forEach((nilai, jumlah) {
    if (jumlah > terbanyak || (jumlah == terbanyak && nilai < terbaik)) {
      terbaik = nilai;
      terbanyak = jumlah;
    }
  });
  return terbaik;
}

/// Hitung pola per tagihan.
List<PolaBayar> hitungPolaBayar(List<CatatanBayar> riwayat) {
  final perTagihan = <int, List<CatatanBayar>>{};
  for (final r in riwayat) {
    perTagihan.putIfAbsent(r.tagihanId, () => []).add(r);
  }

  final hasil = <PolaBayar>[];
  perTagihan.forEach((id, daftar) {
    final hari = daftar.map((d) => d.tanggalBayar.day).toList();
    final selisih = daftar
        .map((d) => d.jatuhTempoPeriode.difference(d.tanggalBayar).inDays)
        .toList();

    // Keyakinan: 60% dari banyaknya bukti (3 pembayaran = penuh pada bagian ini)
    // + 40% dari kerapatan pola (berapa banyak yang sama dengan hari khas).
    final hariKhas = modus(hari);
    final cocok = hari.where((h) => h == hariKhas).length;
    final kerapatan = daftar.isEmpty ? 0.0 : cocok / daftar.length;
    final bagianBukti = (daftar.length / 3).clamp(0.0, 1.0);
    final keyakinan = (60 * bagianBukti + 40 * kerapatan).round();

    hasil.add(PolaBayar(
      tagihanId: id,
      namaTagihan: daftar.first.namaTagihan,
      jumlahPembayaran: daftar.length,
      hariKhasDalamBulan: hariKhas,
      selisihHariKhas: median(selisih),
      keyakinan: keyakinan,
    ));
  });

  hasil.sort((a, b) => b.jumlahPembayaran.compareTo(a.jumlahPembayaran));
  return hasil;
}

/// FR-40: usul penyesuaian daftar pengingat (lead hari) satu tagihan.
class UsulPengingat {
  const UsulPengingat({
    required this.tagihanId,
    required this.namaTagihan,
    required this.leadSekarang,
    required this.leadUsul,
    required this.alasan,
  });

  final int tagihanId;
  final String namaTagihan;
  final List<int> leadSekarang;
  final List<int> leadUsul;
  final String alasan;

  bool get berbeda => leadSekarang.join(',') != leadUsul.join(',');
}

/// Susun daftar lead yang disarankan dari kebiasaan membayar.
///
/// Contoh: biasanya dibayar 4 hari sebelum jatuh tempo → H-5, H-3, H-1, H
/// (satu hari sebelum kebiasaan, supaya pengingat datang lebih dulu).
List<int> leadDisarankan(int? selisihHariKhas) {
  if (selisihHariKhas == null) return const [3, 1, 0];
  final kebiasaan = selisihHariKhas < 0 ? 0 : selisihHariKhas;
  // H-0 (hari jatuh tempo) & H-1 tidak pernah dibuang — itu pengingat paling
  // penting; sisanya mengikuti kebiasaan membayar.
  final kandidat = <int>{0, 1};
  if (kebiasaan >= 2) {
    kandidat.add(kebiasaan);
    kandidat.add(kebiasaan + 1);
  }
  final urut = kandidat.toList()..sort((a, b) => b.compareTo(a));
  return urut.take(4).toList();
}

/// Usul untuk semua tagihan yang polanya sudah cukup kuat.
List<UsulPengingat> usulPengingat({
  required List<PolaBayar> pola,
  required Map<int, List<int>> leadSekarang,
}) {
  final hasil = <UsulPengingat>[];
  for (final p in pola) {
    if (!p.cukupBukti) continue;
    final sekarang = leadSekarang[p.tagihanId] ?? const <int>[];
    final usul = leadDisarankan(p.selisihHariKhas);
    if (sekarang.join(',') == usul.join(',')) continue;
    final s = p.selisihHariKhas ?? 0;
    hasil.add(UsulPengingat(
      tagihanId: p.tagihanId,
      namaTagihan: p.namaTagihan,
      leadSekarang: sekarang,
      leadUsul: usul,
      alasan: s > 0
          ? 'Biasanya dibayar $s hari sebelum jatuh tempo, jadi pengingat '
              'digeser mengikuti kebiasaan itu.'
          : s < 0
              ? 'Biasanya baru dibayar ${-s} hari setelah jatuh tempo — '
                  'pengingat dirapatkan di sekitar hari jatuh tempo.'
              : 'Biasanya dibayar tepat pada hari jatuh tempo.',
    ));
  }
  return hasil;
}

/// FR-17: peta tagihanId → lead hari yang biasanya dipakai membayar (hanya untuk
/// tagihan yang polanya kuat). Dipakai perencana pengingat untuk menambah satu
/// pengingat pada hari kebiasaan.
Map<int, int> leadPintarDariPola(List<PolaBayar> pola,
    {required Set<int> tagihanAktif}) {
  final hasil = <int, int>{};
  for (final p in pola) {
    if (!p.cukupBukti) continue;
    if (!tagihanAktif.contains(p.tagihanId)) continue;
    final s = p.selisihHariKhas;
    if (s == null) continue;
    // Hanya bila kebiasaannya lebih awal dari jatuh tempo (s > 0). Kalau
    // pengguna biasanya telat, pengingat terlambat sudah ada sendiri.
    if (s > 0) hasil[p.tagihanId] = s;
  }
  return hasil;
}
