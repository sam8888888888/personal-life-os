/// FR-134 — Layar rincian satu Perjalanan (agenda, tiket, hotel, dokumen,
/// daftar bawaan) + ringkasan anggaran yang terhubung ke laporan keuangan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/perjalanan/perjalanan.dart';
import '../../core/providers/batch10_providers.dart';
import '../../core/utils/bahasa.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';
import 'jurnal_perjalanan_screen.dart';

class DetailPerjalananScreen extends ConsumerStatefulWidget {
  const DetailPerjalananScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<DetailPerjalananScreen> createState() =>
      _DetailPerjalananScreenState();
}

class _DetailPerjalananScreenState
    extends ConsumerState<DetailPerjalananScreen> {
  PerjalananData? _p;
  List<ItemPerjalananData> _items = const [];
  RingkasanPerjalanan? _r;
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
      final p = await repo.satu(widget.id);
      if (p == null) {
        if (!mounted) return;
        setState(() {
          _siap = true;
          _galat = 'Perjalanan tidak ditemukan (mungkin sudah dihapus).';
        });
        return;
      }
      final items = p.uid == null ? <ItemPerjalananData>[] : await repo.items(p.uid!);
      final r = await repo.ringkasan(p);
      if (!mounted) return;
      setState(() {
        _p = p;
        _items = items;
        _r = r;
        _siap = true;
        _galat = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _siap = true;
        _galat = 'Gagal memuat rincian: ${e.runtimeType}.';
      });
    }
  }

  Future<void> _tambahItem() async {
    var jenis = JenisItemPerjalanan.agenda;
    final judul = TextEditingController();
    final tempat = TextEditingController();
    final waktu = TextEditingController();
    final biaya = TextEditingController();
    final dokumen = TextEditingController();
    final hasil = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Tambah isi perjalanan'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<JenisItemPerjalanan>(
                key: const Key('itm_jenis'),
                initialValue: jenis,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Jenis'),
                items: JenisItemPerjalanan.values
                    .map((j) => DropdownMenuItem(value: j, child: Text(j.label)))
                    .toList(),
                onChanged: (j) => setD(() => jenis = j ?? jenis),
              ),
              TextField(
                key: const Key('itm_judul'),
                controller: judul,
                decoration: const InputDecoration(
                    labelText: 'Judul', hintText: 'Contoh: Pesawat GA-402'),
              ),
              TextField(
                key: const Key('itm_tempat'),
                controller: tempat,
                decoration: const InputDecoration(labelText: 'Tempat (boleh kosong)'),
              ),
              TextField(
                key: const Key('itm_waktu'),
                controller: waktu,
                decoration: const InputDecoration(
                    labelText: 'Waktu (boleh kosong)',
                    hintText: '2026-10-05 07:30'),
              ),
              TextField(
                key: const Key('itm_biaya'),
                controller: biaya,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Biaya (Rp, boleh kosong)'),
              ),
              TextField(
                key: const Key('itm_dokumen'),
                controller: dokumen,
                decoration: const InputDecoration(
                    labelText: 'Tautkan dokumen (kode/uid, boleh kosong)'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(tr('umum.batal'))),
            FilledButton(
              key: const Key('itm_simpan'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('umum.simpan')),
            ),
          ],
        ),
      ),
    );
    if (hasil != true) return;
    final uid = _p?.uid;
    if (uid == null) {
      _pesan('Perjalanan ini belum punya penanda sinkron (uid) — tidak bisa '
          'menambah isi.');
      return;
    }
    if (judul.text.trim().isEmpty) {
      _pesan('Judul ${tr('umum.wajibDiisi')}');
      return;
    }
    try {
      await ref.read(repoPerjalananProvider).tambahItem(
            perjalananUid: uid,
            jenis: jenis,
            judul: judul.text,
            tempat: tempat.text,
            waktu: DateTime.tryParse(waktu.text.trim()),
            biayaSen: senDariKetikan(biaya.text),
            dokumenUid:
                dokumen.text.trim().isEmpty ? null : dokumen.text.trim(),
          );
      await _muat();
      _pesan('Isi perjalanan ditambahkan.');
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
    final p = _p;
    return Scaffold(
      appBar: AppBar(
        title: Text(p?.nama ?? tr('perjalanan.judul')),
        actions: [
          if (p != null)
            IconButton(
              key: const Key('detail_prj_hapus'),
              tooltip: 'Hapus perjalanan',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final nav = Navigator.of(context);
                final yakin = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Hapus perjalanan ini?'),
                    content: const Text('Agenda, tiket, hotel, daftar bawaan '
                        'dan jurnalnya ikut terhapus. Pengeluaran yang sudah '
                        'tercatat di laporan keuangan TIDAK dihapus.'),
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
                await ref.read(repoPerjalananProvider).hapus(widget.id);
                nav.pop();
              },
            ),
        ],
      ),
      floatingActionButton: FilledButton.icon(
        key: const Key('detail_prj_tambah_item'),
        onPressed: _tambahItem,
        icon: const Icon(Icons.add),
        label: const Text('Isi perjalanan'),
      ),
      body: !_siap
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (_galat != null)
                  Card(
                    key: const Key('detail_prj_galat'),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                        padding: const EdgeInsets.all(12), child: Text(_galat!)),
                  ),
                if (_r != null) _kartuRingkasan(_r!),
                if (p != null)
                  Card(
                    child: ListTile(
                      key: const Key('detail_prj_jurnal'),
                      leading: const Icon(Icons.auto_stories_outlined),
                      title: Text(tr('perjalanan.jurnal')),
                      subtitle: const Text('Foto, pengeluaran, tempat, penilaian, '
                          'kenangan — pengeluaran langsung masuk laporan keuangan.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final nav = Navigator.of(context);
                        await nav.push(MaterialPageRoute(
                          builder: (_) => JurnalPerjalananScreen(
                            perjalananUid: p.uid ?? '',
                            idPerjalanan: p.idPerjalanan,
                            namaPerjalanan: p.nama,
                          ),
                        ));
                        await _muat();
                      },
                    ),
                  ),
                if (_items.isEmpty)
                  Card(
                    key: const Key('detail_prj_kosong'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Belum ada isi perjalanan. Tekan "Isi '
                          'perjalanan" untuk menambah agenda, tiket, hotel, '
                          'dokumen, atau daftar bawaan.'),
                    ),
                  ),
                for (final jenis in JenisItemPerjalanan.values)
                  ..._bagian(jenis),
              ],
            ),
    );
  }

  Widget _kartuRingkasan(RingkasanPerjalanan r) {
    return Card(
      key: const Key('detail_prj_anggaran'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${tr('perjalanan.anggaran')} · ${fmtRingkasRp(r.anggaranSen)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (r.persenAnggaran != null) ...[
            LinearProgressIndicator(
                value: (r.persenAnggaran! / 100).clamp(0.0, 1.0)),
            const SizedBox(height: 4),
            Text('Terpakai ${r.persenAnggaran}% · sisa ${fmtRingkasRp(r.sisaAnggaranSen)}'),
          ],
          const SizedBox(height: 4),
          Text(r.dasarAnggaran),
          if (r.rencanaSen > 0) ...[
            const SizedBox(height: 2),
            Text('Rencana biaya item: ${fmtRingkasRp(r.rencanaSen)}'),
          ],
          if (r.jumlahBawaan > 0) ...[
            const SizedBox(height: 2),
            Text('Bawaan siap ${r.bawaanSiap}/${r.jumlahBawaan} (${r.persenBawaan}%)'),
          ],
          for (final w in r.peringatan) ...[
            const SizedBox(height: 6),
            Text('• $w',
                key: Key('detail_prj_peringatan_${w.hashCode}'),
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          for (final b in r.belumBisa) ...[
            const SizedBox(height: 4),
            Text('${tr('umum.belumBisa')}: $b',
                style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
          if (r.dokumenTertaut.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('${tr('perjalanan.dokumen')} tertaut: ${r.dokumenTertaut.length}'),
          ],
        ]),
      ),
    );
  }

  List<Widget> _bagian(JenisItemPerjalanan jenis) {
    final isi = _items.where((i) => i.jenis == jenis.kode).toList();
    if (isi.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(jenis.label.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      ),
      for (final i in isi)
        Card(
          key: Key('item_${i.id}'),
          child: ListTile(
            leading: jenis == JenisItemPerjalanan.bawaan
                ? Checkbox(
                    key: Key('item_cek_${i.id}'),
                    value: i.selesai,
                    onChanged: (v) async {
                      await ref
                          .read(repoPerjalananProvider)
                          .setSelesaiItem(i.id, v ?? false);
                      await _muat();
                    },
                  )
                : Icon(jenis == JenisItemPerjalanan.tiket
                    ? Icons.confirmation_number_outlined
                    : jenis == JenisItemPerjalanan.hotel
                        ? Icons.hotel_outlined
                        : jenis == JenisItemPerjalanan.dokumen
                            ? Icons.folder_outlined
                            : Icons.event_outlined),
            title: Text(i.judul),
            subtitle: Text([
              if (i.tempat != null && i.tempat!.isNotEmpty) i.tempat!,
              if (i.waktu != null)
                '${i.waktu!.day}/${i.waktu!.month}/${i.waktu!.year} '
                    '${i.waktu!.hour.toString().padLeft(2, '0')}:'
                    '${i.waktu!.minute.toString().padLeft(2, '0')}',
              if (i.biayaSen > 0) fmtRingkasRp(i.biayaSen),
              if (i.dokumenUid != null && i.dokumenUid!.isNotEmpty) 'dokumen: ${i.dokumenUid}',
            ].join(' · ')),
            trailing: IconButton(
              key: Key('item_hapus_${i.id}'),
              icon: const Icon(Icons.close),
              tooltip: 'Hapus item',
              onPressed: () async {
                await ref.read(repoPerjalananProvider).hapusItem(i.id);
                await _muat();
              },
            ),
          ),
        ),
    ];
  }
}
