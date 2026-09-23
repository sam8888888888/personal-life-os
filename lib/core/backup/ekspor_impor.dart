/// FR-24 — Ekspor cadangan JSON & impor restore (termasuk migrasi antar HP).
///
/// Bentuk berkas (satu berkas JSON, mudah dibawa ke HP lain):
/// ```json
/// {
///   "format": "plo-backup",
///   "versiSkema": 19,
///   "versiAplikasi": "1.11.0+14",
///   "dibuatPada": "2026-09-15T08:00:00.000",
///   "tabel": { "<namaTabel>": [ { "<kolom>": nilai } ] }
/// }
/// ```
///
/// Nilai `versiSkema` & `versiAplikasi` TIDAK lagi berupa konstanta sendiri di
/// berkas ini: keduanya dibaca dari sumber tunggalnya (`db.schemaVersion` dan
/// `lib/core/versi.dart`), supaya tidak bisa tertinggal dari kenyataan.
///
/// ATURAN YANG DIPEGANG BERKAS INI
/// 1. Daftar tabel TIDAK ditulis satu per satu: dibaca dari `db.allTables`,
///    jadi tabel skema baru (v3 ke atas) ikut ter-ekspor otomatis tanpa
///    mengubah berkas ini.
/// 2. Nilai `DateTime` ditulis sebagai teks ISO 8601. Saat impor, nilai itu
///    dikembalikan ke bentuk yang dipakai database (angka unix atau teks)
///    lewat `db.typeMapping`, sehingga tidak bergantung setelan penyimpanan.
/// 3. Impor bersifat SATU TRANSAKSI: satu baris bermasalah membatalkan
///    seluruh perubahan — tidak ada impor sebagian.
/// 4. Impor selalu ditutup pembacaan ulang jumlah baris (verifikasi). Hasil
///    tidak pernah disebut berhasil tanpa cek baca-balik.
/// 5. Bahasa mengikuti PRD §III-11: menjelaskan keadaan apa adanya, tanpa kata
///    yang menghakimi pengguna.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../platform/brankas_rahasia.dart';
import '../utils/waktu.dart';
import '../versi.dart' as versi;
import '../../data/database/database.dart';
import 'kunci_cadangan.dart';

/// Penanda format berkas cadangan.
const String formatCadangan = 'plo-backup';

/// Penanda berkas cadangan yang **TERENKRIPSI** (amplop AES-256-GCM).
///
/// Berkas jenis ini hanya memuat metadata ringan (waktu, versi) di bagian luar
/// dan isi data di dalam amplop — sehingga berkas boleh dibagikan lewat
/// WhatsApp/Drive tanpa membocorkan keuangan, kesehatan, dan dokumen keluarga.
const String formatCadanganTerenkripsi = 'plo-backup-terenkripsi';

/// Panjang frasa sandi cadangan paling pendek.
const int panjangSandiCadanganMin = 8;

/// Versi aplikasi yang ditulis ke berkas cadangan.
///
/// Diambil dari SATU sumber kebenaran (`lib/core/versi.dart`), bukan dari
/// konstanta kedua di berkas ini: versi kedua itu dulu tertinggal ('1.0.0+1'
/// padahal pubspec sudah jauh di atasnya) sehingga berkas cadangan menulis
/// versi yang salah. Uji `test/versi_konsisten_test.dart` menjaga pubspec &
/// berkas ini tetap sinkron.
String get versiAplikasiCadangan => '${versi.versiAplikasi}+${versi.nomorBuild}';

/// Awalan nama berkas cadangan (dipakai juga saat mendaftar berkas).
const String awalanBerkasCadangan = 'plo_backup';

/// Penentu folder cadangan (bisa diganti saat pengujian).
typedef PenentuFolderCadangan = Future<Directory> Function();

/// Galat berkas cadangan — pesannya sudah siap tampil untuk pengguna.
class GalatCadangan implements Exception {
  const GalatCadangan(this.pesan);

  /// Kalimat Bahasa Indonesia yang menjelaskan masalah + keadaan data.
  final String pesan;

  @override
  String toString() => pesan;
}

/// Berkas cadangan terenkripsi meminta frasa sandi (belum diberikan).
///
/// Dipisah dari [GalatCadangan] supaya layar tahu bahwa yang dibutuhkan adalah
/// frasa sandi — bukan berkasnya yang rusak.
class GalatCadanganButuhSandi extends GalatCadangan {
  const GalatCadanganButuhSandi()
      : super('Berkas cadangan ini terenkripsi. Masukkan frasa sandi yang '
            'dipakai saat membuatnya. Data di perangkat Anda tidak diubah.');
}

/// Frasa sandi tidak cocok, atau isi amplop rusak.
class GalatCadanganSandiSalah extends GalatCadangan {
  const GalatCadanganSandiSalah()
      : super('Frasa sandi tidak cocok dengan berkas cadangan ini (atau '
            'berkasnya rusak). Data di perangkat Anda tidak diubah — silakan '
            'coba lagi dengan frasa sandi yang benar.');
}

