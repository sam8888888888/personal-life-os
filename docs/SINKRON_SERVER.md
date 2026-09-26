# Sinkron ke Server (Akun & Sinkron) — keadaan nyata & rencana

Dokumen ini menjawab pertanyaan Papi (26 Sep 2026): *"Seumpama semua data disimpan di web
(database server), bisa nggak? Supaya bisa dipakai jutaan orang dan semua akun benar-benar
tersinkron."*

Jawabannya: **bisa — dan sebagian besar sudah dibangun.** Dokumen ini mencatat apa yang
sudah terbukti, apa yang belum, dan keputusan yang sudah diambil Papi.

## 1. Keputusan Papi (26 Sep 2026)

1. **Sinkron bersifat OPSIONAL per akun** — ada tombol nyalakan/matikan, pengguna memilih
   sendiri. Janji "data tidak keluar dari HP" tetap berlaku sampai pengguna menyalakannya.
2. **Mulai dari pilot akun Papi sendiri** — uji penuh: daftar, masuk, sinkron dua arah,
   mode pesawat.

## 2. Yang sudah ada (bukan rencana)

| Bagian | Keadaan |
|---|---|
| Aplikasi: klien API | `lib/core/akun/klien_akun.dart` — tanpa paket tambahan (cukup `dart:io` + `dart:convert`), alamat server diatur lewat `--dart-define=LIFEOS_API` |
| Aplikasi: mesin sinkron | `lib/core/sinkron/sinkron_semua.dart` (FR-150) — **10 modul**: kotak masuk, catatan harian, tagihan, transaksi, orang, dokumen, kebiasaan, tugas, visi, temuan; ada sidik perubahan, penanda hapus, pemulihan kaitan tertunda |
| Aplikasi: sesi | token disimpan **terenkripsi** di brankas Keystore (audit P0-3), bukan di basis data |
| Aplikasi: layar | `Akun & Sinkron` — Masuk, Daftar akun baru, Periksa server, **Sinkron sekarang**, Keluar; plus sinkron lewat berkas tanpa server |
| Server | `lifeos-sync` (Austria, `/opt/aaron-tools/lifeos-sync`), API v1.0.0 di `https://coder.sam.university/lifeos-api`, hanya terikat `127.0.0.1:3500` + nginx/TLS |
| Pintu API | `GET /sehat`, `POST /daftar`, `POST /masuk`, `GET /akun`, `DELETE /akun`, `POST /keluar`, `POST /ganti-sandi`, `POST /sinkron` |
| Keamanan server | kata sandi di-hash + salt; token di-hash (sha256) + kedaluwarsa; semua endpoint berkunci wajib token; setiap kueri difilter `akun_id` |
| Isi server | **0 akun, 0 catatan** — layanan siap, belum dipakai siapa pun |

## 3. Bukti uji (26 Sep 2026)

**A. Sisi server** — `uji_api.py` di Austria: **18/18 lulus** (daftar, masuk, sandi salah
ditolak, tanpa token ditolak, token palsu ditolak, pemisahan akun A/B, sinkron dua arah,
konflik tersimpan, keluar mematikan sesi, hapus akun).

**B. Sisi aplikasi (kode yang sama dengan APK)** — `tool/uji_nyata_sinkron.dart`, dijalankan
lewat **dua jalur**:

| Jalur | Hasil |
|---|---|
| `http://127.0.0.1:3500` (jalur dalam) | **16/16 lulus** |
| `https://coder.sam.university/lifeos-api` (jalur publik, seperti APK) | **16/16 lulus** |

Yang dibuktikan: daftar dua akun · masuk ulang · sandi salah ditolak · dorong 2 perubahan
(`tagihan` + `kebiasaan`) → `diterima=2`, revisi naik `2` · tarik kembali 2 catatan dengan isi
utuh · **akun B tidak melihat data akun A** (0 catatan) · aturan konflik dua arah (versi lebih
**baru** menang & tersimpan; versi lebih **lama** kalah tapi **tetap disimpan** sebagai catatan
konflik, tidak menimpa) · token yang sudah keluar ditolak.

Bentuk data aplikasi ⇄ server **cocok persis**: `{tabel, id_lokal, waktu_klien, dihapus, isi}`
dan balasan `{diterima, konflik, revisi, perubahan}`.

Akun uji memakai alamat `*@lifeos.test` dan dibersihkan dengan `bersihkan_akun_uji.py` —
sesudah uji: **sisa akun 0**.

## 4. Yang BELUM

1. **Belum pernah diuji dari HP Papi** (perjalanan sungguhan: daftar di aplikasi → sinkron →
   mode pesawat → tulis → internet hidup → cek masuk).
2. **Belum ada tombol nyalakan/matikan sinkron** di aplikasi (keputusan Papi no. 1) —
   sekarang sinkron masih manual lewat "Sinkron sekarang". Ini dikerjakan di rilis berikutnya.
3. **Belum ada pemantauan, cadangan otomatis, dan kuota** di server.
4. **Server masih SQLite satu berkas.** Cukup untuk ribuan pengguna; untuk jutaan perlu
   PostgreSQL + replika + pemantauan.
5. **Belum ada uji beban** (berapa akun/penyimpanan per menit yang sanggup dilayani).
6. **Server masih dipakai bersama banyak layanan lain** di Austria.

## 5. Kalau mau dipakai jutaan orang

| Bagian | Sekarang | Perlu |
|---|---|---|
| Pangkalan data | SQLite (1 berkas) | PostgreSQL (banyak mesin, jutaan baris) |
| Daya | Austria 8 core/16 GB, dipakai bersama | server khusus + replika baca |
| Batas pemakaian | belum ada | kuota per akun, pencatatan pemakaian, tagihan |
| Operasional | manual | cadangan otomatis + pemantauan 24 jam + tanggap gangguan |
| Isolasi antar akun | sudah per akun | **wajib diuji ulang tiap rilis** (IDOR / bocor antar-pengguna) |

Perkiraan kasar biaya (urutan besaran, bukan penawaran): ratusan ribu pengguna aktif →
ratusan dolar/bulan; jutaan pengguna aktif → ribuan dolar/bulan **plus** kerja perawatan.
Angka pasti hanya bisa dihitung setelah ada data pemakaian nyata per akun.

## 6. Yang TIDAK berubah: basis data di HP tetap ada

Basis data lokal **tidak dibuang**. Alasannya sederhana:

* aplikasi Papi dipakai di lift, pesawat, dan daerah sinyal jelek — tanpa basis data lokal,
  aplikasi mati total dan pengingat tagihan jadi bergantung internet;
* membaca dari server setiap kali membuka layar terasa lambat dan boros kuota;
* pola yang benar: **HP = meja kerja (selalu ada), server = gudang pusat + penyambung
  antar-perangkat.**

Jadi tujuannya bukan "pindah ke server", tapi "**HP + server, disinkronkan**".

## 7. Langkah berikutnya (urut)

1. Papi memasang **APK v1.14.2 build 19** (perbaikan galat basis data).
2. Papi **daftar akun di aplikasi** (menu Akun & Sinkron) memakai email + sandi pilihan Papi.
   Sandi **tidak** dikirim lewat chat, tidak pernah saya lihat.
3. Aaron memeriksa dari sisi server: apakah akun Papi muncul, apakah data benar-benar naik,
   dan apakah data tetap utuh di HP (uji dua arah).
4. Perbaikan hasil temuan pilot + **tombol nyalakan/matikan sinkron** (keputusan Papi no. 1)
   → rilis berikutnya.
5. Baru bicara skala (PostgreSQL, kuota, harga) kalau pilot sudah bersih.
