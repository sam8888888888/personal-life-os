/// FR-146 — Layar "Tinjauan tahun" (Your Year in Life).
///
/// PRD: "Membutuhkan data ≥6 bulan; hasil hanya ditampilkan bila datanya cukup
/// (bukan dibuat-buat)". Bila belum cukup, layar hanya menampilkan pesan jujur
/// dari mesin [susunTinjauanTahun] — angka tidak dipaksa muncul.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analitik/tinjauan_tahun.dart';
import '../../core/providers/batch9_providers.dart';
import '../../core/utils/uang_utils.dart';

class TinjauanTahunScreen extends ConsumerStatefulWidget {
  const TinjauanTahunScreen({super.key, this.tahunAwal});

  final int? tahunAwal;

  @override
  ConsumerState<TinjauanTahunScreen> createState() =>
      _TinjauanTahunScreenState();
}

class _TinjauanTahunScreenState extends ConsumerState<TinjauanTahunScreen> {
  late int _tahun;
  TinjauanTahun? _hasil;
  String? _galat;
  bool _siap = false;

  @override
  void initState() {
    super.initState();
    _tahun = widget.tahunAwal ?? DateTime.now().year;
    muat();
  }

  Future<void> muat() async {
    setState(() => _siap = false);
    try {
      final h = await ref.read(repoPintarProvider).tinjauanTahun(tahun: _tahun);
      if (!mounted) return;
      setState(() {
        _hasil = h;
        _siap = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = 'Tinjauan tahun belum bisa dihitung: $e';
        _siap = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tahunIni = DateTime.now().year;
    return Scaffold(
      appBar: AppBar(title: const Text('Tinjauan tahun')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (var t = tahunIni; t >= tahunIni - 2; t--)
                ChoiceChip(
                  key: Key('tinjauan_tahun_$t'),
                  label: Text('$t'),
                  selected: _tahun == t,
                  onSelected: (_) {
                    setState(() => _tahun = t);
                    muat();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_siap)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_galat != null)
            Card(
              key: const Key('tinjauan_galat'),
              child: ListTile(title: Text(_galat!)),
            ),
          if (_siap && _hasil != null && !_hasil!.cukupData)
            Card(
              key: const Key('tinjauan_belum_cukup'),
              child: ListTile(
                leading: const Icon(Icons.hourglass_empty),
                title: const Text('Datanya belum cukup'),
                subtitle: Text(_hasil!.pesan),
              ),
            ),
          if (_siap && _hasil != null && _hasil!.cukupData) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: Text('Sepanjang $_tahun'),
                subtitle: Text(_hasil!.pesan),
              ),
            ),
            for (final pilar in _hasil!.pilar)
              Card(
                key: Key('tinjauan_pilar_${pilar.nama.replaceAll(' ', '_')}'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pilar.nama,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      for (final f in pilar.fakta)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(f.label)),
                              Text(
                                f.satuanUangSen != null
                                    ? fmtRpDariSen(f.satuanUangSen!)
                                    : f.nilai,
                              ),
                            ],
                          ),
                        ),
                      if (pilar.catatan != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(pilar.catatan!,
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
