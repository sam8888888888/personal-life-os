# HANDOVER — FONDASI NOTIFIKASI FR-63 & FR-87 — dari Aaron

**Kepada:** Dinda · **Dari:** Aaron Salahuddin
**Waktu:** 15 Sep 2026, 03:30 UTC (10:30 WIB / 11:30 MYT)
**Cabang serahan:** `v15-notifikasi-aaron` (lanjutan dari `v15-data-aaron`)
**Dasar:** `SISA_FITUR_PRD_v3_1.md` bagian 4 butir 3 ("FR-87 Adzan dan pengiriman otomatis FR-63: tunggu fondasi notifikasi Aaron") dan PRD MASTER v3.1 baris FR-63 & FR-87.

> Ringkas: **`lib/core/notifikasi/**` sudah dibuka untuk briefing pagi & pengingat
> sholat.** Kamu tidak perlu menyentuh berkas inti notifikasi; cukup menulis satu
> adaptor kecil (contoh lengkap di §2) lalu mendaftarkannya.

---

## 1. Yang sudah siap (dengan bukti)

| Hal | Hasil |
|---|---|
| Kanal notifikasi baru | `KanalNotifikasi.briefing` (`plo_briefing`) & `KanalNotifikasi.sholat` (`plo_sholat`) — kanal Android dibuat otomatis oleh `_buatKanal()` |
| Briefing pagi (FR-63) | `Pengingat` harian pada jam pilihan (bawaan **06:00**), **7 hari** ke depan sekaligus; isi memuat jumlah & total tagihan 7 hari ke depan |
| Pengingat sholat (FR-87) | `JadwalPengingatSholat` per waktu dengan mode **sebelum / tepat / sesudah** + `menitGeser` (0–120); **5 waktu × 7 hari** maksimum |
| Rentang ID aman | `idBriefingPagiKe(i)` = 1.999.000.010+i, `idSholatKe(i)` = 1.999.000.100+i (di atas `batasIdKhusus`, tidak pernah bentrok dengan ID tagihan — ada ujinya) |
| Saluran modul fitur | `SumberPengingatTambahan` + `RegistriSumberPengingat` (`lib/core/notifikasi/sumber_pengingat_tambahan.dart`) |
| Penyinkron | `PenyinkronPengingat.sinkron()` menggabungkan pengingat tagihan + sumber tambahan, mengurutkan, memasang, **lalu memverifikasi hasil nyata** (PB-09 tetap berlaku) |
| Pengaturan k-v | `PengaturanRepository.baca/simpan/hapusPengaturan/bacaTeks/bacaAngka/bacaSaklar` — tempat menyimpan saklar briefing & mode per waktu sholat |
| Uji | **17 uji baru** di `test/f4_pengingat_tambahan_test.dart`, `flutter analyze` **No issues found!** |

**Aturan yang saya tegakkan (jangan dilanggar saat menyambung):**

1. **Satu sumber gagal tidak menggagalkan yang lain.** Kalau adaptormu melempar
   galat, pengingat tagihan tetap terpasang; galatnya dilaporkan di
   `HasilSinkron.galatSumberTambahan` dan dicatat di jejak. Jangan menelan galat
   sendiri tanpa jejak.
2. **Isi notifikasi tidak menghakimi** (PRD §III-11): semua teks memakai
   "menurut hitungan aplikasi" dan "catat bila sudah Anda lakukan" — tidak ada
   "belum sholat", "gagal", "dosa". Ada ujinya.
3. **Tidak ada pengingat berulang.** Satu notifikasi per waktu per hari, dan
   yang waktunya sudah lewat tidak dijadwalkan (tidak ada banjir notifikasi).
4. **Jumlah dibatasi** (briefing 7 hari, sholat 7 hari) karena pekerja latar +
   sinkronisasi saat aplikasi dibuka menyegarkan jadwal. Menaikkan batas berarti
   ratusan alarm tertunda di sistem — jangan tanpa alasan kuat.

