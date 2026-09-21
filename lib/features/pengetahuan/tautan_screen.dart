/// FR-123 — Penghubung pengetahuan.
///
/// Isi: menautkan butir pengetahuan satu dengan lainnya (catatan ↔ keputusan ↔
/// bacaan ↔ kartu ulangan ↔ pembelajaran), lalu melihat daftar tautannya.
/// Tidak ada butir yang diubah isinya oleh tautan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/laporan/pengetahuan_ringkas.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/waktu.dart';
import 'komponen_pengetahuan.dart';
import 'provider_pengetahuan.dart';

/// Jenis butir yang bisa ditautkan (FR-123: catatan ↔ tujuan ↔ proyek ↔ tugas
/// ↔ dokumen, ditambah butir modul pengetahuan sendiri).
const List<String> jenisButir = <String>[
  'catatan',
  'keputusan',
  'bacaan',
  'kartu',
  'pembelajaran',
  'tujuan',
  'proyek',
  'tugas',
  'dokumen',
];

typedef PilihanButir = ButirPengetahuan;

class TautanScreen extends ConsumerStatefulWidget {
  const TautanScreen({super.key, this.jamSekarang});

  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<TautanScreen> createState() => _TautanScreenState();
}

class _TautanScreenState extends ConsumerState<TautanScreen> {
  bool _memuat = true;
  List<BarisTautan> _tautan = const <BarisTautan>[];
  List<PilihanButir> _butir = const <PilihanButir>[];

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final repo = ref.read(pengetahuanRepoProvider);
    try {
      final tautan = await repo.daftarTautan();
      final catatan = await repo.daftarCatatan(termasukArsip: true);
      final keputusan = await repo.daftarKeputusan();
      final bacaan = await repo.daftarBacaan();
      final kartu = await repo.daftarKartu();
      final belajar = await repo.daftarPembelajaran();
      final modulLain = await repo.butirModulLain();
      if (!mounted) return;
      setState(() {
        _tautan = tautan;
        _butir = <PilihanButir>[
          for (final c in catatan) PilihanButir('catatan', c.id, c.judul),
          for (final k in keputusan) PilihanButir('keputusan', k.id, k.judul),
          for (final b in bacaan) PilihanButir('bacaan', b.id, b.judul),
          for (final k in kartu) PilihanButir('kartu', k.id, k.pertanyaan),
          for (final p in belajar)
            PilihanButir('pembelajaran', p.id ?? 0, p.topik),
          ...modulLain,
        ];
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _memuat = false);
    }
  }

  Future<void> _tambah() async {
    if (_butir.isEmpty) return;
    var a = _butir.first;
    var b = _butir.length > 1 ? _butir[1] : _butir.first;
    final label = TextEditingController();
    String? pesan;

    final setuju = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setel) {
          Widget pemilih(String judul, PilihanButir terpilih,
                  ValueChanged<PilihanButir> onPilih) =>
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(judul,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  DropdownButtonFormField<PilihanButir>(
                    key: Key('pilih_${judul.replaceAll(' ', '_')}'),
                    initialValue: terpilih,
                    isExpanded: true,
                    items: [
                      for (final p in _butir)
                        DropdownMenuItem(value: p, child: Text(p.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setel(() => onPilih(v));
                    },
                  ),
                ],
              );

          return AlertDialog(
            title: const Text('Tautkan butir pengetahuan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  pemilih('Dari butir', a, (p) => a = p),
                  pemilih('Ke butir', b, (p) => b = p),
                  bidangTeks(
                    pengendali: label,
                    label: 'Keterangan tautan (boleh kosong)',
                  ),
                  if (pesan != null)
                    Text(pesan!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal'),
              ),
              FilledButton(
                key: const Key('simpan_tautan'),
                onPressed: () async {
                  if (!tautanSah(a.jenis, a.id, b.jenis, b.id)) {
                    setel(() => pesan =
                        'Sebuah butir tidak bisa ditautkan dengan dirinya sendiri.');
                    return;
                  }
                  final tersimpan =
                      await ref.read(pengetahuanRepoProvider).simpanTautan(
                            BarisTautan(
                              jenisA: a.jenis,
                              idA: a.id,
                              judulA: a.judul,
                              jenisB: b.jenis,
                              idB: b.id,
                              judulB: b.judul,
                              label: label.text.trim().isEmpty
                                  ? null
                                  : label.text.trim(),
                            ),
                            sekarang: _sekarang,
                          );
                  if (!tersimpan) {
                    setel(() => pesan = 'Tautan ini sudah ada di daftar.');
                    return;
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
    if (setuju == true) {
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.pengetahuan,
        aksi: AksiAudit.buat,
        entitas: 'tautan_pengetahuan',
        ringkas: 'Tautan dibuat: ${a.judul} ↔ ${b.judul}',
      );
      await _muat();
    }
  }

  Future<void> _hapus(BarisTautan t) async {
    final repo = ref.read(pengetahuanRepoProvider);
    final semua = await repo.daftarTautan();
    final cocok = semua.where((x) =>
        kunciTautan(x.jenisA, x.idA, x.jenisB, x.idB) ==
        kunciTautan(t.jenisA, t.idA, t.jenisB, t.idB));
    if (cocok.isEmpty) return;
    await repo.hapusTautanButir(t.jenisA, t.idA);
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final perJenis = jumlahTautanPerJenis(_tautan);
    return Scaffold(
      appBar: AppBar(title: const Text('Penghubung pengetahuan')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tambah_tautan'),
        onPressed: _butir.isEmpty ? null : _tambah,
        icon: const Icon(Icons.add),
        label: const Text('Tautan baru'),
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                kartuRingkas('Ringkasan tautan', [
                  barisKunciNilai('Jumlah tautan', '${_tautan.length}'),
                  barisKunciNilai('Butir tersedia', '${_butir.length}'),
                  for (final e in perJenis.entries)
                    barisKunciNilai(labelJenisPengetahuan(e.key), '${e.value}'),
                ]),
                const SizedBox(height: 8),
                if (_butir.isEmpty)
                  kartuKosong('Belum ada butir untuk ditautkan',
                      petunjuk: 'Buat dulu catatan, keputusan, bacaan, atau '
                          'kartu ulangan — lalu tautkan di sini.'),
                if (_tautan.isEmpty && _butir.isNotEmpty)
                  kartuKosong('Belum ada tautan',
                      petunjuk: 'Tekan "Tautan baru" untuk menghubungkan dua '
                          'butir pengetahuan.'),
                for (final t in _tautan)
                  Card(
                    key: Key('tautan_${t.jenisA}_${t.idA}_${t.jenisB}_${t.idB}'),
                    child: ListTile(
                      leading: const Icon(Icons.link),
                      title: Text('${t.judulA} ↔ ${t.judulB}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${labelJenisPengetahuan(t.jenisA)} · '
                              '${labelJenisPengetahuan(t.jenisB)}'),
                          if ((t.label ?? '').isNotEmpty) Text(t.label!),
                        ],
                      ),
                      trailing: IconButton(
                        key: Key('hapus_tautan_${t.idA}_${t.idB}'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _hapus(t),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
