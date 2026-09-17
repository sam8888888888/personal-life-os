/// Peristiwa keuangan bulanan - FR-73. **PURE Dart**: tanpa Flutter dan tanpa
/// Drift, jadi mudah diuji dan tidak menarik lapisan tampilan atau basis data.
///
/// Satu [PeristiwaKeuangan] = satu kejadian uang pada satu tanggal: tagihan
/// yang perlu dibayar, langganan berulang, angsuran utang, pengeluaran yang
/// direncanakan, masa berlaku dokumen, transaksi yang sudah terjadi, atau
/// jatuh tempo yang sudah lewat.
///
/// **Arah uang diwakili tanda [nominalSen]:**
/// * positif = uang masuk,
/// * negatif = uang keluar,
/// * nol = tidak ada nominal (mis. masa berlaku dokumen).
///
/// Dengan begitu [ringkasBulan] dapat memisahkan total masuk dan total keluar
/// tanpa kolom tambahan.
library;

/// Jenis peristiwa keuangan pada kalender (FR-73).
///
/// [jatuhTempoTerlewat] dipakai untuk kejadian yang tanggalnya sudah lewat
/// tetapi belum terjadi/tuntas. Label dipakai sebagai keterangan warna di layar.
enum JenisPeristiwa {
  tagihan('Tagihan'),
  langganan('Langganan'),
  angsuran('Angsuran'),
  pengeluaranTerencana('Pengeluaran terencana'),
  dokumen('Dokumen'),
  transaksi('Transaksi'),
  jatuhTempoTerlewat('Jatuh tempo terlewat');

  const JenisPeristiwa(this.label);

  /// Nama jenis yang ditampilkan ke pengguna (tanpa penilaian).
  final String label;
}

/// Satu kejadian uang pada satu tanggal.
class PeristiwaKeuangan {
  const PeristiwaKeuangan({
    required this.tanggal,
    required this.judul,
    required this.nominalSen,
    required this.jenis,
    this.sudahTerjadi = false,
    this.rujukan,
  });

  /// Tanggal kejadian; bagian jam diabaikan (selalu pukul 00:00 hari itu).
  final DateTime tanggal;

  /// Judul yang dibaca pengguna, mis. "Tagihan: Listrik PLN".
  final String judul;

  /// Nominal bertanda dalam sen (lihat catatan di kepala berkas).
  final int nominalSen;

  /// Jenis peristiwa; menentukan warna penanda di kalender.
  final JenisPeristiwa jenis;

  /// true = kejadiannya sudah tercatat (mis. transaksi nyata), bukan rencana.
  final bool sudahTerjadi;

  /// Penunjuk sumber asli, mis. "tagihan:12" atau "terencana:3".
  /// Berguna untuk menelusuri asal baris tanpa membawa objek basis data.
  final String? rujukan;

  /// true = uang masuk pada tanggal ini.
  bool get uangMasuk => nominalSen > 0;

  /// true = uang keluar pada tanggal ini.
  bool get uangKeluar => nominalSen < 0;

  /// Nominal tanpa tanda - untuk ditampilkan.
  int get nominalAbsSen => nominalSen < 0 ? -nominalSen : nominalSen;

  /// Salinan dengan jenis [JenisPeristiwa.jatuhTempoTerlewat].
  ///
  /// Aturan "sudah lewat" tinggal di satu tempat (repositori) yang mengenal
  /// jam acuan; berkas murni ini hanya menyediakan bentuk salinannya.
  PeristiwaKeuangan sebagaiTerlewat() => PeristiwaKeuangan(
        tanggal: tanggal,
        judul: judul,
        nominalSen: nominalSen,
        jenis: JenisPeristiwa.jatuhTempoTerlewat,
        sudahTerjadi: sudahTerjadi,
        rujukan: rujukan,
      );

  @override
  String toString() =>
      'PeristiwaKeuangan(${kunciTanggal(tanggal)}, ${jenis.name}, '
      '$nominalSen, "$judul")';
}

/// Buang bagian jam: 2026-09-15 14:30 -> 2026-09-15 00:00 (fungsi murni).
DateTime hariSaja(DateTime t) => DateTime(t.year, t.month, t.day);

