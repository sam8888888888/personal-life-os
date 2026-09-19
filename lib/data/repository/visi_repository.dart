/// FR-82 — Life Planning Engine: rantai **Visi → Area hidup → Tujuan → Proyek →
/// Tugas**.
///
/// Aturan yang dijaga di sini (kriteria terima PRD):
/// 1. setiap tugas bisa **ditelusuri ke atas** sampai satu visi
///    ([rantaiTugas]); bila belum tersambung, rantai berhenti di bagian yang ada
///    dan menyebut apa adanya;
/// 2. **menghapus visi tidak menghapus data di bawahnya** — area hanya dilepas
///    (visiId = null), tujuan/proyek/tugas tidak disentuh;
/// 3. menghapus area juga hanya melepas tujuan (areaId = null).
///
/// Semua operasi memakai satu transaksi supaya tidak ada keadaan setengah jalan.
library;

import 'package:drift/drift.dart';

import '../database/database.dart';

/// Rantai satu tugas/tujuan sampai ke atas, apa adanya.
class RantaiRencana {
  const RantaiRencana({
    this.visi,
    this.area,
    this.tujuan,
    this.proyek,
    this.tugas,
  });

  final String? visi;
  final String? area;
  final String? tujuan;
  final String? proyek;
  final String? tugas;

  /// Rantai yang benar-benar ada, dari atas ke bawah.
  List<String> get bagian => [
        ?visi,
        ?area,
        ?tujuan,
        ?proyek,
        ?tugas,
      ];

  /// Kalimat siap tampil — memakai panah, tanpa kata menghakimi.
  String get kalimat =>
      bagian.isEmpty ? 'Belum tersambung ke visi.' : bagian.join(' → ');

  /// Apakah rantai ini benar-benar sampai ke visi?
  bool get sampaiVisi => visi != null;
}

class VisiRepository {
  VisiRepository(this.db);

  final AppDatabase db;

  /// Pengenal stabil baru (`vis_<microseconds>` / `ars_<microseconds>`).
  static String idVisiBaru() => 'vis_${DateTime.now().microsecondsSinceEpoch}';
  static String idAreaBaru() => 'ars_${DateTime.now().microsecondsSinceEpoch}';

  // ------------------------------------------------------------------ visi
  Future<List<VisiData>> ambilVisi({String? status}) {
    final q = db.select(db.visi)
      ..orderBy([
        (v) => OrderingTerm.asc(v.urutan),
        (v) => OrderingTerm.asc(v.nama),
      ]);
    if (status != null) {
      q.where((v) => v.status.equals(status));
    }
    return q.get();
  }

  Future<VisiData?> ambilVisiSatu(int id) =>
      (db.select(db.visi)..where((v) => v.id.equals(id))).getSingleOrNull();

  /// Tambah (`id == null`) atau ubah satu visi.
  Future<VisiData> simpanVisi({
    int? id,
    required String nama,
    String? keterangan,
    String status = 'aktif',
    int urutan = 0,
  }) async {
    final bersih = nama.trim();
    if (bersih.isEmpty) {
      throw ArgumentError('Nama visi tidak boleh kosong.');
    }
    if (id == null) {
      return db.into(db.visi).insertReturning(VisiCompanion.insert(
            idVisi: idVisiBaru(),
            nama: bersih,
            keterangan: Value(keterangan),
            status: Value(status),
            urutan: Value(urutan),
          ));
    }
    await (db.update(db.visi)..where((v) => v.id.equals(id))).write(
      VisiCompanion(
        nama: Value(bersih),
        keterangan: Value(keterangan),
        status: Value(status),
        urutan: Value(urutan),
        diubahPada: Value(DateTime.now()),
      ),
    );
    return (await ambilVisiSatu(id))!;
  }

  /// Hapus visi **tanpa** menghapus isi di bawahnya.
  ///
  /// Area yang menempel hanya dilepas (`visiId = null`); tujuan, proyek, dan
  /// tugas tidak disentuh sama sekali. Mengembalikan jumlah area yang dilepas.
  Future<int> hapusVisi(int id) => db.transaction(() async {
        final dilepas = await (db.update(db.areaHidup)
              ..where((a) => a.visiId.equals(id)))
            .write(const AreaHidupCompanion(visiId: Value(null)));
        await (db.delete(db.visi)..where((v) => v.id.equals(id))).go();
        return dilepas;
      });

  // ------------------------------------------------------------------ area
  Future<List<AreaHidupData>> ambilArea({int? visiId, bool? hanyaTanpaVisi}) {
    final q = db.select(db.areaHidup)
      ..orderBy([
        (a) => OrderingTerm.asc(a.urutan),
        (a) => OrderingTerm.asc(a.nama),
      ]);
    if (visiId != null) {
      q.where((a) => a.visiId.equals(visiId));
    } else if (hanyaTanpaVisi == true) {
      q.where((a) => a.visiId.isNull());
    }
    return q.get();
  }

  Future<AreaHidupData?> ambilAreaSatu(int id) =>
      (db.select(db.areaHidup)..where((a) => a.id.equals(id)))
          .getSingleOrNull();

