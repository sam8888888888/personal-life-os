/// Pengumpul data kesehatan mentah untuk Peringatan Dini (FR-114) dan
/// Ringkasan Kunjungan Dokter (FR-115).
///
/// Tugasnya cuma satu: mengubah baris basis data menjadi [TitikData] dengan
/// satuan yang seragam (berat → gram, tidur/aktivitas → menit, tekanan → mmHg,
/// suasana → skor 1–5). Semua perhitungan/penilaian tetap di `lib/core/kesehatan`.
library;

import 'package:drift/drift.dart';

import '../../core/kesehatan/titik_data.dart';
import '../../core/utils/waktu.dart';
import '../database/database.dart';

class KesehatanPemantauRepository {
  KesehatanPemantauRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? waktuSekarang;

  final AppDatabase db;
  final DateTime Function() _jam;

  /// Berat badan (gram), [hari] hari terakhir.
  Future<List<TitikData>> berat({int hari = 40}) async {
    final batas = _batas(hari);
    final baris = await (db.select(db.ukuranTubuh)
          ..where((u) => u.jenis.equals('berat'))
          ..where((u) => u.tanggal.isBiggerOrEqualValue(batas))
          ..orderBy([(u) => OrderingTerm.asc(u.tanggal)]))
        .get();
    return baris
        .map((u) => TitikData(tanggal: u.tanggal, nilai: _keGram(u.nilai, u.satuan)))
        .toList();
  }

  /// Tidur (menit) per malam, [hari] hari terakhir.
  Future<List<TitikData>> tidur({int hari = 40}) async {
    final batas = _batas(hari);
    final baris = await (db.select(db.tidur)
          ..where((t) => t.tanggal.isBiggerOrEqualValue(batas))
          ..orderBy([(t) => OrderingTerm.asc(t.tanggal)]))
        .get();
    return baris
        .map((t) => TitikData(tanggal: t.tanggal, nilai: t.durasiMenit))
        .toList();
  }

  /// Aktivitas (menit) per catatan, [hari] hari terakhir.
  Future<List<TitikData>> aktivitas({int hari = 40}) async {
    final batas = _batas(hari);
    final baris = await (db.select(db.aktivitas)
          ..where((a) => a.tanggal.isBiggerOrEqualValue(batas))
          ..orderBy([(a) => OrderingTerm.asc(a.tanggal)]))
        .get();
    return baris
        .map((a) => TitikData(tanggal: a.tanggal, nilai: a.durasiMenit))
        .toList();
  }

  /// Tekanan darah (mmHg). [kedua] false = sistolik, true = diastolik.
  Future<List<TitikData>> tekanan({int hari = 40, bool kedua = false}) async {
    final batas = _batas(hari);
    final baris = await (db.select(db.catatanKesehatan)
          ..where((c) => c.jenis.equals('tekanan_darah'))
          ..where((c) => c.waktu.isBiggerOrEqualValue(batas))
          ..orderBy([(c) => OrderingTerm.asc(c.waktu)]))
        .get();
    final hasil = <TitikData>[];
    for (final c in baris) {
      final nilai = kedua ? c.nilaiKedua : c.nilai;
      if (nilai == null) continue;
      hasil.add(TitikData(tanggal: c.waktu, nilai: nilai));
    }
    return hasil;
  }

  /// Suasana hati (skor 1–5) per catatan, [hari] hari terakhir.
  Future<List<TitikData>> suasana({int hari = 40}) async {
    final batas = _batas(hari);
    final baris = await (db.select(db.suasanaHati)
          ..where((s) => s.waktu.isBiggerOrEqualValue(batas))
          ..orderBy([(s) => OrderingTerm.asc(s.waktu)]))
        .get();
    return baris
        .map((s) => TitikData(tanggal: s.waktu, nilai: s.skor))
        .toList();
  }

  /// Keluhan yang pernah dicatat di jurnal kesehatan (teks catatan), [hari] hari.
  Future<List<String>> keluhan({int hari = 30}) async {
    final batas = _batas(hari);
    final baris = await (db.select(db.catatanKesehatan)
          ..where((c) => c.waktu.isBiggerOrEqualValue(batas))
          ..orderBy([(c) => OrderingTerm.desc(c.waktu)]))
        .get();
    return baris
        .map((c) => c.catatan?.trim() ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
  }

  DateTime _batas(int hari) {
    final kini = _jam();
    return DateTime(kini.year, kini.month, kini.day)
        .subtract(Duration(days: hari));
  }

  /// Samakan satuan berat ke gram.
  static num _keGram(num nilai, String satuan) {
    switch (satuan.toLowerCase()) {
      case 'gram':
      case 'g':
        return nilai;
      case 'lb':
      case 'pound':
        return nilai * 453.592;
      case 'kg':
      default:
        return nilai * 1000;
    }
  }
}
