# Laporan Fase 3 — Personal Life OS (Pengingat & Notifikasi)

**Tanggal:** 10 September 2026
**Fase:** F3 · Pengingat & notifikasi (PRD §6.2, FR-10 … FR-16)
**Kriteria selesai (gate PRD §11.3):** ≥95% notifikasi **tepat waktu** di **≥4 perangkat uji**
(Samsung / Xiaomi / Oppo / Pixel).

> **Catatan jujur di depan:** gate "≥95% tepat waktu di ≥4 perangkat" **belum bisa saya
> buktikan** di lingkungan kerja ini — tidak ada HP fisik maupun emulator di sini.
> Yang sudah terbukti: kode benar secara analisis & 79 uji otomatis lulus, jadwal
> pengingat benar menurut data, dan APK debug berhasil dibangun (bukti Gradle +
> manifest + izin Android sudah benar). Uji ketepatan waktu di perangkat nyata
> menjadi tugas Anda (Bapak) memakai tombol **"Uji notifikasi (10 detik)"** yang
> saya sediakan di layar Pengingat.

---

## 1. Ringkasan

| Ukuran | Nilai |
|---|---|
| Berkas kode baru | **11 berkas · 1.534 baris** |
| Total kode `lib/` | 31 berkas · 8.059 baris |
| Berkas uji | 8 berkas · 1.286 baris |
| Hasil `flutter test` | **79 lulus, 0 gagal** (F3: 27 uji baru) |
| Hasil `flutter analyze` | **No issues found** |
| APK F3 (debug) | 171.03 MB (179.338.297 byte) · SHA-256 `0275bb5bac992b6f904fd3e05e42a9ff60291f5a2227c90feacf8dc45b906a29` |

---

## 2. Yang dibangun (peta FR → kode)

| FR | Janji PRD | Wujud di aplikasi | Kode |
|---|---|---|---|
| **FR-10** | Lead time kustom (H-60…H-0), default cerdas H-3/H-1/H-0, jam pilihan | Chip H-60…H-0 di form (default **H-3, H-1, Hari-H**); pengingat dijadwalkan tepat pada jam pilihan (default 09.00) | `core/notifikasi/perencana_pengingat.dart` |
| **FR-11** | Aksi dari notifikasi | Tombol **"✓ Sudah bayar"**, **"Tunda 1 jam"**, **"Buka aplikasi"** langsung di notifikasi; "sudah bayar" menandai lunas + memutar periode berikutnya | `core/notifikasi/penangan_aksi_pengingat.dart`, `layanan_notifikasi_lokal.dart` |
| **FR-12** | Anti-annoyance | Maksimum **7** pengingat lead per siklus; bila lead lebih banyak, yang dibuang adalah lead **terjauh** (H-30/H-60) — H-1 & hari-H selalu dipertahankan; tidak ada notifikasi ganda (ID notifikasi stabil) | `perencana_pengingat.dart` |
| **FR-13** | Tetap jalan walau aplikasi ditutup + panduan baterai per merek | Pekerja latar Workmanager menyegarkan jadwal tiap **6 jam**; panduan khusus **Xiaomi, OPPO/Realme, Vivo, Samsung, Huawei/Honor, Asus/Infinix/Tecno/Itel** + panduan umum | `core/notifikasi/kerja_latar.dart`, `features/pengingat/layanan_panduan.dart` |
| **FR-14** | Kanal notifikasi terpisah | 3 kanal Android: **Tagihan** (importance high), **Terlambat** (max), **Ringkasan mingguan** (default) — bisa diatur/dimatikan sendiri oleh pengguna lewat pengaturan Android | `layanan_notifikasi_lokal.dart` |
| **FR-15** | Ringkasan mingguan Senin pagi | Notifikasi ringkasan tiap **Senin 08.00** berisi jumlah & daftar tagihan pekan itu (contoh isi: "1 tagihan …") | `perencana_pengingat.dart` |
| **FR-16** | Tagihan terlambat diingatkan | **1 pengingat per hari**, maksimum 7 hari, bunyi lebih tegas ("lewat 3 hari dari jatuh tempo") | `perencana_pengingat.dart` |
| **FR-17** | (P2) pola pintar | **Sengaja belum dibuat** — sesuai PRD masuk prioritas P2 setelah F3 disetujui | — |

Tambahan yang saya buat agar bisa diuji & dipakai:

- **Layar "Pengingat & izin"** (menu baru di Pengaturan): status izin notifikasi &
  alarm presisi, tombol **Minta izin notifikasi**, **Minta izin alarm presisi**,
  **Uji notifikasi (10 detik)**, **Segarkan jadwal**, daftar 20 pengingat berikutnya,
  panduan merek HP, dan 5 catatan jejak terakhir.
- **Jejak pengingat** (`jejak_pengingat.jsonl`): setiap sinkronisasi/aksi dicatat ke
  berkas — bahan menelusuri kalau ada pengingat yang tidak muncul di HP Anda.
- **Gerak otomatis**: jadwal disegarkan saat aplikasi dibuka, saat data tagihan
  berubah (ditunda 2 detik agar tidak berulang), dan saat aplikasi kembali aktif.

