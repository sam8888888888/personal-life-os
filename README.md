# Personal Life OS

Asisten kehidupan pribadi (Android, Flutter): pengingat tagihan, keuangan, agendaris,
vault dokumen, dan rutinitas. Dikembangkan bertahap (fase F0–F8).

- **PRD:** `/workspace/prd-pengingat-tagihan/PRD_PERSONAL_LIFE_OS.md`
- **Laporan fase:** `/workspace/prd-pengingat-tagihan/LAPORAN_F*.md`

## Status saat ini
| Fase | Isi | Status |
|---|---|---|
| F1 | Fondasi: skema DB, CRUD + rollover, uji unit | ✅ selesai (35 uji lulus) |
| F2 | UI aplikasi (daftar, tambah/ubah, kalender, dasbor) | menunggu persetujuan |

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
```

## Struktur
- `lib/core/utils/` — logika murni (tanggal/rollover, uang) yang diuji unit
- `lib/data/model/` — enum & model
- `lib/data/database/` — tabel Drift, koneksi, migrasi, seed kategori
- `lib/data/repository/` — CRUD & aturan pelunasan
- `test/` — uji unit + smoke test

## Aturan emas
1. Semua aturan tanggal memakai day-clamping (31 Jan → 28/29 Feb).
2. Data pengguna tinggal di perangkat (offline-first); tidak ada sinkronisasi wajib.
3. Setiap fase berakhir dengan demo + persetujuan sebelum fase berikutnya.
