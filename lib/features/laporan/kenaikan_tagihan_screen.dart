/// FR-35 — Layar Deteksi Kenaikan Tagihan.
///
/// Menampilkan tagihan yang nominal terakhirnya naik dibanding rata-rata tiga
/// pembayaran sebelumnya, lengkap dengan buktinya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/kenaikan_tagihan.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';

class KenaikanTagihanScreen extends ConsumerStatefulWidget {
  const KenaikanTagihanScreen({super.key, this.ambangPersen = 10});

  final int ambangPersen;

  @override
  ConsumerState<KenaikanTagihanScreen> createState() =>
      _KenaikanTagihanScreenState();
}

class _KenaikanTagihanScreenState extends ConsumerState<KenaikanTagihanScreen> {
  bool _memuat = true;
  List<KenaikanTagihan> _temuan = const [];
  int _jumlahRiwayat = 0;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final riwayat = await ref.read(tagihanRepoProvider).riwayatUntukEkspor();
    final temuan = deteksiKenaikanTagihan(
      riwayat: riwayat
          .map((r) => (
                nama: r.namaTagihan,
                tanggalBayar: r.tanggalBayar,
                nominalSen: r.jumlahSen,
              ))
          .toList(),
      ambangPersen: widget.ambangPersen,
    );
    if (!mounted) return;
    setState(() {
      _temuan = temuan;
      _jumlahRiwayat = riwayat.length;
      _memuat = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Kenaikan tagihan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tagihan yang nominalnya naik',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    _temuan.isEmpty
                        ? 'Belum ada kenaikan yang menonjol (ambang ${widget.ambangPersen}%).'
                        : '${_temuan.length} tagihan naik lebih dari '
                            '${widget.ambangPersen}% dibanding rata-rata 3 pembayaran sebelumnya.',
                    key: const Key('kenaikan_ringkas'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_temuan.isEmpty)
            const Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Catatan: perbandingan butuh minimal 4 kali '
                    'pembayaran untuk tagihan yang sama.'),
              ),
            )
          else
            for (final t in _temuan)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(t.nama,
                                key: Key('kenaikan_${t.nama}'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                          ),
                          Text('+${t.persenNaik}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.error,
                              )),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Terakhir ${fmtRpDariSen(t.nominalTerakhirSen)} '
                          '(${fmtTanggalAman(t.tanggalTerakhir)})'),
                      Text('Rata-rata 3 sebelumnya '
                          '${fmtRpDariSen(t.rataRataSebelumnyaSen)} → naik '
                          '${fmtRpDariSen(t.selisihSen)}'),
                      const SizedBox(height: 4),
                      Text(
                        'Bukti 3 pembayaran sebelumnya: '
                        '${t.tigaTerakhirSen.map(fmtRpDariSen).join(" · ")}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 8),
          Text('Diperiksa dari $_jumlahRiwayat catatan pembayaran di HP ini.',
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
