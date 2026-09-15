/// Layar Tujuan (FR-78) — puncak rantai Tujuan -> Proyek -> Tugas.
///
/// Isi layar: daftar tujuan beserta area hidup, target (angka/satuan atau
/// teks), tanggal target, status (aktif / tercapai / dijeda / arsip), dan
/// jumlah proyek di bawahnya.
///
/// Aturan yang ditegakkan di sini:
/// - Progres ditulis dengan angka apa adanya ("2 dari 5 tugas selesai").
///   Tujuan tanpa tugas ditulis "Belum ada tugas", bukan "0%" yang
///   menyesatkan.
/// - Menghapus tujuan TIDAK menghapus proyek/tugas; dialog menjelaskan itu
///   lebih dulu, dan repositori menyetel tautannya menjadi null.
/// - Bahasa mengikuti PRD III-11: menjelaskan keadaan, tanpa menilai.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/repository/aksi_repository.dart';
import 'aksi_providers.dart';
import 'navigasi_aksi.dart';
import 'proyek_screen.dart';

class TujuanScreen extends ConsumerStatefulWidget {
  const TujuanScreen({super.key});

  @override
  ConsumerState<TujuanScreen> createState() => _StateTujuan();
}

class _StateTujuan extends ConsumerState<TujuanScreen> {
  late final AksiRepository _repo = ref.read(repoAksiProvider);

