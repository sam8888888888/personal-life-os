/// Layar Quran (FR-93) — catat baca, dengar, hafal baru, murajaah; target
/// harian & mingguan; ringkasan 7 & 30 hari.
///
/// Aturan penting (kejujuran angka): satuan yang berbeda (halaman, ayat, menit,
/// juz) TIDAK dijumlahkan menjadi satu angka. Progres selalu dibandingkan
/// dengan target pada satuan yang sama.
///
/// Aturan bahasa (PRD III-11): penanda selesai/belum memakai kata "tercatat",
/// tanpa hukuman, tanpa skor, dan tanpa tuduhan.
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

/// Layar catatan Quran (FR-93).
class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key});

  @override
  ConsumerState<QuranScreen> createState() => _StateQuran();
}

class _StateQuran extends ConsumerState<QuranScreen> {
  static const Duration _batas = Duration(seconds: 5);

  late final IbadahLanjutanRepository _repo;
  late final SetelanIbadahLanjutan _setelan;

  bool _memuat = true;
  bool _galat = false;
  List<LogQuranData> _baris = const <LogQuranData>[];
  double _targetHarian = 1;
  double _targetMingguan = 7;
  SatuanQuran _satuanTarget = SatuanQuran.halaman;

  late DateTime _tanggal;
  JenisQuran _jenis = JenisQuran.baca;
  SatuanQuran _satuan = SatuanQuran.halaman;
  final TextEditingController _jumlah = TextEditingController();
  final TextEditingController _bagian = TextEditingController();
  final TextEditingController _catatan = TextEditingController();
  final TextEditingController _inputHarian = TextEditingController();
  final TextEditingController _inputMingguan = TextEditingController();

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
    _jumlah.dispose();
    _bagian.dispose();
    _catatan.dispose();
    _inputHarian.dispose();
    _inputMingguan.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    if (mounted) setState(() => _memuat = true);
    final DateTime hariIni = IbadahLanjutanRepository.hari(waktuSekarang());
    try {
      final List<LogQuranData> baris = await _repo
          .quranRentang(
              IbadahLanjutanRepository.mulaiRentang(hariIni, 30),
              hariIni.add(const Duration(days: 1)))
          .timeout(_batas);
      final double harian = await _setelan.targetQuranHarian().timeout(_batas);
      final double mingguan = await _setelan.targetQuranMingguan().timeout(_batas);
      final SatuanQuran satuan = await _setelan.satuanQuran().timeout(_batas);
      if (!mounted) return;
      setState(() {
        _baris = baris;
        _targetHarian = harian;
        _targetMingguan = mingguan;
        _satuanTarget = satuan;
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

  Future<void> _simpan() async {
    final double? jumlah = angkaDesimal(_jumlah.text);
    if (jumlah == null || jumlah <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Isi jumlah lebih dari 0 supaya catatan bermakna')));
      return;
    }
    try {
      await _repo
          .tambahQuran(
            tanggal: _tanggal,
            jenis: _jenis,
            jumlah: jumlah,
            satuan: _satuan,
            bagian: _bagian.text,
            catatan: _catatan.text,
          )
          .timeout(_batas);
      _jumlah.clear();
      _bagian.clear();
      _catatan.clear();
      await _muat();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Catatan Quran tersimpan di perangkat Anda')));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Catatan belum bisa disimpan saat ini')));
    }
  }

  Future<void> _hapus(LogQuranData baris) async {
    await _repo.hapusQuran(baris.id).timeout(_batas);
    await _muat();
  }

