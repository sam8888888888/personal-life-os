/// Pengingat berlapis masa berlaku dokumen (FR-129).
///
/// **Bentuknya.** Kerangka notifikasi (`lib/core/notifikasi/**`) hanya tahu
/// tagihan. Modul dokumen menyerahkan pengingatnya lewat antarmuka
/// [SumberPengingatTambahan] — berkas ini satu-satunya jembatannya, dan
/// berkas kerangka itu TIDAK diubah.
///
/// **Aturan yang dilayani.** Satu dokumen menyimpan lead hari berlapis
/// ("90,30,7,1"). Untuk setiap lead hari yang jatuh **hari ini** (atau sudah
/// lewat paling banyak [hariKeBelakangMaks] hari) dibuat satu pengingat.
/// Lead yang jauh di belakang tidak lagi dibuat: pengingat yang datang
/// terlambat hanya membingungkan, sedangkan lead berikutnya yang lebih dekat
/// sudah mengambil alih.
///
/// **ID stabil.** ID notifikasi dihitung dari ID baris dokumen + slot lead
/// (lihat `idPengingatDokumen` di `dokumen_repository.dart`), selalu di atas
/// `batasIdKhusus` (1999000000) sehingga tidak pernah bentrok dengan pengingat
/// tagihan. ID yang sama dipakai berulang kali → jadwal yang sudah terpasang
/// diganti, bukan menumpuk.
///
/// **Payload aman.** `tagihanId` diisi 0 dan `periode` kosong. Dengan begitu
/// notifikasi dokumen tidak menawarkan tombol "Sudah bayar" (PB-16) dan tidak
/// bisa mengubah data tagihan.
///
/// **Batas jujur.** Isi berkas dokumen tidak pernah dibaca (tidak ada
/// enkripsi di proyek ini), jadi pengingat hanya menyebut nama & tanggal.
/// Notifikasi tidak diperpanjang melewati [hariKeBelakangMaks] hari, sehingga
/// HP yang lama tidak dibuka bisa melewatkan satu lead — lead berikutnya
/// masih terpasang karena sinkronisasi berjalan tiap aplikasi dibuka dan oleh
/// pekerja latar.
library;

import '../../core/notifikasi/model_pengingat.dart';
import '../../core/notifikasi/sumber_pengingat_tambahan.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/dokumen_repository.dart';

/// Berapa hari ke belakang pengingat yang sudah lewat masih dibuat.
const int hariKeBelakangBawaan = 3;

/// Jam pengingat dokumen (waktu lokal). Notifikasi dokumen tidak punya kolom
/// jam sendiri di skema, jadi dipakai satu jam yang sama untuk semua dokumen.
const int jamPengingatDokumen = 8;

/// Cara membuka basis data (bisa diganti saat pengujian).
typedef PembukaBasisDokumen = AppDatabase Function();

/// Bangun pengingat dari [daftar] dokumen pada saat [sekarang] — **murni**.
///
/// Dokumen yang tidak diingatkan dikembalikan tanpa pengingat bila:
/// `aktif == false`, `arsip == true`, atau `berlaku_sampai` kosong.
List<Pengingat> pengingatDokumenUntuk(
  List<DokumenData> daftar,
  DateTime sekarang, {
  int hariKeBelakangMaks = hariKeBelakangBawaan,
  int jamPengingat = jamPengingatDokumen,
}) {
  final batas = hariKeBelakangMaks < 0 ? 0 : hariKeBelakangMaks;
  final hasil = <Pengingat>[];
  for (final d in daftar) {
    if (!d.aktif || d.arsip) continue;
    final akhir = d.berlakuSampai;
    if (akhir == null) continue;
    final lead = DokumenRepository.leadDokumen(d);
    if (lead.isEmpty) continue;
    // `lead` urut menurun; ambil ekornya supaya yang dibuang adalah lead
    // terjauh, bukan lead terdekat yang paling berguna.
    final dipakai = lead.length > maksLeadPerDokumen
        ? lead.sublist(lead.length - maksLeadPerDokumen)
        : lead;
    for (var slot = 0; slot < dipakai.length; slot++) {
      final leadHari = dipakai[slot];
      final waktu =
          DokumenRepository.waktuPengingat(akhir, leadHari, jam: jamPengingat);
      final jarak = selisihHari(sekarang, waktu); // > 0 = belum waktunya
      if (jarak > 0) continue;
      if (-jarak > batas) continue;
      hasil.add(Pengingat(
        id: idPengingatDokumen(d.id, slot),
        tagihanId: 0,
        waktu: waktu,
        // Tidak ada kanal khusus dokumen di kerangka notifikasi (berkas itu
        // milik modul lain), jadi dipakai kanal pengingat tenggat yang sudah
        // ada: "Pengingat H-x sebelum jatuh tempo".
        kanal: KanalNotifikasi.tagihan,
        judul: 'Masa berlaku: ${d.nama}',
        isi: isiPengingatDokumen(d, leadHari, waktu, sekarang),
      ));
    }
  }
  hasil.sort((a, b) => a.waktu.compareTo(b.waktu));
  return hasil;
}

