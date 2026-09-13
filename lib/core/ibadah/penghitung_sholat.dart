/// Mesin hitung jadwal sholat (FR-86) — memakai `adhan_dart` (MIT),
/// berjalan 100% di perangkat, TIDAK butuh internet.
///
/// Sumber rumus: pustaka `adhan_dart` 2.0.1 (turunan rumus astronomi Batoul
/// Kassem/Adhan). Preset sudut diambil LANGSUNG dari pustaka (tidak ditulis
/// ulang di sini) agar tidak ada angka yang dikarang.
///
/// Penting (jujur ke pengguna): hasil ini PERHITUNGAN, bukan jadwal resmi
/// Kementerian Agama. Selisih lazim 0–2 menit dari jadwal resmi, dan untuk
/// tanggal Hijriah bisa berbeda 1 hari dari penetapan pemerintah.
library;

import 'package:adhan_dart/adhan_dart.dart';

import 'model_sholat.dart';

/// Metode perhitungan yang tersedia di antarmuka.
enum MetodeHitungSholat {
  kemenag(
    'Kemenag Indonesia',
    'kemenag',
    'Sudut Subuh 20°, Isya 18° — kriteria yang dipakai Kementerian Agama RI.',
  ),
  mwl(
    'Muslim World League',
    'mwl',
    'Sudut Subuh 18°, Isya 17° — banyak dipakai di Eropa dan Timur Tengah.',
  ),
  ummAlQura(
    'Umm al-Qura (Makkah)',
    'umm_al_qura',
    'Sudut Subuh 18,5°, Isya 90 menit setelah Maghrib.',
  ),
  karachi(
    'Karachi',
    'karachi',
    'Sudut Subuh 18°, Isya 18°.',
  ),
  singapore(
    'Singapura / MUIS',
    'singapore',
    'Sudut Subuh 20°, Isya 18°, pembulatan ke atas.',
  ),
  egyptian(
    'Mesir',
    'egyptian',
    'Sudut Subuh 19,5°, Isya 17,5°.',
  );

  const MetodeHitungSholat(this.label, this.kode, this.keterangan);

  final String label;
  final String kode;
  final String keterangan;

  /// Parameter hitung dari pustaka `adhan_dart`.
  CalculationParameters parameter() {
    switch (this) {
      case MetodeHitungSholat.kemenag:
        return CalculationMethodParameters.indonesian();
      case MetodeHitungSholat.mwl:
        return CalculationMethodParameters.muslimWorldLeague();
      case MetodeHitungSholat.ummAlQura:
        return CalculationMethodParameters.ummAlQura();
      case MetodeHitungSholat.karachi:
        return CalculationMethodParameters.karachi();
      case MetodeHitungSholat.singapore:
        return CalculationMethodParameters.singapore();
      case MetodeHitungSholat.egyptian:
        return CalculationMethodParameters.egyptian();
    }
  }

  static MetodeHitungSholat dariKode(String kode) => MetodeHitungSholat.values
      .firstWhere((MetodeHitungSholat m) => m.kode == kode,
          orElse: () => MetodeHitungSholat.kemenag);
}

/// Pemetaan waktu -> enum `Prayer` di pustaka.
const Map<WaktuSholat, Prayer> _petaDoa = <WaktuSholat, Prayer>{
  WaktuSholat.subuh: Prayer.fajr,
  WaktuSholat.syuruq: Prayer.sunrise,
  WaktuSholat.dzuhur: Prayer.dhuhr,
  WaktuSholat.ashar: Prayer.asr,
  WaktuSholat.maghrib: Prayer.maghrib,
  WaktuSholat.isya: Prayer.isha,
};

/// Hitung jadwal sholat satu hari.
///
/// [tanggal] hanya dipakai YEAR/MONTH/DAY-nya; nilainya dibaca sebagai tanggal
/// sipil di zona kota tujuan (bukan tanggal perangkat).
JadwalSholatHarian hitungJadwal({
  required KotaSholat kota,
  required DateTime tanggal,
  MetodeHitungSholat metode = MetodeHitungSholat.kemenag,
  bool asharHanafi = false,
  Map<WaktuSholat, int> koreksiMenit = const <WaktuSholat, int>{},
}) {
  if (!kota.koordinatWajar) {
    throw ArgumentError('Koordinat tidak wajar: ${kota.lintang}, ${kota.bujur}');
  }
  final CalculationParameters param = metode.parameter();
  param.madhab = asharHanafi ? Madhab.hanafi : Madhab.shafi;
  final Map<Prayer, int> adj = Map<Prayer, int>.from(param.adjustments);
  for (final MapEntry<WaktuSholat, int> e in koreksiMenit.entries) {
    final Prayer p = _petaDoa[e.key]!;
    adj[p] = (adj[p] ?? 0) + e.value;
  }
  param.adjustments = adj;

  final PrayerTimes pt = PrayerTimes(
    date: DateTime.utc(tanggal.year, tanggal.month, tanggal.day),
    coordinates: Coordinates(kota.lintang, kota.bujur),
    calculationParameters: param,
  );

  return JadwalSholatHarian(
    tanggalKota: DateTime.utc(tanggal.year, tanggal.month, tanggal.day),
    kota: kota,
    kodeMetode: metode.kode,
    namaMetode: metode.label,
    asharHanafi: asharHanafi,
    koreksiMenit: Map<WaktuSholat, int>.from(koreksiMenit),
    waktuUtc: <WaktuSholat, DateTime>{
      WaktuSholat.subuh: pt.fajr.toUtc(),
      WaktuSholat.syuruq: pt.sunrise.toUtc(),
      WaktuSholat.dzuhur: pt.dhuhr.toUtc(),
      WaktuSholat.ashar: pt.asr.toUtc(),
      WaktuSholat.maghrib: pt.maghrib.toUtc(),
      WaktuSholat.isya: pt.isha.toUtc(),
    },
  );
}

