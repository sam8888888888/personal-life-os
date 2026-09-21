/// FR-52 — Layar "Multi-mata uang": mata uang per tagihan + konversi ke Rupiah.
///
/// Kurs diisi PAPI sendiri (aplikasi tidak mengklaim tahu kurs hari ini) dan
/// selalu ditampilkan asal + waktu pembaruannya. Bila kurs suatu mata uang
/// belum diisi, totalnya TIDAK dikonversi dan dikatakan terus terang.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drift/drift.dart' hide Column;

import '../../core/laporan/kurs.dart';
import '../../core/providers/app_providers.dart';
import '../../data/database/database.dart';
import '../../data/repository/pengaturan_repository.dart';
import '../../data/repository/tagihan_repository.dart';

class MataUangScreen extends ConsumerStatefulWidget {
  const MataUangScreen({super.key, this.db, this.sekarang});

  final AppDatabase? db;
  final DateTime? sekarang;

  @override
  ConsumerState<MataUangScreen> createState() => _MataUangScreenState();
}

class _MataUangScreenState extends ConsumerState<MataUangScreen> {
  AppDatabase get _db => widget.db ?? ref.read(databaseProvider);

  late final TagihanRepository _repo = TagihanRepository(_db);
  late final TabelKurs _tabel = TabelKurs(PengaturanRepository(_db));

  bool _memuat = true;
  List<TagihanData> _tagihan = const [];
  Map<String, Kurs> _kurs = const {};
  final Map<String, TextEditingController> _kontrol = {};
  final Map<String, TextEditingController> _sumber = {};

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    for (final c in _kontrol.values) {
      c.dispose();
    }
    for (final c in _sumber.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final semua = await _repo.ambilSemua();
    final aktif = semua.where((t) => t.statusAktif && !t.lunas).toList();
    final kurs = await _tabel.semua();
    for (final m in mataUangDidukung) {
      if (m.utama) continue;
      final k = kurs[m.kode];
      final nilai = _kontrol.putIfAbsent(m.kode, () => TextEditingController());
      if (k != null && nilai.text.isEmpty) {
        nilai.text = k.rupiahPerUnit.toStringAsFixed(
            k.rupiahPerUnit == k.rupiahPerUnit.roundToDouble() ? 0 : 2);
      }
      final sumber =
          _sumber.putIfAbsent(m.kode, () => TextEditingController());
      if (k != null && sumber.text.isEmpty) sumber.text = k.sumber;
    }
    if (!mounted) return;
    setState(() {
      _tagihan = aktif;
      _kurs = kurs;
      _memuat = false;
    });
  }

  Future<void> _ubahMataUang(TagihanData t, String kode) async {
    await _repo.ubah(
      TagihanCompanion(
        kodeMataUang: Value(kode),
        diubahPada: Value(DateTime.now()),
      ),
      id: t.id,
    );
    await _muat();
  }

