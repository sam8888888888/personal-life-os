/// Repositori tagihan — CRUD + aturan pelunasan/rollover (PRD §10.3).
library;

import 'package:drift/drift.dart';

import '../../core/utils/tanggal_utils.dart';
import '../database/database.dart';
import '../model/enums.dart';

class TagihanRepository {
  TagihanRepository(this.db);
  final AppDatabase db;

  /// Tagihan aktif, urut jatuh tempo terdekat.
  Stream<List<TagihanData>> watchAktif() => (db.select(db.tagihan)
        ..where((t) => t.statusAktif.equals(true))
        ..orderBy([
          (t) => OrderingTerm.asc(t.jatuhTempo),
          (t) => OrderingTerm.asc(t.id),
        ]))
      .watch();

  Stream<List<TagihanData>> watchSemua() =>
      (db.select(db.tagihan)..orderBy([(t) => OrderingTerm.desc(t.id)])).watch();

  /// Ambil semua tagihan sekali (bukan stream) — dipakai penyinkron pengingat
  /// dan pekerja latar yang tidak butuh pembaruan langsung.
  Future<List<TagihanData>> ambilSemua() =>
      (db.select(db.tagihan)..orderBy([(t) => OrderingTerm.asc(t.jatuhTempo)])).get();

  Future<TagihanData> tambah(TagihanCompanion c) =>
      db.into(db.tagihan).insertReturning(c);

  /// Update sebagian; mengembalikan jumlah baris berubah.
  Future<int> ubah(TagihanCompanion c, {required int id}) async {
    return (db.update(db.tagihan)..where((t) => t.id.equals(id))).write(
      c.copyWith(id: Value(id), diubahPada: Value(DateTime.now())),
    );
  }

  /// Hapus permanen beserta riwayatnya.
  Future<void> hapus(int id) => db.transaction(() async {
        await (db.delete(db.riwayatPembayaran)
              ..where((r) => r.tagihanId.equals(id)))
            .go();
        await (db.delete(db.tagihan)..where((t) => t.id.equals(id))).go();
      });

  /// Nonaktifkan tagihan berulang tanpa menghapus riwayat.
  Future<int> nonaktifkan(int id) => (db.update(db.tagihan)
        ..where((t) => t.id.equals(id)))
      .write(TagihanCompanion(
          statusAktif: const Value(false), diubahPada: Value(DateTime.now())));

  /// Tandai lunas: catat riwayat, geser periode berikutnya
  /// (day-clamping 31 Jan -> 28/29 Feb). Tagihan sekali -> nonaktif.
  Future<RiwayatPembayaranData> tandaiLunas(int id,
      {DateTime? tanggalBayar, int? jumlahOverrideSen}) async {
    return db.transaction(() async {
      final t = await (db.select(db.tagihan)..where((x) => x.id.equals(id)))
          .getSingle();
      final tglBayar = tanggalBayar ?? DateTime.now();
      final periode = t.jatuhTempo;
      final telat = selisihHari(periode, tglBayar);
      final jumlah = jumlahOverrideSen ?? t.jumlahSen ?? 0;

      final riwayatId = await db.into(db.riwayatPembayaran).insert(
            RiwayatPembayaranCompanion.insert(
              tagihanId: id,
              periodeJatuhTempo: periode,
              jumlahSen: jumlah,
              kodeMataUang: Value(t.kodeMataUang),
              tanggalBayar: tglBayar,
              telatHari: telat > 0 ? Value(telat) : const Value(null),
            ),
          );

      final f = Frekuensi.dariDb(t.frekuensi);
      final penutup = f == Frekuensi.sekali
          ? TagihanCompanion(
              lunas: const Value(true),
              tanggalLunas: Value(tglBayar),
              statusAktif: const Value(false),
              diubahPada: Value(DateTime.now()),
            )
          : TagihanCompanion(
              jatuhTempo: Value(periodeBerikutnya(periode, f, kustomHariN: t.kustomHariN)),
              lunas: const Value(false),
              tanggalLunas: const Value(null),
              diubahPada: Value(DateTime.now()),
            );
      await (db.update(db.tagihan)..where((x) => x.id.equals(id))).write(penutup);

      return (db.select(db.riwayatPembayaran)..where((r) => r.id.equals(riwayatId)))
          .getSingle();
    });
  }

  /// Batalkan status lunas (undo) — kembalikan periode sebelumnya.
  Future<void> undoLunas(int id) => db.transaction(() async {
        final riwayatTerakhir = await (db.select(db.riwayatPembayaran)
              ..where((r) => r.tagihanId.equals(id))
              ..orderBy([(r) => OrderingTerm.desc(r.id)])
              ..limit(1))
            .getSingleOrNull();
        if (riwayatTerakhir == null) return;
        await (db.delete(db.riwayatPembayaran)
              ..where((r) => r.id.equals(riwayatTerakhir.id)))
            .go();
        await (db.update(db.tagihan)..where((x) => x.id.equals(id))).write(
              TagihanCompanion(
                jatuhTempo: Value(riwayatTerakhir.periodeJatuhTempo),
                lunas: const Value(false),
                tanggalLunas: const Value(null),
                statusAktif: const Value(true),
                diubahPada: Value(DateTime.now()),
              ),
            );
      });

  /// Tagihan aktif belum lunas yang jatuh tempo dalam [dalamHari] ke depan.
  Stream<List<TagihanData>> watchJatuhTempoDalam(int dalamHari,
      {DateTime? acuan}) {
    final sekarang = acuan ?? DateTime.now();
    final dari = DateTime(sekarang.year, sekarang.month, sekarang.day);
    final sampai = dari.add(Duration(days: dalamHari));
    return (db.select(db.tagihan)
          ..where((t) =>
              t.statusAktif.equals(true) &
              t.lunas.equals(false) &
              t.jatuhTempo.isBiggerOrEqualValue(dari) &
              t.jatuhTempo.isSmallerOrEqualValue(sampai))
          ..orderBy([(t) => OrderingTerm.asc(t.jatuhTempo)]))
        .watch();
  }

  /// Total semua kewajiban terbuka (sen) — seluruh tagihan aktif belum lunas.
  Future<int> totalTerbukaSen() async {
    final semua = await (db.select(db.tagihan)
          ..where((t) => t.statusAktif.equals(true) & t.lunas.equals(false)))
        .get();
    var total = 0;
    for (final t in semua) {
      total += t.jumlahSen ?? 0;
    }
    return total;
  }

  /// Total tagihan aktif belum lunas dalam bulan kalender [bulan] (sen).
  /// Dipakai dasbor "tagihan bulan ini" (FR-08/FR-33).
  Future<int> totalBelumBayarBulanSen(DateTime bulan) async {
    final awal = DateTime(bulan.year, bulan.month, 1);
    final akhir = DateTime(bulan.year, bulan.month + 1, 0);
    final daftar = await (db.select(db.tagihan)
          ..where((t) =>
              t.statusAktif.equals(true) &
              t.lunas.equals(false) &
              t.jatuhTempo.isBiggerOrEqualValue(awal) &
              t.jatuhTempo.isSmallerOrEqualValue(akhir)))
        .get();
    var total = 0;
    for (final t in daftar) {
      total += t.jumlahSen ?? 0;
    }
    return total;
  }
}
