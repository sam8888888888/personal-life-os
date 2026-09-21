/// FR-33 — "Uang aman sampai gajian" (pure, tanpa I/O).
///
/// Pertanyaan yang dijawab: dari hari ini sampai tanggal gajian berikutnya,
/// berapa uang yang akan keluar untuk tagihan & langganan, dan berapa sisa
/// saldo bila pengguna mengisi saldo sekarang?
///
/// Aturan:
///   * Rentang = hari ini s/d tanggal gajian berikutnya (bila tanggal gajian
///     bulan ini sudah lewat, dipakai bulan depan).
///   * Tagihan aktif yang jatuh tempo di rentang ikut dihitung.
///   * Tagihan yang SUDAH lewat jatuh tempo dan belum dibayar tetap dihitung
///     (uangnya masih perlu disiapkan) dan ditandai "sudah lewat".
///   * Tanggal gajian 29/30/31 menyesuaikan jumlah hari bulan berjalan
///     (mis. 31 Februari → 28/29 Februari).
library;

import '../../data/database/database.dart';
import '../../data/model/enums.dart';
import '../utils/tanggal_utils.dart';

/// Satu butir yang perlu dibayar sebelum gajian.
class ButirGajian {
  const ButirGajian({
    required this.nama,
    required this.tanggal,
    required this.jumlahSen,
    this.sudahLewat = false,
    this.langganan = false,
  });

  final String nama;
  final DateTime tanggal;
  final int jumlahSen;
  final bool sudahLewat;
  final bool langganan;
}

/// Hasil hitungan "aman sampai gajian".
class HasilAmanGajian {
  const HasilAmanGajian({
    required this.hariIni,
    required this.tanggalGajian,
    required this.butir,
    this.saldoSen,
  });

  final DateTime hariIni;
  final DateTime tanggalGajian;
  final List<ButirGajian> butir;

  /// Saldo sekarang (opsional; null = pengguna belum mengisi).
  final int? saldoSen;

  int get jumlahButir => butir.length;
  int get totalSen => butir.fold<int>(0, (a, b) => a + b.jumlahSen);

  /// Sisa saldo setelah semua tagihan dibayar (null bila saldo belum diisi).
  int? get sisaSen => saldoSen == null ? null : saldoSen! - totalSen;

  /// Berapa hari lagi sampai gajian.
  int get hariKeGajian => selisihHari(hariIni, tanggalGajian);

  /// Butir yang jatuh temponya sebelum hari ini dan belum dibayar.
  List<ButirGajian> get sudahLewat =>
      butir.where((b) => b.sudahLewat).toList();
}

/// Tanggal gajian berikutnya menurut [tanggalGajian] (1–31).
DateTime gajianBerikutnya(DateTime hariIni, int tanggalGajian) {
  final tgl = tanggalGajian.clamp(1, 31);
  DateTime diBulan(int tahun, int bulan) {
    final hariMaks = DateTime(tahun, bulan + 1, 0).day;
    return DateTime(tahun, bulan, tgl > hariMaks ? hariMaks : tgl);
  }

  final bulanIni = diBulan(hariIni.year, hariIni.month);
  if (!bulanIni.isBefore(DateTime(hariIni.year, hariIni.month, hariIni.day))) {
    return bulanIni;
  }
  return diBulan(hariIni.year, hariIni.month + 1);
}

/// Hitung butir tagihan & langganan yang jatuh tempo sampai gajian.
HasilAmanGajian hitungAmanSampaiGajian({
  required List<TagihanData> tagihan,
  List<LanggananData> langganan = const <LanggananData>[],
  required DateTime hariIni,
  required int tanggalGajian,
  int? saldoSen,
}) {
  final awal = DateTime(hariIni.year, hariIni.month, hariIni.day);
  final batas = gajianBerikutnya(hariIni, tanggalGajian);
  final butir = <ButirGajian>[];

  // --- tagihan
  for (final t in tagihan) {
    if (!t.statusAktif) continue;
    final frek = Frekuensi.dariDb(t.frekuensi);
    final nominal = t.jumlahSen ?? 0;
    var tgl = DateTime(t.jatuhTempo.year, t.jatuhTempo.month, t.jatuhTempo.day);
    if (!t.lunas && tgl.isBefore(awal)) {
      // Sudah lewat & belum dibayar → tetap perlu disiapkan.
      butir.add(ButirGajian(
          nama: t.nama, tanggal: tgl, jumlahSen: nominal, sudahLewat: true));
    }
    if (frek == Frekuensi.sekali) {
      if (!tgl.isBefore(awal) && !tgl.isAfter(batas)) {
        butir.add(ButirGajian(nama: t.nama, tanggal: tgl, jumlahSen: nominal));
      }
      continue;
    }
    var langkah = 0;
    while (tgl.isBefore(awal) && langkah < 600) {
      tgl = periodeBerikutnya(tgl, frek, kustomHariN: t.kustomHariN);
      langkah++;
    }
    while (!tgl.isAfter(batas) && langkah < 1200) {
      butir.add(ButirGajian(nama: t.nama, tanggal: tgl, jumlahSen: nominal));
      tgl = periodeBerikutnya(tgl, frek, kustomHariN: t.kustomHariN);
      langkah++;
    }
  }

  // --- langganan aktif
  for (final l in langganan) {
    if (StatusLangganan.dariDb(l.status) != StatusLangganan.aktif) continue;
    final frek = Frekuensi.dariDb(l.siklus);
    var tgl = DateTime(
        l.tanggalMulai.year, l.tanggalMulai.month, l.tanggalMulai.day);
    if (frek == Frekuensi.sekali) {
      if (!tgl.isBefore(awal) && !tgl.isAfter(batas)) {
        butir.add(ButirGajian(
            nama: l.nama,
            tanggal: tgl,
            jumlahSen: l.nominalSen,
            langganan: true));
      }
      continue;
    }
    var langkah = 0;
    while (tgl.isBefore(awal) && langkah < 600) {
      tgl = periodeBerikutnya(tgl, frek);
      langkah++;
    }
    while (!tgl.isAfter(batas) && langkah < 1200) {
      butir.add(ButirGajian(
          nama: l.nama,
          tanggal: tgl,
          jumlahSen: l.nominalSen,
          langganan: true));
      tgl = periodeBerikutnya(tgl, frek);
      langkah++;
    }
  }

  butir.sort((a, b) => a.tanggal.compareTo(b.tanggal));
  return HasilAmanGajian(
    hariIni: awal,
    tanggalGajian: batas,
    butir: butir,
    saldoSen: saldoSen,
  );
}
