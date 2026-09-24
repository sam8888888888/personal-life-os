/// SDD v19 Gelombang 3 — Layar Orang (CRM pribadi).
///
/// [OrangScreen] = daftar + tambah. [OrangDetailScreen] = satu orang.
///
/// Dua hal yang terlihat sengaja di layar:
/// * pengingat ulang tahun **bawaan MATI**; ada saklarnya sendiri dengan
///   penjelasan, bukan diam-diam menyala;
/// * catatan "terakhir dihubungi" **hanya** berubah kalau pengguna menekan
///   tombolnya — aplikasi tidak melacak siapa pun.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audit/audit_log.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/pola_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/orang_repository.dart';

const String kunciSaklarUltah = 'ingatkan_ultah_orang';

class OrangScreen extends ConsumerStatefulWidget {
  const OrangScreen({super.key});

  @override
  ConsumerState<OrangScreen> createState() => _OrangScreenState();
}

class _OrangScreenState extends ConsumerState<OrangScreen> {
  final TextEditingController _nama = TextEditingController();
  final TextEditingController _peran = TextEditingController();
  final TextEditingController _telepon = TextEditingController();
  final TextEditingController _cari = TextEditingController();

  String _hubungan = 'lain';
  DateTime? _ulangTahun;
  List<OrangData> _daftar = const <OrangData>[];
  Map<String, int> _jumlah = const <String, int>{};
  bool _saklarUltah = false;
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
    _peran.dispose();
    _telepon.dispose();
    _cari.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final OrangRepository repo = ref.read(repoOrangProvider);
      final List<OrangData> d =
          await repo.daftar(cari: _cari.text, hubungan: null);
      final Map<String, int> j = await repo.jumlahPerHubungan();
      final bool saklar = await ref
          .read(pengaturanRepoProvider)
          .bacaSaklar(kunciSaklarUltah, bawaan: false);
      if (!mounted) return;
      setState(() {
        _daftar = d;
        _jumlah = j;
        _saklarUltah = saklar;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _pesan = 'Daftar orang tidak bisa dibuka: $e';
      });
    }
  }

  Future<void> _pilihUltah() async {
    final DateTime? pilih = await showDatePicker(
      context: context,
      initialDate: _ulangTahun ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (pilih == null) return;
    setState(() => _ulangTahun = pilih);
  }

  Future<void> _simpan() async {
    setState(() => _pesan = null);
    try {
      await ref.read(repoOrangProvider).tambah(
            nama: _nama.text,
            hubungan: _hubungan,
            peran: _peran.text.trim().isEmpty ? null : _peran.text,
            telepon: _telepon.text.trim().isEmpty ? null : _telepon.text,
            ulangTahun: _ulangTahun,
          );
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.orang,
        aksi: AksiAudit.buat,
        entitas: 'orang',
        ringkas: 'Orang ${_nama.text.trim()} dicatat ($_hubungan).',
      );
      _nama.clear();
      _peran.clear();
      _telepon.clear();
      setState(() {
        _ulangTahun = null;
        _hubungan = 'lain';
      });
      await _muat();
      if (!mounted) return;
      setState(() => _pesan = 'Tersimpan.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = '$e');
    }
  }

  Future<void> _ubahSaklarUltah(bool nilai) async {
    await ref
        .read(pengaturanRepoProvider)
        .simpan(kunciSaklarUltah, nilai ? '1' : '0');
    if (!mounted) return;
    setState(() => _saklarUltah = nilai);
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Orang & Kontak')),
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
                  Text('Tambah orang', style: tema.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('orang_nama'),
                    controller: _nama,
                    decoration: const InputDecoration(
                      labelText: 'Nama',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: const Key('orang_hubungan'),
                    initialValue: _hubungan,
                    decoration: const InputDecoration(
                      labelText: 'Hubungan',
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final String h in hubunganOrang)
                        DropdownMenuItem<String>(value: h, child: Text(h)),
                    ],
                    onChanged: (String? v) =>
                        setState(() => _hubungan = v ?? 'lain'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('orang_peran'),
                    controller: _peran,
                    decoration: const InputDecoration(
                      labelText: 'Peran (mis. dokter gigi anak)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('orang_telepon'),
                    controller: _telepon,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telepon (boleh dikosongkan)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        key: const Key('orang_ultah'),
                        onPressed: _pilihUltah,
                        icon: const Icon(Icons.cake_outlined),
                        label: Text(_ulangTahun == null
                            ? 'Ulang tahun (boleh kosong)'
                            : fmtTanggalAman(_ulangTahun!)),
                      ),
                      FilledButton.icon(
                        key: const Key('orang_simpan'),
                        onPressed: _simpan,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Simpan'),
                      ),
                    ],
                  ),
                  if (_pesan != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(_pesan!, key: const Key('orang_pesan')),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  key: const Key('orang_saklar_ultah'),
                  value: _saklarUltah,
                  onChanged: _ubahSaklarUltah,
                  title: const Text('Ingatkan ulang tahun orang'),
                  subtitle: const Text(
                      'Bawaan MATI. Menyalakan ini membuat aplikasi mengingatkan '
                      'ulang tahun orang yang datanya Papi isi sendiri.'),
                ),
                if (_saklarUltah)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: FutureBuilder<List<OrangData>>(
                      future: ref.read(repoOrangProvider).ulangTahunDekat(),
                      builder: (BuildContext c,
                          AsyncSnapshot<List<OrangData>> snap) {
                        final List<OrangData> d =
                            snap.data ?? const <OrangData>[];
                        if (d.isEmpty) {
                          return const Text(
                              'Tidak ada ulang tahun dalam 30 hari ke depan.');
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            for (final OrangData o in d)
                              Text('• ${o.nama} — '
                                  '${o.ulangTahun == null ? '' : fmtTanggalAman(o.ulangTahun!)}'),
                          ],
                        );
                      },
                    ),
                  ),
              ],
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
                  Text('Ringkasan', style: tema.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  if (_jumlah.isEmpty)
                    const Text('Belum ada orang yang dicatat.',
                        key: Key('orang_ringkas_kosong'))
                  else
                    Text(_jumlah.entries
                        .map((MapEntry<String, int> e) =>
                            '${e.key}: ${e.value}')
                        .join(' · ')),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('orang_cari'),
                    controller: _cari,
                    onSubmitted: (_) => _muat(),
                    decoration: InputDecoration(
                      labelText: 'Cari nama',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        key: const Key('orang_cari_tombol'),
                        icon: const Icon(Icons.search),
                        onPressed: _muat,
                      ),
                    ),
                  ),
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
                _memuat ? 'Memuat…' : 'Daftar orang: ${_daftar.length}',
                key: const Key('orang_judul_daftar'),
                style: tema.textTheme.titleMedium,
              ),
            ),
          ),
          for (final OrangData o in _daftar)
            Card(
              key: Key('orang_baris_${o.id}'),
              margin: const EdgeInsets.only(top: 12),
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(o.nama),
                subtitle: Text(<String>[
                  o.hubungan,
                  if (o.peran != null) o.peran!,
                  if (o.telepon != null) o.telepon!,
                ].join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/orang/${o.id}'),
              ),
            ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────── detail orang
class OrangDetailScreen extends ConsumerStatefulWidget {
  const OrangDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<OrangDetailScreen> createState() => _OrangDetailScreenState();
}

class _OrangDetailScreenState extends ConsumerState<OrangDetailScreen> {
  OrangData? _orang;
  bool _memuat = true;
  String? _pesan;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final OrangData? o = await ref.read(repoOrangProvider).cariId(widget.id);
      if (!mounted) return;
      setState(() {
        _orang = o;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _pesan = 'Tidak bisa dibuka: $e';
      });
    }
  }

  Future<void> _tandaiDihubungi() async {
    await ref.read(repoOrangProvider).tandaiDihubungi(widget.id);
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.orang,
      aksi: AksiAudit.ubah,
      entitas: 'orang',
      entitasId: '${widget.id}',
      ringkas: 'Ditandai baru dihubungi (diisi pengguna).',
    );
    await _muat();
    if (!mounted) return;
    setState(() => _pesan = 'Ditandai hari ini.');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final OrangData? o = _orang;
    return Scaffold(
      appBar: AppBar(title: Text(o?.nama ?? 'Orang')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: <Widget>[
                if (o == null)
                  const Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Catatan orang ini tidak ditemukan.',
                          key: Key('orang_detail_hilang')),
                    ),
                  )
                else ...<Widget>[
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(o.nama, style: tema.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('Hubungan: ${o.hubungan}'),
                          if (o.peran != null) Text('Peran: ${o.peran}'),
                          if (o.telepon != null) Text('Telepon: ${o.telepon}'),
                          if (o.email != null) Text('Surel: ${o.email}'),
                          if (o.ulangTahun != null)
                            Text('Ulang tahun: ${fmtTanggalAman(o.ulangTahun!)}'),
                          Text(o.terakhirDihubungi == null
                              ? 'Terakhir dihubungi: belum pernah dicatat'
                              : 'Terakhir dihubungi: '
                                  '${fmtTanggalAman(o.terakhirDihubungi!)}'),
                          if (o.anggotaId != null)
                            Text('Terhubung ke anggota keluarga #${o.anggotaId}'),
                        ],
                      ),
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
                          const Text(
                              'Catatan "terakhir dihubungi" hanya berubah kalau '
                              'Papi menekan tombol di bawah — aplikasi tidak '
                              'melacak siapa pun.'),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            key: const Key('orang_tandai_dihubungi'),
                            onPressed: _tandaiDihubungi,
                            icon: const Icon(Icons.phone_in_talk_outlined),
                            label: const Text('Tandai baru dihubungi hari ini'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_pesan != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(_pesan!, key: const Key('orang_detail_pesan')),
                ],
              ],
            ),
    );
  }
}
