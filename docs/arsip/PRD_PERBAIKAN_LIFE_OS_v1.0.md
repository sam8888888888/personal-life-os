# PRD PERBAIKAN — PERSONAL LIFE OS
### (hasil audit eksternal ChatGPT + verifikasi independen oleh Aaron)

| Item | Keterangan |
|---|---|
| Produk | Personal Life OS — aplikasi Android (Flutter), pengingat tagihan & keuangan pribadi |
| Dokumen | PRD Perbaikan v1.0 (dokumen kerja, bukan dokumen jual) |
| Tanggal | 12 Sep 2026, 17:30 UTC (13 Sep 00:30 WIB / 01:30 MYT) |
| Status | **DRAFT — menunggu tinjauan Papi** |
| Penyusun | Aaron Salahuddin (verifikasi teknis langsung ke kode) |
| Sumber acuan | (1) Audit eksternal ChatGPT atas ZIP `personal-life-os-audit.zip` · (2) Kode di `/home/aaron/lifeos-penyempurnaan` (snapshot untuk audit) · (3) PRD Personal Life OS v1.6 (FR-01…FR-59) |
| Pemilik eksekusi | Dinda (Prime Agent Hub) — atas persetujuan Papi |
| Nomor fitur | Memakai awalan **PB-** (Perbaikan) agar tidak bentrok dengan FR-01…FR-59 |

---

## 1. Ringkasan Eksekutif

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

## 2. Latar Belakang

1. Papi meminta kode diaudit pihak luar agar diketahui kekurangannya. Repo publik dibuat
   (`github.com/sam8888888888/personal-life-os`) dan ZIP audit diserahkan ke ChatGPT.
2. ChatGPT menyerahkan audit statis: 18 temuan, 5 kritis, disertai usulan arsitektur.
3. Agar perbaikan tidak salah arah, **setiap temuan diverifikasi ulang** terhadap kode nyata:
   yang benar dipakai, yang keliru/berlebihan dibuang, yang ambigu dijadikan keputusan produk.

---

## 3. Tujuan & Non-Tujuan

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

## 4. Metode Verifikasi (supaya bisa diaudit balik)

- Setiap butir dicek dengan membaca kode di snapshot `sumber` (baris & berkas dicantumkan).
- Klaim yang menyangkut perilaku **diuji ulang** dengan `flutter analyze` + `flutter test`
  (status saat ini: **80/80 lulus**, analyze bersih) — artinya bug yang terbukti **lolos** dari uji yang ada.
- Berkas bukti: `docs/AARON-CHANGES.diff` (perubahan jalur penyempurnaan) dan repo audit.

---

## 5. Hasil Verifikasi 18 Temuan

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

## 6. Rencana Perbaikan (detail per butir)

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

## 7. Uji Wajib Ditambahkan (menggantikan asumsi "sudah teruji")

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

## 8. Perubahan Skema Database (migrasi)

| Versi | Perubahan | Catatan migrasi |
|---|---|---|
| v1 (sekarang) | Skema awal | — |
| v2 | UNIQUE `RiwayatPembayaran(tagihanId, periodeJatuhTempo)`; UNIQUE `PemasukanBulanan(bulan)` | Sebelum membuat indeks unik: deteksi duplikat, pertahankan 1 baris (yang tertua/menurut aturan yang ditetapkan), hapus sisanya, **catat jumlahnya** ke audit/jejak. Tanpa langkah ini, migrasi bisa gagal di perangkat pengguna yang sudah punya duplikat. |

---

## 9. Keputusan yang Diminta dari Papi (hanya 2)

1. **Rollover akhir bulan (PB-13/#13):** bila jatuh tempo 31 Januari, setelah dibayar:
   - **Rule A** — menempel: 28 Feb → 28 Mar → 28 Apr (perilaku sekarang, sesuai PRD lama)
   - **Rule B** — kembali ke tanggal asli: 28 Feb → **31 Mar** → 30 Apr (umum dipakai untuk langganan)
   Rekomendasi saya: **Rule B**, dengan catatan tanggal asli disimpan (`tanggalAsli`), agar jatuh tempo tidak "mundur" permanen.
2. **Notifikasi uji:** apakah notifikasi uji tetap ada (untuk melatih Papi di HP), atau disembunyikan setelah Papi berhasil menguji notifikasi?

---

## 10. Roadmap & Estimasi

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

## 11. Risiko & Mitigasi

| Risiko | Mitigasi |
|---|---|
| Perbaikan notifikasi mengubah perilaku yang sudah disetujui Papi | Uji matriks aksi (10 butir §7) dijalankan sebelum & sesudah; rollback tersedia (commit terpisah per PB) |
| Migrasi v2 gagal di perangkat lama karena duplikat | Bersihkan duplikat + verifikasi jumlah baris sebelum & sesudah migrasi, saat aplikasi pertama kali dibuka |
| Perubahan dasbor (PB-08) menimbulkan angka ganda | Definisi tunggal: "total periode X = riwayat periode X + tagihan aktif belum lunas periode X"; uji dengan data contoh |
| Bug tetap lolos ke perangkat nyata | Uji lewat `NotificationResponse` (tanpa HP) **dan** uji tekan-tombol manual di HP Papi sebelum rilis |
| Jadwal nyata tidak terbukti di server | Batas yang diakui: ketepatan waktu notifikasi hanya bisa dibuktikan di HP (gate F3) |

---

## 12. Definition of Done

Dinyatakan selesai bila **semua** benar:
1. 10 uji wajib §7 ada dan **lulus**; uji §7.1–§7.4 **gagal** bila PB-01 dibalik (dibuktikan dengan percobaan sengaja).
2. `flutter analyze` bersih; seluruh uji lama tetap hijau (tidak ada regresi).
3. Skema v2 terpasang dengan migrasi bersih-duplikat + laporan jumlah baris yang dibersihkan.
4. Bukti nyata: tangkapan layar/keluaran perintah + hasil uji ditempel di laporan.
5. Diuji tekan-tombol di HP Papi: "Buka aplikasi" **tidak** mengubah data, "Tunda 1 jam" bertahan setelah sinkronisasi.
6. Laporan 3 poin (berhasil apa · berkas mana · langkah lanjut) + catatan jujur bagian yang belum teruji.

---

## 13. Referensi

- Repo audit publik: `https://github.com/sam8888888888/personal-life-os` (snapshot F1–F3 + perubahan jalur penyempurnaan)
- `docs/AARON-CHANGES.diff` — seluruh perubahan jalur penyempurnaan
- PRD Personal Life OS v1.6 (`PRD_PERSONAL_LIFE_OS.md`) — FR-01…FR-59, fase F0–F8
- Laporan fase: `LAPORAN_F1.md`, `LAPORAN_F2.md`, `LAPORAN_F3.md`
- Berkas kode yang menjadi objek perbaikan: `lib/core/notifikasi/*`, `lib/data/repository/tagihan_repository.dart`,
  `lib/data/database/tabel.dart`, `lib/data/repository/pengaturan_repository.dart`,
  `lib/features/ringkasan/ringkasan_screen.dart`, `lib/features/kalender/kalender_screen.dart`,
  `lib/features/tagihan/form_tagihan_screen.dart`, `test/f3_pengingat_test.dart`

*Disusun oleh Dato' Dr. H. Sami'an, M.B.A*