/// Hitung beberapa hari sekaligus (untuk cache offline & penjadwalan pengingat).
List<JadwalSholatHarian> hitungRentang({
  required KotaSholat kota,
  required DateTime tanggalMulai,
  int jumlahHari = 7,
  MetodeHitungSholat metode = MetodeHitungSholat.kemenag,
  bool asharHanafi = false,
  Map<WaktuSholat, int> koreksiMenit = const <WaktuSholat, int>{},
}) {
  if (jumlahHari < 1 || jumlahHari > 366) {
    throw ArgumentError('jumlahHari harus 1..366, bukan $jumlahHari');
  }
  final DateTime mulai =
      DateTime.utc(tanggalMulai.year, tanggalMulai.month, tanggalMulai.day);
  return <JadwalSholatHarian>[
    for (int i = 0; i < jumlahHari; i++)
      hitungJadwal(
        kota: kota,
        tanggal: mulai.add(Duration(days: i)),
        metode: metode,
        asharHanafi: asharHanafi,
        koreksiMenit: koreksiMenit,
      ),
  ];
}

/// Waktu sholat berikutnya (bisa melompat ke jadwal hari berikutnya).
class WaktuBerikutnya {
  const WaktuBerikutnya({
    required this.waktu,
    required this.instan,
    required this.jadwal,
    required this.hariIniKota,
  });

  final WaktuSholat waktu;
  final DateTime instan; // UTC
  final JadwalSholatHarian jadwal;

  /// Tanggal sipil "hari ini" di zona kota (jam 00:00 sebagai penanda).
  final DateTime hariIniKota;

  Duration sisa(DateTime sekarang) => instan.difference(sekarang.toUtc());

  /// Jam dinding kota pada jadwal terkait.
  DateTime get jamLokal {
    final DateTime u = instan.toUtc();
    return u.add(Duration(hours: jadwal.kota.zona.offsetJam));
  }

  /// Benar bila waktu ini jatuh pada tanggal sipil berikutnya
  /// (dihitung terhadap "hari ini" di zona kota).
  bool get besok {
    final DateTime a = DateTime.utc(jamLokal.year, jamLokal.month, jamLokal.day);
    final DateTime b = DateTime.utc(
        hariIniKota.year, hariIniKota.month, hariIniKota.day);
    return a.difference(b).inDays != 0;
  }
}

/// Cari waktu wajib berikutnya dari daftar jadwal yang sudah dihitung.
///
/// [jadwal] harus urut menaik menurut tanggal. Syuruq tidak dihitung karena
/// bukan waktu sholat.
WaktuBerikutnya? cariWaktuBerikutnya({
  required List<JadwalSholatHarian> jadwal,
  required DateTime sekarang,
}) {
  if (jadwal.isEmpty) return null;
  final DateTime kini = sekarang.toUtc();
  final int offset = jadwal.first.kota.zona.offsetJam;
  final DateTime dindingKota = kini.add(Duration(hours: offset));
  final DateTime hariIniKota =
      DateTime.utc(dindingKota.year, dindingKota.month, dindingKota.day);
  for (final JadwalSholatHarian j in jadwal) {
    for (final WaktuSholat w in WaktuSholat.wajibSaja) {
      final DateTime t = j.waktuUtc[w]!;
      if (t.isAfter(kini)) {
        return WaktuBerikutnya(
          waktu: w,
          instan: t,
          jadwal: j,
          hariIniKota: hariIniKota,
        );
      }
    }
  }
  return null;
}

/// Jumlah menit antara dua jam dinding (dipakai pengujian & tampilan).
int selisihMenit(DateTime a, DateTime b) =>
    a.difference(b).inMinutes.abs();
