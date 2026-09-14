/// Penyimpanan catatan sholat harian di perangkat (FR-88).
///
/// Bentuk: SATU berkas JSON kecil (`log_sholat.json`) di folder dokumen
/// aplikasi. Isinya peta tanggal -> daftar waktu wajib yang tercatat.
///
/// ATURAN PENTING:
/// 1. TIDAK PERNAH MELEMPAR. Berkas rusak, folder tidak bisa dipakai, atau
///    kunci tanggal salah -> dikembalikan catatan kosong, bukan galat.
/// 2. Operasi berkas di berkas ini SENGAJA sinkron (`readAsStringSync` /
///    `writeAsStringSync`) supaya tidak menggantung saat diuji di dalam
///    `testWidgets` (zona waktu palsu). Berkasnya kecil, jadi aman.
/// 3. Retensi memakai [bersihkanSebelum]; hari ini tidak pernah dihapus.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'model_log_sholat.dart';
import 'model_sholat.dart';
import 'penyimpanan_jadwal.dart' show PenentuFolder;

/// Format berkas: `{"versi":1,"diubah":"...","hari":{"YYYY-MM-DD":["subuh",...]}}`
class PenyimpananLogSholat {
  PenyimpananLogSholat({
    this.penentuFolder,
    this.namaBerkas = 'log_sholat.json',
  });

  /// Cara menentukan folder berkas (null = folder dokumen aplikasi).
  final PenentuFolder? penentuFolder;
  final String namaBerkas;

  Future<Directory> _folder() async =>
      await (penentuFolder ?? getApplicationDocumentsDirectory)();

  /// Berkas catatan; null bila folder tidak bisa dipakai.
  Future<File?> berkas() async {
    try {
      final Directory d = await _folder();
      if (!d.existsSync()) d.createSync(recursive: true);
      return File('${d.path}${Platform.pathSeparator}$namaBerkas');
    } catch (_) {
      return null;
    }
  }

  /// Baca seluruh isi berkas (selalu berhasil; rusak -> peta kosong).
  Future<Map<String, CatatanSholat>> _bacaSemua() async {
    final Map<String, CatatanSholat> hasil = <String, CatatanSholat>{};
    try {
      final File? f = await berkas();
      if (f == null || !f.existsSync()) return hasil;
      final String isi = f.readAsStringSync();
      if (isi.trim().isEmpty) return hasil;
      final Object? j = jsonDecode(isi);
      if (j is! Map) return hasil;
      final Object? hari = j['hari'];
      if (hari is! Map) return hasil;
      hari.forEach((Object? kunci, Object? nilai) {
        if (kunci is! String || !kunciSah(kunci)) return;
        if (nilai is! List) return;
        hasil[kunci] = CatatanSholat.fromJson(<String, dynamic>{
          'tanggal': kunci,
          'tercatat': nilai,
        });
      });
    } catch (_) {
      return <String, CatatanSholat>{};
    }
    return hasil;
  }

  /// Tulis seluruh peta (gagal tulis tidak melempar).
  Future<void> _tulisSemua(Map<String, CatatanSholat> semua) async {
    try {
      final File? f = await berkas();
      if (f == null) return;
      final List<String> kunci = semua.keys.toList()..sort();
      f.writeAsStringSync(jsonEncode(<String, Object>{
        'versi': 1,
        'diubah': DateTime.now().toUtc().toIso8601String(),
        'hari': <String, Object>{
          for (final String k in kunci) k: semua[k]!.kodeTercatat,
        },
      }));
    } catch (_) {
      // diamkan: catatan gagal disimpan bukan galat yang perlu tampil
    }
  }

  /// Baca catatan satu hari; hari tanpa penanda -> catatan kosong.
  Future<CatatanSholat> ambil(String tanggal) async {
    final Map<String, CatatanSholat> semua = await _bacaSemua();
    return semua[tanggal] ?? kosongPada(tanggal);
  }

  /// Ubah status satu waktu. [tercatat] = false untuk membatalkan penanda.
  /// Syuruq diabaikan (bukan sholat wajib); kunci tanggal salah diabaikan.
  Future<void> tandai(
    String tanggal,
    WaktuSholat waktu, {
    bool tercatat = true,
  }) async {
    if (!kunciSah(tanggal) || !waktu.wajib) return;
    try {
      final Map<String, CatatanSholat> semua = await _bacaSemua();
      final CatatanSholat lama = semua[tanggal] ?? kosongPada(tanggal);
      semua[tanggal] = lama.dengan(waktu, tercatat);
      await _tulisSemua(semua);
    } catch (_) {
      // diamkan
    }
  }

  /// Kosongkan seluruh penanda satu hari (tetap menyimpan barisnya).
  Future<void> kosongkanHari(String tanggal) async {
    if (!kunciSah(tanggal)) return;
    try {
      final Map<String, CatatanSholat> semua = await _bacaSemua();
      semua[tanggal] = kosongPada(tanggal);
      await _tulisSemua(semua);
    } catch (_) {
      // diamkan
    }
  }

  /// Salin penanda dari [dariTanggal] ke [keTanggal] (mis. untuk mengisi hari
  /// ini dari hari yang sudah lengkap). Bila hari sumber belum ada, tidak ada
  /// yang diubah.
  Future<void> salinHari(String dariTanggal, String keTanggal) async {
    if (!kunciSah(dariTanggal) || !kunciSah(keTanggal)) return;
    try {
      final Map<String, CatatanSholat> semua = await _bacaSemua();
      final CatatanSholat? sumber = semua[dariTanggal];
      if (sumber == null) return;
      semua[keTanggal] = CatatanSholat(
        tanggal: keTanggal,
        tercatat: <WaktuSholat>{
          for (final WaktuSholat w in WaktuSholat.wajibSaja)
            if (sumber.tercatatPada(w)) w,
        },
      );
      await _tulisSemua(semua);
    } catch (_) {
      // diamkan
    }
  }

  /// Buang catatan SEBELUM [batasTanggal] (retensi). Hari pada [batasTanggal]
  /// atau sesudahnya tetap disimpan, jadi "hari ini" tidak pernah terhapus
  /// bila batas = hari ini.
  Future<void> bersihkanSebelum(String batasTanggal) async {
    if (!kunciSah(batasTanggal)) return;
    try {
      final Map<String, CatatanSholat> semua = await _bacaSemua();
      final int sebelum = semua.length;
      semua.removeWhere((String kunci, CatatanSholat _) =>
          kunci.compareTo(batasTanggal) < 0);
      if (semua.length == sebelum) return;
      await _tulisSemua(semua);
    } catch (_) {
      // diamkan
    }
  }

  /// Catatan hari-hari yang benar-benar ada di berkas, dalam rentang
  /// [dariTanggal]..[sampaiTanggal] (keduanya ikut disertakan).
  Future<Map<String, CatatanSholat>> ambilRentang(
    String dariTanggal,
    String sampaiTanggal,
  ) async {
    final Map<String, CatatanSholat> semua = await _bacaSemua();
    if (!kunciSah(dariTanggal) || !kunciSah(sampaiTanggal)) {
      return <String, CatatanSholat>{};
    }
    if (dariTanggal.compareTo(sampaiTanggal) > 0) {
      return <String, CatatanSholat>{};
    }
    final List<String> kunci = semua.keys.toList()..sort();
    return <String, CatatanSholat>{
      for (final String k in kunci)
        if (k.compareTo(dariTanggal) >= 0 && k.compareTo(sampaiTanggal) <= 0)
          k: semua[k]!,
    };
  }
}
