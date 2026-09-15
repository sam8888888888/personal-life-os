/// Layar Kebiasaan (FR-80) — daftar kebiasaan, promosi ke Hari Ini, dan
/// catatan harian.
///
/// Kriteria terima PRD: "daftar kebiasaan bisa dipromosikan ke Hari Ini
/// (maksimal 5) dan capaian hariannya dicatat". Batas 5 dijaga di
/// `KebiasaanRepository.setDipromosikan`; layar hanya menampilkan pesan
/// `KebiasaanRepository.pesanPenuh` saat kuota sudah penuh, dan saklar
/// dikembalikan ke posisi mati tanpa mengubah data.
///
/// Setiap pembacaan penyimpanan dibungkus batas waktu 5 detik supaya layar
/// tidak menunggu tanpa ujung. Nada bahasa mengikuti PRD III-11: yang
/// dilaporkan hanya "tercatat" atau "belum tercatat", tanpa penilaian.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/waktu.dart';
import '../../../data/database/database.dart';
import '../../../data/repository/kebiasaan_repository.dart';

/// Repositori kebiasaan untuk layar ini.
///
/// Dibuat lokal (bukan di `lib/core/providers/app_providers.dart`) supaya
/// berkas bersama itu tidak perlu disentuh dari modul ini.
final repoKebiasaanProvider = Provider<KebiasaanRepository>(
    (ref) => KebiasaanRepository(ref.watch(databaseProvider)));

/// Batas waktu setiap pembacaan/penulisan penyimpanan.
const Duration batasPenyimpananKebiasaan = Duration(seconds: 5);

/// Teks ringkasan 7 hari (dipakai layar; bentuknya harus tetap sama).
String teksRingkasan7Hari(RingkasanKebiasaan r) =>
    '7 hari terakhir: ${r.hariTercatat} dari 7 hari tercatat';

/// Teks ringkasan 30 hari.
String teksRingkasan30Hari(RingkasanKebiasaan r) =>
    '30 hari terakhir: ${r.hariTercatat} dari 30 hari tercatat';

/// Teks target per minggu untuk satu kebiasaan.
String teksTargetMingguan(KebiasaanData k) =>
    'Target ${k.targetPerMinggu} kali per minggu';

/// Keterangan singkat capaian hari ini, tanpa penilaian.
String teksHariIni(double nilai) {
  if (nilai >= 1) return 'Hari ini tercatat penuh.';
  if (nilai > 0) return 'Hari ini tercatat setengah jalan.';
  return 'Hari ini belum tercatat.';
}

/// Isi layar sekali muat: daftar, ringkasan 7 & 30 hari, dan nilai hari ini.
class _DataLayar {
  const _DataLayar({
    required this.daftar,
    required this.ringkas7,
    required this.ringkas30,
    required this.hariIni,
  });

  final List<KebiasaanData> daftar;
  final Map<int, RingkasanKebiasaan> ringkas7;
  final Map<int, RingkasanKebiasaan> ringkas30;
  final Map<int, double> hariIni;
}

class KebiasaanScreen extends ConsumerStatefulWidget {
  const KebiasaanScreen({super.key});

  @override
  ConsumerState<KebiasaanScreen> createState() => _KebiasaanScreenState();
}

class _KebiasaanScreenState extends ConsumerState<KebiasaanScreen> {
  _DataLayar? _data;
  bool _memuat = true;
  String? _pesanMuat;

