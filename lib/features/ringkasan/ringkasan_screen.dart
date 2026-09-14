/// Dasbor Ringkasan (UC-5): total tagihan bulan ini, "uang tersisa",
/// dan tagihan terdekat. Halaman pertama yang dilihat pengguna.
library;

import '../../core/utils/waktu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';
import '../../widgets/kartu_tagihan.dart';

class RingkasanScreen extends ConsumerWidget {
  const RingkasanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aktif = ref.watch(tagihanAktifProvider);
    final pemasukan = ref.watch(pemasukanBulanIniProvider);
    final skema = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(tagihanAktifProvider),
      child: aktif.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat data: $e')),
        data: (daftar) {
          final sekarang = waktuSekarang();
          final bulanIni = daftar.where((t) =>
              t.jatuhTempo.year == sekarang.year &&
              t.jatuhTempo.month == sekarang.month);
          final totalBulanIni = bulanIni.fold<int>(0, (a, t) => a + (t.jumlahSen ?? 0));
          final belumBayar = bulanIni.where((t) => !t.lunas);
          final totalBelumBayar = belumBayar.fold<int>(0, (a, t) => a + (t.jumlahSen ?? 0));
          final masuk = pemasukan.value ?? 0;
          final sisa = masuk - totalBelumBayar;
          final terdekat = daftar
              .where((t) => !t.lunas && selisihHari(sekarang, t.jatuhTempo) <= 30)
              .toList()
            ..sort((a, b) => a.jatuhTempo.compareTo(b.jatuhTempo));

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _kartuUangTersisa(context, skema, masuk, totalBelumBayar, sisa),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Ringkasan bulan ${fmtBulanId(sekarang)}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Text('${bulanIni.length} tagihan',
                        style: TextStyle(color: skema.onSurfaceVariant)),
                  ],
                ),
              ),
              _barisInfo(context, 'Total tagihan bulan ini', fmtRpDariSen(totalBulanIni)),
              _barisInfo(context, 'Sudah dibayar',
                  fmtRpDariSen(totalBulanIni - totalBelumBayar),
                  warna: const Color(0xFF2E7D32)),
              _barisInfo(context, 'Belum dibayar (${belumBayar.length} tagihan)',
                  fmtRpDariSen(totalBelumBayar),
                  warna: const Color(0xFFC62828)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Terdekat 30 hari',
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    TextButton(
                      onPressed: () => context.go('/tagihan'),
                      child: const Text('Lihat semua'),
                    ),
                  ],
                ),
              ),
              if (terdekat.isEmpty)
                _kosong(context, ref, daftar.isEmpty)
              else
                ...terdekat.map((t) => KartuTagihan(
                      tagihan: t,
                      onTap: () => context.push('/ubah/${t.id}'),
                      onTandaiLunas: () => _lunas(context, ref, t.id, t.jatuhTempo),
                    )),
            ],
          );
        },
      ),
    );
  }

  Widget _kartuUangTersisa(BuildContext c, ColorScheme skema, int masuk,
      int belumBayar, int sisa) {
    final positif = sisa >= 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: positif
              ? [skema.primary, skema.primary.withValues(alpha: 0.78)]
              : [const Color(0xFFC62828), const Color(0xFF8E1F1F)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(positif ? 'Uang tersisa bulan ini' : 'Uang bulan ini kurang',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text(fmtRp(sisa / 100),
              style: const TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
            masuk == 0
                ? 'Isi pemasukan bulan ini di menu Pengaturan agar hitungannya akurat.'
                : 'Pemasukan ${fmtRpDariSen(masuk)} − tagihan belum dibayar ${fmtRpDariSen(belumBayar)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _barisInfo(BuildContext c, String label, String nilai, {Color? warna}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style:
                      TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(nilai,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w600, color: warna)),
            ),
          ],
        ),
      );

  Widget _kosong(BuildContext context, WidgetRef ref, bool belumAdaApaPun) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.receipt_long, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 8),
            const Text('Belum ada tagihan tercatat.'),
            const SizedBox(height: 4),
            Text(
              'Tambah tagihan pertama Anda dalam 30 detik (UC-1).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/tambah'),
              icon: const Icon(Icons.add),
              label: const Text('Tambah tagihan'),
            ),
            if (belumAdaApaPun) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final n = await ref.read(pengaturanRepoProvider).isiContohData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$n tagihan contoh ditambahkan')));
                  }
                },
                icon: const Icon(Icons.playlist_add),
                label: const Text('Isi dari template (contoh)'),
              ),
            ],
          ],
        ),
      );

  Future<void> _lunas(BuildContext context, WidgetRef ref, int id,
      DateTime periode) async {
    // PB-06: kirim periode yang SEDANG dilihat pengguna, supaya dua ketukan
    // beruntun tidak menggeser periode dua kali.
    await ref
        .read(tagihanRepoProvider)
        .tandaiLunas(id, periodeYangDibayar: periode);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ditandai sudah dibayar')));
    }
  }
}
