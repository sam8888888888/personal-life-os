/// FR-122 — Pelacakan buku & bacaan.
///
/// Isi: daftar bacaan (buku/artikel/jurnal), halaman yang sudah dibaca, status,
/// penilaian pengguna sendiri, dan jumlah halaman yang tercatat.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/laporan/pengetahuan_ringkas.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/waktu.dart';
import 'komponen_pengetahuan.dart';
import 'provider_pengetahuan.dart';

const List<String> jenisBacaan = <String>[
  'buku',
  'artikel',
  'jurnal',
  'audio',
  'lain',
];

const List<String> statusBacaan = <String>['antre', 'dibaca', 'selesai', 'berhenti'];

class BacaanScreen extends ConsumerStatefulWidget {
  const BacaanScreen({super.key, this.jamSekarang});

  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<BacaanScreen> createState() => _BacaanScreenState();
}

class _BacaanScreenState extends ConsumerState<BacaanScreen> {
  bool _memuat = true;
  String _saringan = 'semua';
  List<BarisBacaan> _bacaan = const <BarisBacaan>[];

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final daftar = await ref.read(pengetahuanRepoProvider).daftarBacaan();
      if (!mounted) return;
      setState(() {
        _bacaan = daftar;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _memuat = false);
    }
  }

  List<BarisBacaan> get _terlihat => _saringan == 'semua'
      ? _bacaan
      : _bacaan.where((b) => b.status == _saringan).toList();

  Future<void> _form({BarisBacaan? ada}) async {
    final judul = TextEditingController(text: ada?.judul ?? '');
    final penulis = TextEditingController(text: ada?.penulis ?? '');
    final total = TextEditingController(
        text: ada?.halamanTotal == null ? '' : '${ada!.halamanTotal}');
    final halaman = TextEditingController(text: '${ada?.halamanKini ?? 0}');
    final nilai = TextEditingController(
        text: ada?.nilai == null ? '' : '${ada!.nilai}');
    var jenis = ada?.jenis ?? jenisBacaan.first;
    var status = ada?.status ?? 'antre';

    final setuju = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setel) => AlertDialog(
          title: Text(ada == null ? 'Bacaan baru' : 'Ubah bacaan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bidangTeks(pengendali: judul, label: 'Judul'),
                bidangTeks(pengendali: penulis, label: 'Penulis (boleh kosong)'),
                pemilihChip(
                  kunci: 'jenis_bacaan',
                  label: 'Jenis',
                  pilihan: jenisBacaan,
                  terpilih: jenis,
                  onPilih: (p) => setel(() => jenis = p),
                ),
                bidangTeks(
                  pengendali: total,
                  label: 'Jumlah halaman (boleh dikosongkan)',
                  jenisPapanKetik: TextInputType.number,
                ),
                bidangTeks(
                  pengendali: halaman,
                  label: 'Sudah dibaca sampai halaman',
                  jenisPapanKetik: TextInputType.number,
                ),
                pemilihChip(
                  kunci: 'status_bacaan',
                  label: 'Status',
                  pilihan: statusBacaan,
                  terpilih: status,
                  onPilih: (p) => setel(() => status = p),
                ),
                bidangTeks(
                  pengendali: nilai,
                  label: 'Penilaian sendiri 0–5 (boleh kosong)',
                  jenisPapanKetik: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              key: const Key('simpan_bacaan'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (setuju != true || judul.text.trim().isEmpty) return;

    await ref.read(pengetahuanRepoProvider).simpanBacaan(
          id: ada?.id,
          judul: judul.text.trim(),
          penulis: penulis.text.trim().isEmpty ? null : penulis.text.trim(),
          jenis: jenis,
          halamanTotal: int.tryParse(total.text.trim()),
          halamanKini: int.tryParse(halaman.text.trim()) ?? 0,
          status: status,
          nilai: int.tryParse(nilai.text.trim()),
          sekarang: _sekarang,
        );
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.pengetahuan,
      aksi: ada == null ? AksiAudit.buat : AksiAudit.ubah,
      entitas: 'bacaan',
      ringkas: '${ada == null ? 'Bacaan ditambah' : 'Bacaan diubah'}: '
          '${judul.text.trim()}',
    );
    await _muat();
  }

  Future<void> _tambahHalaman(BarisBacaan b, int tambahan) async {
    await ref
        .read(pengetahuanRepoProvider)
        .majukanHalaman(b.id, b.halamanKini + tambahan);
    await _muat();
  }

  Future<void> _hapus(BarisBacaan b) async {
    if (!await konfirmasiHapus(context, 'Bacaan "${b.judul}"')) return;
    await ref.read(pengetahuanRepoProvider).hapusBacaan(b.id);
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final ringkas = ringkasBacaan(_bacaan, acuan: _sekarang);
    final lihat = _terlihat;
    return Scaffold(
      appBar: AppBar(title: const Text('Buku & bacaan')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tambah_bacaan'),
        onPressed: () => _form(),
        icon: const Icon(Icons.add),
        label: const Text('Bacaan baru'),
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                kartuRingkas('Ringkasan bacaan', [
                  barisKunciNilai('Jumlah bacaan', '${ringkas.total}'),
                  barisKunciNilai('Sedang dibaca', '${ringkas.sedangDibaca.length}'),
                  barisKunciNilai('Menunggu (antre)', '${ringkas.antre}'),
                  barisKunciNilai('Selesai', '${ringkas.selesai}'),
                  barisKunciNilai('Selesai ${_sekarang.year}',
                      '${ringkas.selesaiTahunIni}'),
                  barisKunciNilai('Halaman tercatat', '${ringkas.halamanDibaca}'),
                  barisKunciNilai(
                    'Penilaian sendiri rata-rata',
                    ringkas.rataNilai == null
                        ? 'Belum ada data'
                        : ringkas.rataNilai!.toStringAsFixed(1),
                  ),
                ]),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final s in <String>['semua', ...statusBacaan])
                      ChoiceChip(
                        key: Key('saring_bacaan_$s'),
                        label: Text(s),
                        selected: _saringan == s,
                        onSelected: (_) => setState(() => _saringan = s),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (lihat.isEmpty)
                  kartuKosong(
                    _bacaan.isEmpty ? 'Belum ada bacaan' : 'Tidak ada pada saringan ini',
                    petunjuk: 'Tekan "Bacaan baru" untuk mencatat buku/artikel '
                        'dan halaman yang sudah dibaca.',
                  ),
                for (final b in lihat)
                  Card(
                    key: Key('bacaan_${b.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(b.judul,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                              ),
                              Text(b.status),
                            ],
                          ),
                          if ((b.penulis ?? '').isNotEmpty) Text(b.penulis!),
                          const SizedBox(height: 6),
                          if (b.progres != null) ...[
                            LinearProgressIndicator(value: b.progres),
                            const SizedBox(height: 4),
                            Text('${b.halamanKini} / ${b.halamanTotal} halaman '
                                '(${(b.progres! * 100).round()} %)'),
                          ] else
                            Text('Halaman tercatat: ${b.halamanKini}'),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              OutlinedButton(
                                key: Key('tambah10_bacaan_${b.id}'),
                                onPressed: () => _tambahHalaman(b, 10),
                                child: const Text('+10 halaman'),
                              ),
                              OutlinedButton(
                                key: Key('ubah_bacaan_${b.id}'),
                                onPressed: () => _form(ada: b),
                                child: const Text('Ubah'),
                              ),
                              OutlinedButton(
                                key: Key('hapus_bacaan_${b.id}'),
                                onPressed: () => _hapus(b),
                                child: const Text('Hapus'),
                              ),
                              if ((b.nilai ?? 0) > 0) lencana('penilaian ${b.nilai}/5'),
                              if (b.jumlahTautan > 0)
                                lencana('${b.jumlahTautan} tautan'),
                            ],
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
