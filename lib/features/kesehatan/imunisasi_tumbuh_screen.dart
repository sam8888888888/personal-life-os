/// SDD v19 Gelombang 2 — Layar imunisasi & tumbuh kembang (dua layar satu
/// berkas, karena keduanya selalu dipakai bersama saat memeriksa anak).
///
/// [ImunisasiScreen] = **rekaman** apa yang sudah diberikan (bukan janji).
/// [TumbuhKembangScreen] = deret pengukuran anak, disajikan apa adanya.
///
/// Dua kejujuran yang dinyatakan terus-terang di layar:
/// 1. jadwal dosis berikutnya tidak pernah dihitung aplikasi — hanya diingat
///    dari tanggal yang diisi manusia;
/// 2. persentil tumbuh kembang belum ditampilkan karena tabel rujukan kurva
///    belum dipasang, jadi angkanya tidak ditebak.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/kesehatan_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/imunisasi_repository.dart';
import '../../data/repository/tumbuh_kembang_repository.dart';

// ───────────────────────────────────────────────────────────── imunisasi
class ImunisasiScreen extends ConsumerStatefulWidget {
  const ImunisasiScreen({super.key});

  @override
  ConsumerState<ImunisasiScreen> createState() => _ImunisasiScreenState();
}

class _ImunisasiScreenState extends ConsumerState<ImunisasiScreen> {
  final TextEditingController _vaksin = TextEditingController();

