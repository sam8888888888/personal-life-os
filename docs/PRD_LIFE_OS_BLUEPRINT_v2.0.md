# BLUEPRINT & PRD FITUR — PERSONAL LIFE OS
## Rencana Upgrade v2.0 (Master Blueprint)

| Item | Keterangan |
|---|---|
| Produk | Personal Life OS — Android (Flutter) |
| Dokumen | Blueprint & PRD Fitur v2.0 — *bahan upgrade fitur selanjutnya* |
| Versi | 2.0 (DRAFT) |
| Tanggal | 13 Sep 2026, 01:20 WIB (12 Sep 18:20 UTC) |
| Status | **DRAFT — menunggu tinjauan & keputusan Papi** |
| Penyusun | Aaron Salahuddin (perapian ide + verifikasi teknis) |
| Sumber | (1) Hasil obrolan Papi dengan ChatGPT (dokumen `fitur baru personal life os.txt`) · (2) PRD Personal Life OS v1.6 (FR-01…FR-59) · (3) PRD Perbaikan v1.0 (PB-01…PB-16) · (4) kode nyata di `/home/aaron/lifeos-penyempurnaan` |
| Nomor fitur baru | **FR-60 … FR-152** (93 fitur) — tidak menimpa FR-01…FR-59 |
| Perbaikan wajib | **PB-01 … PB-16** (dokumen terpisah) — **prasyarat**, bukan pilihan |

---

## 1. Ringkasan Eksekutif

ChatGPT (atas permintaan Papi) menghasilkan gagasan yang arahnya benar dan besar: Personal Life OS
**bukan** aplikasi tagihan, tetapi **satu layar yang menjawab "hari ini saya harus apa"** — plus perluasan
menjadi 10 modul (Knowledge, Goal, Action, Finance, Asset, Family, Islamic, Wellbeing, Document,
Intelligence) yang semuanya bermuara pada satu hal: **tindakan**, bukan sekadar catatan.

Dokumen ini merapikan seluruh gagasan itu menjadi **93 fitur bernomor (FR-60…FR-152)**, dikelompokkan
per modul, diberi prioritas (P0/P1/P2), fase (V1.5/V2/V3/V4), estimasi, kebutuhan online, dan
**kriteria terima yang bisa diperiksa** — supaya bisa dieksekusi bertahap dan tidak menjadi aplikasi
raksasa yang membingungkan.

Tiga penilaian saya yang menentukan bentuk dokumen ini:

1. **Gagasan ChatGPT benar, tetapi urutannya harus dibalik.** Ia sendiri menulis: *"kalau fondasi datanya
   salah, AI hanya akan menghasilkan insight yang terlihat pintar tetapi sebenarnya salah."* Saya
   memperkuat itu: **selesaikan dulu 16 perbaikan (PB-01…PB-16)** — terutama tombol notifikasi yang bisa
   menandai lunas secara keliru, idempotensi pembayaran, dan integritas database. Menambah 93 fitur di
   atas logika pembayaran yang belum benar = memperbesar kerusakan data.
2. **Jangan 93 fitur sekaligus.** ChatGPT menyarankan 6–8 fitur inti yang matang lebih dulu; saya
   sepakat dan menerjemahkannya menjadi **V1.5 = 8 fitur inti** (Life Command Center + penguatan
   tagihan/langganan + riwayat + cashflow/budget sederhana + tujuan + net worth).
3. **Prinsip yang Papi tetapkan tetap dipegang**: aplikasi **harus bisa offline dan online** (bukan
   offline-first) — data inti selalu jalan tanpa internet; fitur yang butuh data nyata (jadwal sholat,
   kalender Hijriah, cuaca, kurs, sinkron, AI) mengambil data online saat diperlukan, dengan penanda
   "data per jam berapa" dan tetap berguna saat offline.

**Yang paling menjual dari seluruh kumpulan ide ini** (dan belum ada di pesaing lokal):
**Life Command Center** (satu layar: apa yang harus dilakukan hari ini), **Islamic Life** sebagai pilar
sejajar Finance/Health (bukan tempelan), **Life Timeline** (sejarah hidup yang bisa dicari), dan
**Monthly Life Review** (alasan pengguna kembali setiap bulan).

---

## 2. Sumber, Metode, dan Apa yang Sudah Ada

- **Sumber ide:** obrolan Papi dengan ChatGPT — mencakup 32 fitur awal + 20 modul Health + 20 modul
  Islamic + 15 modul "lubang besar" (Knowledge OS, Decision OS, Asset OS, Document Vault, Family OS,
  Learning OS, Habit OS, Sleep/Energy, Maintenance Engine, Emergency OS, Travel OS, Life Planning,
  Personal Analytics, Forecast, AI Copilot) + Life Timeline/Search/Briefing/Review.
