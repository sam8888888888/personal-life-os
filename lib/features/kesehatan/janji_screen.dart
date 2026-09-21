/// FR-109 — Layar "Janji dokter, tes lab & kontrol".
///
/// Mencatat janji beserta tempat, pengingat berlapis (bawaan 7 hari & 1 hari
/// plus 2 jam sebelum), dan menandai janji yang sudah selesai. Layar ini juga
/// menunjukkan **kapan saja** pengingatnya akan berbunyi, supaya Papi tidak
/// perlu menebak.
library;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/janji.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';

class JanjiScreen extends ConsumerStatefulWidget {
  const JanjiScreen({super.key, this.db, this.sekarang});

  final AppDatabase? db;
  final DateTime? sekarang;

  @override
  ConsumerState<JanjiScreen> createState() => _JanjiScreenState();
}

class _JanjiScreenState extends ConsumerState<JanjiScreen> {
  AppDatabase get _db => widget.db ?? ref.read(databaseProvider);

  final TextEditingController _judul = TextEditingController();
  final TextEditingController _tempat = TextEditingController();
  final TextEditingController _catatan = TextEditingController();
  final TextEditingController _lead = TextEditingController(text: '7,1');
  final TextEditingController _jamPengingat = TextEditingController(text: '08:00');

  String _jenis = jenisJanji.first.nilaiDb;
  bool _duaJam = true;
  late DateTime _waktu;

  bool _memuat = true;
  List<JanjiKesehatanData> _daftar = const [];
  String? _pesan;

