/// SDD v19 Gelombang 3 — Temuan korelasi (yang DISIMPAN, bukan dihitung ulang).
///
/// Bedanya dengan `lib/core/analitik/temuan_pintar.dart` (FR-142): berkas itu
/// menghitung temuan sesaat dan melupakannya. Tabel ini **menyimpan** temuan
/// beserta rentang tanggalnya, sehingga pertanyaan *"apakah pola ini masih
/// benar bulan lalu?"* punya jawaban.
///
/// Empat aturan yang ditegakkan di sini — dan tidak boleh dilanggar layar:
///
/// 1. **n < 14 → DITOLAK.** Titik paling penting dari SDD §4.11. Menampilkan
///    "pola" dari 4 titik data adalah cara tercepat membuat aplikasi terasa
///    menipu, jadi bukan peringatan — melainkan penolakan.
/// 2. **Bahasa terlarang → DITOLAK** (PRD §III-11). Tidak ada "Anda mengalami",
///    "penyebab", "diagnosis" di kalimat temuan.
/// 3. **n selalu tersimpan** dan wajib ditampilkan layar.
/// 4. **Umpan balik manusia mengalahkan statistik.** Bila pengguna menyatakan
///    "bukan begitu" (dikonfirmasiPengguna = false), temuan itu diabaikan dan
///    perhitungan ulang **tidak menghidupkannya kembali**.
library;

import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/pola/mesin_pola.dart';
import '../database/database.dart';

/// Galat aturan temuan (pesannya ditujukan untuk pengguna).
class GalatTemuan implements Exception {
  GalatTemuan(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}

class TemuanRepository {
  TemuanRepository(this._db);

  final AppDatabase _db;
  static final Random _acak = Random.secure();

  static String uidBaru() => List<int>.generate(16, (_) => _acak.nextInt(256))
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  /// Simpan (atau perbarui) satu hasil mesin pola.
  ///
  /// Mengembalikan `true` bila baris tersimpan, `false` bila dilewati karena
  /// temuan itu sudah dimatikan pengguna ("bukan begitu") — bukan galat.
  Future<bool> simpanDariMesin(HasilUjiPola hasil) async {
    if (hasil.ukuranSampel < ambangSampelMinimum) {
      throw GalatTemuan(
          'Pola ini hanya punya ${hasil.ukuranSampel} pasangan data, '
          'kurang dari $ambangSampelMinimum — tidak boleh ditampilkan.');
    }
    final String kalimat = '${hasil.judul}. ${hasil.bahasa}';
    if (bahasaTerlarang(kalimat)) {
      throw GalatTemuan(
          'Kalimat temuan memuat bahasa yang dilarang (tidak boleh menyatakan '
          'sebab-akibat atau diagnosis).');
    }

    final TemuanData? ada = await cariKodeRentang(
      kode: hasil.kode,
      mulai: hasil.rentangMulai,
      selesai: hasil.rentangSelesai,
    );
    if (ada != null) {
      // Umpan balik manusia tidak boleh ditimpa perhitungan mesin.
      final bool dikunci = ada.dikonfirmasiPengguna == false || ada.diabaikan;
      await (_db.update(_db.temuan)..where((t) => t.id.equals(ada.id))).write(
        TemuanCompanion(
          judul: Value(hasil.judul),
          uraian: Value(hasil.bahasa),
          kekuatan: Value(hasil.kekuatan),
          ukuranSampel: Value(hasil.ukuranSampel),
          nilaiP: Value(hasil.nilaiP),
          dihitungPada: Value(DateTime.now()),
          diabaikan: dikunci ? const Value(true) : Value(ada.diabaikan),
        ),
      );
      return !dikunci;
    }

    await _db.into(_db.temuan).insert(
          TemuanCompanion.insert(
            uid: Value(uidBaru()),
            kode: hasil.kode,
            judul: hasil.judul,
            uraian: hasil.bahasa,
            kekuatan: hasil.kekuatan,
            ukuranSampel: hasil.ukuranSampel,
            nilaiP: Value(hasil.nilaiP),
            rentangMulai: hasil.rentangMulai,
            rentangSelesai: hasil.rentangSelesai,
          ),
        );
    return true;
  }

  Future<TemuanData?> cariKodeRentang({
    required String kode,
    required DateTime mulai,
    required DateTime selesai,
  }) =>
      (_db.select(_db.temuan)
            ..where((t) =>
                t.kode.equals(kode) &
                t.rentangMulai.equals(mulai) &
                t.rentangSelesai.equals(selesai))
            ..limit(1))
          .getSingleOrNull();

  /// Temuan yang boleh dilihat: belum diabaikan, terkuat lebih dulu.
  Future<List<TemuanData>> daftarTampil({int batas = 50}) async {
    final List<TemuanData> semua = await (_db.select(_db.temuan)
          ..where((t) => t.diabaikan.equals(false))
          ..limit(batas))
        .get();
    semua.sort((TemuanData a, TemuanData b) =>
        b.kekuatan.abs().compareTo(a.kekuatan.abs()));
    return semua;
  }

  Future<List<TemuanData>> semua({int batas = 200}) =>
      (_db.select(_db.temuan)
            ..orderBy(<OrderingTerm Function($TemuanTable)>[
              ($TemuanTable t) => OrderingTerm.desc(t.dihitungPada),
            ])
            ..limit(batas))
          .get();

  /// Umpan balik pengguna. `sadar = false` → temuan langsung diabaikan
  /// (umpan balik manusia mengalahkan statistik).
  Future<void> umpanBalik(int id, {required bool sadar}) async {
    await (_db.update(_db.temuan)..where((t) => t.id.equals(id))).write(
      TemuanCompanion(
        dikonfirmasiPengguna: Value(sadar),
        diabaikan: Value(!sadar),
      ),
    );
  }

  /// Bungkam temuan tanpa menyatakan setuju/tidak.
  Future<void> abaikan(int id) async {
    await (_db.update(_db.temuan)..where((t) => t.id.equals(id)))
        .write(const TemuanCompanion(diabaikan: Value(true)));
  }

  /// Hidupkan kembali temuan yang pernah dibungkam.
  Future<void> kembalikan(int id) async {
    await (_db.update(_db.temuan)..where((t) => t.id.equals(id))).write(
      const TemuanCompanion(
        diabaikan: Value(false),
        dikonfirmasiPengguna: Value(null),
      ),
    );
  }

  Future<void> hapus(int id) async {
    await (_db.delete(_db.temuan)..where((t) => t.id.equals(id))).go();
  }

  /// Ringkasan untuk layar: berapa tampil, berapa dibungkam, kapan terakhir dihitung.
  Future<RingkasTemuan> ringkas() async {
    final QueryRow? r = await _db.customSelect(
      'SELECT COUNT(*) AS semua, '
      'SUM(CASE WHEN diabaikan = 0 THEN 1 ELSE 0 END) AS tampil, '
      'MAX(dihitung_pada) AS terakhir FROM temuan',
    ).getSingleOrNull();
    if (r == null) {
      return const RingkasTemuan(semua: 0, tampil: 0, terakhir: null);
    }
    return RingkasTemuan(
      semua: r.readNullable<int>('semua') ?? 0,
      tampil: r.readNullable<int>('tampil') ?? 0,
      terakhir: r.readNullable<DateTime>('terakhir'),
    );
  }
}

/// Ringkasan temuan untuk layar.
class RingkasTemuan {
  const RingkasTemuan({
    required this.semua,
    required this.tampil,
    required this.terakhir,
  });

  final int semua;
  final int tampil;
  final DateTime? terakhir;
}
