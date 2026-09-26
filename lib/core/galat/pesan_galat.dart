/// Pesan galat untuk pengguna — bahasa manusia, tanpa perintah SQL mentah.
///
/// Latar belakang (temuan pengguna 26 Sep 2026): layar Kotak Masuk menampilkan
/// `Tidak bisa menyimpan: SqliteException(1032): attempt to write a readonly
/// database, while executing INSERT INTO "kotak_masuk" (uid, isi, …) VALUES
/// (?, ?, …)` — panjang, berisi perintah SQL, dan tidak menjelaskan apa yang
/// harus dilakukan. Bagi pemilik aplikasi itu bukan pesan, itu kebisingan.
///
/// Aturan berkas ini:
///
/// 1. Kalimat pertama menyebut **apa yang terjadi** dan **apa yang bisa
///    dilakukan**.
/// 2. Rincian teknis tetap disertakan sepotong (biar bisa dilaporkan ke
///    pendukung) tapi dipotong SEBELUM perintah SQL — tidak ada dump SQL.
/// 3. Tidak pernah berbunyi seolah berhasil.
library;

import '../../data/database/enkripsi_basisdata.dart';
import '../../data/database/executor_pulih.dart';

/// Pesan untuk kegagalan menyimpan.
String pesanGalatSimpan(Object galat) {
  if (galat is GalatBasisData) return galat.pesan;
  if (galatBerkasPindah(galat)) {
    return 'Penyimpanan sedang dipulihkan (berkas basis data sempat berpindah). '
        'Teks yang sudah ditulis tetap ada di kotak ini — tekan Simpan sekali '
        'lagi. Data lama tidak hilang.';
  }
  return 'Tidak bisa menyimpan. Teks tetap ada di kotak ini — coba sekali lagi '
      'sebentar. Rincian: ${ringkasGalat(galat)}';
}

/// Pesan untuk kegagalan membaca/memuat.
String pesanGalatMuat(Object galat) {
  if (galat is GalatBasisData) return galat.pesan;
  return 'Isi tidak bisa dibaca sekarang. Rincian: ${ringkasGalat(galat)}';
}

/// Inti galat: satu baris, dipotong sebelum perintah SQL, maksimal [maks] huruf.
String ringkasGalat(Object galat, {int maks = 120}) {
  String teks = galat.toString().split('\n').first.trim();
  // Buang bagian "while executing INSERT INTO …" — perintah SQL tidak ada
  // gunanya bagi pengguna dan bisa membocorkan nama kolom.
  final RegExp awalSql = RegExp(
    r'\b(while executing|INSERT INTO|UPDATE "|DELETE FROM|SELECT |CREATE |'
    r'PRAGMA |BEGIN |COMMIT)\b',
    caseSensitive: false,
  );
  final RegExpMatch? kena = awalSql.firstMatch(teks);
  if (kena != null) {
    teks = teks.substring(0, kena.start).trim();
  }
  final int potong = teks.indexOf(',');
  if (potong > 0 && potong < 60) teks = teks.substring(0, potong);
  if (teks.isEmpty) teks = galat.runtimeType.toString();
  return teks.length <= maks ? teks : '${teks.substring(0, maks)}…';
}
