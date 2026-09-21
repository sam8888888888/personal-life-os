/// FR-112 — jurnal suasana hati & stres, murni tanpa I/O.
///
/// Prinsip: pengguna menilai dirinya sendiri pada skala 1–5. Aplikasi hanya
/// melaporkan angka & arahnya, tidak menyebut keadaan pengguna sebagai
/// kekurangan, dan tidak memakai kata terlarang (PRD §III-11).
library;

/// Skala 1–5 yang ditampilkan apa adanya (label netral, bukan penilaian).
const Map<int, String> labelSuasana = <int, String>{
  1: '1 · paling berat',
  2: '2 · berat',
  3: '3 · sedang',
  4: '4 · ringan',
  5: '5 · paling ringan',
};

/// Skala energi & stres.
const Map<int, String> labelEnergi = <int, String>{
  1: '1 · paling rendah',
  2: '2 · rendah',
  3: '3 · sedang',
  4: '4 · tinggi',
  5: '5 · paling tinggi',
};

const Map<int, String> labelStres = <int, String>{
  1: '1 · paling ringan',
  2: '2 · ringan',
  3: '3 · sedang',
  4: '4 · tinggi',
  5: '5 · paling tinggi',
};

/// Satu catatan suasana hati.
class BarisSuasana {
  const BarisSuasana({
    required this.skor,
    required this.waktu,
    this.energi,
    this.stres,
    this.pemicu,
    this.catatan,
    this.id,
  });

  final int? id;
  final int skor;
  final int? energi;
  final int? stres;
  final String? pemicu;
  final String? catatan;
  final DateTime waktu;
}

/// Rata-rata [nilai] yang aman (null bila kosong).
double? _rata(List<int> nilai) {
  if (nilai.isEmpty) return null;
  return nilai.reduce((a, b) => a + b) / nilai.length;
}

/// Satu batang harian (rata-rata hari itu).
class BatangSuasana {
  const BatangSuasana({
    required this.tanggal,
    required this.label,
    required this.rataRata,
    required this.jumlah,
  });

  final DateTime tanggal;
  final String label;

  /// Rata-rata suasana hari itu (null bila tidak ada catatan).
  final double? rataRata;
  final int jumlah;
}

/// Ringkasan suasana hati pada rentang hari terakhir.
class RingkasSuasana {
  const RingkasSuasana({
    required this.jumlahCatatan,
    required this.rataRata,
    required this.terakhir,
    required this.energiRataRata,
    required this.stresRataRata,
    required this.pemicuTersering,
    required this.batang,
    required this.rataRataRentang,
    required this.rataRataSebelumnya,
  });

  final int jumlahCatatan;
  final double? rataRata;
  final BarisSuasana? terakhir;
  final double? energiRataRata;
  final double? stresRataRata;
  final List<String> pemicuTersering;
  final List<BatangSuasana> batang;

  /// Rata-rata pada rentang ([hari] hari terakhir) dan rentang sebelumnya.
  final double? rataRataRentang;
  final double? rataRataSebelumnya;

  /// Arah perubahan antar rentang (null bila salah satu rentang kosong).
  int? get arah {
    final a = rataRataRentang;
    final b = rataRataSebelumnya;
    if (a == null || b == null) return null;
    final selisih = a - b;
    if (selisih.abs() < 0.05) return 0;
    return selisih > 0 ? 1 : -1;
  }
}

/// Ringkas suasana hati; [acuan] dianggap hari ini.
RingkasSuasana ringkasSuasana(
  List<BarisSuasana> catatan, {
  required DateTime acuan,
  int hari = 14,
}) {
  final urut = [...catatan]..sort((a, b) => a.waktu.compareTo(b.waktu));
  final awalRentang = DateTime(acuan.year, acuan.month, acuan.day)
      .subtract(Duration(days: hari - 1));
  final awalSebelum = awalRentang.subtract(Duration(days: hari));

  final rentang = urut.where((c) => !c.waktu.isBefore(awalRentang)).toList();
  final sebelum = urut
      .where((c) =>
          c.waktu.isBefore(awalRentang) && !c.waktu.isBefore(awalSebelum))
      .toList();

  final pemicu = <String, int>{};
  for (final c in urut) {
    final p = (c.pemicu ?? '').trim();
    if (p.isEmpty) continue;
    pemicu.update(p.toLowerCase(), (v) => v + 1, ifAbsent: () => 1);
  }
  final pemicuUrut = pemicu.entries.toList()
    ..sort((a, b) => b.value == a.value
        ? a.key.compareTo(b.key)
        : b.value.compareTo(a.value));

  const namaHari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  final batang = <BatangSuasana>[];
  for (var i = hari - 1; i >= 0; i--) {
    final tgl =
        DateTime(acuan.year, acuan.month, acuan.day).subtract(Duration(days: i));
    final hariIni = urut
        .where((c) =>
            c.waktu.year == tgl.year &&
            c.waktu.month == tgl.month &&
            c.waktu.day == tgl.day)
        .toList();
    batang.add(BatangSuasana(
      tanggal: tgl,
      label: namaHari[tgl.weekday - 1],
      rataRata: _rata(hariIni.map((c) => c.skor).toList()),
      jumlah: hariIni.length,
    ));
  }

  return RingkasSuasana(
    jumlahCatatan: urut.length,
    rataRata: _rata(urut.map((c) => c.skor).toList()),
    terakhir: urut.isEmpty ? null : urut.last,
    energiRataRata:
        _rata(urut.map((c) => c.energi).whereType<int>().toList()),
    stresRataRata: _rata(urut.map((c) => c.stres).whereType<int>().toList()),
    pemicuTersering: pemicuUrut.take(5).map((e) => e.key).toList(),
    batang: batang,
    rataRataRentang: _rata(rentang.map((c) => c.skor).toList()),
    rataRataSebelumnya: _rata(sebelum.map((c) => c.skor).toList()),
  );
}

/// Kalimat arah perubahan yang netral (angka apa adanya).
String kalimatArahSuasana(RingkasSuasana r) {
  final arah = r.arah;
  if (arah == null) return 'Belum bisa dibandingkan dengan rentang sebelumnya.';
  if (arah == 0) return 'Rata-rata hampir sama dengan rentang sebelumnya.';
  final a = r.rataRataRentang!.toStringAsFixed(1);
  final b = r.rataRataSebelumnya!.toStringAsFixed(1);
  return arah > 0
      ? 'Rata-rata naik dari $b ke $a (skala 1–5, makin tinggi makin ringan).'
      : 'Rata-rata turun dari $b ke $a (skala 1–5, makin rendah makin berat).';
}
