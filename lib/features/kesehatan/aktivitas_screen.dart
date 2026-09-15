/// FR-102 — Pencatat aktivitas.
///
/// Isi: form catat (jenis, durasi menit, jarak km opsional, intensitas,
/// tanggal, catatan), ringkasan total menit 7 hari & 30 hari, grafik batang
/// 7 hari, dan riwayat terbaru.
///
/// Tidak ada penilaian "olahraga Anda kurang" dan tidak ada target otomatis;
/// halaman hanya melaporkan angka catatan pengguna.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/repository/kesehatan_repository.dart';
import 'grafik_batang_harian.dart';
import 'kartu_bagian.dart';
import 'label_hari.dart';
import 'provider_kesehatan.dart';

/// Pilihan jenis aktivitas yang sering dipakai (boleh ditulis sendiri).
const List<String> jenisAktivitasUmum = [
  'Jalan',
  'Lari',
  'Sepeda',
  'Renang',
  'Gym',
  'Peregangan',
  'Olahraga',
  'Aktivitas rumah',
];

class AktivitasScreen extends ConsumerStatefulWidget {
  const AktivitasScreen({super.key, this.jamSekarang});

  /// Sumber waktu (dipakai uji supaya tanggal tidak bergeser).
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<AktivitasScreen> createState() => _AktivitasScreenState();
}

class _AktivitasScreenState extends ConsumerState<AktivitasScreen> {
  final _jenis = TextEditingController();
  final _durasi = TextEditingController();
  final _jarak = TextEditingController();
  final _catatan = TextEditingController();

  IntensitasAktivitas _intensitas = IntensitasAktivitas.sedang;
  late DateTime _tanggal;

