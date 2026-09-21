/// Pengingat sisa obat (FR-107) — jembatan ke kerangka notifikasi.
///
/// **Kapan berbunyi.** Mengikuti PRD: H-5 dan H-1 sebelum perkiraan habis
/// (juga saat sudah habis). Dihitung dari sisa yang diisi pengguna dibagi dosis
/// per hari. Bila sisa belum diisi, tidak ada pengingat — aplikasi tidak
/// menebak.
///
/// **ID stabil.** Dihitung dari ID obat di atas [batasIdObat] (di atas
/// `batasIdKhusus`), jadi tidak pernah bentrok dengan pengingat tagihan/shokat/
/// dokumen. ID yang sama dipakai ulang → jadwal lama diganti, bukan menumpuk.
library;

import 'package:drift/drift.dart';

import '../../core/laporan/obat_habis.dart';
import '../../core/notifikasi/model_pengingat.dart';
import '../../core/notifikasi/perencana_pengingat.dart';
import '../../core/notifikasi/sumber_pengingat_tambahan.dart';
import '../../data/database/database.dart';

/// Cara membuka basis data (bisa diganti saat pengujian). Sengaja lokal —
/// modul ini tidak menumpang typedef modul lain.
typedef PembukaBasisObat = AppDatabase Function();

/// Batas ID pengingat obat (di atas batas dokumen: batasIdKhusus + 1000).
const int batasIdObat = batasIdKhusus + 3000000;
const int blokIdPerObat = 8;

/// Jam pengingat obat (waktu lokal).
const int jamPengingatObat = 8;

int idPengingatObat(int obatId) {
  final aman = obatId < 0 ? -obatId : obatId;
  return batasIdObat + (aman % 200000) * blokIdPerObat;
}

/// Data ringkas satu obat untuk perhitungan pengingat.
class BarisSisaObat {
  const BarisSisaObat({
    required this.obatId,
    required this.nama,
    required this.sisa,
    required this.dosisPerHari,
    required this.satuan,
  });

  final int obatId;
  final String nama;
  final int? sisa;
  final int dosisPerHari;
  final String satuan;
}

/// Susun pengingat sisa obat pada saat [sekarang] — **murni**.
List<Pengingat> pengingatObatUntuk(
  List<BarisSisaObat> daftar,
  DateTime sekarang, {
  int jamPengingat = jamPengingatObat,
  int hariKeBelakangMaks = 1,
}) {
  final hasil = <Pengingat>[];
  for (final o in daftar) {
    final hari = sisaHari(sisa: o.sisa, dosisPerHari: o.dosisPerHari);
    if (hari == null) continue;
    if (!perluDiingatkan(hari)) continue;

    final waktu = DateTime(
      sekarang.year,
      sekarang.month,
      sekarang.day,
      jamPengingat,
    );
    // Sudah lewat lebih dari sehari? Lewati — pengingat basi tidak berguna.
    if (sekarang.difference(waktu).inHours > 24 * hariKeBelakangMaks) continue;

    final habis = perkiraanHabis(
        sisa: o.sisa, dosisPerHari: o.dosisPerHari, dari: sekarang);
    hasil.add(Pengingat(
      id: idPengingatObat(o.obatId),
      tagihanId: 0,
      waktu: waktu,
      kanal: KanalNotifikasi.briefing,
      judul: hari <= 1
          ? 'Obat hampir habis: ${o.nama}'
          : 'Waktunya membeli obat: ${o.nama}',
      isi: '${kalimatSisa(
        namaObat: o.nama,
        sisa: o.sisa,
        dosisPerHari: o.dosisPerHari,
        satuan: o.satuan,
        sekarang: sekarang,
      )}${habis == null ? '' : ' Perkiraan habis ${tanggalAmanObat(habis)}.'} '
          'Buka aplikasi untuk memperbarui sisanya.',
    ));
  }
  hasil.sort((a, b) => a.waktu.compareTo(b.waktu));
  return hasil;
}

/// Sumber pengingat tambahan milik modul kesehatan (FR-107).
class SumberPengingatObat implements SumberPengingatTambahan {
  SumberPengingatObat({
    PembukaBasisObat? pembukaBasisData,
    this.tutupBasisData = true,
    this.jamPengingat = jamPengingatObat,
  }) : buka = pembukaBasisData ?? AppDatabase.new;

  final PembukaBasisObat buka;
  final bool tutupBasisData;
  final int jamPengingat;

  @override
  Future<List<Pengingat>> pengingatTambahan(DateTime sekarang) async {
    final AppDatabase db = buka();
    try {
      final obatAktif = await (db.select(db.obat)
            ..where((t) => t.aktif.equals(true)))
          .get();
      if (obatAktif.isEmpty) return const [];

      final baris = <BarisSisaObat>[];
      for (final o in obatAktif) {
        final jadwal = await (db.select(db.jadwalObat)
              ..where((t) => t.obatId.equals(o.id) & t.aktif.equals(true)))
            .get();
        baris.add(BarisSisaObat(
          obatId: o.id,
          nama: o.nama,
          sisa: o.sisa,
          dosisPerHari: dosisPerHari(o.jumlahPerMinum, jadwal.length),
          satuan: o.satuan,
        ));
      }
      return pengingatObatUntuk(baris, sekarang, jamPengingat: jamPengingat);
    } finally {
      if (tutupBasisData) await db.close();
    }
  }
}
