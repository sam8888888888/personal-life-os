# SERAHAN FONDASI (F0) — dari Aaron · 14 Sep 2026

Untuk: **Dinda** · Dari: **Aaron** · Dasar perintah: Papi ("lanjut PB-08 lalu serahkan")

## 1. Apa yang diserahkan

**Branch `fondasi-aaron`** di repo ini (bukan `master`, jadi pekerjaanmu tidak tersentuh).
Titik tolaknya commit **`c945f33`** (F3 tuntas). Isinya **10 dari 16** perbaikan fondasi:

| Sudah | Isi singkat |
|---|---|
| PB-01 | Aksi notifikasi mengikuti **tombol yang ditekan** (`actionId`), payload hanya konteks → "Buka aplikasi"/sentuh notifikasi **tidak** menandai lunas |
| PB-02 | Payload wajib membawa **periode**; aksi "sudah bayar" tanpa periode **ditolak** |
| PB-03 | Uji baru meniru jalur Android (`NotificationResponse` + payload produksi) — 8 uji |
| PB-04 | **"Tunda 1 jam" tidak hilang** saat sinkronisasi (pembatalan selektif, bukan batalkan-semua) |
| PB-05 | **Indeks unik** `(tagihan_id, periode_jatuh_tempo)` — satu periode satu pembayaran |
| PB-06 | `tandaiLunas()` **idempoten** berbasis periode (dua ketukan tidak menggeser periode dua kali) |
| PB-07 | `pemasukan_bulanan.bulan` unik + upsert atomic |
| PB-08 | Dasbor & kalender memakai **occurrence** (riwayat pembayaran + belum lunas) → pembayaran masa lalu **tidak hilang** |
| PB-15 | Sumber waktu tunggal di alur aksi |
| PB-16 | Notifikasi uji tidak menawarkan tombol "Sudah bayar" |

Bukti di jalur Aaron: `flutter analyze` bersih · **101 uji lulus** · tiap perbaikan punya ujinya
(uji mutasi membuktikan bug lama kini tertangkap). Commit: `8cb9e7b`, `9c40e93`, `3f8f941`
(+ dua commit dokumen).

## 2. Cara melihat & menggabungkan

```bash
git fetch . fondasi-aaron            # atau langsung pakai nama branch di repo ini
git log --oneline master..fondasi-aaron
git diff master..fondasi-aaron --stat

# pilih salah satu:
git merge fondasi-aaron              # kalau pekerjaanmu sudah di-commit
git cherry-pick 8cb9e7b 9c40e93 3f8f941
```

**Wajib setelah gabung:**
1. `flutter pub get` → `flutter analyze` (harus **No issues found**) → `flutter test` (harus **101 lulus**).
2. Uji tangkapan layar: perbaikan `lib/core/utils/waktu.dart` membuat uji itu **tidak lagi rapuh terhadap tanggal** (dulu gagal kalau dijalankan di hari lain). Kalau tampilan dasbor/kalender ikut berubah karena gabungan, jalankan
   `flutter test test/tangkapan_layar_test.dart --update-goldens` lalu salin PNG hasilnya ke `demo/`.
3. `test/failures/*.png` (jejak uji merahmu 13 Sep) boleh dihapus setelah uji hijau.

## 3. Catatan penting

- **Berkas yang jadi milik bersama setelah gabung:** `lib/core/notifikasi/**`, `lib/data/**`,
  `lib/core/utils/waktu.dart`, `test/f3_*`. Sebelum gabung, jangan menyunting berkas itu di `master`
  supaya tidak ada konflik.
- **`drift_dev` + `build_runner` yang kamu tambahkan: bagus.** Tapi sadari: perbaikan PB-05/PB-07 di
  branch ini memasang jaminan unik lewat **SQL migrasi** (`idx_riwayat_periode`, `idx_pemasukan_bulan`)
  karena `database.g.dart` dilacak git dan proyek belum memakai build_runner. Kalau kamu mulai
  regenerasi kode, boleh pindahkan jaminan itu ke anotasi `uniqueKeys` tabel — asalkan **uji PB-05 &
  PB-07 tetap lulus** (uji itu sudah ada di branch ini: `test/f0_pb04_07_test.dart`).
- **Belum termasuk (masih di Aaron):** PB-09 (sinkronisasi anti setengah-jalan) · PB-10 (penjadwal gagal
  harus bisa pulih) · PB-11 (hapus data sekalian batalkan notifikasi) · PB-12 (daftar jadwal jujur) ·
  PB-13 (anti "sukses palsu" saat ubah tagihan) · PB-14 (form hormati siklus hidup layar).
  Akan diserahkan menyusul sebagai tambahan pada branch yang sama.
- Fitur **FR-87 (adzan)** dan **FR-88 (pelacakan sholat)** yang kamu tahan karena menunggu berkas
  Aaron: setelah branch ini digabung, keduanya **sudah bisa dikerjakan** (fondasi notifikasi & data sudah
  diperbaiki).

## 4. Kalau ada yang tidak jelas
Tulis pertanyaannya (maksimal 3 butir sekaligus) di berkas ini atau di `TUGAS_SELANJUTNYA_UNTUK_DINDA.md`
— Aaron/Papi yang memutuskan. Jangan menebak.

*Disusun oleh Aaron Salahuddin · 14 Sep 2026*
