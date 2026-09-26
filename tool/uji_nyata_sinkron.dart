/// Uji nyata: kode APLIKASI (bukan skrip Python) bicara dengan layanan
/// Akun & Sinkron yang hidup. Dijalankan dari server Austria.
///
/// Cara pakai:
///
///     dart run tool/uji_nyata_sinkron.dart http://127.0.0.1:3500
///     dart run tool/uji_nyata_sinkron.dart https://coder.sam.university/lifeos-api
///
/// Kenapa ada berkas ini: uji `uji_api.py` di sisi server membuktikan layanan
/// benarnya jalan, TAPI belum membuktikan **klien di aplikasi** berbicara
/// dengan bentuk data yang sama. Berkas ini memakai `KlienAkun` yang sama persis
/// dengan yang dipakai APK, jadi kalau ada beda nama kolom/medan, akan ketahuan
/// di sini — bukan di HP pengguna.
///
/// Akun uji memakai alamat berakhiran `@lifeos.test` supaya bisa dibersihkan
/// dengan `bersihkan_akun_uji.py` di server (tidak ada residu).
library;

import 'dart:io';

import 'package:personal_life_os/core/akun/klien_akun.dart';

int _lulus = 0;
int _gagal = 0;

void periksa(bool syarat, String pesan) {
  if (syarat) {
    _lulus++;
    stdout.writeln('  OK    $pesan');
  } else {
    _gagal++;
    stdout.writeln('  GAGAL $pesan');
  }
}

