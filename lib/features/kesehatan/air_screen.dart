/// FR-111 — Pencatat air.
///
/// Isi: tombol tambah per gelas/botol (ukuran gelas bisa diatur, bawaan
/// 250 ml), jumlah ml bebas, total hari ini + target harian yang bisa diatur,
/// dan riwayat 7 hari.
///
/// Halaman hanya melaporkan angka catatan pengguna — tidak menilai "cukup"
/// atau "kurang", dan tidak memaksa jumlah tertentu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/repository/kesehatan_repository.dart';
import 'grafik_batang_harian.dart';
import 'kartu_bagian.dart';
import 'label_hari.dart';
import 'provider_kesehatan.dart';

class AirScreen extends ConsumerStatefulWidget {
  const AirScreen({super.key, this.jamSekarang});

  /// Sumber waktu (dipakai uji supaya tanggal tidak bergeser).
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<AirScreen> createState() => _AirScreenState();
}

class _AirScreenState extends ConsumerState<AirScreen> {
  final _jumlah = TextEditingController();
  final _target = TextEditingController();
  final _ukuranGelas = TextEditingController();

  bool _memuat = true;
  RingkasanAir? _ringkasan;
  List<CatatanAirData> _hariIni = const [];
  List<BatangAirHarian> _riwayat = const [];
  int _ukuranGelasMl = KesehatanRepository.ukuranGelasBawaanMl;

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _jumlah.dispose();
    _target.dispose();
    _ukuranGelas.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    final repo = ref.read(kesehatanRepoProvider);
    final kini = _sekarang;
    final ringkasan = await repo.ringkasanAir(acuan: kini);
    final hariIni = await repo.catatanAirRentang(
      dari: awalHari(kini),
      sampai: akhirHari(kini),
    );
    final riwayat = await repo.riwayatAirHarian(hari: 7, sampai: kini);
    final gelas = await repo.ukuranGelasMl();
    if (!mounted) return;
    setState(() {
      _ringkasan = ringkasan;
      _hariIni = hariIni;
      _riwayat = riwayat;
      _ukuranGelasMl = gelas;
      _target.text =
          _target.text.trim().isEmpty ? '${ringkasan.targetMl}' : _target.text;
      _ukuranGelas.text = _ukuranGelas.text.trim().isEmpty
          ? '$gelas'
          : _ukuranGelas.text;
      _memuat = false;
    });
  }

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  Future<void> _tambah(int ml) async {
    try {
      await ref.read(kesehatanRepoProvider).catatAir(jumlahMl: ml);
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.kesehatan,
        aksi: AksiAudit.buat,
        entitas: 'air',
        ringkas: 'Air ${formatMl(ml)} dicatat.',
      );
    } on ArgumentError catch (e) {
      _pesan('Catatan belum bisa disimpan: ${e.message}');
      return;
    }
    await _muat();
    _pesan('${formatMl(ml)} tercatat.');
  }

  Future<void> _tambahDariIsian() async {
    final ml = int.tryParse(_jumlah.text.trim());
    if (ml == null) {
      _pesan('Jumlah air diisi angka ml, contoh 200.');
      return;
    }
    await _tambah(ml);
    _jumlah.clear();
  }

  Future<void> _batalkanTerakhir() async {
    final terakhir = await ref.read(kesehatanRepoProvider).catatanAirRentang(
          dari: awalHari(_sekarang),
          sampai: akhirHari(_sekarang),
        );
    if (terakhir.isEmpty) {
      _pesan('Belum ada catatan air hari ini.');
      return;
    }
    await ref.read(kesehatanRepoProvider).hapusAir(terakhir.first.id);
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.kesehatan,
      aksi: AksiAudit.hapus,
      entitas: 'air',
      entitasId: '${terakhir.first.id}',
      ringkas: 'Catatan air terakhir dibatalkan.',
    );
    await _muat();
    _pesan('Catatan terakhir dibatalkan.');
  }

  Future<void> _simpanPengaturan() async {
    final target = int.tryParse(_target.text.trim());
    final gelas = int.tryParse(_ukuranGelas.text.trim());
    if (target == null || gelas == null) {
      _pesan('Target dan ukuran gelas diisi angka ml.');
      return;
    }
    try {
      await ref.read(kesehatanRepoProvider).simpanTargetAirMl(target);
      await ref.read(kesehatanRepoProvider).simpanUkuranGelasMl(gelas);
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.kesehatan,
        aksi: AksiAudit.ubah,
        entitas: 'air_pengaturan',
        ringkas: 'Target air $target ml & ukuran gelas $gelas ml diperbarui.',
      );
    } on ArgumentError catch (e) {
      _pesan('Pengaturan belum bisa disimpan: ${e.message}');
      return;
    }
    await _muat();
    _pesan('Pengaturan air tersimpan.');
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ringkasan = _ringkasan;
    final botolMl = _ukuranGelasMl * 2;

    return Scaffold(
      appBar: AppBar(title: const Text('Air')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                KartuBagian(
                  judul: 'Hari ini',
                  ikon: Icons.water_drop_outlined,
                  anak: [
                    if (ringkasan == null || !ringkasan.adaCatatan)
                      const TeksBelumAdaData()
                    else ...[
                      Text(
                        formatMl(ringkasan.totalMl),
                        key: const Key('total_air_hari_ini'),
                        style: tema.textTheme.headlineSmall,
                      ),
                      Text(
                        'Target harian: ${formatMl(ringkasan.targetMl)}',
                        key: const Key('target_air'),
                      ),
                      Text(
                        ringkasan.sisaMl == 0
                            ? 'Catatan hari ini sudah mencapai atau melewati '
                                'target.'
                            : 'Sisa menuju target: ${formatMl(ringkasan.sisaMl)}',
                        key: const Key('sisa_air'),
                        style: tema.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${ringkasan.jumlahCatatan} catatan hari ini.',
                        key: const Key('jumlah_catatan_air'),
                        style: tema.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          key: const Key('tambah_gelas'),
                          onPressed: () => _tambah(_ukuranGelasMl),
                          icon: const Icon(Icons.local_drink_outlined),
                          label: Text('Tambah gelas ($_ukuranGelasMl ml)'),
                        ),
                        OutlinedButton.icon(
                          key: const Key('tambah_botol'),
                          onPressed: () => _tambah(botolMl),
                          icon: const Icon(Icons.water_drop_outlined),
                          label: Text('Tambah botol ($botolMl ml)'),
                        ),
                        OutlinedButton(
                          key: const Key('batalkan_air_terakhir'),
                          onPressed: _batalkanTerakhir,
                          child: const Text('Batalkan catatan terakhir'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('input_jumlah_air'),
                            controller: _jumlah,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Jumlah lain (ml)',
                              hintText: 'Contoh: 200',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          key: const Key('tambah_air_khusus'),
                          onPressed: _tambahDariIsian,
                          child: const Text('Tambah'),
                        ),
                      ],
                    ),
                  ],
                ),
                KartuBagian(
                  judul: 'Pengaturan air',
                  ikon: Icons.tune_outlined,
                  anak: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('input_ukuran_gelas'),
                            controller: _ukuranGelas,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Ukuran gelas (ml)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: const Key('input_target_air'),
                            controller: _target,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Target harian (ml)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const Key('simpan_pengaturan_air'),
                      onPressed: _simpanPengaturan,
                      child: const Text('Simpan pengaturan'),
                    ),
                  ],
                ),
                KartuBagian(
                  judul: 'Riwayat 7 hari',
                  ikon: Icons.history_outlined,
                  anak: [
                    if (_hariIni.isEmpty &&
                        _riwayat.every((b) => b.totalMl == 0))
                      const TeksBelumAdaData()
                    else ...[
                      GrafikBatangHarian(
                        key: const Key('grafik_air_7_hari'),
                        batang: [
                          for (final b in _riwayat)
                            BatangHarian(tanggal: b.tanggal, nilai: b.totalMl),
                        ],
                        satuan: 'ml',
                      ),
                      const SizedBox(height: 8),
                      for (final b in _riwayat.reversed)
                        Text(
                          '${labelTanggalSedang(b.tanggal)}: '
                          '${b.totalMl == 0 ? 'Belum ada data' : formatMl(b.totalMl)}',
                          key: Key(
                            'air_harian_${b.tanggal.year}-'
                            '${b.tanggal.month.toString().padLeft(2, '0')}-'
                            '${b.tanggal.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                    ],
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Angka ini hanya catatan Anda sendiri. Target bisa Anda ubah '
                    'kapan saja.',
                    style: tema.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
    );
  }
}
