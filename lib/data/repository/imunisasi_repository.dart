/// SDD v19 Gelombang 2 — Register imunisasi (REKAMAN, bukan janji).
///
/// Bedanya dengan `janji_kesehatan` (jenis 'vaksin'): tabel itu mencatat
/// rencana, tabel ini mencatat apa yang SUDAH diberikan — sehingga pertanyaan
/// *"kapan anak saya vaksin campak dosis kedua?"* punya jawaban.
///
/// Aturan yang dijaga:
/// * `anggotaId` **wajib** — imunisasi selalu milik seseorang.
/// * Kombinasi (anggota, vaksin, dosis) **unik** — menolak pencatatan ganda.
/// * `berikutnyaPada` **tidak pernah** dihitung aplikasi: jadwal imunisasi
///   adalah keputusan klinis, aplikasi hanya mengingatkan tanggal yang diisi
///   manusia.
library;

import 'dart:math';

import 'package:drift/drift.dart';

import '../database/database.dart';

class GalatImunisasi implements Exception {
  GalatImunisasi(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}

/// Vaksin dasar yang lazim (boleh diisi bebas di luar daftar ini).
const List<String> vaksinUmum = <String>[
  'BCG',
  'Hepatitis B',
  'Polio',
  'DPT',
  'Hib',
  'Campak',
  'Rubella',
  'Tifoid',
  'Influenza',
  'lain',
];

class ImunisasiRepository {
  ImunisasiRepository(this._db);

  final AppDatabase _db;
  static final Random _acak = Random.secure();

  static String uidBaru() => List<int>.generate(16, (_) => _acak.nextInt(256))
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  Future<String> tambah({
    required int anggotaId,
    required String namaVaksin,
    required DateTime tanggal,
    int dosisKe = 1,
    String? nomorBatch,
    String? tempat,
    String? pemberi,
    String? reaksi,
    DateTime? berikutnyaPada,
    String? catatan,
  }) async {
    final String vaksin = namaVaksin.trim();
    if (vaksin.isEmpty) {
      throw GalatImunisasi('Nama vaksinnya belum diisi.');
    }
    if (dosisKe < 1) {
      throw GalatImunisasi('Dosis ke berapa minimal 1.');
    }
    final bool sudahAda = await _sudahTercatat(anggotaId, vaksin, dosisKe);
    if (sudahAda) {
      throw GalatImunisasi(
          'Vaksin $vaksin dosis $dosisKe sudah tercatat untuk anggota ini.');
    }
    final String uid = uidBaru();
    await _db.into(_db.imunisasi).insert(
          ImunisasiCompanion.insert(
            uid: Value(uid),
            anggotaId: anggotaId,
            namaVaksin: vaksin,
            dosisKe: Value(dosisKe),
            tanggal: tanggal,
            nomorBatch: Value(nomorBatch),
            tempat: Value(tempat),
            pemberi: Value(pemberi),
            reaksi: Value(reaksi),
            berikutnyaPada: Value(berikutnyaPada),
            catatan: Value(catatan),
          ),
        );
    return uid;
  }

  Future<bool> _sudahTercatat(int anggotaId, String vaksin, int dosisKe) async {
    final QueryRow? r = await _db.customSelect(
      'SELECT 1 AS ada FROM imunisasi '
      'WHERE anggota_id = ? AND nama_vaksin = ? AND dosis_ke = ? LIMIT 1',
      variables: <Variable<Object>>[
        Variable<int>(anggotaId),
        Variable<String>(vaksin),
        Variable<int>(dosisKe),
      ],
    ).getSingleOrNull();
    return r != null;
  }

  /// Riwayat imunisasi satu anggota, terbaru dulu.
  Future<List<ImunisasiData>> riwayat(int anggotaId, {int batas = 100}) =>
      (_db.select(_db.imunisasi)
            ..where((t) => t.anggotaId.equals(anggotaId))
            ..orderBy(<OrderingTerm Function($ImunisasiTable)>[
              ($ImunisasiTable t) => OrderingTerm.desc(t.tanggal),
            ])
            ..limit(batas))
          .get();

  /// Dosis berikutnya yang sudah diisi manusia dan jatuh pada/lewat hari ini.
  Future<List<ImunisasiData>> jatuhTempo({DateTime? pada}) async {
    final DateTime acuan = pada ?? DateTime.now();
    return (_db.select(_db.imunisasi)
          ..where((t) =>
              t.berikutnyaPada.isNotNull() &
              t.berikutnyaPada.isSmallerOrEqualValue(acuan))
          ..orderBy(<OrderingTerm Function($ImunisasiTable)>[
            ($ImunisasiTable t) => OrderingTerm.asc(t.berikutnyaPada),
          ]))
        .get();
  }

  /// Dosis berikutnya yang akan datang (untuk pengingat).
  Future<List<ImunisasiData>> akanDatang({DateTime? sejak, int batas = 50}) {
    final DateTime acuan = sejak ?? DateTime.now();
    return (_db.select(_db.imunisasi)
          ..where((t) =>
              t.berikutnyaPada.isNotNull() &
              t.berikutnyaPada.isBiggerOrEqualValue(acuan))
          ..orderBy(<OrderingTerm Function($ImunisasiTable)>[
            ($ImunisasiTable t) => OrderingTerm.asc(t.berikutnyaPada),
          ])
          ..limit(batas))
        .get();
  }

  /// Ubah catatan (mis. tanggal perkiraan berikutnya berubah setelah kontrol).
  Future<void> ubah(int id, ImunisasiCompanion isi) async {
    await (_db.update(_db.imunisasi)..where((t) => t.id.equals(id)))
        .write(isi.copyWith(diubahPada: Value(DateTime.now())));
  }

  Future<void> hapus(int id) async {
    await (_db.delete(_db.imunisasi)..where((t) => t.id.equals(id))).go();
  }

  /// Ringkas per anggota: jumlah dosis tercatat + dosis berikutnya terdekat.
  Future<List<RingkasImunisasi>> ringkasPerAnggota() async {
    final List<QueryRow> baris = await _db.customSelect(
      'SELECT anggota_id AS anggota_id, COUNT(*) AS jumlah, '
      'MIN(CASE WHEN berikutnya_pada IS NOT NULL AND berikutnya_pada >= ? '
      'THEN berikutnya_pada END) AS berikut '
      'FROM imunisasi GROUP BY anggota_id ORDER BY anggota_id',
      variables: <Variable<Object>>[
        Variable<int>(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      ],
    ).get();
    return baris
        .map((QueryRow r) => RingkasImunisasi(
              anggotaId: r.read<int>('anggota_id'),
              jumlah: r.read<int>('jumlah'),
              berikutnyaPada: r.readNullable<DateTime>('berikut'),
            ))
        .toList();
  }
}

/// Ringkasan imunisasi per anggota keluarga.
class RingkasImunisasi {
  const RingkasImunisasi({
    required this.anggotaId,
    required this.jumlah,
    required this.berikutnyaPada,
  });

  final int anggotaId;
  final int jumlah;
  final DateTime? berikutnyaPada;
}
