/// Layar Tugas (FR-78 & FR-79).
///
/// Isi layar:
/// - tombol "Tugas cepat" (FR-79): menyimpan tugas berdiri sendiri tanpa
///   proyek dalam dua ketukan (buka lembar, lalu Simpan);
/// - daftar "Tugas cepat hari ini": tugas berdiri sendiri yang belum selesai
///   dan jatuh temponya kosong atau paling lambat hari ini;
/// - daftar tugas pada proyek/tujuan yang sedang dibuka, dengan penanda
///   selesai, jatuh tempo, dan prioritas.
///
/// Bahasa mengikuti PRD III-11. Melewati jatuh tempo hanya ditulis sebagai
/// tanggal, bukan sebagai teguran.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import '../../data/repository/aksi_repository.dart';
import 'aksi_providers.dart';
import 'tugas_cepat_sheet.dart';

class TugasScreen extends ConsumerStatefulWidget {
  const TugasScreen({
    super.key,
    this.proyekId,
    this.tujuanId,
    this.namaProyek,
    this.namaTujuan,
  });

  final int? proyekId;
  final int? tujuanId;
  final String? namaProyek;
  final String? namaTujuan;

  @override
  ConsumerState<TugasScreen> createState() => _StateTugas();
}

/// Saringan daftar tugas.
enum FilterTugas { semua, belumSelesai, selesai }

class _StateTugas extends ConsumerState<TugasScreen> {
  late final AksiRepository _repo = ref.read(repoAksiProvider);

  bool _memuat = true;
  List<BarisTugas> _tugas = const <BarisTugas>[];
  List<BarisTugas> _cepatHariIni = const <BarisTugas>[];
  FilterTugas _filter = FilterTugas.belumSelesai;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final semua = await _repo
          .ambilTugas(proyekId: widget.proyekId, tujuanId: widget.tujuanId)
          .timeout(const Duration(seconds: 5));
      final cepat = await _repo
          .tugasCepatHariIni()
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _tugas = semua;
        _cepatHariIni = cepat;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tugas = const <BarisTugas>[];
        _cepatHariIni = const <BarisTugas>[];
        _memuat = false;
      });
    }
  }

  /// Tugas yang tampil pada saringan aktif.
  ///
  /// Di layar tanpa proyek/tujuan, tugas cepat yang sudah muncul di bagian
  /// "Tugas cepat hari ini" dikeluarkan dari daftar bawah supaya satu tugas
  /// tidak tampil dua kali di halaman yang sama.
  List<BarisTugas> get _tampil {
    final cepat = widget.proyekId == null && widget.tujuanId == null
        ? {for (final t in _cepatHariIni) t.id}
        : const <int>{};
    final dasar = _tugas
        .where((t) => !cepat.contains(t.id))
        .toList(growable: false);
    return switch (_filter) {
      FilterTugas.semua => dasar,
      FilterTugas.belumSelesai =>
        dasar.where((t) => !t.selesai).toList(growable: false),
      FilterTugas.selesai =>
        dasar.where((t) => t.selesai).toList(growable: false),
    };
  }

  Future<void> _tugasCepat() async {
    final tersimpan = await tampilkanTugasCepat(context, _repo);
    if (tersimpan != null) await _muat();
  }

  Future<void> _dialogTugas() async {
    final tersimpan = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogTugas(
        proyekId: widget.proyekId,
        tujuanId: widget.tujuanId,
      ),
    );
    if (tersimpan == true) await _muat();
  }

  Future<void> _ubahSelesai(BarisTugas t, bool nilai) async {
    try {
      await _repo
          .tandaiSelesai(t.id, selesai: nilai)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perubahan belum tersimpan. Coba lagi.')),
      );
      return;
    }
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final judul = widget.namaProyek != null
        ? 'Tugas · ${widget.namaProyek}'
        : (widget.namaTujuan != null ? 'Tugas · ${widget.namaTujuan}' : 'Tugas');
    final tampil = _tampil;
    return Scaffold(
      appBar: AppBar(
        title: Text(judul),
        actions: <Widget>[
          IconButton(
            key: const Key('tombol_tugas_baru'),
            tooltip: 'Tambah tugas lengkap',
            icon: const Icon(Icons.add),
            onPressed: _dialogTugas,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tombol_tugas_cepat'),
        onPressed: _tugasCepat,
        icon: const Icon(Icons.bolt_outlined),
        label: const Text('Tugas cepat'),
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: <Widget>[
                if (widget.proyekId == null && widget.tujuanId == null) ...<Widget>[
                  Text('Tugas cepat hari ini',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (_cepatHariIni.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Belum ada data',
                        key: Key('tugas_cepat_kosong'),
                      ),
                    )
                  else
                    for (final t in _cepatHariIni)
                      _kartuTugas(t, kunciAwalan: 'cepat', tampilkanProyek: false),
                  const Divider(height: 32),
                ],
                // Wrap (bukan Row): tiga chip ini tidak muat sebaris pada
                // layar sempit 420 px.
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    ChoiceChip(
                      key: const Key('filter_belum_selesai'),
                      label: const Text('Belum selesai'),
                      selected: _filter == FilterTugas.belumSelesai,
                      onSelected: (_) =>
                          setState(() => _filter = FilterTugas.belumSelesai),
                    ),
                    ChoiceChip(
                      key: const Key('filter_semua'),
                      label: const Text('Semua'),
                      selected: _filter == FilterTugas.semua,
                      onSelected: (_) =>
                          setState(() => _filter = FilterTugas.semua),
                    ),
                    ChoiceChip(
                      key: const Key('filter_selesai'),
                      label: const Text('Selesai'),
                      selected: _filter == FilterTugas.selesai,
                      onSelected: (_) =>
                          setState(() => _filter = FilterTugas.selesai),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  tampil.isEmpty
                      ? 'Belum ada data'
                      : '${tampil.length} tugas pada saringan ini',
                  key: const Key('jumlah_tugas_tampil'),
                ),
                const SizedBox(height: 8),
                for (final t in tampil) _kartuTugas(t),
              ],
            ),
    );
  }

  Widget _kartuTugas(
    BarisTugas t, {
    String kunciAwalan = 'tugas',
    bool tampilkanProyek = false,
  }) {
    final jatuhTempo = t.jatuhTempo;
    final lewat = jatuhTempo != null &&
        AksiRepository.hariSaja(jatuhTempo)
            .isBefore(AksiRepository.hariSaja(waktuSekarang()));
    return Card(
      key: Key('${kunciAwalan}_${t.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(
          key: Key('selesai_tugas_${t.id}'),
          value: t.selesai,
          onChanged: (v) => _ubahSelesai(t, v ?? false),
        ),
        title: Text(t.nama),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              jatuhTempo == null
                  ? 'Tanpa jatuh tempo'
                  : 'Jatuh tempo ${fmtTanggalId(jatuhTempo)}'
                      '${lewat ? ' · tanggal sudah lewat' : ''}',
            ),
            if (t.prioritas != 'biasa')
              Text('Prioritas ${AksiRepository.labelPrioritas(t.prioritas)}'),
            if (t.frekuensi != 'sekali') Text('Berulang: ${t.frekuensi}'),
            if (t.proyekId == null && t.tujuanId == null)
              const Text('Berdiri sendiri (tanpa proyek)')
            else if (tampilkanProyek && t.proyekId != null)
              Text('Proyek #${t.proyekId}'),
          ],
        ),
      ),
    );
  }
}

