/// FR-77 - Berkas laporan bulanan: PDF siap bagikan + CSV siap dibuka di
/// aplikasi lembar kerja.
///
/// Berkas ini memakai paket `pdf` yang sudah ada di `pubspec.yaml`. Font yang
/// dipakai adalah font bawaan Helvetica - tidak ada aset font yang perlu
/// dibundel, jadi laporan tetap bisa dibuat di perangkat mana pun.
///
/// Catatan angka:
/// * Seluruh nominal masuk sebagai SEN (1 rupiah = 100 sen) dan ditampilkan
///   lewat `fmtRpDariSen` supaya simbol mata uang mengikuti pengaturan FR-67.
/// * Pada CSV, kolom `jumlah` ditulis apa adanya dalam SEN (bilangan bulat)
///   supaya bisa dihitung ulang di aplikasi lembar kerja tanpa pembulatan.
///   Satuannya dinyatakan pada blok ringkasan di bawah daftar transaksi.
///
/// Catatan kejujuran isi (dipakai di kepala & kaki PDF):
/// laporan ini disusun dari catatan yang diisi pengguna sendiri di aplikasi,
/// bukan dari mutasi rekening atau pihak ketiga.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/tanggal_utils.dart';
import '../utils/uang_utils.dart';
import 'ringkasan_bulanan.dart';

/// Kalimat kaki berkas: menyebut pembuatnya apa adanya.
const String catatanKakiLaporan = 'Dibuat otomatis oleh Personal Life OS.';

/// Kalimat pengingat asal angka - ditulis di PDF supaya pembaca tidak salah
/// sangka bahwa angkanya berasal dari bank atau pihak lain.
const String pengingatAsalAngka =
    'Angka pada laporan ini diambil dari catatan yang Anda isi sendiri di '
    'aplikasi Personal Life OS - bukan dari mutasi rekening atau pihak lain '
    'mana pun.';

/// Bangun berkas PDF laporan bulanan dari [r].
///
/// Hasilnya berupa byte PDF sah (diawali `%PDF-`), siap ditulis ke berkas
/// `.pdf`. [judul] adalah judul dokumen, [catatan] opsional ditambahkan pada
/// akhir isi (mis. catatan pengguna untuk bulan itu).
Future<Uint8List> bangunPdfLaporanBulanan(
  RingkasanBulanan r, {
  String judul = 'Laporan Bulanan',
  String? catatan,
}) async {
  final periode = namaBulanTahunId(r.bulan);
  final dokumen = pw.Document(
    title: '$judul - $periode',
    author: 'Personal Life OS',
    creator: 'Personal Life OS',
    subject: 'Ringkasan keuangan bulan $periode',
  );

  dokumen.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 42),
      theme: pw.ThemeData.withFont(),
      footer: (konteks) => _kakiHalaman(konteks),
      build: (konteks) => <pw.Widget>[
        pw.Text(
          judul,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Periode: $periode',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 14),
        _judulBagian('Ringkasan bulan'),
        _tabelRingkasan(r),
        pw.SizedBox(height: 8),
        pw.Text(
          r.teksRingkasan,
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 16),
        _judulBagian('Rincian per kategori'),
        if (r.rincianKategori.isEmpty)
          _teksKosong('Belum ada catatan transaksi pada bulan ini.')
        else
          _tabelKategori(r),
        pw.SizedBox(height: 16),
        _judulBagian('Lima pengeluaran terbesar'),
        if (r.limaPengeluaranTerbesar.isEmpty)
          _teksKosong('Belum ada catatan pengeluaran pada bulan ini.')
        else
          _tabelPengeluaranTerbesar(r),
        pw.SizedBox(height: 16),
        _judulBagian('Tagihan yang jatuh tempo'),
        _tabelTagihan(r),
        if (catatan != null && catatan.trim().isNotEmpty) ...<pw.Widget>[
          pw.SizedBox(height: 16),
          _judulBagian('Catatan'),
          pw.Text(catatan.trim(), style: const pw.TextStyle(fontSize: 10)),
        ],
        pw.SizedBox(height: 18),
        pw.Divider(color: PdfColors.grey400),
        pw.Text(
          pengingatAsalAngka,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    ),
  );

  return dokumen.save();
}

/// CSV laporan bulanan: satu baris per transaksi, lalu blok ringkasan.
///
/// Bentuk berkasnya:
/// * baris pertama - header `tanggal;kategori;jenis;jumlah;catatan`;
/// * baris berikutnya - satu transaksi per baris, pemisah `;`, tanda kutip
///   ganda di dalam isi di-escape menjadi `""` dan dibungkus tanda kutip;
/// * baris kosong, lalu blok ringkasan berbentuk `kunci;angka` yang didahului
///   baris penanda `#`.
String ringkasanKeCsv(RingkasanBulanan r) {
  final keluaran = StringBuffer();
  keluaran.write('tanggal;kategori;jenis;jumlah;catatan\n');
  for (final t in r.transaksi) {
    keluaran.write([
      _tanggalCsv(t.tanggal),
      t.kategori,
      t.jenis.nilaiDb,
      '${t.jumlahSen}',
      t.catatan ?? '',
    ].map(_selCsv).join(';'));
    keluaran.write('\n');
  }

  keluaran.write('\n');
  keluaran.write('# Blok ringkasan. Angka jumlah dalam sen (1 rupiah = 100 sen).\n');
  final barisRingkasan = <String, String>{
    'periode': kunciBulanLaporan(r.bulan),
    'nama_bulan': namaBulanTahunId(r.bulan),
    'total_pemasukan': '${r.totalPemasukanSen}',
    'total_pengeluaran': '${r.totalPengeluaranSen}',
    'selisih': '${r.selisihSen}',
    'jumlah_transaksi': '${r.jumlahTransaksi}',
    'jumlah_tagihan': '${r.jumlahTagihan}',
    'total_tagihan': '${r.totalTagihanSen}',
    'tagihan_lunas': '${r.jumlahTagihanLunas}',
    'tagihan_belum_lunas': '${r.jumlahTagihanBelumLunas}',
  };
  for (final e in barisRingkasan.entries) {
    keluaran.write('${_selCsv(e.key)};${_selCsv(e.value)}\n');
  }

  return keluaran.toString();
}

