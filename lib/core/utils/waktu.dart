/// Sumber waktu tunggal untuk seluruh aplikasi.
///
/// Bagian yang menampilkan "hari ini" (ringkasan, kalender, pengaturan,
/// perencana pengingat) membaca waktu lewat [waktuSekarang] — bukan
/// `DateTime.now()` langsung. Dengan begitu pengujian (termasuk tangkapan
/// layar/golden) dapat mengunci waktu sehingga hasilnya tidak berubah saat
/// tanggal berganti, sementara aplikasi tetap memakai jam sistem.
library;

DateTime Function() _sumber = DateTime.now;

/// Waktu sekarang menurut sumber yang sedang aktif.
DateTime waktuSekarang() => _sumber();

/// Pakai sumber waktu lain — hanya dipakai pengujian.
void pakaiSumberWaktu(DateTime Function() sumber) => _sumber = sumber;

/// Kembalikan ke jam sistem.
void pakaiWaktuAsli() => _sumber = DateTime.now;
