/// FR-48 — Layar Dasbor Dana Persiapan.
///
/// Menampilkan tiap dana (target, terkumpul, setoran per bulan), riwayat
/// setoran, dan arus kas bersih. Semua angka yang belum bisa dihitung
/// disebutkan apa adanya di bagian "Belum bisa".
library;

import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analitik/dana_persiapan.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/bahasa.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';
import '../../core/providers/batch11_providers.dart';

class DanaPersiapanScreen extends ConsumerStatefulWidget {
  const DanaPersiapanScreen({super.key});

  @override
  ConsumerState<DanaPersiapanScreen> createState() =>
      _DanaPersiapanScreenState();
}

class _DanaPersiapanScreenState extends ConsumerState<DanaPersiapanScreen> {
  DasborDanaPersiapan? _dasbor;
  List<DanaPersiapanData> _baris = const [];
  bool _siap = false;
  String? _galat;
  StreamSubscription<void>? _pantauan;

  @override
  void initState() {
    super.initState();
    _muat();
    // Ikuti perubahan tabel: setoran/hapus dari layar lain langsung terlihat.
    final db = ref.read(databaseProvider);
    _pantauan = db
        .tableUpdates(TableUpdateQuery.onAllTables(
            [db.danaPersiapan, db.setoranDana]))
        .listen((_) {
      if (mounted) _muat();
    });
  }

