/// SDD v19 Gelombang 2 — Layar hasil laboratorium.
///
/// Tiga layar dalam satu berkas (ketiganya satu urusan):
/// * [LabScreen] — daftar panel hasil lab + tambah panel;
/// * [LabDetailScreen] — analit di dalam satu panel + tambah analit;
/// * [TrenAnalitScreen] — perjalanan satu analit dari waktu ke waktu.
///
/// Disiplin yang terlihat di layar: rentang rujukan yang dipakai adalah rentang
/// **dari laboratorium pengguna**, dan aplikasi hanya menyatakan "di luar
/// rentang yang Anda catat" — tidak pernah menyatakan pengguna sakit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audit/audit_log.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/kesehatan_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/hasil_lab_repository.dart';

// ───────────────────────────────────────────────────────────── daftar panel
class LabScreen extends ConsumerStatefulWidget {
  const LabScreen({super.key});

  @override
  ConsumerState<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends ConsumerState<LabScreen> {
  final TextEditingController _panel = TextEditingController();
  final TextEditingController _laboratorium = TextEditingController();

  DateTime _tanggal = DateTime.now();
  List<HasilLabData> _daftar = const <HasilLabData>[];
  bool _memuat = true;
  String? _pesan;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _panel.dispose();
    _laboratorium.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final List<HasilLabData> d = await ref.read(repoHasilLabProvider).daftar();
      if (!mounted) return;
      setState(() {
        _daftar = d;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _pesan = 'Daftar hasil lab tidak bisa dibuka: $e';
      });
    }
  }

  Future<void> _pilihTanggal() async {
    final DateTime? pilih = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(_tanggal.year - 20),
      lastDate: DateTime(_tanggal.year + 1),
    );
    if (pilih == null) return;
    setState(() => _tanggal = pilih);
  }

  Future<void> _simpan() async {
    try {
      await ref.read(repoHasilLabProvider).tambah(
            tanggal: _tanggal,
            namaPanel: _panel.text,
            laboratorium:
                _laboratorium.text.trim().isEmpty ? null : _laboratorium.text,
          );
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.hasilLab,
        aksi: AksiAudit.buat,
        entitas: 'hasil_lab',
        ringkas: 'Panel hasil lab ${_panel.text.trim()} disimpan '
            '(${fmtTanggalAman(_tanggal)}).',
      );
      _panel.clear();
      _laboratorium.clear();
      await _muat();
      if (!mounted) return;
      setState(() => _pesan = 'Panel tersimpan.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Hasil Laboratorium')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: <Widget>[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Tambah panel', style: tema.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('lab_panel'),
                    controller: _panel,
                    decoration: const InputDecoration(
                      labelText: 'Nama panel (mis. Darah Lengkap)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('lab_lab'),
                    controller: _laboratorium,
                    decoration: const InputDecoration(
                      labelText: 'Laboratorium (boleh dikosongkan)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      for (final String p in panelHasilLab)
                        ActionChip(
                          label: Text(p),
                          onPressed: () => setState(() => _panel.text = p),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      OutlinedButton.icon(
                        key: const Key('lab_tanggal'),
                        onPressed: _pilihTanggal,
                        icon: const Icon(Icons.event),
                        label: Text(fmtTanggalAman(_tanggal)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        key: const Key('lab_simpan'),
                        onPressed: _simpan,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Simpan panel'),
                      ),
                    ],
                  ),
                  if (_pesan != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(_pesan!, key: const Key('lab_pesan')),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text(
                _memuat ? 'Memuat…' : 'Panel tersimpan: ${_daftar.length}',
                key: const Key('lab_judul_daftar'),
                style: tema.textTheme.titleMedium,
              ),
            ),
          ),
          if (!_memuat && _daftar.isEmpty)
            const Card(
              margin: EdgeInsets.only(top: 12),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Belum ada hasil lab yang dicatat.',
                  key: Key('lab_kosong'),
                ),
              ),
            ),
          for (final HasilLabData h in _daftar)
            Card(
              key: Key('lab_baris_${h.id}'),
              margin: const EdgeInsets.only(top: 12),
              child: ListTile(
                leading: const Icon(Icons.science_outlined),
                title: Text(h.namaPanel),
                subtitle: Text(
                  '${fmtTanggalAman(h.tanggal)}'
                  '${h.laboratorium == null ? '' : ' · ${h.laboratorium}'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/kesehatan/lab/${h.id}'),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── detail panel
class LabDetailScreen extends ConsumerStatefulWidget {
  const LabDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<LabDetailScreen> createState() => _LabDetailScreenState();
}

class _LabDetailScreenState extends ConsumerState<LabDetailScreen> {
  final TextEditingController _nama = TextEditingController();
  final TextEditingController _nilai = TextEditingController();
  final TextEditingController _nilaiTeks = TextEditingController();
  final TextEditingController _satuan = TextEditingController();
  final TextEditingController _bawah = TextEditingController();
  final TextEditingController _atas = TextEditingController();

  HasilLabData? _panel;
  List<AnalitLabData> _analit = const <AnalitLabData>[];
  bool _memuat = true;
  String? _pesan;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _nama.dispose();
    _nilai.dispose();
    _nilaiTeks.dispose();
    _satuan.dispose();
    _bawah.dispose();
    _atas.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final HasilLabRepository repo = ref.read(repoHasilLabProvider);
      final HasilLabData? panel = await (_carikan(repo));
      final List<AnalitLabData> a = await repo.analitDari(widget.id);
      if (!mounted) return;
      setState(() {
        _panel = panel;
        _analit = a;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _pesan = 'Panel tidak bisa dibuka: $e';
      });
    }
  }

  Future<HasilLabData?> _carikan(HasilLabRepository repo) async {
    final List<HasilLabData> semua = await repo.daftar();
    for (final HasilLabData h in semua) {
      if (h.id == widget.id) return h;
    }
    return null;
  }

  double? _angka(TextEditingController k) {
    final String t = k.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _simpanAnalit() async {
    setState(() => _pesan = null);
    try {
      await ref.read(repoHasilLabProvider).tambahAnalit(
            hasilLabId: widget.id,
            nama: _nama.text,
            nilai: _angka(_nilai),
            nilaiTeks: _nilaiTeks.text.trim().isEmpty ? null : _nilaiTeks.text,
            satuan: _satuan.text,
            rujukanBawah: _angka(_bawah),
            rujukanAtas: _angka(_atas),
          );
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.hasilLab,
        aksi: AksiAudit.buat,
        entitas: 'analit_lab',
        ringkas: 'Analit ${_nama.text.trim()} ditambahkan ke panel '
            '${_panel?.namaPanel ?? widget.id}.',
      );
      _nama.clear();
      _nilai.clear();
      _nilaiTeks.clear();
      _satuan.clear();
      _bawah.clear();
      _atas.clear();
      await _muat();
      if (!mounted) return;
      setState(() => _pesan = 'Analit tersimpan.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_panel?.namaPanel ?? 'Panel hasil lab')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: <Widget>[
                if (_panel != null)
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.event_note_outlined),
                      title: Text(fmtTanggalAman(_panel!.tanggal)),
                      subtitle: Text(_panel!.laboratorium ??
                          'Laboratorium belum diisi'),
                    ),
                  ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Tambah analit', style: tema.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('an_nama'),
                          controller: _nama,
                          decoration: const InputDecoration(
                            labelText: 'Nama analit (mis. Hemoglobin)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                key: const Key('an_nilai'),
                                controller: _nilai,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Angka hasil',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                key: const Key('an_satuan'),
                                controller: _satuan,
                                decoration: const InputDecoration(
                                  labelText: 'Satuan (g/dL)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('an_teks'),
                          controller: _nilaiTeks,
                          decoration: const InputDecoration(
                            labelText: 'Kalau bukan angka (mis. negatif)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                key: const Key('an_bawah'),
                                controller: _bawah,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Rujukan bawah (dari lab)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                key: const Key('an_atas'),
                                controller: _atas,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Rujukan atas (dari lab)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Rentang rujukan diisi dari lembar lab Papi. Kalau '
                          'dikosongkan, aplikasi tidak menilai apa pun.',
                          style: tema.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          key: const Key('an_simpan'),
                          onPressed: _simpanAnalit,
                          icon: const Icon(Icons.add),
                          label: const Text('Simpan analit'),
                        ),
                        if (_pesan != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(_pesan!, key: const Key('an_pesan')),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: Text('Analit tercatat: ${_analit.length}',
                        key: const Key('an_judul_daftar'),
                        style: tema.textTheme.titleMedium),
                  ),
                ),
                if (_analit.isEmpty)
                  const Card(
                    margin: EdgeInsets.only(top: 12),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Belum ada analit di panel ini.',
                        key: Key('an_kosong'),
                      ),
                    ),
                  ),
                for (final AnalitLabData a in _analit)
                  Card(
                    key: Key('an_baris_${a.id}'),
                    margin: const EdgeInsets.only(top: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(a.nama, style: tema.textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Text(
                            '${a.nilai ?? a.nilaiTeks ?? '-'}'
                            '${a.satuan.isEmpty ? '' : ' ${a.satuan}'}',
                          ),
                          if (a.bendera == 'tidak_dinilai')
                            Text(
                              'Belum dinilai — rentang rujukan dari lab belum diisi.',
                              style: tema.textTheme.bodySmall,
                            )
                          else if (a.bendera != 'normal')
                            Text(
                              'Di luar rentang rujukan yang Anda catat '
                              '(${a.bendera}).',
                              style: tema.textTheme.bodySmall,
                            ),
                          const SizedBox(height: 4),
                          TextButton(
                            key: Key('an_tren_${a.id}'),
                            onPressed: () => context.push(
                                '/kesehatan/lab/${widget.id}/tren/${Uri.encodeComponent(a.nama)}'),
                            child: const Text('Lihat tren analit ini'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ────────────────────────────────────────────────────────────── tren analit
class TrenAnalitScreen extends ConsumerStatefulWidget {
  const TrenAnalitScreen({super.key, required this.id, required this.nama});

  final int id;
  final String nama;

  @override
  ConsumerState<TrenAnalitScreen> createState() => _TrenAnalitScreenState();
}

class _TrenAnalitScreenState extends ConsumerState<TrenAnalitScreen> {
  List<TrenAnalit> _tren = const <TrenAnalit>[];
  bool _memuat = true;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final List<TrenAnalit> t =
          await ref.read(repoHasilLabProvider).trenAnalit(widget.nama);
      if (!mounted) return;
      setState(() {
        _tren = t;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _galat = 'Tren tidak bisa dibuka: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Tren ${widget.nama}')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: <Widget>[
                if (_galat != null) Text(_galat!),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Perjalanan nilai', style: tema.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(
                          _tren.isEmpty
                              ? 'Belum ada nilai untuk analit ini.'
                              : _tren
                                  .map((TrenAnalit t) => t.tampil)
                                  .join('  →  '),
                          key: const Key('tren_deret'),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Angka di atas apa adanya dari catatan Papi. Rentang '
                          'rujukan tetap milik laboratorium, bukan aplikasi.',
                          style: tema.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final TrenAnalit t in _tren.reversed)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      title: Text(t.tampil),
                      subtitle: Text(fmtTanggalAman(t.tanggal)),
                      trailing: t.diLuarRentang
                          ? const Icon(Icons.info_outline, size: 18)
                          : null,
                    ),
                  ),
              ],
            ),
    );
  }
}