  int? _anggotaId;
  int _dosis = 1;
  DateTime _tanggal = DateTime.now();
  DateTime? _berikutnya;
  List<ImunisasiData> _riwayat = const <ImunisasiData>[];
  bool _memuat = true;
  String? _pesan;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _vaksin.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final List<ImunisasiData> r = _anggotaId == null
          ? const <ImunisasiData>[]
          : await ref.read(repoImunisasiProvider).riwayat(_anggotaId!);
      if (!mounted) return;
      setState(() {
        _riwayat = r;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _pesan = 'Riwayat tidak bisa dibuka: $e';
      });
    }
  }

  Future<void> _pilihTanggal({required bool berikutnya}) async {
    final DateTime? pilih = await showDatePicker(
      context: context,
      initialDate: berikutnya ? (_berikutnya ?? DateTime.now()) : _tanggal,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 20),
    );
    if (pilih == null) return;
    setState(() {
      if (berikutnya) {
        _berikutnya = pilih;
      } else {
        _tanggal = pilih;
      }
    });
  }

  Future<void> _simpan() async {
    setState(() => _pesan = null);
    if (_anggotaId == null) {
      setState(() => _pesan = 'Pilih dulu anggota keluarganya.');
      return;
    }
    try {
      await ref.read(repoImunisasiProvider).tambah(
            anggotaId: _anggotaId!,
            namaVaksin: _vaksin.text,
            tanggal: _tanggal,
            dosisKe: _dosis,
            berikutnyaPada: _berikutnya,
          );
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.imunisasi,
        aksi: AksiAudit.buat,
        entitas: 'imunisasi',
        ringkas: 'Imunisasi ${_vaksin.text.trim()} dosis $_dosis dicatat '
            '(${fmtTanggalAman(_tanggal)}).',
      );
      _vaksin.clear();
      setState(() {
        _berikutnya = null;
        _dosis = 1;
      });
      await _muat();
      if (!mounted) return;
      setState(() => _pesan = 'Imunisasi tersimpan.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final AsyncValue<List<AnggotaKeluargaData>> anggota =
        ref.watch(daftarAnggotaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Imunisasi')),
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
                  Text('Catat imunisasi', style: tema.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  anggota.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (Object e, StackTrace s) =>
                        Text('Daftar anggota gagal dimuat: $e'),
                    data: (List<AnggotaKeluargaData> daftar) => daftar.isEmpty
                        ? const Text(
                            'Belum ada anggota keluarga. Tambahkan dulu di menu '
                            'Keluarga.',
                            key: Key('imun_tanpa_anggota'),
                          )
                        : DropdownButtonFormField<int>(
                            key: const Key('imun_anggota'),
                            initialValue: _anggotaId,
                            decoration: const InputDecoration(
                              labelText: 'Untuk siapa',
                              border: OutlineInputBorder(),
                            ),
                            items: <DropdownMenuItem<int>>[
                              for (final AnggotaKeluargaData a in daftar)
                                DropdownMenuItem<int>(
                                  value: a.id,
                                  child: Text(a.nama),
                                ),
                            ],
                            onChanged: (int? v) {
                              setState(() => _anggotaId = v);
                              _muat();
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('imun_vaksin'),
                    controller: _vaksin,
                    decoration: const InputDecoration(
                      labelText: 'Nama vaksin',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      for (final String v in vaksinUmum)
                        ActionChip(
                          label: Text(v),
                          onPressed: () => setState(() => _vaksin.text = v),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: const Key('imun_dosis'),
                          initialValue: _dosis,
                          decoration: const InputDecoration(
                            labelText: 'Dosis ke',
                            border: OutlineInputBorder(),
                          ),
                          items: <DropdownMenuItem<int>>[
                            for (int i = 1; i <= 5; i++)
                              DropdownMenuItem<int>(value: i, child: Text('$i')),
                          ],
                          onChanged: (int? v) =>
                              setState(() => _dosis = v ?? 1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('imun_tanggal'),
                          onPressed: () => _pilihTanggal(berikutnya: false),
                          icon: const Icon(Icons.event),
                          label: Text('Diberikan:\n${fmtTanggalAman(_tanggal)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('imun_berikutnya'),
                    onPressed: () => _pilihTanggal(berikutnya: true),
                    icon: const Icon(Icons.event_repeat),
                    label: Text(_berikutnya == null
                        ? 'Dosis berikutnya (boleh dikosongkan)'
                        : 'Berikutnya: ${fmtTanggalAman(_berikutnya!)}'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('imun_simpan'),
                    onPressed: _simpan,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Simpan imunisasi'),
                  ),
                  if (_pesan != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(_pesan!, key: const Key('imun_pesan')),
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
                _memuat ? 'Memuat…' : 'Riwayat: ${_riwayat.length} dosis',
                key: const Key('imun_judul_riwayat'),
                style: tema.textTheme.titleMedium,
              ),
            ),
          ),
          if (_anggotaId == null)
            const Card(
              margin: EdgeInsets.only(top: 12),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Pilih anggota untuk melihat riwayatnya.',
                    key: Key('imun_belum_pilih')),
              ),
            ),
          for (final ImunisasiData i in _riwayat)
            Card(
              key: Key('imun_baris_${i.id}'),
              margin: const EdgeInsets.only(top: 12),
              child: ListTile(
                leading: const Icon(Icons.vaccines_outlined),
                title: Text('${i.namaVaksin} · dosis ${i.dosisKe}'),
                subtitle: Text(
                  '${fmtTanggalAman(i.tanggal)}'
                  '${i.berikutnyaPada == null ? '' : ' · berikutnya ${fmtTanggalAman(i.berikutnyaPada!)}'}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────── tumbuh kembang
class TumbuhKembangScreen extends ConsumerStatefulWidget {
  const TumbuhKembangScreen({super.key});

  @override
  ConsumerState<TumbuhKembangScreen> createState() =>
      _TumbuhKembangScreenState();
}

class _TumbuhKembangScreenState extends ConsumerState<TumbuhKembangScreen> {
  final TextEditingController _berat = TextEditingController();
  final TextEditingController _tinggi = TextEditingController();
  final TextEditingController _lingkar = TextEditingController();

  int? _anggotaId;
  DateTime _tanggal = DateTime.now();
  List<TumbuhKembangData> _deret = const <TumbuhKembangData>[];
  bool _memuat = true;
  String? _pesan;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _berat.dispose();
    _tinggi.dispose();
    _lingkar.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final List<TumbuhKembangData> d = _anggotaId == null
          ? const <TumbuhKembangData>[]
          : await ref.read(repoTumbuhKembangProvider).deret(_anggotaId!);
      if (!mounted) return;
      setState(() {
        _deret = d;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _pesan = 'Data tumbuh kembang tidak bisa dibuka: $e';
      });
    }
  }

  double? _angka(TextEditingController k) {
    final String t = k.text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  Future<void> _pilihTanggal() async {
    final DateTime? pilih = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (pilih == null) return;
    setState(() => _tanggal = pilih);
  }

  Future<void> _simpan() async {
    setState(() => _pesan = null);
    if (_anggotaId == null) {
      setState(() => _pesan = 'Pilih dulu anak yang diukur.');
      return;
    }
    try {
      final List<AnggotaKeluargaData> daftar =
          await ref.read(daftarAnggotaProvider.future);
      DateTime? lahir;
      for (final AnggotaKeluargaData a in daftar) {
        if (a.id == _anggotaId) lahir = a.tanggalLahir;
      }
      if (lahir == null) {
        setState(() => _pesan =
            'Tanggal lahir anak ini belum diisi, jadi umurnya belum bisa '
            'dihitung. Isi dulu di menu Keluarga.');
        return;
      }
      await ref.read(repoTumbuhKembangProvider).simpan(
            anggotaId: _anggotaId!,
            tanggal: _tanggal,
            umurBulan: TumbuhKembangRepository.umurBulanPada(lahir, _tanggal),
            beratKg: _angka(_berat),
            tinggiCm: _angka(_tinggi),
            lingkarKepalaCm: _angka(_lingkar),
          );
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.tumbuhKembang,
        aksi: AksiAudit.buat,
        entitas: 'tumbuh_kembang',
        ringkas: 'Pengukuran anak dicatat (${fmtTanggalAman(_tanggal)}).',
      );
      _berat.clear();
      _tinggi.clear();
      _lingkar.clear();
      await _muat();
      if (!mounted) return;
      setState(() => _pesan = 'Pengukuran tersimpan.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final AsyncValue<List<AnggotaKeluargaData>> anggota =
        ref.watch(daftarAnggotaProvider);
    final TumbuhKembangData? terakhir = _deret.isEmpty ? null : _deret.last;
    final double? imt = terakhir == null
        ? null
        : TumbuhKembangRepository.imt(
            beratKg: terakhir.beratKg, tinggiCm: terakhir.tinggiCm);
    return Scaffold(
      appBar: AppBar(title: const Text('Tumbuh Kembang')),
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
                  Text('Catat pengukuran', style: tema.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  anggota.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (Object e, StackTrace s) =>
                        Text('Daftar anggota gagal dimuat: $e'),
                    data: (List<AnggotaKeluargaData> daftar) => daftar.isEmpty
                        ? const Text(
                            'Belum ada anggota keluarga. Tambahkan dulu di menu '
                            'Keluarga.',
                            key: Key('tk_tanpa_anggota'),
                          )
                        : DropdownButtonFormField<int>(
                            key: const Key('tk_anggota'),
                            initialValue: _anggotaId,
                            decoration: const InputDecoration(
                              labelText: 'Anak yang diukur',
                              border: OutlineInputBorder(),
                            ),
                            items: <DropdownMenuItem<int>>[
                              for (final AnggotaKeluargaData a in daftar)
                                DropdownMenuItem<int>(
                                  value: a.id,
                                  child: Text(a.nama),
                                ),
                            ],
                            onChanged: (int? v) {
                              setState(() => _anggotaId = v);
                              _muat();
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('tk_tanggal'),
                    onPressed: _pilihTanggal,
                    icon: const Icon(Icons.event),
                    label: Text('Tanggal ukur: ${fmtTanggalAman(_tanggal)}'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          key: const Key('tk_berat'),
                          controller: _berat,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Berat (kg)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const Key('tk_tinggi'),
                          controller: _tinggi,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Tinggi (cm)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const Key('tk_lingkar'),
                          controller: _lingkar,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Lingkar kepala (cm)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('tk_simpan'),
                    onPressed: _simpan,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Simpan pengukuran'),
                  ),
                  if (_pesan != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(_pesan!, key: const Key('tk_pesan')),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (terakhir != null)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Pengukuran terakhir',
                        style: tema.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${fmtTanggalAman(terakhir.tanggal)} · umur '
                      '${terakhir.umurBulan} bulan',
                      key: const Key('tk_terakhir_tanggal'),
                    ),
                    Text(
                      '${terakhir.beratKg == null ? '-' : '${terakhir.beratKg} kg'}'
                      ' · ${terakhir.tinggiCm == null ? '-' : '${terakhir.tinggiCm} cm'}'
                      '${terakhir.lingkarKepalaCm == null ? '' : ' · lingkar ${terakhir.lingkarKepalaCm} cm'}',
                      key: const Key('tk_terakhir_ukur'),
                    ),
                    if (imt != null)
                      Text('Indeks massa tubuh: $imt (aritmetika sederhana)'),
                    const SizedBox(height: 6),
                    Text(
                      TumbuhKembangRepository.alasanPersentilKosong(
                        beratKg: terakhir.beratKg,
                        tinggiCm: terakhir.tinggiCm,
                      ),
                      key: const Key('tk_catatan_persentil'),
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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text(
                _memuat ? 'Memuat…' : 'Riwayat ukur: ${_deret.length}',
                key: const Key('tk_judul_deret'),
                style: tema.textTheme.titleMedium,
              ),
            ),
          ),
          if (_anggotaId != null && !_memuat && _deret.isEmpty)
            const Card(
              margin: EdgeInsets.only(top: 12),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada pengukuran untuk anak ini.',
                    key: Key('tk_kosong')),
              ),
            ),
          for (final TumbuhKembangData t in _deret.reversed)
            Card(
              key: Key('tk_baris_${t.id}'),
              margin: const EdgeInsets.only(top: 12),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.straighten_outlined),
                title: Text(
                  '${t.beratKg == null ? '-' : '${t.beratKg} kg'} · '
                  '${t.tinggiCm == null ? '-' : '${t.tinggiCm} cm'}',
                ),
                subtitle: Text(
                    '${fmtTanggalAman(t.tanggal)} · ${t.umurBulan} bulan'),
              ),
            ),
        ],
      ),
    );
  }
}
