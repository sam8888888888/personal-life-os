/// Layar Perawatan berkala (FR-83 — Life Maintenance Engine).
///
/// Menampilkan dua bagian:
///  1. **Jatuh tempo dalam 30 hari** — hanya muncul bila ada perawatan aktif
///     yang jadwalnya tersisa paling banyak 30 hari (termasuk hari ini);
///  2. seluruh daftar perawatan, urut jadwal terdekat.
///
/// Tiap baris punya tombol "Sudah dilakukan hari ini" yang memanggil
/// `PerawatanRepository.tandaiDilakukan` — satu-satunya aksi di layar ini.
/// Penjadwalan notifikasi tidak diurus dari sini: modul perawatan hanya
/// menyimpan jadwal, pengingat dijadwalkan oleh `lib/core/notifikasi/**`.
///
/// Gaya & nada mengikuti PRD III-11: layar menjelaskan jadwal, bukan menilai
/// pengguna. Kalimat seperti "jadwal ini sudah lewat" dipakai apa adanya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/repository/perawatan_repository.dart';

/// Repositori perawatan untuk layar ini.
///
/// Dibuat lokal (bukan di `lib/core/providers/app_providers.dart`) supaya
/// berkas bersama itu tidak perlu disentuh dari modul ini.
final repoPerawatanProvider = Provider<PerawatanRepository>(
    (ref) => PerawatanRepository(ref.watch(databaseProvider)));

/// Nama kategori yang dikenali skema `perawatan.kategori`.
const Map<String, String> labelKategoriPerawatan = <String, String>{
  'kendaraan': 'Kendaraan',
  'rumah': 'Rumah',
  'dokumen': 'Dokumen',
  'keluarga': 'Keluarga',
  'perangkat': 'Perangkat',
  'lain': 'Lainnya',
};

/// Kalimat status jadwal — menjelaskan, tanpa menegur.
String kalimatJadwalPerawatan(PerawatanData p, DateTime sekarang) {
  final sisa = PerawatanRepository.sisaHari(p, sekarang);
  if (sisa < 0) return 'Jadwal ini sudah lewat ${-sisa} hari';
  if (sisa == 0) return 'Jadwalnya hari ini';
  return 'Dalam $sisa hari lagi';
}

class PerawatanScreen extends ConsumerStatefulWidget {
  const PerawatanScreen({super.key});

  @override
  ConsumerState<PerawatanScreen> createState() => _PerawatanScreenState();
}

class _PerawatanScreenState extends ConsumerState<PerawatanScreen> {
  List<PerawatanData>? _semua;
  List<PerawatanData> _sorotan = const <PerawatanData>[];
  bool _memuat = true;
  bool _adaMasalah = false;

