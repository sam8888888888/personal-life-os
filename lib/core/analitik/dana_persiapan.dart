/// FR-48 — Dasbor Arus Kas & Dana Persiapan.
///
/// "Dana persiapan" = uang yang disisihkan untuk kebutuhan yang SUDAH
/// diketahui (pajak, sekolah, servis, tiket pulang). Mesin ini menghitung:
///   * progres tiap dana (persen, sisa, setoran per bulan sampai tanggal target);
///   * arus kas bersih = proyeksi arus kas (FR-30) DIKURANGI alokasi dana
///     persiapan yang belum terkumpul untuk bulan itu.
///
/// Aturan kejujuran: angka yang tidak bisa dihitung TIDAK dikarang — masuk
/// daftar `belumBisa` beserta alasannya (target belum diisi, tanggal lewat,
/// tanggal target tidak ada, dsb).
library;

import 'package:flutter/foundation.dart';

/// Status dana persiapan.
enum StatusDana {
  terkumpul('terkumpul', 'Terkumpul'),
  jalan('jalan', 'Sedang diisi'),
  belum('belum', 'Belum mulai'),
  lewat('lewat', 'Lewat target');

  const StatusDana(this.kode, this.label);
  final String kode;
  final String label;

  static StatusDana dariKode(String? kode) => values.firstWhere(
        (s) => s.kode == kode,
        orElse: () => StatusDana.belum,
      );
}

/// Satu dana persiapan (mesin, bukan baris basis data).
@immutable
class DanaPersiapan {
  const DanaPersiapan({
    required this.nama,
    required this.targetSen,
    required this.tersediaSen,
    this.tanggalTarget,
    this.arsip = false,
    this.catatan,
  });

  final String nama;
  final int targetSen;
  final int tersediaSen;
  final DateTime? tanggalTarget;
  final bool arsip;
  final String? catatan;
}

/// Satu setoran (riwayat).
@immutable
class SetoranDana {
  const SetoranDana({
    required this.danaNama,
    required this.jumlahSen,
    required this.tanggal,
    this.catatan,
  });

  final String danaNama;
  final int jumlahSen;
  final DateTime tanggal;
  final String? catatan;
}

/// Hasil hitungan untuk satu dana.
@immutable
class RingkasanDana {
  const RingkasanDana({
    required this.nama,
    required this.targetSen,
    required this.tersediaSen,
    required this.setoranBulananSen,
    required this.status,
    required this.sekarang,
    required this.bulanTersisa,
    this.tanggalTarget,
  });

  final String nama;
  final int targetSen;
  final int tersediaSen;
  final int? setoranBulananSen;
  final StatusDana status;
  final DateTime sekarang;
  final int? bulanTersisa;
  final DateTime? tanggalTarget;

  int get sisaSen => (targetSen - tersediaSen).clamp(0, targetSen);

  /// Persen terkumpul (0–100); null bila target belum diisi.
  int? get persen {
    if (targetSen <= 0) return null;
    return ((tersediaSen * 100) / targetSen).clamp(0, 100).round();
  }

  /// Setoran yang masih perlu tiap bulan; null bila tidak bisa dihitung.
  int? get setoranPerBulanSen => setoranBulananSen;

  String get dasar =>
      '${_rp(tersediaSen)} dari target ${targetSen <= 0 ? '—' : _rp(targetSen)}'
      '${persen == null ? ' (target belum diisi)' : ' · $persen%'}'
      '${bulanTersisa == null ? '' : ' · sisa $bulanTersisa bulan'}';

  String get keteranganStatus => switch (status) {
        StatusDana.terkumpul => 'Dana sudah terkumpul penuh.',
        StatusDana.jalan =>
          'Sedang diisi${setoranBulananSen == null ? '' : ' · ${_rp(setoranBulananSen!)} per bulan'}',
        StatusDana.belum => 'Belum ada setoran.',
        StatusDana.lewat =>
          'Tanggal target sudah lewat, dana belum penuh.',
      };
}

/// Hitung satu dana persiapan.
RingkasanDana hitungDanaPersiapan(
  DanaPersiapan dana, {
  DateTime? sekarang,
}) {
  final kini = sekarang ?? DateTime.now();
  final target = dana.targetSen < 0 ? 0 : dana.targetSen;

  int? bulan;
  if (dana.tanggalTarget != null) {
    bulan = bulanAntara(kini, dana.tanggalTarget!);
  }

  int? setoran;
  final sisa = target - dana.tersediaSen;
  if (target > 0 && sisa > 0 && bulan != null && bulan > 0) {
    setoran = (sisa / bulan).ceil();
  }

  final StatusDana status;
  if (target > 0 && dana.tersediaSen >= target) {
    status = StatusDana.terkumpul;
  } else if (dana.tanggalTarget != null &&
      dana.tanggalTarget!.isBefore(DateTime(kini.year, kini.month, kini.day))) {
    status = StatusDana.lewat;
  } else if (dana.tersediaSen > 0) {
    status = StatusDana.jalan;
  } else {
    status = StatusDana.belum;
  }

  return RingkasanDana(
    nama: dana.nama,
    targetSen: target,
    tersediaSen: dana.tersediaSen,
    setoranBulananSen: setoran,
    status: status,
    sekarang: kini,
    bulanTersisa: bulan,
    tanggalTarget: dana.tanggalTarget,
  );
}

