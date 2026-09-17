/// Detail satu kewajiban (FR-69 + FR-74).
///
/// Isi layar:
/// * sisa utang, bagian pokok & bunga yang sudah dibayar, jadwal jatuh tempo;
/// * tombol catat pembayaran;
/// * riwayat pembayaran (terbaru lebih dulu) dengan tombol hapus + konfirmasi;
/// * tombol ubah & hapus kewajiban. Hapus kewajiban memakai aturan hapus
///   berdampingan di repositori: seluruh pembayarannya ikut terhapus.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/uang/jadwal_kewajiban.dart';
import '../../../core/utils/tanggal_utils.dart';
import '../../../core/utils/uang_utils.dart';
import '../../../core/utils/waktu.dart';
import '../../../data/database/database.dart';
import '../../../data/repository/pembayaran_kewajiban_repository.dart';
import '../kekayaan/form_kewajiban_screen.dart';
import 'form_pembayaran_kewajiban_screen.dart';
import 'provider_uang_lanjutan.dart';

class DetailKewajibanScreen extends ConsumerStatefulWidget {
  const DetailKewajibanScreen({
    super.key,
    required this.kewajibanId,
    this.jamSekarang,
  });

  final int kewajibanId;

  /// Jam uji; dianggap waktu perangkat.
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<DetailKewajibanScreen> createState() =>
      DetailKewajibanScreenState();
}

