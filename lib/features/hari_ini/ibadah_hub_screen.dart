/// Tab Ibadah (V1.5 + V2) — SATU pintu masuk modul ibadah.
///
/// Ini satu-satunya berkas hub ibadah: kartu V1 (jadwal, pelacakan, rekap,
/// kalender, pengingat) + kartu V2 (Ramadan FR-91, Puasa FR-92, Quran FR-93,
/// Dzikir FR-95, Muhasabah FR-100). Jangan membuat hub kedua di tempat lain.
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
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  key: const Key('buka_ramadan'),
                  leading: const Icon(Icons.nightlight_outlined),
                  title: const Text('Ramadan'),
                  subtitle: const Text(
                      'Imsak, iftar, hitungan hari · menurut hitungan aplikasi (FR-91)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ibadah/ramadan'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_puasa'),
                  leading: const Icon(Icons.event_available_outlined),
                  title: const Text('Puasa'),
                  subtitle: const Text(
                      'Ramadan, Senin-Kamis, Ayyamul Bidh, qadha · tanpa penilaian (FR-92)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ibadah/puasa'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_quran'),
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Quran'),
                  subtitle: const Text(
                      'Baca, dengar, hafal, murajaah · target harian & mingguan (FR-93)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ibadah/quran'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_hifz'),
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Hafalan (hifz)'),
                  subtitle: const Text(
                      'Per juz/surah · baru, murajaah, perlu diulang (FR-94)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ibadah/hifz'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_zakat'),
                  leading: const Icon(Icons.volunteer_activism_outlined),
                  title: const Text('Zakat & sedekah'),
                  subtitle: const Text(
                      'Catatan infaq + asisten hitung zakat (FR-96)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ibadah/zakat'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_rencana_ibadah'),
                  leading: const Icon(Icons.mosque_outlined),
                  title: const Text('Rencana Haji & Umrah'),
                  subtitle: const Text('Target dana + daftar persiapan '
                      'dokumen (FR-97)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ibadah/rencana'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_dzikir'),
                  leading: const Icon(Icons.radio_button_checked),
                  title: const Text('Dzikir & doa'),
                  subtitle: const Text(
                      'Penghitung per sesi · target diatur sendiri (FR-95)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ibadah/dzikir'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_muhasabah'),
                  leading: const Icon(Icons.self_improvement_outlined),
                  title: const Text('Muhasabah malam'),
                  subtitle: const Text(
                      'Enam daftar refleksi + tulisan bebas · tanpa penilaian (FR-100)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ibadah/muhasabah'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Waktu sholat dihitung dari koordinat kota, bukan jadwal resmi '
            'Kementerian Agama. Awal bulan Hijriah bisa berbeda dari penetapan '
            'pemerintah; karena itu tersedia pilihan acuan dan koreksi hari. '
            'Seluruh catatan ibadah disimpan di perangkat Anda.',
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
