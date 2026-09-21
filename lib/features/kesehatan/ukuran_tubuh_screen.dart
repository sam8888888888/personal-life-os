/// FR-104 — Layar "Berat & ukuran tubuh".
///
/// Mencatat berat, lingkar perut, lemak tubuh, massa otot, detak jantung
/// istirahat; menampilkan IMT (dengan rumus & ambang yang disebut terbuka),
/// tren 30 hari, dan progres menuju target.
library;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/kesehatan_ukur.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/pengaturan_repository.dart';

/// Kunci pengaturan: tinggi badan & target berat (dipakai IMT + progres).
const String kunciTinggiBadan = 'tinggi_badan_cm';
const String kunciTargetBerat = 'target_berat_kg';

double? _angka(String teks) {
  final bersih = teks.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
  if (bersih.isEmpty) return null;
  return double.tryParse(bersih);
}

String fmtAngka(double nilai) {
  final bulat = nilai == nilai.roundToDouble();
  return bulat
      ? nilai.toStringAsFixed(0)
      : nilai.toStringAsFixed(1).replaceAll('.', ',');
}

class UkuranTubuhScreen extends ConsumerStatefulWidget {
  const UkuranTubuhScreen({super.key, this.db, this.sekarang});

  final AppDatabase? db;
  final DateTime? sekarang;

  @override
  ConsumerState<UkuranTubuhScreen> createState() => _UkuranTubuhScreenState();
}

class _UkuranTubuhScreenState extends ConsumerState<UkuranTubuhScreen> {
  AppDatabase get _db => widget.db ?? ref.read(databaseProvider);
  late final PengaturanRepository _pengaturan = PengaturanRepository(_db);

  final Map<String, TextEditingController> _nilai = {};
  final TextEditingController _tinggi = TextEditingController();
  final TextEditingController _target = TextEditingController();

  bool _memuat = true;
  List<UkuranTubuhData> _riwayat = const [];
  String? _pesan;

