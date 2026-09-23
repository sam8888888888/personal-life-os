/// Enkripsi basis data saat disimpan (temuan audit 23 Sep 2026, P2-2).
///
/// Data tagihan, transaksi, kesehatan, dan dokumen keluarga disimpan di satu
/// berkas SQLite. Sebelumnya berkas itu terbaca sebagai teks polos oleh siapa
/// pun yang bisa menyalinnya (HP di-root, perkakas cadangan). Sekarang berkas
/// dienkripsi dengan SQLCipher memakai kunci 256-bit yang dibuat di Android
/// Keystore dan TIDAK BISA DIEKSPOR.
///
/// Aturan yang dipegang berkas ini:
///
/// 1. **Tidak pernah mengaku aman.** [KeadaanBasisData] menjawab apa adanya:
///    `terenkripsi`, `polos`, atau `tidakDidukung`. Kalau pustaka SQLCipher
///    tidak ada di perangkat (hook tidak terpasang), berkas TIDAK disentuh dan
///    keadaannya dilaporkan `tidakDidukung`.
/// 2. **Migrasi berkas lama punya titik pulih.** Berkas polos disalin lebih
///    dulu (`*.cadangan-polos`), hasilnya diverifikasi (jumlah tabel sama),
///    dan salinan itu dihapus HANYA setelah verifikasi lolos. Gagal di tahap
///    mana pun → berkas polos dikembalikan utuh supaya aplikasi tetap jalan.
/// 3. **Satu proses saja.** Penanda `*.migrasi` mencegah dua isolate
///    memigrasi berkas yang sama bersamaan.
library;

import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/notifikasi/jejak.dart';
import '../../core/platform/brankas_rahasia.dart';

/// Nama kunci basis data di brankas perangkat (Keystore).
const String namaKunciBasisData = 'basisdata.kunci';

/// Keadaan enkripsi basis data — dipakai layar untuk berkata apa adanya.
enum KeadaanBasisData {
  /// Isi berkas terenkripsi & kuncinya ada di Keystore perangkat.
  terenkripsi,

  /// Berkas masih terbaca polos (mis. enkripsi tidak mungkin di perangkat ini).
  polos,

  /// Perangkat/pustaka tidak mendukung enkripsi (tanpa Keystore / tanpa SQLCipher).
  tidakDidukung,
}

/// Keadaan basis data yang terakhir disiapkan.
KeadaanBasisData keadaanBasisDataSaatIni = KeadaanBasisData.polos;

/// Penjelasan keadaan itu (siap tampil ke pengguna), atau null.
String? pesanBasisDataSaatIni;

