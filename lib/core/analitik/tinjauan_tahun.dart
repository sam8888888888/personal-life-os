/// FR-146 — Annual Life Review ("Your Year in Life").
///
/// Kriteria terima PRD: "Membutuhkan data ≥6 bulan; hasil hanya ditampilkan bila
/// datanya cukup (**bukan dibuat-buat**)". Karena itu [TinjauanTahun.cukupData]
/// diperiksa lebih dulu, dan bila belum cukup hanya pesan jujur yang diberikan —
/// angka tidak dipaksa muncul.
///
/// Angka diambil dari [BahanAnalitik] yang sama dengan analitik (FR-141),
/// tinjauan pekan (FR-144) dan laporan bulanan (FR-145), supaya tidak ada angka
/// berbeda antar layar.
library;

import 'bahan_analitik.dart';

/// Satu fakta pada sebuah pilar.
class FaktaTahun {
  const FaktaTahun({required this.label, required this.nilai, this.satuanUangSen});

  final String label;
  final String nilai;

  /// Bila terisi, [nilai] diabaikan tampilan dan yang dipakai angka sen ini.
  final int? satuanUangSen;
}

/// Satu pilar kehidupan (Keuangan, Kesehatan, Ibadah, …).
class PilarTahun {
  const PilarTahun({
    required this.nama,
    required this.ikon,
    required this.fakta,
    this.catatan,
  });

  final String nama;
  final String ikon;
  final List<FaktaTahun> fakta;

  /// Catatan jujur bila ada bagian yang belum bisa dihitung.
  final String? catatan;

  bool get adaIsi => fakta.any((f) => f.nilai != '—' || f.satuanUangSen != null);
}

/// Hasil tinjauan satu tahun.
class TinjauanTahun {
  const TinjauanTahun({
    required this.tahun,
    required this.cukupData,
    required this.pesan,
    required this.pilar,
    required this.bulanTercatat,
  });

  final int tahun;
  final bool cukupData;

  /// Pesan yang selalu ada: alasannya bila belum cukup, atau ringkasannya.
  final String pesan;
  final List<PilarTahun> pilar;
  final int bulanTercatat;
}

/// Susun tinjauan tahun [tahun] dari [bahan] (rentang 1 Jan–31 Des tahun itu)
/// dan [bulanTercatat] = jumlah bulan dalam tahun itu yang punya catatan.
TinjauanTahun susunTinjauanTahun({
  required int tahun,
  required BahanAnalitik bahan,
  required int bulanTercatat,
  int minimalBulan = 6,
}) {
  if (bulanTercatat < minimalBulan) {
    return TinjauanTahun(
      tahun: tahun,
      cukupData: false,
      bulanTercatat: bulanTercatat,
      pesan:
          'Tinjauan tahunan baru bisa ditampilkan setelah ada data minimal '
          '$minimalBulan bulan. Sepanjang $tahun ini baru $bulanTercatat bulan '
          'yang punya catatan — angkanya belum ditampilkan supaya tidak menyesatkan.',
      pilar: const <PilarTahun>[],
    );
  }

  final pengeluaranPerBulan =
      bulanTercatat == 0 ? 0 : (bahan.pengeluaranSen / bulanTercatat).round();
  final menitTidurRata = bahan.tidurRataMenit;

  final keuangan = PilarTahun(
    nama: 'Keuangan',
    ikon: 'uang',
    fakta: [
      FaktaTahun(label: 'Uang keluar', nilai: '', satuanUangSen: bahan.pengeluaranSen),
      FaktaTahun(label: 'Uang masuk', nilai: '', satuanUangSen: bahan.pemasukanSen),
      FaktaTahun(
          label: 'Selisih masuk − keluar',
          nilai: '',
          satuanUangSen: bahan.arusKasSen),
      FaktaTahun(label: 'Pengeluaran rata-rata per bulan', nilai: '', satuanUangSen: pengeluaranPerBulan),
      FaktaTahun(label: 'Tagihan dibayar', nilai: '${bahan.tagihanLunas}'),
      FaktaTahun(label: 'Transaksi tercatat', nilai: '${bahan.transaksiBaru}'),
    ],
  );

  final kesehatan = PilarTahun(
    nama: 'Kesehatan',
    ikon: 'kesehatan',
    fakta: [
      FaktaTahun(label: 'Malam tidur tercatat', nilai: '${bahan.malamTidurTercatat}'),
      FaktaTahun(
        label: 'Rata-rata tidur per malam',
        nilai: menitTidurRata == null
            ? '—'
            : '${(menitTidurRata / 60).toStringAsFixed(1)} jam',
      ),
      FaktaTahun(label: 'Hari beraktivitas', nilai: '${bahan.hariAktivitas}'),
      FaktaTahun(label: 'Total menit aktivitas', nilai: '${bahan.menitAktivitas}'),
      FaktaTahun(label: 'Catatan medis', nilai: '${bahan.catatanMedis}'),
    ],
  );

  final ibadah = PilarTahun(
    nama: 'Ibadah',
    ikon: 'ibadah',
    fakta: [
      FaktaTahun(label: 'Hafalan baru', nilai: '${bahan.hafalanBaru}'),
      FaktaTahun(label: 'Zakat tersalurkan', nilai: '', satuanUangSen: bahan.zakatSen),
    ],
  );

  final pengetahuan = PilarTahun(
    nama: 'Pengetahuan',
    ikon: 'pengetahuan',
    fakta: [
      FaktaTahun(label: 'Catatan dibuat', nilai: '${bahan.catatanPengetahuan}'),
      FaktaTahun(label: 'Bacaan selesai', nilai: '${bahan.bacaanSelesai}'),
      FaktaTahun(label: 'Menit belajar', nilai: '${bahan.pembelajaranMenit}'),
      FaktaTahun(label: 'Kartu diulang', nilai: '${bahan.kartuDiulang}'),
    ],
  );

  final ritme = PilarTahun(
    nama: 'Ritme & tujuan',
    ikon: 'ritme',
    fakta: [
      FaktaTahun(label: 'Tujuan selesai', nilai: '${bahan.tujuanSelesai}'),
      FaktaTahun(label: 'Tugas selesai', nilai: '${bahan.tugasSelesai}'),
      FaktaTahun(label: 'Tugas masih terbuka', nilai: '${bahan.tugasTerbuka}'),
    ],
  );

  final rumah = PilarTahun(
    nama: 'Rumah & aset',
    ikon: 'rumah',
    fakta: [
      FaktaTahun(label: 'Perawatan aset', nilai: '${bahan.perawatanAset}'),
      FaktaTahun(label: 'Biaya perawatan', nilai: '', satuanUangSen: bahan.biayaPerawatanSen),
      FaktaTahun(
        label: 'Kekayaan bersih',
        nilai: bahan.kekayaanBersihSen == null ? '—' : '',
        satuanUangSen: bahan.kekayaanBersihSen,
      ),
    ],
    catatan: bahan.kekayaanBersihSen == null
        ? 'Kekayaan bersih belum bisa dihitung: aset/kewajiban belum diisi.'
        : null,
  );

  final pilar = [keuangan, kesehatan, ibadah, pengetahuan, ritme, rumah]
      .where((p) => p.adaIsi)
      .toList();

  return TinjauanTahun(
    tahun: tahun,
    cukupData: true,
    bulanTercatat: bulanTercatat,
    pesan:
        'Angka sepanjang $tahun dari $bulanTercatat bulan yang punya catatan. '
        'Sumbernya tabel yang sama dengan analitik & laporan bulanan.',
    pilar: pilar,
  );
}
