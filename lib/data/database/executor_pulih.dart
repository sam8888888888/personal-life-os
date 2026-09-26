/// Penyembuh koneksi basis data — temuan pengguna 26 Sep 2026.
///
/// **Gejala nyata di HP:** menekan *Simpan ke kotak masuk* memunculkan
/// `SqliteException(1032): attempt to write a readonly database`, lengkap
/// dengan perintah SQL mentahnya. Setelah itu SEMUA penyimpanan gagal sampai
/// aplikasi ditutup paksa.
///
/// **Artinya apa:** kode 1032 adalah `SQLITE_READONLY_DBMOVED` — berkas basis
/// data sudah berpindah atau digantikan di luar aplikasi (mis. pemulihan data
/// oleh Android, aplikasi pembersih, atau berkas diganti saat koneksi masih
/// terbuka). SQLite menandai koneksi itu **tidak sah selamanya**: menulis
/// lewat koneksi lama bukan hanya gagal, tapi bisa berakhir di berkas yang
/// sudah tidak ada (data hilang tanpa pesan).
///
/// **Kenapa menetap:** aplikasi ini memakai satu koneksi panjang (dibuka sekali
/// saat aplikasi dijalankan). SQLite sendiri menyarankan obatnya: tutup
/// koneksinya, buka koneksi baru. Tanpa penanganan, obat itu hanya terjadi saat
/// proses aplikasi mati — itulah sebabnya masalah ini menetap "sampai aplikasi
/// ditutup".
///
/// **Yang dikerjakan berkas ini:** lapisan tipis di atas executor drift. Bila
/// sebuah perintah gagal karena berkasnya berpindah, koneksi lama ditutup,
/// koneksi baru dibuat dari jalur + kunci yang sama, lalu perintah itu
/// dijalankan **ulang sekali**. Kalau masih gagal, galatnya diteruskan apa
/// adanya — tidak pernah mengaku berhasil.
///
/// Perintah di dalam transaksi sengaja TIDAK diulang otomatis: mengulang satu
/// perintah di tengah transaksi bisa menghasilkan setengah data. Transaksi
/// tetap boleh dibuat lewat [beginTransaction] pada koneksi yang sehat.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../core/notifikasi/jejak.dart';

/// Kode galat SQLite yang berarti "berkasnya tidak bisa ditulis karena
/// berpindah / hilang / terkunci" — bukan karena datanya salah.
///
/// 8 = READONLY · 264 = READONLY_RECOVERY · 520 = READONLY_CANTLOCK ·
/// 776 = READONLY_ROLLBACK · 1032 = READONLY_DBMOVED · 1288 = READONLY_CANTINIT ·
/// 1544 = READONLY_DIRECTORY.
const Set<int> kodeBerkasPindah = <int>{8, 264, 520, 776, 1032, 1288, 1544};

/// Berapa kali koneksi sudah disembuhkan pada proses aplikasi ini.
///
/// Dipakai layar Pengaturan / laporan untuk berkata apa adanya — bukan untuk
/// disembunyikan.
int jumlahPemulihanBasisData = 0;

/// Catatan terakhir saat koneksi disembuhkan (siap tampil ke pengguna).
String? catatanPemulihanBasisData;

/// Apakah [galat] berarti berkas basis datanya berpindah?
///
/// Diperiksa dari kode SQLite lebih dulu. Kalau galat datang dari pekerja
/// latar (isolate drift), kodenya bisa terbungkus sehingga yang tersisa cuma
/// teksnya — karena itu ada pemeriksaan teks sebagai jalur kedua, terbatas pada
/// penanda yang khas (bukan sembarang kata "error").
bool galatBerkasPindah(Object galat) {
  if (galat is sqlite.SqliteException &&
      kodeBerkasPindah.contains(galat.extendedResultCode)) {
    return true;
  }
  final String teks = galat.toString().toLowerCase();
  return teks.contains('readonly database') ||
      teks.contains('read-only database') ||
      teks.contains('sqlite_readonly') ||
      teks.contains('dbmoved') ||
      teks.contains('(1032)');
}

/// Executor drift yang membuka ulang koneksinya sendiri bila berkasnya
/// berpindah. Lihat penjelasan panjang di atas berkas ini.
///
/// Sebelum membuka ulang, isi koneksi lama **diselamatkan lebih dulu** lewat
/// `VACUUM INTO`: kalau berkas di jalur aslinya sudah hilang, membuka ulang
/// begitu saja akan membuat basis data kosong — persis yang tidak boleh terjadi
/// pada data keluarga. Isi lama ditulis ke berkas pemulihan, lalu (bila berkas
/// aslinya memang hilang) dipasang kembali ke jalur aslinya.
class ExecutorPulih implements QueryExecutor {
  /// [_buat] harus membuat executor BARU setiap kali dipanggil — itulah yang
  /// dipakai saat menyembuhkan koneksi. [jalur] adalah jalur berkas basis data
  /// (dipakai untuk menyelamatkan isi).
  ExecutorPulih(this._buat, {this.jalur}) : _dalam = _buat();

  final QueryExecutor Function() _buat;

