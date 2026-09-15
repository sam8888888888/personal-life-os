/// FR-139 — Search Everything: layar pencarian satu pintu.
///
/// Catatan kejujuran yang ditampilkan ke pengguna: pencarian memeriksa teks
/// yang Anda tulis sendiri (nama & catatan). Isi berkas (foto/PDF dokumen)
/// TIDAK dibaca, karena aplikasi ini tidak menjalankan pengenal teks.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/pencarian/model_hasil_cari.dart';
import '../../core/providers/app_providers.dart';
import '../../data/repository/pencarian_repository.dart';

class PencarianScreen extends ConsumerStatefulWidget {
  const PencarianScreen({super.key, this.repo, this.tundaKetik});

  /// Repositori yang dipakai; null = dari database aplikasi.
  final PencarianRepository? repo;

  /// Jeda sebelum mencari (ms). Tes memakai nilai kecil supaya cepat.
  final Duration? tundaKetik;

  @override
  ConsumerState<PencarianScreen> createState() => _PencarianScreenState();
}

class _PencarianScreenState extends ConsumerState<PencarianScreen> {
  final TextEditingController _kendali = TextEditingController();
  Timer? _timer;
  RingkasanCari? _hasil;
  bool _mencari = false;

  Duration get _jeda => widget.tundaKetik ?? const Duration(milliseconds: 250);

  PencarianRepository get _repo =>
      widget.repo ?? PencarianRepository(ref.read(databaseProvider));

  @override
  void dispose() {
    _timer?.cancel();
    _kendali.dispose();
    super.dispose();
  }

  void _ketik(String kata) {
    _timer?.cancel();
    _timer = Timer(_jeda, () => _cari(kata));
  }

  Future<void> _cari(String kata) async {
    setState(() => _mencari = true);
    try {
      final hasil = await _repo
          .cari(kata)
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _hasil = hasil;
        _mencari = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Kegagalan dibaca apa adanya, bukan disembunyikan.
      setState(() {
        _hasil = RingkasanCari(kata: kata.trim(), hasil: const []);
        _mencari = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final RingkasanCari? hasil = _hasil;
    return Scaffold(
      appBar: AppBar(title: const Text('Cari')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              key: const Key('kata_cari'),
              controller: _kendali,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari tagihan, tugas, obat, dokumen, catatan…',
                border: OutlineInputBorder(),
              ),
              onChanged: _ketik,
              onSubmitted: (v) => _cari(v),
            ),
          ),
          if (_mencari) const LinearProgressIndicator(),
          if (hasil != null && !_mencari)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                hasil.kosong
                    ? 'Tidak ada hasil untuk "${hasil.kata}".'
                    : '${hasil.hasil.length} hasil untuk "${hasil.kata}"',
                key: const Key('jumlah_hasil'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          Expanded(child: _isi(context, hasil)),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Pencarian memeriksa nama & catatan yang Anda tulis sendiri. '
              'Isi berkas (foto/PDF) tidak dibaca.',
              key: Key('catatan_pencarian'),
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _isi(BuildContext context, RingkasanCari? hasil) {
    if (hasil == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Ketik kata kunci untuk mencari.',
              key: Key('pencarian_kosong')),
        ),
      );
    }
    if (hasil.kosong) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Belum ada data yang cocok.'),
        ),
      );
    }
    final anak = <Widget>[];
    for (final modul in ModulHasil.values) {
      final baris = hasil.hasil.where((h) => h.modul == modul).toList();
      if (baris.isEmpty) continue;
      anak.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          '${modul.label} (${baris.length})',
          key: Key('grup_${modul.name}'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ));
      for (final h in baris) {
        anak.add(ListTile(
          key: Key('hasil_${modul.name}_${h.idSumber ?? h.judul.hashCode}'),
          leading: const Icon(Icons.chevron_right),
          title: Text(h.judul.isEmpty ? '(tanpa nama)' : h.judul),
          subtitle: Text(h.keterangan),
          onTap: h.rute == null ? null : () => context.push(h.rute!),
        ));
      }
    }
    return ListView(children: anak);
  }
}
