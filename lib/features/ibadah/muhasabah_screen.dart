/// Layar Muhasabah / Refleksi malam (FR-100).
///
/// Satu catatan per tanggal: enam daftar refleksi (bentuk daftar periksa) plus
/// kolom tulisan bebas, dan rangkuman 7 hari terakhir.
///
/// Aturan yang dipegang (PRD III-11):
/// * **Kosong berarti belum diisi, bukan berarti tidak dilakukan.** Karena itu
///   setiap butir punya tiga keadaan: "Ya", "Tidak", dan "Belum diisi".
/// * Tidak ada skor, peringkat, atau nilai. Rangkuman hanya menyebutkan berapa
///   butir yang SUDAH ANDA ISI hari itu, sebagai penanda kelengkapan catatan.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/repository/ibadah_lanjutan_repository.dart';
import 'ibadah_lanjutan_provider.dart';
import 'komponen_ibadah_lanjutan.dart';

/// Nama keadaan satu butir refleksi.
String labelNilaiRefleksi(bool? nilai) {
  if (nilai == null) return 'Belum diisi';
  return nilai ? 'Ya' : 'Tidak';
}

/// Layar refleksi malam (FR-100).
class MuhasabahScreen extends ConsumerStatefulWidget {
  const MuhasabahScreen({super.key});

  @override
  ConsumerState<MuhasabahScreen> createState() => _StateMuhasabah();
}

class _StateMuhasabah extends ConsumerState<MuhasabahScreen> {
  static const Duration _batas = Duration(seconds: 5);

  late final IbadahLanjutanRepository _repo;

  bool _memuat = true;
  bool _galat = false;
  NilaiRefleksi _nilai = NilaiRefleksi.kosong;
  final TextEditingController _catatan = TextEditingController();
  List<RefleksiMuhasabahData> _rentang = const <RefleksiMuhasabahData>[];
  late DateTime _tanggal;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(ibadahLanjutanRepoProvider);
    _tanggal = IbadahLanjutanRepository.hari(waktuSekarang());
    unawaited(_muat());
  }

  @override
  void dispose() {
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    if (mounted) setState(() => _memuat = true);
    final DateTime hariIni = IbadahLanjutanRepository.hari(waktuSekarang());
    try {
      final RefleksiMuhasabahData? baris =
          await _repo.refleksiTanggal(_tanggal).timeout(_batas);
      final List<RefleksiMuhasabahData> rentang = await _repo
          .refleksiRentang(IbadahLanjutanRepository.mulaiRentang(hariIni, 7),
              hariIni.add(const Duration(days: 1)))
          .timeout(_batas);
      if (!mounted) return;
      setState(() {
        _nilai = NilaiRefleksi.dariBaris(baris);
        _catatan.text = baris?.catatan ?? '';
        _rentang = rentang;
        _memuat = false;
        _galat = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _galat = true;
      });
    }
  }

  Future<void> _simpan() async {
    try {
      await _repo
          .simpanRefleksi(_tanggal, _nilai, catatan: _catatan.text)
          .timeout(_batas);
      await _muat();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Refleksi tersimpan di perangkat Anda')));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Refleksi belum bisa disimpan saat ini')));
    }
  }

  Future<void> _pilihTanggal() async {
    final DateTime? pilih = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pilih != null) {
      setState(() => _tanggal = pilih);
      await _muat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final DateTime hariIni = IbadahLanjutanRepository.hari(waktuSekarang());
    final Map<DateTime, RefleksiMuhasabahData> perHari =
        <DateTime, RefleksiMuhasabahData>{
      for (final RefleksiMuhasabahData b in _rentang)
        IbadahLanjutanRepository.hari(b.tanggal): b,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Muhasabah')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: <Widget>[
          KartuBagian(
            judul: 'Refleksi ${teksTanggal(_tanggal)}',
            isi: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InkWell(
                  key: const Key('tanggal_muhasabah'),
                  onTap: _pilihTanggal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.event_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text('Tanggal: ${teksTanggal(_tanggal)}'),
                        const Spacer(),
                        Text('Ubah',
                            style: tema.textTheme.bodySmall
                                ?.copyWith(color: tema.colorScheme.primary)),
                      ],
                    ),
                  ),
                ),
                for (final ButirRefleksi butir in ButirRefleksi.values)
                  Row(
                    children: <Widget>[
                      Checkbox(
                        key: Key('butir_${butir.kunci}'),
                        tristate: true,
                        value: _nilai.nilai(butir),
                        onChanged: (bool? v) => setState(
                            () => _nilai = _nilai.dengan(butir, v)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(butir.label),
                            Text(labelNilaiRefleksi(_nilai.nilai(butir)),
                                style: tema.textTheme.bodySmall?.copyWith(
                                    color: tema.colorScheme.outline)),
                          ],
                        ),
                      ),
                    ],
                  ),
                const CatatanJujur(
                    teks: 'Tanda "Belum diisi" berarti Anda belum mengisi '
                        'butir itu — bukan berarti tidak Anda lakukan.'),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('catatan_muhasabah'),
                  controller: _catatan,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Tulisan bebas (opsional)',
                    hintText: 'Tulis apa yang Anda syukuri atau ingin diperbaiki',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('simpan_muhasabah'),
                  onPressed: _simpan,
                  child: const Text('Simpan refleksi'),
                ),
              ],
            ),
          ),
          KartuBagian(
            judul: '7 hari terakhir',
            isi: _memuat
                ? const Text('Membaca catatan...')
                : _galat
                    ? const Text('Catatan belum bisa dibaca saat ini')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (int i = 6; i >= 0; i--)
                            _barisHari(
                                hariIni.subtract(Duration(days: i)),
                                perHari[hariIni.subtract(Duration(days: i))],
                                tema),
                          const CatatanJujur(
                              teks: 'Angka "x dari 6 butir terisi" hanya '
                                  'menandakan kelengkapan catatan Anda, bukan '
                                  'penilaian. Tidak ada nilai, urutan, atau '
                                  'peringkat di layar ini.'),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  /// Ringkasan satu hari — tanpa kata penilaian apa pun.
  Widget _barisHari(DateTime tanggal, RefleksiMuhasabahData? baris, ThemeData tema) {
    final int terisi = jumlahButirTerisi(baris);
    final String? catatan = baris?.catatan;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 86,
            child: Text('${teksHari(tanggal)} ${teksTanggal(tanggal)}',
                style: tema.textTheme.bodySmall),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(baris == null
                    ? teksBelumAdaData
                    : '$terisi dari 6 butir terisi'),
                if (catatan != null)
                  Text(catatan,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall
                          ?.copyWith(color: tema.colorScheme.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
