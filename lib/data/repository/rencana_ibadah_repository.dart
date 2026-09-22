/// Penyimpanan rencana haji/umrah (FR-97).
///
/// Dua tabel: `rencana_ibadah` (target dana & tanggal) dan `persiapan_ibadah`
/// (butir dokumen/berkas). Hitungannya ada di `lib/core/ibadah/rencana_ibadah.dart`
/// supaya bisa diuji tanpa basis data.
///
/// Catatan jujur: aplikasi ini TIDAK menyarankan produk keuangan apa pun dan
/// TIDAK menyimpan data pribadi seperti nomor paspor — hanya nama butir & status.
library;

import 'package:drift/drift.dart';

import '../../core/ibadah/rencana_ibadah.dart';
import '../database/database.dart';

class RencanaIbadahRepository {
  RencanaIbadahRepository(this.db);

  final AppDatabase db;

  Future<List<RencanaIbadahRingkas>> semua() async {
    final rencana = await (db.select(db.rencanaIbadah)
          ..orderBy([(r) => OrderingTerm.asc(r.targetTanggal)]))
        .get();
    final butir = await db.select(db.persiapanIbadah).get();
    return rencana
        .map((r) => RencanaIbadahRingkas(
              id: r.id,
              jenis: JenisRencanaIbadah.dariDb(r.jenis),
              nama: r.nama,
              targetSen: r.targetSen,
              terkumpulSen: r.terkumpulSen,
              targetTanggal: r.targetTanggal,
              persiapan: butir
                  .where((b) => b.rencanaId == r.id)
                  .map((b) => ButirPersiapan(
                        nama: b.nama,
                        selesai: b.selesai,
                        tanggalTarget: b.tanggalTarget,
                        catatan: b.catatan,
                      ))
                  .toList(),
            ))
        .toList();
  }

  /// Baris butir mentah satu rencana (dipakai checkbox di layar).
  Future<List<PersiapanIbadahData>> butirMentah(int rencanaId) =>
      (db.select(db.persiapanIbadah)
            ..where((b) => b.rencanaId.equals(rencanaId))
            ..orderBy([(b) => OrderingTerm.asc(b.id)]))
          .get();

  /// Tambah rencana. [denganPersiapanBawaan] mengisi daftar dokumen awal
  /// (boleh dihapus/ditambah Papi setelahnya).
  Future<int> tambahRencana({
    required JenisRencanaIbadah jenis,
    required String nama,
    required int targetSen,
    required DateTime targetTanggal,
    int terkumpulSen = 0,
    String? catatan,
    bool denganPersiapanBawaan = true,
  }) async {
    final bersih = nama.trim();
    if (bersih.isEmpty) throw ArgumentError('Nama rencana tidak boleh kosong.');
    if (targetSen < 0 || terkumpulSen < 0) {
      throw ArgumentError('Nominal tidak boleh negatif.');
    }
    final id = await db.into(db.rencanaIbadah).insert(RencanaIbadahCompanion.insert(
          jenis: Value(jenis.nilaiDb),
          nama: bersih,
          targetSen: Value(targetSen),
          terkumpulSen: Value(terkumpulSen),
          targetTanggal: targetTanggal,
          catatan: Value(catatan),
        ));
    if (denganPersiapanBawaan) {
      for (final b in persiapanBawaan(jenis)) {
        await db.into(db.persiapanIbadah).insert(PersiapanIbadahCompanion.insert(
              rencanaId: id,
              nama: b.nama,
            ));
      }
    }
    return id;
  }

  Future<void> ubahRencana(
    int id, {
    String? nama,
    int? targetSen,
    int? terkumpulSen,
    DateTime? targetTanggal,
    String? catatan,
  }) async {
    if (targetSen != null && targetSen < 0) {
      throw ArgumentError('Target tidak boleh negatif.');
    }
    await (db.update(db.rencanaIbadah)..where((r) => r.id.equals(id))).write(
      RencanaIbadahCompanion(
        nama: nama == null ? const Value.absent() : Value(nama.trim()),
        targetSen: targetSen == null ? const Value.absent() : Value(targetSen),
        terkumpulSen:
            terkumpulSen == null ? const Value.absent() : Value(terkumpulSen),
        targetTanggal:
            targetTanggal == null ? const Value.absent() : Value(targetTanggal),
        catatan: catatan == null ? const Value.absent() : Value(catatan),
        diubahPada: Value(DateTime.now()),
      ),
    );
  }

  /// Tambah [sen] ke dana terkumpul (mis. setoran bulan ini).
  Future<void> tambahDana(int id, int sen) async {
    if (sen <= 0) throw ArgumentError('Setoran harus lebih dari nol.');
    final baris = await (db.select(db.rencanaIbadah)
          ..where((r) => r.id.equals(id)))
        .getSingle();
    await (db.update(db.rencanaIbadah)..where((r) => r.id.equals(id))).write(
      RencanaIbadahCompanion(
        terkumpulSen: Value(baris.terkumpulSen + sen),
        diubahPada: Value(DateTime.now()),
      ),
    );
  }

  Future<int> tambahPersiapan(int rencanaId, String nama,
      {DateTime? tanggalTarget}) async {
    final bersih = nama.trim();
    if (bersih.isEmpty) throw ArgumentError('Nama butir tidak boleh kosong.');
    return db.into(db.persiapanIbadah).insert(PersiapanIbadahCompanion.insert(
          rencanaId: rencanaId,
          nama: bersih,
          tanggalTarget: Value(tanggalTarget),
        ));
  }

  Future<void> tandaiPersiapan(int id, bool selesai) async {
    await (db.update(db.persiapanIbadah)..where((b) => b.id.equals(id)))
        .write(PersiapanIbadahCompanion(selesai: Value(selesai)));
  }

  Future<void> hapusPersiapan(int id) async {
    await (db.delete(db.persiapanIbadah)..where((b) => b.id.equals(id))).go();
  }

  /// Hapus rencana beserta butir persiapannya (riwayat lain tidak disentuh).
  Future<void> hapusRencana(int id) async {
    await (db.delete(db.persiapanIbadah)
          ..where((b) => b.rencanaId.equals(id)))
        .go();
    await (db.delete(db.rencanaIbadah)..where((r) => r.id.equals(id))).go();
  }
}
