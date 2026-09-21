/// Rute aplikasi (go_router) + kerangka navigasi bawah 5 tab (V1.5).
///
/// Susunan tab mengikuti rancangan TODAY_V1_5.md §2: Hari Ini · Uang · Kerja ·
/// Ibadah · Lainnya. Layar lama tetap hidup sebagai sub-layar di tab Uang /
/// Lainnya, jadi tidak ada fitur yang hilang.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/hari_ini/baca_catatan_sholat.dart';
import 'features/hari_ini/briefing_pagi_screen.dart';
import 'features/hari_ini/hari_ini_screen.dart';
import 'core/providers/app_providers.dart';
import 'features/hari_ini/ibadah_hub_screen.dart';
import 'features/hari_ini/kerja_screen.dart';
import 'features/hari_ini/lainnya_screen.dart';
import 'features/ibadah/jadwal_sholat_screen.dart';
import 'features/ibadah/kalender_hijriah_screen.dart';
import 'features/ibadah/dzikir_screen.dart';
import 'features/ibadah/muhasabah_screen.dart';
import 'features/ibadah/pelacakan_sholat_screen.dart';
import 'features/ibadah/puasa_screen.dart';
import 'features/ibadah/quran_screen.dart';
import 'features/ibadah/ramadan_screen.dart';
import 'features/ibadah/pengingat_ibadah_screen.dart';
import 'features/ibadah/pengaturan_ibadah.dart';
import 'features/ibadah/rekap_sholat_screen.dart';
import 'features/aksi/aksi_hub_screen.dart';
import 'features/aksi/kebiasaan_screen.dart';
import 'features/aksi/perawatan_screen.dart';
import 'features/aksi/tugas_screen.dart';
import 'features/aksi/tujuan_screen.dart';
import 'features/aksi/visi_screen.dart';
import 'features/akun/akun_screen.dart';
import 'features/peta_fitur/peta_fitur_screen.dart';
import 'features/akun/masuk_screen.dart';
import 'features/cari/pencarian_screen.dart';
import 'features/dokumen/dokumen_form_screen.dart';
import 'features/dokumen/dokumen_screen.dart';
import 'features/kalender/kalender_keuangan_screen.dart';
import 'features/kalender/kalender_screen.dart';
import 'features/kesehatan/aktivitas_screen.dart';
import 'features/kesehatan/air_screen.dart';
import 'features/kesehatan/kesehatan_hub_screen.dart';
import 'features/kesehatan/obat_screen.dart';
import 'features/kesehatan/tidur_screen.dart';
import 'features/laporan/beban_tagihan_screen.dart';
import 'features/laporan/laporan_bulanan_screen.dart';
import 'features/pengingat/pengingat_screen.dart';
import 'features/platform/audit_log_screen.dart';
import 'features/platform/pusat_notifikasi_screen.dart';
import 'features/pengaturan/backup_screen.dart';
import 'features/pengaturan/pengaturan_screen.dart';
import 'features/ringkasan/ringkasan_screen.dart';
import 'features/tagihan/daftar_tagihan_screen.dart';
import 'features/tagihan/kelola_kategori_tagihan_screen.dart';
import 'features/tagihan/form_tagihan_screen.dart';
import 'features/uang/anggaran/anggaran_screen.dart';
import 'features/uang/kekayaan/kekayaan_screen.dart';
import 'features/uang/langganan/langganan_screen.dart';
import 'features/uang/kewajiban/detail_kewajiban_screen.dart';
import 'features/uang/kewajiban/kewajiban_screen.dart';
import 'features/uang/pengeluaran_terencana/pengeluaran_terencana_screen.dart';
import 'features/uang/strategi_pelunasan/strategi_pelunasan_screen.dart';
import 'features/uang/transaksi/daftar_transaksi_screen.dart';
import 'features/uang/uang_hub_screen.dart';