- **Metode perapian:** setiap gagasan dipetakan ke **satu ID fitur** (tidak ada yang dibuang tanpa
  alasan — lihat Lampiran A). Gagasan yang sudah tercakup PRD lama tidak dihitung ulang; yang bertabrakan
  ditandai "memperluas FR-XX".
- **Sudah ada di kode (F1–F3):** tagihan sekali/berulang, frekuensi & day-clamping, template Indonesia,
  pengingat H-x + aksi notifikasi, ringkasan "uang tersisa", kalender, pengaturan, ekspor dasar belum ada.
- **Sudah disetujui di PRD lama (FR-01…FR-59)** dan tetap berlaku: widget, ringkasan pagi, uang aman
  sampai gajian, kalkulator denda, deteksi kenaikan, skor disiplin, Wrapped tahunan, OCR, pemindai
  SMS/bank, pola tanggal bayar, Google Kalender, pusat bayar, rumah tangga, multi-profil, laporan PDF,
  deteksi duplikat, split bill, ledger kas, multi-mata uang, document vault, modul kesehatan dasar,
  delegasi WhatsApp, sub-akses keluarga, perawatan kendaraan/rumah, voice parsing, auto-catat.
- **Yang baru dalam dokumen ini** adalah **lapisan yang belum ada di PRD lama**: Life Command Center
  harian, Subscription Intelligence, Debt Manager dengan strategi, Net Worth Tracker, Financial Calendar
  gabungan, Notification Center + Snooze Engine, Audit Log pengguna, Global Search, Life Timeline,
  Goal→Project→Task, Islamic Life (12 fitur + 3 signature), Health OS lengkap, Knowledge/Learning OS,
  Decision OS, Asset/Home OS, Emergency OS, Travel OS, Analytics/Forecast, Monthly/Annual Life Review,
  AI Copilot ber-konteks.

---

## 3. Tujuan & Non-Tujuan

**Tujuan**
1. Menjadikan aplikasi **"command center kehidupan"**: satu layar menjawab *apa yang harus dilakukan,
   apa yang terlambat, bagaimana kondisi uang, apa yang butuh perhatian*.
2. Menutup lubang besar: langganan berulang, utang, kekayaan bersih, budget, dokumen & masa berlaku,
   aset & perawatan, keluarga, pengetahuan, ibadah, kesehatan.
3. Membuat pengguna **kembali setiap hari** (Today/Briefing) dan **setiap bulan** (Monthly Life Review).
4. Menjaga fondasi: semua modul baru berdiri di atas data yang **idempoten, teruji, dapat dipulihkan**.
5. Menjadi **produk yang layak dijual** (Gratis + Pro) tanpa mengorbankan data milik pengguna.

**Non-Tujuan (tegas — supaya tidak melebar)**
- **Bukan alat medis.** Tidak ada diagnosis, tidak ada saran pengobatan/dosis. Modul kesehatan hanya
  mencatat, menampilkan tren, dan mengingatkan.
- **Bukan pemberi fatwa.** Tidak ada penilaian keimanan, tidak ada "skor ibadah", tidak ada keputusan
  hukum (zakat/qadha dihitung sebagai *alat bantu*, keputusan tetap pada pengguna/ahli).
- **Bukan penasihat investasi/asuransi.** Tidak menjual produk, tidak menyarankan instrumen.
- **Bukan aplikasi 100 menu.** Menu utama maksimal 5 tab + satu daftar "Lainnya"; fitur baru masuk
  lewat konteks (kartu di Today), bukan lewat menu baru.
- **Bukan pengganti MyFitnessPal / aplikasi Quran lengkap.** Fokus pada kebiasaan & keterhubungan modul.
- **Tidak ada integrasi pembayaran otomatis** (butuh kerja sama pihak ketiga) — tetap "pusat bayar"
  berupa tautan/salin VA.
- **Tidak ada iklan** dan tidak ada penjualan data.

---

## 4. Prinsip Produk (dipegang di semua modul)

1. **Action adalah produk, data hanya bahan bakar.** Setiap modul wajib punya siklus:
   *Capture → Understand → Remind → Act → Record → Learn → Improve.*
2. **Satu layar menjawab "hari ini apa".** Today selalu jadi halaman pertama, bukan dashboard angka.
3. **Offline dan online.** Data inti selalu lokal & tetap jalan tanpa internet; fitur bersifat data-nyata
   (sholat, Hijriah, cuaca, kurs, sinkron, AI) mengambil online dengan penanda waktu data + perilaku
   offline yang jelas (pakai data terakhir, jangan gagal senyap).
