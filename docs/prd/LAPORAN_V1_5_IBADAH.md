# LAPORAN V1.5 — IBADAH (FR-86 Jadwal Sholat & FR-90 Kalender Hijriah)

Tanggal: 13 September 2026 (malam) · Dikerjakan oleh: Dinda
Dasar: `PRD_PERSONAL_LIFE_OS_MASTER_v3.0.md` §0 (perintah Boss: "baca PRD ini dan eksekusi")

## 1. Ringkasan
Dua fitur V1.5 sudah jadi, teruji, dan tampil di aplikasi:

| ID | Fitur | Status | Bukti |
|----|-------|--------|-------|
| FR-86 | Jadwal Sholat (6 waktu, 48 kota, 2 metode) | **SELESAI** | 7 berkas baru, uji hijau |
| FR-90 | Kalender Hijriah (2 acuan, koreksi hari, hari besar) | **SELESAI** | uji hijau |
| FR-88 | Pelacakan 5 waktu sholat | **BELUM** (menunggu fondasi Aaron: `lib/data/**`) | - |
| FR-87 | Adzan (suara + notifikasi) | **BELUM** (menunggu `lib/core/notifikasi/**` milik Aaron) | - |

Sengaja hanya menyentuh berkas BARU + 3 berkas milik Dinda (`app_router.dart`,
`pengaturan_screen.dart`, `pubspec.yaml`). Tidak ada berkas milik Aaron yang diubah.

## 2. Berkas yang dibuat
| Berkas | Ukuran | Baris |
|--------|--------|-------|
| `lib/core/ibadah/model_sholat.dart` | 7.936 B | 234 |
| `lib/core/ibadah/penghitung_sholat.dart` | 7.464 B | 228 |
| `lib/core/ibadah/kalender_hijriah.dart` | 9.142 B | 270 |
| `lib/core/ibadah/kota_indonesia.dart` | 6.826 B | 76 |
| `lib/core/ibadah/penyimpanan_jadwal.dart` | 5.880 B | 174 |
| `lib/features/ibadah/jadwal_sholat_screen.dart` | 15.346 B | 451 |
| `lib/features/ibadah/kalender_hijriah_screen.dart` | 9.533 B | 291 |
| **Total** | **62.127 B** | **1.724** |

Diubah (milik Dinda): `lib/app_router.dart` (+2 rute: `/ibadah/jadwal-sholat`,
`/ibadah/kalender-hijriah`), `lib/features/pengaturan/pengaturan_screen.dart`
(bagian "Ibadah" + versi 0.4.0), `pubspec.yaml` (+`adhan_dart: ^2.0.1`,
+`hijri_core: ^1.1.0`).

## 3. Berkas uji
| Berkas | Ukuran | Baris | Uji |
|--------|--------|-------|-----|
| `test/ibadah_sholat_test.dart` | 18.771 B | 483 | 30 |
| `test/ibadah_ui_test.dart` | 13.682 B | 330 | 11 |
| **Total** | **32.453 B** | **813** | **41** |

## 4. Cara hitung & bukti akurasi
- Pustaka: `adhan_dart 2.0.1` (MIT, tanpa dependensi lain, hitung di perangkat) dan
  `hijri_core 1.1.0` (MIT, acuan bisa dipilih).
- Preset sudut TIDAK dikarang: memakai bawaan pustaka
  (`CalculationMethodParameters.indonesian()` = Subuh 20°, Isya 18°).
- `adhan_dart` mengembalikan waktu sebagai **instan UTC**. Aplikasi menambah
  offset zona tetap (WIB +7, WITA +8, WIT +9) untuk waktu dinding kota.
- Pembanding luar: **Aladhan API** (metode 20 = KEMENAG, metode 3 = MWL) untuk
  tanggal 13 September 2026:

