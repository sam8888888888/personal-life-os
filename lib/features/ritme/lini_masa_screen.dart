/// FR-140 — Life Timeline (signature).
///
/// Kriteria terima PRD: "Timeline akurat dari data nyata; menampilkan rangkuman
/// 'apa yang terjadi bulan ini'". Kejadian diambil dari tabel masing-masing
/// modul (lewat [HidupRepository]) dan tiap baris menyebut asal datanya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/timeline/lini_masa.dart';
import '../../core/utils/tanggal_utils.dart';
import '../ritme/ritme_providers.dart';

/// Modul yang bisa disaring di lini masa.
const List<String> modulLiniMasa = [
  'uang',
  'tugas',
  'kesehatan',
  'pengetahuan',
  'ibadah',
  'rumah',
  'dokumen',
];

class LiniMasaScreen extends ConsumerStatefulWidget {
  const LiniMasaScreen({super.key});

  @override
  ConsumerState<LiniMasaScreen> createState() => _LiniMasaScreenState();
}

class _LiniMasaScreenState extends ConsumerState<LiniMasaScreen> {
  int _hari = 365;
  String? _modul;
  String _cari = '';
  List<BulanLiniMasa> _bulan = const [];
  String _ringkas = '';
  bool _siap = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    muat();
  }

  Future<void> muat() async {
    try {
      final repo = ref.read(repoHidupProvider);
      final sampai = DateTime.now();
      final dari = sampai.subtract(Duration(days: _hari));
      final kejadian = await repo.peristiwa(dari: dari, sampai: sampai);
      if (!mounted) return;
      setState(() {
        _bulan = susunLiniMasa(
          peristiwa: kejadian,
          modul: _modul,
          cari: _cari,
        );
        _ringkas = ringkasBulanIni(kejadian, sampai);
        _siap = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = 'Lini masa belum bisa dibaca: $e';
        _siap = true;
      });
    }
  }

  String _labelModul(String m) =>
      PeristiwaHidup(tanggal: DateTime.now(), modul: m, judul: '').labelModul;

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Lini masa hidup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Card(
            child: ListTile(
              key: const Key('lini_ringkas'),
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Apa yang terjadi bulan ini'),
              subtitle: Text(_ringkas),
            ),
          ),
          TextField(
            key: const Key('lini_cari'),
            decoration: const InputDecoration(
              labelText: 'Cari kejadian',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              _cari = v;
              muat();
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                key: const Key('lini_saring_semua'),
                label: const Text('Semua modul'),
                selected: _modul == null,
                onSelected: (_) {
                  _modul = null;
                  muat();
                },
              ),
              for (final m in modulLiniMasa)
                ChoiceChip(
                  key: Key('lini_saring_$m'),
                  label: Text(_labelModul(m)),
                  selected: _modul == m,
                  onSelected: (_) {
                    _modul = m;
                    muat();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final h in [30, 90, 365])
                ChoiceChip(
                  key: Key('lini_rentang_$h'),
                  label: Text(h >= 365 ? '1 tahun' : '$h hari'),
                  selected: _hari == h,
                  onSelected: (_) {
                    _hari = h;
                    muat();
                  },
                ),
            ],
          ),
          if (_galat != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_galat!, key: const Key('lini_galat')),
            ),
          const SizedBox(height: 8),
          if (_bulan.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.timeline_outlined),
                title: Text('Belum ada kejadian pada rentang ini'),
                subtitle: Text('Catatan dari semua modul akan tersusun di sini '
                    'secara otomatis.'),
              ),
            ),
          for (final b in _bulan) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Text(
                '${labelBulan(b.kunci)} · ${b.peristiwa.length} kejadian',
                key: Key('lini_bulan_${b.kunci}'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (var i = 0; i < b.peristiwa.length; i++)
              Card(
                key: Key('lini_peristiwa_${b.kunci}_$i'),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    child: Text('${b.peristiwa[i].tanggal.day}',
                        style: const TextStyle(fontSize: 11)),
                  ),
                  title: Text(b.peristiwa[i].judul),
                  subtitle: Text([
                    fmtTanggalPendekAman(b.peristiwa[i].tanggal),
                    b.peristiwa[i].labelModul,
                    if (b.peristiwa[i].keterangan.isNotEmpty)
                      b.peristiwa[i].keterangan,
                    'sumber: ${b.peristiwa[i].rujukan}',
                  ].join(' · ')),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
