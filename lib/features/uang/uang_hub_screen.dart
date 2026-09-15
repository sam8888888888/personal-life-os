/// Tab Uang (V1.5) — pintu masuk pekerjaan uang.
///
/// Isi lama dipakai ulang: Dasbor Uang (RingkasanScreen), Daftar Tagihan, dan
/// Kalender Uang. Empat modul V1.5 (Arus kas FR-71, Anggaran FR-72, Langganan
/// FR-68, Kekayaan bersih FR-76) sudah berjalan di atas fondasi data skema v3
/// dan dibuka dari sini.
library;

import 'package:flutter/material.dart';
import 'package:personal_life_os/core/utils/waktu.dart';
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
  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

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
          Text('Kelola uang', style: tema.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.swap_vert_outlined),
                  title: const Text('Arus kas'),
                  subtitle: const Text('Catat pengeluaran & pemasukan (FR-71)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/uang/transaksi'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.pie_chart_outline),
                  title: const Text('Anggaran bulanan'),
                  subtitle: const Text('Batas belanja per kategori (FR-72)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/uang/anggaran'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.autorenew_outlined),
                  title: const Text('Langganan'),
                  subtitle: const Text('Layanan berulang & masa berhenti (FR-68)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/uang/langganan'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: const Text('Kekayaan bersih'),
                  subtitle: const Text('Aset, utang & tren bulanan (FR-76)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/uang/kekayaan'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
