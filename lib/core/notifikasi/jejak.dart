/// Jejak pengingat — catatan kecil di berkas untuk bukti & penelusuran
/// (dipakai pekerja latar yang tidak punya akses UI).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Aliran aksi notifikasi untuk isolate utama (UI mendengarkan).
final StreamController<Map<String, dynamic>> _aliran =
    StreamController<Map<String, dynamic>>.broadcast();

Stream<Map<String, dynamic>> get aliranJejak => _aliran.stream;

void kabarkanJejak(Map<String, dynamic> data) {
  if (!_aliran.isClosed) _aliran.add(data);
}

/// Nama berkas jejak di direktori dokumen aplikasi.
const String namaBerkasJejak = 'jejak_pengingat.jsonl';

/// Batas waktu pencarian folder dokumen.
///
/// Pengingat dipasang dari UI dan dari isolate latar. Bila plugin path_provider
/// tidak menjawab (mis. saat uji atau isolate belum siap), pencarian folder
/// TIDAK BOLEH menggantung alur notifikasi selamanya.
const Duration batasWaktuJejak = Duration(seconds: 2);

/// Pengganti penentu berkas (dipakai uji: kembalikan null untuk menonaktifkan).
Future<File?> Function()? penentuJejak;

Future<File?> _berkas() async {
  final pengganti = penentuJejak;
  if (pengganti != null) return pengganti();
  try {
    final dir = await getApplicationDocumentsDirectory().timeout(batasWaktuJejak);
    return File('${dir.path}/$namaBerkasJejak');
  } catch (_) {
    return null;
  }
}

/// Tulis satu baris jejak (JSON per baris). Gagal tulis tidak mengganggu alur.
Future<void> catatJejak(Map<String, dynamic> data) async {
  try {
    final f = await _berkas();
    if (f == null) return;
    await f.writeAsString(
      '${jsonEncode({...data, 'waktu': DateTime.now().toIso8601String()})}\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {
    // abaikan: jejak bersifat pelengkap
  } finally {
    kabarkanJejak(data);
  }
}

/// Baca maksimal [maks] baris terakhir jejak (terbaru dulu).
Future<List<Map<String, dynamic>>> bacaJejak({int maks = 20}) async {
  try {
    final f = await _berkas();
    if (f == null || !await f.exists()) return const [];
    final baris = (await f.readAsString()).trim().split('\n');
    final hasil = <Map<String, dynamic>>[];
    for (final b in baris.reversed) {
      if (b.trim().isEmpty) continue;
      final m = jsonDecode(b);
      if (m is Map<String, dynamic>) hasil.add(m);
      if (hasil.length >= maks) break;
    }
    return hasil;
  } catch (_) {
    return const [];
  }
}
