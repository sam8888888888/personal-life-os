# Laporan Fase 2 — Personal Life OS (UI Inti)

**Tanggal:** 10 September 2026
**Fase:** F2 · UI inti (PRD §11.3)
**Kriteria selesai (gate):** alur **UC-1** (menambah tagihan dari nol / dari template)
dan **UC-2** (melihat semua tagihan bulan ini di daftar & kalender) mulus di uji manual.

---

## 1. Ringkasan
Fase 2 selesai secara teknis. Aplikasi sekarang punya tampilan sungguhan: dasbor
"uang tersisa", daftar tagihan dengan filter, form tambah/ubah, kalender bulanan,
dan halaman pengaturan. Empat tab navigasi bawah menghubungkan semuanya.

| Ukuran | Nilai |
|---|---|
| Berkas kode (`lib/`) | 20 berkas · ±6.400 baris |
| Berkas uji (`test/`) | 6 berkas · 51 uji |
| Hasil `flutter test` | **51 lulus, 0 gagal** |
| Hasil `flutter analyze` | **No issues found** |
| APK F2 (debug) | 179,61 MB · SHA-256 `8ac2d104166a65c12d3cdbc380568dc4020e89bcbc58444e0fb2dcdf33a30f2a` |

---

## 2. Yang dibangun di F2

| Halaman | Berkas | Isi |
|---|---|---|
| **Ringkasan (dasbor)** | `features/ringkasan/ringkasan_screen.dart` | Kartu "uang tersisa" (pemasukan − tagihan belum dibayar), total tagihan bulan ini, sudah/belum dibayar, daftar 30 hari terdekat, tombol tandai lunas |
| **Daftar Tagihan** | `features/tagihan/daftar_tagihan_screen.dart` | Filter (belum dibayar / sudah dibayar / aktif / nonaktif), total belum bayar, aksi lunas + **batalkan** (undo) |
| **Form tambah/ubah** | `features/tagihan/form_tagihan_screen.dart` | 7 chip template, nama, jumlah (format Indonesia: `150rb`, `1.250.000`), kategori, tanggal (date picker id-ID), pengulangan (9 pilihan), pengingat H-60…H-0, jam, prioritas, catatan, tautan bayar, hapus dengan konfirmasi |
| **Kalender** | `features/kalender/kalender_screen.dart` | Kisi bulanan (mulai Senin), titik merah = belum dibayar, titik abu = sudah dibayar, ganti bulan, ketuk tanggal → daftar tagihan hari itu |
| **Pengaturan** | `features/pengaturan/pengaturan_screen.dart` | Pemasukan bulanan (bahan hitung uang tersisa), isi contoh data, hapus semua data, info versi |
| **Tema & i18n** | `core/theme/app_tema.dart`, `main.dart` | Material 3, warna biji `#2E7D32`, Bahasa Indonesia (locale `id_ID`), format tanggal/angka Indonesia |

**Arsitektur:** Riverpod (provider database & repositori), go_router (rute + navigasi
bawah), layar terpisah per fitur. Tidak ada data keluar perangkat; semua lokal.

---

## 3. Bukti uji (gate F2)

### 3.1 Uji otomatis — `flutter test` → 51 lulus
| Berkas uji | Jumlah | Fokus |
|---|---|---|
| `utilitas_test.dart` | 25 | Tanggal (day-clamping, rollover), format & parsing Rupiah |
| `repository_test.dart` | 9 | CRUD, pelunasan + periode berikutnya, undo, total |
| `template_test.dart` | 3 | 7 template lokal (termasuk STNK 60/30/14/7/1) |
| `f2_ui_test.dart` | 8 | **UC-1, UC-2, UC-5 pada aplikasi nyata** (layar 420×900, DB in-memory) |
| `widget_test.dart` | 1 | Asap: 4 tab utama tampil |
| `tangkapan_layar_test.dart` | 5 | Pembuat tangkapan layar (dilewati otomatis bila font SDK tak ada) |

