/// FR-140 — Life Timeline (signature).
///
/// Kriteria terima PRD: "Timeline akurat dari data nyata; menampilkan rangkuman
/// 'apa yang terjadi bulan ini'."
///
/// Jadi tiap peristiwa WAJIB punya rujukan ke tabel/baris asalnya ([rujukan]),
/// dan ringkasan bulanan dihitung dari daftar peristiwa yang sama — bukan
/// dikarang terpisah.
library;

/// Satu kejadian hidup.
class PeristiwaHidup {
  const PeristiwaHidup({
    required this.tanggal,
    required this.modul,
    required this.judul,
    this.keterangan = '',
    this.rujukan = '',
  });

  final DateTime tanggal;

  /// uang · tugas · kesehatan · pengetahuan · ibadah · rumah · keluarga · dokumen
  final String modul;

  final String judul;
  final String keterangan;

  /// Asal data, mis. `tagihan#12` — supaya angka/kejadian bisa ditelusuri.
  final String rujukan;

  String get labelModul => switch (modul) {
        'uang' => 'Uang',
        'tugas' => 'Tugas & tujuan',
        'kesehatan' => 'Kesehatan',
        'pengetahuan' => 'Pengetahuan',
        'ibadah' => 'Ibadah',
        'rumah' => 'Rumah & aset',
        'keluarga' => 'Keluarga',
        'dokumen' => 'Dokumen',
        _ => modul,
      };
}

/// Satu bulan pada lini masa.
class BulanLiniMasa {
  const BulanLiniMasa({required this.kunci, required this.peristiwa});

  /// 'YYYY-MM'.
  final String kunci;
  final List<PeristiwaHidup> peristiwa;
}

/// Saring + kelompokkan peristiwa menjadi lini masa per bulan (terbaru di atas).
List<BulanLiniMasa> susunLiniMasa({
  required List<PeristiwaHidup> peristiwa,
  DateTime? dari,
  DateTime? sampai,
  String? modul,
  String? cari,
}) {
  final kata = (cari ?? '').trim().toLowerCase();
  final lulus = peristiwa.where((p) {
    if (dari != null && p.tanggal.isBefore(_awalHari(dari))) return false;
    if (sampai != null && p.tanggal.isAfter(_akhirHari(sampai))) return false;
    if (modul != null && modul.isNotEmpty && p.modul != modul) return false;
    if (kata.isNotEmpty) {
      final bahan = '${p.judul} ${p.keterangan} ${p.labelModul}'.toLowerCase();
      if (!bahan.contains(kata)) return false;
    }
    return true;
  }).toList()
    ..sort((a, b) => b.tanggal.compareTo(a.tanggal));

  final perBulan = <String, List<PeristiwaHidup>>{};
  for (final p in lulus) {
    perBulan.putIfAbsent(kunciBulan(p.tanggal), () => []).add(p);
  }
  final kunci = perBulan.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final k in kunci)
      BulanLiniMasa(kunci: k, peristiwa: perBulan[k]!),
  ];
}

/// Ringkasan "apa yang terjadi bulan ini" dari data nyata.
String ringkasBulanIni(List<PeristiwaHidup> peristiwa, DateTime bulan) {
  final isi = peristiwa
      .where((p) =>
          p.tanggal.year == bulan.year && p.tanggal.month == bulan.month)
      .toList();
  if (isi.isEmpty) {
    return 'Belum ada catatan kejadian pada bulan ini.';
  }
  final perModul = <String, int>{};
  for (final p in isi) {
    perModul[p.modul] = (perModul[p.modul] ?? 0) + 1;
  }
  final urut = perModul.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final rincian = urut
      .take(4)
      .map((e) => '${PeristiwaHidup(tanggal: bulan, modul: e.key, judul: '').labelModul} ${e.value}')
      .join(' · ');
  return '${isi.length} kejadian tercatat bulan ini — $rincian.';
}

/// 'YYYY-MM' dari sebuah tanggal.
String kunciBulan(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}';

/// Label bulan Indonesia dari kunci 'YYYY-MM'.
String labelBulan(String kunci) {
  const nama = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  final bagian = kunci.split('-');
  if (bagian.length != 2) return kunci;
  final bulan = int.tryParse(bagian[1]) ?? 0;
  if (bulan < 1 || bulan > 12) return kunci;
  return '${nama[bulan - 1]} ${bagian[0]}';
}

DateTime _awalHari(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime _akhirHari(DateTime t) =>
    DateTime(t.year, t.month, t.day, 23, 59, 59, 999);
