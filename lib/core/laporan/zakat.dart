/// FR-96 — Zakat & sedekah: logika murni (alat bantu hitung, bukan keputusan).
///
/// **Prinsip.** Aplikasi menampilkan **asumsi** yang dipakai (nisab 85 gram
/// emas, harga emas yang diisi pengguna + tanggalnya, tarif 2,5 %, haul 354
/// hari). Tidak ada harga emas yang diambil sendiri dari internet, dan hasilnya
/// selalu disebut sebagai alat bantu — keputusan akhir tetap milik pengguna
/// (boleh dikonsultasikan ke amil/ulama).
library;

import '../../data/database/database.dart';

/// Nisab zakat maal menurut acuan emas (gram).
const int gramNisabEmas = 85;

/// Tarif zakat maal (2,5 %).
const double tarifZakatMaal = 0.025;

/// Satu tahun hijriah (hari) untuk pelacakan haul.
const int hariHaulHijriah = 354;

/// Berat beras untuk zakat fitrah per jiwa (kg) — acuan umum 2,5 kg.
const double kgFitrahPerJiwa = 2.5;

/// Hasil perhitungan zakat maal.
class HasilZakat {
  const HasilZakat({
    required this.nisabSen,
    required this.hartaBersihSen,
    required this.zakatSen,
    required this.wajibZakat,
    required this.sudahHaul,
    required this.hariMenujuHaul,
    required this.asumsi,
  });

  final int nisabSen;
  final int hartaBersihSen;
  final int zakatSen;
  final bool wajibZakat;
  final bool sudahHaul;
  final int? hariMenujuHaul;
  final List<String> asumsi;
}

/// Hitung zakat maal dari data yang diisi pengguna.
///
/// * [hartaSen] — total harta yang dizakati (kas, tabungan, emas, investasi,
///   piutang) dalam sen rupiah.
/// * [utangSen] — utang jatuh tempo dalam sen rupiah (dikurangkan).
/// * [hargaEmasPerGramSen] — harga emas per gram menurut pengguna (sen).
/// * [mulaiHaul] — tanggal harta pertama kali mencapai nisab (opsional).
HasilZakat hitungZakat({
  required int hartaSen,
  required int utangSen,
  required int hargaEmasPerGramSen,
  DateTime? mulaiHaul,
  DateTime? sekarang,
  int gramNisab = gramNisabEmas,
}) {
  final nisab = hargaEmasPerGramSen * gramNisab;
  final bersih = hartaSen - utangSen;
  final hartaBersih = bersih < 0 ? 0 : bersih;
  final mencapaiNisab = hargaEmasPerGramSen > 0 && hartaBersih >= nisab;

  var sudahHaul = false;
  int? sisaHari;
  if (mulaiHaul != null && sekarang != null) {
    final lewat = sekarang.difference(mulaiHaul).inDays;
    sudahHaul = lewat >= hariHaulHijriah;
    sisaHari = sudahHaul ? 0 : hariHaulHijriah - lewat;
  }

  final wajib = mencapaiNisab && (mulaiHaul == null ? false : sudahHaul);
  final zakat = wajib ? (hartaBersih * tarifZakatMaal).round() : 0;

  final asumsi = <String>[
    'Nisab memakai acuan $gramNisab gram emas '
        '(${_rupiah(hargaEmasPerGramSen)} per gram).',
    if (hargaEmasPerGramSen <= 0)
      'Harga emas belum diisi, jadi nisab belum bisa dihitung.',
    'Zakat dihitung ${(tarifZakatMaal * 100).toStringAsFixed(1).replaceAll('.', ',')}% dari harta bersih '
        '(harta − utang jatuh tempo).',
    'Haul dipakai $hariHaulHijriah hari (satu tahun hijriah).',
    if (mulaiHaul == null)
      'Tanggal mulai haul belum diisi, jadi kewajiban zakat belum bisa dipastikan.',
    'Perhitungan ini alat bantu, bukan keputusan. Silakan dikonsultasikan ke '
        'amil atau ulama setempat.',
  ];

  return HasilZakat(
    nisabSen: nisab,
    hartaBersihSen: hartaBersih,
    zakatSen: zakat,
    wajibZakat: wajib,
    sudahHaul: sudahHaul,
    hariMenujuHaul: sisaHari,
    asumsi: asumsi,
  );
}

