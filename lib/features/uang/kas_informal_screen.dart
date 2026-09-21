/// FR-51 — Layar "Kas & utang informal".
///
/// Mencatat utang ke warung/kontrakan, piutang ke tetangga, dan catatan tunai
/// sederhana; menampilkan saldo per pihak dan catatan yang jatuh temponya dekat.
/// Tidak ada tagihan resmi, tidak ada dokumen — hanya catatan supaya tidak lupa.
library;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/kas_informal.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';

class KasInformalScreen extends ConsumerStatefulWidget {
  const KasInformalScreen({super.key, this.db, this.sekarang});

  final AppDatabase? db;
  final DateTime? sekarang;

  @override
  ConsumerState<KasInformalScreen> createState() => _KasInformalScreenState();
}

class _KasInformalScreenState extends ConsumerState<KasInformalScreen> {
  AppDatabase get _db => widget.db ?? ref.read(databaseProvider);

  final TextEditingController _pihak = TextEditingController();
  final TextEditingController _jumlah = TextEditingController();
  final TextEditingController _catatan = TextEditingController();

  String _jenis = 'utang';
  DateTime? _jatuhTempo;

  bool _memuat = true;
  List<KasInformalData> _daftar = const [];
  String? _pesan;

  DateTime get _sekarang => widget.sekarang ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _pihak.dispose();
    _jumlah.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final daftar = await (_db.select(_db.kasInformal)
          ..orderBy([(t) => OrderingTerm.desc(t.tanggal)]))
        .get();
    if (!mounted) return;
    setState(() {
      _daftar = daftar;
      _memuat = false;
    });
  }

  int? _angka(String teks) {
    final bersih = teks.replaceAll(RegExp(r'[^0-9]'), '');
    if (bersih.isEmpty) return null;
    return int.tryParse(bersih);
  }

  Future<void> _pilihJatuhTempo() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _jatuhTempo ?? _sekarang.add(const Duration(days: 7)),
      firstDate: DateTime(_sekarang.year - 5),
      lastDate: DateTime(_sekarang.year + 10),
    );
    if (hasil == null) return;
    setState(() => _jatuhTempo = hasil);
  }

  Future<void> _simpan() async {
    final pihak = _pihak.text.trim();
    final jumlah = _angka(_jumlah.text);
    if (pihak.isEmpty) {
      setState(() => _pesan = 'Tulis nama pihaknya dulu (mis. Warung Bu Sri).');
      return;
    }
    if (jumlah == null || jumlah <= 0) {
      setState(() => _pesan = 'Isi jumlahnya dulu (angka rupiah).');
      return;
    }
    await _db.into(_db.kasInformal).insert(KasInformalCompanion.insert(
          jenis: _jenis,
          pihak: pihak,
          tanggal: _sekarang,
          jumlahSen: jumlah * 100,
          jatuhTempo: Value(_jatuhTempo),
          catatan:
              Value(_catatan.text.trim().isEmpty ? null : _catatan.text.trim()),
        ));
    _pihak.clear();
    _jumlah.clear();
    _catatan.clear();
    setState(() => _jatuhTempo = null);
    await _muat();
    if (!mounted) return;
    setState(() => _pesan = 'Catatan ${labelJenisKas(_jenis).toLowerCase()} '
        'untuk $pihak tersimpan.');
  }

  Future<void> _tandaiLunas(KasInformalData d, bool lunas) async {
    await (_db.update(_db.kasInformal)..where((t) => t.id.equals(d.id))).write(
      KasInformalCompanion(
        lunas: Value(lunas),
        tanggalLunas: Value(lunas ? _sekarang : null),
        diubahPada: Value(_sekarang),
      ),
    );
    await _muat();
  }

  Future<void> _hapus(KasInformalData d) async {
    await (_db.delete(_db.kasInformal)..where((t) => t.id.equals(d.id))).go();
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) return const Center(child: CircularProgressIndicator());
    final tema = Theme.of(context);
    final ringkas = ringkasKas(_daftar, _sekarang);

    return Scaffold(
      appBar: AppBar(title: const Text('Kas & utang informal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Catat baru', style: tema.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final j in ['utang', 'piutang', 'tunai'])
                        ChoiceChip(
                          key: Key('jenis_kas_$j'),
                          label: Text(labelJenisKas(j)),
                          selected: _jenis == j,
                          onSelected: (_) => setState(() => _jenis = j),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          key: const Key('isi_pihak_kas'),
                          controller: _pihak,
                          decoration: const InputDecoration(
                            labelText: 'Pihak (warung/orang)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const Key('isi_jumlah_kas'),
                          controller: _jumlah,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Jumlah (Rp)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('isi_catatan_kas'),
                          controller: _catatan,
                          decoration: const InputDecoration(
                            labelText: 'Catatan (boleh kosong)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        key: const Key('pilih_jatuh_tempo_kas'),
                        onPressed: _pilihJatuhTempo,
                        icon: const Icon(Icons.event_outlined, size: 18),
                        label: Text(_jatuhTempo == null
                            ? 'Jatuh tempo'
                            : fmtTanggalId(_jatuhTempo!)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('simpan_kas'),
                    onPressed: _simpan,
                    icon: const Icon(Icons.add),
                    label: const Text('Simpan catatan'),
                  ),
                  if (_pesan != null) ...[
                    const SizedBox(height: 8),
                    Text(_pesan!, key: const Key('pesan_kas')),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            key: const Key('ringkas_kas'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ringkasan', style: tema.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(kalimatKas(ringkas), key: const Key('kalimat_kas')),
                  const SizedBox(height: 8),
                  for (final s in ringkas.perPihak.take(8))
                    Text(
                      '${s.pihak}: '
                      '${s.selisihSen == 0 ? 'seimbang' : s.selisihSen > 0 ? 'berutang ${rupiahKas(s.selisihSen)} ke kita' : 'kita berutang ${rupiahKas(-s.selisihSen)}'}',
                      key: Key('saldo_pihak_${s.pihak}'),
                      style: tema.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          if (ringkas.jatuhTempoDekat.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              key: const Key('kartu_jatuh_tempo_dekat'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Jatuh tempo dekat',
                        style: tema.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    for (final d in ringkas.jatuhTempoDekat.take(6))
                      Text(
                        '${d.pihak} · ${rupiahKas(d.jumlahSen)} · '
                        '${fmtTanggalId(d.jatuhTempo!)}',
                        key: Key('dekat_${d.id}'),
                        style: tema.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text('Semua catatan', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_daftar.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada catatan.'),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final d in _daftar)
                    ListTile(
                      key: Key('kas_${d.id}'),
                      leading: Icon(d.lunas
                          ? Icons.check_circle_outline
                          : Icons.receipt_long_outlined),
                      title: Text('${d.pihak} · ${rupiahKas(d.jumlahSen)}'),
                      subtitle: Text([
                        labelJenisKas(d.jenis),
                        fmtTanggalId(d.tanggal),
                        if (d.jatuhTempo != null)
                          'jatuh tempo ${fmtTanggalId(d.jatuhTempo!)}',
                        if (d.lunas) 'sudah lunas',
                        if (d.catatan != null && d.catatan!.isNotEmpty)
                          d.catatan!,
                      ].join(' · ')),
                      trailing: Wrap(
                        spacing: 2,
                        children: [
                          IconButton(
                            key: Key('lunas_kas_${d.id}'),
                            tooltip: d.lunas ? 'Tandai belum lunas' : 'Tandai lunas',
                            icon: Icon(d.lunas
                                ? Icons.undo_outlined
                                : Icons.check_outlined),
                            onPressed: () => _tandaiLunas(d, !d.lunas),
                          ),
                          IconButton(
                            key: Key('hapus_kas_${d.id}'),
                            tooltip: 'Hapus',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _hapus(d),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
