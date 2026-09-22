/// FR-117 — Kartu darurat: bisa dibuka saat offline, dan dari pintasan
/// aplikasi yang sengaja boleh tampil di atas layar kunci.
///
/// Aturan yang dijaga:
///  * **Kartu cepat** (golongan darah, alergi, kontak darurat) selalu tampil —
///    inilah yang dibutuhkan penolong lebih dulu.
///  * **Rincian** (kondisi, obat penting, catatan) hanya tampil bila perangkat
///    TIDAK terkunci, kecuali pengguna mematikan pengaturan itu di profil.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/berkas_medis.dart';
import '../../data/database/database.dart';
import 'kesehatan_medis_providers.dart';

class KartuDaruratScreen extends ConsumerStatefulWidget {
  const KartuDaruratScreen({super.key, this.paksaTerkunci});

  /// Dipakai uji supaya keadaan kunci layar bisa ditentukan.
  final bool? paksaTerkunci;

  @override
  ConsumerState<KartuDaruratScreen> createState() => _KartuDaruratScreenState();
}

class _KartuDaruratScreenState extends ConsumerState<KartuDaruratScreen> {
  ProfilKesehatanData? _profil;
  bool _siap = false;
  bool _terkunci = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    _terkunci =
        widget.paksaTerkunci ?? await _terkunciSekarang();
    final p = await ref.read(repoMedisProvider).ambilProfil();
    if (!mounted) return;
    setState(() {
      _profil = p;
      _siap = true;
    });
  }

  Future<bool> _terkunciSekarang() => perangkatTerkunci();

  /// Rincian sensitif boleh tampil?
  bool get _bolehRincian {
    final p = _profil;
    if (p == null) return false;
    if (!p.sembunyikanRincianDikunci) return true;
    return !_terkunci;
  }

  String get _teksKartu {
    final p = _profil;
    if (p == null) return 'Profil kesehatan belum diisi.';
    final b = StringBuffer('KARTU DARURAT\n');
    if (p.golonganDarah != null) b.writeln('Golongan darah: ${p.golonganDarah}');
    if (p.alergi != null) b.writeln('Alergi: ${p.alergi}');
    if (_bolehRincian) {
      if (p.kondisi != null) b.writeln('Kondisi: ${p.kondisi}');
      if (p.obatPenting != null) b.writeln('Obat penting: ${p.obatPenting}');
      if (p.catatan != null) b.writeln('Catatan: ${p.catatan}');
    }
    if (p.kontakNama != null || p.kontakTelepon != null) {
      b.writeln('Kontak darurat: ${p.kontakNama ?? '-'} '
          '(${p.kontakHubungan ?? '-'}) ${p.kontakTelepon ?? ''}');
    }
    return b.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = _profil;
    return Scaffold(
      appBar: AppBar(title: const Text('Kartu darurat')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          if (p == null)
            Card(
              key: const Key('kartu_kosong'),
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Profil kesehatan belum diisi'),
                subtitle: const Text('Isi golongan darah, alergi, dan kontak '
                    'darurat dulu supaya kartu ini berguna.'),
                onTap: () => Navigator.of(context)
                    .pushNamed('/kesehatan/profil-kesehatan'),
              ),
            )
          else ...[
            Card(
              key: const Key('kartu_cepat'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kartu cepat',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    _baris('Golongan darah', p.golonganDarah),
                    _baris('Alergi', p.alergi),
                    _baris('Kontak darurat',
                        '${p.kontakNama ?? '-'} (${p.kontakHubungan ?? '-'}) '
                            '${p.kontakTelepon ?? ''}'),
                  ],
                ),
              ),
            ),
            if (_bolehRincian)
              Card(
                key: const Key('kartu_rincian'),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rincian',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      _baris('Kondisi', p.kondisi),
                      _baris('Obat penting', p.obatPenting),
                      _baris('Catatan', p.catatan),
                    ],
                  ),
                ),
              )
            else
              Card(
                key: const Key('kartu_rincian_terkunci'),
                child: const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Rincian disembunyikan'),
                  subtitle: Text('Perangkat sedang terkunci. Buka kunci '
                      'perangkat untuk melihat kondisi & obat penting.'),
                ),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('kartu_salin'),
              onPressed: () async {
                final pengumum = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: _teksKartu));
                if (!mounted) return;
                pengumum.showSnackBar(const SnackBar(
                    content: Text('Teks kartu disalin — bisa ditempel di '
                        'catatan atau dikirim ke penolong.')));
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Salin teks kartu'),
            ),
            const SizedBox(height: 8),
            Text(
              'Kartu ini dibuka tanpa internet lewat pintasan aplikasi '
              '"Kartu Darurat" (bisa tampil di atas layar kunci).',
              key: const Key('kartu_catatan_pintasan'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _baris(String label, String? nilai) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text('$label: ${(nilai == null || nilai.trim().isEmpty) ? '— belum diisi' : nilai}'),
      );
}
