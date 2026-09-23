/// Kunci cadangan perangkat (hasil audit 23 Sep 2026, P0-3).
///
/// Cadangan otomatis & cadangan pengaman (yang dibuat sebelum impor) tidak bisa
/// meminta frasa sandi kepada pengguna — tidak ada orang di depan layar saat
/// pekerjaan latar berjalan. Karena itu dipakai **kunci acak perangkat** yang
/// disimpan di brankas Android Keystore (tidak bisa diekspor):
///
/// * berkas cadangan di perangkat TIDAK PERNAH berupa teks polos;
/// * berkas itu hanya bisa dibuka kembali di perangkat yang sama;
/// * untuk memindah data ke HP lain, pengguna membuat cadangan berfrasa sandi
///   sendiri (Pengaturan → Cadangan → isi frasa sandi).
///
/// Bila perangkat tidak punya brankas (mis. pengujian di desktop), fungsi ini
/// menjawab `null` dan pemanggil harus memutuskan apa adanya (menulis berkas
/// polos atau menolak) — bukan berpura-pura aman.
library;

import 'dart:convert';
import 'dart:math';

import '../../data/database/database.dart';
import '../../data/repository/pengaturan_repository.dart';
import '../platform/brankas_rahasia.dart';

/// Nama rahasia di brankas tempat kunci cadangan perangkat disimpan.
const String kunciCadanganPerangkat = 'cadangan.kunci_perangkat';

/// Panjang kunci acak (byte) sebelum diubah ke base64.
const int panjangKunciCadangan = 32;

/// Kunci cadangan perangkat — dibuat sekali lalu dipakai terus.
Future<String?> kunciCadanganPerangkatUntuk(AppDatabase db) async {
  final rahasia = PenyimpanRahasia(PengaturanRepository(db));
  if (!await rahasia.tersedia()) return null;
  final ada = await rahasia.baca(kunciCadanganPerangkat);
  if (ada != null && ada.length >= panjangKunciCadangan) return ada;
  final baru = buatKunciCadanganAcak();
  final ok = await simpanRahasiaPerangkat(kunciCadanganPerangkat, baru);
  if (!ok) return null;
  return baru;
}

/// Kunci cadangan acak (32 byte → base64).
String buatKunciCadanganAcak() {
  final acak = Random.secure();
  final byte = List<int>.generate(panjangKunciCadangan, (_) => acak.nextInt(256));
  return base64Encode(byte);
}
