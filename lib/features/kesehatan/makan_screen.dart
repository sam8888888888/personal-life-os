/// FR-110 — Catatan makan ringkas (quick log).
///
/// Isi: catat makan dengan beberapa tekanan (jenis → isi → simpan), lihat apa
/// yang sudah tercatat hari ini dan berapa catatan per hari. Aplikasi tidak
/// menghitung kalori dan tidak menilai isi makanan (PRD §7.4 & III-11).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/laporan/makan_ringkas.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import '../../data/repository/kesehatan_repository.dart';
import '../pengetahuan/komponen_pengetahuan.dart';
import '../pengetahuan/provider_pengetahuan.dart';
import 'grafik_batang_harian.dart';
import 'kartu_bagian.dart';

class MakanRingkasScreen extends ConsumerStatefulWidget {
  const MakanRingkasScreen({super.key, this.jamSekarang});

  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<MakanRingkasScreen> createState() => _MakanRingkasScreenState();
}

class _MakanRingkasScreenState extends ConsumerState<MakanRingkasScreen> {
  bool _memuat = true;
  List<BarisMakan> _catatan = const <BarisMakan>[];

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
          .daftarMakan(sampai: _sekarang, hari: 30);
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

  Future<void> _catat(String jenis) async {
    final isi = TextEditingController();
    final porsi = TextEditingController();
    String? mutu;
    final setuju = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setel) => AlertDialog(
        title: Text('Catat ${labelMakan(jenis).toLowerCase()}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bidangTeks(
                pengendali: isi,
                label: 'Apa yang dimakan',
                petunjuk: 'Tulis apa adanya, mis. nasi + telur',
              ),
              if (isiTersering(_catatan).isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: [
                    for (final s in isiTersering(_catatan))
                      ActionChip(
                        key: Key('cepat_$s'),
                        label: Text(s),
                        onPressed: () => isi.text = s,
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              bidangTeks(
                pengendali: porsi,
                label: 'Porsi (boleh dikosongkan)',
                petunjuk: 'Mis. 1 piring, 1 gelas',
              ),
              pemilihChip(
                kunci: 'mutu',
                label: 'Menurut Anda sendiri (boleh dikosongkan)',
                pilihan: const <String>['baik', 'cukup', 'kurang'],
                terpilih: mutu ?? '',
                onPilih: (p) => setel(() => mutu = p),
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
            key: const Key('simpan_makan'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Simpan'),
          ),
        ],
        ),
      ),
    );
    if (setuju != true || isi.text.trim().isEmpty) return;
    await ref.read(kesehatanRingkasRepoProvider).simpanMakan(
          jenis: jenis,
          isi: isi.text.trim(),
          porsi: porsi.text.trim().isEmpty ? null : porsi.text.trim(),
          mutu: mutu,
          waktu: _sekarang,
          sekarang: _sekarang,
        );
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.kesehatan,
      aksi: AksiAudit.buat,
      entitas: 'catatan_makan',
      ringkas: 'Makan dicatat (${labelMakan(jenis)}): ${isi.text.trim()}',
    );
    await _muat();
  }

  Future<void> _hapus(BarisMakan m) async {
    final id = m.id;
    if (id == null) return;
    if (!await konfirmasiHapus(context, 'Catatan "${m.isi}"')) return;
    await ref.read(kesehatanRingkasRepoProvider).hapusMakan(id);
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final ringkas = ringkasMakanHari(_catatan, acuan: _sekarang);
    final batang = batangMakan(_catatan, acuan: _sekarang)
        .map((b) => BatangHarian(tanggal: b.tanggal, nilai: b.jumlah))
        .toList();
    final hariIni = _catatan
        .where((c) => hariMakanSama(c.waktu, _sekarang))
        .toList()
      ..sort((a, b) => a.waktu.compareTo(b.waktu));

    return Scaffold(
      appBar: AppBar(title: const Text('Catatan makan')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                KartuBagian(
                  judul: 'Catat cepat',
                  ikon: Icons.restaurant_outlined,
                  anak: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final jenis in jenisMakan)
                          FilledButton.tonal(
                            key: Key('catat_$jenis'),
                            onPressed: () => _catat(jenis),
                            child: Text(labelMakan(jenis)),
                          ),
                      ],
                    ),
                  ],
                ),
                KartuBagian(
                  judul: 'Hari ini',
                  ikon: Icons.today_outlined,
                  anak: [
                    if (ringkas.jumlahCatatan == 0)
                      const TeksBelumAdaData()
                    else ...[
                      for (final j in ringkas.perJenis)
                        Text('${j.label}: '
                            '${j.tercatat ? j.isi.join(', ') : 'belum tercatat'}'),
                      const SizedBox(height: 6),
                      Text('Jumlah catatan: ${ringkas.jumlahCatatan}'),
                      if (ringkas.jamPertama != null && ringkas.jamTerakhir != null)
                        Text('Catatan pertama ${fmtJam(ringkas.jamPertama!)} · '
                            'terakhir ${fmtJam(ringkas.jamTerakhir!)}'),
                    ],
                  ],
                ),
                KartuBagian(
                  judul: 'Catatan per hari (7 hari)',
                  ikon: Icons.bar_chart,
                  anak: [
                    if (_catatan.isEmpty)
                      const TeksBelumAdaData()
                    else
                      GrafikBatangHarian(batang: batang, satuan: 'catatan'),
                    const SizedBox(height: 6),
                    Text(
                      hariBerturutTercatat(_catatan, acuan: _sekarang) > 0
                          ? 'Tercatat ${hariBerturutTercatat(_catatan, acuan: _sekarang)} '
                              'hari berturut-turut (termasuk hari ini).'
                          : 'Belum ada catatan pada hari ini.',
                    ),
                  ],
                ),
                if (hariIni.isEmpty)
                  kartuKosong('Belum ada catatan hari ini',
                      petunjuk: 'Tekan salah satu tombol di atas untuk mencatat.'),
                for (final m in hariIni.reversed)
                  Card(
                    key: Key('makan_${m.id}'),
                    child: ListTile(
                      title: Text('${labelMakan(m.jenis)} · ${m.isi}'),
                      subtitle: Text('${fmtJam(m.waktu)}'
                          '${(m.porsi ?? '').isEmpty ? '' : ' · ${m.porsi}'}'
                          '${(m.mutu ?? '').isEmpty ? '' : ' · menurut saya: ${m.mutu}'}'),
                      trailing: IconButton(
                        key: Key('hapus_makan_${m.id}'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _hapus(m),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
