/// FR-26 — Kunci aplikasi (PIN / kunci perangkat) untuk data sensitif.
///
/// Aturan yang dipegang di sini:
/// * PIN **tidak pernah disimpan apa adanya** — hanya turunan PBKDF2-HMAC-SHA256
///   (garam acak + banyak putaran) yang ditulis ke basis data.
/// * Salah PIN berkali-kali → percobaan ditahan sementara (bukan dikunci
///   selamanya, bukan pula dibiarkan bebas).
/// * Kunci ini menahan **tampilan**, bukan menyandikan basis data.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../data/repository/pengaturan_repository.dart';

// ---------------------------------------------------------------------------
// Nama pengaturan (k-v) — satu tempat, dipakai layar & uji.
// ---------------------------------------------------------------------------

const String kunciKunciAktif = 'kunci_aktif';
const String kunciKunciGaram = 'kunci_garam';
const String kunciKunciTurunan = 'kunci_turunan';
const String kunciKunciIterasi = 'kunci_iterasi';
const String kunciKunciGagal = 'kunci_gagal';
const String kunciKunciTungguSampai = 'kunci_tunggu_sampai';
const String kunciKunciBukaPerangkat = 'kunci_buka_perangkat';
const String kunciKunciTenggangDetik = 'kunci_tenggang_detik';

/// Panjang PIN paling pendek yang diterima.
const int kunciPanjangMin = 4;

/// Panjang PIN paling panjang (menjaga agar tidak jadi sandi).
const int kunciPanjangMaks = 12;

/// Putaran PBKDF2 bawaan. Uji memakai angka kecil supaya cepat.
const int kunciIterasiBawaan = 60000;

/// Berapa kali salah sebelum ditahan sementara.
const int kunciPercobaanMaks = 5;

/// Lama tahanan sementara (detik) setelah [kunciPercobaanMaks] kali salah.
const int kunciTahananDetik = 30;

/// Masa tenggang bawaan (detik) sebelum aplikasi terkunci lagi setelah
/// ditinggal ke latar. 0 = langsung terkunci.
const int kunciTenggangBawaan = 0;

/// Hasil satu kali percobaan membuka kunci.
class HasilBukaKunci {
  const HasilBukaKunci({
    required this.berhasil,
    this.sisaPercobaan = kunciPercobaanMaks,
    this.tungguSampai,
    this.pesan,
  });

  /// Benar bila PIN diterima.
  final bool berhasil;

  /// Sisa kesempatan sebelum ditahan sementara.
  final int sisaPercobaan;

  /// Bila tidak null, percobaan berikutnya baru diterima setelah waktu ini.
  final DateTime? tungguSampai;

  /// Keterangan apa adanya untuk pengguna.
  final String? pesan;

  bool get tertahan => tungguSampai != null;
}

/// Kunci aplikasi (FR-26).
class KunciAplikasi {
  KunciAplikasi(this.repo, {Random? acak, int? iterasi})
      : _acak = acak ?? Random.secure(),
        _iterasi = iterasi ?? kunciIterasiBawaan;

  final PengaturanRepository repo;
  final Random _acak;
  final int _iterasi;

  /// Apakah kunci sedang dipakai.
  Future<bool> aktif() async {
    final ada = await repo.bacaSaklar(kunciKunciAktif);
    if (!ada) return false;
    final turunan = await repo.baca(kunciKunciTurunan);
    return turunan != null && turunan.isNotEmpty;
  }

  /// Apakah aplikasi boleh dibuka dengan kunci perangkat (PIN/sidik jari HP).
  Future<bool> bukaPerangkatAktif() =>
      repo.bacaSaklar(kunciKunciBukaPerangkat);

  /// Masa tenggang (detik) sebelum terkunci lagi.
  Future<int> tenggangDetik() async =>
      repo.bacaAngka(kunciKunciTenggangDetik, kunciTenggangBawaan);

  Future<void> simpanTenggang(int detik) => repo.simpan(
      kunciKunciTenggangDetik, detik.toString());

  /// Pasang PIN (sekaligus menyalakan kunci).
  ///
  /// [bukaPerangkat] = izinkan membuka dengan kunci perangkat HP.
  Future<void> pasangPin(String pin,
      {bool bukaPerangkat = false}) async {
    final keluhan = keluhanPin(pin);
    if (keluhan != null) throw ArgumenPinTidakSah(keluhan);
    final garam = _buatGaram();
    final turunan = _hitung(pin, garam, _iterasi);
    await repo.simpan(kunciKunciGaram, base64Encode(garam));
    await repo.simpan(kunciKunciTurunan, base64Encode(turunan));
    await repo.simpan(kunciKunciIterasi, _iterasi.toString());
    await repo.simpan(kunciKunciBukaPerangkat, bukaPerangkat ? 'ya' : 'tidak');
    await _bersihkanHitung();
    await repo.simpan(kunciKunciAktif, 'ya');
  }

  /// Nyalakan/matikan izin buka dengan kunci perangkat.
  Future<void> setBukaPerangkat(bool aktif) =>
      repo.simpan(kunciKunciBukaPerangkat, aktif ? 'ya' : 'tidak');

