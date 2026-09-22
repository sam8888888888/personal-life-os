/// FR-135 — repositori Jurnal Perjalanan.
///
/// Inti kriteria terima PRD: "Pengeluaran perjalanan masuk laporan keuangan
/// TANPA input ulang". Karena itu setiap catatan yang punya pengeluaran
/// langsung menulis satu baris `transaksi` (uang nyata) dan menyimpan
/// `transaksiId` sebagai tautan — laporan keuangan mengenalnya tanpa input
/// kedua.
library;

import 'dart:math' show Random;

import 'package:drift/drift.dart';

import '../../core/perjalanan/jurnal_perjalanan.dart';
import '../database/database.dart';

class JurnalPerjalananRepository {
  JurnalPerjalananRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _jam;
  static final _acak = Random();

  /// Kode kategori khusus perjalanan (dibuat sekali, tidak menumpuk).
  static const String kodeKategoriPerjalanan = 'kel_perjalanan';

  static String _uidBaru() => List<int>.generate(16, (_) => _acak.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  Future<List<CatatanPerjalananData>> daftar(String perjalananUid) =>
      (db.select(db.catatanPerjalanan)
            ..where((t) => t.perjalananUid.equals(perjalananUid))
            ..orderBy([(t) => OrderingTerm.desc(t.tanggal)]))
          .get();

  /// Simpan catatan. Bila [pengeluaranSen] > 0, transaksi keuangan ikut dibuat
  /// dan ditautkan (satu kali — idempotensi lewat `idTransaksi` stabil).
  Future<int> tambah({
    required String perjalananUid,
    required String idPerjalanan,
    required DateTime tanggal,
    required String judul,
    String? tempat,
    String? cerita,
    int? penilaian,
    int pengeluaranSen = 0,
  }) async {
    if (judul.trim().isEmpty) {
      throw ArgumentError('Judul catatan tidak boleh kosong.');
    }
    final uid = _uidBaru();
    final id = await db.into(db.catatanPerjalanan).insert(
          CatatanPerjalananCompanion.insert(
            uid: Value(uid),
            idCatatan: 'jrn_$uid',
            perjalananUid: perjalananUid,
            tanggal: tanggal,
            judul: judul.trim(),
            tempat:
                Value(tempat == null ? '' : tempat.trim()),
            cerita:
                Value(cerita == null ? '' : cerita.trim()),
            penilaian: Value(
                (penilaian != null && penilaian >= 1 && penilaian <= 5)
                    ? penilaian
                    : null),
            pengeluaranSen: Value(pengeluaranSen < 0 ? 0 : pengeluaranSen),
          ),
        );

    if (pengeluaranSen > 0) {
      final idTransaksi =
          idTransaksiJurnal(idPerjalanan, id); // stabil & idempoten
      final kategoriId = await _kategoriPerjalananId();
      final trxId = await db.into(db.transaksi).insert(
            TransaksiCompanion.insert(
              idTransaksi: idTransaksi,
              jenis: const Value('pengeluaran'),
              tanggal: DateTime(tanggal.year, tanggal.month, tanggal.day),
              jumlahSen: pengeluaranSen,
              kategoriId: Value(kategoriId),
              catatan: Value('Perjalanan: ${judul.trim()}'),
              sumber: const Value('perjalanan'),
              perjalananUid: Value(perjalananUid),
            ),
            onConflict: DoUpdate(
              (_) => TransaksiCompanion(
                jumlahSen: Value(pengeluaranSen),
                catatan: Value('Perjalanan: ${judul.trim()}'),
                diubahPada: Value(_jam()),
              ),
              target: [db.transaksi.idTransaksi],
            ),
          );
      final idTerpakai = trxId == 0
          ? (await (db.select(db.transaksi)
                    ..where((t) => t.idTransaksi.equals(idTransaksi)))
                  .getSingle())
              .id
          : trxId;
      await (db.update(db.catatanPerjalanan)..where((t) => t.id.equals(id)))
          .write(CatatanPerjalananCompanion(
        transaksiId: Value(idTerpakai),
        diubahPada: Value(_jam()),
      ));
    }
    return id;
  }

  /// Hapus catatan; bila punya pengeluaran, transaksi keuangannya ikut dihapus
  /// supaya laporan tidak menyimpan uang yang sudah dibatalkan.
  Future<void> hapus(int id, {bool hapusTransaksi = true}) async {
    final baris = await (db.select(db.catatanPerjalanan)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (baris == null) return;
    if (hapusTransaksi && baris.transaksiId != null) {
      await (db.delete(db.transaksi)
            ..where((t) => t.id.equals(baris.transaksiId!)))
          .go();
    }
    await (db.delete(db.catatanPerjalanan)..where((t) => t.id.equals(id))).go();
  }

  /// uid baris catatan (dipakai untuk menautkan lampiran/foto).
  Future<String?> uidCatatan(int id) async {
    final baris = await (db.select(db.catatanPerjalanan)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return baris?.uid;
  }

  Future<void> setJumlahFoto(int id, int jumlah) async {
    await (db.update(db.catatanPerjalanan)..where((t) => t.id.equals(id)))
        .write(CatatanPerjalananCompanion(jumlahFoto: Value(jumlah)));
  }

  Future<RekapJurnal> rekap(String perjalananUid, String namaPerjalanan) async {
    final baris = await daftar(perjalananUid);
    return rekapJurnal(
      namaPerjalanan: namaPerjalanan,
      catatan: baris
          .map((b) => CatatanJurnal(
                tanggal: b.tanggal,
                judul: b.judul,
                tempat: b.tempat,
                cerita: b.cerita,
                penilaian: b.penilaian,
                pengeluaranSen: b.pengeluaranSen,
                transaksiId: b.transaksiId,
                jumlahFoto: b.jumlahFoto,
              ))
          .toList(),
    );
  }

  /// Kategori `Perjalanan` — dibuat sekali, dikembalikan lagi kalau ada.
  Future<int?> _kategoriPerjalananId() async {
    final ada = await (db.select(db.kategoriTransaksi)
          ..where((t) => t.kode.equals(kodeKategoriPerjalanan)))
        .getSingleOrNull();
    if (ada != null) return ada.id;
    return db.into(db.kategoriTransaksi).insert(
          KategoriTransaksiCompanion.insert(
            kode: kodeKategoriPerjalanan,
            nama: 'Perjalanan',
            jenis: const Value('pengeluaran'),
            ikon: const Value('flight'),
            warna: const Value('#2D9CDB'),
            sifatArus: const Value('sekali'),
            bawaanSistem: const Value(true),
          ),
          onConflict: DoNothing(),
        );
  }
}
