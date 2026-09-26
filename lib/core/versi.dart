/// Satu sumber kebenaran versi aplikasi (dipakai layar Tentang + nomor build).
///
/// Naikkan [versiAplikasi] & [nomorBuild] setiap kali APK baru dikirim ke Papi
/// supaya bisa dibedakan di HP: build lama vs build baru. `version:` di
/// `pubspec.yaml` WAJIB sama (itu yang mengalir ke versionName/versionCode
/// Android) — ada uji penjaga (`test/v3_audit_penjaga_test.dart`) yang
/// menggagalkan build bila keduanya tidak sinkron, supaya label versi di layar
/// tidak pernah berbohong.
library;

/// Versi yang tampil ke pengguna.
const String versiAplikasi = '1.14.2';

/// Nomor build (harus sama dengan versionCode di android/app/build.gradle.kts,
/// yang diambil dari `version:` di pubspec.yaml).
const int nomorBuild = 19;

/// Keterangan jalur pengembangan (bukan nomor versi).
const String jalurPengembangan = 'V3';
