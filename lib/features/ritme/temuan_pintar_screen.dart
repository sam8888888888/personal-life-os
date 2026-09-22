/// FR-142 — Layar "Temuan pintar" (Smart Insights).
///
/// Setiap temuan menampilkan DASAR DATA & PERIODENYA (PRD: tidak ada angka
/// misterius), dan bagian bawah menampilkan apa yang BELUM bisa disimpulkan
/// beserta alasannya — bukan didiamkan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analitik/temuan_pintar.dart';
import '../../core/providers/batch9_providers.dart';

class TemuanPintarScreen extends ConsumerStatefulWidget {
  const TemuanPintarScreen({super.key});

  @override
  ConsumerState<TemuanPintarScreen> createState() => _TemuanPintarScreenState();
}

class _TemuanPintarScreenState extends ConsumerState<TemuanPintarScreen> {
  HasilTemuan? _hasil;
  String? _galat;
  bool _siap = false;

  @override
  void initState() {
    super.initState();
    muat();
  }

  Future<void> muat() async {
    try {
      final bahan = await ref.read(repoPintarProvider).bahanTemuan();
      if (!mounted) return;
      setState(() {
        _hasil = susunTemuan(bahan);
        _siap = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = 'Temuan belum bisa dihitung: $e';
        _siap = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final hasil = _hasil;
    return Scaffold(
      appBar: AppBar(title: const Text('Temuan pintar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.lightbulb_outline),
              title: Text('Temuan dari catatan Papi'),
              subtitle: Text('Setiap temuan menyebut tabel & periode datanya. '
                  'Temuan hanya muncul bila datanya cukup — yang belum cukup '
                  'disebut alasannya di bawah.'),
            ),
          ),
          if (_galat != null)
            Card(
              key: const Key('temuan_galat'),
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Belum bisa dihitung'),
                subtitle: Text(_galat!),
              ),
            ),
          if (hasil != null && hasil.temuan.isEmpty)
            const Card(
              key: Key('temuan_kosong'),
              child: ListTile(
                leading: Icon(Icons.search_off),
                title: Text('Belum ada temuan yang menonjol'),
                subtitle: Text('Catatan Papi belum menunjukkan hal yang perlu '
                    'ditonjolkan. Tambah catatan, lalu buka lagi.'),
              ),
            ),
          if (hasil != null)
            for (final t in hasil.temuan)
              Card(
                key: Key('temuan_${t.kode}'),
                child: ListTile(
                  leading: Icon(t.penting
                      ? Icons.priority_high
                      : Icons.check_circle_outline),
                  title: Text(t.judul),
                  trailing: t.angka == null
                      ? null
                      : Text(t.angka!,
                          style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(t.rincian),
                      const SizedBox(height: 4),
                      Text('dasar: ${t.dasar}',
                          key: Key('temuan_dasar_${t.kode}'),
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
          if (hasil != null && hasil.belumBisa.isNotEmpty)
            Card(
              key: const Key('temuan_belum_bisa'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yang belum bisa disimpulkan',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    for (final alasan in hasil.belumBisa)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $alasan'),
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