4. **Isi cepat, sedikit gesekan.** Input maksimal 3 ketukan untuk hal yang sering dicatat (air, sholat,
   pengeluaran, tugas). Tanpa ini semua fitur akan ditinggalkan.
5. **Tidak menghakimi.** Tidak ada skor moral/iman/kesehatan yang menuduh. Gunakan istilah "tercatat",
   "belum tercatat", bukan "gagal".
6. **Data milik pengguna.** Ekspor penuh kapan saja, tanpa akun wajib, tanpa telemetri.
7. **Sensitif = terlindungi.** Dokumen, kesehatan, keuangan wajib enkripsi + kunci biometrik + blokir
   screenshot (PB & fitur F-keamanan).
8. **Sumber terverifikasi** untuk konten agama & kesehatan (metadata sumber, bukan kutipan acak).
9. **Sedikit tapi matang** lebih baik daripada banyak tapi setengah. Maksimal 8 fitur dalam satu fase.
10. **Semua modul saling terhubung** (sholat masuk kalender, zakat masuk finance, dokumen masuk
    pengingat, kesehatan masuk timeline) — nilai aplikasi lahir dari keterhubungan, bukan dari jumlah menu.

---

## 5. Peta Modul & Navigasi

**10 modul (satu aplikasi, satu database, satu akun lokal):**

| Modul | Isi pokok | Fase masuk |
|---|---|---|
| 0 · Today / Command Center | Hari ini, perhatian, briefing, ringkasan pilar | V1.5 |
| 1 · Money OS | Tagihan, langganan, cashflow, budget, utang, kekayaan bersih, kalender keuangan | V1.5 |
| 2 · Action & Goal OS | Goal → Project → Task, kebiasaan, perawatan hidup | V2 |
| 3 · Islamic Life OS | Sholat, adzan, pelacakan, kalender Hijriah, Ramadan, puasa, Quran, dzikir, zakat, haji, muhasabah | V2 |
| 4 · Wellbeing OS | Tren berat/tidur/aktivitas, obat, catatan medis, jadwal dokter, air, suasana hati | V2–V3 |
| 5 · Knowledge & Learning OS | Catatan/ide, keputusan, pembelajaran, pengulangan berkala | V3 |
| 6 · Home & Asset OS | Rumah, kendaraan, perangkat, garansi, perawatan | V3 |
| 7 · Document OS | Dokumen & masa berlaku, brankas terenkripsi | V2 (dasar) → V3 |
| 8 · Family OS | Anggota keluarga, tanggung jawab, kalender keluarga | V3 |
| 9 · Platform & Intelligence | Backup/restore, audit log, pencarian global, timeline, insight, forecast, review bulanan/tahunan, AI copilot | V2 (backup/audit/search) → V4 (AI) |

**Navigasi (anti-100-menu):** 5 tab bawah — **Today · Uang · Kerja (Action/Goal) · Ibadah · Lainnya** —
dan tiap modul punya satu halaman ringkas + daftar di dalamnya. Kartu di Today menjadi pintu masuk utama.

---

## 6. Prasyarat: Fondasi Dulu (tidak bisa dinegosiasikan)

Berdasarkan **PRD Perbaikan v1.0** (PB-01…PB-16) dan audit eksternal:

| Prasyarat | Kenapa | Status |
|---|---|---|
| PB-01/02/03 — aksi notifikasi pakai `actionId`, payload hanya konteks & selalu membawa periode, uji lewat `NotificationResponse` | Menekan "Buka aplikasi"/menyentuh notifikasi bisa menandai lunas | **Belum** |
| PB-05/06/07 — indeks unik (satu periode satu pembayaran; satu bulan satu baris) + `tandaiLunas()` idempoten | Mencegah pembayaran/rollover ganda | **Belum** |
| PB-08 — konsep *occurrence* (riwayat) dipakai dasbor & kalender | Histori tidak hilang setelah rollover; dasar semua laporan & insight | **Belum** |
| PB-04/09/10/11 — snooze tahan sinkronisasi, sinkronisasi anti-setengah-jalan, pemulihan saat init gagal | Notifikasi dapat dipercaya | **Belum** |
| PB-12…PB-16 — perbaikan kecil (anti "sukses palsu", siklus hidup widget, sumber waktu tunggal) | Kebersihan & kejujuran status | **Belum** |

**Aturan gate:** modul fitur baru hanya boleh mulai setelah **PB-01…PB-08 lulus uji** (fase P0-A/P0-B/P0-C
di dokumen perbaikan). Fitur baru tanpa fondasi ini akan menambah kerusakan data.


