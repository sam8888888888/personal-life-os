/// Logika murni Home & Asset OS (FR-124…FR-127).
///
/// Sengaja TANPA Flutter dan TANPA basis data: semua hitungan bisa diuji
/// langsung, dan layar hanya menampilkan hasilnya.
///
/// Nada teks mengikuti PRD §III-11: menjelaskan angka & dasar hitungannya,
/// tidak menilai pengguna, dan tidak ada klaim mutlak (FR-127: "estimasi
/// menampilkan dasar perhitungan; tidak ada klaim mutlak").
library;

/// Jenis aset fisik yang dikenali (FR-124).
///
/// Dipisah dari [JenisAsetKeuangan] karena yang ini benda berwujud: punya
/// tanggal beli, nomor seri, garansi, dan masa pakai.
enum JenisAsetFisik {
  rumah('rumah', 'Rumah / Properti'),
  kendaraan('kendaraan', 'Kendaraan'),
  perangkat('perangkat', 'Perangkat / Gadget'),
  furnitur('furnitur', 'Furnitur'),
  elektronik('elektronik', 'Elektronik'),
  lain('lain', 'Lain-lain');

  const JenisAsetFisik(this.kode, this.label);

  /// Nilai yang disimpan di kolom `aset.jenis`.
  final String kode;
  final String label;

  /// Baca dari kolom `jenis`; jenis aset keuangan (kas/bank/investasi) → null.
  static JenisAsetFisik? dariKode(String kode) {
    for (final j in values) {
      if (j.kode == kode) return j;
    }
    // 'properti' berasal dari daftar jenis aset keuangan yang sudah ada.
    if (kode == 'properti') return JenisAsetFisik.rumah;
    return null;
  }
}

/// Status garansi satu aset (FR-126).
enum StatusGaransi {
  /// Belum ada tanggal garansi diisi.
  tidakAda,

  /// Masih berlaku dan masih jauh.
  aktif,

  /// Masih berlaku tetapi tinggal [ambangHari] hari lagi atau kurang.
  segeraBerakhir,

  /// Sudah lewat tanggalnya.
  berakhir,
}

/// Hasil pemeriksaan garansi: status + sisa hari (negatif = sudah lewat).
class HasilGaransi {
  const HasilGaransi({required this.status, required this.sisaHari});

  final StatusGaransi status;
  final int sisaHari;

  /// Keterangan siap tampil — menyebut angkanya, bukan kalimat umum.
  String get keterangan => switch (status) {
        StatusGaransi.tidakAda => 'Tanggal garansi belum diisi',
        StatusGaransi.aktif => 'Garansi berlaku · sisa $sisaHari hari',
        StatusGaransi.segeraBerakhir => 'Garansi berakhir $sisaHari hari lagi',
        StatusGaransi.berakhir => 'Garansi sudah berakhir $sisaHari hari lalu',
      };

  bool get perluPerhatian =>
      status == StatusGaransi.segeraBerakhir || status == StatusGaransi.berakhir;
}

/// Ambang "garansi hampir berakhir" (hari). Dipakai FR-126 untuk Perhatian.
const int ambangGaransiHari = 30;

/// Periksa garansi [garansiSampai] pada waktu [sekarang].
///
/// [ambangHari] boleh diubah (mis. 7 hari) — bawaan [ambangGaransiHari].
HasilGaransi periksaGaransi(
  DateTime? garansiSampai,
  DateTime sekarang, {
  int ambangHari = ambangGaransiHari,
}) {
  if (garansiSampai == null) {
    return const HasilGaransi(status: StatusGaransi.tidakAda, sisaHari: 0);
  }
  final sisa = bedaHari(sekarang, garansiSampai);
  if (sisa < 0) {
    return HasilGaransi(status: StatusGaransi.berakhir, sisaHari: -sisa);
  }
  if (sisa <= ambangHari) {
    return HasilGaransi(status: StatusGaransi.segeraBerakhir, sisaHari: sisa);
  }
  return HasilGaransi(status: StatusGaransi.aktif, sisaHari: sisa);
}

/// Perkiraan umur pakai & waktu penggantian (FR-127).
///
/// Semua angka adalah **perkiraan dari isian pengguna** (tanggal beli, masa
/// pakai, harga beli) — [dasar] wajib ditampilkan supaya pengguna tahu dari
/// mana angkanya datang.
class PerkiraanUmurPakai {
  const PerkiraanUmurPakai({
    required this.perkiraanGanti,
    required this.sisaBulan,
    required this.danaSisihPerBulanSen,
    required this.dasar,
  });

  /// Tanggal perkiraan penggantian (tanggal beli + masa pakai).
  final DateTime perkiraanGanti;

  /// Sisa bulan menuju perkiraan ganti; negatif = sudah lewat.
  final int sisaBulan;

  /// Saran menyisihkan dana per bulan (harga beli ÷ masa pakai, dibulatkan ke
  /// atas). null = harga beli belum diisi.
  final int? danaSisihPerBulanSen;

  /// Dasar perhitungan dalam bahasa manusia, mis.
  /// "Beli 12 Jan 2023 + masa pakai 60 bulan = perkiraan ganti 12 Jan 2028".
  final String dasar;

  bool get sudahLewat => sisaBulan < 0;
}

