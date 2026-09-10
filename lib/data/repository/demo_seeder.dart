/// Pengisian data contoh — hanya jalan bila aplikasi dibangun dengan
/// --dart-define=DEMO_SEED=true (dipakai untuk pratinjau/demo, tidak untuk rilis).
library;

import 'package:drift/drift.dart';

import '../database/database.dart';
import 'pengaturan_repository.dart';

const bool kDemoSeed = bool.fromEnvironment('DEMO_SEED');

Future<void> seedDemoJikaDiminta() async {
  if (!kDemoSeed) return;
  final db = AppDatabase();
  final ada = await (db.select(db.tagihan)..limit(1)).get();
  if (ada.isEmpty) {
    final repo = PengaturanRepository(db);
    await repo.isiContohData();
    // beri variasi: satu tagihan ditandai sudah dibayar, satu terlambat
    final daftar = await (db.select(db.tagihan)
          ..orderBy([(t) => OrderingTerm.asc(t.jatuhTempo)]))
        .get();
    if (daftar.length >= 3) {
      await (db.update(db.tagihan)..where((t) => t.id.equals(daftar[1].id)))
          .write(const TagihanCompanion(lunas: Value(true)));
    }
  }
  await db.close();
}
