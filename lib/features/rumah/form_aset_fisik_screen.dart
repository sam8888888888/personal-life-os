/// FR-124/126/127 — Form tambah & ubah aset fisik.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rumah/aset_fisik.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';
import 'rumah_providers.dart';

class FormAsetFisikScreen extends ConsumerStatefulWidget {
  const FormAsetFisikScreen({super.key, this.id});

  /// null = tambah baru.
  final int? id;

  @override
  ConsumerState<FormAsetFisikScreen> createState() =>
      _FormAsetFisikScreenState();
}

class _FormAsetFisikScreenState extends ConsumerState<FormAsetFisikScreen> {
  final _nama = TextEditingController();
  final _harga = TextEditingController();
  final _nomorSeri = TextEditingController();
  final _masaPakai = TextEditingController();
  final _lokasi = TextEditingController();
  final _catatan = TextEditingController();

  JenisAsetFisik _jenis = JenisAsetFisik.perangkat;
  DateTime? _tanggalBeli;
  DateTime? _garansiSampai;
  bool _siap = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    if (widget.id == null) {
      _siap = true;
    } else {
      _muat();
    }
  }

  Future<void> _muat() async {
    final a = await ref.read(repoRumahProvider).ambilAsetSatu(widget.id!);
    if (a == null) {
      if (mounted) setState(() => _galat = 'Aset tidak ditemukan.');
      return;
    }
    _nama.text = a.nama;
    _jenis = JenisAsetFisik.dariKode(a.jenis) ?? JenisAsetFisik.lain;
    _harga.text = a.hargaBeliSen == null
        ? ''
        : (a.hargaBeliSen! ~/ 100).toString();
    _nomorSeri.text = a.nomorSeri ?? '';
    _masaPakai.text = a.masaPakaiBulan?.toString() ?? '';
    _lokasi.text = a.lokasi ?? '';
    _catatan.text = a.catatan ?? '';
    _tanggalBeli = a.tanggalBeli;
    _garansiSampai = a.garansiSampai;
    if (mounted) setState(() => _siap = true);
  }

  @override
  void dispose() {
    _nama.dispose();
    _harga.dispose();
    _nomorSeri.dispose();
    _masaPakai.dispose();
    _lokasi.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal({required bool garansi}) async {
    final awal = garansi ? _garansiSampai : _tanggalBeli;
    final hasil = await showDatePicker(
      context: context,
      initialDate: awal ?? DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (hasil == null) return;
    setState(() {
      if (garansi) {
        _garansiSampai = hasil;
      } else {
        _tanggalBeli = hasil;
      }
    });
  }

  Future<void> _simpan() async {
    final nama = _nama.text.trim();
    if (nama.isEmpty) {
      setState(() => _galat = 'Nama aset tidak boleh kosong.');
      return;
    }
    final rupiah = parseRupiah(_harga.text);
    final masaPakai = _masaPakai.text.trim().isEmpty
        ? null
        : int.tryParse(_masaPakai.text.trim());
    if (_masaPakai.text.trim().isNotEmpty && (masaPakai == null || masaPakai <= 0)) {
      setState(() => _galat = 'Masa pakai diisi angka bulan (mis. 60).');
      return;
    }
    try {
      await ref.read(repoRumahProvider).simpanAsetFisik(
            id: widget.id,
            nama: nama,
            jenis: _jenis,
            tanggalBeli: _tanggalBeli,
            hargaBeliSen: rupiah == null ? null : rupiahKeSen(rupiah),
            nomorSeri: _nomorSeri.text,
            garansiSampai: _garansiSampai,
            masaPakaiBulan: masaPakai,
            lokasi: _lokasi.text,
            catatan: _catatan.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _galat = 'Belum bisa disimpan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? 'Tambah aset' : 'Ubah aset')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(
            key: const Key('form_aset_nama'),
            controller: _nama,
            decoration: const InputDecoration(
              labelText: 'Nama aset',
              hintText: 'mis. Honda Vario, Kulkas, Laptop',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<JenisAsetFisik>(
            key: const Key('form_aset_jenis'),
            initialValue: _jenis,
            decoration: const InputDecoration(labelText: 'Jenis'),
            items: [
              for (final j in JenisAsetFisik.values)
                DropdownMenuItem(value: j, child: Text(j.label)),
            ],
            onChanged: (v) => setState(() => _jenis = v ?? _jenis),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('form_aset_harga'),
            controller: _harga,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Harga beli (Rp)',
              helperText: 'Dipakai sebagai nilai aset di Kekayaan Bersih bila '
                  'belum ada nilai bulanan',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('form_aset_nomor_seri'),
            controller: _nomorSeri,
            decoration: const InputDecoration(
              labelText: 'Nomor seri / rangka / polisi (opsional)',
            ),
          ),
          const SizedBox(height: 12),
          _tombolTanggal(
            kunci: 'form_aset_tanggal_beli',
            label: 'Tanggal beli',
            nilai: _tanggalBeli,
            onTap: () => _pilihTanggal(garansi: false),
          ),
          const SizedBox(height: 12),
          _tombolTanggal(
            kunci: 'form_aset_garansi',
            label: 'Garansi berakhir',
            nilai: _garansiSampai,
            onTap: () => _pilihTanggal(garansi: true),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('form_aset_masa_pakai'),
            controller: _masaPakai,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Perkiraan masa pakai (bulan)',
              hintText: 'mis. 60',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('form_aset_lokasi'),
            controller: _lokasi,
            decoration: const InputDecoration(labelText: 'Lokasi (opsional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('form_aset_catatan'),
            controller: _catatan,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
          ),
          if (_galat != null) ...[
            const SizedBox(height: 12),
            Text(_galat!, key: const Key('form_aset_galat'),
                style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('form_aset_simpan'),
            onPressed: _simpan,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _tombolTanggal({
    required String kunci,
    required String label,
    required DateTime? nilai,
    required VoidCallback onTap,
  }) =>
      OutlinedButton(
        key: Key(kunci),
        onPressed: onTap,
        child: Text(nilai == null
            ? '$label: belum diisi'
            : '$label: ${fmtTanggalPendekAman(nilai)}'),
      );
}
