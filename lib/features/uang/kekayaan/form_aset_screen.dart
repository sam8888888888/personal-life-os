/// Form tambah/ubah aset (FR-76).
///
/// Hanya mengurus data dasar aset. Nilai per bulan diisi dari layar Kekayaan
/// Bersih, supaya grafik tren tetap punya satu pintu masuk.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audit/audit_log.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/uang_utils.dart';
import '../../../data/database/database.dart';
import '../../../data/model/enums.dart';
import '../../../data/repository/aset_repository.dart';

class FormAsetScreen extends ConsumerStatefulWidget {
  const FormAsetScreen({super.key, this.aset, this.jamSekarang});

  /// null = tambah baru, bukan null = ubah.
  final AsetData? aset;

  /// Jam uji supaya aturan bulan terkunci ikut jam layar pemanggil.
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<FormAsetScreen> createState() => _FormAsetScreenState();
}

class _FormAsetScreenState extends ConsumerState<FormAsetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _nilai = TextEditingController();
  final _institusi = TextEditingController();
  final _catatan = TextEditingController();

  JenisAset _jenis = JenisAset.kas;
  bool _likuid = true;

  AsetRepository get _repo => AsetRepository(
        ref.read(databaseProvider),
        jamSekarang: widget.jamSekarang,
      );

  bool get _baru => widget.aset == null;

  @override
  void initState() {
    super.initState();
    final a = widget.aset;
    if (a == null) return;
    _nama.text = a.nama;
    _nilai.text = (a.nilaiAwalSen / 100).round().toString();
    _institusi.text = a.institusi ?? '';
    _catatan.text = a.catatan ?? '';
    _jenis = JenisAset.dariDb(a.jenis);
    _likuid = a.likuid;
  }

  @override
  void dispose() {
    _nama.dispose();
    _nilai.dispose();
    _institusi.dispose();
    _catatan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_baru ? 'Tambah aset' : 'Ubah aset')),
      body: Form(
        key: _formKey,
        // SingleChildScrollView + Column: semua kolom tetap hidup sehingga
        // validasi tidak terlewat walau kolom tergulir keluar layar.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('nama_aset'),
                controller: _nama,
                decoration: const InputDecoration(
                  labelText: 'Nama aset *',
                  hintText: 'Contoh: Tabungan BCA',
                ),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama aset perlu diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<JenisAset>(
                initialValue: _jenis,
                decoration: const InputDecoration(labelText: 'Jenis aset'),
                items: JenisAset.values
                    .map((j) => DropdownMenuItem(value: j, child: Text(j.label)))
                    .toList(),
                onChanged: (v) => setState(() => _jenis = v ?? JenisAset.kas),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('nilai_aset'),
                controller: _nilai,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nilai aset (Rp) *',
                  hintText: '5000000 atau 5jt',
                  helperText: 'Dipakai bila belum ada catatan nilai bulanan.',
                ),
                validator: (v) {
                  final n = parseRupiah(v);
                  if (n == null || n < 0) return 'Nilai belum benar';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const Key('likuid_aset'),
                contentPadding: EdgeInsets.zero,
                value: _likuid,
                title: const Text('Dana likuid'),
                subtitle: const Text('Bisa dipakai cepat (kas, tabungan).'),
                onChanged: (v) => setState(() => _likuid = v),
              ),
              const SizedBox(height: 4),
              TextFormField(
                key: const Key('institusi_aset'),
                controller: _institusi,
                decoration: const InputDecoration(
                  labelText: 'Institusi (opsional)',
                  hintText: 'Contoh: BCA, Pegadaian',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('catatan_aset'),
                controller: _catatan,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('simpan_aset'),
                onPressed: _simpan,
                icon: const Icon(Icons.save),
                label: Text(_baru ? 'Simpan aset' : 'Simpan perubahan'),
              ),
              if (!_baru) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('hapus_aset_form'),
                  onPressed: _hapus,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus aset ini'),
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
    final angka = parseRupiah(_nilai.text);
    if (!valid || _nama.text.trim().isEmpty || angka == null || angka < 0) {
      _formKey.currentState!.validate();
      return;
    }
    final sen = rupiahKeSen(angka);
    try {
      if (_baru) {
        await _repo.tambahAset(
          nama: _nama.text.trim(),
          jenis: _jenis,
          nilaiAwalSen: sen,
          likuid: _likuid,
          institusi: _institusi.text.trim(),
          catatan: _catatan.text.trim(),
        );
      } else {
        await _repo.ubahAset(
          widget.aset!.id,
          nama: _nama.text.trim(),
          jenis: _jenis,
          nilaiAwalSen: sen,
          likuid: _likuid,
          institusi: _institusi.text.trim(),
          catatan: _catatan.text.trim(),
        );
      }
      // FR-138 — catatan aktivitas modul aset.
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.aset,
        aksi: _baru ? AksiAudit.buat : AksiAudit.ubah,
        entitas: 'aset',
        entitasId: _baru ? null : '${widget.aset!.id}',
        ringkas: 'Aset "${_nama.text.trim()}" '
            '${_baru ? 'dibuat' : 'diubah'} (${fmtRpDariSen(sen)}).',
      );
    } catch (e) {
      _pesan('Aset tidak bisa disimpan: $e');
      return;
    }
    if (!mounted) return;
    _pesan(_baru ? 'Aset tersimpan.' : 'Perubahan aset tersimpan.');
    Navigator.of(context).pop(true);
  }

  Future<void> _hapus() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus aset ini?'),
        content: const Text('Aset dan seluruh riwayat nilai bulanannya akan '
            'dihapus. Untuk sekadar menyembunyikannya, pilih "Arsipkan" pada '
            'daftar aset.'),
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
      await _repo.hapusAset(widget.aset!.id);
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.aset,
        aksi: AksiAudit.hapus,
        entitas: 'aset',
        entitasId: '${widget.aset!.id}',
        ringkas: 'Aset "${widget.aset!.nama}" dihapus.',
      );
    } catch (e) {
      _pesan('Aset tidak bisa dihapus: $e');
      return;
    }
    if (!mounted) return;
    _pesan('Aset dihapus.');
    Navigator.of(context).pop(true);
  }

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }
}
