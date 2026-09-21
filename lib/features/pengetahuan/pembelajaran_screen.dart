/// FR-120 — Pelacakan pembelajaran.
///
/// Isi: catat topik yang dipelajari, sumber, dan menitnya; lihat menit per hari
/// serta topik yang paling banyak dicatat. Aplikasi tidak menilai hasil belajar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/laporan/pengetahuan_ringkas.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import 'komponen_pengetahuan.dart';
import 'provider_pengetahuan.dart';

class PembelajaranScreen extends ConsumerStatefulWidget {
  const PembelajaranScreen({super.key, this.jamSekarang});

  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<PembelajaranScreen> createState() => _PembelajaranScreenState();
}

class _PembelajaranScreenState extends ConsumerState<PembelajaranScreen> {
  bool _memuat = true;
  List<BarisPembelajaran> _baris = const <BarisPembelajaran>[];

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final daftar = await ref.read(pengetahuanRepoProvider).daftarPembelajaran();
      if (!mounted) return;
      setState(() {
        _baris = daftar;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _memuat = false);
    }
  }

  Future<void> _form() async {
    final topik = TextEditingController();
    final sumber = TextEditingController();
    final menit = TextEditingController(text: '30');
    final catatan = TextEditingController();
    var status = 'belajar';

    final setuju = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setel) => AlertDialog(
          title: const Text('Catat belajar'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bidangTeks(pengendali: topik, label: 'Topik'),
                bidangTeks(
                  pengendali: sumber,
                  label: 'Sumber (boleh dikosongkan)',
                  petunjuk: 'Mis. buku, kursus, video',
                ),
                bidangTeks(
                  pengendali: menit,
                  label: 'Menit',
                  jenisPapanKetik: TextInputType.number,
                ),
                pemilihChip(
                  kunci: 'tahap',
                  label: 'Tahap',
                  pilihan: const <String>['belajar', 'latihan', 'selesai'],
                  terpilih: status,
                  onPilih: (p) => setel(() => status = p),
                ),
                bidangTeks(pengendali: catatan, label: 'Catatan', baris: 2),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              key: const Key('simpan_pembelajaran'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (setuju != true || topik.text.trim().isEmpty) return;

    await ref.read(pengetahuanRepoProvider).simpanPembelajaran(
          topik: topik.text.trim(),
          sumber: sumber.text.trim().isEmpty ? null : sumber.text.trim(),
          menit: int.tryParse(menit.text.trim()) ?? 0,
          status: status,
          catatan: catatan.text.trim().isEmpty ? null : catatan.text.trim(),
          tanggal: _sekarang,
          sekarang: _sekarang,
        );
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.pengetahuan,
      aksi: AksiAudit.buat,
      entitas: 'pembelajaran',
      ringkas: 'Belajar dicatat: ${topik.text.trim()}',
    );
    await _muat();
  }

  Future<void> _hapus(BarisPembelajaran b) async {
    final id = b.id;
    if (id == null) return;
    if (!await konfirmasiHapus(context, 'Catatan belajar "${b.topik}"')) return;
    await ref.read(pengetahuanRepoProvider).hapusPembelajaran(id);
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final ringkas = ringkasPembelajaran(_baris, acuan: _sekarang);
    final batang = batangPembelajaran(_baris, acuan: _sekarang);
    final tertinggi = batang.fold<int>(1, (a, b) => b.menit > a ? b.menit : a);
    final urut = [..._baris]..sort((a, b) => b.tanggal.compareTo(a.tanggal));

    return Scaffold(
      appBar: AppBar(title: const Text('Pembelajaran')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tambah_pembelajaran'),
        onPressed: _form,
        icon: const Icon(Icons.add),
        label: const Text('Catat belajar'),
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                kartuRingkas('Ringkasan', [
                  barisKunciNilai('Menit 7 hari terakhir', '${ringkas.menitRentang}'),
                  barisKunciNilai('Total menit', '${ringkas.totalMenit}'),
                  barisKunciNilai('Hari ada catatan (7 hari)',
                      '${ringkas.hariAktif}'),
                  barisKunciNilai('Topik terbanyak',
                      ringkas.topikTeratas ?? 'Belum ada data'),
                ]),
                const SizedBox(height: 8),
                kartuRingkas('Menit per hari (14 hari)', [
                  if (_baris.isEmpty)
                    const Text('Belum ada catatan.')
                  else
                    SizedBox(
                      height: 90,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final b in batang)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      height: b.menit == 0
                                          ? 2
                                          : 2 + (b.menit / tertinggi) * 60,
                                      decoration: BoxDecoration(
                                        color: b.menit == 0
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
                ]),
                const SizedBox(height: 8),
                if (ringkas.perTopik.isNotEmpty)
                  kartuRingkas('Menit per topik', [
                    for (final e in (ringkas.perTopik.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value))))
                      barisKunciNilai(e.key, '${e.value} menit'),
                  ]),
                const SizedBox(height: 8),
                if (urut.isEmpty)
                  kartuKosong('Belum ada catatan belajar',
                      petunjuk: 'Tekan "Catat belajar" untuk mencatat topik, '
                          'sumber, dan menitnya.'),
                for (final b in urut)
                  Card(
                    key: Key('pembelajaran_${b.id}'),
                    child: ListTile(
                      title: Text(b.topik,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${b.menit} menit · ${b.status}'
                          '${(b.sumber ?? '').isEmpty ? '' : ' · ${b.sumber}'}'
                          ' · ${fmtTanggalPendekAman(b.tanggal)}'),
                      trailing: IconButton(
                        key: Key('hapus_pembelajaran_${b.id}'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _hapus(b),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
