/// Rute aplikasi (go_router) + kerangka navigasi bawah 5 tab (V1.5).
///
/// Susunan tab mengikuti rancangan TODAY_V1_5.md §2: Hari Ini · Uang · Kerja ·
/// Ibadah · Lainnya. Layar lama tetap hidup sebagai sub-layar di tab Uang /
/// Lainnya, jadi tidak ada fitur yang hilang.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/hari_ini/baca_catatan_sholat.dart';
import 'features/hari_ini/briefing_pagi_screen.dart';
import 'features/hari_ini/hari_ini_screen.dart';
import 'features/hari_ini/ibadah_hub_screen.dart';
import 'features/hari_ini/kerja_screen.dart';
import 'features/hari_ini/lainnya_screen.dart';
import 'features/ibadah/jadwal_sholat_screen.dart';
import 'features/ibadah/kalender_hijriah_screen.dart';
import 'features/ibadah/pelacakan_sholat_screen.dart';
import 'features/ibadah/rekap_sholat_screen.dart';
import 'features/kalender/kalender_screen.dart';
import 'features/pengingat/pengingat_screen.dart';
import 'features/pengaturan/pengaturan_screen.dart';
import 'features/ringkasan/ringkasan_screen.dart';
import 'features/tagihan/daftar_tagihan_screen.dart';
import 'features/tagihan/form_tagihan_screen.dart';
import 'features/uang/anggaran/anggaran_screen.dart';
import 'features/uang/kekayaan/kekayaan_screen.dart';
import 'features/uang/langganan/langganan_screen.dart';
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
      path: '/briefing',
      builder: (c, s) => const BriefingPagiScreen(),
    ),
    GoRoute(
      path: '/ibadah/jadwal-sholat',
      builder: (c, s) => const JadwalSholatScreen(),
    ),
    GoRoute(
      path: '/ibadah/kalender-hijriah',
      builder: (c, s) => const KalenderHijriahScreen(),
    ),
    GoRoute(
      path: '/ibadah/pelacakan',
      builder: (c, s) => const PelacakanSholatScreen(),
    ),
    GoRoute(
      path: '/ibadah/rekap',
      builder: (c, s) => const RekapSholatScreen(),
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
    4: ['/lainnya', '/pengaturan', '/pengingat'],
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
