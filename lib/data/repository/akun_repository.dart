/// Penyimpanan sesi akun di perangkat.
///
/// Data yang tidak sensitif (email, nama, waktu masuk) tetap di tabel
/// `pengaturan` lewat [PengaturanRepository]; **TOKEN sesi** disimpan lewat
/// brankas Keystore ([PenyimpanRahasia]) — hasil audit 23 Sep 2026 (P0-3):
/// token polos di basis data ikut terbawa berkas cadangan/Google Drive/HP yang
/// di-root, sehingga akses ke akun pengguna bisa dibajak tanpa PIN.
///
/// Tidak ada perubahan skema; nilai lama dipindahkan ke brankas saat dibaca.
library;

import '../../core/akun/klien_akun.dart';
import '../../core/platform/brankas_rahasia.dart';
import 'pengaturan_repository.dart';

const String kunciTokenAkun = 'akun_token';
const String kunciEmailAkun = 'akun_email';
const String kunciNamaAkun = 'akun_nama';
const String kunciMasukPada = 'akun_masuk_pada';

class AkunRepository {
  AkunRepository(this._pengaturan, {PenyimpanRahasia? rahasia})
      : _rahasia = rahasia ?? PenyimpanRahasia(_pengaturan);

  final PengaturanRepository _pengaturan;
  final PenyimpanRahasia _rahasia;

  /// Apakah token sesi tersimpan TERENKRIPSI di perangkat ini.
  Future<bool> tokenTerlindungi() => _rahasia.tersedia();

  /// Sesi akun yang tersimpan, atau null kalau belum pernah masuk.
  Future<AkunSesi?> sesiTersimpan() async {
    final token = await _rahasia.baca(kunciTokenAkun);
    final email = await _pengaturan.baca(kunciEmailAkun);
    if (token == null || token.isEmpty) return null;
    if (email == null || email.isEmpty) return null;
    final nama = await _pengaturan.baca(kunciNamaAkun);
    return AkunSesi(
      token: token,
      email: email,
      nama: (nama == null || nama.isEmpty) ? email : nama,
    );
  }

  Future<void> simpanSesi(AkunSesi sesi, {DateTime? waktu}) async {
    await _rahasia.simpan(kunciTokenAkun, sesi.token);
    await _pengaturan.simpan(kunciEmailAkun, sesi.email);
    await _pengaturan.simpan(kunciNamaAkun, sesi.nama);
    await _pengaturan.simpan(
        kunciMasukPada, (waktu ?? DateTime.now()).toUtc().toIso8601String());
  }

  /// Dipakai saat keluar akun: sesi dibuang, DATA LOKAL tidak dihapus.
  Future<void> bersihkanSesi() async {
    for (final kunci in const [
      kunciTokenAkun,
      kunciEmailAkun,
      kunciNamaAkun,
      kunciMasukPada,
    ]) {
      // _rahasia.hapus membersihkan brankas DAN tabel pengaturan sekaligus,
      // sehingga tidak ada sisa token di jalur mana pun.
      await _rahasia.hapus(kunci);
    }
  }

  /// Token mentah hanya untuk panggilan API (tidak pernah ditampilkan di layar).
  Future<String?> token() => _rahasia.baca(kunciTokenAkun);
}