| Kota | KEMENAG (API) | Hasil aplikasi | Beda | MWL (API) | Hasil aplikasi | Beda |
|------|---------------|----------------|------|-----------|----------------|------|
| Jakarta | 04:30 / 11:49 / 15:03 / 17:50 / 18:59 | 04:30 / 11:50 / 15:04 / 17:50 / 18:59 | ≤1 menit | 04:38 … 18:55 | 04:38 … 18:55 | ≤1 menit |
| Makassar | 04:39 / 11:58 / 15:11 / 18:00 / 19:09 | 04:39 / 11:59 / 15:12 / 18:00 / 19:09 | ≤1 menit | 04:47 … 19:05 | 04:47 … 19:05 | ≤1 menit |

Uji memakai toleransi **±2 menit** dan mencatat selisihnya apa adanya.
Ashar madzhab Hanafi (Jakarta): **16:07** vs Syafii **15:04** — sesuai hitungan fikih.
- 48 kota diambil dari **Open-Meteo Geocoding** (data hidup, bukan karangan);
  Palangka Raya & Tanjungpinang ditambahkan, hanya "Palangka Raya" tidak
  ditemukan pada pencarian pertama.
- Hijriah: acuan bawaan **Umm al-Qura** (bisa diganti **FCNA/aritmetik**),
  koreksi hari −2…+2 menit [hari]. Contoh terverifikasi: 1 Ramadhan 1447 H =
  **18 Februari 2026** (UAQ) vs **19 Februari 2026** (FCNA).

## 5. Bug nyata yang ditemukan uji (dan sudah diperbaiki)
1. **Dropdown metode meluber 31 px** pada layar 420×900 → ditambah `isExpanded: true`.
2. **Sel kalender meluber 0,8 px dan 11 px** di layar HP → isi sel dibungkus
   `FittedBox(scaleDown)` agar menyesuaikan ukuran.
3. **Tanggal Hijriah "hari ini" memakai tanggal UTC** → jam 06.00 WIB akan
   terbaca tanggal kemarin. Diperbaiki: memakai tanggal sipil jam perangkat.
4. **Uji UI menggantung** karena operasi berkas asinkron di dalam `testWidgets`
   (zona waktu palsu) → folder sementara dibuat sinkron.
5. Zona salah pada pembuat daftar kota: Pontianak & Palangka Raya sempat
   tertulis WIT, seharusnya WIB → diperbaiki.

## 6. Kejujuran batas (penting)
- Hasil adalah **perhitungan, bukan jadwal resmi** Kementerian Agama. Selisih
  yang terukur 0–2 menit. Label ini tampil di layar.
- Awal bulan Hijriah bisa berbeda dari **penetapan pemerintah**; karena itu ada
  pilihan acuan dan koreksi hari, plus catatan di layar.
- **Tanpa GPS.** Kota dipilih manual dari 48 kota (keputusan sadar: menghindari
  plugin lokasi yang menambah izin & perubahan berkas native).
- **Belum diuji di HP sungguhan** oleh saya (tidak ada perangkat/emulator di
  lingkungan ini). Yang sudah terbukti: 41 uji otomatis hijau, `flutter analyze`
  bersih, dan tangkapan layar ter-render tanpa garis meluber (0 piksel kuning).
- **FR-87 (adzan) dan FR-88 (pelacakan 5 waktu)** belum bisa dikerjakan karena
  butuh berkas milik Aaron (`lib/core/notifikasi/**`, `lib/data/**`) yang belum
  masuk.

## 7. Tangkapan layar
- `demo/f4_jadwal_sholat.png` (1.260×2.700)
- `demo/f4_kalender_hijriah.png` (1.260×2.700)
Tangkapan layar lama (`f2_*`, `f3_pengingat`) dibuat ulang karena bergantung
tanggal (dibuat 10 Sep, sekarang 13 Sep), dan layar Pengaturan memang berubah.

## 8. Yang diminta putusan Boss
1. Acuan Hijriah bawaan **Umm al-Qura** — cukup, atau minta tambahan tabel
   penetapan Indonesia?
2. Bolehkah menulis label "kriteria Kemenag" (sudut 20°/18°) di layar, atau
   cukup "metode Indonesia"?
3. Tetap **pilih kota manual**, atau tambah **GPS** (butuh plugin + izin baru)?