  @override
  void dispose() {
    _pantauan?.cancel();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final repo = ref.read(repoDanaPersiapanProvider);
      final baris = await repo.semua(termasukArsip: true);
      final dasbor = await repo.ringkasan();
      if (!mounted) return;
      setState(() {
        _baris = baris.where((b) => !b.arsip).toList();
        _dasbor = dasbor;
        _siap = true;
        _galat = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _siap = true;
        _galat = 'Gagal memuat dana persiapan: ${e.runtimeType}.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dasbor = _dasbor;
    return Scaffold(
      appBar: AppBar(title: Text(tr('dana.judul'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('dana_tambah'),
        onPressed: _tambah,
        icon: const Icon(Icons.add),
        label: Text(tr('umum.tambah')),
      ),
      body: !_siap
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                if (_galat != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_galat!),
                    ),
                  ),
                if (dasbor != null) ...[
                  Card(
                    key: const Key('dana_ringkas'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dasbor.dasar,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Alokasi per bulan: '
                              '${fmtRpDariSen(dasbor.totalAlokasiBulananSen)}'),
                          Text(dasbor.arusKasBersihSen == null
                              ? 'Arus kas bersih: belum bisa dihitung.'
                              : 'Arus kas bersih setelah alokasi: '
                                  '${fmtRpDariSen(dasbor.arusKasBersihSen!)}'),
                        ],
                      ),
                    ),
                  ),
                  for (final w in dasbor.peringatan)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('• $w',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 8),
                ],
                if (_baris.isEmpty)
                  Padding(
                    key: const Key('dana_kosong'),
                    padding: const EdgeInsets.all(12),
                    child: Text('${tr('umum.belumAda')} Tekan "${tr('umum.tambah')}" '
                        'untuk membuat dana persiapan pertama (pajak, sekolah, '
                        'servis, tiket pulang).'),
                  ),
                for (final b in _baris) _kartuDana(b),
                if (dasbor != null && dasbor.belumBisa.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(tr('umum.belumBisa'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  for (final b in dasbor.belumBisa)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• $b',
                          style: const TextStyle(fontStyle: FontStyle.italic)),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _kartuDana(DanaPersiapanData b) {
    final ringkas = hitungDanaPersiapan(
      DanaPersiapan(
        nama: b.nama,
        targetSen: b.targetSen,
        tersediaSen: b.tersediaSen,
        tanggalTarget: b.tanggalTarget,
        arsip: b.arsip,
        catatan: b.catatan,
      ),
    );
    final persen = ringkas.persen;
    return Card(
      key: Key('dana_${b.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(b.nama,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                key: Key('dana_hapus_${b.id}'),
                tooltip: tr('umum.hapus'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _hapus(b),
              ),
            ]),
            Text(ringkas.dasar),
            if (persen != null) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                key: Key('dana_persen_${b.id}'),
                value: (persen / 100).clamp(0.0, 1.0),
              ),
            ],
            const SizedBox(height: 4),
            Text(ringkas.keteranganStatus),
            if ((b.catatan ?? '').trim().isNotEmpty)
              Text(b.catatan!, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(
                key: Key('dana_setor_${b.id}'),
                onPressed: () => _setor(b),
                icon: const Icon(Icons.savings_outlined),
                label: Text(tr('dana.setor')),
              ),
              TextButton.icon(
                key: Key('dana_ubah_${b.id}'),
                onPressed: () => _ubah(b),
                icon: const Icon(Icons.edit_outlined),
                label: Text(tr('umum.ubah')),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _tambah() async {
    final hasil = await _dialogDana();
    if (hasil == null) return;
    final repo = ref.read(repoDanaPersiapanProvider);
    await repo.tambah(
      nama: hasil.nama,
      targetSen: hasil.targetSen,
      tanggalTarget: hasil.tanggalTarget,
      catatan: hasil.catatan,
    );
    await _muat();
  }

  Future<void> _ubah(DanaPersiapanData b) async {
    final hasil = await _dialogDana(awal: b);
    if (hasil == null) return;
    final repo = ref.read(repoDanaPersiapanProvider);
    await repo.ubah(
      b.id,
      nama: hasil.nama,
      targetSen: hasil.targetSen,
      tanggalTarget: hasil.tanggalTarget,
      hapusTanggalTarget: hasil.tanggalTarget == null,
      catatan: hasil.catatan,
    );
    await _muat();
  }

  Future<void> _setor(DanaPersiapanData b) async {
    if (b.uid == null || b.uid!.isEmpty) return;
    final teks = TextEditingController();
    final tanggal = ValueNotifier<DateTime>(DateTime.now());
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${tr('dana.setor')} — ${b.nama}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            key: const Key('setor_jumlah'),
            controller: teks,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jumlah (Rp)'),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<DateTime>(
            valueListenable: tanggal,
            builder: (_, t, _) => Row(children: [
              Expanded(child: Text('Tanggal: ${t.day}/${t.month}/${t.year}')),
              TextButton(
                key: const Key('setor_tanggal'),
                onPressed: () async {
                  final pilih = await showDatePicker(
                    context: c,
                    initialDate: t,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pilih != null) tanggal.value = pilih;
                },
                child: Text(tr('umum.ubah')),
              ),
            ]),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('umum.batal'))),
          FilledButton(
              key: const Key('setor_simpan'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('umum.simpan'))),
        ],
      ),
    );
    if (lanjut != true) return;
    final jumlah = senDariKetikan(teks.text);
    if (jumlah == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah setoran belum diisi.')),
      );
      return;
    }
    await ref.read(repoDanaPersiapanProvider).tambahSetoran(
          danaUid: b.uid!,
          jumlahSen: jumlah,
          tanggal: tanggal.value,
        );
    await _muat();
  }

  Future<void> _hapus(DanaPersiapanData b) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${tr('umum.hapus')} ${b.nama}?'),
        content: const Text('Riwayat setoran dana ini ikut terhapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('umum.batal'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('umum.hapus'))),
        ],
      ),
    );
    if (yakin != true) return;
    await ref.read(repoDanaPersiapanProvider).hapus(b.id);
    await _muat();
  }

  Future<_HasilDialogDana?> _dialogDana({DanaPersiapanData? awal}) async {
    final nama = TextEditingController(text: awal?.nama ?? '');
    final target = TextEditingController(
        text: awal == null || awal.targetSen <= 0
            ? ''
            : fmtRpDariSen(awal.targetSen));
    final catatan = TextEditingController(text: awal?.catatan ?? '');
    final tanggal = ValueNotifier<DateTime?>(awal?.tanggalTarget);
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(awal == null ? tr('dana.tambah') : tr('dana.ubah')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const Key('dana_nama'),
              controller: nama,
              decoration: const InputDecoration(labelText: 'Nama dana'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('dana_target'),
              controller: target,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Target (Rp)', hintText: 'contoh: 5.000.000'),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<DateTime?>(
              valueListenable: tanggal,
              builder: (_, t, _) => Row(children: [
                Expanded(
                  child: Text(t == null
                      ? 'Tanggal target: belum diisi'
                      : 'Tanggal target: ${t.day}/${t.month}/${t.year}'),
                ),
                TextButton(
                  key: const Key('dana_tanggal'),
                  onPressed: () async {
                    final pilih = await showDatePicker(
                      context: c,
                      initialDate: t ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (pilih != null) tanggal.value = pilih;
                  },
                  child: Text(tr('umum.ubah')),
                ),
              ]),
            ),
            TextField(
              key: const Key('dana_catatan'),
              controller: catatan,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('umum.batal'))),
          FilledButton(
              key: const Key('dana_simpan'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('umum.simpan'))),
        ],
      ),
    );
    if (lanjut != true) return null;
    if (nama.text.trim().isEmpty) return null;
    return _HasilDialogDana(
      nama: nama.text.trim(),
      targetSen: senDariKetikan(target.text),
      tanggalTarget: tanggal.value,
      catatan: catatan.text.trim().isEmpty ? null : catatan.text.trim(),
    );
  }
}

class _HasilDialogDana {
  _HasilDialogDana({
    required this.nama,
    required this.targetSen,
    required this.tanggalTarget,
    required this.catatan,
  });
  final String nama;
  final int targetSen;
  final DateTime? tanggalTarget;
  final String? catatan;
}