---

## 3. Bukti uji (27 uji baru untuk F3)

### 3.1 Uji logika murni — `test/f3_pengingat_test.dart` (18 uji)
Memakai **layanan notifikasi palsu**: jadwal diuji tanpa HP, hasilnya bisa diperiksa tepat.

| Uji | Yang dibuktikan |
|---|---|
| FR-10 lead H-3/H-1/H-0 | Jadwal persis **17 Sep 07.30, 19 Sep 07.30, 20 Sep 07.30** (jam 07:30 pilihan pengguna) |
| FR-12 batas 7 | Lead `60,30,14,7,3,1,0,5,2` → maksimum 7; **Hari-H & H-1 tetap ada**, H-60/H-30 dibuang |
| Lewat masa & horizon | Pengingat yang waktunya sudah lewat atau >45 hari tidak dijadwalkan |
| FR-16 terlambat | Tagihan lewat 3 hari → **7 pengingat harian**, ID berbeda tiap hari, teks "lewat 3 hari" |
| Lunas/nonaktif | Tidak dijadwalkan sama sekali |
| FR-15 ringkasan | Notifikasi Senin **08.00**, ID tetap `99999999`, isi menyebut "1 tagihan" & nama tagihan |
| Jam tidak valid | `99:99` / kosong → aman memakai 09:00 |
| Penyinkron | Memasang jadwal, melaporkan jumlah, **menyusun ulang setelah pelunasan** (jadwal pindah ke periode Oktober), dan **tidak melempar** saat layanan gagal (dilaporkan sebagai `galat`) |
| FR-11 aksi | "Sudah bayar" menandai lunas + periode maju; "Tunda 1 jam" menjadwalkan ulang +1 jam; "Buka aplikasi" tidak mengubah data; tagihan tak dikenal & payload rusak ditolak dengan pesan |

### 3.2 Uji UI — `test/f3_pengingat_ui_test.dart` (9 uji)
Layar nyata 420×900 dengan layanan notifikasi palsu: status izin & jadwal tampil,
4 tombol aksi bekerja (izin diminta, notifikasi uji 10 detik dijadwalkan, jadwal
tersegarkan), pintu masuk dari Pengaturan bekerja, dan logika panduan merek
dikenali (Xiaomi/OPPO/Samsung/Vivo/Huawei) dengan fallback panduan umum.

### 3.3 Tangkapan layar
`demo/f3_pengingat.png` — layar "Pengingat & izin" (1.260×2.700 px, 1.381 warna unik,
383.217 B), dibuat dengan merender aplikasi sungguhan pada ukuran ponsel.

---

## 4. Bug nyata yang ditemukan saat F3 (dan perbaikannya)

1. **PALING PENTING — notifikasi lama bisa menandai lunas periode yang salah.**
   Payload notifikasi mula-mula hanya membawa ID tagihan. Kalau pengguna menekan
   "✓ Sudah bayar" pada notifikasi yang sudah lama (tagihan sudah berganti periode),
   sistem akan menandai lunas **periode berikutnya** dan riwayat pembayaran
   bertambah dua kali — tagihan bisa "hilang" sebulan.
   *Perbaikan:* payload kini membawa **periode jatuh tempo** yang dirujuk; aksi
   dengan periode tidak cocok akan ditolak dengan pesan "periode … sudah dibayar;
   periode aktif sekarang …". Dikunci oleh uji
   "PENTING: notifikasi lama tidak menandai lunas periode berikutnya".

2. **Pengingat bisa gagal total di isolate latar karena format tanggal Indonesia.**
   `DateFormat(..., 'id_ID')` butuh `initializeDateFormatting`, yang dijalankan
   `main()`. Pekerja latar Workmanager dan aksi notifikasi berjalan di isolate
   terpisah yang **tidak** menjalankan `main()` → notifikasi bisa error
   `LocaleDataException` (gagal terjadwal).
   *Perbaikan:* format tanggal Indonesia tanpa data locale (`fmtTanggalAman`)
   untuk semua teks notifikasi **plus** pemanggilan `initializeDateFormatting`
   di tiap jalur latar. Ditemukan uji FR-10 sebelum menyentuh HP.

3. **Anti-annoyance FR-12 salah arah: yang dibuang justru pengingat terdekat.**
   Saat lead lebih dari 7, kode lama memotong dari depan daftar (H-60, H-30…)
   sehingga **Hari-H dan H-1 yang paling penting justru terbuang**.
   *Perbaikan:* yang dibuang adalah lead terjauh. Dikunci uji FR-12.

4. **Jadwal bisa menggantung selamanya bila plugin berkas tidak menjawab.**
   Pencatatan jejak memakai `path_provider`; bila plugin tidak menjawab, proses
   sinkronisasi berhenti di tengah — jadwal terpasang sebagian dan tombol
   "Segarkan jadwal" tidak memberi kabar. Ditemukan oleh uji UI (tombol ditekan,
   jadwal terpasang, tapi pesan tidak muncul).
   *Perbaikan:* batas waktu 2 detik + penentu berkas yang bisa diganti; alur
   notifikasi tidak lagi bergantung pada keberhasilan menulis jejak.