  /// Jalur berkas basis data; `null` = penyelamatan isi tidak dijalankan.
  final String? jalur;

  QueryExecutor _dalam;
  QueryExecutorUser? _pengguna;
  Future<void>? _sedangMemulihkan;

  /// Berkas tempat isi lama diselamatkan pada pemulihan terakhir (siap tampil).
  String? berkasPenyelamatanTerakhir;

  @override
  SqlDialect get dialect => _dalam.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) {
    _pengguna = user;
    return _dalam.ensureOpen(user);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) =>
      _jalankan((QueryExecutor e) => e.runSelect(statement, args));

  @override
  Future<int> runInsert(String statement, List<Object?> args) =>
      _jalankan((QueryExecutor e) => e.runInsert(statement, args));

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      _jalankan((QueryExecutor e) => e.runUpdate(statement, args));

  @override
  Future<int> runDelete(String statement, List<Object?> args) =>
      _jalankan((QueryExecutor e) => e.runDelete(statement, args));

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      _jalankan((QueryExecutor e) => e.runCustom(statement, args));

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      _jalankan((QueryExecutor e) => e.runBatched(statements));

  /// Transaksi memakai koneksi yang sedang terbuka apa adanya — sengaja tidak
  /// ada pengulangan otomatis di dalam transaksi (lihat catatan di atas berkas).
  @override
  TransactionExecutor beginTransaction() => _dalam.beginTransaction();

  @override
  QueryExecutor beginExclusive() => _dalam.beginExclusive();

  @override
  Future<void> close() => _dalam.close();

  Future<T> _jalankan<T>(Future<T> Function(QueryExecutor) aksi) async {
    try {
      return await aksi(_dalam);
    } catch (galat, jejak) {
      if (!galatBerkasPindah(galat)) rethrow;
      await _pulihkan(galat, jejak);
      return aksi(_dalam);
    }
  }

  Future<void> _pulihkan(Object galat, StackTrace jejak) {
    // Beberapa permintaan bisa gagal bersamaan; cukup satu yang membuka ulang.
    return _sedangMemulihkan ??= _lakukanPemulihan(galat).whenComplete(() {
      _sedangMemulihkan = null;
    });
  }

  Future<void> _lakukanPemulihan(Object galat) async {
    catatGalatTertelan('basisdata.berkasPindah', galat);
    final QueryExecutor lama = _dalam;
    // Selamatkan isi koneksi lama SEBELUM koneksi baru dibuat.
    await _selamatkanIsiLama(lama);
    final QueryExecutor baru = _buat();
    _dalam = baru;
    try {
      if (_pengguna != null) await baru.ensureOpen(_pengguna!);
    } catch (e) {
      catatGalatTertelan('basisdata.bukaUlangGagal', e);
      rethrow;
    }
    try {
      await lama.close();
    } catch (e) {
      catatGalatTertelan('basisdata.tutupKoneksiLama', e);
    }
    jumlahPemulihanBasisData++;
    catatanPemulihanBasisData ??=
        'Penyimpanan dipulihkan otomatis (berkas basis data sempat berpindah). '
        'Data yang sudah ada tidak hilang.';
  }

  /// Tulis isi koneksi lama ke berkas pemulihan lewat `VACUUM INTO`.
  ///
  /// Dua keadaan yang dibedakan dengan sengaja:
  ///
  /// * **Berkas di jalur aslinya hilang/kosong** → isi lama dipasang kembali ke
  ///   jalur aslinya. Kalau langkah ini gagal, galat diteruskan (lebih baik
  ///   gagal menyimpan daripada diam-diam membuat basis data kosong).
  /// * **Berkas di jalur aslinya ada (diganti pihak lain)** → isi lama tetap
  ///   disimpan sebagai berkas pemulihan terpisah, dan aplikasi melanjutkan
  ///   dengan berkas yang ada di jalur asli. Tidak ada yang ditimpa.
  Future<void> _selamatkanIsiLama(QueryExecutor lama) async {
    final String? jalur = this.jalur;
    if (jalur == null) return;
    final File berkas = File(jalur);
    final bool hilang = !berkas.existsSync() || berkas.lengthSync() == 0;
    final String tujuan = '$jalur.pulih-${DateTime.now().millisecondsSinceEpoch}';
    try {
      await lama.runCustom('VACUUM INTO ?', <Object?>[tujuan]);
    } catch (e) {
      catatGalatTertelan('basisdata.selamatkanIsiLama', e);
      if (hilang) rethrow; // jangan lanjut ke basis data kosong
      return;
    }
    if (!File(tujuan).existsSync()) return;
    berkasPenyelamatanTerakhir = tujuan;
    if (hilang) {
      File(tujuan).copySync(jalur);
      catatanPemulihanBasisData =
          'Berkas basis data sempat hilang; isinya berhasil diselamatkan '
          'kembali ke tempat semula. Tidak ada data yang hilang.';
    } else {
      catatanPemulihanBasisData =
          'Berkas basis data diganti di luar aplikasi. Isi lama diselamatkan '
          'ke $tujuan; aplikasi memakai berkas yang ada di tempat semula.';
    }
  }
}
