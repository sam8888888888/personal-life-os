/// FR-29 — Layar Statistik Pembayaran.
///
/// Menampilkan: ringkasan (total, jumlah, rata-rata, terbesar/terkecil, tepat
/// waktu), tren 12 bulan terakhir (grafik batang sederhana tanpa paket luar),
/// dan daftar tagihan menurut total yang dibayar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/statistik_pembayaran.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';

class StatistikPembayaranScreen extends ConsumerStatefulWidget {
  const StatistikPembayaranScreen({super.key, this.acuan});

  /// Acuan "hari ini" (boleh disuntik saat uji supaya hasilnya tetap).
  final DateTime? acuan;

  @override
  ConsumerState<StatistikPembayaranScreen> createState() =>
      _StatistikPembayaranScreenState();
}

class _StatistikPembayaranScreenState
    extends ConsumerState<StatistikPembayaranScreen> {
  bool _memuat = true;
  StatistikPembayaran _stat = hitungStatistikPembayaran(const []);
  List<StatistikBulan> _perBulan = const [];
  List<StatistikPerTagihan> _perTagihan = const [];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final riwayat = await ref.read(tagihanRepoProvider).riwayatUntukEkspor();
    final baris = riwayat
        .map((r) => PembayaranRingkas(
              namaTagihan: r.namaTagihan,
              tanggalBayar: r.tanggalBayar,
              jumlahSen: r.jumlahSen,
              telatHari: r.telatHari ?? 0,
            ))
        .toList();
    if (!mounted) return;
    setState(() {
      _stat = hitungStatistikPembayaran(baris);
      _perBulan = statistikPerBulan(baris, acuan: widget.acuan);
      _perTagihan = statistikPerTagihan(baris);
      _memuat = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Statistik Pembayaran')),
      body: _stat.kosong
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada riwayat pembayaran.\nSetelah Papi menandai tagihan '
                  'lunas, ringkasannya muncul di sini.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _kartuRingkasan(context),
                const SizedBox(height: 16),
                _kartuTren(context),
                const SizedBox(height: 16),
                _kartuPerTagihan(context),
              ],
            ),
    );
  }

  Widget _kartuRingkasan(BuildContext context) {
    final gayaJudul = Theme.of(context).textTheme.titleMedium;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ringkasan', style: gayaJudul),
            const SizedBox(height: 8),
            Text(
              fmtRpDariSen(_stat.totalSen),
              key: const Key('stat_total'),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            Text('total dibayar dari ${_stat.jumlahPembayaran} pembayaran'),
            const Divider(height: 24),
            _baris(context, 'Rata-rata per pembayaran',
                fmtRpDariSen(_stat.rataRataSen), 'stat_rata'),
            _baris(context, 'Paling besar', fmtRpDariSen(_stat.terbesarSen),
                'stat_besar'),
            _baris(context, 'Paling kecil', fmtRpDariSen(_stat.terkecilSen),
                'stat_kecil'),
            const Divider(height: 24),
            _baris(
              context,
              'Tepat waktu',
              '${_stat.persenTepatWaktu}% '
                  '(${_stat.tepatWaktu} dari ${_stat.jumlahPembayaran})',
              'stat_tepat',
            ),
            if (_stat.lewatJatuhTempo > 0)
              _baris(
                context,
                'Lewat jatuh tempo',
                '${_stat.lewatJatuhTempo}× · rata-rata '
                    '${_stat.rataHariTelat} hari',
                'stat_telat',
              ),
          ],
        ),
      ),
    );
  }

  Widget _baris(BuildContext context, String label, String nilai, String kunci) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(nilai,
              key: Key(kunci),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _kartuTren(BuildContext context) {
    final tertinggi = _perBulan.fold<int>(
        0, (a, b) => b.totalSen > a ? b.totalSen : a);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tren 12 bulan terakhir',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final b in _perBulan)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              key: Key('batang_${b.bulan.year}-${b.bulan.month}'),
                              height: tertinggi == 0
                                  ? 2
                                  : (2 + 78 * (b.totalSen / tertinggi)),
                              decoration: BoxDecoration(
                                color: b.totalSen == 0
                                    ? Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                    : Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              namaBulanSingkat[b.bulan.month],
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bulan paling besar: '
              '${_perBulan.isEmpty || tertinggi == 0 ? "belum ada" : "$_namaBulanTerbesar ${fmtRpDariSen(tertinggi)}"}',
              key: const Key('stat_bulan_terbesar'),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String get _namaBulanTerbesar {
    var terbesar = _perBulan.first;
    for (final b in _perBulan) {
      if (b.totalSen > terbesar.totalSen) terbesar = b;
    }
    return '${namaBulanSingkat[terbesar.bulan.month]} ${terbesar.bulan.year}';
  }

  Widget _kartuPerTagihan(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Menurut tagihan',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final t in _perTagihan)
              ListTile(
                key: Key('per_tagihan_${t.nama}'),
                contentPadding: EdgeInsets.zero,
                title: Text(t.nama),
                subtitle: Text('${t.jumlahPembayaran}× dibayar · rata-rata '
                    '${fmtRpDariSen(t.rataRataSen)} · ${t.tepatWaktu} tepat waktu'),
                trailing: Text(fmtRpDariSen(t.totalSen),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}
