/// FR-77 — Layar "Laporan Bulanan": ringkasan satu bulan + ekspor PDF & CSV.
///
/// Layar ini hanya MEMBACA data (transaksi, kategori, tagihan) dan menulis
/// berkas ke folder dokumen aplikasi. Tidak ada baris basis data yang diubah,
/// kecuali satu catatan audit (FR-138) setelah berkas benar-benar tersimpan.
///
/// Hal yang perlu diketahui pembaca kode:
/// * Layar ini punya Scaffold + AppBar sendiri, bukan dibungkus HalamanJudul.
/// * Waktu dibaca lewat `jamSekarang` (bawaan `waktuSekarang()`), tidak pernah
///   memanggil `DateTime.now()` langsung — supaya bisa diuji.
/// * Folder penyimpanan bisa disuntik lewat [folderLaporan]; bawaannya folder
///   dokumen aplikasi (`path_provider`). Uji widget memakai folder sementara.
/// * Nama berkas: `plo_laporan_YYYYMM.pdf` dan `plo_laporan_YYYYMM.csv`.
/// * Bulan tanpa catatan tetap boleh diekspor; PDF-nya berisi ringkasan
///   dengan angka nol dan kalimat jujur bahwa belum ada catatan — bukan berkas
///   kosong yang membuat bingung.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/audit/audit_log.dart';
import '../../core/laporan/pdf_laporan_bulanan.dart';
import '../../core/laporan/ringkasan_bulanan.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';
import '../../core/utils/waktu.dart';
import '../../data/model/enums.dart';
import '../../data/repository/laporan_bulanan_repository.dart';

/// Cara layar memperoleh folder penyimpanan laporan.
///
/// Disuntik lewat konstruktor supaya uji bisa memakai folder sementara, dan
/// supaya layar ini tidak bergantung pada kanal platform saat diuji.
typedef FolderLaporan = Future<Directory> Function();

/// Repositori laporan bulanan (hanya baca) untuk layar ini.
///
/// Sengaja diletakkan di berkas fitur — bukan di `lib/core/providers/` —
/// supaya berkas bersama tidak perlu disentuh saat modul ini bertambah.
final laporanBulananRepoProvider = Provider<LaporanBulananRepository>(
  (ref) => LaporanBulananRepository(ref.watch(databaseProvider)),
);

class LaporanBulananScreen extends ConsumerStatefulWidget {
  const LaporanBulananScreen({
    super.key,
    this.jamSekarang,
    this.folderLaporan,
  });

  /// Jam uji; bawaan waktu perangkat.
  final DateTime Function()? jamSekarang;

  /// Folder penyimpanan berkas; bawaan folder dokumen aplikasi.
  final FolderLaporan? folderLaporan;

  @override
  ConsumerState<LaporanBulananScreen> createState() =>
      LaporanBulananScreenState();
}

class LaporanBulananScreenState extends ConsumerState<LaporanBulananScreen> {
  /// Batas tunggu untuk setiap pembacaan berkas/sistem luar.
  static const Duration batasTunggu = Duration(seconds: 5);

  late DateTime bulan;
  RingkasanBulanan? ringkasan;
  bool memuat = true;
  String? galat;

  DateTime get sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  LaporanBulananRepository get repo => ref.read(laporanBulananRepoProvider);

  @override
  void initState() {
    super.initState();
    final kini = sekarang;
    bulan = DateTime(kini.year, kini.month, 1);
    muat();
  }

  /// Baca ulang ringkasan bulan yang sedang dipilih.
  Future<void> muat() async {
    setState(() {
      memuat = true;
      galat = null;
    });
    try {
      final hasil = await repo.bulan(bulan).timeout(batasTunggu);
      if (!mounted) return;
      setState(() {
        ringkasan = hasil;
        memuat = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        memuat = false;
        galat = 'Belum ada data — pembacaan bulan ini memakan waktu terlalu lama.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        memuat = false;
        galat = 'Belum ada data pada bulan ini.';
      });
    }
  }

  /// Geser bulan yang dilihat: -1 bulan sebelumnya, +1 bulan berikutnya.
  Future<void> geserBulan(int langkah) async {
    setState(() {
      bulan = DateTime(bulan.year, bulan.month + langkah, 1);
    });
    await muat();
  }

  // -------------------------------------------------------------------------
  // Ekspor
  // -------------------------------------------------------------------------

