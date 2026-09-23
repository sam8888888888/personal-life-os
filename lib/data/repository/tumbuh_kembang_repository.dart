/// SDD v19 Gelombang 2 — Tumbuh kembang anak.
///
/// Prinsip yang dipegang:
/// * Aplikasi **menyajikan** pengukuran apa adanya (berat, tinggi, lingkar
///   kepala, umur). Tidak pernah menyatakan anak "normal", "stunting", atau
///   label klinis apa pun.
/// * `persentilBmi` **sengaja dibiarkan kosong** pada tahap ini: menghitungnya
///   butuh tabel rujukan (kurva) yang dibundel di aplikasi. Selama tabel
///   rujukan belum dipasang, aplikasi **tidak menebak** — dan layar menyatakan
///   alasannya. Ini keadaan yang dilaporkan apa adanya, bukan disamarkan.
///
/// Satu pengukuran per anak per hari: menyimpan ulang di tanggal yang sama
/// akan MENIMPA baris hari itu (bukan menumpuk baris kembar).
library;

import 'dart:math';

import 'package:drift/drift.dart';

import '../database/database.dart';

class GalatTumbuhKembang implements Exception {
  GalatTumbuhKembang(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}

class TumbuhKembangRepository {
  TumbuhKembangRepository(this._db);

  final AppDatabase _db;
  static final Random _acak = Random.secure();

  static String uidBaru() => List<int>.generate(16, (_) => _acak.nextInt(256))
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  /// Umur dalam bulan penuh pada tanggal pengukuran (dihitung dari tanggal
  /// lahir — bukan ditebak, bukan dibulatkan ke atas).
  static int umurBulanPada(DateTime lahir, DateTime tanggal) {
    int bulan = (tanggal.year - lahir.year) * 12 + (tanggal.month - lahir.month);
    if (tanggal.day < lahir.day) bulan -= 1;
    return bulan < 0 ? 0 : bulan;
  }

  /// Simpan satu pengukuran. Bila hari itu sudah ada, barisnya DIPERBARUI
  /// (satu anak = satu baris per tanggal, sesuai indeks unik `idx_tk_hari`).
  Future<String> simpan({
    required int anggotaId,
    required DateTime tanggal,
    required int umurBulan,
    double? beratKg,
    double? tinggiCm,
    double? lingkarKepalaCm,
    String? catatan,
  }) async {
    if (beratKg == null && tinggiCm == null && lingkarKepalaCm == null) {
      throw GalatTumbuhKembang(
          'Isi minimal satu ukuran: berat, tinggi, atau lingkar kepala.');
    }
    if (beratKg != null && (beratKg <= 0 || beratKg > 150)) {
      throw GalatTumbuhKembang('Berat badan sepertinya tidak masuk akal.');
    }
    if (tinggiCm != null && (tinggiCm <= 0 || tinggiCm > 250)) {
      throw GalatTumbuhKembang('Tinggi badan sepertinya tidak masuk akal.');
    }
    final DateTime hari = DateTime(tanggal.year, tanggal.month, tanggal.day);
    final TumbuhKembangData? ada = await (_db.select(_db.tumbuhKembang)
          ..where((t) =>
              t.anggotaId.equals(anggotaId) & t.tanggal.equals(hari))
          ..limit(1))
        .getSingleOrNull();
    if (ada != null) {
      await (_db.update(_db.tumbuhKembang)..where((t) => t.id.equals(ada.id)))
          .write(TumbuhKembangCompanion(
        umurBulan: Value(umurBulan),
        beratKg: Value(beratKg),
        tinggiCm: Value(tinggiCm),
        lingkarKepalaCm: Value(lingkarKepalaCm),
        catatan: Value(catatan),
      ));
      return ada.uid ?? '';
    }
    final String uid = uidBaru();
    await _db.into(_db.tumbuhKembang).insert(
          TumbuhKembangCompanion.insert(
            uid: Value(uid),
            anggotaId: anggotaId,
            tanggal: hari,
            umurBulan: umurBulan,
            beratKg: Value(beratKg),
            tinggiCm: Value(tinggiCm),
            lingkarKepalaCm: Value(lingkarKepalaCm),
            catatan: Value(catatan),
          ),
        );
    return uid;
  }

  /// Seluruh deret pengukuran satu anak, dari yang paling lama (siap digambar).
  Future<List<TumbuhKembangData>> deret(int anggotaId, {int batas = 400}) =>
      (_db.select(_db.tumbuhKembang)
            ..where((t) => t.anggotaId.equals(anggotaId))
            ..orderBy(<OrderingTerm Function($TumbuhKembangTable)>[
              ($TumbuhKembangTable t) => OrderingTerm.asc(t.tanggal),
            ])
            ..limit(batas))
          .get();

  /// Pengukuran terakhir (untuk ringkasan di layar).
  Future<TumbuhKembangData?> terakhir(int anggotaId) => (_db.select(_db.tumbuhKembang)
        ..where((t) => t.anggotaId.equals(anggotaId))
        ..orderBy(<OrderingTerm Function($TumbuhKembangTable)>[
          ($TumbuhKembangTable t) => OrderingTerm.desc(t.tanggal),
        ])
        ..limit(1))
      .getSingleOrNull();

  Future<void> hapus(int id) async {
    await (_db.delete(_db.tumbuhKembang)..where((t) => t.id.equals(id))).go();
  }

  /// Indeks massa tubuh sederhana (berat ÷ tinggi²) — **aritmetika**, bukan
  /// penilaian kesehatan. Mengembalikan null bila datanya belum lengkap.
  static double? imt({double? beratKg, double? tinggiCm}) {
    if (beratKg == null || tinggiCm == null || tinggiCm <= 0) return null;
    final double meter = tinggiCm / 100;
    final double nilai = beratKg / (meter * meter);
    return double.parse(nilai.toStringAsFixed(1));
  }

  /// Kalimat jujur kenapa persentil belum bisa ditampilkan.
  ///
  /// Dipakai layar supaya pengguna tidak melihat kolom kosong tanpa penjelasan.
  static String alasanPersentilKosong({
    double? beratKg,
    double? tinggiCm,
  }) {
    if (beratKg == null && tinggiCm == null) {
      return 'Persentil belum bisa dihitung — berat dan tinggi belum diisi.';
    }
    if (tinggiCm == null) {
      return 'Persentil belum bisa dihitung — tinggi badan belum diisi.';
    }
    if (beratKg == null) {
      return 'Persentil belum bisa dihitung — berat badan belum diisi.';
    }
    return 'Persentil belum ditampilkan — tabel rujukan kurva pertumbuhan belum '
        'dipasang di aplikasi ini, jadi angkanya tidak ditebak.';
  }
}
