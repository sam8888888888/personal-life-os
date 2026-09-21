/// FR-36 — Layar Skor Disiplin Tagihan (lokal).
///
/// Menampilkan skor 0–100, rentetan tepat waktu, capaian, dan penjelasan cara
/// menghitungnya. Disertai penegasan: ini bukan skor kredit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/skor_disiplin.dart';
import '../../core/providers/app_providers.dart';

class SkorDisiplinScreen extends ConsumerStatefulWidget {
  const SkorDisiplinScreen({super.key, this.acuan});

  final DateTime? acuan;

  @override
  ConsumerState<SkorDisiplinScreen> createState() => _SkorDisiplinScreenState();
}

class _SkorDisiplinScreenState extends ConsumerState<SkorDisiplinScreen> {
  bool _memuat = true;
  HasilSkorDisiplin? _hasil;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final riwayat = await ref.read(tagihanRepoProvider).riwayatUntukEkspor();
    final hasil = hitungSkorDisiplin(
      riwayat
          .map((r) => (
                tepatWaktu: (r.telatHari ?? 0) <= 0,
                tanggalBayar: r.tanggalBayar,
              ))
          .toList(),
      acuan: widget.acuan,
    );
    if (!mounted) return;
    setState(() {
      _hasil = hasil;
      _memuat = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final h = _hasil!;
    return Scaffold(
      appBar: AppBar(title: const Text('Skor disiplin tagihan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!h.adaRiwayat) ...[
                    const Text('Belum ada riwayat pembayaran. Setelah Papi '
                        'menandai tagihan lunas, skornya mulai terhitung.'),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${h.skor}',
                          key: const Key('skor_angka'),
                          style: const TextStyle(
                              fontSize: 44, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 4),
                        const Text('/ 100'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Rentetan tepat waktu: ${h.streak}×',
                        key: const Key('skor_streak')),
                    Text('${h.tepatWaktu} dari ${h.jumlahPembayaran} pelunasan '
                        'tepat waktu'
                        '${h.lewatJatuhTempo > 0 ? " · ${h.lewatJatuhTempo} lewat jatuh tempo" : ""}'),
                    const Divider(height: 24),
                    Text('Cara menghitung: ${h.penjelasan}',
                        key: const Key('skor_penjelasan'),
                        style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (h.capaian.isNotEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('Capaian',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  for (final c in h.capaian)
                    ListTile(
                      key: Key('capaian_${c.judul}'),
                      leading: const Icon(Icons.emoji_events_outlined),
                      title: Text(c.judul),
                      subtitle: Text(c.keterangan),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Catatan penting: ini skor lokal di HP Papi sendiri, dihitung '
                'dari catatan pembayaran tagihan Papi. Ini BUKAN skor kredit '
                '(SLIK/BI checking) dan tidak dikirim ke bank atau pihak mana pun.',
                key: Key('skor_disclaimer'),
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
