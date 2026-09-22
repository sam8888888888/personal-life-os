/// FR-152 — repositori kurs: simpan/muat dari `pengaturan` + ambil dari jaringan.
///
/// Aturan PRD: "kurs menampilkan sumber & waktu pembaruan". Karena itu:
/// * kurs SELALU disimpan bersama sumber + waktu;
/// * bila jaringan gagal, kurs lama TETAP dipakai tetapi umurnya ditampilkan
///   ("data per waktu") dan kegagalan dilaporkan apa adanya.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/utils/kurs.dart';
import '../database/database.dart';
import 'pengaturan_repository.dart';

class KursRepository {
  KursRepository(this.db, {DateTime Function()? jamSekarang, this.klien})
      : _jam = jamSekarang ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _jam;
  final HttpClient? klien;
  late final PengaturanRepository _pengaturan = PengaturanRepository(db);

  static const String kunciKurs = 'kurs.mata_uang';

  /// Endpoint publik tanpa kunci API (data harian Bank-bank sentral via
  /// exchangerate). Sumbernya dicatat apa adanya di [Kurs.sumber].
  static const String urlKurs =
      'https://open.er-api.com/v6/latest/IDR';

  Future<Kurs?> muat() async {
    final teks = await _pengaturan.baca(kunciKurs);
    return Kurs.dariJson(teks);
  }

  Future<void> simpanKurs(Kurs kurs) =>
      _pengaturan.simpan(kunciKurs, jsonEncode(kurs.keJson()));

  /// Ambil kurs terbaru. Melempar [KursGagal] bila jaringan gagal — pemanggil
  /// (layar) menampilkan pesan & tetap memakai kurs tersimpan.
  Future<Kurs> ambilDariJaringan({Duration batasWaktu = const Duration(seconds: 12)}) async {
    final klienPakai = klien ?? HttpClient();
    klienPakai.connectionTimeout = batasWaktu;
    try {
      final req = await klienPakai.getUrl(Uri.parse(urlKurs)).timeout(batasWaktu);
      final res = await req.close().timeout(batasWaktu);
      if (res.statusCode != 200) {
        throw KursGagal('Server kurs menjawab ${res.statusCode}.');
      }
      final teks = await res.transform(utf8.decoder).join().timeout(batasWaktu);
      final kurs = kursDariErApi(teks, sekarang: _jam());
      await simpanKurs(kurs);
      return kurs;
    } on KursGagal {
      rethrow;
    } catch (e) {
      throw KursGagal('Tidak bisa mengambil kurs: ${e.runtimeType}. '
          'Periksa sambungan internet lalu coba lagi.');
    } finally {
      if (klien == null) klienPakai.close(force: true);
    }
  }

  /// Isi kurs manual (mis. tidak ada internet) — sumbernya ditandai "manual".
  Future<Kurs> isiManual(String kode, double nilai) async {
    final salah = periksaKursManual(kode, nilai);
    if (salah != null) throw KursGagal(salah);
    final lama = await muat();
    final peta = <String, double>{
      'IDR': 1,
      ...?lama?.perRupiah,
      kode.toUpperCase(): nilai,
    };
    final kurs = Kurs(
      perRupiah: peta,
      sumber: 'diisi manual oleh pengguna',
      waktu: _jam(),
    );
    await simpanKurs(kurs);
    return kurs;
  }
}

class KursGagal implements Exception {
  KursGagal(this.pesan);
  final String pesan;
  @override
  String toString() => pesan;
}

/// Uraikan jawaban open.er-api.com (IDR sebagai basis):
/// `{"result":"success","time_last_update_utc":"...","rates":{"USD":0.0000615,...}}`
/// → berapa Rupiah untuk 1 unit mata uang itu.
Kurs kursDariErApi(String teks, {DateTime? sekarang}) {
  final Map<String, dynamic> map;
  try {
    map = jsonDecode(teks) as Map<String, dynamic>;
  } catch (_) {
    throw KursGagal('Jawaban server kurs tidak bisa dibaca.');
  }
  final rates = map['rates'];
  if (rates is! Map) {
    throw KursGagal('Jawaban server kurs tidak memuat daftar kurs.');
  }
  final peta = <String, double>{'IDR': 1};
  for (final kode in const ['MYR', 'USD']) {
    final v = rates[kode];
    if (v is num && v > 0) {
      peta[kode] = 1 / v.toDouble();
    }
  }
  if (peta.length <= 1) {
    throw KursGagal('Server kurs tidak memuat MYR/USD.');
  }
  final waktuTeks = map['time_last_update_utc'] as String?;
  final waktu = (waktuTeks == null ? null : _parseRfc1123(waktuTeks)) ??
      sekarang ??
      DateTime.now();
  return Kurs(
    perRupiah: peta,
    sumber: 'open.er-api.com (exchangerate-api)',
    waktu: waktu.toLocal(),
  );
}

DateTime? _parseRfc1123(String teks) {
  const bulan = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };
  final m = RegExp(r'(\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})')
      .firstMatch(teks);
  if (m == null) return null;
  final b = bulan[m.group(2)];
  if (b == null) return null;
  return DateTime.utc(
    int.parse(m.group(3)!),
    b,
    int.parse(m.group(1)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
    int.parse(m.group(6)!),
  );
}