  /// Tambah (`id == null`) atau ubah satu area.
  ///
  /// `kosongkanVisi = true` melepas area dari visinya (kolom nullable, jadi
  /// `visiId: null` tidak bisa dibedakan dari "tidak diubah").
  Future<AreaHidupData> simpanArea({
    int? id,
    required String nama,
    int? visiId,
    bool kosongkanVisi = false,
    String? keterangan,
    bool aktif = true,
    int urutan = 0,
  }) async {
    final bersih = nama.trim();
    if (bersih.isEmpty) {
      throw ArgumentError('Nama area tidak boleh kosong.');
    }
    if (kosongkanVisi && visiId != null) {
      throw ArgumentError(
          'Pilih salah satu: visiId diisi, atau kosongkanVisi = true.');
    }
    if (id == null) {
      return db.into(db.areaHidup).insertReturning(AreaHidupCompanion.insert(
            idArea: idAreaBaru(),
            nama: bersih,
            visiId: Value(kosongkanVisi ? null : visiId),
            keterangan: Value(keterangan),
            aktif: Value(aktif),
            urutan: Value(urutan),
          ));
    }
    await (db.update(db.areaHidup)..where((a) => a.id.equals(id))).write(
      AreaHidupCompanion(
        nama: Value(bersih),
        visiId: kosongkanVisi
            ? const Value(null)
            : (visiId == null ? const Value.absent() : Value(visiId)),
        keterangan: Value(keterangan),
        aktif: Value(aktif),
        urutan: Value(urutan),
        diubahPada: Value(DateTime.now()),
      ),
    );
    return (await ambilAreaSatu(id))!;
  }

  /// Hapus area **tanpa** menghapus tujuan di bawahnya.
  ///
  /// Mengembalikan jumlah tujuan yang dilepas (`areaId = null`).
  Future<int> hapusArea(int id) => db.transaction(() async {
        final dilepas = await (db.update(db.tujuan)
              ..where((t) => t.areaId.equals(id)))
            .write(const TujuanCompanion(areaId: Value(null)));
        await (db.delete(db.areaHidup)..where((a) => a.id.equals(id))).go();
        return dilepas;
      });

  /// Sambungkan tujuan ke satu area (null = lepas sambungan).
  Future<int> sambungkanTujuan(int tujuanId, int? areaId) =>
      (db.update(db.tujuan)..where((t) => t.id.equals(tujuanId))).write(
        TujuanCompanion(
          areaId: Value(areaId),
          diubahPada: Value(DateTime.now()),
        ),
      );

  /// Jumlah tujuan per area (untuk ringkasan di layar).
  Future<Map<int, int>> jumlahTujuanPerArea() async {
    final q = db.selectOnly(db.tujuan)
      ..addColumns([db.tujuan.areaId, db.tujuan.id.count()])
      ..groupBy([db.tujuan.areaId]);
    final baris = await q.get();
    final hasil = <int, int>{};
    for (final b in baris) {
      final id = b.read(db.tujuan.areaId);
      if (id == null) continue;
      hasil[id] = b.read(db.tujuan.id.count()) ?? 0;
    }
    return hasil;
  }

  // ---------------------------------------------------------------- rantai
  /// Telusuri rantai satu tujuan ke atas: tujuan → area → visi.
  Future<RantaiRencana> rantaiTujuan(int tujuanId) async {
    final t = await (db.select(db.tujuan)..where((x) => x.id.equals(tujuanId)))
        .getSingleOrNull();
    if (t == null) return const RantaiRencana();
    return _rantaiDari(tujuan: t);
  }

  /// Telusuri rantai satu tugas ke atas sampai visi (kriteria FR-82).
  Future<RantaiRencana> rantaiTugas(int tugasId) async {
    final g = await (db.select(db.tugas)..where((x) => x.id.equals(tugasId)))
        .getSingleOrNull();
    if (g == null) return const RantaiRencana();

    String? namaProyek;
    int? tujuanId = g.tujuanId;
    if (g.proyekId != null) {
      final p = await (db.select(db.proyek)
            ..where((x) => x.id.equals(g.proyekId!)))
          .getSingleOrNull();
      if (p != null) {
        namaProyek = p.nama;
        tujuanId ??= p.tujuanId;
      }
    }

    TujuanData? tujuan;
    if (tujuanId != null) {
      tujuan = await (db.select(db.tujuan)
            ..where((x) => x.id.equals(tujuanId!)))
          .getSingleOrNull();
    }

    final dasar = tujuan == null
        ? const RantaiRencana()
        : await _rantaiDari(tujuan: tujuan);
    return RantaiRencana(
      visi: dasar.visi,
      area: dasar.area,
      tujuan: dasar.tujuan,
      proyek: namaProyek,
      tugas: g.nama,
    );
  }

  Future<RantaiRencana> _rantaiDari({required TujuanData tujuan}) async {
    String? namaArea;
    String? namaVisi;
    final areaId = tujuan.areaId;
    if (areaId != null) {
      final a = await (db.select(db.areaHidup)
            ..where((x) => x.id.equals(areaId)))
          .getSingleOrNull();
      if (a != null) {
        namaArea = a.nama;
        final visiId = a.visiId;
        if (visiId != null) {
          final v = await (db.select(db.visi)
                ..where((x) => x.id.equals(visiId)))
              .getSingleOrNull();
          namaVisi = v?.nama;
        }
      }
    }
    return RantaiRencana(
      visi: namaVisi,
      area: namaArea,
      tujuan: tujuan.nama,
    );
  }
}
