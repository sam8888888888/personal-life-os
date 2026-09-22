/// FR-131 — Anggota keluarga & tanggung jawab.
///
/// Satu item (tagihan atau tugas) boleh punya **pemilik** (untuk siapa item itu)
/// dan **penanggung jawab** (yang mengerjakan/membayar) — sesuai contoh PRD:
/// "tagihan sekolah: pemilik anak, penanggung jawab pasangan".
///
/// Data anggota bertanda `pribadi` (mis. anak) dibatasi: pemanggil hanya
/// menerimanya bila [sertakanPribadi] true — layar mengisinya dari pemeriksaan
/// kunci layar perangkat, bukan dari tombol biasa.
library;

import 'package:drift/drift.dart';

import '../../core/utils/waktu.dart';
import '../database/database.dart';

/// Satu anggota keluarga + ringkasan bebannya.
class AnggotaDenganBeban {
  const AnggotaDenganBeban({
    required this.anggota,
    required this.jumlahTagihan,
    required this.totalTagihanSen,
    required this.jumlahTugas,
  });

  final AnggotaKeluargaData anggota;
  final int jumlahTagihan;
  final int totalTagihanSen;
  final int jumlahTugas;
}

class KeluargaRepository {
  KeluargaRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? waktuSekarang;

  final AppDatabase db;
  final DateTime Function() _jam;

  static String idAnggotaBaru() =>
      'ang_${DateTime.now().microsecondsSinceEpoch}';

  /// Label hubungan yang dipakai aplikasi (bebas, tapi ini yang ditawarkan).
  static const List<String> hubungan = [
    'pasangan',
    'anak',
    'orangtua',
    'saudara',
    'lain',
  ];

  // ------------------------------------------------------------- anggota

  /// Daftar anggota. [sertakanPribadi] false = anggota ber-tanda `pribadi`
  /// disembunyikan (dipakai saat perangkat masih terkunci).
  Future<List<AnggotaKeluargaData>> ambilAnggota({
    bool sertakanArsip = false,
    bool sertakanPribadi = true,
  }) {
    final q = db.select(db.anggotaKeluarga)
      ..orderBy([(a) => OrderingTerm.asc(a.nama)]);
    if (!sertakanArsip) q.where((a) => a.arsip.equals(false));
    if (!sertakanPribadi) q.where((a) => a.pribadi.equals(false));
    return q.get();
  }

  Future<AnggotaKeluargaData?> ambilAnggotaSatu(int id) =>
      (db.select(db.anggotaKeluarga)..where((a) => a.id.equals(id)))
          .getSingleOrNull();

  Future<AnggotaKeluargaData> simpanAnggota({
    int? id,
    required String nama,
    String hubungan = 'lain',
    DateTime? tanggalLahir,
    bool pribadi = false,
    String? catatan,
  }) async {
    final bersih = nama.trim();
    if (bersih.isEmpty) {
      throw ArgumentError('Nama anggota tidak boleh kosong.');
    }
    if (id == null) {
      final idBaru = idAnggotaBaru();
      return db.into(db.anggotaKeluarga).insertReturning(
            AnggotaKeluargaCompanion.insert(
              idAnggota: idBaru,
              // uid = pengenal sinkron (FR-150): nilai sama di semua HP.
              uid: Value(idBaru),
              nama: bersih,
              hubungan: Value(hubungan),
              tanggalLahir: Value(tanggalLahir),
              pribadi: Value(pribadi),
              catatan: Value(_kosongJadiNull(catatan)),
            ),
          );
    }
    await (db.update(db.anggotaKeluarga)..where((a) => a.id.equals(id)))
        .write(AnggotaKeluargaCompanion(
      nama: Value(bersih),
      hubungan: Value(hubungan),
      tanggalLahir:
          tanggalLahir == null ? const Value.absent() : Value(tanggalLahir),
      pribadi: Value(pribadi),
      catatan: Value(_kosongJadiNull(catatan)),
      diubahPada: Value(_jam()),
    ));
    return (await ambilAnggotaSatu(id))!;
  }

  Future<void> arsipkanAnggota(int id, {bool arsip = true}) =>
      (db.update(db.anggotaKeluarga)..where((a) => a.id.equals(id)))
          .write(AnggotaKeluargaCompanion(
              arsip: Value(arsip), diubahPada: Value(_jam())));

  // ------------------------------------------------- penanggung jawab item

  /// Tetapkan pemilik & penanggung jawab pada satu TAGIHAN.
  Future<void> tetapkanPemilikTagihan(
    int tagihanId, {
    int? pemilikId,
    int? penanggungJawabId,
    bool hapusPemilik = false,
    bool hapusPenanggungJawab = false,
  }) =>
      (db.update(db.tagihan)..where((t) => t.id.equals(tagihanId))).write(
        TagihanCompanion(
          pemilikId: hapusPemilik ? const Value(null) : Value(pemilikId),
          penanggungJawabId: hapusPenanggungJawab
              ? const Value(null)
              : Value(penanggungJawabId),
        ),
      );

  /// Tetapkan pemilik & penanggung jawab pada satu TUGAS.
  Future<void> tetapkanPemilikTugas(
    int tugasId, {
    int? pemilikId,
    int? penanggungJawabId,
    bool hapusPemilik = false,
    bool hapusPenanggungJawab = false,
  }) =>
      (db.update(db.tugas)..where((t) => t.id.equals(tugasId))).write(
        TugasCompanion(
          pemilikId: hapusPemilik ? const Value(null) : Value(pemilikId),
          penanggungJawabId: hapusPenanggungJawab
              ? const Value(null)
              : Value(penanggungJawabId),
        ),
      );

  // -------------------------------------------------------------- saringan

  /// Tagihan milik ATAU ditanggung [anggotaId].
  Future<List<TagihanData>> tagihanAnggota(int anggotaId) => (db.select(db.tagihan)
        ..where((t) =>
            t.pemilikId.equals(anggotaId) |
            t.penanggungJawabId.equals(anggotaId))
        ..orderBy([(t) => OrderingTerm.asc(t.jatuhTempo)]))
      .get();

  /// Tugas milik ATAU ditanggung [anggotaId].
  Future<List<Tuga>> tugasAnggota(int anggotaId) => (db.select(db.tugas)
        ..where((t) =>
            t.pemilikId.equals(anggotaId) |
            t.penanggungJawabId.equals(anggotaId))
        ..orderBy([(t) => OrderingTerm.asc(t.nama)]))
      .get();

  /// Ringkasan beban tiap anggota (jumlah & total tagihan, jumlah tugas).
  Future<List<AnggotaDenganBeban>> ringkasBeban({
    bool sertakanPribadi = true,
  }) async {
    final anggota = await ambilAnggota(sertakanPribadi: sertakanPribadi);
    final hasil = <AnggotaDenganBeban>[];
    for (final a in anggota) {
      final t = await tagihanAnggota(a.id);
      final g = await tugasAnggota(a.id);
      hasil.add(AnggotaDenganBeban(
        anggota: a,
        jumlahTagihan: t.length,
        totalTagihanSen: t.fold<int>(0, (x, y) => x + (y.jumlahSen ?? 0)),
        jumlahTugas: g.where((z) => !z.selesai).length,
      ));
    }
    return hasil;
  }

  static String? _kosongJadiNull(String? teks) {
    final bersih = teks?.trim();
    if (bersih == null || bersih.isEmpty) return null;
    return bersih;
  }
}
