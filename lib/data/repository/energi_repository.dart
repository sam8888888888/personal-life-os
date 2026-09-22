/// Penyimpanan & hitungan energi harian (FR-84) — menumpang tabel `tidur` yang
/// sudah ada: tidur sudah dicatat per malam, jadi energi/fokus/jam produktif
/// cukup MENEMPEL pada baris malam itu (tidak ada tabel baru, tidak ada data
/// ganda).
///
/// Aturan: tidak membuat baris tidur baru dari sini — kalau malam itu belum
/// dicatat, aplikasi mengatakannya apa adanya supaya angka tidur tidak jadi
/// palsu.
library;

import 'package:drift/drift.dart';

import '../../core/kesehatan/energi_tidur.dart';
import '../../core/utils/waktu.dart';
import '../database/database.dart';

class EnergiRepository {
  EnergiRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? waktuSekarang;

  final AppDatabase db;
  final DateTime Function() _jam;

  /// Catatan [hari] terakhir (urut lama → baru).
  Future<List<CatatanEnergiHari>> catatan({int hari = 60}) async {
    final kini = _jam();
    final dari = DateTime(kini.year, kini.month, kini.day)
        .subtract(Duration(days: hari));
    final baris = await (db.select(db.tidur)
          ..where((t) => t.tanggal.isBiggerOrEqualValue(dari))
          ..orderBy([(t) => OrderingTerm.asc(t.tanggal)]))
        .get();
    return baris
        .map((r) => CatatanEnergiHari(
              tanggal: r.tanggal,
              menitTidur: r.durasiMenit,
              energi: r.energi,
              fokus: r.fokus,
              jamProduktifMenit: r.jamProduktifMenit,
            ))
        .toList();
  }

  /// Isi/sunting energi, fokus, dan jam produktif pada malam [tanggal].
  Future<TidurData> simpanEnergi({
    required DateTime tanggal,
    int? energi,
    int? fokus,
    int? jamProduktifMenit,
  }) async {
    if (energi != null && (energi < 1 || energi > 5)) {
      throw ArgumentError('Energi, bila diisi, bernilai 1–5.');
    }
    if (fokus != null && (fokus < 1 || fokus > 5)) {
      throw ArgumentError('Fokus, bila diisi, bernilai 1–5.');
    }
    if (jamProduktifMenit != null &&
        (jamProduktifMenit < 0 || jamProduktifMenit > 1439)) {
      throw ArgumentError('Jam produktif antara 00.00 dan 23.59.');
    }
    final hari = DateTime(tanggal.year, tanggal.month, tanggal.day);
    final ada = await (db.select(db.tidur)
          ..where((t) => t.tanggal.equals(hari)))
        .get();
    if (ada.isEmpty) {
      throw StateError(
          'Belum ada catatan tidur untuk ${hari.day}/${hari.month}/${hari.year}. '
          'Catat tidurnya dulu di menu Tidur, lalu isi energi di sini.');
    }
    await (db.update(db.tidur)..where((t) => t.id.equals(ada.first.id)))
        .write(TidurCompanion(
      energi: Value(energi),
      fokus: Value(fokus),
      jamProduktifMenit: Value(jamProduktifMenit),
    ));
    final sesudah = await (db.select(db.tidur)
          ..where((t) => t.id.equals(ada.first.id)))
        .getSingle();
    return sesudah;
  }

  /// Pola energi & jam produktif dari catatan [hari] terakhir.
  Future<PolaEnergi> pola({int hari = 60, int minimalHari = 14}) async =>
      hitungPolaEnergi(await catatan(hari: hari), minimalHari: minimalHari);
}
