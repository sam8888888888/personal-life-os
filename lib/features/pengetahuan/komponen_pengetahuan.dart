/// Komponen bersama layar modul Pengetahuan (FR-118…FR-123).
///
/// Kecil & sengaja sederhana: kartu kosong yang jujur, kartu ringkas, baris
/// kunci–nilai, lencana, dan dialog konfirmasi hapus. Dipakai semua layar
/// pengetahuan supaya tampilannya seragam.
library;

import 'package:flutter/material.dart';

/// Kartu "belum ada data" — menjelaskan keadaan apa adanya, bukan menilai.
Widget kartuKosong(String pesan, {String? petunjuk}) => Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pesan, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (petunjuk != null) ...[
              const SizedBox(height: 6),
              Text(petunjuk),
            ],
          ],
        ),
      ),
    );

/// Kartu ringkas berjudul.
Widget kartuRingkas(String judul, List<Widget> isi) => Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(judul, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...isi,
          ],
        ),
      ),
    );

/// Baris "kunci: nilai".
Widget barisKunciNilai(String kunci, String nilai) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 132, child: Text(kunci)),
          Expanded(
            child: Text(nilai, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

/// Lencana kecil untuk kategori/topik.
Widget lencana(String teks) => Container(
      margin: const EdgeInsets.only(right: 6, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(teks, style: const TextStyle(fontSize: 12)),
    );

/// Dialog konfirmasi hapus (tegas, menyebut apa yang dihapus).
Future<bool> konfirmasiHapus(BuildContext c, String apa) async {
  final hasil = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: const Text('Hapus?'),
      content: Text('$apa akan dihapus dari perangkat ini.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('konfirmasi_hapus'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  return hasil ?? false;
}

/// Bidang teks standar layar pengetahuan.
Widget bidangTeks({
  required TextEditingController pengendali,
  required String label,
  int baris = 1,
  String? petunjuk,
  TextInputType? jenisPapanKetik,
}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: pengendali,
        minLines: baris,
        maxLines: baris == 1 ? 1 : null,
        keyboardType: jenisPapanKetik,
        decoration: InputDecoration(
          labelText: label,
          helperText: petunjuk,
          border: const OutlineInputBorder(),
        ),
      ),
    );

/// Pemilih sederhana dari daftar pilihan (chip).
Widget pemilihChip({
  required List<String> pilihan,
  required String terpilih,
  required ValueChanged<String> onPilih,
  String label = '',
  /// Awalan kunci widget; dipakai supaya beberapa pemilih pada satu layar tetap
  /// bisa dibedakan (dan diuji) tanpa kunci yang bertabrakan.
  String kunci = 'pilih',
}) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in pilihan)
              ChoiceChip(
                key: Key('${kunci}_$p'),
                label: Text(p),
                selected: p == terpilih,
                onSelected: (_) => onPilih(p),
              ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
