/// FR-141 — Personal Analytics.
///
/// Kriteria terima PRD: "Tiap angka dapat ditelusuri ke data asalnya (tidak ada
/// angka misterius)." Karena itu setiap kartu metrik menampilkan baris
/// **sumber** dari [MetrikAnalitik.sumber].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analitik/analitik_hidup.dart';
import '../../core/utils/uang_utils.dart';
import '../ritme/ritme_providers.dart';

class AnalitikScreen extends ConsumerStatefulWidget {
  const AnalitikScreen({super.key});

  @override
  ConsumerState<AnalitikScreen> createState() => _AnalitikScreenState();
}

class _AnalitikScreenState extends ConsumerState<AnalitikScreen> {
  int _hari = 30;
  final Set<String> _saring = <String>{};
  List<MetrikAnalitik> _metrik = const [];
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
      final bahan = await repo.bahan(dari: dari, sampai: sampai, hari: _hari);
      if (!mounted) return;
      setState(() {
        _metrik = susunAnalitik(bahan, saringKelompok: _saring);
        _siap = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = 'Angka belum bisa dihitung: $e';
        _siap = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final kelompok = <String, List<MetrikAnalitik>>{};
    for (final m in _metrik) {
      kelompok.putIfAbsent(m.kelompok, () => []).add(m);
    }
    final semuaKelompok = kelompokAnalitik(_metrik);
    return Scaffold(
      appBar: AppBar(title: const Text('Analitik pribadi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: Text('Ringkasan ${labelRentang(_hari)} terakhir'),
              subtitle: const Text('Semua angka dihitung dari catatan aplikasi. '
                  'Setiap kartu menyebut tabel asalnya.'),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final h in rentangAnalitik)
                ChoiceChip(
                  key: Key('analitik_rentang_$h'),
                  label: Text(labelRentang(h)),
                  selected: _hari == h,
                  onSelected: (_) {
                    setState(() => _hari = h);
                    muat();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_galat != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_galat!, key: const Key('analitik_galat')),
            ),
          if (_metrik.isEmpty)
            Card(
              key: const Key('analitik_kosong'),
              child: ListTile(
                leading: const Icon(Icons.query_stats_outlined),
                title: const Text('Belum ada angka pada rentang ini'),
                subtitle: Text('Catat aktivitas, transaksi, atau tugas dulu — '
                    'analitik mengikuti data yang ada (${labelRentang(_hari)}).'),
              ),
            ),
          for (final nama in kelompok.keys) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Text(nama,
                  key: Key('analitik_kelompok_$nama'),
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final m in kelompok[nama]!)
              Card(
                key: Key('analitik_metrik_${m.nama.replaceAll(' ', '_')}'),
                child: ListTile(
                  title: Text(m.nama),
                  trailing: Text(
                    m.satuanUangSen != null
                        ? fmtRpDariSen(m.satuanUangSen!)
                        : m.nilai,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  subtitle: Text(
                    'sumber: ${m.sumber}',
                    key: Key(
                        'analitik_sumber_${m.nama.replaceAll(' ', '_')}'),
                  ),
                ),
              ),
          ],
          if (semuaKelompok.isEmpty && _metrik.isNotEmpty)
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
