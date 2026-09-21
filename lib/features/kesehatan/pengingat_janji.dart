/// Pengingat janji dokter (FR-109) — jembatan ke kerangka notifikasi.
///
/// Memakai [waktuPengingatJanji] (7 hari, 1 hari, 2 jam sebelum) dan ID stabil
/// di atas [batasIdJanji]. Janji yang sudah ditandai selesai tidak diingatkan
/// lagi; pengingatnya dibatalkan pada sinkronisasi berikutnya karena
/// [PenyinkronPengingat] menyingkirkan jadwal yang tidak lagi diminta.
library;

import 'package:drift/drift.dart' show OrderingTerm;

import '../../core/laporan/janji.dart';
import '../../core/notifikasi/model_pengingat.dart';
import '../../core/notifikasi/perencana_pengingat.dart';
import '../../core/notifikasi/sumber_pengingat_tambahan.dart';
import '../../data/database/database.dart';

/// Cara membuka basis data (bisa diganti saat pengujian).
typedef PembukaBasisJanji = AppDatabase Function();

/// Batas ID pengingat janji (di atas batas obat: batasIdKhusus + 3000000).
const int batasIdJanji = batasIdKhusus + 4000000;
const int blokIdPerJanji = maksSlotPengingatJanji;

int idPengingatJanji(int janjiId, int slot) {
  final aman = janjiId < 0 ? -janjiId : janjiId;
  final bagian = slot.clamp(0, blokIdPerJanji - 1);
  return batasIdJanji + (aman % 200000) * blokIdPerJanji + bagian;
}

/// Susun pengingat untuk daftar janji pada saat [sekarang] — **murni**.
///
/// Pengingat yang waktunya masih jauh (> 30 hari) tidak dibuat supaya jadwal
/// notifikasi tidak penuh oleh janji yang masih lama.
List<Pengingat> pengingatJanjiUntuk(
  List<JanjiKesehatanData> daftar,
  DateTime sekarang, {
  int hariKeDepanMaks = 30,
}) {
  final hasil = <Pengingat>[];
  for (final j in daftar) {
    if (j.selesai) continue;
    if (j.waktu.isBefore(sekarang)) continue;
    if (j.waktu.difference(sekarang).inDays > hariKeDepanMaks) continue;

    final waktu = waktuPengingatJanji(
      j.waktu,
      leadHari: j.pengingatHari,
      duaJam: j.ingatkanDuaJam,
      jamPengingat: j.jamPengingat,
    );
    for (var slot = 0; slot < waktu.length; slot++) {
      if (slot >= blokIdPerJanji) break;
      final w = waktu[slot];
      if (w.isBefore(sekarang.subtract(const Duration(hours: 1)))) continue;
      hasil.add(Pengingat(
        id: idPengingatJanji(j.id, slot),
        tagihanId: 0,
        waktu: w,
        kanal: KanalNotifikasi.briefing,
        judul: '${labelJenisJanji(j.jenis)}: ${j.judul}',
        isi: kalimatPengingatJanji(
          judul: j.judul,
          jenis: j.jenis,
          waktuJanji: j.waktu,
          waktuPengingat: w,
          tempat: j.tempat,
        ),
      ));
    }
  }
  hasil.sort((a, b) => a.waktu.compareTo(b.waktu));
  return hasil;
}

/// Sumber pengingat tambahan milik modul kesehatan (FR-109).
class SumberPengingatJanji implements SumberPengingatTambahan {
  SumberPengingatJanji({
    PembukaBasisJanji? pembukaBasisData,
    this.tutupBasisData = true,
    this.hariKeDepanMaks = 30,
  }) : buka = pembukaBasisData ?? AppDatabase.new;

  final PembukaBasisJanji buka;
  final bool tutupBasisData;
  final int hariKeDepanMaks;

  @override
  Future<List<Pengingat>> pengingatTambahan(DateTime sekarang) async {
    final AppDatabase db = buka();
    try {
      final daftar = await (db.select(db.janjiKesehatan)
            ..where((t) => t.selesai.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.waktu)]))
          .get();
      return pengingatJanjiUntuk(daftar, sekarang,
          hariKeDepanMaks: hariKeDepanMaks);
    } finally {
      if (tutupBasisData) await db.close();
    }
  }
}
