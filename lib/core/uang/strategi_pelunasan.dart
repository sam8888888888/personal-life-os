/// Simulasi strategi pelunasan utang — FR-75. **PURE Dart**, tanpa Flutter
/// dan tanpa Drift, supaya gampang diuji dan dipakai ulang.
///
/// Dua metode yang disediakan:
///
/// * **Bola salju** (`MetodePelunasan.bolaSalju`) - utang terkecil lebih dulu.
/// * **Longsor** (`MetodePelunasan.longsor`) - bunga tertinggi lebih dulu.
///
/// Simulasi berjalan bulan demi bulan dengan aturan sederhana:
///
/// 1. bunga satu bulan = `sisa pokok * bunga tahunan / 12`, dibulatkan ke sen;
/// 2. minimum bayar tiap kewajiban dibayar lebih dulu, mengikuti urutan
///    prioritas;
/// 3. sisa setoran bulan itu dipakai pada kewajiban pertama yang belum tuntas
///    menurut urutan prioritas;
/// 4. sampai [batasBulan] bulan, simulasi berhenti dan sisanya dilaporkan apa
///    adanya (tidak dipaksa "lunas").
///
/// Batas kejujuran yang penting (dipakai juga oleh layar):
///
/// * ini SIMULASI sederhana, bukan nasihat keuangan;
/// * bunga dianggap tetap dan biaya/denda lain diabaikan;
/// * tidak ada dana darurat, pemasukan baru, atau pinjaman baru dihitung.
library;

/// Cara mengurutkan prioritas pelunasan.
enum MetodePelunasan {
  bolaSalju('bola_salju'),
  longsor('longsor');

  const MetodePelunasan(this.nilaiDb);

  /// Kunci stabil untuk penyimpanan/tampilan.
  final String nilaiDb;

  String get label => switch (this) {
        MetodePelunasan.bolaSalju => 'Bola salju',
        MetodePelunasan.longsor => 'Longsor',
      };

  String get penjelasan => switch (this) {
        MetodePelunasan.bolaSalju =>
          'Utang terkecil dibayar lebih dulu, lalu naik ke yang lebih besar.',
        MetodePelunasan.longsor =>
          'Bunga tertinggi dibayar lebih dulu, lalu turun ke yang lebih kecil.',
      };

  static MetodePelunasan dariNilai(String? v) => MetodePelunasan.values
      .firstWhere((m) => m.nilaiDb == v, orElse: () => MetodePelunasan.bolaSalju);
}

/// Kewajiban dalam bentuk ringkas: cukup untuk simulasi tanpa menyentuh
/// basis data.
class KewajibanRingkas {
  const KewajibanRingkas({
    required this.id,
    required this.nama,
    required this.sisaSen,
    this.bungaPersenTahun,
    this.minimumBayarSen,
  });

  final int id;
  final String nama;

  /// Sisa utang sekarang (sen) - bagian pokok, bukan termasuk bunga.
  final int sisaSen;

  /// Bunga per tahun dalam persen; null = belum diketahui (dianggap 0).
  final double? bungaPersenTahun;

  /// Minimum bayar per bulan (sen); null = tidak ada minimum (dianggap 0).
  final int? minimumBayarSen;

  double get bungaTahunan => bungaPersenTahun ?? 0;

  int get minimumBayar => minimumBayarSen ?? 0;

  KewajibanRingkas salinan({int? sisaSen}) => KewajibanRingkas(
        id: id,
        nama: nama,
        sisaSen: sisaSen ?? this.sisaSen,
        bungaPersenTahun: bungaPersenTahun,
        minimumBayarSen: minimumBayarSen,
      );
}

/// Bunga satu bulan dari sisa pokok (sen), dibulatkan ke sen terdekat.
int bungaBulanSen(int sisaPokokSen, double bungaPersenTahun) {
  if (sisaPokokSen <= 0 || bungaPersenTahun <= 0) return 0;
  return (sisaPokokSen * bungaPersenTahun / 1200).round();
}