class DetailKewajibanScreenState
    extends ConsumerState<DetailKewajibanScreen> {
  bool memuat = true;
  String? galat;
  RingkasanKewajiban? ringkasan;
  List<PembayaranKewajibanData> pembayaran = const [];

  DateTime get sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  PembayaranKewajibanRepository get repo =>
      ref.read(pembayaranKewajibanRepoProvider);

  @override
  void initState() {
    super.initState();
    muat();
  }

  /// Baca ulang kewajiban + seluruh pembayarannya.
  Future<void> muat() async {
    try {
      final r = await repo
          .ambilRingkasanSatu(widget.kewajibanId)
          .timeout(const Duration(seconds: 5));
      final p = await repo
          .ambilPembayaran(widget.kewajibanId)
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        ringkasan = r;
        pembayaran = p;
        memuat = false;
        galat = r == null ? 'Belum ada data' : null;
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

  // -------------------------------------------------------------------------
  // Aksi
  // -------------------------------------------------------------------------

  Future<void> bukaFormPembayaran() async {
    final r = ringkasan;
    if (r == null) return;
    final tersimpan =
        await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => FormPembayaranKewajibanScreen(
        kewajibanId: r.kewajiban.id,
        namaKewajiban: r.kewajiban.nama,
        sisaSen: r.sisaSen,
        jamSekarang: widget.jamSekarang,
      ),
    ));
    if (tersimpan == true) await muat();
  }

  Future<void> bukaFormUbah() async {
    final r = ringkasan;
    if (r == null) return;
    final tersimpan =
        await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => FormKewajibanScreen(
        kewajiban: r.kewajiban,
        jamSekarang: widget.jamSekarang,
      ),
    ));
    if (tersimpan == true) await muat();
  }

  Future<void> hapusPembayaran(PembayaranKewajibanData p) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const Key('dialog_hapus_pembayaran'),
        title: const Text('Hapus pembayaran ini?'),
        content: Text(
            'Catatan pembayaran ${fmtRpDariSen(p.jumlahSen)} pada '
            '${fmtTanggalAman(p.tanggal)} akan dihapus, sehingga sisa utang '
            'dihitung ulang tanpa baris ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('konfirmasi_hapus_pembayaran'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    await repo.hapusPembayaran(p.id);
    await muat();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pembayaran dihapus.')));
  }

  Future<void> hapusKewajiban() async {
    final r = ringkasan;
    if (r == null) return;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const Key('dialog_hapus_kewajiban'),
        title: Text('Hapus kewajiban "${r.kewajiban.nama}"?'),
        content: const Text('Catatan pembayarannya ikut terhapus. Bila hanya '
            'ingin menyembunyikannya, pakai "Arsipkan" di layar Kekayaan '
            'bersih.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('konfirmasi_hapus_kewajiban'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    await repo.hapusKewajiban(widget.kewajibanId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kewajiban dihapus.')));
    Navigator.of(context).pop(true);
  }

  // -------------------------------------------------------------------------
  // Tampilan
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final r = ringkasan;
    return Scaffold(
      appBar: AppBar(
        title: Text(r?.kewajiban.nama ?? 'Detail kewajiban'),
        actions: [
          if (r != null)
            IconButton(
              key: const Key('ubah_kewajiban'),
              tooltip: 'Ubah kewajiban',
              onPressed: bukaFormUbah,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                if (r == null)
                  Card(
                    key: const Key('pesan_galat'),
                    child: ListTile(
                      leading: const Icon(Icons.inbox_outlined),
                      title: Text(galat ?? 'Belum ada data'),
                      subtitle:
                          const Text('Kewajiban itu belum bisa dibaca.'),
                    ),
                  )
                else ...[
                  _kartuSisa(r),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('catat_pembayaran'),
                    onPressed: bukaFormPembayaran,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Catat pembayaran'),
                  ),
                  const SizedBox(height: 16),
                  Text('Riwayat pembayaran', style: tema.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (pembayaran.isEmpty)
                    const Card(
                      key: Key('kosong_riwayat'),
                      child: ListTile(
                        leading: Icon(Icons.inbox_outlined),
                        title: Text('Belum ada data'),
                        subtitle:
                            Text('Belum ada pembayaran tercatat untuk '
                                'kewajiban ini.'),
                      ),
                    )
                  else
                    for (final p in pembayaran) _kartuPembayaran(p),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    key: const Key('hapus_kewajiban'),
                    onPressed: hapusKewajiban,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus kewajiban ini'),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _kartuSisa(RingkasanKewajiban r) {
    final tema = Theme.of(context);
    final k = r.kewajiban;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sisa utang', style: tema.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              fmtRpDariSen(r.sisaSen),
              key: const Key('angka_sisa_utang'),
              style: tema.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              key: const Key('bilah_pokok'),
              value: r.bagianPokokTerbayar,
            ),
            const SizedBox(height: 8),
            Text('Bagian pokok terbayar '
                '${fmtRpDariSen(r.totalPokokDibayarSen)} dari '
                '${fmtRpDariSen(r.pokokAcuanSen)}'),
            Text('Bagian bunga terbayar ${fmtRpDariSen(r.totalBungaDibayarSen)}'),
            Text('Jumlah pembayaran tercatat: ${r.jumlahPembayaran}'),
            if (r.terakhirDibayarPada != null)
              Text('Pembayaran terakhir '
                  '${fmtTanggalAman(r.terakhirDibayarPada!)}'),
            const SizedBox(height: 8),
            Text(
              kalimatJatuhTempo(
                hariJatuhTempo: k.tanggalJatuhTempoHari,
                sekarang: sekarang,
                formatTanggal: fmtTanggalAman,
              ),
              key: const Key('jadwal_pembayaran'),
            ),
            if (k.minimumBayarSen != null)
              Text('Minimum bayar ${fmtRpDariSen(k.minimumBayarSen!)}'),
            if (r.lunas) const Text('Sudah tuntas'),
          ],
        ),
      ),
    );
  }

  Widget _kartuPembayaran(PembayaranKewajibanData p) {
    final tema = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: Key('pembayaran_${p.id}'),
        title: Text(
          fmtRpDariSen(p.jumlahSen),
          key: Key('jumlah_pembayaran_${p.id}'),
        ),
        subtitle: Text('${fmtTanggalAman(p.tanggal)} · pokok '
            '${fmtRpDariSen(p.pokokSen)} · bunga ${fmtRpDariSen(p.bungaSen)}'
            '${p.catatan == null || p.catatan!.isEmpty ? '' : '\n${p.catatan}'}'),
        isThreeLine: true,
        trailing: IconButton(
          key: Key('hapus_pembayaran_${p.id}'),
          tooltip: 'Hapus pembayaran',
          onPressed: () => hapusPembayaran(p),
          icon: Icon(Icons.delete_outline, color: tema.colorScheme.error),
        ),
      ),
    );
  }
}
