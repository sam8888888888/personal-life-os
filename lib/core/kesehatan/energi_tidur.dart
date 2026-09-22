/// FR-84 — Sleep & Energy OS (bagian hitungan).
///
/// Kriteria terima PRD: "Setelah ≥14 hari data, aplikasi menampilkan jam
/// produktif pribadi (mis. '08.00–11.00') **beserta dasar datanya**".
///
/// Jam produktif di sini BUKAN karangan aplikasi: ia hanya dihitung dari jam
/// yang Papi sendiri catat sebagai jam paling produktif pada hari itu. Bila
/// catatan itu belum cukup, jam produktif tidak ditampilkan dan alasannya
/// dikembalikan apa adanya.
library;

/// Satu hari catatan (dari tabel `tidur` + kolom energi/fokus/jam produktif).
class CatatanEnergiHari {
  const CatatanEnergiHari({
    required this.tanggal,
    required this.menitTidur,
    this.energi,
    this.fokus,
    this.jamProduktifMenit,
  });

  final DateTime tanggal;
  final int menitTidur;

  /// 1–5, null = tidak diisi.
  final int? energi;
  final int? fokus;

  /// Menit dari tengah malam (mis. 08.30 → 510), null = tidak diisi.
  final int? jamProduktifMenit;
}

/// Hasil hitungan pola energi.
class PolaEnergi {
  const PolaEnergi({
    required this.cukupData,
    required this.jumlahHari,
    required this.jumlahHariEnergi,
    required this.jumlahHariProduktif,
    required this.pesan,
    required this.dasar,
    this.rataMenitTidur,
    this.rataEnergi,
    this.rataFokus,
    this.jamProduktif,
    this.jamProduktifDari,
    this.jamProduktifSampai,
  });

  final bool cukupData;
  final int jumlahHari;
  final int jumlahHariEnergi;
  final int jumlahHariProduktif;

  /// Pesan jujur yang selalu ditampilkan.
  final String pesan;

  /// Contoh: "tabel tidur · 22 Agu–22 Sep 2026 (24 malam tercatat)".
  final String dasar;

  final double? rataMenitTidur;
  final double? rataEnergi;
  final double? rataFokus;

  /// Contoh: "08.30–11.15".
  final String? jamProduktif;
  final int? jamProduktifDari;
  final int? jamProduktifSampai;
}

String _jamMenit(int menit) {
  final j = (menit ~/ 60) % 24;
  final m = menit % 60;
  return '${j.toString().padLeft(2, '0')}.${m.toString().padLeft(2, '0')}';
}

String _labelTanggal(DateTime t) {
  const bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${t.day} ${bulan[t.month - 1]} ${t.year}';
}

/// Hitung pola energi dari [hari]. [minimalHari] = batas data (PRD: 14 hari).
PolaEnergi hitungPolaEnergi(
  List<CatatanEnergiHari> hari, {
  int minimalHari = 14,
}) {
  final urut = [...hari]..sort((a, b) => a.tanggal.compareTo(b.tanggal));
  final jumlahHari = urut.length;
  if (jumlahHari == 0) {
    return const PolaEnergi(
      cukupData: false,
      jumlahHari: 0,
      jumlahHariEnergi: 0,
      jumlahHariProduktif: 0,
      pesan: 'Belum ada catatan tidur. Catat dulu di menu Tidur.',
      dasar: 'tabel tidur · belum ada catatan',
    );
  }

  final totalMenit = urut.fold<int>(0, (a, b) => a + b.menitTidur);
  final rataMenitTidur = totalMenit / jumlahHari;

  final denganEnergi = urut.where((h) => h.energi != null).toList();
  final denganFokus = urut.where((h) => h.fokus != null).toList();
  final denganProduktif = urut.where((h) => h.jamProduktifMenit != null).toList();

  double? rata(Iterable<int?> nilai) {
    final isi = nilai.whereType<int>().toList();
    if (isi.isEmpty) return null;
    return isi.fold<int>(0, (a, b) => a + b) / isi.length;
  }

  final rataEnergi = rata(denganEnergi.map((h) => h.energi));
  final rataFokus = rata(denganFokus.map((h) => h.fokus));

  final dasar = 'tabel tidur · ${_labelTanggal(urut.first.tanggal)}–'
      '${_labelTanggal(urut.last.tanggal)} ($jumlahHari malam tercatat)';

  // Jam produktif: hanya dari catatan pengguna sendiri (min–maks jam yang
  // dicatat), supaya benar-benar "pribadi" dan bisa ditelusuri.
  String? jamProduktif;
  int? dari;
  int? sampai;
  if (denganProduktif.length >= minimalHari) {
    final menit = denganProduktif.map((h) => h.jamProduktifMenit!).toList()..sort();
    dari = menit.first;
    sampai = menit.last;
    jamProduktif = '${_jamMenit(dari)}–${_jamMenit(sampai)}';
  }

  final cukupData = jumlahHari >= minimalHari;
  String pesan;
  if (!cukupData) {
    pesan = 'Pola energi muncul setelah $minimalHari malam tercatat; '
        'sejauh ini baru $jumlahHari malam.';
  } else if (jamProduktif == null) {
    pesan = 'Tidur & energi sudah $jumlahHari malam — cukup untuk melihat pola. '
        'Jam produktif belum bisa ditampilkan: isi dulu "jam paling produktif" '
        'minimal $minimalHari hari (baru ${denganProduktif.length} hari).';
  } else {
    pesan = 'Jam produktif pribadi dihitung dari $jumlahHari malam catatan, '
        'dengan ${denganProduktif.length} hari berisi jam produktif.';
  }

  return PolaEnergi(
    cukupData: cukupData,
    jumlahHari: jumlahHari,
    jumlahHariEnergi: denganEnergi.length,
    jumlahHariProduktif: denganProduktif.length,
    pesan: pesan,
    dasar: dasar,
    rataMenitTidur: rataMenitTidur,
    rataEnergi: rataEnergi,
    rataFokus: rataFokus,
    jamProduktif: jamProduktif,
    jamProduktifDari: dari,
    jamProduktifSampai: sampai,
  );
}
