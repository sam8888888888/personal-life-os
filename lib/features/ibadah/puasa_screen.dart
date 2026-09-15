/// Layar Puasa (FR-92) — catat puasa per tanggal, ringkasan bulan ini, dan
/// hitungan qadha dari catatan pengguna sendiri.
///
/// Aturan bahasa (PRD III-11): tidak ada "skor", tidak ada "gagal", tidak ada
/// tuduhan, dan tidak ada penetapan kewajiban. Catatan "tidak puasa" disimpan
/// apa adanya; hitungan qadha selalu disebut sebagai "menurut catatan Anda".
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/repository/ibadah_lanjutan_repository.dart';
import 'ibadah_lanjutan_provider.dart';
import 'komponen_ibadah_lanjutan.dart';
import 'setelan_ibadah_lanjutan.dart';

/// Layar catatan puasa (FR-92).
class PuasaScreen extends ConsumerStatefulWidget {
  const PuasaScreen({super.key});

  @override
  ConsumerState<PuasaScreen> createState() => _StatePuasa();
}

class _StatePuasa extends ConsumerState<PuasaScreen> {
  static const Duration _batas = Duration(seconds: 5);

  late final IbadahLanjutanRepository _repo;
  late final SetelanIbadahLanjutan _setelan;

  bool _memuat = true;
  bool _galat = false;
  List<LogPuasaData> _bulanIni = const <LogPuasaData>[];
  List<LogPuasaData> _semua = const <LogPuasaData>[];
  int _targetQadha = 0;

