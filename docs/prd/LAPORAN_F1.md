# LAPORAN FASE 1 — PERSONAL LIFE OS
**Tanggal:** 10 Sep 2026 (waktu riset mulai 9 Sep 2026) · **Disusun oleh:** Dinda
**Status:** ✅ Pekerjaan F1 tuntas — menunggu demo & persetujuan Bapak untuk lanjut F2
**Lokasi proyek:** `/workspace/personal-life-os` (Flutter 3.47.2 · Dart 3.13.2)
**Dokumen PRD rujukan:** `PRD_PERSONAL_LIFE_OS.md` v1.6 (Bab §11.3 fase F1)

---

## 1. Lingkup F1 menurut PRD
> F1 · Fondasi (±1–2 minggu): setup Flutter/Android, skema DB + migrasi,
> CRUD + template, uji unit logika tanggal/rollover.
> **Gate:** aplikasi bisa dibuka; uji unit logika tanggal lulus.

## 2. Yang sudah dikerjakan

### 2.1 Lingkungan pengembangan (bekas proyek mycampus — masih utuh)
| Komponen | Lokasi | Versi |
|---|---|---|
| Flutter SDK | `/workspace/tools/flutter` | 3.47.2 stable (revisi d3b14c87) |
| Dart SDK | bawaan Flutter | 3.13.2 |
| JDK | `/workspace/jdk-203.0.113.10+1` | Temurin 203.0.113.10 |
| Android SDK | `/workspace/android-sdk` | platform 34/35/36, build-tools 34 & 36 |

### 2.2 Struktur proyek (zero-biaya, offline-first)
```
lib/
├── main.dart                                  # kerangka aplikasi (F1)
├── core/utils/
│   ├── tanggal_utils.dart                     # aturan tanggal & frekuensi (pure)
│   └── uang_utils.dart                        # format & parsing Rupiah (pure)
└── data/
    ├── model/enums.dart                       # Frekuensi, KanalPengingat, Prioritas
    ├── database/
    │   ├── tabel.dart                         # 5 tabel Drift (skema v1)
    │   ├── database.dart                      # koneksi + migrasi + seed kategori
    │   └── database.g.dart                    # hasil generator (4.270 baris)
    └── repository/
        ├── tagihan_repository.dart            # CRUD + pelunasan/rollover
        └── template_tagihan.dart              # 7 template tagihan lokal (FR-05)
```

### 2.3 Skema database v1 (Drift/SQLite lokal)
| Tabel | Isi | Catatan penting |
|---|---|---|
| `Kategori` | 10 kategori bawaan penyedia Indonesia (PLN, PDAM, BPJS, internet, ponsel, kartu kredit, langganan, kendaraan, sekolah, rumah tangga) | FR-05 template lokal |
| `Tagihan` | nama, jumlah, jatuh tempo, frekuensi, lead pengingat, jam, kanal, prioritas, tautan bayar, status | kolom `kodeMataUang` (default IDR) & `kanalPengingat` (default push) sudah disiapkan untuk F7 — kolom `jenis` juga siap dipakai modul dokumen FR-53 |
| `RiwayatPembayaran` | periode yang dibayar, jumlah, tanggal, keterlambatan | bahan rekap tahunan FR-08 |
| `PemasukanBulanan` | pemasukan per bulan (YYYY-MM) | bahan konsep "uang tersisa" FR-33 |
| `Pengaturan` | kunci–nilai | pengaturan aplikasi |

### 2.4 Aturan bisnis inti (sudah teruji otomatis)
1. **Rollover day-clamping:** 31 Jan + 1 bulan → 28 Feb (2026) / 29 Feb (2028) — tidak pernah "tanggal hantu".
2. **Pelunasan:** catat riwayat → geser periode berikutnya; tagihan sekali → otomatis nonaktif.
3. **Undo pelunasan:** riwayat dihapus, periode kembali seperti semula.
4. **Keterlambatan** dihitung dan disimpan (telatHari).
5. **Total tagihan** dua sudut pandang: `totalBelumBayarBulanSen` (jendela bulan kalender) dan `totalTerbukaSen` (semua kewajiban terbuka).
6. **Parsing uang Indonesia:** `1.250.000`, `Rp 150.000`, `150rb`, `2jt`, `1.250,5` — semua dikenali benar.
7. **Parsing tanggal Indonesia:** ISO, `dd/MM/yyyy`, `dd-MM-yy`, `d MMMM yyyy`; tanggal mustahil (31/02) ditolak.

