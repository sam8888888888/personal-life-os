/// Layar "Hutang & kewajiban" (FR-74).
///
/// Isi layar:
/// * total sisa utang seluruh kewajiban aktif;
/// * daftar kewajiban: sisa utang, jadwal jatuh tempo berikutnya, minimum bayar;
/// * tombol masuk ke detail (catat pembayaran & riwayat).
///
/// Aturan angka yang dipakai: sisa utang = pokok acuan - jumlah bagian pokok
/// yang sudah dibayar (lihat `PembayaranKewajibanRepository`). Bagian bunga
/// tidak mengurangi sisa utang.
///
/// Setiap pembacaan penyimpanan dibungkus batas waktu 5 detik. Bila lewat
/// batas itu, layar menulis "Belum ada data" apa adanya dan tidak menebak
/// angka.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/uang/jadwal_kewajiban.dart';
import '../../../core/utils/tanggal_utils.dart';
import '../../../core/utils/uang_utils.dart';
import '../../../core/utils/waktu.dart';
import '../../../data/repository/pembayaran_kewajiban_repository.dart';
import '../kekayaan/form_kewajiban_screen.dart';
import 'detail_kewajiban_screen.dart';
import 'provider_uang_lanjutan.dart';

class KewajibanScreen extends ConsumerStatefulWidget {
  const KewajibanScreen({super.key, this.jamSekarang});

  /// Jam uji; dianggap waktu perangkat.
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<KewajibanScreen> createState() => KewajibanScreenState();
}

class KewajibanScreenState extends ConsumerState<KewajibanScreen> {
  bool memuat = true;
  String? galat;
  List<RingkasanKewajiban> daftar = const [];

  DateTime get sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  PembayaranKewajibanRepository get repo =>
      ref.read(pembayaranKewajibanRepoProvider);

  @override
  void initState() {
    super.initState();
    muat();
  }

  /// Baca ulang seluruh kewajiban + sisa utangnya.
  Future<void> muat() async {
    try {
      final hasil =
          await repo.ambilRingkasan().timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        daftar = hasil;
        memuat = false;
        galat = null;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        memuat = false;
        galat = 'Belum ada data';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        memuat = false;
        galat = 'Belum ada data ($e)';
      });
    }
  }

  Future<void> bukaDetail(RingkasanKewajiban r) async {
    final berubah = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DetailKewajibanScreen(
        kewajibanId: r.kewajiban.id,
        jamSekarang: widget.jamSekarang,
      ),
    ));
    if (berubah == true) await muat();
  }

  Future<void> bukaFormTambah() async {
    // Form kewajiban sudah ada di modul Kekayaan dan dipakai ulang di sini
    // supaya kolomnya tidak berbeda antara dua layar.
    final tersimpan = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) =>
          FormKewajibanScreen(jamSekarang: widget.jamSekarang),
    ));
    if (tersimpan == true) await muat();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    var totalSisa = 0;
    var totalDibayar = 0;
    for (final r in daftar) {
      totalSisa += r.sisaSen;
      totalDibayar += r.totalDibayarSen;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Hutang & kewajiban')),
      body: memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                if (galat != null)
                  Card(
                    key: const Key('pesan_galat'),
                    child: ListTile(
                      leading: const Icon(Icons.inbox_outlined),
                      title: Text(galat!),
                      subtitle: const Text(
                          'Data kewajiban belum bisa dibaca sekarang.'),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total sisa utang',
                            style: tema.textTheme.labelLarge),
                        const SizedBox(height: 4),
                        Text(
                          daftar.isEmpty ? 'Belum ada data' : fmtRpDariSen(totalSisa),
                          key: const Key('total_sisa_utang'),
                          style: tema.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          daftar.isEmpty
                              ? 'Tambahkan kewajiban lewat tombol di bawah.'
                              : '${daftar.length} kewajiban · sudah dibayar '
                                  '${fmtRpDariSen(totalDibayar)}',
                          style: tema.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('tambah_kewajiban'),
                  onPressed: bukaFormTambah,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah kewajiban'),
                ),
                if (daftar.isEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    key: const Key('kosong_kewajiban'),
                    child: const ListTile(
                      leading: Icon(Icons.inbox_outlined),
                      title: Text('Belum ada data'),
                      subtitle: Text('Belum ada kewajiban yang dicatat.'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Text('Daftar kewajiban', style: tema.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final r in daftar) _kartuKewajiban(r),
                ],
              ],
            ),
    );
  }

  Widget _kartuKewajiban(RingkasanKewajiban r) {
    final k = r.kewajiban;
    final tema = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: Key('kewajiban_${k.id}'),
        onTap: () => bukaDetail(r),
        title: Text(k.nama),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              fmtRpDariSen(r.sisaSen),
              key: Key('sisa_utang_${k.id}'),
              style: tema.textTheme.titleMedium,
            ),
            Text('sisa utang', style: tema.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(kalimatJatuhTempo(
              hariJatuhTempo: k.tanggalJatuhTempoHari,
              sekarang: sekarang,
              formatTanggal: fmtTanggalAman,
            )),
            if (k.minimumBayarSen != null)
              Text('Minimum bayar ${fmtRpDariSen(k.minimumBayarSen!)}'),
            if (r.lunas) const Text('Sudah tuntas'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
