/// SDD v19 Gelombang 1 — Tautan (graf polimorfik antar semua entitas).
///
/// Generalisasi `tautan_pengetahuan`: tabel lama memakai ID ANGKA, tabel ini
/// memakai UID (stabil lintas HP). Tautan **berarah** (A→B); panel
/// "Dirujuk oleh" membaca arah balik lewat `idx_tautan_balik`.
///
/// Aturan yang ditegakkan di sini (bukan di basis data, karena penegakan
/// foreign key memang mati di proyek ini):
/// * entitas wajib nama tabel yang BENAR-BENAR ada di berkas basis data —
///   diperiksa ke `sqlite_master`, bukan daftar kaku di kode, supaya tidak
///   menolak tabel baru yang sah dan tidak menerima entitas hantu;
/// * tidak boleh menautkan entitas ke dirinya sendiri;
/// * pasangan yang sama tidak dibuat dua kali (indeks unik `idx_tautan_pasangan`
///   + `INSERT OR IGNORE`) — label null diperlakukan sama dengan label kosong.
library;

import 'dart:math';

import 'package:drift/drift.dart';

import '../database/database.dart';

/// Galat tautan — pesannya siap tampil ke pengguna.
class GalatTautan implements Exception {
  const GalatTautan(this.pesan);
  final String pesan;

  @override
  String toString() => pesan;
}

/// Repositori tautan (backlink).
class TautanRepository {
  TautanRepository(this._db);

  final AppDatabase _db;
  static final Random _acak = Random.secure();

  static String uidBaru() => List<int>.generate(16, (_) => _acak.nextInt(256))
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  /// Buat tautan A→B. Mengembalikan uid tautan, atau `null` bila pasangan itu
  /// sudah ada (bukan galat — memang tidak perlu dibuat dua kali).
  ///
  /// Melempar [GalatTautan] bila entitas tidak dikenal atau menautkan diri sendiri.
  Future<String?> tambah({
    required String entitasA,
    required String uidA,
    String judulA = '',
    required String entitasB,
    required String uidB,
    String judulB = '',
    String? label,
    String sumber = 'manual',
    bool usulan = false,
    double? kekuatan,
    DateTime? waktu,
  }) async {
    if (uidA.trim().isEmpty || uidB.trim().isEmpty) {
      throw const GalatTautan('tautan butuh pengenal entitas yang jelas');
    }
    await _pastikanEntitas(entitasA);
    await _pastikanEntitas(entitasB);
    if (entitasA == entitasB && uidA == uidB) {
      throw const GalatTautan('sebuah catatan tidak bisa menautkan dirinya sendiri');
    }
    final String uid = uidBaru();
    final DateTime kapan = waktu ?? DateTime.now();
    await _db.into(_db.tautan).insert(
          TautanCompanion.insert(
            uid: Value(uid),
            entitasA: entitasA,
            uidA: uidA,
            judulA: Value(judulA),
            entitasB: entitasB,
            uidB: uidB,
            judulB: Value(judulB),
            sumber: Value(sumber),
            label: Value(label),
            kekuatan: Value(kekuatan),
            usulan: Value(usulan),
            dibuatPada: Value(kapan),
          ),
          // Pasangan yang sudah ada TIDAK dibuat dua kali (indeks unik
          // idx_tautan_pasangan). Bukan galat.
          mode: InsertMode.insertOrIgnore,
        );
    final TautanData? baris = await (_db.select(_db.tautan)
          ..where((t) => t.uid.equals(uid))
          ..limit(1))
        .getSingleOrNull();
    return baris?.uid;
  }

  /// Periksa entitas benar-benar tabel yang ada.
  Future<void> _pastikanEntitas(String nama) async {
    if (nama.trim().isEmpty) {
      throw const GalatTautan('nama entitas tidak boleh kosong');
    }
    final QueryRow? ada = await _db
        .customSelect(
          "SELECT 1 AS ada FROM sqlite_master "
          "WHERE type = 'table' AND name = ? LIMIT 1",
          variables: <Variable<String>>[Variable<String>(nama)],
        )
        .getSingleOrNull();
    if (ada == null) {
      throw GalatTautan('entitas "$nama" bukan tabel yang dikenal aplikasi');
    }
  }

  /// Tautan keluar: "apa saja yang ditautkan DARI entitas ini".
  Future<List<TautanData>> keluar(String entitas, String uid) => (_db.select(_db.tautan)
        ..where((t) => t.entitasA.equals(entitas) & t.uidA.equals(uid))
        ..orderBy([(t) => OrderingTerm.desc(t.dibuatPada)]))
      .get();

  /// Tautan masuk: "siapa saja yang merujuk KE entitas ini" — panel backlink.
  Future<List<TautanData>> masuk(String entitas, String uid) => (_db.select(_db.tautan)
        ..where((t) => t.entitasB.equals(entitas) & t.uidB.equals(uid))
        ..orderBy([(t) => OrderingTerm.desc(t.dibuatPada)]))
      .get();

  /// Jumlah rujukan masuk — dipakai lencana di layar detail.
  Future<int> jumlahMasuk(String entitas, String uid) async {
    final QueryRow r = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM tautan '
          'WHERE entitas_b = ? AND uid_b = ?',
          variables: <Variable<String>>[
            Variable<String>(entitas),
            Variable<String>(uid),
          ],
        )
        .getSingle();
    return r.read<int>('n');
  }

  /// Usulan mesin yang belum diterima (antrean).
  Future<List<TautanData>> usulanMenunggu({int batas = 50}) => (_db.select(_db.tautan)
        ..where((t) => t.usulan.equals(true))
        ..orderBy([(t) => OrderingTerm.desc(t.kekuatan)])
        ..limit(batas))
      .get();

  /// Terima usulan mesin → jadi tautan yang diakui pengguna.
  Future<void> terimaUsulan(int id) async {
    await (_db.update(_db.tautan)..where((t) => t.id.equals(id)))
        .write(const TautanCompanion(usulan: Value(false)));
  }

  Future<void> hapus(int id) =>
      (_db.delete(_db.tautan)..where((t) => t.id.equals(id))).go();

  /// Buang tautan yatim — entitasnya tidak ditemukan lagi.
  ///
  /// Hanya dipakai bila pengguna memintanya (tombol di layar); TIDAK pernah
  /// otomatis, dan yang dibuang dicatat jumlahnya supaya bisa dilaporkan.
  Future<int> hapusYatim() async {
    final List<TautanData> semua = await _db.select(_db.tautan).get();
    int dibuang = 0;
    for (final TautanData t in semua) {
      final bool adaA = await _barisAda(t.entitasA, t.uidA);
      final bool adaB = await _barisAda(t.entitasB, t.uidB);
      if (!adaA || !adaB) {
        await hapus(t.id);
        dibuang++;
      }
    }
    return dibuang;
  }

  Future<bool> _barisAda(String tabel, String uid) async {
    final QueryRow? r = await _db
        .customSelect(
          'SELECT 1 AS ada FROM $tabel WHERE uid = ? LIMIT 1',
          variables: <Variable<String>>[Variable<String>(uid)],
        )
        .getSingleOrNull();
    return r != null;
  }
}
