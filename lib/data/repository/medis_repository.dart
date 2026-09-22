/// FR-108 (brankas catatan medis) & FR-117 (profil kesehatan + kartu darurat).
///
/// Berkas lampiran tidak disimpan di sini: ia memakai tabel `lampiran`
/// (`induk_tabel = 'catatan_medis'`) seperti modul lain, lalu **dienkripsi**
/// lewat kanal Android Keystore (lihat `core/platform/berkas_medis.dart`).
library;

import 'package:drift/drift.dart';

import '../../core/utils/waktu.dart';
import '../database/database.dart';

/// Jenis catatan medis yang dikenali (FR-108).
class JenisCatatanMedis {
  const JenisCatatanMedis(this.kode, this.label);

  final String kode;
  final String label;

  static const List<JenisCatatanMedis> semua = [
    JenisCatatanMedis('lab', 'Hasil laboratorium'),
    JenisCatatanMedis('tahunan', 'Pemeriksaan tahunan'),
    JenisCatatanMedis('resep', 'Resep'),
    JenisCatatanMedis('imunisasi', 'Imunisasi'),
    JenisCatatanMedis('tagihan_medis', 'Tagihan medis'),
    JenisCatatanMedis('dokter', 'Catatan dokter'),
    JenisCatatanMedis('pencitraan', 'Laporan pencitraan'),
    JenisCatatanMedis('lain', 'Lain-lain'),
  ];

  /// Label jenis dari kode (nama berbeda dari field `label`).
  static String labelDari(String kode) {
    for (final j in semua) {
      if (j.kode == kode) return j.label;
    }
    return kode;
  }
}

/// Pengenal sinkron profil kesehatan — SENGAJA tetap (bukan dibuat per HP)
/// supaya profil dari beberapa HP menyatu jadi satu baris.
const String uidProfilKesehatan = 'profil_kesehatan_utama';

class MedisRepository {
  MedisRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? waktuSekarang;

  final AppDatabase db;
  final DateTime Function() _jam;

  // ------------------------------------------------------- catatan medis

  /// Daftar catatan medis, terbaru di depan.
  ///
  /// [cari] memeriksa judul, hasil, ringkasan, nama tenaga kesehatan, fasilitas
  /// dan catatan — supaya mencari kata seperti "kolesterol" menemukan catatannya
  /// (kriteria terima FR-108).
  Future<List<CatatanMedi>> ambilCatatan({
    bool sertakanArsip = false,
    String? cari,
    String? jenis,
  }) async {
    final q = db.select(db.catatanMedis)
      ..orderBy([(c) => OrderingTerm.desc(c.tanggal)]);
    if (!sertakanArsip) q.where((c) => c.arsip.equals(false));
    if (jenis != null && jenis.isNotEmpty) q.where((c) => c.jenis.equals(jenis));
    final semua = await q.get();
    final kata = (cari ?? '').trim().toLowerCase();
    if (kata.isEmpty) return semua;
    return semua.where((c) {
      final bahan = [
        c.judul,
        c.hasil,
        c.ringkasan,
        c.catatan,
        c.tenagaKesehatan,
        c.fasilitas,
        JenisCatatanMedis.labelDari(c.jenis),
      ].whereType<String>().join(' ').toLowerCase();
      return bahan.contains(kata);
    }).toList();
  }

  Future<CatatanMedi?> ambilCatatanSatu(int id) =>
      (db.select(db.catatanMedis)..where((c) => c.id.equals(id)))
          .getSingleOrNull();

  Future<CatatanMedi> simpanCatatan({
    int? id,
    required String jenis,
    required String judul,
    required DateTime tanggal,
    String? tenagaKesehatan,
    String? fasilitas,
    String? hasil,
    String? ringkasan,
    String? catatan,
    String? uid,
  }) async {
    final bersih = judul.trim();
    if (bersih.isEmpty) {
      throw ArgumentError('Judul catatan tidak boleh kosong.');
    }
    if (id == null) {
      return db.into(db.catatanMedis).insertReturning(
            CatatanMedisCompanion.insert(
              judul: bersih,
              tanggal: DateTime(tanggal.year, tanggal.month, tanggal.day),
              uid: Value(uid ?? _uidMedisBaru()),
              jenis: Value(jenis),
              tenagaKesehatan: Value(_kosongJadiNull(tenagaKesehatan)),
              fasilitas: Value(_kosongJadiNull(fasilitas)),
              hasil: Value(_kosongJadiNull(hasil)),
              ringkasan: Value(_kosongJadiNull(ringkasan)),
              catatan: Value(_kosongJadiNull(catatan)),
            ),
          );
    }
    await (db.update(db.catatanMedis)..where((c) => c.id.equals(id)))
        .write(CatatanMedisCompanion(
      jenis: Value(jenis),
      judul: Value(bersih),
      tanggal: Value(DateTime(tanggal.year, tanggal.month, tanggal.day)),
      tenagaKesehatan: Value(_kosongJadiNull(tenagaKesehatan)),
      fasilitas: Value(_kosongJadiNull(fasilitas)),
      hasil: Value(_kosongJadiNull(hasil)),
      ringkasan: Value(_kosongJadiNull(ringkasan)),
      catatan: Value(_kosongJadiNull(catatan)),
      diubahPada: Value(_jam()),
    ));
    return (await ambilCatatanSatu(id))!;
  }

