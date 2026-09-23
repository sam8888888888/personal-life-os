# Persiapan Rilis ke Play Store — Personal Life OS

Disusun 23 Sep 2026 sebagai tindak lanjut audit kode eksternal. Keadaan ditulis apa adanya:
apa yang sudah siap, apa yang masih harus dikerjakan **di luar kode** (akun Play, formulir,
kebijakan), dan apa yang hanya bisa diuji di perangkat.

## 1 · Sudah beres di dalam kode

| Butir | Keadaan | Berkas bukti |
|---|---|---|
| Kunci rilis (bukan kunci debug) | build membaca `android/key.properties`; contoh + cara membuat keystore ada di `android/key.properties.example` | `android/app/build.gradle.kts` |
| Cadangan otomatis Android dimatikan | `allowBackup="false"`, `dataExtractionRules`, larangan pindah-perangkat | `AndroidManifest.xml`, `res/xml/data_extraction_rules.xml` |
| Wajib HTTPS | `usesCleartextTraffic="false"` + `networkSecurityConfig` | `res/xml/network_security_config.xml` |
| Izin jaringan untuk sinkron & AI (opsional) | `INTERNET` ada di manifest UTAMA (dulu hanya di build debug) | `AndroidManifest.xml` |
| Izin SMS benar-benar hilang dari kode | tidak ada `READ_SMS` di `lib/` maupun `android/`; uji penjaga memindai keduanya | `test/v3_audit_penjaga_test.dart` |
| ukuran & obfuscation | `isMinifyEnabled`, `isShrinkResources`, aturan keep ML Kit | `android/app/proguard-rules.pro` |
| `minSdk`/`targetSdk` dipatok | 24 (Android 7) / 36 (Android 16) | `android/app/build.gradle.kts` |
| FileProvider dipersempit | hanya subfolder `bagikan/` | `res/xml/berkas_paths.xml` |
| Rahasia tidak polos di basis data | token akun, kunci AI, turunan PIN lewat brankas Keystore | `BrankasRahasia.kt`, `lib/core/platform/brankas_rahasia.dart` |
| Cadangan terenkripsi | AES-256-GCM + PBKDF2 600.000 putaran | `lib/core/backup/ekspor_impor.dart` |
| Rute aplikasi tidak bisa dipicu aplikasi lain | daftar putih rute di MainActivity | `MainActivity.kt` |

## 2 · Harus dikerjakan di akun Play Console (bukan kode)

1. **Play App Signing** dinyalakan: bentuk rilis = **AAB** (bukan APK). Play memangkas
   pustaka CPU per perangkat, sehingga unduhan jauh lebih kecil daripada APK universal.
2. **Formulir Data Safety** — isi jujur:
   - Data pribadi & keuangan **tidak dikumpulkan ke server kami** (tersimpan di perangkat,
     terenkripsi; cadangan awan Android dimatikan).
   - **Perkecualian yang WAJIB disebut**: bila pengguna menyalakan **AI Copilot** atau
     **sinkron akun** (keduanya opsional dan mati secara bawaan), ringkasan data yang
     diperlukan dikirim ke layanan pihak ketiga: penyedia AI (DeepSeek) dan server sinkron
     milik pemilik. Data kesehatan & dokumen keluarga TIDAK pernah dikirim ke mana pun.
   - Tidak ada iklan, tidak ada pelacak, tidak ada penjualan data.
3. **Kebijakan privasi publik** — wajib karena aplikasi memuat data kesehatan. Isinya harus
   memuat butir (2) apa adanya + cara menghapus data (aplikasi menyediakan hapus semua data
   di layar Pengaturan; data tidak bisa dipulihkan setelahnya).
4. **Rating konten** + mulai **closed testing** (jalur pengujian tertutup) karena akun
   pribadi pengembang baru wajib menjalani periode pengujian sebelum produksi.
5. **Penjelasan izin `SCHEDULE_EXACT_ALARM` (Android 14+)** — naskah siap pakai:
   > Aplikasi ini adalah pengingat tagihan dan pengingat obat. Pengguna memilih sendiri jam
   > pengingatnya (mis. H-1 pukul 08.00 atau jam minum obat). Pengingat harus muncul pada jam
   > itu; pergeseran beberapa jam membuat pengingat tagihan/obat tidak berguna. Izin ini hanya
   > dipakai untuk menjadwalkan pengingat yang dibuat pengguna sendiri, tidak untuk apa pun
   > yang lain.
   Jika ditolak Play, alternatifnya alarm tidak-tepat (inexact) dengan konsekuensi pengingat
   bisa bergeser beberapa menit — perubahan kode diperlukan, dan itu keputusan pemilik.
6. **`targetSdk`** sudah 36; perbarui setiap Play menaikkan syarat minimum.

## 3 · Yang hanya bisa dibuktikan di perangkat nyata

- Pemasangan APK/AAB rilis bertanda tangan kunci baru (bila aplikasi lama masih terpasang
  dengan kunci lain, harus **dihapus dulu** — data lokal ikut hilang, jadi cadangkan dulu).
- Lampiran berkas pada brankas catatan medis (kanal Keystore) benar-benar menyimpan & membaca.
- Notifikasi terjadwal benar-benar berbunyi saat aplikasi tertutup dan setelah HP dinyalakan ulang.
- Perilaku saat perangkat **tidak punya kamera, tidak punya kompas, dan tidak punya keystore**
  (aplikasi harus tetap jalan dan mengatakan keterbatasannya, bukan gagal senyap).
- Ukuran & kinerja APK setelah `minify` + `shrinkResources` (R8 bisa memangkas terlalu banyak
  kalau aturan keep kurang — ini risiko yang harus diuji, bukan diandaikan aman).

## 4 · Perintah build yang dipakai

```bash
# APK uji di HP (semua pustaka CPU dipertahankan — perintah pemilik)
flutter build apk --release --target-platform android-arm,android-arm64,android-x64

# Bentuk untuk Play Store
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols

# Unggah build/symbols/ ke tempat aman (JANGAN ke repo) supaya jejak galat
# produksi masih bisa dibaca.
```

Verifikasi sebelum dikirim:

```bash
aapt2 dump permissions <berkas>.apk | grep -c READ_SMS     # harus 0
aapt2 dump permissions <berkas>.apk | grep INTERNET        # harus ada
apksigner verify --print-certs <berkas>.apk                # kunci RILIS, bukan debug
```
