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
  const DaftarTagihanScreen({super.key, this.sekarang});

  /// Waktu sekarang (bisa disuntik saat uji supaya hasilnya pasti).
  final DateTime Function()? sekarang;

  @override
  ConsumerState<DaftarTagihanScreen> createState() => _DaftarTagihanScreenState();
}

class _DaftarTagihanScreenState extends ConsumerState<DaftarTagihanScreen> {
  FilterTagihan _filter = FilterTagihan.belumDibayar;

  /// null = semua kategori; [saringTanpaKategori] = tagihan tanpa kategori;
  /// selain itu = id kategori yang dipilih pengguna.
  int? _kategori;

  /// FR-07: kata pencarian (nama tagihan & catatan).
  String _cari = '';

  /// FR-07: saringan bulan (null = semua bulan).
  DateTime? _bulan;

  /// FR-07: hanya yang terlambat (aktif, belum lunas, lewat jatuh tempo).
  bool _terlambatSaja = false;

  DateTime get _kini => (widget.sekarang ?? DateTime.now)();
  DateTime get _awalHariIni =>
      DateTime(_kini.year, _kini.month, _kini.day);

  bool _cocokCari(TagihanData t) {
    final q = _cari.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (t.nama.toLowerCase().contains(q)) return true;
    final cat = t.catatan?.toLowerCase() ?? '';
    return cat.contains(q);
  }

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
          if (_terlambatSaja &&
              !(t.statusAktif && !t.lunas && t.jatuhTempo.isBefore(_awalHariIni))) {
            return false;
          }
          if (!_cocokCari(t)) return false;
          if (_bulan != null &&
              !(t.jatuhTempo.year == _bulan!.year &&
                  t.jatuhTempo.month == _bulan!.month)) {
            return false;
          }
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
            // FR-07: pencarian + saringan bulan.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('cari_tagihan'),
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'Cari nama tagihan atau catatan',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _cari = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<DateTime?>(
                    key: const Key('pilih_bulan_tagihan'),
                    value: _bulan,
                    hint: const Text('Semua bulan'),
                    items: <DropdownMenuItem<DateTime?>>[
                      const DropdownMenuItem<DateTime?>(
                          value: null, child: Text('Semua bulan')),
                      for (final b in pilihanBulan(acuan: _kini))
                        DropdownMenuItem<DateTime?>(
                            value: b, child: Text(fmtBulanTahun(b))),
                    ],
                    onChanged: (v) => setState(() => _bulan = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _chip('Belum dibayar', FilterTagihan.belumDibayar),
                  _chip('Sudah dibayar', FilterTagihan.sudahDibayar),
                  _chip('Aktif', FilterTagihan.semua),
                  _chip('Nonaktif', FilterTagihan.nonaktif),
                  // FR-07: status "Terlambat" memakai saringan tersendiri.
                FilterChip(
                  key: const Key('chip_terlambat'),
                  label: const Text('Terlambat'),
                  selected: _terlambatSaja,
                  onSelected: (v) => setState(() => _terlambatSaja = v),
                ),
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
                              onDuplikat: () => _aksiDuplikat(context, t),
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

  /// FR-09: salin tagihan sebagai tagihan baru (siap disunting).
  Future<void> _aksiDuplikat(BuildContext context, TagihanData t) async {
    final idBaru =
        await ref.read(tagihanRepoProvider).duplikat(t.id);
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.tagihan,
      aksi: 'duplikat tagihan',
      ringkas: '${t.nama} → salinan #$idBaru',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tagihan disalin: ${t.nama} (salinan)'),
        action: SnackBarAction(
          label: 'Ubah salinan',
          onPressed: () => context.push('/ubah/$idBaru'),
        ),
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

/// Pilihan bulan: 12 bulan ke belakang + 6 bulan ke depan, terdekat dulu.
///
/// Bulan mendatang ikut ditampilkan karena tagihan berulang sering jatuh tempo
/// bulan depan — tanpa itu pengguna tidak bisa melihatnya dari daftar.
List<DateTime> pilihanBulan({DateTime? acuan, int mundur = 12, int maju = 6}) {
  final kini = acuan ?? DateTime.now();
  final bulan = <DateTime>[];
  for (var i = 0; i <= mundur; i++) {
    bulan.add(DateTime(kini.year, kini.month - i, 1));
  }
  for (var i = 1; i <= maju; i++) {
    bulan.add(DateTime(kini.year, kini.month + i, 1));
  }
  bulan.sort((a, b) => b.compareTo(a));
  return bulan;
}

/// Label bulan dalam bahasa Indonesia (mis. "Sep 2026").
String fmtBulanTahun(DateTime b) => '${namaBulanSingkat[b.month]} ${b.year}';