Contoh isi uji alur nyata:
- **UC-1:** buka aplikasi → dasbor kosong → ketuk tombol tambah → isi nama & jumlah → simpan → tagihan muncul di dasbor dengan nominal benar.
- **UC-1 (template):** ketuk chip "Listrik PLN" → nama & jumlah terisi otomatis.
- **UC-1 (tolak data salah):** nama kosong + jumlah `abc` → form **tidak** tersimpan.
- **UC-2 (daftar):** 2 tagihan tampil, total belum dibayar Rp 510.000.
- **UC-2 (kalender):** ketuk tanggal 15 → hanya tagihan tanggal 15 yang tampil.
- **UC-5:** pemasukan Rp 12.000.000 − Rp 700.000 → "Rp 11.300.000".

### 3.2 Uji terukur tangkapan layar
Tangkapan layar dibuat dengan merender aplikasi sungguhan pada ukuran ponsel
420×900 (rasio 3×) memakai font Roboto asli dari Flutter SDK, lalu diperiksa
secara terukur: kelima berkas berbeda isi (beda warna 16–41 poin antar halaman)
dan kartu hijau "uang tersisa" terbaca pada bagian atas dasbor.

| Halaman | Berkas |
|---|---|
| Ringkasan / dasbor | `demo/f2_ringkasan.png` |
| Daftar tagihan | `demo/f2_tagihan.png` |
| Kalender | `demo/f2_kalender.png` |
| Pengaturan | `demo/f2_pengaturan.png` |
| Form tambah | `demo/f2_form_tambah.png` |

---

## 4. Temuan bug nyata selama pengujian F2 (dan perbaikannya)

1. **Kolom form yang tergulir keluar layar tidak tervalidasi.**
   Form memakai `ListView` (hanya membangun widget yang terlihat). Saat pengguna
   menggulir ke bawah lalu menekan simpan, kolom nama/jumlah yang sudah tidak
   terlihat **tidak ikut divalidasi** → tagihan tanpa nama bisa tersimpan.
   *Perbaikan:* form diganti `SingleChildScrollView` + `Column` (semua kolom tetap
   hidup) **dan** ditambah pemeriksaan ganda nilai mentah sebelum simpan.
   Diverifikasi oleh uji "form menolak nama kosong & jumlah tidak valid".

2. **Teks meluber (overflow) pada lebar ponsel 420 px** di 3 tempat: baris judul
   ringkasan, baris "sudah/belum dibayar", dan baris ringkasan daftar tagihan.
   Ditemukan otomatis oleh uji tata letak (`RenderFlex overflowed`).
   *Perbaikan:* `Expanded`/`Flexible` + `TextOverflow.ellipsis` agar nominal
   besar (mis. Rp 12.000.000) tidak memotong tampilan.

3. **Catatan pengujian, bukan bug aplikasi:** ketukan uji meleset saat daftar
   masih dalam animasi gulir (Flutter mengabaikan sentuhan selama menggulir).
   Uji diperbaiki dengan menunggu animasi selesai sebelum menekan tombol.

---

## 5. Catatan jujur (keterbatasan)

1. **Pratinjau web tidak dapat menjalankan lapisan database.** Drift (SQLite)
   tidak berjalan di browser pada konfigurasi build ini, jadi halaman web tampil
   kosong. Karena itu tangkapan layar F2 **bukan** dari browser, melainkan hasil
   render mesin Flutter pada ukuran ponsel (metode di §3.2). Aplikasi sasaran
   tetap **Android**, dan APK F2 sudah berhasil dibangun.
2. **Pengingat notifikasi belum aktif** — itu isi F3. Di F2, status "lunas",
   rollover periode, dan hitungan uang tersisa sudah berfungsi.
3. **Uji masih otomatis + tangkapan layar**, belum diuji pada perangkat fisik
   (tidak ada perangkat/emulator di lingkungan ini). Bapak dapat memasang APK
   debug untuk uji manual.
4. APK masih **debug** (179 MB, 3 arsitektur). Versi rilis di F4 akan jauh lebih
   kecil.

---

## 6. Permintaan keputusan Bapak
1. **Setujui F2** → lanjut **F3 (pengingat: notifikasi H-x, aksi "sudah bayar",
   Workmanager, panduan izin per merek)**.
2. Konfirmasi harga Pro **Rp 399.000/tahun** (catatan PRD §12).
3. Opsional: preferensi warna/tema, agar F3–F4 langsung sesuai selera Bapak.
