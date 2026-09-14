/// Model untuk FR-86 (Jadwal Sholat) dan FR-88 (Pelacakan 5 waktu).
///
/// ATURAN WAKTU (penting):
/// Semua waktu sholat disimpan sebagai INSTAN ABSOLUT dalam frame UTC
/// (`DateTime` yang `.isUtc == true`). Untuk menampilkan jam dinding kota tujuan,
/// panggil [JadwalSholatHarian.waktuLokal] — hasilnya `DateTime` ber-frame UTC
/// yang ANGKA jam/menitnya adalah waktu dinding zona kota (WIB/WITA/WIT).
/// Cara ini dipakai karena `adhan_dart` mengembalikan instan absolut, dan
/// perangkat pengguna bisa berada di zona waktu yang berbeda dari kota pilihan.
library;

/// Zona waktu Indonesia (tanpa daylight saving — sudah dicek: Indonesia tidak
/// memakai DST, jadi offset tetap sepanjang tahun).
enum ZonaIndonesia {
  wib('WIB', 7, 'Waktu Indonesia Barat'),
  wita('WITA', 8, 'Waktu Indonesia Tengah'),
  wit('WIT', 9, 'Waktu Indonesia Timur');

  const ZonaIndonesia(this.label, this.offsetJam, this.namaPanjang);

  final String label;
  final int offsetJam;
  final String namaPanjang;

  /// Terjemahan nama zona IANA -> zona Indonesia.
  static ZonaIndonesia dariIana(String iana) {
    switch (iana) {
      case 'Asia/Makassar':
      case 'Asia/Ujung_Pandang':
      case 'Asia/Singapore':
      case 'Asia/Kuching':
        return ZonaIndonesia.wita;
      case 'Asia/Jayapura':
        return ZonaIndonesia.wit;
      case 'Asia/Jakarta':
      case 'Asia/Pontianak':
      default:
        return ZonaIndonesia.wib;
    }
  }
}

/// Lima waktu sholat wajib + syuruq (matahari terbit, bukan sholat).
enum WaktuSholat {
  subuh('Subuh', 'Sebelum matahari terbit'),
  syuruq('Syuruq', 'Matahari terbit — bukan waktu sholat'),
  dzuhur('Dzuhur', 'Setelah matahari tergelincir'),
  ashar('Ashar', 'Sore'),
  maghrib('Maghrib', 'Setelah matahari terbenam'),
  isya('Isya', 'Malam');

  const WaktuSholat(this.label, this.keterangan);

  final String label;
  final String keterangan;

  /// Syuruq hanya penanda, bukan sholat wajib.
  bool get wajib => this != WaktuSholat.syuruq;

  /// Lima waktu wajib, urut.
  static const List<WaktuSholat> wajibSaja = <WaktuSholat>[
    WaktuSholat.subuh,
    WaktuSholat.dzuhur,
    WaktuSholat.ashar,
    WaktuSholat.maghrib,
    WaktuSholat.isya,
  ];
}

/// Kota (atau lokasi pilihan) tempat jadwal sholat dihitung.
class KotaSholat {
  const KotaSholat({
    required this.nama,
    required this.provinsi,
    required this.lintang,
    required this.bujur,
    required this.zona,
  });

  /// Lokasi yang diisi sendiri oleh pengguna.
  factory KotaSholat.kustom({
    required double lintang,
    required double bujur,
    required ZonaIndonesia zona,
    String nama = 'Lokasi pilihan Anda',
  }) =>
      KotaSholat(
        nama: nama,
        provinsi: 'Diisi sendiri',
        lintang: lintang,
        bujur: bujur,
        zona: zona,
      );

  final String nama;
  final String provinsi;
  final double lintang;
  final double bujur;
  final ZonaIndonesia zona;

  String get labelLengkap => '$nama — ${zona.label}';

  bool get koordinatWajar =>
      lintang >= -90 && lintang <= 90 && bujur >= -180 && bujur <= 180;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'nama': nama,
        'provinsi': provinsi,
        'lintang': lintang,
        'bujur': bujur,
        'zona': zona.name,
      };

  factory KotaSholat.fromJson(Map<String, dynamic> j) => KotaSholat(
        nama: j['nama'] as String,
        provinsi: (j['provinsi'] ?? '') as String,
        lintang: (j['lintang'] as num).toDouble(),
        bujur: (j['bujur'] as num).toDouble(),
        zona: ZonaIndonesia.values.firstWhere(
          (ZonaIndonesia z) => z.name == j['zona'],
          orElse: () => ZonaIndonesia.wib,
        ),
      );

  @override
  String toString() => 'KotaSholat($nama, $lintang, $bujur, ${zona.label})';
}

