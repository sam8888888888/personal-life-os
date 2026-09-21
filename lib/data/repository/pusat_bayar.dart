/// FR-42 — Pusat Bayar: preferensi aplikasi bayar per tagihan, nomor VA/QRIS,
/// catatan konfirmasi pembayaran.
///
/// Disimpan di tabel `pengaturan` sebagai satu JSON (kunci `pusat_bayar`) supaya
/// tidak perlu ubah skema database — pilihan ini memang setelan pengguna, bukan
/// data tagihan yang ikut tersinkron.
library;

import 'dart:convert';

import 'pengaturan_repository.dart';

/// Kunci penyimpanan di tabel pengaturan.
const String kunciPusatBayar = 'pusat_bayar';

/// Jenis nomor pembayaran yang lazim dipakai di Indonesia.
enum JenisNomorBayar {
  va('va', 'Virtual Account'),
  qris('qris', 'QRIS'),
  lain('lain', 'Lainnya');

  const JenisNomorBayar(this.nilaiDb, this.label);
  final String nilaiDb;
  final String label;

  static JenisNomorBayar dariDb(String? v) => JenisNomorBayar.values
      .firstWhere((e) => e.nilaiDb == v, orElse: () => JenisNomorBayar.va);
}

/// Aplikasi bayar yang biasa dipakai (bisa ditambah pengguna lewat "Lainnya").
const List<String> aplikasiBayarBawaan = [
  'BCA mobile',
  'Livin by Mandiri',
  'BRImo',
  'BNI Mobile',
  'DANA',
  'OVO',
  'GoPay',
  'ShopeePay',
  'SeaBank',
  'Jago',
  'Lainnya',
];

/// Preferensi pembayaran satu tagihan.
class PreferensiBayar {
  const PreferensiBayar({
    this.aplikasi = '',
    this.jenis = JenisNomorBayar.va,
    this.nomor = '',
    this.catatan = '',
    this.catatanPada,
  });

  final String aplikasi;
  final JenisNomorBayar jenis;
  final String nomor;

  /// Catatan konfirmasi pembayaran (mis. "sudah transfer, tunggu verifikasi").
  final String catatan;
  final DateTime? catatanPada;

  bool get adaNomor => nomor.trim().isNotEmpty;
  bool get adaCatatan => catatan.trim().isNotEmpty;
  bool get kosong =>
      aplikasi.trim().isEmpty && nomor.trim().isEmpty && catatan.trim().isEmpty;

  PreferensiBayar salin({
    String? aplikasi,
    JenisNomorBayar? jenis,
    String? nomor,
    String? catatan,
    DateTime? catatanPada,
    bool hapusCatatan = false,
  }) {
    return PreferensiBayar(
      aplikasi: aplikasi ?? this.aplikasi,
      jenis: jenis ?? this.jenis,
      nomor: nomor ?? this.nomor,
      catatan: hapusCatatan ? '' : (catatan ?? this.catatan),
      catatanPada: hapusCatatan ? null : (catatanPada ?? this.catatanPada),
    );
  }

  Map<String, dynamic> keJson() => {
        'aplikasi': aplikasi,
        'jenis': jenis.nilaiDb,
        'nomor': nomor,
        'catatan': catatan,
        if (catatanPada != null) 'catatan_pada': catatanPada!.toIso8601String(),
      };

  factory PreferensiBayar.dariJson(Map<String, dynamic> j) => PreferensiBayar(
        aplikasi: j['aplikasi'] as String? ?? '',
        jenis: JenisNomorBayar.dariDb(j['jenis'] as String?),
        nomor: j['nomor'] as String? ?? '',
        catatan: j['catatan'] as String? ?? '',
        catatanPada: DateTime.tryParse(j['catatan_pada'] as String? ?? ''),
      );
}

/// Baca/tulis preferensi pembayaran (satu JSON di pengaturan).
class PusatBayarPenyimpanan {
  const PusatBayarPenyimpanan(this.pengaturan);

  final PengaturanRepository pengaturan;

  Future<Map<int, PreferensiBayar>> semua() async {
    final teks = await pengaturan.baca(kunciPusatBayar);
    if (teks == null || teks.trim().isEmpty) return {};
    final Object? data = jsonDecode(teks);
    if (data is! Map) return {};
    final hasil = <int, PreferensiBayar>{};
    data.forEach((kunci, nilai) {
      final id = int.tryParse(kunci.toString());
      if (id == null || nilai is! Map) return;
      hasil[id] = PreferensiBayar.dariJson(
          nilai.map((k, v) => MapEntry(k.toString(), v)));
    });
    return hasil;
  }

  Future<void> simpan(int tagihanId, PreferensiBayar p) async {
    final peta = await semua();
    if (p.kosong) {
      peta.remove(tagihanId);
    } else {
      peta[tagihanId] = p;
    }
    await _tulis(peta);
  }

  Future<void> hapus(int tagihanId) async {
    final peta = await semua()..remove(tagihanId);
    await _tulis(peta);
  }

  Future<void> _tulis(Map<int, PreferensiBayar> peta) async {
    final isi = <String, dynamic>{
      for (final e in peta.entries) e.key.toString(): e.value.keJson(),
    };
    await pengaturan.simpan(kunciPusatBayar, jsonEncode(isi));
  }
}
