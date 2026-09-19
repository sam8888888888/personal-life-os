/// FR-66 — Mode sorot "hari berat". **MURNI**: tanpa basis data, tanpa tampilan.
///
/// Aturan yang dipegang berkas ini (PRD Modul 0):
/// 1. dipakai bila beban satu hari **lebih dari [ambang]** butir (bawaan 5);
/// 2. urutan disarankan dari data yang ada: yang terlambat dulu, lalu prioritas
///    tinggi, lalu nominal terbesar, lalu nama (abjad) — bukan karangan;
/// 3. penundaan hanya **ditawarkan** untuk butir yang tidak mendesak
///    ([ButirHariBerat.bisaDitunda]); tidak ada butir yang hilang.
library;

import '../utils/tanggal_utils.dart';
import 'tagihan_ringkas.dart';

/// Bentuk ringkas tugas untuk Today (bukan kelas Drift).
class TugasRingkas {
  const TugasRingkas({
    required this.id,
    required this.nama,
    this.jatuhTempo,
    this.prioritas = 'biasa',
    this.selesai = false,
  });

  final int id;
  final String nama;
  final DateTime? jatuhTempo;
  final String prioritas;
  final bool selesai;
}

/// Satu butir yang ikut membebani hari ini.
class ButirHariBerat {
  const ButirHariBerat({
    required this.jenis,
    required this.id,
    required this.nama,
    required this.jatuhTempo,
    required this.urutan,
    required this.alasan,
    this.nominalSen,
    this.terlambat = false,
    this.prioritasTinggi = false,
  });

  /// 'tagihan' atau 'tugas'.
  final String jenis;
  final int id;
  final String nama;
  final DateTime jatuhTempo;

  /// Nomor urut yang disarankan (mulai dari 1).
  final int urutan;
  final String alasan;
  final int? nominalSen;
  final bool terlambat;
  final bool prioritasTinggi;

  /// Yang mendesak tidak ditawarkan untuk ditunda.
  bool get bisaDitunda => !terlambat && !prioritasTinggi;
}

/// Hasil mode "hari berat".
class HasilHariBerat {
  const HasilHariBerat({required this.urutan, this.ambang = 5});

  final List<ButirHariBerat> urutan;
  final int ambang;

  int get jumlah => urutan.length;
  bool get berat => jumlah > ambang;
  int get jumlahBisaDitunda => urutan.where((b) => b.bisaDitunda).length;
  bool get adaYangBisaDitunda => jumlahBisaDitunda > 0;
}

/// Susun urutan yang disarankan untuk [hari].
///
/// Ikut dihitung: tagihan aktif yang belum lunas dengan jatuh tempo **hari itu
/// atau sebelumnya** (yang terlambat tetap milik hari ini) dan tugas yang belum
/// selesai dengan jatuh tempo hari itu atau sebelumnya.
HasilHariBerat susunHariBerat({
  required Iterable<TagihanRingkas> tagihan,
  Iterable<TugasRingkas> tugas = const <TugasRingkas>[],
  required DateTime hari,
  int ambang = 5,
}) {
  final inti = DateTime(hari.year, hari.month, hari.day);
  final butir = <ButirHariBerat>[];

  bool ikut(DateTime? jt) {
    if (jt == null) return false;
    final d = DateTime(jt.year, jt.month, jt.day);
    return !d.isAfter(inti);
  }

  for (final t in tagihan) {
    if (!t.menuntutTindakan) continue;
    if (!ikut(t.jatuhTempo)) continue;
    final telat = selisihHari(t.jatuhTempo, inti);
    butir.add(ButirHariBerat(
      jenis: 'tagihan',
      id: t.id,
      nama: t.nama,
      jatuhTempo: t.jatuhTempo,
      nominalSen: t.jumlahSen,
      urutan: 0,
      terlambat: telat > 0,
      prioritasTinggi: t.prioritas == 'tinggi',
      alasan: telat > 0
          ? 'Terlambat $telat hari'
          : (t.prioritas == 'tinggi'
              ? 'Jatuh tempo hari ini · prioritas tinggi'
              : 'Jatuh tempo hari ini'),
    ));
  }

  for (final g in tugas) {
    if (g.selesai) continue;
    final jt = g.jatuhTempo;
    if (!ikut(jt)) continue;
    final telat = selisihHari(jt!, inti);
    butir.add(ButirHariBerat(
      jenis: 'tugas',
      id: g.id,
      nama: g.nama,
      jatuhTempo: jt,
      urutan: 0,
      terlambat: telat > 0,
      prioritasTinggi: g.prioritas == 'tinggi',
      alasan: telat > 0
          ? 'Terlambat $telat hari'
          : (g.prioritas == 'tinggi'
              ? 'Hari ini · prioritas tinggi'
              : 'Hari ini'),
    ));
  }

  butir.sort((a, b) {
    if (a.terlambat != b.terlambat) return a.terlambat ? -1 : 1;
    if (a.prioritasTinggi != b.prioritasTinggi) {
      return a.prioritasTinggi ? -1 : 1;
    }
    final na = a.nominalSen ?? -1;
    final nb = b.nominalSen ?? -1;
    if (na != nb) return nb.compareTo(na);
    return a.nama.toLowerCase().compareTo(b.nama.toLowerCase());
  });

  final hasil = <ButirHariBerat>[];
  for (var i = 0; i < butir.length; i++) {
    final b = butir[i];
    hasil.add(ButirHariBerat(
      jenis: b.jenis,
      id: b.id,
      nama: b.nama,
      jatuhTempo: b.jatuhTempo,
      nominalSen: b.nominalSen,
      urutan: i + 1,
      alasan: b.alasan,
      terlambat: b.terlambat,
      prioritasTinggi: b.prioritasTinggi,
    ));
  }
  return HasilHariBerat(urutan: hasil, ambang: ambang);
}