/// Kalimat isi notifikasi — menyebut keadaan apa adanya, tanpa menegur.
///
/// Memakai [fmtTanggalAman] (tanpa data locale) karena notifikasi bisa disusun
/// di isolate latar yang tidak menjalankan `main()`.
String isiPengingatDokumen(
  DokumenData d,
  int leadHari,
  DateTime waktuPengingat,
  DateTime sekarang,
) {
  final akhir = d.berlakuSampai;
  final sisa = akhir == null ? null : selisihHari(sekarang, akhir);
  final kapan = akhir == null ? '-' : fmtTanggalAman(akhir);
  final bagian = StringBuffer('Pengingat H-$leadHari. ');
  if (sisa == null) {
    bagian.write('Masa berlaku ${d.nama} sampai $kapan.');
  } else if (sisa > 0) {
    bagian.write(
        'Masa berlaku ${d.nama} berakhir $kapan, tersisa $sisa hari lagi.');
  } else if (sisa == 0) {
    bagian.write('Masa berlaku ${d.nama} berakhir hari ini ($kapan).');
  } else {
    bagian.write(
        'Masa berlaku ${d.nama} sudah lewat ${-sisa} hari (berakhir $kapan).');
  }
  if (d.pemilik != null && d.pemilik!.isNotEmpty) {
    bagian.write(' Pemilik: ${d.pemilik}.');
  }
  bagian.write(' Buka aplikasi untuk melihat catatannya.');
  return bagian.toString();
}

/// Sumber pengingat tambahan milik modul dokumen (FR-129).
class SumberPengingatDokumen implements SumberPengingatTambahan {
  SumberPengingatDokumen({
    PembukaBasisDokumen? pembukaBasisData,
    this.tutupBasisData = true,
    this.hariKeBelakangMaks = hariKeBelakangBawaan,
    this.jamPengingat = jamPengingatDokumen,
  }) : buka = pembukaBasisData ?? AppDatabase.new;

  /// Cara membuka basis data (bawaan: aplikasi).
  final PembukaBasisDokumen buka;

  /// Tutup basis data setelah dipakai (pekerja latar: ya; pengujian: tidak).
  final bool tutupBasisData;

  final int hariKeBelakangMaks;
  final int jamPengingat;

  @override
  Future<List<Pengingat>> pengingatTambahan(DateTime sekarang) async {
    final AppDatabase db = buka();
    try {
      final daftar = await DokumenRepository(db).ambilUntukPengingat();
      return pengingatDokumenUntuk(
        daftar,
        sekarang,
        hariKeBelakangMaks: hariKeBelakangMaks,
        jamPengingat: jamPengingat,
      );
    } finally {
      if (tutupBasisData) await db.close();
    }
  }
}

/// Daftarkan sumber pengingat dokumen ke registri aplikasi.
///
/// Dipanggil Dinda di `main.dart` (isolate utama) dan di
/// `kerja_latar.dart` (pekerja latar) — dua-duanya perlu, karena isolate latar
/// tidak mewarisi variabel statis isolate utama:
///
/// ```dart
/// daftarkanSumberPengingatDokumen();
/// ```
///
/// Aman dipanggil berulang: registri mengenali jenis yang sama.
void daftarkanSumberPengingatDokumen() {
  RegistriSumberPengingat.daftarkan(SumberPengingatDokumen());
}
