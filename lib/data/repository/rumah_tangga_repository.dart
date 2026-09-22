/// FR-43 — repositori Mode Rumah Tangga.
///
/// Tabel: `rumah_tangga`, `tagihan_bersama`, `bagian_rumah`.
/// Anggota TIDAK disimpan di tabel sendiri: nama anggota diambil dari daftar
/// anggota keluarga yang sudah ada (FR-56, tabel `anggota_keluarga`) atau
/// diketik langsung. Jadi orangnya satu sumber, tidak ada data kembar.
///
/// Perhitungan ada di `core/rumah/rumah_tangga.dart` (murni, bisa diuji).
library;

import 'dart:math' show Random;

import 'package:drift/drift.dart';

import '../../core/rumah/patungan.dart' show bagiSamaRata;
import '../../core/rumah/rumah_tangga.dart';
import '../database/database.dart';

class RumahTanggaRepository {
  RumahTanggaRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _jam;
  static final _acak = Random();

  String _uid(String awalan) =>
      '$awalan${_jam().microsecondsSinceEpoch.toRadixString(36)}'
      '${_acak.nextInt(1 << 20).toRadixString(36)}';

  // ── rumah ───────────────────────────────────────────────────────────────

  Future<List<RumahTanggaData>> semuaRumah({bool termasukArsip = false}) {
    final q = db.select(db.rumahTangga);
    if (!termasukArsip) q.where((t) => t.arsip.equals(false));
    q.orderBy([(t) => OrderingTerm.asc(t.nama)]);
    return q.get();
  }

  Stream<List<RumahTanggaData>> pantauRumah({bool termasukArsip = false}) {
    final q = db.select(db.rumahTangga);
    if (!termasukArsip) q.where((t) => t.arsip.equals(false));
    q.orderBy([(t) => OrderingTerm.asc(t.nama)]);
    return q.watch();
  }

  /// Kode undangan baru (tanpa akun, 6 karakter aman).
  String kodeBaru() => kodeUndanganRumah(_acak.nextInt(1 << 30));

  Future<int> tambahRumah({required String nama, String? catatan}) async {
    if (nama.trim().isEmpty) {
      throw ArgumentError('Nama rumah tangga tidak boleh kosong.');
    }
    return db.into(db.rumahTangga).insert(RumahTanggaCompanion.insert(
          uid: Value(_uid('rms_')),
          nama: nama.trim(),
          kodeUndangan: Value(kodeBaru()),
          catatan: Value(catatan == null ? '' : catatan.trim()),
          diubahPada: Value(_jam()),
        ));
  }

  Future<void> ubahRumah(int id,
      {String? nama, String? catatan, bool? arsip}) async {
    await (db.update(db.rumahTangga)..where((t) => t.id.equals(id)))
        .write(RumahTanggaCompanion(
      nama: nama == null ? const Value.absent() : Value(nama.trim()),
      catatan: catatan == null ? const Value.absent() : Value(catatan.trim()),
      arsip: arsip == null ? const Value.absent() : Value(arsip),
      diubahPada: Value(_jam()),
    ));
  }

  /// Cari rumah lewat kode undangan (cara "gabung tanpa akun").
  Future<RumahTanggaData?> cariKode(String kode) {
    final k = kode.trim().toUpperCase();
    if (!kodeUndanganSah(k)) return Future.value(null);
    return (db.select(db.rumahTangga)..where((t) => t.kodeUndangan.equals(k)))
        .getSingleOrNull();
  }