Future<void> main(List<String> argumen) async {
  final String alamat =
      argumen.isNotEmpty ? argumen.first : 'http://127.0.0.1:3500';
  final String cap = DateTime.now().microsecondsSinceEpoch.toString();
  final String emailA = 'uji.a.$cap@lifeos.test';
  final String emailB = 'uji.b.$cap@lifeos.test';
  const String sandi = 'rahasia12345';

  final KlienAkun klien = KlienAkun(alamat: alamat, namaPerangkat: 'uji-klien');
  stdout.writeln('Alamat layanan: $alamat');

  // ── 1. Daftar dua akun ────────────────────────────────────────────────────
  stdout.writeln('== 1. Daftar akun (dua akun terpisah) ==');
  final AkunSesi a = await klien.daftar(email: emailA, nama: 'Uji A', sandi: sandi);
  periksa(a.token.length > 20, 'akun A dapat token (${a.token.length} huruf)');
  periksa(a.email == emailA, 'email akun A sesuai');

  final AkunSesi b = await klien.daftar(email: emailB, nama: 'Uji B', sandi: sandi);
  periksa(b.token.isNotEmpty && b.token != a.token, 'akun B dapat tokenberbeda');

  // ── 2. Masuk ulang & sandi salah ──────────────────────────────────────────
  stdout.writeln('== 2. Masuk & penolakan sandi salah ==');
  final AkunSesi lagi = await klien.masuk(email: emailA, sandi: sandi);
  periksa(lagi.token.isNotEmpty, 'masuk ulang berhasil');
  try {
    await klien.masuk(email: emailA, sandi: 'sandi_salah_99');
    periksa(false, 'sandi salah seharusnya DITOLAK');
  } on AkunGagal {
    periksa(true, 'sandi salah ditolak (AkunGagal)');
  }

  // ── 3. Sinkron dua arah: dorong lalu tarik ────────────────────────────────
  stdout.writeln('== 3. Sinkron dua arah ==');
  final Map<String, Object?> tagihan = <String, Object?>{
    'tabel': 'tagihan',
    'id_lokal': 'uji-tagihan-$cap',
    'waktu_klien': DateTime.now().toUtc().toIso8601String(),
    'dihapus': false,
    'isi': <String, Object?>{'nama': 'Listrik', 'jumlah': 350000, 'lunas': false},
  };
  final Map<String, Object?> kebiasaan = <String, Object?>{
    'tabel': 'kebiasaan',
    'id_lokal': 'uji-kebiasaan-$cap',
    'waktu_klien': DateTime.now().toUtc().toIso8601String(),
    'dihapus': false,
    'isi': <String, Object?>{'nama': 'Jalan pagi', 'menit': 20},
  };
  final Map<String, dynamic> jawabA = await klien.sinkron(
    token: a.token,
    sejak: 0,
    perubahan: <Map<String, dynamic>>[tagihan, kebiasaan],
  );
  periksa(jawabA['diterima'] == 2, 'server menerima 2 perubahan (${jawabA['diterima']})');
  final int revisi = (jawabA['revisi'] as num?)?.toInt() ?? 0;
  periksa(revisi >= 2, 'nomor revisi naik menjadi $revisi');

  final Map<String, dynamic> tarikA = await klien.sinkron(token: a.token, sejak: 0);
  final List<dynamic> dapatA = (tarikA['perubahan'] as List<dynamic>?) ?? <dynamic>[];
  final Set<String> tabelDapat = dapatA
      .map((dynamic e) => (e as Map<String, dynamic>)['tabel'] as String)
      .toSet();
  periksa(dapatA.length >= 2, 'akun A menarik kembali ${dapatA.length} catatan');
  periksa(
    tabelDapat.containsAll(<String>{'tagihan', 'kebiasaan'}),
    'jenis data yang ditarik benar ($tabelDapat)',
  );
  final Map<String, dynamic>? kembali = dapatA
      .cast<Map<String, dynamic>>()
      .where((Map<String, dynamic> e) => e['id_lokal'] == tagihan['id_lokal'])
      .firstOrNull;
  periksa(kembali != null && kembali['isi'] != null, 'isi catatan utuh saat ditarik kembali');

  // ── 4. Pemisahan antar akun ───────────────────────────────────────────────
  stdout.writeln('== 4. Pemisahan antar akun (kebocoran antar-pengguna) ==');
  final Map<String, dynamic> tarikB = await klien.sinkron(token: b.token, sejak: 0);
  final List<dynamic> dapatB = (tarikB['perubahan'] as List<dynamic>?) ?? <dynamic>[];
  periksa(
    dapatB.isEmpty,
    'akun B TIDAK melihat data akun A (dapat ${dapatB.length})',
  );

  // ── 5. Aturan konflik (dua arah) ──────────────────────────────────────────
  // Aturan server (diverifikasi dari kode): pengiriman dengan waktu LEBIH BARU
  // menang & tersimpan; pengiriman dengan waktu LEBIH LAMA kalah TAPI tetap
  // disimpan sebagai catatan konflik — jadi tidak ada versi yang hilang.
  stdout.writeln('== 5. Aturan konflik ==');
  final Map<String, dynamic> lebihBaru = <String, dynamic>{
    ...tagihan,
    'waktu_klien': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
    'isi': <String, Object?>{'nama': 'Listrik', 'jumlah': 400000, 'lunas': true},
  };
  final Map<String, dynamic> jawabBaru = await klien.sinkron(
    token: a.token,
    sejak: revisi,
    perubahan: <Map<String, dynamic>>[lebihBaru],
  );
  periksa(
    (jawabBaru['diterima'] as num?)?.toInt() == 1 &&
        (jawabBaru['konflik'] as num?)?.toInt() == 0,
    'versi LEBIH BARU menang (diterima=${jawabBaru['diterima']}, '
    'konflik=${jawabBaru['konflik']})',
  );

  final Map<String, dynamic> tarikBaru = await klien.sinkron(token: a.token, sejak: 0);
  final Map<String, dynamic>? tersimpan = (tarikBaru['perubahan'] as List<dynamic>?)
      ?.cast<Map<String, dynamic>>()
      .where((Map<String, dynamic> e) => e['id_lokal'] == tagihan['id_lokal'])
      .firstOrNull;
  final Map<String, dynamic> isiTersimpan =
      (tersimpan?['isi'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
  periksa(
    isiTersimpan['jumlah'] == 400000 && isiTersimpan['lunas'] == true,
    'isi terbaru benar-benar tersimpan di server ($isiTersimpan)',
  );

  final Map<String, dynamic> lebihLama = <String, dynamic>{
    ...tagihan,
    'waktu_klien': DateTime.now().toUtc().subtract(const Duration(days: 2)).toIso8601String(),
    'isi': <String, Object?>{'nama': 'Listrik', 'jumlah': 1, 'lunas': false},
  };
  final Map<String, dynamic> jawabLama = await klien.sinkron(
    token: a.token,
    sejak: revisi,
    perubahan: <Map<String, dynamic>>[lebihLama],
  );
  periksa(
    (jawabLama['konflik'] as num?)?.toInt() == 1,
    'versi LEBIH LAMA kalah & tetap disimpan sebagai konflik '
    '(konflik=${jawabLama['konflik']})',
  );

  final Map<String, dynamic> tarikAkhir = await klien.sinkron(token: a.token, sejak: 0);
  final Map<String, dynamic>? tetapBaru = (tarikAkhir['perubahan'] as List<dynamic>?)
      ?.cast<Map<String, dynamic>>()
      .where((Map<String, dynamic> e) => e['id_lokal'] == tagihan['id_lokal'])
      .firstOrNull;
  final Map<String, dynamic> isiTetap =
      (tetapBaru?['isi'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
  periksa(
    isiTetap['jumlah'] == 400000,
    'versi yang kalah TIDAK menimpa versi baru di server (jumlah=${isiTetap['jumlah']})',
  );

  // ── 6. Keluar mematikan sesi ──────────────────────────────────────────────
  stdout.writeln('== 6. Keluar akun ==');
  await klien.keluar(a.token);
  try {
    await klien.sinkron(token: a.token, sejak: 0);
    periksa(false, 'token yang sudah keluar seharusnya DITOLAK');
  } on AkunGagal {
    periksa(true, 'token yang sudah keluar ditolak');
  }

  stdout.writeln('');
  stdout.writeln('RINGKASAN: $_lulus lulus / $_gagal gagal');
  stdout.writeln('Akun uji: $emailA , $emailB (bersihkan dengan '
      'bersihkan_akun_uji.py di server)');
  if (_gagal > 0) exitCode = 1;
}