  /// Simpan laporan bulan yang sedang tampil sebagai PDF.
  Future<void> unduhPdf() => _simpanBerkas(pdf: true);

  /// Simpan laporan bulan yang sedang tampil sebagai CSV.
  Future<void> unduhCsv() => _simpanBerkas(pdf: false);

  Future<void> _simpanBerkas({required bool pdf}) async {
    final r = ringkasan;
    if (r == null) {
      pesan('Laporan bulan ini belum siap dibaca, jadi berkas belum dibuat.');
      return;
    }

    try {
      final folder = await (widget.folderLaporan?.call() ??
              getApplicationDocumentsDirectory())
          .timeout(batasTunggu);

      final namaBerkas =
          'plo_laporan_${kodeBerkasBulan(r.bulan)}.${pdf ? 'pdf' : 'csv'}';
      final berkas = File(p.join(folder.path, namaBerkas));

      final Uint8List isi;
      if (pdf) {
        isi = await bangunPdfLaporanBulanan(
          r,
          judul: 'Laporan Bulanan',
          catatan: 'Laporan disusun pada ${fmtTanggalAman(sekarang)} '
              'pukul ${fmtJam(sekarang)}.',
        ).timeout(batasTunggu);
      } else {
        isi = Uint8List.fromList(utf8.encode(ringkasanKeCsv(r)));
      }

      await berkas.writeAsBytes(isi, flush: true).timeout(batasTunggu);
      final ukuran = await berkas.length().timeout(batasTunggu);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('hasil_unduh'),
          duration: const Duration(seconds: 8),
          content: Text('Tersimpan: $namaBerkas (${_ukuranTeks(ukuran)})'),
        ),
      );

