/// FR-134 — pengingat keberangkatan (H-7, H-1, H-0) sebagai sumber pengingat
/// tambahan, mengikuti pola `SumberPengingatPerawatan`.
///
/// WAJIB didaftarkan di DUA tempat: `main.dart` (isolate utama) dan
/// `kerja_latar.dart` (`daftarkanSumberPengingatLatar`) — isolate latar tidak
/// mewarisi variabel statis, lupa salah satu = pengingat berhenti tanpa galat.
library;

import 'package:drift/drift.dart';

import '../../core/notifikasi/model_pengingat.dart';
import '../../core/notifikasi/perencana_pengingat.dart';
import '../../core/notifikasi/sumber_pengingat_tambahan.dart';
import '../../core/perjalanan/perjalanan.dart';
import '../../data/database/database.dart';

typedef PembukaBasisPerjalanan = AppDatabase Function();

/// Rentang ID khusus pengingat perjalanan (`id*10 + slot`) — tidak bertabrakan
/// dengan tagihan, briefing, sholat, maupun pengingat rumah tangga.
const int idDasarPengingatPerjalanan = batasIdKhusus + 200000;

/// Batas jumlah alarm: perjalanan yang berangkat lebih jauh dari ini tidak
/// dijadwalkan sekaligus (menghindari ratusan alarm tertunda ditolak sistem).
const int hariPerjalananKeDepan = 30;
const int jamPengingatPerjalanan = 8;

class SumberPengingatPerjalanan implements SumberPengingatTambahan {
  SumberPengingatPerjalanan({
    PembukaBasisPerjalanan? pembukaBasisData,
    this.tutupBasisData = true,
    this.hariKeDepan = hariPerjalananKeDepan,
  }) : buka = pembukaBasisData ?? AppDatabase.new;

  final PembukaBasisPerjalanan buka;
  final bool tutupBasisData;
  final int hariKeDepan;

  @override
  Future<List<Pengingat>> pengingatTambahan(DateTime sekarang) async {
    final AppDatabase db = buka();
    try {
      final daftar = await (db.select(db.perjalanan)
            ..where((p) => p.arsip.equals(false))
            ..orderBy([(p) => OrderingTerm.asc(p.mulai)]))
          .get();
      return pengingatPerjalananUntuk(
        daftar,
        sekarang,
        hariKeDepan: hariKeDepan,
      );
    } finally {
      if (tutupBasisData) await db.close();
    }
  }
}

/// Susun pengingat keberangkatan untuk daftar perjalanan (fungsi murni — bisa
/// diuji tanpa notifikasi Android).
List<Pengingat> pengingatPerjalananUntuk(
  List<PerjalananData> daftar,
  DateTime sekarang, {
  int hariKeDepan = hariPerjalananKeDepan,
}) {
  final hasil = <Pengingat>[];
  for (final p in daftar) {
    final sisaHari = p.mulai
        .difference(DateTime(sekarang.year, sekarang.month, sekarang.day))
        .inDays;
    if (sisaHari > hariKeDepan) continue;
    final waktu = jadwalPengingatKeberangkatan(
      p.mulai,
      sekarang: sekarang,
      leadHari: const [7, 1, 0],
    );
    for (var i = 0; i < waktu.length; i++) {
      final beda = DateTime(p.mulai.year, p.mulai.month, p.mulai.day)
          .difference(DateTime(
              waktu[i].year, waktu[i].month, waktu[i].day))
          .inDays;
      hasil.add(Pengingat(
        id: idDasarPengingatPerjalanan + p.id * 10 + i,
        tagihanId: 0,
        waktu: waktu[i],
        kanal: KanalNotifikasi.ringkasan,
        judul: 'Keberangkatan: ${p.nama}',
        isi: beda <= 0
            ? 'Hari ini berangkat ke ${p.tujuan}. Cek tiket, dokumen, dan bawaan.'
            : 'H-$beda menuju ${p.tujuan}. Siapkan tiket, dokumen, dan bawaan.',
      ));
    }
  }
  hasil.sort((a, b) => a.waktu.compareTo(b.waktu));
  return hasil;
}

/// Daftarkan sumber pengingat perjalanan (isolate utama & latar).
void daftarkanSumberPengingatPerjalanan() {
  RegistriSumberPengingat.daftarkan(SumberPengingatPerjalanan());
}
