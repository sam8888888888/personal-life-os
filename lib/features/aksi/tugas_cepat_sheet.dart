/// Lembar "Tugas cepat" (FR-79) — menyimpan tugas berdiri sendiri.
///
/// Dua ketukan: (1) ketuk tombol "Tugas cepat", (2) tulis nama lalu ketuk
/// "Simpan". Tanggal opsional; bawaannya hari ini, sehingga tugas langsung
/// muncul di daftar "Tugas cepat hari ini" dan tidak memaksa pengguna memilih
/// proyek terlebih dahulu.
library;

import 'package:flutter/material.dart';

import '../../core/utils/waktu.dart';
import '../../data/repository/aksi_repository.dart';

/// Tampilkan lembar tugas cepat. Mengembalikan tugas yang tersimpan, atau
/// null bila dibatalkan.
Future<BarisTugas?> tampilkanTugasCepat(
  BuildContext context,
  AksiRepository repo,
) {
  return showDialog<BarisTugas>(
    context: context,
    builder: (_) => _DialogTugasCepat(repo: repo),
  );
}

class _DialogTugasCepat extends StatefulWidget {
  const _DialogTugasCepat({required this.repo});

  final AksiRepository repo;

  @override
  State<_DialogTugasCepat> createState() => _StateTugasCepat();
}

/// Pilihan tanggal untuk tugas cepat.
enum _PilihanTanggal { hariIni, besok, tanpaTanggal }

class _StateTugasCepat extends State<_DialogTugasCepat> {
  final _kendaliNama = TextEditingController();
  _PilihanTanggal _tanggal = _PilihanTanggal.hariIni;
  bool _menyimpan = false;
  String? _pesanGalat;

  @override
  void dispose() {
    _kendaliNama.dispose();
    super.dispose();
  }

  DateTime? _jatuhTempo(DateTime sekarang) {
    final hariIni = AksiRepository.hariSaja(sekarang);
    return switch (_tanggal) {
      _PilihanTanggal.hariIni => hariIni,
      _PilihanTanggal.besok => hariIni.add(const Duration(days: 1)),
      _PilihanTanggal.tanpaTanggal => null,
    };
  }

  Future<void> _simpan() async {
    final nama = _kendaliNama.text.trim();
    if (nama.isEmpty) {
      setState(() => _pesanGalat = 'Tulis dulu nama tugasnya.');
      return;
    }
    setState(() {
      _menyimpan = true;
      _pesanGalat = null;
    });
    try {
      final tugas = await widget.repo
          .simpanTugasCepat(nama, jatuhTempo: _jatuhTempo(waktuSekarang()))
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      Navigator.of(context).pop(tugas);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _menyimpan = false;
        _pesanGalat = 'Tugas belum tersimpan. Coba tekan Simpan sekali lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tugas cepat'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            key: const Key('form_nama_cepat'),
            controller: _kendaliNama,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _simpan(),
            decoration: const InputDecoration(
              labelText: 'Apa yang ingin Anda kerjakan?',
              hintText: 'Mis. telepon tukang servis',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: <Widget>[
              ChoiceChip(
                key: const Key('cepat_hari_ini'),
                label: const Text('Hari ini'),
                selected: _tanggal == _PilihanTanggal.hariIni,
                onSelected: (_) =>
                    setState(() => _tanggal = _PilihanTanggal.hariIni),
              ),
              ChoiceChip(
                key: const Key('cepat_besok'),
                label: const Text('Besok'),
                selected: _tanggal == _PilihanTanggal.besok,
                onSelected: (_) =>
                    setState(() => _tanggal = _PilihanTanggal.besok),
              ),
              ChoiceChip(
                key: const Key('cepat_tanpa_tanggal'),
                label: const Text('Tanpa tanggal'),
                selected: _tanggal == _PilihanTanggal.tanpaTanggal,
                onSelected: (_) =>
                    setState(() => _tanggal = _PilihanTanggal.tanpaTanggal),
              ),
            ],
          ),
          if (_pesanGalat != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _pesanGalat!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _menyimpan ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('simpan_tugas_cepat'),
          onPressed: _menyimpan ? null : _simpan,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
