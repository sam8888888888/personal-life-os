/// SDD v19 Gelombang 3 — Orang (CRM pribadi).
///
/// Untuk manusia di luar keluarga inti: dokter, guru anak, tetangga, atasan,
/// montir, pemilik kontrakan.
///
/// Dua aturan etika data yang dijaga di lapisan ini (SDD §4.10):
///
/// 1. `terakhirDihubungi` **hanya** diisi pengguna. Tidak ada pelacakan
///    otomatis dari aktivitas lain.
/// 2. Fitur "sudah lama tidak menghubungi" **wajib opt-in**. Karena itu
///    [sudahLamaTidakDihubungi] mengembalikan daftar kosong kecuali pemanggil
///    secara sadar menyatakan izinnya (`izin: true`). Memantau hubungan sosial
///    orang lain secara diam-diam bertentangan dengan DNA produk ini.
///
/// Satu lagi: satu anggota keluarga hanya boleh punya SATU baris `orang`.
library;

import 'dart:math';

import 'package:drift/drift.dart';

import '../database/database.dart';

/// Galat aturan orang (pesannya ditujukan untuk pengguna).
class GalatOrang implements Exception {
  GalatOrang(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}

/// Delapan jenis hubungan yang dikenal. Di luar ini → 'lain'.
const List<String> hubunganOrang = <String>[
  'keluarga',
  'teman',
  'rekan',
  'dokter',
  'guru',
  'vendor',
  'tetangga',
  'lain',
];

class OrangRepository {
  OrangRepository(this._db);

  final AppDatabase _db;
  static final Random _acak = Random.secure();

  static String uidBaru() => List<int>.generate(16, (_) => _acak.nextInt(256))
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  /// Pengenal stabil lintas HP (pola id_anggota / id_dokumen).
  static String idStabil() => 'OR-${uidBaru().substring(0, 10)}';

  Future<String> tambah({
    required String nama,
    String hubungan = 'lain',
    String? peran,
    String? telepon,
    String? email,
    DateTime? ulangTahun,
    int? anggotaId,
    String? catatan,
  }) async {
    final String namaBersih = nama.trim();
    if (namaBersih.isEmpty) {
      throw GalatOrang('Namanya belum diisi.');
    }
    if (namaBersih.length > 120) {
      throw GalatOrang('Nama terlalu panjang (maksimal 120 huruf).');
    }
    if (anggotaId != null) {
      final bool sudahDipakai = await anggotaSudahPunyaOrang(anggotaId);
      if (sudahDipakai) {
        throw GalatOrang(
            'Anggota keluarga ini sudah punya satu catatan orang. Buka yang ada, '
            'jangan buat dua.');
      }
    }
    final String uid = uidBaru();
    await _db.into(_db.orang).insert(
          OrangCompanion.insert(
            uid: Value(uid),
            idOrang: idStabil(),
            nama: namaBersih,
            hubungan: Value(
                hubunganOrang.contains(hubungan) ? hubungan : 'lain'),
            peran: Value(peran),
            telepon: Value(telepon),
            email: Value(email),
            ulangTahun: Value(ulangTahun),
            anggotaId: Value(anggotaId),
            catatan: Value(catatan),
          ),
        );
    return uid;
  }

  /// Apakah anggota keluarga ini sudah terhubung ke satu baris `orang`.
  Future<bool> anggotaSudahPunyaOrang(int anggotaId) async {
    final QueryRow? r = await _db.customSelect(
      'SELECT 1 AS ada FROM orang WHERE anggota_id = ? LIMIT 1',
      variables: <Variable<Object>>[Variable<int>(anggotaId)],
    ).getSingleOrNull();
    return r != null;
  }

  Future<OrangData?> cariUid(String uid) => (_db.select(_db.orang)
        ..where((t) => t.uid.equals(uid))
        ..limit(1))
      .getSingleOrNull();

  Future<OrangData?> cariId(int id) => (_db.select(_db.orang)
        ..where((t) => t.id.equals(id))
        ..limit(1))
      .getSingleOrNull();

  /// Daftar orang: belum diarsipkan, diurutkan menurut nama.
  Future<List<OrangData>> daftar({
    String? hubungan,
    String? cari,
    bool termasukArsip = false,
    int batas = 300,
  }) {
    final SimpleSelectStatement<$OrangTable, OrangData> q =
        _db.select(_db.orang)
          ..orderBy(<OrderingTerm Function($OrangTable)>[
            ($OrangTable t) => OrderingTerm.asc(t.nama),
          ])
          ..limit(batas);
    if (!termasukArsip) {
      q.where((t) => t.arsip.equals(false));
    }
    if (hubungan != null && hubunganOrang.contains(hubungan)) {
      q.where((t) => t.hubungan.equals(hubungan));
    }
    final String kata = (cari ?? '').trim().toLowerCase();
    if (kata.isNotEmpty) {
      q.where((t) => t.nama.lower().contains(kata));
    }
    return q.get();
  }