  final _ctrlNama = TextEditingController();
  final _ctrlTarget = TextEditingController(text: '7');

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _ctrlNama.dispose();
    _ctrlTarget.dispose();
    super.dispose();
  }

  /// Baca ulang seluruh bahan layar dari penyimpanan (dengan batas waktu).
  Future<void> _muat() async {
    final repo = ref.read(repoKebiasaanProvider);
    if (_data != null) {
      setState(() => _memuat = true);
    }
    try {
      final daftar = await repo.ambilSemua().timeout(batasPenyimpananKebiasaan);
      final ringkas7 =
          await repo.ringkasanSemua(hari: 7).timeout(batasPenyimpananKebiasaan);
      final ringkas30 = await repo
          .ringkasanSemua(hari: 30)
          .timeout(batasPenyimpananKebiasaan);
      final hariIni = await repo
          .nilaiHari(waktuSekarang())
          .timeout(batasPenyimpananKebiasaan);
      if (!mounted) return;
      setState(() {
        _data = _DataLayar(
          daftar: daftar,
          ringkas7: ringkas7,
          ringkas30: ringkas30,
          hariIni: hariIni,
        );
        _memuat = false;
        _pesanMuat = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _pesanMuat = 'Data kebiasaan belum bisa dimuat. Tekan "Muat ulang".';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kebiasaan')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tombol_kebiasaan_baru'),
        onPressed: _bukaDialogBaru,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: _isiLayar(),
    );
  }

  Widget _isiLayar() {
    final data = _data;
    if (data == null) {
      if (_memuat) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _pesanMuat ?? 'Data kebiasaan belum bisa dimuat.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('muat_ulang_kebiasaan'),
                onPressed: _muat,
                child: const Text('Muat ulang'),
              ),
            ],
          ),
        ),
      );
    }

    if (data.daftar.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Belum ada data', textAlign: TextAlign.center),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        if (_memuat) const LinearProgressIndicator(),
        if (_pesanMuat != null) ...[
          Text(
            _pesanMuat!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          '${data.daftar.length} kebiasaan tersimpan',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        ...data.daftar.map(_kartuKebiasaan),
      ],
    );
  }

  Widget _kartuKebiasaan(KebiasaanData k) {
    final data = _data!;
    final nilaiHariIni = data.hariIni[k.id] ?? 0.0;
    final ringkas7 =
        data.ringkas7[k.id] ?? RingkasanKebiasaan.kosong(7);
    final ringkas30 =
        data.ringkas30[k.id] ?? RingkasanKebiasaan.kosong(30);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            key: Key('baris_kebiasaan_${k.id}'),
            leading: CircleAvatar(
              backgroundColor: _warnaDari(k.warna),
              child: Icon(_ikonDari(k.ikon), color: Colors.white, size: 20),
            ),
            title: Text(
              k.nama,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(teksTargetMingguan(k)),
            trailing: Switch(
              key: Key('saklar_promosi_${k.id}'),
              value: k.dipromosikan,
              onChanged: (nilai) => _ubahPromosi(k, nilai),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(teksHariIni(nilaiHariIni)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: Key('catat_penuh_${k.id}'),
                  onPressed: () => _catat(k, 1.0),
                  child: const Text('Penuh'),
                ),
                OutlinedButton(
                  key: Key('catat_setengah_${k.id}'),
                  onPressed: () => _catat(k, 0.5),
                  child: const Text('Setengah'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teksRingkasan7Hari(ringkas7)),
                const SizedBox(height: 2),
                Text(teksRingkasan30Hari(ringkas30)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Nyalakan/matikan promosi. Bila kuota penuh, saklar kembali mati dan
  /// pengguna menerima pesan penjelas.
  Future<void> _ubahPromosi(KebiasaanData k, bool nilai) async {
    final repo = ref.read(repoKebiasaanProvider);
    bool berhasil;
    try {
      berhasil = await repo
          .setDipromosikan(k.id, nilai)
          .timeout(batasPenyimpananKebiasaan);
    } catch (_) {
      if (!mounted) return;
      _pesan('Promosi belum bisa diubah saat ini.');
      await _muat();
      return;
    }
    if (!mounted) return;
    if (!berhasil) {
      _pesan(KebiasaanRepository.pesanPenuh);
      await _muat();
      return;
    }
    await _muat();
  }

  /// Catat capaian harian untuk tanggal hari ini.
  Future<void> _catat(KebiasaanData k, double nilai) async {
    final repo = ref.read(repoKebiasaanProvider);
    try {
      await repo
          .catat(k.id, waktuSekarang(), nilai)
          .timeout(batasPenyimpananKebiasaan);
    } catch (_) {
      if (!mounted) return;
      _pesan('Catatan belum bisa disimpan saat ini.');
      return;
    }
    await _muat();
  }

  /// Dialog sederhana: nama + target per minggu.
  Future<void> _bukaDialogBaru() async {
    _ctrlNama.clear();
    _ctrlTarget.text = '7';
    final hasil = await showDialog<({String nama, int target})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kebiasaan baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('input_nama_kebiasaan'),
              controller: _ctrlNama,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nama kebiasaan',
                hintText: 'Contoh: Minum air 8 gelas',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('input_target_kebiasaan'),
              controller: _ctrlTarget,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target per minggu (1-7)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('batal_kebiasaan'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('simpan_kebiasaan'),
            onPressed: () {
              final nama = _ctrlNama.text.trim();
              if (nama.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Nama kebiasaan belum diisi.')),
                );
                return;
              }
              final angka = int.tryParse(_ctrlTarget.text.trim()) ?? 7;
              Navigator.of(ctx).pop(
                (nama: nama, target: angka.clamp(1, 7)),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (hasil == null) return;
    await _simpanBaru(hasil.nama, hasil.target);
  }

  Future<void> _simpanBaru(String nama, int target) async {
    final repo = ref.read(repoKebiasaanProvider);
    try {
      await repo
          .simpan(nama: nama, targetPerMinggu: target)
          .timeout(batasPenyimpananKebiasaan);
    } catch (_) {
      if (!mounted) return;
      _pesan('Kebiasaan baru belum bisa disimpan saat ini.');
      return;
    }
    await _muat();
  }

  void _pesan(String teks) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(teks)));
  }

  /// Ikon bawaan Material yang dikenali; nama lain memakai ikon `repeat`.
  static IconData _ikonDari(String nama) => switch (nama) {
        'repeat' => Icons.repeat,
        'water_drop' => Icons.water_drop,
        'directions_run' => Icons.directions_run,
        'menu_book' => Icons.menu_book,
        'self_improvement' => Icons.self_improvement,
        'bedtime' => Icons.bedtime,
        'fitness_center' => Icons.fitness_center,
        'savings' => Icons.savings,
        'edit_note' => Icons.edit_note,
        _ => Icons.repeat,
      };

  /// Warna hex "#RRGGBB" dari basis data; bila bentuknya tidak dikenal,
  /// dipakai warna bawaan tema.
  static Color _warnaDari(String hex) {
    final teks = hex.replaceFirst('#', '').trim();
    if (teks.length != 6) return const Color(0xFF4A90D9);
    final angka = int.tryParse(teks, radix: 16);
    if (angka == null) return const Color(0xFF4A90D9);
    return Color(0xFF000000 | angka);
  }
}
