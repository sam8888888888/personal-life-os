/// FR-141 — Personal Analytics.
///
/// Kriteria terima PRD: "Tiap angka dapat ditelusuri ke data asalnya (tidak ada
/// angka misterius)." Karena itu SETIAP metrik wajib membawa [MetrikAnalitik.sumber]
/// yang menyebut tabel & rentangnya.
library;

import 'bahan_analitik.dart';

/// Satu angka analitik beserta asalnya.
class MetrikAnalitik {
  const MetrikAnalitik({
    required this.kelompok,
    required this.nama,
    required this.nilai,
    required this.sumber,
    this.angka,
    this.satuanUangSen,
  });

  final String kelompok;
  final String nama;
  final String nilai;

  /// Dari tabel/rentang mana angka ini dihitung.
  final String sumber;

  /// Nilai mentah (dipakai pengurutan/pembanding), bila ada.
  final num? angka;

  /// Bila metrik berupa uang, nilainya dalam sen (untuk format Rupiah).
  final int? satuanUangSen;
}

/// Rentang analitik yang disediakan (PRD: 7/30/90 hari & 1 tahun).
const List<int> rentangAnalitik = [7, 30, 90, 365];

String labelRentang(int hari) {
  if (hari >= 365) return '1 tahun';
  return '$hari hari';
}

