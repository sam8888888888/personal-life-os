/// FR-114 — Peringatan Dini (watch) + pengaturan ambang batasnya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/kesehatan/peringatan_dini.dart';
import '../../core/providers/app_providers.dart';
import '../../data/repository/kesehatan_pemantau_repository.dart';
import '../../data/repository/pengaturan_repository.dart';

class PeringatanDiniScreen extends ConsumerStatefulWidget {
  const PeringatanDiniScreen({super.key});

  @override
  ConsumerState<PeringatanDiniScreen> createState() =>
      _PeringatanDiniScreenState();
}

class _PeringatanDiniScreenState extends ConsumerState<PeringatanDiniScreen> {
  AmbangPeringatan _ambang = const AmbangPeringatan();
  List<PeringatanDini> _daftar = const [];
  bool _siap = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final pengaturan = PengaturanRepository(ref.read(databaseProvider));
      _ambang = AmbangPeringatan.dariPeta({
        'minggu_berat_naik': await pengaturan.baca('minggu_berat_naik'),
        'persen_tidur_turun': await pengaturan.baca('persen_tidur_turun'),
        'persen_aktivitas_turun':
            await pengaturan.baca('persen_aktivitas_turun'),
        'kenaikan_sistolik': await pengaturan.baca('kenaikan_sistolik'),
      });
      final repo = KesehatanPemantauRepository(ref.read(databaseProvider));
      final hasil = susunPeringatanDini(
        sekarang: DateTime.now(),
        berat: await repo.berat(),
        tidur: await repo.tidur(),
        aktivitas: await repo.aktivitas(),
        sistolik: await repo.tekanan(),
        ambang: _ambang,
      );
      if (!mounted) return;
      setState(() {
        _daftar = hasil;
        _siap = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = 'Data belum bisa dibaca: $e';
        _siap = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peringatan dini'),
        actions: [
          IconButton(
            key: const Key('peringatan_ambang'),
            tooltip: 'Atur ambang batas',
            onPressed: _aturAmbang,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Bukan diagnosis'),
              subtitle: Text('Peringatan dihitung dari catatan aplikasi '
                  'dibanding kebiasaan sendiri. Bukan hasil pemeriksaan dan '
                  'bukan penilaian.'),
            ),
          ),
          if (_galat != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_galat!, key: const Key('peringatan_galat')),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text('Ambang saat ini: berat naik ${_ambang.mingguBeratNaik} '
                'minggu · tidur < ${_ambang.persenTidurTurun}% · '
                'aktivitas < ${_ambang.persenAktivitasTurun}% · '
                'sistolik +${_ambang.kenaikanSistolik} mmHg',
                key: const Key('peringatan_ambang_teks'),
                style: Theme.of(context).textTheme.bodySmall),
          ),
          if (_daftar.isEmpty)
            const Card(
              key: Key('peringatan_kosong'),
              child: ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('Belum ada yang perlu diperhatikan'),
                subtitle: Text('Belum ada pola yang melewati ambang. Ini bukan '
                    'berarti sehat atau tidak sehat — hanya belum ada polanya.'),
              ),
            ),
          for (final p in _daftar)
            Card(
              key: Key('peringatan_${p.jenis.name}'),
              child: ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(p.judul),
                subtitle: Text('${p.dasar}\n${p.saran}'),
                isThreeLine: true,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _aturAmbang() async {
    var kerja = _ambang;
    final simpan = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) {
          Widget baris(String label, int nilai, int min, int max,
                  int langkah, AmbangPeringatan Function(int) ubah,
                  String kunci) =>
              Row(
                children: [
                  Expanded(child: Text('$label: $nilai')),
                  IconButton(
                    key: Key('${kunci}_kurang'),
                    onPressed: nilai <= min
                        ? null
                        : () => setDialog(() => kerja = ubah(nilai - langkah)),
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    key: Key('${kunci}_tambah'),
                    onPressed: nilai >= max
                        ? null
                        : () => setDialog(() => kerja = ubah(nilai + langkah)),
                    icon: const Icon(Icons.add),
                  ),
                ],
              );
          return AlertDialog(
            title: const Text('Ambang peringatan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  baris('Minggu berat naik', kerja.mingguBeratNaik, 2, 12, 1,
                      (v) => kerja.salin(mingguBeratNaik: v), 'ambang_minggu'),
                  baris('Tidur (%)', kerja.persenTidurTurun, 50, 100, 5,
                      (v) => kerja.salin(persenTidurTurun: v), 'ambang_tidur'),
                  baris('Aktivitas (%)', kerja.persenAktivitasTurun, 30, 100, 5,
                      (v) => kerja.salin(persenAktivitasTurun: v), 'ambang_akt'),
                  baris('Sistolik (mmHg)', kerja.kenaikanSistolik, 5, 60, 1,
                      (v) => kerja.salin(kenaikanSistolik: v), 'ambang_sistolik'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                key: const Key('ambang_simpan'),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
    if (simpan != true) return;
    final pengaturan = PengaturanRepository(ref.read(databaseProvider));
    for (final e in kerja.kePeta().entries) {
      await pengaturan.simpan(e.key, '${e.value}');
    }
    await _muat();
  }
}
