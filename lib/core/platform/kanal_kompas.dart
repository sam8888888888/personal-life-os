/// FR-98 — saluran arah hadap perangkat (kompas).
///
/// Sisi Android: `KanalKompas.kt` (SensorManager, TYPE_ROTATION_VECTOR).
/// Sisi Dart ini hanya menerjemahkan; bila sensor tidak ada / izin ditolak,
/// [aliran] mengirim `null` dan layar memakai arah mata angin (tanpa angka palsu).
library;

import 'package:flutter/services.dart';

class HeadingKompas {
  const HeadingKompas({required this.derajat, this.akurasi});

  /// Arah hadap 0–360 (0 = Utara).
  final double derajat;

  /// Perkiraan galat derajat dari sensor; null = sensor tidak melaporkan.
  final double? akurasi;

  bool get sah => derajat >= 0 && derajat <= 360;
}

class KanalKompas {
  KanalKompas._();

  static const String namaSaluran = 'plo/kompas';
  static const MethodChannel _kanal = MethodChannel('plo/kompas');
  static const EventChannel _aliran = EventChannel('plo/kompas/arah');

  /// Saluran tiruan untuk uji/widget tanpa sensor nyata.
  static Stream<HeadingKompas?>? _tiruan;

  /// Pakai aliran tiruan (khusus uji). `null` = kembali ke sensor nyata.
  static void pakaiTiruan(Stream<HeadingKompas?>? aliran) => _tiruan = aliran;

  /// Apakah perangkat melaporkan punya sensor kompas. Gagal → false
  /// (kita memilih "tidak ada" daripada mengarang arah).
  static Future<bool> sensorAda() async {
    if (_tiruan != null) return true;
    try {
      final hasil = await _kanal.invokeMethod<bool>('sensorAda');
      return hasil ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Aliran arah hadap. Bila sensor tidak ada, aliran tetap hidup tetapi
  /// mengirim null (layar memakai mode mata angin).
  static Stream<HeadingKompas?> aliran() {
    final t = _tiruan;
    if (t != null) return t;
    return _aliran.receiveBroadcastStream().map<HeadingKompas?>(uraiPesan);
  }

  /// Uraikan pesan dari Android: `{'derajat': 123.4, 'akurasi': 8.2}`.
  static HeadingKompas? uraiPesan(dynamic pesan) {
    if (pesan is! Map) return null;
    final d = pesan['derajat'];
    if (d is! num) return null;
    final h = HeadingKompas(
      derajat: d.toDouble(),
      akurasi: (pesan['akurasi'] as num?)?.toDouble(),
    );
    return h.sah ? h : null;
  }
}
