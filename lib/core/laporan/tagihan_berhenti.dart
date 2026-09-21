/// FR-46 (bagian kedua) — Deteksi tagihan yang "berhenti muncul".
///
/// Duplikat langganan sudah ditangani FR-70 (`deteksi_langganan.dart`). Berkas
/// ini menutup separuh lainnya: tagihan berulang yang dulu dibayar rutin, lalu
/// tidak muncul lagi catatannya — biasanya tanda langganannya sudah dihentikan,
/// jadi pengingatnya perlu dimatikan (bukan tagihannya dihapus).
library;

import 'package:flutter/material.dart';

import '../../data/database/database.dart';
import '../../data/model/enums.dart';
import '../utils/tanggal_utils.dart';

/// Sebab sebuah tagihan dianggap berhenti muncul.
enum SebabBerhenti {
  /// Belum pernah ada catatan pembayaran padahal siklusnya sudah lewat.
  belumPernahDibayar,

  /// Dulu rutin dibayar, sekarang tidak ada catatan beberapa siklus.
  terputus,
}

/// Satu temuan tagihan berhenti muncul, lengkap dengan buktinya.
class TagihanBerhenti {
  const TagihanBerhenti({
    required this.tagihanId,
    required this.nama,
    required this.panjangSiklusHari,
    required this.jumlahPembayaran,
    required this.siklusTerlewat,
    required this.sebab,
    this.terakhirDibayar,
  });

  final int tagihanId;
  final String nama;
  final int panjangSiklusHari;
  final int jumlahPembayaran;
  final int siklusTerlewat;
  final SebabBerhenti sebab;
  final DateTime? terakhirDibayar;

  /// Kalimat bukti (dipakai di layar; tanpa kata menghakimi).
  String get ringkas => sebab == SebabBerhenti.belumPernahDibayar
      ? 'Belum pernah ada catatan pembayaran, padahal siklusnya sudah lewat '
          '$siklusTerlewat kali (tiap $panjangSiklusHari hari).'
      : 'Terakhir dibayar ${fmtTanggalId(terakhirDibayar!)} — sudah '
          '$siklusTerlewat siklus tanpa catatan baru.';

  String get nilaiPenting => '$jumlahPembayaran pembayaran tercatat';
}

/// Panjang satu siklus tagihan (hari), minimal 1.
int panjangSiklusHari(TagihanData t) {
  final f = Frekuensi.dariDb(t.frekuensi);
  final berikut = periodeBerikutnya(t.jatuhTempo, f, kustomHariN: t.kustomHariN);
  final selisih = berikut.difference(t.jatuhTempo).inDays;
  return selisih < 1 ? 1 : selisih;
}

/// Cari tagihan berulang yang catatan pembayarannya berhenti.
///
/// [riwayat] = catatan pembayaran (id tagihan + tanggal bayar). [ambangSiklus]
/// bawaan 2: baru dianggap berhenti setelah dua siklus tanpa catatan — supaya
/// tagihan yang cuma telat sekali tidak langsung dicurigai.
List<TagihanBerhenti> deteksiTagihanBerhenti({
  required List<TagihanData> tagihan,
  required List<({int tagihanId, DateTime tanggalBayar})> riwayat,
  required DateTime sekarang,
  int ambangSiklus = 2,
}) {
  final terakhir = <int, DateTime>{};
  final jumlah = <int, int>{};
  for (final r in riwayat) {
    jumlah[r.tagihanId] = (jumlah[r.tagihanId] ?? 0) + 1;
    final lama = terakhir[r.tagihanId];
    if (lama == null || r.tanggalBayar.isAfter(lama)) {
      terakhir[r.tagihanId] = r.tanggalBayar;
    }
  }

  final hasil = <TagihanBerhenti>[];
  for (final t in tagihan) {
    if (!t.statusAktif || t.lunas) continue;
    final f = Frekuensi.dariDb(t.frekuensi);
    if (!f.berulang) continue;
    final panjang = panjangSiklusHari(t);
    final bayarTerakhir = terakhir[t.id];

    if (bayarTerakhir == null) {
      final lewat = sekarang.difference(t.jatuhTempo).inDays;
      if (lewat <= ambangSiklus * panjang) continue;
      final siklus = lewat ~/ panjang;
      if (siklus < ambangSiklus) continue;
      hasil.add(TagihanBerhenti(
        tagihanId: t.id,
        nama: t.nama,
        panjangSiklusHari: panjang,
        jumlahPembayaran: 0,
        siklusTerlewat: siklus,
        sebab: SebabBerhenti.belumPernahDibayar,
      ));
      continue;
    }

    final jarak = sekarang.difference(bayarTerakhir).inDays;
    final siklus = jarak ~/ panjang;
    if (siklus < ambangSiklus) continue;
    hasil.add(TagihanBerhenti(
      tagihanId: t.id,
      nama: t.nama,
      panjangSiklusHari: panjang,
      jumlahPembayaran: jumlah[t.id] ?? 0,
      siklusTerlewat: siklus,
      sebab: SebabBerhenti.terputus,
      terakhirDibayar: bayarTerakhir,
    ));
  }

  hasil.sort((a, b) => b.siklusTerlewat.compareTo(a.siklusTerlewat));
  return hasil;
}

/// Panel ringkas untuk layar Langganan (sebelah panel duplikat FR-70).
class PanelTagihanBerhenti extends StatelessWidget {
  const PanelTagihanBerhenti({
    super.key,
    required this.daftar,
    this.onMatikanPengingat,
  });

  final List<TagihanBerhenti> daftar;

  /// Nonaktifkan pengingat tagihan (tagihannya tidak dihapus).
  final Future<void> Function(int tagihanId)? onMatikanPengingat;

  @override
  Widget build(BuildContext context) {
    if (daftar.isEmpty) return const SizedBox.shrink();
    final tema = Theme.of(context);
    return Card(
      key: const Key('panel_tagihan_berhenti'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tagihan yang berhenti muncul',
                style: tema.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Tagihan ini dulu berulang, tapi catatan pembayarannya sudah '
              'lama tidak muncul. Kalau langganannya memang sudah berhenti, '
              'pengingatnya bisa dimatikan — datanya tetap tersimpan.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final t in daftar)
              Padding(
                key: Key('berhenti_${t.tagihanId}'),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.nama, style: tema.textTheme.bodyLarge),
                    Text('${t.ringkas} · ${t.nilaiPenting}',
                        style: tema.textTheme.bodySmall),
                    if (onMatikanPengingat != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: Key('matikan_pengingat_${t.tagihanId}'),
                          onPressed: () => onMatikanPengingat!(t.tagihanId),
                          child: const Text('Matikan pengingatnya'),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
