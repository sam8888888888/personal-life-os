/// Layar Akun & Sinkron — menu utama: status masuk, periksa server, keluar.
///
/// JUJUR soal keadaan: sinkron isi data (tagihan/uang/kebiasaan) belum aktif.
/// Layar ini tidak berpura-pura sudah menyinkronkan apa pun.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/akun/klien_akun.dart';
import '../../core/providers/akun_providers.dart';

class AkunScreen extends ConsumerStatefulWidget {
  const AkunScreen({super.key});

  @override
  ConsumerState<AkunScreen> createState() => _AkunScreenState();
}

class _AkunScreenState extends ConsumerState<AkunScreen> {
  String? _catatanServer;
  bool _memeriksa = false;

  Future<void> _periksaServer() async {
    final repo = ref.read(akunRepoProvider);
    final token = await repo.token();
    if (token == null) return;
    setState(() {
      _memeriksa = true;
      _catatanServer = null;
    });
    try {
      final data = await ref.read(klienAkunProvider).infoAkun(token);
      final akun = data['akun'] as Map<String, dynamic>? ?? const {};
      setState(() {
        _catatanServer = 'Akun ${akun['email']} dikenali server · '
            '${data['jumlah_catatan'] ?? 0} catatan tersimpan · '
            'revisi terakhir ${data['revisi_tertinggi'] ?? 0}.';
      });
    } on AkunGagal catch (e) {
      setState(() => _catatanServer = 'Gagal: ${e.pesan}');
    } finally {
      if (mounted) setState(() => _memeriksa = false);
    }
  }

  Future<void> _keluar(AkunSesi sesi) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Data di HP ini TIDAK dihapus. Hanya akunnya '
            'dilepas dari perangkat ini.'),
        actions: [
          TextButton(onPressed: () => c.pop(false), child: const Text('Batal')),
          FilledButton(
              onPressed: () => c.pop(true), child: const Text('Keluar')),
        ],
      ),
    );
    if (yakin != true) return;
    try {
      await ref.read(klienAkunProvider).keluar(sesi.token);
    } on AkunGagal {
      // Sesi lokal tetap dibersihkan; server bisa dimatikan belakangan.
    }
    await ref.read(akunRepoProvider).bersihkanSesi();
    ref.invalidate(sesiAkunProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Sudah keluar dari akun.')));
  }

  @override
  Widget build(BuildContext context) {
    final sesi = ref.watch(sesiAkunProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Akun & Sinkron')),
      body: sesi.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal membaca akun: $e')),
        data: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (s == null)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Belum masuk',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      const Text('Masuk pakai akun Papi supaya semua HP '
                          'memakai data yang sama.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const Key('buka_masuk'),
                        onPressed: () => context.push('/akun/masuk'),
                        icon: const Icon(Icons.login),
                        label: const Text('Masuk'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const Key('buka_daftar'),
                        onPressed: () => context.push('/akun/masuk?daftar=1'),
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Daftar akun baru'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(s.nama),
                      subtitle: Text(s.email),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      key: const Key('periksa_server'),
                      leading: const Icon(Icons.cloud_outlined),
                      title: const Text('Periksa server akun'),
                      subtitle: Text(_catatanServer ??
                          'Menyambung ke server untuk memastikan akun dikenali.'),
                      trailing: _memeriksa
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh),
                      onTap: _memeriksa ? null : _periksaServer,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      key: const Key('keluar_akun'),
                      leading: const Icon(Icons.logout),
                      title: const Text('Keluar dari akun'),
                      onTap: () => _keluar(s),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 8),
                        Text('Keadaan sinkron',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Belum aktif. Akun dan servernya sudah jalan, tetapi '
                      'pemindahan isi data (tagihan, uang, kebiasaan, dokumen) '
                      'sedang dikerjakan pada tahap berikutnya. Ron tidak akan '
                      'bilang "sudah sinkron" sebelum benar-benar diuji di dua HP.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