  DateTime get _sekarang => widget.sekarang ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    for (final j in jenisUkuranTubuh) {
      _nilai[j.nilaiDb] = TextEditingController();
    }
    _muat();
  }

  @override
  void dispose() {
    for (final c in _nilai.values) {
      c.dispose();
    }
    _tinggi.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final semua = await (_db.select(_db.ukuranTubuh)
          ..orderBy([(t) => OrderingTerm.desc(t.tanggal)]))
        .get();
    _tinggi.text = await _pengaturan.baca(kunciTinggiBadan) ?? '';
    _target.text = await _pengaturan.baca(kunciTargetBerat) ?? '';
    if (!mounted) return;
    setState(() {
      _riwayat = semua;
      _memuat = false;
    });
  }

  Future<void> _simpan(String jenisDb) async {
    final angka = _angka(_nilai[jenisDb]?.text ?? '');
    if (angka == null || angka <= 0) {
      setState(() => _pesan = 'Isi angkanya dulu (lebih besar dari nol).');
      return;
    }
    final j = jenisUkuranTubuh.firstWhere((x) => x.nilaiDb == jenisDb);
    await _db.into(_db.ukuranTubuh).insert(UkuranTubuhCompanion.insert(
          jenis: j.nilaiDb,
          nilai: angka,
          satuan: Value(j.satuan),
          tanggal: _sekarang,
        ));
    _nilai[jenisDb]?.clear();
    await _muat();
    if (!mounted) return;
    setState(() => _pesan = '${j.label} tersimpan.');
  }

  Future<void> _simpanPengaturan() async {
    await _pengaturan.simpan(kunciTinggiBadan, _tinggi.text.trim());
    await _pengaturan.simpan(kunciTargetBerat, _target.text.trim());
    if (!mounted) return;
    setState(() => _pesan = 'Tinggi badan & target disimpan.');
  }

  Future<void> _hapus(UkuranTubuhData baris) async {
    await (_db.delete(_db.ukuranTubuh)..where((t) => t.id.equals(baris.id))).go();
    await _muat();
  }

  double? get _beratTerakhir {
    for (final r in _riwayat) {
      if (r.jenis == 'berat') return r.nilai;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) return const Center(child: CircularProgressIndicator());
    final tema = Theme.of(context);
    final tinggi = _angka(_tinggi.text);
    final target = _angka(_target.text);
    final berat = _beratTerakhir;
    final nilaiImt = imt(berat, tinggi);
    final progres = persenProgres(
        titikAwal: _riwayat.isEmpty ? null : _riwayat.last.nilai,
        target: target,
        sekarang: berat);
    final ringkas = ringkasPerJenis(
      [
        for (final r in _riwayat)
          BarisUkur(jenis: r.jenis, nilai: r.nilai, waktu: r.tanggal),
      ],
      sekarang: _sekarang,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Berat & ukuran tubuh')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            key: const Key('kartu_imt'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Indeks Massa Tubuh (IMT)', style: tema.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    nilaiImt == null
                        ? 'Isi tinggi badan & berat badan dulu untuk menghitung IMT.'
                        : 'IMT ${fmtAngka(nilaiImt)} · ${labelImt(nilaiImt)}',
                    key: const Key('nilai_imt'),
                    style: tema.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rumus: berat (kg) ÷ tinggi (m)². Ambang yang dipakai adalah '
                    'ambang umum (Kemenkes RI, Asia-Pasifik) — sebutan ini bukan '
                    'diagnosis.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tinggi badan & target', style: tema.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('isi_tinggi'),
                          controller: _tinggi,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Tinggi (cm)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const Key('isi_target_berat'),
                          controller: _target,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Target berat (kg)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ponytail: tema aplikasi memakai minimumSize Size.fromHeight(48)
                  // (lebar minimum = tak hingga), jadi tombol WAJIB diberi lebar
                  // terikat di dalam Row — kalau tidak, Flutter melempar
                  // "BoxConstraints forces an infinite width".
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          key: const Key('simpan_pengaturan_ukuran'),
                          onPressed: _simpanPengaturan,
                          child: const Text('Simpan'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (berat != null)
                        Text('Berat terakhir: ${fmtAngka(berat)} kg',
                            key: const Key('berat_terakhir')),
                    ],
                  ),
                  if (progres != null) ...[
                    const SizedBox(height: 8),
                    Text('Progres menuju target: ${progres.toStringAsFixed(0)}%',
                        key: const Key('progres_target')),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: progres / 100),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final j in jenisUkuranTubuh) _kartuJenis(j, tema, ringkas),
          if (_pesan != null) ...[
            const SizedBox(height: 8),
            Text(_pesan!, key: const Key('pesan_ukuran')),
          ],
          const SizedBox(height: 12),
          Text('Riwayat terakhir', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_riwayat.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada catatan ukuran tubuh.'),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final r in _riwayat.take(12))
                    ListTile(
                      key: Key('riwayat_ukuran_${r.id}'),
                      dense: true,
                      title: Text(
                          '${jenisUkuranTubuh.firstWhere((j) => j.nilaiDb == r.jenis, orElse: () => jenisUkuranTubuh.first).label}: '
                          '${fmtAngka(r.nilai)} ${r.satuan}'),
                      subtitle: Text(fmtTanggalId(r.tanggal)),
                      trailing: IconButton(
                        key: Key('hapus_ukuran_${r.id}'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _hapus(r),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _kartuJenis(JenisUkuran j, ThemeData tema, List<RingkasJenis> ringkas) {
    final r = ringkas.where((x) => x.jenis == j.nilaiDb).toList();
    final ringkasJenis = r.isEmpty ? null : r.first;
    return Card(
      key: Key('jenis_${j.nilaiDb}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${j.label} (${j.satuan})', style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: Key('isi_${j.nilaiDb}'),
                    controller: _nilai[j.nilaiDb],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Angka baru',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FilledButton.tonal(
                    key: Key('simpan_${j.nilaiDb}'),
                    onPressed: () => _simpan(j.nilaiDb),
                    child: const Text('Catat'),
                  ),
                ),
              ],
            ),
            if (ringkasJenis != null) ...[
              const SizedBox(height: 8),
              Text(
                '30 hari: ${ringkasJenis.jumlah} catatan · rata-rata '
                '${fmtAngka(ringkasJenis.rataRata)} · terakhir '
                '${fmtAngka(ringkasJenis.terakhir)} (${labelArah(ringkasJenis.arah)})',
                key: Key('ringkas_${j.nilaiDb}'),
                style: tema.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
