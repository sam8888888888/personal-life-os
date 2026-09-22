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
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.auto_graph_outlined),
                  title: Text('Ritme hidup'),
                  subtitle: Text('Kalender keluarga, lini masa, analitik, '
                      'tinjauan pekan, laporan bulanan'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_kalender_keluarga'),
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Kalender keluarga'),
                  subtitle: const Text('Agenda semua anggota, warna berbeda '
                      'per anggota, termasuk ulang tahun'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/kalender-keluarga'),
                ),
                ListTile(
                  key: const Key('buka_lini_masa'),
                  leading: const Icon(Icons.timeline_outlined),
                  title: const Text('Lini masa hidup'),
                  subtitle: const Text('Seluruh kejadian per bulan, bisa '
                      'dicari & disaring per modul'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/lini-masa'),
                ),
                ListTile(
                  key: const Key('buka_analitik'),
                  leading: const Icon(Icons.insights_outlined),
                  title: const Text('Analitik pribadi'),
                  subtitle: const Text('Ringkasan 7/30/90 hari & 1 tahun — '
                      'tiap angka menyebut sumbernya'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/analitik'),
                ),
                ListTile(
                  key: const Key('buka_tinjauan_pekan'),
                  leading: const Icon(Icons.event_repeat_outlined),
                  title: const Text('Tinjauan pekan'),
                  subtitle: const Text('Apa yang membaik, perlu perhatian, '
                      'dan fokus pekan depan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/tinjauan-pekan'),
                ),
                ListTile(
                  key: const Key('buka_temuan_pintar'),
                  leading: const Icon(Icons.lightbulb_outline),
                  title: const Text('Temuan pintar'),
                  subtitle: const Text('Hal yang menyimpang dari catatan — '
                      'selalu disertai tabel & periode datanya'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/temuan-pintar'),
                ),
                ListTile(
                  key: const Key('buka_ramalan_saldo'),
                  leading: const Icon(Icons.trending_up),
                  title: const Text('Ramalan saldo'),
                  subtitle: const Text('Perkiraan 3–6 bulan ke depan '
                      '(rentang pesimis–optimis + asumsinya)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ramalan-saldo'),
                ),
                ListTile(
                  key: const Key('buka_perjalanan'),
                  leading: const Icon(Icons.flight_takeoff_outlined),
                  title: const Text('Perjalanan'),
                  subtitle: const Text('Itinerary, tiket, hotel, anggaran, '
                      'daftar bawaan, dokumen + jurnal perjalanan (FR-134/135)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/perjalanan'),
                ),
                ListTile(
                  key: const Key('buka_rumah_tangga'),
                  leading: const Icon(Icons.family_restroom_outlined),
                  title: const Text('Tanggung jawab rumah'),
                  subtitle: const Text('Siapa bayar apa, pengingat halus satu '
                      'ketukan, catatan pelunasan (FR-133)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/rumah-tangga'),
                ),
                ListTile(
                  key: const Key('buka_impor_foto'),
                  leading: const Icon(Icons.document_scanner_outlined),
                  title: const Text('Impor dari foto'),
                  subtitle: const Text('Foto tagihan, struk, atau nota — dibaca '
                      'di perangkat, diperiksa dulu (FR-38 & FR-50)'),
                  onTap: () => context.push('/tagihan/impor-foto'),
                ),
                ListTile(
                  key: const Key('buka_mode_rumah_tangga'),
                  leading: const Icon(Icons.home_work_outlined),
                  title: const Text('Mode rumah tangga'),
                  subtitle: const Text('Kode undangan tanpa akun, tagihan '
                      'bersama, siapa bayar apa (FR-43)'),
                  onTap: () => context.push('/rumah/mode-rumah-tangga'),
                ),
                ListTile(
                  key: const Key('buka_sub_akses_keluarga'),
                  leading: const Icon(Icons.vpn_key_outlined),
                  title: const Text('Sub-akses keluarga'),
                  subtitle: const Text('Pilih sendiri modul apa yang boleh '
                      'dilihat anggota keluarga (FR-56)'),
                  onTap: () => context.push('/keluarga/sub-akses'),
                ),
                ListTile(
                  key: const Key('buka_pemindai_bank'),
                  leading: const Icon(Icons.sms_outlined),
                  title: const Text('Pemindai SMS bank'),
                  subtitle: const Text('Deteksi pembayaran dari SMS bank di '
                      'perangkat — opsional (FR-39)'),
                  onTap: () => context.push('/uang/pemindai-bank'),
                ),
                ListTile(
                  key: const Key('buka_suara'),
                  leading: const Icon(Icons.mic_none_outlined),
                  title: const Text('Ucapkan atau tulis'),
                  subtitle: const Text('Satu kalimat jadi draf pengeluaran/'
                      'tagihan (FR-58)'),
                  onTap: () => context.push('/suara'),
                ),
                ListTile(
                  key: const Key('buka_dana_persiapan'),
                  leading: const Icon(Icons.savings_outlined),
                  title: const Text('Dana persiapan'),
                  subtitle: const Text('Uang yang disisihkan untuk kebutuhan '
                      'terencana + arus kas bersih'),
                  onTap: () => context.push('/laporan/dana-persiapan'),
                ),
                ListTile(
                  key: const Key('buka_patungan'),
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Patungan & split bill'),
                  subtitle: const Text('Grup belanja bersama: siapa bayar '
                      'berapa, siapa transfer ke siapa'),
                  onTap: () => context.push('/patungan'),
                ),
                ListTile(
                  key: const Key('buka_delegasi'),
                  leading: const Icon(Icons.send_outlined),
                  title: const Text('Delegasi pengingat (WhatsApp)'),
                  subtitle: const Text('Teruskan pengingat tagihan ke '
                      'keluarga lewat WhatsApp/SMS'),
                  onTap: () => context.push('/tagihan/delegasi'),
                ),
                ListTile(
                  key: const Key('buka_copilot'),
                  leading: const Icon(Icons.psychology_outlined),
                  title: const Text('AI Copilot ber-konteks'),
                  subtitle: const Text('Tanya jawab atas data sendiri — '
                      'dengan izin & penjelasan data yang dikirim'),
                  onTap: () => context.push('/copilot'),
                ),
                ListTile(
                  key: const Key('buka_tinjauan_tahun'),
                  leading: const Icon(Icons.event_note_outlined),
                  title: const Text('Tinjauan tahun'),
                  subtitle: const Text('"Your Year in Life" — muncul setelah '
                      'ada data 6 bulan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/tinjauan-tahun'),
                ),
                ListTile(
                  key: const Key('buka_laporan_hidup'),
                  leading: const Icon(Icons.summarize_outlined),
                  title: const Text('Laporan bulanan'),
                  subtitle: const Text('Keuangan, tagihan, tujuan, langganan, '
                      'kekayaan bersih — bisa jadi PDF'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/laporan-hidup'),
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
