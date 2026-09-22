/// FR-133 — repositori Kas & Tanggung Jawab Rumah Tangga.
///
/// "Pengingat tidak terkirim tanpa persetujuan pengguna": saklar persetujuan
/// disimpan di tabel `pengaturan` (bukan tabel baru) dan diperiksa lagi di
/// lapisan repositori — bukan hanya disembunyikan di layar.
library;

import 'dart:math' show Random;

import 'package:drift/drift.dart';

import '../../core/rumah/tanggung_jawab_rumah.dart';
import '../database/database.dart';
import 'pengaturan_repository.dart';

class TanggungJawabRepository {
  TanggungJawabRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? DateTime.now,
        _pengaturan = PengaturanRepository(db);

  final AppDatabase db;
  final DateTime Function() _jam;
  final PengaturanRepository _pengaturan;
  static final _acak = Random();

  /// Kunci saklar persetujuan di tabel `pengaturan`.
  static const String kunciPersetujuan = 'rumah.izinkan_pengingat';

  static String _uidBaru() => List<int>.generate(16, (_) => _acak.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  Future<bool> persetujuanMenyala() =>
      _pengaturan.bacaSaklar(kunciPersetujuan);

  Future<void> setPersetujuan(bool nilai) =>
      _pengaturan.simpan(kunciPersetujuan, nilai ? '1' : '0');

  Future<List<TanggungJawabRumahData>> semua({bool sertakanLunas = true}) async {
    final q = db.select(db.tanggungJawabRumah)
      ..orderBy([
        (t) => OrderingTerm(expression: t.lunas),
        (t) => OrderingTerm(expression: t.jatuhTempo),
      ]);
    if (!sertakanLunas) q.where((t) => t.lunas.equals(false));
    return q.get();
  }

  Future<int> tambah({
    required String nama,
    required int jumlahSen,
    required DateTime jatuhTempo,
    String? pemilikNama,
    String? penanggungJawabNama,
    String? catatan,
    String frekuensi = 'bulanan',
  }) async {
    if (nama.trim().isEmpty) {
      throw ArgumentError('Nama kewajiban tidak boleh kosong.');
    }
    final uid = _uidBaru();
    return db.into(db.tanggungJawabRumah).insert(
          TanggungJawabRumahCompanion.insert(
            uid: Value(uid),
            idTanggungJawab: 'tjr_$uid',
            nama: nama.trim(),
            jumlahSen: Value(jumlahSen < 0 ? 0 : jumlahSen),
            jatuhTempo: jatuhTempo,
            pemilikNama: Value(_teks(pemilikNama)),
            penanggungJawabNama: Value(_teks(penanggungJawabNama)),
            catatan: Value(_teks(catatan)),
            frekuensi: Value(frekuensi),
          ),
        );
  }

  Future<void> ubah(
    int id, {
    String? nama,
    int? jumlahSen,
    DateTime? jatuhTempo,
    String? pemilikNama,
    String? penanggungJawabNama,
    String? catatan,
  }) async {
    await (db.update(db.tanggungJawabRumah)..where((t) => t.id.equals(id)))
        .write(TanggungJawabRumahCompanion(
      nama: nama == null ? const Value.absent() : Value(nama.trim()),
      jumlahSen: jumlahSen == null ? const Value.absent() : Value(jumlahSen),
      jatuhTempo:
          jatuhTempo == null ? const Value.absent() : Value(jatuhTempo),
      pemilikNama: pemilikNama == null
          ? const Value.absent()
          : Value(_teks(pemilikNama)),
      penanggungJawabNama: penanggungJawabNama == null
          ? const Value.absent()
          : Value(_teks(penanggungJawabNama)),
      catatan: catatan == null ? const Value.absent() : Value(_teks(catatan)),
      diubahPada: Value(_jam()),
    ));
  }

  /// Tandai lunas + simpan catatan pelunasan (FR-133: "catatan pelunasan").
  Future<void> tandaiLunas(
    int id, {
    String? catatanPelunasan,
    DateTime? tanggalBayar,
  }) async {
    await (db.update(db.tanggungJawabRumah)..where((t) => t.id.equals(id)))
        .write(TanggungJawabRumahCompanion(
      lunas: const Value(true),
      tanggalBayar: Value(tanggalBayar ?? _jam()),
      catatanPelunasan: Value(_teks(catatanPelunasan)),
      diubahPada: Value(_jam()),
    ));
  }

  Future<void> batalkanLunas(int id) async {
    await (db.update(db.tanggungJawabRumah)..where((t) => t.id.equals(id)))
        .write(TanggungJawabRumahCompanion(
      lunas: const Value(false),
      tanggalBayar: const Value(null),
      diubahPada: Value(_jam()),
    ));
  }

  Future<void> hapus(int id) async {
    await (db.delete(db.tanggungJawabRumah)..where((t) => t.id.equals(id))).go();
  }

  /// Catat bahwa pengingat halus sudah dikirim (dipakai pembatas sekali/hari).
  Future<void> catatDiingatkan(int id, DateTime waktu) async {
    await (db.update(db.tanggungJawabRumah)..where((t) => t.id.equals(id)))
        .write(TanggungJawabRumahCompanion(
      diingatkanPada: Value(waktu),
      diubahPada: Value(waktu),
    ));
  }

  Future<TanggungJawabRumahData?> satu(int id) =>
      (db.select(db.tanggungJawabRumah)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<RingkasanRumahTangga> ringkasan() async {
    final baris = await semua();
    return ringkasRumahTangga(
      baris
          .map((b) => KewajibanRumah(
                nama: b.nama,
                jumlahSen: b.jumlahSen,
                jatuhTempo: b.jatuhTempo,
                pemilikNama: b.pemilikNama,
                penanggungJawabNama: b.penanggungJawabNama,
                lunas: b.lunas,
                tanggalBayar: b.tanggalBayar,
                catatanPelunasan: b.catatanPelunasan,
                diingatkanPada: b.diingatkanPada,
              ))
          .toList(),
      sekarang: _jam(),
    );
  }

  static String? _teks(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
