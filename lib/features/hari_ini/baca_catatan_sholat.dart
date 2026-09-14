/// Pembacaan jumlah sholat tercatat hari ini (FR-88) untuk kartu pilar Ibadah.
///
/// Sengaja defensif: bila penyimpanan belum bisa dibuka (mis. izin folder
/// belum ada), hasilnya null dan kartu menulis "Belum ada catatan hari ini" —
/// tidak pernah menuduh, dan tidak pernah menampilkan galat ke pengguna.
library;

import '../../core/ibadah/model_log_sholat.dart';
import '../../core/ibadah/penyimpanan_log_sholat.dart';

Future<int?> bacaJumlahSholatHariIni({
  PenyimpananLogSholat? penyimpanan,
  DateTime Function()? jamSekarang,
}) async {
  try {
    final simpan = penyimpanan ?? PenyimpananLogSholat();
    final sekarang = jamSekarang?.call() ?? DateTime.now();
    final catatan = await simpan.ambil(tanggalKunci(sekarang));
    // 0 catatan diperlakukan sama dengan "belum ada catatan": tidak memberi
    // kesan penilaian (III-11).
    return catatan.jumlah == 0 ? null : catatan.jumlah;
  } catch (_) {
    return null;
  }
}
