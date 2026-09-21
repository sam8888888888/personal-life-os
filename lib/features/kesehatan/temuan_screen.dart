/// FR-113 — Temuan & pola dari catatan kesehatan sendiri.
///
/// Isi: menghitung pola dari angka yang SUDAH dicatat pengguna (berat, tekanan
/// darah, tidur, air, suasana hati) dan menampilkannya sebagai bahan
/// pertimbangan. Bukan diagnosis, bukan nasihat medis — setiap temuan
/// menyertakan angka pendukungnya supaya bisa diperiksa sendiri.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/temuan_kesehatan.dart';
import '../../core/utils/waktu.dart';
import '../pengetahuan/komponen_pengetahuan.dart';
import '../pengetahuan/provider_pengetahuan.dart';
import 'kartu_bagian.dart';
import 'provider_kesehatan.dart';

class TemuanKesehatanScreen extends ConsumerStatefulWidget {
  const TemuanKesehatanScreen({super.key, this.jamSekarang});

  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<TemuanKesehatanScreen> createState() => _TemuanKesehatanScreenState();
}

class _TemuanKesehatanScreenState extends ConsumerState<TemuanKesehatanScreen> {
  bool _memuat = true;
  List<TemuanKesehatan> _temuan = const <TemuanKesehatan>[];
  int _titikData = 0;

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final sehat = ref.read(kesehatanRepoProvider);
    final ringkas = ref.read(kesehatanRingkasRepoProvider);
    final kini = _sekarang;
    try {
      final berat = await sehat.riwayatUkuran('berat', hari: 120, sampai: kini);
      final sistolik =
          await sehat.riwayatUkuran('sistolik', hari: 120, sampai: kini);
      final tidur = await sehat.riwayatTidur(hari: 30, sampai: kini);
      final air = await sehat.riwayatAirHarian(hari: 30, sampai: kini);
      final targetAir = await sehat.targetAirMl();
      final suasana = await ringkas.daftarSuasana(sampai: kini, hari: 60);

      final semuaTanggal = <DateTime>[
        ...berat.map((e) => e.tanggal),
        ...sistolik.map((e) => e.tanggal),
        ...tidur.map((e) => e.tanggal),
        ...air.where((e) => e.totalMl > 0).map((e) => e.tanggal),
        ...suasana.map((e) => e.waktu),
      ]..sort();

      final bahan = BahanTemuan(
        berat: [for (final b in berat) TitikAngka(b.nilai, b.tanggal)],
        sistolik: [for (final s in sistolik) TitikAngka(s.nilai, s.tanggal)],
        tidurJam: [
          for (final t in tidur) TitikHari(t.durasiMenit / 60, t.tanggal),
        ],
        airMl: [
          for (final a in air)
            if (a.totalMl > 0) TitikHari(a.totalMl.toDouble(), a.tanggal),
        ],
        targetAirMl: targetAir.toDouble(),
        suasana: [for (final s in suasana) TitikHari(s.skor.toDouble(), s.waktu)],
        menitAktivitas: const <TitikHari>[],
        obatTerlewatHari: 0,
        hariTerakhirCatat: semuaTanggal.isEmpty ? null : semuaTanggal.last,
      );
      final hasil = cariTemuan(bahan, acuan: kini);
      if (!mounted) return;
      setState(() {
        _temuan = hasil;
        _titikData = bahan.berat.length +
            bahan.sistolik.length +
            bahan.tidurJam.length +
            bahan.airMl.length +
            bahan.suasana.length;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _memuat = false);
    }
  }

  Color _warna(TingkatTemuan t) => switch (t) {
        TingkatTemuan.perhatikan => const Color(0xFFB5451B),
        TingkatTemuan.catat => const Color(0xFF3D6DB5),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Temuan dari catatan Anda')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                KartuBagian(
                  judul: 'Cara membaca halaman ini',
                  ikon: Icons.info_outline,
                  anak: [
                    Text('Temuan dihitung dari $_titikData angka yang Anda catat '
                        'sendiri (120 hari terakhir untuk berat & tekanan darah, '
                        '30 hari untuk tidur & air, 60 hari untuk suasana hati).'),
                    const SizedBox(height: 4),
                    const Text(
                      'Ini BUKAN diagnosis dan bukan nasihat medis. Angka '
                      'pendukung selalu ditampilkan supaya Anda bisa memeriksa '
                      'sendiri, dan keputusan tetap di tangan Anda.',
                    ),
                  ],
                ),
                if (_temuan.isEmpty)
                  kartuKosong('Belum ada pola yang perlu ditampilkan',
                      petunjuk: 'Makin banyak yang dicatat, makin banyak yang '
                          'bisa dihitung. Tidak ada temuan juga berarti tidak ada '
                          'yang menonjol dari catatan saat ini.')
                else
                  for (final t in _temuan)
                    Card(
                      key: Key('temuan_${t.jenis}_${t.judul}'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(t.judul,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ),
                                lencana(t.tingkat == TingkatTemuan.perhatikan
                                    ? 'perlu diperhatikan'
                                    : 'sekadar catatan'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(t.angka,
                                style: TextStyle(
                                    color: _warna(t.tingkat),
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(t.penjelasan),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}