---

## 2. Cara pakai — satu adaptor, dua baris pendaftaran

**(a) Buat adaptor** di berkasmu sendiri, mis.
`lib/features/ibadah/sumber_pengingat_ibadah.dart`:

```dart
import '../../core/ibadah/model_sholat.dart';
import '../../core/ibadah/penghitung_sholat.dart';
import '../../core/ibadah/penyimpanan_jadwal.dart';
import '../../core/notifikasi/model_pengingat.dart';
import '../../core/notifikasi/perencana_pengingat.dart';
import '../../core/notifikasi/sumber_pengingat_tambahan.dart';
import '../../data/database/database.dart';
import '../../data/repository/pengaturan_repository.dart';

/// Menyiapkan pengingat briefing pagi (FR-63) & waktu sholat (FR-87).
class SumberPengingatIbadah implements SumberPengingatTambahan {
  static const _perencana = PerencanaPengingat(sertakanRingkasanMingguan: false);

  @override
  Future<List<Pengingat>> pengingatTambahan(DateTime sekarang) async {
    final db = AppDatabase(); // dibuka sendiri: aman di isolate pekerja latar
    try {
      final pengaturan = PengaturanRepository(db);
      return _perencana.rencanakan(
        tagihan: const [], // tagihan sudah diproses oleh penyinkron
        sekarang: sekarang,
        sertakanBriefingPagi: await pengaturan.bacaSaklar('briefing.pagi'),
        jamBriefingPagi:
            await pengaturan.bacaTeks('briefing.jam', jamBriefingBawaan),
        jadwalSholat: await _jadwalHariIni(sekarang, pengaturan),
      );
    } finally {
      await db.close();
    }
  }

  Future<List<JadwalPengingatSholat>> _jadwalHariIni(
      DateTime sekarang, PengaturanRepository pengaturan) async {
    if (!await pengaturan.bacaSaklar('sholat.pengingat.aktif')) return const [];

    final kota = daftarKotaIndonesia
        .firstWhere((k) => k.nama == await pengaturan.bacaTeks('sholat.kota', 'Jakarta'));
    final kode = await pengaturan.bacaTeks(
        'sholat.metode', MetodeHitungSholat.kemenag.kode);

    // Utamakan jadwal yang sudah tersimpan di perangkat (tahan offline);
    // kalau belum ada, hitung sendiri — fungsi yang sama dengan layarmu.
    final jadwal = (await PenyimpananJadwal().ambil(
          kota: kota,
          tanggal: sekarang,
          kodeMetode: kode,
          asharHanafi: false,
        )) ??
        hitungJadwal(
          kota: kota,
          tanggal: sekarang,
          metode: MetodeHitungSholat.dariKode(kode),
        );

    final hasil = <JadwalPengingatSholat>[];
    for (final waktu in WaktuSholat.wajibSaja) {
      final jam = jadwal.waktuLokalAtauNull(waktu);
      if (jam == null) continue;
      final mode = ModePengingatSholat.dariDb(
          await pengaturan.baca('sholat.${waktu.name}.mode'));
      hasil.add(JadwalPengingatSholat(
        nama: waktu.label,
        jam: '${jam.hour.toString().padLeft(2, '0')}:'
            '${jam.minute.toString().padLeft(2, '0')}',
        mode: mode,
        menitGeser: await pengaturan.bacaAngka(
            'sholat.${waktu.name}.geser',
            mode == ModePengingatSholat.sebelum ? 5 : 0),
      ));
    }
    return hasil;
  }
}
```

> Nama parameter `PenyimpananJadwal.ambil(...)` saya tulis sesuai bentuk yang
> saya baca di kodemu (kota, tanggal, kodeMetode, asharHanafi, koreksiMenit) —
> kalau ada yang beda, sesuaikan; bagian itu milikmu.

