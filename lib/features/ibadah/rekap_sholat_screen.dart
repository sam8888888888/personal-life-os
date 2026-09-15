/// Layar Riwayat & konsistensi sholat (FR-89).
///
/// ATURAN III-11: layar ini TIDAK menilai ibadah. Tidak ada skor, nilai,
/// peringkat, pujian, atau hukuman — hanya "tercatat"/"belum tercatat".
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/ibadah/model_log_sholat.dart';
import '../../core/ibadah/model_sholat.dart';
import '../../core/ibadah/penyimpanan_log_sholat.dart';
import '../../core/ibadah/rekap_sholat.dart';
import '../../core/utils/waktu.dart';

/// Bentuk ringkas untuk label rentang, mis. "1 Sep".
final DateFormat _fmtRentang = DateFormat('d MMM', 'id_ID');

class RekapSholatScreen extends StatefulWidget {
  const RekapSholatScreen({super.key, this.penyimpananLog, this.jamSekarang});

  /// Penyimpanan log sholat; bisa diganti saat diuji.
  final PenyimpananLogSholat? penyimpananLog;

  /// Sumber waktu (tanggal sipil). Bawaan: satu sumber waktu aplikasi.
  final DateTime Function()? jamSekarang;

  @override
  State<RekapSholatScreen> createState() => _StateRekapSholat();
}

class _StateRekapSholat extends State<RekapSholatScreen> {
  late final PenyimpananLogSholat _simpan =
      widget.penyimpananLog ?? PenyimpananLogSholat();
  late final DateTime Function() _jam =
      widget.jamSekarang ?? (() => waktuSekarang());

  int _hari = 7;
  bool _memuat = true;
  RekapSholat? _rekap;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final List<String> kunci =
        RekapSholat.rentangTanggal(_jam(), jumlahHari: _hari);
    Map<String, CatatanSholat> data = <String, CatatanSholat>{};
    try {
      // Batas waktu: bila penyimpanan tidak menjawab (mis. izin berkas
      // bermasalah), layar menampilkan "belum ada catatan" — bukan berputar
      // tanpa henti.
      data = await _simpan
          .ambilRentang(kunci.first, kunci.last)
          .timeout(const Duration(seconds: 4),
              onTimeout: () => <String, CatatanSholat>{});
    } catch (_) {
      data = <String, CatatanSholat>{};
    }
    if (!mounted) return;
    setState(() {
      _rekap = RekapSholat.hitung(tanggal: kunci, catatan: data);
      _memuat = false;
    });
  }

  void _ubahHari(int hari) {
    if (hari == _hari) return;
    setState(() => _hari = hari);
    _muat();
  }

  @override
  Widget build(BuildContext context) {
    final bool adaCatatan = (_rekap?.totalTercatat ?? 0) > 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat sholat')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ChoiceChip(
                      key: const Key('pilih_7'),
                      label: const Text('7 hari'),
                      selected: _hari == 7,
                      onSelected: (_) => _ubahHari(7),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      key: const Key('pilih_30'),
                      label: const Text('30 hari'),
                      selected: _hari == 30,
                      onSelected: (_) => _ubahHari(30),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _rentangTeks(),
                          key: const Key('rentang_rekap'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _rekap?.kalimatTotal ?? 'Belum ada data',
                          key: const Key('total_rekap'),
                        ),
                        const SizedBox(height: 6),
                        const Text('Catatan pribadi Anda — hanya rekap apa yang '
                            'Anda tandai, bukan penilaian ibadah.'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!adaCatatan)
                  const Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Belum ada catatan pada rentang ini'),
                    ),
                  )
                else
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        for (final WaktuSholat w in WaktuSholat.wajibSaja)
                          _barisWaktu(w),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Text('Tiap hari', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (int i = 0;
                        i < (_rekap?.tanggal.length ?? 0);
                        i++)
                      Tooltip(
                        message: _rekap!.tanggal[i],
                        child: Chip(
                          key: Key('hari_${_rekap!.tanggal[i]}'),
                          label: Text('${_rekap!.jumlahHariKe(i)}/5'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Belum tercatat bukan berarti tidak dikerjakan — hanya berarti '
                  'tidak ditandai di aplikasi.',
                ),
              ],
            ),
    );
  }

  String _rentangTeks() {
    final RekapSholat? r = _rekap;
    if (r == null || r.tanggal.isEmpty) return 'Belum ada data';
    final DateTime? a = tanggalDariKunci(r.tanggal.first);
    final DateTime? b = tanggalDariKunci(r.tanggal.last);
    if (a == null || b == null) return 'Belum ada data';
    return '${_fmtRentang.format(a)} – ${_fmtRentang.format(b)}';
  }

  Widget _barisWaktu(WaktuSholat w) {
    final RekapWaktu? r = _rekap?.rekapWaktu(w);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  w.label,
                  key: Key('rekap_${w.name}'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(r?.kalimat ?? 'Belum ada data'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: r?.bagian ?? 0),
        ],
      ),
    );
  }
}
