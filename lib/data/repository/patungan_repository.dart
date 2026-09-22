/// FR-47 — repositori Split Bill & Patungan.
///
/// Menyimpan grup, anggota, belanja, dan bagian; mesin hitungnya ada di
/// `core/keuangan/patungan.dart` supaya bisa diuji tanpa basis data.
library;

import 'dart:math' show Random;

import 'package:drift/drift.dart';

import '../../core/rumah/patungan.dart';
import '../database/database.dart';

class PatunganRepository {
  PatunganRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _jam;
  static final Random _acak = Random();

  String _uid(String awalan) =>
      '$awalan${_jam().microsecondsSinceEpoch.toRadixString(36)}'
      '${_acak.nextInt(1 << 20).toRadixString(36)}';

  /// Kode undangan sederhana: 6 huruf/angka besar, mudah dibaca ulang.
  String kodeUndanganBaru() {
    const huruf = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final sb = StringBuffer();
    for (var i = 0; i < 6; i++) {
      sb.write(huruf[_acak.nextInt(huruf.length)]);
    }
    return sb.toString();
  }

  // ── Grup ──────────────────────────────────────────────────────────────────
  Future<List<GrupPatunganData>> grupSemua({bool termasukArsip = false}) async {
    final q = db.select(db.grupPatungan);
    if (!termasukArsip) q.where((t) => t.arsip.equals(false));
    q.orderBy([(t) => OrderingTerm.desc(t.diubahPada)]);
    return q.get();
  }

  Future<int> tambahGrup({required String nama, String? catatan}) async {
    if (nama.trim().isEmpty) {
      throw ArgumentError('Nama grup tidak boleh kosong.');
    }
    return db.into(db.grupPatungan).insert(GrupPatunganCompanion.insert(
          uid: Value(_uid('grp_')),
          nama: nama.trim(),
          catatan: Value(catatan == null ? '' : catatan.trim()),
          kodeUndangan: Value(kodeUndanganBaru()),
          diubahPada: Value(_jam()),
        ));
  }

  Future<void> ubahGrup(int id, {String? nama, String? catatan, bool? arsip}) async {
    await (db.update(db.grupPatungan)..where((t) => t.id.equals(id)))
        .write(GrupPatunganCompanion(
      nama: nama == null ? const Value.absent() : Value(nama.trim()),
      catatan: catatan == null ? const Value.absent() : Value(catatan.trim()),
      arsip: arsip == null ? const Value.absent() : Value(arsip),
      diubahPada: Value(_jam()),
    ));
  }

