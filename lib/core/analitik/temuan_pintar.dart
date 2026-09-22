/// FR-142 — Smart Insights: temuan lintas modul.
///
/// Aturan jujur dari PRD: **setiap temuan menyebut dasar data & periodenya**,
/// dan **hanya muncul bila datanya cukup**. Karena itu fungsi ini tidak pernah
/// "mengarang" temuan: bila data kurang, temuan itu tidak ditampilkan dan
/// alasannya dikembalikan apa adanya di [HasilTemuan.belumBisa].
///
/// Berkas ini murni hitungan tanpa Flutter/basis data → bisa diuji tanpa HP.
library;

import '../utils/tanggal_utils.dart';
import '../utils/uang_utils.dart';

/// Total pengeluaran satu bulan. [periode] berformat `YYYY-MM`.
class PengeluaranBulan {
  const PengeluaranBulan({required this.periode, required this.sen, this.jumlah = 0});

  final String periode;
  final int sen;
  final int jumlah;
}

/// Langganan aktif; [terakhirDipakai] null = belum pernah dicatat.
class LanggananRingkas {
  const LanggananRingkas({
    required this.nama,
    required this.nominalSen,
    this.terakhirDipakai,
  });

  final String nama;
  final int nominalSen;
  final DateTime? terakhirDipakai;
}

/// Tagihan aktif yang akan datang.
class TagihanJatuhTempo {
  const TagihanJatuhTempo({
    required this.nama,
    required this.jatuhTempo,
    this.nominalSen = 0,
  });

  final String nama;
  final DateTime jatuhTempo;
  final int nominalSen;
}

/// Satu titik saldo harian (dipakai untuk mencari titik terendah).
class TitikSaldo {
  const TitikSaldo({required this.tanggal, required this.saldoSen});

  final DateTime tanggal;
  final int saldoSen;
}

/// Satu temuan beserta dasar datanya.
class Temuan {
  const Temuan({
    required this.kode,
    required this.judul,
    required this.rincian,
    required this.dasar,
    this.angka,
    this.penting = false,
  });

  /// Pengenal mesin (untuk uji & saringan), bukan untuk ditampilkan.
  final String kode;
  final String judul;
  final String rincian;

  /// Asal angka: tabel + periode. Wajib ada (PRD: tidak ada angka misterius).
  final String dasar;

  /// Angka ringkas untuk ditampilkan di kanan baris, mis. `+38%`.
  final String? angka;

  /// Perlu perhatian (ditampilkan lebih dulu).
  final bool penting;
}

/// Semua bahan mentah temuan.
class BahanTemuan {
  const BahanTemuan({
    this.pengeluaranBulanan = const <PengeluaranBulan>[],
    this.langganan = const <LanggananRingkas>[],
    this.tagihanAktif = const <TagihanJatuhTempo>[],
    this.saldoHarian = const <TitikSaldo>[],
  });

  final List<PengeluaranBulan> pengeluaranBulanan;
  final List<LanggananRingkas> langganan;
  final List<TagihanJatuhTempo> tagihanAktif;
  final List<TitikSaldo> saldoHarian;
}

/// Hasil: temuan yang boleh tampil + alasan yang datanya belum cukup.
class HasilTemuan {
  const HasilTemuan({required this.temuan, required this.belumBisa});

  final List<Temuan> temuan;
  final List<String> belumBisa;

  bool get kosong => temuan.isEmpty;
}

String _labelPeriode(String periode) {
  final bagian = periode.split('-');
  if (bagian.length != 2) return periode;
  final tahun = int.tryParse(bagian[0]);
  final bulan = int.tryParse(bagian[1]);
  if (tahun == null || bulan == null || bulan < 1 || bulan > 12) return periode;
  // namaBulanSingkat di proyek ini 1-indeks: namaBulanSingkat[9] == 'Sep'.
  return '${namaBulanSingkat[bulan]} $tahun';
}

