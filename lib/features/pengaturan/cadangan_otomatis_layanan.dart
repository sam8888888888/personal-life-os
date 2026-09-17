/// FR-137 — layanan cadangan otomatis: menjalankan, memutar berkas lama,
/// memeriksa keutuhan, dan menyimpan hasilnya sebagai setelan.
///
/// Penghapusan HANYA menyentuh berkas cadangan otomatis yang tercatat di
/// daftar ([kunciCadanganOtomatisDaftar]) — cadangan buatan pengguna tidak
/// pernah dihapus.
library;

import 'dart:convert';
import 'dart:io';

import '../../core/backup/cadangan_otomatis.dart';
import '../../core/backup/ekspor_impor.dart';
import '../../core/utils/waktu.dart';
import '../ibadah/pengaturan_ibadah.dart';

/// Hasil satu kali penjalanan cadangan otomatis.
class HasilCadanganOtomatis {
  const HasilCadanganOtomatis({
    required this.dijalankan,
    required this.pesan,
    this.namaBerkas,
    this.totalBaris = 0,
    this.diputarKeluar = const <String>[],
    this.keutuhan,
  });

  /// Apakah cadangan benar-benar dibuat pada pemanggilan ini.
  final bool dijalankan;

  /// Keterangan untuk pengguna (jujur, tanpa menghakimi).
  final String pesan;

  final String? namaBerkas;
  final int totalBaris;

  /// Nama berkas lama yang dihapus karena rotasi.
  final List<String> diputarKeluar;

  final HasilPeriksaKeutuhan? keutuhan;
}

/// Layanan cadangan otomatis. Semua ketergantungan disuntikkan supaya bisa
/// diuji tanpa folder aplikasi yang sebenarnya.
class LayananCadanganOtomatis {
  LayananCadanganOtomatis({
    required this.setelan,
    required this.cadangan,
    DateTime Function()? jam,
  }) : _jam = jam ?? waktuSekarang;

  final PenyimpananSetelan setelan;
  final LayananCadangan cadangan;
  final DateTime Function() _jam;

  // --- setelan -----------------------------------------------------------

  Future<bool> aktif() =>
      setelan.bacaSaklar(kunciCadanganOtomatisAktif,
          bawaan: cadanganOtomatisAktifBawaan);

  Future<void> setAktif(bool nilai) =>
      setelan.simpan(kunciCadanganOtomatisAktif, nilai ? 'true' : 'false');

  Future<int> jedaHari() async => batasiJedaCadangan(await setelan
      .bacaAngka(kunciCadanganOtomatisJedaHari, jedaCadanganOtomatisBawaan));

  Future<void> setJedaHari(int hari) =>
      setelan.simpan(kunciCadanganOtomatisJedaHari, '${batasiJedaCadangan(hari)}');

  Future<DateTime?> terakhir() async {
    final String teks = await setelan.bacaTeks(kunciCadanganOtomatisTerakhir, '');
    return teks.trim().isEmpty ? null : DateTime.tryParse(teks.trim());
  }

  /// Nama berkas cadangan otomatis yang tercatat (urutan pembuatan).
  Future<List<String>> daftar() async {
    final String teks = await setelan.bacaTeks(kunciCadanganOtomatisDaftar, '');
    if (teks.trim().isEmpty) return const <String>[];
    try {
      final Object? isi = jsonDecode(teks);
      if (isi is List) {
        return <String>[
          for (final Object? n in isi)
            if (n is String && n.trim().isNotEmpty) n
        ];
      }
    } catch (_) {
      // Isi rusak: mulai dari daftar kosong, tidak ada berkas yang dihapus.
    }
    return const <String>[];
  }

  /// Hasil pemeriksaan keutuhan yang terakhir disimpan.
  Future<HasilPeriksaKeutuhan?> periksaTersimpan() async {
    final String teks = await setelan.bacaTeks(kunciCadanganOtomatisPeriksa, '');
    if (teks.trim().isEmpty) return null;
    try {
      final Object? isi = jsonDecode(teks);
      if (isi is Map) {
        return HasilPeriksaKeutuhan.dariJson(isi.cast<String, Object?>());
      }
    } catch (_) {
      // Isi rusak: dianggap belum pernah diperiksa.
    }
    return null;
  }

  // --- tindakan ----------------------------------------------------------

