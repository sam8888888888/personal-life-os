/// SDD v19 Gelombang 1 — Catatan Harian (tulang punggung kronologis).
///
/// Satu halaman per hari. Dua aturan yang dijaga keras di sini:
///
/// 1. `ringkasanMesin` **tidak pernah** menimpa `isi` milik pengguna, dan
///    `isi` **tidak pernah** ditulis proses otomatis. Karena itu keduanya
///    punya fungsi simpan sendiri ([simpanIsi] dan [simpanRingkasanMesin]).
/// 2. Unik "satu halaman per hari" dijamin kolom teks `tanggal_kunci`
///    ('YYYY-MM-DD'), BUKAN kolom tanggal — bentuk penyimpanan DateTime di
///    proyek ini bercampur (angka unix atau teks), sehingga nilai waktu yang
///    berbeda beberapa detik akan lolos dari indeks unik.
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../database/database.dart';

/// Kunci satu hari: 'YYYY-MM-DD' (waktu lokal perangkat).
String kunciTanggalHarian(DateTime hari) {
  final String t = hari.year.toString().padLeft(4, '0');
  final String b = hari.month.toString().padLeft(2, '0');
  final String h = hari.day.toString().padLeft(2, '0');
  return '$t-$b-$h';
}

/// Tengah malam waktu lokal (dipakai kolom `tanggal`).
DateTime tengahMalam(DateTime hari) => DateTime(hari.year, hari.month, hari.day);

/// Repositori catatan harian.
class CatatanHarianRepository {
  CatatanHarianRepository(this._db);

  final AppDatabase _db;
  static final Random _acak = Random.secure();

  static String uidBaru() => List<int>.generate(16, (_) => _acak.nextInt(256))
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  /// Halaman satu hari — dibuatkan barisnya bila belum ada.
  Future<CatatanHarianData> halaman(DateTime hari, {DateTime? waktu}) async {
    final String kunci = kunciTanggalHarian(hari);
    final CatatanHarianData? ada = await (_db.select(_db.catatanHarian)
          ..where((t) => t.tanggalKunci.equals(kunci))
          ..limit(1))
        .getSingleOrNull();
    if (ada != null) return ada;
    final DateTime sekarang = waktu ?? DateTime.now();
    await _db.into(_db.catatanHarian).insert(
          CatatanHarianCompanion.insert(
            uid: Value(uidBaru()),
            tanggal: tengahMalam(hari),
            tanggalKunci: kunci,
            dibuatPada: Value(sekarang),
            diubahPada: Value(sekarang),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return (await (_db.select(_db.catatanHarian)
              ..where((t) => t.tanggalKunci.equals(kunci))
              ..limit(1))
            .getSingle());
  }

  /// Tulis tulisan pengguna. Tidak menyentuh `ringkasan_mesin`.
  Future<void> simpanIsi(DateTime hari, String isi, {DateTime? waktu}) async {
    await halaman(hari, waktu: waktu);
    await (_db.update(_db.catatanHarian)
          ..where((t) => t.tanggalKunci.equals(kunciTanggalHarian(hari))))
        .write(CatatanHarianCompanion(
      isi: Value(isi),
      diubahPada: Value(waktu ?? DateTime.now()),
    ));
  }

  /// Tulis ringkasan buatan mesin. Tidak menyentuh `isi` pengguna.
  Future<void> simpanRingkasanMesin(DateTime hari, String ringkasan,
      {DateTime? waktu}) async {
    await halaman(hari, waktu: waktu);
    await (_db.update(_db.catatanHarian)
          ..where((t) => t.tanggalKunci.equals(kunciTanggalHarian(hari))))
        .write(CatatanHarianCompanion(
      ringkasanMesin: Value(ringkasan),
      diubahPada: Value(waktu ?? DateTime.now()),
    ));
  }

  /// Simpan sorotan otomatis hari itu (JSON array).
  Future<void> simpanSorotan(DateTime hari, List<String> sorotan,
      {DateTime? waktu}) async {
    await halaman(hari, waktu: waktu);
    await (_db.update(_db.catatanHarian)
          ..where((t) => t.tanggalKunci.equals(kunciTanggalHarian(hari))))
        .write(CatatanHarianCompanion(
      sorotan: Value(jsonEncode(sorotan)),
      diubahPada: Value(waktu ?? DateTime.now()),
    ));
  }

  /// Simpan nilai denormalisasi (suasana 0–5, menit tidur, energi 1–5).
  Future<void> simpanDenormalisasi(
    DateTime hari, {
    int? suasana,
    int? tidurMenit,
    int? energi,
    DateTime? waktu,
  }) async {
    await halaman(hari, waktu: waktu);
    await (_db.update(_db.catatanHarian)
          ..where((t) => t.tanggalKunci.equals(kunciTanggalHarian(hari))))
        .write(CatatanHarianCompanion(
      suasana: Value(suasana),
      tidurMenit: Value(tidurMenit),
      energi: Value(energi),
      diubahPada: Value(waktu ?? DateTime.now()),
    ));
  }

  /// Sorotan hari itu; daftar kosong bila belum ada.
  ///
  /// JSON yang rusak TIDAK diam-diam jadi daftar kosong — pemanggil bisa
  /// membedakan lewat [sorotanRusak] dan menyatakannya di layar.
  List<String> sorotanDari(CatatanHarianData baris) {
    final Object? isi = _urai(baris.sorotan);
    if (isi is List) return isi.map((Object? e) => '$e').toList();
    return const <String>[];
  }

  /// true bila kolom sorotan tidak bisa diurai.
  bool sorotanRusak(CatatanHarianData baris) => _urai(baris.sorotan) == null;

  Object? _urai(String teks) {
    try {
      return jsonDecode(teks);
    } catch (_) {
      return null;
    }
  }

  /// Halaman terbaru (semua hari, terbaru dulu).
  Future<List<CatatanHarianData>> terbaru({int batas = 30}) => (_db.select(_db.catatanHarian)
        ..orderBy([(t) => OrderingTerm.desc(t.tanggalKunci)])
        ..limit(batas))
      .get();

  /// Hanya hari yang benar-benar ditulis pengguna (`isi` tidak kosong).
  Future<List<CatatanHarianData>> berisi({int batas = 30}) => (_db.select(_db.catatanHarian)
        ..where((t) => t.isi.isNotValue(''))
        ..orderBy([(t) => OrderingTerm.desc(t.tanggalKunci)])
        ..limit(batas))
      .get();
}
