/// Layar Proyek (FR-78) — daftar proyek di bawah satu tujuan.
///
/// Setiap baris menampilkan tenggat, status, dan jumlah tugas selesai/total.
/// Proyek tanpa tugas ditulis "Belum ada tugas", bukan "0 dari 0".
/// Menghapus proyek TIDAK menghapus tugas: tautan `proyekId` disetel null
/// lebih dulu (dialog menjelaskan hal itu), sehingga tugas menjadi tugas
/// berdiri sendiri.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/repository/aksi_repository.dart';
import 'aksi_providers.dart';
import 'navigasi_aksi.dart';
import 'tugas_screen.dart';

class ProyekScreen extends ConsumerStatefulWidget {
  const ProyekScreen({super.key, this.tujuanId, this.namaTujuan});

  /// Bila diisi, layar hanya menampilkan proyek milik tujuan itu.
  final int? tujuanId;
  final String? namaTujuan;

  @override
  ConsumerState<ProyekScreen> createState() => _StateProyek();
}

class _StateProyek extends ConsumerState<ProyekScreen> {
  late final AksiRepository _repo = ref.read(repoAksiProvider);

  bool _memuat = true;
  List<ProyekData> _proyek = const <ProyekData>[];
  Map<int, JumlahTugasProyek> _jumlah = const <int, JumlahTugasProyek>{};

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final proyek = await _repo
          .ambilProyek(tujuanId: widget.tujuanId)
          .timeout(const Duration(seconds: 5));
      final jumlah = await _repo
          .jumlahTugasPerProyek()
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _proyek = proyek;
        _jumlah = jumlah;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _proyek = const <ProyekData>[];
        _jumlah = const <int, JumlahTugasProyek>{};
        _memuat = false;
      });
    }
  }

  Future<void> _dialogProyek() async {
    final tersimpan = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogProyek(tujuanId: widget.tujuanId),
    );
    if (tersimpan == true) await _muat();
  }

  Future<void> _konfirmasiHapus(ProyekData p) async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus proyek "${p.nama}"?'),
        content: const Text(
          'Tugas di bawah proyek ini tetap tersimpan. Tautannya menjadi tanpa '
          'proyek, sehingga pekerjaan Anda tidak hilang.',
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('batal_hapus_proyek'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('konfirmasi_hapus_proyek'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus proyek'),
          ),
        ],
      ),
    );
    if (setuju != true) return;
    try {
      await _repo.hapusProyek(p.id).timeout(const Duration(seconds: 5));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proyek belum terhapus. Coba lagi.')),
      );
      return;
    }
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final judul = widget.namaTujuan == null
        ? 'Proyek'
        : 'Proyek · ${widget.namaTujuan}';
    return Scaffold(
      appBar: AppBar(
        title: Text(judul),
        actions: <Widget>[
          IconButton(
            key: const Key('tombol_proyek_baru'),
            tooltip: 'Tambah proyek',
            icon: const Icon(Icons.add),
            onPressed: _dialogProyek,
          ),
        ],
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              children: <Widget>[
                if (_proyek.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text(
                      'Belum ada data',
                      key: Key('proyek_kosong'),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  for (final p in _proyek) _kartuProyek(p),
              ],
            ),
    );
  }

  Widget _kartuProyek(ProyekData p) {
    final jumlah = _jumlah[p.id] ?? const JumlahTugasProyek(total: 0, selesai: 0);
    return Card(
      key: Key('proyek_${p.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ListTile(
            title: Text(p.nama),
            subtitle: Text(
              p.tenggat == null
                  ? 'Tanpa tenggat'
                  : 'Tenggat ${fmtTanggalId(p.tenggat!)}',
            ),
            trailing: Chip(label: Text(AksiRepository.labelStatus(p.status))),
            onTap: () => bukaLayarAksi(
              context,
              TugasScreen(proyekId: p.id, namaProyek: p.nama),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              jumlah.total == 0
                  ? 'Belum ada tugas'
                  : '${jumlah.selesai} dari ${jumlah.total} tugas selesai '
                      '(${jumlah.persen}%)',
              key: Key('jumlah_tugas_${p.id}'),
            ),
          ),
          Row(
            children: <Widget>[
              TextButton.icon(
                key: Key('buka_tugas_${p.id}'),
                icon: const Icon(Icons.checklist_outlined),
                label: const Text('Buka tugas'),
                onPressed: () => bukaLayarAksi(
                  context,
                  TugasScreen(proyekId: p.id, namaProyek: p.nama),
                ),
              ),
              const Spacer(),
              TextButton(
                key: Key('hapus_proyek_${p.id}'),
                onPressed: () => _konfirmasiHapus(p),
                child: const Text('Hapus'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Form proyek baru (nama + tenggat opsional).
class _DialogProyek extends ConsumerStatefulWidget {
  const _DialogProyek({this.tujuanId});

  final int? tujuanId;

  @override
  ConsumerState<_DialogProyek> createState() => _StateDialogProyek();
}

class _StateDialogProyek extends ConsumerState<_DialogProyek> {
  final _kendaliNama = TextEditingController();
  DateTime? _tenggat;
  String? _pesanGalat;

  @override
  void dispose() {
    _kendaliNama.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final nama = _kendaliNama.text.trim();
    if (nama.isEmpty) {
      setState(() => _pesanGalat = 'Tulis dulu nama proyeknya.');
      return;
    }
    try {
      await ref.read(repoAksiProvider).simpanProyek(
            tujuanId: widget.tujuanId,
            nama: nama,
            tenggat: _tenggat,
          ).timeout(const Duration(seconds: 5));
    } catch (_) {
      if (!mounted) return;
      setState(() => _pesanGalat = 'Proyek belum tersimpan. Coba lagi.');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Proyek baru'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            key: const Key('form_nama_proyek'),
            controller: _kendaliNama,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nama proyek'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('form_tenggat_proyek'),
            icon: const Icon(Icons.event_outlined),
            label: Text(
              _tenggat == null
                  ? 'Pilih tenggat (opsional)'
                  : 'Tenggat ${fmtTanggalId(_tenggat!)}',
            ),
            onPressed: () async {
              final pilih = await showDatePicker(
                context: context,
                initialDate: AksiRepository.hariSaja(waktuSekarang()),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (pilih != null) setState(() => _tenggat = pilih);
            },
          ),
          if (_pesanGalat != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _pesanGalat!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('simpan_proyek'),
          onPressed: _simpan,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
