/// Cache jadwal sholat di perangkat (FR-86 bagian "Online: Tidak").
///
/// Sifat: satu berkas JSON di folder dokumen aplikasi. Tidak pernah mengunci
/// antarmuka: setiap kegagalan (berkas rusak, izin ditolak) hanya menghasilkan
/// "tidak ada cache", bukan galat yang tampil ke pengguna.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'model_sholat.dart';
import 'penghitung_sholat.dart';

/// Penentu folder berkas (bisa diganti saat pengujian).
typedef PenentuFolder = Future<Directory> Function();

class PenyimpananJadwal {
  PenyimpananJadwal({
    this.penentuFolder,
    this.namaBerkas = 'jadwal_sholat.json',
    this.hariSimpan = 90,
  });

  /// Cara menentukan folder berkas (null = folder dokumen aplikasi).
  final PenentuFolder? penentuFolder;
  final String namaBerkas;

  /// Lama simpan cache (hari) — kebijakan bergulir 90 hari.
  final int hariSimpan;

  Future<Directory> _folder() async =>
      await (penentuFolder ?? getApplicationDocumentsDirectory)();

  /// Berkas cache; null bila folder tidak bisa dipakai.
  Future<File?> berkas() async {
    try {
      final Directory d = await _folder();
      if (!d.existsSync()) await d.create(recursive: true);
      return File('${d.path}${Platform.pathSeparator}$namaBerkas');
    } catch (_) {
      return null;
    }
  }

  /// Kunci unik satu hasil hitung.
  static String kunci(JadwalSholatHarian j) =>
      '${j.tanggalKota.toIso8601String().substring(0, 10)}'
      '|${j.kodeMetode}|${j.asharHanafi ? 1 : 0}'
      '|${j.kota.lintang}|${j.kota.bujur}'
      '|${_koreksiKunci(j.koreksiMenit)}';

  static String _koreksiKunci(Map<WaktuSholat, int> k) {
    final List<String> bagian = <String>[
      for (final WaktuSholat w in WaktuSholat.values)
        if ((k[w] ?? 0) != 0) '${w.name}:${k[w]}',
    ];
    return bagian.isEmpty ? '-' : bagian.join(',');
  }

  /// Baca seluruh isi cache (kosong bila gagal).
  Future<Map<String, JadwalSholatHarian>> _bacaSemua() async {
    final Map<String, JadwalSholatHarian> hasil = <String, JadwalSholatHarian>{};
    try {
      final File? f = await berkas();
      if (f == null || !f.existsSync()) return hasil;
      final String isi = await f.readAsString();
      if (isi.trim().isEmpty) return hasil;
      final Object? j = jsonDecode(isi);
      if (j is! Map) return hasil;
      final Object? hari = j['hari'];
      if (hari is! List) return hasil;
      for (final Object? item in hari) {
        if (item is! Map) continue;
        try {
          final JadwalSholatHarian jj =
              JadwalSholatHarian.fromJson(item.cast<String, dynamic>());
          hasil[kunci(jj)] = jj;
        } catch (_) {
          // satu baris rusak tidak menggagalkan seluruh cache
        }
      }
    } catch (_) {
      return <String, JadwalSholatHarian>{};
    }
    return hasil;
  }

  /// Simpan/segarkan beberapa hari, lalu pangkas cache lama.
  Future<int> simpanBanyak(List<JadwalSholatHarian> daftar,
      {DateTime? sekarang}) async {
    try {
      final File? f = await berkas();
      if (f == null) return 0;
      final Map<String, JadwalSholatHarian> isi = await _bacaSemua();
      for (final JadwalSholatHarian j in daftar) {
        isi[kunci(j)] = j;
      }
      final Map<String, JadwalSholatHarian> dipangkas =
          _pangkas(isi, sekarang ?? DateTime.now());
      await f.writeAsString(jsonEncode(<String, Object>{
        'versi': 1,
        'disimpan': DateTime.now().toUtc().toIso8601String(),
        'hari': <Object>[
          for (final JadwalSholatHarian j in dipangkas.values) j.toJson(),
        ],
      }));
      return dipangkas.length;
    } catch (_) {
      return 0;
    }
  }

  /// Buang entri di luar rentang [sekarang - hariSimpan, sekarang + 30 hari].
  static Map<String, JadwalSholatHarian> _pangkas(
    Map<String, JadwalSholatHarian> isi,
    DateTime sekarang,
  ) {
    final DateTime batasAwal =
        DateTime.utc(sekarang.year, sekarang.month, sekarang.day)
            .subtract(Duration(days: 90));
    final DateTime batasAkhir =
        DateTime.utc(sekarang.year, sekarang.month, sekarang.day)
            .add(const Duration(days: 30));
    isi.removeWhere((String _, JadwalSholatHarian j) =>
        j.tanggalKota.isBefore(batasAwal) || j.tanggalKota.isAfter(batasAkhir));
    return isi;
  }

  /// Ambil satu jadwal dari cache; null bila belum ada.
  Future<JadwalSholatHarian?> ambil({
    required DateTime tanggal,
    required KotaSholat kota,
    required String kodeMetode,
    bool asharHanafi = false,
    Map<WaktuSholat, int> koreksiMenit = const <WaktuSholat, int>{},
  }) async {
    final JadwalSholatHarian polos = JadwalSholatHarian(
      tanggalKota: DateTime.utc(tanggal.year, tanggal.month, tanggal.day),
      kota: kota,
      kodeMetode: kodeMetode,
      namaMetode: MetodeHitungSholat.dariKode(kodeMetode).label,
      asharHanafi: asharHanafi,
      koreksiMenit: koreksiMenit,
      waktuUtc: const <WaktuSholat, DateTime>{},
    );
    return (await _bacaSemua())[kunci(polos)];
  }

  /// Ambil jadwal tersimpan untuk satu kota (urut tanggal).
  Future<List<JadwalSholatHarian>> ambilRentang(KotaSholat kota) async {
    final List<JadwalSholatHarian> isi = (await _bacaSemua())
        .values
        .where((JadwalSholatHarian j) =>
            j.kota.nama == kota.nama &&
            j.kota.lintang == kota.lintang &&
            j.kota.bujur == kota.bujur)
        .toList()
      ..sort((JadwalSholatHarian a, JadwalSholatHarian b) =>
          a.tanggalKota.compareTo(b.tanggalKota));
    return isi;
  }

  /// Hapus berkas cache.
  Future<void> bersihkan() async {
    try {
      final File? f = await berkas();
      if (f != null && f.existsSync()) await f.delete();
    } catch (_) {
      // diamkan: pembersihan gagal bukan masalah bagi pengguna
    }
  }
}
