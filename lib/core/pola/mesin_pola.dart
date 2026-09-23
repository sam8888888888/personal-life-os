/// SDD v19 Gelombang 3 — Mesin korelasi (mesin pola).
///
/// Berkas ini **murni hitungan**: tanpa Flutter, tanpa basis data. Karena itu
/// seluruh disiplin statistik di bawah bisa diuji tanpa HP.
///
/// Disiplin yang dipegang (SDD §4.11, bagian yang disebut dokumen sebagai
/// "BAGIAN TERPENTING DARI SELURUH DOKUMEN"):
///
/// 1. **Ambang sampel minimum 14 pasangan.** Di bawah itu temuan TIDAK BOLEH
///    ditampilkan — menampilkan "pola" dari 4 titik data adalah cara tercepat
///    membuat aplikasi terasa menipu.
/// 2. **n selalu ditampilkan** ke pengguna, bukan disembunyikan.
/// 3. **Bahasa**: selalu "pola terlihat di catatan Anda", tidak pernah
///    diagnosis. Kalimat temuan dari mesin diperiksa dulu oleh
///    [bahasaTerlarang] sebelum disimpan.
/// 4. **Spearman, bukan Pearson.** Data kesehatan & suasana hati sering
///    ordinal (skala 1–5) dan tidak normal.
/// 5. **Koreksi perbandingan berganda.** Menguji banyak pasangan sekaligus
///    menghasilkan temuan palsu bila tidak dikoreksi — di sini dipakai
///    Benjamini–Hochberg (kendali laju temuan palsu). Sudah tersedia juga
///    [koreksiBonferroni] bila ingin lebih ketat.
///
/// Catatan kejujuran soal nilai-p: p dihitung dengan **uji permutasi** (bukan
/// rumus t-approksimasi). Alasannya: Spearman pada data ordinal tidak
/// memenuhi asumsi normal, sedangkan permutasi tidak menuntut asumsi apa pun.
/// Uji permutasi memakai benih tetap sehingga hasilnya **sama setiap kali**
/// (bisa diulang & diuji).
library;

import 'dart:math';

/// Jumlah pasangan minimum sebelum sebuah pola boleh ditampilkan.
const int ambangSampelMinimum = 14;

/// Kata/frasa yang DILARANG muncul di kalimat temuan (PRD §III-11).
///
/// Daftar ini sengaja mengikuti dokumen apa adanya: klaim tentang orangnya
/// ("anda mengalami", "anda menderita"), klaim sebab-akibat ("penyebab",
/// "karena anda", "menyebabkan"), dan klaim penyakit milik pengguna.
const List<String> frasaTerlarang = <String>[
  'anda mengalami',
  'anda menderita',
  'penyebab',
  'karena anda',
  'menyebabkan',
  'penyakit anda',
];

/// Sanggahan yang justru WAJIB ada di kalimat aplikasi.
///
/// Kalimat "…bukan diagnosis" memuat kata "diagnosis", jadi tanpa pengecualian
/// ini penjaga bahasa akan menuduh kalimat jujur aplikasi sendiri sebagai
/// pelanggaran — kesalahan nyata yang pernah terjadi di gelombang 3.
const List<String> frasaDikecualikan = <String>[
  'bukan diagnosis',
  'pola dari catatan anda',
  'pola terlihat di catatan anda',
];

/// Kata/frasa yang menandakan kalimat pola yang jujur.
const List<String> frasaDianjurkan = <String>[
  'pola terlihat',
  'cenderung',
  'di catatan anda',
  'sejalan dengan',
  'n = ',
];

/// Apakah [teks] memuat bahasa terlarang (jika ya, temuan tidak boleh disimpan).
///
/// Sanggahan yang ditulis aplikasi sendiri ([frasaDikecualikan]) dibuang dulu,
/// supaya kalimat "…bukan diagnosis" tidak dianggap pelanggaran.
bool bahasaTerlarang(String teks) {
  String t = teks.toLowerCase();
  for (final String k in frasaDikecualikan) {
    t = t.replaceAll(k, ' ');
  }
  for (final String f in frasaTerlarang) {
    if (t.contains(f)) return true;
  }
  return false;
}

/// Satu titik data berpasangan: nilai X dan nilai Y pada hari yang sama.
class TitikPola {
  const TitikPola({required this.tanggal, required this.x, required this.y});

  final DateTime tanggal;
  final double x;
  final double y;
}

/// Hasil satu uji pasangan.
class HasilUjiPola {
  const HasilUjiPola({
    required this.kode,
    required this.judul,
    required this.kekuatan,
    required this.ukuranSampel,
    required this.nilaiP,
    required this.rentangMulai,
    required this.rentangSelesai,
    required this.bahasa,
  });

  final String kode;
  final String judul;

  /// Koefisien Spearman (−1…+1). Tandanya menentukan arah.
  final double kekuatan;

