/// FR-47 — Layar Split Bill & Patungan.
///
/// Daftar grup → rincian grup (anggota, belanja, hasil "siapa bayar ke siapa").
/// Teks ringkasannya bisa dibagikan lewat WhatsApp/salin — memakai ulang
/// kanal FR-49 (`bukaTautan`) supaya tidak ada tautan yang ditulis dua kali.
library;

import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/buka_tautan.dart';
import '../../core/providers/app_providers.dart';
import '../../core/rumah/patungan.dart';
import '../../core/utils/bahasa.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';
import '../../core/providers/batch11_providers.dart';

class PatunganScreen extends ConsumerStatefulWidget {
  const PatunganScreen({super.key});

  @override
  ConsumerState<PatunganScreen> createState() => _PatunganScreenState();
}

class _PatunganScreenState extends ConsumerState<PatunganScreen> {
  List<GrupPatunganData> _grup = const [];
  bool _siap = false;
  String? _galat;
  StreamSubscription<void>? _pantauan;

  @override
  void initState() {
    super.initState();
    _muat();
    // Ikuti perubahan tabel grup/anggota/belanja/bagian.
    final db = ref.read(databaseProvider);
    _pantauan = db
        .tableUpdates(TableUpdateQuery.onAllTables([
      db.grupPatungan,
      db.anggotaPatungan,
      db.belanjaPatungan,
      db.bagianPatungan,
    ])).listen((_) {
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
      final daftar = await ref.read(repoPatunganProvider).grupSemua();
      if (!mounted) return;
      setState(() {
        _grup = daftar;
        _siap = true;
        _galat = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _siap = true;
        _galat = 'Gagal memuat grup patungan: ${e.runtimeType}.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('patungan.judul'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('patungan_tambah'),
        onPressed: _tambahGrup,
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
                if (_grup.isEmpty)
                  Padding(
                    key: const Key('patungan_kosong'),
                    padding: const EdgeInsets.all(12),
                    child: Text('${tr('umum.belumAda')} Tekan "${tr('umum.tambah')}" '
                        'untuk membuat grup patungan (makan bersama, arisan, '
                        'trip) lalu isi anggotanya.'),
                  ),
                for (final g in _grup)
                  Card(
                    key: Key('grup_${g.id}'),
                    child: ListTile(
                      title: Text(g.nama),
                      subtitle: Text('Kode undangan: '
                          '${(g.kodeUndangan ?? '').isEmpty ? '—' : g.kodeUndangan}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final nav = Navigator.of(context);
                        await nav.push(MaterialPageRoute(
                          builder: (_) => GrupPatunganScreen(grupId: g.id),
                        ));
                        await _muat();
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _tambahGrup() async {
    final nama = TextEditingController();
    final catatan = TextEditingController();
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('patungan.tambah')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            key: const Key('grup_nama'),
            controller: nama,
            decoration: const InputDecoration(labelText: 'Nama grup'),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('grup_catatan'),
            controller: catatan,
            decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('umum.batal'))),
          FilledButton(
              key: const Key('grup_simpan'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('umum.simpan'))),
        ],
      ),
    );
    if (lanjut != true || nama.text.trim().isEmpty) return;
    await ref.read(repoPatunganProvider).tambahGrup(
          nama: nama.text.trim(),
          catatan: catatan.text.trim().isEmpty ? null : catatan.text.trim(),
        );
    await _muat();
  }
}

/// Rincian satu grup: anggota, belanja, hasil.
class GrupPatunganScreen extends ConsumerStatefulWidget {
  const GrupPatunganScreen({super.key, required this.grupId});
  final int grupId;

  @override
  ConsumerState<GrupPatunganScreen> createState() => _GrupPatunganScreenState();
}

class _GrupPatunganScreenState extends ConsumerState<GrupPatunganScreen> {
  HasilPatungan? _hasil;
  List<AnggotaPatunganData> _anggota = const [];
  List<BelanjaPatunganData> _belanja = const [];
  String _namaGrup = '';
  String _kodeUndangan = '';
  bool _siap = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final repo = ref.read(repoPatunganProvider);
      final grup = (await repo.grupSemua(termasukArsip: true))
          .firstWhere((g) => g.id == widget.grupId);
      final hasil = await repo.hasil(widget.grupId);
      final uid = grup.uid ?? '';
      final anggota = uid.isEmpty ? <AnggotaPatunganData>[] : await repo.anggota(uid);
      final belanja = uid.isEmpty ? <BelanjaPatunganData>[] : await repo.belanja(uid);
      if (!mounted) return;
      setState(() {
        _namaGrup = grup.nama;
        _kodeUndangan = grup.kodeUndangan ?? '';
        _hasil = hasil;
        _anggota = anggota;
        _belanja = belanja;
        _siap = true;
        _galat = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _siap = true;
        _galat = 'Gagal memuat grup: ${e.runtimeType}.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasil = _hasil;
    return Scaffold(
      appBar: AppBar(title: Text(_namaGrup.isEmpty ? tr('patungan.judul') : _namaGrup)),
      body: !_siap
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                if (_galat != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_galat!),
                    ),
                  ),
                if (_kodeUndangan.isNotEmpty)
                  Text('Kode undangan: $_kodeUndangan — berikan ke anggota lain '
                      'saat data grup ini dibagikan.'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: Text(tr('patungan.anggota'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  TextButton.icon(
                    key: const Key('grup_anggota_tambah'),
                    onPressed: _tambahAnggota,
                    icon: const Icon(Icons.person_add_alt),
                    label: Text(tr('umum.tambah')),
                  ),
                ]),
                if (_anggota.isEmpty)
                  const Text('Belum ada anggota. Tambahkan dulu sebelum '
                      'mencatat belanja.'),
                for (final a in _anggota)
                  ListTile(
                    key: Key('anggota_${a.id}'),
                    dense: true,
                    title: Text(a.nama),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: tr('umum.hapus'),
                      onPressed: () async {
                        await ref.read(repoPatunganProvider).hapusAnggota(a.id);
                        await _muat();
                      },
                    ),
                  ),
                const Divider(height: 32),
                Row(children: [
                  Expanded(
                    child: Text(tr('patungan.belanja'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  TextButton.icon(
                    key: const Key('grup_belanja_tambah'),
                    onPressed: _anggota.isEmpty ? null : _tambahBelanja,
                    icon: const Icon(Icons.add),
                    label: Text(tr('umum.tambah')),
                  ),
                ]),
                if (_belanja.isEmpty)
                  const Text('Belum ada belanja/nota di grup ini.'),
                for (final b in _belanja)
                  ListTile(
                    key: Key('belanja_${b.id}'),
                    dense: true,
                    title: Text(b.judul),
                    subtitle: Text('${fmtRpDariSen(b.totalSen)} · dibayar '
                        '${b.pembayar} · ${b.tanggal.day}/${b.tanggal.month}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: tr('umum.hapus'),
                      onPressed: () async {
                        await ref.read(repoPatunganProvider).hapusBelanja(b.id);
                        await _muat();
                      },
                    ),
                  ),
                const Divider(height: 32),
                Text(tr('patungan.hasil'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (hasil != null) ...[
                  const SizedBox(height: 4),
                  Text(hasil.dasar),
                  for (final s in hasil.saldo)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• ${s.nama}: ${s.dasar}'),
                    ),
                  const SizedBox(height: 8),
                  if (hasil.transfer.isEmpty)
                    const Text('Semua sudah pas, tidak ada yang perlu transfer.')
                  else
                    for (var i = 0; i < hasil.transfer.length; i++)
                      ListTile(
                        key: Key('transfer_$i'),
                        dense: true,
                        leading: const Icon(Icons.swap_horiz),
                        title: Text(hasil.transferTeks(hasil.transfer[i])),
                      ),
                  for (final w in hasil.peringatan)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('• $w',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  for (final b in hasil.belumBisa)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${tr('umum.belumBisa')}: $b',
                          style: const TextStyle(fontStyle: FontStyle.italic)),
                    ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, children: [
                    OutlinedButton.icon(
                      key: const Key('grup_salin'),
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: teksRingkasPatungan(hasil)));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Ringkasan patungan disalin.')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Salin ringkasan'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('grup_whatsapp'),
                      onPressed: () async {
                        final tautan = 'https://wa.me/?text='
                            '${Uri.encodeComponent(teksRingkasPatungan(hasil))}';
                        final dibuka = await bukaTautan(tautan);
                        if (!context.mounted) return;
                        if (!dibuka) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Tidak ada aplikasi yang bisa '
                                    'membuka tautan WhatsApp — ringkasannya '
                                    'bisa disalin.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Bagikan'),
                    ),
                  ]),
                ],
              ],
            ),
    );
  }

  Future<void> _tambahAnggota() async {
    final nama = TextEditingController();
    final grup = (await ref.read(repoPatunganProvider).grupSemua(termasukArsip: true))
        .firstWhere((g) => g.id == widget.grupId);
    if (!mounted) return;
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tambah anggota'),
        content: TextField(
          key: const Key('anggota_nama'),
          controller: nama,
          decoration: const InputDecoration(labelText: 'Nama anggota'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('umum.batal'))),
          FilledButton(
              key: const Key('anggota_simpan'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('umum.simpan'))),
        ],
      ),
    );
    if (lanjut != true || nama.text.trim().isEmpty) return;
    await ref
        .read(repoPatunganProvider)
        .tambahAnggota(grup.uid ?? '', nama.text.trim());
    await _muat();
  }

  Future<void> _tambahBelanja() async {
    final grup = (await ref.read(repoPatunganProvider).grupSemua(termasukArsip: true))
        .firstWhere((g) => g.id == widget.grupId);
    final judul = TextEditingController();
    final total = TextEditingController();
    final pembayar = ValueNotifier<String>(_anggota.first.nama);
    if (!mounted) return;
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tambah belanja'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const Key('belanja_judul'),
              controller: judul,
              decoration: const InputDecoration(labelText: 'Judul (mis. Makan malam)'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('belanja_total'),
              controller: total,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total (Rp)'),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<String>(
              valueListenable: pembayar,
              builder: (_, v, _) => DropdownButtonFormField<String>(
                key: const Key('belanja_pembayar'),
                initialValue: v,
                decoration: const InputDecoration(labelText: 'Dibayar oleh'),
                items: _anggota
                    .map((a) => DropdownMenuItem(value: a.nama, child: Text(a.nama)))
                    .toList(),
                onChanged: (x) {
                  if (x != null) pembayar.value = x;
                },
              ),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Bagian dibagi sama rata ke semua anggota '
                  '(sisa pembulatan dibebankan berurutan).',
                  style: TextStyle(fontSize: 12)),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('umum.batal'))),
          FilledButton(
              key: const Key('belanja_simpan'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('umum.simpan'))),
        ],
      ),
    );
    if (lanjut != true) return;
    final nilai = senDariKetikan(total.text);
    if (nilai <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total belanja belum diisi.')),
      );
      return;
    }
    try {
      await ref.read(repoPatunganProvider).tambahBelanja(
            grupUid: grup.uid ?? '',
            judul: judul.text.trim().isEmpty ? 'Belanja' : judul.text.trim(),
            totalSen: nilai,
            pembayar: pembayar.value,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
    await _muat();
  }
}
