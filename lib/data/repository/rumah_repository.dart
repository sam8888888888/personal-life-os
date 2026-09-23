/// Repositori Home & Asset OS — FR-124 (daftar aset fisik), FR-125 (jadwal &
/// riwayat perawatan berbiaya), FR-126 (garansi).
///
/// **Kenapa aset fisik memakai tabel `aset` yang sudah ada** (bukan tabel
/// baru): PRD FR-124 meminta total nilai aset tampil dan bisa masuk ke
/// perhitungan kekayaan bersih (FR-76) *tanpa input ulang*. Menumpang tabel
/// yang sama membuat `AsetRepository.nilaiBersih()` langsung ikut menghitung
/// begitu kolom `harga_beli_sen` terisi (lihat `_nilaiAsetPada`).
///
/// **Kenapa jadwal memakai tabel `perawatan` yang sudah ada** (FR-83): mesin
/// jadwal + pengingat sudah ada; yang kurang hanya kaitan ke aset, jadi cukup
/// satu kolom `aset_id` — bukan mesin baru.
library;

import 'package:drift/drift.dart';

import '../../core/rumah/aset_fisik.dart';
import '../../core/utils/waktu.dart';
import '../database/database.dart';
import 'aset_repository.dart';

class RumahRepository {
  RumahRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? waktuSekarang;

  final AppDatabase db;
  final DateTime Function() _jam;

  /// Kode jenis aset fisik (kolom `aset.jenis`).
  static List<String> get kodeJenisFisik =>
      JenisAsetFisik.values.map((j) => j.kode).toList();

  // -------------------------------------------------------------------------
  // FR-124 — Daftar aset fisik
  // -------------------------------------------------------------------------

  /// Semua aset fisik yang belum diarsipkan, urut nama.
  Future<List<AsetData>> ambilAsetFisik({bool sertakanArsip = false}) {
    final q = db.select(db.aset)
      ..where((a) => a.jenis.isIn(kodeJenisFisik))
      ..orderBy([(a) => OrderingTerm.asc(a.nama)]);
    if (!sertakanArsip) q.where((a) => a.arsip.equals(false));
    return q.get();
  }

  Future<AsetData?> ambilAsetSatu(int id) =>
      (db.select(db.aset)..where((a) => a.id.equals(id))).getSingleOrNull();

  /// Total nilai aset fisik (sen). Harga beli yang belum diisi dihitung 0.
  Future<int> totalNilaiAsetFisikSen() async {
    final baris = await ambilAsetFisik();
    return baris.fold<int>(0, (a, b) => a + (b.hargaBeliSen ?? 0));
  }

  /// Tambah (`id == null`) atau ubah satu aset fisik.
  Future<AsetData> simpanAsetFisik({
    int? id,
    required String nama,
    required JenisAsetFisik jenis,
    DateTime? tanggalBeli,
    int? hargaBeliSen,
    String? nomorSeri,
    DateTime? garansiSampai,
    int? masaPakaiBulan,
    String? lokasi,
    String? catatan,
  }) async {
    final bersih = nama.trim();
    if (bersih.isEmpty) {
      throw ArgumentError('Nama aset tidak boleh kosong.');
    }
    if (hargaBeliSen != null && hargaBeliSen < 0) {
      throw ArgumentError('Harga beli tidak boleh negatif.');
    }
    if (masaPakaiBulan != null && masaPakaiBulan <= 0) {
      throw ArgumentError('Masa pakai harus lebih dari 0 bulan.');
    }
    final nilai = AsetCompanion(
      nama: Value(bersih),
      jenis: Value(jenis.kode),
      tanggalBeli: Value(tanggalBeli),
      hargaBeliSen: Value(hargaBeliSen),
      nomorSeri: Value(_kosongJadiNull(nomorSeri)),
      garansiSampai: Value(garansiSampai),
      masaPakaiBulan: Value(masaPakaiBulan),
      lokasi: Value(_kosongJadiNull(lokasi)),
      catatan: Value(_kosongJadiNull(catatan)),
      diubahPada: Value(_jam()),
    );
    if (id == null) {
      return db.into(db.aset).insertReturning(AsetCompanion.insert(
            idAset: AsetRepository.idAsetBaru(),
            nama: bersih,
            jenis: Value(jenis.kode),
            tanggalBeli: Value(tanggalBeli),
            hargaBeliSen: Value(hargaBeliSen),
            nomorSeri: Value(_kosongJadiNull(nomorSeri)),
            garansiSampai: Value(garansiSampai),
            masaPakaiBulan: Value(masaPakaiBulan),
            lokasi: Value(_kosongJadiNull(lokasi)),
            catatan: Value(_kosongJadiNull(catatan)),
          ));
    }
    await (db.update(db.aset)..where((a) => a.id.equals(id))).write(nilai);
    return (await ambilAsetSatu(id))!;
  }

