/// FR-58 — Layar Voice & Parsing Cerdas.
///
/// Satu kalimat (diucapkan atau ditulis) → DRAF → pengguna memeriksa →
/// baru disimpan. Untuk draf yang butuh banyak isian (dana persiapan &
/// perawatan) aplikasi mengarahkan ke layarnya, bukan menebak-nebak.
library;

import 'package:drift/drift.dart' show DoNothing, Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/parsing/parsing_cerdas.dart';
import '../../core/platform/kanal_media.dart' show KanalGagal;
import '../../core/platform/kanal_suara.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/tagihan_repository.dart';

class SuaraScreen extends ConsumerStatefulWidget {
  const SuaraScreen({super.key});

  @override
  ConsumerState<SuaraScreen> createState() => _SuaraScreenState();
}

class _SuaraScreenState extends ConsumerState<SuaraScreen> {
  final _kanal = KanalSuara();
  final _tulisan = TextEditingController();
  DrafHasil? _draf;
  bool _mendengar = false;
  String? _pesan;

  @override
  void dispose() {
    _tulisan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ucapkan atau tulis')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _tulisan,
                    maxLines: 2,
                    onChanged: (v) => _urai(v),
                    decoration: const InputDecoration(
                      labelText: 'Kalimat',
                      hintText: 'mis. beli galon 20 ribu',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _mendengar ? null : _dengar,
                        icon: _mendengar
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.mic),
                        label: const Text('Dengar'),
                      ),
                      TextButton(
                        onPressed: () {
                          _tulisan.clear();
                          setState(() => _draf = null);
                        },
                        child: const Text('Bersihkan'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in contohKalimat)
                        ActionChip(
                          label: Text(c, style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            _tulisan.text = c;
                            _urai(c);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(catatanKanalSuara,
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
          if (_pesan != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_pesan!, style: const TextStyle(fontSize: 12)),
            ),
          if (_draf != null) _kartuDraf(context, _draf!),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _kartuDraf(BuildContext context, DrafHasil d) {
    return Card(
      color: d.dikenali
          ? null
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.jenis.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(d.kalimat),
            if (d.dikenali)
              Text('Keyakinan ${d.tingkatKeyakinan}%',
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
            if (d.alasan.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('Yang masih perlu dilengkapi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              for (final a in d.alasan)
                Text('• $a', style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (drafSiapSimpan(d) &&
                    d.jenis == JenisDraf.pengeluaran)
                  FilledButton.icon(
                    onPressed: () => _simpanPengeluaran(d),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Simpan pengeluaran'),
                  ),
                if (drafSiapSimpan(d) && d.jenis == JenisDraf.tagihan)
                  FilledButton.icon(
                    onPressed: () => _simpanTagihan(d),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Simpan tagihan'),
                  ),
                if (d.jenis == JenisDraf.dana)
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: d.mentah));
                      context.push('/laporan/dana-persiapan');
                    },
                    icon: const Icon(Icons.savings_outlined),
                    label: const Text('Buka dana persiapan'),
                  ),
                if (d.jenis == JenisDraf.perawatan)
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: d.mentah));
                      context.push('/aksi/perawatan');
                    },
                    icon: const Icon(Icons.build_outlined),
                    label: const Text('Buka perawatan'),
                  ),
                TextButton.icon(
                  onPressed: (d.jenis == JenisDraf.tagihan ||
                          d.jenis == JenisDraf.pengeluaran)
                      ? () => context.push(d.jenis == JenisDraf.tagihan
                          ? '/tagihan'
                          : '/uang')
                      : null,
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Lihat daftarnya'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _urai(String teks) {
    setState(() {
      _draf = teks.trim().isEmpty ? null : uraikanKalimat(teks);
      _pesan = null;
    });
  }

  Future<void> _dengar() async {
    setState(() => _mendengar = true);
    try {
      final tersedia = await _kanal.tersedia();
      if (!tersedia) {
        _kabar('Perangkat ini belum bisa mengenali suara lewat aplikasi. '
            'Silakan tuliskan kalimatnya.');
        return;
      }
      final hasil = await _kanal.dengar();
      if (!hasil.ada) {
        _kabar('Suara tidak terbaca. Coba lagi atau tuliskan kalimatnya.');
        return;
      }
      _tulisan.text = hasil.teks;
      _urai(hasil.teks);
      if (hasil.alternatif.length > 1) {
        _kabar('Kalau hasilnya kurang tepat, coba salah satu alternatif: '
            '${hasil.alternatif.skip(1).join(' / ')}');
      }
    } on KanalGagal catch (e) {
      _kabar(e.pesan);
    } catch (e) {
      _kabar('Pengenalan suara gagal: $e');
    } finally {
      if (mounted) setState(() => _mendengar = false);
    }
  }

  void _kabar(String teks) {
    if (!mounted) return;
    setState(() => _pesan = teks);
  }

  Future<void> _simpanPengeluaran(DrafHasil d) async {
    final nominal = d.nominalSen!;
    final waktu = d.tanggal ?? DateTime.now();
    final db = ref.read(databaseProvider);
    final idTransaksi = 'suara-${waktu.millisecondsSinceEpoch}-$nominal';
    await db.into(db.transaksi).insert(
          TransaksiCompanion.insert(
            idTransaksi: idTransaksi,
            jenis: const Value('pengeluaran'),
            tanggal: DateTime(waktu.year, waktu.month, waktu.day),
            jumlahSen: nominal,
            catatan: Value(d.judul.trim().isEmpty ? d.mentah : d.judul.trim()),
            sumber: const Value('suara'),
          ),
          onConflict: DoNothing(),
        );
    _kabar('Pengeluaran ${fmtRpDariSen(nominal)} disimpan.');
    setState(() => _draf = null);
    _tulisan.clear();
  }

  Future<void> _simpanTagihan(DrafHasil d) async {
    final repo = TagihanRepository(ref.read(databaseProvider));
    await repo.tambah(TagihanCompanion.insert(
          nama: d.judul.trim().isEmpty ? d.mentah : d.judul.trim(),
          jatuhTempo: d.tanggal!,
          jumlahSen: Value(d.nominalSen),
          catatan: const Value('Dibuat dari kalimat suara'),
        ));
    _kabar('Tagihan disimpan dengan jatuh tempo '
        '${d.tanggal!.day}/${d.tanggal!.month}/${d.tanggal!.year}.');
    setState(() => _draf = null);
    _tulisan.clear();
  }
}
