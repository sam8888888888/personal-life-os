/// SDD v19 Gelombang 3 — Penjalankan mesin pola.
///
/// Menghubungkan tiga hal yang sengaja dipisah:
///   * [kandidatDariBasisData] — ambil datanya,
///   * [MesinPola.hitung] — hitung & saring (murni, bisa diuji),
///   * [TemuanRepository] — simpan dengan aturan (n ≥ 14, bahasa, umpan balik).
///
/// Berkas ini juga mengembalikan **alasan jujur** untuk pasangan yang belum
/// bisa diuji, supaya layar tidak perlu menebak kenapa daftarnya pendek.
library;

import '../../data/database/database.dart';
import '../../data/repository/temuan_repository.dart';
import 'mesin_pola.dart';
import 'pasangan_pola.dart';

/// Hasil satu kali penjalanan mesin pola.
class RingkasJalankanPola {
  const RingkasJalankanPola({
    required this.pasanganDiuji,
    required this.tersimpan,
    required this.dilewatiKurangData,
    required this.dilewatiPengguna,
  });

  final int pasanganDiuji;
  final int tersimpan;

  /// Pasangan yang datanya belum cukup — beserta jumlah pasangannya.
  final List<String> dilewatiKurangData;

  /// Temuan yang tidak dihidupkan lagi karena pengguna sudah bilang
  /// "bukan begitu".
  final int dilewatiPengguna;
}

/// Jalankan mesin pola untuk seluruh pasangan aktif.
Future<RingkasJalankanPola> jalankanMesinPola(
  AppDatabase db, {
  TemuanRepository? repo,
}) async {
  final TemuanRepository temuan = repo ?? TemuanRepository(db);
  final List<KandidatPola> kandidat = await kandidatDariBasisData(db);

  final List<String> kurang = <String>[];
  for (final KandidatPola k in kandidat) {
    if (k.titik.length < ambangSampelMinimum) {
      kurang.add('${k.kode}: baru ${k.titik.length} hari berpasangan '
          '(butuh $ambangSampelMinimum)');
    }
  }

  final List<HasilUjiPola> hasil = MesinPola.hitung(kandidat);
  int tersimpan = 0;
  int dilewatiPengguna = 0;
  for (final HasilUjiPola h in hasil) {
    final bool tersimpanBaris = await temuan.simpanDariMesin(h);
    if (tersimpanBaris) {
      tersimpan++;
    } else {
      dilewatiPengguna++;
    }
  }

  return RingkasJalankanPola(
    pasanganDiuji: kandidat.length,
    tersimpan: tersimpan,
    dilewatiKurangData: kurang,
    dilewatiPengguna: dilewatiPengguna,
  );
}