---

## 7. Daftar Fitur Baru (FR-60 … FR-152)

**Keterangan kolom**
- **Prio:** P0 wajib · P1 penting · P2 bila waktu cukup
- **Fase:** V1.5 / V2 / V3 / V4
- **Est:** S ≤ 3 hari · M 4–8 hari · L 9+ hari (angka diskusi, bukan komitmen)
- **Online:** apakah butuh jaringan (sesuai prinsip "offline dan online")

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
| FR-76 | **Net Worth Tracker** — aset (kas, bank, investasi, properti, kendaraan, emas, kripto, bisnis) − kewajiban (kartu kredit, KPR, pinjaman, cicilan) + grafik tren bulanan | P1 | V2 | M | Tidak | Nilai bersih = aset − kewajiban (uji hitung); grafik menyimpan riwayat bulanan dan tidak berubah retroaktif |
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
| FR-86 | **Jadwal Sholat** — 5 waktu sesuai lokasi; pilih lokasi otomatis atau kota manual; pilih metode perhitungan, konvensi Ashar (madhhab), dan penyesuaian menit | P0 | V2 | M | Ya (cache) | Waktu berbeda saat lokasi/metode diganti (uji 2 kota × 2 metode); nilai tersimpan sehingga besok tetap tampil walau offline, dengan penanda "dihitung untuk <kota>, <tanggal>" |
| FR-87 | **Adzan & Pengingat Sholat** — mode: adzan, 5 menit sebelum, saat masuk waktu, pengingat setelah waktu berjalan + pilihan suara/dering | P0 | V2 | M | Tidak | Tiap mode bisa dipilih per waktu sholat; pengingat berbunyi walau aplikasi tertutup; tidak ada pengingat berulang tanpa henti |
| FR-88 | **Pelacakan Sholat 5 Waktu** — tombol cepat ✓ per waktu; status "selesai / belum tercatat" | P0 | V2 | S | Tidak | Menandai satu waktu ≤2 ketukan; status hari ini tampil di Today; tidak ada istilah menghakimi |
| FR-89 | **Riwayat & Konsistensi Sholat** — rekap mingguan/bulanan per waktu (mis. "Subuh 24/30 tercatat"), bukan skor keimanan | P1 | V2 | S | Tidak | Angka rekap cocok dengan data mentah (uji hitung); label memakai "tercatat" |
| FR-90 | **Kalender Hijriah** — tanggal Hijriah + hari besar, dengan **pilihan acuan kalender** (mis. rujukan resmi negara/pilihan pengguna) | P0 | V2 | M | Ya (cache) | Tanggal Hijriah berubah sesuai acuan yang dipilih; ada catatan bahwa penetapan awal bulan tertentu bisa berbeda; tetap tampil offline dari data tersimpan |
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

## 8. Roadmap Fase (urutan yang disarankan)

**Aturan:** satu fase tuntas + uji hijau sebelum fase berikutnya. **Maksimal 8 fitur per fase.**

| Fase | Isi | Perkiraan | Gate (syarat dianggap selesai) |
|---|---|---|---|
| **F0 · Fondasi (WAJIB PERTAMA)** | PB-01…PB-16 (dokumen PRD Perbaikan) | 6–9 hari | 10 uji wajib perbaikan lulus; tombol notifikasi tidak lagi bisa menandai lunas keliru; pembayaran tidak bisa ganda |
| **V1.5 · Inti Harian** | FR-60 Today · FR-61 Kartu Pilar · FR-62 Attention · FR-63 Morning Briefing · FR-68 Recurring · FR-71 Cashflow · FR-72 Budget · FR-76 Net Worth (+ pendukung FR-65 & FR-67) | 3–4 minggu | Pengguna bisa merencanakan & memantau keuangan bulanan dari satu layar; notifikasi dapat dipercaya |
| **V2 · Pilar Kehidupan** | Islamic: FR-86, 87, 88, 90, 91, 99 · Document: FR-128, 129 · Platform: FR-136, 137, 138, 139, 147, 148 · Action: FR-78, 79 · Health dasar: FR-101, 102, 103, 106, 111 | 6–8 minggu | 5 pilar tampil di Today; data lintas modul terhubung; pencarian & audit log bekerja |
| **V3 · Pendalaman** | Islamic lanjutan (FR-89, 92, 93, 95, 96, 100) · Health lanjutan (FR-104, 105, 107, 108, 109, 112, 115, 116, 117) · Asset (FR-124, 125, 126) · Family (FR-131, 132, 133) · Knowledge (FR-118, 119, 120, 122) · Platform (FR-140, 141, 142, 144, 145) | 8–12 minggu | Timeline, review bulanan, dan insight bekerja dari data nyata |
| **V4 · Kecerdasan & Platform** | FR-143 Forecast · FR-146 Annual Review · FR-149 AI Copilot · FR-150 Sinkron · FR-134, 135 Travel · FR-121, 123 · FR-127 · FR-152 | 8–12 minggu | AI hanya memakai data pengguna dengan izin; sinkron tidak menghilangkan data |