**(b) Daftarkan** (dua isolate — inilah satu-satunya bagian yang menyentuh berkas
inti, dan sudah saya sediakan tempatnya):

```dart
// 1. isolate utama — lib/main.dart
RegistriSumberPengingat.daftarkan(SumberPengingatIbadah());

// 2. isolate pekerja latar — lib/core/notifikasi/kerja_latar.dart
void daftarkanSumberPengingatLatar() {
  RegistriSumberPengingat.daftarkan(SumberPengingatIbadah());
}
```

**Kalau kamu tidak mau menyentuh dua berkas itu sama sekali:** tulis adaptornya
lalu bilang ke saya (lewat laporan/berkas), saya yang menyambungkan dua baris itu
di cabang saya dan menyerahkan ulang. Kalau tidak didaftarkan, pengingat tambahan
tetap berbunyi untuk jadwal yang sudah terpasang, tetapi tidak diperpanjang oleh
pekerja latar.

**Kunci pengaturan yang saya sarankan** (kamu bebas mengubah, ini hanya usulan
supaya layar & adaptor sepakat):

| Kunci | Isi |
|---|---|
| `briefing.pagi` | `true` / `false` — saklar briefing (FR-63 "bisa dimatikan") |
| `briefing.jam` | `HH:mm`, bawaan `06:00` |
| `sholat.pengingat.aktif` | `true` / `false` |
| `sholat.<waktu>.mode` | `sebelum` / `tepat` / `sesudah` (nama waktu = `WaktuSholat.name`, mis. `subuh`) |
| `sholat.<waktu>.geser` | menit geser (mis. `5`) |

---

## 3. Yang BELUM termasuk (jujur)

1. **Layar pengaturan** untuk saklar & mode: belum ada — itu bagianmu, di UI
   (V1.15 butir FR-63 & FR-87). Saya hanya menyediakan pembaca/penulis k-v-nya.
2. **Nada/suara adzan khusus** (pilihan suara/dering) belum saya pisahkan: notifikasi
   sholat sekarang memakai detail notifikasi yang sama dengan pengingat biasa.
   Kalau Papi mau suara adzan khusus, kirim berkas audionya + izin Papi, saya
   tambahkan kanal suara terpisah.
3. **Layar pratinjau pengingat** (`pengingat_screen`, F3) hanya menampilkan
   pengingat tagihan untuk sekarang; pengingat sholat/briefing muncul di daftar
   setelah disinkronkan tetapi layarnya belum dikelompokkan per jenis.
4. **Tidak bisa diverifikasi di server:** notifikasi benar-benar berbunyi saat
   aplikasi tertutup/HP di-reboot, dan apakah pekerja latar bisa membaca berkas
   jadwal sholat dari isolate latar. Dua hal itu **gate di HP Papi**.

---

## 4. Berkas yang menjadi milik bersama setelah gabung

| Berkas | Perlakuan |
|---|---|
| `lib/core/notifikasi/perencana_pengingat.dart` | milik bersama (tambah mode/aturan = tambah uji) |
| `lib/core/notifikasi/sumber_pengingat_tambahan.dart` | milik bersama (antarmuka + registri) |
| `lib/core/notifikasi/penyinkron_pengingat.dart` | milik bersama |
| `lib/core/notifikasi/kerja_latar.dart` | milik bersama — `daftarkanSumberPengingatLatar()` adalah tempatmu |
| `lib/data/repository/pengaturan_repository.dart` | milik bersama |
| `test/f4_pengingat_tambahan_test.dart` | milik bersama |

**Konstrain yang jangan dihapus:** rentang ID cadangan (`batasIdKhusus` ke atas)
dan pemisahan galat sumber tambahan dari keberhasilan sinkronisasi tagihan.

---

*Disusun oleh Aaron Salahuddin · 15 Sep 2026 · untuk Dinda — fondasi notifikasi V1.5.*
