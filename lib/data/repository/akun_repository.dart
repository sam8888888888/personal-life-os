/// Penyimpanan sesi akun di perangkat.
///
/// Menumpang tabel `pengaturan` yang sudah ada (lewat [PengaturanRepository]),
/// jadi TIDAK ada perubahan skema basis data dan data lama pengguna aman.
library;

import '../../core/akun/klien_akun.dart';
import 'pengaturan_repository.dart';

const String kunciTokenAkun = 'akun_token';
const String kunciEmailAkun = 'akun_email';
const String kunciNamaAkun = 'akun_nama';
const String kunciMasukPada = 'akun_masuk_pada';

class AkunRepository {
  AkunRepository(this._pengaturan);

  final PengaturanRepository _pengaturan;

  /// Sesi akun yang tersimpan, atau null kalau belum pernah masuk.
  Future<AkunSesi?> sesiTersimpan() async {
    final token = await _pengaturan.baca(kunciTokenAkun);
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
    await _pengaturan.simpan(kunciTokenAkun, sesi.token);
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
      await _pengaturan.hapusPengaturan(kunci);
    }
  }

  /// Token mentah hanya untuk panggilan API (tidak pernah ditampilkan di layar).
  Future<String?> token() => _pengaturan.baca(kunciTokenAkun);
}
