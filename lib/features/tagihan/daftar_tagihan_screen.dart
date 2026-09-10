/// Daftar Tagihan (UC-2 versi daftar): semua tagihan + filter + aksi lunas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';
import '../../widgets/kartu_tagihan.dart';

enum FilterTagihan { semua, belumDibayar, sudahDibayar, nonaktif }

class DaftarTagihanScreen extends ConsumerStatefulWidget {
  const DaftarTagihanScreen({super.key});

  @override
  ConsumerState<DaftarTagihanScreen> createState() => _DaftarTagihanScreenState();
}

class _DaftarTagihanScreenState extends ConsumerState<DaftarTagihanScreen> {
  FilterTagihan _filter = FilterTagihan.belumDibayar;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(semuaTagihanProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal memuat: $e')),
      data: (semua) {
        final terfilter = semua.where((t) {
          switch (_filter) {
            case FilterTagihan.semua:
              return t.statusAktif;
            case FilterTagihan.belumDibayar:
              return t.statusAktif && !t.lunas;
            case FilterTagihan.sudahDibayar:
              return t.lunas;
            case FilterTagihan.nonaktif:
              return !t.statusAktif;
          }
        }).toList()
          ..sort((a, b) => a.jatuhTempo.compareTo(b.jatuhTempo));

        final total = terfilter
            .where((t) => !t.lunas)
            .fold<int>(0, (a, t) => a + (t.jumlahSen ?? 0));

        return Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _chip('Belum dibayar', FilterTagihan.belumDibayar),
                  _chip('Sudah dibayar', FilterTagihan.sudahDibayar),
                  _chip('Aktif', FilterTagihan.semua),
                  _chip('Nonaktif', FilterTagihan.nonaktif),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('${terfilter.length} tagihan'),
                  const Spacer(),
                  Flexible(
                    child: Text('Belum dibayar: ${fmtRpDariSen(total)}',
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: terfilter.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox,
                              size: 48,
                              color: Theme.of(context).colorScheme.outline),
                          const SizedBox(height: 8),
                          const Text('Tidak ada tagihan di filter ini.'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: terfilter.length,
                      itemBuilder: (c, i) {
                        final t = terfilter[i];
                        return KartuTagihan(
                          tagihan: t,
                          onTap: () => context.push('/ubah/${t.id}'),
                          onTandaiLunas:
                              t.lunas ? null : () => _aksiLunas(context, t.id),
                          onUndoLunas:
                              t.lunas ? () => _aksiUndo(context, t.id) : null,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(String label, FilterTagihan nilai) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: _filter == nilai,
          onSelected: (_) => setState(() => _filter = nilai),
        ),
      );

  Future<void> _aksiLunas(BuildContext context, int id) async {
    final r = await ref.read(tagihanRepoProvider).tandaiLunas(id);
    if (!context.mounted) return;
    final berikut = fmtTanggalId(r.periodeJatuhTempo);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Lunas untuk periode $berikut. Periode berikutnya sudah dibuat.'),
      action: SnackBarAction(
        label: 'Batalkan',
        onPressed: () => ref.read(tagihanRepoProvider).undoLunas(id),
      ),
    ));
  }

  Future<void> _aksiUndo(BuildContext context, int id) async {
    await ref.read(tagihanRepoProvider).undoLunas(id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status lunas dibatalkan.')));
    }
  }
}
