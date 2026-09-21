/// FR-30 — Layar Proyeksi Arus Kas 3 Bulan.
///
/// Menjawab: "tiga bulan ke depan, berapa uang yang akan keluar?"
/// Sumber: tagihan aktif (semua frekuensi) + langganan yang masih berjalan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/proyeksi_arus_kas.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';

class ProyeksiArusKasScreen extends ConsumerStatefulWidget {
  const ProyeksiArusKasScreen({super.key, this.acuan, this.jumlahBulan = 3});

  /// Acuan "hari ini" (boleh disuntik saat uji supaya hasilnya tetap).
  final DateTime? acuan;
  final int jumlahBulan;

  @override
  ConsumerState<ProyeksiArusKasScreen> createState() =>
      _ProyeksiArusKasScreenState();
}

class _ProyeksiArusKasScreenState
    extends ConsumerState<ProyeksiArusKasScreen> {
  bool _memuat = true;
  List<BarisProyeksi> _baris = const [];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final db = ref.read(databaseProvider);
    final tagihan = await ref.read(tagihanRepoProvider).ambilSemua();
    final langganan = await db.select(db.langganan).get();
    final hasil = proyeksiArusKas(
      tagihan: tagihan,
      langganan: langganan,
      mulai: widget.acuan ?? DateTime.now(),
      jumlahBulan: widget.jumlahBulan,
    );
    if (!mounted) return;
    setState(() {
      _baris = hasil;
      _memuat = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final total = totalProyeksiSen(_baris);
    final terberat = bulanTerberat(_baris);
    return Scaffold(
      appBar: AppBar(title: const Text('Proyeksi Arus Kas')),
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
                  Text('${_baris.length} bulan ke depan',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    fmtRpDariSen(total),
                    key: const Key('proyeksi_total'),
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const Text('perkiraan uang yang akan keluar'),
                  if (terberat != null) ...[
                    const Divider(height: 24),
                    Text(
                      'Bulan paling berat: ${fmtBulanAman(terberat.bulan)} · '
                      '${fmtRpDariSen(terberat.totalSen)}',
                      key: const Key('proyeksi_terberat'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final b in _baris) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                key: Key('proyeksi_${b.bulan.year}-${b.bulan.month}'),
                title: Text(fmtBulanAman(b.bulan)),
                subtitle: Text('${b.jumlahTagihan} tagihan · '
                    '${b.jumlahLangganan} langganan'),
                trailing: Text(fmtRpDariSen(b.totalSen),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Perkiraan ini memakai tagihan yang masih aktif dan langganan yang '
            'sedang berjalan. Tagihan yang sudah lunas tetap muncul pada jadwal '
            'berikutnya sesuai frekuensinya (bulanan, tahunan, dan seterusnya).',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
