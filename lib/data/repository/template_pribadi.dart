/// FR-09 — Template tagihan pribadi (disimpan pengguna, bukan bawaan).
///
/// Pengguna bisa menyimpan tagihan yang sering dipakai sebagai template, lalu
/// memakainya lagi lewat chip "Cepat mengisi dari template" di form tagihan.
///
/// Penyimpanan memakai tabel `pengaturan` (k-v) dengan satu kunci berisi JSON —
/// tidak menambah tabel/skema. Jalur upgrade: bila kelak perlu disinkronkan
/// antar HP, pindahkan ke tabel sendiri dan ikutkan di modul sinkron.
library;

import 'dart:convert';

import 'pengaturan_repository.dart';

/// Satu template pribadi.
class TemplatePribadi {
  const TemplatePribadi({
    required this.nama,
    required this.perkiraanSen,
    required this.frekuensi,
    required this.leadHari,
    this.catatan,
  });

  final String nama;
  final int perkiraanSen;
  final String frekuensi;
  final List<int> leadHari;
  final String? catatan;

  Map<String, dynamic> kePeta() => {
        'nama': nama,
        'perkiraanSen': perkiraanSen,
        'frekuensi': frekuensi,
        'leadHari': leadHari,
        if (catatan != null) 'catatan': catatan,
      };

  static TemplatePribadi? dariPeta(Map<String, dynamic> peta) {
    final nama = peta['nama'];
    if (nama is! String || nama.trim().isEmpty) return null;
    final sen = peta['perkiraanSen'];
    final lead = peta['leadHari'];
    return TemplatePribadi(
      nama: nama,
      perkiraanSen: sen is int ? sen : 0,
      frekuensi: peta['frekuensi'] is String ? peta['frekuensi'] as String : 'bulanan',
      leadHari: lead is List
          ? lead.whereType<int>().toList()
          : const <int>[7, 3, 1],
      catatan: peta['catatan'] is String ? peta['catatan'] as String : null,
    );
  }

  @override
  String toString() => 'TemplatePribadi($nama)';
}

/// Kunci penyimpanan di tabel `pengaturan`.
const String kunciTemplatePribadi = 'template_pribadi';

/// Ubah daftar template menjadi JSON (aman untuk dibaca ulang).
String templatePribadiKeJson(List<TemplatePribadi> daftar) =>
    jsonEncode(daftar.map((t) => t.kePeta()).toList());

/// Baca template dari JSON; data rusak → daftar kosong (jangan melempar galat,
/// supaya aplikasi tetap jalan walau nilai tersimpan pernah disunting manual).
List<TemplatePribadi> jsonKeTemplatePribadi(String? teks) {
  if (teks == null || teks.trim().isEmpty) return const [];
  try {
    final isi = jsonDecode(teks);
    if (isi is! List) return const [];
    final hasil = <TemplatePribadi>[];
    for (final item in isi) {
      if (item is Map<String, dynamic>) {
        final t = TemplatePribadi.dariPeta(item);
        if (t != null) hasil.add(t);
      } else if (item is Map) {
        final t = TemplatePribadi.dariPeta(item.cast<String, dynamic>());
        if (t != null) hasil.add(t);
      }
    }
    return hasil;
  } catch (_) {
    return const [];
  }
}

/// Batas jumlah template pribadi (menjaga daftar tetap ringkas & mudah dipakai).
const int batasTemplatePribadi = 20;

/// Simpan/kelola template pribadi lewat tabel pengaturan.
class PenyimpananTemplatePribadi {
  const PenyimpananTemplatePribadi(this._pengaturan);

  final PengaturanRepository _pengaturan;

  Future<List<TemplatePribadi>> semua() async =>
      jsonKeTemplatePribadi(await _pengaturan.baca(kunciTemplatePribadi));

  /// Tambah template baru; nama sama akan menggantikan yang lama.
  ///
  /// Mengembalikan daftar terbaru. Bila sudah mencapai [batasTemplatePribadi]
  /// dan namanya baru, daftar lama dikembalikan tanpa perubahan.
  Future<List<TemplatePribadi>> tambah(TemplatePribadi baru) async {
    final daftar = [...await semua()];
    final posisi = daftar.indexWhere((t) =>
        t.nama.trim().toLowerCase() == baru.nama.trim().toLowerCase());
    if (posisi >= 0) {
      daftar[posisi] = baru;
    } else {
      if (daftar.length >= batasTemplatePribadi) return daftar;
      daftar.add(baru);
    }
    await _pengaturan.simpan(kunciTemplatePribadi, templatePribadiKeJson(daftar));
    return daftar;
  }

  /// Hapus template menurut nama (tidak apa-apa bila tidak ada).
  Future<List<TemplatePribadi>> hapus(String nama) async {
    final daftar = (await semua())
        .where((t) => t.nama.trim().toLowerCase() != nama.trim().toLowerCase())
        .toList();
    await _pengaturan.simpan(kunciTemplatePribadi, templatePribadiKeJson(daftar));
    return daftar;
  }
}
