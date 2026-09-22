/// FR-98 — repositori masjid terdekat (data dari jaringan + simpanan).
///
/// Prinsip jaringan Papi (12 Sep 2026): "harus bisa offline dan online".
/// Karena itu: hasil pencarian disimpan di `pengaturan` beserta waktunya;
/// saat offline, daftar lama tetap ditampilkan dengan keterangan
/// "data per waktu" — bukan gagal senyap dan bukan dikarang.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/ibadah/kiblat.dart';
import '../database/database.dart';
import 'pengaturan_repository.dart';

class Masjid {
  const Masjid({
    required this.nama,
    required this.lintang,
    required this.bujur,
    required this.jarakKm,
    required this.arahDerajat,
    this.alamat,
  });

  final String nama;
  final double lintang;
  final double bujur;
  final double jarakKm;
  final double arahDerajat;
  final String? alamat;

  String get arahTeks => arahMataAngin(arahDerajat);

  /// "1,2 km · Barat Laut".
  String get jarakTeks =>
      '${jarakKm.toStringAsFixed(2).replaceAll('.', ',')} km · $arahTeks';

  Map<String, dynamic> keJson() => {
        'nama': nama,
        'lintang': lintang,
        'bujur': bujur,
        'jarakKm': jarakKm,
        'arah': arahDerajat,
        'alamat': alamat,
      };

  static Masjid? dariJson(Map<String, dynamic> m) {
    final nama = m['nama'] as String?;
    final lat = (m['lintang'] as num?)?.toDouble();
    final lon = (m['bujur'] as num?)?.toDouble();
    if (nama == null || lat == null || lon == null) return null;
    return Masjid(
      nama: nama,
      lintang: lat,
      bujur: lon,
      jarakKm: (m['jarakKm'] as num?)?.toDouble() ?? 0,
      arahDerajat: (m['arah'] as num?)?.toDouble() ?? 0,
      alamat: m['alamat'] as String?,
    );
  }
}

/// Hasil pemuatan daftar masjid — selalu menyebut asal data.
class HasilMasjid {
  const HasilMasjid({
    required this.daftar,
    required this.dariSimpanan,
    this.waktu,
    this.pesan,
    this.galat,
  });

  final List<Masjid> daftar;

  /// true = dari simpanan di perangkat, bukan baru diambil.
  final bool dariSimpanan;
  final DateTime? waktu;

  /// Keterangan yang WAJIB ditampilkan (mis. "data per ...").
  final String? pesan;

  /// Kegagalan jaringan (kalau ada) — dilaporkan, tidak disembunyikan.
  final String? galat;

  bool get kosong => daftar.isEmpty;

  String get teksAsal {
    if (daftar.isEmpty) return pesan ?? 'Belum ada data masjid.';
    final t = waktu;
    final asal = dariSimpanan ? 'data tersimpan' : 'baru diambil';
    if (t == null) return 'Daftar masjid ($asal).';
    final dua = _dua;
    return 'Daftar masjid ($asal) per ${t.day}/${t.month}/${t.year} '
        '${dua(t.hour)}:${dua(t.minute)} · sumber: OpenStreetMap (Overpass API).'
        '${galat == null ? '' : ' $galat'}';
  }
}

class MasjidRepository {
  MasjidRepository(this.db, {DateTime Function()? jamSekarang, this.klien})
      : _jam = jamSekarang ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _jam;
  final HttpClient? klien;
  late final PengaturanRepository _pengaturan = PengaturanRepository(db);

  static const String kunciSimpanan = 'kiblat.masjid_terdekat';
  static const String urlOverpass = 'https://overpass-api.de/api/interpreter';

