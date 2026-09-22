/// FR-145 — Monthly Life Report (signature).
///
/// Kriteria terima PRD: "Tersedia untuk setiap bulan berjalan; bisa dibagikan
/// sebagai PDF." Bagian yang diminta: keuangan, tagihan, tujuan, tugas,
/// langganan, kekayaan bersih + "apa yang membaik / berubah / perlu perhatian".
///
/// Semua angka berasal dari [BahanAnalitik] yang sama dengan analitik (FR-141)
/// dan tinjauan pekan (FR-144) — satu sumber, jadi tidak ada angka berbeda
/// antar layar.
library;

import '../analitik/bahan_analitik.dart';
import '../timeline/lini_masa.dart' show labelBulan;

/// Satu baris laporan: label, nilai, dan asalnya.
class BarisLaporan {
  const BarisLaporan({required this.label, required this.nilai, this.sumber = ''});

  final String label;
  final String nilai;
  final String sumber;
}

class BagianLaporan {
  const BagianLaporan({required this.judul, required this.baris});

  final String judul;
  final List<BarisLaporan> baris;
}

class LaporanHidupBulanan {
  const LaporanHidupBulanan({
    required this.bulan,
    required this.dari,
    required this.sampai,
    required this.bagian,
    required this.membaik,
    required this.berubah,
    required this.perluPerhatian,
    required this.angka,
  });

  /// 'YYYY-MM'.
  final String bulan;
  final DateTime dari;
  final DateTime sampai;
  final List<BagianLaporan> bagian;
  final List<String> membaik;
  final List<String> berubah;
  final List<String> perluPerhatian;
  final BahanAnalitik angka;

  String get label => labelBulan(bulan);

  /// Angka kunci untuk disimpan sebagai arsip (bisa dibandingkan antar bulan).
  Map<String, Object?> angkaKunci() => {
        'bulan': bulan,
        'tagihan_lunas': angka.tagihanLunas,
        'tagihan_dibayar_sen': angka.totalBayarSen,
        'transaksi': angka.transaksiBaru,
        'pengeluaran_sen': angka.pengeluaranSen,
        'pemasukan_sen': angka.pemasukanSen,
        'arus_kas_sen': angka.arusKasSen,
        'tugas_selesai': angka.tugasSelesai,
        'tugas_baru': angka.tugasBaru,
        'tujuan_selesai': angka.tujuanSelesai,
        'hari_aktivitas': angka.hariAktivitas,
        'menit_aktivitas': angka.menitAktivitas,
        'tidur_rata_menit': angka.tidurRataMenit?.round(),
        'catatan_pengetahuan': angka.catatanPengetahuan,
        'kartu_diulang': angka.kartuDiulang,
        'perawatan_aset': angka.perawatanAset,
        'langganan_aktif': angka.langgananAktif,
        'kekayaan_bersih_sen': angka.kekayaanBersihSen,
      };

  /// Teks laporan (dipakai untuk disalin & isi PDF).
  String teksLengkap() {
    final b = StringBuffer('LAPORAN BULANAN — ${label.toUpperCase()}\n');
    b.writeln('Periode ${_tgl(dari)} – ${_tgl(sampai)}\n');
    for (final bg in bagian) {
      b.writeln(bg.judul.toUpperCase());
      for (final r in bg.baris) {
        b.writeln('  • ${r.label}: ${r.nilai}');
      }
      b.writeln();
    }
    void tulis(String judul, List<String> isi) {
      b.writeln(judul.toUpperCase());
      if (isi.isEmpty) {
        b.writeln('  • belum ada yang bisa dibandingkan');
      } else {
        for (final x in isi) {
          b.writeln('  • $x');
        }
      }
      b.writeln();
    }

    tulis('Yang membaik', membaik);
    tulis('Yang berubah', berubah);
    tulis('Yang perlu perhatian', perluPerhatian);
    b.writeln('Angka di laporan ini dihitung dari catatan pribadi di aplikasi, '
        'bukan perkiraan.');
    return b.toString();
  }

  static String _tgl(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}/'
      '${t.month.toString().padLeft(2, '0')}/${t.year}';
}

