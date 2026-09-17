/// Kartu ibadah pagi untuk Briefing Pagi Islami (FR-99).
///
/// Isi kartu: target Quran hari ini beserta progresnya (FR-93) dan daftar
/// adhkar pagi yang bisa ditandai selesai (FR-95). Semua angka berasal dari
/// tabel ibadah lanjutan; kartu ini TIDAK menetapkan kewajiban apa pun, tidak
/// memberi nilai, dan tidak menyimpan data baru selain tanda selesai yang
/// ditekan pengguna sendiri.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repository/ibadah_lanjutan_repository.dart';
import '../ibadah/ibadah_lanjutan_provider.dart';

/// Satu butir adhkar pagi: nama dan hitungan bawaannya.
class AdhkarPagi {
  const AdhkarPagi(this.nama, this.target);

  final String nama;
  final int target;

  /// Kunci stabil untuk uji (`adhkar_<slug>`).
  String get slug => nama.toLowerCase().replaceAll(' ', '_');
}

/// Daftar adhkar pagi ringkas. Sengaja pendek: hanya yang paling dikenal dan
/// tidak memerlukan teks Arab panjang (aplikasi tidak memuat mushaf).
const List<AdhkarPagi> adhkarPagi = <AdhkarPagi>[
  AdhkarPagi('Ayat Kursi', 1),
  AdhkarPagi('Subhanallah', 33),
  AdhkarPagi('Alhamdulillah', 33),
  AdhkarPagi('Allahu Akbar', 33),
];

/// Batas waktu baca setelan & basis data (aturan platform: selalu ada batas).
const Duration batasBacaIbadahPagi = Duration(seconds: 5);

/// Keadaan kartu yang sudah dimuat.
class DataIbadahPagi {
  const DataIbadahPagi({
    required this.targetQuran,
    required this.satuanQuran,
    required this.jumlahQuran,
    required this.tercatat,
  });

  const DataIbadahPagi.kosong()
      : targetQuran = 0,
        satuanQuran = SatuanQuran.halaman,
        jumlahQuran = 0,
        tercatat = const <String, int>{};

  final double targetQuran;
  final SatuanQuran satuanQuran;
  final double jumlahQuran;

  /// Nama adhkar -> hitungan hari ini.
  final Map<String, int> tercatat;

  bool selesai(String nama) => (tercatat[nama] ?? 0) > 0;
}

/// Kartu ibadah pagi (FR-99). [sekarang] = tanggal sipil perangkat.
class KartuIbadahPagi extends ConsumerStatefulWidget {
  const KartuIbadahPagi({super.key, required this.sekarang});

  final DateTime sekarang;

  @override
  ConsumerState<KartuIbadahPagi> createState() => KartuIbadahPagiState();
}

class KartuIbadahPagiState extends ConsumerState<KartuIbadahPagi> {
  DataIbadahPagi isi = const DataIbadahPagi.kosong();
  bool memuat = true;
  String? galat;

  DateTime get _awalHari =>
      DateTime(widget.sekarang.year, widget.sekarang.month, widget.sekarang.day);

  @override
  void initState() {
    super.initState();
    muat();
  }

  /// Muat target & hitungan hari ini. Bila gagal, kartu menampilkan keterangan
  /// jujur dan tidak menghentikan briefing.
  Future<void> muat() async {
    try {
      final data = await _baca().timeout(batasBacaIbadahPagi);
      if (!mounted) return;
      setState(() {
        isi = data;
        memuat = false;
        galat = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isi = const DataIbadahPagi.kosong();
        memuat = false;
        galat = 'Tidak bisa membaca catatan ibadah: $e';
      });
    }
  }

  Future<DataIbadahPagi> _baca() async {
    final repo = ref.read(ibadahLanjutanRepoProvider);
    final setelan = ref.read(setelanIbadahLanjutanProvider);
    final targetQuran = await setelan.targetQuranHarian();
    final satuan = await setelan.satuanQuran();
    final barisQuran =
        await repo.quranRentang(_awalHari, _awalHari.add(const Duration(days: 1)));
    final barisDzikir = await repo.dzikirRentang(
        _awalHari, _awalHari.add(const Duration(days: 1)));
    final tercatat = <String, int>{};
    for (final b in barisDzikir) {
      if (b.jenis == JenisDzikir.pagi.nilaiDb) tercatat[b.nama] = b.tercatat;
    }
    double jumlah = 0;
    for (final b in barisQuran) {
      if (b.satuan == satuan.nilaiDb) jumlah += b.jumlah;
    }
    return DataIbadahPagi(
      targetQuran: targetQuran,
      satuanQuran: satuan,
      jumlahQuran: jumlah,
      tercatat: tercatat,
    );
  }

  /// Tandai satu adhkar selesai / batal. Satu tulisan basis data per ketukan.
  Future<void> tandai(AdhkarPagi butir, bool selesai) async {
    final repo = ref.read(ibadahLanjutanRepoProvider);
    await repo.catatDzikir(
      tanggal: _awalHari,
      jenis: JenisDzikir.pagi,
      nama: butir.nama,
      target: butir.target,
      tercatat: selesai ? butir.target : 0,
    );
    await muat();
  }

  static String _teksAngka(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_outlined, size: 18),
                const SizedBox(width: 8),
                Text('Ibadah pagi', style: tema.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 6),
            if (galat != null)
              Text(galat!, key: const ValueKey('ibadah_pagi_galat'),
                  style: tema.textTheme.bodySmall)
            else if (memuat)
              const Text('Memuat catatan ibadah…')
            else ...[
              Text(
                'Quran hari ini: ${_teksAngka(isi.jumlahQuran)} '
                '${isi.satuanQuran.label} dari target '
                '${_teksAngka(isi.targetQuran)} ${isi.satuanQuran.label}',
                key: const ValueKey('quran_progres'),
                style: tema.textTheme.bodyMedium,
              ),
              if (isi.targetQuran > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(
                    key: const ValueKey('quran_bilah'),
                    value: (isi.jumlahQuran / isi.targetQuran).clamp(0.0, 1.0),
                  ),
                ),
              const SizedBox(height: 10),
              Text('Adhkar pagi', key: const ValueKey('adhkar_pagi'),
                  style: tema.textTheme.labelLarge),
              for (final butir in adhkarPagi)
                CheckboxListTile(
                  key: ValueKey('adhkar_${butir.slug}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: isi.selesai(butir.nama),
                  title: Text(butir.nama),
                  subtitle: Text('${butir.target} kali'),
                  onChanged: (v) => tandai(butir, v ?? false),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  key: const ValueKey('buka_quran'),
                  onPressed: () => context.go('/ibadah/quran'),
                  child: const Text('Buka catatan Quran'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
