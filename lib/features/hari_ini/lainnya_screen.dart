/// Tab Lainnya — rumah pengaturan & modul yang belum punya tab sendiri.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LainnyaScreen extends StatelessWidget {
  const LainnyaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.wb_twilight),
                  title: const Text('Ringkasan pagi'),
                  subtitle: const Text('Agenda, tagihan 7 hari, waktu sholat berikutnya'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/briefing'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Pengingat & Izin'),
                  subtitle: const Text('Status izin, uji notifikasi, panduan merek'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/pengingat'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Pengaturan'),
                  subtitle: const Text('Pemasukan bulanan, ibadah, versi aplikasi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/pengaturan'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  key: const Key('buka_cari'),
                  leading: const Icon(Icons.search),
                  title: const Text('Cari'),
                  subtitle: const Text(
                      'Satu kata untuk semua: tagihan, tugas, obat, dokumen, catatan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/cari'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_aksi'),
                  leading: const Icon(Icons.checklist_outlined),
                  title: const Text('Aksi & Tujuan'),
                  subtitle: const Text(
                      'Tujuan, proyek, tugas, kebiasaan, perawatan berkala'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/aksi'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_kesehatan'),
                  leading: const Icon(Icons.favorite_outline),
                  title: const Text('Kesehatan'),
                  subtitle: const Text(
                      'Ukuran tubuh, aktivitas, tidur, obat, air minum'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/kesehatan'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_notifikasi'),
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Pusat notifikasi'),
                  subtitle: const Text(
                      'Riwayat pengingat, tandai dibaca, tunda (FR-147 & FR-148)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/notifikasi'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_audit'),
                  leading: const Icon(Icons.history_outlined),
                  title: const Text('Catatan aktivitas'),
                  subtitle: const Text(
                      'Jejak perubahan data di perangkat Anda (FR-138)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/audit'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_cadangan_lainnya'),
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Data & cadangan'),
                  subtitle: const Text(
                      'Ekspor & pulihkan seluruh data, termasuk data pilar V2'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/cadangan'),
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
                  leading: Icon(Icons.folder_outlined),
                  title: Text('Dokumen'),
                  subtitle: Text('Layar dokumen menyusul (FR-128)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Personal Life OS · versi 0.6.0 (fase V2 — Pilar Kehidupan)',
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
