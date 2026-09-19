/// FR-70 — Deteksi langganan: duplikat, jarang dipakai, tarif naik.
///
/// Berkas ini **PURE** (tanpa I/O) dan hanya membaca data yang sudah ada:
/// * duplikat → nama yang sama setelah dinormalkan + siklus sama;
/// * tarif naik → nominal langganan lebih kecil daripada pembayaran terakhir
///   (tabel `riwayat_pembayaran`) atau nominal tagihan tertaut;
/// * jarang dipakai → `terakhirDipakaiPada` (atau tanggal mulai) sudah lewat
///   batas hari.
///
/// Nada bahasa mengikuti PRD III-11: menyebut keadaan apa adanya, tanpa
/// menyalahkan pengguna. Tidak ada tindakan otomatis — semua lewat tombol.
library;

import 'package:flutter/material.dart';

import '../../../core/utils/tanggal_utils.dart';
import '../../../core/utils/uang_utils.dart';
import '../../../data/database/database.dart';
import '../../../data/model/enums.dart';
import '../../../data/repository/langganan_repository.dart';

/// Jenis temuan FR-70.
enum JenisTemuanLangganan { duplikat, tarifNaik, jarangDipakai }

/// Satu temuan siap tampil.
class TemuanLangganan {
  const TemuanLangganan({
    required this.jenis,
    required this.baris,
    required this.ringkas,
    this.totalBulananSen,
    this.nominalAcuanSen,
    this.naikPersen,
    this.hariSejakDipakai,
  });

  final JenisTemuanLangganan jenis;
  final List<LanggananData> baris;
  final String ringkas;
  final int? totalBulananSen;
  final int? nominalAcuanSen;
  final int? naikPersen;
  final int? hariSejakDipakai;

  /// Kunci stabil untuk widget/uji.
  String get kunci => '${jenis.name}_${baris.map((b) => b.id).join('_')}';
}

/// Nama dinormalkan: huruf kecil, tanpa tanda baca/spasi.
///
/// "Netflix " dan "netflix+" dianggap sama pada tahap deteksi — pengguna tetap
/// yang memutuskan, aplikasi hanya menunjukkan.
String normalisasiNamaLangganan(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Deteksi seluruh temuan FR-70.
///
/// [pembayaranTerakhirSen] dan [nominalTagihanSen] berkunci `tagihanId`.
/// [batasJarangHari] bawaan 60 hari, [batasNaikPersen] bawaan 5% — dua angka
/// ini sengaja menjadi parameter supaya bisa diuji dengan angka nyata.
List<TemuanLangganan> deteksiLangganan({
  required Iterable<LanggananData> daftar,
  required DateTime sekarang,
  Map<int, int> pembayaranTerakhirSen = const <int, int>{},
  Map<int, int> nominalTagihanSen = const <int, int>{},
  int batasJarangHari = 60,
  int batasNaikPersen = 5,
}) {
  final aktif = daftar
      .where((l) => StatusLangganan.dariDb(l.status) == StatusLangganan.aktif)
      .toList();
  final hasil = <TemuanLangganan>[];

  // 1. Duplikat: nama sama (setelah dinormalkan) + siklus sama.
  final grup = <String, List<LanggananData>>{};
  for (final l in aktif) {
    grup
        .putIfAbsent(
            '${normalisasiNamaLangganan(l.nama)}|${l.siklus}', () => <LanggananData>[])
        .add(l);
  }
  for (final baris in grup.values) {
    if (baris.length < 2) continue;
    final total = baris.fold<int>(
        0, (a, l) => a + LanggananRepository.nominalBulananSen(l));
    hasil.add(TemuanLangganan(
      jenis: JenisTemuanLangganan.duplikat,
      baris: baris,
      totalBulananSen: total,
      ringkas: '${baris.length} langganan aktif dengan nama hampir sama '
          '(${baris.map((b) => b.nama).join(', ')}) — setara '
          '${fmtRpDariSen(total)} per bulan. Periksa apakah salah satunya '
          'perlu dihentikan.',
    ));
  }

  // 2. Tarif naik: acuan bukti terbaru (pembayaran terakhir, lalu tagihan).
  for (final l in aktif) {
    final tagihanId = l.tagihanId;
    if (tagihanId == null || l.nominalSen <= 0) continue;
    final acuan = pembayaranTerakhirSen[tagihanId] ?? nominalTagihanSen[tagihanId];
    if (acuan == null || acuan <= l.nominalSen) continue;
    final persen = ((acuan - l.nominalSen) * 100 / l.nominalSen).round();
    if (persen < batasNaikPersen) continue;
    hasil.add(TemuanLangganan(
      jenis: JenisTemuanLangganan.tarifNaik,
      baris: <LanggananData>[l],
      nominalAcuanSen: acuan,
      naikPersen: persen,
      ringkas: '"${l.nama}" tercatat ${fmtRpDariSen(l.nominalSen)}, tetapi '
          'bukti terakhir yang ada ${fmtRpDariSen(acuan)} (naik $persen%). '
          'Tarif mungkin sudah berubah.',
    ));
  }

  // 3. Jarang dipakai: patokan `terakhirDipakaiPada`, atau tanggal mulai.
  for (final l in aktif) {
    final patokan = l.terakhirDipakaiPada ?? l.tanggalMulai;
    final hari = selisihHari(patokan, sekarang);
    if (hari < batasJarangHari) continue;
    hasil.add(TemuanLangganan(
      jenis: JenisTemuanLangganan.jarangDipakai,
      baris: <LanggananData>[l],
      hariSejakDipakai: hari,
      ringkas: l.terakhirDipakaiPada == null
          ? '"${l.nama}" belum pernah ditandai dipakai sejak '
              '${fmtTanggalId(l.tanggalMulai)} ($hari hari lalu).'
          : '"${l.nama}" terakhir ditandai dipakai '
              '${fmtTanggalId(l.terakhirDipakaiPada!)} ($hari hari lalu).',
    ));
  }

  return hasil;
}

/// Panel "Perhatian langganan" (FR-70).
///
/// Hanya menampilkan temuan + dua tombol nyata; tidak ada perubahan data yang
/// berjalan sendiri.
class PanelPerhatianLangganan extends StatelessWidget {
  const PanelPerhatianLangganan({
    super.key,
    required this.temuan,
    required this.onTandaiDipakai,
    required this.onSesuaikanNominal,
  });

  final List<TemuanLangganan> temuan;
  final void Function(LanggananData) onTandaiDipakai;
  final void Function(LanggananData, int) onSesuaikanNominal;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      key: const Key('panel_perhatian'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Perhatian langganan', style: tema.textTheme.titleMedium),
            Text('${temuan.length} hal yang mungkin perlu dilihat'),
            const SizedBox(height: 6),
            for (final t in temuan)
              Padding(
                key: Key('temuan_${t.kunci}'),
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.ringkas),
                    if (t.jenis == JenisTemuanLangganan.jarangDipakai)
                      TextButton.icon(
                        key: Key('tandai_dipakai_${t.baris.first.id}'),
                        onPressed: () => onTandaiDipakai(t.baris.first),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Masih dipakai'),
                      ),
                    if (t.jenis == JenisTemuanLangganan.tarifNaik)
                      TextButton.icon(
                        key: Key('sesuaikan_nominal_${t.baris.first.id}'),
                        onPressed: () => onSesuaikanNominal(
                            t.baris.first, t.nominalAcuanSen ?? 0),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Sesuaikan nominal'),
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
