# HANDOVER — FONDASI DATA V1.5 (SKEMA v3) — dari Aaron

**Kepada:** Dinda · **Dari:** Aaron Salahuddin
**Waktu:** 15 Sep 2026, 03:00 UTC (10:00 WIB / 11:00 MYT)
**Cabang serahan:** `v15-data-aaron` — commit `11858ae` (kode) + `8e16ccb` (uji)
**Dasar:** `PRD_PERSONAL_LIFE_OS_MASTER_v3.1.md` §0 butir 2 (gelombang V1.5) dan
`SISA_FITUR_PRD_v3_1.md` bagian 4 — butir 2 & 3 (yang selama ini menunggu saya).

> Ringkas: **`lib/data/**` dan seed kategori untuk FR-68, FR-71, FR-72, FR-76 sudah
> dibuka.** Kamu tidak perlu menunggu lagi untuk 4 fitur itu.

---

## 1. Yang sudah dikerjakan (dengan bukti terukur)

| Hal | Hasil | Bukti |
|---|---|---|
| Tabel baru (skema v3) | **8 tabel** | lihat daftar di bawah |
| Repository baru | **5 berkas** | `lib/data/repository/*` |
| Kategori kas bawaan | **23** (11 pengeluaran + 12 pemasukan) | uji "seed kategori transaksi" |
| Uji baru | **36** (34 perilaku + 2 migrasi) | `test/v15_data_test.dart`, `test/v15_migrasi_test.dart` |
| `flutter analyze` | **No issues found!** | dijalankan 15 Sep 2026 di container build |
| `flutter test` (seluruh proyek) | **264 lulus / 266** | 2 gagal = tangkapan layar f5 yang memang rapuh tanggal (lihat §3) |

**Daftar tabel (skema v3, `schemaVersion = 3`):**

1. `kategori_transaksi` — kategori kas Indonesia (kode stabil, jenis, ikon, warna, sifat arus)
2. `transaksi` — satu baris arus kas (kunci idempotensi `id_transaksi`)
3. `anggaran_bulanan` — batas anggaran per kategori per bulan (`kategori_id = 0` = total bulan)
4. `langganan` — langganan berulang, tertaut ke mesin tagihan lama
5. `aset` — daftar aset (kas, bank, investasi, properti, kendaraan, emas, kripto, bisnis, lain)
6. `kewajiban` — daftar kewajiban (kartu kredit, KPR, pinjaman, cicilan, lain)
7. `nilai_aset_bulanan` — riwayat nilai aset per bulan (terkunci bila bulan lampau)
8. `nilai_kewajiban_bulanan` — riwayat nilai kewajiban per bulan

**Repository baru:** `periode.dart` (kunci `YYYY-MM` + rentang bulan),
`template_kategori_transaksi.dart` (23 kategori siap seed),
`kategori_transaksi_repository.dart`, `transaksi_repository.dart`,
`anggaran_repository.dart`, `langganan_repository.dart`, `aset_repository.dart`
(aset + kewajiban + nilai bersih + tren).

---

## 2. Cara melihat dan menggabung

```bash
# lihat isinya
git log --oneline master..v15-data-aaron

# gabung (pilih salah satu)
git merge v15-data-aaron
# atau per commit
git cherry-pick 11858ae 8e16ccb
```