/// Selisih bulan penuh dari [dari] ke [sampai] (dibulatkan ke atas).
int bulanAntara(DateTime dari, DateTime sampai) {
  final a = DateTime(dari.year, dari.month);
  final b = DateTime(sampai.year, sampai.month);
  var bulan = (b.year - a.year) * 12 + (b.month - a.month);
  // Sisa hari di bulan berjalan dianggap bulan tambahan bila masih ada.
  if (sampai.day > dari.day) bulan += 1;
  return bulan < 0 ? 0 : bulan;
}

/// Ringkasan seluruh dana + arus kas bersih setelah alokasi.
@immutable
class DasborDanaPersiapan {
  const DasborDanaPersiapan({
    required this.dana,
    required this.belumBisa,
    required this.sekarang,
    this.arusKasBulanIniSen,
  });

  final List<RingkasanDana> dana;
  final List<String> belumBisa;
  final DateTime sekarang;

  /// Proyeksi arus kas bulan berjalan (dari FR-30) bila datanya ada.
  final int? arusKasBulanIniSen;

  int get totalTargetSen =>
      dana.fold<int>(0, (a, b) => a + b.targetSen);

  int get totalTersediaSen =>
      dana.fold<int>(0, (a, b) => a + b.tersediaSen);

  int get totalSisaSen => (totalTargetSen - totalTersediaSen).clamp(0, 1 << 62);

  int get totalAlokasiBulananSen => dana.fold<int>(
      0, (a, b) => a + (b.setoranBulananSen ?? 0));

  /// Arus kas bersih = arus kas − alokasi dana bulan ini. Null bila arus kas
  /// belum bisa dihitung (data pemasukan/pengeluaran belum ada).
  int? get arusKasBersihSen {
    final kas = arusKasBulanIniSen;
    if (kas == null) return null;
    return kas - totalAlokasiBulananSen;
  }

  /// Dana yang paling perlu perhatian (lewat target atau sisa terbesar).
  List<RingkasanDana> get prioritas {
    final urut = [...dana];
    urut.sort((a, b) {
      final pa = a.status == StatusDana.lewat ? 0 : 1;
      final pb = b.status == StatusDana.lewat ? 0 : 1;
      if (pa != pb) return pa.compareTo(pb);
      return b.sisaSen.compareTo(a.sisaSen);
    });
    return urut;
  }

  String get dasar =>
      '${dana.length} dana persiapan · terkumpul ${_rp(totalTersediaSen)} '
      'dari ${_rp(totalTargetSen)}.';

  /// Peringatan yang layak ditampilkan (urut dari yang paling mendesak).
  List<String> get peringatan {
    final hasil = <String>[];
    if (arusKasBersihSen != null && arusKasBersihSen! < 0) {
      hasil.add('Alokasi dana persiapan melebihi arus kas bulan ini '
          '(${_rp(totalAlokasiBulananSen)} vs ${_rp(arusKasBulanIniSen!)}).');
    }
    for (final d in dana) {
      if (d.status == StatusDana.lewat) {
        hasil.add('${d.nama}: tanggal target sudah lewat, sisa '
            '${_rp(d.sisaSen)} belum terkumpul.');
      }
    }
    for (final d in dana) {
      if (d.targetSen > 0 && d.setoranBulananSen != null && d.bulanTersisa == 1) {
        hasil.add('${d.nama}: perlu ${_rp(d.setoranBulananSen!)} bulan ini '
            'agar tercapai tepat waktu.');
      }
    }
    return hasil;
  }
}

/// Susun dasbor dari daftar dana.
DasborDanaPersiapan ringkasDanaPersiapan(
  List<DanaPersiapan> daftar, {
  DateTime? sekarang,
  int? arusKasSen,
}) {
  final kini = sekarang ?? DateTime.now();
  final aktif = daftar.where((d) => !d.arsip).toList();
  final hasil = aktif.map((d) => hitungDanaPersiapan(d, sekarang: kini)).toList();

  final belum = <String>[];
  if (aktif.isEmpty) {
    belum.add('Belum ada dana persiapan yang dicatat.');
  }
  for (final d in aktif) {
    if (d.targetSen <= 0) {
      belum.add('${d.nama}: target belum diisi, jadi sisa & setoran per bulan '
          'belum bisa dihitung.');
    }
    if (d.tanggalTarget == null && d.targetSen > 0) {
      belum.add('${d.nama}: tanggal target belum diisi, jadi setoran per bulan '
          'belum bisa dihitung.');
    }
  }
  if (arusKasSen == null) {
    belum.add('Arus kas bulan ini belum bisa dihitung (data pemasukan/tagihan '
        'belum cukup), jadi arus kas bersih belum ditampilkan.');
  }

  return DasborDanaPersiapan(
    dana: hasil,
    belumBisa: belum,
    sekarang: kini,
    arusKasBulanIniSen: arusKasSen,
  );
}

/// Riwayat setoran per dana (untuk layar), terbaru dulu.
List<SetoranDana> riwayatSetoran(
  List<SetoranDana> semua,
  String danaNama, {
  int batas = 12,
}) {
  final hasil = semua.where((s) => s.danaNama == danaNama).toList()
    ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
  return hasil.length > batas ? hasil.sublist(0, batas) : hasil;
}

String _rp(int sen) {
  final negatif = sen < 0;
  final nilai = negatif ? -sen : sen;
  final rupiah = nilai ~/ 100;
  final teks = rupiah.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
  return '${negatif ? '-' : ''}Rp $teks';
}