/// Kunci tanggal `yyyy-mm-dd` - dipakai sebagai kunci widget `sel_<kunci>`.
String kunciTanggal(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

/// true = dua waktu jatuh pada hari kalender yang sama.
bool samaHari(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// true = [tanggal] berada di bulan [bulan]/[tahun].
///
/// Selalu dibandingkan setelah jam dibuang, supaya baris bertanda pukul 00:00
/// maupun 23:59 tidak pernah terlewat.
bool diBulan(DateTime tanggal, int tahun, int bulan) =>
    tanggal.year == tahun && tanggal.month == bulan;

/// Urutan tetap antar jenis (kunci urut kedua setelah tanggal).
const Map<JenisPeristiwa, int> _urutanJenis = <JenisPeristiwa, int>{
  JenisPeristiwa.tagihan: 0,
  JenisPeristiwa.angsuran: 1,
  JenisPeristiwa.langganan: 2,
  JenisPeristiwa.pengeluaranTerencana: 3,
  JenisPeristiwa.jatuhTempoTerlewat: 4,
  JenisPeristiwa.dokumen: 5,
  JenisPeristiwa.transaksi: 6,
};

/// Urut peristiwa: tanggal menaik, lalu jenis, lalu judul (stabil & tetap).
///
/// Mengembalikan daftar baru; daftar masukan tidak diubah.
List<PeristiwaKeuangan> urutPeristiwa(
  Iterable<PeristiwaKeuangan> daftar,
) {
  final salinan = List<PeristiwaKeuangan>.of(daftar);
  salinan.sort((a, b) {
    final t = hariSaja(a.tanggal).compareTo(hariSaja(b.tanggal));
    if (t != 0) return t;
    final j = (_urutanJenis[a.jenis] ?? 99).compareTo(_urutanJenis[b.jenis] ?? 99);
    if (j != 0) return j;
    return a.judul.compareTo(b.judul);
  });
  return salinan;
}

/// Kelompokkan peristiwa per tanggal (kunci selalu pukul 00:00).
///
/// Urutan kunci mengikuti urutan tanggal menaik, dan isi tiap tanggal juga
/// urut (lihat [urutPeristiwa]) - jadi tampilan tidak berubah-ubah.
Map<DateTime, List<PeristiwaKeuangan>> kelompokPerTanggal(
  Iterable<PeristiwaKeuangan> daftar,
) {
  final hasil = <DateTime, List<PeristiwaKeuangan>>{};
  for (final p in urutPeristiwa(daftar)) {
    hasil.putIfAbsent(hariSaja(p.tanggal), () => <PeristiwaKeuangan>[]).add(p);
  }
  return hasil;
}

/// Angka ringkas satu bulan kalender.
class RingkasanKalenderKeuangan {
  const RingkasanKalenderKeuangan({
    required this.tahun,
    required this.bulan,
    required this.totalMasukSen,
    required this.totalKeluarSen,
    required this.totalTerlewatSen,
    required this.jumlahPeristiwa,
    required this.jumlahTerlewat,
  });

  final int tahun;
  final int bulan;

  /// Jumlah seluruh peristiwa uang masuk (sen).
  final int totalMasukSen;

  /// Jumlah seluruh peristiwa uang keluar (sen), **termasuk** yang sudah
  /// lewat - uangnya tetap perlu keluar, jadi tidak dipisahkan dari total.
  final int totalKeluarSen;

  /// Bagian dari [totalKeluarSen] yang tanggalnya sudah lewat dan belum
  /// terjadi/tuntas (jenis [JenisPeristiwa.jatuhTempoTerlewat]).
  final int totalTerlewatSen;

  final int jumlahPeristiwa;
  final int jumlahTerlewat;

  /// true = tidak ada peristiwa pada bulan itu (layar menulis "Belum ada data").
  bool get kosong => jumlahPeristiwa == 0;

  /// Arus bersih bulan itu (masuk - keluar).
  int get bersihSen => totalMasukSen - totalKeluarSen;
}

/// Ringkasan satu bulan: total masuk, total keluar, dan total yang terlewat.
///
/// Hanya peristiwa di bulan [bulan]/[tahun] yang dihitung; peristiwa bulan
/// lain diabaikan (tidak melempar galat), supaya daftar bulan apa pun aman
/// diberikan ke fungsi ini.
RingkasanKalenderKeuangan ringkasBulan(
  Iterable<PeristiwaKeuangan> daftar,
  int bulan,
  int tahun,
) {
  var masuk = 0;
  var keluar = 0;
  var terlewat = 0;
  var jumlah = 0;
  var jumlahTerlewat = 0;
  for (final p in daftar) {
    if (!diBulan(p.tanggal, tahun, bulan)) continue;
    jumlah += 1;
    if (p.nominalSen > 0) {
      masuk += p.nominalSen;
    } else if (p.nominalSen < 0) {
      keluar += -p.nominalSen;
    }
    if (p.jenis == JenisPeristiwa.jatuhTempoTerlewat) {
      terlewat += p.nominalAbsSen;
      jumlahTerlewat += 1;
    }
  }
  return RingkasanKalenderKeuangan(
    tahun: tahun,
    bulan: bulan,
    totalMasukSen: masuk,
    totalKeluarSen: keluar,
    totalTerlewatSen: terlewat,
    jumlahPeristiwa: jumlah,
    jumlahTerlewat: jumlahTerlewat,
  );
}