/// Membuat router baru (dipakai aplikasi & uji UI).
GoRouter buatRouter({String awal = '/'}) => GoRouter(
  initialLocation: awal,
  routes: [
    // Alamat lama "/" diarahkan ke tab pertama (rancangan §2.3).
    GoRoute(path: '/', redirect: (c, s) => '/today'),
    ShellRoute(
      builder: (context, state, child) => KerangkaNavigasi(child: child),
      routes: [
        // Kartu pilar Ibadah membaca catatan FR-88 saat layar dibuka.
        GoRoute(
          path: '/today',
          builder: (c, s) =>
              HariIniScreen(ambilJumlahSholatTercatat: bacaJumlahSholatHariIni),
        ),
        GoRoute(path: '/uang', builder: (c, s) => const UangHubScreen()),
        GoRoute(path: '/kerja', builder: (c, s) => const KerjaScreen()),
        GoRoute(path: '/ibadah', builder: (c, s) => const IbadahHubScreen()),
        GoRoute(path: '/lainnya', builder: (c, s) => const LainnyaScreen()),
        // Layar lama, sekarang menjadi sub-layar di dalam tab.
        GoRoute(path: '/ringkasan', builder: (c, s) => const RingkasanScreen()),
        GoRoute(path: '/tagihan', builder: (c, s) => const DaftarTagihanScreen()),
        GoRoute(path: '/kalender', builder: (c, s) => const KalenderScreen()),
        GoRoute(path: '/pengaturan', builder: (c, s) => const PengaturanScreen()),
      ],
    ),
    GoRoute(
      path: '/tagihan/kategori',
      builder: (c, s) => const KelolaKategoriTagihanScreen(),
    ),
    GoRoute(
      path: '/tambah',
      builder: (c, s) => const HalamanJudul(
          judul: 'Tambah Tagihan', isi: FormTagihanScreen()),
    ),
    GoRoute(
      path: '/pengingat',
      builder: (c, s) => const HalamanJudul(
          judul: 'Pengingat & Izin', isi: PengingatScreen()),
    ),
    GoRoute(
      path: '/cadangan',
      builder: (c, s) => const BackupScreen(),
    ),
    // Platform V2: catatan aktivitas (FR-138) & pusat notifikasi (FR-147/148).
    GoRoute(
      path: '/audit',
      builder: (c, s) => const AuditLogScreen(),
    ),
    GoRoute(
      path: '/notifikasi',
      builder: (c, s) => const PusatNotifikasiScreen(),
    ),
    // Batch 2 V2: dokumen (FR-128/129) dan uang lanjutan (FR-74/75).
    GoRoute(
      path: '/dokumen',
      builder: (c, s) => const DokumenScreen(),
      routes: [
        GoRoute(
          path: 'tambah',
          builder: (c, s) => const DokumenFormScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/uang/kewajiban',
      builder: (c, s) => const KewajibanScreen(),
    ),
    GoRoute(
      path: '/uang/kewajiban/:id',
      builder: (c, s) => DetailKewajibanScreen(
          kewajibanId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/uang/pengeluaran-terencana',
      builder: (c, s) => const PengeluaranTerencanaScreen(),
    ),
    GoRoute(
      path: '/uang/strategi-pelunasan',
      builder: (c, s) => const StrategiPelunasanScreen(),
    ),
    GoRoute(
      path: '/briefing',
      builder: (c, s) => const BriefingPagiScreen(),
    ),
    // Satu pintu setelan hitungan sholat: kota, metode, madzhab, dan ihtiyati
    // dibaca/disimpan dari sumber yang sama oleh ketiga layar di bawah.
    GoRoute(
      path: '/ibadah/jadwal-sholat',
      builder: (c, s) => Consumer(builder: (c, ref, _) {
        return JadwalSholatScreen(
            setelan: PengaturanIbadah.dariRepository(
                ref.read(pengaturanRepoProvider)));
      }),
    ),
    GoRoute(
      path: '/ibadah/kalender-hijriah',
      builder: (c, s) => const KalenderHijriahScreen(),
    ),
    GoRoute(
      path: '/ibadah/pelacakan',
      builder: (c, s) => Consumer(builder: (c, ref, _) {
        return PelacakanSholatScreen(
            setelan: PengaturanIbadah.dariRepository(
                ref.read(pengaturanRepoProvider)));
      }),
    ),
    GoRoute(
      path: '/ibadah/rekap',
      builder: (c, s) => const RekapSholatScreen(),
    ),
    // Modul ibadah lanjutan V2 (FR-91/92/93/95/100).
    GoRoute(
      path: '/ibadah/ramadan',
      builder: (c, s) => const RamadanScreen(),
    ),
    GoRoute(
      path: '/ibadah/puasa',
      builder: (c, s) => const PuasaScreen(),
    ),
    GoRoute(
      path: '/ibadah/quran',
      builder: (c, s) => const QuranScreen(),
    ),
    GoRoute(
      path: '/ibadah/dzikir',
      builder: (c, s) => const DzikirScreen(),
    ),
    GoRoute(
      path: '/ibadah/muhasabah',
      builder: (c, s) => const MuhasabahScreen(),
    ),
    GoRoute(
      path: '/ibadah/pengingat',
      builder: (c, s) => Consumer(builder: (c, ref, _) {
        return PengingatIbadahScreen(
            setelan: PengaturanIbadah.dariRepository(
                ref.read(pengaturanRepoProvider)));
      }),
    ),
    // Modul uang V1.5 (FR-68/71/72/76) — layar penuh di atas kerangka tab.
    GoRoute(
      path: '/uang/transaksi',
      builder: (c, s) => const DaftarTransaksiScreen(),
    ),
    GoRoute(
      path: '/uang/anggaran',
      builder: (c, s) => const AnggaranScreen(),
    ),
    GoRoute(
      path: '/uang/langganan',
      builder: (c, s) => const LanggananScreen(),
    ),
    GoRoute(
      path: '/uang/kekayaan',
      builder: (c, s) => const KekayaanScreen(),
    ),
    // Laporan: beban tagihan per bulan (FR-28).
    GoRoute(
      path: '/laporan/beban-tagihan',
      builder: (c, s) => const BebanTagihanScreen(),
    ),
    // Laporan bulanan + unduhan PDF/CSV (FR-77).
    GoRoute(
      path: '/laporan/bulanan',
      builder: (c, s) => const LaporanBulananScreen(),
    ),
    // Kalender keuangan: semua kewajiban uang per tanggal (FR-73).
    GoRoute(
      path: '/kalender-keuangan',
      builder: (c, s) => const KalenderKeuanganScreen(),
    ),
    // Modul aksi & tujuan V2 (FR-78/79/80/83).
    GoRoute(
      path: '/aksi',
      builder: (c, s) => const AksiHubScreen(),
      routes: [
        GoRoute(path: 'tujuan', builder: (c, s) => const TujuanScreen()),
        GoRoute(path: 'tugas', builder: (c, s) => const TugasScreen()),
        GoRoute(
            path: 'kebiasaan', builder: (c, s) => const KebiasaanScreen()),
        GoRoute(
            path: 'perawatan', builder: (c, s) => const PerawatanScreen()),
        // FR-82 — puncak rantai rencana.
        GoRoute(path: 'visi', builder: (c, s) => const VisiScreen()),
      GoRoute(path: '/akun', builder: (c, s) => const AkunScreen()),
      GoRoute(path: '/peta-fitur', builder: (c, s) => const PetaFiturScreen()),
      GoRoute(
        path: '/akun/masuk',
        builder: (c, s) =>
            MasukScreen(mulaiDaftar: s.uri.queryParameters['daftar'] == '1'),
      ),
      ],
    ),
    // FR-139 — pencarian satu pintu lintas modul.
    GoRoute(
      path: '/cari',
      builder: (c, s) => const PencarianScreen(),
    ),
    // Modul kesehatan V2 (FR-101/102/103/106/111).
    GoRoute(
      path: '/kesehatan',
      builder: (c, s) => const KesehatanHubScreen(),
      routes: [
        GoRoute(
          path: 'aktivitas',
          builder: (c, s) => const AktivitasScreen(),
        ),
        GoRoute(
          path: 'tidur',
          builder: (c, s) => const TidurScreen(),
        ),
        GoRoute(
          path: 'obat',
          builder: (c, s) => const ObatScreen(),
        ),
        GoRoute(
          path: 'air',
          builder: (c, s) => const AirScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/ubah/:id',
      builder: (c, s) => HalamanJudul(
        judul: 'Ubah Tagihan',
        isi: FormTagihanScreen(id: int.parse(s.pathParameters['id']!)),
      ),
    ),
  ],
);

final appRouter = buatRouter();

/// Halaman dengan AppBar (untuk form & layar penuh).
class HalamanJudul extends StatelessWidget {
  const HalamanJudul({super.key, required this.judul, required this.isi});
  final String judul;
  final Widget isi;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(judul)),
        body: isi,
      );
}

/// Kerangka dengan navigasi bawah 5 tab (V1.5).
class KerangkaNavigasi extends StatelessWidget {
  const KerangkaNavigasi({super.key, required this.child});
  final Widget child;

  static const _tab = [
    (path: '/today', label: 'Hari Ini', ikon: Icons.today_outlined, ikonAktif: Icons.today),
    (path: '/uang', label: 'Uang', ikon: Icons.account_balance_wallet_outlined, ikonAktif: Icons.account_balance_wallet),
    (path: '/kerja', label: 'Kerja', ikon: Icons.work_outline, ikonAktif: Icons.work),
    (path: '/ibadah', label: 'Ibadah', ikon: Icons.mosque_outlined, ikonAktif: Icons.mosque),
    (path: '/lainnya', label: 'Lainnya', ikon: Icons.more_horiz_outlined, ikonAktif: Icons.more_horiz),
  ];

  /// Layar lama tetap menyalakan tab induknya.
  static const _grup = <int, List<String>>{
    1: ['/uang', '/ringkasan', '/tagihan', '/kalender', '/ubah'],
    2: ['/kerja'],
    3: ['/ibadah'],
    4: [
      '/lainnya',
      '/pengaturan',
      '/pengingat',
      '/cadangan',
      '/audit',
      '/notifikasi',
      '/cari',
      '/aksi',
      '/kesehatan',
      '/dokumen',
    ],
  };

  int _indeks(BuildContext context) {
    final lokasi = GoRouterState.of(context).uri.path;
    if (lokasi == '/' || lokasi.startsWith('/today') || lokasi.startsWith('/briefing')) {
      return 0;
    }
    for (final e in _grup.entries) {
      for (final p in e.value) {
        if (lokasi == p || lokasi.startsWith('$p/')) return e.key;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final i = _indeks(context);
    return Scaffold(
      body: child,
      floatingActionButton: i <= 1
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/tambah'),
              icon: const Icon(Icons.add),
              label: const Text('Tagihan'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (n) => context.go(_tab[n].path),
        destinations: _tab
            .map((t) => NavigationDestination(
                  icon: Icon(t.ikon), selectedIcon: Icon(t.ikonAktif), label: t.label,
                ))
            .toList(),
      ),
    );
  }
}
