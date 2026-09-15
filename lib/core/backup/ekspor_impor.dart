/// FR-24 — Ekspor cadangan JSON & impor restore (termasuk migrasi antar HP).
///
/// Bentuk berkas (satu berkas JSON, mudah dibawa ke HP lain):
/// ```json
/// {
///   "format": "plo-backup",
///   "versiSkema": 4,
///   "versiAplikasi": "1.0.0+1",
///   "dibuatPada": "2026-09-15T08:00:00.000",
///   "tabel": { "<namaTabel>": [ { "<kolom>": nilai } ] }
/// }
/// ```
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

import '../utils/waktu.dart';
import '../../data/database/database.dart';

/// Penanda format berkas cadangan.
const String formatCadangan = 'plo-backup';

/// Versi skema database yang dikenal aplikasi ini.
///
/// Samakan dengan `schemaVersion` di `lib/data/database/database.dart`.
const int versiSkemaAplikasi = 4;

/// Versi aplikasi yang ditulis ke berkas cadangan.
///
/// Samakan dengan `version:` di `pubspec.yaml`.
const String versiAplikasiCadangan = '1.0.0+1';

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
  });

  final String path;
  final String namaBerkas;

  /// Waktu cadangan dibuat (dari sumber waktu aplikasi).
  final DateTime dibuatPada;

  /// Jumlah baris per nama tabel.
  final Map<String, int> jumlahBaris;

  /// Jumlah seluruh baris pada semua tabel.
  final int totalBaris;
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
    this.versiAplikasi = versiAplikasiCadangan,
    this.versiSkema = versiSkemaAplikasi,
  });

  final AppDatabase db;

  /// Cara menentukan folder cadangan (null = folder dokumen aplikasi).
  final PenentuFolderCadangan? penentuFolder;

  /// Sumber waktu (null = satu sumber waktu aplikasi, `waktuSekarang()`).
  final DateTime Function()? jam;

  final String versiAplikasi;
  final int versiSkema;

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
  Future<HasilEkspor> ekspor({DateTime? pada}) async {
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

    final Directory folder = await _folder();
    final String nama = namaBerkasEkspor(waktu);
    final File berkas = File('${folder.path}${Platform.pathSeparator}$nama');
    try {
      await berkas.writeAsString(
        const JsonEncoder.withIndent('  ').convert(isi),
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
    );
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
  Future<PratinjauCadangan> pratinjau(String path) async {
    final _IsiCadangan isi = await _bacaBerkas(path);
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
      lihat = await pratinjau(path);
      isi = await _bacaBerkas(path);
    } on GalatCadangan catch (e) {
      return HasilImpor(
        berhasil: false,
        namaBerkas: _namaBerkas(path),
        pesan: e.pesan,
      );
    }

    // (5) Cadangan pengaman lebih dulu — data sekarang diamankan sebelum
    //     apa pun ditimpa.
    String? pathAman;
    if (buatCadanganPengaman) {
      final DateTime waktu = _sekarang();
      final File berkasAman = await _tulisKeFolder(namaBerkasPengaman(waktu), waktu);
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

  Future<File> _tulisKeFolder(String nama, DateTime waktu) async {
    final Directory folder = await _folder();
    final Map<String, List<Map<String, Object?>>> isiTabel =
        await bacaSemuaTabel();
    final File berkas = File('${folder.path}${Platform.pathSeparator}$nama');
    await berkas.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'format': formatCadangan,
        'versiSkema': versiSkema,
        'versiAplikasi': versiAplikasi,
        'dibuatPada': waktu.toIso8601String(),
        'tabel': isiTabel,
      }),
      flush: true,
    );
    return berkas;
  }

  /// Baca + periksa berkas. Semua berkas tidak sah ditolak di sini.
  Future<_IsiCadangan> _bacaBerkas(String path) async {
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
    final Map<Object?, Object?> akar = mentah;

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
