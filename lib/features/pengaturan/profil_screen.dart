/// FR-44 — Layar Multi-profil (pribadi / keluarga / usaha).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profil/profil.dart';
import '../../core/profil/profil_providers.dart';

class ProfilScreen extends ConsumerStatefulWidget {
  const ProfilScreen({super.key});

  @override
  ConsumerState<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends ConsumerState<ProfilScreen> {
  final TextEditingController _nama = TextEditingController();
  JenisProfil _jenis = JenisProfil.keluarga;
  String? _pesan;
  bool _sibuk = false;

  @override
  void dispose() {
    _nama.dispose();
    super.dispose();
  }

  Future<void> _pindah(String id) async {
    setState(() => _sibuk = true);
    try {
      await ref.read(profilAktifProvider.notifier).ganti(id);
      if (mounted) setState(() => _pesan = 'Profil diganti.');
    } catch (e) {
      if (mounted) setState(() => _pesan = 'Gagal pindah profil: $e');
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _tambah() async {
    setState(() => _sibuk = true);
    try {
      await ref.read(profilAktifProvider.notifier).tambah(_nama.text, _jenis);
      _nama.clear();
      if (mounted) setState(() => _pesan = 'Profil ditambahkan.');
    } catch (e) {
      if (mounted) setState(() => _pesan = '$e');
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _hapus(Profil p) async {
    setState(() => _sibuk = true);
    try {
      await ref.read(profilAktifProvider.notifier).hapus(p.id);
      if (mounted) setState(() => _pesan = 'Profil "${p.nama}" dihapus.');
    } catch (e) {
      if (mounted) setState(() => _pesan = '$e');
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final daftar = ref.watch(profilAktifProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Setiap profil punya data SENDIRI: tagihan, uang, dokumen, dan '
            'kesehatan tidak bercampur. Berguna untuk memisahkan urusan '
            'pribadi, keluarga, dan usaha di satu HP.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Profil "Pribadi" adalah data Anda yang sekarang — tidak ada data '
            'yang dipindahkan atau dihapus oleh fitur ini.',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
          const Divider(height: 32),
          const Text('Daftar profil',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final p in daftar.daftar)
            Card(
              key: Key('profil_${p.id}'),
              child: ListTile(
                leading: Icon(p.jenis == JenisProfil.usaha
                    ? Icons.storefront
                    : p.jenis == JenisProfil.keluarga
                        ? Icons.family_restroom
                        : Icons.person),
                title: Text(p.nama),
                subtitle: Text(p.id == daftar.aktif
                    ? '${p.jenis.label} · sedang dipakai'
                    : p.jenis.label),
                trailing: p.id == daftar.aktif
                    ? const Icon(Icons.check_circle)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            key: Key('pindah_${p.id}'),
                            onPressed: _sibuk ? null : () => _pindah(p.id),
                            child: const Text('Pindah'),
                          ),
                          IconButton(
                            key: Key('hapus_${p.id}'),
                            onPressed:
                                _sibuk ? null : () => _hapus(p),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Hapus profil',
                          ),
                        ],
                      ),
              ),
            ),
          const Divider(height: 32),
          const Text('Tambah profil',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('nama_profil_baru'),
            controller: _nama,
            decoration: const InputDecoration(
              labelText: 'Nama profil (mis. Usaha Toko)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final j in JenisProfil.values)
                ChoiceChip(
                  key: Key('jenis_${j.name}'),
                  label: Text(j.label),
                  selected: _jenis == j,
                  onSelected: (_) => setState(() => _jenis = j),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('tambah_profil'),
            onPressed: _sibuk ? null : _tambah,
            icon: const Icon(Icons.add),
            label: const Text('Tambah profil'),
          ),
          const SizedBox(height: 6),
          const Text(
            'Profil baru mulai kosong (kategori bawaan disiapkan otomatis). '
            'Profil "Pribadi" tidak bisa dihapus, dan profil yang sedang '
            'dipakai harus dipindah dulu sebelum dihapus.',
            style: TextStyle(fontSize: 12),
          ),
          if (_pesan != null) ...[
            const SizedBox(height: 16),
            Text(_pesan!, key: const Key('pesan_profil')),
          ],
        ],
      ),
    );
  }
}
