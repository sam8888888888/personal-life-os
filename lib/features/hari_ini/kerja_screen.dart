/// Tab Kerja (V1.5 tipis) — agenda 7 hari ke depan + keadaan kosong jujur.
///
/// Sumber agenda V1.5 = tabel tagihan/dokumen yang sudah ada (FR-65). Modul
/// Tugas & Goal (FR-78/79) menyusul, jadi bagian itu menulis "Belum ada data".
library;

import 'package:flutter/material.dart';
import 'package:personal_life_os/core/utils/waktu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/hari_ini/penyusun_hari_ini.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import 'pemetaan_tagihan.dart';
import 'warna_tingkat.dart';

class KerjaScreen extends ConsumerStatefulWidget {
  const KerjaScreen({super.key, this.jamSekarang});

  /// Jam uji; dianggap tanggal sipil perangkat.
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<KerjaScreen> createState() => _KerjaScreenState();
}

class _KerjaScreenState extends ConsumerState<KerjaScreen> {
  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tagihan = petaDaftarTagihan(
        ref.watch(semuaTagihanProvider).value ?? const <TagihanData>[]);
    final butir = tagihanTujuhHari(tagihan, _sekarang);

    return Scaffold(
      appBar: AppBar(title: const Text('Kerja')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Text('Agenda 7 hari ke depan', style: tema.textTheme.titleSmall),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Text(
              'Sumber agenda saat ini: tagihan & dokumen Anda.',
              style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.outline),
            ),
          ),
          if (butir.isEmpty)
            const _Kosong('Belum ada agenda 7 hari ke depan')
          else
            for (final b in butir)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    ikonButir(b.jenis),
                    color: warnaTingkat(b.tingkat, tema),
                  ),
                  title: Text(b.judul, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    b.waktu == null
                        ? b.alasan
                        : '${fmtTanggalAman(b.waktu!)} · ${b.alasan}',
                    maxLines: 2,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: b.rute == null ? null : () => context.push(b.rute!),
                ),
              ),
          const SizedBox(height: 16),
          Text('Tugas & Goal', style: tema.textTheme.titleSmall),
          const SizedBox(height: 8),
          const _Kosong('Belum ada data — modul tugas menyusul'),
        ],
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(teks, style: tema.textTheme.bodyMedium),
    );
  }
}
