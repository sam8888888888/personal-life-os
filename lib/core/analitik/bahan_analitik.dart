/// Bahan mentah untuk analitik lintas modul (FR-141), ringkasan pekan (FR-144),
/// dan laporan bulanan (FR-145).
///
/// Satu tipe dipakai bertiga supaya angkanya pasti sama di ketiga tempat —
/// tidak ada "angka misterius" yang berbeda antar layar.
///
/// Semua hitungan BERAT (kueri basis data) dilakukan repositori; berkas ini
/// murni angka tanpa Flutter/DB, jadi bisa diuji tanpa perangkat.
library;

class BahanAnalitik {
  const BahanAnalitik({
    required this.dari,
    required this.sampai,
    this.hari = 0,
    // uang
    this.tagihanBaru = 0,
    this.tagihanLunas = 0,
    this.totalTagihanSen = 0,
    this.totalBayarSen = 0,
    this.transaksiBaru = 0,
    this.pengeluaranSen = 0,
    this.pemasukanSen = 0,
    // tujuan & tugas
    this.tujuanSelesai = 0,
    this.tujuanBaru = 0,
    this.tugasSelesai = 0,
    this.tugasBaru = 0,
    this.tugasTerbuka = 0,
    // kesehatan
    this.hariAktivitas = 0,
    this.menitAktivitas = 0,
    this.menitTidur = 0,
    this.malamTidurTercatat = 0,
    this.ukuranTubuh = 0,
    this.beratAkhirGram,
    this.catatanMedis = 0,
    this.janjiKesehatan = 0,
    // pengetahuan
    this.catatanPengetahuan = 0,
    this.keputusanBaru = 0,
    this.bacaanSelesai = 0,
    this.kartuDiulang = 0,
    this.pembelajaranMenit = 0,
    // ibadah
    this.hafalanBaru = 0,
    this.zakatSen = 0,
    // rumah & aset
    this.perawatanAset = 0,
    this.biayaPerawatanSen = 0,
    this.dokumenKedaluwarsa = 0,
    // langganan & kekayaan
    this.langgananAktif = 0,
    this.biayaLanggananSen = 0,
    this.kekayaanBersihSen,
    this.totalAsetSen,
    this.totalKewajibanSen,
  });

  final DateTime dari;
  final DateTime sampai;
  final int hari;

  final int tagihanBaru;
  final int tagihanLunas;
  final int totalTagihanSen;
  final int totalBayarSen;
  final int transaksiBaru;
  final int pengeluaranSen;
  final int pemasukanSen;

  final int tujuanSelesai;
  final int tujuanBaru;
  final int tugasSelesai;
  final int tugasBaru;
  final int tugasTerbuka;

  final int hariAktivitas;
  final int menitAktivitas;
  final int menitTidur;
  final int malamTidurTercatat;
  final int ukuranTubuh;
  final num? beratAkhirGram;
  final int catatanMedis;
  final int janjiKesehatan;

  final int catatanPengetahuan;
  final int keputusanBaru;
  final int bacaanSelesai;
  final int kartuDiulang;
  final int pembelajaranMenit;

  final int hafalanBaru;
  final int zakatSen;

  final int perawatanAset;
  final int biayaPerawatanSen;
  final int dokumenKedaluwarsa;

  final int langgananAktif;
  final int biayaLanggananSen;
  final int? kekayaanBersihSen;
  final int? totalAsetSen;
  final int? totalKewajibanSen;

  /// Rata-rata menit tidur per malam yang tercatat.
  num? get tidurRataMenit =>
      malamTidurTercatat == 0 ? null : menitTidur / malamTidurTercatat;

  /// Selisih uang masuk − keluar pada periode ini.
  int get arusKasSen => pemasukanSen - pengeluaranSen;

  static BahanAnalitik kosong(DateTime dari, DateTime sampai, {int hari = 0}) =>
      BahanAnalitik(dari: dari, sampai: sampai, hari: hari);
}