/// Susun laporan bulanan dengan membandingkan [ini] dan [lalu].
LaporanHidupBulanan susunLaporanHidupBulanan({
  required BahanAnalitik ini,
  required BahanAnalitik lalu,
  List<String> langgananDekat = const [],
  List<String> tujuanTerdekat = const [],
  List<String> asetTerbesar = const [],
}) {
  final keuangan = <BarisLaporan>[
    BarisLaporan(
      label: 'Pemasukan tercatat',
      nilai: _rupiah(ini.pemasukanSen),
      sumber: 'tabel transaksi',
    ),
    BarisLaporan(
      label: 'Pengeluaran tercatat',
      nilai: _rupiah(ini.pengeluaranSen),
      sumber: 'tabel transaksi',
    ),
    BarisLaporan(
      label: 'Arus kas bersih',
      nilai: _rupiah(ini.arusKasSen),
      sumber: 'transaksi: masuk − keluar',
    ),
  ];

  final tagihan = <BarisLaporan>[
    BarisLaporan(
      label: 'Tagihan dibayar',
      nilai: '${ini.tagihanLunas} tagihan',
      sumber: 'tabel riwayat_pembayaran',
    ),
    BarisLaporan(
      label: 'Nilai pembayaran',
      nilai: _rupiah(ini.totalBayarSen),
      sumber: 'tabel riwayat_pembayaran',
    ),
    BarisLaporan(
      label: 'Nilai tagihan baru',
      nilai: _rupiah(ini.totalTagihanSen),
      sumber: 'tabel tagihan',
    ),
  ];

  final tujuanTugas = <BarisLaporan>[
    BarisLaporan(
      label: 'Tujuan baru',
      nilai: '${ini.tujuanBaru}',
      sumber: 'tabel tujuan',
    ),
    BarisLaporan(
      label: 'Tujuan tercapai',
      nilai: '${ini.tujuanSelesai}',
      sumber: 'tabel tujuan',
    ),
    BarisLaporan(
      label: 'Tugas selesai',
      nilai: '${ini.tugasSelesai}',
      sumber: 'tabel tugas',
    ),
    BarisLaporan(
      label: 'Tugas masih terbuka',
      nilai: '${ini.tugasTerbuka}',
      sumber: 'tabel tugas',
    ),
  ];

  final langganan = <BarisLaporan>[
    BarisLaporan(
      label: 'Langganan aktif',
      nilai: '${ini.langgananAktif}',
      sumber: 'tabel langganan',
    ),
    BarisLaporan(
      label: 'Biaya langganan per bulan',
      nilai: _rupiah(ini.biayaLanggananSen),
      sumber: 'tabel langganan (perkiraan biaya)',
    ),
    BarisLaporan(
      label: 'Jatuh tempo terdekat',
      nilai: langgananDekat.isEmpty ? 'tidak ada' : langgananDekat.join(', '),
      sumber: 'tabel langganan (tanggal berikutnya)',
    ),
  ];

  final kekayaan = <BarisLaporan>[
    BarisLaporan(
      label: 'Total aset',
      nilai: ini.totalAsetSen == null ? 'belum ada data' : _rupiah(ini.totalAsetSen!),
      sumber: 'tabel aset & nilai_aset_bulanan',
    ),
    BarisLaporan(
      label: 'Total kewajiban',
      nilai: ini.totalKewajibanSen == null
          ? 'belum ada data'
          : _rupiah(ini.totalKewajibanSen!),
      sumber: 'tabel kewajiban & nilai_kewajiban_bulanan',
    ),
    BarisLaporan(
      label: 'Kekayaan bersih',
      nilai: ini.kekayaanBersihSen == null
          ? 'belum ada data'
          : _rupiah(ini.kekayaanBersihSen!),
      sumber: 'aset − kewajiban',
    ),
    BarisLaporan(
      label: 'Aset terbesar',
      nilai: asetTerbesar.isEmpty ? 'belum ada data' : asetTerbesar.join(', '),
      sumber: 'tabel aset (nilai terbesar)',
    ),
  ];

  final kesehatan = <BarisLaporan>[
    BarisLaporan(
      label: 'Hari beraktivitas',
      nilai: '${ini.hariAktivitas} hari',
      sumber: 'tabel aktivitas',
    ),
    BarisLaporan(
      label: 'Rata-rata tidur',
      nilai: ini.tidurRataMenit == null
          ? 'belum ada catatan'
          : '${ini.tidurRataMenit!.round()} menit/malam',
      sumber: 'tabel tidur',
    ),
    BarisLaporan(
      label: 'Catatan medis baru',
      nilai: '${ini.catatanMedis}',
      sumber: 'tabel catatan_medis',
    ),
  ];

  final rumah = <BarisLaporan>[
    BarisLaporan(
      label: 'Perawatan aset',
      nilai: '${ini.perawatanAset} kali',
      sumber: 'tabel riwayat_perawatan_aset',
    ),
    BarisLaporan(
      label: 'Biaya perawatan',
      nilai: _rupiah(ini.biayaPerawatanSen),
      sumber: 'tabel riwayat_perawatan_aset (biaya)',
    ),
  ];

  // ── tiga kelompok pembanding bulan lalu ──────────────────────────────────
  final membaik = <String>[];
  final berubah = <String>[];
  final perlu = <String>[];

  void banding({
    required String nama,
    required num kini,
    required num lalu,
    required int arah, // 1 = naik itu baik · -1 = turun itu baik · 0 = netral
    int? uangSen,
    num ambangPersen = 0,
  }) {
    if (kini == 0 && lalu == 0) return;
    final acuan = lalu == 0 ? 1 : lalu.abs();
    final persen = ((kini - lalu) / acuan) * 100;
    if (persen.abs() < ambangPersen) return;
    final teks = uangSen != null
        ? '$nama ${_rupiah(kini.round())} (bulan lalu ${_rupiah(lalu.round())})'
        : '$nama ${_angka(kini)} (bulan lalu ${_angka(lalu)})';
    if (arah == 0) {
      berubah.add(teks);
    } else if ((kini > lalu && arah == 1) || (kini < lalu && arah == -1)) {
      membaik.add(teks);
    } else {
      perlu.add(teks);
    }
  }

  banding(
      nama: 'Arus kas',
      kini: ini.arusKasSen,
      lalu: lalu.arusKasSen,
      arah: 1,
      uangSen: 1);
  banding(
      nama: 'Pengeluaran',
      kini: ini.pengeluaranSen,
      lalu: lalu.pengeluaranSen,
      arah: -1,
      uangSen: 1);
  banding(
      nama: 'Nilai tagihan dibayar',
      kini: ini.totalBayarSen,
      lalu: lalu.totalBayarSen,
      arah: 1,
      uangSen: 1);
  banding(
      nama: 'Tugas selesai',
      kini: ini.tugasSelesai,
      lalu: lalu.tugasSelesai,
      arah: 1);
  banding(
      nama: 'Tugas masih terbuka',
      kini: ini.tugasTerbuka,
      lalu: lalu.tugasTerbuka,
      arah: -1);
  banding(
      nama: 'Hari beraktivitas',
      kini: ini.hariAktivitas,
      lalu: lalu.hariAktivitas,
      arah: 1);
  banding(
      nama: 'Catatan pengetahuan',
      kini: ini.catatanPengetahuan,
      lalu: lalu.catatanPengetahuan,
      arah: 1);
  banding(
      nama: 'Kartu ulangan dikerjakan',
      kini: ini.kartuDiulang,
      lalu: lalu.kartuDiulang,
      arah: 1);
  banding(
      nama: 'Perawatan aset',
      kini: ini.perawatanAset,
      lalu: lalu.perawatanAset,
      arah: 1);
  banding(
      nama: 'Jumlah catatan transaksi',
      kini: ini.transaksiBaru,
      lalu: lalu.transaksiBaru,
      arah: 0);
  if (ini.kekayaanBersihSen != null && lalu.kekayaanBersihSen != null) {
    banding(
      nama: 'Kekayaan bersih',
      kini: ini.kekayaanBersihSen!,
      lalu: lalu.kekayaanBersihSen!,
      arah: 1,
      uangSen: 1,
    );
  }

  return LaporanHidupBulanan(
    bulan: kunciBulanLaporan(ini.dari),
    dari: ini.dari,
    sampai: ini.sampai,
    bagian: [
      BagianLaporan(judul: 'Keuangan', baris: keuangan),
      BagianLaporan(judul: 'Tagihan', baris: tagihan),
      BagianLaporan(judul: 'Tujuan & tugas', baris: tujuanTugas),
      BagianLaporan(judul: 'Langganan', baris: langganan),
      BagianLaporan(judul: 'Kekayaan bersih', baris: kekayaan),
      BagianLaporan(judul: 'Kesehatan', baris: kesehatan),
      BagianLaporan(judul: 'Rumah & aset', baris: rumah),
    ],
    membaik: membaik,
    berubah: berubah,
    perluPerhatian: perlu,
    angka: ini,
  );
}

