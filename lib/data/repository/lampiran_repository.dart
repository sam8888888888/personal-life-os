/// Simpan / daftar / hapus lampiran catatan — FR-118.
///
/// Berkas disalin ke folder dokumen aplikasi (bukan cache) supaya tidak hilang
/// saat sistem membersihkan ruang. Baris basis data menyimpan jalur berkas di
/// HP ini; lampiran SENGAJA belum ikut sinkron antar HP (butuh penyimpanan
/// objek di server) dan itu ditulis apa adanya di layar.
library;

import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';

class LampiranGagal implements Exception {
  LampiranGagal(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}

class LampiranRepository {
  LampiranRepository(this._db, {this.folderInduk});

  final AppDatabase _db;

  /// Bisa disuntik saat uji supaya tidak butuh plugin path_provider.
  final Future<Directory> Function()? folderInduk;

  static final Random _acak = Random.secure();

  Future<Directory> folder() async {
    final sumber = folderInduk;
    final induk = sumber != null
        ? await sumber()
        : await getApplicationDocumentsDirectory();
    final dir = Directory('${induk.path}${Platform.pathSeparator}lampiran');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<LampiranData> simpan({
    required String indukTabel,
    required String indukUid,
    required String jenis,
    required String jalurSumber,
    String keterangan = '',
  }) async {
    final sumber = File(jalurSumber);
    if (!await sumber.exists()) {
      throw LampiranGagal('Berkasnya tidak ditemukan di HP ini.');
    }
    final dir = await folder();
    final nama = sumber.uri.pathSegments.isNotEmpty
        ? sumber.uri.pathSegments.last
        : 'lampiran';
    final tujuan = File(
        '${dir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_$nama');
    await sumber.copy(tujuan.path);
    final ukuran = await tujuan.length();
    final id = await _db.into(_db.lampiran).insert(LampiranCompanion.insert(
          uid: Value(_uidBaru()),
          indukTabel: indukTabel,
          indukUid: indukUid,
          jenis: jenis,
          berkas: tujuan.path,
          keterangan: Value(keterangan),
          ukuranByte: Value(ukuran),
        ));
    return (_db.select(_db.lampiran)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<List<LampiranData>> daftar(String indukTabel, String indukUid) {
    final q = _db.select(_db.lampiran)
      ..where((t) => t.indukTabel.equals(indukTabel) & t.indukUid.equals(indukUid))
      ..orderBy([(t) => OrderingTerm.desc(t.dibuatPada)]);
    return q.get();
  }

  Future<int> jumlah(String indukTabel, String indukUid) async {
    final q = _db.selectOnly(_db.lampiran)
      ..addColumns([_db.lampiran.id.count()])
      ..where(_db.lampiran.indukTabel.equals(indukTabel) &
          _db.lampiran.indukUid.equals(indukUid));
    final baris = await q.getSingle();
    return baris.read(_db.lampiran.id.count()) ?? 0;
  }

  Future<int> totalUkuranByte(String indukTabel, String indukUid) async {
    final semua = await daftar(indukTabel, indukUid);
    return semua.fold<int>(0, (a, b) => a + b.ukuranByte);
  }

  /// Hapus baris + berkasnya. Kalau berkasnya sudah tidak ada, tidak dianggap
  /// gagal — yang penting baris basis datanya bersih.
  Future<void> hapus(int id) async {
    final baris = await (_db.select(_db.lampiran)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (baris == null) return;
    final berkas = File(baris.berkas);
    if (await berkas.exists()) {
      try {
        await berkas.delete();
      } catch (_) {
        // Berkas terkunci sistem → baris tetap dihapus, berkas ditinggal.
      }
    }
    await (_db.delete(_db.lampiran)..where((t) => t.id.equals(id))).go();
  }

  Future<bool> berkasAda(LampiranData baris) => File(baris.berkas).exists();

  /// Dipakai layar: label jenis lampiran.
  static String labelJenis(String jenis) => switch (jenis) {
        'foto' => 'Foto',
        'suara' => 'Rekaman suara',
        _ => jenis,
      };

  static String ukuranRapi(int byte) {
    if (byte < 1024) return '$byte B';
    if (byte < 1024 * 1024) return '${(byte / 1024).toStringAsFixed(0)} KB';
    return '${(byte / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String _uidBaru() => List<int>.generate(16, (_) => _acak.nextInt(256))
      .map((x) => x.toRadixString(16).padLeft(2, '0'))
      .join();
}