/// Susun temuan dari [bahan]. Ambang & batas minimal dapat diubah untuk uji.
HasilTemuan susunTemuan(
  BahanTemuan bahan, {
  double ambangMenyimpang = 0.20,
  int hariLanggananJarang = 60,
  int minimalBulanPengeluaran = 4,
  int minimalTitikSaldo = 14,
  int minimalTagihan = 5,
}) {
  final temuan = <Temuan>[];
  final belumBisa = <String>[];

  // ── 1. Pengeluaran menyimpang ────────────────────────────────────────────
  final bulanan = [...bahan.pengeluaranBulanan]
    ..sort((a, b) => a.periode.compareTo(b.periode));
  if (bulanan.length < minimalBulanPengeluaran) {
    belumBisa.add(
        'Pengeluaran menyimpang butuh $minimalBulanPengeluaran bulan catatan; sejauh ini baru ${bulanan.length} bulan.');
  } else {
    final terakhir = bulanan.last;
    final pembanding = bulanan.sublist(bulanan.length - 4, bulanan.length - 1);
    final rata = pembanding.isEmpty
        ? 0
        : (pembanding.fold<int>(0, (a, b) => a + b.sen) / pembanding.length)
            .round();
    if (rata <= 0) {
      belumBisa.add(
          'Pengeluaran menyimpang belum bisa dihitung: bulan pembanding belum punya catatan pengeluaran.');
    } else {
      final selisih = terakhir.sen - rata;
      final rasio = selisih.abs() / rata;
      if (rasio >= ambangMenyimpang) {
        final naik = selisih > 0;
        temuan.add(Temuan(
          kode: 'pengeluaran_menyimpang',
          judul: naik
              ? 'Pengeluaran ${_labelPeriode(terakhir.periode)} lebih tinggi'
              : 'Pengeluaran ${_labelPeriode(terakhir.periode)} lebih rendah',
          rincian:
              '${fmtRpDariSen(terakhir.sen)} pada ${_labelPeriode(terakhir.periode)}, '
              'sedangkan rata-rata ${pembanding.length} bulan sebelumnya '
              '${fmtRpDariSen(rata)}. Selisih ${fmtRpDariSen(selisih.abs())} '
              '(${(rasio * 100).toStringAsFixed(0)}%).',
          dasar: 'tabel transaksi · ${_labelPeriode(terakhir.periode)} '
              'vs ${_labelPeriode(pembanding.first.periode)}–${_labelPeriode(pembanding.last.periode)}',
          angka: '${naik ? '+' : '−'}${(rasio * 100).toStringAsFixed(0)}%',
          penting: naik,
        ));
      }
    }
  }

  // ── 2. Langganan jarang dipakai ──────────────────────────────────────────
  final pernahDicatat =
      bahan.langganan.where((l) => l.terakhirDipakai != null).toList();
  if (bahan.langganan.isEmpty) {
    belumBisa.add('Langganan jarang dipakai belum bisa: belum ada langganan aktif.');
  } else if (pernahDicatat.isEmpty) {
    belumBisa.add(
        'Langganan jarang dipakai belum bisa: catatan "terakhir dipakai" belum pernah diisi.');
  } else {
    final kandidat = pernahDicatat.where((l) {
      final hari = DateTime.now().difference(l.terakhirDipakai!).inDays;
      return hari >= hariLanggananJarang;
    }).toList()
      ..sort((a, b) => b.nominalSen.compareTo(a.nominalSen));
    if (kandidat.isNotEmpty) {
      final total = kandidat.fold<int>(0, (a, b) => a + b.nominalSen);
      final nama = kandidat.take(3).map((l) => l.nama).join(', ');
      temuan.add(Temuan(
        kode: 'langganan_jarang_dipakai',
        judul: '${kandidat.length} langganan jarang dipakai',
        rincian:
            '$nama${kandidat.length > 3 ? ', dan ${kandidat.length - 3} lainnya' : ''} '
            '— tidak dipakai ≥$hariLanggananJarang hari. Bila dihentikan, '
            'sekitar ${fmtRpDariSen(total)} per siklus bisa dihemat.',
        dasar: 'tabel langganan · kolom "terakhir dipakai" (${pernahDicatat.length} langganan tercatat)',
        angka: '${kandidat.length}',
        penting: true,
      ));
    }
  }

  // ── 3. Titik saldo terendah ──────────────────────────────────────────────
  if (bahan.saldoHarian.length < minimalTitikSaldo) {
    belumBisa.add(
        'Titik saldo terendah butuh $minimalTitikSaldo hari catatan transaksi; sejauh ini baru ${bahan.saldoHarian.length} hari.');
  } else if (bahan.saldoHarian
      .every((t) => t.saldoSen == bahan.saldoHarian.first.saldoSen)) {
    // Semua titik sama = tidak ada transaksi pada rentang itu. Menampilkan
    // "saldo terendah Rp 0" hanya akan menyesatkan, jadi tidak dibuat temuan.
    belumBisa.add(
        'Titik saldo terendah belum bisa dihitung: belum ada transaksi pada rentang ini.');
  } else {
    final urut = [...bahan.saldoHarian]..sort((a, b) => a.saldoSen.compareTo(b.saldoSen));
    final terendah = urut.first;
    final minus = bahan.saldoHarian.where((t) => t.saldoSen < 0).length;
    temuan.add(Temuan(
      kode: 'titik_saldo_terendah',
      judul: 'Titik saldo terendah',
      rincian:
          '${fmtRpDariSen(terendah.saldoSen)} pada ${fmtTanggalAman(terendah.tanggal)}'
          '${minus > 0 ? ' · $minus hari saldo minus' : ''}.',
      dasar:
          'tabel transaksi · ${fmtTanggalAman(bahan.saldoHarian.first.tanggal)}–${fmtTanggalAman(bahan.saldoHarian.last.tanggal)} (${bahan.saldoHarian.length} hari)',
      angka: fmtRpDariSen(terendah.saldoSen),
      penting: minus > 0,
    ));
  }

  // ── 4. Sebaran jatuh tempo ───────────────────────────────────────────────
  if (bahan.tagihanAktif.length < minimalTagihan) {
    belumBisa.add(
        'Sebaran jatuh tempo butuh minimal $minimalTagihan tagihan aktif; sejauh ini ${bahan.tagihanAktif.length}.');
  } else {
    var diAkhirBulan = 0;
    for (final t in bahan.tagihanAktif) {
      final hariTerakhir = DateTime(t.jatuhTempo.year, t.jatuhTempo.month + 1, 0).day;
      if (t.jatuhTempo.day > hariTerakhir - 7) diAkhirBulan++;
    }
    final rasio = diAkhirBulan / bahan.tagihanAktif.length;
    if (rasio >= 0.5) {
      temuan.add(Temuan(
        kode: 'sebaran_jatuh_tempo',
        judul: 'Tagihan menumpuk di akhir bulan',
        rincian:
            '${(rasio * 100).toStringAsFixed(0)}% tagihan aktif ($diAkhirBulan dari '
            '${bahan.tagihanAktif.length}) jatuh tempo pada 7 hari terakhir bulan. '
            'Menggeser sebagian tanggal bisa meringankan minggu terakhir.',
        dasar: 'tabel tagihan · ${bahan.tagihanAktif.length} tagihan aktif',
        angka: '${(rasio * 100).toStringAsFixed(0)}%',
        penting: true,
      ));
    }
  }

  temuan.sort((a, b) {
    if (a.penting != b.penting) return a.penting ? -1 : 1;
    return a.judul.compareTo(b.judul);
  });

  return HasilTemuan(temuan: temuan, belumBisa: belumBisa);
}
