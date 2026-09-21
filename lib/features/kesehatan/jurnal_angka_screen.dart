/// FR-105 — Layar "Jurnal kesehatan (angka)".
///
/// Mencatat tekanan darah (dua angka), detak jantung, gula darah, suhu,
/// saturasi oksigen, kolesterol, dan hasil lab lain + catatan satuan. Satuan
/// yang dipakai pengguna diingat per jenis. Menampilkan rata-rata & tren 30
/// hari dengan kalimat netral — aplikasi mencatat, tidak menilai.
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/kesehatan_ukur.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/pengaturan_repository.dart';

/// Kunci pengaturan: satuan yang dipakai per jenis.
const String kunciSatuanKesehatan = 'satuan_kesehatan';

/// Satuan yang diingat pengguna per jenis.
class SatuanTersimpan {
  const SatuanTersimpan(this.pengaturan);

  final PengaturanRepository pengaturan;

  Future<Map<String, String>> semua() async {
    final teks = await pengaturan.baca(kunciSatuanKesehatan);
    if (teks == null || teks.trim().isEmpty) return {};
    final Object? data = jsonDecode(teks);
    if (data is! Map) return {};
    return {
      for (final e in data.entries)
        if (e.value is String) e.key.toString(): e.value as String,
    };
  }

  Future<void> simpan(String jenis, String satuan) async {
    final peta = await semua();
    final bersih = satuan.trim();
    if (bersih.isEmpty) {
      peta.remove(jenis);
    } else {
      peta[jenis] = bersih;
    }
    await pengaturan.simpan(kunciSatuanKesehatan, jsonEncode(peta));
  }
}

double? _angka(String teks) {
  final bersih = teks.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
  if (bersih.isEmpty) return null;
  return double.tryParse(bersih);
}

class JurnalAngkaScreen extends ConsumerStatefulWidget {
  const JurnalAngkaScreen({super.key, this.db, this.sekarang});

  final AppDatabase? db;
  final DateTime? sekarang;

  @override
  ConsumerState<JurnalAngkaScreen> createState() => _JurnalAngkaScreenState();
}

class _JurnalAngkaScreenState extends ConsumerState<JurnalAngkaScreen> {
  AppDatabase get _db => widget.db ?? ref.read(databaseProvider);
  late final SatuanTersimpan _satuan =
      SatuanTersimpan(PengaturanRepository(_db));

  JenisCatatan _jenis = jenisCatatanKesehatan.first;
  final TextEditingController _utama = TextEditingController();
  final TextEditingController _kedua = TextEditingController();
  final TextEditingController _satuanTeks = TextEditingController();
  final TextEditingController _catatan = TextEditingController();
  final TextEditingController _jenisLab = TextEditingController();

  bool _memuat = true;
  List<CatatanKesehatanData> _riwayat = const [];
  Map<String, String> _satuanPeta = const {};
  String? _pesan;