/// 'YYYY-MM' dari tanggal mana pun di bulan itu.
String kunciBulanLaporan(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}';

/// Rentang awal & akhir satu bulan ('YYYY-MM').
({DateTime dari, DateTime sampai}) rentangBulan(String kunci) {
  final bagian = kunci.split('-');
  final tahun = int.tryParse(bagian.isNotEmpty ? bagian[0] : '') ?? 1970;
  final bulan = int.tryParse(bagian.length > 1 ? bagian[1] : '') ?? 1;
  final dari = DateTime(tahun, bulan, 1);
  final sampai = DateTime(tahun, bulan + 1, 0, 23, 59, 59, 999);
  return (dari: dari, sampai: sampai);
}

/// Kunci bulan sebelumnya ('YYYY-MM').
String bulanSebelum(String kunci) {
  final r = rentangBulan(kunci);
  final sebelumnya = DateTime(r.dari.year, r.dari.month - 1, 1);
  return kunciBulanLaporan(sebelumnya);
}

/// Daftar kunci bulan pilihan (12 bulan terakhir dari [sekarang]).
List<String> pilihanBulan(DateTime sekarang, {int jumlah = 12}) => [
      for (var i = 0; i < jumlah; i++)
        kunciBulanLaporan(DateTime(sekarang.year, sekarang.month - i, 1)),
    ];

String _rupiah(num sen) {
  final angka = (sen / 100).round();
  final teks = angka.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < teks.length; i++) {
    if (i > 0 && (teks.length - i) % 3 == 0) b.write('.');
    b.write(teks[i]);
  }
  return '${angka < 0 ? '-' : ''}Rp$b';
}

String _angka(num n) {
  if (n == n.roundToDouble()) return n.round().toString();
  return n.toStringAsFixed(1);
}

/// Metrik analitik yang dipakai laporan (dipastikan ada agar laporan tidak
/// kehilangan bagian).
List<String> bagianLaporanWajib() => const [
      'Keuangan',
      'Tagihan',
      'Tujuan & tugas',
      'Langganan',
      'Kekayaan bersih',
      'Kesehatan',
      'Rumah & aset',
    ];