*Semua angka adalah **diskusi, bukan komitmen**. Diasumsikan satu pengembang dengan lingkungan build siap dan
wajib lewat tahap uji di HP Papi sebelum dianggap selesai.*

---

## 9. Arsitektur & Model Data (ringkas)

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

## 10. Keamanan & Privasi (wajib untuk modul sensitif)

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

## 11. Batas Aman Konten (tulisan & perilaku yang dilarang)

| Modul | Kalimat/perilaku yang DILARANG | Pengganti yang dipakai |
|---|---|---|
| Kesehatan | "Anda menderita X", saran dosis/perubahan obat, diagnosis dari foto | "Angka Anda berubah dibanding catatan sebelumnya. Pertimbangkan membicarakannya dengan tenaga kesehatan." |
| Islamic | "Skor iman 43", "Anda gagal hari ini", menyimpulkan "belum sholat" karena belum dicentang, memberi fatwa | "3 dari 5 sholat tercatat hari ini", "Maghrib belum tercatat", "Besok masih ada kesempatan" |
| Keuangan | Saran investasi/produk tertentu, janji hasil, menakut-nakuti utang | "Dengan pola sekarang, proyeksi saldo terendah pada <tanggal>. Asumsi: <daftar asumsi>." |
| Perilaku umum | Memaksa pengguna memberi izin; notifikasi tanpa batas; data terkirim tanpa izin | Izin diminta saat dibutuhkan; batas notifikasi per siklus; tombol mati per fitur |

---

## 12. Metrik Keberhasilan

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

## 13. Monetisasi (usulan)

| Paket | Isi | Alasan |
|---|---|---|
| **Gratis** | Today, tagihan & langganan, pengingat, kalender, cashflow dasar, budget dasar, **seluruh modul Islamic**, **Health dasar (pencatatan & pengingat)**, backup manual, audit log | Ibadah & kesehatan dasar **tidak dijual** — itu bagian dari nilai dasar produk dan sumber ulasan baik |
| **Pro** (Rp399.000/tahun — harga lama, menunggu keputusan ulang) | Multi-profil, laporan PDF/Excel, Net Worth & Debt Strategy, Brankas Dokumen, brankas catatan medis, Health insight lanjutan, AI Copilot (kuota), Sinkron cloud/multi-perangkat, tema premium, kunci aplikasi | Fitur yang dipakai pengguna serius & bernilai jangka panjang |
| **Sekali bayar (opsional)** | Modul Aset/Travel/Learning | Alternatif bagi pengguna yang menolak langganan |

Catatan: kupon & diskon sudah dipahami dari toko yang ada — bisa dipakai untuk peluncuran modul baru.

---

## 14. Risiko & Mitigasi

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

## 15. Keputusan yang Diminta dari Papi (7 butir)

1. **Urutan:** setuju **fondasi (PB) dulu**, baru fitur baru? *(Rekomendasi: ya — tanpa ini fitur baru menumpuk di atas bug data.)*
2. **Isi V1.5:** setuju 8 fitur inti (Today, Kartu Pilar, Attention, Morning Briefing, Recurring/Langganan, Cashflow, Budget, Net Worth)? Atau Papi ingin **Islamic Life** ikut di V1.5?
3. **Modul Islamic & Health dasar:** gratis (rekomendasi) atau jadi bagian Pro?
4. **Harga Pro:** tetap Rp399.000/tahun, atau dipecah per modul?
5. **AI Copilot:** pakai penyedia mana (DeepSeek / OpenAI), lewat server Papi sendiri atau langsung dari aplikasi?
6. **Sinkron cloud:** pakai penyedia pihak ketiga (mis. Google Drive pengguna) atau server Papi sendiri?
7. **Nama & posisi produk:** tetap "Personal Life OS", atau ada nama/brand baru untuk versi besar ini?

---

## 16. Definition of Done (per fitur & per fase)

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

## Lampiran A — Peta Ide ChatGPT → ID Fitur (bukti tidak ada yang hilang)

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

## Lampiran B — Yang Ditolak atau Ditunda (dengan alasan)

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

*Disusun oleh Dato' Dr. H. Sami'an, M.B.A*
