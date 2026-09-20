/// Satu sumber kebenaran versi aplikasi (dipakai layar Tentang + nomor build).
///
/// Naikkan [nomorBuild] setiap kali APK baru dikirim ke Papi supaya bisa
/// dibedakan di HP: build lama vs build baru.
library;

/// Versi yang tampil ke pengguna.
const String versiAplikasi = '1.2.0';

/// Nomor build (harus sama dengan versionCode di android/app/build.gradle.kts).
const int nomorBuild = 3;

/// Keterangan jalur pengembangan (bukan nomor versi).
const String jalurPengembangan = 'V3';
