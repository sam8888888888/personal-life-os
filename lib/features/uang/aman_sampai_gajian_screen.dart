/// FR-33 — Layar "Uang aman sampai gajian".
///
/// Pengguna mengisi tanggal gajian dan (opsional) saldo sekarang; aplikasi
/// menghitung tagihan & langganan yang jatuh tempo sampai gajian berikutnya,
/// lalu menampilkan sisanya. Semua data tetap di HP.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/aman_sampai_gajian.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';

const String kunciTanggalGajian = 'gajian_tanggal';
const String kunciSaldoSekarang = 'saldo_sekarang_sen';

class AmanSampaiGajianScreen extends ConsumerStatefulWidget {
  const AmanSampaiGajianScreen({super.key, this.hariIni});

  /// Acuan "hari ini" (boleh disuntik saat uji).
  final DateTime? hariIni;

  @override
  ConsumerState<AmanSampaiGajianScreen> createState() =>
      _AmanSampaiGajianScreenState();
}

class _AmanSampaiGajianScreenState
    extends ConsumerState<AmanSampaiGajianScreen> {
  bool _memuat = true;
  int _tanggalGajian = 25;
  int? _saldoSen;
  HasilAmanGajian? _hasil;
  final TextEditingController _kendaliSaldo = TextEditingController();
  String? _galatSaldo;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _kendaliSaldo.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    final pengaturan = ref.read(pengaturanRepoProvider);
    final tglTeks = await pengaturan.baca(kunciTanggalGajian);
    _tanggalGajian = int.tryParse(tglTeks ?? '') ?? 25;
    _tanggalGajian = _tanggalGajian.clamp(1, 31);
    final saldoTeks = await pengaturan.baca(kunciSaldoSekarang);
    _saldoSen = int.tryParse(saldoTeks ?? '');
    if (_saldoSen != null) {
      _kendaliSaldo.text = fmtRpDariSen(_saldoSen!);
    }
    await _hitung();
    if (!mounted) return;
    setState(() => _memuat = false);
  }

  Future<void> _hitung() async {
    final db = ref.read(databaseProvider);
    final tagihan = await ref.read(tagihanRepoProvider).ambilSemua();
    final langganan = await db.select(db.langganan).get();
    final hasil = hitungAmanSampaiGajian(
      tagihan: tagihan,
      langganan: langganan,
      hariIni: widget.hariIni ?? DateTime.now(),
      tanggalGajian: _tanggalGajian,
      saldoSen: _saldoSen,
    );
    if (!mounted) return;
    setState(() => _hasil = hasil);
  }

  Future<void> _simpan() async {
    final teks = _kendaliSaldo.text.trim();
    int? sen;
    if (teks.isNotEmpty) {
      final angka = parseRupiah(teks);
      if (angka == null) {
        setState(() => _galatSaldo = 'Angka saldo belum bisa dibaca. '
            'Contoh: 2500000 atau 2.500.000');
        return;
      }
      sen = rupiahKeSen(angka);
    }
    final pengaturan = ref.read(pengaturanRepoProvider);
    await pengaturan.simpan(kunciTanggalGajian, '$_tanggalGajian');
    if (sen == null) {
      await pengaturan.hapusPengaturan(kunciSaldoSekarang);
    } else {
      await pengaturan.simpan(kunciSaldoSekarang, '$sen');
    }
    if (!mounted) return;
    setState(() {
      _saldoSen = sen;
      _galatSaldo = null;
    });
    await _hitung();
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final h = _hasil!;
    return Scaffold(
      appBar: AppBar(title: const Text('Uang aman sampai gajian')),
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
                  Text('Pengaturan', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Text('Tanggal gajian tiap bulan')),
                      DropdownButton<int>(
                        key: const Key('pilih_tanggal_gajian'),
                        value: _tanggalGajian,
                        items: [
                          for (var i = 1; i <= 31; i++)
                            DropdownMenuItem(value: i, child: Text('$i')),
                        ],
                        onChanged: (v) => setState(() => _tanggalGajian = v!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('input_saldo'),
                    controller: _kendaliSaldo,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Saldo sekarang (opsional)',
                      helperText: 'Contoh: 2500000',
                      errorText: _galatSaldo,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('simpan_pengaturan_gajian'),
                    onPressed: _simpan,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Simpan & hitung'),
                  ),
                ],
              ),
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
                  Text('Sampai gajian berikutnya',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${fmtTanggalAman(h.hariIni)} → ${fmtTanggalAman(h.tanggalGajian)} '
                    '(${h.hariKeGajian} hari lagi)',
                    key: const Key('gajian_rentang'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    fmtRpDariSen(h.totalSen),
                    key: const Key('gajian_total'),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  Text('untuk ${h.jumlahButir} tagihan/langganan'),
                  if (h.saldoSen == null) ...[
                    const Divider(height: 24),
                    const Text('Isi saldo sekarang di atas untuk melihat '
                        'sisa uang setelah tagihan dibayar.'),
                  ] else ...[
                    const Divider(height: 24),
                    Text(
                      h.sisaSen! < 0
                          ? 'Kurang ${fmtRpDariSen(-h.sisaSen!)} '
                              'dari saldo yang diisi'
                          : 'Sisa ${fmtRpDariSen(h.sisaSen!)} setelah tagihan dibayar',
                      key: const Key('gajian_sisa'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: h.sisaSen! < 0
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (h.butir.isEmpty)
            const Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Tidak ada tagihan yang jatuh tempo sampai gajian.'),
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final b in h.butir)
                    ListTile(
                      key: Key('gajian_butir_${b.nama}-${b.tanggal.day}'),
                      leading: Icon(b.sudahLewat
                          ? Icons.error_outline
                          : (b.langganan
                              ? Icons.autorenew
                              : Icons.receipt_long_outlined)),
                      title: Text(b.nama),
                      subtitle: Text(b.sudahLewat
                          ? 'Sudah lewat jatuh tempo (${fmtTanggalAman(b.tanggal)})'
                          : fmtTanggalAman(b.tanggal)),
                      trailing: Text(fmtRpDariSen(b.jumlahSen)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Perkiraan ini memakai tagihan aktif & langganan yang sedang '
            'berjalan di HP ini. Kalau tanggal gajian jatuh pada tanggal 29–31 '
            'dan bulan berjalan lebih pendek, aplikasi memakai hari terakhir bulan.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
