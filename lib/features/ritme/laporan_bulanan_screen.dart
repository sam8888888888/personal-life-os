/// FR-145 — Monthly Life Report (signature).
///
/// Kriteria terima PRD: "Tersedia untuk setiap bulan berjalan; bisa dibagikan
/// sebagai PDF." Laporan memuat keuangan, tagihan, tujuan, tugas, langganan,
/// kekayaan bersih + "apa yang membaik / berubah / perlu perhatian" — semuanya
/// dari [BahanAnalitik] yang sama dengan layar analitik.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/laporan/laporan_hidup_bulanan.dart';
import '../../core/laporan/pdf_laporan_hidup.dart';
import '../../core/platform/bagikan.dart';
import '../../core/utils/tanggal_utils.dart';
import '../ritme/ritme_providers.dart';

/// Batas tunggu pekerjaan berkas (sama pola dengan laporan lain).
const Duration batasTungguLaporanHidup = Duration(seconds: 20);

class LaporanHidupScreen extends ConsumerStatefulWidget {
  const LaporanHidupScreen({super.key, this.direktoriSementara});

  /// Dipakai uji supaya tidak menyentuh direktori sungguhan.
  final Future<Directory> Function()? direktoriSementara;

  @override
  ConsumerState<LaporanHidupScreen> createState() =>
      _LaporanHidupScreenState();
}

class _LaporanHidupScreenState extends ConsumerState<LaporanHidupScreen> {
  late String _bulan = kunciBulanLaporan(DateTime.now());
  LaporanHidupBulanan? _laporan;
  bool _siap = false;
  String? _galat;
  String _pesan = '';
  List<String> _arsip = const [];

  @override
  void initState() {
    super.initState();
    muat();
  }

  Future<void> muat() async {
    setState(() => _siap = false);
    try {
      final repo = ref.read(repoHidupProvider);
      final r = rentangBulan(_bulan);
      final laluR = rentangBulan(bulanSebelum(_bulan));
      final ini = await repo.bahan(dari: r.dari, sampai: r.sampai);
      final lalu = await repo.bahan(dari: laluR.dari, sampai: laluR.sampai);
      final laporan = susunLaporanHidupBulanan(
        ini: ini,
        lalu: lalu,
        langgananDekat: await repo.langgananDekat(),
        tujuanTerdekat: await repo.tujuanTerdekat(),
        asetTerbesar: await repo.asetTerbesar(),
      );
      final arsip = await ref.read(repoTinjauanProvider).riwayatLaporan();
      if (!mounted) return;
      setState(() {
        _laporan = laporan;
        _arsip = arsip.map((a) => a.bulan).toList();
        _siap = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = 'Laporan belum bisa disusun: $e';
        _siap = true;
      });
    }
  }

  Future<void> simpanArsip() async {
    final l = _laporan;
    if (l == null) return;
    await ref.read(repoTinjauanProvider).simpanLaporan(
          bulan: l.bulan,
          ringkasTeks: l.teksLengkap(),
          angka: l.angkaKunci(),
        );
    final arsip = await ref.read(repoTinjauanProvider).riwayatLaporan();
    if (!mounted) return;
    setState(() {
      _pesan = 'Laporan ${l.label} disimpan ke arsip.';
      _arsip = arsip.map((a) => a.bulan).toList();
    });
  }

  Future<void> salinTeks() async {
    final l = _laporan;
    if (l == null) return;
    await Clipboard.setData(ClipboardData(text: l.teksLengkap()));
    if (!mounted) return;
    setState(() => _pesan = 'Teks laporan disalin.');
  }

  /// Buat PDF lalu buka lembar berbagi.
  Future<(String?, String)> bagikanPdf() async {
    final l = _laporan;
    if (l == null) return (null, 'Laporan belum siap.');
    try {
      final isi = await bangunPdfLaporanHidup(l);
      final dir = await (widget.direktoriSementara ?? getTemporaryDirectory)();
      final berkas = File('${dir.path}/laporan-bulanan-${l.bulan}.pdf');
      await berkas
          .writeAsBytes(isi, flush: true)
          .timeout(batasTungguLaporanHidup);
      final terkirim = await bagikanBerkas(
        jalur: berkas.path,
        judul: 'Laporan bulanan ${l.label}',
      );
      if (!terkirim) {
        return (berkas.path,
            'PDF tersimpan di ${berkas.path}, tetapi lembar berbagi belum terbuka.');
      }
      return (berkas.path, 'PDF laporan ${l.label} siap dibagikan.');
    } catch (e) {
      return (null, 'PDF belum bisa dibuat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final l = _laporan;
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan bulanan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('laporan_bulan_sebelum'),
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  _bulan = bulanSebelum(_bulan);
                  muat();
                },
              ),
              Expanded(
                child: Text(
                  l?.label ?? _bulan,
                  key: const Key('laporan_bulan'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const Key('laporan_bulan_sesudah'),
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  final r = rentangBulan(_bulan);
                  _bulan = kunciBulanLaporan(DateTime(r.dari.year, r.dari.month + 1, 1));
                  muat();
                },
              ),
            ],
          ),
          if (_galat != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_galat!, key: const Key('laporan_galat')),
            ),
          if (l != null) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.summarize_outlined),
                title: Text('Ringkasan ${l.label}'),
                subtitle: Text('Periode ${fmtTanggalPendekAman(l.dari)} – '
                    '${fmtTanggalPendekAman(l.sampai)}'),
              ),
            ),
            for (final b in l.bagian)
              Card(
                key: Key('laporan_bagian_${b.judul.replaceAll(' ', '_')}'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.judul,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      for (final r in b.baris)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(r.label)),
                                  Text(r.nilai,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium),
                                ],
                              ),
                              Text('sumber: ${r.sumber}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            _kelompok('Yang membaik', l.membaik, 'laporan_membaik', Colors.green),
            _kelompok('Yang berubah', l.berubah, 'laporan_berubah', Colors.blueGrey),
            _kelompok('Yang perlu perhatian', l.perluPerhatian,
                'laporan_perlu', Colors.orange),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('laporan_simpan'),
              onPressed: simpanArsip,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Simpan ke arsip'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('laporan_pdf'),
              onPressed: () async {
                final (jalur, pesan) = await bagikanPdf();
                if (!mounted) return;
                setState(() => _pesan = '$pesan ${jalur ?? ''}'.trim());
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(pesan),
                  duration: const Duration(seconds: 4),
                ));
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Buat PDF & bagikan'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('laporan_salin'),
              onPressed: salinTeks,
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Salin teks laporan'),
            ),
            if (_pesan.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_pesan, key: const Key('laporan_pesan')),
              ),
            Card(
              key: const Key('laporan_arsip'),
              child: ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text('Arsip tersimpan'),
                subtitle: Text(_arsip.isEmpty
                    ? 'belum ada laporan yang disimpan'
                    : _arsip.join(', ')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kelompok(
      String judul, List<String> isi, String key, MaterialColor warna) {
    return Card(
      key: Key(key),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(judul, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            if (isi.isEmpty)
              const Text('belum ada yang bisa dibandingkan'),
            for (final x in isi)
              Text(x, style: TextStyle(color: warna.shade700)),
          ],
        ),
      ),
    );
  }
}
