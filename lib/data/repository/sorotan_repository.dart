/// SDD v19 Gelombang 1 — Sorotan (kutipan yang ditinggikan).
///
/// Bahan baku ringkasan progresif: sorotan → ringkasan → artikel.
///
/// Aturan yang ditegakkan di sini:
/// * kutipan tidak boleh kosong;
/// * bila offset diisi, keduanya wajib ada dan `mulai < akhir`; bila teks
///   sumber berubah sehingga offset tidak lagi cocok, pemanggil memakai
///   [tanpaOffset] — menyimpan kutipan saja, TIDAK menampilkan sorotan di
///   tempat yang salah;
/// * warna wajib `#RRGGBB` bila diisi.
library;

import 'dart:math';

import 'package:drift/drift.dart';

import '../database/database.dart';

/// Galat sorotan — pesannya siap tampil ke pengguna.
class GalatSorotan implements Exception {
  const GalatSorotan(this.pesan);
  final String pesan;

  @override
  String toString() => pesan;
}

/// Pola warna yang diterima (mengikuti kolom `warna` repo).
final RegExp polaWarnaSorotan = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// Repositori sorotan.
class SorotanRepository {
  SorotanRepository(this._db);

  final AppDatabase _db;
  static final Random _acak = Random.secure();

  static String uidBaru() => List<int>.generate(16, (_) => _acak.nextInt(256))
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  /// Simpan satu sorotan. Mengembalikan uid-nya.
  Future<String> tambah({
    required String entitas,
    required String entitasUid,
    required String kutipan,
    int? mulai,
    int? akhir,
    String? warna,
    String? catatan,
    DateTime? waktu,
  }) async {
    final String teks = kutipan.trim();
    if (teks.isEmpty) {
      throw const GalatSorotan('sorotan tidak boleh kosong');
    }
    if (entitas.trim().isEmpty || entitasUid.trim().isEmpty) {
      throw const GalatSorotan('sorotan butuh catatan sumber yang jelas');
    }
    if ((mulai == null) != (akhir == null)) {
      throw const GalatSorotan('posisi sorotan harus lengkap (awal dan akhir)');
    }
    if (mulai != null && akhir != null && mulai >= akhir) {
      throw const GalatSorotan('posisi sorotan tidak masuk akal');
    }
    if (warna != null && !polaWarnaSorotan.hasMatch(warna)) {
      throw const GalatSorotan('warna sorotan harus berbentuk #RRGGBB');
    }
    final String uid = uidBaru();
    await _db.into(_db.sorotan).insert(SorotanCompanion.insert(
          uid: Value(uid),
          entitas: entitas,
          entitasUid: entitasUid,
          kutipan: teks,
          mulai: Value(mulai),
          akhir: Value(akhir),
          warna: Value(warna),
          catatan: Value(catatan),
          dibuatPada: Value(waktu ?? DateTime.now()),
        ));
    return uid;
  }

  /// Buang offset (kutipan tetap) — dipakai bila teks sumber sudah berubah.
  Future<void> tanpaOffset(int id) async {
    await (_db.update(_db.sorotan)..where((t) => t.id.equals(id)))
        .write(const SorotanCompanion(mulai: Value(null), akhir: Value(null)));
  }

  /// Semua sorotan milik satu entitas, terbaru dulu.
  Future<List<SorotanData>> untukPemilik(String entitas, String entitasUid) =>
      (_db.select(_db.sorotan)
            ..where((t) =>
                t.entitas.equals(entitas) & t.entitasUid.equals(entitasUid))
            ..orderBy([(t) => OrderingTerm.desc(t.dibuatPada)]))
          .get();

  Future<int> jumlahUntuk(String entitas, String entitasUid) async {
    final QueryRow r = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM sorotan WHERE entitas = ? AND entitas_uid = ?',
          variables: <Variable<String>>[
            Variable<String>(entitas),
            Variable<String>(entitasUid),
          ],
        )
        .getSingle();
    return r.read<int>('n');
  }

  /// Catatan pengguna atas satu sorotan (boleh dikosongkan).
  Future<void> simpanCatatan(int id, String? catatan) async {
    await (_db.update(_db.sorotan)..where((t) => t.id.equals(id)))
        .write(SorotanCompanion(catatan: Value(catatan)));
  }

  Future<void> hapus(int id) =>
      (_db.delete(_db.sorotan)..where((t) => t.id.equals(id))).go();
}
