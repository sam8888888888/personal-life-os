/// Layar Visi & Area hidup (FR-82) — puncak rantai rencana.
///
/// Layar ini hanya menyusun rantai: Visi → Area hidup → Tujuan → Proyek →
/// Tugas. Menghapus visi atau area **tidak** menghapus isi di bawahnya; layar
/// menyebutkan hal itu apa adanya di dialog konfirmasi, bukan menyembunyikannya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../data/database/database.dart';
import '../../data/repository/visi_repository.dart';

/// Repositori rantai rencana (dibuat lokal, tidak menyentuh berkas bersama).
final repoVisiProvider = Provider<VisiRepository>(
    (ref) => VisiRepository(ref.watch(databaseProvider)));

class VisiScreen extends ConsumerStatefulWidget {
  const VisiScreen({super.key});

  @override
  ConsumerState<VisiScreen> createState() => _VisiScreenState();
}

class _VisiScreenState extends ConsumerState<VisiScreen> {
  List<VisiData> _visi = const [];
  Map<int, List<AreaHidupData>> _areaPerVisi = const {};
  List<AreaHidupData> _areaTanpaVisi = const [];
  Map<int, int> _tujuanPerArea = const {};
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final repo = ref.read(repoVisiProvider);
    final visi = await repo.ambilVisi();
    final perVisi = <int, List<AreaHidupData>>{};
    for (final v in visi) {
      perVisi[v.id] = await repo.ambilArea(visiId: v.id);
    }
    final tanpaVisi = await repo.ambilArea(hanyaTanpaVisi: true);
    final jumlah = await repo.jumlahTujuanPerArea();
    if (!mounted) return;
    setState(() {
      _visi = visi;
      _areaPerVisi = perVisi;
      _areaTanpaVisi = tanpaVisi;
      _tujuanPerArea = jumlah;
      _memuat = false;
    });
  }

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  /// Dialog satu kolom nama (+ keterangan opsional). Mengembalikan null = batal.
  Future<List<String>?> _tanya({
    required String judul,
    required String label,
    required Key kunciIsi,
    required Key kunciSimpan,
  }) async {
    final ctrlNama = TextEditingController();
    final ctrlKet = TextEditingController();
    final hasil = await showDialog<List<String>>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(judul),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: kunciIsi,
              controller: ctrlNama,
              autofocus: true,
              decoration: InputDecoration(labelText: label),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrlKet,
              decoration: const InputDecoration(labelText: 'Keterangan (opsional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(null),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: kunciSimpan,
            onPressed: () => Navigator.of(c).pop(
                [ctrlNama.text.trim(), ctrlKet.text.trim()]),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    // Catatan: pengendali teks TIDAK dibuang di sini — dialog masih memakainya
    // selama animasi tutup, dan membuangnya lebih awal membuat aksi menolak
    // berjalan ("controller used after being disposed"). Umur objeknya pendek
    // dan dipegang dialog, jadi tidak menahan apa pun setelah layar ditutup.
    if (hasil == null || hasil.first.isEmpty) {
      if (hasil != null) _pesan('Nama tidak boleh kosong.');
      return null;
    }
    return hasil;
  }

  Future<void> _tambahVisi() async {
    final hasil = await _tanya(
      judul: 'Visi baru',
      label: 'Visi (mis. "Hidup tenang, bebas utang")',
      kunciIsi: const Key('nama_visi'),
      kunciSimpan: const Key('simpan_visi'),
    );
    if (hasil == null) return;
    await ref.read(repoVisiProvider).simpanVisi(
          nama: hasil.first,
          keterangan: hasil.length > 1 && hasil[1].isNotEmpty ? hasil[1] : null,
        );
    await _muat();
    _pesan('Visi "${hasil.first}" disimpan.');
  }

  Future<void> _tambahArea({int? visiId}) async {
    final hasil = await _tanya(
      judul: 'Area hidup baru',
      label: 'Area (mis. "Kesehatan", "Keuangan")',
      kunciIsi: const Key('nama_area'),
      kunciSimpan: const Key('simpan_area'),
    );
    if (hasil == null) return;
    await ref.read(repoVisiProvider).simpanArea(
          nama: hasil.first,
          visiId: visiId,
          keterangan: hasil.length > 1 && hasil[1].isNotEmpty ? hasil[1] : null,
        );
    await _muat();
    _pesan('Area "${hasil.first}" disimpan.');
  }

  Future<void> _hapusVisi(VisiData v) async {
    final jumlahArea = (_areaPerVisi[v.id] ?? const []).length;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Hapus visi "${v.nama}"?'),
        content: Text('Visi ini dihapus, tetapi $jumlahArea area di bawahnya '
            'tetap ada — hanya dilepas dari visi. Tujuan, proyek, dan tugas '
            'tidak tersentuh.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('konfirmasi_hapus_visi'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Hapus visi'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    final dilepas = await ref.read(repoVisiProvider).hapusVisi(v.id);
    await _muat();
    _pesan('Visi "${v.nama}" dihapus · $dilepas area dilepas, '
        'datanya tetap ada.');
  }

  Future<void> _hapusArea(AreaHidupData a) async {
    final jumlahTujuan = _tujuanPerArea[a.id] ?? 0;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Hapus area "${a.nama}"?'),
        content: Text('Area ini dihapus, tetapi $jumlahTujuan tujuan di '
            'bawahnya tetap ada — hanya dilepas dari area.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('konfirmasi_hapus_area'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Hapus area'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    final dilepas = await ref.read(repoVisiProvider).hapusArea(a.id);
    await _muat();
    _pesan('Area "${a.nama}" dihapus · $dilepas tujuan dilepas.');
  }

  /// Lembar rantai: daftar tujuan di area ini beserta rantai lengkapnya.
  Future<void> _bukaRantaiArea(AreaHidupData a) async {
    final repo = ref.read(repoVisiProvider);
    final db = ref.read(databaseProvider);
    final tujuan = await (db.select(db.tujuan)
          ..where((t) => t.areaId.equals(a.id)))
        .get();
    final baris = <(TujuanData, RantaiRencana)>[];
    for (final t in tujuan) {
      baris.add((t, await repo.rantaiTujuan(t.id)));
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text('Rantai rencana — ${a.nama}',
                style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (baris.isEmpty)
              const Text('Belum ada tujuan di area ini.')
            else
              for (final b in baris)
                Padding(
                  key: Key('rantai_tujuan_${b.$1.id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.$1.nama),
                      Text(b.$2.kalimat,
                          style: Theme.of(c).textTheme.bodySmall),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (_memuat) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Visi & Area')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tambah_visi'),
        onPressed: _tambahVisi,
        icon: const Icon(Icons.flag_outlined),
        label: const Text('Visi'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Text('Rantai rencana', style: tema.textTheme.titleMedium),
          Text('Visi → Area hidup → Tujuan → Proyek → Tugas. '
              'Menghapus bagian atas tidak menghapus bagian bawah.'),
          const SizedBox(height: 12),
          if (_visi.isEmpty && _areaTanpaVisi.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Belum ada visi. Tekan tombol "Visi" untuk mulai — '
                    'satu kalimat pun cukup.'),
              ),
            ),
          for (final v in _visi) _kartuVisi(v),
          if (_areaTanpaVisi.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Area tanpa visi', style: tema.textTheme.titleSmall),
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  for (final a in _areaTanpaVisi) _barisArea(a),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('tambah_area_tanpa_visi'),
                      onPressed: () => _tambahArea(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Area baru'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kartuVisi(VisiData v) {
    final area = _areaPerVisi[v.id] ?? const <AreaHidupData>[];
    final totalTujuan = area.fold<int>(
        0, (s, a) => s + (_tujuanPerArea[a.id] ?? 0));
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            key: Key('visi_${v.id}'),
            leading: const Icon(Icons.flag_outlined),
            title: Text(v.nama),
            subtitle: Text([
              if ((v.keterangan ?? '').isNotEmpty) v.keterangan!,
              '${area.length} area · $totalTujuan tujuan',
            ].join(' · ')),
            trailing: IconButton(
              key: Key('hapus_visi_${v.id}'),
              tooltip: 'Hapus visi (area tetap ada)',
              onPressed: () => _hapusVisi(v),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text('Area hidup', style: Theme.of(context).textTheme.labelLarge),
          ),
          for (final a in area) _barisArea(a),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: Key('tambah_area_${v.id}'),
              onPressed: () => _tambahArea(visiId: v.id),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Area baru'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barisArea(AreaHidupData a) => ListTile(
        key: Key('area_${a.id}'),
        dense: true,
        leading: const Icon(Icons.category_outlined, size: 20),
        title: Text(a.nama),
        subtitle: Text('${_tujuanPerArea[a.id] ?? 0} tujuan'),
        onTap: () => _bukaRantaiArea(a),
        trailing: IconButton(
          key: Key('hapus_area_${a.id}'),
          tooltip: 'Hapus area (tujuan tetap ada)',
          onPressed: () => _hapusArea(a),
          icon: const Icon(Icons.delete_outline, size: 20),
        ),
      );
}