  DateTime get _sekarang => widget.sekarang ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _utama.dispose();
    _kedua.dispose();
    _satuanTeks.dispose();
    _catatan.dispose();
    _jenisLab.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final semua = await (_db.select(_db.catatanKesehatan)
          ..orderBy([(t) => OrderingTerm.desc(t.waktu)]))
        .get();
    final satuan = await _satuan.semua();
    if (!mounted) return;
    setState(() {
      _riwayat = semua;
      _satuanPeta = satuan;
      _satuanTeks.text = satuan[_jenis.nilaiDb] ?? _jenis.satuanBawaan;
      _memuat = false;
    });
  }

  void _pilihJenis(JenisCatatan j) {
    setState(() {
      _jenis = j;
      _satuanTeks.text = _satuanPeta[j.nilaiDb] ?? j.satuanBawaan;
      _pesan = null;
    });
  }

  Future<void> _simpan() async {
    final utama = _angka(_utama.text);
    if (utama == null) {
      setState(() => _pesan = 'Isi angkanya dulu.');
      return;
    }
    final kedua = _jenis.berpasangan ? _angka(_kedua.text) : null;
    if (_jenis.berpasangan && kedua == null) {
      setState(() => _pesan = 'Isi kedua angkanya (${_jenis.label}).');
      return;
    }

    final satuan = _satuanTeks.text.trim();
    await _satuan.simpan(_jenis.nilaiDb, satuan);
    final catatanGabung = [
      if (_jenis.nilaiDb == 'lab' && _jenisLab.text.trim().isNotEmpty)
        'Jenis lab: ${_jenisLab.text.trim()}',
      if (_catatan.text.trim().isNotEmpty) _catatan.text.trim(),
    ].join(' · ');

    await _db.into(_db.catatanKesehatan).insert(CatatanKesehatanCompanion.insert(
          jenis: _jenis.nilaiDb,
          waktu: _sekarang,
          nilai: utama,
          nilaiKedua: Value(kedua),
          satuan: Value(satuan),
          catatan:
              Value(catatanGabung.isEmpty ? null : catatanGabung),
        ));
    _utama.clear();
    _kedua.clear();
    _catatan.clear();
    _jenisLab.clear();
    await _muat();
    if (!mounted) return;
    setState(() => _pesan = '${_jenis.label} tersimpan.');
  }

  Future<void> _hapus(CatatanKesehatanData baris) async {
    await (_db.delete(_db.catatanKesehatan)..where((t) => t.id.equals(baris.id)))
        .go();
    await _muat();
  }

  String _labelUntuk(String jenisDb) =>
      jenisCatatan(jenisDb)?.label ?? jenisDb;

  @override
  Widget build(BuildContext context) {
    if (_memuat) return const Center(child: CircularProgressIndicator());
    final tema = Theme.of(context);
    final ringkas = ringkasPerJenis(
      [
        for (final r in _riwayat)
          BarisUkur(
            jenis: r.jenis,
            nilai: r.nilai,
            nilaiKedua: r.nilaiKedua,
            waktu: r.waktu,
          ),
      ],
      sekarang: _sekarang,
    );
    final ringkasSekarang =
        ringkas.where((r) => r.jenis == _jenis.nilaiDb).toList();
    final r = ringkasSekarang.isEmpty ? null : ringkasSekarang.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Jurnal kesehatan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Catat angka baru', style: tema.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final j in jenisCatatanKesehatan)
                        ChoiceChip(
                          key: Key('jenis_catatan_${j.nilaiDb}'),
                          label: Text(j.label),
                          selected: _jenis.nilaiDb == j.nilaiDb,
                          onSelected: (_) => _pilihJenis(j),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('isi_nilai_utama'),
                          controller: _utama,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _jenis.berpasangan
                                ? 'Sistolik'
                                : _jenis.label,
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      if (_jenis.berpasangan) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: const Key('isi_nilai_kedua'),
                            controller: _kedua,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Diastolik',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('isi_satuan'),
                    controller: _satuanTeks,
                    decoration: const InputDecoration(
                      labelText: 'Satuan',
                      hintText: 'mis. mmHg, mg/dL',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_jenis.nilaiDb == 'lab') ...[
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('isi_jenis_lab'),
                      controller: _jenisLab,
                      decoration: const InputDecoration(
                        labelText: 'Jenis pemeriksaan (mis. HbA1c)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('isi_catatan_kesehatan'),
                    controller: _catatan,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (boleh dikosongkan)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('simpan_catatan_kesehatan'),
                    onPressed: _simpan,
                    icon: const Icon(Icons.add),
                    label: const Text('Simpan catatan'),
                  ),
                  if (_pesan != null) ...[
                    const SizedBox(height: 8),
                    Text(_pesan!, key: const Key('pesan_jurnal')),
                  ],
                ],
              ),
            ),
          ),
          if (r != null) ...[
            const SizedBox(height: 12),
            Card(
              key: Key('ringkas_catatan_${_jenis.nilaiDb}'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_jenis.label} — 30 hari terakhir',
                        style: tema.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text(
                      '${r.jumlah} catatan · rata-rata ${r.rataRata.toStringAsFixed(1)} '
                      '${_satuanPeta[_jenis.nilaiDb] ?? _jenis.satuanBawaan} · '
                      'terendah ${r.terendah.toStringAsFixed(1)} · tertinggi '
                      '${r.tertinggi.toStringAsFixed(1)}',
                      key: const Key('angka_ringkas_30_hari'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Terakhir ${r.terakhir.toStringAsFixed(1)}'
                      '${r.nilaiKeduaTerakhir == null ? '' : '/${r.nilaiKeduaTerakhir!.toStringAsFixed(0)}'}'
                      ' · ${labelArah(r.arah)}',
                      key: const Key('tren_terakhir'),
                    ),
                    const SizedBox(height: 6),
                    const Text(kalimatPerubahanNetral,
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text('Catatan tersimpan', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_riwayat.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada catatan angka kesehatan.'),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final b in _riwayat.take(15))
                    ListTile(
                      key: Key('riwayat_kesehatan_${b.id}'),
                      dense: true,
                      title: Text('${_labelUntuk(b.jenis)}: '
                          '${b.nilai.toStringAsFixed(0)}'
                          '${b.nilaiKedua == null ? '' : '/${b.nilaiKedua!.toStringAsFixed(0)}'}'
                          ' ${b.satuan}'),
                      subtitle: Text(
                          '${fmtTanggalId(b.waktu)}'
                          '${b.catatan == null || b.catatan!.isEmpty ? '' : ' · ${b.catatan}'}'),
                      trailing: IconButton(
                        key: Key('hapus_catatan_kesehatan_${b.id}'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _hapus(b),
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
