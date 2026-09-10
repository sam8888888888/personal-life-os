/// Template tagihan lokal Indonesia (FR-05) — untuk isi cepat saat pertama pakai.
library;

import 'package:drift/drift.dart';

import '../../core/utils/tanggal_utils.dart';
import '../database/database.dart';
import '../model/enums.dart';
import 'package:drift/drift.dart' show Value;

/// Satu baris template siap pakai.
class TemplateTagihan {
  const TemplateTagihan({
    required this.nama,
    required this.perkiraanSen,
    required this.frekuensi,
    required this.leadHari,
    this.catatan,
  });

  final String nama;
  final int perkiraanSen;
  final Frekuensi frekuensi;
  final List<int> leadHari;
  final String? catatan;
}

/// Daftar template bawaan — perkiraan nominal khas rumah tangga Indonesia.
const daftarTemplate = <TemplateTagihan>[
  TemplateTagihan(
      nama: 'Listrik PLN',
      perkiraanSen: 30000000, // Rp 300.000
      frekuensi: Frekuensi.bulanan,
      leadHari: [7, 3, 1],
      catatan: 'Token/listrik pascabayar'),
  TemplateTagihan(
      nama: 'Air PDAM', perkiraanSen: 12000000, frekuensi: Frekuensi.bulanan, leadHari: [5, 1]),
  TemplateTagihan(
      nama: 'Internet rumah', perkiraanSen: 35000000, frekuensi: Frekuensi.bulanan, leadHari: [7, 1]),
  TemplateTagihan(
      nama: 'BPJS Kesehatan',
      perkiraanSen: 15000000,
      frekuensi: Frekuensi.bulanan,
      leadHari: [10, 3, 1],
      catatan: 'Jatuh tempo tiap tanggal 15'),
  TemplateTagihan(
      nama: 'Langganan streaming', perkiraanSen: 5400000, frekuensi: Frekuensi.bulanan, leadHari: [3]),
  TemplateTagihan(
      nama: 'Cicilan motor',
      perkiraanSen: 85000000,
      frekuensi: Frekuensi.bulanan,
      leadHari: [7, 3, 1],
      catatan: 'Cek tanggal jatuh tempo di kontrak'),
  TemplateTagihan(
      nama: 'Pajak kendaraan (STNK)',
      perkiraanSen: 2500000,
      frekuensi: Frekuensi.tahunan,
      leadHari: [60, 30, 14, 7, 1],
      catatan: 'Pengingat jauh hari karena wajib perpanjangan'),
];

/// Tambah beberapa template sekaligus ke database.
/// [tanggalAwal] menentukan jatuh tempo pertama; tiap tagihan digeser
/// 1 hari agar kalender demo terlihat beragam.
extension TemplateSeederExtension on AppDatabase {
  Future<int> isiDariTemplate(List<TemplateTagihan> template,
      {DateTime? tanggalAwal}) async {
    final awal = tanggalAwal ?? DateTime.now();
    var n = 0;
    for (final (i, t) in template.indexed) {
      final jatuhTempo = tambahBulan(DateTime(awal.year, awal.month, awal.day), 0)
          .add(Duration(days: i));
      await into(tagihan).insert(TagihanCompanion.insert(
        nama: t.nama,
        jumlahSen: Value(t.perkiraanSen),
        jatuhTempo: jatuhTempo,
        frekuensi: Value(t.frekuensi.nilaiDb),
        kustomHariN: const Value(null),
        pengingatLeadHari: Value(leadKeTeks(t.leadHari)),
        catatan: Value(t.catatan),
        kanalPengingat: Value(KanalPengingat.push.nilaiDb),
      ));
      n++;
    }
    return n;
  }
}
