/// SDD v19 Gelombang 2 — Log gejala terstruktur.
///
/// Aturan yang dijaga:
/// * `mulai` wajib; bila `selesai` diisi, wajib `selesai >= mulai`.
/// * `berat` (1–5) adalah PERSEPSI PENGGUNA. Di luar rentang **dijepit**
///   (bukan ditolak) supaya input pengguna tidak pernah hilang.
/// * Aplikasi tidak menilai apakah gejalanya serius — hanya mencatat.
///
/// Kaitan ke pemicu (obat, tidur, makanan, aktivitas, siklus) memakai tabel
/// `tautan` yang sudah ada — tidak ada tabel persimpangan baru.
library;

import 'dart:math';

import 'package:drift/drift.dart';

import '../database/database.dart';

class GalatGejala implements Exception {
  GalatGejala(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}

/// Sepuluh gejala yang paling sering dicatat (boleh diisi bebas).
const List<String> namaGejalaUmum = <String>[
  'sakit kepala',
  'pusing',
  'mual',
  'nyeri perut',
  'lemas',
  'batuk',
  'nyeri sendi',
  'sesak',
  'demam',
  'lain',
];

const List<String> lokasiTubuhGejala = <String>[
  'kepala',
  'perut',
  'punggung',
  'sendi',
  'dada',
  'tenggorokan',
  'lain',
];

class GejalaRepository {
  GejalaRepository(this._db);

  final AppDatabase _db;
  static final Random _acak = Random.secure();

  static String uidBaru() => List<int>.generate(16, (_) => _acak.nextInt(256))
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  Future<String> tambah({
    required String nama,
    required DateTime mulai,
    DateTime? selesai,
    int? berat,
    int? durasiMenit,
    String? lokasiTubuh,
    int? anggotaId,
    String? catatan,
  }) async {
    final String namaBersih = nama.trim();
    if (namaBersih.isEmpty) {
      throw GalatGejala('Nama gejalanya belum diisi.');
    }
    if (selesai != null && selesai.isBefore(mulai)) {
      throw GalatGejala('Waktu selesai tidak boleh lebih awal dari waktu mulai.');
    }
    final String uid = uidBaru();
    await _db.into(_db.gejala).insert(
          GejalaCompanion.insert(
            uid: Value(uid),
            nama: namaBersih,
            // Dijepit ke 1–5, bukan ditolak: catatan pengguna tidak boleh hilang.
            berat: Value(_jepitBerat(berat)),
            mulai: mulai,
            selesai: Value(selesai),
            durasiMenit: Value(
                durasiMenit ?? selesai?.difference(mulai).inMinutes),
            lokasiTubuh: Value(lokasiTubuh),
            anggotaId: Value(anggotaId),
            catatan: Value(catatan),
          ),
        );
    return uid;
  }

  static int? _jepitBerat(int? berat) {
    if (berat == null) return null;
    if (berat < 1) return 1;
    if (berat > 5) return 5;
    return berat;
  }

  /// Catatan gejala terbaru dulu.
  Future<List<GejalaData>> daftar({int? anggotaId, int batas = 200}) {
    final SimpleSelectStatement<$GejalaTable, GejalaData> q =
        _db.select(_db.gejala)
          ..orderBy(<OrderingTerm Function($GejalaTable)>[
            ($GejalaTable t) => OrderingTerm.desc(t.mulai),
          ])
          ..limit(batas);
    if (anggotaId != null) {
      q.where((t) => t.anggotaId.equals(anggotaId));
    }
    return q.get();
  }

  /// Yang belum ada waktu selesainya (masih berlangsung).
  Future<List<GejalaData>> sedangBerlangsung() => (_db.select(_db.gejala)
        ..where((t) => t.selesai.isNull())
        ..orderBy(<OrderingTerm Function($GejalaTable)>[
          ($GejalaTable t) => OrderingTerm.desc(t.mulai),
        ]))
      .get();

  /// Tandai sudah selesai (mis. saat pengguna ingat gejalanya berhenti).
  Future<void> tandaiSelesai(int id, DateTime selesai) async {
    final GejalaData? baris =
        await (_db.select(_db.gejala)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    if (baris == null) {
      throw GalatGejala('Catatan gejalanya tidak ditemukan.');
    }
    if (selesai.isBefore(baris.mulai)) {
      throw GalatGejala('Waktu selesai tidak boleh lebih awal dari waktu mulai.');
    }
    await (_db.update(_db.gejala)..where((t) => t.id.equals(id))).write(
      GejalaCompanion(
        selesai: Value(selesai),
        durasiMenit: Value(selesai.difference(baris.mulai).inMinutes),
        diubahPada: Value(DateTime.now()),
      ),
    );
  }

  Future<void> hapus(int id) async {
    await (_db.delete(_db.gejala)..where((t) => t.id.equals(id))).go();
  }

  /// Frekuensi tiap gejala — bahan mentah mesin pola
  /// ("dari 14 catatan sakit kepala, 11 hari kurang tidur").
  Future<List<FrekuensiGejala>> palingSering({int batas = 10}) async {
    final List<QueryRow> baris = await _db.customSelect(
      'SELECT nama, COUNT(*) AS jumlah, MAX(mulai) AS terakhir '
      'FROM gejala GROUP BY nama ORDER BY jumlah DESC, nama ASC LIMIT ?',
      variables: <Variable<Object>>[Variable<int>(batas)],
    ).get();
    return baris
        .map((QueryRow r) => FrekuensiGejala(
              nama: r.read<String>('nama'),
              jumlah: r.read<int>('jumlah'),
              terakhir: r.read<DateTime>('terakhir'),
            ))
        .toList();
  }
}

/// Jumlah catatan per gejala.
class FrekuensiGejala {
  const FrekuensiGejala({
    required this.nama,
    required this.jumlah,
    required this.terakhir,
  });

  final String nama;
  final int jumlah;
  final DateTime terakhir;
}
