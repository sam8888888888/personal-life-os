# STATUS FITUR PRD v3.1 — 152 butir

Disusun ulang oleh Aaron (Ron) · 22 Sep 2026 (Batch 13: FR-38 & FR-50 selesai; FR-59 SEBAGIAN — baca notifikasi bank tidak dikerjakan atas keputusan pemilik).
Penandaan jujur: **SELESAI** = ada kode + uji dan sudah diverifikasi; **SEBAGIAN** = ada tetapi belum lengkap; **BELUM** = belum ada jejaknya.

**Hitungan: SELESAI 151 · SEBAGIAN 1 · BELUM 0** (total 152 butir)


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
| FR-24 | Ekspor cadangan JSON + impor restore (termasuk migrasi antar HP) | - | SELESAI | `lib/core/backup/ekspor_impor.dart`, `lib/features/pengaturan/backup_screen.dart`, uji 28/28. Batas: pemilihan berkas hanya dari folder dokumen aplikasi; berkas tidak dienkripsi. |
| FR-25 | Ekspor CSV untuk dibuka di spreadsheet | - | SELESAI | Ron 21 Sep: ekspor CSV tagihan & riwayat pembayaran (menu Uang → Ekspor CSV), uji 8 kasus. |
| FR-26 | Kunci aplikasi (PIN/pola/biometrik) untuk data sensitif | - | SELESAI | Ron 22 Sep: PIN 4-12 angka disimpan sebagai turunan PBKDF2-HMAC-SHA256 (PIN mentah tidak pernah ditulis); salah 5 kali -> percobaan ditahan 30 detik; boleh dibuka dengan kunci perangkat HP (sidik jari/PIN HP lewat Android Keyguard); tirai kunci menahan ISI aplikasi sampai PIN benar; masa tenggang sebelum terkunci lagi bisa diatur (langsung/30 dtk/1 mnt/5 mnt). Uji: 11 kasus (logika + layar). |
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
| FR-39 | Pemindai SMS/notifikasi bank on-device (opt-in): deteksi pembayaran ta | V2 | SELESAI | Ron 22 Sep: izin bawaan mati + dialog sistem; penguraian di perangkat; usulan saja (tagihan tidak pernah ditandai lunas sendiri). Rute /uang/pemindai-bank. |
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
| FR-59 | Auto-catat pengeluaran (perluas FR-39) | F8 | SEBAGIAN | Ron 22 Sep: dari SMS bank sudah bisa (catat pengeluaran / tandai lunas, satu ketukan). Membaca NOTIFIKASI aplikasi bank SENGAJA TIDAK dikerjakan — keputusan pemilik, izin baca semua notifikasi terlalu berisiko. |

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
| FR-108 | Brankas Catatan Medis | V3 | SELESAI | Ron 22 Sep: brankas catatan medis — jenis (lab, tahunan, resep, imunisasi, tagihan medis, dokter, pencitraan), pencarian kata menjangkau judul/hasil/ringkasan/tenaga kesehatan/fasilitas + lampiran berkas TERENKRIPSI (AES-256-GCM, kunci di Android Keystore, tidak diekspor). Bila perangkat tidak mendukung enkripsi, berkas TIDAK disimpan. |
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
