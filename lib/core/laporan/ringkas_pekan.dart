/// FR-144 — Weekly Life Review.
///
/// Kriteria terima PRD: "Tersedia setiap pekan; dapat dikirim sebagai notifikasi
/// ringkas."
///
/// Bagian angka dihitung dengan MEMBANDINGKAN pekan ini dan pekan lalu dari
/// [BahanAnalitik] yang sama — jadi "membaik" dan "perlu perhatian" selalu
/// punya angka pendukung, bukan kesan.
library;

import '../analitik/bahan_analitik.dart';

/// Satu pilar pada tinjauan pekan.
class PilarPekan {
  const PilarPekan({
    required this.pilar,
    this.membaik = const [],
    this.perluPerhatian = const [],
  });

  final String pilar;
  final List<String> membaik;
  final List<String> perluPerhatian;

  bool get adaIsi => membaik.isNotEmpty || perluPerhatian.isNotEmpty;
}

class RingkasPekan {
  const RingkasPekan({
    required this.pekanMulai,
    required this.pekanSampai,
    required this.pilar,
    required this.fokusDisarankan,
    required this.angka,
  });

  final DateTime pekanMulai;
  final DateTime pekanSampai;
  final List<PilarPekan> pilar;
  final List<String> fokusDisarankan;
  final BahanAnalitik angka;

  bool get adaPerbandingan =>
      pilar.any((p) => p.membaik.isNotEmpty || p.perluPerhatian.isNotEmpty);

  /// Kalimat ringkas untuk notifikasi pekanan (maksimal beberapa baris).
  String get ringkasNotifikasi {
    final b = <String>[];
    final membaik = <String>[];
    final perhatian = <String>[];
    for (final p in pilar) {
      membaik.addAll(p.membaik);
      perhatian.addAll(p.perluPerhatian);
    }
    if (membaik.isEmpty && perhatian.isEmpty) {
      b.add('Pekan ini belum ada catatan yang bisa dibandingkan.');
    } else {
      if (membaik.isNotEmpty) {
        b.add('Membaik: ${membaik.take(2).join('; ')}');
      }
      if (perhatian.isNotEmpty) {
        b.add('Perlu perhatian: ${perhatian.take(2).join('; ')}');
      }
    }
    if (fokusDisarankan.isNotEmpty) {
      b.add('Fokus pekan depan: ${fokusDisarankan.take(2).join('; ')}');
    }
    return b.join('\n');
  }
}

