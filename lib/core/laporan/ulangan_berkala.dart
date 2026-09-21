/// FR-121 — pengulangan berkala (spaced repetition), murni tanpa I/O.
///
/// Prinsip: jadwal ulangan dihitung dari JAWABAN pengguna, bukan dari penilaian
/// aplikasi. Kata "lupa" tidak dipakai sebagai hukuman — menjawab salah hanya
/// berarti kartunya kembali ke kotak pertama. Tidak ada kata terlarang PRD §III-11.
library;

/// Jarak ulangan per kotak (hari). Kotak 0 = baru.
const List<int> jarakKotakHari = <int>[1, 3, 7, 16, 35, 90, 180];

/// Kotak tertinggi yang punya jadwal sendiri.
int get kotakTertinggi => jarakKotakHari.length - 1;

/// Jarak ulangan (hari) untuk [kotak] (dijepit ke rentang yang dikenal).
int jarakHari(int kotak) {
  if (kotak < 0) return jarakKotakHari.first;
  if (kotak > kotakTertinggi) return jarakKotakHari.last;
  return jarakKotakHari[kotak];
}

/// Waktu ulangan berikutnya bila kartu [kotak] diulang pada [sekarang].
///
/// Hasilnya selalu awal hari (jam 00:00) + jarak hari, supaya jadwal tidak
/// bergeser karena jam pemakaian.
DateTime ulanganBerikut({required DateTime sekarang, required int kotak}) {
  final awal = DateTime(sekarang.year, sekarang.month, sekarang.day);
  return awal.add(Duration(days: jarakHari(kotak)));
}

/// Hasil satu kali menjawab kartu.
class HasilJawab {
  const HasilJawab({
    required this.kotakBaru,
    required this.ulanganBerikut,
    required this.jumlahBenarBaru,
    required this.benar,
  });

  final int kotakBaru;
  final DateTime ulanganBerikut;
  final int jumlahBenarBaru;
  final bool benar;
}

/// Hitung keadaan kartu setelah dijawab.
///
/// Benar → naik satu kotak (maksimum [kotakTertinggi]).
/// Belum tepat → kembali ke kotak 0 (mulai lagi dari jarak terpendek).
HasilJawab jawabKartu({
  required int kotak,
  required bool benar,
  required DateTime sekarang,
  int jumlahBenar = 0,
}) {
  final kotakBaru = benar ? (kotak + 1).clamp(0, kotakTertinggi) : 0;
  return HasilJawab(
    kotakBaru: kotakBaru,
    ulanganBerikut: ulanganBerikut(sekarang: sekarang, kotak: kotakBaru),
    jumlahBenarBaru: jumlahBenar + (benar ? 1 : 0),
    benar: benar,
  );
}

/// Satu kartu ulangan (dipotret dari penyimpanan).
class KartuUlanganRingkas {
  const KartuUlanganRingkas({
    required this.id,
    required this.pertanyaan,
    required this.ulanganBerikut,
    this.jawaban = '',
    this.topik,
    this.kotak = 0,
    this.jumlahDiulang = 0,
    this.jumlahBenar = 0,
  });

  final int id;
  final String pertanyaan;
  final String jawaban;
  final String? topik;
  final int kotak;
  final DateTime ulanganBerikut;
  final int jumlahDiulang;
  final int jumlahBenar;
}

/// Kartu yang sudah waktunya diulang ([acuan] sebagai hari ini), paling lama
/// menunggu lebih dulu.
List<KartuUlanganRingkas> kartuJatuhTempo(
  List<KartuUlanganRingkas> kartu, {
  required DateTime acuan,
}) {
  final batas = DateTime(acuan.year, acuan.month, acuan.day, 23, 59, 59);
  return kartu.where((k) => !k.ulanganBerikut.isAfter(batas)).toList()
    ..sort((a, b) => a.ulanganBerikut.compareTo(b.ulanganBerikut));
}

/// Ringkasan kumpulan kartu.
class RingkasUlangan {
  const RingkasUlangan({
    required this.total,
    required this.jatuhTempo,
    required this.baru,
    required this.kuat,
    required this.jumlahDiulang,
    required this.jumlahBenar,
    required this.perTopik,
  });

  final int total;
  final int jatuhTempo;
  final int baru;
  final int kuat;
  final int jumlahDiulang;
  final int jumlahBenar;
  final Map<String, int> perTopik;

  /// Bagian jawaban tepat dari seluruh ulangan (null bila belum pernah diulang).
  double? get bagianTepat =>
      jumlahDiulang == 0 ? null : jumlahBenar / jumlahDiulang;
}

RingkasUlangan ringkasUlangan(
  List<KartuUlanganRingkas> kartu, {
  required DateTime acuan,
}) {
  final perTopik = <String, int>{};
  var diulang = 0;
  var benar = 0;
  var baru = 0;
  var kuat = 0;
  for (final k in kartu) {
    final topik = (k.topik ?? '').trim();
    if (topik.isNotEmpty) {
      perTopik.update(topik, (v) => v + 1, ifAbsent: () => 1);
    }
    diulang += k.jumlahDiulang;
    benar += k.jumlahBenar;
    if (k.kotak == 0) baru++;
    if (k.kotak >= 5) kuat++;
  }
  return RingkasUlangan(
    total: kartu.length,
    jatuhTempo: kartuJatuhTempo(kartu, acuan: acuan).length,
    baru: baru,
    kuat: kuat,
    jumlahDiulang: diulang,
    jumlahBenar: benar,
    perTopik: perTopik,
  );
}

/// Nama keadaan kotak untuk ditampilkan (tanpa penilaian).
String labelKotak(int kotak) {
  if (kotak <= 0) return 'baru';
  final hari = jarakHari(kotak);
  return 'ulangan tiap $hari hari';
}