  DateTime get _sekarang => widget.sekarang ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final besok = _sekarang.add(const Duration(days: 1));
    _waktu = DateTime(besok.year, besok.month, besok.day, 9);
    _muat();
  }

  @override
  void dispose() {
    _judul.dispose();
    _tempat.dispose();
    _catatan.dispose();
    _lead.dispose();
    _jamPengingat.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final daftar = await (_db.select(_db.janjiKesehatan)
          ..orderBy([(t) => OrderingTerm.asc(t.waktu)]))
        .get();
    if (!mounted) return;
    setState(() {
      _daftar = daftar;
      _memuat = false;
    });
  }

  Future<void> _pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _waktu,
      firstDate: DateTime(_sekarang.year - 1),
      lastDate: DateTime(_sekarang.year + 5),
    );
    if (hasil == null) return;
    setState(() => _waktu = DateTime(
        hasil.year, hasil.month, hasil.day, _waktu.hour, _waktu.minute));
  }

  Future<void> _pilihJam() async {
    final hasil = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _waktu.hour, minute: _waktu.minute),
    );
    if (hasil == null) return;
    setState(() =>
        _waktu = DateTime(_waktu.year, _waktu.month, _waktu.day, hasil.hour, hasil.minute));
  }

  Future<void> _simpan() async {
    final judul = _judul.text.trim();
    if (judul.isEmpty) {
      setState(() => _pesan = 'Isi judul janjinya dulu.');
      return;
    }
    await _db.into(_db.janjiKesehatan).insert(JanjiKesehatanCompanion.insert(
          judul: judul,
          jenis: Value(_jenis),
          waktu: _waktu,
          tempat: Value(_tempat.text.trim().isEmpty ? null : _tempat.text.trim()),
          catatan: Value(_catatan.text.trim().isEmpty ? null : _catatan.text.trim()),
          pengingatHari: Value(_lead.text.trim().isEmpty ? '7,1' : _lead.text.trim()),
          ingatkanDuaJam: Value(_duaJam),
          jamPengingat:
              Value(_jamPengingat.text.trim().isEmpty ? '08:00' : _jamPengingat.text.trim()),
        ));
    _judul.clear();
    _tempat.clear();
    _catatan.clear();
    await _muat();
    if (!mounted) return;
    setState(() => _pesan = 'Janji “$judul” tersimpan.');
  }

  Future<void> _tandaiSelesai(JanjiKesehatanData j, bool selesai) async {
    await (_db.update(_db.janjiKesehatan)..where((t) => t.id.equals(j.id)))
        .write(JanjiKesehatanCompanion(
      selesai: Value(selesai),
      diubahPada: Value(_sekarang),
    ));
    await _muat();
  }

  Future<void> _hapus(JanjiKesehatanData j) async {
    await (_db.delete(_db.janjiKesehatan)..where((t) => t.id.equals(j.id))).go();
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) return const Center(child: CircularProgressIndicator());
    final tema = Theme.of(context);
    final pengingatContoh = waktuPengingatJanji(
      _waktu,
      leadHari: _lead.text,
      duaJam: _duaJam,
      jamPengingat: _jamPengingat.text,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Janji dokter & kontrol')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Catat janji baru', style: tema.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('isi_judul_janji'),
                    controller: _judul,
                    decoration: const InputDecoration(
                      labelText: 'Judul (mis. Kontrol tekanan darah)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final j in jenisJanji)
                        ChoiceChip(
                          key: Key('pilih_jenis_janji_${j.nilaiDb}'),
                          label: Text(j.label),
                          selected: _jenis == j.nilaiDb,
                          onSelected: (_) => setState(() => _jenis = j.nilaiDb),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('tanggal_janji'),
                        onPressed: _pilihTanggal,
                        icon: const Icon(Icons.event_outlined),
                        label: Text(fmtTanggalId(_waktu)),
                      ),
                      OutlinedButton.icon(
                        key: const Key('jam_janji'),
                        onPressed: _pilihJam,
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(
                            '${_waktu.hour.toString().padLeft(2, '0')}:${_waktu.minute.toString().padLeft(2, '0')}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('isi_tempat_janji'),
                    controller: _tempat,
                    decoration: const InputDecoration(
                      labelText: 'Tempat (mis. Klinik Sehat)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('isi_catatan_janji'),
                    controller: _catatan,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (boleh dikosongkan)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('lead_janji'),
                          controller: _lead,
                          decoration: const InputDecoration(
                            labelText: 'Pengingat (hari sebelum)',
                            hintText: 'mis. 7,1',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const Key('jam_pengingat_janji'),
                          controller: _jamPengingat,
                          decoration: const InputDecoration(
                            labelText: 'Jam pengingat',
                            hintText: '08:00',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    key: const Key('dua_jam_janji'),
                    contentPadding: EdgeInsets.zero,
                    value: _duaJam,
                    onChanged: (v) => setState(() => _duaJam = v),
                    title: const Text('Tambahkan pengingat 2 jam sebelum'),
                  ),
                  if (pengingatContoh.isNotEmpty)
                    Text(
                      'Pengingat yang akan berbunyi: '
                      '${pengingatContoh.map((t) => '${fmtTanggalId(t)} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}').join(' · ')}',
                      key: const Key('daftar_pengingat_janji'),
                      style: tema.textTheme.bodySmall,
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('simpan_janji'),
                    onPressed: _simpan,
                    icon: const Icon(Icons.add),
                    label: const Text('Simpan janji'),
                  ),
                  if (_pesan != null) ...[
                    const SizedBox(height: 8),
                    Text(_pesan!, key: const Key('pesan_janji')),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Daftar janji', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_daftar.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada janji tercatat.'),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final j in _daftar)
                    ListTile(
                      key: Key('janji_${j.id}'),
                      leading: Icon(j.selesai
                          ? Icons.check_circle_outline
                          : Icons.event_available_outlined),
                      title: Text('${j.judul} · ${labelJenisJanji(j.jenis)}'),
                      subtitle: Text([
                        '${fmtTanggalId(j.waktu)} '
                            '${j.waktu.hour.toString().padLeft(2, '0')}:${j.waktu.minute.toString().padLeft(2, '0')}',
                        if (j.tempat != null && j.tempat!.isNotEmpty) j.tempat!,
                        'pengingat ${j.pengingatHari}'
                            '${j.ingatkanDuaJam ? ' + 2 jam' : ''}',
                        if (j.selesai) 'sudah selesai',
                      ].join(' · ')),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            key: Key('selesai_janji_${j.id}'),
                            tooltip: j.selesai
                                ? 'Tandai belum selesai'
                                : 'Tandai selesai',
                            icon: Icon(j.selesai
                                ? Icons.undo_outlined
                                : Icons.check_outlined),
                            onPressed: () => _tandaiSelesai(j, !j.selesai),
                          ),
                          IconButton(
                            key: Key('hapus_janji_${j.id}'),
                            tooltip: 'Hapus',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _hapus(j),
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