  /// Hapus grup + anggota + belanja + bagiannya (semua milik grup itu).
  Future<void> hapusGrup(int id) async {
    final grup =
        await (db.select(db.grupPatungan)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    if (grup == null) return;
    final uid = grup.uid ?? '';
    await db.transaction(() async {
      if (uid.isNotEmpty) {
        final belanja = await (db.select(db.belanjaPatungan)
              ..where((t) => t.grupUid.equals(uid)))
            .get();
        for (final b in belanja) {
          final bu = b.uid ?? '';
          if (bu.isNotEmpty) {
            await (db.delete(db.bagianPatungan)
                  ..where((t) => t.belanjaUid.equals(bu)))
                .go();
          }
        }
        await (db.delete(db.belanjaPatungan)..where((t) => t.grupUid.equals(uid)))
            .go();
        await (db.delete(db.anggotaPatungan)..where((t) => t.grupUid.equals(uid)))
            .go();
      }
      await (db.delete(db.grupPatungan)..where((t) => t.id.equals(id))).go();
    });
  }

  // ── Anggota ───────────────────────────────────────────────────────────────
  Future<List<AnggotaPatunganData>> anggota(String grupUid) {
    return (db.select(db.anggotaPatungan)
          ..where((t) => t.grupUid.equals(grupUid))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  Future<int> tambahAnggota(String grupUid, String nama) async {
    if (nama.trim().isEmpty) {
      throw ArgumentError('Nama anggota tidak boleh kosong.');
    }
    return db.into(db.anggotaPatungan).insert(AnggotaPatunganCompanion.insert(
          uid: Value(_uid('agt_')),
          grupUid: grupUid,
          nama: nama.trim(),
          diubahPada: Value(_jam()),
        ));
  }

  Future<void> hapusAnggota(int id) async {
    await (db.delete(db.anggotaPatungan)..where((t) => t.id.equals(id))).go();
  }

  // ── Belanja ───────────────────────────────────────────────────────────────
  Future<List<BelanjaPatunganData>> belanja(String grupUid) {
    return (db.select(db.belanjaPatungan)
          ..where((t) => t.grupUid.equals(grupUid))
          ..orderBy([(t) => OrderingTerm.desc(t.tanggal)]))
        .get();
  }

  Future<List<BagianPatunganData>> bagianUntuk(String belanjaUid) {
    return (db.select(db.bagianPatungan)
          ..where((t) => t.belanjaUid.equals(belanjaUid)))
        .get();
  }

  /// Tambah belanja; bila [cara] = sama rata, bagian dibagi otomatis ke seluruh
  /// anggota grup (sisa pembulatan dibebankan berurutan, jumlah tetap pas).
  Future<int> tambahBelanja({
    required String grupUid,
    required String judul,
    required int totalSen,
    required String pembayar,
    DateTime? tanggal,
    CaraBagi cara = CaraBagi.samaRata,
    Map<String, int>? bagianKhusus,
    String? catatan,
  }) async {
    if (judul.trim().isEmpty) {
      throw ArgumentError('Judul belanja tidak boleh kosong.');
    }
    if (totalSen < 0) {
      throw ArgumentError('Total belanja tidak boleh negatif.');
    }
    final daftarAnggota = await anggota(grupUid);
    if (daftarAnggota.isEmpty) {
      throw ArgumentError('Tambahkan anggota grup dulu.');
    }
    if (!daftarAnggota.any((a) => a.nama == pembayar)) {
      throw ArgumentError('Pembayar harus salah satu anggota grup.');
    }

    Map<String, int> bagian;
    if (cara == CaraBagi.samaRata) {
      bagian = bagiSamaRata(totalSen, daftarAnggota.map((a) => a.nama).toList());
    } else {
      bagian = bagianKhusus ?? const {};
      if (bagian.isEmpty) {
        throw ArgumentError('Bagian khusus belum diisi.');
      }
      final beda = bagian.values.fold<int>(0, (a, b) => a + b) - totalSen;
      if (beda != 0) {
        throw ArgumentError('Jumlah bagian tidak sama dengan total '
            '(selisih ${beda < 0 ? '-' : '+'}${(beda.abs() / 100).round()} rupiah).');
      }
    }

    return db.transaction(() async {
      final uid = _uid('blj_');
      final id = await db
          .into(db.belanjaPatungan)
          .insert(BelanjaPatunganCompanion.insert(
            uid: Value(uid),
            grupUid: grupUid,
            judul: judul.trim(),
            totalSen: Value(totalSen),
            pembayar: Value(pembayar),
            tanggal: tanggal ?? _jam(),
            cara: Value(cara.kode),
            catatan: Value(catatan == null ? '' : catatan.trim()),
            diubahPada: Value(_jam()),
          ));
      for (final masuk in bagian.entries) {
        await db.into(db.bagianPatungan).insert(BagianPatunganCompanion.insert(
              uid: Value(_uid('bgn_')),
              belanjaUid: uid,
              anggota: Value(masuk.key),
              jumlahSen: Value(masuk.value),
              diubahPada: Value(_jam()),
            ));
      }
      return id;
    });
  }

  Future<void> hapusBelanja(int id) async {
    final baris =
        await (db.select(db.belanjaPatungan)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    if (baris == null) return;
    final uid = baris.uid ?? '';
    await db.transaction(() async {
      if (uid.isNotEmpty) {
        await (db.delete(db.bagianPatungan)..where((t) => t.belanjaUid.equals(uid)))
            .go();
      }
      await (db.delete(db.belanjaPatungan)..where((t) => t.id.equals(id))).go();
    });
  }

  // ── Hasil ─────────────────────────────────────────────────────────────────
  Future<HasilPatungan> hasil(int grupId) async {
    final grup =
        await (db.select(db.grupPatungan)..where((t) => t.id.equals(grupId)))
            .getSingleOrNull();
    if (grup == null) {
      throw ArgumentError('Grup tidak ditemukan.');
    }
    final uid = grup.uid ?? '';
    final daftarAnggota = uid.isEmpty ? <AnggotaPatunganData>[] : await anggota(uid);
    final daftarBelanja = uid.isEmpty ? <BelanjaPatunganData>[] : await belanja(uid);

    final bagian = <BagianPatungan>[];
    for (final b in daftarBelanja) {
      final bu = b.uid ?? '';
      if (bu.isEmpty) continue;
      for (final x in await bagianUntuk(bu)) {
        bagian.add(BagianPatungan(
          kunciBelanja: kunciBelanja(BelanjaPatungan(
            grupNama: grup.nama,
            judul: b.judul,
            totalSen: b.totalSen,
            pembayar: b.pembayar,
            tanggal: b.tanggal,
            cara: CaraBagi.dariKode(b.cara),
            catatan: b.catatan,
          )),
          anggota: x.anggota,
          jumlahSen: x.jumlahSen,
        ));
      }
    }

    return hitungPatungan(
      grup: GrupPatungan(
        nama: grup.nama,
        catatan: grup.catatan,
        kodeUndangan: grup.kodeUndangan,
        arsip: grup.arsip,
      ),
      anggota: daftarAnggota
          .map((a) => AnggotaPatungan(grupNama: grup.nama, nama: a.nama))
          .toList(),
      belanja: daftarBelanja
          .map((b) => BelanjaPatungan(
                grupNama: grup.nama,
                judul: b.judul,
                totalSen: b.totalSen,
                pembayar: b.pembayar,
                tanggal: b.tanggal,
                cara: CaraBagi.dariKode(b.cara),
                catatan: b.catatan,
              ))
          .toList(),
      bagian: bagian,
    );
  }
}
