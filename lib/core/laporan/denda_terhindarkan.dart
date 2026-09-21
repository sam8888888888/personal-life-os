/// FR-34 — Kalkulator denda terhindarkan (pure, tanpa I/O).
///
/// Gagasan: tiap kali tagihan dibayar TEPAT WAKTU, uang denda/bunga yang
/// seharusnya keluar tidak jadi keluar. Modul ini menghitungnya.
///
/// Aturan penting (supaya angkanya jujur, bukan karangan):
///   * Hanya tagihan yang PUNYA aturan denda (persen/bulan atau nominal tetap)
///     yang dihitung. Tagihan tanpa aturan denda dilewati dan didaftarkan di
///     [tagihanTanpaAturan] supaya pengguna bisa mengisinya.
///   * Aturan denda per tagihan berlaku mulai HARI aturan itu dibuat
///     ([ditetapkanPada]); pelunasan pada hari yang sama ikut dihitung.
///   * Bila keduanya diisi (persen & nominal), dipakai yang lebih besar —
///     inilah yang biasanya berlaku di bank (denda minimum).
library;

/// Aturan denda satu tagihan.
class AturanDenda {
  const AturanDenda({
    required this.persenPerBulan,
    required this.nominalSen,
    this.ditetapkanPada,
  });

  /// Denda sebagai persen dari nominal (mis. 2 = 2% per bulan).
  final int persenPerBulan;

  /// Denda nominal tetap (mis. Rp 25.000).
  final int nominalSen;

  /// Sejak kapan aturan ini berlaku (pembayaran sebelum tanggal ini tidak
  /// dihitung). Null = berlaku untuk semua riwayat.
  final DateTime? ditetapkanPada;

  bool get ada => persenPerBulan > 0 || nominalSen > 0;

  /// Denda yang berlaku untuk [nominalTagihanSen].
  int dendaUntuk(int nominalTagihanSen) {
    final persenSen = (nominalTagihanSen * persenPerBulan) ~/ 100;
    return persenSen > nominalSen ? persenSen : nominalSen;
  }
}

/// Satu pembayaran tepat waktu yang menghasilkan penghematan.
class HematDenda {
  const HematDenda({
    required this.namaTagihan,
    required this.tanggalBayar,
    required this.nominalSen,
    required this.dendaTerhindarSen,
  });

  final String namaTagihan;
  final DateTime tanggalBayar;
  final int nominalSen;
  final int dendaTerhindarSen;
}

/// Hasil hitungan denda terhindarkan.
class HasilDendaTerhindarkan {
  const HasilDendaTerhindarkan({
    required this.daftar,
    required this.tagihanTanpaAturan,
    required this.totalSen,
    required this.bulanIniSen,
  });

  final List<HematDenda> daftar;

  /// Nama tagihan yang belum punya aturan denda (belum bisa dihitung).
  final List<String> tagihanTanpaAturan;

  final int totalSen;
  final int bulanIniSen;

  bool get adaAturan => daftar.isNotEmpty;
}

/// Hitung denda yang terhindar dari riwayat pembayaran.
///
/// [aturan] = peta nama tagihan → aturan denda.
List<HematDenda> _hitung(List<({String nama, DateTime tanggalBayar, int nominalSen, bool tepatWaktu})> riwayat,
    Map<String, AturanDenda> aturan) {
  final hasil = <HematDenda>[];
  for (final r in riwayat) {
    if (!r.tepatWaktu) continue;
    final a = aturan[r.nama];
    if (a == null || !a.ada) continue;
    if (a.ditetapkanPada != null && r.tanggalBayar.isBefore(a.ditetapkanPada!)) {
      continue;
    }
    hasil.add(HematDenda(
      namaTagihan: r.nama,
      tanggalBayar: r.tanggalBayar,
      nominalSen: r.nominalSen,
      dendaTerhindarSen: a.dendaUntuk(r.nominalSen),
    ));
  }
  hasil.sort((x, y) => y.tanggalBayar.compareTo(x.tanggalBayar));
  return hasil;
}

HasilDendaTerhindarkan hitungDendaTerhindarkan({
  required List<({String nama, DateTime tanggalBayar, int nominalSen, bool tepatWaktu})> riwayat,
  required Map<String, AturanDenda> aturan,
  required List<String> semuaNamaTagihan,
  DateTime? acuan,
}) {
  final daftar = _hitung(riwayat, aturan);
  final kini = acuan ?? DateTime.now();
  var total = 0;
  var bulanIni = 0;
  for (final h in daftar) {
    total += h.dendaTerhindarSen;
    if (h.tanggalBayar.year == kini.year && h.tanggalBayar.month == kini.month) {
      bulanIni += h.dendaTerhindarSen;
    }
  }
  final tanpaAturan = semuaNamaTagihan
      .where((n) => !(aturan[n]?.ada ?? false))
      .toList()
    ..sort();
  return HasilDendaTerhindarkan(
    daftar: daftar,
    tagihanTanpaAturan: tanpaAturan,
    totalSen: total,
    bulanIniSen: bulanIni,
  );
}

// ---------------------------------------------------------------------------
// Penyimpanan aturan (memakai tabel pengaturan yang sudah ada).
//
// ponytail: aturan disimpan sebagai teks "nama|persen|nominal|stempel" per
// baris di satu kunci pengaturan, bukan tabel baru — cukup untuk kebutuhan
// sekarang dan tidak menambah perubahan skema. Jalur upgrade: bila kelak perlu
// disinkronkan antar HP, pindahkan ke tabel sendiri + ikutkan di sinkron.
// ---------------------------------------------------------------------------

String kunciAturanDenda(String namaTagihan) =>
    'denda_tagihan:${namaTagihan.trim().toLowerCase()}';

/// Teks penyimpanan: "persen|nominalSen|stempelEpochMs" (stempel boleh kosong).
String aturanKeTeks(AturanDenda a) =>
    '${a.persenPerBulan}|${a.nominalSen}|'
    '${a.ditetapkanPada?.millisecondsSinceEpoch ?? ''}';

AturanDenda? teksKeAturan(String? teks) {
  if (teks == null || teks.trim().isEmpty) return null;
  final bagian = teks.split('|');
  if (bagian.length < 2) return null;
  final persen = int.tryParse(bagian[0]) ?? 0;
  final nominal = int.tryParse(bagian[1]) ?? 0;
  final stempel = bagian.length > 2 && bagian[2].isNotEmpty
      ? int.tryParse(bagian[2])
      : null;
  return AturanDenda(
    persenPerBulan: persen,
    nominalSen: nominal,
    ditetapkanPada: stempel == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(stempel),
  );
}
