/// FR-116 — laporan kesehatan bulanan (murni, tanpa I/O).
///
/// Isi: apa yang BENAR-BENAR tercatat pada bulan itu, apa adanya. Tidak ada
/// penilaian, tidak ada target yang dipaksakan, tidak ada kata terlarang
/// (PRD §7.4 & III-11).
library;

/// Nama bulan (tanpa pakai paket locale — aman di pekerja latar & uji).
const List<String> _namaBulan = <String>[
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// Nama bulan penuh, mis. 9 → "September".
String namaBulanPenuh(int bulan) => _namaBulan[(bulan - 1).clamp(0, 11)];

/// Satu angka harian (mis. menit aktivitas, jam tidur, ml air, skor suasana).
class TitikBulanan {
  const TitikBulanan(this.hari, this.nilai);

  final DateTime hari;
  final double nilai;
}

/// Bahan laporan satu bulan.
class BahanLaporanBulanan {
  const BahanLaporanBulanan({
    required this.bulan,
    this.berat = const <TitikBulanan>[],
    this.sistolik = const <TitikBulanan>[],
    this.tidurJam = const <TitikBulanan>[],
    this.airMl = const <TitikBulanan>[],
    this.menitAktivitas = const <TitikBulanan>[],
    this.suasana = const <TitikBulanan>[],
    this.jumlahCatatanMakan = 0,
    this.jumlahCatatanKesehatan = 0,
    this.jumlahJanji = 0,
    this.jumlahHariMinumObat = 0,
    this.targetBerat,
    this.targetAirMl,
  });

  /// Bulan laporan (tanggal 1 sebagai penanda).
  final DateTime bulan;
  final List<TitikBulanan> berat;
  final List<TitikBulanan> sistolik;
  final List<TitikBulanan> tidurJam;
  final List<TitikBulanan> airMl;
  final List<TitikBulanan> menitAktivitas;
  final List<TitikBulanan> suasana;
  final int jumlahCatatanMakan;
  final int jumlahCatatanKesehatan;
  final int jumlahJanji;
  final int jumlahHariMinumObat;

  /// Target yang DIISI SENDIRI pengguna (boleh kosong). Dipakai hanya untuk
  /// menilai apakah perubahan bergerak MENUJU atau MENJAUH dari target itu.
  final double? targetBerat;
  final double? targetAirMl;
}

/// Satu bagian laporan (judul + baris teks + jumlah data).
class BagianLaporan {
  const BagianLaporan({
    required this.judul,
    required this.jumlahData,
    required this.baris,
  });

  final String judul;
  final int jumlahData;
  final List<String> baris;
}

/// Laporan kesehatan satu bulan.
class LaporanKesehatanBulanan {
  const LaporanKesehatanBulanan({
    required this.judulBulan,
    required this.jumlahHari,
    required this.hariAdaCatatan,
    required this.bagian,
  });

  /// Mis. "September 2026".
  final String judulBulan;
  final int jumlahHari;

  /// Jumlah hari pada bulan itu yang punya catatan kesehatan apa pun.
  final int hariAdaCatatan;
  final List<BagianLaporan> bagian;

  /// Total baris teks laporan (untuk keterangan "berapa butir").
  int get jumlahBaris => bagian.fold(0, (a, b) => a + b.baris.length);

  /// Seluruh teks laporan sebagai satu daftar (dipakai untuk berbagi/salin).
  List<String> get semuaTeks => [
        'Laporan kesehatan $judulBulan',
        'Hari dengan catatan: $hariAdaCatatan dari $jumlahHari hari',
        ...bagian.expand((b) => <String>['', b.judul, ...b.baris]),
      ];
}

String _f(double v, {int desimal = 1}) => v.toStringAsFixed(desimal);

/// Bagian dari satu deret angka: jumlah, rata-rata, terendah, tertinggi.
BagianLaporan _bagianDeret(String judul, List<TitikBulanan> data,
    {String satuan = '', int desimal = 1}) {
  if (data.isEmpty) {
    return BagianLaporan(
      judul: judul,
      jumlahData: 0,
      baris: const <String>['Belum ada catatan bulan ini.'],
    );
  }
  final urut = [...data]..sort((a, b) => a.hari.compareTo(b.hari));
  final nilai = urut.map((d) => d.nilai).toList()..sort();
  final rata = nilai.reduce((a, b) => a + b) / nilai.length;
  final awal = urut.first;
  final akhir = urut.last;
  final arah = akhir.nilai - awal.nilai;
  return BagianLaporan(
    judul: judul,
    jumlahData: urut.length,
    baris: <String>[
      'Jumlah catatan: ${urut.length}',
      'Rata-rata: ${_f(rata, desimal: desimal)}$satuan',
      'Terendah: ${_f(nilai.first, desimal: desimal)}$satuan · '
          'Tertinggi: ${_f(nilai.last, desimal: desimal)}$satuan',
      'Catatan pertama ${awal.hari.day}/${awal.hari.month}: '
          '${_f(awal.nilai, desimal: desimal)}$satuan → '
          'catatan terakhir ${akhir.hari.day}/${akhir.hari.month}: '
          '${_f(akhir.nilai, desimal: desimal)}$satuan '
          '(selisih ${arah >= 0 ? '+' : ''}${_f(arah, desimal: desimal)})',
    ],
  );
}

/// Susun laporan kesehatan bulanan dari bahan yang tersedia.
LaporanKesehatanBulanan susunLaporanBulanan(BahanLaporanBulanan bahan) {
  final bulan = bahan.bulan;
  final jumlahHari = DateTime(bulan.year, bulan.month + 1, 0).day;

  // Hari yang punya catatan apa pun pada bulan itu.
  final hariCatat = <String>{};
  void catatHari(List<TitikBulanan> data) {
    for (final d in data) {
      if (d.hari.year == bulan.year && d.hari.month == bulan.month) {
        hariCatat.add('${d.hari.year}-${d.hari.month}-${d.hari.day}');
      }
    }
  }

  for (final d in <List<TitikBulanan>>[
    bahan.berat,
    bahan.sistolik,
    bahan.tidurJam,
    bahan.airMl,
    bahan.menitAktivitas,
    bahan.suasana,
  ]) {
    catatHari(d);
  }

  final bagian = <BagianLaporan>[
    ...kelompokPerubahan(bahan),
    _bagianDeret('Berat badan', bahan.berat, satuan: ' kg'),
    _bagianDeret('Tekanan darah sistolik', bahan.sistolik, satuan: ' mmHg',
        desimal: 0),
    _bagianDeret('Tidur', bahan.tidurJam, satuan: ' jam'),
    _bagianDeret('Air minum', bahan.airMl, satuan: ' ml', desimal: 0),
    _bagianDeret('Aktivitas', bahan.menitAktivitas, satuan: ' menit', desimal: 0),
    _bagianDeret('Suasana hati', bahan.suasana, desimal: 1),
    BagianLaporan(
      judul: 'Catatan lain',
      jumlahData: bahan.jumlahCatatanMakan +
          bahan.jumlahCatatanKesehatan +
          bahan.jumlahJanji,
      baris: <String>[
        'Catatan makan: ${bahan.jumlahCatatanMakan}',
        'Catatan kesehatan (angka/tekanan/lab): ${bahan.jumlahCatatanKesehatan}',
        'Janji & kontrol kesehatan: ${bahan.jumlahJanji}',
      ],
    ),
    BagianLaporan(
      judul: 'Minum obat',
      jumlahData: bahan.jumlahHariMinumObat,
      baris: bahan.jumlahHariMinumObat == 0
          ? const <String>['Belum ada catatan minum obat bulan ini.']
          : <String>['Hari dengan catatan minum obat: ${bahan.jumlahHariMinumObat}'],
    ),
  ];

  return LaporanKesehatanBulanan(
    judulBulan: '${namaBulanPenuh(bulan.month)} ${bulan.year}',
    jumlahHari: jumlahHari,
    hariAdaCatatan: hariCatat.length,
    bagian: bagian,
  );
}

/// Ringkasan tiga kelompok (FR-116): yang membaik, yang berubah, yang perlu
/// diperhatikan.
///
/// Aturan yang dipakai TERBUKA dan tidak menilai kesehatan seseorang:
///  - membaik            : bergerak menuju target yang pengguna isi sendiri;
///  - berubah            : selisih >= 2 satuan (suasana hati >= 1 poin);
///  - perlu diperhatikan : bergerak menjauh dari target, atau tidak ada catatan
///                         selama 14 hari terakhir pada bulan itu.
/// Setiap baris menyebutkan angkanya supaya bisa diperiksa sendiri.
List<BagianLaporan> kelompokPerubahan(BahanLaporanBulanan bahan) {
  final bulan = bahan.bulan;
  final akhirBulan = DateTime(bulan.year, bulan.month + 1, 0);
  final batasDiam = akhirBulan.subtract(const Duration(days: 13));

  final deret = <_DeretKelompok>[
    _DeretKelompok('Berat badan', bahan.berat, ' kg', 1, bahan.targetBerat, 2),
    _DeretKelompok('Air minum', bahan.airMl, ' ml', 0, bahan.targetAirMl, 2),
    _DeretKelompok('Tidur', bahan.tidurJam, ' jam', 1, null, 2),
    _DeretKelompok('Aktivitas', bahan.menitAktivitas, ' menit', 0, null, 2),
    _DeretKelompok('Suasana hati', bahan.suasana, ' dari 5', 1, null, 1),
    _DeretKelompok('Tekanan darah sistolik', bahan.sistolik, ' mmHg', 0, null, 2),
  ];

  final membaik = <String>[];
  final berubah = <String>[];
  final perhatian = <String>[];

  for (final d in deret) {
    final isi = d.data
        .where((p) => p.hari.year == bulan.year && p.hari.month == bulan.month)
        .toList()
      ..sort((a, b) => a.hari.compareTo(b.hari));
    if (isi.length < 2) {
      if (isi.isEmpty) {
        perhatian.add('${d.nama}: belum ada catatan pada bulan ini.');
      } else {
        berubah.add('${d.nama}: baru ${isi.length} catatan, belum bisa '
            'dibandingkan.');
      }
      continue;
    }
    final awal = isi.first;
    final akhir = isi.last;
    final selisih = akhir.nilai - awal.nilai;
    final teks = '${d.nama}: ${awal.nilai.toStringAsFixed(d.desimal)} → '
        '${akhir.nilai.toStringAsFixed(d.desimal)}${d.satuan} '
        '(${selisih >= 0 ? '+' : ''}${selisih.toStringAsFixed(d.desimal)})';

    final diam = akhir.hari.isBefore(batasDiam);
    final menujuTarget = d.target != null &&
        ((d.target! - akhir.nilai).abs() < (d.target! - awal.nilai).abs());
    final menjauhTarget = d.target != null &&
        ((d.target! - akhir.nilai).abs() > (d.target! - awal.nilai).abs());

    if (menujuTarget) {
      membaik.add(teks);
    } else if (menjauhTarget || diam) {
      perhatian.add(menjauhTarget
          ? '$teks — bergerak menjauh dari target '
              '${d.target!.toStringAsFixed(d.desimal)}${d.satuan}.'
          : '$teks — catatan terakhir '
              '${akhir.hari.day}/${akhir.hari.month}, sudah lebih dari 14 hari.');
    } else if (selisih.abs() >= d.ambang) {
      berubah.add(teks);
    } else {
      berubah.add('$teks — masih di sekitar angka yang sama.');
    }
  }

  return <BagianLaporan>[
    BagianLaporan(
      judul: 'Yang membaik',
      jumlahData: membaik.length,
      baris: membaik.isEmpty
          ? const <String>['Belum ada catatan yang bergerak menuju target Anda.']
          : membaik,
    ),
    BagianLaporan(
      judul: 'Yang berubah',
      jumlahData: berubah.length,
      baris: berubah.isEmpty
          ? const <String>['Belum ada perubahan yang bisa dibandingkan.']
          : berubah,
    ),
    BagianLaporan(
      judul: 'Yang perlu diperhatikan',
      jumlahData: perhatian.length,
      baris: perhatian.isEmpty
          ? const <String>['Tidak ada yang menonjol dari catatan bulan ini.']
          : perhatian,
    ),
  ];
}

/// Satu deret angka untuk kelompok perubahan.
class _DeretKelompok {
  const _DeretKelompok(
    this.nama,
    this.data,
    this.satuan,
    this.desimal,
    this.target,
    this.ambang,
  );

  final String nama;
  final List<TitikBulanan> data;
  final String satuan;
  final int desimal;
  final double? target;

  /// Ambang selisih (dalam satuan) supaya dianggap "berubah".
  final double ambang;
}

/// Daftar bulan yang punya data (untuk pemilih bulan di layar).
List<DateTime> bulanTersedia(List<DateTime> semuaHari) {
  final kunci = <String, DateTime>{};
  for (final h in semuaHari) {
    kunci['${h.year}-${h.month}'] = DateTime(h.year, h.month);
  }
  final hasil = kunci.values.toList()
    ..sort((a, b) => b.compareTo(a));
  return hasil;
}
