# TUGAS SELANJUTNYA — PERSONAL LIFE OS (dari Papi, 13 Sep 2026)

Berkas pendamping di folder ini:
- **`PRD_PERSONAL_LIFE_OS_MASTER_v3.1.md`** — **satu-satunya PRD yang dipakai**: Bagian I = fondasi (PB-01…PB-16), Bagian II = seluruh fitur (FR-01…FR-152), Bagian III = arsitektur/roadmap. **§0 = keputusan Papi yang mengikat.**
- Dokumen lama (PRD v1.6, PRD Perbaikan, Blueprint) sudah dipindah ke `arsip/` — hanya rujukan, jangan dipakai sebagai acuan kerja.

## 1. Urutan yang WAJIB diikuti

**Fondasi (F0) dulu — sekarang dikerjakan AARON**, baru fitur baru.
Alasan: bug aksi notifikasi bisa **menandai lunas padahal pengguna hanya membuka notifikasi**, dan dasbor kehilangan histori setelah pembayaran. Fitur baru di atas fondasi ini hanya menambah data yang salah.

| Bagian | Siapa | Status |
|---|---|---|
| PB-01, PB-02, PB-03, PB-15, PB-16 (aksi notifikasi + uji jalur Android) | **Aaron** | ✅ selesai 13 Sep 2026 (88/88 uji lulus; uji mutasi membuktikan bug lama kini tertangkap) |
| PB-04 (tunda tahan sinkronisasi), PB-05/06/07 (indeks unik + idempotensi + migrasi v2), PB-08 (riwayat/occurrence untuk dasbor & kalender), PB-09/10/11 (keandalan penjadwalan), PB-12/13/14 (perbaikan kecil) | **Aaron** | sedang dikerjakan |
| V1.5 — 12 fitur: FR-60 Today · FR-61 Kartu Pilar · FR-62 Attention · FR-63 Morning Briefing · FR-68 Langganan · FR-71 Cashflow · FR-72 Budget · FR-76 Net Worth · FR-86 Jadwal Sholat · FR-87 Adzan & pengingat · FR-88 Pelacakan 5 waktu · FR-90 Kalender Hijriah | **Dinda** | mulai **setelah** fondasi diserahkan |

## 2. Aturan supaya tidak bertabrakan (PENTING)

Selama F0 berjalan, **JANGAN mengubah** berkas berikut (sedang dipegang Aaron):

```
lib/core/notifikasi/**            (model_pengingat, penangan_aksi_pengingat, layanan_notifikasi_lokal, penyinkron, perencana)
lib/data/**                       (tabel.dart, database.dart, repository/**)
lib/core/utils/waktu.dart
test/f3_pengingat_test.dart
test/f3_aksi_notifikasi_test.dart
android/gradle.properties
docs/**
```

Kalau Dinda perlu menyentuh berkas di atas, **tunggu penyerahan fondasi** (cara penyerahan: Aaron menyerahkan patch/branch + laporan uji; Papi yang mengizinkan).

## 3. Yang BOLEH Dinda mulai sekarang (tidak bertabrakan)

1. **Rancangan layar Today & struktur menu** (5 tab: Today · Uang · Kerja · Ibadah · Lainnya) — mockup/struktur widget, **tanpa** mengubah lapisan data.
2. **Riset sumber jadwal sholat & kalender Hijriah**: pilih pustaka/metode perhitungan, konvensi Ashar, sumber acuan Hijriah, dan **cara cache agar tetap tampil offline** (sesuai prinsip "offline dan online").
3. **Daftar kategori pengeluaran/pemasukan Indonesia** untuk FR-71/FR-72 (bahan awal Budget).
4. **Desain tabel database baru** (rancangan saja, belum migrasi): transaksi, anggaran, utang, aset, logSholat, logPuasa, dokumen, dll. — agar begitu fondasi selesai, eksekusi cepat.

## 4. Yang WAJIB dipatuhi (etika produk — §11 blueprint)

- **Jangan** membuat skor keimanan / menyimpulkan "belum sholat" hanya karena belum dicentang → pakai istilah **"selesai / belum tercatat"**.
- **Jangan** membuat diagnosis kesehatan, saran dosis obat, atau klaim medis.
- **Jangan** memberi nasihat investasi/produk keuangan.
- **Jangan** memakai kata "gagal" untuk kebiasaan/pelacakan pengguna — pakai "tercatat / belum tercatat".

## 5. Standar kerja (sama seperti sebelumnya)

1. Backup + commit sebelum mengubah kode; satu perubahan satu commit yang jelas.
2. `flutter analyze` bersih + `flutter test` hijau sebelum melaporkan selesai.
3. Setiap fitur wajib punya **kriteria terima** yang bisa diperiksa (ada di blueprint §7) + bukti uji nyata.
4. Laporan 3 poin: **berhasil apa · berkas mana · langkah lanjut**, plus catatan jujur bagian yang belum teruji.
5. Uji di HP Papi untuk hal yang menyangkut notifikasi/waktu nyata.

## 6. Kalau ada yang belum jelas

Jangan menebak. Tulis pertanyaannya (maksimal 3 butir sekaligus) dan tunggu keputusan Papi — Aaron yang meneruskan.

---
*Disusun oleh Aaron Salahuddin · 13 Sep 2026 · untuk Dinda*
