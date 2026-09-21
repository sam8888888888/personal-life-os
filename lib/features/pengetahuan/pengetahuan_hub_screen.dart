/// Hub modul Pengetahuan (FR-118…FR-123).
///
/// Pintu masuk: ringkasan singkat tiap bagian + tombol menuju layarnya.
/// Semua angka di sini berasal dari catatan pengguna sendiri.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/laporan/pengetahuan_ringkas.dart';
import '../../core/laporan/ulangan_berkala.dart';
import '../../core/utils/waktu.dart';
import '../kesehatan/kartu_bagian.dart';
import 'provider_pengetahuan.dart';

class PengetahuanHubScreen extends ConsumerStatefulWidget {
  const PengetahuanHubScreen({super.key, this.jamSekarang});

  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<PengetahuanHubScreen> createState() =>
      _PengetahuanHubScreenState();
}

class _PengetahuanHubScreenState extends ConsumerState<PengetahuanHubScreen> {
  bool _memuat = true;
  RingkasCatatan? _catatan;
  RingkasKeputusan? _keputusan;
  RingkasUlangan? _ulangan;
  RingkasBacaan? _bacaan;
  RingkasPembelajaran? _belajar;
  int _jumlahTautan = 0;

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final repo = ref.read(pengetahuanRepoProvider);
    final kini = _sekarang;
    try {
      final catatan = await repo.daftarCatatan(termasukArsip: true);
      final keputusan = await repo.daftarKeputusan();
      final kartu = await repo.daftarKartu();
      final bacaan = await repo.daftarBacaan();
      final belajar = await repo.daftarPembelajaran();
      final tautan = await repo.daftarTautan();
      if (!mounted) return;
      setState(() {
        _catatan = ringkasCatatan(catatan);
        _keputusan = ringkasKeputusan(keputusan, acuan: kini);
        _ulangan = ringkasUlangan(kartu, acuan: kini);
        _bacaan = ringkasBacaan(bacaan, acuan: kini);
        _belajar = ringkasPembelajaran(belajar, acuan: kini);
        _jumlahTautan = tautan.length;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _memuat = false);
    }
  }

  Widget _tombol(BuildContext c, String judul, String keterangan, String rute) => Card(
        child: ListTile(
          key: Key('pengetahuan_$rute'),
          title: Text(judul, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(keterangan),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => c.push(rute),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final catatan = _catatan;
    final keputusan = _keputusan;
    final ulangan = _ulangan;
    final bacaan = _bacaan;
    final belajar = _belajar;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengetahuan')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                KartuBagian(
                  judul: 'Catatan & ide',
                  ikon: Icons.sticky_note_2_outlined,
                  anak: [Text('${catatan?.total ?? 0} catatan · '
                      '${catatan?.jumlahDisematkan ?? 0} disematkan · '
                      '${catatan?.jumlahDiarsipkan ?? 0} diarsipkan')],
                ),
                KartuBagian(
                  judul: 'Jurnal keputusan',
                  ikon: Icons.account_tree_outlined,
                  anak: [Text('${keputusan?.total ?? 0} keputusan · '
                      '${keputusan?.menungguTinjauan ?? 0} siap ditinjau')],
                ),
                KartuBagian(
                  judul: 'Kartu ulangan',
                  ikon: Icons.style_outlined,
                  anak: [Text('${ulangan?.total ?? 0} kartu · '
                      '${ulangan?.jatuhTempo ?? 0} siap diulang hari ini')],
                ),
                KartuBagian(
                  judul: 'Buku & bacaan',
                  ikon: Icons.menu_book_outlined,
                  anak: [Text('${bacaan?.sedangDibaca.length ?? 0} sedang dibaca · '
                      '${bacaan?.selesaiTahunIni ?? 0} selesai tahun ini')],
                ),
                KartuBagian(
                  judul: 'Pembelajaran',
                  ikon: Icons.school_outlined,
                  anak: [
                    Text('${belajar?.menitRentang ?? 0} menit 7 hari terakhir · '
                        'topik terbanyak: '
                        '${belajar?.topikTeratas ?? 'belum ada'}'),
                  ],
                ),
                KartuBagian(
                  judul: 'Penghubung pengetahuan',
                  ikon: Icons.hub_outlined,
                  anak: [Text('$_jumlahTautan tautan antar butir')],
                ),
                const SizedBox(height: 8),
                _tombol(context, 'Catatan & ide',
                    'Tulis gagasan, rencana, kutipan, pelajaran', '/pengetahuan/catatan'),
                _tombol(context, 'Jurnal keputusan',
                    'Catat keputusan & tinjau hasilnya', '/pengetahuan/keputusan'),
                _tombol(context, 'Kartu ulangan',
                    'Pengulangan berkala dengan jadwal dari jawaban Anda',
                    '/pengetahuan/ulangan'),
                _tombol(context, 'Buku & bacaan',
                    'Halaman terbaca, status, dan penilaian sendiri',
                    '/pengetahuan/bacaan'),
                _tombol(context, 'Pembelajaran',
                    'Topik, sumber, dan menit belajar', '/pengetahuan/pembelajaran'),
                _tombol(context, 'Penghubung pengetahuan',
                    'Tautkan catatan ↔ keputusan ↔ bacaan ↔ kartu',
                    '/pengetahuan/tautan'),
              ],
            ),
    );
  }
}
