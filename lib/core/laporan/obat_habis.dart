/// FR-107 — Perkiraan obat habis & pengingat membeli.
///
/// **Cara menghitung.** Dosis per hari = jumlah per minum × jumlah jam minum
/// yang aktif. Sisa hari = sisa ÷ dosis per hari. Perkiraan tanggal habis =
/// hari ini + sisa hari. Semua angka berasal dari data pengguna; aplikasi tidak
/// menebak apa pun.
///
/// **Kapan mengingatkan.** Sesuai PRD: H-5 dan H-1 sebelum habis (juga saat
/// sudah habis). Kalau sisa belum diisi, aplikasi **tidak** mengingatkan —
/// mengingatkan tanpa data hanya bikin bingung.
library;

/// Dosis per hari dari data obat (0 bila jadwalnya belum ada/tidak aktif).
int dosisPerHari(int jumlahPerMinum, int jumlahJadwalAktif) {
  if (jumlahPerMinum <= 0 || jumlahJadwalAktif <= 0) return 0;
  return jumlahPerMinum * jumlahJadwalAktif;
}

/// Sisa hari pemakaian (dibulatkan ke bawah). null bila datanya belum lengkap.
int? sisaHari({required int? sisa, required int dosisPerHari}) {
  if (sisa == null) return null;
  if (dosisPerHari <= 0) return null;
  if (sisa <= 0) return 0;
  return sisa ~/ dosisPerHari;
}

/// Perkiraan tanggal obat habis (tengah malam hari ke-`sisaHari`).
DateTime? perkiraanHabis({
  required int? sisa,
  required int dosisPerHari,
  required DateTime dari,
}) {
  final hari = sisaHari(sisa: sisa, dosisPerHari: dosisPerHari);
  if (hari == null) return null;
  final dasar = DateTime(dari.year, dari.month, dari.day);
  return dasar.add(Duration(days: hari));
}

/// Kode keadaan sisa obat.
///
/// * `belum_diisi` — sisa belum dicatat (tidak diingatkan)
/// * `tanpa_jadwal` — jadwal minum belum ada, jadi tidak bisa dihitung
/// * `habis` — sisa 0 atau kurang
/// * `kritis` — sisa ≤ 1 hari
/// * `peringatan` — sisa ≤ 5 hari
/// * `aman`
String kodeSisa({required int? sisa, required int dosisPerHari}) {
  if (sisa == null) return 'belum_diisi';
  if (dosisPerHari <= 0) return 'tanpa_jadwal';
  if (sisa <= 0) return 'habis';
  final hari = sisaHari(sisa: sisa, dosisPerHari: dosisPerHari) ?? 0;
  if (hari <= 1) return 'kritis';
  if (hari <= 5) return 'peringatan';
  return 'aman';
}

/// Hari-hari yang memicu pengingat membeli (sesuai PRD).
const List<int> hariDiingatkan = [5, 1];

/// Apakah sisa obat ini perlu diingatkan pada hari [sisaHariIni]?
///
/// Hanya H-5 dan H-1 (plus saat sudah habis) — bukan tiap hari, supaya
/// pengingatnya tidak jadi kebisingan.
bool perluDiingatkan(int sisaHariIni) =>
    hariDiingatkan.contains(sisaHariIni) || sisaHariIni <= 0;

/// Kalimat keadaan sisa obat — menyebut angka apa adanya, tidak menegur.
String kalimatSisa({
  required String namaObat,
  required int? sisa,
  required int dosisPerHari,
  required String satuan,
  required DateTime sekarang,
}) {
  final kode = kodeSisa(sisa: sisa, dosisPerHari: dosisPerHari);
  switch (kode) {
    case 'belum_diisi':
      return 'Sisa $namaObat belum dicatat. Isi sisanya supaya perkiraan habis '
          'bisa dihitung.';
    case 'tanpa_jadwal':
      return 'Jadwal minum $namaObat belum diatur, jadi perkiraan habis belum '
          'bisa dihitung.';
    case 'habis':
      return 'Sisa $namaObat sudah habis (0 $satuan).';
  }
  final hari = sisaHari(sisa: sisa, dosisPerHari: dosisPerHari) ?? 0;
  final tanggal = perkiraanHabis(sisa: sisa, dosisPerHari: dosisPerHari, dari: sekarang);
  final kapan = tanggal == null ? '' : ' (perkiraan habis ${_tanggalAman(tanggal)})';
  if (kode == 'kritis') {
    return 'Sisa $namaObat ${sisa ?? 0} $satuan — cukup untuk sekitar $hari hari$kapan.';
  }
  if (kode == 'peringatan') {
    return 'Sisa $namaObat ${sisa ?? 0} $satuan — cukup untuk sekitar $hari hari$kapan.';
  }
  return 'Sisa $namaObat ${sisa ?? 0} $satuan — cukup untuk sekitar $hari hari$kapan.';
}

/// Tanggal tanpa data locale (aman dipakai di isolate latar).
String _tanggalAman(DateTime t) {
  const bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${t.day} ${bulan[t.month - 1]} ${t.year}';
}

/// Tanggal aman untuk dipakai modul notifikasi (tanpa locale).
String tanggalAmanObat(DateTime t) => _tanggalAman(t);
