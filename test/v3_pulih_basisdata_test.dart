/// Uji perbaikan galat "attempt to write a readonly database" (26 Sep 2026).
///
/// Yang dibuktikan berkas ini:
///
/// 1. **Galatnya nyata dan bisa dibuat ulang.** Koneksi SQLite biasa yang
///    berkasnya dipindah/diganti di luar aplikasi MENOLAK menulis dengan kode
///    `1032` (`SQLITE_READONLY_DBMOVED`) — persis yang muncul di HP pengguna.
/// 2. **Perbaikannya bekerja.** Dengan [ExecutorPulih], perintah tulis yang
///    sama BERHASIL: koneksi lama ditutup, koneksi baru dibuka, perintah
///    diulang — dan datanya benar-benar mendarat di berkas pada jalur aslinya
///    (bukan ke berkas yang sudah dipindahkan).
/// 3. **Tidak pernah mengaku berhasil.** Kalau berkasnya memang tidak bisa
///    ditulis, galatnya tetap diteruskan.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/database/executor_pulih.dart';
import 'package:sqlite3/sqlite3.dart' as sq;

/// Berkas basis data kecil dengan satu tabel — cukup untuk membuktikan tulis.
Future<void> _siapkanTabel(QueryExecutor eksekutor) async {
  await eksekutor.ensureOpen(_PenggunaUji());
  await eksekutor.runCustom(
    'CREATE TABLE IF NOT EXISTS catatan (id INTEGER PRIMARY KEY, isi TEXT)',
  );
}

/// [QueryExecutorUser] minimal untuk menguji executor tanpa seluruh skema app.
class _PenggunaUji implements QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

/// Pindahkan berkas basis data seperti kejadian nyata: berkas pada jalur yang
/// dipegang koneksi digantikan (Android memulihkan data, aplikasi pembersih,
/// atau berkas diganti aplikasi lain).
void _pindahkanBerkas(File berkas) {
  berkas.copySync('${berkas.path}.dipindah');
  berkas.deleteSync();
}

void main() {
  late Directory dir;
  late File berkas;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('uji-pulih-basisdata');
    berkas = File('${dir.path}/uji.sqlite');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('koneksi biasa: berkas dipindah → menulis GAGAL dengan kode 1032', () async {
    final QueryExecutor eksekutor = NativeDatabase(berkas);
    await _siapkanTabel(eksekutor);
    await eksekutor.runInsert(
      'INSERT INTO catatan (isi) VALUES (?)',
      <Object?>['sebelum'],
    );

    _pindahkanBerkas(berkas);

    Object? galat;
    try {
      await eksekutor.runInsert(
        'INSERT INTO catatan (isi) VALUES (?)',
        <Object?>['sesudah'],
      );
    } catch (e) {
      galat = e;
    }
    await eksekutor.close();

    expect(galat == null, isFalse, reason: 'koneksi lama seharusnya menolak menulis');
    expect(
      galatBerkasPindah(galat!),
      isTrue,
      reason: 'galat harus dikenali sebagai "berkas berpindah": $galat',
    );
    expect(
      '$galat',
      contains('readonly'),
      reason: 'pesan SQLite harus memuat "readonly" seperti di HP',
    );
  });

  test('ExecutorPulih: berkas dihapus → isi lama DISELAMATKAN, menulis berhasil', () async {
    jumlahPemulihanBasisData = 0;
    catatanPemulihanBasisData = null;
    final ExecutorPulih eksekutor = ExecutorPulih(
      () => NativeDatabase(berkas),
      jalur: berkas.path,
    );
    await _siapkanTabel(eksekutor);
    await eksekutor.runInsert(
      'INSERT INTO catatan (isi) VALUES (?)',
      <Object?>['sebelum'],
    );

    _pindahkanBerkas(berkas);
    expect(jumlahPemulihanBasisData, 0, reason: 'belum ada pemulihan sebelum gagal');

    // Inilah penekanan "Simpan ke kotak masuk" di HP: tanpa pemulihan otomatis,
    // baris ini melempar SqliteException(1032).
    await eksekutor.runInsert(
      'INSERT INTO catatan (isi) VALUES (?)',
      <Object?>['sesudah'],
    );

    expect(jumlahPemulihanBasisData, 1, reason: 'koneksi harus dibuka ulang sekali');
    expect(
      eksekutor.berkasPenyelamatanTerakhir == null,
      isFalse,
      reason: 'isi lama harus diselamatkan ke berkas pemulihan',
    );
    await eksekutor.close();

    // Bukti utama: berkas pada jalur ASLI sekarang berisi baris LAMA + BARU —
    // artinya data pengguna tidak hilang saat koneksi dipulihkan.
    final sq.Database cek = sq.sqlite3.open(berkas.path);
    try {
      final List<String> isi = cek
          .select('SELECT isi FROM catatan ORDER BY id')
          .map((sq.Row r) => r['isi'] as String)
          .toList();
      expect(isi, <String>['sebelum', 'sesudah']);
    } finally {
      cek.close();
    }
  });

  test('galat lain TIDAK dianggap berkas pindah (tidak menutupi masalah asli)', () {
    expect(galatBerkasPindah(StateError('bukan galat basis data')), isFalse);
    expect(galatBerkasPindah(Exception('database is locked')), isFalse);
    expect(
      galatBerkasPindah(
        sq.SqliteException(
          extendedResultCode: 1032,
          message: 'attempt to write a readonly database',
        ),
      ),
      isTrue,
    );
    expect(
      galatBerkasPindah(
        sq.SqliteException(extendedResultCode: 1, message: 'no such table: catatan'),
      ),
      isFalse,
    );
  });

  test('AppDatabase utuh: data lama SELAMAT setelah berkas dihapus di luar aplikasi', () async {
    jumlahPemulihanBasisData = 0;
    catatanPemulihanBasisData = null;
    final AppDatabase db = AppDatabase.forTesting(
      ExecutorPulih(() => NativeDatabase(berkas), jalur: berkas.path),
    );
    await db.customStatement('SELECT 1'); // memicu pembukaan + migrasi

    await db.into(db.kotakMasuk).insert(
          KotakMasukCompanion.insert(
            uid: const Value<String>('uji-pulih-1'),
            isi: const Value<String>('sebelum'),
            sumber: const Value<String>('uji'),
          ),
        );

    _pindahkanBerkas(berkas);

    await db.into(db.kotakMasuk).insert(
          KotakMasukCompanion.insert(
            uid: const Value<String>('uji-pulih-2'),
            isi: const Value<String>('sesudah'),
            sumber: const Value<String>('uji'),
          ),
        );

    expect(jumlahPemulihanBasisData, 1);
    expect(catatanPemulihanBasisData == null, isFalse);
    // Dua baris: yang lama diselamatkan, yang baru tersimpan — bukan satu baris
    // di basis data kosong.
    final List<KotakMasukData> baris = await db.select(db.kotakMasuk).get();
    expect(baris.map((KotakMasukData b) => b.isi).toList(), <String>['sebelum', 'sesudah']);
    await db.close();
  });
}
