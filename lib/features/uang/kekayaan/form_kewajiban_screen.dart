/// Form tambah/ubah kewajiban (FR-76).
///
/// Kolom bunga & minimum bayar disiapkan untuk FR-74 (Debt Manager); di layar
/// ini hanya dicatat apa adanya, tanpa perhitungan bunga.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/uang_utils.dart';
import '../../../data/database/database.dart';
import '../../../data/model/enums.dart';
import '../../../data/repository/aset_repository.dart';

class FormKewajibanScreen extends ConsumerStatefulWidget {
  const FormKewajibanScreen({super.key, this.kewajiban, this.jamSekarang});

  /// null = tambah baru, bukan null = ubah.
  final KewajibanData? kewajiban;

  /// Jam uji supaya aturan bulan terkunci ikut jam layar pemanggil.
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<FormKewajibanScreen> createState() =>
      _FormKewajibanScreenState();
}

class _FormKewajibanScreenState extends ConsumerState<FormKewajibanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _sisa = TextEditingController();
  final _pokok = TextEditingController();
  final _minimum = TextEditingController();
  final _jatuhTempo = TextEditingController();
  final _catatan = TextEditingController();

  JenisKewajiban _jenis = JenisKewajiban.lain;

  AsetRepository get _repo => AsetRepository(
        ref.read(databaseProvider),
        jamSekarang: widget.jamSekarang,
      );

  bool get _baru => widget.kewajiban == null;

  @override
  void initState() {
    super.initState();
    final k = widget.kewajiban;
    if (k == null) return;
    _nama.text = k.nama;
    _sisa.text = (k.saldoAwalSen / 100).round().toString();
    _pokok.text = (k.pokokSen / 100).round().toString();
    _minimum.text =
        k.minimumBayarSen == null ? '' : (k.minimumBayarSen! / 100).round().toString();
    _jatuhTempo.text = k.tanggalJatuhTempoHari?.toString() ?? '';
    _catatan.text = k.catatan ?? '';
    _jenis = JenisKewajiban.dariDb(k.jenis);
  }

  @override
  void dispose() {
    _nama.dispose();
    _sisa.dispose();
    _pokok.dispose();
    _minimum.dispose();
    _jatuhTempo.dispose();
    _catatan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_baru ? 'Tambah kewajiban' : 'Ubah kewajiban')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('nama_kewajiban'),
                controller: _nama,
                decoration: const InputDecoration(
                  labelText: 'Nama kewajiban *',
                  hintText: 'Contoh: KPR rumah',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama kewajiban perlu diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<JenisKewajiban>(
                initialValue: _jenis,
                decoration: const InputDecoration(labelText: 'Jenis kewajiban'),
                items: JenisKewajiban.values
                    .map((j) => DropdownMenuItem(value: j, child: Text(j.label)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _jenis = v ?? JenisKewajiban.lain),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('sisa_kewajiban'),
                controller: _sisa,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sisa pokok saat ini (Rp) *',
                  hintText: '200000000 atau 200jt',
                  helperText: 'Dipakai bila belum ada catatan nilai bulanan.',
                ),
                validator: (v) {
                  final n = parseRupiah(v);
                  if (n == null || n < 0) return 'Nilai belum benar';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('pokok_kewajiban'),
                controller: _pokok,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Pokok pinjaman awal (Rp)',
                  helperText: 'Boleh dikosongkan.',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = parseRupiah(v);
                  return (n == null || n < 0) ? 'Nilai belum benar' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('minimum_kewajiban'),
                controller: _minimum,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum bayar per bulan (Rp)',
                  helperText: 'Kosong = tidak diubah saat menyimpan perubahan.',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = parseRupiah(v);
                  return (n == null || n < 0) ? 'Nilai belum benar' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('jatuh_tempo_kewajiban'),
                controller: _jatuhTempo,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tanggal jatuh tempo tiap bulan (1-31)',
                  helperText: 'Kosong = tidak diubah saat menyimpan perubahan.',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 1 || n > 31) {
                    return 'Isi angka 1 sampai 31';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('catatan_kewajiban'),
                controller: _catatan,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Catatan (opsional)'),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('simpan_kewajiban'),
                onPressed: _simpan,
                icon: const Icon(Icons.save),
                label: Text(_baru ? 'Simpan kewajiban' : 'Simpan perubahan'),
              ),
              if (!_baru) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('hapus_kewajiban_form'),
                  onPressed: _hapus,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus kewajiban ini'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _simpan() async {
    final valid = _formKey.currentState!.validate();
    final sisaMentah = parseRupiah(_sisa.text);
    if (!valid ||
        _nama.text.trim().isEmpty ||
        sisaMentah == null ||
        sisaMentah < 0) {
      _formKey.currentState!.validate();
      return;
    }
    final sisaSen = rupiahKeSen(sisaMentah);
    // Kolom opsional: kosong = tidak diubah (repositori memakai Value.absent
    // untuk nilai null), jadi nilai lama tidak terhapus tanpa sengaja.
    final pokokMentah = parseRupiah(_pokok.text);
    final minimumMentah = parseRupiah(_minimum.text);
    final jatuhTempo = int.tryParse(_jatuhTempo.text.trim());
    try {
      if (_baru) {
        await _repo.tambahKewajiban(
          nama: _nama.text.trim(),
          jenis: _jenis,
          pokokSen: pokokMentah == null ? 0 : rupiahKeSen(pokokMentah),
          saldoAwalSen: sisaSen,
          minimumBayarSen:
              minimumMentah == null ? null : rupiahKeSen(minimumMentah),
          tanggalJatuhTempoHari: jatuhTempo,
          catatan: _catatan.text.trim(),
        );
      } else {
        await _repo.ubahKewajiban(
          widget.kewajiban!.id,
          nama: _nama.text.trim(),
          jenis: _jenis,
          pokokSen: pokokMentah == null ? 0 : rupiahKeSen(pokokMentah),
          saldoAwalSen: sisaSen,
          minimumBayarSen:
              minimumMentah == null ? null : rupiahKeSen(minimumMentah),
          tanggalJatuhTempoHari: jatuhTempo,
          catatan: _catatan.text.trim(),
        );
      }
    } catch (e) {
      _pesan('Kewajiban tidak bisa disimpan: $e');
      return;
    }
    if (!mounted) return;
    _pesan(_baru ? 'Kewajiban tersimpan.' : 'Perubahan kewajiban tersimpan.');
    Navigator.of(context).pop(true);
  }

  Future<void> _hapus() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus kewajiban ini?'),
        content: const Text('Kewajiban dan riwayat nilai bulanannya akan '
            'dihapus. Untuk sekadar menyembunyikannya, pilih "Arsipkan" pada '
            'daftar kewajiban.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    try {
      await _repo.hapusKewajiban(widget.kewajiban!.id);
    } catch (e) {
      _pesan('Kewajiban tidak bisa dihapus: $e');
      return;
    }
    if (!mounted) return;
    _pesan('Kewajiban dihapus.');
    Navigator.of(context).pop(true);
  }

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }
}
