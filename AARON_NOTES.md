# CATATAN PROYEK — AARON (penyempurnaan Personal Life OS)

**Pemilik jalur ini:** Aaron Salahuddin (agen keamanan & rekayasa, Bapak Sami'an)
**Dibuat:** 12 September 2026 · 08:35 UTC (15:35 WIB / 16:35 MYT)

## Aturan pemisahan (perintah Papi)
- Proyek **Dinda** (asli): `/workspace/personal-life-os` di dalam container `prime-agent-hub` (volume Docker
  `prime-agent-hub_prime-workspace`). **Aaron TIDAK menulis ke sini.**
- Proyek **Aaron** (jalur penyempurnaan): **`/home/aaron/lifeos-penyempurnaan`** di server Contabo
  `217.216.109.229`. Ini salinan terpisah; semua pekerjaan penyempurnaan dikerjakan di sini.

## Titik tolak salinan
- Disalin dari commit Dinda **`c945f33`** ("F3 tuntas: pengingat & notifikasi …"), 336 berkas,
  tanpa `build/`, `.dart_tool/`, `android/.gradle/`, `android/.kotlin/`.
- Cabang kerja Aaron: **`aaron/penyempurnaan`** (riwayat Dinda tetap utuh di cabang lain).
- Kalau Dinda melanjutkan F4 dan mau digabung: bandingkan dengan
  `git diff aaron/penyempurnaan..origin/<milik-Dinda>` — jangan saling menimpa.

## Lingkungan build khusus Aaron (terpisah dari hub Dinda)
Container build sendiri: **`aaron-lifeos-build`** (image `prime-agent-hub-prime-agent:latest`, tidak
menjalankan aplikasi hub, hanya alat build). Mount:

| Di container | Dari host | Isi |
|---|---|---|
| `/proyek` | `/home/aaron/lifeos-penyempurnaan` | sumber proyek Aaron |
| `/opt/tools` | volume hub `…/tools` | Flutter 3.47.2 (read/write, cache SDK) |
| `/opt/jdk` | volume hub `…/jdk-17.0.20.1+1` | JDK 17 |
| `/opt/android-sdk` | volume hub `…/android-sdk` | Android SDK 36 |
| `/root/.gradle` | `/home/aaron/.lifeos-gradle` | cache Gradle (tahan restart) |
| `/root/.pub-cache` | `/home/aaron/.lifeos-pubcache` | cache Dart (tahan restart) |

**Proyek Dinda tidak di-mount** ke container ini → tidak mungkin tersentuh dari jalur Aaron.

### Perintah kerja
```bash
ssh aaron@217.216.109.229
sudo -n docker exec -it aaron-lifeos-build bash -lc '
  cd /proyek
  export JAVA_HOME=/opt/jdk ANDROID_HOME=/opt/android-sdk ANDROID_SDK_ROOT=/opt/android-sdk
  export PATH=/opt/tools/flutter/bin:/opt/tools/flutter/bin/cache/dart-sdk/bin:/opt/jdk/bin:$PATH
  flutter pub get
  flutter analyze
  flutter test
  flutter build apk --release --split-per-abi     # APK kecil per arsitektur
'
```
Hentikan container bila tidak dipakai (hemat RAM): `sudo -n docker stop aaron-lifeos-build`.

## Cadangan
- Cadangan berkala kode: `/home/aaron/backups/lifeos/` (tar.gz) + riwayat git di repo.
- APK hasil build dikirim ke Papi lewat Telegram; salinan lokal di `/opt/data/lifeos/` (komputer agent).

## Keadaan awal (verifikasi 12 Sep 2026)
- `flutter analyze` di salinan: bersih.
- 74 uji fungsi lulus; 6 uji tangkapan layar gagal karena `DateTime.now()` (golden direkam 10 Sep) → akan diperbaiki di jalur ini.
- APK release 62 MB (3 arsitektur) dibangun; versi per-arsitektur sedang disiapkan (±20 MB).
- Belum siap Play Store: masih ditandatangani debug key, belum ada App Bundle/kebijakan privasi.

## Rencana (disetujui Papi 12 Sep 2026)
- **Paket A:** widget interaktif, aksi cepat ikon & panel cepat, "Bagikan ke Life OS" (OCR), backup otomatis
  + pindah HP via QR, APK kecil & siap Play.
- **Paket B:** kartu kredit (cetak vs jatuh tempo), pos dana, peta bulan berat, amplop anggaran,
  cocokkan mutasi, arsip bukti bayar + laporan bulanan.
- **Paket C:** enkripsi database + biometrik + blokir screenshot, modul Life Engine, mode rumah tangga,
  input suara/Telegram, rapikan QC.