  /// Jumlah orang per hubungan — untuk ringkasan di layar.
  Future<Map<String, int>> jumlahPerHubungan() async {
    final List<QueryRow> baris = await _db.customSelect(
      'SELECT hubungan, COUNT(*) AS jumlah FROM orang WHERE arsip = 0 '
      'GROUP BY hubungan ORDER BY jumlah DESC',
    ).get();
    return <String, int>{
      for (final QueryRow r in baris)
        r.read<String>('hubungan'): r.read<int>('jumlah'),
    };
  }

  Future<void> ubah(int id, OrangCompanion isi) async {
    await (_db.update(_db.orang)..where((t) => t.id.equals(id)))
        .write(isi.copyWith(diubahPada: Value(DateTime.now())));
  }

  /// Catat "terakhir dihubungi" — **hanya** dari aksi pengguna.
  Future<void> tandaiDihubungi(int id, [DateTime? kapan]) async {
    await (_db.update(_db.orang)..where((t) => t.id.equals(id))).write(
      OrangCompanion(
        terakhirDihubungi: Value(kapan ?? DateTime.now()),
        diubahPada: Value(DateTime.now()),
      ),
    );
  }

  Future<void> arsipkan(int id, {bool arsip = true}) async {
    await (_db.update(_db.orang)..where((t) => t.id.equals(id)))
        .write(OrangCompanion(
      arsip: Value(arsip),
      diubahPada: Value(DateTime.now()),
    ));
  }

  Future<void> hapus(int id) async {
    await (_db.delete(_db.orang)..where((t) => t.id.equals(id))).go();
  }

  /// Ulang tahun dalam [hariKe] hari ke depan (boleh diingatkan).
  Future<List<OrangData>> ulangTahunDekat({int hariKe = 30}) async {
    final DateTime kini = DateTime.now();
    final List<OrangData> semua = await (_db.select(_db.orang)
          ..where((t) => t.arsip.equals(false) & t.ulangTahun.isNotNull()))
        .get();
    final List<OrangData> hasil = <OrangData>[];
    for (final OrangData o in semua) {
      final DateTime ultah = o.ulangTahun!;
      DateTime tahunIni = DateTime(kini.year, ultah.month, ultah.day);
      if (tahunIni.isBefore(DateTime(kini.year, kini.month, kini.day))) {
        tahunIni = DateTime(kini.year + 1, ultah.month, ultah.day);
      }
      final int selisih = tahunIni.difference(DateTime(kini.year, kini.month, kini.day)).inDays;
      if (selisih <= hariKe) hasil.add(o);
    }
    hasil.sort((OrangData a, OrangData b) {
      final int sa = _sisaHari(a, kini);
      final int sb = _sisaHari(b, kini);
      return sa.compareTo(sb);
    });
    return hasil;
  }

  static int _sisaHari(OrangData o, DateTime kini) {
    final DateTime ultah = o.ulangTahun!;
    DateTime tahunIni = DateTime(kini.year, ultah.month, ultah.day);
    if (tahunIni.isBefore(DateTime(kini.year, kini.month, kini.day))) {
      tahunIni = DateTime(kini.year + 1, ultah.month, ultah.day);
    }
    return tahunIni.difference(DateTime(kini.year, kini.month, kini.day)).inDays;
  }

  /// Orang yang lama tidak dihubungi — **opt-in**.
  ///
  /// Mengembalikan daftar KOSONG bila [izin] bukan `true`, sesuai aturan
  /// etika: aplikasi tidak memantau hubungan sosial siapa pun secara diam-diam.
  Future<List<OrangData>> sudahLamaTidakDihubungi({
    int bulan = 6,
    bool izin = false,
  }) async {
    if (!izin) return const <OrangData>[];
    if (bulan < 1) throw GalatOrang('Rentang bulannya minimal 1.');
    final DateTime kini = DateTime.now();
    final DateTime ambang = DateTime(kini.year, kini.month - bulan, kini.day);
    final List<OrangData> semua = await (_db.select(_db.orang)
          ..where((t) => t.arsip.equals(false)))
        .get();
    final List<OrangData> hasil = <OrangData>[];
    for (final OrangData o in semua) {
      final DateTime? terakhir = o.terakhirDihubungi;
      if (terakhir == null || terakhir.isBefore(ambang)) {
        hasil.add(o);
      }
    }
    return hasil;
  }
}
