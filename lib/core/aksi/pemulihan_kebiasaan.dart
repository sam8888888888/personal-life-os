/// FR-81 & FR-85 — metrik pemulihan kebiasaan dan konsistensi **tanpa skor
/// moral**. MURNI: tanpa basis data, tanpa tampilan.
///
/// Aturan yang dipegang berkas ini:
/// 1. angka yang dilaporkan hanya "tercatat / belum tercatat" dan jeda;
/// 2. tidak ada angka tunggal yang menggambarkan kualitas manusia (FR-85);
/// 3. tidak ada kata menghakimi — tidak ada "gagal", "hukuman", "streak putus"
///    (PRD §III-11, uji bahasa mengunci ini);
/// 4. jeda bukan pelanggaran: kalimatnya menyebut keadaan, lalu mempersilakan
///    melanjutkan.
library;

/// Hasil hitungan pemulihan untuk satu kebiasaan pada satu rentang hari.
class NilaiPemulihan {
  const NilaiPemulihan({
    required this.rentangHari,
    required this.hariTercatat,
    required this.jedaTerpanjang,
    required this.hariSejakCatatanTerakhir,
    required this.hariBerturutAkhir,
    required this.rataNilai,
  });

  /// Panjang rentang yang dihitung (mis. 7 atau 30).
  final int rentangHari;

  /// Jumlah hari dengan catatan (nilai > 0).
  final int hariTercatat;

  /// Jeda terpanjang: hari berurutan tanpa catatan.
  final int jedaTerpanjang;

  /// Berapa hari sejak catatan terakhir (0 = hari ini).
  final int hariSejakCatatanTerakhir;

  /// Jumlah hari berurutan yang tercatat pada ujung terbaru rentang.
  final int hariBerturutAkhir;

  /// Rata-rata nilai harian (0,0–1,0) — angka pengukuran, bukan penilaian.
  final double rataNilai;

  bool get adaCatatan => hariTercatat > 0;

  /// Persentase hari tercatat (dibulatkan) — hanya pelaporan.
  int get persenTercatat =>
      rentangHari == 0 ? 0 : (hariTercatat * 100 / rentangHari).round();

  /// Kalimat siap tampil, netral dan tanpa menyalahkan.
  String get kalimat {
    if (rentangHari == 0) return 'Belum ada rentang yang dihitung.';
    if (!adaCatatan) {
      return 'Belum ada catatan pada $rentangHari hari terakhir. '
          'Menandai bisa dimulai kapan saja.';
    }
    final dasar = 'Tercatat $hariTercatat dari $rentangHari hari';
    // Catatan yang kembali setelah jeda disebut sebagai pemulihan — inilah inti
    // FR-81: yang dipandang adalah "sudah jalan lagi", bukan jeda sebelumnya.
    if (jedaTerpanjang > 0 && hariBerturutAkhir >= 2) {
      return '$dasar · catatan muncul kembali pada $hariBerturutAkhir hari '
          'terakhir.';
    }
    if (hariSejakCatatanTerakhir == 0) {
      return '$dasar · catatan terakhir hari ini.';
    }
    return '$dasar · catatan terakhir $hariSejakCatatanTerakhir hari lalu.';
  }
}

/// Hitung pemulihan dari deret nilai harian (lama → terbaru).
///
/// Hari tanpa catatan diwakili nilai 0 oleh pemanggil, jadi hitungannya apa
/// adanya.
NilaiPemulihan hitungPemulihan(List<double> nilaiHarian) {
  final panjang = nilaiHarian.length;
  if (panjang == 0) {
    return const NilaiPemulihan(
      rentangHari: 0,
      hariTercatat: 0,
      jedaTerpanjang: 0,
      hariSejakCatatanTerakhir: 0,
      hariBerturutAkhir: 0,
      rataNilai: 0,
    );
  }

  var tercatat = 0;
  var jumlah = 0.0;
  var jedaSekarang = 0;
  var jedaTerpanjang = 0;
  var sejakTerakhir = panjang; // dianggap belum pernah bila tidak ketemu
  for (var i = 0; i < panjang; i++) {
    final nilai = nilaiHarian[i];
    jumlah += nilai;
    if (nilai > 0) {
      tercatat++;
      sejakTerakhir = panjang - 1 - i;
      jedaSekarang = 0;
    } else {
      jedaSekarang++;
      if (jedaSekarang > jedaTerpanjang) jedaTerpanjang = jedaSekarang;
    }
  }

  var berturut = 0;
  for (var i = panjang - 1; i >= 0; i--) {
    if (nilaiHarian[i] > 0) {
      berturut++;
    } else {
      break;
    }
  }

  return NilaiPemulihan(
    rentangHari: panjang,
    hariTercatat: tercatat,
    jedaTerpanjang: jedaTerpanjang,
    hariSejakCatatanTerakhir: sejakTerakhir == panjang ? panjang : sejakTerakhir,
    hariBerturutAkhir: berturut,
    rataNilai: jumlah / panjang,
  );
}

/// Kalimat konsistensi satu rentang (FR-85) — netral, tanpa skor.
String kalimatKonsistensi(int hariTercatat, int rentangHari) {
  if (rentangHari <= 0) return 'Belum ada rentang yang dihitung.';
  if (hariTercatat == 0) {
    return 'Belum ada catatan pada $rentangHari hari terakhir.';
  }
  return 'Tercatat pada $hariTercatat dari $rentangHari hari terakhir.';
}

/// Berapa kebiasaan yang tercatat pada tiap hari (lama → terbaru).
///
/// Dipakai untuk grafik mingguan FR-85: yang digambar adalah "berapa yang
/// tercatat", bukan "seberapa bagus".
List<int> jumlahTercatatPerHari(
  Iterable<List<double>> deret, {
  required int rentangHari,
}) {
  final hasil = List<int>.filled(rentangHari, 0);
  for (final d in deret) {
    for (var i = 0; i < rentangHari && i < d.length; i++) {
      if (d[i] > 0) hasil[i] += 1;
    }
  }
  return hasil;
}