/// Hasil perhitungan zakat fitrah.
class HasilFitrah {
  const HasilFitrah({
    required this.jiwa,
    required this.kgBeras,
    required this.uangSen,
    required this.asumsi,
  });

  final int jiwa;
  final double kgBeras;
  final int? uangSen;
  final List<String> asumsi;
}

/// Hitung zakat fitrah: [jiwa] × 2,5 kg beras; uang diisi bila harga beras
/// per kg dimasukkan pengguna.
HasilFitrah hitungFitrah({
  required int jiwa,
  int? hargaBerasPerKgSen,
  double kgPerJiwa = kgFitrahPerJiwa,
}) {
  final aman = jiwa < 0 ? 0 : jiwa;
  final kg = aman * kgPerJiwa;
  final uang = hargaBerasPerKgSen == null || hargaBerasPerKgSen <= 0
      ? null
      : (kg * hargaBerasPerKgSen).round();
  return HasilFitrah(
    jiwa: aman,
    kgBeras: kg,
    uangSen: uang,
    asumsi: [
      'Acuan $kgPerJiwa kg beras per jiwa (boleh disesuaikan dengan kebiasaan '
          'setempat).',
      if (uang == null)
        'Harga beras belum diisi, jadi nilainya hanya dalam kilogram.'
      else
        'Nilai uang memakai harga beras ${_rupiah(hargaBerasPerKgSen!)} per kg '
            'yang diisi sendiri oleh pengguna.',
      'Perhitungan ini alat bantu, bukan keputusan.',
    ],
  );
}

/// Rekap catatan infaq/sedekah: total bulan ini & tahun ini.
class RingkasSedekah {
  const RingkasSedekah({
    required this.totalBulanIniSen,
    required this.totalTahunIniSen,
    required this.jumlahCatatan,
    required this.perJenis,
  });

  final int totalBulanIniSen;
  final int totalTahunIniSen;
  final int jumlahCatatan;
  final Map<String, int> perJenis;
}

RingkasSedekah ringkasSedekah(List<ZakatSedekahData> daftar, DateTime sekarang) {
  var bulan = 0;
  var tahun = 0;
  final perJenis = <String, int>{};
  for (final d in daftar) {
    perJenis.update(d.jenis, (v) => v + d.jumlahSen, ifAbsent: () => d.jumlahSen);
    if (d.tanggal.year == sekarang.year) {
      tahun += d.jumlahSen;
      if (d.tanggal.month == sekarang.month) bulan += d.jumlahSen;
    }
  }
  return RingkasSedekah(
    totalBulanIniSen: bulan,
    totalTahunIniSen: tahun,
    jumlahCatatan: daftar.length,
    perJenis: perJenis,
  );
}

/// Jenis catatan zakat/sedekah (urutan tampil).
const List<({String nilaiDb, String label})> jenisZakatSedekah = [
  (nilaiDb: 'zakat_maal', label: 'Zakat maal'),
  (nilaiDb: 'zakat_fitrah', label: 'Zakat fitrah'),
  (nilaiDb: 'infaq', label: 'Infaq'),
  (nilaiDb: 'sedekah', label: 'Sedekah'),
  (nilaiDb: 'wakaf', label: 'Wakaf'),
];

String labelJenisZakat(String nilaiDb) {
  for (final j in jenisZakatSedekah) {
    if (j.nilaiDb == nilaiDb) return j.label;
  }
  return nilaiDb;
}

/// Format rupiah ringkas tanpa locale (aman untuk notifikasi/laporan).
String _rupiah(int sen) {
  final rupiah = (sen / 100).round();
  final teks = rupiah.toString();
  final buf = StringBuffer();
  for (var i = 0; i < teks.length; i++) {
    if (i > 0 && (teks.length - i) % 3 == 0) buf.write('.');
    buf.write(teks[i]);
  }
  return 'Rp ${buf.toString()}';
}