/// Hasil hitung jadwal sholat satu hari untuk satu kota.
class JadwalSholatHarian {
  JadwalSholatHarian({
    required this.tanggalKota,
    required this.kota,
    required this.kodeMetode,
    required this.namaMetode,
    required this.asharHanafi,
    required Map<WaktuSholat, DateTime> waktuUtc,
    this.koreksiMenit = const <WaktuSholat, int>{},
  }) : waktuUtc = Map<WaktuSholat, DateTime>.unmodifiable(waktuUtc);

  /// Tanggal sipil kota tujuan (jam 00:00, frame UTC sebagai penanda tanggal).
  final DateTime tanggalKota;
  final KotaSholat kota;
  final String kodeMetode;
  final String namaMetode;
  final bool asharHanafi;

  /// Instan absolut tiap waktu (UTC).
  final Map<WaktuSholat, DateTime> waktuUtc;

  /// Koreksi menit yang dipakai (0 = tanpa koreksi).
  final Map<WaktuSholat, int> koreksiMenit;

  /// Waktu dinding zona kota. Angka jam/menit pada hasil = jam setempat kota.
  DateTime waktuLokal(WaktuSholat w) {
    final DateTime u = waktuUtc[w]!;
    return u.toUtc().add(Duration(hours: kota.zona.offsetJam));
  }

  DateTime? waktuLokalAtauNull(WaktuSholat w) =>
      waktuUtc.containsKey(w) ? waktuLokal(w) : null;

  /// Waktu wajib berikutnya setelah [sekarang] (instan bebas, dibandingkan
  /// sebagai instan absolut).
  WaktuSholat? berikutnya(DateTime sekarang) {
    final DateTime kini = sekarang.toUtc();
    for (final WaktuSholat w in WaktuSholat.wajibSaja) {
      if (waktuUtc[w]!.isAfter(kini)) return w;
    }
    return null; // semua waktu hari ini sudah lewat -> pakai jadwal besok
  }

  /// Sisa waktu menuju [w] pada hari ini; null bila sudah lewat.
  Duration? sisaKe(WaktuSholat w, DateTime sekarang) {
    final DateTime t = waktuUtc[w]!;
    if (!t.isAfter(sekarang.toUtc())) return null;
    return t.difference(sekarang.toUtc());
  }

  String get penandaSumber =>
      'Dihitung untuk ${kota.nama} (${kota.zona.label}), '
      '${tanggalKota.day.toString().padLeft(2, '0')}-'
      '${tanggalKota.month.toString().padLeft(2, '0')}-'
      '${tanggalKota.year}';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tanggal': tanggalKota.toIso8601String(),
        'kota': kota.toJson(),
        'kodeMetode': kodeMetode,
        'namaMetode': namaMetode,
        'asharHanafi': asharHanafi,
        'waktuUtc': <String, String>{
          for (final MapEntry<WaktuSholat, DateTime> e in waktuUtc.entries)
            e.key.name: e.value.toUtc().toIso8601String(),
        },
        'koreksiMenit': <String, int>{
          for (final MapEntry<WaktuSholat, int> e in koreksiMenit.entries)
            e.key.name: e.value,
        },
      };

  factory JadwalSholatHarian.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> w = (j['waktuUtc'] as Map).cast<String, dynamic>();
    final Map<WaktuSholat, DateTime> waktu = <WaktuSholat, DateTime>{};
    for (final WaktuSholat ws in WaktuSholat.values) {
      final Object? t = w[ws.name];
      if (t is String) waktu[ws] = DateTime.parse(t).toUtc();
    }
    final Map<String, dynamic> k =
        ((j['koreksiMenit'] ?? <String, dynamic>{}) as Map).cast<String, dynamic>();
    return JadwalSholatHarian(
      tanggalKota: DateTime.parse(j['tanggal'] as String).toUtc(),
      kota: KotaSholat.fromJson((j['kota'] as Map).cast<String, dynamic>()),
      kodeMetode: j['kodeMetode'] as String,
      namaMetode: j['namaMetode'] as String,
      asharHanafi: (j['asharHanafi'] ?? false) as bool,
      waktuUtc: waktu,
      koreksiMenit: <WaktuSholat, int>{
        for (final MapEntry<String, dynamic> e in k.entries)
          if (WaktuSholat.values.any((WaktuSholat x) => x.name == e.key))
            WaktuSholat.values.firstWhere((WaktuSholat x) => x.name == e.key):
                e.value as int,
      },
    );
  }
}

/// Format jam dinding `HH:mm` (tanpa locale, aman untuk isolate latar).
String jamMenit(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Tanggal `dd-MM-yyyy` (tanpa locale).
String tanggalPendek(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