  Future<void> _simpanKurs(InfoMataUang m) async {
    final teks = (_kontrol[m.kode]?.text ?? '').replaceAll(',', '.');
    final nilai = double.tryParse(teks.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (nilai == null || nilai <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        key: const Key('hasil_kurs'),
        content: Text('Isi kurs ${m.kode} dengan angka lebih besar dari nol.'),
      ));
      return;
    }
    final sumber = (_sumber[m.kode]?.text ?? '').trim();
    await _tabel.simpan(Kurs(
      kode: m.kode,
      rupiahPerUnit: nilai,
      sumber: sumber.isEmpty ? 'diisi sendiri' : sumber,
      diperbarui: widget.sekarang ?? DateTime.now(),
    ));
    await _muat();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      key: const Key('hasil_kurs'),
      content: Text('Kurs ${m.kode} disimpan.'),
    ));
  }

  Future<void> _hapusKurs(InfoMataUang m) async {
    await _tabel.hapus(m.kode);
    _kontrol[m.kode]?.clear();
    _sumber[m.kode]?.clear();
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) return const Center(child: CircularProgressIndicator());
    final tema = Theme.of(context);
    final ringkas = ringkasPerMataUang([
      for (final t in _tagihan)
        (kode: t.kodeMataUang, satuanTerkecil: t.jumlahSen ?? 0),
    ], _kurs);
    final totalRupiah = ringkas
        .where((r) => r.totalRupiahSen != null)
        .fold<int>(0, (a, r) => a + r.totalRupiahSen!);
    final adaTanpaKurs = ringkas.any((r) => !r.adaKurs && r.kode != 'IDR');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Multi-mata uang', style: tema.textTheme.titleMedium),
                const SizedBox(height: 6),
                const Text(
                    'Setiap tagihan boleh memakai mata uangnya sendiri. Total '
                    'di bawah dikonversi ke Rupiah memakai kurs yang Papi isi '
                    'sendiri.'),
                const SizedBox(height: 8),
                Text('Total tagihan aktif: ${fmtMataUang(totalRupiah, 'IDR')}',
                    key: const Key('total_rupiah'),
                    style: tema.textTheme.titleSmall),
                if (adaTanpaKurs)
                  Text(
                    'Sebagian mata uang belum punya kurs, jadi belum ikut '
                    'dihitung ke total di atas.',
                    key: const Key('catatan_kurs_kurang'),
                    style: tema.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
        if (ringkas.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rincian per mata uang',
                      style: tema.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final r in ringkas)
                    Padding(
                      key: Key('ringkas_${r.kode}'),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r.kode} · ${r.jumlahTagihan} tagihan'),
                          Text(
                            r.adaKurs || r.kode == 'IDR'
                                ? '${fmtMataUang(r.totalSatuanTerkecil, r.kode)} '
                                    '≈ ${fmtMataUang(r.totalRupiahSen ?? 0, 'IDR')}'
                                : '${fmtMataUang(r.totalSatuanTerkecil, r.kode)} '
                                    '· kurs belum diisi',
                            style: tema.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text('Mata uang tiap tagihan', style: tema.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Nominal tagihan selalu diartikan dalam mata uang yang dipilih di '
          'bawah ini.',
          style: tema.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (_tagihan.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada tagihan aktif yang belum lunas.'),
            ),
          ),
        for (final t in _tagihan)
          Card(
            key: Key('mata_uang_${t.id}'),
            child: ListTile(
              title: Text(t.nama),
              subtitle: Text(t.jumlahSen == null
                  ? 'nominal belum diisi'
                  : fmtMataUang(t.jumlahSen!, t.kodeMataUang)),
              trailing: DropdownButton<String>(
                key: Key('pilih_mata_uang_${t.id}'),
                value: infoMataUang(t.kodeMataUang)?.kode ?? 'IDR',
                items: [
                  for (final m in mataUangDidukung)
                    DropdownMenuItem(value: m.kode, child: Text(m.kode)),
                ],
                onChanged: (v) {
                  if (v != null) _ubahMataUang(t, v);
                },
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text('Kurs (diisi sendiri)', style: tema.textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Aplikasi tidak mengambil kurs dari internet dan tidak mengklaim '
          'tahu kurs hari ini. Isi kurs terakhir yang Papi ketahui beserta '
          'sumbernya.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        for (final m in mataUangDidukung.where((m) => !m.utama))
          Card(
            key: Key('kurs_${m.kode}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${m.kode} — ${m.nama}',
                      style: tema.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          key: Key('nilai_kurs_${m.kode}'),
                          controller: _kontrol[m.kode],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Rupiah per 1 unit',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          key: Key('sumber_kurs_${m.kode}'),
                          controller: _sumber[m.kode],
                          decoration: const InputDecoration(
                            labelText: 'Sumber (mis. Bank Indonesia)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(keteranganKurs(_kurs[m.kode]),
                      key: Key('keterangan_kurs_${m.kode}'),
                      style: tema.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonal(
                        key: Key('simpan_kurs_${m.kode}'),
                        onPressed: () => _simpanKurs(m),
                        child: const Text('Simpan kurs'),
                      ),
                      if (_kurs.containsKey(m.kode))
                        TextButton(
                          key: Key('hapus_kurs_${m.kode}'),
                          onPressed: () => _hapusKurs(m),
                          child: const Text('Hapus kurs'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
