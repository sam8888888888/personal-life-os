/// Catatan Harian — satu halaman per hari (SDD v19 Gelombang 1).
///
/// Dua hal yang dipisah keras di layar ini:
/// * **Tulisan Papi** (`isi`) — hanya berubah bila Papi menekan simpan;
/// * **Ringkasan otomatis** (`ringkasan_mesin`) — hanya dibaca di sini, dan
///   ditampilkan terpisah supaya tidak pernah menimpa tulisan.
///
/// Panel "Dirujuk oleh" membaca tabel `tautan` (arah balik) — inilah gunanya
/// jaringan ikat: catatan hari ini bisa dilihat dari mana saja yang menautkannya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/v19_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/catatan_harian_repository.dart';

class CatatanHarianScreen extends ConsumerStatefulWidget {
  const CatatanHarianScreen({super.key});

  @override
  ConsumerState<CatatanHarianScreen> createState() =>
      _CatatanHarianScreenState();
}

class _CatatanHarianScreenState extends ConsumerState<CatatanHarianScreen> {
  final TextEditingController _tulis = TextEditingController();
  final TextEditingController _sorotanBaru = TextEditingController();

  DateTime _hari = DateTime.now();
  CatatanHarianData? _halaman;
  List<SorotanData> _sorotan = const <SorotanData>[];
  List<TautanData> _rujukan = const <TautanData>[];
  List<CatatanHarianData> _terakhir = const <CatatanHarianData>[];
  bool _memuat = true;
  String? _pesan;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _tulis.dispose();
    _sorotanBaru.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    try {
      final CatatanHarianRepository repo = ref.read(repoCatatanHarianProvider);
      final CatatanHarianData halaman = await repo.halaman(_hari);
      final List<SorotanData> sorotan = halaman.uid == null
          ? const <SorotanData>[]
          : await ref
              .read(repoSorotanProvider)
              .untukPemilik('catatan_harian', halaman.uid!);
      final List<TautanData> rujukan = halaman.uid == null
          ? const <TautanData>[]
          : await ref
              .read(repoTautanProvider)
              .masuk('catatan_harian', halaman.uid!);
      final List<CatatanHarianData> terakhir = await repo.berisi(batas: 10);
      if (!mounted) return;
      setState(() {
        _halaman = halaman;
        _sorotan = sorotan;
        _rujukan = rujukan;
        _terakhir = terakhir;
        _tulis.text = halaman.isi;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _pesan = 'Catatan tidak bisa dibuka: $e';
      });
    }
  }

  Future<void> _simpan() async {
    try {
      await ref.read(repoCatatanHarianProvider).simpanIsi(_hari, _tulis.text);
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.catatanHarian,
        aksi: AksiAudit.ubah,
        entitas: 'catatan_harian',
        entitasId: kunciTanggalHarian(_hari),
        ringkas: 'Catatan harian ${fmtTanggalAman(_hari)} disimpan.',
      );
      await _muat();
      if (!mounted) return;
      setState(() => _pesan = 'Catatan tersimpan.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = 'Tidak bisa menyimpan: $e');
    }
  }

  Future<void> _tambahSorotan() async {
    final String teks = _sorotanBaru.text.trim();
    final String? uid = _halaman?.uid;
    if (teks.isEmpty || uid == null) {
      setState(() => _pesan = 'Tulis dulu teks yang ingin disorot.');
      return;
    }
    try {
      await ref.read(repoSorotanProvider).tambah(
            entitas: 'catatan_harian',
            entitasUid: uid,
            kutipan: teks,
          );
      _sorotanBaru.clear();
      await _muat();
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = 'Sorotan tidak tersimpan: $e');
    }
  }

  void _geserHari(int delta) {
    setState(() => _hari = _hari.add(Duration(days: delta)));
    _muat();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final bool iniHariIni =
        kunciTanggalHarian(_hari) == kunciTanggalHarian(DateTime.now());
    final List<String> sorotanTeks = _halaman == null
        ? const <String>[]
        : ref.read(repoCatatanHarianProvider).sorotanDari(_halaman!);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Harian'),
        actions: <Widget>[
          IconButton(
            key: const Key('ch_prev'),
            onPressed: () => _geserHari(-1),
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Hari sebelumnya',
          ),
          IconButton(
            key: const Key('ch_next'),
            onPressed: () => _geserHari(1),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Hari berikutnya',
          ),
        ],
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: <Widget>[
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    key: const Key('ch_tanggal'),
                    leading: const Icon(Icons.event_note_outlined),
                    title: Text(fmtTanggalAman(_hari)),
                    subtitle: Text(iniHariIni
                        ? 'Hari ini'
                        : 'Bukan hari ini — geser panah untuk berpindah'),
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
                        TextField(
                          key: const Key('ch_isi'),
                          controller: _tulis,
                          maxLines: 6,
                          minLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Catatan hari ini',
                            hintText: 'Apa yang terjadi, apa yang dipikirkan.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          key: const Key('ch_simpan'),
                          onPressed: _simpan,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Simpan catatan'),
                        ),
                        if (_pesan != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(_pesan!, key: const Key('ch_pesan')),
                        ],
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
                        Text('Ringkasan otomatis',
                            style: tema.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          _halaman?.ringkasanMesin == null ||
                                  _halaman!.ringkasanMesin!.isEmpty
                              ? 'Belum ada ringkasan untuk hari ini.'
                              : _halaman!.ringkasanMesin!,
                          key: const Key('ch_ringkasan'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ringkasan ini dibuat mesin dan disimpan terpisah — '
                          'tidak pernah menimpa tulisan Papi.',
                          style: tema.textTheme.bodySmall,
                        ),
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
                        Text('Sorotan', style: tema.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        if (_halaman != null &&
                            ref
                                .read(repoCatatanHarianProvider)
                                .sorotanRusak(_halaman!))
                          const Text(
                            'Sorotan otomatis hari ini tidak bisa dibaca.',
                            key: Key('ch_sorotan_rusak'),
                          ),
                        for (final String s in sorotanTeks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Icon(Icons.auto_awesome, size: 16),
                                const SizedBox(width: 6),
                                Expanded(child: Text(s)),
                              ],
                            ),
                          ),
                        for (final SorotanData s in _sorotan)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Icon(Icons.format_quote, size: 16),
                                const SizedBox(width: 6),
                                Expanded(child: Text(s.kutipan)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('ch_sorotan_baru'),
                          controller: _sorotanBaru,
                          decoration: const InputDecoration(
                            labelText: 'Tandai kalimat penting',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          key: const Key('ch_sorotan_tambah'),
                          onPressed: _tambahSorotan,
                          child: const Text('Tambah sorotan'),
                        ),
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
                        Text('Dirujuk oleh',
                            style: tema.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        if (_rujukan.isEmpty)
                          const Text(
                            'Belum ada catatan lain yang menautkan ke halaman ini.',
                            key: Key('ch_rujukan_kosong'),
                          ),
                        for (final TautanData t in _rujukan)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.link, size: 18),
                            title: Text(t.judulA.isEmpty
                                ? t.entitasA
                                : t.judulA),
                            subtitle: Text(t.label ?? t.entitasA),
                          ),
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
                        Text('Hari yang sudah ditulis',
                            style: tema.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        if (_terakhir.isEmpty)
                          const Text('Belum ada catatan yang ditulis.',
                              key: Key('ch_terakhir_kosong')),
                        for (final CatatanHarianData c in _terakhir)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(fmtTanggalAman(c.tanggal)),
                            subtitle: Text(
                              c.isi.replaceAll('\n', ' '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              setState(() => _hari = c.tanggal);
                              _muat();
                            },
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
