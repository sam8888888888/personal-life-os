/// FR-143 — Layar "Ramalan saldo" (Forecast).
///
/// PRD: "Proyeksi menampilkan asumsi & rentang (bukan satu angka mutlak)".
/// Karena itu setiap bulan menampilkan tiga angka (pesimis · tengah · optimis)
/// dan daftar asumsi yang dipakai, plus peringatan bila ada bulan yang
/// saldo pesimisnya minus.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analitik/ramalan_saldo.dart';
import '../../core/providers/batch9_providers.dart';
import '../../core/utils/uang_utils.dart';

class RamalanSaldoScreen extends ConsumerStatefulWidget {
  const RamalanSaldoScreen({super.key});

  @override
  ConsumerState<RamalanSaldoScreen> createState() => _RamalanSaldoScreenState();
}

class _RamalanSaldoScreenState extends ConsumerState<RamalanSaldoScreen> {
  RamalanSaldo? _ramalan;
  String? _galat;
  bool _siap = false;
  int _bulan = 4;

  @override
  void initState() {
    super.initState();
    muat();
  }

  Future<void> muat() async {
    try {
      final r = await ref.read(repoPintarProvider).ramalan(jumlahBulan: _bulan);
      if (!mounted) return;
      setState(() {
        _ramalan = r;
        _siap = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = 'Ramalan belum bisa dihitung: $e';
        _siap = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final r = _ramalan;
    final minus = r?.bulanPertamaMinus;
    return Scaffold(
      appBar: AppBar(title: const Text('Ramalan saldo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.trending_up),
              title: Text('Mulai dari ${fmtRpDariSen(r?.saldoAwalSen ?? 0)}'),
              subtitle: const Text('Perkiraan, bukan janji: angkanya bergerak '
                  'sesuai catatan Papi.'),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final b in const [3, 4, 6])
                ChoiceChip(
                  key: Key('ramalan_rentang_$b'),
                  label: Text('$b bulan'),
                  selected: _bulan == b,
                  onSelected: (_) {
                    setState(() => _bulan = b);
                    muat();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_galat != null)
            Card(
              key: const Key('ramalan_galat'),
              child: ListTile(title: Text(_galat!)),
            ),
          if (minus != null)
            Card(
              key: const Key('ramalan_peringatan'),
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber_outlined),
                title: Text('Saldo bisa minus pada ${minus.label}'),
                subtitle: Text(
                    'Hitungan pesimis ${fmtRpDariSen(minus.saldoPesimisSen)}. '
                    'Angka tengah ${fmtRpDariSen(minus.saldoTengahSen)}.'),
              ),
            ),
          if (r != null)
            for (final b in r.bulan)
              Card(
                key: Key('ramalan_bulan_${b.bulan.year}-${b.bulan.month}'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.label,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text('Masuk ${fmtRpDariSen(b.masukSen)} · '
                          'keluar tetap ${fmtRpDariSen(b.keluarTetapSen)} · '
                          'perkiraan harian ${fmtRpDariSen(b.keluarVariabelSen)}'),
                      const SizedBox(height: 6),
                      Text(
                        'Saldo: ${fmtRpDariSen(b.saldoPesimisSen)} '
                        '(pesimis) · ${fmtRpDariSen(b.saldoTengahSen)} '
                        '(tengah) · ${fmtRpDariSen(b.saldoOptimisSen)} (optimis)',
                        key: Key('ramalan_nilai_${b.bulan.year}-${b.bulan.month}'),
                      ),
                    ],
                  ),
                ),
              ),
          if (r != null && r.tabrakan.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              key: const Key('ramalan_tabrakan'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tenggat bertabrakan',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    for (final t in r.tabrakan)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${t.tanggal.day}/${t.tanggal.month}/${t.tanggal.year}: '
                          '${t.nama.join(', ')} — total ${fmtRpDariSen(t.totalSen)}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (r != null) ...[
            const SizedBox(height: 8),
            Card(
              key: const Key('ramalan_asumsi'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Asumsi yang dipakai',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    for (final a in r.asumsi)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $a'),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (r != null && r.belumBisa.isNotEmpty)
            Card(
              key: const Key('ramalan_belum_bisa'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yang belum bisa diramal',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    for (final b in r.belumBisa)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $b'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