/// Urutan prioritas pelunasan (tidak mengubah daftar masukan).
///
/// Urutan tetap dan dapat diulang: bila angkanya sama, nama dipakai sebagai
/// pembanding, lalu id. Jadi hasil simulasi tidak berubah-ubah setiap dibuka.
List<KewajibanRingkas> urutkanPelunasan(
  List<KewajibanRingkas> daftar,
  MetodePelunasan metode,
) {
  final salinan = List<KewajibanRingkas>.of(daftar);
  salinan.sort((a, b) {
    switch (metode) {
      case MetodePelunasan.bolaSalju:
        final c = a.sisaSen.compareTo(b.sisaSen);
        if (c != 0) return c;
      case MetodePelunasan.longsor:
        final c = b.bungaTahunan.compareTo(a.bungaTahunan);
        if (c != 0) return c;
        final s = a.sisaSen.compareTo(b.sisaSen);
        if (s != 0) return s;
    }
    final n = a.nama.compareTo(b.nama);
    return n != 0 ? n : a.id.compareTo(b.id);
  });
  return salinan;
}

/// Hasil untuk satu kewajiban: bulan ke berapa tuntas dan berapa uangnya.
class LangkahPelunasan {
  const LangkahPelunasan({
    required this.kewajibanId,
    required this.nama,
    required this.bulanKe,
    required this.sisaAwalSen,
    required this.totalDibayarSen,
    required this.totalBungaSen,
    required this.sudahTuntas,
  });

  final int kewajibanId;
  final String nama;

  /// Bulan ke berapa kewajiban ini tuntas (1 = bulan pertama). 0 = sudah
  /// tuntas sebelum simulasi mulai (sisanya nol).
  final int bulanKe;

  final int sisaAwalSen;
  final int totalDibayarSen;
  final int totalBungaSen;
  final bool sudahTuntas;
}

/// Hasil simulasi lengkap.
class HasilSimulasiPelunasan {
  const HasilSimulasiPelunasan({
    required this.metode,
    required this.urutan,
    required this.langkah,
    required this.setoranBulananSen,
    required this.jumlahBulan,
    required this.totalBungaSen,
    required this.totalDibayarSen,
    required this.sisaAkhirSen,
    required this.lunasSemua,
    required this.batasBulan,
  });

  final MetodePelunasan metode;

  /// Urutan prioritas yang dipakai simulasi.
  final List<KewajibanRingkas> urutan;

  /// Hasil per kewajiban, mengikuti [urutan].
  final List<LangkahPelunasan> langkah;

  final int setoranBulananSen;

  /// Berapa bulan simulasi berjalan sampai semua tuntas (atau sampai
  /// [batasBulan] bila belum tuntas).
  final int jumlahBulan;

  final int totalBungaSen;
  final int totalDibayarSen;

  /// Sisa utang yang belum tertutup saat simulasi berhenti.
  final int sisaAkhirSen;

  final bool lunasSemua;
  final int batasBulan;

  int get jumlahKewajiban => urutan.length;

  /// Jumlah kewajiban yang tuntas dalam batas simulasi.
  int get jumlahTuntas => langkah.where((l) => l.sudahTuntas).length;
}

