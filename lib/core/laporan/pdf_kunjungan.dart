/// FR-115 — PDF satu halaman untuk kunjungan dokter.
///
/// Angka di PDF diambil dari [RingkasanKunjungan] yang sama dengan yang tampil
/// di layar, jadi "angka identik dengan data aplikasi" (kriteria terima PRD).
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../kesehatan/ringkasan_kunjungan.dart';
import '../utils/tanggal_utils.dart';

/// Bangun PDF 1 halaman.
Future<Uint8List> bangunPdfKunjungan(
  RingkasanKunjungan r, {
  String? catatanPengguna,
  DateTime? dicetak,
}) async {
  final dokumen = pw.Document(
    title: 'Ringkasan kunjungan',
    author: 'Personal Life OS',
    creator: 'Personal Life OS',
  );
  final waktu = dicetak ?? DateTime.now();
  dokumen.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
      theme: pw.ThemeData.withFont(),
      build: (konteks) => <pw.Widget>[
        pw.Text('Ringkasan untuk kunjungan dokter',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(
          'Catatan ${r.hari} hari: ${fmtTanggalPendekAman(r.dari)} – '
          '${fmtTanggalPendekAman(r.sampai)} · '
          'dicetak ${fmtTanggalPendekAman(waktu)}',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Ringkasan ini dibuat aplikasi dari catatan pribadi, bukan hasil '
          'pemeriksaan dan bukan diagnosis.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: const ['Bagian', 'Ringkasan', 'Jumlah catatan'],
          headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 10),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(2),
          },
          data: [
            for (final b in r.baris) [b.label, b.nilai, b.catatan],
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('Keluhan yang pernah dicatat',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        if (r.keluhan.isEmpty)
          pw.Text('Tidak ada keluhan yang dicatat pada periode ini.',
              style: const pw.TextStyle(fontSize: 10))
        else
          ...r.keluhan
              .take(12)
              .map((k) => pw.Bullet(
                    text: k,
                    style: const pw.TextStyle(fontSize: 10),
                  )),
        if (catatanPengguna != null && catatanPengguna.trim().isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('Catatan tambahan',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(catatanPengguna.trim(),
              style: const pw.TextStyle(fontSize: 10)),
        ],
        pw.SizedBox(height: 18),
        pw.Divider(color: PdfColors.grey400),
        pw.Text(
          'Sumber: catatan pribadi di Personal Life OS — bukan rekam medis '
          'resmi, bukan diagnosis.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    ),
  );
  return dokumen.save();
}
