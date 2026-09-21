/// Penyimpanan catatan Makan (FR-110) & Suasana hati (FR-112).
///
/// Terpisah dari `kesehatan_repository.dart` supaya berkas itu tidak perlu
/// disentuh (aturan proyek: modul baru memakai berkas sendiri). Hitungan ada di
/// `lib/core/laporan/makan_ringkas.dart` & `suasana_hati.dart` — murni & teruji.
library;

import 'package:drift/drift.dart';

import '../../core/laporan/makan_ringkas.dart' as makan;
import '../../core/laporan/suasana_hati.dart' as suasana;
import '../../core/utils/waktu.dart';
import '../database/database.dart';

/// Batas tunggu bawaan satu pembacaan penyimpanan.
const Duration batasBacaRingkas = Duration(seconds: 5);

class KesehatanRingkasRepository {
  KesehatanRingkasRepository(this._db);

  final AppDatabase _db;

  // -------------------------------------------------------------------------
  // FR-110 — catatan makan
  // -------------------------------------------------------------------------

  /// Catatan makan paling lama [hari] hari terakhir (lama → baru).
  Future<List<makan.BarisMakan>> daftarMakan({
    required DateTime sampai,
    int hari = 30,
  }) async {
    final awal = DateTime(sampai.year, sampai.month, sampai.day)
        .subtract(Duration(days: hari - 1));
    final baris = await (_db.select(_db.catatanMakan)
          ..where((t) => t.waktu.isBiggerOrEqualValue(awal))
          ..orderBy([(t) => OrderingTerm.asc(t.waktu)]))
        .get()
        .timeout(batasBacaRingkas);
    return baris
        .map((c) => makan.BarisMakan(
              id: c.id,
              jenis: c.jenis,
              isi: c.isi,
              porsi: c.porsi,
              mutu: c.mutu,
              waktu: c.waktu,
            ))
        .toList();
  }

  Future<int> simpanMakan({
    required String jenis,
    required String isi,
    String? porsi,
    String? mutu,
    String? catatan,
    DateTime? waktu,
    DateTime? sekarang,
  }) async {
    final kini = sekarang ?? waktuSekarang();
    return _db.into(_db.catatanMakan).insert(
          CatatanMakanCompanion.insert(
            jenis: jenis,
            isi: isi,
            porsi: Value(porsi),
            mutu: Value(mutu),
            catatan: Value(catatan),
            waktu: waktu ?? kini,
            uid: Value('lok-${kini.microsecondsSinceEpoch}-${_db.hashCode}'),
          ),
        );
  }

  Future<void> hapusMakan(int id) =>
      (_db.delete(_db.catatanMakan)..where((t) => t.id.equals(id))).go();

  // -------------------------------------------------------------------------
  // FR-112 — suasana hati & stres
  // -------------------------------------------------------------------------

  Future<List<suasana.BarisSuasana>> daftarSuasana({
    required DateTime sampai,
    int hari = 60,
  }) async {
    final awal = DateTime(sampai.year, sampai.month, sampai.day)
        .subtract(Duration(days: hari - 1));
    final baris = await (_db.select(_db.suasanaHati)
          ..where((t) => t.waktu.isBiggerOrEqualValue(awal))
          ..orderBy([(t) => OrderingTerm.asc(t.waktu)]))
        .get()
        .timeout(batasBacaRingkas);
    return baris
        .map((s) => suasana.BarisSuasana(
              id: s.id,
              skor: s.skor,
              energi: s.energi,
              stres: s.stres,
              pemicu: s.pemicu,
              catatan: s.catatan,
              waktu: s.waktu,
            ))
        .toList();
  }

  Future<int> simpanSuasana({
    required int skor,
    int? energi,
    int? stres,
    String? pemicu,
    String? catatan,
    DateTime? waktu,
    DateTime? sekarang,
  }) async {
    final kini = sekarang ?? waktuSekarang();
    return _db.into(_db.suasanaHati).insert(
          SuasanaHatiCompanion.insert(
            skor: skor.clamp(1, 5),
            energi: Value(energi),
            stres: Value(stres),
            pemicu: Value(pemicu),
            catatan: Value(catatan),
            waktu: waktu ?? kini,
            uid: Value('lok-${kini.microsecondsSinceEpoch}-${_db.hashCode}'),
          ),
        );
  }

  Future<void> hapusSuasana(int id) =>
      (_db.delete(_db.suasanaHati)..where((t) => t.id.equals(id))).go();
}