/// Hitung perkiraan umur pakai. null bila data belum cukup
/// (tanggal beli & masa pakai dua-duanya wajib).
PerkiraanUmurPakai? perkiraanUmurPakai({
  DateTime? tanggalBeli,
  int? masaPakaiBulan,
  int? hargaBeliSen,
  required DateTime sekarang,
}) {
  if (tanggalBeli == null || masaPakaiBulan == null || masaPakaiBulan <= 0) {
    return null;
  }
  final ganti = tambahBulan(tanggalBeli, masaPakaiBulan);
  final sisa = bulanAntara(sekarang, ganti);
  final dana = (hargaBeliSen == null || hargaBeliSen <= 0)
      ? null
      : ((hargaBeliSen + masaPakaiBulan - 1) ~/ masaPakaiBulan);
  return PerkiraanUmurPakai(
    perkiraanGanti: ganti,
    sisaBulan: sisa,
    danaSisihPerBulanSen: dana,
    dasar: 'Beli ${fmtTanggal(tanggalBeli)} + masa pakai $masaPakaiBulan bulan '
        '= perkiraan ganti ${fmtTanggal(ganti)}',
  );
}

/// Ringkasan biaya perawatan (FR-125).
class RingkasanBiayaPerawatan {
  const RingkasanBiayaPerawatan({
    required this.totalSen,
    required this.jumlahCatatan,
    required this.tertautPengeluaran,
    required this.rataPerTahunSen,
  });

  final int totalSen;
  final int jumlahCatatan;

  /// Berapa catatan yang biayanya sudah dikaitkan ke transaksi pengeluaran.
  final int tertautPengeluaran;

  /// Rata-rata biaya per tahun (dihitung dari rentang tanggal catatan);
  /// null bila catatan kurang dari dua atau rentangnya nol.
  final int? rataPerTahunSen;

  String get keterangan => jumlahCatatan == 0
      ? 'Belum ada catatan perawatan'
      : '$jumlahCatatan catatan · $tertautPengeluaran tertaut pengeluaran';
}

/// Biaya perawatan sederhana: satu catatan = tanggal + biaya.
class CatatanBiaya {
  const CatatanBiaya({
    required this.tanggal,
    required this.biayaSen,
    this.tertaut = false,
  });

  final DateTime tanggal;
  final int biayaSen;

  /// true = biayanya sudah dikaitkan ke transaksi pengeluaran (FR-125).
  final bool tertaut;
}

/// Jumlahkan biaya perawatan & hitung rata-rata per tahun.
RingkasanBiayaPerawatan ringkasBiayaPerawatan(List<CatatanBiaya> catatan) {
  var total = 0;
  for (final c in catatan) {
    if (c.biayaSen > 0) total += c.biayaSen;
  }
  int? rata;
  if (catatan.length >= 2) {
    final tanggal = catatan.map((c) => c.tanggal).toList()
      ..sort((a, b) => a.compareTo(b));
    final hari = bedaHari(tanggal.first, tanggal.last).abs();
    if (hari > 0) {
      rata = (total * 365 / hari).round();
    }
  }
  return RingkasanBiayaPerawatan(
    totalSen: total,
    jumlahCatatan: catatan.length,
    tertautPengeluaran: catatan.where((c) => c.tertaut).length,
    rataPerTahunSen: rata,
  );
}

// ---------------------------------------------------------------------------
// Bantuan tanggal (dibuat lokal supaya berkas ini tidak bergantung Flutter)
// ---------------------------------------------------------------------------

/// Selisih hari kalender [dari] → [ke] (jam diabaikan).
int bedaHari(DateTime dari, DateTime ke) {
  final a = DateTime(dari.year, dari.month, dari.day);
  final b = DateTime(ke.year, ke.month, ke.day);
  return b.difference(a).inDays;
}

/// Tambah [bulan] bulan; tanggal yang tidak ada (mis. 31 → 30) dijepit ke akhir
/// bulan, seperti kebiasaan kalender.
DateTime tambahBulan(DateTime awal, int bulan) {
  final totalBulan = awal.month - 1 + bulan;
  final tahun = awal.year + (totalBulan ~/ 12);
  final bln = totalBulan % 12 + 1;
  final akhirBulan = DateTime(tahun, bln + 1, 0).day;
  final hari = awal.day <= akhirBulan ? awal.day : akhirBulan;
  return DateTime(tahun, bln, hari);
}

/// Selisih bulan penuh antara [dari] dan [ke] (negatif bila [ke] lebih dulu).
int bulanAntara(DateTime dari, DateTime ke) {
  var bulan = (ke.year - dari.year) * 12 + (ke.month - dari.month);
  if (ke.day < dari.day) bulan -= 1;
  return bulan;
}

const List<String> _namaBulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Format tanggal aman (tanpa locale) — mis. "12 Jan 2023".
String fmtTanggal(DateTime d) =>
    '${d.day} ${_namaBulan[d.month - 1]} ${d.year}';

/// Format rupiah dari sen — mis. "Rp 12.500.000".
String fmtRupiah(int sen) {
  final rupiah = sen ~/ 100;
  final teks = rupiah.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < teks.length; i++) {
    if (i > 0 && (teks.length - i) % 3 == 0) buf.write('.');
    buf.write(teks[i]);
  }
  return '${sen < 0 ? '-' : ''}Rp $buf';
}
