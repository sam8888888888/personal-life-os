# PRD PERSONAL LIFE OS — MASTER v3.0
### Satu dokumen kerja: fondasi + seluruh fitur (FR-01 … FR-152)

| Item | Keterangan |
|---|---|
| Produk | Personal Life OS — aplikasi Android (Flutter) |
| Dokumen | **PRD MASTER v3.1 — INI SATU-SATUNYA DOKUMEN YANG DIPAKAI** |
| Versi | **3.1** (3.0 = gabungan PRD v1.6 + PRD Perbaikan v1.0 + Blueprint v2.1; 3.1 = perbaikan konsistensi fase) |
| Tanggal | 13 Sep 2026, 02:55 WIB |
| Status | **DISETUJUI PAPI** — keputusan produk ada di §0 |
| Catatan revisi v3.1 | Kolom **Fase** untuk FR-76, FR-86, FR-87, FR-88, FR-90 disamakan dengan keputusan §0 (V1.5). Temuan Dinda 14 Sep 2026 — benar, dokumen sebelumnya tidak konsisten. |
| Penyusun | Aaron Salahuddin |
| Pemakai dokumen | Papi (pemilik produk) · Dinda (eksekutor fitur) · Aaron (fondasi & audit) |
| Cakupan fitur | **FR-01 … FR-152** (59 fitur lama yang sudah disetujui + 93 fitur baru) |
| Perbaikan fondasi | **PB-01 … PB-16** (Bagian I — prasyarat, bukan pilihan) |

---

## 0. KEPUTUSAN PAPI (disetujui 13 Sep 2026) — MENGIKAT

Papi menyerahkan pemilihan kepada rekomendasi Aaron dan menyetujui seluruh 7 butir ini:

| # | Pertanyaan | Keputusan | Konsekuensi |
|---|---|---|---|
| 1 | Fondasi atau fitur dulu? | **Fondasi dulu** | PB-01…PB-16 dikerjakan lebih dulu; tidak ada fitur baru sebelum PB-01…PB-08 lulus |
| 2 | Gelombang fitur pertama | **8 fitur inti + Islamic dasar** | V1.5 = FR-60 · FR-61 · FR-62 · FR-63 · FR-68 · FR-71 · FR-72 · FR-76 · FR-86 · FR-87 · FR-88 · FR-90 (12 fitur) |
| 3 | Islamic & Health dasar | **Gratis** | Ibadah & kesehatan dasar tidak dijual; Pro hanya untuk fitur lanjutan |
| 4 | Harga Pro | **Satu harga Rp399.000/tahun** | Tidak ada paket per modul pada tahap ini |
| 5 | Jalur AI | **Lewat server sendiri (perantara)** | Kunci AI tidak ditanam di aplikasi; kuota & catatan per pengguna; AI tetap fase V4 |
| 6 | Sinkron cloud | **Tanpa cloud dulu** | Cadangan lokal otomatis + pindah HP via kode QR; sinkron server menyusul sebagai fitur Pro |
| 7 | Nama produk | **Tetap "Personal Life OS"** | Branding, dokumen, dan repo memakai nama ini |

**Urutan yang berlaku:** Fondasi (PB) → V1.5 (12 fitur) → V2 → V3 → V4.

**Dua fitur pendukung yang WAJIB ikut V1.5** (agar 12 fitur di atas berdiri benar):
**FR-65** (satu sumber data untuk Today ↔ Kalender) dan **FR-67** (bahasa & format lokal).

## 0.1 Peta dokumen (agar tidak ada lagi kebingungan)

| Dokumen | Status | Isi |
|---|---|---|
| **PRD_PERSONAL_LIFE_OS_MASTER_v3.0.md** (berkas ini) | **PAKAI INI** | Fondasi + seluruh fitur + arsitektur + keputusan + roadmap |
| `arsip/PRD_PERSONAL_LIFE_OS.md` (v1.6) | arsip (rujukan) | Riset pasar, 20 pesaing, 59 fitur lama — teks lengkapnya |
| `arsip/PRD_PERBAIKAN_LIFE_OS_v1.0.md` | arsip (rujukan) | Rincian 16 perbaikan + bukti verifikasi audit |
| `arsip/PRD_LIFE_OS_BLUEPRINT_v2.0.md` | arsip (rujukan) | Blueprint fitur v2.1 (isi sudah dipindah ke dokumen ini) |
| `TUGAS_SELANJUTNYA_UNTUK_DINDA.md` | aktif | Aturan kerja & pembagian tugas (Aaron vs Dinda) |

Aturan: kalau ada perbedaan isi, **dokumen MASTER ini yang menang**.

---
---

# BAGIAN I — FONDASI & PERBAIKAN (PB-01 … PB-16)

> Prasyarat wajib. Tanpa bagian ini, seluruh fitur di Bagian II berdiri di atas data yang bisa salah.

### I-1. Ringkasan Eksekutif

Audit eksternal (ChatGPT) menemukan 18 butir masalah, dengan 5 di antaranya berlabel kritis. Audit itu
**statis** (tanpa menjalankan Flutter) dan mengakui sendiri belum menjalankan uji apa pun.

Saya memverifikasi ulang setiap butir **langsung ke kode** (baris demi baris) sebelum dipakai sebagai
bahan perbaikan. Hasilnya: **11 butir terbukti, 3 butir terbukti sebagian, 2 butir memang keputusan
desain yang harus ditetapkan pemilik produk, dan 2 butir tidak terbukti/gugur.**

Yang paling serius dan **terbukti**: tombol pada notifikasi tidak dibedakan oleh aplikasi — aplikasi
membaca *isi payload* yang selalu berbunyi "sudah_bayar", bukan *tombol yang benar-benar ditekan*.
Akibatnya menekan **"Buka aplikasi"** — bahkan sekadar **menyentuh notifikasi untuk membukanya** —
berpotensi **menandai tagihan lunas dan menggeser periode berikutnya**. Ini menyentuh data keuangan
pengguna, jadi **wajib diperbaiki sebelum aplikasi dipakai/dirilis**.

Prinsip kerja dokumen ini: **perbaikan keandalan lebih dulu, fitur baru belakangan.** Menambah fitur di
atas logika pembayaran yang belum benar hanya memperbesar risiko.

---

### I-2. Latar Belakang

1. Papi meminta kode diaudit pihak luar agar diketahui kekurangannya. Repo publik dibuat
   (`github.com/sam8888888888/personal-life-os`) dan ZIP audit diserahkan ke ChatGPT.
2. ChatGPT menyerahkan audit statis: 18 temuan, 5 kritis, disertai usulan arsitektur.
3. Agar perbaikan tidak salah arah, **setiap temuan diverifikasi ulang** terhadap kode nyata:
   yang benar dipakai, yang keliru/berlebihan dibuang, yang ambigu dijadikan keputusan produk.

---

### I-3. Tujuan & Non-Tujuan

**Tujuan**
1. Menghilangkan risiko data keuangan salah (tombol notifikasi, pembayaran ganda, periode ganda).
2. Menegakkan integritas data di lapisan database (bukan hanya di UI).
3. Menjadikan uji otomatis **mampu menangkap** kelas bug ini (uji lewat `NotificationResponse`, bukan payload buatan tangan).
4. Menyiapkan konsep *occurrence* (pembayaran per periode) agar dasbor & kalender tidak kehilangan sejarah.

**Non-Tujuan (tidak dikerjakan dalam dokumen ini)**
- Fitur baru apa pun (cuaca, jadwal sholat, sinkron, dsb.) → masuk PRD Fitur terpisah (FR-60 dst.).
- Perubahan desain tampilan yang tidak terkait bug.
- Penerbitan ke Play Store (kunci rilis, Data Safety) → fase rilis, dokumen terpisah.

---

### I-4. Metode Verifikasi (supaya bisa diaudit balik)

- Setiap butir dicek dengan membaca kode di snapshot `sumber` (baris & berkas dicantumkan).
- Klaim yang menyangkut perilaku **diuji ulang** dengan `flutter analyze` + `flutter test`
  (status saat ini: **80/80 lulus**, analyze bersih) — artinya bug yang terbukti **lolos** dari uji yang ada.
- Berkas bukti: `docs/AARON-CHANGES.diff` (perubahan jalur penyempurnaan) dan repo audit.

---

### I-5. Hasil Verifikasi 18 Temuan

| # | Temuan ChatGPT | Status verifikasi | Bukti (berkas:baris) |
|---|---|---|---|
| 1 | Semua tombol notifikasi bisa jadi "Sudah Bayar" | 🔴 **TERBUKTI (KRITIS)** | `model_pengingat.dart:82-88` & `:91-96` (aksi dipaku `sudah_bayar`); `layanan_notifikasi_lokal.dart:213-217` & `:220-225` (hanya `r.payload` diteruskan, `r.actionId` diabaikan) |
| 2 | Uji tidak menangkap bug itu | 🔴 **TERBUKTI** | `test/f3_pengingat_test.dart:89-100` — payload untuk aksi non-bayar dibuat sendiri oleh uji, bukan dari produksi; uji `:336-340` juga memakai payload buatan |
| 3 | Arsitektur: pindahkan aksi ke `actionId`, payload hanya konteks | ✅ **Sesuai rekomendasi** | akan ditetapkan sebagai PB-01 |
| 4 | "Tunda 1 jam" hilang saat sinkronisasi | 🔴 **TERBUKTI** | `layanan_notifikasi_lokal.dart:121-131` (`batalkanSemua()` lalu pasang ulang) + `:150-152` (`cancelAllPendingNotifications`); slot tunda (`perencana_pengingat.dart:44 slotTunda=89`) hanya dibuat oleh handler `penangan_aksi_pengingat.dart:128`, tidak pernah direncanakan ulang oleh perencana |
| 5 | Dasbor kehilangan histori setelah rollover | 🔴 **TERBUKTI** | `ringkasan_screen.dart:31-36,64-70` menghitung dari `jatuhTempo` **saat ini**; `riwayatPembayaran` **tidak pernah dibaca** layar mana pun (bukti: `git grep riwayatPembayaran lib/` → hanya tulis/hapus) |
| 6 | Kalender kena masalah sama | 🟠 **TERBUKTI** | `kalender_screen.dart:35` memakai `tagihanAktifProvider` + penyaringan bulan dari `jatuhTempo` |
| 7 | Tidak ada UNIQUE(tagihanId, periodeJatuhTempo) | 🔴 **TERBUKTI** | `tabel.dart:52-62` — tanpa `uniqueKeys`/`customConstraints` |
| 8 | `tandaiLunas()` tidak idempoten | 🔴 **TERBUKTI (level repositori)** | `tagihan_repository.dart:57-97` — tidak memeriksa `t.lunas` sebelum mencatat riwayat & rollover. (Catatan teknis: transaksi SQLite men-serialisasi penulisan, jadi ini **bukan** lost-update, melainkan **rollover ganda** bila dipanggil dua kali) |
| 9 | `PemasukanBulanan.bulan` tidak UNIQUE | 🟠 **TERBUKTI** | `tabel.dart:65-71`; `pengaturan_repository.dart` memakai `getSingleOrNull()` → bisa error bila ada duplikat |
| 10 | Sinkronisasi membatalkan dulu, memasang kemudian (failure window) | 🟠 **TERBUKTI** | `layanan_notifikasi_lokal.dart:121-131`; kegagalan hanya `debugPrint` |
| 11 | `siapkan()` menandai siap walau gagal | 🟠 **TERBUKTI** | `layanan_notifikasi_lokal.dart:50-54` — `_siap = true` berada di luar `try`, jadi tetap `true` saat `catch` jalan |
| 12 | `tertunda()` mengembalikan `waktu: null` | 🟡 **TERBUKTI** | `layanan_notifikasi_lokal.dart:170-176` |
| 13 | Rollover akhir bulan bisa "date drift" (31 Jan → 28 Feb → 28 Mar) | ⚖️ **TERBUKTI secara perilaku, tapi ini KEPUTUSAN PRODUK** | `tanggal_utils.dart:11-18` (`tambahBulan` menjepit dari tanggal berjalan) + `:29-30`; PRD lama menyebut day-clamping ⇒ perlu keputusan Papi: **Rule A (menempel)** atau **Rule B (kembali ke tanggal asli 31)** |
| 14 | `ubah()` bisa "sukses palsu" | 🟡 **TERBUKTI** | `tagihan_repository.dart:35-39` mengembalikan jumlah baris; `form_tagihan_screen.dart:323,343` tidak memeriksa hasil dan selalu menampilkan "Perubahan tersimpan." |
| 15 | `_muatData()` bisa `setState()` setelah dispose | 🟡 **TERBUKTI** | `form_tagihan_screen.dart:48-53` (tanpa `if (!mounted) return;`) |
| 16 | Repositori terlalu percaya pemanggil | 🟡 **TERBUKTI** | sama dengan #8 (`tagihan_repository.dart:57`) |
| 17 | `hapusSemuaData()` tidak membatalkan notifikasi | 🟡 **TERBUKTI** | `pengaturan_repository.dart:44-52` hanya menghapus baris tabel |
| 18 | Cakupan uji belum menyentuh failure mode penting | 🟠 **TERBUKTI** | daftar uji yang belum ada dicantumkan di §7 |