  late DateTime _tanggal;
  JenisPuasa _jenis = JenisPuasa.ramadan;
  StatusPuasa _status = StatusPuasa.puasa;
  final TextEditingController _catatan = TextEditingController();
  final TextEditingController _target = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = ref.read(ibadahLanjutanRepoProvider);
    _setelan = ref.read(setelanIbadahLanjutanProvider);
    _tanggal = IbadahLanjutanRepository.hari(waktuSekarang());
    unawaited(_muat());
  }

  @override
  void dispose() {
    _catatan.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    if (mounted) setState(() => _memuat = true);
    final DateTime sekarang = waktuSekarang();
    try {
      final List<LogPuasaData> bulanIni =
          await _repo.puasaBulan(sekarang).timeout(_batas);
      final List<LogPuasaData> semua =
          await _repo.semuaPuasa().timeout(_batas);
      final int target = await _setelan.targetQadha().timeout(_batas);
      if (!mounted) return;
      setState(() {
        _bulanIni = bulanIni;
        _semua = semua;
        _targetQadha = target;
        _memuat = false;
        _galat = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _galat = true;
      });
    }
  }

  /// Simpan catatan; pengguna boleh menyimpan ulang tanggal & jenis yang sama.
  Future<void> _simpan() async {
    try {
      await _repo
          .simpanPuasa(
            tanggal: _tanggal,
            jenis: _jenis,
            status: _status,
            catatan: _catatan.text,
          )
          .timeout(_batas);
      _catatan.clear();
      await _muat();
      if (!mounted) return;
      final ScaffoldMessengerState pesan = ScaffoldMessenger.of(context);
      pesan.showSnackBar(const SnackBar(
          content: Text('Catatan tersimpan di perangkat Anda')));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Catatan belum bisa disimpan saat ini')));
    }
  }

  Future<void> _hapus(LogPuasaData baris) async {
    await _repo.hapusPuasa(baris.id).timeout(_batas);
    await _muat();
  }

  Future<void> _simpanTarget() async {
    final int? nilai = int.tryParse(_target.text.trim());
    await _setelan.simpanTargetQadha(nilai ?? 0).timeout(_batas);
    _target.clear();
    await _muat();
  }

  Future<void> _pilihTanggal() async {
    final DateTime? pilih = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pilih != null) setState(() => _tanggal = pilih);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final DateTime sekarang = waktuSekarang();
    final String namaBulan = _namaBulan(sekarang.month);
    final RingkasanPuasa ringkas = hitungRingkasanPuasa(_bulanIni);
    final HitungQadha qadha = hitungQadha(_semua);

    return Scaffold(
      appBar: AppBar(title: const Text('Puasa')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: <Widget>[
          KartuBagian(
            judul: 'Catat puasa',
            isi: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InkWell(
                  key: const Key('tanggal_puasa'),
                  onTap: _pilihTanggal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.event_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text('Tanggal: ${teksTanggal(_tanggal)}'),
                        const Spacer(),
                        Text('Ubah',
                            style: tema.textTheme.bodySmall
                                ?.copyWith(color: tema.colorScheme.primary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<JenisPuasa>(
                  isExpanded: true,
                  key: const Key('jenis_puasa'),
                  initialValue: _jenis,
                  decoration: const InputDecoration(labelText: 'Jenis puasa'),
                  items: <DropdownMenuItem<JenisPuasa>>[
                    for (final JenisPuasa j in JenisPuasa.values)
                      DropdownMenuItem<JenisPuasa>(
                          value: j, child: Text(j.label)),
                  ],
                  onChanged: (JenisPuasa? j) =>
                      setState(() => _jenis = j ?? JenisPuasa.ramadan),
                ),
                const SizedBox(height: 12),
                SegmentedButton<StatusPuasa>(
                  key: const Key('status_puasa'),
                  segments: const <ButtonSegment<StatusPuasa>>[
                    ButtonSegment<StatusPuasa>(
                        value: StatusPuasa.puasa, label: Text('Puasa')),
                    ButtonSegment<StatusPuasa>(
                        value: StatusPuasa.tidak, label: Text('Tidak puasa')),
                  ],
                  selected: <StatusPuasa>{_status},
                  onSelectionChanged: (Set<StatusPuasa> pilih) =>
                      setState(() => _status = pilih.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('catatan_puasa'),
                  controller: _catatan,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    hintText: 'Misalnya: sahur di rumah',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('simpan_puasa'),
                  onPressed: _simpan,
                  child: const Text('Simpan catatan'),
                ),
                const CatatanJujur(
                    teks: 'Menyimpan tanggal & jenis yang sama akan memperbarui '
                        'catatan itu, bukan menambah baris baru.'),
              ],
            ),
          ),
          KartuBagian(
            judul: 'Ringkasan $namaBulan ${sekarang.year}',
            isi: ringkas.kosong
                ? const BarisKosong(
                    keterangan: 'Catat puasa lewat kartu di atas.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      BarisRingkasan(
                          label: 'Catatan berstatus puasa',
                          nilai: '${ringkas.puasa} hari',
                          tebal: true),
                      BarisRingkasan(
                          label: 'Catatan berstatus tidak puasa',
                          nilai: '${ringkas.tidak} hari'),
                      BarisRingkasan(
                          label: 'Jumlah catatan bulan ini',
                          nilai: '${ringkas.total} hari'),
                    ],
                  ),
          ),
          KartuBagian(
            judul: 'Catatan bulan ini',
            isi: _memuat
                ? const Text('Membaca catatan...')
                : _galat
                    ? const Text('Catatan belum bisa dibaca saat ini')
                    : _bulanIni.isEmpty
                        ? const BarisKosong()
                        : Column(
                            children: <Widget>[
                              for (final LogPuasaData b in _bulanIni)
                                _BarisPuasa(
                                  baris: b,
                                  onHapus: () => _hapus(b),
                                ),
                            ],
                          ),
          ),
          KartuBagian(
            judul: 'Qadha Ramadan (menurut catatan Anda)',
            isi: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (!qadha.adaCatatan)
                  const BarisKosong(
                      keterangan: 'Belum ada catatan qadha dan belum ada '
                          'catatan Ramadan tanpa puasa.')
                else ...<Widget>[
                  BarisRingkasan(
                      label: 'Catatan Ramadan tanpa puasa',
                      nilai: '${qadha.ramadhanTanpaPuasa} hari'),
                  BarisRingkasan(
                      label: 'Qadha yang sudah tercatat',
                      nilai: '${qadha.qadhaTercatat} hari'),
                  BarisRingkasan(
                      label: 'Selisih menurut catatan Anda',
                      nilai: '${qadha.selisih} hari',
                      tebal: true),
                  if (_targetQadha > 0)
                    BarisRingkasan(
                        label: 'Sisa menurut target Anda',
                        nilai: '${_targetQadha - qadha.qadhaTercatat} hari'),
                ],
                if (_targetQadha > 0)
                  BarisRingkasan(
                      label: 'Target qadha yang Anda isi',
                      nilai: '$_targetQadha hari'),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('target_qadha'),
                  controller: _target,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target qadha (opsional, diisi sendiri)',
                    hintText: 'Misalnya 5',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('simpan_target_qadha'),
                  onPressed: _simpanTarget,
                  child: const Text('Simpan target'),
                ),
                const CatatanJujur(
                    teks: 'Aplikasi tidak menetapkan kewajiban dan tidak '
                        'menilai. Angka di atas semata-mata hasil hitung dari '
                        'catatan yang Anda tulis sendiri.'),
              ],
            ),
          ),
          const CatatanJujur(
              teks: 'Tanggal Hijriah untuk jenis Ayyamul Bidh bersifat '
                  'perhitungan; awal bulan Hijriah bisa berbeda dari '
                  'penetapan pemerintah.'),
        ],
      ),
    );
  }

  static String _namaBulan(int bulan) => const <String>[
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli',
        'Agustus', 'September', 'Oktober', 'November', 'Desember',
      ][bulan - 1];
}

class _BarisPuasa extends StatelessWidget {
  const _BarisPuasa({required this.baris, required this.onHapus});

  final LogPuasaData baris;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    final JenisPuasa jenis = JenisPuasa.dariDb(baris.jenis);
    final StatusPuasa status = StatusPuasa.dariDb(baris.status);
    final String? catatan = baris.catatan;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.event_available_outlined),
      title: Text('${teksTanggal(baris.tanggal)} · ${jenis.label}'),
      subtitle: Text(catatan == null
          ? 'Status: ${status.label}'
          : 'Status: ${status.label} · $catatan'),
      trailing: IconButton(
        key: Key('hapus_puasa_${baris.id}'),
        onPressed: onHapus,
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Hapus catatan',
      ),
    );
  }
}
