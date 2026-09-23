/// Penyimpanan tinjauan mingguan (FR-144) & arsip laporan bulanan (FR-145).
///
/// Keduanya memakai `uid` stabil (bukan id baris) supaya ikut mesin sinkron
/// FR-150 tanpa menggandakan baris saat 4 HP bertukar data.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/utils/waktu.dart';
import '../database/database.dart';
import '../../core/notifikasi/jejak.dart';

class TinjauanRepository {
  TinjauanRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? waktuSekarang;

  final AppDatabase db;
  final DateTime Function() _jam;

  // ── FR-144 ────────────────────────────────────────────────────────────────

  static String uidPekan(DateTime pekanMulai) =>
      'tw_${pekanMulai.year}-${_dua(pekanMulai.month)}-${_dua(pekanMulai.day)}';

  static String uidLaporan(String bulan) => 'lb_$bulan';

  Future<TinjauanMingguanData?> ambilPekan(DateTime pekanMulai) {
    final uid = uidPekan(pekanMulai);
    return (db.select(db.tinjauanMingguan)
          ..where((t) => t.uid.equals(uid))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Simpan (atau perbarui) tinjauan satu pekan.
  Future<void> simpanPekan({
    required DateTime pekanMulai,
    String? membaik,
    String? perluPerhatian,
    String? fokusPekanDepan,
    bool selesai = false,
  }) async {
    final uid = uidPekan(pekanMulai);
    final lama = await ambilPekan(pekanMulai);
    final kini = _jam();
    if (lama == null) {
      await db.into(db.tinjauanMingguan).insert(TinjauanMingguanCompanion.insert(
            uid: Value(uid),
            pekanMulai: pekanMulai,
            membaik: Value(membaik),
            perluPerhatian: Value(perluPerhatian),
            fokusPekanDepan: Value(fokusPekanDepan),
            selesai: Value(selesai),
            dibuatPada: Value(kini),
            diubahPada: Value(kini),
          ));
      return;
    }
    await (db.update(db.tinjauanMingguan)..where((t) => t.uid.equals(uid)))
        .write(TinjauanMingguanCompanion(
      membaik: Value(membaik),
      perluPerhatian: Value(perluPerhatian),
      fokusPekanDepan: Value(fokusPekanDepan),
      selesai: Value(selesai),
      diubahPada: Value(kini),
    ));
  }

  /// Riwayat tinjauan, terbaru lebih dulu.
  Future<List<TinjauanMingguanData>> riwayatPekan({int batas = 26}) =>
      (db.select(db.tinjauanMingguan)
            ..orderBy([(t) => OrderingTerm.desc(t.pekanMulai)])
            ..limit(batas))
          .get();

  // ── FR-145 ────────────────────────────────────────────────────────────────

  Future<ArsipLaporanBulananData?> ambilLaporan(String bulan) {
    final uid = uidLaporan(bulan);
    return (db.select(db.arsipLaporanBulanan)
          ..where((a) => a.uid.equals(uid))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Simpan laporan bulanan (termasuk angka kuncinya) sebagai arsip.
  Future<void> simpanLaporan({
    required String bulan,
    required String ringkasTeks,
    required Map<String, Object?> angka,
  }) async {
    final uid = uidLaporan(bulan);
    final lama = await ambilLaporan(bulan);
    final json = jsonEncode(angka);
    if (lama == null) {
      await db
          .into(db.arsipLaporanBulanan)
          .insert(ArsipLaporanBulananCompanion.insert(
            uid: Value(uid),
            bulan: bulan,
            ringkasTeks: ringkasTeks,
            angkaJson: Value(json),
            dibuatPada: Value(_jam()),
          ));
      return;
    }
    await (db.update(db.arsipLaporanBulanan)..where((a) => a.uid.equals(uid)))
        .write(ArsipLaporanBulananCompanion(
      ringkasTeks: Value(ringkasTeks),
      angkaJson: Value(json),
      dibuatPada: Value(_jam()),
    ));
  }

  Future<List<ArsipLaporanBulananData>> riwayatLaporan({int batas = 24}) =>
      (db.select(db.arsipLaporanBulanan)
            ..orderBy([(a) => OrderingTerm.desc(a.bulan)])
            ..limit(batas))
          .get();

  /// Angka tersimpan sebagai peta (untuk pembanding antar bulan).
  static Map<String, Object?> bacaAngka(ArsipLaporanBulananData a) {
    try {
      final isi = jsonDecode(a.angkaJson);
      if (isi is Map) return isi.cast<String, Object?>();
    } catch (e) {
      // arsip lama/rusak: layar tetap menampilkan teksnya, angka dilewati —
      // tetapi kegagalannya DICATAT supaya tidak hilang tanpa jejak.
      catatGalatTertelan('tinjauan.angkaArsipRusak', e);
    }
    return const <String, Object?>{};
  }

  static String _dua(int n) => n.toString().padLeft(2, '0');
}
