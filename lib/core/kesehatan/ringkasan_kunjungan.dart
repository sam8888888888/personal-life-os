/// FR-115 — Mode Kunjungan Dokter: satu halaman ringkasan 30 hari.
///
/// PRD: "Menghasilkan 1 halaman PDF; angka identik dengan data aplikasi."
///
/// Karena itu **semua angka dihitung di sini dari data yang sama** yang dipakai
/// layar kesehatan — PDF hanya menyusun ulang [RingkasanKunjungan], tidak
/// menghitung apa pun sendiri. Berkas ini murni (tanpa Flutter & basis data).
library;

import 'titik_data.dart';

/// Satu baris ringkasan siap tampil/cetak.
class BarisKunjungan {
  const BarisKunjungan({
    required this.label,
    required this.nilai,
    required this.catatan,
  });

  final String label;
  final String nilai;

  /// Keterangan jumlah data (mis. "12 catatan") supaya dasar angkanya jelas.
  final String catatan;
}

/// Ringkasan keadaan [hari] hari terakhir untuk dibawa ke kunjungan dokter.
class RingkasanKunjungan {
  const RingkasanKunjungan({
    required this.dari,
    required this.sampai,
    required this.hari,
    this.beratAwalGram,
    this.beratAkhirGram,
    this.jumlahUkuranBerat = 0,
    this.sistolikRata,
    this.diastolikRata,
    this.jumlahUkuranTekanan = 0,
    this.tidurRataMenit,
    this.jumlahMalamTidur = 0,
    this.totalMenitAktivitas = 0,
    this.jumlahCatatanAktivitas = 0,
    this.suasanaRata,
    this.jumlahCatatanSuasana = 0,
    this.keluhan = const [],
  });

  final DateTime dari;
  final DateTime sampai;
  final int hari;

  final num? beratAwalGram;
  final num? beratAkhirGram;
  final int jumlahUkuranBerat;

  final num? sistolikRata;
  final num? diastolikRata;
  final int jumlahUkuranTekanan;

  final num? tidurRataMenit;
  final int jumlahMalamTidur;

  final num totalMenitAktivitas;
  final int jumlahCatatanAktivitas;

  final num? suasanaRata;
  final int jumlahCatatanSuasana;

  final List<String> keluhan;

  bool get adaData =>
      jumlahUkuranBerat > 0 ||
      jumlahUkuranTekanan > 0 ||
      jumlahMalamTidur > 0 ||
      jumlahCatatanAktivitas > 0 ||
      jumlahCatatanSuasana > 0 ||
      keluhan.isNotEmpty;

  num? get selisihBeratGram => (beratAwalGram == null || beratAkhirGram == null)
      ? null
      : beratAkhirGram! - beratAwalGram!;

  /// Baris siap tampil. [tanpaData] untuk nilai yang belum ada catatan.
  List<BarisKunjungan> get baris => [
        BarisKunjungan(
          label: 'Berat badan',
          nilai: beratAkhirGram == null
              ? tanpaData
              : '${_kg(beratAwalGram!)} → ${_kg(beratAkhirGram!)} kg'
                  '${selisihBeratGram == null || selisihBeratGram == 0 ? '' : ' '
                      '(${selisihBeratGram! > 0 ? '+' : ''}'
                      '${_kg(selisihBeratGram!.abs())} kg)'}',
          catatan: '$jumlahUkuranBerat ukuran',
        ),
        BarisKunjungan(
          label: 'Tekanan darah',
          nilai: sistolikRata == null
              ? tanpaData
              : '${sistolikRata!.round()}/${diastolikRata!.round()} mmHg '
                  '(rata-rata)',
          catatan: '$jumlahUkuranTekanan ukuran',
        ),
        BarisKunjungan(
          label: 'Tidur',
          nilai: tidurRataMenit == null
              ? tanpaData
              : '${_jamMenit(tidurRataMenit!)} per malam (rata-rata)',
          catatan: '$jumlahMalamTidur malam tercatat',
        ),
        BarisKunjungan(
          label: 'Aktivitas',
          nilai: jumlahCatatanAktivitas == 0
              ? tanpaData
              : '${totalMenitAktivitas.round()} menit total · '
                  '${(totalMenitAktivitas / hari).round()} menit/hari',
          catatan: '$jumlahCatatanAktivitas catatan',
        ),
        BarisKunjungan(
          label: 'Suasana hati',
          nilai: suasanaRata == null
              ? tanpaData
              : '${suasanaRata!.toStringAsFixed(1)} dari 5 (rata-rata)',
          catatan: '$jumlahCatatanSuasana catatan',
        ),
      ];

  static const String tanpaData = 'Belum ada catatan';
}

