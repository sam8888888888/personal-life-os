/// Rute aplikasi (go_router) + kerangka navigasi bawah.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/kalender/kalender_screen.dart';
import 'features/pengingat/pengingat_screen.dart';
import 'features/pengaturan/pengaturan_screen.dart';
import 'features/ringkasan/ringkasan_screen.dart';
import 'features/tagihan/daftar_tagihan_screen.dart';
import 'features/tagihan/form_tagihan_screen.dart';

/// Membuat router baru (dipakai aplikasi & uji UI).
GoRouter buatRouter({String awal = '/'}) => GoRouter(
  initialLocation: awal,
  routes: [
    ShellRoute(
      builder: (context, state, child) => KerangkaNavigasi(child: child),
      routes: [
        GoRoute(path: '/', builder: (c, s) => const RingkasanScreen()),
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
      path: '/ubah/:id',
      builder: (c, s) => HalamanJudul(
        judul: 'Ubah Tagihan',
        isi: FormTagihanScreen(id: int.parse(s.pathParameters['id']!)),
      ),
    ),
  ],
);

final appRouter = buatRouter();

/// Halaman dengan AppBar (untuk form).
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

/// Kerangka dengan navigasi bawah 4 tab.
class KerangkaNavigasi extends StatelessWidget {
  const KerangkaNavigasi({super.key, required this.child});
  final Widget child;

  static const _tab = [
    (path: '/', label: 'Ringkasan', ikon: Icons.dashboard_outlined, ikonAktif: Icons.dashboard),
    (path: '/tagihan', label: 'Tagihan', ikon: Icons.receipt_long_outlined, ikonAktif: Icons.receipt_long),
    (path: '/kalender', label: 'Kalender', ikon: Icons.calendar_month_outlined, ikonAktif: Icons.calendar_month),
    (path: '/pengaturan', label: 'Pengaturan', ikon: Icons.settings_outlined, ikonAktif: Icons.settings),
  ];

  int _indeks(BuildContext context) {
    final lokasi = GoRouterState.of(context).uri.path;
    final i = _tab.indexWhere((t) => t.path == lokasi);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final i = _indeks(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab[i].label),
        actions: [
          if (i == 1)
            IconButton(
              tooltip: 'Tambah tagihan',
              onPressed: () => context.push('/tambah'),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: child,
      floatingActionButton: i == 0 || i == 2
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
