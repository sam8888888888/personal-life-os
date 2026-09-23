/// FR-26 — Kunci aplikasi (PIN / kunci perangkat) untuk data sensitif.
///
/// Aturan yang dipegang di sini (diperketat 23 Sep 2026 setelah audit):
/// * PIN **tidak pernah disimpan apa adanya** — hanya turunan PBKDF2-HMAC-SHA256
///   (garam acak + banyak putaran) yang disimpan.
/// * Garam & turunan disimpan lewat **brankas Keystore** (`lifeos/rahasia`),
///   bukan di tabel `pengaturan` polos. Akibatnya salinan basis data saja
///   (cadangan/Google Drive/HP yang di-root) **tidak cukup** untuk menebak PIN
///   secara luring: kuncinya ada di Android Keystore yang tidak bisa diekspor.
/// * PIN paling sedikit **6 angka** (10^6 kemungkinan) dan PBKDF2 memakai
///   **600.000 putaran** (selaras rekomendasi OWASP 2023). PIN 4 angka dengan
///   60.000 putaran bisa dibobol di bawah satu menit dengan GPU konsumen.
/// * Salah PIN berkali-kali → percobaan ditahan sementara (bukan dikunci
///   selamanya, bukan pula dibiarkan bebas).
/// * Bila bahan kunci HILANG padahal kunci sedang aktif → aplikasi **TIDAK
///   terbuka diam-diam** (fail-closed). Pengguna diberi tahu dan bisa mengatur
///   ulang PIN; data tidak dihapus.
/// * Kunci ini menahan **tampilan**, bukan menyandikan basis data.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../data/repository/pengaturan_repository.dart';
import '../platform/brankas_rahasia.dart';

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

/// Panjang PIN paling pendek yang diterima (audit P1-2: 4 angka terlalu mudah).
const int kunciPanjangMin = 6;

/// Panjang PIN paling panjang (menjaga agar tidak jadi sandi).
const int kunciPanjangMaks = 12;

/// Putaran PBKDF2 bawaan. Uji memakai angka kecil supaya cepat.
const int kunciIterasiBawaan = 600000;

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
    this.rusak = false,
  });

  /// Benar bila PIN diterima.
  final bool berhasil;

  /// Sisa kesempatan sebelum ditahan sementara.
  final int sisaPercobaan;

  /// Bila tidak null, percobaan berikutnya baru diterima setelah waktu ini.
  final DateTime? tungguSampai;

  /// Keterangan apa adanya untuk pengguna.
  final String? pesan;

  /// Bahan kunci hilang/tidak terbaca padahal kunci sedang aktif: aplikasi
  /// TIDAK terbuka, dan pengguna ditawari mengatur ulang PIN.
  final bool rusak;

  bool get tertahan => tungguSampai != null;
}

/// Kunci aplikasi (FR-26).
class KunciAplikasi {
  KunciAplikasi(this.repo, {Random? acak, int? iterasi, PenyimpanRahasia? rahasia})
      : _acak = acak ?? Random.secure(),
        _iterasi = iterasi ?? kunciIterasiBawaan {
    _rahasia = rahasia ?? PenyimpanRahasia(repo);
  }

  final PengaturanRepository repo;
  final Random _acak;
  final int _iterasi;

  /// Penyimpan garam & turunan PIN (brankas Keystore bila tersedia).
  late final PenyimpanRahasia _rahasia;

  /// Apakah bahan kunci benar-benar tersimpan terenkripsi di perangkat ini.
  Future<bool> rahasiaTerlindungi() => _rahasia.tersedia();

  /// Apakah kunci sedang dipakai.
  Future<bool> aktif() async {
    final ada = await repo.bacaSaklar(kunciKunciAktif);
    if (!ada) return false;
    final turunan = await _rahasia.baca(kunciKunciTurunan);
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
  /// [bukaPerangkat] = izin membuka dengan kunci perangkat HP.
  Future<void> pasangPin(String pin,
      {bool bukaPerangkat = false}) async {
    final keluhan = keluhanPin(pin);
    if (keluhan != null) throw ArgumenPinTidakSah(keluhan);
    final garam = _buatGaram();
    final turunan = _hitung(pin, garam, _iterasi);
    await _rahasia.simpan(kunciKunciGaram, base64Encode(garam));
    await _rahasia.simpan(kunciKunciTurunan, base64Encode(turunan));
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
    await _rahasia.hapus(kunciKunciTurunan);
    await _rahasia.hapus(kunciKunciGaram);
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

    final garamTeks = await _rahasia.baca(kunciKunciGaram);
    final turunanTeks = await _rahasia.baca(kunciKunciTurunan);
    if (garamTeks == null || turunanTeks == null) {
      // FAIL-CLOSED: kalau kunci sebenarnya aktif tetapi bahan kuncinya tidak
      // ada, aplikasi TIDAK terbuka diam-diam (dulu: `berhasil: true`, sehingga
      // menghapus baris `kunci_turunan` langsung membuka aplikasi).
      final sedangAktif = await repo.bacaSaklar(kunciKunciAktif);
      if (sedangAktif) {
        return const HasilBukaKunci(
          berhasil: false,
          rusak: true,
          pesan: 'Kunci aplikasi aktif, tetapi bahan kuncinya tidak bisa '
              'dibaca di perangkat ini. Aplikasi tidak dibuka otomatis. '
              'Atur ulang PIN untuk masuk kembali — data Anda tidak dihapus.',
        );
      }
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
      await _pindahkanKeBrankas();
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

  /// Pindahkan bahan kunci lama yang masih tersimpan polos di tabel
  /// `pengaturan` ke brankas Keystore (dijalankan setelah PIN benar).
  Future<void> _pindahkanKeBrankas() async {
    if (!await _rahasia.tersedia()) return;
    for (final nama in const [kunciKunciTurunan, kunciKunciGaram]) {
      if (await _rahasia.baca(nama) == null) {
        await _rahasia.pindahkanKeBrankas(nama);
      }
    }
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
