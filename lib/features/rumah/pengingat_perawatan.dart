/// Pengingat perawatan aset (FR-125) & garansi aset (FR-126).
///
/// Modul ini **tidak** menyentuh mesin penjadwalan milik modul tagihan: ia
/// hanya menyerahkan daftar [Pengingat] lewat [SumberPengingatTambahan], pola
/// yang sama dengan pengingat dokumen (FR-129) dan ibadah (FR-63/87).
///
/// ID notifikasi memakai rentang cadangan `batasIdKhusus + 200 + i` supaya
/// tidak pernah bentrok dengan tagihan (`(tagihanId % 10^7) * 100 + slot`),
/// briefing (`+10`), sholat (`+100`), atau dokumen (`+150`).
library;

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/foundation.dart';

import '../../core/notifikasi/model_pengingat.dart';
import '../../core/notifikasi/perencana_pengingat.dart';
import '../../core/notifikasi/sumber_pengingat_tambahan.dart';
import '../../data/database/database.dart';

/// Jam pengingat perawatan (pagi, sebelum aktivitas).
const int jamPengingatPerawatan = 8;

/// Berapa hari ke depan perawatan dipasang pengingatnya.
const int hariPerawatanKeDepan = 30;

/// Selisih hari kalender [dari] → [ke].
int selisihHariRumah(DateTime dari, DateTime ke) {
  final a = DateTime(dari.year, dari.month, dari.day);
  final b = DateTime(ke.year, ke.month, ke.day);
  return b.difference(a).inDays;
}

/// ID notifikasi untuk butir perawatan ke-[i] (rentang cadangan +200).
int idPerawatanKe(int i) => batasIdKhusus + 200 + i;

/// Susun pengingat perawatan dari daftar jadwal.
///
/// [namaAset] memetakan `perawatan.aset_id` → nama aset (opsional; jadwal yang
/// tidak terikat aset tetap jalan). Fungsi ini **murni** (tidak menulis apa
/// pun) supaya bisa diuji langsung dan aman dipanggil tiap sinkronisasi.
List<Pengingat> pengingatPerawatanUntuk(
  List<PerawatanData> daftar,
  DateTime sekarang, {
  Map<int, String> namaAset = const {},
  int jamPengingat = jamPengingatPerawatan,
  int hariKeDepan = hariPerawatanKeDepan,
}) {
  final hasil = <Pengingat>[];
  var urutan = 0;
  for (final p in daftar) {
    final sisa = selisihHariRumah(sekarang, p.berikutnya);
    if (sisa > hariKeDepan) continue;
    var waktu =
        DateTime(p.berikutnya.year, p.berikutnya.month, p.berikutnya.day)
            .add(Duration(hours: jamPengingat));
    final terlambat = waktu.isBefore(sekarang);
    if (terlambat) {
      // Jadwal yang sudah lewat tetap diingatkan (sekali), bukan dibuang:
      // dipasang beberapa menit dari sekarang supaya pasti berbunyi.
      waktu = sekarang.add(const Duration(minutes: 2));
    }
    final namaBaik = (p.nama).trim();
    final aset = p.asetId == null ? null : namaAset[p.asetId];
    hasil.add(Pengingat(
      id: idPerawatanKe(urutan),
      tagihanId: 0,
      waktu: waktu,
      kanal: KanalNotifikasi.tagihan,
      judul: aset == null ? 'Perawatan: $namaBaik' : 'Perawatan $aset',
      isi: isiPengingatPerawatan(p, sekarang, namaAset: namaAset),
      hariSebelum: terlambat ? null : sisa,
      terlambat: terlambat,
    ));
    urutan++;
  }
  return hasil;
}

/// Kalimat isi notifikasi — menyebut angka apa adanya, tanpa menegur.
///
/// Memakai tanggal yang diformat lokal (tanpa locale) karena notifikasi bisa
/// disusun di isolate latar yang tidak menjalankan `main()`.
String isiPengingatPerawatan(
  PerawatanData p,
  DateTime sekarang, {
  Map<int, String> namaAset = const {},
}) {
  final sisa = selisihHariRumah(sekarang, p.berikutnya);
  final kapan = fmtTanggalRingkas(p.berikutnya);
  final aset = p.asetId == null ? null : namaAset[p.asetId];
  final bagian = StringBuffer();
  if (aset != null) bagian.write('$aset · ');
  bagian.write(p.nama);
  if (sisa > 0) {
    bagian.write(' dijadwalkan $kapan, $sisa hari lagi.');
  } else if (sisa == 0) {
    bagian.write(' dijadwalkan hari ini ($kapan).');
  } else {
    bagian.write(' sudah lewat ${-sisa} hari (jadwal $kapan).');
  }
  if (p.terakhirDilakukan != null) {
    bagian.write(' Terakhir dikerjakan '
        '${fmtTanggalRingkas(p.terakhirDilakukan!)}.');
  }
  bagian.write(' Buka aplikasi untuk menandai selesai.');
  return bagian.toString();
}

/// Tanggal ringkas tanpa locale, mis. "12 Jan 2026".
String fmtTanggalRingkas(DateTime d) {
  const bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${d.day} ${bulan[d.month - 1]} ${d.year}';
}

/// Cara membuka basis data (bisa diganti saat pengujian).
typedef PembukaBasisRumah = AppDatabase Function();

/// Sumber pengingat tambahan milik modul Rumah & Aset.
class SumberPengingatPerawatan implements SumberPengingatTambahan {
  SumberPengingatPerawatan({
    PembukaBasisRumah? pembukaBasisData,
    this.tutupBasisData = true,
    this.hariKeDepan = hariPerawatanKeDepan,
    this.jamPengingat = jamPengingatPerawatan,
  }) : buka = pembukaBasisData ?? AppDatabase.new;

  final PembukaBasisRumah buka;
  final bool tutupBasisData;
  final int hariKeDepan;
  final int jamPengingat;

  @override
  Future<List<Pengingat>> pengingatTambahan(DateTime sekarang) async {
    final AppDatabase db = buka();
    try {
      final daftar = await (db.select(db.perawatan)
            ..where((p) => p.aktif.equals(true))
            ..orderBy([(p) => OrderingTerm.asc(p.berikutnya)]))
          .get();
      final namaAset = <int, String>{};
      final aset = await (db.select(db.aset)..where((a) => a.arsip.equals(false)))
          .get();
      for (final a in aset) {
        namaAset[a.id] = a.nama;
      }
      return pengingatPerawatanUntuk(
        daftar,
        sekarang,
        namaAset: namaAset,
        jamPengingat: jamPengingat,
        hariKeDepan: hariKeDepan,
      );
    } finally {
      if (tutupBasisData) await db.close();
    }
  }
}

/// Daftarkan sumber pengingat perawatan.
///
/// WAJIB dipanggil di **dua** tempat: `main.dart` (isolate utama) dan
/// `kerja_latar.dart` (`daftarkanSumberPengingatLatar`) — isolate latar tidak
/// mewarisi variabel statis isolate utama, dan lupa salah satu membuat
/// pengingat berhenti diperpanjang tanpa galat apa pun.
void daftarkanSumberPengingatPerawatan() {
  RegistriSumberPengingat.daftarkan(SumberPengingatPerawatan());
}

/// Dipakai uji & layar: ambil jadwal perawatan yang jatuh tempo.
@visibleForTesting
Future<List<PerawatanData>> ambilPerawatanAktif(AppDatabase db) =>
    (db.select(db.perawatan)
          ..where((p) => p.aktif.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.berikutnya)]))
        .get();