  /// Sembunyikan aset tanpa menghapus riwayat (keputusan rancangan §4.6).
  Future<void> arsipkanAset(int id, {bool arsip = true}) =>
      (db.update(db.aset)..where((a) => a.id.equals(id)))
          .write(AsetCompanion(arsip: Value(arsip), diubahPada: Value(_jam())));

  // -------------------------------------------------------------------------
  // FR-125 — Jadwal & riwayat perawatan aset
  // -------------------------------------------------------------------------

  Future<List<PerawatanData>> jadwalAset(int asetId) => (db.select(db.perawatan)
        ..where((p) => p.asetId.equals(asetId))
        ..orderBy([(p) => OrderingTerm.asc(p.berikutnya)]))
      .get();

  /// Jadwal perawatan yang jatuh tempo dalam [hariKeDepan] hari (termasuk yang
  /// sudah lewat). Dipakai Perhatian Today & pengingat.
  Future<List<PerawatanData>> perawatanJatuhTempo(
    DateTime sekarang, {
    int hariKeDepan = 30,
  }) async {
    final batas = DateTime(sekarang.year, sekarang.month, sekarang.day)
        .add(Duration(days: hariKeDepan));
    final q = db.select(db.perawatan)
      ..where((p) => p.aktif.equals(true))
      ..where((p) => p.berikutnya.isSmallerOrEqualValue(batas))
      ..orderBy([(p) => OrderingTerm.asc(p.berikutnya)]);
    return q.get();
  }

  /// Tambah jadwal perawatan untuk satu aset. [berikutnya] kosong = dihitung
  /// dari hari ini + [intervalHari].
  Future<PerawatanData> tambahJadwalAset({
    required int asetId,
    required String nama,
    int intervalHari = 365,
    DateTime? berikutnya,
    String kategori = 'lain',
    String leadHari = '7,1',
    String? catatan,
  }) async {
    final bersih = nama.trim();
    if (bersih.isEmpty) {
      throw ArgumentError('Nama perawatan tidak boleh kosong.');
    }
    if (intervalHari <= 0) {
      throw ArgumentError('Interval perawatan harus lebih dari 0 hari.');
    }
    final awal = _jam();
    final jadwal = berikutnya ?? DateTime(awal.year, awal.month, awal.day + intervalHari);
    return db.into(db.perawatan).insertReturning(PerawatanCompanion.insert(
          nama: bersih,
          berikutnya: jadwal,
          asetId: Value(asetId),
          kategori: Value(kategori),
          intervalHari: Value(intervalHari),
          leadHari: Value(leadHari),
          catatan: Value(_kosongJadiNull(catatan)),
        ));
  }

