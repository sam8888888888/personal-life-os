/// FR-145 — PDF laporan bulanan (signature), bisa dibagikan.
///
/// Isi PDF diambil dari [LaporanHidupBulanan] yang sama dengan yang tampil di
/// layar — jadi tidak ada dua versi angka.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'laporan_hidup_bulanan.dart';

/// Bangun PDF laporan bulanan.
Future<Uint8List> bangunPdfLaporanHidup(
  LaporanHidupBulanan l, {
  DateTime? dicetak,
}) async {
  final dokumen = pw.Document(
    title: 'Laporan bulanan ${l.label}',
    author: 'Personal Life OS',
    creator: 'Personal Life OS',
  );
  final waktu = dicetak ?? DateTime.now();
  dokumen.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
      theme: pw.ThemeData.withFont(),
      footer: (konteks) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Halaman ${konteks.pageNumber} dari ${konteks.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (konteks) => <pw.Widget>[
        pw.Text('Laporan bulanan — ${l.label}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(
          'Periode ${_tgl(l.dari)} – ${_tgl(l.sampai)} · '
          'dibuat ${_tgl(waktu)}',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Seluruh angka dihitung dari catatan pribadi di aplikasi, bukan '
          'perkiraan dan bukan nasihat keuangan.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 14),
        for (final bagian in l.bagian) ...[
          pw.Text(bagian.judul.toUpperCase(),
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: const ['Bagian', 'Nilai', 'Sumber angka'],
            headerStyle:
                pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
            },
            data: [
              for (final b in bagian.baris) [b.label, b.nilai, b.sumber],
            ],
          ),
          pw.SizedBox(height: 12),
        ],
        _bagianDaftar('Yang membaik', l.membaik),
        _bagianDaftar('Yang berubah', l.berubah),
        _bagianDaftar('Yang perlu perhatian', l.perluPerhatian),
      ],
    ),
  );
  return dokumen.save();
}

pw.Widget _bagianDaftar(String judul, List<String> isi) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(judul.toUpperCase(),
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        for (final x in isi) pw.Bullet(text: x, style: const pw.TextStyle(fontSize: 10)),
        if (isi.isEmpty)
          pw.Text('belum ada yang bisa dibandingkan',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
      ],
    );

String _tgl(DateTime t) =>
    '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