5. **XML manifest rusak akibat suntingan saya sendiri** (atribut `android:name`
   dan `android:icon` ganda) → manifest tidak bisa diparse.
   *Perbaikan:* dideduplikasi dan **diverifikasi dengan parser XML** (valid, 70 baris).

6. **Panduan Huawei/Honor hanya 2 langkah** (< syarat 3 langkah).
   *Perbaikan:* ditambah 2 langkah (konsumsi daya & mengunci aplikasi di daftar tugas).

7. **Build APK gagal karena daemon Gradle dibunuh sistem (kehabisan memori).**
   `android/gradle.properties` bawaan memakai `-Xmx8G`; mesin build ini hanya punya
   ~12 GB RAM dengan 4,4 GB tersedia → daemon hilang di tengah build
   ("Gradle build daemon disappeared unexpectedly") setelah 9 menit.
   *Perbaikan:* `-Xmx3G`, `MaxMetaspaceSize=1G`, `kotlin.daemon.jvmargs=-Xmx1536m`,
   `org.gradle.workers.max=2`, `org.gradle.parallel=false` → build selesai 6 menit.
   Catatan: setelan ini saya naikkan lagi bila Anda memakai mesin build ber-RAM besar.

---

## 4b. Bukti konfigurasi Android (dibaca langsung dari APK)

Manifest gabungan **di dalam APK** diperiksa isinya (bukan hanya berkas sumbernya):

| Yang diperiksa | Hasil |
|---|---|
| Izin `POST_NOTIFICATIONS` | ADA |
| Izin `SCHEDULE_EXACT_ALARM` | ADA |
| Izin `RECEIVE_BOOT_COMPLETED` | ADA |
| Izin `VIBRATE`, `WAKE_LOCK` | ADA |
| `ScheduledNotificationReceiver` | ADA |
| `ScheduledNotificationBootReceiver` | ADA |
| `ActionBroadcastReceiver` | ADA |
| Nama aplikasi "Personal Life OS" | ADA |
| Java desugaring (syarat plugin notifikasi) | aktif — build selesai tanpa galat desugaring |

**Peringatan jujur dari build:** Flutter menandai `flutter_timezone` dan
`workmanager_android` masih memakai Kotlin Gradle Plugin gaya lama. Build sekarang
**berhasil**, tetapi versi Flutter mendatang bisa menolaknya. Bila itu terjadi,
kedua paket perlu dinaikkan versinya (atau pekerja latar diganti). Saya catat di sini
supaya tidak menjadi kejutan di kemudian hari.

---

## 5. Yang belum saya lakukan (jujur)

1. **Gate ketepatan waktu di perangkat nyata belum diuji** (tidak ada HP/emulator di sini).
2. **FR-17 (pola pintar P2)** belum dibuat — menunggu persetujuan Anda setelah F3.
3. **Notifikasi WhatsApp/Telegram** (kanal `KanalPengingat` di data) belum disambungkan;
   F3 fokus pada notifikasi lokal HP sesuai FR-10…FR-16.
4. **`SCHEDULE_EXACT_ALARM`**: pada Android 12+ pengguna harus memberi izin
   "alarm & pengingat" agar notifikasi tepat waktu. Aplikasi otomatis memakai mode
   *inexact* (tidak presisi, tapi tetap jalan) bila izin belum diberikan; tombol
   "Minta izin alarm presisi" disediakan.
5. Jejak pengingat tersimpan di berkas aplikasi (belum ada layar berbagi jejak).

---

## 6. Cara menguji di HP Anda (5 menit)

1. Pasang `build/app/outputs/flutter-apk/app-debug.apk` (debug, ±171 MB).
2. Buka aplikasi → tab **Pengaturan** → **Pengingat & izin**.
3. Ketuk **Minta izin notifikasi** (dan **alarm presisi** bila muncul).
4. Ikuti panduan merek HP Anda (mis. Xiaomi: Autostart + Hemat baterai → tanpa batas).
5. Ketuk **Uji notifikasi (10 detik)**, lalu **kunci HP**. Notifikasi harus muncul
   dalam ~10 detik, lengkap dengan 3 tombol aksi.
6. Tambah tagihan dengan jatuh tempo **besok**, jam pengingat **2 menit dari sekarang**
   → tunggu; notifikasi "besok jatuh tempo" harus muncul tepat waktu.
7. Tekan **"✓ Sudah bayar"** dari notifikasi → buka aplikasi → tagihan harus sudah
   lunas dan periode berikutnya tercatat.

Mohon kabari hasil langkah 5–7 di HP Anda. Itulah bukti gate F3 yang sesungguhnya.

---

## 7. Permintaan keputusan

1. **Lanjut F4?** (sesuai PRD §11.3: pemasukan, dompet/akun, laporan bulanan)
2. **Uji di HP Anda dulu** sebelum lanjut, atau saya lanjut F4 sambil menunggu hasil uji?
3. Konfirmasi harga **Pro Rp 399.000/tahun** (masih menunggu keputusan Anda dari F1).
