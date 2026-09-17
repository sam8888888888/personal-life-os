/// Layar "Pengeluaran terencana" (FR-70).
///
/// Pengeluaran terencana = uang yang HARUS tersedia sebelum tanggal tertentu,
/// tetapi belum menjadi transaksi. Layar ini:
/// * menambah, mengubah, menghapus, dan menandai "sudah terjadi";
/// * menampilkan daftar urut tanggal;
/// * menghitung "total yang harus disiapkan sampai tanggal terpilih".
///
/// Rentang tanggal memakai batas atas EKSKLUSIF: baris dihitung bila
/// tanggalnya lebih awal dari pukul 00:00 hari setelah tanggal terpilih, jadi
/// satu hari tidak pernah terhitung dua kali.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/tanggal_utils.dart';
import '../../../core/utils/uang_utils.dart';
import '../../../core/utils/waktu.dart';
import '../../../data/database/database.dart';
import '../../../data/repository/pengeluaran_terencana_repository.dart';
import 'form_pengeluaran_terencana_screen.dart';
import '../kewajiban/provider_uang_lanjutan.dart';

class PengeluaranTerencanaScreen extends ConsumerStatefulWidget {
  const PengeluaranTerencanaScreen({super.key, this.jamSekarang});

  /// Jam uji; dianggap waktu perangkat.
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<PengeluaranTerencanaScreen> createState() =>
      PengeluaranTerencanaScreenState();
}

