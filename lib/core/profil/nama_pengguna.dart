/// Nama pengguna untuk sapaan (permintaan Papi, 26 Sep 2026):
/// layar Hari Ini harus menyapa dengan NAMA, mis. "Selamat pagi, Samian".
///
/// Sumber nama, berurutan:
///   1. isian "Nama panggilan" di Pengaturan (pilihan sadar pengguna);
///   2. nama akun dari server (terisi sendiri sesudah masuk/daftar);
///   3. 'Anda' bila keduanya kosong — sapaan tetap tampil, tidak kosong.
library;

import '../../data/repository/pengaturan_repository.dart';

/// Kunci pengaturan tempat nama panggilan disimpan.
const String kunciNamaPanggilan = 'umum.nama_panggilan';

/// Sapaan bawaan bila pengguna belum mengisi nama.
const String namaPanggilanBawaan = 'Anda';

/// Sapaan menurut jam + nama.
///
/// Batas waktu memakai kebiasaan Indonesia: pagi 04.00–10.59,
/// siang 11.00–14.59, sore 15.00–17.59, malam 18.00–03.59.
String sapaanWaktu(DateTime waktu, String nama) {
  final namaBersih = nama.trim().isEmpty ? namaPanggilanBawaan : nama.trim();
  return '${_ucapSelamat(waktu.hour)}, ${rapikanNama(namaBersih)}';
}

String _ucapSelamat(int jam) {
  if (jam >= 4 && jam < 11) return 'Selamat pagi';
  if (jam >= 11 && jam < 15) return 'Selamat siang';
  if (jam >= 15 && jam < 18) return 'Selamat sore';
  return 'Selamat malam';
}

/// Rapikan nama seperlunya: nama yang ditulis serba huruf kecil dibesarkan
/// huruf depan tiap katanya ("samian" → "Samian"); tulisan pengguna sendiri
/// yang sudah punya huruf besar/kecil dibiarkan apa adanya ("Soe'oed", "McD").
String rapikanNama(String nama) {
  final bersih = nama.trim();
  if (bersih.isEmpty) return namaPanggilanBawaan;
  if (bersih != bersih.toLowerCase()) return bersih;
  return bersih
      .split(' ')
      .map((k) => k.isEmpty ? k : '${k[0].toUpperCase()}${k.substring(1)}')
      .join(' ');
}

/// Pembaca & penyimpan nama panggilan.
class NamaPengguna {
  const NamaPengguna(this.pengaturan);

  final PengaturanRepository pengaturan;

  /// Nama yang dipakai untuk sapaan.
  ///
  /// [namaAkun] = nama dari akun yang sedang masuk (bila ada).
  Future<String> baca({String? namaAkun}) async {
    final lokal = (await pengaturan.baca(kunciNamaPanggilan))?.trim();
    if (lokal != null && lokal.isNotEmpty) return lokal;
    final dariAkun = namaAkun?.trim();
    if (dariAkun != null && dariAkun.isNotEmpty) return dariAkun;
    return namaPanggilanBawaan;
  }

  /// Simpan nama panggilan. Nama kosong = hapus isian (kembali ke nama akun).
  Future<void> simpan(String nama) async {
    final bersih = nama.trim();
    if (bersih.isEmpty) {
      await pengaturan.hapusPengaturan(kunciNamaPanggilan);
      return;
    }
    await pengaturan.simpan(kunciNamaPanggilan, bersih);
  }

  /// Isi otomatis dari akun — hanya bila pengguna belum pernah mengisi sendiri,
  /// supaya pilihan pengguna tidak tertimpa.
  Future<void> isiDariAkunBilaKosong(String namaAkun) async {
    final bersih = namaAkun.trim();
    if (bersih.isEmpty) return;
    final lokal = (await pengaturan.baca(kunciNamaPanggilan))?.trim();
    if (lokal != null && lokal.isNotEmpty) return;
    await pengaturan.simpan(kunciNamaPanggilan, bersih);
  }
}