  /// Jalankan cadangan otomatis bila sudah waktunya (atau [paksa]).
  Future<HasilCadanganOtomatis> jalankan({bool paksa = false}) async {
    try {
      final bool nyala = await aktif();
      final int jeda = await jedaHari();
      final DateTime? akhir = await terakhir();
      final DateTime sekarang = _jam();

      if (!paksa &&
          !perluCadanganOtomatis(
            aktif: nyala,
            terakhir: akhir,
            sekarang: sekarang,
            jedaHari: jeda,
          )) {
        return HasilCadanganOtomatis(
          dijalankan: false,
          pesan: nyala
              ? 'Cadangan otomatis belum waktunya dijalankan.'
              : 'Cadangan otomatis sedang dimatikan.',
        );
      }

      final HasilEkspor hasil = await cadangan.ekspor(pada: sekarang);
      final List<String> daftarBaru = <String>[...await daftar(), hasil.namaBerkas];
      final List<String> kedaluwarsa =
          namaKedaluwarsa(daftarBaru, simpan: simpanCadanganOtomatisBawaan);
      final List<String> diputar = <String>[];
      final Directory folder = File(hasil.path).parent;
      for (final String nama in kedaluwarsa) {
        try {
          final File f = File('${folder.path}${Platform.pathSeparator}$nama');
          if (f.existsSync()) {
            f.deleteSync();
            diputar.add(nama);
          }
        } catch (_) {
          // Gagal menghapus satu berkas: berkas tetap tercatat, tidak fatal.
          continue;
        }
      }
      final List<String> sisa = <String>[
        for (final String n in daftarBaru)
          if (!diputar.contains(n)) n
      ];

      await setelan.simpan(
          kunciCadanganOtomatisTerakhir, sekarang.toIso8601String());
      await setelan.simpan(kunciCadanganOtomatisDaftar, jsonEncode(sisa));

      final HasilPeriksaKeutuhan periksa = await periksaKeutuhan(
          namaBerkas: hasil.namaBerkas, path: hasil.path);

      return HasilCadanganOtomatis(
        dijalankan: true,
        pesan: 'Cadangan otomatis dibuat: ${hasil.namaBerkas} '
            '(${hasil.totalBaris} baris).',
        namaBerkas: hasil.namaBerkas,
        totalBaris: hasil.totalBaris,
        diputarKeluar: diputar,
        keutuhan: periksa,
      );
    } on GalatCadangan catch (e) {
      return HasilCadanganOtomatis(dijalankan: false, pesan: 'Gagal: ${e.pesan}');
    } catch (e) {
      return HasilCadanganOtomatis(
          dijalankan: false, pesan: 'Gagal menjalankan cadangan otomatis: $e');
    }
  }

  /// Periksa keutuhan satu berkas cadangan.
  ///
  /// Bila [path] tidak diberikan, berkas terbaru yang tercatat sebagai
  /// cadangan otomatis dipakai; bila daftar kosong, berkas cadangan terbaru di
  /// folder cadangan. Hasilnya disimpan supaya bisa dilihat tanpa mengulang.
  Future<HasilPeriksaKeutuhan> periksaKeutuhan({
    String? namaBerkas,
    String? path,
  }) async {
    try {
      String? jalur = path;
      String? nama = namaBerkas;
      if (jalur == null) {
        final List<BerkasCadangan> berkas = await cadangan.daftarBerkas();
        if (berkas.isEmpty) {
          final HasilPeriksaKeutuhan kosong = HasilPeriksaKeutuhan(
            waktu: _jam(),
            namaBerkas: null,
            utuh: false,
            pesan: 'Belum ada berkas cadangan untuk diperiksa.',
          );
          await _simpanPeriksa(kosong);
          return kosong;
        }
        final List<String> catat = await daftar();
        BerkasCadangan? pilih;
        for (final BerkasCadangan b in berkas) {
          if (catat.isEmpty || catat.contains(b.nama)) {
            pilih = b;
            break;
          }
        }
        pilih ??= berkas.first;
        jalur = pilih.path;
        nama = pilih.nama;
      }
      final PratinjauCadangan p = await cadangan.pratinjau(jalur);
      final int total = p.totalBaris;
      final HasilPeriksaKeutuhan hasil = HasilPeriksaKeutuhan(
        waktu: _jam(),
        namaBerkas: nama ?? p.namaBerkas,
        utuh: true,
        pesan: 'Berkas cadangan bisa dibaca. $total baris, '
            'skema v${p.versiSkema}.',
        totalBaris: total,
        versiSkema: p.versiSkema,
      );
      await _simpanPeriksa(hasil);
      return hasil;
    } catch (e) {
      final HasilPeriksaKeutuhan gagal = HasilPeriksaKeutuhan(
        waktu: _jam(),
        namaBerkas: namaBerkas,
        utuh: false,
        pesan: 'Berkas cadangan tidak bisa dibaca: $e',
      );
      await _simpanPeriksa(gagal);
      return gagal;
    }
  }

  Future<void> _simpanPeriksa(HasilPeriksaKeutuhan hasil) => setelan.simpan(
      kunciCadanganOtomatisPeriksa, jsonEncode(hasil.keJson()));
}