  /// n — jumlah pasangan yang benar-benar dipakai.
  final int ukuranSampel;

  /// Nilai-p (sudah dikoreksi bila [MesinPola.hitung] diminta mengoreksi).
  final double nilaiP;

  final DateTime rentangMulai;
  final DateTime rentangSelesai;

  /// Kalimat pola siap tampil (sudah lolos pemeriksaan bahasa).
  final String bahasa;

  /// Apakah arah hubungannya positif.
  bool get searah => kekuatan > 0;

  /// Kekuatan absolut — dipakai untuk mengurutkan.
  double get kekuatanAbs => kekuatan.abs();

  /// Apakah temuan ini memenuhi ambang sampel.
  bool get layakTampil => ukuranSampel >= ambangSampelMinimum;
}

/// Mesin pola: hitung korelasi Spearman + nilai-p permutasi + koreksi ganda.
abstract final class MesinPola {
  /// Benih tetap supaya hasil uji permutasi bisa diulang persis.
  static const int benihPermutasi = 20260923;

  /// Jumlah pengacakan pada uji permutasi.
  static const int ulanganPermutasi = 2000;

  /// Peringkat dengan penanganan nilai kembar (rata-rata peringkat).
  ///
  /// Inilah bedanya Spearman dari Pearson: yang dibandingkan adalah URUTAN,
  /// bukan nilai mentahnya.
  static List<double> peringkat(List<double> nilai) {
    final int n = nilai.length;
    final List<int> indeks = List<int>.generate(n, (int i) => i)
      ..sort((int a, int b) => nilai[a].compareTo(nilai[b]));
    final List<double> hasil = List<double>.filled(n, 0);
    int i = 0;
    while (i < n) {
      int j = i;
      while (j + 1 < n && nilai[indeks[j + 1]] == nilai[indeks[i]]) {
        j++;
      }
      // Peringkat rata-rata untuk kelompok nilai yang sama.
      final double rata = (i + j) / 2 + 1;
      for (int k = i; k <= j; k++) {
        hasil[indeks[k]] = rata;
      }
      i = j + 1;
    }
    return hasil;
  }

  /// Koefisien korelasi Spearman. Mengembalikan null bila tidak bisa dihitung
  /// (data kurang dari 3 pasangan, atau salah satu sisi tidak bervariasi).
  static double? spearman(List<double> xs, List<double> ys) {
    if (xs.length != ys.length || xs.length < 3) return null;
    final List<double> rx = peringkat(xs);
    final List<double> ry = peringkat(ys);
    final double rataX = rx.reduce((double a, double b) => a + b) / rx.length;
    final double rataY = ry.reduce((double a, double b) => a + b) / ry.length;
    double atas = 0;
    double bawahX = 0;
    double bawahY = 0;
    for (int i = 0; i < rx.length; i++) {
      final double dx = rx[i] - rataX;
      final double dy = ry[i] - rataY;
      atas += dx * dy;
      bawahX += dx * dx;
      bawahY += dy * dy;
    }
    if (bawahX == 0 || bawahY == 0) return null;
    final double r = atas / sqrt(bawahX * bawahY);
    // Jepit ke −1…+1 (galat pembulatan titik mengambang).
    return r.clamp(-1.0, 1.0);
  }

  /// Nilai-p dua sisi lewat uji permutasi (benih tetap → hasil bisa diulang).
  static double nilaiPermutasi(
    List<double> xs,
    List<double> ys, {
    double? kekuatanTeramati,
    int ulangan = ulanganPermutasi,
    int benih = benihPermutasi,
  }) {
    final double? teramati = kekuatanTeramati ?? spearman(xs, ys);
    if (teramati == null) return 1;
    final Random acak = Random(benih);
    final double ambang = teramati.abs();
    int ekstrem = 0;
    for (int u = 0; u < ulangan; u++) {
      final List<double> campur = List<double>.of(xs)..shuffle(acak);
      final double? r = spearman(campur, ys);
      if (r != null && r.abs() >= ambang) ekstrem++;
    }
    // (+1) supaya nilai-p tidak pernah 0 — pola dari 14 titik tetap bukan bukti.
    return (ekstrem + 1) / (ulangan + 1);
  }

  /// Koreksi Bonferroni: p × jumlah uji, dipotong di 1.
  static double koreksiBonferroni(double p, int jumlahUji) {
    if (jumlahUji < 1) return p;
    return (p * jumlahUji).clamp(0.0, 1.0);
  }