  Future<void> _simpanTarget() async {
    final double? harian = angkaDesimal(_inputHarian.text);
    final double? mingguan = angkaDesimal(_inputMingguan.text);
    if (harian != null) {
      await _setelan.simpanTargetQuranHarian(harian).timeout(_batas);
    }
    if (mingguan != null) {
      await _setelan.simpanTargetQuranMingguan(mingguan).timeout(_batas);
    }
    _inputHarian.clear();
    _inputMingguan.clear();
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
    final DateTime hariIni = IbadahLanjutanRepository.hari(waktuSekarang());
    final Map<DateTime, double> harian =
        totalQuranHarian(_baris, _satuanTarget);
    final double totalHariIni = harian[hariIni] ?? 0;
    final DateTime mulai7 = IbadahLanjutanRepository.mulaiRentang(hariIni, 7);
    final double total7 = harian.entries
        .where((MapEntry<DateTime, double> e) => !e.key.isBefore(mulai7))
        .fold<double>(0, (double a, MapEntry<DateTime, double> e) => a + e.value);
    final Map<SatuanQuran, double> perSatuan = totalQuranPerSatuan(_baris);
    final Map<JenisQuran, double> perJenis = totalQuranPerJenis(_baris, _satuanTarget);

    return Scaffold(
      appBar: AppBar(title: const Text('Quran')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: <Widget>[
          KartuBagian(
            judul: 'Catat aktivitas Quran',
            isi: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InkWell(
                  key: const Key('tanggal_quran'),
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
                DropdownButtonFormField<JenisQuran>(
                  isExpanded: true,
                  key: const Key('jenis_quran'),
                  initialValue: _jenis,
                  decoration: const InputDecoration(labelText: 'Jenis'),
                  items: <DropdownMenuItem<JenisQuran>>[
                    for (final JenisQuran j in JenisQuran.values)
                      DropdownMenuItem<JenisQuran>(value: j, child: Text(j.label)),
                  ],
                  onChanged: (JenisQuran? j) =>
                      setState(() => _jenis = j ?? JenisQuran.baca),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('jumlah_quran'),
                  controller: _jumlah,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Jumlah',
                    hintText: 'Misalnya 3',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SatuanQuran>(
                  isExpanded: true,
                  key: const Key('satuan_quran'),
                  initialValue: _satuan,
                  decoration: const InputDecoration(labelText: 'Satuan'),
                  items: <DropdownMenuItem<SatuanQuran>>[
                    for (final SatuanQuran s in SatuanQuran.values)
                      DropdownMenuItem<SatuanQuran>(
                          value: s, child: Text(s.label)),
                  ],
                  onChanged: (SatuanQuran? s) =>
                      setState(() => _satuan = s ?? SatuanQuran.halaman),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('bagian_quran'),
                  controller: _bagian,
                  decoration: const InputDecoration(
                    labelText: 'Bagian (opsional)',
                    hintText: 'Misalnya Al-Baqarah 1-5',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('catatan_quran'),
                  controller: _catatan,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('simpan_quran'),
                  onPressed: _simpan,
                  child: const Text('Simpan catatan'),
                ),
              ],
            ),
          ),
          KartuBagian(
            judul: 'Target Anda',
            isi: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DropdownButtonFormField<SatuanQuran>(
                  isExpanded: true,
                  key: const Key('satuan_target_quran'),
                  initialValue: _satuanTarget,
                  decoration:
                      const InputDecoration(labelText: 'Satuan target'),
                  items: <DropdownMenuItem<SatuanQuran>>[
                    for (final SatuanQuran s in SatuanQuran.values)
                      DropdownMenuItem<SatuanQuran>(
                          value: s, child: Text(s.label)),
                  ],
                  onChanged: (SatuanQuran? s) async {
                    final SatuanQuran baru = s ?? SatuanQuran.halaman;
                    setState(() => _satuanTarget = baru);
                    await _setelan.simpanSatuanQuran(baru).timeout(_batas);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('target_harian_quran'),
                  controller: _inputHarian,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'Target harian',
                      hintText: teksAngkaDesimal(_targetHarian)),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('target_mingguan_quran'),
                  controller: _inputMingguan,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'Target mingguan',
                      hintText: teksAngkaDesimal(_targetMingguan)),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('simpan_target_quran'),
                  onPressed: _simpanTarget,
                  child: const Text('Simpan target'),
                ),
                const Divider(height: 20),
                if (_targetHarian <= 0)
                  const Text('Target harian belum diisi')
                else
                  BarisRingkasan(
                      label: 'Tercatat hari ini (${_satuanTarget.label})',
                      nilai:
                          '${teksAngkaDesimal(totalHariIni)} dari ${teksAngkaDesimal(_targetHarian)}'),
                if (_targetMingguan > 0)
                  BarisRingkasan(
                      label: 'Tercatat 7 hari terakhir (${_satuanTarget.label})',
                      nilai:
                          '${teksAngkaDesimal(total7)} dari ${teksAngkaDesimal(_targetMingguan)}'),
                const CatatanJujur(
                    teks: 'Penanda di atas hanya membandingkan catatan Anda '
                        'dengan target yang Anda isi sendiri.'),
              ],
            ),
          ),
          KartuBagian(
            judul: '7 hari terakhir (${_satuanTarget.label})',
            isi: _memuat
                ? const Text('Membaca catatan...')
                : _galat
                    ? const Text('Catatan belum bisa dibaca saat ini')
                    : _baris.isEmpty
                        ? const BarisKosong(
                            keterangan:
                                'Catat aktivitas Quran lewat kartu di atas.')
                        : GrafikBatang(
                            nilai: <DateTime, double>{
                              for (final DateTime t in _tanggalRentang(hariIni, 7))
                                t: harian[t] ?? 0,
                            },
                            satuanTeks: _satuanTarget.label,
                          ),
          ),
          KartuBagian(
            judul: '30 hari terakhir',
            isi: _memuat
                ? const Text('Membaca catatan...')
                : _baris.isEmpty
                    ? const BarisKosong()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          GrafikBatang(
                            nilai: <DateTime, double>{
                              for (final DateTime t in _tanggalRentang(hariIni, 30))
                                t: harian[t] ?? 0,
                            },
                            satuanTeks: _satuanTarget.label,
                          ),
                          const SizedBox(height: 10),
                          const Text('Total menurut satuan:'),
                          for (final SatuanQuran s in SatuanQuran.values)
                            if ((perSatuan[s] ?? 0) > 0)
                              BarisRingkasan(
                                  label: s.label,
                                  nilai: teksAngkaDesimal(perSatuan[s]!)),
                          const SizedBox(height: 8),
                          Text('Menurut jenis (${_satuanTarget.label}):',
                              style: tema.textTheme.bodyMedium),
                          for (final JenisQuran j in JenisQuran.values)
                            BarisRingkasan(
                                label: j.label,
                                nilai:
                                    '${teksAngkaDesimal(perJenis[j] ?? 0)} ${_satuanTarget.label}'),
                        ],
                      ),
          ),
          KartuBagian(
            judul: 'Catatan 30 hari terakhir',
            isi: _baris.isEmpty
                ? const BarisKosong()
                : Column(
                    children: <Widget>[
                      for (final LogQuranData b in _baris)
                        ListTile(
                          key: Key('baris_quran_${b.id}'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.menu_book_outlined),
                          title: Text('${teksTanggal(b.tanggal)} · '
                              '${JenisQuran.dariDb(b.jenis).label} · '
                              '${teksAngkaDesimal(b.jumlah)} '
                              '${SatuanQuran.dariDb(b.satuan).label}'),
                          subtitle: b.bagian == null && b.catatan == null
                              ? null
                              : Text(<String>[
                                  if (b.bagian != null) b.bagian!,
                                  if (b.catatan != null) b.catatan!,
                                ].join(' · ')),
                          trailing: IconButton(
                            key: Key('hapus_quran_${b.id}'),
                            onPressed: () => _hapus(b),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Hapus catatan',
                          ),
                        ),
                    ],
                  ),
          ),
          const CatatanJujur(
              teks: 'Halaman, ayat, menit, dan juz tidak dijumlahkan menjadi '
                  'satu angka karena satuannya berbeda.'),
        ],
      ),
    );
  }

  /// Daftar tanggal [jumlahHari] terakhir (termasuk [hariIni]), urut lama→baru.
  static List<DateTime> _tanggalRentang(DateTime hariIni, int jumlahHari) =>
      <DateTime>[
        for (int i = jumlahHari - 1; i >= 0; i--)
          hariIni.subtract(Duration(days: i)),
      ];
}
