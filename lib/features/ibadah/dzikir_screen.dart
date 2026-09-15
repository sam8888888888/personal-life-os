/// Layar Dzikir & Doa (FR-95) — penghitung per sesi (pagi, petang, sebelum
/// tidur, sesi lain) dengan target yang diatur sendiri, tombol hitung, tombol
/// ulang, serta riwayat hari ini & 7 hari terakhir.
///
/// Aturan bahasa (PRD III-11): hitungan disimpan apa adanya. Tidak ada tuduhan
/// bila target belum tercapai; yang ada hanya "tercatat X dari target Y".
///
/// Catatan sumber: layar ini menyediakan beberapa lafaz yang lazim sebagai
/// contoh nama. Angka target TIDAK diambil dari kitab mana pun — semuanya
/// diisi sendiri oleh Anda lewat setelan.
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

/// Nama lafaz yang lazim dipakai sebagai contoh (bukan ketetapan aplikasi).
const List<String> contohNamaDzikir = <String>[
  'Subhanallah',
  'Alhamdulillah',
  'Allahu Akbar',
  'Astaghfirullah',
  'Laa ilaaha illallah',
];

/// Layar penghitung dzikir (FR-95).
class DzikirScreen extends ConsumerStatefulWidget {
  const DzikirScreen({super.key});

  @override
  ConsumerState<DzikirScreen> createState() => _StateDzikir();
}

class _StateDzikir extends ConsumerState<DzikirScreen> {
  static const Duration _batas = Duration(seconds: 5);

  late final IbadahLanjutanRepository _repo;
  late final SetelanIbadahLanjutan _setelan;

  bool _memuat = true;
  bool _galat = false;
  int _target = 33;
  int _tercatat = 0;
  JenisDzikir _jenis = JenisDzikir.pagi;
  final TextEditingController _nama = TextEditingController(text: 'Subhanallah');
  List<LogDzikirData> _hariIni = const <LogDzikirData>[];
  List<LogDzikirData> _rentang = const <LogDzikirData>[];

  @override
  void initState() {
    super.initState();
    _repo = ref.read(ibadahLanjutanRepoProvider);
    _setelan = ref.read(setelanIbadahLanjutanProvider);
    unawaited(_muat());
  }

