/// SDD v19 Gelombang 1 — Kotak Masuk (tangkap cepat / inbox).
///
/// Tujuan: menurunkan biaya menangkap menjadi satu tindakan tanpa keputusan.
/// Penyortiran (triase) dilakukan belakangan; tebakan tujuan hanya **usulan**,
/// pengguna yang memutuskan — sama seperti draf OCR di layar suara.
///
/// Batas yang dinyatakan jujur: tebakan tujuan otomatis (memakai pengurai
/// cerdas) BELUM dipasang di langkah ini. Kolomnya sudah ada
/// (`jenis_tebakan`, `tebakan_keyakinan`) supaya layar bisa menampilkannya
/// tanpa perubahan skema lagi.
library;

import 'dart:math';

import 'package:drift/drift.dart';

import '../database/database.dart';

/// Repositori kotak masuk.
class KotakMasukRepository {
  KotakMasukRepository(this._db);

  final AppDatabase _db;

  static final Random _acak = Random.secure();

  /// Pengenal stabil antar HP.
  static String uidBaru() => List<int>.generate(16, (_) => _acak.nextInt(256))
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  /// Simpan satu tangkapan. Mengembalikan uid barisnya.
  Future<String> tambah({
    String isi = '',
    String jenisMedia = 'teks',
    String sumber = 'layar',
    String? tautan,
    String? lampiranUid,
    int? anggotaId,
    String? jenisTebakan,
    double tebakanKeyakinan = 0,
    DateTime? waktu,
  }) async {
    final String uid = uidBaru();
    final DateTime sekarang = waktu ?? DateTime.now();
    await _db.into(_db.kotakMasuk).insert(KotakMasukCompanion.insert(
          uid: Value(uid),
          isi: Value(isi),
          jenisMedia: Value(jenisMedia),
          sumber: Value(sumber),
          tautan: Value(tautan),
          lampiranUid: Value(lampiranUid),
          anggotaId: Value(anggotaId),
          jenisTebakan: Value(jenisTebakan),
          tebakanKeyakinan: Value(tebakanKeyakinan),
          dibuatPada: Value(sekarang),
          diubahPada: Value(sekarang),
        ));
    return uid;
  }

  /// Isi antrean: `status = 'baru'`, terbaru dulu.
  Future<List<KotakMasukData>> antrean({int batas = 50}) => (_db.select(_db.kotakMasuk)
        ..where((t) => t.status.equals('baru'))
        ..orderBy([(t) => OrderingTerm.desc(t.dibuatPada)])
        ..limit(batas))
      .get();

  /// Semua baris yang belum dibuang (untuk daftar riwayat).
  Future<List<KotakMasukData>> semua({int batas = 200}) => (_db.select(_db.kotakMasuk)
        ..where((t) => t.status.isNotIn(const ['dibuang']))
        ..orderBy([(t) => OrderingTerm.desc(t.dibuatPada)])
        ..limit(batas))
      .get();

  Future<int> jumlahBaru() async {
    final hasil = await _db
        .customSelect(
          "SELECT COUNT(*) AS n FROM kotak_masuk WHERE status = 'baru'",
        )
        .getSingle();
    return hasil.read<int>('n');
  }

  Future<KotakMasukData?> cariUid(String uid) => (_db.select(_db.kotakMasuk)
        ..where((t) => t.uid.equals(uid))
        ..limit(1))
      .getSingleOrNull();

  /// Tandai sudah disortir: wajib tahu ke mana (tabel + uid tujuan).
  ///
  /// Aturan ini ditegakkan di sini, bukan di basis data: `status = 'diproses'`
  /// tanpa tujuan akan membuat baris "hilang" dari antrean tanpa jejak.
  Future<void> tandaiDiproses(
    int id, {
    required String tujuanTabel,
    required String tujuanUid,
    DateTime? waktu,
  }) async {
    if (tujuanTabel.trim().isEmpty || tujuanUid.trim().isEmpty) {
      throw ArgumentError('tujuan triase tidak boleh kosong');
    }
    await (_db.update(_db.kotakMasuk)..where((t) => t.id.equals(id))).write(
      KotakMasukCompanion(
        status: const Value('diproses'),
        tujuanTabel: Value(tujuanTabel),
        tujuanUid: Value(tujuanUid),
        diprosesPada: Value(waktu ?? DateTime.now()),
        diubahPada: Value(waktu ?? DateTime.now()),
      ),
    );
  }

  /// Arsipkan (tidak dibuang) — dipakai untuk antrean yang menua.
  Future<void> arsipkan(int id, {DateTime? waktu}) =>
      _ubahStatus(id, 'diarsipkan', waktu: waktu);

  /// Buang tanpa menghapus (jejak tetap ada untuk audit).
  Future<void> buang(int id, {DateTime? waktu}) =>
      _ubahStatus(id, 'dibuang', waktu: waktu);

  /// Kembalikan ke antrean.
  Future<void> kembalikanKeAntrean(int id, {DateTime? waktu}) =>
      _ubahStatus(id, 'baru', waktu: waktu);

  /// Hapus permanen (dipakai layar hanya setelah pengguna memilih "hapus").
  Future<void> hapus(int id) =>
      (_db.delete(_db.kotakMasuk)..where((t) => t.id.equals(id))).go();

  /// Arsipkan yang lebih tua dari [hari] hari — dijalankan atas permintaan
  /// pengguna, TIDAK pernah otomatis. Mengembalikan jumlah baris.
  Future<int> arsipkanLebihTuaDari(int hari, {DateTime? sekarang}) async {
    final DateTime batas =
        (sekarang ?? DateTime.now()).subtract(Duration(days: hari));
    return (_db.update(_db.kotakMasuk)
          ..where((t) =>
              t.status.equals('baru') &
              t.dibuatPada.isSmallerThanValue(batas)))
        .write(KotakMasukCompanion(
      status: const Value('diarsipkan'),
      diubahPada: Value(DateTime.now()),
    ));
  }

  Future<void> _ubahStatus(int id, String status, {DateTime? waktu}) async {
    await (_db.update(_db.kotakMasuk)..where((t) => t.id.equals(id))).write(
      KotakMasukCompanion(
        status: Value(status),
        diubahPada: Value(waktu ?? DateTime.now()),
      ),
    );
  }
}