**WAJIB setelah gabung** (kalau tidak, tabel baru tidak dikenal):

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # database.g.dart bertambah 8 tabel
flutter analyze
flutter test
```

> **Catatan penting soal cabang:** `v15-data-aaron` **sudah memuat** seluruh
> perbaikan fondasi PB-01…PB-16 (commit `f3e8581`) **dan** penggabungan dengan
> V1.5 milikmu (`3c870a0`) — jadi setelah cabang ini digabung, cabang
> `fondasi-aaron` **tidak perlu digabung lagi**.


---

## 3. Syarat uji setelah gabung — dan satu catatan jujur

- `flutter analyze` → **No issues found!**
- `flutter test` → **264 lulus, 2 gagal**: `tangkapan layar tab hari ini` dan
  `tangkapan layar tab kerja` (`f5_today.png`, `f5_kerja.png`).

**Dua kegagalan itu bukan dari perubahan data ini.** Saya sudah memeriksanya di
worktree bersih pada commit `1b07306` (sebelum satu pun berkas data saya masuk) —
gagal juga, diff **15,30% (520.337 piksel)** pada `f5_kerja.png`. Penyebabnya sudah
kamu tulis sendiri di berkas uji itu: tangkapan 5 tab memakai rute sungguhan
sehingga tanggalnya mengikuti hari berjalan. Jadi angka "230/230 hijau" benar
**pada hari tangkapan dibuat**, bukan sesudahnya.

Saran perbaikan (pilih satu, terserah kamu karena berkas layarnya milikmu):

1. **Terbaik:** layar tab (`today`, `kerja`, `uang`, `ibadah`, `lainnya`) membaca
   waktu lewat `waktuSekarang()` dari `lib/core/utils/waktu.dart` seperti layar
   lain, lalu tangkapan dibuat ulang **sekali** — sesudah itu uji emas stabil
   selamanya.
2. **Sementara:** jangan jadikan "semua uji hijau" sebagai syarat serahan; tulis
   di laporan bahwa 2 tangkapan tab memang harus dibuat ulang bila ganti hari.

**Konstrain yang TIDAK boleh hilang saat menyunting:** indeks unik SQL di
`database.dart` (`idx_riwayat_periode`, `idx_pemasukan_bulan`, dan **semua** indeks
`v3`). Indeks-ini yang menjaga "satu periode = satu pembayaran", "satu bulan = satu
baris pemasukan", "satu kode kategori = satu baris", "satu periode+kategori = satu
anggaran", dan "satu aset/bulan = satu nilai". Jangan diganti anotasi `uniqueKeys`
tanpa memverifikasi ulang.

---

## 4. Keputusan atas pertanyaan yang kamu tulis untuk saya

Pertanyaanmu di `rancangan/TABEL_DB_V1_5.md` §8 dan `rancangan/KATEGORI_KEUANGAN_ID.md` §13:

| # | Pertanyaanmu | Keputusan saya | Alasan |
|---|---|---|---|
| 1 | Opsi A (tabel `KategoriTransaksi` baru) atau Opsi B (tambah kolom `jenis` di `Kategori`)? | **Opsi A** | kategori tagihan ("PLN", "BPJS") dan kategori kas ("Makan & Minum") berbeda arti; tidak ada tabel lama yang perlu diubah |
| 2 | Empat kolom tambahan (`kode`, `indukKode`, `sifatArus`, `perlakuanKas`)? | **`kode`, `indukKode`, `sifatArus` dipakai. `perlakuanKas` DITUNDA.** | `kode` wajib supaya seed ulang tidak menggandakan kategori saat nama diubah; `indukKode` menyiapkan sub-kategori; `sifatArus` sudah dipakai FR-68. `perlakuanKas` ("pinjaman diterima bukan pendapatan") menyangkut FR-74 yang belum dibangun — saya tidak mau ada kolom yang belum punya perilaku teruji. Perilakunya akan ditambahkan bersama tabel pembayaran kewajiban (nanti). |
| 3 | `AnggaranBulanan` penanda `0` untuk total, atau indeks unik parsial? | **Penanda `0`** | SQLite menganggap NULL berbeda-beda pada indeks unik, jadi penanda 0 lebih sederhana dan jaminannya tetap satu baris per periode+kategori; keabsahan id diperiksa di repository |
| 4 | Hapus tagihan: apa yang terjadi pada langganan & transaksi tertaut? | **Langganan → `status = berhenti` + `tagihan_id` dikosongkan; Transaksi → `tagihan_id` dikosongkan, barisnya TETAP ada** | uangnya benar-benar keluar; riwayat kas tidak boleh hilang diam-diam (aturan MASTER: baris jangan hilang, nilai dikosongkan + catatan) |
| 5 | Hapus aset: cascade atau hapus manual? | **Arsip dulu (`arsip = true`); hapus aset = hapus riwayatnya dalam satu transaksi** | aman dari salah tekan, pola sama seperti `TagihanRepository.hapus()` |
| 6 | Sub-kategori 130 butir di-seed sekarang? | **Belum.** Kolom `induk_kode` sudah siap. | 23 kategori tingkat atas sudah cukup untuk FR-71/FR-72; seed-nya idempoten (kunci `kode`) sehingga sub-kategori bisa ditambah kapan saja **tanpa migrasi baru** |
| 7 | Label UI "Utang & Cicilan" → "Cicilan & Utang"? | **Belum saya putuskan** — nama kategori di database memakai nama dokumenmu ("Utang & Cicilan"). Label UI menunggu keputusan Papi | §13 butir 6 milik Papi, bukan milik saya |
| 8 | Kunci periode | **Ketat `YYYY-MM`** (`2026-09` diterima, `2026-9` ditolak) | supaya bulan yang sama tidak terbelah dua kunci |

---

## 5. Aturan yang saya tegakkan di lapisan data (berguna saat kamu pakai)

- **`langganan.pause` menghentikan pengingat tanpa menghapus riwayat:** pause →
  `Tagihan.statusAktif = false` pada tagihan tertaut; `aktifkan` → hidup lagi.
  Tidak ada mesin pengingat baru — pengingat tetap dijadwalkan dari tabel Tagihan.
- **`lepasTautan` menghidupkan kembali tagihan** (lebih aman: pengingat berlebih
  masih bisa dimatikan pengguna daripada pengingat mati diam-diam).
- **Nilai kekayaan tidak berubah retroaktif:** nilai bulan lampau otomatis
  `terkunci`; mengubahnya wajib `paksa: true` **dan** `alasan`, jejaknya disimpan
  (`dibuka_kunci_pada`, `alasan_buka_kunci`).
- **Nilai bersih tidak disimpan** — selalu dihitung aset − kewajiban, jadi tidak ada
  dua angka yang bisa tidak sinkron.
- Nilai yang belum ada memakai nilai awal (`nilai_awal_sen` / `saldo_awal_sen`),
  jadi layar tidak kosong di perangkat baru.
- Semua nominal **sen** (integer), sama seperti tabel lama.
- `hapusSemuaData` (pengaturan) kini juga mengosongkan tabel v3 — kategori bawaan
  tetap disisakan, sama seperti kategori tagihan bawaan.

---

## 6. Yang BELUM termasuk (jujur, jangan dianggap selesai)

1. **Fondasi notifikasi FR-63 & FR-87** masih saya pegang. Rencana saya:
   menambah kanal `briefing` & `sholat` + saluran `sumberTambahan` pada
   `PenyinkronPengingat`, sehingga **kamu** menulis adapter kecil dari data
   kota/jadwal sholatmu (`PenghitungSholat`/`PenyimpananJadwal`), tanpa harus
   menyentuh `lib/core/notifikasi/**`. Sampai itu jadi, FR-63 (notifikasi 06:00)
   dan FR-87 (adzan) belum bisa kamu selesaikan.
2. **UI apa pun** untuk FR-68/71/72/76 belum ada — itu bagianmu.
3. FR-69, FR-70, FR-73, FR-74, FR-75 belum (V2): tabel `pembayaranKewajiban` belum
   dibuat, `perlakuanKas` belum ada.
4. Migrasi **hanya diuji v2 → v3**. Belum ada uji v1 → v3 (tidak ada perangkat v1
   lagi di jalur uji). Migrasi v1 → v2 sudah pernah ada dan tidak saya ubah.
5. Uji notifikasi tepat waktu / widget tetap **hanya bisa** diverifikasi di HP Papi.

---

## 7. Berkas yang menjadi milik bersama setelah gabung

| Berkas | Perlakuan |
|---|---|
| `lib/data/database/database.g.dart` | **generated** — hasil `build_runner`; jangan disunting manual; regenerate setelah menarik cabang ini |
| `lib/data/database/tabel.dart`, `database.dart` | milik bersama (kamu menambah kolom = tambah migrasi + tambah uji migrasi) |
| `lib/data/model/enums.dart` | milik bersama (enum baru: `JenisArus`, `SifatArus`, `StatusLangganan`, `JenisAset`, `JenisKewajiban`) |
| `test/v15_data_test.dart`, `test/v15_migrasi_test.dart` | milik bersama |

---

*Disusun oleh Aaron Salahuddin · 15 Sep 2026 · untuk Dinda — jalur data V1.5.*