  Future<void> hapusRumah(int id) async {
    final rumah =
        await (db.select(db.rumahTangga)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    final uid = rumah?.uid;
    await db.transaction(() async {
      if (uid != null) {
        final daftar = await (db.select(db.tagihanRumahBersama)
              ..where((t) => t.rumahUid.equals(uid)))
            .get();
        for (final t in daftar) {
          final tu = t.uid;
          if (tu != null) {
            await (db.delete(db.bagianTagihanRumah)
                  ..where((b) => b.tagihanUid.equals(tu)))
                .go();
          }
        }
        await (db.delete(db.tagihanRumahBersama)
              ..where((t) => t.rumahUid.equals(uid)))
            .go();
      }
      await (db.delete(db.rumahTangga)..where((t) => t.id.equals(id))).go();
    });
  }

  // ── tagihan bersama ─────────────────────────────────────────────────────

  Future<List<TagihanRumahBersamaData>> tagihan(String rumahUid) {
    return (db.select(db.tagihanRumahBersama)
          ..where((t) => t.rumahUid.equals(rumahUid) & t.arsip.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.jatuhTempo)]))
        .get();
  }

  /// Tambah tagihan bersama sekaligus bagiannya.
  ///
  /// [anggota] = daftar nama penanggung bagian. Bila [bagianKhusus] kosong,
  /// pembagian memakai BAGI RATA milik FR-47 (jumlah bagian selalu pas).
  Future<int> tambahTagihan({
    required String rumahUid,
    required String judul,
    required int totalSen,
    required DateTime jatuhTempo,
    List<String> anggota = const [],
    String? penanggung,
    String? catatan,
    Map<String, int>? bagianKhusus,
  }) async {
    if (judul.trim().isEmpty) {
      throw ArgumentError('Judul tagihan bersama tidak boleh kosong.');
    }
    if (totalSen < 0) throw ArgumentError('Total tagihan tidak boleh negatif.');
    final uid = _uid('tgb_');
    final nama = [
      for (final a in anggota)
        if (a.trim().isNotEmpty) a.trim(),
    ];
    final bagian = (bagianKhusus != null && bagianKhusus.isNotEmpty)
        ? bagianKhusus
        : bagiSamaRata(totalSen, nama);
    return db.transaction(() async {
      final id = await db.into(db.tagihanRumahBersama).insert(
            TagihanRumahBersamaCompanion.insert(
              uid: Value(uid),
              rumahUid: rumahUid,
              judul: judul.trim(),
              totalSen: Value(totalSen),
              jatuhTempo: jatuhTempo,
              penanggung: Value(penanggung == null ? '' : penanggung.trim()),
              catatan: Value(catatan == null ? '' : catatan.trim()),
              diubahPada: Value(_jam()),
            ),
          );
      for (final masuk in bagian.entries) {
        await db.into(db.bagianTagihanRumah).insert(BagianTagihanRumahCompanion.insert(
              uid: Value(_uid('bgr_')),
              tagihanUid: uid,
              anggota: masuk.key,
              jumlahSen: Value(masuk.value),
              diubahPada: Value(_jam()),
            ));
      }
      return id;
    });
  }

  Future<void> hapusTagihan(int id) async {
    final t =
        await (db.select(db.tagihanRumahBersama)..where((x) => x.id.equals(id)))
            .getSingleOrNull();
    await db.transaction(() async {
      final tu = t?.uid;
      if (tu != null) {
        await (db.delete(db.bagianTagihanRumah)..where((b) => b.tagihanUid.equals(tu)))
            .go();
      }
      await (db.delete(db.tagihanRumahBersama)..where((x) => x.id.equals(id))).go();
    });
  }

  Future<List<BagianTagihanRumahData>> bagian(String tagihanUid) {
    return (db.select(db.bagianTagihanRumah)
          ..where((t) => t.tagihanUid.equals(tagihanUid))
          ..orderBy([(t) => OrderingTerm.asc(t.anggota)]))
        .get();
  }

  /// Catat pembayaran satu anggota (menjadi riwayat "siapa bayar apa").
  Future<void> catatBayar({
    required String tagihanUid,
    required String anggota,
    required int jumlahSen,
    DateTime? waktu,
  }) async {
    if (jumlahSen == 0) {
      throw ArgumentError('Jumlah pembayaran tidak boleh nol.');
    }
    final baris = await (db.select(db.bagianTagihanRumah)
          ..where((t) =>
              t.tagihanUid.equals(tagihanUid) & t.anggota.equals(anggota.trim())))
        .getSingleOrNull();
    if (baris == null) {
      throw ArgumentError('Bagian untuk $anggota belum ada di tagihan ini.');
    }
    final baru = baris.dibayarSen + jumlahSen;
    await (db.update(db.bagianTagihanRumah)..where((t) => t.id.equals(baris.id)))
        .write(BagianTagihanRumahCompanion(
      dibayarSen: Value(baru < 0 ? 0 : baru),
      waktuBayar: Value(waktu ?? _jam()),
      diubahPada: Value(_jam()),
    ));
  }

  /// Setel (atau buat) bagian satu anggota.
  Future<void> setBagian({
    required String tagihanUid,
    required String anggota,
    required int jumlahSen,
  }) async {
    final nama = anggota.trim();
    if (nama.isEmpty) throw ArgumentError('Nama anggota tidak boleh kosong.');
    final baris = await (db.select(db.bagianTagihanRumah)
          ..where((t) => t.tagihanUid.equals(tagihanUid) & t.anggota.equals(nama)))
        .getSingleOrNull();
    if (baris == null) {
      await db.into(db.bagianTagihanRumah).insert(BagianTagihanRumahCompanion.insert(
            uid: Value(_uid('bgr_')),
            tagihanUid: tagihanUid,
            anggota: nama,
            jumlahSen: Value(jumlahSen),
            diubahPada: Value(_jam()),
          ));
      return;
    }
    await (db.update(db.bagianTagihanRumah)..where((t) => t.id.equals(baris.id)))
        .write(BagianTagihanRumahCompanion(
      jumlahSen: Value(jumlahSen),
      diubahPada: Value(_jam()),
    ));
  }

  // ── ringkasan siap pakai layar ──────────────────────────────────────────

  /// Susun hasil FR-43 dari isi basis data.
  ///
  /// [namaAnggotaTambahan] dipakai untuk anggota yang belum punya bagian
  /// (mis. dari daftar anggota keluarga FR-56) supaya ia tetap ikut terhitung.
  Future<HasilRumahTangga> hasil(
    int rumahId, {
    List<String> namaAnggotaTambahan = const [],
  }) async {
    final rumah =
        await (db.select(db.rumahTangga)..where((t) => t.id.equals(rumahId)))
            .getSingleOrNull();
    if (rumah == null) throw ArgumentError('Rumah tangga tidak ditemukan.');
    final uid = rumah.uid ?? '';
    final daftar = await tagihan(uid);
    final modelTagihan = <TagihanBersama>[];
    final semuaBagian = <BagianRumah>[];
    final nama = <String>{...namaAnggotaTambahan.map((e) => e.trim())};

    for (final t in daftar) {
      final model = TagihanBersama(
        rumahNama: rumah.nama,
        judul: t.judul,
        totalSen: t.totalSen,
        jatuhTempo: t.jatuhTempo,
        penanggung: t.penanggung.trim().isEmpty ? null : t.penanggung,
        catatan: t.catatan,
      );
      modelTagihan.add(model);
      for (final b in await bagian(t.uid ?? '')) {
        nama.add(b.anggota.trim());
        semuaBagian.add(BagianRumah(
          kunciTagihan: kunciTagihanBersama(model),
          anggota: b.anggota,
          jumlahSen: b.jumlahSen,
          dibayarSen: b.dibayarSen,
          waktuBayar: b.waktuBayar,
          catatan: b.catatan,
        ));
      }
    }
    final daftarNama = nama.where((n) => n.isNotEmpty).toList()..sort();
    return hitungRumahTangga(
      rumahNama: rumah.nama,
      anggota: [for (final n in daftarNama) AnggotaRumah(nama: n)],
      tagihan: modelTagihan,
      bagian: semuaBagian,
      sekarang: _jam(),
    );
  }
}