      // FR-138: catatan aktivitas ditulis di lapisan layar, setelah berkas
      // benar-benar ada. Kegagalan mencatat tidak membatalkan aksi pengguna.
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.lain,
        aksi: AksiAudit.ekspor,
        entitas: 'laporan_bulanan',
        entitasId: kodeBerkasBulan(r.bulan),
        sesudah: '$namaBerkas (${_ukuranTeks(ukuran)})',
        ringkas: 'Laporan bulanan ${namaBulanTahunId(r.bulan)} disimpan '
            'sebagai $namaBerkas',
      );
    } catch (e) {
      if (!mounted) return;
      pesan('Berkas laporan belum bisa disimpan. Coba lagi setelah folder '
          'dokumen aplikasi bisa dibuka.');
    }
  }

  /// "12,3 KB" / "845 byte" — desimal memakai koma seperti kebiasaan Indonesia.
  String _ukuranTeks(int byte) => byte < 1024
      ? '$byte byte'
      : '${(byte / 1024).toStringAsFixed(1).replaceAll('.', ',')} KB';

  void pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      key: const Key('pesan_laporan'),
      content: Text(teks),
    ));
  }

  // -------------------------------------------------------------------------
  // Tampilan
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final r = ringkasan;

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Bulanan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          _pemilihBulan(),
          const SizedBox(height: 8),
          if (galat != null)
            Card(
              key: const Key('pesan_galat'),
              child: ListTile(
                leading: const Icon(Icons.inbox_outlined),
                title: Text(galat!),
                subtitle: const Text('Belum ada yang bisa ditampilkan sekarang.'),
              ),
            ),
          if (r == null && memuat)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (r != null) ...[
            _kartuRingkasan(r),
            if (!r.adaTransaksi) _kartuKosong(),
            if (r.tagihan.isNotEmpty) _kartuTagihan(r),
            if (r.limaPengeluaranTerbesar.isNotEmpty) _kartuTerbesar(r),
            _kartuKategori(r),
          ],
          const SizedBox(height: 12),
          _tombolUnduh(),
        ],
      ),
    );
  }

  Widget _pemilihBulan() => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                key: const Key('bulan_sebelum'),
                tooltip: 'Bulan sebelumnya',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => geserBulan(-1),
              ),
              Expanded(
                child: Text(
                  namaBulanTahunId(bulan),
                  key: const Key('label_bulan'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const Key('bulan_berikut'),
                tooltip: 'Bulan berikutnya',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => geserBulan(1),
              ),
            ],
          ),
        ),
      );

  Widget _kartuRingkasan(RingkasanBulanan r) {
    final tidakAdaCatatan = !r.adaTransaksi;
    return Card(
      key: const Key('ringkasan_bulanan'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ringkasan ${namaBulanTahunId(r.bulan)}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _barisAngka(
              'Pemasukan',
              tidakAdaCatatan ? 'Belum ada data' : fmtRpDariSen(r.totalPemasukanSen),
              'total_pemasukan',
              warna: Colors.green.shade700,
            ),
            _barisAngka(
              'Pengeluaran',
              tidakAdaCatatan
                  ? 'Belum ada data'
                  : fmtRpDariSen(r.totalPengeluaranSen),
              'total_pengeluaran',
              warna: Colors.red.shade700,
            ),
            _barisAngka(
              'Selisih',
              tidakAdaCatatan ? 'Belum ada data' : fmtRpDariSen(r.selisihSen),
              'selisih',
              tebal: true,
            ),
            const Divider(height: 20),
            Text(r.teksRingkasan, key: const Key('teks_ringkasan')),
          ],
        ),
      ),
    );
  }

  Widget _barisAngka(
    String label,
    String angka,
    String kunci, {
    Color? warna,
    bool tebal = false,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              angka,
              key: Key(kunci),
              style: TextStyle(
                color: warna,
                fontWeight: tebal ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _kartuKosong() => const Card(
        key: Key('laporan_kosong'),
        child: ListTile(
          leading: Icon(Icons.inbox_outlined),
          title: Text('Belum ada catatan transaksi pada bulan ini.'),
          subtitle: Text(
            'Tombol unduh tetap bisa dipakai. Berkas yang dibuat akan berisi '
            'ringkasan dengan angka nol dan keterangan bahwa belum ada catatan.',
          ),
        ),
      );

  Widget _kartuTagihan(RingkasanBulanan r) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tagihan bulan ini',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('${r.jumlahTagihan} tagihan, total '
                  '${fmtRpDariSen(r.totalTagihanSen)}'),
              Text('${r.jumlahTagihanLunas} sudah lunas, '
                  '${r.jumlahTagihanBelumLunas} belum lunas'),
              const SizedBox(height: 6),
              for (final t in r.tagihan)
                Padding(
                  key: Key('tagihan_bulanan_${t.nama}'),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${t.nama} · '
                            '${fmtTanggalAman(t.jatuhTempo)} · '
                            '${t.lunas ? 'sudah lunas' : 'belum lunas'}'),
                      ),
                      Text(fmtRpDariSen(t.jumlahSen)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _kartuTerbesar(RingkasanBulanan r) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lima pengeluaran terbesar',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              for (final t in r.limaPengeluaranTerbesar)
                Padding(
                  key: Key('pengeluaran_terbesar_${t.id}'),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${t.kategori} · '
                            '${fmtTanggalPendekAman(t.tanggal)}'),
                      ),
                      Text(fmtRpDariSen(t.jumlahSen),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _kartuKategori(RingkasanBulanan r) {
    final pengeluaran = r.rincianKategori
        .where((k) => k.jenis == JenisArus.pengeluaran)
        .toList(growable: false);
    final pemasukan = r.rincianKategori
        .where((k) => k.jenis == JenisArus.pemasukan)
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rincian per kategori',
                style: Theme.of(context).textTheme.titleMedium),
            if (r.rincianKategori.isEmpty)
              const Text('Belum ada catatan kategori pada bulan ini.'),
            // Tiap jenis diberi induk sendiri supaya nama kategori yang sama
            // pada pemasukan dan pengeluaran tidak bertabrakan kuncinya.
            if (pengeluaran.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('Pengeluaran',
                      style: Theme.of(context).textTheme.labelLarge),
                  for (final k in pengeluaran) _barisKategori(k),
                ],
              ),
            if (pemasukan.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('Pemasukan',
                      style: Theme.of(context).textTheme.labelLarge),
                  for (final k in pemasukan) _barisKategori(k),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _barisKategori(RincianKategoriBulanan k) => Padding(
        key: Key('kategori_bulanan_${k.nama}'),
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text('${k.nama} · ${k.jumlahTransaksi} transaksi'),
            ),
            Text(fmtRpDariSen(k.jumlahSen)),
          ],
        ),
      );

  Widget _tombolUnduh() => Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const Key('unduh_pdf'),
              onPressed: () => unduhPdf(),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Unduh PDF'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('unduh_csv'),
              onPressed: () => unduhCsv(),
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('Unduh CSV'),
            ),
          ),
        ],
      );
}
