/// Layar "Semua Fitur" — peta 152 butir PRD v3.1 beserta tandanya.
///
/// Tujuan: supaya Papi bisa melihat SELURUH isi aplikasi dalam satu tempat dan
/// tahu mana yang benar-benar sudah selesai (✓), baru sebagian (◐), dan belum (○).
/// Tanda diambil dari data yang disusun dari PRD + kenyataan kode, ditulis apa
/// adanya — yang belum, tidak diberi tanda selesai.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/peta_fitur/data_peta_fitur.dart';

class PetaFiturScreen extends StatefulWidget {
  const PetaFiturScreen({super.key});

  @override
  State<PetaFiturScreen> createState() => _PetaFiturScreenState();
}

class _PetaFiturScreenState extends State<PetaFiturScreen> {
  StatusFitur? _saring;
  String _cari = '';

  static const Map<StatusFitur, String> _label = {
    StatusFitur.selesai: 'Selesai',
    StatusFitur.sebagian: 'Sebagian',
    StatusFitur.belum: 'Belum',
  };

  static const Map<StatusFitur, IconData> _ikon = {
    StatusFitur.selesai: Icons.check_circle,
    StatusFitur.sebagian: Icons.contrast,
    StatusFitur.belum: Icons.radio_button_unchecked,
  };

  List<ButirFitur> get _tampil {
    final kata = _cari.trim().toLowerCase();
    return petaFitur.where((b) {
      if (_saring != null && b.status != _saring) return false;
      if (kata.isEmpty) return true;
      return b.id.toLowerCase().contains(kata) ||
          b.nama.toLowerCase().contains(kata) ||
          b.modul.toLowerCase().contains(kata) ||
          b.catatan.toLowerCase().contains(kata);
    }).toList();
  }

  Color _warna(BuildContext c, StatusFitur s) => switch (s) {
        StatusFitur.selesai => Colors.green.shade700,
        StatusFitur.sebagian => Colors.orange.shade800,
        StatusFitur.belum => Theme.of(c).colorScheme.outline,
      };

  void _buka(ButirFitur b) {
    if (b.rute != null) {
      context.push(b.rute!);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        // Catatan sebuah butir bisa panjang (mis. alasan sebuah butir hanya
        // sebetah sebagian); isinya digulir supaya tidak terpotong di layar
        // kecil — dulu di sini muncul RenderFlex overflow 32 px.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_label[b.status]!,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _warna(c, b.status))),
              const SizedBox(height: 8),
              Text(b.nama, style: const TextStyle(fontSize: 16)),
              if (b.rincian.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(b.rincian),
              ],
              if (b.catatan.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Catatan: ${b.catatan}',
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
              if (b.rute == null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Layarnya belum ada — butir ini belum dikerjakan.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ringkas = ringkasanPetaFitur();
    final jumlah = ringkas[StatusFitur.selesai] ?? 0;
    final total = petaFitur.length;
    final tampil = _tampil;

    // Kelompokkan per modul, pertahankan urutan modul dari data.
    final urut = <String>[];
    final perModul = <String, List<ButirFitur>>{};
    for (final b in tampil) {
      if (!perModul.containsKey(b.modul)) {
        perModul[b.modul] = <ButirFitur>[];
        urut.add(b.modul);
      }
      perModul[b.modul]!.add(b);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Semua Fitur')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$jumlah dari $total butir sudah selesai',
                        key: const Key('peta_ringkas'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                        value: total == 0 ? 0 : jumlah / total),
                    const SizedBox(height: 10),
                    Wrap(spacing: 16, runSpacing: 6, children: [
                      _legenda(context, StatusFitur.selesai,
                          ringkas[StatusFitur.selesai] ?? 0),
                      _legenda(context, StatusFitur.sebagian,
                          ringkas[StatusFitur.sebagian] ?? 0),
                      _legenda(context, StatusFitur.belum,
                          ringkas[StatusFitur.belum] ?? 0),
                    ]),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              key: const Key('peta_cari'),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari fitur (mis. listrik, langganan, tidur)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _cari = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilterChip(
                  key: const Key('peta_saring_semua'),
                  label: const Text('Semua'),
                  selected: _saring == null,
                  onSelected: (_) => setState(() => _saring = null),
                ),
                for (final s in StatusFitur.values)
                  FilterChip(
                    key: Key('peta_saring_${s.name}'),
                    label: Text(_label[s] ?? s.name),
                    selected: _saring == s,
                    onSelected: (_) => setState(() => _saring = s),
                  ),
              ],
            ),
          ),
          Expanded(
            child: tampil.isEmpty
                ? const Center(child: Text('Tidak ada butir yang cocok.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                    itemCount: urut.length,
                    itemBuilder: (c, i) {
                      final mod = urut[i];
                      final butir = perModul[mod]!;
                      final selesai = butir
                          .where((b) => b.status == StatusFitur.selesai)
                          .length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                            child: Text(
                              '$mod  ($selesai/${butir.length} selesai)',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                          Card(
                            margin: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (var j = 0; j < butir.length; j++) ...[
                                  if (j > 0) const Divider(height: 1),
                                  ListTile(
                                    key: Key('peta_${butir[j].id}'),
                                    leading: Icon(_ikon[butir[j].status],
                                        color: _warna(c, butir[j].status)),
                                    title: Text(butir[j].nama),
                                    subtitle: Text(
                                      butir[j].catatan.isNotEmpty
                                          ? butir[j].catatan
                                          : _label[butir[j].status]!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: butir[j].rute == null
                                        ? null
                                        : const Icon(Icons.chevron_right),
                                    onTap: () => _buka(butir[j]),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _legenda(BuildContext c, StatusFitur s, int n) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_ikon[s], size: 16, color: _warna(c, s)),
          const SizedBox(width: 6),
          Text('${_label[s]} $n'),
        ],
      );
}
