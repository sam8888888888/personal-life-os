# STATUS FITUR PRD v3.1 — 152 butir

Disusun ulang oleh Aaron (Ron) · 21 Sep 2026.
Penandaan jujur: **SELESAI** = ada kode + uji dan sudah diverifikasi; **SEBAGIAN** = ada tetapi belum lengkap; **BELUM** = belum ada jejaknya.

**Hitungan: SELESAI 97 · SEBAGIAN 1 · BELUM 54** (total 152 butir)


## 0 · Dasar & Tagihan (V1)

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-01 | Tambah tagihan: nama, jumlah, jatuh tempo (tanggal; opsi "setiap | - | SELESAI |  |
| FR-02 | Template cepat tagihan Indonesia: Listrik PLN, Air PDAM, Internet/ | - | SELESAI |  |
| FR-03 | Frekuensi: sekali, mingguan, 2-mingguan, bulanan, 2-bulanan | - | SELESAI |  |
| FR-04 | Tagihan berulang otomatis membuat entri periode berikutnya saat | - | SELESAI |  |
| FR-05 | Edit & hapus; penghapusan menanyakan konfirmasi & menawarkan | - | SELESAI |  |
| FR-06 | Status: Belum Bayar / Lunas (+tanggal bayar) / Terlambat | - | SELESAI |  |
| FR-07 | Pencarian & filter (kategori, status, bulan) | - | SELESAI | Ron 21 Sep: kotak pencarian (nama/catatan) + saringan bulan (termasuk bulan mendatang) + status terlambat. |
| FR-08 | Kategori kustom + ikon & warna per kategori | - | SELESAI | layar `/tagihan/kategori`, uji 29/29. Kolom `warna` = teks `#RRGGBB` (tanpa migrasi). |
| FR-09 | Duplikasi cepat tagihan (salin sebagai template pribadi) | - | SELESAI | Ron 21 Sep: duplikat cepat tagihan + template pribadi yang tersimpan. |
| FR-10 | Lead time kustom per tagihan: H-7 / H-3 / H-1 / hari-H / kustom | - | SELESAI |  |
| FR-11 | Aksi dari notifikasi: "✓ Sudah bayar" (tanpa buka aplikasi) | - | SELESAI |  |
| FR-12 | Anti-bising: maksimum N notifikasi per tagihan per siklus | - | SELESAI |  |
| FR-13 | Notifikasi terkirim walau aplikasi tertutup | - | SELESAI |  |
| FR-14 | Kanal notifikasi: Tagihan (wajib), Terlambat (urgent), Ringkasan | - | SELESAI |  |
| FR-15 | Ringkasan mingguan (setiap Senin pagi): daftar tagihan 7 hari ke | - | SELESAI |  |
| FR-16 | Notifikasi "tagihan terlambat" sekali per hari hingga dibayar | - | SELESAI |  |
| FR-17 | Pengingat pintar berbasis pola: bila pengguna biasanya bayar | - | SELESAI | Ron 21 Sep: pola bayar dipelajari dari riwayat; lead pengingat disarankan aplikasi. |
| FR-18 | 4 tab utama: Ringkasan (hari ini/7 hari/menyusul + uang | - | SELESAI |  |
| FR-19 | Kartu ringkasan: total tagihan bulan berjalan, total belum bayar | - | SELESAI |  |
| FR-20 | Input pemasukan bulanan opsional untuk menghitung "uang tersisa" | - | SELESAI |  |
| FR-21 | Mode gelap & terang, aksent warna, ukuran teks mengikuti sistem | - | SELESAI | Ron 20 Sep: mode terang/gelap/ikut sistem + saklar di Pengaturan. |
| FR-22 | Badge/angka tagihan hari ini di ikon launcher (bila API | - | BELUM |  |
| FR-23 | Semua data lokal (SQLite), tanpa akun, tanpa telemetri wajib | - | SELESAI | Diperbarui 21 Sep: data tetap lokal; akun kini OPSIONAL untuk sinkron (FR-150). |
| FR-24 | Ekspor cadangan JSON + impor restore (termasuk migrasi antar HP) | - | SELESAI | `lib/core/backup/ekspor_impor.dart`, `lib/features/pengaturan/backup_screen.dart`, uji 28/28. Batas: pemilihan berkas hanya dari folder dokumen aplikasi; berkas tidak dienkripsi. |
| FR-25 | Ekspor CSV untuk dibuka di spreadsheet | - | SELESAI | Ron 21 Sep: ekspor CSV tagihan & riwayat pembayaran (menu Uang → Ekspor CSV), uji 8 kasus. |
| FR-26 | Kunci aplikasi (PIN/pola/biometrik) untuk data sensitif | - | BELUM |  |
| FR-27 | Sinkronisasi antar perangkat via file/cloud pilihan pengguna | - | BELUM |  |
| FR-28 | Grafik sederhana beban tagihan per bulan (total & per kategori) | - | SELESAI | `lib/core/laporan/beban_tagihan.dart` + layar + rute `/laporan/beban-tagihan`, uji 24/24. |
| FR-29 | Riwayat pembayaran & statistik: rata-rata nominal, jumlah | - | SELESAI | Ron 21 Sep: statistik pembayaran — total, rata-rata, terbesar/terkecil, % tepat waktu, tren 12 bulan. |
| FR-30 | Proyeksi arus kas 3 bulan ke depan (terinspirasi PocketSmith/ | - | SELESAI | Ron 21 Sep: proyeksi arus kas 3 bulan (tagihan semua frekuensi + langganan aktif), uji 8 kasus. |
| FR-31 | Widget layar utama: tagihan 7 hari ke depan + total; tap membuka detai | - | BELUM |  |
| FR-32 | Ringkasan harian pagi (toggle): tagihan hari ini & besok + total (F02) | - | SELESAI | Ron 21 Sep: ringkasan pagi — tagihan hari ini, besok, dan total 7 hari. |
| FR-33 | "Uang aman sampai gajian": input tanggal gajian & saldo opsional → pro | - | SELESAI | Ron 21 Sep: uang aman sampai gajian — tanggal gajian + saldo opsional, tagihan lewat jatuh tempo tetap dihitung. |
| FR-34 | Kalkulator denda terhindarkan: estimasi denda/bunga yang dihindari tia | - | SELESAI | Ron 21 Sep: kalkulator denda terhindarkan (aturan denda per tagihan: persen/bulan atau nominal tetap). |
| FR-35 | Deteksi kenaikan tagihan: pembandingan nominal terhadap rata-rata 3 bu | - | SELESAI | Ron 21 Sep: deteksi kenaikan tagihan — nominal terakhir vs rata-rata 3 sebelumnya, berikut buktinya. |
| FR-36 | Skor Disiplin Tagihan lokal (0–100) + streak bebas denda + daftar capa | - | SELESAI | Ron 21 Sep: skor disiplin tagihan lokal 0–100 + rentetan & capaian, dengan penegasan bukan skor kredit. |
| FR-37 | Rekap Tahunan ala "Wrapped": statistik tahunan + kartu berbagi gambar  | - | SELESAI | Ron 21 Sep: rekap tahunan (total, tepat waktu, bulan tersibuk) + kartu berbagi PNG. |
| FR-38 | Impor tagihan dari foto/screenshot dengan OCR di perangkat; isi kolom  | - | BELUM |  |
| FR-39 | Pemindai SMS/notifikasi bank on-device (opt-in): deteksi pembayaran ta | - | BELUM |  |
| FR-40 | Pembelajaran pola tanggal bayar dari riwayat; usul penyesuaian penging | - | SELESAI | Ron 21 Sep: pengingat pintar mengikuti pola bayar pengguna (layar Pola bayar). |
| FR-41 | Ekspor tagihan mendatang ke Google Kalender; opsi impor .ics (F11) | - | SELESAI | Ron 21 Sep: ekspor jadwal tagihan ke .ics (Google Kalender), periode 3/6/12/24 bulan. |
| FR-42 | Pusat Bayar: preferensi aplikasi bayar per tagihan, salin nomor VA/QRI | - | SELESAI | Ron 21 Sep: Pusat Bayar — VA/QRIS, salin nomor sekali tekan, catatan konfirmasi. |
| FR-43 | Mode Rumah Tangga: kode undangan tanpa akun, tagihan bersama, notifika | - | BELUM |  |
| FR-44 | Multi-profil terpisah (pribadi/keluarga/usaha) | - | BELUM |  |
| FR-45 | Laporan bulanan PDF/Excel + tombol bagikan | - | SELESAI | Ron 21 Sep: tombol bagikan laporan bulanan (PDF & CSV) lewat kanal Android sendiri. |
| FR-46 | Deteksi langganan duplikat & tagihan yang berhenti muncul (F16) | - | SELESAI | Ron 21 Sep: deteksi tagihan berulang yang berhenti muncul + bukti & matikan pengingatnya. |
| FR-47 | v2 | - | BELUM |  |
| FR-48 | v2 | - | BELUM |  |
| FR-49 | Pengingat Multi-Kanal | - | SELESAI | Ron 21 Sep: pengingat multi-kanal (notifikasi/WhatsApp/SMS/Telegram) + teks siap kirim. Pengiriman otomatis via WA Business belum ada (dinyatakan di layar). |
| FR-50 | v2 | - | BELUM |  |
| FR-51 | Catatan Kas & Utang Informal (cash ledger): | - | SELESAI | Ron 21 Sep: catatan kas & utang informal — saldo per pihak + jatuh tempo dekat. |
| FR-52 | Multi-Mata Uang & Konversi: setiap tagihan memakai | - | SELESAI | Ron 21 Sep: mata uang per tagihan + konversi; kurs diisi pengguna, sumber & tanggal ditampilkan. |
| FR-53 | Document Vault & Masa Berlaku: dokumen (STNK, pajak | - | SELESAI | Ron 21 Sep: brankas dokumen + masa berlaku (Dinda) dilengkapi tombol 'salin nomor' tanpa membuka berkas (Ron). |
| FR-54 | Modul Kesehatan (opsional): pengingat obat/suplemen | - | BELUM |  |
| FR-55 | v2 | - | BELUM |  |
| FR-56 | Sub-Akses Keluarga (opsional sinkron): berbagi | - | BELUM |  |
| FR-57 | F8 kandidat | - | BELUM |  |
| FR-58 | F8 kandidat | - | BELUM |  |
| FR-59 | F8 kandidat | - | BELUM |  |

## 1 · Today / Pusat Harian

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-60 | Today (Life Command Center) | V1.5 | SELESAI |  |
| FR-61 | Kartu Pilar Harian | V1.5 | SELESAI |  |
| FR-62 | Attention / Perhatian | V1.5 | SELESAI |  |
| FR-63 | Morning Briefing | V1.5 | SELESAI | fondasi notifikasi sudah digabung; layar Pengingat Ibadah + adaptor + pengiriman otomatis 06:00 terpasang. Uji 20/20. |
| FR-64 | Evening Review | V2 | SELESAI | Ron 20 Sep: tinjauan malam + satu pertanyaan refleksi, bisa dimatikan (uji 9 kasus). |
| FR-65 | Sinkron agenda Today ↔ Kalender | V1.5 | SELESAI | Ron 20 Sep: uji silang Today ↔ Kalender ↔ Kalender Keuangan lulus. |
| FR-66 | Mode sorot "hari berat" | V2 | SELESAI | Ron 20 Sep: mode sorot hari berat + tunda pengingat tanpa mengubah jatuh tempo. |
| FR-67 | Bahasa & format lokal | V1.5 | SELESAI | Ron 20 Sep: format tanggal mengikuti mata uang (IDR→id_ID, MYR→ms_MY). |

## 2 · Uang (Money OS)

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-68 | Recurring & Subscription Manager (memperluas FR-03/FR-16) | V1.5 | SELESAI | Langganan: daftar, siklus, jeda/berhenti, pengingat. Uji 21/21 |
| FR-69 | Subscription Intelligence | V1.5 | SELESAI | Ron 20 Sep: total tahunan, 5 terbesar, proyeksi 12 bulan. |
| FR-70 | Deteksi langganan duplikat / jarang dipakai / harga naik (memperluas F | V2 | SELESAI | Ron 20 Sep: deteksi duplikat, kenaikan tarif, langganan jarang dipakai. |
| FR-71 | Cashflow: pemasukan & pengeluaran berkategori (memperluas FR-20) | V1.5 | SELESAI | Arus kas ber-kategori; rute /uang/transaksi |
| FR-72 | Budget vs Actual per kategori | V1.5 | SELESAI | Anggaran vs realisasi per kategori; rute /uang/anggaran |
| FR-73 | Financial Calendar | V1.5 | SELESAI | Kalender keuangan 6 sumber; rute /kalender-keuangan; 12 uji |
| FR-74 | Debt Manager | V2 | SELESAI | daftar kewajiban, sisa pokok, catat pembayaran pokok+bunga, jadwal; rute /uang/kewajiban. 49 uji modul uang lanjutan |
| FR-75 | Debt Strategy (Avalanche / Snowball) | V2 | SELESAI | simulasi dua metode, estimasi bulan lunas + bunga, asumsi ditampilkan; rute /uang/strategi-pelunasan |
| FR-76 | Net Worth Tracker | V1.5 | SELESAI | Kekayaan bersih + tren bulanan; rute /uang/kekayaan |
| FR-77 | Laporan Keuangan Bulanan (memperluas FR-45) | V2 | SELESAI | ringkasan bulan + PDF & CSV di folder dokumen aplikasi, paket pdf 3.13.0 tanpa plugin lain; 33 uji + potret f12_laporan_bulanan |

## 3 · Aksi & Tujuan

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-78 | Goal → Project → Task | V2 | SELESAI | tujuan/proyek/tugas + progres; rute /aksi; 20 uji |
| FR-79 | Task cepat (3 ketukan) | V2 | SELESAI | tugas cepat di tab Kerja + pintu Aksi |
| FR-80 | Habit Engine | V2 | SELESAI | kebiasaan + penanda harian; rute /aksi/kebiasaan |
| FR-81 | Habit Recovery Score | V3 | SELESAI | Ron 20 Sep: metrik pemulihan kebiasaan, tanpa kata menghakimi. |
| FR-82 | Life Planning Engine | V3 | SELESAI | Ron 20 Sep: rantai Visi → Area → Tujuan → Proyek → Tugas (skema v5). |
| FR-83 | Life Maintenance Engine | V2 | SELESAI | 6 template perawatan berkala + pengingat; rute /aksi/perawatan |
| FR-84 | Sleep & Energy OS | V3 | BELUM |  |
| FR-85 | Progress & konsistensi tanpa skor moral | V2 | SELESAI | Ron 20 Sep: konsistensi mingguan tanpa skor moral. |

## 4 · Ibadah (Islamic OS)

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-86 | Jadwal Sholat | V1.5 | SELESAI |  |
| FR-87 | Adzan & Pengingat Sholat | V1.5 | SELESAI | pengingat 5 waktu (bawaan mati, bisa dinyalakan), mode sebelum/tepat/sesudah + geser menit. Uji 20/20. |
| FR-88 | Pelacakan Sholat 5 Waktu | V1.5 | SELESAI |  |
| FR-89 | Riwayat & Konsistensi Sholat | V2 | SELESAI | Terverifikasi 21 Sep: rekap mingguan/bulanan per waktu; angka dibandingkan dengan data mentah di uji lama; label 'tercatat'. |
| FR-90 | Kalender Hijriah | V1.5 | SELESAI |  |
| FR-91 | Ramadan Mode | V2 | SELESAI | rute /ibadah/ramadan |
| FR-92 | Pelacakan Puasa | V2 | SELESAI | rute /ibadah/puasa |
| FR-93 | Pelacakan Quran | V2 | SELESAI | rute /ibadah/quran + kartu progres di briefing pagi |
| FR-94 | Pelacakan Hafalan (Hifz) | V3 | SELESAI | Ron 21 Sep: pelacakan hafalan per juz/surah + status + jadwal ulangan versi pengguna. |
| FR-95 | Dzikir & Doa | V2 | SELESAI | rute /ibadah/dzikir; 4 adhkar pagi bisa ditandai dari FR-99 |
| FR-96 | Zakat & Sedekah | V3 | SELESAI | Ron 21 Sep: catatan infaq/sedekah + asisten hitung zakat (nisab 85 gram emas dari harga yang diisi pengguna, haul 354 hari, asumsi terbuka). |
| FR-97 | Rencana Haji & Umrah | V3 | BELUM |  |
| FR-98 | Arah Kiblat & Masjid Terdekat | V3 | BELUM |  |
| FR-99 | Islamic Morning Briefing (signature) | V2 | SELESAI | kartu ibadah pagi di briefing: sapaan, progres Quran, 4 adhkar; 3 uji |
| FR-100 | Islamic Evening Review & Muhasabah | V2 | SELESAI | rute /ibadah/muhasabah |

## 5 · Kesehatan

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-101 | Health Dashboard (tren) | V2 | SELESAI | rute /kesehatan |
| FR-102 | Pencatat Aktivitas | V2 | SELESAI | rute /kesehatan/aktivitas |
| FR-103 | Pencatat Tidur | V2 | SELESAI | rute /kesehatan/tidur |
| FR-104 | Berat & Ukuran Tubuh | V2 | SELESAI | Ron 21 Sep: berat & ukuran tubuh — IMT dengan ambang umum, target & tren 30 hari. |
| FR-105 | Jurnal Kesehatan (angka) | V2 | SELESAI | Ron 21 Sep: jurnal angka kesehatan — tekanan darah 2 angka, satuan per jenis, tren 30 hari. |
| FR-106 | Manajer Obat & Vitamin | V2 | SELESAI | rute /kesehatan/obat + penanda minum |
| FR-107 | Perkiraan Obat Habis & Pengingat Beli | V2 | SELESAI | Ron 21 Sep: perkiraan obat habis (sisa ÷ dosis per hari) + pengingat H-5/H-1. |
| FR-108 | Brankas Catatan Medis | V3 | BELUM |  |
| FR-109 | Janji Dokter di Kalender | V2 | SELESAI | Ron 21 Sep: janji dokter/lab/kontrol + pengingat 7 hari, 1 hari, dan 2 jam sebelum. |
| FR-110 | Catatan Makan Ringkas (quick log) | V3 | BELUM |  |
| FR-111 | Pencatat Air | V2 | SELESAI | tombol +250 ml / +500 ml |
| FR-112 | Jurnal Suasana Hati & Stres | V2 | BELUM |  |
| FR-113 | Mesin Temuan Kesehatan (insight) | V3 | BELUM |  |
| FR-114 | Peringatan Dini (watch) | V3 | BELUM |  |
| FR-115 | Mode Kunjungan Dokter | V3 | BELUM |  |
| FR-116 | Laporan Kesehatan Bulanan | V3 | BELUM |  |
| FR-117 | Profil Kesehatan & Kartu Darurat | V2 | BELUM |  |

## 6 · Pengetahuan

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-118 | Catatan & Ide | V3 | BELUM |  |
| FR-119 | Jurnal Keputusan (Decision OS) | V3 | BELUM |  |
| FR-120 | Pelacakan Pembelajaran | V3 | BELUM |  |
| FR-121 | Pengulangan Berkala (spaced repetition) | V4 | BELUM |  |
| FR-122 | Pelacakan Buku & Bacaan | V3 | BELUM |  |
| FR-123 | Penghubung Pengetahuan | V4 | BELUM |  |

## 7 · Rumah & Aset

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-124 | Daftar Aset | V3 | BELUM |  |
| FR-125 | Jadwal & Riwayat Perawatan Aset | V3 | BELUM |  |
| FR-126 | Garansi & Invoice | V3 | BELUM |  |
| FR-127 | Perkiraan Umur Pakai & Penggantian | V4 | BELUM |  |

## 8 · Dokumen

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-128 | Brankas Dokumen & Masa Berlaku (memperluas FR-53) | V2 | SELESAI | dengan catatan (daftar + masa berlaku + nama berkas; enkripsi berkas BELUM — layar menuliskan itu apa adanya |
| FR-129 | Pengingat Perpanjangan Berlapis | V2 | SELESAI | lead 90/30/7/1 hari, bisa diubah; terdaftar di isolate utama & latar |
| FR-130 | Salin Cepat & Bagikan Terkendali | V2 | BELUM |  |

## 9 · Keluarga

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-131 | Anggota Keluarga & Tanggung Jawab | V3 | BELUM |  |
| FR-132 | Kalender Keluarga | V3 | BELUM |  |
| FR-133 | Kas & Tanggung Jawab Rumah Tangga (memperluas FR-43 & FR-47) | V3 | BELUM |  |

## 10 · Perjalanan

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-134 | Perencanaan Perjalanan | V4 | BELUM |  |
| FR-135 | Jurnal Perjalanan | V4 | BELUM |  |

## 11 · Platform & Kecerdasan

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-136 | Backup & Restore penuh (memperluas FR-24) | V2 | SELESAI | format cadangan otomatis mencakup 23 tabel baru v4; skema lebih baru ditolak |
| FR-137 | Cadangan Otomatis + Rotasi + Cek Integritas | V2 | SELESAI | dengan catatan (saklar bawaan MATI; berjalan saat aplikasi dibuka, bukan penjadwal OS; rotasi hanya menghapus berkas yang dicatatnya sendiri; 10 uji |
| FR-138 | Audit Log Pengguna | V2 | SELESAI | Ron 20 Sep: catatan aktivitas mencakup uang, kategori, langganan, kesehatan. |
| FR-139 | Search Everything (signature) | V2 | SELESAI | satu kotak cari lintas tabel; rute /cari; 15 uji |
| FR-140 | Life Timeline (signature) | V3 | BELUM |  |
| FR-141 | Personal Analytics | V3 | BELUM |  |
| FR-142 | Smart Insights | V3 | BELUM |  |
| FR-143 | Forecast | V4 | BELUM |  |
| FR-144 | Weekly Life Review | V3 | BELUM |  |
| FR-145 | Monthly Life Report (signature) | V3 | BELUM |  |
| FR-146 | Annual Life Review | V4 | BELUM |  |
| FR-147 | Notification Center | V2 | SELESAI | rute /notifikasi: riwayat + tingkat + tanda selesai |
| FR-148 | Snooze & Reschedule Engine (memperluas FR-11 & memperbaiki PB-04) | V2 | SELESAI | 15 menit/1 jam/3 jam/besok 09:00; tercatat di audit |
| FR-149 | AI Copilot ber-konteks | V4 | BELUM |  |
| FR-150 | Sinkron Antar Perangkat & Cloud (memperluas FR-27) | V4 | SEBAGIAN | Ron 21 Sep: akun + server sinkron jalan, TAGIHAN sudah tersinkron; modul lain belum. |
| FR-151 | Widget & Akses Cepat Lanjutan (memperluas FR-31) | V2 | BELUM |  |
| FR-152 | Multi-bahasa & Multi-mata Uang (memperluas FR-52) | V4 | BELUM |  |