  /// Matikan kunci (PIN dihapus).
  Future<void> matikan() async {
    await repo.simpan(kunciKunciAktif, 'tidak');
    await repo.hapusPengaturan(kunciKunciTurunan);
    await repo.hapusPengaturan(kunciKunciGaram);
    await _bersihkanHitung();
  }

  /// Keterangan bila PIN tidak sah — null berarti sah.
  static String? keluhanPin(String pin) {
    if (pin.length < kunciPanjangMin) {
      return 'PIN paling sedikit $kunciPanjangMin angka.';
    }
    if (pin.length > kunciPanjangMaks) {
      return 'PIN paling banyak $kunciPanjangMaks angka.';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(pin)) {
      return 'PIN hanya angka.';
    }
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) {
      return 'PIN tidak boleh satu angka berulang semua.';
    }
    return null;
  }

  /// Waktu sampai kapan percobaan ditahan (null = boleh mencoba sekarang).
  Future<DateTime?> tungguSampai() async {
    final teks = await repo.baca(kunciKunciTungguSampai);
    if (teks == null || teks.isEmpty) return null;
    final ms = int.tryParse(teks);
    if (ms == null) return null;
    final sampai = DateTime.fromMillisecondsSinceEpoch(ms);
    if (!sampai.isAfter(DateTime.now())) return null;
    return sampai;
  }

  /// Buka kunci dengan PIN. Menghitung percobaan salah & menahannya.
  Future<HasilBukaKunci> buka(String pin) async {
    final tertahanSampai = await tungguSampai();
    if (tertahanSampai != null) {
      return HasilBukaKunci(
        berhasil: false,
        sisaPercobaan: 0,
        tungguSampai: tertahanSampai,
        pesan: 'Terlalu banyak percobaan salah. Coba lagi setelah '
            '${_jamMenit(tertahanSampai)}.',
      );
    }

    final garamTeks = await repo.baca(kunciKunciGaram);
    final turunanTeks = await repo.baca(kunciKunciTurunan);
    if (garamTeks == null || turunanTeks == null) {
      return const HasilBukaKunci(
        berhasil: true,
        pesan: 'Kunci belum dipasang.',
      );
    }
    final iterasi =
        int.tryParse(await repo.baca(kunciKunciIterasi) ?? '') ?? _iterasi;
    final garam = base64Decode(garamTeks);
    final turunanBenar = base64Decode(turunanTeks);
    final turunanCoba = _hitung(pin, garam, iterasi);

    if (_sama(turunanBenar, turunanCoba)) {
      await _bersihkanHitung();
      return const HasilBukaKunci(berhasil: true, pesan: 'Terbuka.');
    }

    final gagal = (await repo.bacaAngka(kunciKunciGagal, 0)) + 1;
    await repo.simpan(kunciKunciGagal, gagal.toString());
    if (gagal >= kunciPercobaanMaks) {
      final sampai =
          DateTime.now().add(const Duration(seconds: kunciTahananDetik));
      await repo.simpan(
          kunciKunciTungguSampai, sampai.millisecondsSinceEpoch.toString());
      await repo.simpan(kunciKunciGagal, '0');
      return HasilBukaKunci(
        berhasil: false,
        sisaPercobaan: 0,
        tungguSampai: sampai,
        pesan: 'PIN salah $kunciPercobaanMaks kali. Coba lagi setelah '
            '${_jamMenit(sampai)}.',
      );
    }
    return HasilBukaKunci(
      berhasil: false,
      sisaPercobaan: kunciPercobaanMaks - gagal,
      pesan: 'PIN salah. Sisa kesempatan ${kunciPercobaanMaks - gagal}.',
    );
  }

  Future<void> _bersihkanHitung() async {
    await repo.simpan(kunciKunciGagal, '0');
    await repo.hapusPengaturan(kunciKunciTungguSampai);
  }

  List<int> _buatGaram() =>
      List<int>.generate(16, (_) => _acak.nextInt(256));

  List<int> _hitung(String pin, List<int> garam, int iterasi) =>
      hitungPbkdf2(pin, garam, iterasi: iterasi);

  bool _sama(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var beda = 0;
    for (var i = 0; i < a.length; i++) {
      beda |= a[i] ^ b[i];
    }
    return beda == 0;
  }

  String _jamMenit(DateTime w) =>
      '${w.hour.toString().padLeft(2, '0')}.'
      '${w.minute.toString().padLeft(2, '0')}';
}

/// PIN yang tidak memenuhi syarat.
class ArgumenPinTidakSah implements Exception {
  const ArgumenPinTidakSah(this.pesan);
  final String pesan;

  @override
  String toString() => pesan;
}

/// PBKDF2-HMAC-SHA256 (dipakai PIN & bisa dipakai fitur lain).
List<int> hitungPbkdf2(String sandi, List<int> garam,
    {int iterasi = kunciIterasiBawaan, int panjang = 32}) {
  final hmac = Hmac(sha256, utf8.encode(sandi));
  final keluaran = <int>[];
  var blokKe = 1;
  while (keluaran.length < panjang) {
    final awal = <int>[
      ...garam,
      (blokKe >> 24) & 0xff,
      (blokKe >> 16) & 0xff,
      (blokKe >> 8) & 0xff,
      blokKe & 0xff,
    ];
    var u = hmac.convert(awal).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iterasi; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    keluaran.addAll(t);
    blokKe++;
  }
  return keluaran.sublist(0, panjang);
}