/// Keterangan singkat satu berkas cadangan di folder dokumen aplikasi.
class BerkasCadangan {
  const BerkasCadangan({
    required this.nama,
    required this.path,
    required this.diubahPada,
    required this.ukuranByte,
  });

  final String nama;
  final String path;

  /// Waktu berkas terakhir diubah menurut sistem berkas.
  final DateTime diubahPada;

  /// Ukuran berkas dalam byte (untuk ditampilkan).
  final int ukuranByte;
}

/// Hasil ekspor: lokasi berkas + jumlah baris per tabel.
class HasilEkspor {
  const HasilEkspor({
    required this.path,
    required this.namaBerkas,
    required this.dibuatPada,
    required this.jumlahBaris,
    required this.totalBaris,
    this.terenkripsi = false,
  });

  final String path;
  final String namaBerkas;

  /// Waktu cadangan dibuat (dari sumber waktu aplikasi).
  final DateTime dibuatPada;

  /// Jumlah baris per nama tabel.
  final Map<String, int> jumlahBaris;

  /// Jumlah seluruh baris pada semua tabel.
  final int totalBaris;

  /// Apakah berkas ditulis TERENKRIPSI (amplop AES-256-GCM).
  final bool terenkripsi;
}

/// Hasil pemeriksaan berkas SEBELUM ada data yang diubah.
class PratinjauCadangan {
  const PratinjauCadangan({
    required this.path,
    required this.namaBerkas,
    required this.dibuatPada,
    required this.diubahBerkasPada,
    required this.versiSkema,
    required this.versiAplikasi,
    required this.jumlahBaris,
    required this.totalBaris,
    required this.catatanMigrasi,
    required this.tabelTanpaCadangan,
    required this.tabelTidakDikenal,
  });

  final String path;
  final String namaBerkas;

  /// Waktu berkas dibuat menurut isinya (null bila berkas lama belum memuat).
  final DateTime? dibuatPada;

  /// Waktu berkas diubah menurut sistem berkas (selalu ada).
  final DateTime diubahBerkasPada;

  /// Versi skema yang tertulis di berkas.
  final int versiSkema;

  /// Versi aplikasi yang membuat berkas (null bila tidak dicatat).
  final String? versiAplikasi;

  /// Jumlah baris per tabel menurut berkas.
  final Map<String, int> jumlahBaris;

  final int totalBaris;

  /// Catatan migrasi bila berkas memakai skema lebih lama dari aplikasi.
  final List<String> catatanMigrasi;

  /// Tabel aplikasi yang tidak ada di berkas (isinya menjadi kosong).
  final List<String> tabelTanpaCadangan;

  /// Tabel di berkas yang tidak dikenal aplikasi (diabaikan).
  final List<String> tabelTidakDikenal;

  /// True bila pengguna perlu diberi tahu ada bagian yang tidak ikut pulih.
  bool get adaCatatan =>
      catatanMigrasi.isNotEmpty ||
      tabelTanpaCadangan.isNotEmpty ||
      tabelTidakDikenal.isNotEmpty;
}

/// Hasil impor. `berhasil == false` berarti TIDAK ada data yang diubah.
class HasilImpor {
  const HasilImpor({
    required this.berhasil,
    required this.pesan,
    this.namaBerkas,
    this.jumlahBaris = const <String, int>{},
    this.jumlahBarisTerbaca = const <String, int>{},
    this.tabelTidakCocok = const <String>[],
    this.pathCadanganPengaman,
    this.catatanMigrasi = const <String>[],
    this.kolomDiabaikan = const <String>[],
  });

  final bool berhasil;
  final String pesan;
  final String? namaBerkas;

  /// Jumlah baris yang seharusnya tertulis (menurut berkas).
  final Map<String, int> jumlahBaris;

  /// Jumlah baris hasil pembacaan ulang setelah impor (bukti verifikasi).
  final Map<String, int> jumlahBarisTerbaca;

  /// Tabel yang jumlah barisnya tidak sama antara berkas dan hasil baca.
  final List<String> tabelTidakCocok;

  /// Cadangan pengaman yang dibuat sebelum data diubah.
  final String? pathCadanganPengaman;

  final List<String> catatanMigrasi;

  /// Kolom yang ada di berkas tetapi tidak dikenal aplikasi (diabaikan).
  final List<String> kolomDiabaikan;

  /// True bila angka di berkas dan angka hasil baca-balik sama.
  bool get hitunganCocok => berhasil && tabelTidakCocok.isEmpty;
}

/// Layanan inti ekspor & impor cadangan (FR-24).
class LayananCadangan {
  LayananCadangan({
    required this.db,
    this.penentuFolder,
    this.jam,
    String? versiAplikasi,
    int? versiSkema,
  })  : versiAplikasi = versiAplikasi ?? versiAplikasiCadangan,
        _versiSkemaMinta = versiSkema;