**Tidak terbukti / gugur setelah verifikasi**
- Klaim bahwa masalah aksi notifikasi "hanya mungkin secara teoretis": **keliru** — jalurnya nyata dan bisa terjadi
  pada sentuhan biasa (buka notifikasi), sehingga **tingkat bahayanya lebih tinggi** daripada yang ditulis audit.
- Klaim "race condition / lost update" pada #8: **tidak terbukti** sebagai race di SQLite (transaksi serial);
  yang nyata adalah **ketiadaan idempotensi**.

**Temuan tambahan saya sendiri (tidak ada di audit)**
- **PB-EX1 [KRITIS, satu keluarga dengan #1]**: pengingat "Tunda 1 jam" dibuat **tanpa** `periode`
  (`penangan_aksi_pengingat.dart:127-137`) → pelindung "notifikasi lama tidak boleh menandai lunas periode baru"
  (`:76-93`) **tidak berlaku** untuk jalur ini. Setelah PB-01 dipasang, payload harus **selalu** membawa periode.
- **PB-EX2**: `penangan_aksi_pengingat.dart:131` masih memakai `DateTime.now()` walau fungsi menerima parameter
  `sekarang` → hasil uji bisa berbeda dari perilaku nyata (konsistensi sumber waktu).
- **PB-EX3**: notifikasi uji (`layanan_notifikasi_lokal.dart:155-167`) memakai tagihanId 0 → aksi "Sudah bayar"
  pada notifikasi uji akan berbunyi "tagihan tidak ditemukan" (aman, tetapi sebaiknya tombol bayar
  disembunyikan pada notifikasi uji agar tidak membingungkan).

---

### I-6. Rencana Perbaikan (detail per butir)

### PRIORITAS 1 — WAJIB SEBELUM APA PUN (keamanan data pembayaran)

**PB-01 · Jadikan `actionId` sumber kebenaran; payload hanya membawa konteks** · P0 · estimasi M · area: notifikasi
- Ubah `Pengingat.payloadDenganPeriode()` & `payload` → **tanpa** kunci `aksi`; isi hanya
  `tagihanId`, `notifId`, `periode` (periode **wajib**), `hariSebelum`.
- `LayananNotifikasiLokal._saatAksiDipilih` dan `_saatAksiLatarDipilih` meneruskan **`r.actionId`** ke handler.
- `tanganiAksiPengingat(payload, actionId: ...)`: aksi ditentukan `actionId` (fallback: bila kosong →
  perlakukan sebagai **buka**, bukan bayar).
- Terapkan juga pada payload aksi tombol yang berbeda (`sudah_bayar`, `tunda_1_jam`, `buka`) — payload kini identik
  untuk semua tombol, yang membedakan hanya `actionId`.
- **Acceptance criteria**
  1. `actionId='buka'` + payload produksi → **tidak ada** perubahan data apa pun.
  2. Sentuh badan notifikasi (actionId null) → hanya membuka aplikasi, **tidak** menandai lunas.
  3. `actionId='tunda_1_jam'` → **tidak** menandai lunas; hanya menjadwalkan ulang 1 jam.
  4. `actionId='sudah_bayar'` → menandai lunas **hanya** untuk periode di payload.
  5. Payload produksi **tidak lagi memuat** kata `aksi`.

**PB-02 · Payload selalu membawa periode (termasuk jalur tunda)** · P0 · estimasi S · area: notifikasi
- Setiap `Pengingat` yang dijadwalkan (termasuk tunda 1 jam & notifikasi uji) wajib mengisi `periode`.
- Acceptance: notifikasi "tunda" yang ditekan "Sudah bayar" tidak boleh menandai lunas periode berikutnya
  (atas dasar yang sama seperti PB-01 kriteria 4); uji wajib membuktikan.

**PB-03 · Uji menembus jalur nyata `NotificationResponse`** · P0 · estimasi M · area: uji
- Tambah lapisan uji yang meniru Android: `NotificationResponse(actionId: …)` + **payload dari produksi**
  (`payloadDenganPeriode`) → handler → periksa hasil.
- Wajib ada matriks uji: (`sudah_bayar` × payload produksi), (`tunda_1_jam` × payload produksi),
  (`buka` × payload produksi), (`null` × payload produksi), plus payload rusak/kosong.
- Hapus/ubah helper uji `payloadNyata()` yang membuat payload palsu, atau tandai jelas sebagai "payload uji internal".
- Acceptance: **uji ini gagal** bila PB-01 dibalik (dibuktikan dengan percobaan sengaja).

### PRIORITAS 2 — WAJIB (kehilangan data & integritas)

**PB-04 · "Tunda 1 jam" bertahan terhadap sinkronisasi** · P0 · estimasi M · area: notifikasi
- Sinkronisasi tidak boleh membatalkan jadwal tunda. Pilihan teknis (pilih satu saat eksekusi):
  (a) slot tunda diikutkan ke perencana sebagai pengingat sah, atau (b) `batalkanSemua` diganti
  pembatalan selektif berbasis daftar ID rencana.
- Acceptance: tunda → sinkron (buka aplikasi/ubah tagihan/worker) → tunda **masih ada** di
  `pendingNotificationRequests()`; jadwal lama tetap utuh.

**PB-05 · Pembayaran tidak boleh tercatat dua kali di level database** · P0 · estimasi M · area: data
- Tambah indeks unik `RiwayatPembayaran(tagihanId, periodeJatuhTempo)`.
- Migrasi **wajib** membersihkan duplikat lama lebih dulu (pilih satu yang dipertahankan, sisanya dihapus,
  dan **catat jumlah yang dibersihkan** ke jejak).
- Acceptance: insert kedua untuk pasangan sama **ditolak** oleh database; uji membuktikan penolakan itu.

**PB-06 · `tandaiLunas()` idempoten** · P0 · estimasi M · area: data
- Di dalam transaksi: baca tagihan → bila `lunas == true` → **kembalikan hasil "sudah lunas sebelumnya"**
  tanpa mencatat riwayat dan **tanpa** rollover; bila `statusAktif == false` → tolak dengan alasan jelas.
- Opsional: kunci optimistis (`compare and set` pada `diubahPada`) untuk menahan dua panggilan berurutan cepat.
- Acceptance: dua panggilan berurutan → **satu** baris riwayat, **satu** rollover; uji membuktikan.

**PB-07 · `PemasukanBulanan.bulan` unik + penyimpanan atomic** · P1 · estimasi S · area: data
- Indeks unik `bulan`; penulisan memakai upsert (`insertOnConflictUpdate`) di dalam transaksi.
- Acceptance: menyimpan dua kali untuk bulan yang sama → tetap **satu** baris, tanpa error.

**PB-08 · Riwayat pembayaran dipakai untuk periode yang sudah lewat (occurrence)** · P0 · estimasi L · area: dasbor/kalender/data
- Tetapkan model: **Tagihan = keadaan sekarang**; **RiwayatPembayaran = kejadian per periode**.
- Dasbor & kalender bulan tertentu menghitung dari **gabungan**: (a) riwayat pembayaran periode itu,
  (b) tagihan aktif yang belum lunas pada periode itu.
- Acceptance: setelah membayar tagihan September, ringkasan September **tetap** menampilkan
  "Total Rp 500.000 · sudah dibayar Rp 500.000 · belum Rp 0"; kalender September tetap menampilkan
  entri "15 Sep ✓ sudah dibayar"; periode Oktober tampil terpisah.

### PRIORITAS 3 — KEANDALAN SISTEM NOTIFIKASI

**PB-09 · Sinkronisasi tidak boleh menyisakan jadwal setengah terpasang** · P1 · estimasi M · area: notifikasi
- Urutan aman: susun rencana → batalkan ID yang **tidak** ada di rencana → pasang/segarkan → baca ulang
  `pendingNotificationRequests()` → **verifikasi** jumlah & ID → bila gagal, tulis jejak + (idealnya) ulangi sekali.
- Acceptance: dengan satu jadwal yang sengaja digagalkan, jadwal lain **tetap** terpasang; kegagalan **tercatat**
  (bukan hanya `debugPrint`) dan tampil di layar "Pengingat & izin".

**PB-10 · `siapkan()` tidak menandai siap bila gagal** · P1 · estimasi S · area: notifikasi
- `_siap = true` hanya bila seluruh inisialisasi berhasil; saat gagal → tetap `false` **dan** catat jejak +
  sediakan tombol "Coba lagi" di layar Pengingat.
- Acceptance: dengan plugin yang sengaja digagalkan, pemanggilan berikutnya **mencoba ulang** (bukan langsung `return`).

**PB-11 · `hapusSemuaData()` berkoordinasi dengan penjadwal** · P1 · estimasi S · area: data/notifikasi
- Setelah menghapus data: panggil pembatalan notifikasi secara eksplisit.
- Acceptance: setelah "hapus semua data", `pendingNotificationRequests()` kosong (kecuali notifikasi uji),
  **tanpa** menunggu sinkronisasi berikutnya.

### PRIORITAS 4 — PERBAIKAN KECIL (tetap wajib)

**PB-12 · `tertunda()` mengembalikan waktu yang benar atau jujur `null` sesuai kontrak** · P2 · estimasi S
- Ambil waktu dari data internal rencana (bukan dari plugin bila tidak tersedia), atau ubah kontrak & UI
  agar hanya menampilkan jumlah jadwal + id — **jangan** menampilkan klaim waktu yang tidak diketahui.

**PB-13 · `ubah()` diperiksa hasilnya (anti "sukses palsu")** · P2 · estimasi S
- Form memeriksa jumlah baris: 0 → tampilkan "Tagihan tidak ditemukan / sudah dihapus", jangan menampilkan sukses.

**PB-14 · `_muatData()` menghormati siklus hidup widget** · P2 · estimasi S
- Tambah `if (!mounted) return;` sebelum `setState`.

**PB-15 · Sumber waktu tunggal di seluruh alur aksi** · P2 · estimasi S
- `penangan_aksi_pengingat.dart:131` memakai parameter `sekarang` (bukan `DateTime.now()`).

**PB-16 · Notifikasi uji tidak menawarkan tombol "Sudah bayar"** · P2 · estimasi S
- Sembunyikan aksi bayar pada notifikasi uji (id uji) agar tidak ada aksi yang berakhir "tagihan tidak ditemukan".

---

### I-7. Uji Wajib Ditambahkan (menggantikan asumsi "sudah teruji")

1. `NotificationResponse(actionId='buka')` + payload produksi → data **tidak berubah**.
2. `NotificationResponse(actionId='tunda_1_jam')` + payload produksi → **tidak** lunas; jadwal tunda bertambah.
3. `NotificationResponse(actionId='sudah_bayar')` + payload produksi → lunas **tepat satu** periode.
4. Sentuh notifikasi tanpa actionId → hanya membuka, data tidak berubah.
5. `tunda → sinkron → tunda masih ada`.
6. Dua `tandaiLunas()` berurutan → satu riwayat, satu rollover.
7. Dua penyimpanan pemasukan bulan sama → satu baris.
8. Setelah pembayaran, ringkasan & kalender bulan berjalan **tetap** memperlihatkan pembayaran itu.
9. Rollover rantai: 31 Jan → Feb → Mar sesuai **keputusan Rule A/B** (dokumentasikan pilihannya di uji).
10. Payload rusak/kosong/tanpa periode → tidak menandai lunas apa pun.

---

### I-8. Perubahan Skema Database (migrasi)

| Versi | Perubahan | Catatan migrasi |
|---|---|---|
| v1 (sekarang) | Skema awal | — |
| v2 | UNIQUE `RiwayatPembayaran(tagihanId, periodeJatuhTempo)`; UNIQUE `PemasukanBulanan(bulan)` | Sebelum membuat indeks unik: deteksi duplikat, pertahankan 1 baris (yang tertua/menurut aturan yang ditetapkan), hapus sisanya, **catat jumlahnya** ke audit/jejak. Tanpa langkah ini, migrasi bisa gagal di perangkat pengguna yang sudah punya duplikat. |

---

### I-9. Keputusan yang Diminta dari Papi (hanya 2)

1. **Rollover akhir bulan (PB-13/#13):** bila jatuh tempo 31 Januari, setelah dibayar:
   - **Rule A** — menempel: 28 Feb → 28 Mar → 28 Apr (perilaku sekarang, sesuai PRD lama)
   - **Rule B** — kembali ke tanggal asli: 28 Feb → **31 Mar** → 30 Apr (umum dipakai untuk langganan)
   Rekomendasi saya: **Rule B**, dengan catatan tanggal asli disimpan (`tanggalAsli`), agar jatuh tempo tidak "mundur" permanen.
2. **Notifikasi uji:** apakah notifikasi uji tetap ada (untuk melatih Papi di HP), atau disembunyikan setelah Papi berhasil menguji notifikasi?

---

### I-10. Roadmap & Estimasi

| Fase | Isi | Estimasi (hari kerja) |
|---|---|---|
| P0-A | PB-01, PB-02, PB-03 (aksi notifikasi + uji nyata) | 1,5–2 |
| P0-B | PB-05, PB-06, PB-07 (integritas data + idempotensi + migrasi v2) | 1,5–2 |
| P0-C | PB-08 (riwayat/occurrence untuk dasbor & kalender) | 2–3 |
| P1 | PB-04, PB-09, PB-10, PB-11 (keandalan penjadwalan) | 1,5–2 |
| P2 | PB-12 … PB-16 (perbaikan kecil) | 1 |

*Estimasi angka diskusi, bukan komitmen. Semua angka diasumsikan dikerjakan satu orang dengan lingkungan build siap.*

**Aturan urutan:** satu fase tuntas + uji hijau sebelum fase berikutnya (aturan fase yang sudah disepakati).

---

### I-11. Risiko & Mitigasi

| Risiko | Mitigasi |
|---|---|
| Perbaikan notifikasi mengubah perilaku yang sudah disetujui Papi | Uji matriks aksi (10 butir §7) dijalankan sebelum & sesudah; rollback tersedia (commit terpisah per PB) |
| Migrasi v2 gagal di perangkat lama karena duplikat | Bersihkan duplikat + verifikasi jumlah baris sebelum & sesudah migrasi, saat aplikasi pertama kali dibuka |
| Perubahan dasbor (PB-08) menimbulkan angka ganda | Definisi tunggal: "total periode X = riwayat periode X + tagihan aktif belum lunas periode X"; uji dengan data contoh |
| Bug tetap lolos ke perangkat nyata | Uji lewat `NotificationResponse` (tanpa HP) **dan** uji tekan-tombol manual di HP Papi sebelum rilis |
| Jadwal nyata tidak terbukti di server | Batas yang diakui: ketepatan waktu notifikasi hanya bisa dibuktikan di HP (gate F3) |

---

### I-12. Definition of Done

Dinyatakan selesai bila **semua** benar:
1. 10 uji wajib §7 ada dan **lulus**; uji §7.1–§7.4 **gagal** bila PB-01 dibalik (dibuktikan dengan percobaan sengaja).
2. `flutter analyze` bersih; seluruh uji lama tetap hijau (tidak ada regresi).
3. Skema v2 terpasang dengan migrasi bersih-duplikat + laporan jumlah baris yang dibersihkan.
4. Bukti nyata: tangkapan layar/keluaran perintah + hasil uji ditempel di laporan.
5. Diuji tekan-tombol di HP Papi: "Buka aplikasi" **tidak** mengubah data, "Tunda 1 jam" bertahan setelah sinkronisasi.
6. Laporan 3 poin (berhasil apa · berkas mana · langkah lanjut) + catatan jujur bagian yang belum teruji.

---

### I-13. Referensi

- Repo audit publik: `https://github.com/sam8888888888/personal-life-os` (snapshot F1–F3 + perubahan jalur penyempurnaan)
- `docs/AARON-CHANGES.diff` — seluruh perubahan jalur penyempurnaan
- PRD Personal Life OS v1.6 (`PRD_PERSONAL_LIFE_OS.md`) — FR-01…FR-59, fase F0–F8
- Laporan fase: `LAPORAN_F1.md`, `LAPORAN_F2.md`, `LAPORAN_F3.md`
- Berkas kode yang menjadi objek perbaikan: `lib/core/notifikasi/*`, `lib/data/repository/tagihan_repository.dart`,
  `lib/data/database/tabel.dart`, `lib/data/repository/pengaturan_repository.dart`,
  `lib/features/ringkasan/ringkasan_screen.dart`, `lib/features/kalender/kalender_screen.dart`,
  `lib/features/tagihan/form_tagihan_screen.dart`, `test/f3_pengingat_test.dart`

---
---

# BAGIAN II — FITUR

## II.1 Fitur yang sudah disetujui lebih dulu (FR-01 … FR-59)

Daftar ringkas (teks lengkap + riset pasarnya ada di `arsip/PRD_PERSONAL_LIFE_OS.md`).
Semuanya tetap berlaku; kolom prioritas mengikuti PRD v1.6.

| ID | Prio | Ringkas |
|---|---|---|
| FR-01 | P0 | Tambah tagihan: nama, jumlah, jatuh tempo (tanggal; opsi "setiap |
| FR-02 | P0 | Template cepat tagihan Indonesia: Listrik PLN, Air PDAM, Internet/ |
| FR-03 | P0 | Frekuensi: sekali, mingguan, 2-mingguan, bulanan, 2-bulanan, |
| FR-04 | P0 | Tagihan berulang otomatis membuat entri periode berikutnya saat |
| FR-05 | P0 | Edit & hapus; penghapusan menanyakan konfirmasi & menawarkan |
| FR-06 | P0 | Status: Belum Bayar / Lunas (+tanggal bayar) / Terlambat |
| FR-07 | P0 | Pencarian & filter (kategori, status, bulan). |
| FR-08 | P1 | Kategori kustom + ikon & warna per kategori. |
| FR-09 | P2 | Duplikasi cepat tagihan (salin sebagai template pribadi). |
| FR-10 | P0 | Lead time kustom per tagihan: H-7 / H-3 / H-1 / hari-H / kustom |
| FR-11 | P0 | Aksi dari notifikasi: "✓ Sudah bayar" (tanpa buka aplikasi), |
| FR-12 | P0 | Anti-bising: maksimum N notifikasi per tagihan per siklus; |
| FR-13 | P0 | Notifikasi terkirim walau aplikasi tertutup |
| FR-14 | P1 | Kanal notifikasi: Tagihan (wajib), Terlambat (urgent), Ringkasan. |
| FR-15 | P1 | Ringkasan mingguan (setiap Senin pagi): daftar tagihan 7 hari ke |
| FR-16 | P1 | Notifikasi "tagihan terlambat" sekali per hari hingga dibayar. |
| FR-17 | P2 | Pengingat pintar berbasis pola: bila pengguna biasanya bayar |
| FR-18 | P0 | 4 tab utama: **Ringkasan** (hari ini/7 hari/menyusul + uang |
| FR-19 | P0 | Kartu ringkasan: total tagihan bulan berjalan, total belum bayar, |
| FR-20 | P1 | Input pemasukan bulanan opsional untuk menghitung "uang tersisa". |
| FR-21 | P1 | Mode gelap & terang, aksent warna, ukuran teks mengikuti sistem. |
| FR-22 | P1 | Badge/angka tagihan hari ini di ikon launcher (bila API |
| FR-23 | P0 | Semua data lokal (SQLite), tanpa akun, tanpa telemetri wajib. |
| FR-24 | P0 | Ekspor cadangan JSON + impor restore (termasuk migrasi antar HP). |
| FR-25 | P1 | Ekspor CSV untuk dibuka di spreadsheet. |
| FR-26 | P2 | Kunci aplikasi (PIN/pola/biometrik) untuk data sensitif. |
| FR-27 | P2 | Sinkronisasi antar perangkat via file/cloud pilihan pengguna |
| FR-28 | P0 | Grafik sederhana beban tagihan per bulan (total & per kategori). |
| FR-29 | P1 | Riwayat pembayaran & statistik: rata-rata nominal, jumlah |
| FR-30 | P2 | Proyeksi arus kas 3 bulan ke depan (terinspirasi PocketSmith/ |
| FR-31 | P1/v1.5 | Widget layar utama: tagihan 7 hari ke depan + total; tap membuka detail tagihan (F01). |
| FR-32 | P1/v1.5 | Ringkasan harian pagi (toggle): tagihan hari ini & besok + total (F02). |
| FR-33 | P1/v1.5 | "Uang aman sampai gajian": input tanggal gajian & saldo opsional → proyeksi saldo setelah tagihan bulan berjal… |
| FR-34 | P1/v1.5 | Kalkulator denda terhindarkan: estimasi denda/bunga yang dihindari tiap pelunasan tepat waktu + total bulanan … |
| FR-35 | P1/v1.5 | Deteksi kenaikan tagihan: pembandingan nominal terhadap rata-rata 3 bulan; peringatan anomali (F05). |
| FR-36 | P1/v1.5 | Skor Disiplin Tagihan lokal (0–100) + streak bebas denda + daftar capaian; disclaimer "bukan skor kredit" (F06… |
| FR-37 | P2/v2 | Rekap Tahunan ala "Wrapped": statistik tahunan + kartu berbagi gambar (F07). |
| FR-38 | P2/v2 | Impor tagihan dari foto/screenshot dengan OCR di perangkat; isi kolom otomatis + konfirmasi pengguna (F08). |
| FR-39 | P2/v2.5 | Pemindai SMS/notifikasi bank *on-device* (opt-in): deteksi pembayaran tagihan & saldo; tanpa cloud; alur izin … |
| FR-40 | P2/v2 | Pembelajaran pola tanggal bayar dari riwayat; usul penyesuaian pengingat (F10). |
| FR-41 | P1/v1.5 | Ekspor tagihan mendatang ke Google Kalender; opsi impor .ics (F11). |
| FR-42 | P1–P2 | Pusat Bayar: preferensi aplikasi bayar per tagihan, salin nomor VA/QRIS, catatan konfirmasi pembayaran (F12). |
| FR-43 | P2/v2 | Mode Rumah Tangga: kode undangan tanpa akun, tagihan bersama, notifikasi ke semua anggota, riwayat "siapa baya… |
| FR-44 | P2/v2 | Multi-profil terpisah (pribadi/keluarga/usaha) — kandidat Premium (F14). |
| FR-45 | P2/v2 | Laporan bulanan PDF/Excel + tombol bagikan — kandidat Premium (F15). |
| FR-46 | P2/v2 | Deteksi langganan duplikat & tagihan yang berhenti muncul (F16). |
| FR-47 | v2 — perluas FR-43 | Split Bill & Patungan: grup tagihan bersama |
| FR-48 | v2 — perkuat FR-33/FR-30 | Dasbor Arus Kas & Dana Persiapan: |
| FR-49 | v2 | Pengingat Multi-Kanal — WhatsApp first: saat pengingat |
| FR-50 | v2 — perluas FR-38 | OCR diperluas ke struk belanja, nota manual, |
| FR-51 | v3 kandidat | Catatan Kas & Utang Informal (cash ledger): |
| FR-52 | v3 kandidat | Multi-Mata Uang & Konversi: setiap tagihan memakai |
| FR-53 | F8 kandidat | Document Vault & Masa Berlaku: dokumen (STNK, pajak |
| FR-54 | F8 kandidat | Modul Kesehatan (opsional): pengingat obat/suplemen |
| FR-55 | v2 — perluas FR-49 | Delegasi Cepat via WhatsApp: kirim pengingat |
| FR-56 | F8 kandidat | Sub-Akses Keluarga (opsional sinkron): berbagi |
| FR-57 | F8 kandidat — engine sama dgn FR-03, biaya rendah | Perawatan |
| FR-58 | F8 kandidat — bertahap | Voice & Parsing Cerdas: input suara atau |
| FR-59 | F8 kandidat — perluas FR-39 | Auto-catat pengeluaran dari |

## II.2 Fitur baru (FR-60 … FR-152) — rinci

Angka 93 fitur, dikelompokkan ke 10 modul. Keterangan kolom P/Est/Online sama seperti Bagian sebelumnya:
Prio (P0 wajib · P1 penting · P2 bila cukup) · Est (S ≤3 hari · M 4–8 hari · L 9+ hari) · Online (butuh jaringan).

### 7.0 Modul 0 — Today / Life Command Center (FR-60 … FR-67)

| ID | Fitur | Prio | Fase | Est | Online | Kriteria terima (ringkas) |
|---|---|---|---|---|---|---|
| FR-60 | **Today (Life Command Center)** — satu layar: sapaan, daftar agenda hari ini (tagihan, obat, janji, tugas, ibadah), urut waktu, warna prioritas (merah/oranye/kuning/hijau) | P0 | V1.5 | M | Tidak | Dalam ≤2 detik membuka app, pengguna melihat maksimal 6 baris "yang harus dilakukan hari ini" tanpa menggulir; setiap baris bisa diaksi (bayar/centang/tunda) |
| FR-61 | **Kartu Pilar Harian** — 5 ringkasan: Health, Money, Productivity, Family, Ibadah (angka ringkas, bukan nilai moral) | P0 | V1.5 | S | Tidak | Kelima kartu menampilkan angka hari ini dan bertanda hijau/kuning/merah sesuai aturan yang ditulis di dokumen; kosong = "belum ada data", bukan angka palsu |
| FR-62 | **Attention / Perhatian** — daftar hal yang butuh tindakan: tagihan < 3 hari, pengeluaran menyimpang, dokumen hampir kedaluwarsa, obat habis, kebiasaan tertinggal | P0 | V1.5 | M | Tidak | Setiap butir punya alasan jelas + tombol tindakan; maksimal 5 butir prioritas tertinggi |
| FR-63 | **Morning Briefing** — ringkasan pagi (bisa dimatikan), satu layar: agenda, tagihan terdekat, cuaca *(opsional, online)*, jadwal sholat (bila modul aktif) | P0 | V1.5 | M | Opsional | Notifikasi pagi membuka layar briefing; bila offline tetap tampil tanpa bagian cuaca dengan penanda "offline" |
| FR-64 | **Evening Review** — ringkasan malam: apa yang selesai, apa yang belum, satu pertanyaan refleksi | P1 | V2 | S | Tidak | Ringkasan akurat sesuai data hari itu; dapat dimatikan per pengguna |
| FR-65 | **Sinkron agenda Today ↔ Kalender** — Today, Kalender, dan Kalender Keuangan memakai sumber data yang sama | P0 | V1.5 | M | Tidak | Menambah item di satu tempat langsung tampil di tempat lain (uji: tambah → muncul di dua tempat) |
| FR-66 | **Mode sorot "hari berat"** — bila >5 kewajiban pada satu hari, tampilkan saran urutan & tawaran menunda yang tidak mendesak | P1 | V2 | S | Tidak | Hari dengan >5 item menampilkan saran urutan; tidak ada item yang hilang saat ditunda |
| FR-67 | **Bahasa & format lokal** — istilah Indonesia/Malaysia, Rupiah/Ringgit, format tanggal & waktu lokal | P0 | V1.5 | S | Tidak | Semua teks baru memakai format lokal; tidak ada istilah Inggris yang tidak perlu di UI |

### 7.1 Modul 1 — Money OS (FR-68 … FR-77)

| ID | Fitur | Prio | Fase | Est | Online | Kriteria terima (ringkas) |
|---|---|---|---|---|---|---|
| FR-68 | **Recurring & Subscription Manager** *(memperluas FR-03/FR-16)* — tiap langganan: nominal, tanggal, auto-renew, kategori, status "aktif/pause" | P0 | V1.5 | M | Tidak | Daftar langganan punya filter aktif/pause; menandai "pause" menghentikan pengingat tanpa menghapus riwayat |
| FR-69 | **Subscription Intelligence** — total per bulan & per tahun, jumlah langganan, 5 terbesar, proyeksi 12 bulan | P0 | V1.5 | S | Tidak | Angka total cocok dengan penjumlahan manual (uji dengan 12 langganan contoh); tampil "Rp X/bulan · Rp Y/tahun" |
| FR-70 | **Deteksi langganan duplikat / jarang dipakai / harga naik** *(memperluas FR-46 + FR-35)* | P1 | V2 | M | Tidak | Menemukan pasangan duplikat pada data uji; menampilkan bukti (nominal & tanggal) sebelum menyimpulkan |
| FR-71 | **Cashflow: pemasukan & pengeluaran berkategori** *(memperluas FR-20)* — kategori Indonesia (tempat tinggal, makan, transport, pendidikan, keluarga, hiburan, kesehatan, utang, belanja, bisnis, lain-lain) | P0 | V1.5 | M | Tidak | Ringkasan bulanan: pemasukan, pengeluaran, arus kas bersih; kategori bisa diubah pengguna |
| FR-72 | **Budget vs Actual per kategori** — anggaran bulanan per kategori + peringatan saat terlampaui | P0 | V1.5 | M | Tidak | Menampilkan "Anggaran / Terpakai / Selisih (%)"; peringatan muncul pada 80% dan 100% |
| FR-73 | **Financial Calendar** — gabungan: pemasukan, tagihan, langganan, cicilan, utang, pengeluaran terencana dalam satu kalender | P0 | V1.5 | M | Tidak | Satu tampilan bulan memuat semua jenis; bisa menjawab "berapa uang harus tersedia sebelum tanggal 25" (uji dengan data contoh) |
| FR-74 | **Debt Manager** — daftar utang: pokok, bunga, minimum bayar, tanggal jatuh tempo, sisa | P0 | V2 | M | Tidak | Total utang & sisa per utang akurat; pembayaran mengurangi pokok sesuai skema yang dipilih |
| FR-75 | **Debt Strategy (Avalanche / Snowball)** — simulasi: estimasi lunas (bulan), bunga terselamatkan | P1 | V2 | M | Tidak | Dua simulasi menghasilkan angka berbeda pada data uji; rumus & asumsi ditampilkan (bukan kotak hitam) |
| FR-76 | **Net Worth Tracker** — aset (kas, bank, investasi, properti, kendaraan, emas, kripto, bisnis) − kewajiban (kartu kredit, KPR, pinjaman, cicilan) + grafik tren bulanan | P0 | V1.5 | M | Tidak | Nilai bersih = aset − kewajiban (uji hitung); grafik menyimpan riwayat bulanan dan tidak berubah retroaktif |
| FR-77 | **Laporan Keuangan Bulanan** *(memperluas FR-45)* — PDF/Excel: arus kas, kategori, utang, kekayaan bersih, langganan | P1 | V2 | M | Tidak | Berkas dapat dibuka di luar aplikasi; angka identik dengan yang tampil di aplikasi |

### 7.2 Modul 2 — Action & Goal OS (FR-78 … FR-85)

| ID | Fitur | Prio | Fase | Est | Online | Kriteria terima (ringkas) |
|---|---|---|---|---|---|---|
| FR-78 | **Goal → Project → Task** — tujuan punya target & progres; proyek di bawah tujuan; tugas di bawah proyek | P0 | V2 | L | Tidak | Progres tujuan terhitung dari tugas/proyek di bawahnya; menghapus tugas tidak merusak progres tujuan (uji) |
| FR-79 | **Task cepat (3 ketukan)** — tambah tugas dalam ≤3 ketukan, dengan tanggal/jam opsional & pengulangan | P0 | V2 | M | Tidak | Tugas tersimpan ≤3 ketukan; muncul di Today pada tanggalnya |
| FR-80 | **Habit Engine** — maksimal 5 kebiasaan utama yang dipromosikan; penanda selesai harian + kalender kebiasaan | P1 | V2 | M | Tidak | Kebiasaan muncul di Today; riwayat 30 hari tersimpan; tidak ada hukuman/penalti saat terlewat |
| FR-81 | **Habit Recovery Score** — metrik pemulihan (bukan streak yang menghukum) | P2 | V3 | S | Tidak | Nilai pemulihan dihitung dari riwayat; teks tidak pernah menyebut "gagal" |
| FR-82 | **Life Planning Engine** — Vision → Area hidup → Goal → Project → Task → Habit → Hasil | P1 | V3 | L | Tidak | Setiap tugas dapat ditelusuri ke atas sampai satu visi (uji rantai); menghapus visi tidak menghapus data di bawahnya tanpa konfirmasi |
| FR-83 | **Life Maintenance Engine** — perawatan berkala otomatis (oli, servis AC, pajak, filter, cadangan data, ulang tahun, anniversary) | P1 | V2 | M | Tidak | Item perawatan dibuat dari template bawaan; pengingat muncul di Today/notifikasi sesuai jadwal |
| FR-84 | **Sleep & Energy OS** — catat tidur, jam bangun, tingkat energi/fokus (1–5) + temuan pola waktu produktif | P2 | V3 | M | Tidak | Setelah ≥14 hari data, aplikasi menampilkan jam produktif pribadi (mis. "08.00–11.00") beserta dasar datanya |
| FR-85 | **Progress & konsistensi tanpa skor moral** — ringkasan "tercatat / belum tercatat", grafik mingguan | P1 | V2 | S | Tidak | Semua teks memakai istilah netral; tidak ada angka tunggal yang menggambarkan "kualitas manusia" |


### 7.3 Modul 3 — Islamic Life OS (FR-86 … FR-100)

> **Prinsip modul ini (disetujui Papi):** Islam bukan tempelan, tetapi pilar sejajar Finance/Health.
> **Batas keras:** aplikasi **tidak menilai keimanan**, tidak memberi fatwa, tidak menghitung dosa/pahala,
> dan tidak menyimpulkan "belum sholat" hanya karena belum dicentang. Istilah yang dipakai:
> **"selesai" / "belum tercatat"**. Konten agama wajib menyertakan sumber (surah/ayat, kitab, nomor hadis
> & derajatnya) — tidak boleh kutipan acak.

| ID | Fitur | Prio | Fase | Est | Online | Kriteria terima (ringkas) |
|---|---|---|---|---|---|---|
| FR-86 | **Jadwal Sholat** — 5 waktu sesuai lokasi; pilih lokasi otomatis atau kota manual; pilih metode perhitungan, konvensi Ashar (madhhab), dan penyesuaian menit | P0 | V1.5 | M | Ya (cache) | Waktu berbeda saat lokasi/metode diganti (uji 2 kota × 2 metode); nilai tersimpan sehingga besok tetap tampil walau offline, dengan penanda "dihitung untuk <kota>, <tanggal>" |
| FR-87 | **Adzan & Pengingat Sholat** — mode: adzan, 5 menit sebelum, saat masuk waktu, pengingat setelah waktu berjalan + pilihan suara/dering | P0 | V1.5 | M | Tidak | Tiap mode bisa dipilih per waktu sholat; pengingat berbunyi walau aplikasi tertutup; tidak ada pengingat berulang tanpa henti |
| FR-88 | **Pelacakan Sholat 5 Waktu** — tombol cepat ✓ per waktu; status "selesai / belum tercatat" | P0 | V1.5 | S | Tidak | Menandai satu waktu ≤2 ketukan; status hari ini tampil di Today; tidak ada istilah menghakimi |
| FR-89 | **Riwayat & Konsistensi Sholat** — rekap mingguan/bulanan per waktu (mis. "Subuh 24/30 tercatat"), bukan skor keimanan | P1 | V2 | S | Tidak | Angka rekap cocok dengan data mentah (uji hitung); label memakai "tercatat" |
| FR-90 | **Kalender Hijriah** — tanggal Hijriah + hari besar, dengan **pilihan acuan kalender** (mis. rujukan resmi negara/pilihan pengguna) | P0 | V1.5 | M | Ya (cache) | Tanggal Hijriah berubah sesuai acuan yang dipilih; ada catatan bahwa penetapan awal bulan tertentu bisa berbeda; tetap tampil offline dari data tersimpan |
| FR-91 | **Ramadan Mode** — dashboard otomatis saat Ramadan: imsak, subuh, maghrib, puasa hari ini, sholat, bacaan, sedekah | P0 | V2 | M | Ya (cache) | Mode aktif otomatis pada rentang Ramadan; menampilkan hitungan hari ke-berapa; tidak mengubah data modul lain |
| FR-92 | **Pelacakan Puasa** — Ramadan, Senin-Kamis, Ayyamul Bidh, puasa sunnah lain, qadha, custom | P1 | V2 | M | Tidak | Target qadha diisi pengguna sendiri (aplikasi tidak menetapkan kewajiban); rekap per jenis akurat |
| FR-93 | **Pelacakan Quran** — bacaan, mendengar, hafalan, murajaah + target harian (mis. 1 halaman/hari) | P1 | V2 | M | Tidak | Progres & target tampil di Today bila modul aktif; penanda selesai/belum tanpa hukuman |
| FR-94 | **Pelacakan Hafalan (Hifz)** — per juz/surah: baru, murajaah, perlu diulang | P2 | V3 | M | Tidak | Membedakan hafalan baru vs murajaah; jadwal ulangan mengikuti aturan yang dipilih pengguna |
| FR-95 | **Dzikir & Doa** — pagi, petang, sebelum tidur + penghitung (mis. target 100, tercatat 67) | P1 | V2 | S | Tidak | Penghitung tersimpan & bisa direset; teks dzikir bersumber jelas |
| FR-96 | **Zakat & Sedekah** — catatan infaq/sadaqah + **asisten perhitungan zakat** (aset, acuan nisab, pelacakan haul) sebagai alat bantu, bukan keputusan | P1 | V3 | M | Ya (nisab) | Perhitungan menampilkan asumsi & sumber acuan nisab yang dipakai, serta penafian jelas bahwa keputusan akhir pada pengguna/ahli zakat |
| FR-97 | **Rencana Haji & Umrah** — target dana (terhubung Goal & Finance), daftar persiapan dokumen | P2 | V3 | M | Tidak | Target dana tampil sebagai progres di modul Goal; daftar persiapan memakai pengingat dokumen |
| FR-98 | **Arah Kiblat & Masjid Terdekat** — kompas dengan kalibrasi + cadangan arah mata angin bila sensor tidak layak; daftar masjid terdekat | P2 | V3 | M | Ya | Kompas menampilkan peringatan kalibrasi; saat sensor/izin tidak ada, aplikasi menampilkan arah alternatif, bukan angka palsu |
| FR-99 | **Islamic Morning Briefing** *(signature)* — Assalamualaikum, tanggal Hijriah, waktu sholat berikutnya + hitung mundur, target Quran, adhkar, agenda hari ini | P0 | V2 | M | Opsional | Satu layar memuat seluruh isi di atas; bagian yang butuh online (mis. cuaca) tetap absen rapi saat offline |
| FR-100 | **Islamic Evening Review & Muhasabah** — rekap ibadah hari ini + daftar refleksi (bukan penilaian): sholat terjaga, mengingat Allah, membantu orang, menghindari hal yang disesali, belajar, bersyukur + kolom tulisan | P1 | V2 | M | Tidak | Tidak ada skor/penilaian; refleksi tersimpan dan bisa dicari di Life Timeline |

### 7.4 Modul 4 — Wellbeing / Health OS (FR-101 … FR-117)

> **Prinsip modul ini:** aplikasi **mencatat & menunjukkan tren**, bukan mendiagnosis. Tidak ada pernyataan
> "Anda terkena penyakit X", tidak ada saran dosis/perubahan pengobatan. Kalimat yang dipakai:
> *"Angka Anda berubah dibanding catatan sebelumnya — pertimbangkan membicarakannya dengan tenaga kesehatan."*

| ID | Fitur | Prio | Fase | Est | Online | Kriteria terima (ringkas) |
|---|---|---|---|---|---|---|
| FR-101 | **Health Dashboard (tren)** — berat, tekanan darah, tidur, langkah, air, olahraga, suasana hati + arah naik/turun dibanding periode sebelumnya | P1 | V2 | M | Tidak | Setiap angka menampilkan **tren**, bukan hanya nilai hari ini; kosong = "belum ada data" |
| FR-102 | **Pencatat Aktivitas** — jalan, lari, sepeda, renang, gym, peregangan, olahraga, aktivitas rumah (durasi/jarak) | P1 | V2 | M | Tidak | Menampilkan total menit aktif hari ini & mingguan (grafik batang) |
| FR-103 | **Pencatat Tidur** — jam tidur, jam bangun, durasi, kualitas, tidur siang | P1 | V2 | S | Tidak | Durasi dihitung benar melewati tengah malam (uji khusus) |
| FR-104 | **Berat & Ukuran Tubuh** — berat, lingkar perut, lemak tubuh, IMT, massa otot, detak jantung istirahat + target | P1 | V2 | M | Tidak | Grafik tren + progres menuju target (%); IMT memakai rumus & satuan yang ditampilkan |
| FR-105 | **Jurnal Kesehatan (angka)** — tekanan darah, detak jantung, gula darah, suhu, saturasi oksigen, kolesterol, hasil lab + catatan satuan | P1 | V2 | M | Tidak | Menampilkan rata-rata & tren 30 hari; bisa menyimpan satuan yang dipakai pengguna |
| FR-106 | **Manajer Obat & Vitamin** — jadwal minum (jam & jumlah) + penanda "sudah diminum" | P1 | V2 | M | Tidak | Pengingat muncul di waktu yang ditetapkan; status harian mudah terlihat; **tidak ada** saran dosis |
| FR-107 | **Perkiraan Obat Habis & Pengingat Beli** — sisa tablet, perkiraan tanggal habis, pengingat membeli | P1 | V2 | S | Tidak | Perkiraan habis dihitung dari jadwal minum × sisa; pengingat muncul H-5 dan H-1 |
| FR-108 | **Brankas Catatan Medis** — hasil lab, pemeriksaan tahunan, resep, imunisasi, tagihan medis, catatan dokter, laporan pencitraan + pencarian | P1 | V3 | L | Tidak | Berkas tersimpan terenkripsi di perangkat; pencarian kata ("kolesterol") menemukan berkas & catatan terkait |
| FR-109 | **Janji Dokter di Kalender** — pemeriksaan, tes lab, kontrol + pengingat 7 hari/1 hari/2 jam | P1 | V2 | S | Tidak | Janji muncul di Today & Kalender; pengingat berlapis berjalan |
| FR-110 | **Catatan Makan Ringkas (quick log)** — per waktu makan, daftar sederhana + penilaian mutu (baik/cukup/kurang) | P2 | V3 | M | Tidak | Mencatat satu waktu makan ≤3 ketukan; tidak mengklaim hitungan kalori presisi |
| FR-111 | **Pencatat Air** — target harian + tombol +250 ml / +500 ml | P1 | V2 | S | Tidak | Jumlah harian akurat; muncul di kartu pilar Today |
| FR-112 | **Jurnal Suasana Hati & Stres** — pilihan suasana hati, tingkat energi & stres (1–5), catatan bebas | P1 | V2 | S | Tidak | Tersimpan per hari; bisa dicari di Life Timeline |
| FR-113 | **Mesin Temuan Kesehatan (insight)** — menghubungkan tidur ↔ suasana hati ↔ aktivitas ↔ berat, dalam bahasa netral | P2 | V3 | L | Tidak | Temuan hanya muncul bila data ≥30 hari dan menyebut dasar datanya; tidak ada klaim medis |
| FR-114 | **Peringatan Dini (watch)** — mis. berat naik 4 minggu berturut-turut, tidur di bawah kebiasaan, aktivitas menurun 14 hari | P2 | V3 | M | Tidak | Ambang batas dapat diatur; tiap peringatan menyertakan saran netral "pertimbangkan membicarakannya dengan tenaga kesehatan" |
| FR-115 | **Mode Kunjungan Dokter** — satu halaman ringkasan 30 hari (berat, tekanan darah, tidur, aktivitas, suasana hati, keluhan) yang bisa dicetak | P1 | V3 | M | Tidak | Menghasilkan 1 halaman PDF; angka identik dengan data aplikasi |
| FR-116 | **Laporan Kesehatan Bulanan** — perubahan berat/aktivitas/tidur/air/kebiasaan + "yang membaik, yang berubah, yang perlu perhatian" | P1 | V3 | M | Tidak | Laporan bulanan tersedia untuk setiap bulan yang punya data |
| FR-117 | **Profil Kesehatan & Kartu Darurat** — profil (golongan darah, alergi, kondisi, obat, kontak darurat) + kartu darurat yang bisa dibuka tanpa internet & tanpa membuka seluruh aplikasi | P1 | V2 | M | Tidak | Kartu darurat bisa ditampilkan dari layar kunci/saat offline; isi sensitif hanya bisa dibuka setelah autentikasi perangkat |


### 7.5 Modul 5 — Knowledge & Learning OS (FR-118 … FR-123)

| ID | Fitur | Prio | Fase | Est | Online | Kriteria terima (ringkas) |
|---|---|---|---|---|---|---|
| FR-118 | **Catatan & Ide** — simpan catatan, kutipan, tautan, foto, rekaman suara, tag; pencarian cepat | P2 | V3 | M | Tidak | Menyimpan catatan ≤3 ketukan dari mana pun (termasuk lewat "bagikan ke aplikasi"); pencarian menemukan isi catatan |
| FR-119 | **Jurnal Keputusan (Decision OS)** — keputusan: pilihan, alasan, risiko, biaya, hasil yang diharapkan, tenggat keputusan, keputusan final, tinjauan hasil 3/6/12 bulan | P2 | V3 | M | Tidak | Aplikasi mengingatkan meninjau hasil pada tanggal tinjauan; menampilkan "6 bulan lalu Anda memilih A karena X, hasilnya Y" |
| FR-120 | **Pelacakan Pembelajaran** — kursus, keahlian, jam belajar, tingkat penguasaan | P2 | V3 | M | Tidak | Jam belajar terakumulasi per keahlian; tampil di ringkasan Analytics |
| FR-121 | **Pengulangan Berkala (spaced repetition)** — jadwal ulangan untuk hafalan/kosakata/istilah | P2 | V4 | M | Tidak | Item yang dinyatakan lupa muncul kembali lebih cepat sesuai jadwal, dan dapat ditelusuri |
| FR-122 | **Pelacakan Buku & Bacaan** — daftar baca, sedang dibaca, selesai + catatan & kutipan | P2 | V3 | S | Tidak | Progres per buku tersimpan; kutipan tertaut ke buku asalnya |
| FR-123 | **Penghubung Pengetahuan** — tautkan catatan ↔ tujuan ↔ proyek ↔ tugas ↔ dokumen | P2 | V4 | M | Tidak | Satu catatan bisa tertaut ke beberapa entitas, dan tautan bisa dibuka dua arah |

### 7.6 Modul 6 — Home & Asset OS (FR-124 … FR-127)

| ID | Fitur | Prio | Fase | Est | Online | Kriteria terima (ringkas) |
|---|---|---|---|---|---|---|
| FR-124 | **Daftar Aset** — rumah, kendaraan, perangkat, furnitur, elektronik: tanggal beli, harga, nomor seri, garansi | P1 | V3 | M | Tidak | Total nilai aset tampil & bisa masuk ke perhitungan kekayaan bersih (FR-76) tanpa input ulang |
| FR-125 | **Jadwal & Riwayat Perawatan Aset** — servis berkala (oli, AC, tandon, filter), riwayat perbaikan, biaya | P1 | V3 | M | Tidak | Tiap aset punya pengingat perawatan; riwayat menyimpan biaya (terhubung pengeluaran) |
| FR-126 | **Garansi & Invoice** — lampiran berkas/struk per aset + pengingat berakhirnya garansi | P2 | V3 | S | Tidak | Garansi yang mendekati berakhir memunculkan perhatian di Today |
| FR-127 | **Perkiraan Umur Pakai & Penggantian** — estimasi masa guna + saran waktu pemeriksaan/penggantian | P2 | V4 | S | Tidak | Estimasi menampilkan dasar perhitungan; tidak ada klaim mutlak |

### 7.7 Modul 7 — Document OS (FR-128 … FR-130)

| ID | Fitur | Prio | Fase | Est | Online | Kriteria terima (ringkas) |
|---|---|---|---|---|---|---|
| FR-128 | **Brankas Dokumen & Masa Berlaku** *(memperluas FR-53)* — KTP, KK, paspor, SIM, STNK, sertifikat, ijazah, kontrak, polis, dokumen anak + tanggal berlaku/ perpanjangan | P0 | V2 | M | Tidak | Berkas tersimpan terenkripsi lokal; setiap dokumen menampilkan sisa hari menuju kedaluwarsa |
| FR-129 | **Pengingat Perpanjangan Berlapis** — H-90 / H-30 / H-7 / H-1 + tombol "sudah diperpanjang" yang memperbarui masa berlaku | P0 | V2 | S | Tidak | Semua tenggat memunculkan pengingat tepat waktu; menandai diperpanjang menghapus pengingat lama |
| FR-130 | **Salin Cepat & Bagikan Terkendali** — salin nomor paspor/KTP/KK tanpa membuka galeri; bagikan satu berkas dengan penyamaran bagian sensitif | P1 | V2 | S | Tidak | Salin satu ketukan; tidak ada berkas terkirim tanpa aksi pengguna yang jelas |

### 7.8 Modul 8 — Family OS (FR-131 … FR-133)

| ID | Fitur | Prio | Fase | Est | Online | Kriteria terima (ringkas) |
|---|---|---|---|---|---|---|
| FR-131 | **Anggota Keluarga & Tanggung Jawab** — tiap item punya pemilik & penanggung jawab (mis. tagihan sekolah: pemilik anak, penanggung jawab pasangan) | P1 | V3 | M | Tidak | Filter per anggota bekerja; data anak hanya bisa dilihat pengguna yang berhak |
| FR-132 | **Kalender Keluarga** — agenda bersama, ulang tahun, anniversary, kegiatan sekolah anak dalam satu tampilan | P1 | V3 | M | Tidak | Satu tampilan memuat agenda semua anggota dengan warna berbeda |
| FR-133 | **Kas & Tanggung Jawab Rumah Tangga** *(memperluas FR-43 & FR-47)* — "siapa bayar apa", pengingat halus satu ketukan, catatan pelunasan | P2 | V3 | L | Tidak | Riwayat siapa membayar apa akurat; pengingat tidak terkirim tanpa persetujuan pengguna |

### 7.9 Modul 9 — Travel OS (FR-134 … FR-135)

| ID | Fitur | Prio | Fase | Est | Online | Kriteria terima (ringkas) |
|---|---|---|---|---|---|---|
| FR-134 | **Perencanaan Perjalanan** — itinerary, tiket, hotel, anggaran, daftar bawaan, dokumen, pengingat keberangkatan | P2 | V4 | M | Tidak | Satu perjalanan menyatukan jadwal, anggaran (terhubung Finance) dan dokumen (terhubung Document OS) |
| FR-135 | **Jurnal Perjalanan** — foto, pengeluaran, tempat, penilaian, kenangan | P2 | V4 | M | Tidak | Pengeluaran perjalanan masuk laporan keuangan tanpa input ulang |

### 7.10 Modul 10 — Platform & Intelligence OS (FR-136 … FR-152)

| ID | Fitur | Prio | Fase | Est | Online | Kriteria terima (ringkas) |
|---|---|---|---|---|---|---|
| FR-136 | **Backup & Restore penuh** *(memperluas FR-24)* — JSON + berkas lampiran, dengan pratinjau isi backup sebelum restore | P0 | V2 | M | Tidak | Restore di perangkat lain menghasilkan data identik (uji banding jumlah baris & angka kunci) |
| FR-137 | **Cadangan Otomatis + Rotasi + Cek Integritas** — cadangan berkala, simpan N salinan terakhir, periksa keutuhan database | P0 | V2 | M | Tidak | Cadangan berjalan otomatis tanpa membuka aplikasi; hasil pemeriksaan integritas bisa dilihat pengguna |
| FR-138 | **Audit Log Pengguna** — catatan perubahan penting: "22:31 tagihan #18 ditandai lunas", "nominal diubah 300.000 → 325.000", "pengingat ditunda sampai 23:30" | P1 | V2 | M | Tidak | Setiap perubahan angka keuangan tercatat dengan waktu & nilai sebelum-sesudah; log bisa diekspor |
| FR-139 | **Search Everything** *(signature)* — satu kotak mencari tagihan, pembayaran, tugas, catatan, dokumen, jurnal, janji | P1 | V2 | M | Tidak | Mengetik "PLN" menemukan tagihan, riwayat pembayaran, catatan, dan dokumen terkait dalam satu daftar hasil |
| FR-140 | **Life Timeline** *(signature)* — seluruh kejadian hidup tersusun per hari/bulan/tahun, dapat dicari & disaring per modul | P1 | V3 | L | Tidak | Timeline akurat dari data nyata; menampilkan rangkuman "apa yang terjadi bulan ini" |
| FR-141 | **Personal Analytics** — ringkasan lintas modul untuk 7/30/90 hari dan 1 tahun | P2 | V3 | M | Tidak | Tiap angka dapat ditelusuri ke data asalnya (tidak ada angka misterius) |
| FR-142 | **Smart Insights** — temuan lintas modul: pengeluaran menyimpang, langganan jarang dipakai, titik saldo terendah, sebaran jatuh tempo ("73% tagihan jatuh pada minggu terakhir") | P2 | V3 | L | Tidak | Setiap temuan menyertakan dasar data & periode; hanya muncul bila data cukup |
| FR-143 | **Forecast** — proyeksi saldo beberapa bulan, perkiraan keterlambatan proyek, tabrakan tenggat | P2 | V4 | L | Tidak | Proyeksi menampilkan asumsi & rentang (bukan satu angka mutlak) |
| FR-144 | **Weekly Life Review** — rekap mingguan per pilar: apa yang membaik, apa yang perlu perhatian, fokus minggu depan | P2 | V3 | M | Tidak | Tersedia setiap pekan; dapat dikirim sebagai notifikasi ringkas |
| FR-145 | **Monthly Life Report** *(signature)* — laporan bulanan: keuangan, tagihan, tujuan, tugas, langganan, kekayaan bersih + "apa yang membaik / berubah / perlu perhatian" | P1 | V3 | M | Tidak | Tersedia untuk setiap bulan berjalan; bisa dibagikan sebagai PDF |
| FR-146 | **Annual Life Review** — "Your Year in Life": capaian, kebiasaan, keuangan, kesehatan, ibadah | P2 | V4 | M | Tidak | Membutuhkan data ≥6 bulan; hasil hanya ditampilkan bila datanya cukup (bukan dibuat-buat) |
| FR-147 | **Notification Center** — riwayat notifikasi dengan tingkat (mendesak/penting/biasa) + tanda selesai | P1 | V2 | M | Tidak | Riwayat lengkap dapat dibuka & disaring; jumlah notifikasi tidak berlebihan (maksimum per siklus tetap dijaga) |
| FR-148 | **Snooze & Reschedule Engine** *(memperluas FR-11 & memperbaiki PB-04)* — 15 menit, 1 jam, 3 jam, besok, akhir pekan, kustom; **jatuh tempo asli tidak berubah** | P0 | V2 | M | Tidak | Menunda pengingat tidak mengubah tanggal jatuh tempo; tunda bertahan setelah sinkronisasi (uji wajib) |
| FR-149 | **AI Copilot ber-konteks** — tanya jawab atas data sendiri ("apa yang harus saya prioritaskan besok?"), dengan izin eksplisit & penjelasan data apa yang dikirim | P2 | V4 | L | **Ya** | Jawaban hanya memakai data pengguna; saat offline atau tanpa izin, fitur mati dengan pesan jelas; tidak ada data yang dikirim tanpa persetujuan |
| FR-150 | **Sinkron Antar Perangkat & Cloud** *(memperluas FR-27)* — sinkron opsional, terenkripsi, pilihan penyedia atau server sendiri | P2 | V4 | L | **Ya** | Konflik data ditangani dengan aturan yang jelas & tidak menghilangkan data; sinkron bisa dimatikan sepenuhnya |
| FR-151 | **Widget & Akses Cepat Lanjutan** *(memperluas FR-31)* — widget Today interaktif (aksi langsung), aksi cepat ikon, tombol panel cepat | P1 | V2 | M | Tidak | Aksi dari widget langsung mengubah data & tersinkron dengan aplikasi (uji) |
| FR-152 | **Multi-bahasa & Multi-mata Uang** *(memperluas FR-52)* — Indonesia, Melayu, Inggris + Rupiah/Ringgit/USD | P2 | V4 | M | Ya (kurs) | Perubahan bahasa/mata uang berlaku konsisten; kurs menampilkan sumber & waktu pembaruan |

---



## II.3 Signature features (pembeda utama)

## 7.11 Signature Features (pembeda utama — dijaga paling ketat)

| # | Fitur | FR | Kenapa jadi pembeda |
|---|---|---|---|
| 1 | **Life Command Center (Today)** | FR-60 | Menjawab "hari ini saya harus apa" — pesaing hanya menampilkan daftar |
| 2 | **Islamic Life sebagai pilar sejajar** | FR-86…FR-100 | Tidak ada pesaing lokal yang mengikat ibadah ↔ keuangan ↔ kesehatan ↔ keluarga dalam satu aplikasi |
| 3 | **Life Search** | FR-139 | Satu kotak untuk seluruh data hidup |
| 4 | **Life Timeline** | FR-140 | Sejarah hidup yang bisa dicari & disaring |
| 5 | **Monthly & Annual Life Review** | FR-145, FR-146 | Alasan pengguna kembali setiap bulan/tahun |
| 6 | **Financial Calendar + Debt Strategy + Net Worth** | FR-73…FR-76 | Naik kelas dari "pengingat tagihan" ke "sistem keuangan" |
| 7 | **Document Vault bernyawa** | FR-128, FR-129 | Dokumen tahu kapan ia menjadi masalah |
| 8 | **Health tren + Mode Kunjungan Dokter** | FR-101, FR-115 | Berguna secara nyata saat ke dokter |
| 9 | **Snooze Engine + Notification Center** | FR-147, FR-148 | Notifikasi yang bisa dipercaya (setelah PB-04) |
| 10 | **Audit Log pengguna** | FR-138 | Menjawab "kenapa angka ini berubah?" — jarang ada di aplikasi sejenis |



---
---

# BAGIAN III — ARSITEKTUR, PELAKSANAAN & KEPUTUSAN TEKNIS

### III-8. Roadmap Fase (urutan yang disarankan)

**Aturan:** satu fase tuntas + uji hijau sebelum fase berikutnya. **Maksimal 8 fitur per fase.**

| Fase | Isi | Perkiraan | Gate (syarat dianggap selesai) |
|---|---|---|---|
| **F0 · Fondasi (WAJIB PERTAMA)** | PB-01…PB-16 (dokumen PRD Perbaikan) | 6–9 hari | 10 uji wajib perbaikan lulus; tombol notifikasi tidak lagi bisa menandai lunas keliru; pembayaran tidak bisa ganda |
| **V1.5 · Inti Harian + Islamic dasar** *(sesuai keputusan Papi #2-B)* | FR-60 Today · FR-61 Kartu Pilar · FR-62 Attention · FR-63 Morning Briefing · FR-68 Recurring · FR-71 Cashflow · FR-72 Budget · FR-76 Net Worth · **FR-86 Jadwal Sholat · FR-87 Adzan & pengingat · FR-88 Pelacakan 5 waktu · FR-90 Kalender Hijriah** (+ pendukung FR-65 & FR-67) | 4–5 minggu | Pengguna bisa memantau keuangan & menjalankan ibadah harian dari satu layar; notifikasi dapat dipercaya |
| **V2 · Pilar Kehidupan** | Islamic lanjutan: FR-89, 91, 92, 93, 95, 99, 100 · Document: FR-128, 129 · Platform: FR-136, 137, 138, 139, 147, 148 · Action: FR-78, 79 · Health dasar: FR-101, 102, 103, 106, 111 | 6–8 minggu | 5 pilar tampil di Today; data lintas modul terhubung; pencarian & audit log bekerja |
| **V3 · Pendalaman** | Islamic lanjutan (FR-89, 92, 93, 95, 96, 100) · Health lanjutan (FR-104, 105, 107, 108, 109, 112, 115, 116, 117) · Asset (FR-124, 125, 126) · Family (FR-131, 132, 133) · Knowledge (FR-118, 119, 120, 122) · Platform (FR-140, 141, 142, 144, 145) | 8–12 minggu | Timeline, review bulanan, dan insight bekerja dari data nyata |
| **V4 · Kecerdasan & Platform** | FR-143 Forecast · FR-146 Annual Review · FR-149 AI Copilot · FR-150 Sinkron · FR-134, 135 Travel · FR-121, 123 · FR-127 · FR-152 | 8–12 minggu | AI hanya memakai data pengguna dengan izin; sinkron tidak menghilangkan data |

*Semua angka adalah **diskusi, bukan komitmen**. Diasumsikan satu pengembang dengan lingkungan build siap dan
wajib lewat tahap uji di HP Papi sebelum dianggap selesai.*

---

### III-9. Arsitektur & Model Data (ringkas)

**Prinsip teknis**
1. **Satu database lokal** (Drift/SQLite) menjadi sumber kebenaran pengguna; setiap modul punya repositori sendiri
   dan tidak menulis langsung ke tabel modul lain.
2. **Notification Engine tunggal** dipakai semua modul (tagihan, obat, sholat, dokumen, janji, kebiasaan) —
   dengan aturan anti-bising global, snooze, dan riwayat (FR-147, FR-148).
3. **Sumber waktu tunggal** (`waktu.dart`) agar seluruh perilaku bisa diuji dan konsisten.
4. **Konsep occurrence**: tabel keadaan (mis. Tagihan = keadaan sekarang) **dipisah** dari tabel kejadian
   (RiwayatPembayaran = per periode). Ini prasyarat semua laporan & insight benar (menyambung PB-08).
5. **Lapisan data online**: setiap modul yang butuh data luar menyimpan `{nilai, sumber, waktuAmbil}`;
   saat offline, nilai terakhir tetap dipakai dengan label waktunya.
6. **Audit log lokal** mencatat setiap perubahan angka penting (FR-138) — lokal, tanpa telemetri.
7. **Migrasi bernomor** untuk setiap penambahan tabel/kolom + uji migrasi + cadangan otomatis sebelum naik versi.

**Kelompok tabel baru (perkiraan)**
- Keuangan: `transaksi`, `kategoriPengeluaran`, `anggaran`, `utang`, `pembayaranUtang`, `aset`, `nilaiAsetBulanan`
- Aksi & tujuan: `tujuan`, `proyek`, `tugas`, `kebiasaan`, `logKebiasaan`, `jurnalKeputusan`
- Islamic: `logSholat`, `logPuasa`, `logQuran`, `logDzikir`, `dzikir`, `cacheJadwalSholat`, `acuanKalenderHijriah`
- Kesehatan: `ukuranTubuh`, `catatanKesehatan`, `aktivitas`, `tidur`, `suasanaHati`, `obat`, `jadwalObat`, `berkasMedis`
- Dokumen & aset: `dokumen`, `masaBerlaku`, `berkasLampiran`, `perawatanAset`, `garansi`
- Keluarga & perjalanan: `anggotaKeluarga`, `penanggungJawab`, `perjalanan`, `itemPerjalanan`
- Platform: `notifikasiRiwayat`, `auditLog`, `catatan` (knowledge), `tautanPengetahuan`, `cacheOnline`, `unduhanCadangan`

**Navigasi:** 5 tab bawah (Today · Uang · Kerja · Ibadah · Lainnya) + kartu di Today sebagai pintu masuk utama.
**Kinerja:** Today wajib tampil < 500 ms dengan 1.000 baris data; daftar panjang memakai pemuatan bertahap.

---

### III-10. Keamanan & Privasi (wajib untuk modul sensitif)

| Bidang | Ketentuan |
|---|---|
| Enkripsi | Database terenkripsi (SQLCipher) + kunci per perangkat (kunci disimpan di penyimpanan aman perangkat) |
| Kunci masuk | PIN/biometrik + kunci otomatis (durasi bisa diatur) |
| Layar | Blokir screenshot/rekaman layar pada halaman sensitif (keuangan, dokumen, kesehatan) |
| Notifikasi | Isi notifikasi sensitif disamarkan di layar kunci (hanya "1 tagihan jatuh tempo") |
| Izin | Diminta bertahap & hanya saat fitur dipakai (lokasi hanya untuk modul sholat/lokasi; sensor hanya untuk kiblat) |
| Data anak & keluarga | Hanya terlihat oleh pengguna pemilik perangkat; tidak ada unggahan otomatis |
| Ekspor & bagikan | Selalu lewat tindakan pengguna; berkas sensitif diberi opsi penyamaran |
| Online | Setiap modul online menyatakan: data apa yang dikirim, ke mana, dan tombol mematikannya |
| AI | Izin eksplisit sebelum mengirim data; daftar data yang dikirim ditampilkan; hasil tidak disimpan di server pihak ketiga bila bisa dihindari |
| Telemetri | Tidak ada. Tidak ada penghasilan dari penjualan data |
| Kepatuhan toko | Formulir Data Safety & kebijakan privasi diperbarui setiap kali fitur online ditambahkan (termasuk cuaca/sholat/AI) |
| Uji keamanan per rilis | IDOR/akses lintas modul, path traversal berkas lampiran, kebocoran antar profil, penolakan akses tanpa autentikasi |

---

### III-11. Batas Aman Konten (tulisan & perilaku yang dilarang)

| Modul | Kalimat/perilaku yang DILARANG | Pengganti yang dipakai |
|---|---|---|
| Kesehatan | "Anda menderita X", saran dosis/perubahan obat, diagnosis dari foto | "Angka Anda berubah dibanding catatan sebelumnya. Pertimbangkan membicarakannya dengan tenaga kesehatan." |
| Islamic | "Skor iman 43", "Anda gagal hari ini", menyimpulkan "belum sholat" karena belum dicentang, memberi fatwa | "3 dari 5 sholat tercatat hari ini", "Maghrib belum tercatat", "Besok masih ada kesempatan" |
| Keuangan | Saran investasi/produk tertentu, janji hasil, menakut-nakuti utang | "Dengan pola sekarang, proyeksi saldo terendah pada <tanggal>. Asumsi: <daftar asumsi>." |
| Perilaku umum | Memaksa pengguna memberi izin; notifikasi tanpa batas; data terkirim tanpa izin | Izin diminta saat dibutuhkan; batas notifikasi per siklus; tombol mati per fitur |

---

### III-12. Metrik Keberhasilan

| Metrik | Sasaran awal | Cara ukur |
|---|---|---|
| Aktivasi | Pengguna baru mencatat ≥3 tagihan & menandai ≥1 lunas dalam 24 jam | Data lokal (opsional dibagikan pengguna) |
| Retensi harian (D7) | ≥ 35% membuka aplikasi ≥4 hari dalam seminggu pertama | Statistik lokal/uang pengguna |
| Retensi bulanan (D30) | ≥ 20% membuka laporan bulanan | Aplikasi |
| Kecepatan input | Mencatat item rutin ≤ 10 detik | Uji kegunaan |
| Keandalan | Bebas crash ≥ 99,5%; tidak ada kehilangan data | Uji perangkat + laporan pengguna |
| Notifikasi dipercaya | ≥ 95% pengingat muncul tepat waktu di ≥4 perangkat uji | Gate F3 (uji di HP) |
| Konversi Pro | 3–5% pengguna aktif bulanan | Pembelian |

---

### III-13. Monetisasi (usulan)

| Paket | Isi | Alasan |
|---|---|---|
| **Gratis** *(dikunci oleh Keputusan Papi #3-A)* | Today, tagihan & langganan, pengingat, kalender, cashflow dasar, budget dasar, **seluruh modul Islamic**, **Health dasar (pencatatan & pengingat)**, backup manual, audit log | Ibadah & kesehatan dasar **tidak dijual** — itu bagian dari nilai dasar produk dan sumber ulasan baik |
| **Pro** *(dikunci oleh Keputusan Papi #4-A: satu harga, Rp399.000/tahun)* | Multi-profil, laporan PDF/Excel, Net Worth & Debt Strategy, Brankas Dokumen, brankas catatan medis, Health insight lanjutan, AI Copilot (kuota), Sinkron cloud/multi-perangkat, tema premium, kunci aplikasi | Fitur yang dipakai pengguna serius & bernilai jangka panjang |
| **Sekali bayar (opsional)** | Modul Aset/Travel/Learning | Alternatif bagi pengguna yang menolak langganan |

Catatan: kupon & diskon sudah dipahami dari toko yang ada — bisa dipakai untuk peluncuran modul baru.

---

### III-14. Risiko & Mitigasi

| Risiko | Mitigasi |
|---|---|
| Cakupan melebar (93 fitur) → aplikasi membingungkan | Maksimal 8 fitur per fase; satu fase tuntas dulu; menu maksimal 5 tab |
| Fondasi belum benar → data rusak | Gate F0: PB-01…PB-08 wajib lulus sebelum fitur apa pun |
| Modul kesehatan/agama menimbulkan masalah etika/regulasi | Batas aman §11 ditulis sebagai aturan produk; semua teks lewat pemeriksaan |
| Data sensitif bocor | §10: enkripsi, kunci biometrik, blokir screenshot, izin bertahap, tanpa telemetri |
| Ketergantungan layanan luar (sholat, kurs, AI) | Cache + label waktu data + perilaku offline jelas + sumber alternatif |
| Sinkronisasi antar perangkat menghilangkan data | Aturan konflik eksplisit + cadangan sebelum sinkron + uji pemulihan |
| Kapasitas build server (RAM 12 GB dipakai bersama) | Build dijalankan dengan memori terbatas & container dihentikan setelah dipakai; jalur build dapat dipindah ke server lain bila perlu |
| Waktu pengujian perangkat | Uji wajib di HP Papi setiap fase (termasuk notifikasi) |

---

### III-15. Status Keputusan (SELESAI — 13 Sep 2026)

Seluruh 7 butir **sudah diputuskan Papi** dan tercatat di **§0** dokumen ini:
fondasi dulu · V1.5 = 8 fitur inti + Islamic dasar · Islamic & Health dasar gratis ·
Pro satu harga Rp399.000/tahun · AI lewat server sendiri (fase V4) · sinkron cloud menyusul
(tanpa cloud dulu) · nama tetap "Personal Life OS".

Tidak ada keputusan yang menggantung. Hal-hal yang masih bisa berubah **bukan keputusan produk**,
melainkan hal teknis pelaksanaan (mis. nama berkas, urutan uji, ukuran ikon) dan tidak perlu menunggu Papi.

### III-16. Definition of Done (per fitur & per fase)

**Per fitur**
1. Ada **kriteria terima** yang bisa diperiksa (§7) dan terpenuhi.
2. Ada uji otomatis untuk logika inti + bukti uji (keluaran perintah/tangkapan layar).
3. Tidak merusak fitur lama (uji regresi hijau).
4. Bila menyentuh data sensitif: lewat daftar periksa keamanan §10.
5. Bila butuh online: ada perilaku offline, label waktu data, dan tombol mati.

**Per fase**
6. Semua fitur fase lulus; tidak ada fitur "setengah jalan" yang dipamerkan sebagai selesai.
7. Diuji di HP Papi (minimal: buka, catat, pengingat, laporan).
8. Backup sebelum perubahan + rollback disiapkan.
9. Laporan 3 poin (berhasil apa · berkas mana · langkah lanjut) + catatan jujur bagian yang belum teruji.

---

### LAMPIRAN A — Peta Ide ChatGPT → ID Fitur (bukti tidak ada yang hilang)

| Ide di obrolan | Menjadi |
|---|---|
| Smart Home / Today, Life Command Center | FR-60, FR-61, FR-62 |
| Recurring & Subscription Manager | FR-68, FR-70 |
| Subscription intelligence (per bulan/tahun) | FR-69 |
| Cashflow & Budget (income/expense, budget vs actual) | FR-71, FR-72 |
| Financial Calendar | FR-73 |
| Debt Manager + strategi Avalanche/Snowball | FR-74, FR-75 |
| Net Worth Tracker | FR-76 |
| Goal System (Goal → Project → Task) | FR-78, FR-82 |
| Reminder Intelligence (eskalasi 7/3/1/H/terlambat) + Notification Center | FR-147 (eskalasi sudah ada di FR-10/FR-16, diperkuat) |
| Snooze / Reschedule Engine (jatuh tempo asli tidak berubah) | FR-148 |
| Search Everything | FR-139 |
| Universal Activity / Life Timeline | FR-140 |
| Smart Insights | FR-142 |
| Monthly Life Report + AI review | FR-145 |
| Life Score / Life Health (tanpa gamifikasi berlebihan) | FR-61, FR-85 |
| Backup & Recovery (export/import/CSV/otomatis/rotasi/cek integritas) | FR-136, FR-137 |
| Audit Log | FR-138 |
| Family / Household | FR-131, FR-132, FR-133 |
| Health: dashboard tren, aktivitas, tidur, berat, jurnal angka, obat, refill, catatan medis, janji, catatan makan, air, jurnal suasana hati, insight, peringatan dini, mode kunjungan dokter, laporan, profil, kartu darurat | FR-101 … FR-117 |
| Islamic: jadwal sholat, adzan, pelacakan 5 waktu, riwayat, kalender Hijriah, Ramadan mode, puasa, Quran, hifz, dzikir, zakat/sedekah, haji/umrah, kiblat & masjid, morning briefing, evening review/muhasabah | FR-86 … FR-100 |
| Personal Knowledge OS | FR-118, FR-123 |
| Decision OS | FR-119 |
| Learning OS + spaced repetition | FR-120, FR-121 |
| Home & Asset OS | FR-124, FR-125, FR-126, FR-127 |
| Document Vault | FR-128, FR-129, FR-130 |
| Emergency & Safety OS + Emergency Card | FR-117 (kartu darurat & profil) |
| Travel OS + Trip Journal | FR-134, FR-135 |
| Life Planning Engine (Vision → … → Habits) | FR-82, FR-83 |
| Sleep & Energy OS | FR-84, FR-103 |
| Habit & Behavior OS + recovery | FR-80, FR-81 |
| Personal Analytics | FR-141 |
| Life Forecast | FR-143 |
| Personal AI Copilot | FR-149 |
| Life Briefing / Weekly Review / Annual Review | FR-63, FR-144, FR-146 |
| 10 OS arsitektur + alur Capture → Improve | §5 dan §9 dokumen ini |

### LAMPIRAN B — Yang Ditolak atau Ditunda (dengan alasan)

| Ide | Keputusan | Alasan |
|---|---|---|
| Diagnosis/penilaian kesehatan oleh aplikasi | **Ditolak** | Bukan alat medis; berisiko & melanggar batas aman §11 |
| "Skor iman" / penilaian ibadah | **Ditolak** | Aplikasi bukan hakim; bertentangan dengan prinsip tidak menghakimi |
| Fatwa & keputusan hukum zakat/qadha oleh aplikasi | **Ditolak** | Bukan kewenangan aplikasi; hanya alat bantu hitung |
| Nasihat investasi & rekomendasi produk keuangan | **Ditolak** | Bukan penasihat keuangan berizin |
| Bot penghitung kalori presisi / klon MyFitnessPal | **Ditunda** | Fokus pada kebiasaan; presisi kalori butuh basis data besar |
| Aplikasi Quran lengkap (mushaf, audio besar) | **Ditunda** | Ukuran & lisensi; cukup pelacakan + sumber terverifikasi |
| Pembacaan SMS/notifikasi bank otomatis | **Ditunda** | Izin sensitif, risiko kebijakan Play; jalur aman = tempel mutasi |
| Pembayaran langsung dari aplikasi | **Ditunda** | Butuh kerja sama pihak ketiga |
| 100+ menu / semua fitur sekaligus | **Ditolak** | Aturan maksimal 8 fitur per fase & maksimal 5 tab |
| Gamifikasi berat (poin, hukuman, streak yang menghukum) | **Ditolak** | Bertentangan dengan prinsip pendamping, bukan hakim |

---

## Referensi

- Obrolan ide Papi & ChatGPT — `fitur baru personal life os.txt` (13 Sep 2026)
- PRD Personal Life OS v1.6 (`PRD_PERSONAL_LIFE_OS.md`) — FR-01…FR-59, fase F0–F8
- PRD Perbaikan v1.0 (`PRD_PERBAIKAN_LIFE_OS_v1.0.md`) — PB-01…PB-16 (prasyarat)
- Repo audit publik: `https://github.com/sam8888888888/personal-life-os`
- Jalur kerja Aaron: `/home/aaron/lifeos-penyempurnaan` (cabang `aaron/penyempurnaan`)

---
*Disusun oleh Dato' Dr. H. Sami'an, M.B.A*