// ---------------------------------------------------------------------------
// Bagian dalam
// ---------------------------------------------------------------------------

pw.Widget _judulBagian(String teks) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        teks,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
    );

pw.Widget _teksKosong(String teks) =>
    pw.Text(teks, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700));

pw.Widget _tabelRingkasan(RingkasanBulanan r) => pw.TableHelper.fromTextArray(
      headers: const ['Keterangan', 'Angka'],
      data: [
        ['Pemasukan', fmtRpDariSen(r.totalPemasukanSen)],
        ['Pengeluaran', fmtRpDariSen(r.totalPengeluaranSen)],
        ['Selisih (pemasukan - pengeluaran)', fmtRpDariSen(r.selisihSen)],
        ['Jumlah transaksi', '${r.jumlahTransaksi} baris'],
        ['Jumlah tagihan jatuh tempo', '${r.jumlahTagihan} tagihan'],
        ['Total nominal tagihan', fmtRpDariSen(r.totalTagihanSen)],
        [
          'Tagihan sudah lunas',
          '${r.jumlahTagihanLunas} tagihan (${fmtRpDariSen(r.nominalTagihanLunasSen)})',
        ],
        [
          'Tagihan belum lunas',
          '${r.jumlahTagihanBelumLunas} tagihan '
              '(${fmtRpDariSen(r.nominalTagihanBelumLunasSen)})',
        ],
      ],
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      headerAlignment: pw.Alignment.centerLeft,
      headerAlignments: {
        1: pw.Alignment.centerRight,
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
      },
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    );

pw.Widget _tabelKategori(RingkasanBulanan r) => pw.TableHelper.fromTextArray(
      headers: const ['Kategori', 'Jenis', 'Jumlah', 'Baris'],
      data: [
        for (final k in r.rincianKategori)
          [k.nama, k.jenis.label, fmtRpDariSen(k.jumlahSen), '${k.jumlahTransaksi}'],
      ],
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      headerAlignment: pw.Alignment.centerLeft,
      headerAlignments: {
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    );

pw.Widget _tabelPengeluaranTerbesar(RingkasanBulanan r) =>
    pw.TableHelper.fromTextArray(
      headers: const ['Tanggal', 'Kategori', 'Jumlah', 'Catatan'],
      data: [
        for (final t in r.limaPengeluaranTerbesar)
          [
            fmtTanggalAman(t.tanggal),
            t.kategori,
            fmtRpDariSen(t.jumlahSen),
            t.catatan ?? '-',
          ],
      ],
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      headerAlignment: pw.Alignment.centerLeft,
      headerAlignments: {
        2: pw.Alignment.centerRight,
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerLeft,
      },
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    );

pw.Widget _tabelTagihan(RingkasanBulanan r) {
  if (r.tagihan.isEmpty) {
    return _teksKosong('Belum ada tagihan yang jatuh tempo pada bulan ini.');
  }
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        '${r.jumlahTagihan} tagihan, total ${fmtRpDariSen(r.totalTagihanSen)} - '
        '${r.jumlahTagihanLunas} sudah lunas, '
        '${r.jumlahTagihanBelumLunas} belum lunas.',
        style: const pw.TextStyle(fontSize: 10),
      ),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: const ['Tagihan', 'Jatuh tempo', 'Jumlah', 'Keadaan'],
        data: [
          for (final t in r.tagihan)
            [
              t.nama,
              fmtTanggalAman(t.jatuhTempo),
              fmtRpDariSen(t.jumlahSen),
              t.lunas ? 'sudah lunas' : 'belum lunas',
            ],
        ],
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 10),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        headerAlignment: pw.Alignment.centerLeft,
        headerAlignments: {
          2: pw.Alignment.centerRight,
        },
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerLeft,
        },
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      ),
    ],
  );
}

pw.Widget _kakiHalaman(pw.Context konteks) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.Text(
          '$catatanKakiLaporan Halaman ${konteks.pageNumber} dari '
          '${konteks.pagesCount}.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );

String _tanggalCsv(DateTime t) => '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

/// Amankan satu sel CSV: bungkus tanda kutip bila isinya memuat pemisah,
/// tanda kutip, atau ganti baris. Tanda kutip ganda di dalam isi digandakan.
String _selCsv(String isi) {
  final perluKutip = isi.contains(';') ||
      isi.contains('"') ||
      isi.contains('\n') ||
      isi.contains('\r');
  if (!perluKutip) return isi;
  return '"${isi.replaceAll('"', '""')}"';
}
