/// Tab Ibadah (V1.5) — pintu masuk modul ibadah.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class IbadahHubScreen extends StatelessWidget {
  const IbadahHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ibadah')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Jadwal sholat'),
                  subtitle: const Text('48 kota · metode Kemenag/MWL · koreksi menit'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ibadah/jadwal-sholat'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('Pelacakan 5 waktu'),
                  subtitle: const Text('Catatan pribadi, tanpa penilaian'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ibadah/pelacakan'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.insights_outlined),
                  title: const Text('Riwayat & konsistensi'),
                  subtitle: const Text('Rekap 7/30 hari, memakai kata "tercatat"'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ibadah/rekap'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Kalender Hijriah'),
                  subtitle: const Text('Acuan Umm al-Qura atau FCNA · koreksi hari'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ibadah/kalender-hijriah'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_pengingat_ibadah'),
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Ringkasan pagi & pengingat sholat'),
                  subtitle: const Text(
                      'Satu ringkasan sehari · pengingat 5 waktu (FR-63 & FR-87)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ibadah/pengingat'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Waktu sholat dihitung dari koordinat kota, bukan jadwal resmi '
            'Kementerian Agama. Awal bulan Hijriah bisa berbeda dari penetapan '
            'pemerintah; karena itu tersedia pilihan acuan dan koreksi hari.',
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
