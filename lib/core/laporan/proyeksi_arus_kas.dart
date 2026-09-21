/// FR-30 — Proyeksi arus kas 3 bulan ke depan (pure, tanpa I/O).
///
/// Menjawab pertanyaan: "tiga bulan ke depan, berapa uang yang akan keluar
/// untuk tagihan & langganan?" Datanya dari tagihan aktif (frekuensi apa pun,
/// termasuk mingguan & tahunan) + langganan yang masih berjalan.
///
/// Aturan:
///   * bulan berjalan ikut dihitung (mulai dari tanggal [mulai] ke depan),
///   * tagihan yang jatuh tempo lampau tetap diproyeksikan ke jadwal
///     berikutnya (memakai mesin frekuensi yang sudah dipakai pengingat),
///   * frekuensi `sekali` hanya dihitung bila jatuh temponya di dalam rentang,
///   * yang nonaktif / langganan pause-berhenti tidak dihitung.
library;

import '../../data/database/database.dart';
import '../../data/model/enums.dart';
import '../utils/tanggal_utils.dart';

/// Satu bulan dalam proyeksi.
class BarisProyeksi {
  const BarisProyeksi({
    required this.bulan,
    required this.jumlahTagihan,
    required this.jumlahLangganan,
    required this.totalTagihanSen,
    required this.totalLanggananSen,
  });

  final DateTime bulan;
  final int jumlahTagihan;
  final int jumlahLangganan;
  final int totalTagihanSen;
  final int totalLanggananSen;

  int get totalSen => totalTagihanSen + totalLanggananSen;
  int get jumlahButir => jumlahTagihan + jumlahLangganan;
}

/// Hitung proyeksi [jumlahBulan] bulan mulai bulan dari [mulai].
List<BarisProyeksi> proyeksiArusKas({
  required List<TagihanData> tagihan,
  List<LanggananData> langganan = const <LanggananData>[],
  required DateTime mulai,
  int jumlahBulan = 3,
}) {
  final awal = DateTime(mulai.year, mulai.month, mulai.day);
  final bulanAwal = DateTime(awal.year, awal.month, 1);
  final bulanAkhir = DateTime(awal.year, awal.month + jumlahBulan - 1, 1);
  final batasAkhir = DateTime(bulanAkhir.year, bulanAkhir.month + 1, 0); // hari terakhir

  final peta = <int, List<int>>{}; // indeks bulan ke-0..n-1 → [tagihan, langganan, senTagihan, senLangganan]
  List<int> slot(DateTime t) {
    final idx = (t.year - bulanAwal.year) * 12 + (t.month - bulanAwal.month);
    if (idx < 0 || idx >= jumlahBulan) throw StateError('di luar rentang');
    return peta.putIfAbsent(idx, () => [0, 0, 0, 0]);
  }

  bool dalamRentang(DateTime t) =>
      !t.isBefore(awal) && !t.isAfter(batasAkhir);

  // --- tagihan
  for (final t in tagihan) {
    if (!t.statusAktif) continue;
    final frek = Frekuensi.dariDb(t.frekuensi);
    final nominal = t.jumlahSen ?? 0;
    var tgl = DateTime(t.jatuhTempo.year, t.jatuhTempo.month, t.jatuhTempo.day);
    if (frek == Frekuensi.sekali) {
      if (dalamRentang(tgl)) {
        final s = slot(tgl);
        s[0] += 1;
        s[2] += nominal;
      }
      continue;
    }
    // Maju ke jadwal pertama yang masih di depan (batas 600 langkah ~ 50 tahun bulanan).
    var langkah = 0;
    while (tgl.isBefore(awal) && langkah < 600) {
      tgl = periodeBerikutnya(tgl, frek, kustomHariN: t.kustomHariN);
      langkah++;
    }
    while (!tgl.isAfter(batasAkhir) && langkah < 1200) {
      final s = slot(tgl);
      s[0] += 1;
      s[2] += nominal;
      tgl = periodeBerikutnya(tgl, frek, kustomHariN: t.kustomHariN);
      langkah++;
    }
  }

  // --- langganan
  for (final l in langganan) {
    if (StatusLangganan.dariDb(l.status) != StatusLangganan.aktif) continue;
    final frek = Frekuensi.dariDb(l.siklus);
    final nominal = l.nominalSen;
    var tgl = DateTime(l.tanggalMulai.year, l.tanggalMulai.month, l.tanggalMulai.day);
    if (frek == Frekuensi.sekali) {
      if (dalamRentang(tgl)) {
        final s = slot(tgl);
        s[1] += 1;
        s[3] += nominal;
      }
      continue;
    }
    var langkah = 0;
    while (tgl.isBefore(awal) && langkah < 600) {
      tgl = periodeBerikutnya(tgl, frek);
      langkah++;
    }
    while (!tgl.isAfter(batasAkhir) && langkah < 1200) {
      final s = slot(tgl);
      s[1] += 1;
      s[3] += nominal;
      tgl = periodeBerikutnya(tgl, frek);
      langkah++;
    }
  }

  return List<BarisProyeksi>.generate(jumlahBulan, (i) {
    final s = peta[i] ?? const [0, 0, 0, 0];
    return BarisProyeksi(
      bulan: DateTime(bulanAwal.year, bulanAwal.month + i, 1),
      jumlahTagihan: s[0],
      jumlahLangganan: s[1],
      totalTagihanSen: s[2],
      totalLanggananSen: s[3],
    );
  });
}

/// Total seluruh rentang proyeksi (untuk baris ringkas di layar).
int totalProyeksiSen(List<BarisProyeksi> baris) =>
    baris.fold<int>(0, (a, b) => a + b.totalSen);

/// Bulan dengan beban terbesar (null bila semua kosong).
BarisProyeksi? bulanTerberat(List<BarisProyeksi> baris) {
  if (baris.isEmpty) return null;
  var terbesar = baris.first;
  for (final b in baris) {
    if (b.totalSen > terbesar.totalSen) terbesar = b;
  }
  return terbesar.totalSen == 0 ? null : terbesar;
}