  /// Koreksi Benjamini–Hochberg (kendali laju temuan palsu).
  ///
  /// Mengembalikan nilai-p terkoreksi dengan urutan yang SAMA seperti input.
  static List<double> koreksiBenjaminiHochberg(List<double> nilaiP) {
    final int m = nilaiP.length;
    if (m == 0) return <double>[];
    final List<int> urut = List<int>.generate(m, (int i) => i)
      ..sort((int a, int b) => nilaiP[a].compareTo(nilaiP[b]));
    final List<double> hasil = List<double>.filled(m, 1);
    double sebelumnya = 1;
    for (int i = m - 1; i >= 0; i--) {
      final int k = urut[i];
      final double calon = nilaiP[k] * m / (i + 1);
      // Langkah menurun: pastikan nilai terkoreksi tidak turun saat p menaik.
      sebelumnya = calon < sebelumnya ? calon : sebelumnya;
      hasil[k] = sebelumnya.clamp(0.0, 1.0);
    }
    return hasil;
  }

  /// Rangkai kalimat pola yang jujur untuk satu pasangan.
  ///
  /// Kalimatnya selalu memuat n, selalu menyebut "catatan Anda", dan tidak
  /// pernah menyatakan sebab-akibat.
  static String kalimatPola({
    required String sisiX,
    required String sisiY,
    required double kekuatan,
    required int ukuranSampel,
    String? satuanX,
    String? satuanY,
  }) {
    final String arah = kekuatan > 0
        ? 'cenderung naik bersamaan'
        : 'cenderung turun saat yang lain naik';
    final String kuat = kekuatan.abs() >= 0.5
        ? 'cukup kuat'
        : (kekuatan.abs() >= 0.3 ? 'sedang' : 'lemah');
    return 'Pola terlihat di catatan Anda (n = $ukuranSampel): '
        '$sisiX dan $sisiY $arah. Hubungannya $kuat '
        '(Spearman ${kekuatan.toStringAsFixed(2)}). '
        'Ini pola dari catatan Anda, bukan diagnosis.';
  }

  /// Uji sekumpulan kandidat pasangan, lalu kembalikan yang layak tampil.
  ///
  /// [kandidat] berisi pasangan (kode, judul, titik, nama sisi). Yang dikerjakan:
  /// 1. buang pasangan dengan n < [ambangSampelMinimum];
  /// 2. hitung Spearman + nilai-p permutasi;
  /// 3. koreksi Benjamini–Hochberg atas SELURUH pasangan yang diuji;
  /// 4. buang kalimat yang memuat bahasa terlarang (tidak boleh lolos).
  static List<HasilUjiPola> hitung(
    List<KandidatPola> kandidat, {
    bool koreksiGanda = true,
  }) {
    final List<KandidatPola> layak = kandidat
        .where((KandidatPola k) => k.titik.length >= ambangSampelMinimum)
        .toList();
    if (layak.isEmpty) return <HasilUjiPola>[];

    final List<double?> kekuatan = <double?>[];
    final List<double> nilaiP = <double>[];
    for (final KandidatPola k in layak) {
      final List<double> xs =
          k.titik.map((TitikPola t) => t.x).toList(growable: false);
      final List<double> ys =
          k.titik.map((TitikPola t) => t.y).toList(growable: false);
      final double? r = spearman(xs, ys);
      kekuatan.add(r);
      nilaiP.add(r == null ? 1 : nilaiPermutasi(xs, ys, kekuatanTeramati: r));
    }

    final List<double> nilaiPKoreksi =
        koreksiGanda ? koreksiBenjaminiHochberg(nilaiP) : nilaiP;

    final List<HasilUjiPola> hasil = <HasilUjiPola>[];
    for (int i = 0; i < layak.length; i++) {
      final KandidatPola k = layak[i];
      final double? r = kekuatan[i];
      if (r == null) continue; // salah satu sisi tidak bervariasi
      final List<DateTime> tanggal =
          k.titik.map((TitikPola t) => t.tanggal).toList()..sort();
      final String bahasa = kalimatPola(
        sisiX: k.sisiX,
        sisiY: k.sisiY,
        kekuatan: r,
        ukuranSampel: k.titik.length,
      );
      if (bahasaTerlarang(bahasa)) continue; // penjaga terakhir sebelum simpan
      hasil.add(HasilUjiPola(
        kode: k.kode,
        judul: k.judul,
        kekuatan: r,
        ukuranSampel: k.titik.length,
        nilaiP: nilaiPKoreksi[i],
        rentangMulai: tanggal.first,
        rentangSelesai: tanggal.last,
        bahasa: bahasa,
      ));
    }
    hasil.sort((HasilUjiPola a, HasilUjiPola b) =>
        b.kekuatanAbs.compareTo(a.kekuatanAbs));
    return hasil;
  }
}

/// Bahan satu kandidat pola: pasangan titik data + nama kedua sisinya.
class KandidatPola {
  const KandidatPola({
    required this.kode,
    required this.judul,
    required this.sisiX,
    required this.sisiY,
    required this.titik,
  });

  final String kode;
  final String judul;
  final String sisiX;
  final String sisiY;
  final List<TitikPola> titik;
}