/// Jalankan simulasi pelunasan.
///
/// [setoranBulananSen] = uang yang disiapkan setiap bulan untuk seluruh
/// kewajiban pada daftar ini. Harus lebih dari nol.
///
/// Lempar [ArgumentError] bila setoran <= 0 atau [batasBulan] < 1.
HasilSimulasiPelunasan simulasiPelunasan({
  required List<KewajibanRingkas> kewajiban,
  required int setoranBulananSen,
  MetodePelunasan metode = MetodePelunasan.bolaSalju,
  int batasBulan = 600,
}) {
  if (setoranBulananSen <= 0) {
    throw ArgumentError('Setoran bulanan perlu lebih dari nol.');
  }
  if (batasBulan < 1) {
    throw ArgumentError('Batas bulan perlu minimal 1.');
  }

  final urutan = urutkanPelunasan(kewajiban, metode);
  final jumlah = urutan.length;

  final sisaPokok = [for (final u in urutan) u.sisaSen < 0 ? 0 : u.sisaSen];
  final bungaTertunggak = List<int>.filled(jumlah, 0);
  final dibayar = List<int>.filled(jumlah, 0);
  final bungaDibebankan = List<int>.filled(jumlah, 0);
  final bulanTuntas = List<int>.filled(jumlah, 0);
  final sudahTuntas = [for (var i = 0; i < jumlah; i++) sisaPokok[i] == 0];

  int tagihan(int i) => sisaPokok[i] + bungaTertunggak[i];

  bool adaSisa() {
    for (var i = 0; i < jumlah; i++) {
      if (tagihan(i) > 0) return true;
    }
    return false;
  }

  /// Bayar [uang] ke kewajiban [i]: bunga tertunggak dulu, lalu pokok.
  /// [dibayar] mencatat uang yang BENAR-BENAR terpakai (bunga + pokok), bukan
  /// seluruh uang yang disodorkan.
  void bayar(int i, int uang) {
    var sisa = uang;
    final keBunga = sisa < bungaTertunggak[i] ? sisa : bungaTertunggak[i];
    bungaTertunggak[i] -= keBunga;
    sisa -= keBunga;
    final kePokok = sisa < sisaPokok[i] ? sisa : sisaPokok[i];
    sisaPokok[i] -= kePokok;
    dibayar[i] += keBunga + kePokok;
  }

  var bulan = 0;
  var bungaSeluruh = 0;

  while (bulan < batasBulan && adaSisa()) {
    bulan++;

    // 1) Bunga bulan ini (dihitung dari sisa pokok saja).
    for (var i = 0; i < jumlah; i++) {
      final b = bungaBulanSen(sisaPokok[i], urutan[i].bungaTahunan);
      if (b <= 0) continue;
      bungaTertunggak[i] += b;
      bungaDibebankan[i] += b;
      bungaSeluruh += b;
    }

    var anggaran = setoranBulananSen;

    // 2) Minimum bayar lebih dulu, mengikuti urutan prioritas.
    for (var i = 0; i < jumlah && anggaran > 0; i++) {
      final minimum = urutan[i].minimumBayar;
      if (minimum <= 0) continue;
      final t = tagihan(i);
      if (t <= 0) continue;
      var pakai = minimum < t ? minimum : t;
      if (pakai > anggaran) pakai = anggaran;
      if (pakai <= 0) continue;
      bayar(i, pakai);
      anggaran -= pakai;
    }

    // 3) Sisa anggaran ke kewajiban pertama yang belum tuntas pada urutan.
    for (var i = 0; i < jumlah && anggaran > 0; i++) {
      final t = tagihan(i);
      if (t <= 0) continue;
      final pakai = t < anggaran ? t : anggaran;
      bayar(i, pakai);
      anggaran -= pakai;
    }

    // 4) Catat kewajiban yang tuntas bulan ini.
    for (var i = 0; i < jumlah; i++) {
      if (sudahTuntas[i] || tagihan(i) > 0) continue;
      sudahTuntas[i] = true;
      bulanTuntas[i] = bulan;
    }
  }

  var sisaAkhir = 0;
  for (var i = 0; i < jumlah; i++) {
    sisaAkhir += tagihan(i);
  }
  var totalDibayar = 0;
  for (var i = 0; i < jumlah; i++) {
    totalDibayar += dibayar[i];
  }

  return HasilSimulasiPelunasan(
    metode: metode,
    urutan: urutan,
    langkah: [
      for (var i = 0; i < jumlah; i++)
        LangkahPelunasan(
          kewajibanId: urutan[i].id,
          nama: urutan[i].nama,
          bulanKe: bulanTuntas[i],
          sisaAwalSen: urutan[i].sisaSen,
          totalDibayarSen: dibayar[i],
          totalBungaSen: bungaDibebankan[i],
          sudahTuntas: sudahTuntas[i],
        ),
    ],
    setoranBulananSen: setoranBulananSen,
    jumlahBulan: bulan,
    totalBungaSen: bungaSeluruh,
    totalDibayarSen: totalDibayar,
    sisaAkhirSen: sisaAkhir,
    lunasSemua: sisaAkhir == 0,
    batasBulan: batasBulan,
  );
}
