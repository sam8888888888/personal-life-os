/// Repositori kategori kas (FR-71/FR-72).
///
/// Aturan yang ditegakkan di sini (keputusan rancangan §4.1 + §13 butir 7):
/// 1. kategori bawaan sistem **tidak boleh dihapus** — hanya disembunyikan
///    (`arsip = true`) supaya riwayat transaksi tidak kehilangan nama;
/// 2. kategori yang masih dipakai transaksi/anggaran **tidak boleh dihapus**
///    (pesan galat menyebut pemakaiannya, bukan menghapus riwayat diam-diam);
/// 3. `kode` selalu terisi — kategori buatan pengguna memakai awalan `usr_`.
library;

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../model/enums.dart';

class KategoriTransaksiRepository {
  KategoriTransaksiRepository(this.db);

  final AppDatabase db;

  Stream<List<KategoriTransaksiData>> watchAktif({JenisArus? jenis}) {
    final q = db.select(db.kategoriTransaksi)
      ..where((k) => k.arsip.equals(false))
      ..orderBy([
        (k) => OrderingTerm.asc(k.urutan),
        (k) => OrderingTerm.asc(k.nama),
      ]);
    if (jenis != null) q.where((k) => k.jenis.equals(jenis.nilaiDb));
    return q.watch();
  }

  Future<List<KategoriTransaksiData>> ambilSemua({JenisArus? jenis}) {
    final q = db.select(db.kategoriTransaksi)
      ..where((k) => k.arsip.equals(false))
      ..orderBy([
        (k) => OrderingTerm.asc(k.urutan),
        (k) => OrderingTerm.asc(k.nama),
      ]);
    if (jenis != null) q.where((k) => k.jenis.equals(jenis.nilaiDb));
    return q.get();
  }

  Future<KategoriTransaksiData?> ambilSatu(int id) =>
      (db.select(db.kategoriTransaksi)..where((k) => k.id.equals(id)))
          .getSingleOrNull();

  /// Tambah kategori pengguna. [kode] opsional — bila kosong dibuat otomatis
  /// (`usr_<microseconds>`), stabil untuk impor/ekspor.
  Future<KategoriTransaksiData> tambah({
    required String nama,
    required JenisArus jenis,
    String? kode,
    String ikon = 'category',
    String warna = '#4A90D9',
    SifatArus sifatArus = SifatArus.campuran,
    int? urutan,
  }) async {
    final bersih = nama.trim();
    if (bersih.isEmpty) {
      throw ArgumentError('Nama kategori tidak boleh kosong.');
    }
    final kodeDipakai = kode ?? 'usr_${DateTime.now().microsecondsSinceEpoch}';
    final noUrut = urutan ?? await _urutanBerikutnya(jenis);
    return db.into(db.kategoriTransaksi).insertReturning(
          KategoriTransaksiCompanion.insert(
            kode: kodeDipakai,
            nama: bersih,
            jenis: Value(jenis.nilaiDb),
            ikon: Value(ikon),
            warna: Value(warna),
            sifatArus: Value(sifatArus.nilaiDb),
            urutan: Value(noUrut),
          ),
        );
  }

  Future<int> ubah(
    int id, {
    String? nama,
    String? ikon,
    String? warna,
    SifatArus? sifatArus,
    int? urutan,
    String? indukKode,
  }) {
    return (db.update(db.kategoriTransaksi)..where((k) => k.id.equals(id)))
        .write(KategoriTransaksiCompanion(
      nama: nama == null ? const Value.absent() : Value(nama.trim()),
      ikon: ikon == null ? const Value.absent() : Value(ikon),
      warna: warna == null ? const Value.absent() : Value(warna),
      sifatArus:
          sifatArus == null ? const Value.absent() : Value(sifatArus.nilaiDb),
      urutan: urutan == null ? const Value.absent() : Value(urutan),
      indukKode: indukKode == null ? const Value.absent() : Value(indukKode),
      diubahPada: Value(DateTime.now()),
    ));
  }

  /// Sembunyikan dari daftar tanpa menghapus riwayat transaksi.
  Future<int> sembunyikan(int id) =>
      _setArsip(id, true);

  Future<int> tampilkan(int id) => _setArsip(id, false);

  Future<int> _setArsip(int id, bool nilai) =>
      (db.update(db.kategoriTransaksi)..where((k) => k.id.equals(id)))
          .write(KategoriTransaksiCompanion(
        arsip: Value(nilai),
        diubahPada: Value(DateTime.now()),
      ));

  /// Berapa transaksi & anggaran yang memakai kategori ini.
  Future<({int transaksi, int anggaran})> pemakaian(int id) async {
    final t = await (db.selectOnly(db.transaksi)
          ..addColumns([db.transaksi.id.count()])
          ..where(db.transaksi.kategoriId.equals(id)))
        .getSingle();
    final a = await (db.selectOnly(db.anggaranBulanan)
          ..addColumns([db.anggaranBulanan.id.count()])
          ..where(db.anggaranBulanan.kategoriId.equals(id)))
        .getSingle();
    return (
      transaksi: t.read(db.transaksi.id.count()) ?? 0,
      anggaran: a.read(db.anggaranBulanan.id.count()) ?? 0,
    );
  }

  /// Hapus kategori pengguna. Menolak (dengan alasan jelas) bila kategori
  /// bawaan sistem atau masih dipakai.
  Future<void> hapus(int id) async {
    final k = await ambilSatu(id);
    if (k == null) {
      throw StateError('Kategori tidak ditemukan.');
    }
    if (k.bawaanSistem) {
      throw StateError(
          'Kategori bawaan sistem tidak bisa dihapus — sembunyikan saja '
          '(arsip) supaya riwayat lama tetap punya nama.');
    }
    final pakai = await pemakaian(id);
    if (pakai.transaksi > 0 || pakai.anggaran > 0) {
      throw StateError('Kategori masih dipakai ${pakai.transaksi} transaksi '
          'dan ${pakai.anggaran} anggaran. Sembunyikan (arsip) atau '
          'pindahkan dulu isinya.');
    }
    await (db.delete(db.kategoriTransaksi)..where((x) => x.id.equals(id))).go();
  }

  Future<int> _urutanBerikutnya(JenisArus jenis) async {
    final q = db.selectOnly(db.kategoriTransaksi)
      ..addColumns([db.kategoriTransaksi.urutan.max()])
      ..where(db.kategoriTransaksi.jenis.equals(jenis.nilaiDb));
    final baris = await q.getSingle();
    final tertinggi = baris.read(db.kategoriTransaksi.urutan.max());
    return (tertinggi ?? -1) + 1;
  }
}