  Future<void> arsipkanCatatan(int id, {bool arsip = true}) =>
      (db.update(db.catatanMedis)..where((c) => c.id.equals(id)))
          .write(CatatanMedisCompanion(
              arsip: Value(arsip), diubahPada: Value(_jam())));

  /// Hapus catatan — hanya kalau pengguna memang memintanya (dipakai uji).
  Future<void> hapusCatatan(int id) =>
      (db.delete(db.catatanMedis)..where((c) => c.id.equals(id))).go();

  // ------------------------------------------------------ profil kesehatan

  /// Profil kesehatan (satu baris). null = belum diisi.
  Future<ProfilKesehatanData?> ambilProfil() =>
      (db.select(db.profilKesehatan)
            ..orderBy([(p) => OrderingTerm.asc(p.id)])
            ..limit(1))
          .getSingleOrNull();

  /// Simpan/ubah profil kesehatan (dibuat sekali, lalu diperbarui).
  Future<ProfilKesehatanData> simpanProfil({
    String? golonganDarah,
    String? alergi,
    String? kondisi,
    String? obatPenting,
    String? kontakNama,
    String? kontakHubungan,
    String? kontakTelepon,
    String? catatan,
    bool? sembunyikanRincianDikunci,
  }) async {
    final lama = await ambilProfil();
    if (lama == null) {
      return db.into(db.profilKesehatan).insertReturning(
            ProfilKesehatanCompanion.insert(
              // uid tetap: semua HP menuju satu profil yang sama (FR-150),
              // bukan membuat profil ganda tiap perangkat.
              uid: const Value(uidProfilKesehatan),
              golonganDarah: Value(_kosongJadiNull(golonganDarah)),
              alergi: Value(_kosongJadiNull(alergi)),
              kondisi: Value(_kosongJadiNull(kondisi)),
              obatPenting: Value(_kosongJadiNull(obatPenting)),
              kontakNama: Value(_kosongJadiNull(kontakNama)),
              kontakHubungan: Value(_kosongJadiNull(kontakHubungan)),
              kontakTelepon: Value(_kosongJadiNull(kontakTelepon)),
              catatan: Value(_kosongJadiNull(catatan)),
              sembunyikanRincianDikunci:
                  Value(sembunyikanRincianDikunci ?? true),
            ),
          );
    }
    await (db.update(db.profilKesehatan)..where((p) => p.id.equals(lama.id)))
        .write(ProfilKesehatanCompanion(
      golonganDarah: Value(_kosongJadiNull(golonganDarah)),
      alergi: Value(_kosongJadiNull(alergi)),
      kondisi: Value(_kosongJadiNull(kondisi)),
      obatPenting: Value(_kosongJadiNull(obatPenting)),
      kontakNama: Value(_kosongJadiNull(kontakNama)),
      kontakHubungan: Value(_kosongJadiNull(kontakHubungan)),
      kontakTelepon: Value(_kosongJadiNull(kontakTelepon)),
      catatan: Value(_kosongJadiNull(catatan)),
      sembunyikanRincianDikunci: sembunyikanRincianDikunci == null
          ? const Value.absent()
          : Value(sembunyikanRincianDikunci),
      diubahPada: Value(_jam()),
    ));
    return (await ambilProfil())!;
  }

  /// Apakah profil cukup untuk dijadikan kartu darurat.
  static bool kartuSiap(ProfilKesehatanData? p) {
    if (p == null) return false;
    final ada = [
      p.golonganDarah,
      p.alergi,
      p.kondisi,
      p.obatPenting,
      p.kontakTelepon,
    ].where((x) => x != null && x.trim().isNotEmpty).length;
    return ada >= 2;
  }

  /// Ganti jalur berkas lampiran (dipakai setelah berkas dienkripsi).
  Future<void> gantiBerkasLampiran(int lampiranId, String berkas) =>
      (db.update(db.lampiran)..where((l) => l.id.equals(lampiranId)))
          .write(LampiranCompanion(berkas: Value(berkas)));

  static String _uidMedisBaru() =>
      'med_${DateTime.now().microsecondsSinceEpoch}';

  static String? _kosongJadiNull(String? teks) {
    final bersih = teks?.trim();
    if (bersih == null || bersih.isEmpty) return null;
    return bersih;
  }
}
