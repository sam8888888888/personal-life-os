/// FR-54 — pengingat minum obat/suplemen sebagai sumber pengingat tambahan.
///
/// Memakai ULANG modul obat FR-106 (`obat`, `jadwal_obat`, `minum_obat`) dan
/// hanya menambah: (1) saklar izin, (2) penjadwalan pemberitahuan.
///
/// WAJIB didaftarkan di DUA tempat pada `kerja_latar.dart`
/// (`daftarkanSumberPengingatLatar` dan `daftarkanSumberPengingatUtama`) —
/// kalau salah satu lupa, pengingat berhenti tanpa galat.
library;

import 'package:drift/drift.dart';

import '../../core/kesehatan/rencana_obat.dart';
import '../../core/notifikasi/model_pengingat.dart';
import '../../core/notifikasi/perencana_pengingat.dart';
import '../../core/notifikasi/sumber_pengingat_tambahan.dart';
import '../../data/database/database.dart';
import '../../data/repository/obat_repository.dart';
import '../../data/repository/pengaturan_repository.dart';

typedef PembukaBasisObat = AppDatabase Function();

/// Kunci saklar izin di tabel `pengaturan` (bukan tabel baru).
const String kunciIzinPengingatObat = 'kesehatan.izinPengingatObat';

/// Rentang ID notifikasi obat (lihat `rencana_obat.dart` → [idPengingatObat]).
const int idDasarPengingatJadwalObat = batasIdKhusus + 300000;

/// Berapa lama ke depan alarm disiapkan sekali jalan.
const Duration jendelaPengingatObat = Duration(hours: 24);

/// Baca/simpan izin pengingat obat — bawaan MATI (opsional, hormat pengguna).
class IzinPengingatObat {
  const IzinPengingatObat(this.db);

  final AppDatabase db;

  Future<bool> baca() =>
      PengaturanRepository(db).bacaSaklar(kunciIzinPengingatObat, bawaan: false);

  Future<void> simpan(bool menyala) =>
      PengaturanRepository(db).simpan(kunciIzinPengingatObat, menyala ? '1' : '0');
}

/// Sumber pengingat obat untuk pekerja notifikasi.
class SumberPengingatJadwalObat implements SumberPengingatTambahan {
  SumberPengingatJadwalObat({
    PembukaBasisObat? pembukaBasisData,
    this.tutupBasisData = true,
    this.jendela = jendelaPengingatObat,
  }) : buka = pembukaBasisData ?? AppDatabase.new;

  final PembukaBasisObat buka;
  final bool tutupBasisData;
  final Duration jendela;

  @override
  Future<List<Pengingat>> pengingatTambahan(DateTime sekarang) async {
    final AppDatabase db = buka();
    try {
      if (!await IzinPengingatObat(db).baca()) return const [];
      final daftar = await ObatRepository(db).jadwalRingkas();
      if (daftar.isEmpty) return const [];
      final slot = slotMendatang(daftar, sekarang, jendela: jendela);
      if (slot.isEmpty) return const [];
      final tercatat = await _kunciSudahDicatat(db, sekarang, jendela);
      final ringkas = ringkasPengingatObat(slot, sekarang,
          sudahDicatat: tercatat);
      final urutanPerObat = <int, int>{};
      final hasil = <Pengingat>[];
      for (final s in ringkas.slot) {
        final urutan = urutanPerObat[s.obatId] ?? 0;
        urutanPerObat[s.obatId] = urutan + 1;
        final teks = teksPengingatObat(s);
        hasil.add(Pengingat(
          id: idPengingatObat(idDasarPengingatJadwalObat, s.obatId, urutan),
          tagihanId: 0,
          waktu: s.waktu,
          kanal: KanalNotifikasi.ringkasan,
          judul: teks.judul,
          isi: teks.isi,
        ));
      }
      return hasil;
    } finally {
      if (tutupBasisData) await db.close();
    }
  }
}

/// Slot yang SUDAH punya catatan minum (jangan diingatkan dua kali).
Future<Set<String>> _kunciSudahDicatat(
  AppDatabase db,
  DateTime sekarang,
  Duration jendela,
) async {
  final catatan = await (db.select(db.minumObat)
        ..where((m) =>
            m.waktuRencana.isBiggerOrEqualValue(sekarang.subtract(jendela)) &
            m.waktuRencana.isSmallerThanValue(sekarang.add(jendela))))
      .get();
  return {
    for (final c in catatan)
      '${c.obatId}@${c.waktuRencana.toIso8601String().substring(0, 16)}',
  };
}

/// Daftarkan sumber pengingat obat (isolate utama & latar).
void daftarkanSumberPengingatJadwalObat() {
  RegistriSumberPengingat.daftarkan(SumberPengingatJadwalObat());
}
