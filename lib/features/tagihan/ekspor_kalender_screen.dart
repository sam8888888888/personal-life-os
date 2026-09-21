/// FR-41 — Layar "Ekspor kalender (.ics)": tagihan mendatang → Google Kalender.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/laporan/ekspor_ics.dart';
import '../../core/providers/app_providers.dart';
import '../../data/database/database.dart';
import '../../data/repository/tagihan_repository.dart';

/// Menulis berkas .ics ke [folder]. Dipisah dari layar supaya bisa diuji
/// dengan berkas & database sungguhan (uji widget memakai waktu palsu).
Future<({String jalur, int acara, int tagihan})> eksporKalender({
  required TagihanRepository repo,
  required Directory folder,
  required DateTime dari,
  required DateTime sampai,
  DateTime? dibuat,
}) async {
  final tagihan = await repo.ambilSemua();
  final hasil = susunIcsTagihan(
    tagihan,
    dari: dari,
    sampai: sampai,
    dibuat: dibuat,
  );
  if (!folder.existsSync()) folder.createSync(recursive: true);
  final berkas = File('${folder.path}/$namaBerkasIcs');
  await berkas.writeAsString(hasil.isi, flush: true);
  return (
    jalur: berkas.path,
    acara: hasil.jumlahAcara,
    tagihan: hasil.jumlahTagihan,
  );
}

class EksporKalenderScreen extends ConsumerStatefulWidget {
  const EksporKalenderScreen({super.key, this.folder, this.sekarang});

  /// Folder tujuan (boleh disuntik saat uji).
  final Directory? folder;

  /// Waktu acuan (boleh disuntik saat uji supaya hasilnya tetap).
  final DateTime? sekarang;

  @override
  ConsumerState<EksporKalenderScreen> createState() =>
      _EksporKalenderScreenState();
}

class _EksporKalenderScreenState extends ConsumerState<EksporKalenderScreen> {
  int _bulanKeDepan = 12;
  bool _sibuk = false;
  String? _galat;
  ({String jalur, int acara, int tagihan})? _hasil;

  DateTime get _sekarang => widget.sekarang ?? DateTime.now();

  Future<void> _ekspor() async {
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      final folder = widget.folder ??
          Directory('${(await getApplicationDocumentsDirectory()).path}/ekspor');
      final sekarang = _sekarang;
      final hasil = await eksporKalender(
        repo: ref.read(tagihanRepoProvider),
        folder: folder,
        dari: DateTime(sekarang.year, sekarang.month, sekarang.day),
        sampai: DateTime(sekarang.year, sekarang.month + _bulanKeDepan, 0),
        dibuat: sekarang,
      );
      if (!mounted) return;
      setState(() => _hasil = hasil);
    } catch (e) {
      if (!mounted) return;
      setState(() => _galat = 'Gagal menulis berkas: $e');
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ekspor kalender')),
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
                  const Text('Jadwal tagihan ke kalender Papi',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text(
                      'Berkas .ics berisi tagihan mendatang (satu acara tiap '
                      'jatuh tempo, tagihan berulang diperluas). Bukanya di '
                      'Google Kalender → Setelan → Impor, atau ketuk berkasnya '
                      'di HP lalu pilih Kalender. Setiap acara sudah memuat '
                      'pengingat sesuai lead hari tagihan.'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: const Key('pilih_rentang_bulan'),
                    initialValue: _bulanKeDepan,
                    decoration: const InputDecoration(
                        labelText: 'Rentang ke depan', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('3 bulan')),
                      DropdownMenuItem(value: 6, child: Text('6 bulan')),
                      DropdownMenuItem(value: 12, child: Text('12 bulan')),
                      DropdownMenuItem(value: 24, child: Text('24 bulan')),
                    ],
                    onChanged: (v) =>
                        setState(() => _bulanKeDepan = v ?? _bulanKeDepan),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('jalankan_ekspor_kalender'),
                    onPressed: _sibuk ? null : _ekspor,
                    icon: _sibuk
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.event_outlined),
                    label: const Text('Buat berkas .ics'),
                  ),
                ],
              ),
            ),
          ),
          if (_galat != null) ...[
            const SizedBox(height: 12),
            Text(_galat!,
                key: const Key('ekspor_kalender_galat'),
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_hasil != null) ...[
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                key: const Key('berkas_ics'),
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(namaBerkasIcs),
                subtitle: Text('${_hasil!.acara} acara · ${_hasil!.tagihan} '
                    'tagihan\n${_hasil!.jalur}'),
                isThreeLine: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Keterangan ringkas (dipakai laporan/uji): jumlah acara & tagihan dari daftar.
({int acara, int tagihan}) ringkasIcs(List<TagihanData> tagihan,
    {required DateTime dari, required DateTime sampai}) {
  final h = susunIcsTagihan(tagihan, dari: dari, sampai: sampai);
  return (acara: h.jumlahAcara, tagihan: h.jumlahTagihan);
}