  /// Tandai jadwal selesai hari ini: `terakhir_dilakukan` = [tanggal],
  /// `berikutnya` = tanggal + interval (boleh ditimpa [berikutnyaBaru]).
  Future<void> tandaiJadwalSelesai(
    int id, {
    DateTime? tanggal,
    DateTime? berikutnyaBaru,
  }) async {
    final baris =
        await (db.select(db.perawatan)..where((p) => p.id.equals(id)))
            .getSingleOrNull();
    if (baris == null) return;
    final kapan = tanggal ?? _jam();
    final berikut = berikutnyaBaru ??
        DateTime(kapan.year, kapan.month, kapan.day + baris.intervalHari);
    await (db.update(db.perawatan)..where((p) => p.id.equals(id))).write(
      PerawatanCompanion(
        terakhirDilakukan: Value(DateTime(kapan.year, kapan.month, kapan.day)),
        berikutnya: Value(berikut),
        diubahPada: Value(_jam()),
      ),
    );
  }

  Future<void> hapusJadwal(int id) =>
      (db.delete(db.perawatan)..where((p) => p.id.equals(id))).go();

  /// Riwayat perbaikan satu aset, terbaru di atas.
  Future<List<RiwayatPerawatanAsetData>> riwayatAset(int asetId) =>
      (db.select(db.riwayatPerawatanAset)
            ..where((r) => r.asetId.equals(asetId))
            ..orderBy([
              (r) => OrderingTerm.desc(r.tanggal),
              (r) => OrderingTerm.desc(r.id),
            ]))
          .get();

  /// Catat satu perbaikan/perawatan berbiaya.
  Future<RiwayatPerawatanAsetData> tambahRiwayat({
    required int asetId,
    required String uraian,
    required DateTime tanggal,
    int biayaSen = 0,
    int? transaksiId,
    String? catatan,
  }) async {
    final bersih = uraian.trim();
    if (bersih.isEmpty) {
      throw ArgumentError('Uraian perawatan tidak boleh kosong.');
    }
    if (biayaSen < 0) {
      throw ArgumentError('Biaya tidak boleh negatif.');
    }
    return db
        .into(db.riwayatPerawatanAset)
        .insertReturning(RiwayatPerawatanAsetCompanion.insert(
          asetId: asetId,
          uraian: bersih,
          tanggal: DateTime(tanggal.year, tanggal.month, tanggal.day),
          biayaSen: Value(biayaSen),
          transaksiId: Value(transaksiId),
          catatan: Value(_kosongJadiNull(catatan)),
        ));
  }

  Future<void> hapusRiwayat(int id) =>
      (db.delete(db.riwayatPerawatanAset)..where((r) => r.id.equals(id))).go();

  /// Ringkasan biaya perawatan satu aset (FR-125).
  Future<RingkasanBiayaPerawatan> ringkasBiayaAset(int asetId) async {
    final baris = await riwayatAset(asetId);
    return ringkasBiayaPerawatan(baris
        .map((r) => CatatanBiaya(
              tanggal: r.tanggal,
              biayaSen: r.biayaSen,
              tertaut: r.transaksiId != null,
            ))
        .toList());
  }

  // -------------------------------------------------------------------------
  // FR-126 — Garansi
  // -------------------------------------------------------------------------

  /// Aset yang garansinya berakhir dalam [ambangHari] hari (termasuk yang sudah
  /// lewat). Dipakai Perhatian di layar Today.
  Future<List<AsetData>> garansiDekat(
    DateTime sekarang, {
    int ambangHari = ambangGaransiHari,
  }) async {
    final batas = DateTime(sekarang.year, sekarang.month, sekarang.day)
        .add(Duration(days: ambangHari));
    final q = db.select(db.aset)
      ..where((a) => a.arsip.equals(false))
      ..where((a) => a.garansiSampai.isNotNull())
      ..where((a) => a.garansiSampai.isSmallerOrEqualValue(batas))
      ..orderBy([(a) => OrderingTerm.asc(a.garansiSampai)]);
    return q.get();
  }

  // -------------------------------------------------------------------------

  static String? _kosongJadiNull(String? teks) {
    final bersih = teks?.trim();
    if (bersih == null || bersih.isEmpty) return null;
    return bersih;
  }
}
