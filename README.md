# Personal Life OS

Asisten kehidupan pribadi (Android, Flutter): pengingat tagihan, keuangan, agendaris,
vault dokumen, dan rutinitas. Dikembangkan bertahap (fase F0–F8).

- **PRD:** `/workspace/prd-pengingat-tagihan/PRD_PERSONAL_LIFE_OS.md`
- **Laporan fase:** `/workspace/prd-pengingat-tagihan/LAPORAN_F*.md`

## Status saat ini
| Fase | Isi | Status |
|---|---|---|
| F1 | Fondasi: skema DB, CRUD + rollover, uji unit | ✅ selesai |
| F2 | UI inti: dasbor uang tersisa, daftar tagihan, form, kalender, pengaturan, tema, i18n id-ID | ✅ selesai (51 uji lulus) |
| F3 | Pengingat: notifikasi H-x, Workmanager, izin per merek | menunggu persetujuan Bapak |

## Menjalankan
```bash
# Siapkan lingkungan (bekas proyek mycampus)
export PATH=/workspace/tools/flutter/bin:/workspace/tools/flutter/bin/cache/dart-sdk/bin:/workspace/jdk-17.0.20.1+1/bin:$PATH
export JAVA_HOME=/workspace/jdk-17.0.20.1+1
export ANDROID_HOME=/workspace/android-sdk
export ANDROID_SDK_ROOT=/workspace/android-sdk

flutter pub get
flutter analyze          # harus: No issues found
flutter test             # harus: All tests passed
flutter run -d <device>  # jalankan di perangkat/emulator
flutter build apk --debug   # hasil: build/app/outputs/flutter-apk/app-debug.apk

# Tangkapan layar demo (butuh font Roboto dari Flutter SDK):
flutter test test/tangkapan_layar_test.dart --update-goldens
# hasil PNG: test/goldens/f2_*.png
```

## Struktur
- `lib/core/utils/` — logika murni (tanggal/rollover, uang) yang diuji unit
- `lib/data/model/` — enum & model
- `lib/data/database/` — tabel Drift, koneksi, migrasi, seed kategori
- `lib/data/repository/` — CRUD, aturan pelunasan, pengaturan, pengisi data contoh
- `lib/core/providers/` — provider Riverpod (database, repositori, pemasukan)
- `lib/features/` — layar per fitur: `ringkasan/`, `tagihan/`, `kalender/`, `pengaturan/`
- `lib/widgets/` — widget bersama (kartu tagihan)
- `lib/app_router.dart` — rute go_router + navigasi bawah 4 tab
- `demo/` — tangkapan layar demo (F1, F2)
- `test/` — uji unit + uji UI + pembuat tangkapan layar

## Aturan emas
1. Semua aturan tanggal memakai day-clamping (31 Jan → 28/29 Feb).
2. Data pengguna tinggal di perangkat (offline-first); tidak ada sinkronisasi wajib.
3. Setiap fase berakhir dengan demo + persetujuan sebelum fase berikutnya.