/// Form tugas lengkap: proyek/tujuan, jatuh tempo, jam, prioritas, frekuensi.
class _DialogTugas extends ConsumerStatefulWidget {
  const _DialogTugas({this.proyekId, this.tujuanId});

  final int? proyekId;
  final int? tujuanId;

  @override
  ConsumerState<_DialogTugas> createState() => _StateDialogTugas();
}

class _StateDialogTugas extends ConsumerState<_DialogTugas> {
  final _kendaliNama = TextEditingController();
  final _kendaliCatatan = TextEditingController();
  DateTime? _jatuhTempo;
  String _prioritas = 'biasa';
  String _frekuensi = 'sekali';
  String? _pesanGalat;

  static const List<String> _pilihanFrekuensi = <String>[
    'sekali',
    'harian',
    'mingguan',
    'bulanan',
    'kustom_hari',
  ];

  @override
  void dispose() {
    _kendaliNama.dispose();
    _kendaliCatatan.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final nama = _kendaliNama.text.trim();
    if (nama.isEmpty) {
      setState(() => _pesanGalat = 'Tulis dulu nama tugasnya.');
      return;
    }
    try {
      await ref.read(repoAksiProvider).simpanTugas(
            nama: nama,
            proyekId: widget.proyekId,
            tujuanId: widget.tujuanId,
            catatan: _kendaliCatatan.text.trim().isEmpty
                ? null
                : _kendaliCatatan.text.trim(),
            jatuhTempo: _jatuhTempo,
            prioritas: _prioritas,
            frekuensi: _frekuensi,
          ).timeout(const Duration(seconds: 5));
    } catch (_) {
      if (!mounted) return;
      setState(() => _pesanGalat = 'Tugas belum tersimpan. Coba lagi.');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tugas baru'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              key: const Key('form_nama_tugas'),
              controller: _kendaliNama,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nama tugas'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('form_catatan_tugas'),
              controller: _kendaliCatatan,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('form_jatuh_tempo_tugas'),
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _jatuhTempo == null
                    ? 'Pilih jatuh tempo (opsional)'
                    : 'Jatuh tempo ${fmtTanggalId(_jatuhTempo!)}',
              ),
              onPressed: () async {
                final pilih = await showDatePicker(
                  context: context,
                  initialDate: AksiRepository.hariSaja(waktuSekarang()),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (pilih != null) setState(() => _jatuhTempo = pilih);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('form_prioritas_tugas'),
              isExpanded: true,
              initialValue: _prioritas,
              decoration: const InputDecoration(labelText: 'Prioritas'),
              items: <DropdownMenuItem<String>>[
                for (final p in AksiRepository.prioritasTugas)
                  DropdownMenuItem<String>(
                    value: p,
                    child: Text(AksiRepository.labelPrioritas(p)),
                  ),
              ],
              onChanged: (v) => setState(() => _prioritas = v ?? _prioritas),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('form_frekuensi_tugas'),
              isExpanded: true,
              initialValue: _frekuensi,
              decoration: const InputDecoration(labelText: 'Pengulangan'),
              items: <DropdownMenuItem<String>>[
                for (final f in _pilihanFrekuensi)
                  DropdownMenuItem<String>(value: f, child: Text(f)),
              ],
              onChanged: (v) => setState(() => _frekuensi = v ?? _frekuensi),
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
          key: const Key('simpan_tugas'),
          onPressed: _simpan,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