const String _tanpaDataLabel = RingkasanKunjungan.tanpaData;

/// Susun ringkasan dari data mentah.
///
/// [berat] dalam gram, [tidur] dalam menit, [aktivitas] dalam menit,
/// [tekanan] sebagai peta `sistolik`/`diastolik` per tanggal.
RingkasanKunjungan susunRingkasanKunjungan({
  required DateTime sekarang,
  int hari = 30,
  List<TitikData> berat = const [],
  List<TitikData> tidur = const [],
  List<TitikData> aktivitas = const [],
  List<TitikData> sistolik = const [],
  List<TitikData> diastolik = const [],
  List<TitikData> suasana = const [],
  List<String> keluhan = const [],
}) {
  final sampai = DateTime(sekarang.year, sekarang.month, sekarang.day);
  final dari = sampai.subtract(Duration(days: hari - 1));
  List<TitikData> dalam(List<TitikData> data) => data
      .where((t) =>
          !_awalHari(t.tanggal).isBefore(dari) &&
          !_awalHari(t.tanggal).isAfter(sampai))
      .toList()
    ..sort((a, b) => a.tanggal.compareTo(b.tanggal));

  final b = dalam(berat);
  final t = dalam(tidur);
  final a = dalam(aktivitas);
  final s = dalam(sistolik);
  final d = dalam(diastolik);
  final su = dalam(suasana);

  return RingkasanKunjungan(
    dari: dari,
    sampai: sampai,
    hari: hari,
    beratAwalGram: b.isEmpty ? null : b.first.nilai,
    beratAkhirGram: b.isEmpty ? null : b.last.nilai,
    jumlahUkuranBerat: b.length,
    sistolikRata: s.isEmpty ? null : _rata(s),
    diastolikRata: d.isEmpty ? null : _rata(d),
    jumlahUkuranTekanan: s.length,
    tidurRataMenit: t.isEmpty ? null : _rata(t),
    jumlahMalamTidur: t.length,
    totalMenitAktivitas: a.fold<num>(0, (x, y) => x + y.nilai),
    jumlahCatatanAktivitas: a.length,
    suasanaRata: su.isEmpty ? null : _rata(su),
    jumlahCatatanSuasana: su.length,
    keluhan: keluhan.where((k) => k.trim().isNotEmpty).toList(),
  );
}

/// Teks ringkasan (dipakai bagikan & PDF) — angka apa adanya.
String teksRingkasanKunjungan(RingkasanKunjungan r) {
  final buf = StringBuffer()
    ..writeln('RINGKASAN KESEHATAN ${r.hari} HARI')
    ..writeln('Periode: ${fmtTanggalKunjungan(r.dari)} – '
        '${fmtTanggalKunjungan(r.sampai)}')
    ..writeln();
  for (final b in r.baris) {
    buf.writeln('${b.label}: ${b.nilai} (${b.catatan})');
  }
  if (r.keluhan.isNotEmpty) {
    buf
      ..writeln()
      ..writeln('Keluhan yang tercatat:');
    for (final k in r.keluhan) {
      buf.writeln('- $k');
    }
  }
  buf
    ..writeln()
    ..writeln('Angka di atas berasal dari catatan aplikasi, bukan hasil '
        'pemeriksaan. Bukan diagnosis.');
  return buf.toString().trimRight();
}

// ---------------------------------------------------------------- bantuan

DateTime _awalHari(DateTime d) => DateTime(d.year, d.month, d.day);

num _rata(List<TitikData> data) =>
    data.fold<num>(0, (a, b) => a + b.nilai) / data.length;

String _kg(num gram) => (gram / 1000).toStringAsFixed(1);

String _jamMenit(num menit) {
  final j = menit ~/ 60;
  final m = (menit % 60).round();
  return '$j jam $m menit';
}

const List<String> _bulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Tanggal tanpa locale, mis. "12 Jan 2026".
String fmtTanggalKunjungan(DateTime d) =>
    '${d.day} ${_bulan[d.month - 1]} ${d.year}';

/// Label "belum ada catatan" (dipakai layar).
String get labelTanpaDataKunjungan => _tanpaDataLabel;
