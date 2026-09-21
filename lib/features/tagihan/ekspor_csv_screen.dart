/// Layar Ekspor CSV (FR-25) — tagihan & riwayat pembayaran ke spreadsheet.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/laporan/ekspor_csv.dart';
import '../../core/providers/app_providers.dart';
import '../../data/database/database.dart';
import '../../data/repository/tagihan_repository.dart';

/// Menulis dua berkas CSV (tagihan + riwayat pembayaran) ke [folder].
///
/// Dipisah dari layar supaya bisa diuji dengan database & folder sungguhan
/// (uji widget memakai waktu palsu sehingga penulisan berkas tidak selesai).
Future<List<BerkasCsv>> eksporSemuaCsv({
  required AppDatabase db,
  required TagihanRepository repo,
  required Directory folder,
}) async {
  final tagihan = await repo.ambilSemua();
  final kategori = await db.select(db.kategori).get();
  final peta = {for (final k in kategori) k.id: k.nama};
  final riwayat = await repo.riwayatUntukEkspor();
  return tulisCsv(folder, [
    (nama: 'tagihan.csv', isi: csvTagihan(tagihan, namaKategori: peta)),
    (nama: 'riwayat_pembayaran.csv', isi: csvRiwayat(riwayat)),
  ]);
}

class EksporCsvScreen extends ConsumerStatefulWidget {
  const EksporCsvScreen({super.key, this.folder});

  /// Folder tujuan (boleh disuntik saat uji). Bawaan: folder dokumen aplikasi.
  final Directory? folder;

  @override
  ConsumerState<EksporCsvScreen> createState() => _EksporCsvScreenState();
}

class _EksporCsvScreenState extends ConsumerState<EksporCsvScreen> {
  List<BerkasCsv> _hasil = const [];
  String? _galat;
  bool _sibuk = false;

  Future<Directory> _folderTujuan() async =>
      widget.folder ?? Directory('${(await getApplicationDocumentsDirectory()).path}/ekspor');

  Future<void> _ekspor() async {
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      final hasil = await eksporSemuaCsv(
        db: ref.read(databaseProvider),
        repo: ref.read(tagihanRepoProvider),
        folder: await _folderTujuan(),
      );
      if (!mounted) return;
      setState(() => _hasil = hasil);
    } catch (e) {
      setState(() => _galat = 'Gagal menulis berkas: $e');
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ekspor CSV')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bukti untuk spreadsheet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Dua berkas: daftar tagihan dan riwayat pembayaran. '
                      'Pemisah kolom titik-koma (;) supaya rapi dibuka di Excel '
                      'Indonesia; ada kolom bilangan bulat (sen) untuk dihitung '
                      'dan kolom teks untuk dibaca.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('jalankan_ekspor_csv'),
                    onPressed: _sibuk ? null : _ekspor,
                    icon: _sibuk
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.table_view_outlined),
                    label: const Text('Buat berkas CSV'),
                  ),
                ],
              ),
            ),
          ),
          if (_galat != null) ...[
            const SizedBox(height: 12),
            Text(_galat!,
                key: const Key('ekspor_csv_galat'),
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_hasil.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final b in _hasil)
                    ListTile(
                      key: Key('berkas_${b.nama}'),
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(b.nama),
                      subtitle: Text('${b.baris} baris · ${b.jalur}'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Berkas tersimpan di folder aplikasi di HP ini. '
                'Buka lewat aplikasi Files/My Files lalu pilih Excel atau '
                'Google Sheets.'),
          ],
        ],
      ),
    );
  }
}