  bool _memuat = true;
  List<Aktivita> _daftar = const [];
  RingkasanAktivitas? _ringkasan;
  List<BatangHarian> _batang = const [];

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _tanggal = awalHari(_sekarang);
    _muat();
  }

  @override
  void dispose() {
    _jenis.dispose();
    _durasi.dispose();
    _jarak.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    final repo = ref.read(kesehatanRepoProvider);
    final kini = _sekarang;
    final daftar = await repo.daftarAktivitas(hari: 7, sampai: kini);
    final ringkasan = await repo.ringkasanAktivitas(acuan: kini);
    final batang = await repo.batangAktivitas(hari: 7, sampai: kini);
    if (!mounted) return;
    setState(() {
      _daftar = daftar;
      _ringkasan = ringkasan;
      _batang = batang;
      _memuat = false;
    });
  }

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  Future<void> _simpan() async {
    final jenis = _jenis.text.trim();
    if (jenis.isEmpty) {
      _pesan('Isi jenis aktivitas lebih dulu.');
      return;
    }
    final durasi = int.tryParse(_durasi.text.trim());
    if (durasi == null) {
      _pesan('Durasi diisi angka menit, contoh 30.');
      return;
    }
    final teksJarak = _jarak.text.trim().replaceAll(',', '.');
    double? jarak;
    if (teksJarak.isNotEmpty) {
      jarak = double.tryParse(teksJarak);
      if (jarak == null) {
        _pesan('Jarak diisi angka km, contoh 5 atau 5,5. Boleh dikosongkan.');
        return;
      }
    }
    try {
      await ref.read(kesehatanRepoProvider).catatAktivitas(
            jenis: jenis,
            durasiMenit: durasi,
            jarakKm: jarak,
            intensitas: _intensitas,
            tanggal: _tanggal,
            catatan: _catatan.text,
          );
    } on ArgumentError catch (e) {
      _pesan('Catatan belum bisa disimpan: ${e.message}');
      return;
    }
    _durasi.clear();
    _jarak.clear();
    _catatan.clear();
    await _muat();
    _pesan('Catatan aktivitas tersimpan.');
  }

  Future<void> _hapus(Aktivita a) async {
    await ref.read(kesehatanRepoProvider).hapusAktivitas(a.id);
    await _muat();
    _pesan('Catatan dihapus.');
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ringkasan = _ringkasan;

    return Scaffold(
      appBar: AppBar(title: const Text('Aktivitas')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                KartuBagian(
                  judul: 'Catat aktivitas',
                  ikon: Icons.add_task_outlined,
                  anak: [
                    TextField(
                      key: const Key('input_jenis_aktivitas'),
                      controller: _jenis,
                      decoration: const InputDecoration(
                        labelText: 'Jenis aktivitas',
                        hintText: 'Contoh: jalan',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final j in jenisAktivitasUmum)
                          PilihanCepat(
                            kunci: Key('pilih_jenis_${j.toLowerCase()}'),
                            label: j,
                            terpilih: _jenis.text.trim().toLowerCase() ==
                                j.toLowerCase(),
                            onPilih: () => setState(() => _jenis.text = j),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('input_durasi_menit'),
                      controller: _durasi,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Durasi (menit)',
                        hintText: 'Contoh: 30',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('input_jarak_km'),
                      controller: _jarak,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Jarak (km, boleh kosong)',
                        hintText: 'Contoh: 5,2',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Intensitas', style: tema.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final i in IntensitasAktivitas.values)
                          PilihanCepat(
                            kunci: Key('pilih_intensitas_${i.nilaiDb}'),
                            label: i.label,
                            terpilih: _intensitas == i,
                            onPilih: () => setState(() => _intensitas = i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tanggal: ${labelTanggalSedang(_tanggal)}',
                            key: const Key('label_tanggal_aktivitas'),
                          ),
                        ),
                        TextButton(
                          key: const Key('pilih_tanggal_aktivitas'),
                          onPressed: () async {
                            final pilih = await showDatePicker(
                              context: context,
                              initialDate: _tanggal,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (pilih != null) {
                              setState(() => _tanggal = awalHari(pilih));
                            }
                          },
                          child: const Text('Pilih tanggal'),
                        ),
                      ],
                    ),
                    TextField(
                      key: const Key('input_catatan_aktivitas'),
                      controller: _catatan,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (boleh kosong)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const Key('simpan_aktivitas'),
                      onPressed: _simpan,
                      child: const Text('Simpan catatan'),
                    ),
                  ],
                ),
                KartuBagian(
                  judul: 'Total menit',
                  ikon: Icons.timeline_outlined,
                  anak: [
                    if (ringkasan == null || !ringkasan.adaCatatan)
                      const TeksBelumAdaData()
                    else ...[
                      Text(
                        '7 hari terakhir: ${ringkasan.menit7Hari} menit',
                        key: const Key('total_menit_7_hari'),
                      ),
                      Text(
                        '30 hari terakhir: ${ringkasan.menit30Hari} menit',
                        key: const Key('total_menit_30_hari'),
                      ),
                      Text(
                        'Hari ini: ${ringkasan.menitHariIni} menit',
                        key: const Key('total_menit_hari_ini'),
                      ),
                      const SizedBox(height: 12),
                      GrafikBatangHarian(
                        key: const Key('grafik_aktivitas'),
                        batang: _batang,
                        satuan: 'menit',
                      ),
                    ],
                  ],
                ),
                KartuBagian(
                  judul: 'Riwayat 7 hari',
                  ikon: Icons.history_outlined,
                  anak: [
                    if (_daftar.isEmpty)
                      const TeksBelumAdaData()
                    else
                      ..._daftar.map(
                        (a) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            a.jenis,
                            key: Key('jenis_aktivitas_${a.id}'),
                          ),
                          subtitle: Text(
                            '${a.durasiMenit} menit'
                            '${a.jarakKm == null ? '' : ' · ${formatAngkaDesimal(a.jarakKm!)} km'}'
                            ' · ${IntensitasAktivitas.dariDb(a.intensitas).label}'
                            ' · ${labelTanggalSedang(a.tanggal)}',
                          ),
                          trailing: IconButton(
                            key: Key('hapus_aktivitas_${a.id}'),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Hapus catatan',
                            onPressed: () => _hapus(a),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
