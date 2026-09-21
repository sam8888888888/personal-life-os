/// FR-34 — Layar Kalkulator Denda Terhindarkan.
///
/// Menampilkan berapa denda/bunga yang TIDAK jadi keluar karena tagihan
/// dibayar tepat waktu, plus tempat mengatur aturan denda tiap tagihan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/denda_terhindarkan.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';

class DendaTerhindarkanScreen extends ConsumerStatefulWidget {
  const DendaTerhindarkanScreen({super.key, this.acuan});

  final DateTime? acuan;

  @override
  ConsumerState<DendaTerhindarkanScreen> createState() =>
      _DendaTerhindarkanScreenState();
}

class _DendaTerhindarkanScreenState
    extends ConsumerState<DendaTerhindarkanScreen> {
  bool _memuat = true;
  HasilDendaTerhindarkan? _hasil;
  Map<String, AturanDenda> _aturan = const {};
  List<String> _namaTagihan = const [];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final pengaturan = ref.read(pengaturanRepoProvider);
    final tagihan = await ref.read(tagihanRepoProvider).ambilSemua();
    final riwayat = await ref.read(tagihanRepoProvider).riwayatUntukEkspor();

    final nama = tagihan.map((t) => t.nama).toSet().toList()..sort();
    final aturan = <String, AturanDenda>{};
    for (final n in nama) {
      final teks = await pengaturan.baca(kunciAturanDenda(n));
      final a = teksKeAturan(teks);
      if (a != null) aturan[n] = a;
    }

    final hasil = hitungDendaTerhindarkan(
      riwayat: riwayat
          .map((r) => (
                nama: r.namaTagihan,
                tanggalBayar: r.tanggalBayar,
                nominalSen: r.jumlahSen,
                tepatWaktu: (r.telatHari ?? 0) <= 0,
              ))
          .toList(),
      aturan: aturan,
      semuaNamaTagihan: nama,
      acuan: widget.acuan,
    );

    if (!mounted) return;
    setState(() {
      _aturan = aturan;
      _namaTagihan = nama;
      _hasil = hasil;
      _memuat = false;
    });
  }

  Future<void> _aturDenda(String namaTagihan) async {
    final lama = _aturan[namaTagihan];
    final kendaliPersen = TextEditingController(
        text: (lama?.persenPerBulan ?? 0) == 0 ? '' : '${lama!.persenPerBulan}');
    final kendaliNominal = TextEditingController(
        text: (lama?.nominalSen ?? 0) == 0
            ? ''
            : fmtRpDariSen(lama!.nominalSen));
    String? galat;

    final simpan = await showDialog<bool>(
      context: context,
      builder: (konteks) => StatefulBuilder(
        builder: (konteks, set) => AlertDialog(
          title: Text('Denda $namaTagihan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Isi salah satu atau keduanya. Kalau keduanya diisi, dipakai '
                'yang lebih besar (denda minimum seperti di bank).',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('denda_persen'),
                controller: kendaliPersen,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Denda persen per bulan (%)',
                  hintText: 'contoh: 2',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('denda_nominal'),
                controller: kendaliNominal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Denda nominal tetap (Rp)',
                  hintText: 'contoh: 25000',
                ),
              ),
              if (galat != null) ...[
                const SizedBox(height: 8),
                Text(galat!,
                    style: TextStyle(color: Theme.of(konteks).colorScheme.error)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(konteks).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              key: const Key('simpan_denda'),
              onPressed: () {
                if (kendaliPersen.text.trim().isEmpty &&
                    kendaliNominal.text.trim().isEmpty) {
                  set(() => galat = 'Isi minimal salah satu.');
                  return;
                }
                Navigator.of(konteks).pop(true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (simpan != true) return;
    final persen = int.tryParse(kendaliPersen.text.trim()) ?? 0;
    final nominal = kendaliNominal.text.trim().isEmpty
        ? 0
        : rupiahKeSen(parseRupiah(kendaliNominal.text) ?? 0);
    // Dicatat per HARI (bukan jam-menit): denda dihitung mulai hari aturan
    // dibuat, jadi pelunasan hari ini tetap ikut terhitung.
    final kini = DateTime.now();
    final aturan = AturanDenda(
      persenPerBulan: persen,
      nominalSen: nominal,
      ditetapkanPada: DateTime(kini.year, kini.month, kini.day),
    );
    await ref
        .read(pengaturanRepoProvider)
        .simpan(kunciAturanDenda(namaTagihan), aturanKeTeks(aturan));
    if (!mounted) return;
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final h = _hasil!;
    return Scaffold(
      appBar: AppBar(title: const Text('Denda terhindarkan')),
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
                  Text('Uang yang tidak jadi keluar',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    fmtRpDariSen(h.totalSen),
                    key: const Key('denda_total'),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  Text('dari ${h.daftar.length} pelunasan tepat waktu'),
                  const Divider(height: 24),
                  Text('Bulan ini: ${fmtRpDariSen(h.bulanIniSen)}',
                      key: const Key('denda_bulan_ini')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (h.daftar.isNotEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final d in h.daftar)
                    ListTile(
                      key: Key('denda_hemat_${d.namaTagihan}-${d.tanggalBayar.day}'),
                      leading: const Icon(Icons.savings_outlined),
                      title: Text(d.namaTagihan),
                      subtitle: Text('Dibayar ${fmtTanggalAman(d.tanggalBayar)} · '
                          'nominal ${fmtRpDariSen(d.nominalSen)}'),
                      trailing: Text('+${fmtRpDariSen(d.dendaTerhindarSen)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Atur denda per tagihan',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text(
                    'Angka di atas hanya menghitung tagihan yang sudah punya '
                    'aturan denda. Tagihan lain ditampilkan "belum diatur".',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (_namaTagihan.isEmpty)
                    const Text('Belum ada tagihan.')
                  else
                    for (final n in _namaTagihan)
                      ListTile(
                        key: Key('atur_denda_$n'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(n),
                        subtitle: Text(_aturan[n]?.ada ?? false
                            ? '${_aturan[n]!.persenPerBulan}% per bulan'
                                '${_aturan[n]!.nominalSen > 0 ? " · min ${fmtRpDariSen(_aturan[n]!.nominalSen)}" : ""}'
                            : 'Belum diatur'),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _aturDenda(n),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Perkiraan ini alat bantu hitung, bukan tagihan resmi. Besaran denda '
            'yang sebenarnya mengikuti perjanjian dengan bank/penyedia layanan.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
