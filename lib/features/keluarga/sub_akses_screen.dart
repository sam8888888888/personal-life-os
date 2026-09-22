/// FR-56 — Layar Sub-Akses Keluarga.
///
/// Pengguna menentukan sendiri anggota mana yang boleh melihat modul apa.
/// Semua izin MATI secara bawaan, dan penegakannya ada di lapisan data
/// (`SubAksesRepository.bolehLihat/bolehTambah`), bukan sekadar menyembunyikan
/// menu di layar ini.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/keluarga/sub_akses.dart';
import '../../core/providers/batch12_providers.dart';
import '../../data/database/database.dart';

class SubAksesScreen extends ConsumerStatefulWidget {
  const SubAksesScreen({super.key});

  @override
  ConsumerState<SubAksesScreen> createState() => _SubAksesScreenState();
}

class _SubAksesScreenState extends ConsumerState<SubAksesScreen> {
  List<AnggotaKeluargaData> _anggota = const [];
  Map<int, Map<ModulKeluarga, IzinSubAksesKeluargaData>> _izin = {};
  RingkasSubAkses? _ringkas;
  bool _siap = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final repo = ref.read(repoSubAksesProvider);
      final anggota = await repo.anggota();
      final izin = <int, Map<ModulKeluarga, IzinSubAksesKeluargaData>>{};
      for (final a in anggota) {
        final peta = <ModulKeluarga, IzinSubAksesKeluargaData>{};
        for (final b in await repo.izin(anggotaId: a.id)) {
          final modul = ModulKeluarga.dariKode(b.modul);
          if (modul != null) peta[modul] = b;
        }
        izin[a.id] = peta;
      }
      final ringkas = await repo.ringkas();
      if (!mounted) return;
      setState(() {
        _anggota = anggota;
        _izin = izin;
        _ringkas = ringkas;
        _siap = true;
        _galat = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _siap = true;
        _galat = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sub-Akses Keluarga')),
      body: !_siap
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Berbagi data keluarga — pilih sendiri',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        const Text(catatanSubAkses,
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                if (_galat != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Belum bisa dimuat: $_galat'),
                    ),
                  ),
                if (_anggota.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                          'Belum ada anggota keluarga. Tambahkan dulu di menu '
                          'Keluarga, lalu kembali ke sini untuk mengatur akses.'),
                    ),
                  )
                else
                  for (final a in _anggota) _kartuAnggota(context, a),
                if (_ringkas != null) _kartuRingkas(context, _ringkas!),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _kartuAnggota(BuildContext context, AnggotaKeluargaData a) {
    final peta = _izin[a.id] ?? {};
    final jumlahAktif = peta.values.where((b) => b.aktif && b.bolehLihat).length;
    return Card(
      child: ExpansionTile(
        key: Key('anggota-${a.id}'),
        title: Text(a.nama),
        subtitle: Text(jumlahAktif == 0
            ? 'Belum diberi akses modul apa pun'
            : '$jumlahAktif modul boleh dilihat'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          for (final m in ModulKeluarga.values)
            _barisModul(context, a, m, peta[m]),
          const Divider(),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _paketBerbagi(context, a),
                icon: const Icon(Icons.ios_share),
                label: const Text('Buat paket berbagi'),
              ),
              TextButton.icon(
                onPressed: () => _cabutAkses(context, a),
                icon: const Icon(Icons.block),
                label: const Text('Cabut semua akses'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barisModul(BuildContext context, AnggotaKeluargaData a,
      ModulKeluarga m, IzinSubAksesKeluargaData? baris) {
    final bolehLihat = baris?.bolehLihat ?? false;
    final bolehTambah = baris?.bolehTambah ?? false;
    return Column(
      children: [
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: bolehLihat,
          title: Text(m.label),
          onChanged: (v) => _simpan(a, m,
              bolehLihat: v ?? false, bolehTambah: bolehTambah && (v ?? false)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: bolehTambah,
            title: const Text('Boleh menambah catatan', style: TextStyle(fontSize: 12)),
            onChanged: bolehLihat
                ? (v) => _simpan(a, m, bolehLihat: true, bolehTambah: v ?? false)
                : null,
          ),
        ),
      ],
    );
  }

  Future<void> _simpan(AnggotaKeluargaData a, ModulKeluarga m,
      {required bool bolehLihat, required bool bolehTambah}) async {
    await ref.read(repoSubAksesProvider).simpanIzin(
          anggotaId: a.id,
          modul: m,
          bolehLihat: bolehLihat,
          bolehTambah: bolehTambah,
          aktif: bolehLihat || bolehTambah,
        );
    await _muat();
  }

  Future<void> _cabutAkses(BuildContext context, AnggotaKeluargaData a) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Cabut semua akses ${a.nama}?'),
        content: const Text(
            'Semua modul akan dimatikan untuk anggota ini. Data tidak dihapus, '
            'hanya tidak lagi dibagikan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Cabut')),
        ],
      ),
    );
    if (ya != true) return;
    await ref.read(repoSubAksesProvider).cabutSemua(a.id);
    await _muat();
  }

  Future<void> _paketBerbagi(
      BuildContext context, AnggotaKeluargaData a) async {
    try {
      final isi = await ref.read(repoSubAksesProvider).paketBerbagi(a.id);
      await Clipboard.setData(ClipboardData(text: isi));
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Paket berbagi untuk ${a.nama}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sudah disalin ke papan klip. Kirim berkas ini ke '
                    'perangkat anggota lewat jalur yang Anda percaya.'),
                const SizedBox(height: 8),
                SelectableText(isi, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(c), child: const Text('Tutup')),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Belum bisa membuat paket: $e')));
    }
  }

  Widget _kartuRingkas(BuildContext context, RingkasSubAkses ringkas) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ringkasan akses',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(ringkas.dasar, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            for (final p in ringkas.perAnggota)
              Text('• ${p.anggota}: ${p.kalimat}',
                  style: const TextStyle(fontSize: 12)),
            if (ringkas.belumBisa.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('Belum beres', style: TextStyle(fontWeight: FontWeight.bold)),
              for (final b in ringkas.belumBisa)
                Text('• $b', style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