/// Susun tinjauan pekan: [ini] = pekan berjalan, [lalu] = pekan sebelumnya.
RingkasPekan susunRingkasPekan({
  required BahanAnalitik ini,
  required BahanAnalitik lalu,
  List<String> tugasPenting = const [],
  List<String> tujuanTerdekat = const [],
  List<String> dokumenDekat = const [],
}) {
  final uangBaik = <String>[];
  final uangPerlu = <String>[];
  final kesBaik = <String>[];
  final kesPerlu = <String>[];
  final tugasBaik = <String>[];
  final tugasPerlu = <String>[];
  final pengBaik = <String>[];
  final pengPerlu = <String>[];
  final ibadahBaik = <String>[];
  final ibadahPerlu = <String>[];
  final rumahBaik = <String>[];
  final rumahPerlu = <String>[];

  void banding({
    required String nama,
    required num kini,
    required num lalu,
    required bool naikItuBaik,
    required List<String> keBaik,
    required List<String> kePerlu,
    num ambangPersen = 0,
  }) {
    if (kini == 0 && lalu == 0) return;
    final acuan = lalu == 0 ? 1 : lalu.abs();
    final selisihPersen = ((kini - lalu) / acuan) * 100;
    if (selisihPersen.abs() < ambangPersen) return;
    final naik = kini > lalu;
    final keterangan = '$nama ${_angka(kini)} (pekan lalu ${_angka(lalu)})';
    if (naik == naikItuBaik) {
      keBaik.add(keterangan);
    } else {
      kePerlu.add(keterangan);
    }
  }

  banding(
    nama: 'Tagihan dibayar',
    kini: ini.tagihanLunas,
    lalu: lalu.tagihanLunas,
    naikItuBaik: true,
    keBaik: uangBaik,
    kePerlu: uangPerlu,
  );
  banding(
    nama: 'Arus kas',
    kini: ini.arusKasSen,
    lalu: lalu.arusKasSen,
    naikItuBaik: true,
    keBaik: uangBaik,
    kePerlu: uangPerlu,
  );
  banding(
    nama: 'Pengeluaran',
    kini: ini.pengeluaranSen,
    lalu: lalu.pengeluaranSen,
    naikItuBaik: false,
    keBaik: uangBaik,
    kePerlu: uangPerlu,
  );
  banding(
    nama: 'Hari beraktivitas',
    kini: ini.hariAktivitas,
    lalu: lalu.hariAktivitas,
    naikItuBaik: true,
    keBaik: kesBaik,
    kePerlu: kesPerlu,
  );
  banding(
    nama: 'Menit aktivitas',
    kini: ini.menitAktivitas,
    lalu: lalu.menitAktivitas,
    naikItuBaik: true,
    keBaik: kesBaik,
    kePerlu: kesPerlu,
    ambangPersen: 5,
  );
  final tidurKini = ini.tidurRataMenit ?? 0;
  final tidurLalu = lalu.tidurRataMenit ?? 0;
  banding(
    nama: 'Rata-rata tidur (menit)',
    kini: tidurKini.round(),
    lalu: tidurLalu.round(),
    naikItuBaik: true,
    keBaik: kesBaik,
    kePerlu: kesPerlu,
    ambangPersen: 5,
  );
  banding(
    nama: 'Tugas selesai',
    kini: ini.tugasSelesai,
    lalu: lalu.tugasSelesai,
    naikItuBaik: true,
    keBaik: tugasBaik,
    kePerlu: tugasPerlu,
  );
  banding(
    nama: 'Tugas masih terbuka',
    kini: ini.tugasTerbuka,
    lalu: lalu.tugasTerbuka,
    naikItuBaik: false,
    keBaik: tugasBaik,
    kePerlu: tugasPerlu,
  );
  banding(
    nama: 'Catatan pengetahuan',
    kini: ini.catatanPengetahuan,
    lalu: lalu.catatanPengetahuan,
    naikItuBaik: true,
    keBaik: pengBaik,
    kePerlu: pengPerlu,
  );
  banding(
    nama: 'Kartu ulangan dikerjakan',
    kini: ini.kartuDiulang,
    lalu: lalu.kartuDiulang,
    naikItuBaik: true,
    keBaik: pengBaik,
    kePerlu: pengPerlu,
  );
  banding(
    nama: 'Hafalan ditambah',
    kini: ini.hafalanBaru,
    lalu: lalu.hafalanBaru,
    naikItuBaik: true,
    keBaik: ibadahBaik,
    kePerlu: ibadahPerlu,
  );
  banding(
    nama: 'Zakat & sedekah',
    kini: ini.zakatSen,
    lalu: lalu.zakatSen,
    naikItuBaik: true,
    keBaik: ibadahBaik,
    kePerlu: ibadahPerlu,
  );
  banding(
    nama: 'Perawatan aset',
    kini: ini.perawatanAset,
    lalu: lalu.perawatanAset,
    naikItuBaik: true,
    keBaik: rumahBaik,
    kePerlu: rumahPerlu,
  );
  banding(
    nama: 'Dokumen mendekati kedaluwarsa',
    kini: ini.dokumenKedaluwarsa,
    lalu: lalu.dokumenKedaluwarsa,
    naikItuBaik: false,
    keBaik: rumahBaik,
    kePerlu: rumahPerlu,
  );

  final pilar = <PilarPekan>[
    PilarPekan(pilar: 'Uang', membaik: uangBaik, perluPerhatian: uangPerlu),
    PilarPekan(
        pilar: 'Kesehatan', membaik: kesBaik, perluPerhatian: kesPerlu),
    PilarPekan(
        pilar: 'Tujuan & tugas', membaik: tugasBaik, perluPerhatian: tugasPerlu),
    PilarPekan(
        pilar: 'Pengetahuan', membaik: pengBaik, perluPerhatian: pengPerlu),
    PilarPekan(
        pilar: 'Ibadah', membaik: ibadahBaik, perluPerhatian: ibadahPerlu),
    PilarPekan(
        pilar: 'Rumah & aset', membaik: rumahBaik, perluPerhatian: rumahPerlu),
  ];

  final fokus = <String>[
    ...tujuanTerdekat.take(2).map((t) => 'tujuan: $t'),
    ...tugasPenting.take(3).map((t) => 'tugas: $t'),
    ...dokumenDekat.take(2).map((t) => 'dokumen: $t'),
  ];

  return RingkasPekan(
    pekanMulai: ini.dari,
    pekanSampai: ini.sampai,
    pilar: pilar,
    fokusDisarankan: fokus,
    angka: ini,
  );
}

/// Label pilar yang diuji (untuk memastikan tidak ada pilar yang hilang).
List<String> pilarPekan() => const [
      'Uang',
      'Kesehatan',
      'Tujuan & tugas',
      'Pengetahuan',
      'Ibadah',
      'Rumah & aset',
    ];

String _angka(num n) {
  if (n == n.roundToDouble()) return n.round().toString();
  return n.toStringAsFixed(1);
}

/// Dipakai layar untuk menyusun rentang pekan (Senin–Minggu).
DateTime awalPekan(DateTime t) {
  final hari = DateTime(t.year, t.month, t.day);
  return hari.subtract(Duration(days: hari.weekday - DateTime.monday));
}

/// Label rentang pekan: '15–21 Sep 2026'.
String labelPekan(DateTime mulai) {
  final akhir = mulai.add(const Duration(days: 6));
  const nama = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  if (mulai.month == akhir.month) {
    return '${mulai.day}–${akhir.day} ${nama[mulai.month - 1]} ${mulai.year}';
  }
  return '${mulai.day} ${nama[mulai.month - 1]} – '
      '${akhir.day} ${nama[akhir.month - 1]} ${akhir.year}';
}

/// Nama pilar untuk metrik analitik (dipakai bersama agar tidak ada dua istilah).
String pilarDariKelompok(String kelompok) => kelompok;
