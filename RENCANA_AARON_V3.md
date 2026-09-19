# RENCANA KERJA AARON — PERSONAL LIFE OS (V3)

Disusun: Aaron (Ron) · 19 Sep 2026 — atas perintah Papi: **"AMBIL ALIH TOTAL, SEKARANG AARON YANG KERJAKAN SEMUA"**.

## 0. Status pengambilalihan

| Butir | Keadaan |
|---|---|
| Basis kerja Ron | `/home/aaron/lifeos-aaron` — clone REPO DINDA penuh, commit `75b74e3` |
| Cabang kerja | `aaron/v3` (jalur Ron; repo Dinda TIDAK disentuh, tetap utuh di `/workspace/personal-life-os`) |
| Dokumen & PRD | Disalin lengkap: `/home/aaron/lifeos-docs/prd-pengingat-tagihan/` (31 berkas) → salinan Ron `/opt/data/lifeos/dinda_handover_full/` |
| Cadangan mentah | `/home/aaron/backups/lifeos/dinda_full_20260919.tar.gz` (208 MB: repo + semua dokumen) |
| Container build | `aaron-lifeos-build` (mount toolchain `/opt/hub-toolchain`, repo baru di `/proyek`) |
| Bukti basis bersih | `flutter analyze lib test` = **No issues found** · `flutter test` = **778 lulus / 0 gagal** |

Aturan kerja Ron pada proyek ini:
1. Repo dan folder Dinda **tidak disentuh** — semua kerja di jalur Ron.
2. Setiap batch: `flutter analyze` bersih + seluruh uji hijau + potret golden deterministik sebelum dilaporkan.
3. Tiap batch selesai → APK arm64 `--release` dikirim ke Papi untuk uji di HP (gate akhir tetap HP Papi).
4. Jujur: apa yang belum/tidak bisa dibuktikan di server ditulis apa adanya di laporan.

## 1. Hitungan saat ini (per dokumen status Dinda 17 Sep, sudah diverifikasi Ron)

- SELESAI: 58 · SEBAGIAN: 7 · BELUM: 87 → **94 baris kerja** untuk Ron.

## 2. Urutan batch

| Batch | Isi | ID |
|---|---|---|
| **A** (sekarang) | Langganan & uang lanjutan (fondasi sudah ada) | FR-69, FR-70, FR-138 |
| **B** | Modul Today & Aksi/Goal sisa | FR-64, FR-66, FR-81, FR-82, FR-85 |
| **C** | Serahan V1.5 yang masih "sebagian" | FR-65, FR-67, FR-89 |
| **D** | Islamic lanjutan | FR-94, FR-96, FR-97, FR-98 |
| **E** | Health OS lanjutan (12) | FR-104, 105, 107, 108, 109, 110, 112, 113, 114, 115, 116, 117 |
| **F** | Aksi/Health berat (perlu keputusan Papi dulu: FR-84 data tidur/energi) | FR-84 + sisa B |
| **G** | Knowledge / Home-Asset / Dokumen / Family / Travel (16) | FR-118…127, FR-130…135 |
| **H** | Fitur lama P0–P1 (23) | FR-07, 21, 22, 25, 26, 27, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 43, 45, 49, 53, 54 |
| **I** | Platform & Intelligence OS (11) — AI Copilot wajib lewat server sendiri (butuh keputusan Papi) | FR-140…146, 149…152 |
| **J** | Fitur lama sisa kecil (16) | FR-09, 17, 42, 44, 46, 47, 48, 50, 51, 52, 55, 56, 57, 58, 59 |

## 3. Yang menunggu keputusan Papi (bukan penghalang batch lain)

1. **Utang dihapus** → riwayat pembayarannya ikut dihapus atau disimpan? (temuan Dinda, belum diputuskan)
2. **Kunci enkripsi dokumen** (FR-108/FR-128) — cara pulihkan kalau HP hilang.
3. **Sinkron antar HP** (FR-27) — pakai server Papi atau penyimpanan pilihan pengguna?
4. **AI Copilot** (FR-152) — §0 PRD: wajib lewat server sendiri (bukan kunci API di aplikasi).
5. **Play Store** — butuh keystore rilis + akun.

## 4. Bukti per batch

Setiap batch ditulis di berkas ini: perintah uji yang dijalankan, hasil nyata, berkas yang berubah, dan apa yang belum.

| Batch | Keadaan | Commit | Bukti |
|---|---|---|---|
| **A1 — FR-69, FR-70** | SELESAI | `c1694d2` | analyze bersih; 786 uji hijau (8 uji baru) |
| **A2 — FR-138** | SELESAI | `6188bab`, `064a9d5` | audit modul uang, kategori, langganan, kesehatan; 11 uji baru; total **797 uji hijau** |
| B — FR-64, FR-66, FR-81, FR-82, FR-85 | belum mulai | — | — |

Catatan teknis A2:
* penulisan catatan audit diletakkan di **lapisan layar** (bukan repository) — pola yang
  sama dengan modul tagihan, karena dua tulisan drift ber-`await` dalam satu
  `tester.runAsync` membuat uji widget menggantung;
* `ModulAudit.kategori` ditambahkan supaya catatan kategori punya nama modul sendiri
  (saringan layar Catatan Aktivitas memakai `ModulAudit.semua`).