class PengeluaranTerencanaScreenState
    extends ConsumerState<PengeluaranTerencanaScreen> {
  bool memuat = true;
  String? galat;
  List<PengeluaranTerencanaData> daftar = const [];
  late DateTime batas;

  DateTime get sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  PengeluaranTerencanaRepository get repo =>
      ref.read(pengeluaranTerencanaRepoProvider);

  @override
  void initState() {
    super.initState();
    batas = tanggalSaja(sekarang);
    muat();
  }

  /// Baca ulang seluruh baris pengeluaran terencana.
  Future<void> muat() async {
    try {
      final hasil =
          await repo.ambilSemua().timeout(const Duration(seconds: 5));
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

  // -------------------------------------------------------------------------
  // Aksi
  // -------------------------------------------------------------------------

  void geserBatas(int hari) {
    setState(() => batas = tanggalSaja(sekarang).add(Duration(days: hari)));
  }

  Future<void> pilihBatas() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: batas,
      firstDate: DateTime(batas.year - 3),
      lastDate: DateTime(batas.year + 5),
    );
    if (hasil != null) setState(() => batas = tanggalSaja(hasil));
  }

  Future<void> bukaForm(PengeluaranTerencanaData? baris) async {
    final tersimpan = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => FormPengeluaranTerencanaScreen(
        pengeluaran: baris,
        jamSekarang: widget.jamSekarang,
      ),
    ));
    if (tersimpan == true) await muat();
  }

  Future<void> aksi(PengeluaranTerencanaData baris, String pilihan) async {
    switch (pilihan) {
      case 'ubah':
        await bukaForm(baris);
      case 'sudah':
        await repo.tandaiSudahTerjadi(baris.id);
        await muat();
        pesan('"${baris.nama}" ditandai sudah terjadi.');
      case 'rencana':
        await repo.tandaiSudahTerjadi(baris.id, sudahTerjadi: false);
        await muat();
        pesan('"${baris.nama}" kembali ke daftar rencana.');
      case 'hapus':
        await hapus(baris);
    }
  }

  Future<void> hapus(PengeluaranTerencanaData baris) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const Key('dialog_hapus_pengeluaran'),
        title: Text('Hapus "${baris.nama}"?'),
        content: const Text('Rencana pengeluaran ini akan dihapus dari daftar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('konfirmasi_hapus_pengeluaran'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    await repo.hapus(baris.id);
    await muat();
    pesan('"${baris.nama}" dihapus.');
  }

  void pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  // -------------------------------------------------------------------------
  // Tampilan
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final batasEksklusif = batas.add(const Duration(days: 1));
    final ringkasan = repo.ringkasanDari(daftar, batasEksklusif);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengeluaran terencana')),
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
                      subtitle: const Text('Daftar belum bisa dibaca sekarang.'),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Perlu disiapkan', style: tema.textTheme.labelLarge),
                        const SizedBox(height: 4),
                        Text(
                          ringkasan.kosong
                              ? 'Belum ada data'
                              : fmtRpDariSen(ringkasan.totalSen),
                          key: const Key('total_persiapan'),
                          style: tema.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sampai ${fmtTanggalAman(batas)}',
                          key: const Key('label_batas'),
                          style: tema.textTheme.bodyMedium,
                        ),
                        if (!ringkasan.kosong)
                          Text(
                            '${ringkasan.jumlahBaris} pengeluaran belum terjadi'
                            '${ringkasan.jumlahTerlewat > 0 ? ' · ${ringkasan.jumlahTerlewat} tanggalnya sudah lewat' : ''}',
                            style: tema.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      key: const Key('batas_hari_ini'),
                      label: const Text('Sampai hari ini'),
                      selected: hariSama(batas, sekarang),
                      onSelected: (_) => geserBatas(0),
                    ),
                    ChoiceChip(
                      key: const Key('batas_7_hari'),
                      label: const Text('7 hari'),
                      selected: hariSama(batas, sekarang.add(const Duration(days: 7))),
                      onSelected: (_) => geserBatas(7),
                    ),
                    ChoiceChip(
                      key: const Key('batas_30_hari'),
                      label: const Text('30 hari'),
                      selected:
                          hariSama(batas, sekarang.add(const Duration(days: 30))),
                      onSelected: (_) => geserBatas(30),
                    ),
                    ActionChip(
                      key: const Key('pilih_batas'),
                      avatar: const Icon(Icons.event, size: 18),
                      label: const Text('Pilih tanggal'),
                      onPressed: pilihBatas,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('tambah_pengeluaran'),
                  onPressed: () => bukaForm(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah pengeluaran terencana'),
                ),
                const SizedBox(height: 16),
                Text('Daftar rencana', style: tema.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (daftar.isEmpty)
                  const Card(
                    key: Key('kosong_pengeluaran'),
                    child: ListTile(
                      leading: Icon(Icons.inbox_outlined),
                      title: Text('Belum ada data'),
                      subtitle: Text('Belum ada pengeluaran terencana '
                          'yang dicatat.'),
                    ),
                  )
                else
                  for (final baris in daftar) _kartu(baris),
              ],
            ),
    );
  }

  bool hariSama(DateTime a, DateTime b) =>
      tanggalSaja(a) == tanggalSaja(b);

  Widget _kartu(PengeluaranTerencanaData baris) {
    final tema = Theme.of(context);
    final sudah = baris.sudahTerjadi;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: Key('pengeluaran_${baris.id}'),
        title: Text(baris.nama),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              fmtRpDariSen(baris.jumlahSen),
              key: Key('jumlah_pengeluaran_${baris.id}'),
              style: tema.textTheme.titleMedium,
            ),
            Text(
              fmtTanggalAman(baris.tanggal),
              key: Key('tanggal_pengeluaran_${baris.id}'),
            ),
            Text(sudah ? 'Sudah terjadi' : 'Belum terjadi'),
            if (!baris.aktif) const Text('Tidak dihitung (dimatikan)'),
            if (baris.catatan != null && baris.catatan!.isNotEmpty)
              Text(baris.catatan!),
          ],
        ),
        trailing: PopupMenuButton<String>(
          key: Key('menu_pengeluaran_${baris.id}'),
          onSelected: (v) => aksi(baris, v),
          itemBuilder: (c) => [
            const PopupMenuItem(value: 'ubah', child: Text('Ubah')),
            PopupMenuItem(
              value: sudah ? 'rencana' : 'sudah',
              child: Text(sudah ? 'Kembalikan ke rencana' : 'Tandai sudah terjadi'),
            ),
            const PopupMenuItem(value: 'hapus', child: Text('Hapus')),
          ],
        ),
      ),
    );
  }
}
