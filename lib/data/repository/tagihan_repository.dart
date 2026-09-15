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
  ///
  /// Skema v3 (langganan & kas) — baris lain **tidak** ikut dihapus:
  /// * `Langganan` yang menaut tagihan ini ditutup (`berhenti`) dan tautannya
  ///   dikosongkan, supaya tidak ada langganan yang menunjuk tagihan hilang;
  /// * `Transaksi` yang bertaut tetap ada, hanya `tagihanId` dikosongkan —
  ///   uangnya benar-benar keluar, jadi riwayat kas tidak boleh hilang diam
  ///   diam (aturan MASTER: baris jangan hilang, nilai dikosongkan + catatan).
  Future<void> hapus(int id) => db.transaction(() async {
        await (db.update(db.langganan)..where((l) => l.tagihanId.equals(id)))
            .write(LanggananCompanion(
          tagihanId: const Value(null),
          status: Value(StatusLangganan.berhenti.nilaiDb),
          diubahPada: Value(DateTime.now()),
        ));
        await (db.update(db.transaksi)..where((t) => t.tagihanId.equals(id)))
            .write(TransaksiCompanion(
          tagihanId: const Value(null),
          diubahPada: Value(DateTime.now()),
        ));
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
      {DateTime? tanggalBayar,
      int? jumlahOverrideSen,
      DateTime? periodeYangDibayar}) async {
    return db.transaction(() async {
      final t = await (db.select(db.tagihan)..where((x) => x.id.equals(id)))
          .getSingle();
      final tglBayar = tanggalBayar ?? DateTime.now();
      final periode = t.jatuhTempo;

      // PB-06: SATU PERIODE = SATU PEMBAYARAN (idempoten).
      //
      // [periodeYangDibayar] = periode yang dilihat/dimaksud pemanggil (dari
      // kartu di layar atau dari payload notifikasi). Bila periode itu bukan
      // periode aktif lagi, artinya aksi datang dari tampilan/notifikasi lama:
      //   - sudah pernah dibayar -> kembalikan catatannya (tidak menggandakan,
      //     tidak menggeser periode dua kali),
      //   - belum pernah dibayar -> tolak dengan pesan jelas.
      // Tanpa [periodeYangDibayar], pemeriksaan tetap memakai periode aktif.
      Future<RiwayatPembayaranData?> cariCatatan(DateTime p) =>
          (db.select(db.riwayatPembayaran)
                ..where((r) =>
                    r.tagihanId.equals(id) & r.periodeJatuhTempo.equals(p))
                ..orderBy([(r) => OrderingTerm.desc(r.id)])
                ..limit(1))
              .getSingleOrNull();

      if (periodeYangDibayar != null &&
          selisihHari(periode, periodeYangDibayar) != 0) {
        final sudahDibayar = await cariCatatan(periodeYangDibayar);
        if (sudahDibayar != null) return sudahDibayar;
        throw StateError(
            'Aksi ini untuk periode ${fmtTanggalAman(periodeYangDibayar)}, '
            'sedangkan periode aktif sekarang ${fmtTanggalAman(periode)}.');
      }

      final catatanAktif = await cariCatatan(periode);
      if (catatanAktif != null) return catatanAktif;
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

  /// PB-08: satu baris PERIODE untuk tampilan bulan.
  ///
  /// Berbeda dari [TagihanData] yang hanya menyimpan keadaan sekarang, baris ini
  /// mewakili kejadian: bisa berasal dari catatan pembayaran (sudah dibayar) atau
  /// dari tagihan aktif yang belum dibayar pada bulan tersebut.
  Future<List<BarisPeriode>> periodeBulan(DateTime bulan) async {
    final awal = DateTime(bulan.year, bulan.month, 1);
    final akhir = DateTime(bulan.year, bulan.month + 1, 0);
    final tagihan = await ambilSemua();
    final namaTagihan = {for (final t in tagihan) t.id: t.nama};

    final catatan = await (db.select(db.riwayatPembayaran)
          ..where((r) =>
              r.periodeJatuhTempo.isBiggerOrEqualValue(awal) &
              r.periodeJatuhTempo.isSmallerOrEqualValue(akhir))
          ..orderBy([(r) => OrderingTerm.asc(r.periodeJatuhTempo)]))
        .get();

    final hasil = <BarisPeriode>[
      for (final r in catatan)
        BarisPeriode(
          tagihanId: r.tagihanId,
          nama: namaTagihan[r.tagihanId] ?? 'Tagihan #${r.tagihanId}',
          periode: r.periodeJatuhTempo,
          jumlahSen: r.jumlahSen,
          lunas: true,
          tanggalBayar: r.tanggalBayar,
          dariRiwayat: true,
        ),
      for (final t in tagihan.where((t) =>
          t.statusAktif &&
          !t.lunas &&
          !t.jatuhTempo.isBefore(awal) &&
          !t.jatuhTempo.isAfter(akhir) &&
          !catatan.any((r) =>
              r.tagihanId == t.id &&
              selisihHari(r.periodeJatuhTempo, t.jatuhTempo) == 0)))
        BarisPeriode(
          tagihanId: t.id,
          nama: t.nama,
          periode: t.jatuhTempo,
          jumlahSen: t.jumlahSen ?? 0,
          lunas: false,
        ),
    ]..sort((a, b) => a.periode.compareTo(b.periode));
    return hasil;
  }

  /// PB-08: ringkasan angka satu bulan (dipakai dasbor).
  Future<RingkasanBulan> ringkasanBulan(DateTime bulan) async =>
      RingkasanBulan(baris: await periodeBulan(bulan));
}

/// Satu periode tagihan pada tampilan bulan (PB-08).
class BarisPeriode {
  const BarisPeriode({
    required this.tagihanId,
    required this.nama,
    required this.periode,
    required this.jumlahSen,
    required this.lunas,
    this.tanggalBayar,
    this.dariRiwayat = false,
  });

  final int tagihanId;
  final String nama;
  final DateTime periode;
  final int jumlahSen;
  final bool lunas;
  final DateTime? tanggalBayar;

  /// true = berasal dari catatan pembayaran (sudah dibayar).
  final bool dariRiwayat;
}

/// Angka ringkas satu bulan untuk dasbor (PB-08).
class RingkasanBulan {
  const RingkasanBulan({required this.baris});

  final List<BarisPeriode> baris;

  int get totalSen => baris.fold<int>(0, (a, b) => a + b.jumlahSen);
  int get dibayarSen =>
      baris.where((b) => b.lunas).fold<int>(0, (a, b) => a + b.jumlahSen);
  int get belumSen => totalSen - dibayarSen;
  int get jumlahBelum => baris.where((b) => !b.lunas).length;
}