  @override
  void dispose() {
    _nama.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    if (mounted) setState(() => _memuat = true);
    final DateTime hariIni = IbadahLanjutanRepository.hari(waktuSekarang());
    try {
      final int target = await _setelan.targetDzikir().timeout(_batas);
      final String nama = await _setelan.namaDzikir().timeout(_batas);
      if (_nama.text.trim() != nama) {
        _nama.text = nama;
      }
      final List<LogDzikirData> rentang = await _repo
          .dzikirRentang(IbadahLanjutanRepository.mulaiRentang(hariIni, 7),
              hariIni.add(const Duration(days: 1)))
          .timeout(_batas);
      final LogDzikirData? sesi =
          await _repo.dzikirSatu(hariIni, _jenis, _nama.text).timeout(_batas);
      if (!mounted) return;
      setState(() {
        _target = target;
        _tercatat = sesi?.tercatat ?? 0;
        _hariIni = rentang
            .where((LogDzikirData b) =>
                IbadahLanjutanRepository.hari(b.tanggal) == hariIni)
            .toList(growable: false);
        _rentang = rentang;
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

  /// Ganti sesi dzikir (pagi/petang/sebelum tidur/sesi lain).
  Future<void> _gantiJenis(JenisDzikir jenis) async {
    setState(() => _jenis = jenis);
    await _muat();
  }

  /// Pakai satu nama dari daftar contoh.
  Future<void> _pakaiNama(String nama) async {
    setState(() => _nama.text = nama);
    await _setelan.simpanNamaDzikir(nama).timeout(_batas);
    await _muat();
  }

  /// Simpan nama yang Anda tulis sendiri.
  Future<void> _simpanNama() async {
    await _setelan.simpanNamaDzikir(_nama.text).timeout(_batas);
    await _muat();
  }

  /// Hitung satu kali (menambah 1 pada hitungan yang tersimpan).
  Future<void> _hitung() async {
    if (_target <= 0) return;
    final int baru = _tercatat + 1;
    setState(() => _tercatat = baru);
    try {
      await _repo
          .catatDzikir(
            tanggal: waktuSekarang(),
            jenis: _jenis,
            nama: _nama.text,
            target: _target,
            tercatat: baru,
          )
          .timeout(_batas);
      await _muat();
    } on Object {
      if (!mounted) return;
      setState(() => _tercatat = _tercatat - 1);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Hitungan belum bisa disimpan saat ini')));
    }
  }

  /// Ulang: hitungan sesi ini kembali ke 0 (tidak menghapus riwayat).
  Future<void> _ulang() async {
    setState(() => _tercatat = 0);
    try {
      await _repo
          .catatDzikir(
            tanggal: waktuSekarang(),
            jenis: _jenis,
            nama: _nama.text,
            target: _target,
            tercatat: 0,
          )
          .timeout(_batas);
      await _muat();
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Hitungan belum bisa disimpan saat ini')));
    }
  }

  Future<void> _simpanTarget(int nilai) async {
    await _setelan.simpanTargetDzikir(nilai).timeout(_batas);
    await _muat();
  }

  Future<void> _hapus(LogDzikirData baris) async {
    await _repo.hapusDzikir(baris.id).timeout(_batas);
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final DateTime hariIni = IbadahLanjutanRepository.hari(waktuSekarang());
    final Map<DateTime, int> totalHarian = totalDzikirHarian(_rentang);

    return Scaffold(
      appBar: AppBar(title: const Text('Dzikir')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: <Widget>[
          KartuBagian(
            judul: 'Sesi dzikir',
            isi: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    for (final JenisDzikir j in JenisDzikir.values)
                      ChoiceChip(
                        key: Key('sesi_${j.nilaiDb}'),
                        label: Text(j.label),
                        selected: _jenis == j,
                        onSelected: (_) => _gantiJenis(j),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('nama_dzikir'),
                  controller: _nama,
                  decoration: const InputDecoration(
                    labelText: 'Nama dzikir',
                    hintText: 'Misalnya Subhanallah',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: <Widget>[
                    for (final String nama in contohNamaDzikir)
                      ActionChip(
                        key: Key('contoh_$nama'),
                        label: Text(nama),
                        onPressed: () => _pakaiNama(nama),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    OutlinedButton(
                      key: const Key('simpan_nama_dzikir'),
                      onPressed: _simpanNama,
                      child: const Text('Pakai nama ini'),
                    ),
                  ],
                ),
                const CatatanJujur(
                    teks: 'Lafaz di atas hanya contoh yang lazim; silakan '
                        'ganti dengan lafaz Anda sendiri.'),
              ],
            ),
          ),
          KartuBagian(
            judul: 'Penghitung',
            isi: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  '$_tercatat',
                  key: const Key('angka_dzikir'),
                  style: tema.textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text('dari target $_target · sesi ${_jenis.label}',
                    style: tema.textTheme.bodyMedium),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    FilledButton.icon(
                      key: const Key('hitung_dzikir'),
                      onPressed: _hitung,
                      icon: const Icon(Icons.add),
                      label: const Text('Hitung'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      key: const Key('ulang_dzikir'),
                      onPressed: _ulang,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Ulang'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    const Expanded(child: Text('Target sesi ini')),
                    IconButton(
                      key: const Key('target_kurang'),
                      onPressed: () => _simpanTarget(_target - 1),
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$_target'),
                    IconButton(
                      key: const Key('target_tambah'),
                      onPressed: () => _simpanTarget(_target + 1),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const CatatanJujur(
                    teks: 'Tombol Ulang mengembalikan hitungan sesi ini ke 0. '
                        'Riwayat hari-hari sebelumnya tidak dihapus.'),
              ],
            ),
          ),
          KartuBagian(
            judul: 'Riwayat hari ini',
            isi: _memuat
                ? const Text('Membaca catatan...')
                : _galat
                    ? const Text('Catatan belum bisa dibaca saat ini')
                    : _hariIni.isEmpty
                        ? const BarisKosong(
                            keterangan:
                                'Tekan tombol Hitung untuk mencatat sesi Anda.')
                        : Column(
                            children: <Widget>[
                              for (final LogDzikirData b in _hariIni)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  leading: const Icon(Icons.radio_button_checked),
                                  title: Text(
                                      '${JenisDzikir.dariDb(b.jenis).label} · ${b.nama}'),
                                  subtitle: Text('Tercatat ${b.tercatat} dari '
                                      'target ${b.target}'),
                                  trailing: IconButton(
                                    key: Key('hapus_dzikir_${b.id}'),
                                    onPressed: () => _hapus(b),
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Hapus catatan',
                                  ),
                                ),
                            ],
                          ),
          ),
          KartuBagian(
            judul: '7 hari terakhir',
            isi: _rentang.isEmpty
                ? const BarisKosong()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      GrafikBatang(
                        nilai: <DateTime, double>{
                          for (int i = 6; i >= 0; i--)
                            hariIni.subtract(Duration(days: i)):
                                (totalHarian[hariIni.subtract(Duration(days: i))] ?? 0)
                                    .toDouble(),
                        },
                        satuanTeks: 'hitungan',
                      ),
                      const SizedBox(height: 8),
                      for (final LogDzikirData b in _rentang)
                        BarisRingkasan(
                          label:
                              '${teksTanggal(b.tanggal)} · ${b.nama} (${JenisDzikir.dariDb(b.jenis).label})',
                          nilai: '${b.tercatat}',
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
