/// FR-116 — Laporan kesehatan bulanan.
///
/// Isi: ringkasan satu bulan dari catatan sendiri (berat, tekanan darah, tidur,
/// air, aktivitas, suasana hati, makan), plus tombol menyalin teksnya.
/// Semua bagian menyebutkan berapa data yang jadi dasar hitungannya.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/laporan_kesehatan_bulanan.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import '../pengetahuan/komponen_pengetahuan.dart';
import '../pengetahuan/provider_pengetahuan.dart';
import 'kartu_bagian.dart';
import 'provider_kesehatan.dart';

class LaporanKesehatanBulananScreen extends ConsumerStatefulWidget {
  const LaporanKesehatanBulananScreen({super.key, this.jamSekarang});

  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<LaporanKesehatanBulananScreen> createState() =>
      _LaporanKesehatanBulananScreenState();
}

class _LaporanKesehatanBulananScreenState extends ConsumerState<LaporanKesehatanBulananScreen> {
  bool _memuat = true;
  DateTime _bulan = DateTime(2000, 1);
  List<DateTime> _pilihan = const <DateTime>[];
  LaporanKesehatanBulanan? _laporan;

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _muat(awal: true);
  }

  Future<void> _muat({bool awal = false}) async {
    final sehat = ref.read(kesehatanRepoProvider);
    final ringkas = ref.read(kesehatanRingkasRepoProvider);
    final kini = _sekarang;
    try {
      final berat = await sehat.riwayatUkuran('berat', hari: 400, sampai: kini);
      final sistolik =
          await sehat.riwayatUkuran('sistolik', hari: 400, sampai: kini);
      final tidur = await sehat.riwayatTidur(hari: 400, sampai: kini);
      final air = await sehat.riwayatAirHarian(hari: 400, sampai: kini);
      final makan = await ringkas.daftarMakan(sampai: kini, hari: 400);
      final suasana = await ringkas.daftarSuasana(sampai: kini, hari: 400);
      final targetAir = await sehat.targetAirMl();

      final semuaHari = <DateTime>[
        ...berat.map((e) => e.tanggal),
        ...sistolik.map((e) => e.tanggal),
        ...tidur.map((e) => e.tanggal),
        ...air.where((e) => e.totalMl > 0).map((e) => e.tanggal),
        ...makan.map((e) => e.waktu),
        ...suasana.map((e) => e.waktu),
      ];
      final tersedia = bulanTersedia(semuaHari);
      final bulan = awal || _bulan.year == 2000
          ? (tersedia.isEmpty ? DateTime(kini.year, kini.month) : tersedia.first)
          : _bulan;

      final dalamBulan = <DateTime>[
        ...berat.map((e) => e.tanggal),
        ...sistolik.map((e) => e.tanggal),
        ...tidur.map((e) => e.tanggal),
        ...air.where((e) => e.totalMl > 0).map((e) => e.tanggal),
        ...makan.map((e) => e.waktu),
        ...suasana.map((e) => e.waktu),
      ].where((d) => d.year == bulan.year && d.month == bulan.month).length;

      final laporan = susunLaporanBulanan(
        BahanLaporanBulanan(
          bulan: bulan,
          berat: [for (final b in berat) TitikBulanan(b.tanggal, b.nilai)],
          sistolik: [for (final s in sistolik) TitikBulanan(s.tanggal, s.nilai)],
          tidurJam: [
            for (final t in tidur) TitikBulanan(t.tanggal, t.durasiMenit / 60),
          ],
          airMl: [
            for (final a in air)
              if (a.totalMl > 0) TitikBulanan(a.tanggal, a.totalMl.toDouble()),
          ],
          menitAktivitas: const <TitikBulanan>[],
          suasana: [
            for (final s in suasana) TitikBulanan(s.waktu, s.skor.toDouble()),
          ],
          jumlahCatatanMakan: makan
              .where((m) => m.waktu.year == bulan.year && m.waktu.month == bulan.month)
              .length,
          jumlahCatatanKesehatan: dalamBulan,
          jumlahJanji: 0,
          jumlahHariMinumObat: 0,
          targetAirMl: targetAir.toDouble(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _pilihan = tersedia;
        _bulan = bulan;
        _laporan = laporan;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _memuat = false);
    }
  }

  String _teksLengkap(LaporanKesehatanBulanan l) {
    final b = StringBuffer();
    b.writeln('Laporan kesehatan ${l.judulBulan}');
    b.writeln('Hari ada catatan: ${l.hariAdaCatatan} dari ${l.jumlahHari}');
    for (final bagian in l.bagian) {
      b.writeln('');
      b.writeln('${bagian.judul} (${bagian.jumlahData} data)');
      for (final baris in bagian.baris) {
        b.writeln('- $baris');
      }
    }
    b.writeln('');
    b.writeln('Catatan: laporan ini dihitung dari apa yang saya catat sendiri, '
        'bukan hasil pemeriksaan medis.');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l = _laporan;
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan bulanan')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_pilihan.isNotEmpty)
                  KartuBagian(
                    judul: 'Pilih bulan',
                    ikon: Icons.calendar_month_outlined,
                    anak: [
                      DropdownButtonFormField<DateTime>(
                        key: const Key('pilih_bulan'),
                        initialValue: _bulan,
                        items: [
                          for (final b in _pilihan)
                            DropdownMenuItem(
                              value: b,
                              child: Text(fmtBulanAman(b)),
                            ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _bulan = v);
                          _muat();
                        },
                      ),
                    ],
                  ),
                if (l == null)
                  kartuKosong('Belum ada catatan',
                      petunjuk: 'Laporan dibentuk dari catatan kesehatan Anda. '
                          'Mulai catat berat, tidur, air, atau suasana hati.')
                else ...[
                  KartuBagian(
                    judul: l.judulBulan,
                    ikon: Icons.summarize_outlined,
                    anak: [
                      Text('Hari ada catatan: ${l.hariAdaCatatan} '
                          'dari ${l.jumlahHari} hari'),
                      const SizedBox(height: 4),
                      const Text('Angka di bawah ini dihitung dari catatan '
                          'Anda sendiri — bukan hasil pemeriksaan medis.'),
                    ],
                  ),
                  for (final bagian in l.bagian)
                    Card(
                      key: Key('bagian_${bagian.judul}'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bagian.judul,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text('${bagian.jumlahData} data'),
                            const SizedBox(height: 6),
                            for (final baris in bagian.baris) Text('• $baris'),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('salin_laporan_bulanan'),
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: _teksLengkap(l)));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Teks laporan disalin'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Salin teks laporan'),
                  ),
                ],
              ],
            ),
    );
  }
}
