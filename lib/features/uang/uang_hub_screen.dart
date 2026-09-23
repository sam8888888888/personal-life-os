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
                  subtitle: const Text('Catat pengeluaran & pemasukan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/uang/transaksi'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.pie_chart_outline),
                  title: const Text('Anggaran bulanan'),
                  subtitle: const Text('Batas belanja per kategori'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/uang/anggaran'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.autorenew_outlined),
                  title: const Text('Langganan'),
                  subtitle: const Text('Layanan berulang & masa berhenti'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/uang/langganan'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: const Text('Kekayaan bersih'),
                  subtitle: const Text('Aset, utang & tren bulanan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/uang/kekayaan'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_aman_sampai_gajian'),
                  leading: const Icon(Icons.event_available_outlined),
                  title: const Text('Uang aman sampai gajian'),
                  subtitle: const Text(
                      'Tagihan sampai tanggal gajian + sisa saldo'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/uang/aman-sampai-gajian'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_denda_terhindarkan'),
                  leading: const Icon(Icons.savings_outlined),
                  title: const Text('Denda terhindarkan'),
                  subtitle: const Text(
                      'Perkiraan denda yang tidak jadi keluar'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/laporan/denda-terhindarkan'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_kenaikan_tagihan'),
                  leading: const Icon(Icons.trending_up_outlined),
                  title: const Text('Kenaikan tagihan'),
                  subtitle: const Text(
                      'Bandingkan nominal dengan 3 pembayaran sebelumnya'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/laporan/kenaikan-tagihan'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_skor_disiplin'),
                  leading: const Icon(Icons.emoji_events_outlined),
                  title: const Text('Skor disiplin tagihan'),
                  subtitle: const Text(
                      'Skor lokal 0–100 & capaian'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/laporan/skor-disiplin'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_statistik_pembayaran'),
                  leading: const Icon(Icons.insights_outlined),
                  title: const Text('Statistik pembayaran'),
                  subtitle: const Text(
                      'Total, rata-rata & tren 12 bulan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/laporan/statistik-pembayaran'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_proyeksi_arus_kas'),
                  leading: const Icon(Icons.stacked_line_chart_outlined),
                  title: const Text('Proyeksi 3 bulan'),
                  subtitle: const Text(
                      'Perkiraan tagihan & langganan 3 bulan ke depan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/laporan/proyeksi-arus-kas'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_pola_bayar'),
                  leading: const Icon(Icons.insights_outlined),
                  title: const Text('Pola bayar & pengingat pintar'),
                  subtitle: const Text(
                      'Kebiasaan membayar yang terbaca + usul pengingat'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/tagihan/pola-bayar'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_pengingat_multi_kanal'),
                  leading: const Icon(Icons.forum_outlined),
                  title: const Text('Pengingat multi-kanal'),
                  subtitle: const Text(
                      'Teruskan pengingat ke WhatsApp / SMS / Telegram'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/tagihan/pengingat-multi-kanal'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_mata_uang'),
                  leading: const Icon(Icons.currency_exchange_outlined),
                  title: const Text('Multi-mata uang & kurs'),
                  subtitle: const Text(
                      'Mata uang per tagihan + konversi ke Rupiah'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/uang/mata-uang'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_rekap_tahunan'),
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('Rekap tahunan'),
                  subtitle: const Text(
                      'Statistik setahun + kartu berbagi gambar'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/uang/rekap-tahunan'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_kas_informal'),
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('Kas & utang informal'),
                  subtitle: const Text(
                      'Utang warung/kontrakan & piutang, saldo per pihak'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/uang/kas-informal'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_pusat_bayar'),
                  leading: const Icon(Icons.account_balance_outlined),
                  title: const Text('Pusat Bayar'),
                  subtitle: const Text(
                      'Aplikasi bayar, nomor VA/QRIS & catatan konfirmasi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/tagihan/pusat-bayar'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_ekspor_kalender'),
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Ekspor kalender (.ics)'),
                  subtitle: const Text(
                      'Tagihan mendatang ke Google Kalender'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/tagihan/ekspor-kalender'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_ekspor_csv'),
                  leading: const Icon(Icons.table_view_outlined),
                  title: const Text('Ekspor CSV'),
                  subtitle: const Text(
                      'Tagihan & riwayat pembayaran untuk spreadsheet'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/tagihan/ekspor-csv'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_kewajiban'),
                  leading: const Icon(Icons.account_balance_outlined),
                  title: const Text('Kewajiban & cicilan'),
                  subtitle: const Text('Utang, cicilan & catatan pembayaran'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/uang/kewajiban'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_pengeluaran_terencana'),
                  leading: const Icon(Icons.event_available_outlined),
                  title: const Text('Pengeluaran terencana'),
                  subtitle: const Text('Belanja besar yang sudah direncanakan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/uang/pengeluaran-terencana'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_strategi_pelunasan'),
                  leading: const Icon(Icons.trending_down_outlined),
                  title: const Text('Strategi pelunasan'),
                  subtitle: const Text('Urutan & simulasi bayar utang'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/uang/strategi-pelunasan'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_beban_tagihan'),
                  leading: const Icon(Icons.bar_chart_outlined),
                  title: const Text('Beban tagihan per bulan'),
                  subtitle: const Text('Grafik 6 bulan, total & per kategori'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/laporan/beban-tagihan'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_kalender_keuangan'),
                  leading: const Icon(Icons.calendar_view_month_outlined),
                  title: const Text('Kalender keuangan'),
                  subtitle: const Text(
                      'Semua kewajiban uang per tanggal'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/kalender-keuangan'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('buka_laporan_bulanan'),
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: const Text('Laporan bulanan'),
                  subtitle: const Text('Rekap sebulan, unduh PDF & CSV'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/laporan/bulanan'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
