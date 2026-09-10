/// Kalender bulanan (UC-2): melihat semua tagihan bulan ini per tanggal.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';

class KalenderScreen extends ConsumerStatefulWidget {
  const KalenderScreen({super.key});

  @override
  ConsumerState<KalenderScreen> createState() => _KalenderScreenState();
}

class _KalenderScreenState extends ConsumerState<KalenderScreen> {
  late DateTime _bulan;
  DateTime? _pilih;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _bulan = DateTime(n.year, n.month);
    _pilih = DateTime(n.year, n.month, n.day);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tagihanAktifProvider);
    final skema = Theme.of(context).colorScheme;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal memuat: $e')),
      data: (semua) {
        final bulanIni = semua
            .where((t) =>
                t.jatuhTempo.year == _bulan.year && t.jatuhTempo.month == _bulan.month)
            .toList();
        final perTanggal = <int, List<TagihanData>>{};
        for (final t in bulanIni) {
          perTanggal.putIfAbsent(t.jatuhTempo.day, () => []).add(t);
        }
        final terpilih = _pilih == null
            ? const <TagihanData>[]
            : (perTanggal[_pilih!.day] ?? const <TagihanData>[]);
        final totalBulan =
            bulanIni.fold<int>(0, (a, t) => a + (t.jumlahSen ?? 0));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => setState(
                        () => _bulan = DateTime(_bulan.year, _bulan.month - 1)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(fmtBulanId(_bulan),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        Text('${bulanIni.length} tagihan · ${fmtRpDariSen(totalBulan)}',
                            style:
                                TextStyle(fontSize: 12, color: skema.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(
                        () => _bulan = DateTime(_bulan.year, _bulan.month + 1)),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            _gridBulan(perTanggal),
            const Divider(height: 1),
            Expanded(
              child: terpilih.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy,
                              size: 40, color: skema.outline),
                          const SizedBox(height: 6),
                          Text(_pilih == null
                              ? 'Pilih tanggal untuk melihat tagihan.'
                              : 'Tidak ada tagihan pada '
                                  '${fmtTanggalId(_pilih!)}.'),
                        ],
                      ),
                    )
                  : ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Text(fmtTanggalId(_pilih!),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        ...terpilih.map((t) => ListTile(
                              leading: Icon(
                                  t.lunas ? Icons.check_circle : Icons.circle_outlined,
                                  color: t.lunas ? skema.primary : skema.error),
                              title: Text(t.nama),
                              subtitle: Text(t.lunas ? 'Sudah dibayar' : 'Belum dibayar'),
                              trailing: Text(
                                  t.jumlahSen == null
                                      ? '—'
                                      : fmtRpDariSen(t.jumlahSen!),
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              onTap: () => context.push('/ubah/${t.id}'),
                            )),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _gridBulan(Map<int, List<TagihanData>> perTanggal) {
    final skema = Theme.of(context).colorScheme;
    final pertama = DateTime(_bulan.year, _bulan.month, 1);
    final jumlahHari = DateTime(_bulan.year, _bulan.month + 1, 0).day;
    // Senin=1 ... Minggu=7 -> offset kolom (mulai Senin)
    final offset = pertama.weekday - 1;
    final sel = <Widget>[
      for (final s in ['S', 'S', 'R', 'K', 'J', 'S', 'M'])
        Center(
          child: Text(s,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: skema.onSurfaceVariant)),
        ),
      for (var i = 0; i < offset; i++) const SizedBox.shrink(),
      for (var hari = 1; hari <= jumlahHari; hari++)
        _selTanggal(hari, perTanggal[hari] ?? const []),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.05,
        children: sel,
      ),
    );
  }

  Widget _selTanggal(int hari, List<TagihanData> daftar) {
    final skema = Theme.of(context).colorScheme;
    final iniHariIni = DateTime.now();
    final adalahHariIni = _bulan.year == iniHariIni.year &&
        _bulan.month == iniHariIni.month &&
        hari == iniHariIni.day;
    final terpilih = _pilih?.day == hari &&
        _pilih?.month == _bulan.month &&
        _pilih?.year == _bulan.year;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _pilih = DateTime(_bulan.year, _bulan.month, hari)),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: terpilih
              ? skema.primaryContainer
              : (adalahHariIni ? skema.surfaceContainerHighest : null),
          border: terpilih ? Border.all(color: skema.primary) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$hari',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: terpilih ? FontWeight.w700 : FontWeight.w500)),
            const SizedBox(height: 3),
            if (daftar.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: daftar.take(3).map((t) {
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.lunas ? skema.outline : skema.error),
                  );
                }).toList(),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