### 2.5 Template tagihan lokal (FR-05)
7 template siap pakai: Listrik PLN, Air PDAM, Internet rumah, BPJS Kesehatan,
Langganan streaming, Cicilan motor, Pajak kendaraan (STNK — lead 60/30/14/7/1 hari).
Bisa dipakai untuk mengisi aplikasi demo dengan sekali perintah.

## 3. Bukti (dijalankan, bukan klaim)
| Pemeriksaan | Perintah | Hasil |
|---|---|---|
| Analisis statis | `flutter analyze` | **No issues found** |
| Uji otomatis | `flutter test` | **38 uji lulus, 0 gagal** (25 uji tanggal/uang + 10 uji repository + 3 uji template lokal + 1 smoke widget) |
| DB di memori | `AppDatabase.forTesting(NativeDatabase.memory())` | seed 10 kategori terverifikasi |
| Build Android | `flutter build apk --debug` | ✅ **berhasil dalam 426 detik**. `build/app/outputs/flutter-apk/app-debug.apk` — 150,91 MB, SHA-256 `487401809fc2ea17a0284a72e94b394a…`, berisi AndroidManifest + classes.dex + 3 ABI (arm64-v8a, armeabi-v7a, x86_64) |

## 4. Catatan teknis & risiko
- **Kejadian file kosong:** `lib/core/utils/uang_utils.dart` sempat terbaca 0 byte (sama seperti insiden file PRD sebelumnya). Sudah dipulihkan dan diuji ulang. **Rekomendasi:** aktifkan pencadangan otomatis (git lokal) agar kejadian ini tidak berulang — saya usulkan `git init` + commit per fase (menunggu izin Bapak).
- Aplikasi masih berupa kerangka; UI sungguhannya masuk F2 (PRD §11.3), sesuai keputusan bertahap.
- Belum ada notifikasi (F3) dan belum ada paket pihak ketiga berbayar.

## 5. Hasil build & demo
- APK debug: `/workspace/personal-life-os/build/app/outputs/flutter-apk/app-debug.apk` (150,91 MB, siap dipasang).
  Cara pasang di ponsel Android: salin berkas → buka → izinkan "instal dari sumber tidak dikenal" → pasang → buka aplikasi.
  Catatan: APK debug memuat 3 arsitektur sekaligus sehingga besar; versi rilis (F4) akan jauh lebih kecil.
- Cara menjalankan sendiri di perangkat: lihat `README.md` proyek (bagian "Menjalankan").
- Karena kanal Telegram untuk kirim berkas belum aktif (tidak ada token di lingkungan ini), APK belum bisa saya kirim ke chat — bila Bapak mau, saya bisa mengaktifkannya atau Bapak menarik berkasnya dari workspace.

### 5.1 Tangkapan layar demo (pratinjau web)
- Berkas: `/workspace/personal-life-os/demo/demo_f1.png` (840×1800 px, pratinjau 420×900 @2x)
- Cara dibuat: `flutter build web --release` → disajikan di port lokal → tangkapan layar Chromium headless
- Verifikasi terukur: latar tema Material 3 (247,251,241), teks gelap (25,29,23), ikon hijau tema (46,125,50 = #2E7D32) → **UI benar-benar ter-render**, bukan halaman kosong
- Pratinjau web ini hanya untuk demo; target rilis tetap Android.

## 6. Gate F1 — yang saya minta dari Bapak
1. **Setujui F1 selesai** (berdasarkan bukti bagian 3–5) → saya lanjut **F2: UI aplikasi** (daftar tagihan, tambah/ubah, kalender, dasbor "uang tersisa").
2. **Izin `git init` + commit** untuk perlindungan kode (mencegah kejadian file kosong).
3. (Opsional) preferensi warna/tema aplikasi agar F2 langsung sesuai selera Bapak.