/// Susun metrik untuk satu rentang.
///
/// [saringKelompok] kosong = semua kelompok.
List<MetrikAnalitik> susunAnalitik(
  BahanAnalitik b, {
  Set<String> saringKelompok = const <String>{},
}) {
  final label = labelRentang(b.hari);
  final r = <MetrikAnalitik>[];

  void tambah(MetrikAnalitik m) {
    if (saringKelompok.isEmpty || saringKelompok.contains(m.kelompok)) {
      r.add(m);
    }
  }

  if (b.totalTagihanSen != 0 || b.tagihanLunas != 0) {
    tambah(MetrikAnalitik(
      kelompok: 'Uang',
      nama: 'Tagihan dibayar',
      nilai: '${b.tagihanLunas} tagihan',
      sumber: 'tabel riwayat_pembayaran, $label terakhir',
      angka: b.tagihanLunas,
    ));
    tambah(MetrikAnalitik(
      kelompok: 'Uang',
      nama: 'Nilai tagihan dibayar',
      nilai: '${b.totalBayarSen}',
      sumber: 'tabel riwayat_pembayaran (jumlah_sen), $label terakhir',
      angka: b.totalBayarSen,
      satuanUangSen: b.totalBayarSen,
    ));
  }
  if (b.transaksiBaru > 0) {
    tambah(MetrikAnalitik(
      kelompok: 'Uang',
      nama: 'Catatan transaksi',
      nilai: '${b.transaksiBaru} catatan',
      sumber: 'tabel transaksi, $label terakhir',
      angka: b.transaksiBaru,
    ));
    tambah(MetrikAnalitik(
      kelompok: 'Uang',
      nama: 'Arus kas',
      nilai: '${b.arusKasSen}',
      sumber: 'tabel transaksi: pemasukan − pengeluaran, $label terakhir',
      angka: b.arusKasSen,
      satuanUangSen: b.arusKasSen,
    ));
  }
  if (b.tugasSelesai > 0 || b.tugasBaru > 0) {
    tambah(MetrikAnalitik(
      kelompok: 'Tujuan & tugas',
      nama: 'Tugas selesai',
      nilai: '${b.tugasSelesai} tugas',
      sumber: 'tabel tugas (selesai_pada), $label terakhir',
      angka: b.tugasSelesai,
    ));
    tambah(MetrikAnalitik(
      kelompok: 'Tujuan & tugas',
      nama: 'Tugas baru',
      nilai: '${b.tugasBaru} tugas',
      sumber: 'tabel tugas (dibuat_pada), $label terakhir',
      angka: b.tugasBaru,
    ));
  }
  if (b.tugasTerbuka > 0) {
    tambah(MetrikAnalitik(
      kelompok: 'Tujuan & tugas',
      nama: 'Tugas masih terbuka',
      nilai: '${b.tugasTerbuka} tugas',
      sumber: 'tabel tugas (belum selesai), saat ini',
      angka: b.tugasTerbuka,
    ));
  }
  if (b.tujuanSelesai > 0) {
    tambah(MetrikAnalitik(
      kelompok: 'Tujuan & tugas',
      nama: 'Tujuan tercapai',
      nilai: '${b.tujuanSelesai} tujuan',
      sumber: 'tabel tujuan (selesai), $label terakhir',
      angka: b.tujuanSelesai,
    ));
  }
  if (b.hariAktivitas > 0 || b.menitAktivitas > 0) {
    tambah(MetrikAnalitik(
      kelompok: 'Kesehatan',
      nama: 'Hari beraktivitas',
      nilai: '${b.hariAktivitas} hari',
      sumber: 'tabel aktivitas (tanggal unik), $label terakhir',
      angka: b.hariAktivitas,
    ));
    tambah(MetrikAnalitik(
      kelompok: 'Kesehatan',
      nama: 'Total menit aktivitas',
      nilai: '${b.menitAktivitas} menit',
      sumber: 'tabel aktivitas (durasi_menit), $label terakhir',
      angka: b.menitAktivitas,
    ));
  }
  if (b.malamTidurTercatat > 0) {
    final rata = b.tidurRataMenit;
    tambah(MetrikAnalitik(
      kelompok: 'Kesehatan',
      nama: 'Rata-rata tidur',
      nilai: rata == null ? '-' : '${rata.round()} menit/malam',
      sumber: 'tabel tidur: menit ÷ malam tercatat, $label terakhir',
      angka: rata,
    ));
  }
  if (b.ukuranTubuh > 0) {
    tambah(MetrikAnalitik(
      kelompok: 'Kesehatan',
      nama: 'Catatan ukuran tubuh',
      nilai: '${b.ukuranTubuh} ukuran',
      sumber: 'tabel ukuran_tubuh, $label terakhir',
      angka: b.ukuranTubuh,
    ));
  }
  if (b.catatanMedis > 0) {
    tambah(MetrikAnalitik(
      kelompok: 'Kesehatan',
      nama: 'Catatan medis masuk',
      nilai: '${b.catatanMedis} catatan',
      sumber: 'tabel catatan_medis, $label terakhir',
      angka: b.catatanMedis,
    ));
  }
  if (b.catatanPengetahuan > 0 || b.keputusanBaru > 0) {
    tambah(MetrikAnalitik(
      kelompok: 'Pengetahuan',
      nama: 'Catatan dibuat',
      nilai: '${b.catatanPengetahuan} catatan',
      sumber: 'tabel catatan_pengetahuan, $label terakhir',
      angka: b.catatanPengetahuan,
    ));
    tambah(MetrikAnalitik(
      kelompok: 'Pengetahuan',
      nama: 'Keputusan dicatat',
      nilai: '${b.keputusanBaru} keputusan',
      sumber: 'tabel keputusan, $label terakhir',
      angka: b.keputusanBaru,
    ));
  }
  if (b.bacaanSelesai > 0) {
    tambah(MetrikAnalitik(
      kelompok: 'Pengetahuan',
      nama: 'Bacaan selesai',
      nilai: '${b.bacaanSelesai} bacaan',
      sumber: 'tabel bacaan (status selesai), $label terakhir',
      angka: b.bacaanSelesai,
    ));
  }
  if (b.kartuDiulang > 0) {
    tambah(MetrikAnalitik(
      kelompok: 'Pengetahuan',
      nama: 'Kartu ulangan dikerjakan',
      nilai: '${b.kartuDiulang} kartu',
      sumber: 'tabel kartu_ulangan (terakhir_diulang), $label terakhir',
      angka: b.kartuDiulang,
    ));
  }
  if (b.hafalanBaru > 0) {
    tambah(MetrikAnalitik(
      kelompok: 'Ibadah',
      nama: 'Hafalan ditambah',
      nilai: '${b.hafalanBaru}',
      sumber: 'tabel hafalan, $label terakhir',
      angka: b.hafalanBaru,
    ));
  }
  if (b.zakatSen > 0) {
    tambah(MetrikAnalitik(
      kelompok: 'Ibadah',
      nama: 'Zakat & sedekah',
      nilai: '${b.zakatSen}',
      sumber: 'tabel zakat_sedekah (jumlah_sen), $label terakhir',
      angka: b.zakatSen,
      satuanUangSen: b.zakatSen,
    ));
  }
  if (b.perawatanAset > 0) {
    tambah(MetrikAnalitik(
      kelompok: 'Rumah & aset',
      nama: 'Perawatan aset',
      nilai: '${b.perawatanAset} kali',
      sumber: 'tabel riwayat_perawatan_aset, $label terakhir',
      angka: b.perawatanAset,
    ));
  }
  if (b.kekayaanBersihSen != null) {
    tambah(MetrikAnalitik(
      kelompok: 'Rumah & aset',
      nama: 'Kekayaan bersih',
      nilai: '${b.kekayaanBersihSen}',
      sumber: 'aset + kewajiban (nilai terakhir), saat ini',
      angka: b.kekayaanBersihSen,
      satuanUangSen: b.kekayaanBersihSen,
    ));
  }
  if (b.langgananAktif > 0) {
    tambah(MetrikAnalitik(
      kelompok: 'Uang',
      nama: 'Langganan aktif',
      nilai: '${b.langgananAktif} langganan',
      sumber: 'tabel langganan (aktif), saat ini',
      angka: b.langgananAktif,
    ));
  }
  return r;
}

/// Kelompok yang tersedia pada satu bahan (dipakai untuk penyaring di layar).
List<String> kelompokAnalitik(List<MetrikAnalitik> metrik) {
  final set = <String>{};
  for (final m in metrik) {
    set.add(m.kelompok);
  }
  final urut = set.toList()..sort();
  return urut;
}