  bool _memuat = true;
  List<TujuanData> _tujuan = const <TujuanData>[];
  Map<int, ProgresTujuan> _progres = const <int, ProgresTujuan>{};

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final tujuan =
          await _repo.ambilTujuan().timeout(const Duration(seconds: 5));
      final progres =
          await _repo.progresSemuaTujuan().timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _tujuan = tujuan;
        _progres = progres;
        _memuat = false;
      });
    } catch (_) {
      // Bila penyimpanan tidak menjawab, layar tetap tampil dengan keadaan
      // kosong — bukan berputar tanpa henti dan bukan angka karangan.
      if (!mounted) return;
      setState(() {
        _tujuan = const <TujuanData>[];
        _progres = const <int, ProgresTujuan>{};
        _memuat = false;
      });
    }
  }

  Future<void> _dialogTujuan() async {
    final tersimpan = await showDialog<bool>(
      context: context,
      builder: (_) => const _DialogTujuan(),
    );
    if (tersimpan == true) await _muat();
  }

  Future<void> _dialogStatus(TujuanData t) async {
    final pilih = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Ubah status tujuan'),
            ),
            for (final s in AksiRepository.statusTujuan)
              ListTile(
                key: Key('pilih_status_$s'),
                title: Text(AksiRepository.labelStatus(s)),
                trailing: s == t.status ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(ctx).pop(s),
              ),
          ],
        ),
      ),
    );
    if (pilih == null || pilih == t.status) return;
    try {
      await _repo
          .ubahStatusTujuan(t.id, pilih)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status belum tersimpan. Coba lagi.')),
      );
      return;
    }
    await _muat();
  }

  Future<void> _konfirmasiHapus(TujuanData t) async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus tujuan "${t.nama}"?'),
        content: const Text(
          'Proyek dan tugas di bawah tujuan ini tetap tersimpan. Tautannya '
          'menjadi tanpa tujuan, sehingga pekerjaan Anda tidak hilang.',
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('batal_hapus_tujuan'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('konfirmasi_hapus_tujuan'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus tujuan'),
          ),
        ],
      ),
    );
    if (setuju != true) return;
    try {
      await _repo.hapusTujuan(t.id).timeout(const Duration(seconds: 5));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tujuan belum terhapus. Coba lagi.')),
      );
      return;
    }
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tujuan'),
        actions: <Widget>[
          IconButton(
            key: const Key('tombol_tujuan_baru'),
            tooltip: 'Tambah tujuan',
            icon: const Icon(Icons.add),
            onPressed: _dialogTujuan,
          ),
        ],
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              children: <Widget>[
                if (_tujuan.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text(
                      'Belum ada data',
                      key: Key('tujuan_kosong'),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  for (final t in _tujuan) _kartuTujuan(t),
              ],
            ),
    );
  }

  Widget _kartuTujuan(TujuanData t) {
    final progres = _progres[t.id] ?? const ProgresTujuan(
      totalTugas: 0,
      tugasSelesai: 0,
      totalProyek: 0,
      proyekSelesai: 0,
    );
    return Card(
      key: Key('tujuan_${t.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ListTile(
            title: Text(t.nama),
            subtitle: Text(
              '${AksiRepository.labelArea(t.area)} · '
              '${AksiRepository.ringkasTarget(t)}',
            ),
            trailing: Chip(label: Text(AksiRepository.labelStatus(t.status))),
            onTap: () => bukaLayarAksi(
              context,
              ProyekScreen(tujuanId: t.id, namaTujuan: t.nama),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  t.tanggalTarget == null
                      ? 'Tanpa tanggal target'
                      : 'Tanggal target: ${fmtTanggalId(t.tanggalTarget!)} '
                          '(${AksiRepository.teksTanggalTarget(t.tanggalTarget, waktuSekarang())})',
                  key: Key('target_tanggal_${t.id}'),
                ),
                const SizedBox(height: 4),
                Text(
                  progres.adaTugas
                      ? '${progres.tugasSelesai} dari ${progres.totalTugas} '
                          'tugas selesai (${progres.persen}%)'
                      : 'Belum ada tugas di tujuan ini',
                  key: Key('progres_tujuan_${t.id}'),
                ),
                const SizedBox(height: 4),
                Text(
                  progres.totalProyek == 0
                      ? 'Belum ada proyek'
                      : '${progres.totalProyek} proyek · '
                          '${progres.proyekSelesai} proyek selesai',
                  key: Key('proyek_tujuan_${t.id}'),
                ),
              ],
            ),
          ),
          // Wrap (bukan Row): tiga tombol ini tidak muat sebaris pada layar
          // sempit, jadi dibuat turun baris sendiri bila perlu.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              TextButton.icon(
                key: Key('buka_proyek_${t.id}'),
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Buka proyek'),
                onPressed: () => bukaLayarAksi(
                  context,
                  ProyekScreen(tujuanId: t.id, namaTujuan: t.nama),
                ),
              ),
              TextButton(
                key: Key('ubah_status_${t.id}'),
                onPressed: () => _dialogStatus(t),
                child: const Text('Ubah status'),
              ),
              TextButton(
                key: Key('hapus_tujuan_${t.id}'),
                onPressed: () => _konfirmasiHapus(t),
                child: const Text('Hapus'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Form tujuan baru: area hidup, target angka/teks, tanggal target.
class _DialogTujuan extends ConsumerStatefulWidget {
  const _DialogTujuan();

  @override
  ConsumerState<_DialogTujuan> createState() => _StateDialogTujuan();
}

class _StateDialogTujuan extends ConsumerState<_DialogTujuan> {
  final _kendaliNama = TextEditingController();
  final _kendaliAngka = TextEditingController();
  final _kendaliSatuan = TextEditingController();
  final _kendaliTeks = TextEditingController();
  String _area = AksiRepository.areaHidup.first;
  DateTime? _tanggalTarget;
  String? _pesanGalat;

  @override
  void dispose() {
    _kendaliNama.dispose();
    _kendaliAngka.dispose();
    _kendaliSatuan.dispose();
    _kendaliTeks.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final nama = _kendaliNama.text.trim();
    if (nama.isEmpty) {
      setState(() => _pesanGalat = 'Tulis dulu nama tujuannya.');
      return;
    }
    final angkaTeks = _kendaliAngka.text.trim();
    final angka = angkaTeks.isEmpty ? null : int.tryParse(angkaTeks);
    if (angkaTeks.isNotEmpty && angka == null) {
      setState(() => _pesanGalat = 'Target angka harus berupa angka.');
      return;
    }
    try {
      await ref.read(repoAksiProvider).simpanTujuan(
            nama: nama,
            area: _area,
            targetAngka: angka,
            satuan: _kendaliSatuan.text.trim().isEmpty
                ? null
                : _kendaliSatuan.text.trim(),
            targetTeks: _kendaliTeks.text.trim().isEmpty
                ? null
                : _kendaliTeks.text.trim(),
            tanggalTarget: _tanggalTarget,
            urutan: 0,
          ).timeout(const Duration(seconds: 5));
    } catch (_) {
      if (!mounted) return;
      setState(() => _pesanGalat = 'Tujuan belum tersimpan. Coba lagi.');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tujuan baru'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              key: const Key('form_nama_tujuan'),
              controller: _kendaliNama,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nama tujuan'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('form_area_tujuan'),
              initialValue: _area,
              decoration: const InputDecoration(labelText: 'Area hidup'),
              items: <DropdownMenuItem<String>>[
                for (final a in AksiRepository.areaHidup)
                  DropdownMenuItem<String>(
                    value: a,
                    child: Text(AksiRepository.labelArea(a)),
                  ),
              ],
              onChanged: (v) => setState(() => _area = v ?? _area),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('form_target_angka'),
                    controller: _kendaliAngka,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Target angka'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('form_satuan_tujuan'),
                    controller: _kendaliSatuan,
                    decoration: const InputDecoration(labelText: 'Satuan'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('form_target_teks'),
              controller: _kendaliTeks,
              decoration: const InputDecoration(
                labelText: 'Target teks (bila tanpa angka)',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('form_tanggal_target'),
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _tanggalTarget == null
                    ? 'Pilih tanggal target (opsional)'
                    : fmtTanggalId(_tanggalTarget!),
              ),
              onPressed: () async {
                final pilih = await showDatePicker(
                  context: context,
                  initialDate: _tanggalTarget ?? AksiRepository.hariSaja(waktuSekarang()),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (pilih != null) setState(() => _tanggalTarget = pilih);
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
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('simpan_tujuan'),
          onPressed: _simpan,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
