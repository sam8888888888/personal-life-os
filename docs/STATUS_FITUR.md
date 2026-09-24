# STATUS FITUR PRD v3.1 — 152 butir

Disusun ulang · 23 Sep 2026. Pada tanggal yang sama seluruh temuan **audit kode eksternal** (P0-1…P3-10) ditindaklanjuti: penandatanganan rilis, cadangan awan Android dimatikan, cadangan & rahasia terenkripsi, kanal berkas medis disambungkan, izin SMS dibuang seluruhnya, versi skema cadangan disamakan dengan basis data, jalur integrasi berkelanjutan, dan pembersihan template/web. Ringkasan per temuan ada di bagian **13 · Perbaikan hasil audit 23 Sep 2026** di bawah.
Penandaan jujur: **SELESAI** = ada kode + uji dan sudah diverifikasi; **SEBAGIAN** = ada tetapi belum lengkap; **BELUM** = belum ada jejaknya.

**Hitungan: SELESAI 150 · SEBAGIAN 1 · BELUM 1** (total 152 butir)


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
| FR-22 | Badge/angka tagihan hari ini di ikon launcher (bila API | - | SELESAI | Ron 22 Sep: lencana angka di ikon aplikasi = jumlah tagihan yang jatuh tempo hari ini atau sudah lewat & belum lunas; dikirim ke peluncur lewat siaran khas Samsung/Sony/HTC/LG/Nova/ADW. Peluncur yang tidak mendukung lencana tidak menampilkannya — dinyatakan di layar, bukan dijanjikan. Uji: hitungan + kanal (kanal tiruan mencatat angka yang dikirim). |
| FR-23 | Semua data lokal (SQLite), tanpa akun, tanpa telemetri wajib | - | SELESAI | Diperbarui 21 Sep: data tetap lokal; akun kini OPSIONAL untuk sinkron (FR-150). |
| FR-24 | Ekspor cadangan JSON + impor restore (termasuk migrasi antar HP) | - | SELESAI | `lib/core/backup/ekspor_impor.dart`, `lib/features/pengaturan/backup_screen.dart`. Diperbarui 23 Sep 2026 (audit P0-3): berkas cadangan SELALU ditulis TERENKRIPSI (AES-256-GCM, kunci turunan PBKDF2-HMAC-SHA256 600.000 putaran). Dua cara buka: (a) tanpa frasa sandi -> kunci perangkat dari brankas Keystore, hanya bisa dibuka di HP itu sendiri; (b) dengan frasa sandi pengguna (paling sedikit 8 karakter) -> berkas bisa dipindah ke HP lain. Versi skema di dalam berkas diambil dari skema basis data yang benar-benar dipakai (dulu tertulis 4 padahal 18). Batas: pemilihan berkas impor hanya dari folder dokumen aplikasi. |
| FR-25 | Ekspor CSV untuk dibuka di spreadsheet | - | SELESAI | Ron 21 Sep: ekspor CSV tagihan & riwayat pembayaran (menu Uang → Ekspor CSV), uji 8 kasus. |
| FR-26 | Kunci aplikasi (PIN/pola/biometrik) untuk data sensitif | - | SELESAI | PIN 6-12 angka; PIN mentah tidak pernah ditulis, yang disimpan turunan PBKDF2-HMAC-SHA256 600.000 putaran + garam, lalu turunannya DIENKRIPSI kunci Android Keystore (hasil audit P1-2: menyalin basis data saja tidak cukup untuk menebak PIN). Salah 5 kali -> ditahan 30 detik; bisa dibuka dengan kunci perangkat HP (sidik jari/PIN HP lewat Android Keyguard); tirai kunci menahan ISI aplikasi sampai PIN benar; masa tenggang bisa diatur (langsung/30 dtk/1 mnt/5 mnt). Kalau basis data tidak bisa dibaca, aplikasi TIDAK terbuka (gagal-tertutup) dan menawarkan atur ulang PIN setelah pemilik membuktikan identitas lewat kunci perangkat. |
| FR-27 | Sinkronisasi antar perangkat via file/cloud pilihan pengguna | - | SELESAI | Ron 22 Sep: pilihan kanal sinkron — server sendiri (akun) atau BERKAS (ekspor .json lalu dibagikan lewat WhatsApp/Drive/USB, impor dari pemilih berkas Android). Tanpa server pun jalan. |
| FR-28 | Grafik sederhana beban tagihan per bulan (total & per kategori) | - | SELESAI | `lib/core/laporan/beban_tagihan.dart` + layar + rute `/laporan/beban-tagihan`, uji 24/24. |
| FR-29 | Riwayat pembayaran & statistik: rata-rata nominal, jumlah | - | SELESAI | Ron 21 Sep: statistik pembayaran — total, rata-rata, terbesar/terkecil, % tepat waktu, tren 12 bulan. |
| FR-30 | Proyeksi arus kas 3 bulan ke depan (terinspirasi PocketSmith/ | - | SELESAI | Ron 21 Sep: proyeksi arus kas 3 bulan (tagihan semua frekuensi + langganan aktif), uji 8 kasus. |
| FR-31 | Widget layar utama: tagihan 7 hari ke depan + total; tap membuka detai | - | SELESAI | Ron 22 Sep: widget layar utama 'Tagihan 7 hari' — judul (jumlah tagihan hari ini / 7 hari ke depan) + total + tiga tagihan terdekat dengan nominalnya; menekan baris membuka daftar tagihan; isi dikirim ulang setiap data tagihan berubah; bisa dinyalakan/dimatikan di Pengaturan -> Ikon & widget. Uji: penyusun isi + kanal. |
| FR-32 | Ringkasan harian pagi (toggle): tagihan hari ini & besok + total (F02) | - | SELESAI | Ron 21 Sep: ringkasan pagi — tagihan hari ini, besok, dan total 7 hari. |
| FR-33 | "Uang aman sampai gajian": input tanggal gajian & saldo opsional → pro | - | SELESAI | Ron 21 Sep: uang aman sampai gajian — tanggal gajian + saldo opsional, tagihan lewat jatuh tempo tetap dihitung. |
| FR-34 | Kalkulator denda terhindarkan: estimasi denda/bunga yang dihindari tia | - | SELESAI | Ron 21 Sep: kalkulator denda terhindarkan (aturan denda per tagihan: persen/bulan atau nominal tetap). |
| FR-35 | Deteksi kenaikan tagihan: pembandingan nominal terhadap rata-rata 3 bu | - | SELESAI | Ron 21 Sep: deteksi kenaikan tagihan — nominal terakhir vs rata-rata 3 sebelumnya, berikut buktinya. |
| FR-36 | Skor Disiplin Tagihan lokal (0–100) + streak bebas denda + daftar capa | - | SELESAI | Ron 21 Sep: skor disiplin tagihan lokal 0–100 + rentetan & capaian, dengan penegasan bukan skor kredit. |
| FR-37 | Rekap Tahunan ala "Wrapped": statistik tahunan + kartu berbagi gambar  | - | SELESAI | Ron 21 Sep: rekap tahunan (total, tepat waktu, bulan tersibuk) + kartu berbagi PNG. |
| FR-38 | Impor tagihan dari foto/screenshot dengan OCR di perangkat | F08 | SELESAI | Ron 22 Sep: OCR ML Kit model terbundel (offline, tanpa Play Services, tidak dikirim keluar); nominal/jatuh tempo/nomor pelanggan jadi DRAF yang wajib diperiksa. Rute /tagihan/impor-foto. |
| FR-39 | Pemindai bank tanpa SMS (impor rekening PDF/CSV / notifikasi bank) | V2 | BELUM | Ron 23 Sep: jalur SMS DIBUANG seluruhnya (kanal Kotlin, kanal Dart, layar, repositori, mesin pengurai, rute) karena izin READ_SMS dilarang pemilik & memicu Play Protect memblokir pemasangan. Pengganti resmi belum dikerjakan — ditandai BELUM, bukan dinaikkan. |
| FR-40 | Pembelajaran pola tanggal bayar dari riwayat; usul penyesuaian penging | - | SELESAI | Ron 21 Sep: pengingat pintar mengikuti pola bayar pengguna (layar Pola bayar). |
| FR-41 | Ekspor tagihan mendatang ke Google Kalender; opsi impor .ics (F11) | - | SELESAI | Ron 21 Sep: ekspor jadwal tagihan ke .ics (Google Kalender), periode 3/6/12/24 bulan. |
| FR-42 | Pusat Bayar: preferensi aplikasi bayar per tagihan, salin nomor VA/QRI | - | SELESAI | Ron 21 Sep: Pusat Bayar — VA/QRIS, salin nomor sekali tekan, catatan konfirmasi. |
| FR-43 | Mode Rumah Tangga: kode undangan tanpa akun, tagihan bersama, notifika | V2 | SELESAI | Ron 22 Sep: kode undangan tanpa akun, tagihan bersama (bagi rata selalu pas), riwayat siapa bayar apa; pengingat disiapkan, tidak dikirim sendiri. Rute /rumah/mode-rumah-tangga. |
| FR-44 | Multi-profil terpisah (pribadi/keluarga/usaha) | - | SELESAI | Ron 22 Sep: profil pribadi/keluarga/usaha masing-masing punya BERKAS basis data SENDIRI sehingga data tidak bercampur (dibuktikan uji dengan dua basis data terpisah); profil 'Pribadi' memakai berkas lama sehingga data pengguna yang sudah ada tidak hilang; profil aktif harus dipindah dulu sebelum dihapus; pindah profil = pindah berkas basis data. Uji: 7 kasus. |
| FR-45 | Laporan bulanan PDF/Excel + tombol bagikan | - | SELESAI | Ron 21 Sep: tombol bagikan laporan bulanan (PDF & CSV) lewat kanal Android sendiri. |
| FR-46 | Deteksi langganan duplikat & tagihan yang berhenti muncul (F16) | - | SELESAI | Ron 21 Sep: deteksi tagihan berulang yang berhenti muncul + bukti & matikan pengingatnya. |
| FR-47 | v2 (Split bill & patungan) | V2 | SELESAI | Ron 22 Sep: grup/anggota/belanja/bagian; bagi rata selalu pas dengan total; hasil "siapa transfer ke siapa". Rute /patungan. |
| FR-48 | v2 (Dana persiapan & arus kas) | V2 | SELESAI | Ron 22 Sep: dana + setoran; setoran per bulan dari tanggal target; arus kas bersih = kas − alokasi. Rute /laporan/dana-persiapan. |
| FR-49 | Pengingat Multi-Kanal | - | SELESAI | Ron 21 Sep: pengingat multi-kanal (notifikasi/WhatsApp/SMS/Telegram) + teks siap kirim. Pengiriman otomatis via WA Business belum ada (dinyatakan di layar). |
| FR-50 | Perluas impor OCR ke struk belanja & nota manual | V2 | SELESAI | Ron 22 Sep: satu layar Tagihan / Struk-Nota; baris barang terbaca, selisih jumlah barang vs TOTAL dikatakan apa adanya; struk disimpan sebagai pengeluaran (sumber: ocr). Rute /tagihan/impor-foto. |
| FR-51 | Catatan Kas & Utang Informal (cash ledger): | - | SELESAI | Ron 21 Sep: catatan kas & utang informal — saldo per pihak + jatuh tempo dekat. |
| FR-52 | Multi-Mata Uang & Konversi: setiap tagihan memakai | - | SELESAI | Ron 21 Sep: mata uang per tagihan + konversi; kurs diisi pengguna, sumber & tanggal ditampilkan. |
| FR-53 | Document Vault & Masa Berlaku: dokumen (STNK, pajak | - | SELESAI | Ron 21 Sep: brankas dokumen + masa berlaku (Dinda) dilengkapi tombol 'salin nomor' tanpa membuka berkas (Ron). |
| FR-54 | Modul Kesehatan (opsional): pengingat obat/suplemen | V2 | SELESAI | Ron 22 Sep: memakai ULANG modul obat FR-106; pengingat opsional (izin wajib); slot yang sudah dicatat tidak diulang. Rute /kesehatan/obat/jadwal. |
| FR-55 | v2 (Delegasi cepat WhatsApp) | V2 | SELESAI | Ron 22 Sep: menyiapkan teks + tautan WhatsApp/SMS, tidak mengirim sendiri; nomor divalidasi. Rute /tagihan/delegasi. |
| FR-56 | Sub-Akses Keluarga (opsional sinkron): berbagi | F8 | SELESAI | Ron 22 Sep: izin per anggota × modul (bawaan MATI), penegakan di lapisan data; paket berbagi hanya izin + jumlah baris. Rute /keluarga/sub-akses. |
| FR-57 | Perawatan berkala (memakai mesin FR-125) | F8 | SELESAI | Ron 22 Sep: sudah ada sejak FR-125 (intervalHari + berikutnya + leadHari, template bawaan, SumberPengingatPerawatan terdaftar); batch 12 memverifikasi & menguji — tanpa tabel/mesin kembar. Rute /aksi/perawatan. |
| FR-58 | Voice & Parsing Cerdas | F8 | SELESAI | Ron 22 Sep: satu kalimat jadi draf (pengeluaran/tagihan/dana/perawatan); pengenalan suara bawaan Android, penguraian di perangkat, draf wajib dikonfirmasi. Rute /suara. |
| FR-59 | Auto-catat pengeluaran (perluas FR-39) | F8 | SEBAGIAN | Ron 23 Sep: jalur SMS sudah DIBUANG seluruhnya, jadi auto-catat dari SMS tidak lagi ada di aplikasi. Penggantinya (impor rekening PDF/CSV atau Notification Listener) belum dikerjakan — ditulis apa adanya. |

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
| FR-84 | Sleep & Energy OS | V3 | SELESAI | Ron 22 Sep: 'Energi & jam produktif' menempel pada catatan tidur yang sudah ada (energi 1-5, fokus 1-5, jam paling produktif diisi pengguna — bukan tebakan mesin); setelah 14 hari muncul pola (rata energi/fokus, jam produktif tersering) beserta dasar datanya; sebelum itu layar menjelaskan kenapa belum bisa. Uji: mesin + layar. |
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
| FR-97 | Rencana Haji & Umrah | V3 | SELESAI | Ron 22 Sep: 'Rencana haji & umrah' menyimpan target dana + daftar persiapan dokumen; progres menampilkan persen tercapai, sisa, dan setoran per bulan sampai tanggal target, lengkap dengan peringatan bila target belum diisi / tanggal sudah lewat / setoran tidak realistis. Tabel baru rencana_ibadah & persiapan_ibadah ikut mesin sinkron 150. Uji: mesin + repositori + layar. |
| FR-98 | Arah Kiblat & Masjid Terdekat | V3 | SELESAI | Ron 22 Sep: 'Arah kiblat & masjid terdekat' menghitung arah kiblat dari koordinat (dengan peringatan kalibrasi); bila sensor kompas tidak ada / izin ditolak, layar TIDAK menampilkan angka palsu - hanya derajat + arah mata angin + kalimat sensor tidak tersedia. Pencarian masjid via Overpass disimpan (sumber + waktu) sehingga tetap terbaca offline; kegagalan jaringan dilaporkan apa adanya dan data lama tetap dipakai. Kanal kompas Android (KanalKompas.kt) + uji tirus. Uji: mesin + repositori + layar. |
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
| FR-108 | Brankas Catatan Medis | V3 | SELESAI | Brankas catatan medis — jenis (lab, tahunan, resep, imunisasi, tagihan medis, dokter, pencitraan), pencarian kata menjangkau judul/hasil/ringkasan/tenaga kesehatan/fasilitas + lampiran berkas TERENKRIPSI (AES-256-GCM, kunci di Android Keystore, tidak diekspor). Bila perangkat tidak mendukung enkripsi, berkas TIDAK disimpan. Diperbaiki 23 Sep 2026 (audit P0-4): kanal brankas berkas medis dulu TIDAK PERNAH dipasang di MainActivity sehingga lampiran gagal dengan galat plugin tak terdaftar — sekarang dipasang, dan ada uji penjaga yang membaca kode Android vs pemanggilan Dart supaya tidak terulang. |
| FR-109 | Janji Dokter di Kalender | V2 | SELESAI | Ron 21 Sep: janji dokter/lab/kontrol + pengingat 7 hari, 1 hari, dan 2 jam sebelum. |
| FR-110 | Catatan Makan Ringkas (quick log) | V3 | SELESAI | Ron 22 Sep: catat cepat per waktu makan, porsi, dan penilaian sendiri (baik/cukup/kurang). |
| FR-111 | Pencatat Air | V2 | SELESAI | tombol +250 ml / +500 ml |
| FR-112 | Jurnal Suasana Hati & Stres | V2 | SELESAI | Ron 22 Sep: suasana hati, energi & stres 1-5, pemicu, catatan; rata-rata & arah 14 hari. |
| FR-113 | Mesin Temuan Kesehatan (insight) | V3 | SELESAI | Ron 22 Sep: temuan dihitung dari angka sendiri (berat, tekanan, tidur, air, suasana) + angka pendukung; bukan diagnosis. |
| FR-114 | Peringatan Dini (watch) | V3 | SELESAI | Ron 22 Sep: peringatan dini dari catatan sendiri — berat naik N minggu, tidur di bawah kebiasaan, aktivitas menurun 14 hari, sistolik naik; ambang bisa diatur & tersimpan; tiap peringatan memuat saran netral tanpa kata menghakimi, disertai catatan 'bukan diagnosis'. |
| FR-115 | Mode Kunjungan Dokter | V3 | SELESAI | Ron 22 Sep: mode kunjungan dokter — ringkasan 30 hari (berat, tekanan, tidur, aktivitas, suasana, keluhan) jadi SATU halaman PDF; angkanya dihitung dari fungsi yang sama dengan layar sehingga identik dengan data aplikasi. |
| FR-116 | Laporan Kesehatan Bulanan | V3 | SELESAI | Ron 22 Sep: laporan bulanan + tiga kelompok: membaik / berubah / perlu diperhatikan. |
| FR-117 | Profil Kesehatan & Kartu Darurat | V2 | SELESAI | Ron 22 Sep: profil kesehatan (golongan darah, alergi, kondisi, obat penting, kontak darurat) + kartu darurat OFFLINE; pintasan Android membuka kartu langsung dari layar kunci (setShowWhenLocked) sementara rincian sensitif hanya tampil setelah perangkat dibuka. |

## 6 · Pengetahuan

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-118 | Catatan & Ide | V3 | SELESAI | Ron 22 Sep: catatan, kategori, tag, sematan, arsip, pencarian + LAMPIRAN foto & rekaman suara (kanal Android sendiri, tanpa paket tambahan; berkas disimpan di folder aplikasi). |
| FR-119 | Jurnal Keputusan (Decision OS) | V3 | SELESAI | Ron 22 Sep: keputusan + pilihan/alasan/risiko/biaya/keyakinan, tinjauan hasil 3/6/12 bulan. |
| FR-120 | Pelacakan Pembelajaran | V3 | SELESAI | Ron 22 Sep: topik, sumber, menit, tahap belajar + grafik 14 hari. |
| FR-121 | Pengulangan Berkala (spaced repetition) | V4 | SELESAI | Ron 22 Sep: jadwal ulangan 1/3/7/16/35/90/180 hari dihitung dari jawaban sendiri. |
| FR-122 | Pelacakan Buku & Bacaan | V3 | SELESAI | Ron 22 Sep: daftar baca, progres halaman, status, catatan & penilaian sendiri. |
| FR-123 | Penghubung Pengetahuan | V4 | SELESAI | Ron 22 Sep: tautan catatan/keputusan/bacaan/kartu/pembelajaran dengan tujuan, proyek, tugas, dokumen. |

## 7 · Rumah & Aset

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-124 | Daftar Aset | V3 | SELESAI | Ron 22 Sep: daftar aset fisik (rumah, kendaraan, perangkat, furnitur, elektronik) — tanggal beli, harga, nomor seri, garansi, masa pakai, lokasi; total nilai tampil & ikut Kekayaan Bersih tanpa input ulang. |
| FR-125 | Jadwal & Riwayat Perawatan Aset | V3 | SELESAI | Ron 22 Sep: jadwal perawatan terikat aset + riwayat perbaikan berbiaya (bisa dikaitkan ke pengeluaran), total & rata-rata per tahun, pengingat perawatan terpasang di isolate utama & latar. |
| FR-126 | Garansi & Invoice | V3 | SELESAI | Ron 22 Sep: garansi per aset (tanggal berakhir) + status aktif/segera berakhir/berakhir; yang berakhir <= 30 hari muncul sebagai Perhatian di Today. |
| FR-127 | Perkiraan Umur Pakai & Penggantian | V4 | SELESAI | Ron 22 Sep: perkiraan umur pakai & waktu penggantian dari tanggal beli + masa pakai, lengkap dengan DASAR perhitungan & saran dana per bulan (estimasi, bukan klaim). |

## 8 · Dokumen

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-128 | Brankas Dokumen & Masa Berlaku (memperluas FR-53) | V2 | SELESAI | dengan catatan (daftar + masa berlaku + nama berkas; enkripsi berkas BELUM — layar menuliskan itu apa adanya |
| FR-129 | Pengingat Perpanjangan Berlapis | V2 | SELESAI | lead 90/30/7/1 hari, bisa diubah; terdaftar di isolate utama & latar |
| FR-130 | Salin Cepat & Bagikan Terkendali | V2 | SELESAI | Ron 22 Sep: salin nomor sekali ketuk + bagikan tersamar — nomor disamarkan, berkas asli hanya ikut bila pengguna mencentangnya sendiri dan berkasnya ada. |

## 9 · Keluarga

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-131 | Anggota Keluarga & Tanggung Jawab | V3 | SELESAI | Ron 22 Sep: anggota keluarga + pemilik & penanggung jawab per item (contoh PRD: tagihan sekolah milik anak, ditanggung pasangan); saringan per anggota bekerja; anggota bertanda pribadi hanya tampil setelah perangkat dibuka. |
| FR-132 | Kalender Keluarga | V3 | SELESAI | Ron 22 Sep: kalender keluarga — satu tampilan agenda semua anggota (tagihan, tugas, janji kesehatan, jadwal perawatan, ulang tahun) dengan WARNA BERBEDA per anggota; saringan per anggota; warna ditetapkan dari urutan anggota sehingga tidak pernah sama. |
| FR-133 | Kas & Tanggung Jawab Rumah Tangga (memperluas FR-43 & FR-47) | V3 | SELESAI | Ron 22 Sep: 'Kas & tanggung jawab rumah tangga' mencatat siapa bayar apa (pemilik, penanggung jawab, jatuh tempo) + riwayat pelunasan; ringkasan per anggota; pengingat halus SATU KETUKAN hanya boleh terkirim bila pengguna menyalakan izin (saklar di tabel pengaturan), maksimal sekali sehari, pada jam wajar 08.00-21.00 - kalau tidak, layar menyebut alasannya. Tabel tanggung_jawab_rumah ikut mesin sinkron 150. Uji: mesin + repositori + layar. |

## 10 · Perjalanan

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-134 | Perencanaan Perjalanan | V4 | SELESAI | Ron 22 Sep: 'Perencanaan perjalanan' menyatukan jadwal + anggaran + dokumen dalam satu perjalanan: agenda/tiket/hotel/dokumen/daftar bawaan; realisasi anggaran dihitung dari transaksi keuangan yang bertaut perjalanan (tanpa input ulang); pengingat keberangkatan H-7/H-1/H-0 sebagai sumber pengingat tambahan. Tabel perjalanan & item_perjalanan ikut mesin sinkron 150. Uji: mesin + repositori + layar. |
| FR-135 | Jurnal Perjalanan | V4 | SELESAI | Ron 22 Sep: 'Jurnal perjalanan' menyimpan cerita + foto + penilaian per hari; SETIAP pengeluaran yang dicatat langsung menjadi transaksi di laporan keuangan (tanpa input ulang) dan ditandai di layar; catatan lama yang belum bertaut transaksi dilaporkan apa adanya (bukan disembunyikan). Tabel catatan_perjalanan ikut mesin sinkron 150. Uji: mesin + repositori + layar. |

## 11 · Platform & Kecerdasan

| ID | Fitur | Fase | Status | Catatan |
|---|---|---|---|---|
| FR-136 | Backup & Restore penuh (memperluas FR-24) | V2 | SELESAI | format cadangan otomatis mencakup 23 tabel baru v4; skema lebih baru ditolak |
| FR-137 | Cadangan Otomatis + Rotasi + Cek Integritas | V2 | SELESAI | dengan catatan (saklar bawaan MATI; berjalan saat aplikasi dibuka, bukan penjadwal OS; rotasi hanya menghapus berkas yang dicatatnya sendiri; 10 uji |
| FR-138 | Audit Log Pengguna | V2 | SELESAI | Ron 20 Sep: catatan aktivitas mencakup uang, kategori, langganan, kesehatan. |
| FR-139 | Search Everything (signature) | V2 | SELESAI | satu kotak cari lintas tabel; rute /cari; 15 uji |
| FR-140 | Life Timeline (signature) | V3 | SELESAI | Ron 22 Sep: lini masa hidup (signature) — kejadian dari 14 sumber data tersusun per bulan, dapat dicari & disaring per modul, tiap baris menyebut asal datanya (mis. tugas#12), plus rangkuman 'apa yang terjadi bulan ini'. |
| FR-141 | Personal Analytics | V3 | SELESAI | Ron 22 Sep: analitik pribadi lintas modul untuk 7/30/90 hari & 1 tahun; SETIAP angka menampilkan baris sumber (tabel & rentangnya) sehingga tidak ada angka misterius. |
| FR-142 | Smart Insights | V3 | SELESAI | Ron 22 Sep: 'Temuan pintar' menyusun temuan dari data nyata (pengeluaran bulanan, sebaran jatuh tempo, langganan jarang dipakai, titik saldo terendah); SETIAP temuan menuliskan dasar data + periode yang dipakai, dan temuan hanya muncul bila datanya cukup — sisanya masuk daftar 'belum bisa' beserta alasannya. Bila belum ada pergerakan uang sama sekali, temuan saldo tidak dibuat (tidak menyesatkan). Uji: mesin + layar. |
| FR-143 | Forecast | V4 | SELESAI | Ron 22 Sep: 'Ramalan saldo' memakai asumsi yang ditulis terbuka (laba bulanan rata-rata, simpangan harian aktual, tagihan tetap & langganan) dan menampilkan RENTANG tiga angka tiap bulan (pesimis/tengah/optimis) — bukan satu angka mutlak, sesuai PRD; bulan yang bisa minus ditandai + saran menggeser apa. Uji: mesin + layar. |
| FR-144 | Weekly Life Review | V3 | SELESAI | Ron 22 Sep: tinjauan pekan per 6 pilar (uang, kesehatan, tujuan & tugas, pengetahuan, ibadah, rumah & aset) membandingkan pekan ini vs pekan lalu dengan angka pendukung; tiga kolom isian tersimpan; teks ringkas bisa disalin untuk notifikasi; pengingat Minggu malam otomatis DILEWATI bila pekan itu sudah diisi. |
| FR-145 | Monthly Life Report (signature) | V3 | SELESAI | Ron 22 Sep: laporan bulanan (signature) — keuangan, tagihan, tujuan, tugas, langganan, kekayaan bersih + 'membaik / berubah / perlu perhatian'; bisa diarsipkan (angka kunci tersimpan sebagai JSON untuk pembanding bulan berikutnya) dan dibagikan sebagai PDF. |
| FR-146 | Annual Life Review | V4 | SELESAI | Ron 22 Sep: 'Tinjauan tahun' merangkum tahun berjalan per pilar (uang, kesehatan, ibadah, hubungan, pengetahuan) dari data nyata; hanya tampil bila data mencakup minimal 6 bulan — kalau kurang, layar menyebut berapa bulan data yang ada dan tidak mengarang hasil. Uji: mesin + layar. |
| FR-147 | Notification Center | V2 | SELESAI | rute /notifikasi: riwayat + tingkat + tanda selesai |
| FR-148 | Snooze & Reschedule Engine (memperluas FR-11 & memperbaiki PB-04) | V2 | SELESAI | 15 menit/1 jam/3 jam/besok 09:00; tercatat di audit |
| FR-149 | AI Copilot ber-konteks | V4 | SELESAI | Ron 22 Sep: hanya data pengguna; izin + kunci sendiri; daftar data yang dikirim ditampilkan; offline/izin mati = fitur mati dengan alasan. Rute /copilot. |
| FR-150 | Sinkron Antar Perangkat & Cloud (memperluas FR-27) | V4 | SELESAI | Ron 22 Sep: sinkron SEMUA MODUL (40 tabel: uang, aset, tujuan/tugas, kebiasaan, kesehatan, dokumen, pengetahuan, ibadah) — pengenal uid, kaitan antar tabel dipetakan ulang antar HP, bentrok versi-kalah disimpan, diuji dua basis data. Belum: berkas lampiran & catatan obat. |
| FR-151 | Widget & Akses Cepat Lanjutan (memperluas FR-31) | V2 | SELESAI | Ron 22 Sep: tombol di widget LANGSUNG menjalankan aksi saat aplikasi terbuka dari widget (satu ketukan, bukan membuka formulir lagi) dan menulis ke basis data yang sama sehingga tersinkron; baris widget bisa ditandai lunas satu per satu; aksi cepat ikon bertambah: 'Catat pengeluaran' dan 'Widget tagihan'. Uji: aksi lunas benar-benar mengubah data. |
| FR-152 | Multi-bahasa & Multi-mata Uang (memperluas FR-52) | V4 | SELESAI | Ron 22 Sep: multi-bahasa (Indonesia/Melayu/Inggris) untuk kerangka aplikasi, Pengaturan, dan tab; kurs selalu disimpan bersama SUMBER + WAKTU pembaruan, bisa diambil dari jaringan atau diisi manual, dan setiap nilai yang belum punya kurs disebut belum bisa dikonversi (tidak dikira-kira). Uji: mesin + repositori + layar. |


## 13 · Perbaikan hasil audit 23 Sep 2026

Audit kode eksternal atas snapshot publik menemukan 4 temuan kritis (P0), 5 tinggi (P1),
6 menengah (P2), dan 10 kebersihan (P3). Keadaannya di kode sekarang — ditulis apa adanya,
termasuk yang BELUM:

| Temuan | Keadaan | Bukti / catatan |
|---|---|---|
| P0-1 APK rilis ditandatangani kunci debug | SELESAI | `android/app/build.gradle.kts` membaca `android/key.properties` (contoh ada di `android/key.properties.example`, berkas aslinya di-`.gitignore`). Bila berkas kunci tidak ada, build tetap jalan dengan kunci debug TETAPI mencetak peringatan di keluaran build. |
| P0-2 Cadangan otomatis Android mengirim seluruh basis data ke Google Drive | SELESAI | `allowBackup="false"`, `dataExtractionRules`, `networkSecurityConfig`, `usesCleartextTraffic="false"` di manifest utama; layar Cadangan menyatakan terus terang bahwa cadangan awan Android dimatikan. |
| P0-3 Rahasia & berkas cadangan tersimpan polos | SELESAI | `BrankasRahasia.kt` (AES-256-GCM, kunci Android Keystore tidak bisa diekspor) + `lib/core/platform/brankas_rahasia.dart`. Token akun, kunci API Copilot, dan turunan PIN tidak lagi polos di basis data. Cadangan ditulis TERENKRIPSI (amplop `plo-backup-terenkripsi`), kunci perangkat untuk cadangan otomatis/pengaman, atau frasa sandi pengguna untuk berkas yang dipindah HP. |
| P0-4 Kanal brankas berkas medis tidak pernah dipasang | SELESAI | Dipasang di `MainActivity.kt`; ada uji penjaga yang membandingkan kanal di kode Dart vs kode Android. Uji di HP (lampirkan berkas medis nyata) tetap menjadi gerbang pemilik. |
| P1-1 Izin INTERNET tidak ada di manifest utama | SELESAI | Ditambahkan; dibuktikan lewat `aapt2 dump permissions` pada APK hasil build. |
| P1-2 PIN 4 angka + 60.000 putaran, dua jalur gagal-terbuka | SELESAI | PIN 6-12 angka, 600.000 putaran, turunan diikat rahasia Keystore, dan kegagalan membaca basis data menahan aplikasi (gagal-tertutup) dengan tawaran atur ulang PIN. |
| P1-3 Versi skema cadangan 4 padahal skema 18; versi aplikasi basi | SELESAI | Versi skema dibaca dari `AppDatabase.schemaVersion`; versi aplikasi dari satu sumber `lib/core/versi.dart` yang dijaga uji agar sama dengan `pubspec.yaml`. |
| P1-4 Tanpa minify/shrink/obfuscate | SELESAI | `isMinifyEnabled`, `isShrinkResources`, `proguard-rules.pro` (+ aturan keep ML Kit). Langkah AAB & `--obfuscate --split-debug-info` ada di `docs/PERSIAPAN_PLAY_STORE.md`. |
| P1-5 Sisa kode SMS (KanalSms & kawan-kawan) | SELESAI | `KanalSms.kt`, `kanal_sms.dart`, `pemindai_bank.dart`, `pemindai_bank_repository.dart`, `pemindai_bank_screen.dart` DIHAPUS; ada uji penjaga yang memindai `lib/` dan `android/` untuk nama izin SMS. |
| P2-1 FileProvider membuka akar folder berkas | SELESAI | `berkas_paths.xml` dipersempit ke subfolder `bagikan/`; berkas yang dibagikan disalin dulu ke `cache/bagikan/`. |
| P2-2 Basis data belum terenkripsi (SQLCipher) | SELESAI | Basis data disimpan TERENKRIPSI memakai SQLCipher. Caranya lewat jalur resmi `package:sqlite3` (`hooks: user_defines: sqlite3: source: sqlcipher` di `pubspec.yaml`); biner unduhannya diverifikasi sha256 oleh paket itu sendiri. Kunci 256-bit dibuat sekali di Android Keystore (`lib/data/database/enkripsi_basisdata.dart`, nama rahasia `basisdata.kunci`) dan TIDAK BISA DIEKSPOR. Berkas lama berisi data pengguna dimigrasi otomatis sekali: disalin dulu ke titik pulih `.cadangan-polos`, hasilnya diverifikasi (jumlah tabel sama), dan salinan polos itu dihapus HANYA setelah verifikasi lolos; gagal di tahap mana pun → berkas polos dikembalikan utuh dan aplikasi tetap jalan. Bila perangkat tidak punya Keystore atau pustaka SQLCipher tidak ada, berkas TIDAK disentuh dan layar Cadangan mengatakan terus terang "BELUM terenkripsi" — tidak pernah mengaku aman. Uji gerbang di HP: pastikan data lama masih terbaca setelah pembaruan (migrasi) dan pengingat tetap jalan. |
| P2-3 Endpoint AI bisa diarahkan ke http:// | SELESAI | Alamat wajib `https`, pesannya menjelaskan sebabnya; `network_security_config.xml` melarang lalu lintas tanpa enkripsi sebagai sabuk pengaman kedua. |
| P2-4 IP server & nama pribadi di repo publik | SELESAI | Catatan internal (`AARON_NOTES.md`, `RENCANA_AARON_V3.md`, `docs/HANDOVER_*.md`, `docs/SERAHAN_TOTAL_*.md`) dikeluarkan dari repo dan di-`.gitignore`; alamat server lewat `--dart-define=LIFEOS_API`. |
| P2-5 MainActivity menerima rute bebas dari aplikasi lain | SELESAI | Rute disaring dengan daftar putih; layar-di-atas-kunci hanya untuk paket sendiri. |
| P2-6 96 `catch (_)` tanpa jejak | SELESAI | Setiap `catch` di lapisan data mencatat galat lewat `catatGalatTertelan` (tersimpan di memori + dialirkan ke layar yang mau menampilkannya). |
| P3-1 Sisa template web | SELESAI | Folder `web/` dihapus, `.metadata` disesuaikan (aplikasi Android saja). |
| P3-2 Deskripsi pubspec template | SELESAI | Diganti deskripsi produk. |
| P3-3 `database.g.dart` ikut ter-commit | TETAP (disengaja) | Dipertahankan agar jalur uji tidak wajib `build_runner`; langkah CI membangun ulang dan menggagalkan build bila hasilnya berbeda. |
| P3-4 Tidak ada CI | SELESAI | `.github/workflows/ci.yml`: `flutter analyze --fatal-infos`, pemeriksaan hasil generate drift, seluruh uji, dan uji tangkapan layar dijalankan ulang. |
| P3-5 Berkas sangat besar (1000+ baris) | BELUM | Pemecahan berkas besar belum dikerjakan (tidak mengubah perilaku, jadi ditunda). |
| P3-6 Dua paradigma state bercampur | BELUM | Penyatuan ke Riverpod dikerjakan bertahap, belum dimulai. |
| P3-7 minSdk/targetSdk tidak dipatok | SELESAI | Dipatok `minSdk = 24`, `targetSdk = 36`. |
| P3-8 analysis_options hanya flutter_lints | SELESAI | **23 aturan** dinyalakan: 4 dari audit 23 Sep + **19 baru** (24 Sep). Cara memilihnya: 28 kandidat diuji sekaligus pada kode sekarang → 19 di antaranya **nol temuan** sehingga langsung jadi gerbang mutu tanpa mengubah satu baris kode. Sembilan sisanya sengaja belum dinyalakan karena menuntut riwayat perubahan besar (jumlah temuan saat diuji: `directives_ordering` 164, `prefer_const_constructors` 76, `unnecessary_lambdas` 29, `prefer_single_quotes` 27, `avoid_slow_async_io` 16, `prefer_final_locals` 9, `prefer_const_declarations` 7, `sort_constructors_first` 6, `prefer_const_literals_to_create_immutables` 4) — dicatat di dalam `analysis_options.yaml`, bukan disembunyikan. `very_good_analysis` tetap belum dipakai (alasan sama). |
| P3-9 Gambar demo & golden ganda | SELESAI | Sumber tunggal = `test/goldens/`; folder `demo/` (dipakai README) sekarang **disalin otomatis** pada akhir penjalanan `flutter test test/tangkapan_layar_test.dart --update-goldens` (`tearDownAll`), jadi tidak bisa basi lagi. 25 gambar basi disamakan + `f6_kesehatan.png` ditambahkan; `demo_f1.png` dipertahankan karena aset README sendiri. Diverifikasi: 28 potret vs 29 gambar demo (28 sama + 1 aset), **nol selisih**. |
| P3-10 `SCHEDULE_EXACT_ALARM` tanpa justifikasi | SEBAGIAN | Alasan penggunaannya ditulis di `docs/PERSIAPAN_PLAY_STORE.md` untuk formulir Play; perpindahan ke alarm inexact belum dikerjakan (pengingat tepat waktu adalah inti fitur). |

### Usulan audit yang BELUM dibangun (bukan bagian perbaikan temuan)

Usulan "Fase 2-3" dari audit (Health Connect, impor rekening PDF/CSV, widget kedua & ketiga,
sinkron E2EE, penampil konflik sinkron, AI on-device, audit aksesibilitas, dll.) **belum
dikerjakan** — daftarnya dicatat sebagai rencana, bukan diklaim selesai. Enkripsi basis data
(SQLCipher) yang semula ada di daftar ini sudah dikerjakan, lihat P2-2 di tabel atas.

## 14 · Cara aplikasi ini diuji (supaya angka uji tidak menyesatkan)

Hasil `flutter test` pada 23 Sep 2026 (setelah Gelombang 1 SDD v19): **1.392 lulus, 1 dilewati,
6 gagal** dari 1.399 berkas kasus uji. Keenam kegagalan itu **bawaan repo, bukan akibat
pekerjaan ini** — dibuktikan dengan menjalankan berkas uji yang sama pada salinan sebelum
perubahan (`/opt/aaron-tools/baseline/lifeos`): hasilnya juga gagal, sama persis:

| Uji yang gagal (warisan) | Sifat |
|---|---|
| `v2_dokumen_test` — (10) `segeraBerakhir`, (13) pengingat lead hari | hitungan hari bergantung tanggal berjalan |
| `v2_dokumen_test` — hitungan murni `sisaHari` & status masa berlaku | batas hari |
| `v2_aksi_test` — tukar jadwal perawatan berkala | selisih waktu (23:00 vs 00:00) |
| `v3_langganan_pintar_test` — langganan jarang dipakai (257 vs 256 hari) | selisih satu hari |
| `v2_ibadah_test` — `hitungRamadan` (36 vs 35 hari) | selisih satu hari |

Keenamnya **belum diperbaiki** (bukan bagian temuan audit); keputusannya diserahkan ke pemilik.
Sebelas kegagalan lain yang dulu ada (4 uji layar akun + uji tirai kunci) **sudah betul**: akarnya
sama — kanal platform tidak pernah menjawab di dalam waktu tiruan uji widget. Perbaikannya:
gudang rahasia **disuntik** (`PenyimpanRahasia(pengaturan, gudang: …)`, lihat
`test/bantuan/gudang_memori.dart`), bukan lewat kanal. Uji tirai kunci yang dulu menggantung
4 menit 55 detik kini selesai ~1 detik.

Dua catatan penting soal menjalankan uji:

1. **Host uji wajib glibc ≥ 2.38.** Biner SQLCipher yang diunduh hook mensyaratkan glibc 2.38;
   di host lama seluruh uji gagal memuat pustaka (bukan karena kode). Dipakai Ubuntu 24.04
   (`flutter test` di Austria).
2. **Kanal platform ditirukan di uji** (`test/flutter_test_config.dart`). Di dalam uji widget,
   panggilan kanal sungguhan tidak selesai di bawah waktu tiruan (`pumpAndSettle` menggantung),
   jadi brankas Keystore dan enkripsi cadangan ditirukan: brankas = peta memori, enkripsi =
   XOR + HMAC-SHA256 (**bukan** AES-256-GCM). Karena itu: **enkripsi sungguhan hanya bisa
   dibuktikan di HP**, bukan oleh suite Dart. Uji tangkapan layar (golden) diperbarui dan
   dijalankan ulang; font Roboto dicari lewat `FLUTTER_ROOT`, bukan path mati.

## 15 · Jaringan ikat SDD v19 — Gelombang 1

Pekerjaan ini mengikuti dokumen SDD v19 bagian "arsitektur lapisan". Gelombang 1 =
**empat tabel batang** yang jadi jaringan ikat seluruh aplikasi, plus dua layar yang
membuatnya langsung berguna. Skema basis data naik **18 → 19**.

| Tabel | Gunanya | Kolom kunci |
|---|---|---|
| `kotak_masuk` | catat cepat: satu pintu, nol keputusan. Sortir belakangan. | `status` (baru/arsip/diproses/dibuang), `tujuan_tabel`, `tujuan_uid` |
| `catatan_harian` | satu halaman per hari; tulisan pengguna dan ringkasan mesin dipisah kolom | `tanggal_kunci` (YYYY-MM-DD, unik), `isi`, `ringkasan_mesin` |
| `tautan` | graf polimorfik antar semua entitas (pengganti bertahap `tautan_pengetahuan`) | `entitas_a`/`uid_a`/`entitas_b`/`uid_b`, `label`, `usulan` |
| `sorotan` | kutipan yang ditinggikan — bahan baku ringkasan progresif | `entitas`, `entitas_uid`, `kutipan`, `mulai`/`akhir`, `warna` |

Lima belas indeks v19 dipasang bersamaan (`idx_km_*`, `idx_ch_*`, `idx_tautan_*`,
`idx_sorotan_*`), termasuk `idx_tautan_balik` untuk panel "Dirujuk oleh".

Dua hal yang ikut dibetulkan di jalur migrasi:

1. **Urutan blok migrasi dirapikan menaik** (semula 18 → 17 → 16 → 15, kini 2 → 19).
   Urutan lama tidak menaik sehingga pembacaan jalur migrasi menyesatkan.
2. **Perpindahan data tautan lama**: baris `tautan_pengetahuan` dipindahkan ke `tautan`
   hanya bila kedua ujungnya punya `uid` yang nyata. Entitas tanpa `uid` **tidak
   dikarang** — dilewati dan jumlahnya dilaporkan lewat `debugPrint`.

Yang bisa dipakai sekarang:

* **Catat Cepat** (menu Lainnya) — tulis/tempel apa saja, tersimpan ke kotak masuk;
  tiga tindakan sortir: *Ke catatan hari ini* (teks masuk ke halaman hari ini **dan**
  dibuat tautan jejak asal), *Arsipkan*, *Buang* (ditandai, tidak dihapus).
* **Catatan Harian** (menu Lainnya) — halaman per hari, geser hari, simpan tulisan,
  tambah sorotan, lihat ringkasan mesin (terpisah dari tulisan), dan panel
  **Dirujuk oleh** yang membaca tabel `tautan`.
* Aksi pengguna pada dua layar itu tercatat di catatan aktivitas (modul baru:
  `kotak_masuk`, `catatan_harian`).

Batas jujur Gelombang 1 (belum dikerjakan, bukan disembunyikan):

* **Tebakan tujuan otomatis** untuk kotak masuk belum dipasang — jadi belum ada usulan
  mesin di layar Catat Cepat.
* **Sorotan belum bisa dibuat dari pilihan teks** di halaman catatan; masih berupa
  masukan teks kutipan.
* **Penegakan relasi antar-tabel tetap dimatikan** (tidak ada `REFERENCES`), sesuai
  keputusan dokumen: ditunda ke v20.
* **Gelombang 2 (lima tabel kesehatan) sudah selesai** — lihat bagian 17.
  **Gelombang 3** (orang + mesin pola) juga sudah selesai — lihat bagian 18.
* APK yang berlaku sekarang adalah **v1.14.1-build18** (perbaikan 24 Sep 2026) — lihat bagian 19.
  APK versi lama (`v1.13.0-build16`, `v1.12.0-build15`, `v1.11.0-build14`) sudah digantikan;
  semuanya masih bisa diunduh dari `aaron.my.id/unduh/`.
  **Catatan jalur unduh:** pakai `https://aaron.my.id/unduh/personal-life-os-<versi>.apk`.
  Jalur `coder.sam.university/apk/...` tetap hidup sebagai cadangan, tetapi di HP Papi
  tautan itu membuka **aplikasi Coder** (app-link), bukan mengunduh berkas — jadi
  jangan dipakai untuk membagikan APK.

Uji: berkas baru `test/v19_jaringan_ikat_test.dart` berisi **22 kasus** — skema & indeks,
migrasi v18 → v19 pada berkas nyata (termasuk dijalankan dua kali), perilaku empat
repositori, dan dua uji layar. Angka suite penuh menyusul di bagian 14 setelah
penjalanan terakhir gelombang ini.

## 16 · Tempat kode disimpan (GitHub & cadangan)

| Tempat | Isi | Catatan |
|---|---|---|
| GitHub `sam8888888888/personal-life-os` (publik) | rilis kode v1.14.1+18 = commit `96b5699`; commit dokumen & uji menyusul sesudahnya (`ed6ddf5`) | naik dari `9ae0f16` (v1.9.2) lewat `cc3a771` → `e24592b` → `3e4ae26` → `60d772f` → `0e0b6a8` → `e320ab9` → `ac5d50c` → `d8daa72` (v1.14.0+17) → `96b5699` |
| Arsip sumber `lifeos-src-v1.14.1-build18_20260924_142455.tar.gz` (12,1 MB) | pohon kerja penuh v1.14.1+18 (termasuk perbaikan kerapian 24 Sep) | SHA-256 `2fb3064ecacc01ee6508a93c8e76675dbcc58ff6054b6342c347bf109001d55b` |
| Bundel git `lifeos-main-72ecde2_20260924_142455.bundle` (41,6 MB) | riwayat git penuh (`--all`, 7 ref) | SHA-256 `f55992ed6c3a64e3c341552194bef680b7a479fb364ef7dff7dcba288243c6bc`; diuji bisa dipulihkan dengan `git clone` (613 berkas, commit `72ecde2`) |
| Arsip berkas di luar git `lifeos-untracked-20260924_142455.tar.gz` | `.github/` + `batch_audit/` | SHA-256 `bcbbf66b5213595d3fc25133be9f3320bf4a0725f21b6423f6e3bd71faaad037` |
| APK `personal-life-os-v1.14.1-build18.apk` (65.684.711 byte) | rilis perbaikan 24 Sep 2026 | SHA-256 `9bc6b48d95056521cb0961c3c96dae3033e569e9edc70dce0c3a1d21fd8b1181`, sertifikat sama dengan versi sebelumnya |

**Arsip sumber** disimpan di tiga tempat: `/opt/data/lifeos/backups/` (OVH),
`/opt/aaron-tools/lifeos-backups/` (Austria), `/home/aaron/lifeos-backups/` (Contabo).
**Bundel git** disimpan di dua tempat: OVH dan Austria (jalur ke Contabo hanya
±1,3 MB/menit, jadi yang dikirim ke sana arsip sumbernya saja — riwayat penuh tetap
aman di GitHub, OVH, dan Austria).
Berkas `SHA256_*.txt` ikut disalin, jadi keutuhan tiap salinan bisa diperiksa ulang
dengan `sha256sum -c`. Sidik jari set berlaku (set rilis **24 Sep 2026 · v1.14.1+18**;
set gelombang 3 tetap tersimpan sebagai riwayat di OVH & Austria):

| Salinan | Arsip sumber | Bundel git |
|---|---|---|
| OVH `/opt/data/lifeos/backups/` | ada (`2fb3064e…d55b`) | ada (`f55992ed…c6bc`) |
| Austria `/opt/aaron-tools/lifeos-backups/` | ada (`sha256sum -c` **OK**) | ada (`sha256sum -c` **OK**) |
| Contabo `/home/aaron/lifeos-backups/` | set lama (v1.13.0+16) | tidak dikirim (jalur lambat) |
| GitHub `sam8888888888/personal-life-os` | — | seluruh riwayat |

Cadangan dibuat ulang tiap rilis/perubahan; angka di tabel ini berlaku untuk set
**24 Sep 2026 (v1.14.1+18)** dan ketiganya sudah diuji `sha256sum -c` di Austria.

Satu berkas **tidak** bisa ikut ke GitHub: `.github/workflows/ci.yml` (gerbang
analisis & uji otomatis). Kredensial yang dipakai untuk push tidak punya izin
`workflow`, jadi GitHub menolak commit yang memuatnya. Berkas itu tetap ada di
pohon kerja dan di dalam arsip cadangan; untuk memasukkannya ke GitHub perlu
kredensial dengan izin `workflow` atau menambahkannya lewat web GitHub.

## 17 · Kesehatan SDD v19 — Gelombang 2 (lima tabel kesehatan)

Skema **19 → 20**. Lima tabel baru (SDD §4.5–4.9) beserta 20 indeks, layar, dan
repositorinya:

| Tabel | Isi | Indeks | Aturan yang dijaga kode |
|---|---|---|---|
| `hasil_lab` | Kepala panel lab (tanggal, panel, laboratorium, anggota) | 5 (`uid`, `id_hasil` unik; tanggal, panel, anggota) | Nama panel wajib; `uid` + `idHasil` stabil lintas HP |
| `analit_lab` | Satu nilai di dalam panel (nilai/teks, satuan, rujukan bawah–atas, bendera) | 4 (`uid` unik; induk, nama; **parsial** bendera) | Minimal satu dari angka/teks wajib; rentang terbalik ditolak; **tanpa rentang rujukan → `tidak_dinilai`** (tidak menebak) |
| `gejala` | Gejala + mulai/selesai/durasi + berat persepsi 1–5 | 4 (`uid` unik; mulai; nama+mulai; anggota+mulai) | Nama wajib; selesai < mulai ditolak; berat di luar 1–5 **dijepit** agar catatan tidak hilang |
| `imunisasi` | Rekaman vaksin (anggota wajib, dosis, tanggal, batch, berikutnya) | 4 (`uid` unik; (anggota,vaksin,dosis) unik; anggota+tanggal; **parsial** berikutnya) | Ganda ditolak; jadwal berikutnya **tidak pernah dihitung** aplikasi |
| `tumbuh_kembang` | Berat, tinggi, lingkar kepala, umur bulan | 3 (`uid` unik; (anggota,tanggal) unik; umur) | Minimal satu ukuran; angka di luar akal ditolak; **satu anak = satu baris per hari** (simpan ulang menimpa) |

Yang **ditambahkan**:

* `lib/data/repository/{hasil_lab,gejala,imunisasi,tumbuh_kembang}_repository.dart`
  — aturan integritas di atas hidup di sini, bukan di layar.
* `lib/features/kesehatan/lab_screen.dart` — daftar panel, detail analit, dan
  **tren analit** (`Hb: 11,2 → 11,8 → 12,4`).
* `lib/features/kesehatan/gejala_screen.dart` — catat gejala + ringkasan
  **frekuensi** (bahan mentah mesin pola di Gelombang 3).
* `lib/features/kesehatan/imunisasi_tumbuh_screen.dart` — register imunisasi per
  anggota + deret pengukuran anak.
* `lib/core/providers/kesehatan_providers.dart` — 4 provider repo + pemilih anggota.
* Registri sinkron: **5 jalur baru** (`hasil_lab` sebelum `analit_lab`, karena
  analit menunjuk induknya lewat `hasil_lab_id`).
* Modul audit baru: `hasil_lab`, `gejala`, `imunisasi`, `tumbuh_kembang`.
* Empat pintu baru di hub kesehatan: Hasil laboratorium, Catatan gejala,
  Imunisasi, Tumbuh kembang.

Yang **sengaja belum dikerjakan** (jujur, bukan disamarkan):

* **Persentil & kurva tumbuh kembang belum ditampilkan.** Menghitungnya butuh
  tabel rujukan kurva yang dibundel di aplikasi; selama belum dipasang,
  `persentil_bmi` dibiarkan **kosong** dan layar menyatakan alasannya —
  angkanya tidak ditebak.
* Grafik pengukuran masih berupa daftar angka (belum grafik).
* Nyalakan penegakan kunci asing (FK) antar-tabel tetap ditunda ke v20 sesuai
  keputusan dokumen; kolomnya sudah ada dan sudah diuji.
* Gelombang 3 (tabel orang + mesin pola) belum dimulai.

Uji gelombang ini: berkas baru `test/v20_kesehatan_test.dart` berisi **33 kasus**
(skema v20 & 20 indeks, migrasi v19 → v20 pada berkas nyata **beserta bukti data
v19 tidak hilang**, aturan hasil lab/analit, gejala, imunisasi, tumbuh kembang,
registri sinkron, dan modul audit). Hasilnya **33/33 lulus**.

Suite penuh: **1.425 lulus / 1 dilewati / 6 gagal** (naik dari 1.392 lulus di
Gelombang 1 — selisih 33 tepat sebanyak kasus baru). Keenam kegagalan adalah uji
peka tanggal/Ramadan bawaan, **bukan** akibat perubahan ini: keenamnya dijalankan
ulang pada salinan lama (`/opt/aaron-tools/baseline/lifeos`, kode sebelum
perubahan) dan hasilnya **gagal pada 6 uji yang sama** (`v2_aksi` FR-83,
`v2_dokumen` FR-128/FR-129/hitungan murni, `v2_ibadah` hitungRamadan,
`v3_langganan_pintar` FR-70). `flutter analyze lib` → **No issues found**.

Versi aplikasi naik ke **1.12.0+15** (`versi.dart`, `pubspec.yaml`, dan dokumentasi
ekspor cadangan ikut disamakan).

### APK gelombang ini

`personal-life-os-v1.12.0-build15.apk` — **universal** (arm64-v8a + armeabi-v7a + x86_64),
**95.159.750 byte**, `versionCode 15`, `versionName 1.12.0`,
SHA-256 **`56ca567aa0d3335321ccfdb911ead341aac7ea272b3e44be8efa13501683dbbf`**.
Sertifikat penanda tangan SHA-256 `7a56a135…506b` — **sama** dengan v1.11.0, jadi
aplikasi lama bisa diperbarui tanpa menghapus data. **12 izin, nol izin SMS**
(sesuai keputusan menghapus pemindai SMS bahaya).

Unduhan: **`https://aaron.my.id/unduh/personal-life-os-v1.12.0-build15.apk`**
(HTTP 200, `content-type: application/octet-stream`; berkas yang diunduh sudah
dibandingkan SHA-256-nya dan **identik**). Cadangan jalur:
`https://coder.sam.university/apk/personal-life-os-v1.12.0-build15.apk`.
Basis data di HP naik otomatis **19 → 20** saat aplikasi pertama dibuka; tabel
kesehatan baru dibuat di tempat, data lama tidak disentuh.

## 18 · Orang dan mesin pola SDD v19 — Gelombang 3

Skema **20 → 21**. Dua tabel penutup dari sebelas tabel SDD v19:

| Tabel | Isi | Indeks | Aturan yang dijaga kode |
|---|---|---|---|
| `orang` | CRM pribadi: dokter, guru, tetangga, atasan, montir (di luar keluarga inti) | 5 (`uid` dan `id_orang` unik; nama; hubungan+nama; ulang tahun parsial) | Nama wajib (1–120); hubungan tak dikenal jatuh ke `lain`; **satu anggota keluarga maksimal satu baris**; `terakhir_dihubungi` hanya diisi pengguna |
| `temuan` | Hasil korelasi lintas domain yang **disimpan** (bisa menjawab "apakah pola ini masih benar bulan lalu?") | 4 (`uid` unik; `kode+rentang` unik; waktu hitung; tampil parsial) | **n kurang dari 14 DITOLAK**; bahasa terlarang DITOLAK; `n` selalu tersimpan; umpan balik "bukan begitu" **tidak dihidupkan lagi** oleh hitung ulang |

**Mesin pola** (`lib/core/pola/`):

* `mesin_pola.dart` — murni hitungan, bisa diuji tanpa HP: peringkat dengan nilai
  kembar, **Spearman** (bukan Pearson), **nilai-p uji permutasi** (benih tetap,
  jadi bisa diulang), koreksi **Bonferroni** dan **Benjamini–Hochberg**, penjaga
  bahasa, dan penyusun kalimat pola yang selalu memuat `n`.
* `pasangan_pola.dart` — pasangan yang **bisa** diuji sekarang (4): `tidur~suasana_hati`,
  `aktivitas~energi`, `air~gejala`, `gejala~tidur`; dan pasangan yang **belum bisa**,
  lengkap dengan alasannya (6) — ditampilkan di layar, bukan disembunyikan.
* `penjalankan_pola.dart` — ambil data, hitung, simpan, plus alasan jujur untuk
  pasangan yang datanya belum cukup.

**Layar:** `/orang`, `/orang/:id`, `/temuan`; dua pintu baru di tab Lainnya
("Orang dan Kontak", "Pola di Catatan"). Saklar **"Ingatkan ulang tahun orang"
bawaan MATI** — sesuai aturan etika dokumen: aplikasi tidak memantau hubungan
sosial siapa pun tanpa diminta.

Satu kesalahan nyata yang ditemukan dan dibetulkan di gelombang ini: penjaga
bahasa versi pertama **menuduh kalimat jujur aplikasi sendiri**, karena kalimat
"...bukan diagnosis" memuat kata "diagnosis". Akibatnya semua temuan ditolak.
Penjaga sekarang memakai daftar larangan dokumen apa adanya
("anda mengalami", "anda menderita", "penyebab", "karena anda", "menyebabkan",
"penyakit anda") dan membuang sanggahan yang ditulis aplikasi sebelum memeriksa.

**Sengaja belum dikerjakan** (jujur): enam pasangan pola dari dokumen belum bisa
diuji karena datanya belum ada di aplikasi (belum ada catatan waktu sholat
harian, belum ada catatan siklus haid, transaksi belum ditandai "impulsif",
catatan makan belum dibedakan di rumah vs di luar); grafik pengukuran anak masih
daftar angka; penegakan kunci asing antar-tabel tetap ditunda ke v20 sesuai
keputusan dokumen.

Uji gelombang ini: `test/v21_pola_orang_test.dart` — **39 kasus**, termasuk contoh
Spearman yang bisa diperiksa tangan (X=[1,2,3], Y=[1,3,2] → 0,5), koreksi BH
(p=[0,01; 0,02; 0,03] → 0,03 semuanya), penolakan n kurang dari 14, dan
pembuktian bahwa temuan yang dibungkam tidak dihidupkan kembali oleh hitung ulang.

Suite penuh setelah gelombang ini: **1.464 lulus / 1 dilewati / 6 gagal** (gelombang
1: 1.392; gelombang 2: 1.425; selisih 39 tepat sebanyak kasus baru). Keenam
kegagalan tetap uji peka tanggal/Ramadan bawaan yang sudah dibuktikan gagal pada
salinan kode lama. Dua potret layar ikut diperbarui: `f5_lainnya.png` (dua menu
baru) dan `f10_cadangan.png` (nomor versi). Satu potret lagi, `f5_briefing.png`,
berubah karena layar itu menampilkan **hitung mundur waktu** — jadi memang bisa
berubah sendiri tanpa perubahan kode (bukan akibat gelombang ini).

### APK gelombang ini

`personal-life-os-v1.13.0-build16.apk` — **universal** (arm64-v8a + armeabi-v7a + x86_64),
**95.438.278 byte**, `versionCode 16`, `versionName 1.13.0`,
SHA-256 **`749fadd140bdcdb9e63184d707bd3356ff35cebf65515c27bd232bd50fcc980e`**.
Sertifikat penanda tangan SHA-256 `7a56a135…506b` — **sama** dengan dua rilis
sebelumnya, jadi bisa dipasang sebagai pembaruan tanpa menghapus data.
**12 izin, nol izin SMS.**

Unduhan: **`https://aaron.my.id/unduh/personal-life-os-v1.13.0-build16.apk`**
(satu-satunya jalur resmi; `coder.sam.university/apk/...` hanya cadangan server).
Basis data di HP naik otomatis **20 → 21** saat aplikasi pertama dibuka.

## 19 · Rilis desain + perbaikan laporan pengguna — v1.14.1 build 18 (24 Sep 2026)

Dua rilis berurutan di atas gelombang 3:

* **v1.14.0 build 17** (commit `d8daa72`) — rilis desain "Editorial Modern": latar seperti
  kertas, arang lembut untuk mode gelap, satu aksen hijau sage, kartu tanpa bayangan +
  garis tipis, hierarki "fokus dulu, detail menyusul" (`lib/core/theme/app_tema.dart`,
  komponen bersama `lib/core/theme/editorial.dart`).
* **v1.14.1 build 18** (commit `96b5699`) — perbaikan tujuh temuan dari uji di HP.
  Tidak ada perubahan skema basis data, jadi data di HP tidak disentuh.

Tujuh temuan pengguna, sebabnya, dan buktinya:

| Temuan | Sebab nyata | Perbaikan | Bukti |
|---|---|---|---|
| 1. "Semua Fitur" dibuka → layar kosong | Rute `/peta-fitur` salah tempat: berada di dalam blok rute bersarang sehingga tidak pernah terdaftar sebagai rute akar | Dipindah ke tingkat akar bersama `/akun` | `test/v3_regresi_menu_tampilan_test.dart`, `test/v3_regresi_jalur_menu_test.dart` |
| 2. "Catat Cepat" tidak bisa menyimpan | Basis data **tidak** rusak; yang salah adalah tata letak: tombol Simpan terdorong keluar layar pada lebar HP | Tombol disusun ulang (bukan lagi satu baris kaku) sehingga selalu terlihat & bisa ditekan | `test/v3_regresi_jalur_menu_test.dart` (mengetuk tombol → baris benar-benar masuk SQLite) |
| 3. "Catatan Harian" sama | Idem, satu jalur dengan Catat Cepat | Terselesaikan bersama perbaikan di atas | `test/v3_regresi_jalur_menu_test.dart` (tulisan pengguna tersimpan) |
| 4. "Orang & Kontak" → galat SQL | Bukan galat SQL: `Wrap` vs `Row` tombol ulang tahun + Simpan meluber 276 piksel pada lebar 360 px | `Row` → `Wrap` + spasi | `test/v3_regresi_orang_layar_test.dart` (layar 360×600, kontak tersimpan) |
| 5. Ketebalan kotak menu tidak sama | Subjudul dua baris membuat tinggi baris menu berbeda-beda | Subjudul dibatasi satu baris (`_MenuSubtitle`) | uji tinggi tile menu yang harus sama di `test/v3_regresi_menu_tampilan_test.dart` |
| 6. "Akun & Sinkron" kosong | Rute `/akun` dan `/akun/masuk` berada di dalam blok bersarang | Dipindah ke tingkat akar | `test/v3_regresi_jalur_menu_test.dart` |
| 7. "Ringkasan pagi" dan layar lain terpotong | Isi layar tidak dapat digulir + tidak ada ruang bawah untuk bilah navigasi | `Scrollbar` + `ListView` dengan ruang bawah 112 px | `test/v3_regresi_menu_tampilan_test.dart` (layar 360×600, tanpa luapan) |

Jujur soal batasnya: laporan pengguna menyebut "galat SQL", tetapi **tidak ada jejak galat
SQLite** yang bisa direproduksi di sini — seluruh jalur simpan (kotak masuk, catatan harian,
orang) lolos di basis data nyata, termasuk migrasi v2 → v21. Karena itu **jangan hapus data
aplikasi** kalau masih muncul galat: kirimkan teks galatnya supaya bisa ditelusuri.

Angka uji rilis ini: `flutter analyze` **bersih** · suite penuh **1.484 lulus / 1 dilewati /
0 gagal** (67 detik). Sebelumnya, gelombang 3 mencatat 6 kegagalan uji peka tanggal; pada
rilis ini angkanya **nol gagal**.

### APK rilis perbaikan

`personal-life-os-v1.14.1-build18.apk` — **universal** (arm64-v8a + armeabi-v7a + x86_64),
**65.684.711 byte**, `versionCode 18`, `versionName 1.14.1`,
SHA-256 **`9bc6b48d95056521cb0961c3c96dae3033e569e9edc70dce0c3a1d21fd8b1181`**.
Tanda tangan v2 **dan** v3 terverifikasi, sertifikat SHA-256 `7a56a135…506b` — sama dengan
rilis sebelumnya, jadi bisa dipasang sebagai pembaruan tanpa menghapus data.
Izin `READ_SMS` **tidak ada** (diperiksa dengan `aapt2 dump permissions`).

Unduhan: **`https://aaron.my.id/unduh/personal-life-os-v1.14.1-build18.apk`**
(diuji: HTTP 200, `content-type: application/octet-stream`, berkas 65.684.711 byte, dan
SHA-256 hasil unduhan **sama** dengan berkas rilis).

