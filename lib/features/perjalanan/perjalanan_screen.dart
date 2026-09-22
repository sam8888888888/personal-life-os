/// FR-134 — Layar daftar Perjalanan.
///
/// Menyatukan jadwal, anggaran (terhubung Finance) dan dokumen tiap perjalanan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/perjalanan/perjalanan.dart';
import '../../core/providers/batch10_providers.dart';
import '../../core/utils/bahasa.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';
import 'detail_perjalanan_screen.dart';

class PerjalananScreen extends ConsumerStatefulWidget {
  const PerjalananScreen({super.key});

  @override
  ConsumerState<PerjalananScreen> createState() => _PerjalananScreenState();
}

class _PerjalananScreenState extends ConsumerState<PerjalananScreen> {
  List<PerjalananData> _daftar = const [];
  final Map<int, RingkasanPerjalanan> _ringkasan = {};
  bool _siap = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final repo = ref.read(repoPerjalananProvider);
      final daftar = await repo.semua();
      final ringkas = <int, RingkasanPerjalanan>{};
      for (final p in daftar) {
        ringkas[p.id] = await repo.ringkasan(p);
      }
      if (!mounted) return;
      setState(() {
        _daftar = daftar;
        _ringkasan
          ..clear()
          ..addAll(ringkas);
        _siap = true;
        _galat = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _siap = true;
        _galat = 'Gagal memuat perjalanan: ${e.runtimeType}.';
      });
    }
  }

  Future<void> _tambah() async {
    final nama = TextEditingController();
    final tujuan = TextEditingController();
    final mulai = TextEditingController();
    final sampai = TextEditingController();
    final anggaran = TextEditingController();
    final hasil = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('perjalanan.baru')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const Key('prj_nama'),
              controller: nama,
              decoration: const InputDecoration(labelText: 'Nama perjalanan'),
            ),
            TextField(
              key: const Key('prj_tujuan'),
              controller: tujuan,
              decoration: const InputDecoration(labelText: 'Tujuan'),
            ),
            TextField(
              key: const Key('prj_mulai'),
              controller: mulai,
              decoration: const InputDecoration(
                  labelText: 'Berangkat (YYYY-MM-DD)', hintText: '2026-10-05'),
            ),
            TextField(
              key: const Key('prj_sampai'),
              controller: sampai,
              decoration: const InputDecoration(
                  labelText: 'Pulang (YYYY-MM-DD)', hintText: '2026-10-12'),
            ),
            TextField(
              key: const Key('prj_anggaran'),
              controller: anggaran,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Anggaran (Rp, boleh kosong)'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('umum.batal'))),
          FilledButton(
            key: const Key('prj_simpan'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('umum.simpan')),
          ),
        ],
      ),
    );
    if (hasil != true) return;

    final a = DateTime.tryParse(mulai.text.trim());
    final b = DateTime.tryParse(sampai.text.trim());
    if (nama.text.trim().isEmpty || a == null || b == null) {
      _pesan('Nama, tanggal berangkat dan tanggal pulang wajib diisi '
          '(format tanggal: 2026-10-05).');
      return;
    }
    try {
      await ref.read(repoPerjalananProvider).tambah(
            nama: nama.text,
            tujuan: tujuan.text,
            mulai: a,
            sampai: b,
            anggaranSen: senDariKetikan(anggaran.text),
          );
      await _muat();
      _pesan('Perjalanan disimpan.');
    } catch (e) {
      _pesan(e is ArgumentError ? '${e.message}' : 'Gagal menyimpan: ${e.runtimeType}.');
    }
  }

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('perjalanan.judul'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('perjalanan_tambah'),
        onPressed: _tambah,
        icon: const Icon(Icons.add),
        label: Text(tr('umum.tambah')),
      ),
      body: !_siap
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (_galat != null)
                  Card(
                    key: const Key('perjalanan_galat'),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_galat!),
                    ),
                  ),
                if (_daftar.isEmpty && _galat == null)
                  Card(
                    key: const Key('perjalanan_kosong'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('${tr('umum.belumAda')} Tekan tombol '
                          '"+ ${tr('umum.tambah')}" untuk membuat perjalanan '
                          'pertama: agenda, tiket, hotel, anggaran, dokumen, '
                          'daftar bawaan, dan pengingat keberangkatan.'),
                    ),
                  ),
                for (final p in _daftar) _kartu(p, _ringkasan[p.id]),
              ],
            ),
    );
  }

  Widget _kartu(PerjalananData p, RingkasanPerjalanan? r) {
    final peringatan = r?.peringatan ?? const <String>[];
    return Card(
      key: Key('perjalanan_${p.id}'),
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DetailPerjalananScreen(id: p.id),
          ));
          await _muat();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.nama,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${p.tujuan} · ${p.mulai.day}/${p.mulai.month}/${p.mulai.year} – '
                '${p.sampai.day}/${p.sampai.month}/${p.sampai.year}'),
            const SizedBox(height: 2),
            Text(
              r == null
                  ? 'Ringkasan belum bisa dihitung.'
                  : r.hariLagi > 0
                      ? '${r.hariLagi} hari lagi'
                      : r.sedangBerlangsung
                          ? 'Sedang berlangsung'
                          : 'Sudah selesai',
            ),
            const SizedBox(height: 6),
            if (r?.persenAnggaran != null)
              LinearProgressIndicator(
                value: (r!.persenAnggaran! / 100).clamp(0.0, 1.0),
              ),
            const SizedBox(height: 4),
            Text(r?.dasarAnggaran ?? ''),
            if ((r?.jumlahBawaan ?? 0) > 0) ...[
              const SizedBox(height: 2),
              Text('Bawaan siap ${r!.bawaanSiap}/${r.jumlahBawaan} '
                  '(${r.persenBawaan}%)'),
            ],
            for (final w in peringatan) ...[
              const SizedBox(height: 4),
              Text('• $w',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            for (final b in (r?.belumBisa ?? const <String>[])) ...[
              const SizedBox(height: 4),
              Text('${tr('umum.belumBisa')}: $b',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
          ]),
        ),
      ),
    );
  }
}
