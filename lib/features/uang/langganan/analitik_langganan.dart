/// FR-69 — Subscription Intelligence (lanjutan FR-68).
///
/// Berkas ini **PURE** (tanpa I/O) supaya bisa diuji tanpa database, dan
/// sengaja tidak membuat rumus baru:
/// * nominal per bulan memakai [LanggananRepository.nominalBulananSen];
/// * tanggal jatuh tempo berikutnya memakai [tanggalBerikutnya] dan
///   [periodeBerikutnya] dari mesin tagihan.
///
/// Yang ditambahkan di sini (kriteria FR-69 yang belum ada):
/// total per tahun, lima langganan terbesar, dan proyeksi 12 bulan.
library;

import 'package:flutter/material.dart';

import '../../../core/utils/tanggal_utils.dart';
import '../../../core/utils/uang_utils.dart';
import '../../../data/database/database.dart';
import '../../../data/model/enums.dart';
import '../../../data/repository/langganan_repository.dart';
// `tanggalBerikutnya` tinggal di layar (dipakai juga oleh uji lama); impor
// melingkar ini disengaja supaya aturannya hanya hidup di satu tempat.
import 'langganan_screen.dart' show tanggalBerikutnya;

/// Satu baris proyeksi bulanan.
class ProyeksiBulan {
  const ProyeksiBulan({
    required this.bulan,
    required this.totalSen,
    required this.jumlah,
  });

  /// Awal bulan (tanggal 1) yang diwakili baris ini.
  final DateTime bulan;

  /// Jumlah nominal yang jatuh tempo pada bulan itu (sen).
  final int totalSen;

  /// Berapa langganan yang jatuh tempo pada bulan itu.
  final int jumlah;
}

/// Satu baris peringkat "terbesar".
class LanggananTerbesar {
  const LanggananTerbesar({required this.langganan, required this.bulananSen});

  final LanggananData langganan;
  final int bulananSen;
}

/// Hasil analitik langganan (FR-69).
class RingkasanLangganan {
  const RingkasanLangganan({
    required this.totalBulananSen,
    required this.jumlahAktif,
    required this.limaTerbesar,
    required this.proyeksi12Bulan,
  });

  final int totalBulananSen;
  final int jumlahAktif;
  final List<LanggananTerbesar> limaTerbesar;
  final List<ProyeksiBulan> proyeksi12Bulan;

  /// Perkiraan biaya setahun bila semuanya jalan terus (sen).
  int get totalTahunanSen => totalBulananSen * 12;
}

/// Hitung analitik FR-69 dari daftar langganan.
///
/// Aturan mengikat: hanya baris **aktif** yang dihitung (pause & berhenti tidak
/// menagih). Proyeksi memakai siklus tercatat apa adanya, jadi angka tahunan
/// tidak dilebih-lebihkan.
RingkasanLangganan hitungRingkasanLangganan(
  Iterable<LanggananData> daftar,
  DateTime sekarang, {
  int bulanProyeksi = 12,
}) {
  final aktif = daftar
      .where((l) => StatusLangganan.dariDb(l.status) == StatusLangganan.aktif)
      .toList();

  final totalBulanan = aktif.fold<int>(
      0, (a, l) => a + LanggananRepository.nominalBulananSen(l));

  final terbesar = aktif
      .map((l) => LanggananTerbesar(
          langganan: l,
          bulananSen: LanggananRepository.nominalBulananSen(l)))
      .where((e) => e.bulananSen > 0)
      .toList()
    ..sort((a, b) => b.bulananSen.compareTo(a.bulananSen));

  final awal = DateTime(sekarang.year, sekarang.month, 1);
  final batas = DateTime(awal.year, awal.month + bulanProyeksi, 1);
  final ember = <DateTime, List<int>>{};
  for (var i = 0; i < bulanProyeksi; i++) {
    ember[DateTime(awal.year, awal.month + i, 1)] = <int>[];
  }

  for (final l in aktif) {
    final f = Frekuensi.dariDb(l.siklus);
    if (f == Frekuensi.sekali) {
      final kunci = DateTime(l.tanggalMulai.year, l.tanggalMulai.month, 1);
      ember[kunci]?.add(l.nominalSen);
      continue;
    }
    var t = tanggalBerikutnya(l, sekarang);
    var langkah = 0;
    while (t != null && t.isBefore(batas) && langkah < 400) {
      ember[DateTime(t.year, t.month, 1)]?.add(l.nominalSen);
      final berikut = periodeBerikutnya(t, f);
      if (!berikut.isAfter(t)) break; // pengaman: jangan berputar
      t = berikut;
      langkah++;
    }
  }

  final proyeksi = ember.entries
      .map((e) => ProyeksiBulan(
            bulan: e.key,
            totalSen: e.value.fold<int>(0, (a, b) => a + b),
            jumlah: e.value.length,
          ))
      .toList()
    ..sort((a, b) => a.bulan.compareTo(b.bulan));

  return RingkasanLangganan(
    totalBulananSen: totalBulanan,
    jumlahAktif: aktif.length,
    limaTerbesar: terbesar.take(5).toList(),
    proyeksi12Bulan: proyeksi,
  );
}

/// Kartu analitik langganan: total tahunan, lima terbesar, proyeksi 12 bulan.
class KartuAnalitikLangganan extends StatelessWidget {
  const KartuAnalitikLangganan({super.key, required this.ringkasan});

  final RingkasanLangganan ringkasan;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final terbesar = ringkasan.limaTerbesar;
    return Card(
      key: const Key('kartu_analitik'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analitik langganan', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Setara ${fmtRpDariSen(ringkasan.totalTahunanSen)} per tahun',
              key: const Key('analitik_total_tahunan'),
              style: tema.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text('Dari ${ringkasan.jumlahAktif} langganan aktif. Bila semuanya '
                'jalan terus selama 12 bulan.'),
            const SizedBox(height: 8),
            Text('Lima langganan terbesar', style: tema.textTheme.labelLarge),
            if (terbesar.isEmpty)
              const Text('Perkiraan belum tersedia: tidak ada langganan aktif.')
            else
              for (var i = 0; i < terbesar.length; i++)
                Padding(
                  key: Key('terbesar_${terbesar[i].langganan.id}'),
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('${i + 1}. ${terbesar[i].langganan.nama} — '
                      '${fmtRpDariSen(terbesar[i].bulananSen)} per bulan'),
                ),
            ExpansionTile(
              key: const Key('analitik_proyeksi'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('Proyeksi 12 bulan'),
              subtitle: Text('Total yang jatuh tempo tiap bulan '
                  '(${ringkasan.proyeksi12Bulan.length} bulan)'),
              children: [
                for (final p in ringkasan.proyeksi12Bulan)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      key: Key('proyeksi_${p.bulan.year}-'
                          '${p.bulan.month.toString().padLeft(2, '0')}'),
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(p.jumlah == 0
                          ? '${fmtBulanPendekId(p.bulan)} · tidak ada jatuh tempo'
                          : '${fmtBulanPendekId(p.bulan)} · '
                              '${fmtRpDariSen(p.totalSen)} '
                              '(${p.jumlah} jatuh tempo)'),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Angka proyeksi memakai siklus yang tercatat; siklus '
                    'mingguan dan tahunan tidak dibulatkan diam-diam.',
                    style: tema.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