  DateTime get _sekarang => waktuSekarang();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  /// Baca ulang seluruh data perawatan dari penyimpanan.
  Future<void> _muat() async {
    final repo = ref.read(repoPerawatanProvider);
    try {
      final semua =
          await repo.ambilSemua().timeout(const Duration(seconds: 5));
      final sorotan = await repo
          .sorotanJatuhTempo(sekarang: _sekarang)
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _semua = semua;
        _sorotan = sorotan;
        _memuat = false;
        _adaMasalah = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _adaMasalah = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perawatan berkala')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tombol_perawatan_baru'),
        onPressed: _dialogPerawatanBaru,
        icon: const Icon(Icons.add),
        label: const Text('Perawatan'),
      ),
      body: _isi(),
    );
  }

  Widget _isi() {
    if (_semua == null) {
      if (_memuat) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Data perawatan belum bisa dibaca saat ini.',
              textAlign: TextAlign.center),
        ),
      );
    }
    final semua = _semua!;
    if (semua.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Text('Belum ada data', textAlign: TextAlign.center),
          ),
        ],
      );
    }

    // Baris jatuh tempo dipisah ke bagiannya sendiri supaya tidak tampil dua
    // kali di halaman yang sama.
    final idSorotan = <int>{for (final p in _sorotan) p.id};
    final sisanya =
        semua.where((p) => !idSorotan.contains(p.id)).toList(growable: false);
    final tema = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_adaMasalah)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Daftar ini mungkin belum yang terbaru.'),
            ),
          if (_sorotan.isNotEmpty) ...[
            Text('Jatuh tempo dalam 30 hari',
                style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._sorotan.map(_kartuBaris),
            const Divider(height: 24),
          ],
          if (sisanya.isNotEmpty)
            Text('Semua perawatan', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...sisanya.map(_kartuBaris),
        ],
      ),
    );
  }

  Widget _kartuBaris(PerawatanData p) {
    final tema = Theme.of(context);
    final kategori = labelKategoriPerawatan[p.kategori] ?? p.kategori;
    return Card(
      key: Key('baris_perawatan_${p.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: Text(p.nama, style: tema.textTheme.titleMedium)),
                Text(kategori, style: tema.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 4),
            Text('Setiap ${p.intervalHari} hari'),
            Text('Berikutnya: ${fmtTanggalId(p.berikutnya)}'),
            Text(kalimatJadwalPerawatan(p, _sekarang),
                style: tema.textTheme.bodySmall),
            if (!p.aktif)
              Text('Tidak diingatkan (nonaktif)',
                  style: tema.textTheme.bodySmall),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('sudah_dilakukan_${p.id}'),
                onPressed: () => _tandaiDilakukan(p),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Sudah dilakukan hari ini'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Aksi
  // ------------------------------------------------------------------

  Future<void> _tandaiDilakukan(PerawatanData p) async {
    final repo = ref.read(repoPerawatanProvider);
    PerawatanData? terbaru;
    try {
      terbaru = await repo
          .tandaiDilakukan(p.id)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      if (!mounted) return;
      _pesan('Jadwal "${p.nama}" belum bisa diperbarui saat ini.');
      return;
    }
    if (!mounted) return;
    // Muat ulang supaya bagian jatuh tempo ikut menyesuaikan.
    await _muat();
    if (!mounted) return;
    _pesan('Jadwal "${p.nama}" diperbarui. Berikutnya: '
        '${fmtTanggalId(terbaru.berikutnya)}');
  }

  /// Dialog sederhana: nama, kategori, dan interval hari.
  Future<void> _dialogPerawatanBaru() async {
    final hasil = await showDialog<_HasilPerawatanBaru>(
      context: context,
      builder: (_) => const _DialogPerawatanBaru(),
    );
    if (hasil == null) return;

    final repo = ref.read(repoPerawatanProvider);
    try {
      await repo
          .simpan(
            nama: hasil.nama,
            kategori: hasil.kategori,
            intervalHari: hasil.intervalHari,
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      if (!mounted) return;
      _pesan('Perawatan "${hasil.nama}" belum bisa disimpan saat ini.');
      return;
    }
    if (!mounted) return;
    await _muat();
    if (!mounted) return;
    _pesan('Perawatan "${hasil.nama}" tersimpan. Jadwalnya mulai dari hari ini.');
  }

  void _pesan(String teks) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(teks)));
}

/// Isi yang dikembalikan dialog perawatan baru.
class _HasilPerawatanBaru {
  const _HasilPerawatanBaru({
    required this.nama,
    required this.kategori,
    required this.intervalHari,
  });

  final String nama;
  final String kategori;
  final int intervalHari;
}

/// Dialog tambah perawatan: nama, kategori, dan interval hari.
///
/// Dibuat sebagai StatefulWidget supaya `TextEditingController` dimiliki dan
/// dibuang oleh widget ini sendiri. Bila controller dibuang oleh pemanggil
/// tepat setelah `showDialog` selesai, animasi penutup dialog masih memakai
/// controller itu dan Flutter melaporkan "used after being disposed".
class _DialogPerawatanBaru extends StatefulWidget {
  const _DialogPerawatanBaru();

  @override
  State<_DialogPerawatanBaru> createState() => _StateDialogPerawatanBaru();
}

class _StateDialogPerawatanBaru extends State<_DialogPerawatanBaru> {
  final _kendaliNama = TextEditingController();
  final _kendaliInterval = TextEditingController(text: '30');
  String _kategori = 'lain';
  String _pesanGalat = '';

  @override
  void dispose() {
    _kendaliNama.dispose();
    _kendaliInterval.dispose();
    super.dispose();
  }

  void _simpan() {
    final nama = _kendaliNama.text.trim();
    final interval = int.tryParse(_kendaliInterval.text.trim());
    if (nama.isEmpty || interval == null || interval < 1) {
      setState(
          () => _pesanGalat = 'Isi nama perawatan dan interval minimal 1 hari.');
      return;
    }
    Navigator.of(context).pop(_HasilPerawatanBaru(
      nama: nama,
      kategori: _kategori,
      intervalHari: interval,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Perawatan baru'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('perawatan_nama'),
              controller: _kendaliNama,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nama perawatan',
                hintText: 'Contoh: Servis AC',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('perawatan_kategori'),
              initialValue: _kategori,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                for (final e in labelKategoriPerawatan.entries)
                  DropdownMenuItem<String>(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _kategori = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('perawatan_interval'),
              controller: _kendaliInterval,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Interval (hari)',
                hintText: 'Contoh: 180',
              ),
            ),
            if (_pesanGalat.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _pesanGalat,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('batal_perawatan'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('simpan_perawatan'),
          onPressed: _simpan,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
