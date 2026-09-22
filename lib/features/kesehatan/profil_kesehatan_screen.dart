/// FR-117 — Profil kesehatan (golongan darah, alergi, kondisi, obat penting,
/// kontak darurat) dan pintu ke kartu darurat.
///
/// Isi formulir sengaja apa adanya: aplikasi tidak menafsirkan, tidak menilai.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/medis_repository.dart';
import 'kesehatan_medis_providers.dart';

class ProfilKesehatanScreen extends ConsumerStatefulWidget {
  const ProfilKesehatanScreen({super.key});

  @override
  ConsumerState<ProfilKesehatanScreen> createState() =>
      _ProfilKesehatanScreenState();
}

class _ProfilKesehatanScreenState extends ConsumerState<ProfilKesehatanScreen> {
  final _darah = TextEditingController();
  final _alergi = TextEditingController();
  final _kondisi = TextEditingController();
  final _obat = TextEditingController();
  final _kontakNama = TextEditingController();
  final _kontakTelepon = TextEditingController();
  final _catatan = TextEditingController();
  String _hubungan = 'pasangan';
  bool _sembunyikan = true;
  bool _siap = false;
  String? _pesan;

  static const List<String> _golongan = [
    'A', 'B', 'AB', 'O', 'A+', 'B+', 'AB+', 'O+', 'A-', 'B-', 'AB-', 'O-'
  ];
  static const List<String> _hubunganKontak = [
    'pasangan',
    'anak',
    'orangtua',
    'saudara',
    'sahabat',
    'lain',
  ];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    for (final k in [
      _darah,
      _alergi,
      _kondisi,
      _obat,
      _kontakNama,
      _kontakTelepon,
      _catatan,
    ]) {
      k.dispose();
    }
    super.dispose();
  }

  Future<void> _muat() async {
    final p = await ref.read(repoMedisProvider).ambilProfil();
    if (!mounted) return;
    setState(() {
      if (p != null) {
        _darah.text = p.golonganDarah ?? '';
        _alergi.text = p.alergi ?? '';
        _kondisi.text = p.kondisi ?? '';
        _obat.text = p.obatPenting ?? '';
        _kontakNama.text = p.kontakNama ?? '';
        _kontakTelepon.text = p.kontakTelepon ?? '';
        _catatan.text = p.catatan ?? '';
        _hubungan = p.kontakHubungan ?? 'pasangan';
        _sembunyikan = p.sembunyikanRincianDikunci;
      }
      _siap = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profil kesehatan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.badge_outlined),
              title: Text('Dipakai untuk kartu darurat'),
              subtitle: Text('Kartu darurat membuka data ini tanpa internet. '
                  'Rincian sensitif bisa disembunyikan saat perangkat terkunci.'),
            ),
          ),
          DropdownButtonFormField<String>(
            key: const Key('profil_darah'),
            initialValue: _golongan.contains(_darah.text) ? _darah.text : null,
            decoration: const InputDecoration(labelText: 'Golongan darah'),
            items: [
              for (final g in _golongan)
                DropdownMenuItem(value: g, child: Text(g)),
            ],
            onChanged: (v) => setState(() => _darah.text = v ?? ''),
          ),
          const SizedBox(height: 8),
          _bidang('profil_alergi', _alergi, 'Alergi'),
          _bidang('profil_kondisi', _kondisi, 'Kondisi yang perlu diketahui'),
          _bidang('profil_obat', _obat, 'Obat penting / rutin'),
          const SizedBox(height: 8),
          Text('Kontak darurat',
              style: Theme.of(context).textTheme.titleMedium),
          _bidang('profil_kontak_nama', _kontakNama, 'Nama kontak'),
          DropdownButtonFormField<String>(
            key: const Key('profil_kontak_hubungan'),
            initialValue: _hubungan,
            decoration: const InputDecoration(labelText: 'Hubungan kontak'),
            items: [
              for (final h in _hubunganKontak)
                DropdownMenuItem(value: h, child: Text(h)),
            ],
            onChanged: (v) => setState(() => _hubungan = v ?? _hubungan),
          ),
          _bidang('profil_kontak_telepon', _kontakTelepon, 'Nomor kontak',
              jenisPapanKetik: TextInputType.phone),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('profil_sembunyikan'),
            value: _sembunyikan,
            onChanged: (v) => setState(() => _sembunyikan = v),
            title: const Text('Sembunyikan rincian saat perangkat terkunci'),
            subtitle: const Text('Kartu cepat (golongan darah, alergi, kontak) '
                'tetap tampil; kondisi & obat hanya setelah perangkat dibuka.'),
          ),
          _bidang('profil_catatan', _catatan, 'Catatan lain', baris: 3),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('profil_simpan'),
            onPressed: _simpan,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Simpan profil'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('profil_buka_kartu'),
            onPressed: () => Navigator.of(context).pushNamed('/kesehatan/kartu-darurat'),
            icon: const Icon(Icons.emergency_outlined),
            label: const Text('Buka kartu darurat'),
          ),
          if (_pesan != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_pesan!, key: const Key('profil_pesan')),
            ),
        ],
      ),
    );
  }

  Widget _bidang(String kunci, TextEditingController kendali, String label,
          {int baris = 1, TextInputType? jenisPapanKetik}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          key: Key(kunci),
          controller: kendali,
          maxLines: baris,
          keyboardType: jenisPapanKetik,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Future<void> _simpan() async {
    try {
      final p = await ref.read(repoMedisProvider).simpanProfil(
            golonganDarah: _darah.text,
            alergi: _alergi.text,
            kondisi: _kondisi.text,
            obatPenting: _obat.text,
            kontakNama: _kontakNama.text,
            kontakHubungan: _hubungan,
            kontakTelepon: _kontakTelepon.text,
            catatan: _catatan.text,
            sembunyikanRincianDikunci: _sembunyikan,
          );
      if (!mounted) return;
      setState(() => _pesan = MedisRepository.kartuSiap(p)
          ? 'Profil tersimpan. Kartu darurat sudah bisa dipakai.'
          : 'Profil tersimpan. Isi minimal dua bagian supaya kartu darurat '
              'berguna (mis. golongan darah + kontak).');
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = 'Belum bisa disimpan: $e');
    }
  }
}
