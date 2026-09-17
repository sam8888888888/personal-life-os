/// Daftar Tagihan (UC-2 versi daftar): semua tagihan + filter + aksi lunas.
///
/// FR-08: tiap baris menampilkan ikon & warna kategorinya, dan daftar bisa
/// disaring per kategori (termasuk "Tanpa kategori").
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audit/audit_log.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';
import '../../widgets/kartu_tagihan.dart';
import 'ikon_warna_kategori.dart';

enum FilterTagihan { semua, belumDibayar, sudahDibayar, nonaktif }

/// Penanda saringan "tanpa kategori" pada [DaftarTagihanScreen].
const int saringTanpaKategori = -1;

class DaftarTagihanScreen extends ConsumerStatefulWidget {
  const DaftarTagihanScreen({super.key});

  @override
  ConsumerState<DaftarTagihanScreen> createState() => _DaftarTagihanScreenState();
}

class _DaftarTagihanScreenState extends ConsumerState<DaftarTagihanScreen> {
  FilterTagihan _filter = FilterTagihan.belumDibayar;

  /// null = semua kategori; [saringTanpaKategori] = tagihan tanpa kategori;
  /// selain itu = id kategori yang dipilih pengguna.
  int? _kategori;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(semuaTagihanProvider);
    // Daftar kategori (stream) — dipakai untuk ikon, warna, dan saringan.
    final kategori = ref.watch(kategoriProvider).value ?? const <KategoriData>[];
    final petaKategori = {for (final k in kategori) k.id: k};
    // Kategori yang sudah dihapus tidak boleh menyaring jadi "kosong".
    final kategoriEfektif = _kategori == null ||
            _kategori == saringTanpaKategori ||
            petaKategori.containsKey(_kategori)
        ? _kategori
        : null;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal memuat: $e')),
      data: (semua) {
        final terfilter = semua.where((t) {
          final lolosStatus = switch (_filter) {
            FilterTagihan.semua => t.statusAktif,
            FilterTagihan.belumDibayar => t.statusAktif && !t.lunas,
            FilterTagihan.sudahDibayar => t.lunas,
            FilterTagihan.nonaktif => !t.statusAktif,
          };
          if (!lolosStatus) return false;
          if (kategoriEfektif == null) return true;
          if (kategoriEfektif == saringTanpaKategori) return t.kategoriId == null;
          return t.kategoriId == kategoriEfektif;
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
            _barisSaringanKategori(kategori, kategoriEfektif),
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
                        final k =
                            t.kategoriId == null ? null : petaKategori[t.kategoriId];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            KartuTagihan(
                              tagihan: t,
                              onTap: () => context.push('/ubah/${t.id}'),
                              onTandaiLunas: t.lunas
                                  ? null
                                  : () => _aksiLunas(context, t.id, t.jatuhTempo),
                              onUndoLunas:
                                  t.lunas ? () => _aksiUndo(context, t.id) : null,
                            ),
                            if (k != null) _lencanaKategori(t.id, k),
                          ],
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

  /// Saringan per kategori (FR-08): ikon & warnanya ikut terlihat di chip.
  Widget _barisSaringanKategori(List<KategoriData> kategori, int? dipilih) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _chipKategori(
            kunci: 'kategori_semua',
            label: 'Semua kategori',
            ikon: Icons.apps,
            warna: Theme.of(context).colorScheme.primary,
            dipilih: dipilih == null,
            onPilih: () => setState(() => _kategori = null),
          ),
          for (final k in kategori)
            _chipKategori(
              kunci: 'kategori_chip_${k.id}',
              label: k.nama,
              ikon: ikonTagihan(k.ikon),
              warna: warnaTagihan(k.warna),
              dipilih: dipilih == k.id,
              onPilih: () => setState(() => _kategori = k.id),
            ),
          _chipKategori(
            kunci: 'kategori_tanpa',
            label: 'Tanpa kategori',
            ikon: Icons.label_off_outlined,
            warna: Theme.of(context).colorScheme.outline,
            dipilih: dipilih == saringTanpaKategori,
            onPilih: () => setState(() => _kategori = saringTanpaKategori),
          ),
        ],
      ),
    );
  }

  Widget _chipKategori({
    required String kunci,
    required String label,
    required IconData ikon,
    required Color warna,
    required bool dipilih,
    required VoidCallback onPilih,
  }) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          key: ValueKey(kunci),
          avatar: Icon(ikon, size: 16, color: warna),
          label: Text(label),
          selected: dipilih,
          onSelected: (_) => onPilih(),
        ),
      );

  /// Label kecil di bawah kartu: ikon + warna + nama kategori tagihan.
  Widget _lencanaKategori(int tagihanId, KategoriData k) {
    final warna = warnaTagihan(k.warna);
    return Padding(
      key: ValueKey('lencana_kategori_$tagihanId'),
      padding: const EdgeInsets.only(left: 30, right: 16, bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikonTagihan(k.ikon), size: 14, color: warna),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              k.nama,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: warna, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _aksiLunas(BuildContext context, int id, DateTime periode) async {
    // PB-06: periode yang terlihat di layar dikirim ikut, penjaga anti ganda.
    final r = await ref
        .read(tagihanRepoProvider)
        .tandaiLunas(id, periodeYangDibayar: periode);
    // FR-138: catatan aktivitas ditulis dari layar (satu tulisan yang ditunggu
    // per aksi pengguna).
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.tagihan,
      aksi: AksiAudit.tandai,
      entitas: 'tagihan',
      entitasId: '$id',
      sesudah: fmtTanggalAman(periode),
      ringkas: 'Tagihan #$id ditandai lunas untuk periode '
          '${fmtTanggalAman(periode)}.',
    );
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
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.tagihan,
      aksi: AksiAudit.ubah,
      entitas: 'tagihan',
      entitasId: '$id',
      ringkas: 'Status lunas tagihan #$id dibatalkan.',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status lunas dibatalkan.')));
    }
  }
}
