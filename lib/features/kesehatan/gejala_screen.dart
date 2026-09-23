/// SDD v19 Gelombang 2 — Layar log gejala.
///
/// Yang ditonjolkan di layar: **frekuensi**. Inilah bahan mentah mesin pola
/// ("dari 14 catatan sakit kepala, 11 hari kurang tidur"), yang nanti akan
/// disandingkan dengan pemicu lewat tabel `tautan`.
///
/// Aplikasi tidak menyebut gejala ini ringan/berat secara klinis; `berat`
/// adalah persepsi pengguna 1–5.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/kesehatan_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/gejala_repository.dart';

class GejalaScreen extends ConsumerStatefulWidget {
  const GejalaScreen({super.key});

  @override
  ConsumerState<GejalaScreen> createState() => _GejalaScreenState();
}

class _GejalaScreenState extends ConsumerState<GejalaScreen> {
  final TextEditingController _nama = TextEditingController();
  final TextEditingController _catatan = TextEditingController();

  DateTime _mulai = DateTime.now();
  int? _berat;
  String? _lokasi;

  List<GejalaData> _daftar = const <GejalaData>[];
  List<FrekuensiGejala> _frekuensi = const <FrekuensiGejala>[];
  bool _memuat = true;
  String? _pesan;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _nama.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final GejalaRepository repo = ref.read(repoGejalaProvider);
      final List<GejalaData> d = await repo.daftar();
      final List<FrekuensiGejala> f = await repo.palingSering();
      if (!mounted) return;
      setState(() {
        _daftar = d;
        _frekuensi = f;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _pesan = 'Daftar gejala tidak bisa dibuka: $e';
      });
    }
  }

  Future<void> _pilihMulai() async {
    final DateTime? pilih = await showDatePicker(
      context: context,
      initialDate: _mulai,
      firstDate: DateTime(_mulai.year - 5),
      lastDate: DateTime(_mulai.year + 1),
    );
    if (pilih == null) return;
    setState(() => _mulai = DateTime(pilih.year, pilih.month, pilih.day,
        _mulai.hour, _mulai.minute));
  }

  Future<void> _simpan() async {
    setState(() => _pesan = null);
    try {
      await ref.read(repoGejalaProvider).tambah(
            nama: _nama.text,
            mulai: _mulai,
            berat: _berat,
            lokasiTubuh: _lokasi,
            catatan: _catatan.text.trim().isEmpty ? null : _catatan.text,
          );
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.gejala,
        aksi: AksiAudit.buat,
        entitas: 'gejala',
        ringkas:
            'Gejala ${_nama.text.trim()} dicatat (${fmtTanggalAman(_mulai)}).',
      );
      _nama.clear();
      _catatan.clear();
      setState(() {
        _berat = null;
        _lokasi = null;
      });
      await _muat();
      if (!mounted) return;
      setState(() => _pesan = 'Gejala tersimpan.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Catatan Gejala')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: <Widget>[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Catat gejala', style: tema.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('gejala_nama'),
                    controller: _nama,
                    decoration: const InputDecoration(
                      labelText: 'Gejala apa?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      for (final String g in namaGejalaUmum)
                        ActionChip(
                          label: Text(g),
                          onPressed: () => setState(() => _nama.text = g),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('gejala_mulai'),
                    onPressed: _pilihMulai,
                    icon: const Icon(Icons.schedule),
                    label: Text('Mulai: ${fmtTanggalAman(_mulai)}'),
                  ),
                  const SizedBox(height: 8),
                  Text('Seberapa mengganggu (1 ringan – 5 berat), '
                      'menurut Papi sendiri:', style: tema.textTheme.bodySmall),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      for (int i = 1; i <= 5; i++)
                        ChoiceChip(
                          key: Key('gejala_berat_$i'),
                          label: Text('$i'),
                          selected: _berat == i,
                          onSelected: (_) => setState(() => _berat = i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      for (final String l in lokasiTubuhGejala)
                        ChoiceChip(
                          key: Key('gejala_lokasi_$l'),
                          label: Text(l),
                          selected: _lokasi == l,
                          onSelected: (_) => setState(
                              () => _lokasi = _lokasi == l ? null : l),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('gejala_catatan'),
                    controller: _catatan,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (mis. kurang tidur, habis makan apa)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('gejala_simpan'),
                    onPressed: _simpan,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Simpan gejala'),
                  ),
                  if (_pesan != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(_pesan!, key: const Key('gejala_pesan')),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Paling sering', style: tema.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  if (_frekuensi.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Belum ada catatan.', key: Key('gejala_frek_kosong')),
                    ),
                  for (final FrekuensiGejala f in _frekuensi)
                    Text(
                      '${f.nama}: ${f.jumlah}× (terakhir '
                      '${fmtTanggalAman(f.terakhir)})',
                      key: Key('gejala_frek_${f.nama}'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text(_memuat ? 'Memuat…' : 'Catatan: ${_daftar.length}',
                  key: const Key('gejala_judul_daftar'),
                  style: tema.textTheme.titleMedium),
            ),
          ),
          if (!_memuat && _daftar.isEmpty)
            const Card(
              margin: EdgeInsets.only(top: 12),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada gejala yang dicatat.',
                    key: Key('gejala_kosong')),
              ),
            ),
          for (final GejalaData g in _daftar)
            Card(
              key: Key('gejala_baris_${g.id}'),
              margin: const EdgeInsets.only(top: 12),
              child: ListTile(
                leading: const Icon(Icons.healing_outlined),
                title: Text(g.nama),
                subtitle: Text(
                  '${fmtTanggalAman(g.mulai)}'
                  '${g.durasiMenit == null ? '' : ' · ${g.durasiMenit} menit'}'
                  '${g.berat == null ? '' : ' · berat ${g.berat}/5'}'
                  '${g.selesai == null ? ' · masih berlangsung' : ''}',
                ),
                trailing: IconButton(
                  key: Key('gejala_hapus_${g.id}'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Hapus catatan ini',
                  onPressed: () async {
                    await ref.read(repoGejalaProvider).hapus(g.id);
                    await _muat();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