  /// Nilai yang diminta saat pengujian (null = ikuti skema database).
  final int? _versiSkemaMinta;

  final AppDatabase db;

  /// Cara menentukan folder cadangan (null = folder dokumen aplikasi).
  final PenentuFolderCadangan? penentuFolder;

  /// Sumber waktu (null = satu sumber waktu aplikasi, `waktuSekarang()`).
  final DateTime Function()? jam;

  final String versiAplikasi;

  /// Versi skema yang ditulis ke berkas cadangan.
  ///
  /// SELALU diambil dari skema database yang benar-benar dipakai
  /// (`AppDatabase.schemaVersion`) — bukan konstanta terpisah yang bisa
  /// tertinggal. Sebelumnya berkas ini menulis `versiSkema: 4` padahal skema
  /// sebenarnya sudah 18, sehingga logika "cadangan ini dari versi lama" di
  /// jalur impor mengambil keputusan yang salah.
  int get versiSkema => _versiSkemaMinta ?? db.schemaVersion;

  DateTime _sekarang() => (jam ?? waktuSekarang)();

  Future<Directory> _folder() async {
    final Directory d =
        await (penentuFolder ?? getApplicationDocumentsDirectory)();
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static String _dua(int angka) => angka.toString().padLeft(2, '0');

  /// Nama berkas cadangan: `plo_backup_YYYYMMDD_HHMM.json`.
  static String namaBerkasEkspor(DateTime t) =>
      '${awalanBerkasCadangan}_${t.year}${_dua(t.month)}${_dua(t.day)}'
      '_${_dua(t.hour)}${_dua(t.minute)}.json';

  /// Nama cadangan pengaman (otomatis sebelum impor) — memakai detik agar
  /// tidak menimpa berkas yang sedang dipulihkan.
  static String namaBerkasPengaman(DateTime t) =>
      '${awalanBerkasCadangan}_pengaman_${t.year}${_dua(t.month)}${_dua(t.day)}'
      '_${_dua(t.hour)}${_dua(t.minute)}${_dua(t.second)}.json';

  // -------------------------------------------------------------------
  // EKSPOR
  // -------------------------------------------------------------------

  /// Baca seluruh tabel lewat `db.allTables` dan tulis satu berkas JSON.
  ///
  /// Bila [sandi] diisi, isi cadangan ditulis TERENKRIPSI (AES-256-GCM dengan
  /// kunci turunan PBKDF2 600.000 putaran) sehingga berkasnya aman dibagikan.
  /// Bila tidak diisi, dipakai **kunci acak perangkat** dari brankas Keystore
  /// (cadangan otomatis/pekerja latar): berkas tetap tidak pernah berupa teks
  /// polos, tetapi hanya bisa dibuka di perangkat yang sama. Hanya bila
  /// perangkat tidak mendukung brankas, berkas ditulis polos — dan pemanggil
  /// melihatnya lewat [HasilEkspor.terenkripsi] = false.
  Future<HasilEkspor> ekspor({DateTime? pada, String? sandi}) async {
    final DateTime waktu = pada ?? _sekarang();
    late final Map<String, List<Map<String, Object?>>> isiTabel;
    try {
      isiTabel = await bacaSemuaTabel();
    } on GalatCadangan {
      rethrow;
    } catch (e) {
      throw GalatCadangan('Isi database belum bisa dibaca untuk dicadangkan: $e');
    }

    final jumlahBaris = <String, int>{
      for (final MapEntry<String, List<Map<String, Object?>>> e
          in isiTabel.entries)
        e.key: e.value.length,
    };
    final isi = <String, Object?>{
      'format': formatCadangan,
      'versiSkema': versiSkema,
      'versiAplikasi': versiAplikasi,
      'dibuatPada': waktu.toIso8601String(),
      'tabel': isiTabel,
    };

    final String? sandiEfektif = await _sandiEfektif(sandi);
    final bool terenkripsi = sandiEfektif != null;
    Object? isiBerkas = isi;
    if (terenkripsi) {
      final amplop = await enkripsiDenganSandi(
        teks: const JsonEncoder.withIndent('  ').convert(isi),
        sandi: sandiEfektif,
      );
      if (amplop == null) {
        throw const GalatCadangan(
            'Cadangan terenkripsi tidak bisa dibuat di perangkat ini, jadi '
            'tidak ada berkas yang ditulis (data Anda tidak diubah).');
      }
      isiBerkas = <String, Object?>{
        'format': formatCadanganTerenkripsi,
        'versiAmplop': 1,
        'versiSkema': versiSkema,
        'versiAplikasi': versiAplikasi,
        'dibuatPada': waktu.toIso8601String(),
        'amplop': amplop,
      };
    }

    final Directory folder = await _folder();
    final String nama = namaBerkasEkspor(waktu);
    final File berkas = File('${folder.path}${Platform.pathSeparator}$nama');
    try {
      await berkas.writeAsString(
        const JsonEncoder.withIndent('  ').convert(isiBerkas),
        flush: true,
      );
    } catch (e) {
      throw GalatCadangan('Berkas cadangan belum bisa ditulis: $e');
    }

    return HasilEkspor(
      path: berkas.path,
      namaBerkas: nama,
      dibuatPada: waktu,
      jumlahBaris: jumlahBaris,
      totalBaris: jumlahBaris.values.fold<int>(0, (a, b) => a + b),
      terenkripsi: terenkripsi,
    );
  }

  /// Frasa sandi yang benar-benar dipakai: pilihan pengguna, kalau tidak ada
  /// dipakai kunci perangkat (brankas Keystore), kalau itu pun tidak tersedia
  /// → null (berkas polos, disebutkan apa adanya ke pemanggil).
  Future<String?> _sandiEfektif(String? sandi) async {
    if (sandi != null && sandi.isNotEmpty) {
      if (sandi.length < panjangSandiCadanganMin) {
        throw GalatCadangan(
            'Frasa sandi cadangan paling sedikit $panjangSandiCadanganMin '
            'karakter — supaya cadangan tidak mudah dibuka orang lain.');
      }
      return sandi;
    }
    return kunciCadanganPerangkatUntuk(db);
  }

  /// Seluruh baris semua tabel, sudah berbentuk nilai yang bisa di-JSON-kan.
  Future<Map<String, List<Map<String, Object?>>>> bacaSemuaTabel() async {
    final hasil = <String, List<Map<String, Object?>>>{};
    for (final TableInfo tabel in db.allTables) {
      final String nama = tabel.actualTableName;
      final List<QueryRow> baris =
          await db.customSelect('SELECT * FROM "$nama"').get();
      hasil[nama] = <Map<String, Object?>>[
        for (final QueryRow r in baris) _barisKeJson(tabel, r),
      ];
    }
    return hasil;
  }

  /// Jumlah baris per tabel (dibaca langsung dari database).
  Future<Map<String, int>> jumlahBarisSemuaTabel() async {
    final hasil = <String, int>{};
    for (final TableInfo tabel in db.allTables) {
      final String nama = tabel.actualTableName;
      final QueryRow r = await db
          .customSelect('SELECT COUNT(*) AS jml FROM "$nama"')
          .getSingle();
      hasil[nama] = r.read<int>('jml');
    }
    return hasil;
  }

  /// Satu baris SQL menjadi peta yang bisa di-JSON-kan.
  ///
  /// Nilai dibaca memakai tipe yang tercatat di tabel Drift, jadi `DateTime`
  /// dan `bool` tidak ikut bentuk mentahnya (angka unix / 0-1).
  Map<String, Object?> _barisKeJson(TableInfo tabel, QueryRow baris) {
    final Map<String, GeneratedColumn> kolom = tabel.columnsByName;
    final hasil = <String, Object?>{};
    baris.data.forEach((Object? kunciMentah, Object? mentah) {
      final String kunci = kunciMentah.toString();
      final GeneratedColumn? k = kolom[kunci];
      final Object? nilai = k == null
          ? mentah
          : (mentah == null ? null : db.typeMapping.read(k.type, mentah));
      hasil[kunci] = _siapJson(tabel.actualTableName, kunci, nilai);
    });
    return hasil;
  }

  /// Nilai Dart menjadi nilai JSON; DateTime menjadi teks ISO 8601.
  static Object? _siapJson(String tabel, String kolom, Object? nilai) {
    if (nilai == null) return null;
    if (nilai is DateTime) return nilai.toIso8601String();
    if (nilai is String || nilai is bool || nilai is int || nilai is double) {
      return nilai;
    }
    if (nilai is Uint8List) {
      throw GalatCadangan(
          'Kolom "$tabel.$kolom" berisi data biner yang belum didukung '
          'cadangan JSON. Data lain tidak dicadangkan.');
    }
    throw GalatCadangan(
        'Kolom "$tabel.$kolom" berisi nilai yang belum didukung cadangan '
        '(${nilai.runtimeType}). Data lain tidak dicadangkan.');
  }

  // -------------------------------------------------------------------
  // DAFTAR BERKAS
  // -------------------------------------------------------------------

  /// Berkas cadangan di folder dokumen aplikasi, terbaru lebih dahulu.
  Future<List<BerkasCadangan>> daftarBerkas() async {
    final Directory folder = await _folder();
    if (!folder.existsSync()) return const <BerkasCadangan>[];
    final daftar = <BerkasCadangan>[];
    for (final FileSystemEntity e in folder.listSync()) {
      if (e is! File) continue;
      final String nama = e.uri.pathSegments.last;
      if (!nama.startsWith(awalanBerkasCadangan) || !nama.endsWith('.json')) {
        continue;
      }
      final FileStat stat = e.statSync();
      daftar.add(BerkasCadangan(
        nama: nama,
        path: e.path,
        diubahPada: stat.modified,
        ukuranByte: stat.size,
      ));
    }
    daftar.sort((a, b) => b.diubahPada.compareTo(a.diubahPada));
    return daftar;
  }

  // -------------------------------------------------------------------
  // IMPOR
  // -------------------------------------------------------------------

  /// Periksa berkas tanpa mengubah apa pun (pratinjau untuk pengguna).
  ///
  /// Melempar [GalatCadangan] bila berkas tidak sah; pesannya sudah jelas dan
  /// menegaskan bahwa data di perangkat belum diubah.
  ///
  /// [sandi] = frasa sandi untuk berkas cadangan terenkripsi (kalau berkasnya
  /// dibuat di perangkat ini, kunci perangkat dipakai otomatis).
  Future<PratinjauCadangan> pratinjau(String path, {String? sandi}) async {
    final _IsiCadangan isi = await _bacaBerkas(path, sandi: sandi);
    final Map<String, List<Map<String, Object?>>> tabelFile = isi.tabel;

    final Set<String> namaDiAplikasi = <String>{
      for (final TableInfo t in db.allTables) t.actualTableName,
    };

    final catatan = <String>[];
    if (isi.versiSkema < versiSkema) {
      catatan.add(
          'Berkas ini dibuat dengan skema versi ${isi.versiSkema}; data ditulis '
          'ke skema versi $versiSkema. Kolom baru yang tidak ada di berkas '
          'memakai nilai bawaan.');
    }

    final tabelTanpaCadangan = <String>[
      for (final String n in namaDiAplikasi)
        if (!tabelFile.containsKey(n)) n,
    ];
    final tabelTidakDikenal = <String>[
      for (final String n in tabelFile.keys)
        if (!namaDiAplikasi.contains(n)) n,
    ];

    final jumlahBaris = <String, int>{
      for (final MapEntry<String, List<Map<String, Object?>>> e
          in tabelFile.entries)
        e.key: e.value.length,
    };

    return PratinjauCadangan(
      path: path,
      namaBerkas: _namaBerkas(path),
      dibuatPada: isi.dibuatPada,
      diubahBerkasPada: _diubahPada(path),
      versiSkema: isi.versiSkema,
      versiAplikasi: isi.versiAplikasi,
      jumlahBaris: jumlahBaris,
      totalBaris: jumlahBaris.values.fold<int>(0, (a, b) => a + b),
      catatanMigrasi: catatan,
      tabelTanpaCadangan: tabelTanpaCadangan,
      tabelTidakDikenal: tabelTidakDikenal,
    );
  }

  /// Pulihkan data dari berkas cadangan.
  ///
  /// Urutan: periksa berkas → [sudahDikonfirmasi] → cadangan pengaman →
  /// terapkan dalam SATU transaksi → baca ulang jumlah baris.
  /// Bila ada satu baris bermasalah, seluruh transaksi dibatalkan dan data
  /// lama tetap utuh.
  Future<HasilImpor> impor(
    String path, {
    bool sudahDikonfirmasi = false,
    bool buatCadanganPengaman = true,
    String? sandi,
  }) async {
    if (!sudahDikonfirmasi) {
      return HasilImpor(
        berhasil: false,
        namaBerkas: _namaBerkas(path),
        pesan: 'Pemulihan belum dikonfirmasi, jadi belum ada data yang diubah.',
      );
    }

    late final _IsiCadangan isi;
    late final PratinjauCadangan lihat;
    try {
      lihat = await pratinjau(path, sandi: sandi);
      isi = await _bacaBerkas(path, sandi: sandi);
    } on GalatCadangan catch (e) {
      return HasilImpor(
        berhasil: false,
        namaBerkas: _namaBerkas(path),
        pesan: e.pesan,
      );
    }

    // (5) Cadangan pengaman lebih dulu — data sekarang diamankan sebelum
    //     apa pun ditimpa. Ditulis TERENKRIPSI (frasa sandi pengguna atau kunci
    //     perangkat) supaya berkas penyelamat pun tidak berupa teks polos.
    String? pathAman;
    if (buatCadanganPengaman) {
      final DateTime waktu = _sekarang();
      final File berkasAman =
          await _tulisKeFolder(namaBerkasPengaman(waktu), waktu, sandi: sandi);
      pathAman = berkasAman.path;
    }

    // (6) Terapkan dalam satu transaksi.
    final kolomDiabaikan = <String>[];
    try {
      await db.transaction(() async {
        // Urutan hapus dibalik (anak dulu) supaya tetap aman bila kelak
        // foreign key ditegakkan; PRAGMA di bawah menunda pemeriksaan FK
        // sampai COMMIT sehingga urutan isi tidak jadi masalah.
        await db.customStatement('PRAGMA defer_foreign_keys = ON');
        final List<TableInfo> tabel = db.allTables.toList(growable: false);
        for (final TableInfo t in tabel.reversed) {
          await db.customStatement('DELETE FROM "${t.actualTableName}"');
        }
        for (final TableInfo t in tabel) {
          final List<Map<String, Object?>> baris =
              isi.tabel[t.actualTableName] ?? const <Map<String, Object?>>[];
          await _tulisBaris(t, baris, kolomDiabaikan);
        }
      });
    } catch (e) {
      return HasilImpor(
        berhasil: false,
        namaBerkas: lihat.namaBerkas,
        pathCadanganPengaman: pathAman,
        catatanMigrasi: lihat.catatanMigrasi,
        jumlahBaris: lihat.jumlahBaris,
        pesan: 'Pemulihan dihentikan dan seluruh perubahan dibatalkan, jadi '
            'data lama Anda tetap utuh. Penyebabnya: $e',
      );
    }

    // (7) Verifikasi nyata: baca ulang jumlah baris dan bandingkan.
    final terbaca = await jumlahBarisSemuaTabel();
    final tidakCocok = <String>[];
    for (final String nama in terbaca.keys) {
      final int diharap = lihat.jumlahBaris[nama] ?? 0;
      if (terbaca[nama] != diharap) {
        tidakCocok.add('$nama (berkas $diharap, terbaca ${terbaca[nama]})');
      }
    }

    if (tidakCocok.isNotEmpty) {
      return HasilImpor(
        berhasil: true,
        namaBerkas: lihat.namaBerkas,
        pathCadanganPengaman: pathAman,
        catatanMigrasi: lihat.catatanMigrasi,
        kolomDiabaikan: kolomDiabaikan,
        jumlahBaris: lihat.jumlahBaris,
        jumlahBarisTerbaca: terbaca,
        tabelTidakCocok: tidakCocok,
        pesan: 'Data ditulis, tetapi pemeriksaan ulang menemukan jumlah baris '
            'yang berbeda pada: ${tidakCocok.join('; ')}. Cadangan pengaman '
            'tetap tersimpan, silakan hubungi pendamping sebelum memakai '
            'data ini.',
      );
    }

    return HasilImpor(
      berhasil: true,
      namaBerkas: lihat.namaBerkas,
      pathCadanganPengaman: pathAman,
      catatanMigrasi: lihat.catatanMigrasi,
      kolomDiabaikan: kolomDiabaikan,
      jumlahBaris: lihat.jumlahBaris,
      jumlahBarisTerbaca: terbaca,
      pesan: 'Data dipulihkan dari ${lihat.namaBerkas} '
          '(${lihat.totalBaris} baris pada ${lihat.jumlahBaris.length} tabel) '
          'dan jumlah barisnya sudah diperiksa ulang.',
    );
  }

  Future<void> _tulisBaris(
    TableInfo tabel,
    List<Map<String, Object?>> baris,
    List<String> kolomDiabaikan,
  ) async {
    if (baris.isEmpty) return;
    final Map<String, GeneratedColumn> kolomTabel = tabel.columnsByName;
    final String namaTabel = tabel.actualTableName;
    final Map<String, String> sqlPerKolom = <String, String>{};
    var nomor = 0;

    for (final Map<String, Object?> b in baris) {
      nomor++;
      for (final String k in b.keys) {
        if (!kolomTabel.containsKey(k)) {
          final String jejak = '$namaTabel.$k';
          if (!kolomDiabaikan.contains(jejak)) kolomDiabaikan.add(jejak);
        }
      }
      final List<String> dipakai = <String>[
        for (final String k in kolomTabel.keys)
          if (b.containsKey(k)) k,
      ];
      if (dipakai.isEmpty) {
        throw GalatCadangan(
            'Baris ke-$nomor pada tabel "$namaTabel" tidak memuat satu pun '
            'kolom yang dikenal aplikasi ini.');
      }
      final String kunci = dipakai.join('|');
      final String sql = sqlPerKolom[kunci] ??= _sqlInsert(namaTabel, dipakai);
      try {
        await db.customInsert(sql, variables: <Variable>[
          for (final String k in dipakai)
            _variabel(_nilaiDariJson(namaTabel, kolomTabel[k]!, b[k])),
        ]);
      } catch (e) {
        throw GalatCadangan(
            'Baris ke-$nomor pada tabel "$namaTabel" tidak bisa ditulis: $e');
      }
    }
  }

  static String _sqlInsert(String tabel, List<String> kolom) {
    final String daftarKolom = kolom.map((k) => '"$k"').join(', ');
    final String tanya = List<String>.filled(kolom.length, '?').join(', ');
    return 'INSERT INTO "$tabel" ($daftarKolom) VALUES ($tanya)';
  }

  /// Nilai JSON menjadi nilai Dart sesuai tipe kolom Drift.
  static Object? _nilaiDariJson(
    String tabel,
    GeneratedColumn kolom,
    Object? nilai,
  ) {
    if (nilai == null) return null;
    if (identical(kolom.type, DriftSqlType.dateTime)) {
      if (nilai is String) {
        final DateTime? t = DateTime.tryParse(nilai);
        if (t == null) {
          throw GalatCadangan('Nilai tanggal "$nilai" pada kolom '
              '"$tabel.${kolom.$name}" bukan teks ISO 8601 yang sah.');
        }
        return t;
      }
      if (nilai is int) {
        // Toleransi berkas lama yang menulis tanggal sebagai angka unix.
        return DateTime.fromMillisecondsSinceEpoch(nilai * 1000);
      }
      throw GalatCadangan('Kolom "$tabel.${kolom.$name}" berisi tanggal dalam '
          'bentuk ${nilai.runtimeType}, bukan teks ISO 8601.');
    }
    if (identical(kolom.type, DriftSqlType.bool)) {
      if (nilai is bool) return nilai;
      if (nilai is int) return nilai != 0;
      throw GalatCadangan('Kolom "$tabel.${kolom.$name}" berisi ${nilai.runtimeType} '
          'untuk nilai benar/salah.');
    }
    return nilai;
  }

  /// Bungkus nilai Dart menjadi `Variable` drift (konversi mengikuti
  /// `db.typeMapping`, jadi tanggal & benar/salah ditulis dengan benar).
  static Variable _variabel(Object? nilai) {
    switch (nilai) {
      case null:
        return const Variable<Object>(null);
      case final String v:
        return Variable<String>(v);
      case final bool v:
        return Variable<bool>(v);
      case final int v:
        return Variable<int>(v);
      case final double v:
        return Variable<double>(v);
      case final DateTime v:
        return Variable<DateTime>(v);
      default:
        throw GalatCadangan('Nilai ${nilai.runtimeType} belum didukung impor.');
    }
  }

  Future<File> _tulisKeFolder(String nama, DateTime waktu,
      {String? sandi}) async {
    final Directory folder = await _folder();
    final Map<String, List<Map<String, Object?>>> isiTabel =
        await bacaSemuaTabel();
    final isi = <String, Object?>{
      'format': formatCadangan,
      'versiSkema': versiSkema,
      'versiAplikasi': versiAplikasi,
      'dibuatPada': waktu.toIso8601String(),
      'tabel': isiTabel,
    };
    final String? sandiEfektif = await _sandiEfektif(sandi);
    Object? isiBerkas = isi;
    if (sandiEfektif != null) {
      final amplop = await enkripsiDenganSandi(
        teks: const JsonEncoder.withIndent('  ').convert(isi),
        sandi: sandiEfektif,
      );
      if (amplop != null) {
        isiBerkas = <String, Object?>{
          'format': formatCadanganTerenkripsi,
          'versiAmplop': 1,
          'versiSkema': versiSkema,
          'versiAplikasi': versiAplikasi,
          'dibuatPada': waktu.toIso8601String(),
          'amplop': amplop,
        };
      }
    }
    final File berkas = File('${folder.path}${Platform.pathSeparator}$nama');
    await berkas.writeAsString(
      const JsonEncoder.withIndent('  ').convert(isiBerkas),
      flush: true,
    );
    return berkas;
  }

  /// Baca + periksa berkas. Semua berkas tidak sah ditolak di sini.
  ///
  /// [sandi] = frasa sandi untuk berkas TERENKRIPSI. Bila tidak diberikan,
  /// dicoba kunci perangkat (brankas Keystore) — berkas yang dibuat di
  /// perangkat ini bisa dibuka tanpa mengetik apa pun. Bila keduanya gagal,
  /// yang dilempar [GalatCadanganButuhSandi]/[GalatCadanganSandiSalah] —
  /// bukan dianggap berkas rusak.
  Future<_IsiCadangan> _bacaBerkas(String path, {String? sandi}) async {
    final File berkas = File(path);
    if (!berkas.existsSync()) {
      throw const GalatCadangan(
          'Berkas cadangan tidak ditemukan di folder dokumen aplikasi. '
          'Data di perangkat Anda tidak diubah.');
    }
    String teks;
    try {
      teks = await berkas.readAsString();
    } catch (e) {
      throw GalatCadangan(
          'Berkas cadangan tidak bisa dibaca ($e). Data di perangkat Anda '
          'tidak diubah.');
    }
    if (teks.trim().isEmpty) {
      throw const GalatCadangan(
          'Berkas cadangan kosong. Tidak ada data yang bisa dipulihkan. '
          'Data di perangkat Anda tidak diubah.');
    }

    Object? mentah;
    try {
      mentah = jsonDecode(teks);
    } on FormatException catch (e) {
      throw GalatCadangan(
          'Isi berkas bukan JSON yang sah (${e.message}). Data di perangkat '
          'Anda tidak diubah.');
    }
    if (mentah is! Map) {
      throw const GalatCadangan(
          'Isi berkas bukan objek JSON, jadi bukan berkas cadangan. '
          'Data di perangkat Anda tidak diubah.');
    }
    final Map<Object?, Object?> akarAwal = mentah;

    Map<Object?, Object?> akar = akarAwal;

    // Berkas TERENKRIPSI: buka dulu amplopnya, baru diperiksa seperti biasa.
    if (akarAwal['format'] == formatCadanganTerenkripsi) {
      final Object? amplop = akarAwal['amplop'];
      if (amplop is! String || amplop.isEmpty) {
        throw const GalatCadangan(
            'Berkas cadangan terenkripsi tidak lengkap (bagian amplop tidak '
            'ada). Data di perangkat Anda tidak diubah.');
      }
      final bool pakaiSandiPengguna = sandi != null && sandi.isNotEmpty;
      final String? frasa =
          pakaiSandiPengguna ? sandi : await kunciCadanganPerangkatUntuk(db);
      if (frasa == null) throw const GalatCadanganButuhSandi();
      final String? teksPolos =
          await dekripsiDenganSandi(amplop: amplop, sandi: frasa);
      if (teksPolos == null) {
        throw pakaiSandiPengguna
            ? const GalatCadanganSandiSalah()
            : const GalatCadanganButuhSandi();
      }
      Object? dalam;
      try {
        dalam = jsonDecode(teksPolos);
      } on FormatException {
        throw const GalatCadangan(
            'Isi cadangan terenkripsi tidak bisa dibaca. Data di perangkat '
            'Anda tidak diubah.');
      }
      if (dalam is! Map) {
        throw const GalatCadangan(
            'Isi cadangan terenkripsi bukan objek JSON. Data di perangkat '
            'Anda tidak diubah.');
      }
      akar = Map<Object?, Object?>.from(dalam);
    }

    if (akar['format'] != formatCadangan) {
      throw const GalatCadangan(
          'Berkas ini bukan cadangan Personal Life OS (penanda "format" tidak '
          'sesuai). Data di perangkat Anda tidak diubah.');
    }

    final Object? versiMentah = akar['versiSkema'];
    if (versiMentah is! int) {
      throw const GalatCadangan(
          'Berkas cadangan tidak memuat nomor versi skema yang sah. '
          'Data di perangkat Anda tidak diubah.');
    }
    if (versiMentah > versiSkema) {
      throw GalatCadangan(
          'Berkas cadangan memakai skema versi $versiMentah, sedangkan '
          'aplikasi ini mendukung sampai versi $versiSkema. Perbarui aplikasi '
          'Anda lalu coba lagi. Data di perangkat Anda tidak diubah.');
    }

    final Object? tabelMentah = akar['tabel'];
    if (tabelMentah is! Map) {
      throw const GalatCadangan(
          'Berkas cadangan tidak memuat bagian "tabel". Data di perangkat '
          'Anda tidak diubah.');
    }

    final hasil = <String, List<Map<String, Object?>>>{};
    tabelMentah.forEach((Object? namaTabel, Object? isiTabel) {
      final String nama = namaTabel.toString();
      if (isiTabel is! List) {
        throw GalatCadangan('Isi tabel "$nama" di berkas bukan daftar baris. '
            'Data di perangkat Anda tidak diubah.');
      }
      final baris = <Map<String, Object?>>[];
      for (var i = 0; i < isiTabel.length; i++) {
        final Object? b = isiTabel[i];
        if (b is! Map) {
          throw GalatCadangan('Baris ke-${i + 1} pada tabel "$nama" di berkas '
              'bukan objek. Data di perangkat Anda tidak diubah.');
        }
        baris.add(<String, Object?>{
          for (final MapEntry<Object?, Object?> e in b.entries)
            e.key.toString(): e.value,
        });
      }
      hasil[nama] = baris;
    });

    DateTime? dibuatPada;
    final Object? dibuat = akar['dibuatPada'];
    if (dibuat is String) dibuatPada = DateTime.tryParse(dibuat);
    final Object? versiAplikasi = akar['versiAplikasi'];

    return _IsiCadangan(
      versiSkema: versiMentah,
      versiAplikasi: versiAplikasi is String ? versiAplikasi : null,
      dibuatPada: dibuatPada,
      tabel: hasil,
    );
  }

  static String _namaBerkas(String path) =>
      File(path).uri.pathSegments.lastWhere((String s) => s.isNotEmpty);

  static DateTime _diubahPada(String path) =>
      File(path).statSync().modified;
}

/// Isi berkas cadangan yang sudah diperiksa.
class _IsiCadangan {
  const _IsiCadangan({
    required this.versiSkema,
    required this.versiAplikasi,
    required this.dibuatPada,
    required this.tabel,
  });

  final int versiSkema;
  final String? versiAplikasi;
  final DateTime? dibuatPada;
  final Map<String, List<Map<String, Object?>>> tabel;
}
