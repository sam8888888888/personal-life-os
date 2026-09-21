/// FR-112 — Jurnal suasana hati & stres.
///
/// Isi: catat suasana hati (skala 1–5 yang Anda pilih sendiri), energi, tingkat
/// stres, pemicu, dan catatan singkat; lihat rata-rata & arah perubahannya.
/// Aplikasi hanya melaporkan angka apa adanya — bukan menilai keadaan Anda.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/laporan/suasana_hati.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import '../pengetahuan/komponen_pengetahuan.dart';
import '../pengetahuan/provider_pengetahuan.dart';
import 'kartu_bagian.dart';

class SuasanaHatiScreen extends ConsumerStatefulWidget {
  const SuasanaHatiScreen({super.key, this.jamSekarang});

  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<SuasanaHatiScreen> createState() => _SuasanaHatiScreenState();
}

class _SuasanaHatiScreenState extends ConsumerState<SuasanaHatiScreen> {
  bool _memuat = true;
  List<BarisSuasana> _catatan = const <BarisSuasana>[];

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final daftar = await ref
          .read(kesehatanRingkasRepoProvider)
          .daftarSuasana(sampai: _sekarang, hari: 60);
      if (!mounted) return;
      setState(() {
        _catatan = daftar;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _memuat = false);
    }
  }

  Future<void> _catat() async {
    var skor = 3;
    int? energi;
    int? stres;
    final pemicu = TextEditingController();
    final catatan = TextEditingController();

    final setuju = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setel) => AlertDialog(
          title: const Text('Catat suasana hati'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                pemilihChip(
                  kunci: 'suasana',
                  label: 'Suasana hati hari ini',
                  pilihan: const <String>['1', '2', '3', '4', '5'],
                  terpilih: '$skor',
                  onPilih: (p) => setel(() => skor = int.parse(p)),
                ),
                Text(labelSuasana[skor] ?? '$skor'),
                const SizedBox(height: 10),
                pemilihChip(
                  kunci: 'energi',
                  label: 'Energi (boleh dikosongkan)',
                  pilihan: const <String>['1', '2', '3', '4', '5'],
                  terpilih: energi == null ? '' : '$energi',
                  onPilih: (p) => setel(() => energi = int.parse(p)),
                ),
                pemilihChip(
                  kunci: 'stres',
                  label: 'Stres (boleh dikosongkan)',
                  pilihan: const <String>['1', '2', '3', '4', '5'],
                  terpilih: stres == null ? '' : '$stres',
                  onPilih: (p) => setel(() => stres = int.parse(p)),
                ),
                bidangTeks(
                  pengendali: pemicu,
                  label: 'Pemicu (boleh dikosongkan)',
                  petunjuk: 'Mis. rapat, kurang tidur, keluarga',
                ),
                bidangTeks(pengendali: catatan, label: 'Catatan singkat', baris: 3),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              key: const Key('simpan_suasana'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (setuju != true) return;
    await ref.read(kesehatanRingkasRepoProvider).simpanSuasana(
          skor: skor,
          energi: energi,
          stres: stres,
          pemicu: pemicu.text.trim().isEmpty ? null : pemicu.text.trim(),
          catatan: catatan.text.trim().isEmpty ? null : catatan.text.trim(),
          waktu: _sekarang,
          sekarang: _sekarang,
        );
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.kesehatan,
      aksi: AksiAudit.buat,
      entitas: 'suasana_hati',
      ringkas: 'Suasana hati dicatat: $skor dari 5',
    );
    await _muat();
  }

  Future<void> _hapus(BarisSuasana s) async {
    final id = s.id;
    if (id == null) return;
    if (!await konfirmasiHapus(context, 'Catatan suasana hati')) return;
    await ref.read(kesehatanRingkasRepoProvider).hapusSuasana(id);
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final r = ringkasSuasana(_catatan, acuan: _sekarang);
    final terbaru = [..._catatan]..sort((a, b) => b.waktu.compareTo(a.waktu));

    return Scaffold(
      appBar: AppBar(title: const Text('Suasana hati & stres')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tambah_suasana'),
        onPressed: _catat,
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                KartuBagian(
                  judul: 'Ringkasan',
                  ikon: Icons.insights_outlined,
                  anak: [
                    if (r.jumlahCatatan == 0)
                      const TeksBelumAdaData()
                    else ...[
                      Text('Jumlah catatan: ${r.jumlahCatatan}'),
                      Text('Rata-rata suasana hati: '
                          '${r.rataRata!.toStringAsFixed(1)} dari 5'),
                      if (r.energiRataRata != null)
                        Text('Rata-rata energi: '
                            '${r.energiRataRata!.toStringAsFixed(1)} dari 5'),
                      if (r.stresRataRata != null)
                        Text('Rata-rata stres: '
                            '${r.stresRataRata!.toStringAsFixed(1)} dari 5'),
                      const SizedBox(height: 4),
                      Text(kalimatArahSuasana(r)),
                      if (r.pemicuTersering.isNotEmpty)
                        Text('Pemicu yang paling sering ditulis: '
                            '${r.pemicuTersering.join(', ')}'),
                    ],
                  ],
                ),
                if (r.jumlahCatatan > 0)
                  KartuBagian(
                    judul: 'Rata-rata per hari (14 hari)',
                    ikon: Icons.bar_chart,
                    anak: [
                      SizedBox(
                        height: 110,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final b in r.batang)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        b.rataRata == null
                                            ? ''
                                            : b.rataRata!.toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 9),
                                      ),
                                      Container(
                                        height: b.rataRata == null
                                            ? 2
                                            : (b.rataRata! / 5) * 70,
                                        decoration: BoxDecoration(
                                          color: b.rataRata == null
                                              ? const Color(0xFFD7DCE5)
                                              : const Color(0xFF3D6DB5),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(b.label,
                                          style: const TextStyle(fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Text(
                        'Skala 1–5 yang Anda pilih sendiri (makin tinggi makin '
                        'ringan). Kolom kosong = hari tanpa catatan.',
                      ),
                    ],
                  ),
                if (terbaru.isEmpty)
                  kartuKosong('Belum ada catatan suasana hati',
                      petunjuk: 'Tekan "Catat" untuk menulis keadaan hari ini '
                          'pada skala 1–5.'),
                for (final s in terbaru.take(20))
                  Card(
                    key: Key('suasana_${s.id}'),
                    child: ListTile(
                      title: Text('${labelSuasana[s.skor] ?? s.skor}'
                          '${s.energi == null ? '' : ' · energi ${s.energi}'}'
                          '${s.stres == null ? '' : ' · stres ${s.stres}'}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${fmtTanggalPendekAman(s.waktu)} · ${fmtJam(s.waktu)}'),
                          if ((s.pemicu ?? '').isNotEmpty) Text('Pemicu: ${s.pemicu}'),
                          if ((s.catatan ?? '').isNotEmpty) Text(s.catatan!),
                        ],
                      ),
                      trailing: IconButton(
                        key: Key('hapus_suasana_${s.id}'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _hapus(s),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
