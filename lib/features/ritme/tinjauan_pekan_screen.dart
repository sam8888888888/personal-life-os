/// FR-144 — Weekly Life Review.
///
/// Kriteria terima PRD: "Tersedia setiap pekan; dapat dikirim sebagai notifikasi
/// ringkas." Layar ini menampilkan rekap pekan per pilar (angka dari data nyata),
/// menyimpan tiga kalimat milik pengguna, dan menyediakan teks ringkas untuk
/// notifikasi/berbagi.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/ringkas_pekan.dart';
import '../../core/utils/tanggal_utils.dart';
import '../ritme/ritme_providers.dart';

class TinjauanPekanScreen extends ConsumerStatefulWidget {
  const TinjauanPekanScreen({super.key});

  @override
  ConsumerState<TinjauanPekanScreen> createState() =>
      _TinjauanPekanScreenState();
}

class _TinjauanPekanScreenState extends ConsumerState<TinjauanPekanScreen> {
  late DateTime _mulai = awalPekan(DateTime.now());
  RingkasPekan? _ringkas;
  bool _siap = false;
  String? _galat;
  String _pesan = '';

  final _membaik = TextEditingController();
  final _perlu = TextEditingController();
  final _fokus = TextEditingController();

  @override
  void initState() {
    super.initState();
    muat();
  }

  @override
  void dispose() {
    _membaik.dispose();
    _perlu.dispose();
    _fokus.dispose();
    super.dispose();
  }

  Future<void> muat() async {
    setState(() => _siap = false);
    try {
      final repo = ref.read(repoHidupProvider);
      final sampai = _mulai.add(const Duration(days: 6, hours: 23, minutes: 59));
      final laluMulai = _mulai.subtract(const Duration(days: 7));
      final ini = await repo.bahan(dari: _mulai, sampai: sampai, hari: 7);
      final lalu = await repo.bahan(
        dari: laluMulai,
        sampai: laluMulai.add(const Duration(days: 6, hours: 23, minutes: 59)),
        hari: 7,
      );
      final ringkas = susunRingkasPekan(
        ini: ini,
        lalu: lalu,
        tugasPenting: await repo.tugasPenting(),
        tujuanTerdekat: await repo.tujuanTerdekat(),
        dokumenDekat: await repo.dokumenDekat(),
      );
      final tersimpan = await ref.read(repoTinjauanProvider).ambilPekan(_mulai);
      if (!mounted) return;
      setState(() {
        _ringkas = ringkas;
        _membaik.text = tersimpan?.membaik ?? '';
        _perlu.text = tersimpan?.perluPerhatian ?? '';
        _fokus.text = tersimpan?.fokusPekanDepan ?? '';
        _siap = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = 'Rekap pekan belum bisa dihitung: $e';
        _siap = true;
      });
    }
  }

  Future<void> simpan({bool selesai = true}) async {
    await ref.read(repoTinjauanProvider).simpanPekan(
          pekanMulai: _mulai,
          membaik: _membaik.text.trim(),
          perluPerhatian: _perlu.text.trim(),
          fokusPekanDepan: _fokus.text.trim(),
          selesai: selesai,
        );
    if (!mounted) return;
    setState(() => _pesan = 'Tinjauan pekan disimpan.');
  }

  Future<void> salinRingkas() async {
    final teks = _teksRingkas();
    await Clipboard.setData(ClipboardData(text: teks));
    if (!mounted) return;
    setState(() => _pesan = 'Teks ringkas disalin (siap dikirim sebagai '
        'notifikasi pesan singkat).');
  }

  String _teksRingkas() {
    final r = _ringkas;
    final kepala = 'Tinjauan pekan ${labelPekan(_mulai)}';
    if (r == null) return kepala;
    return '$kepala\n${r.ringkasNotifikasi}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final r = _ringkas;
    return Scaffold(
      appBar: AppBar(title: const Text('Tinjauan pekan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('tinjauan_pekan_sebelum'),
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  _mulai = _mulai.subtract(const Duration(days: 7));
                  muat();
                },
              ),
              Expanded(
                child: Text(
                  labelPekan(_mulai),
                  key: const Key('tinjauan_pekan_label'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const Key('tinjauan_pekan_sesudah'),
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  _mulai = _mulai.add(const Duration(days: 7));
                  muat();
                },
              ),
            ],
          ),
          if (_galat != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_galat!, key: const Key('tinjauan_pekan_galat')),
            ),
          if (r != null) ...[
            if (!r.adaPerbandingan)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Belum banyak yang bisa dibandingkan'),
                  subtitle: Text('Rekap ini membandingkan pekan ini dengan '
                      'pekan lalu dari catatan yang ada. Tambah catatan dulu '
                      'bila ingin angka yang lebih bermakna.'),
                ),
              ),
            for (final p in r.pilar)
              Card(
                key: Key('tinjauan_pilar_${p.pilar.replaceAll(' ', '_')}'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.pilar,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      if (!p.adaIsi)
                        const Text('tidak ada perubahan berarti'),
                      for (final x in p.membaik)
                        Text('↑ $x',
                            style: const TextStyle(color: Colors.green)),
                      for (final x in p.perluPerhatian)
                        Text('↓ $x',
                            style: const TextStyle(color: Colors.orange)),
                    ],
                  ),
                ),
              ),
            if (r.fokusDisarankan.isNotEmpty)
              Card(
                key: const Key('tinjauan_pekan_fokus_disarankan'),
                child: ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Yang menunggu pekan depan'),
                  subtitle: Text(r.fokusDisarankan.join('\n')),
                ),
              ),
            Card(
              key: const Key('tinjauan_pekan_ringkas_notifikasi'),
              child: ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Ringkas untuk notifikasi'),
                subtitle: Text(_teksRingkas()),
                trailing: IconButton(
                  key: const Key('tinjauan_pekan_salin'),
                  icon: const Icon(Icons.copy_all_outlined),
                  tooltip: 'Salin teks ringkas',
                  onPressed: salinRingkas,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            key: const Key('tinjauan_pekan_membaik'),
            controller: _membaik,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Apa yang membaik pekan ini?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('tinjauan_pekan_perlu'),
            controller: _perlu,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Apa yang perlu perhatian?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('tinjauan_pekan_fokus'),
            controller: _fokus,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Fokus pekan depan',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('tinjauan_pekan_simpan'),
            onPressed: () => simpan(),
            icon: const Icon(Icons.check),
            label: const Text('Simpan tinjauan pekan'),
          ),
          if (_pesan.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_pesan, key: const Key('tinjauan_pekan_pesan')),
            ),
          if (r != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Periode ${fmtTanggalPendekAman(_mulai)} – '
                '${fmtTanggalPendekAman(_mulai.add(const Duration(days: 6)))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
