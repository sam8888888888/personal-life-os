/// FR-94 — Layar "Hafalan (hifz)".
///
/// Menambah hafalan per juz/surah, memilih status (baru, murajaah, perlu
/// diulang, kuat), mengatur **jadwal ulangan versi pengguna sendiri**, dan
/// menandai "sudah diulang" (menyegarkan tanggal terakhir diulang).
library;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/hifz.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';

class HifzScreen extends ConsumerStatefulWidget {
  const HifzScreen({super.key, this.db, this.sekarang});

  final AppDatabase? db;
  final DateTime? sekarang;

  @override
  ConsumerState<HifzScreen> createState() => _HifzScreenState();
}

class _HifzScreenState extends ConsumerState<HifzScreen> {
  AppDatabase get _db => widget.db ?? ref.read(databaseProvider);

  final TextEditingController _nama = TextEditingController();
  final TextEditingController _nomor = TextEditingController();
  final TextEditingController _catatan = TextEditingController();
  final TextEditingController _ulang = TextEditingController(text: '7');

  String _jenis = 'surah';
  String _status = 'baru';

  bool _memuat = true;
  List<HafalanData> _daftar = const [];
  String? _pesan;

  DateTime get _sekarang => widget.sekarang ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _nama.dispose();
    _nomor.dispose();
    _catatan.dispose();
    _ulang.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final daftar = await (_db.select(_db.hafalan)
          ..orderBy([(t) => OrderingTerm.desc(t.terakhir)]))
        .get();
    if (!mounted) return;
    setState(() {
      _daftar = daftar;
      _memuat = false;
    });
  }

  Future<void> _simpan() async {
    final nomor = int.tryParse(_nomor.text.trim());
    var nama = _nama.text.trim();
    if (nama.isEmpty) {
      if (nomor == null) {
        setState(() =>
            _pesan = 'Tulis nama juz/surah atau nomornya dulu.');
        return;
      }
      nama = _jenis == 'juz' ? namaBawaanJuz(nomor) : namaBawaanSurah(nomor);
    }
    final interval = int.tryParse(_ulang.text.trim()) ?? 7;

    await _db.into(_db.hafalan).insert(HafalanCompanion.insert(
          jenis: Value(_jenis),
          nama: nama,
          nomor: Value(nomor),
          status: Value(_status),
          terakhir: _sekarang,
          ulangSetiapHari: Value(interval < 0 ? 0 : interval),
          catatan:
              Value(_catatan.text.trim().isEmpty ? null : _catatan.text.trim()),
        ));
    _nama.clear();
    _nomor.clear();
    _catatan.clear();
    await _muat();
    if (!mounted) return;
    setState(() => _pesan = 'Hafalan “$nama” tersimpan.');
  }

  Future<void> _tandaiDiulang(HafalanData h) async {
    await (_db.update(_db.hafalan)..where((t) => t.id.equals(h.id))).write(
      HafalanCompanion(
        terakhir: Value(_sekarang),
        status: Value(h.status == 'baru' ? 'murajaah' : h.status),
        diubahPada: Value(_sekarang),
      ),
    );
    await _muat();
    if (!mounted) return;
    setState(() => _pesan = '“${h.nama}” tercatat diulang hari ini.');
  }

  Future<void> _ubahStatus(HafalanData h, String status) async {
    await (_db.update(_db.hafalan)..where((t) => t.id.equals(h.id))).write(
      HafalanCompanion(status: Value(status), diubahPada: Value(_sekarang)),
    );
    await _muat();
  }

  Future<void> _hapus(HafalanData h) async {
    await (_db.delete(_db.hafalan)..where((t) => t.id.equals(h.id))).go();
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) return const Center(child: CircularProgressIndicator());
    final tema = Theme.of(context);
    final ringkas = ringkasHafalan(_daftar, _sekarang);

    return Scaffold(
      appBar: AppBar(title: const Text('Hafalan (hifz)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tambah hafalan', style: tema.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final j in ['surah', 'juz'])
                        ChoiceChip(
                          key: Key('pilih_jenis_hafalan_$j'),
                          label: Text(j == 'juz' ? 'Per juz' : 'Per surah'),
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
                          key: const Key('isi_nama_hafalan'),
                          controller: _nama,
                          decoration: const InputDecoration(
                            labelText: 'Nama (mis. Al-Baqarah)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const Key('isi_nomor_hafalan'),
                          controller: _nomor,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Nomor',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in statusHafalan)
                        ChoiceChip(
                          key: Key('pilih_status_hafalan_${s.nilaiDb}'),
                          label: Text(s.label),
                          selected: _status == s.nilaiDb,
                          onSelected: (_) => setState(() => _status = s.nilaiDb),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('isi_ulang_hafalan'),
                          controller: _ulang,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Diulang setiap (hari)',
                            hintText: '0 = tanpa jadwal',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          key: const Key('isi_catatan_hafalan'),
                          controller: _catatan,
                          decoration: const InputDecoration(
                            labelText: 'Catatan (boleh kosong)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('simpan_hafalan'),
                    onPressed: _simpan,
                    icon: const Icon(Icons.add),
                    label: const Text('Simpan hafalan'),
                  ),
                  if (_pesan != null) ...[
                    const SizedBox(height: 8),
                    Text(_pesan!, key: const Key('pesan_hafalan')),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            key: const Key('ringkas_hafalan'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ringkasan', style: tema.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(kalimatRingkasHafalan(ringkas),
                      key: const Key('kalimat_ringkas_hafalan')),
                  const SizedBox(height: 6),
                  for (final s in statusHafalan)
                    Text(
                      '${s.label}: ${ringkas.perStatus[s.nilaiDb] ?? 0}',
                      key: Key('hitung_status_${s.nilaiDb}'),
                      style: tema.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Daftar hafalan', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_daftar.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada hafalan yang tercatat.'),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final h in _daftar) _baris(h),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _baris(HafalanData h) {
    final perlu = perluDiulangSekarang(
      terakhir: h.terakhir,
      ulangSetiapHari: h.ulangSetiapHari,
      sekarang: _sekarang,
    );
    final jadwal = jadwalUlangBerikutnya(
        terakhir: h.terakhir, ulangSetiapHari: h.ulangSetiapHari);
    return ListTile(
      key: Key('hafalan_${h.id}'),
      leading: CircleAvatar(
        backgroundColor: warnaStatusHafalan(h.status),
        radius: 14,
        child: Text(
          h.jenis == 'juz' ? 'J' : 'S',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      title: Text(h.nama),
      subtitle: Text([
        labelStatusHafalan(h.status),
        'terakhir diulang ${fmtTanggalId(h.terakhir)}',
        if (jadwal == null)
          'tanpa jadwal ulangan'
        else
          'ulangan berikutnya ${fmtTanggalId(jadwal)}'
              '${perlu ? ' (sudah masuk jadwal)' : ''}',
        if (h.catatan != null && h.catatan!.isNotEmpty) h.catatan!,
      ].join(' · ')),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            key: Key('diulang_hafalan_${h.id}'),
            tooltip: 'Tandai sudah diulang',
            icon: const Icon(Icons.refresh),
            onPressed: () => _tandaiDiulang(h),
          ),
          PopupMenuButton<String>(
            key: Key('status_hafalan_${h.id}'),
            tooltip: 'Ubah status',
            onSelected: (v) => _ubahStatus(h, v),
            itemBuilder: (_) => [
              for (final s in statusHafalan)
                PopupMenuItem(value: s.nilaiDb, child: Text(s.label)),
            ],
          ),
          IconButton(
            key: Key('hapus_hafalan_${h.id}'),
            tooltip: 'Hapus',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _hapus(h),
          ),
        ],
      ),
    );
  }
}
