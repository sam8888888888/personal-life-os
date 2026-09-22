/// FR-31 & FR-151 — jembatan ke widget layar utama Android.
library;

import 'package:flutter/services.dart';

const String namaKanalWidget = 'lifeos/widget';

class KanalWidget {
  const KanalWidget({this.kanal});

  final MethodChannel? kanal;

  MethodChannel get _kanal => kanal ?? const MethodChannel(namaKanalWidget);

  /// Kirim ringkasan yang harus tampil di widget layar utama.
  ///
  /// [baris] berisi paling banyak tiga baris; [aksi] berisi tombol cepat yang
  /// harus dipasang widget (mis. `lunas` dengan id tagihan terdekat).
  Future<bool> perbarui({
    required String judul,
    required String total,
    required String catatan,
    required List<String> baris,
    List<String> idBaris = const [],
    String? aksiId,
  }) async {
    try {
      return await _kanal.invokeMethod<bool>('perbarui', {
            'judul': judul,
            'total': total,
            'catatan': catatan,
            'baris': baris,
            'idBaris': idBaris,
            'aksiId': aksiId ?? '',
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// FR-151 — aksi yang diminta dari widget layar utama / aksi cepat ikon.
///
/// Aplikasi menjalankan aksi ini **begitu dibuka** dari widget, jadi pengguna
/// cukup satu ketukan (bukan: buka aplikasi lalu tekan lagi).
class AksiWidget {
  const AksiWidget({required this.aksi, this.id, this.judul});

  final String aksi;
  final String? id;
  final String? judul;

  static AksiWidget? dariPeta(Object? mentah) {
    if (mentah is! Map) return null;
    final aksi = mentah['aksi'];
    if (aksi is! String || aksi.isEmpty) return null;
    final id = mentah['id'];
    final judul = mentah['judul'];
    return AksiWidget(
      aksi: aksi,
      id: id is String && id.isNotEmpty ? id : null,
      judul: judul is String && judul.isNotEmpty ? judul : null,
    );
  }

  @override
  String toString() => 'AksiWidget($aksi, id: $id)';
}
