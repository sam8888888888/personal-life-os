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
          Text('Menyusul', style: tema.textTheme.titleSmall),
          const SizedBox(height: 8),
          const Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  enabled: false,
                  leading: Icon(Icons.backup_outlined),
                  title: Text('Data & cadangan'),
                  subtitle: Text('Menunggu fondasi data (FR-136)'),
                ),
                Divider(height: 1),
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
            'Personal Life OS · versi 0.5.0 (fase V1.5 — Modul 0)',
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
