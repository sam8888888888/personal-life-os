/// FR-84 — Layar "Energi & jam produktif" (Sleep & Energy OS).
///
/// Menempel pada tabel `tidur` yang sudah ada: energi/fokus/jam produktif diisi
/// untuk malam yang sudah tercatat. Jam produktif dihitung HANYA dari jam yang
/// Papi sendiri isi — beserta dasar datanya — dan tidak muncul sebelum 14 hari
/// catatan (sesuai PRD).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/kesehatan/energi_tidur.dart';
import '../../core/providers/batch9_providers.dart';

class EnergiTidurScreen extends ConsumerStatefulWidget {
  const EnergiTidurScreen({super.key});

  @override
  ConsumerState<EnergiTidurScreen> createState() => _EnergiTidurScreenState();
}

class _EnergiTidurScreenState extends ConsumerState<EnergiTidurScreen> {
  PolaEnergi? _pola;
  List<CatatanEnergiHari> _hari = const [];
  String? _galat;
  bool _siap = false;

  @override
  void initState() {
    super.initState();
    muat();
  }

  Future<void> muat() async {
    try {
      final repo = ref.read(repoEnergiProvider);
      final hari = await repo.catatan(hari: 60);
      final pola = await repo.pola(hari: 60);
      if (!mounted) return;
      setState(() {
        _hari = hari;
        _pola = pola;
        _siap = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = 'Catatan energi belum bisa dibuka: $e';
        _siap = true;
      });
    }
  }

  String _labelHari(DateTime t) => '${t.day}/${t.month}/${t.year}';

  String _jam(int? menit) {
    if (menit == null) return '—';
    final j = (menit ~/ 60) % 24;
    final m = menit % 60;
    return '${j.toString().padLeft(2, '0')}.${m.toString().padLeft(2, '0')}';
  }

  Future<void> _isi(CatatanEnergiHari hari) async {
    final energi = ValueNotifier<int?>(hari.energi);
    final fokus = ValueNotifier<int?>(hari.fokus);
    final controller = TextEditingController(
        text: hari.jamProduktifMenit == null ? '' : _jam(hari.jamProduktifMenit));
    final simpan = await showDialog<bool>(
      context: context,
      builder: (konteks) => AlertDialog(
        title: Text('Energi ${_labelHari(hari.tanggal)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Energi hari itu (1–5)'),
              ValueListenableBuilder<int?>(
                valueListenable: energi,
                builder: (_, nilai, _) => Wrap(
                  spacing: 6,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      ChoiceChip(
                        key: Key('energi_nilai_$i'),
                        label: Text('$i'),
                        selected: nilai == i,
                        onSelected: (_) => energi.value = i,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text('Fokus hari itu (1–5)'),
              ValueListenableBuilder<int?>(
                valueListenable: fokus,
                builder: (_, nilai, _) => Wrap(
                  spacing: 6,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      ChoiceChip(
                        key: Key('fokus_nilai_$i'),
                        label: Text('$i'),
                        selected: nilai == i,
                        onSelected: (_) => fokus.value = i,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text('Jam paling produktif (mis. 08:30)'),
              TextField(
                key: const Key('jam_produktif_isian'),
                controller: controller,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(hintText: 'HH:MM'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(konteks).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('energi_simpan'),
            onPressed: () => Navigator.of(konteks).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (simpan != true) return;

    int? menitProduktif;
    final teks = controller.text.trim();
    if (teks.isNotEmpty) {
      final cocok = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch(teks);
      if (cocok == null) {
        _pesan('Jam produktif harus berbentuk HH:MM, mis. 08:30.');
        return;
      }
      final j = int.parse(cocok.group(1)!);
      final m = int.parse(cocok.group(2)!);
      if (j > 23 || m > 59) {
        _pesan('Jam produktif harus antara 00:00 dan 23:59.');
        return;
      }
      menitProduktif = j * 60 + m;
    }

    try {
      await ref.read(repoEnergiProvider).simpanEnergi(
            tanggal: hari.tanggal,
            energi: energi.value,
            fokus: fokus.value,
            jamProduktifMenit: menitProduktif,
          );
      _pesan('Catatan ${_labelHari(hari.tanggal)} disimpan.');
      await muat();
    } catch (e) {
      _pesan('Gagal menyimpan: $e');
    }
  }

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pola = _pola;
    return Scaffold(
      appBar: AppBar(title: const Text('Energi & jam produktif')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          if (_galat != null)
            Card(
              key: const Key('energi_galat'),
              child: ListTile(title: Text(_galat!)),
            ),
          if (pola != null)
            Card(
              key: const Key('energi_pola'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pola energi',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text(pola.pesan),
                    const SizedBox(height: 8),
                    Text('Rata-rata tidur: '
                        '${pola.rataMenitTidur == null ? '—' : '${(pola.rataMenitTidur! / 60).toStringAsFixed(1)} jam'}'),
                    Text('Rata-rata energi: '
                        '${pola.rataEnergi == null ? '—' : pola.rataEnergi!.toStringAsFixed(1)}/5'),
                    Text('Rata-rata fokus: '
                        '${pola.rataFokus == null ? '—' : pola.rataFokus!.toStringAsFixed(1)}/5'),
                    Text(
                      pola.jamProduktif == null
                          ? 'Jam produktif: belum bisa ditampilkan'
                          : 'Jam produktif pribadi: ${pola.jamProduktif}',
                      key: const Key('energi_jam_produktif'),
                    ),
                    const SizedBox(height: 6),
                    Text('dasar: ${pola.dasar}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (_hari.isEmpty)
            const Card(
              key: Key('energi_kosong'),
              child: ListTile(
                leading: Icon(Icons.bedtime_outlined),
                title: Text('Belum ada catatan tidur'),
                subtitle: Text('Catat tidur dulu di menu Tidur, lalu isi energi '
                    '& jam produktifnya di sini.'),
              ),
            ),
          for (final hari in _hari.reversed)
            Card(
              key: Key('energi_hari_${hari.tanggal.year}-${hari.tanggal.month}-${hari.tanggal.day}'),
              child: ListTile(
                title: Text(_labelHari(hari.tanggal)),
                subtitle: Text('Tidur ${(hari.menitTidur / 60).toStringAsFixed(1)} jam · '
                    'energi ${hari.energi ?? '—'}/5 · fokus ${hari.fokus ?? '—'}/5 · '
                    'jam produktif ${_jam(hari.jamProduktifMenit)}'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _isi(hari),
              ),
            ),
        ],
      ),
    );
  }
}
