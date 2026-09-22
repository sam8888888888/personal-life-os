/// Tab Lainnya — rumah pengaturan & modul yang belum punya tab sendiri.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/peta_fitur/data_peta_fitur.dart';
import '../../core/providers/akun_providers.dart';

class LainnyaScreen extends ConsumerWidget {
  const LainnyaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              key: const Key('buka_peta_fitur'),
              leading: const Icon(Icons.map_outlined),
              title: const Text('Semua Fitur (PRD v3.1)'),
              subtitle: Text(
                  '${ringkasanPetaFitur()[StatusFitur.selesai]} dari '
                  '${petaFitur.length} butir sudah selesai — lihat tandanya'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/peta-fitur'),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Consumer(
              builder: (context, ref, _) {
                final sesi = ref.watch(sesiAkunProvider).value;
                return ListTile(
                  key: const Key('buka_akun'),
                  leading: const Icon(Icons.cloud_sync_outlined),
                  title: const Text('Akun & Sinkron'),
                  subtitle: Text(sesi == null
                      ? 'Belum masuk — masuk supaya semua HP isinya sama'
                      : 'Masuk sebagai ${sesi.nama}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/akun'),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
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
                  key: const Key('buka_aset'),
                  leading: const Icon(Icons.home_work_outlined),
                  title: const Text('Aset & Rumah'),
                  subtitle: const Text(
                      'Rumah, kendaraan, perangkat: beli, garansi, perawatan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/rumah/aset'),
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
                  key: const Key('buka_dokumen'),
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('Dokumen'),
                  subtitle: const Text(
                      'Masa berlaku berkas & pengingat sebelum kedaluwarsa (FR-128)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/dokumen'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_keluarga'),
                  leading: const Icon(Icons.family_restroom_outlined),
                  title: const Text('Keluarga & tanggung jawab'),
                  subtitle: const Text(
                      'Anggota keluarga, pemilik & penanggung jawab item (FR-131)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/keluarga'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_catatan_medis'),
                  leading: const Icon(Icons.medical_information_outlined),
                  title: const Text('Brankas catatan medis'),
                  subtitle: const Text(
                      'Lab, resep, imunisasi, tagihan medis + cari kata (FR-108)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/kesehatan/catatan-medis'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_peringatan_dini'),
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Peringatan dini'),
                  subtitle: const Text(
                      'Pantauan pola dari catatan sendiri, ambang bisa diatur (FR-114)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/kesehatan/peringatan-dini'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_kunjungan'),
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Mode kunjungan dokter'),
                  subtitle: const Text(
                      'Ringkasan 30 hari jadi 1 halaman PDF (FR-115)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/kesehatan/kunjungan'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_profil_kesehatan'),
                  leading: const Icon(Icons.emergency_outlined),
                  title: const Text('Profil kesehatan & kartu darurat'),
                  subtitle: const Text(
                      'Golongan darah, alergi, kontak darurat — offline (FR-117)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/kesehatan/profil-kesehatan'),
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
