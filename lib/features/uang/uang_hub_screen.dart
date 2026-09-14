/// Tab Uang (V1.5) — pintu masuk pekerjaan uang.
///
/// Isi yang sudah ada dipakai ulang: Dasbor Uang (RingkasanScreen), Daftar
/// Tagihan, dan Kalender Uang. Modul V1.5 lain (Langganan/Cashflow/Budget/
/// Harta Bersih) belum punya data karena fondasi basis data belum diserahkan,
/// jadi ditulis apa adanya — bukan angka contoh (III-11).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/hari_ini/penyusun_hari_ini.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';
import '../hari_ini/pemetaan_tagihan.dart';

class UangHubScreen extends ConsumerStatefulWidget {
  const UangHubScreen({super.key, this.jamSekarang});

  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<UangHubScreen> createState() => _UangHubScreenState();
}

class _UangHubScreenState extends ConsumerState<UangHubScreen> {
  DateTime get _sekarang => widget.jamSekarang?.call() ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tagihan = petaDaftarTagihan(
        ref.watch(semuaTagihanProvider).value ?? const <TagihanData>[]);
    final u = hitungUang(tagihan, _sekarang);
    final aktif = tagihan.where((t) => t.menuntutTindakan && !t.dokumen).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Uang')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard_outlined),
                  title: const Text('Dasbor uang'),
                  subtitle: const Text('Uang tersisa bulan ini & tagihan terdekat'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ringkasan'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Daftar tagihan'),
                  subtitle: Text('$aktif tagihan aktif · belum dibayar '
                      '${fmtRpDariSen(u.belumDibayarSen)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/tagihan'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Kalender uang'),
                  subtitle: const Text('Tagihan per tanggal'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/kalender'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Menyusul', style: tema.textTheme.titleSmall),
          const SizedBox(height: 8),
          const Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  enabled: false,
                  leading: Icon(Icons.autorenew_outlined),
                  title: Text('Langganan (FR-68)'),
                  subtitle: Text('Menunggu fondasi data — rancangan tabel sudah siap'),
                ),
                Divider(height: 1),
                ListTile(
                  enabled: false,
                  leading: Icon(Icons.swap_vert_outlined),
                  title: Text('Arus kas (FR-71)'),
                  subtitle: Text('Menunggu tabel transaksi'),
                ),
                Divider(height: 1),
                ListTile(
                  enabled: false,
                  leading: Icon(Icons.pie_chart_outline),
                  title: Text('Anggaran (FR-72)'),
                  subtitle: Text('Menunggu tabel anggaran'),
                ),
                Divider(height: 1),
                ListTile(
                  enabled: false,
                  leading: Icon(Icons.savings_outlined),
                  title: Text('Harta bersih (FR-76)'),
                  subtitle: Text('Menunggu tabel aset & utang'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
