/// FR-134 (+ FR-135 tautan keuangan) — repositori Perjalanan.
///
/// Mesin hitungnya ada di `lib/core/perjalanan/`; berkas ini hanya mengambil &
/// menulis baris basis data lalu menyerahkan bahan mentah ke mesin itu.
library;

import 'dart:math' show Random;

import 'package:drift/drift.dart';

import '../../core/perjalanan/perjalanan.dart';
import '../database/database.dart';

class PerjalananRepository {
  PerjalananRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _jam;
  static final _acak = Random();

  static String _uidBaru() => List<int>.generate(16, (_) => _acak.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  // ── perjalanan ───────────────────────────────────────────────────────────

  Future<List<PerjalananData>> semua({bool sertakanArsip = false}) async {
    final q = db.select(db.perjalanan)
      ..orderBy([(t) => OrderingTerm.desc(t.mulai)]);
    if (!sertakanArsip) q.where((t) => t.arsip.equals(false));
    return q.get();
  }

  Future<PerjalananData?> satu(int id) => (db.select(db.perjalanan)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();

  Future<PerjalananData?> dariUid(String uid) => (db.select(db.perjalanan)
        ..where((t) => t.uid.equals(uid)))
      .getSingleOrNull();

  Future<int> tambah({
    required String nama,
    required String tujuan,
    required DateTime mulai,
    required DateTime sampai,
    int anggaranSen = 0,
    String? catatan,
  }) async {
    if (nama.trim().isEmpty) {
      throw ArgumentError('Nama perjalanan tidak boleh kosong.');
    }
    if (sampai.isBefore(mulai)) {
      throw ArgumentError('Tanggal pulang tidak boleh lebih awal dari berangkat.');
    }
    final uid = _uidBaru();
    return db.into(db.perjalanan).insert(PerjalananCompanion.insert(
          uid: Value(uid),
          idPerjalanan: 'prj_$uid',
          nama: nama.trim(),
          tujuan: Value(tujuan.trim()),
          mulai: mulai,
          sampai: sampai,
          anggaranSen: Value(anggaranSen < 0 ? 0 : anggaranSen),
          catatan: Value(catatan == null ? '' : catatan.trim()),
        ));
  }

  Future<void> ubah(
    int id, {
    String? nama,
    String? tujuan,
    DateTime? mulai,
    DateTime? sampai,
    int? anggaranSen,
    String? catatan,
  }) async {
    await (db.update(db.perjalanan)..where((t) => t.id.equals(id)))
        .write(PerjalananCompanion(
      nama: nama == null ? const Value.absent() : Value(nama.trim()),
      tujuan: tujuan == null ? const Value.absent() : Value(tujuan.trim()),
      mulai: mulai == null ? const Value.absent() : Value(mulai),
      sampai: sampai == null ? const Value.absent() : Value(sampai),
      anggaranSen:
          anggaranSen == null ? const Value.absent() : Value(anggaranSen),
      catatan: catatan == null ? const Value.absent() : Value(catatan),
      diubahPada: Value(_jam()),
    ));
  }

  Future<void> setArsip(int id, bool arsip) async {
    await (db.update(db.perjalanan)..where((t) => t.id.equals(id)))
        .write(PerjalananCompanion(
      arsip: Value(arsip),
      diubahPada: Value(_jam()),
    ));
  }

  /// Hapus perjalanan **beserta** isi & jurnalnya. Transaksi keuangan yang
  /// sudah tercatat TIDAK dihapus (uang nyata tidak boleh hilang dari laporan);
  /// screen menampilkan peringatan sebelum memanggil ini.
  Future<void> hapus(int id) async {
    final p = await satu(id);
    if (p == null) return;
    final uid = p.uid ?? '';
    if (uid.isNotEmpty) {
      await (db.delete(db.itemPerjalanan)
            ..where((t) => t.perjalananUid.equals(uid)))
          .go();
      await (db.delete(db.catatanPerjalanan)
            ..where((t) => t.perjalananUid.equals(uid)))
          .go();
    }
    await (db.delete(db.perjalanan)..where((t) => t.id.equals(id))).go();
  }

  // ── item perjalanan ──────────────────────────────────────────────────────

  Future<List<ItemPerjalananData>> items(String perjalananUid) =>
      (db.select(db.itemPerjalanan)
            ..where((t) => t.perjalananUid.equals(perjalananUid))
            ..orderBy([
              (t) => OrderingTerm.asc(t.jenis),
              (t) => OrderingTerm(expression: t.urutan),
              (t) => OrderingTerm(expression: t.id),
            ]))
          .get();

  Future<int> tambahItem({
    required String perjalananUid,
    required JenisItemPerjalanan jenis,
    required String judul,
    DateTime? waktu,
    String? tempat,
    int biayaSen = 0,
    bool selesai = false,
    String? dokumenUid,
    String? catatan,
  }) async {
    if (judul.trim().isEmpty) {
      throw ArgumentError('Judul item tidak boleh kosong.');
    }
    final uid = _uidBaru();
    return db.into(db.itemPerjalanan).insert(ItemPerjalananCompanion.insert(
          uid: Value(uid),
          idItem: 'itm_$uid',
          perjalananUid: perjalananUid,
          jenis: Value(jenis.kode),
          judul: judul.trim(),
          waktu: Value(waktu),
          tempat: Value(tempat == null ? '' : tempat.trim()),
          biayaSen: Value(biayaSen < 0 ? 0 : biayaSen),
          selesai: Value(selesai),
          dokumenUid: Value(dokumenUid),
          catatan: Value(catatan),
        ));
  }

  Future<void> setSelesaiItem(int id, bool selesai) async {
    await (db.update(db.itemPerjalanan)..where((t) => t.id.equals(id)))
        .write(ItemPerjalananCompanion(selesai: Value(selesai)));
  }

  Future<void> hapusItem(int id) async {
    await (db.delete(db.itemPerjalanan)..where((t) => t.id.equals(id))).go();
  }

  // ── ringkasan & tautan keuangan ──────────────────────────────────────────

  /// Pengeluaran NYATA dari laporan keuangan yang bertaut perjalanan ini
  /// (FR-134: "anggaran terhubung Finance").
  Future<int> realisasiSen(String perjalananUid) async {
    final baris = await (db.select(db.transaksi)
          ..where((t) => t.perjalananUid.equals(perjalananUid)))
        .get();
    var total = 0;
    for (final b in baris) {
      total += b.jenis == 'pemasukan' ? -b.jumlahSen : b.jumlahSen;
    }
    return total;
  }

  Future<RingkasanPerjalanan> ringkasan(PerjalananData p) async {
    final uid = p.uid ?? '';
    final baris = uid.isEmpty ? <ItemPerjalananData>[] : await items(uid);
    final realisasi = uid.isEmpty ? 0 : await realisasiSen(uid);
    return ringkasPerjalanan(
      dari: p.mulai,
      sampai: p.sampai,
      anggaranSen: p.anggaranSen,
      realisasiSen: realisasi,
      sekarang: _jam(),
      items: baris
          .map((b) => ItemPerjalanan(
                jenis: JenisItemPerjalanan.dariKode(b.jenis),
                judul: b.judul,
                waktu: b.waktu,
                tempat: b.tempat,
                biayaSen: b.biayaSen,
                selesai: b.selesai,
                dokumenUid: b.dokumenUid,
                catatan: b.catatan,
              ))
          .toList(),
    );
  }
}