  /// Baca simpanan terakhir (selalu bisa dipanggil tanpa jaringan).
  Future<HasilMasjid> dariSimpanan() async {
    final teks = await _pengaturan.baca(kunciSimpanan);
    if (teks == null || teks.trim().isEmpty) {
      return const HasilMasjid(
        daftar: [],
        dariSimpanan: true,
        pesan: 'Belum ada daftar masjid tersimpan di perangkat ini.',
      );
    }
    try {
      final map = jsonDecode(teks) as Map<String, dynamic>;
      final waktu = DateTime.tryParse(map['waktu'] as String? ?? '');
      final daftar = ((map['masjid'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Masjid.dariJson(m.cast<String, dynamic>()))
          .whereType<Masjid>()
          .toList();
      return HasilMasjid(
        daftar: daftar,
        dariSimpanan: true,
        waktu: waktu,
        pesan: daftar.isEmpty
            ? 'Simpanan kosong.'
            : 'Menampilkan daftar tersimpan — belum diperbarui.',
      );
    } catch (_) {
      return const HasilMasjid(
        daftar: [],
        dariSimpanan: true,
        pesan: 'Simpanan masjid rusak dan tidak bisa dibaca.',
      );
    }
  }

  /// Ambil dari jaringan; bila gagal, kembalikan simpanan + [HasilMasjid.galat].
  Future<HasilMasjid> sekitar({
    required double lintang,
    required double bujur,
    int radiusMeter = 3000,
    Duration batasWaktu = const Duration(seconds: 20),
  }) async {
    try {
      final teks = await _ambilOverpass(
        lintang: lintang,
        bujur: bujur,
        radiusMeter: radiusMeter,
        batasWaktu: batasWaktu,
      );
      final daftar = uraiOverpass(teks, lintang: lintang, bujur: bujur);
      final waktu = _jam();
      await _pengaturan.simpan(
        kunciSimpanan,
        jsonEncode({
          'waktu': waktu.toIso8601String(),
          'masjid': daftar.map((m) => m.keJson()).toList(),
        }),
      );
      return HasilMasjid(
        daftar: daftar,
        dariSimpanan: false,
        waktu: waktu,
        pesan: daftar.isEmpty
            ? 'Tidak ada masjid ditemukan dalam ${radiusMeter ~/ 1000} km.'
            : null,
      );
    } catch (e) {
      final lama = await dariSimpanan();
      return HasilMasjid(
        daftar: lama.daftar,
        dariSimpanan: true,
        waktu: lama.waktu,
        pesan: lama.pesan,
        galat: 'Gagal mengambil data baru (${e.runtimeType}). '
            'Menampilkan data tersimpan.',
      );
    }
  }

  Future<String> _ambilOverpass({
    required double lintang,
    required double bujur,
    required int radiusMeter,
    required Duration batasWaktu,
  }) async {
    final klienPakai = klien ?? HttpClient();
    klienPakai.connectionTimeout = batasWaktu;
    final kueri = '[out:json][timeout:18];'
        'node(around:$radiusMeter,${lintang.toStringAsFixed(5)},${bujur.toStringAsFixed(5)})'
        '["amenity"="place_of_worship"]["religion"="muslim"];'
        'out body 40;';
    try {
      final req = await klienPakai
          .postUrl(Uri.parse(urlOverpass))
          .timeout(batasWaktu);
      req.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded');
      req.write('data=${Uri.encodeComponent(kueri)}');
      final res = await req.close().timeout(batasWaktu);
      if (res.statusCode != 200) {
        throw HttpException('kode ${res.statusCode}');
      }
      return await res.transform(utf8.decoder).join().timeout(batasWaktu);
    } finally {
      if (klien == null) klienPakai.close(force: true);
    }
  }
}

/// Uraikan jawaban Overpass menjadi daftar masjid (diurutkan dari terdekat).
List<Masjid> uraiOverpass(
  String teks, {
  required double lintang,
  required double bujur,
  int batas = 40,
}) {
  final Map<String, dynamic> map;
  try {
    map = jsonDecode(teks) as Map<String, dynamic>;
  } catch (_) {
    return const [];
  }
  final unsur = (map['elements'] as List?) ?? const [];
  final hasil = <Masjid>[];
  for (final e in unsur) {
    if (e is! Map) continue;
    final lat = (e['lat'] as num?)?.toDouble();
    final lon = (e['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) continue;
    final tags = (e['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final nama = (tags['name'] as String?)?.trim();
    hasil.add(Masjid(
      nama: (nama == null || nama.isEmpty) ? 'Masjid (tanpa nama di peta)' : nama,
      lintang: lat,
      bujur: lon,
      jarakKm: jarakKm(lintang, bujur, lat, lon),
      arahDerajat: arahKe(lintang, bujur, lat, lon),
      alamat: (tags['addr:street'] as String?)?.trim(),
    ));
  }
  hasil.sort((a, b) => a.jarakKm.compareTo(b.jarakKm));
  return hasil.length > batas ? hasil.sublist(0, batas) : hasil;
}

/// Dua digit (jam/menit) supaya teks sumber rapi tanpa perlu intl.
String _dua(int n) => n.toString().padLeft(2, '0');