/// Galat basis data yang tidak bisa dibuka sama sekali — pesannya siap tampil.
class GalatBasisData implements Exception {
  const GalatBasisData(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}

/// Berkas basis data untuk [nama] — sama dengan yang dipakai drift_flutter
/// (`$nama.sqlite` di folder dokumen aplikasi).
Future<File> berkasBasisData(String nama) async {
  final Directory folder = await getApplicationDocumentsDirectory();
  return File(p.join(folder.path, '$nama.sqlite'));
}

/// Siapkan kunci + migrasi berkas lama. Mengembalikan kunci, atau `null` bila
/// enkripsi tidak mungkin di perangkat ini (berkas dibiarkan polos).
Future<String?> siapkanKunciBasisData(File berkas) async {
  final String? kunci = await _kunciBasisData();
  if (kunci == null) {
    keadaanBasisDataSaatIni = KeadaanBasisData.tidakDidukung;
    pesanBasisDataSaatIni =
        'Kunci perangkat (Android Keystore) tidak tersedia, jadi basis data '
        'belum bisa dienkripsi di perangkat ini.';
    return null;
  }
  if (!_pustakaMendukungEnkripsi()) {
    keadaanBasisDataSaatIni = KeadaanBasisData.tidakDidukung;
    pesanBasisDataSaatIni =
        'Pustaka basis data di perangkat ini belum mendukung enkripsi '
        '(SQLCipher), jadi berkasnya masih tersimpan polos.';
    return null;
  }

  String? catatan;
  if (berkas.existsSync()) {
    catatan = await _migrasiBilaPolos(berkas, kunci);
  }

  // Berkas baru (belum ada) akan dibuat terenkripsi oleh `PRAGMA key`.
  final int? denganKunci = berkas.existsSync() ? _jumlahTabel(berkas, kunci) : 0;
  if (denganKunci != null) {
    keadaanBasisDataSaatIni = KeadaanBasisData.terenkripsi;
    pesanBasisDataSaatIni = catatan;
    return kunci;
  }

  // Tidak terbaca dengan kunci kita. Kalau masih terbaca polos, pakai polos
  // supaya aplikasi tetap jalan — dan katakan apa adanya.
  if (_jumlahTabel(berkas, null) != null) {
    keadaanBasisDataSaatIni = KeadaanBasisData.polos;
    pesanBasisDataSaatIni = <String?>[
      catatan,
      'Basis data dibuka TANPA enkripsi supaya aplikasi tetap jalan.',
    ].whereType<String>().join(' ');
    return null;
  }

  throw const GalatBasisData(
    'Basis data tidak bisa dibuka: berkasnya bukan SQLite polos dan tidak '
    'cocok dengan kunci di perangkat ini. Tidak ada yang diubah — jangan '
    'dihapus; hubungi pendukung dengan menyebutkan pesan ini.',
  );
}

/// Executor drift untuk basis data (terenkripsi bila [kunci] tidak null).
QueryExecutor executorBasisData(String nama, String? kunci) {
  if (kunci == null) {
    return driftDatabase(name: nama, native: const DriftNativeOptions());
  }
  return driftDatabase(
    name: nama,
    native: DriftNativeOptions(
      // PRAGMA key dijalankan sebelum kueri pertama — sisi native, jadi aman
      // dijalankan di isolate mana pun (aplikasi utama maupun pekerja latar).
      setup: (CommonDatabase db) =>
          db.execute("PRAGMA key = '${_aman(kunci)}'"),
    ),
  );
}

// ── Kunci ───────────────────────────────────────────────────────────────────

/// Ambil kunci basis data dari brankas Keystore; buat sekali bila belum ada.
///
/// Sengaja TIDAK memakai jalur mundur ke tabel `pengaturan` (seperti
/// [PenyimpanRahasia]): tabel itu ada di dalam basis data yang justru sedang
/// dibuka — memakainya berarti menunggu dirinya sendiri.
Future<String?> _kunciBasisData() async {
  if (!await brankasDidukung()) return null;
  final String? ada = await bacaRahasiaPerangkat(namaKunciBasisData);
  if (ada != null && ada.length >= 32) return ada;

  final Random acak = Random.secure();
  final List<int> byte = List<int>.generate(32, (_) => acak.nextInt(256));
  final String kunci = _keHeksadesimal(byte);
  final bool tersimpan = await simpanRahasiaPerangkat(namaKunciBasisData, kunci);
  if (!tersimpan) return null;
  return kunci;
}

/// 32 byte → 64 huruf heksadesimal (tanpa tanda kutip/spasi, aman di PRAGMA).
String _keHeksadesimal(List<int> byte) =>
    byte.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Kutip nilai untuk literal SQL (kunci kita heksadesimal, ini sabuk pengaman).
String _aman(String nilai) => nilai.replaceAll("'", "''");

// ── Pustaka & verifikasi ────────────────────────────────────────────────────

bool? _mendukung;

/// Apakah pustaka SQLite yang terpasang benar-benar SQLCipher.
///
/// Dijawab dengan bertanya `PRAGMA cipher_version` — SQLite biasa tidak
/// mengenal pragma itu dan menjawab kosong.
bool _pustakaMendukungEnkripsi() {
  if (_mendukung != null) return _mendukung!;
  try {
    final Database db = sqlite3.openInMemory();
    try {
      _mendukung = db.select('PRAGMA cipher_version').isNotEmpty;
    } finally {
      db.close();
    }
  } catch (e) {
    catatGalatTertelan('basisdata.periksaPustaka', e);
    _mendukung = false;
  }
  return _mendukung!;
}

/// Jumlah tabel pada [berkas] — `null` bila tidak bisa dibaca dengan [kunci].
int? _jumlahTabel(File berkas, String? kunci) {
  try {
    final Database db = sqlite3.open(berkas.path);
    try {
      if (kunci != null) db.execute("PRAGMA key = '${_aman(kunci)}'");
      final ResultSet baris = db
          .select("SELECT count(*) AS n FROM sqlite_master WHERE type = 'table'");
      return baris.first['n'] as int;
    } finally {
      db.close();
    }
  } catch (e) {
    catatGalatTertelan(
      kunci == null ? 'basisdata.bacaPolos' : 'basisdata.bacaTerenkripsi',
      e,
    );
    return null;
  }
}

// ── Migrasi berkas polos → terenkripsi ──────────────────────────────────────

/// Enkripsi berkas polos yang sudah berisi data pengguna.
///
/// Mengembalikan catatan untuk pengguna, atau `null` bila tidak ada yang
/// dikerjakan (sudah terenkripsi).
Future<String?> _migrasiBilaPolos(File berkas, String kunci) async {
  if (_jumlahTabel(berkas, kunci) != null) return null;

  final int? jumlahSebelum = _jumlahTabel(berkas, null);
  if (jumlahSebelum == null) {
    throw const GalatBasisData(
      'Basis data tidak bisa dibuka (bukan SQLite polos dan tidak cocok dengan '
      'kunci perangkat). Tidak ada yang diubah.',
    );
  }

  final File penanda = File('${berkas.path}.migrasi');
  try {
    penanda.createSync(exclusive: true);
  } catch (e) {
    catatGalatTertelan('basisdata.migrasiPenanda', e);
    return 'Enkripsi basis data sedang dijalankan proses lain; berkas ini '
        'belum diubah oleh proses sekarang.';
  }

  final File cadangan = File('${berkas.path}.cadangan-polos');
  try {
    if (cadangan.existsSync()) cadangan.deleteSync();
    berkas.copySync(cadangan.path);

    final Database db = sqlite3.open(berkas.path);
    try {
      db.select('SELECT count(*) FROM sqlite_master'); // pastikan terbaca polos
      db.execute("PRAGMA key = ''"); // mode polos (tanpa kunci)
      db.execute("PRAGMA rekey = '${_aman(kunci)}'"); // enkripsi di tempat
    } finally {
      db.close();
    }

    final int? jumlahSesudah = _jumlahTabel(berkas, kunci);
    if (jumlahSesudah == null || jumlahSesudah != jumlahSebelum) {
      _pulihkanPolos(berkas, cadangan);
      return 'Enkripsi basis data gagal diverifikasi (jumlah tabel berbeda), '
          'jadi berkas dikembalikan ke keadaan semula: tetap jalan, belum '
          'terenkripsi.';
    }

    // Terverifikasi → titik pulih polos TIDAK boleh ditinggal (isinya polos).
    cadangan.deleteSync();
    return 'Basis data sekarang terenkripsi (SQLCipher $jumlahSesudah tabel).';
  } catch (e) {
    catatGalatTertelan('basisdata.migrasi', e);
    _pulihkanPolos(berkas, cadangan);
    return 'Enkripsi basis data gagal (${e.runtimeType}); berkas dikembalikan '
        'ke keadaan semula dan aplikasi tetap jalan tanpa enkripsi.';
  } finally {
    if (penanda.existsSync()) penanda.deleteSync();
  }
}

/// Kembalikan berkas polos dari titik pulih.
void _pulihkanPolos(File berkas, File cadangan) {
  try {
    if (!cadangan.existsSync()) return;
    if (berkas.existsSync()) berkas.deleteSync();
    cadangan.copySync(berkas.path);
  } catch (e) {
    catatGalatTertelan('basisdata.pulihkan', e);
  }
}
