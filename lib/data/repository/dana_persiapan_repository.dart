/// FR-48 — repositori Dana Persiapan.
///
/// Menyimpan dana + riwayat setoran, lalu menyusun dasbor (memakai mesin
/// `core/analitik/dana_persiapan.dart`) supaya layar tidak menghitung sendiri.
library;

import 'dart:math' show Random;

import 'package:drift/drift.dart';

import '../../core/analitik/dana_persiapan.dart';
import '../database/database.dart';

class DanaPersiapanRepository {
  DanaPersiapanRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _jam;
  static final Random _acak = Random();

  String _uid() =>
      'dsp_${_jam().microsecondsSinceEpoch.toRadixString(36)}'
      '${_acak.nextInt(1 << 20).toRadixString(36)}';

  Future<List<DanaPersiapanData>> semua({bool termasukArsip = false}) async {
    final q = db.select(db.danaPersiapan);
    if (!termasukArsip) q.where((t) => t.arsip.equals(false));
    q.orderBy([(t) => OrderingTerm.asc(t.tanggalTarget)]);
    return q.get();
  }

  Future<int> tambah({
    required String nama,
    required int targetSen,
    int tersediaSen = 0,
    DateTime? tanggalTarget,
    String? catatan,
  }) async {
    if (nama.trim().isEmpty) {
      throw ArgumentError('Nama dana tidak boleh kosong.');
    }
    return db.into(db.danaPersiapan).insert(DanaPersiapanCompanion.insert(
          uid: Value(_uid()),
          nama: nama.trim(),
          targetSen: Value(targetSen < 0 ? 0 : targetSen),
          tersediaSen: Value(tersediaSen < 0 ? 0 : tersediaSen),
          tanggalTarget: Value(tanggalTarget),
          catatan: Value(catatan == null ? '' : catatan.trim()),
          diubahPada: Value(_jam()),
        ));
  }

  Future<void> ubah(
    int id, {
    String? nama,
    int? targetSen,
    int? tersediaSen,
    DateTime? tanggalTarget,
    bool hapusTanggalTarget = false,
    String? catatan,
    bool? arsip,
  }) async {
    await (db.update(db.danaPersiapan)..where((t) => t.id.equals(id))).write(
      DanaPersiapanCompanion(
        nama: nama == null ? const Value.absent() : Value(nama.trim()),
        targetSen: targetSen == null
            ? const Value.absent()
            : Value(targetSen < 0 ? 0 : targetSen),
        tersediaSen: tersediaSen == null
            ? const Value.absent()
            : Value(tersediaSen < 0 ? 0 : tersediaSen),
        tanggalTarget: hapusTanggalTarget
            ? const Value(null)
            : (tanggalTarget == null ? const Value.absent() : Value(tanggalTarget)),
        catatan: catatan == null ? const Value.absent() : Value(catatan.trim()),
        arsip: arsip == null ? const Value.absent() : Value(arsip),
        diubahPada: Value(_jam()),
      ),
    );
  }

  /// Hapus dana BESERTA riwayat setorannya (riwayat tidak bergantung lagi).
  Future<void> hapus(int id) async {
    final baris = await (db.select(db.danaPersiapan)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (baris == null) return;
    final uid = baris.uid ?? '';
    if (uid.isNotEmpty) {
      await (db.delete(db.setoranDana)..where((t) => t.danaUid.equals(uid))).go();
    }
    await (db.delete(db.danaPersiapan)..where((t) => t.id.equals(id))).go();
  }

  Future<List<SetoranDanaData>> setoran(String danaUid, {int batas = 24}) async {
    final q = db.select(db.setoranDana)
      ..where((t) => t.danaUid.equals(danaUid))
      ..orderBy([(t) => OrderingTerm.desc(t.tanggal)])
      ..limit(batas);
    return q.get();
  }

  Future<List<SetoranDanaData>> semuaSetoran() => db.select(db.setoranDana).get();

  /// Catat setoran sekaligus menambah saldo tersedia dana (satu transaksi).
  Future<int> tambahSetoran({
    required String danaUid,
    required int jumlahSen,
    DateTime? tanggal,
    String? catatan,
  }) async {
    if (danaUid.trim().isEmpty) {
      throw ArgumentError('Dana tidak dikenali.');
    }
    if (jumlahSen == 0) {
      throw ArgumentError('Jumlah setoran tidak boleh nol.');
    }
    final baris = await (db.select(db.danaPersiapan)
          ..where((t) => t.uid.equals(danaUid)))
        .getSingleOrNull();
    if (baris == null) {
      throw ArgumentError('Dana dengan uid itu tidak ditemukan.');
    }
    return db.transaction(() async {
      final id = await db.into(db.setoranDana).insert(SetoranDanaCompanion.insert(
            uid: Value(_uid().replaceFirst('dsp_', 'stn_')),
            danaUid: danaUid,
            jumlahSen: jumlahSen,
            tanggal: tanggal ?? _jam(),
            catatan: Value(catatan == null ? '' : catatan.trim()),
            diubahPada: Value(_jam()),
          ));
      final baru = (baris.tersediaSen + jumlahSen).clamp(0, 1 << 62);
      await (db.update(db.danaPersiapan)..where((t) => t.uid.equals(danaUid)))
          .write(DanaPersiapanCompanion(
        tersediaSen: Value(baru),
        diubahPada: Value(_jam()),
      ));
      return id;
    });
  }

  Future<void> hapusSetoran(int id) async {
    final baris = await (db.select(db.setoranDana)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (baris == null) return;
    await db.transaction(() async {
      await (db.delete(db.setoranDana)..where((t) => t.id.equals(id))).go();
      final dana = await (db.select(db.danaPersiapan)
            ..where((t) => t.uid.equals(baris.danaUid)))
          .getSingleOrNull();
      if (dana != null) {
        final baru = (dana.tersediaSen - baris.jumlahSen).clamp(0, 1 << 62);
        await (db.update(db.danaPersiapan)..where((t) => t.uid.equals(baris.danaUid)))
            .write(DanaPersiapanCompanion(
          tersediaSen: Value(baru),
          diubahPada: Value(_jam()),
        ));
      }
    });
  }

  /// Dasbor lengkap untuk layar (dana + arus kas bersih bila ada).
  Future<DasborDanaPersiapan> ringkasan({int? arusKasSen}) async {
    final baris = await semua(termasukArsip: true);
    final daftar = baris
        .where((b) => !b.arsip)
        .map((b) => DanaPersiapan(
              nama: b.nama,
              targetSen: b.targetSen,
              tersediaSen: b.tersediaSen,
              tanggalTarget: b.tanggalTarget,
              arsip: b.arsip,
              catatan: b.catatan,
            ))
        .toList();
    return ringkasDanaPersiapan(daftar, sekarang: _jam(), arusKasSen: arusKasSen);
  }

  /// Riwayat setoran siap tampil (nama dana + jumlah + waktu).
  Future<List<SetoranDana>> riwayatTampil(String danaNama) async {
    final semuaSetoranKu = await semuaSetoran();
    final dana = await semua(termasukArsip: true);
    final petaUid = <String, String>{
      for (final d in dana)
        if (d.uid != null) d.uid!: d.nama,
    };
    final hasil = semuaSetoranKu
        .where((s) => petaUid[s.danaUid] == danaNama)
        .map((s) => SetoranDana(
              danaNama: petaUid[s.danaUid] ?? '—',
              jumlahSen: s.jumlahSen,
              tanggal: s.tanggal,
              catatan: s.catatan,
            ))
        .toList();
    return riwayatSetoran(hasil, danaNama);
  }
}
