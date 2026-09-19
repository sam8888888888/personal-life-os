/// FR-71 — form tambah/ubah satu transaksi arus kas.
///
/// Isi: jenis (pemasukan/pengeluaran), nominal (parseRupiah/rupiahKeSen),
/// kategori (difilter sesuai jenis), tanggal, dan catatan.
///
/// Idempotensi: kunci `idTransaksi` dibuat sekali per transaksi dan dipakai
/// ulang saat menyimpan perubahan — jadi menyimpan dua kali tidak menggandakan
/// baris (pola sama seperti impor berkas cadangan, lihat `transaksi_repository`).
library;

import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audit/audit_log.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/tanggal_utils.dart';
import '../../../core/utils/uang_utils.dart';
import '../../../core/utils/waktu.dart';
import '../../../data/database/database.dart';
import '../../../data/model/enums.dart';
import '../../../data/repository/kategori_transaksi_repository.dart';
import '../../../data/repository/transaksi_repository.dart';
import 'warna_ikon_kategori.dart';

/// Kategori aktif (belum disembunyikan) untuk pilihan di form.
final kategoriFormProvider =
    StreamProvider.autoDispose<List<KategoriTransaksiData>>((ref) =>
        KategoriTransaksiRepository(ref.watch(databaseProvider)).watchAktif());

/// Repositori transaksi untuk form.
final repoFormTransaksiProvider = Provider<TransaksiRepository>(
    (ref) => TransaksiRepository(ref.watch(databaseProvider)));

/// Form transaksi. `id` kosong = tambah baru, terisi = ubah.
class FormTransaksiScreen extends ConsumerStatefulWidget {
  const FormTransaksiScreen({super.key, this.id, this.jamSekarang});

  final int? id;

  /// Sumber waktu (untuk pengujian); kosong = jam sistem.
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<FormTransaksiScreen> createState() => _FormTransaksiScreenState();
}

class _FormTransaksiScreenState extends ConsumerState<FormTransaksiScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nominal = TextEditingController();
  final _catatan = TextEditingController();

  JenisArus _jenis = JenisArus.pengeluaran;
  int? _kategoriId;
  String? _galatKategori;
  late DateTime _tanggal;

  /// Kunci idempotensi baris ini (null = belum pernah disimpan).
  String? _idTransaksi;
  bool _memuat = false;
  bool _tidakDitemukan = false;
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    final jam = _jamSekarang();
    _tanggal = DateTime(jam.year, jam.month, jam.day);
    if (widget.id != null) {
      _memuat = true;
      _muatData();
    }
  }

  @override
  void dispose() {
    _nominal.dispose();
    _catatan.dispose();
    super.dispose();
  }

  DateTime _jamSekarang() => widget.jamSekarang?.call() ?? waktuSekarang();

  Future<void> _muatData() async {
    final t = await ref.read(repoFormTransaksiProvider).ambilSatu(widget.id!);
    if (!mounted) return;
    setState(() {
      _memuat = false;
      if (t == null) {
        _tidakDitemukan = true;
        return;
      }
      _idTransaksi = t.idTransaksi;
      _jenis = JenisArus.dariDb(t.jenis);
      _nominal.text = (t.jumlahSen / 100).round().toString();
      _catatan.text = t.catatan ?? '';
      _kategoriId = t.kategoriId;
      _tanggal = DateTime(t.tanggal.year, t.tanggal.month, t.tanggal.day);
    });
  }

  /// Kunci idempotensi baru: `trx_<mikrodetik>_<acak>`.
  static String _idTransaksiBaru() {
    final acak = Random().nextInt(1 << 32).toRadixString(16);
    return 'trx_${DateTime.now().microsecondsSinceEpoch}_$acak';
  }

  Future<void> _pilihTanggal() async {
    final pilih = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('id', 'ID'),
    );
    if (pilih != null && mounted) setState(() => _tanggal = pilih);
  }

  Future<void> _simpan() async {
    final valid = _formKey.currentState!.validate();
    final adaKategori = _kategoriId != null;
    if (!adaKategori) {
      setState(() => _galatKategori = 'Pilih kategori dulu');
    }
    final nominal = parseRupiah(_nominal.text);
    if (!valid || !adaKategori || nominal == null || nominal <= 0) return;

    // Kunci dibuat SEBELUM menulis: dua ketukan cepat memakai kunci yang sama,
    // jadi baris tetap satu (idempoten).
    _idTransaksi ??= _idTransaksiBaru();
    setState(() => _menyimpan = true);
    try {
      await ref.read(repoFormTransaksiProvider).simpan(TransaksiCompanion.insert(
            idTransaksi: _idTransaksi!,
            jenis: Value(_jenis.nilaiDb),
            tanggal: DateTime(_tanggal.year, _tanggal.month, _tanggal.day),
            jumlahSen: rupiahKeSen(nominal),
            kategoriId: Value(_kategoriId),
            catatan: Value(
                _catatan.text.trim().isEmpty ? null : _catatan.text.trim()),
            sumber: const Value('manual'),
          ));
      // FR-138 — catatan aktivitas modul uang.
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.transaksi,
        aksi: widget.id == null ? AksiAudit.buat : AksiAudit.ubah,
        entitas: 'transaksi',
        entitasId: _idTransaksi,
        ringkas: 'Transaksi ${_jenis.nilaiDb} '
            '${fmtRpDariSen(rupiahKeSen(nominal))} '
            '${widget.id == null ? 'dicatat' : 'diubah'} '
            '(${fmtTanggalId(_tanggal)}).',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.id == null
              ? 'Transaksi tersimpan.'
              : 'Perubahan tersimpan.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _menyimpan = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaksi tidak tersimpan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final semua =
        ref.watch(kategoriFormProvider).value ?? const <KategoriTransaksiData>[];
    final pilihan =
        semua.where((k) => k.jenis == _jenis.nilaiDb).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? 'Tambah Transaksi' : 'Ubah Transaksi'),
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : _tidakDitemukan
              ? const Center(child: Text('Transaksi tidak ditemukan.'))
              : _form(pilihan),
    );
  }

  Widget _form(List<KategoriTransaksiData> pilihan) => Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<JenisArus>(
                segments: const [
                  ButtonSegment<JenisArus>(
                    value: JenisArus.pengeluaran,
                    label: Text('Pengeluaran'),
                    icon: Icon(Icons.north_east),
                  ),
                  ButtonSegment<JenisArus>(
                    value: JenisArus.pemasukan,
                    label: Text('Pemasukan'),
                    icon: Icon(Icons.south_west),
                  ),
                ],
                selected: {_jenis},
                onSelectionChanged: (pilih) => setState(() {
                  _jenis = pilih.first;
                  // Kategori difilter per jenis: buang pilihan yang tidak cocok.
                  if (!pilihan.any((k) => k.id == _kategoriId)) {
                    _kategoriId = null;
                  }
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('nominal_transaksi'),
                controller: _nominal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal (Rp) *',
                  hintText: '150000 atau 150rb',
                ),
                validator: (v) {
                  final teks = v?.trim() ?? '';
                  if (teks.isEmpty) return 'Nominal wajib diisi';
                  final n = parseRupiah(teks);
                  if (n == null) {
                    return 'Nominal tidak valid — contoh: 150000 atau 150rb';
                  }
                  if (n <= 0) return 'Nominal harus lebih dari nol';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Kategori *',
                  errorText: _galatKategori,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    key: const Key('pilih_kategori_transaksi'),
                    isExpanded: true,
                    value: pilihan.any((k) => k.id == _kategoriId)
                        ? _kategoriId
                        : null,
                    hint: const Text('Pilih kategori'),
                    items: [
                      for (final k in pilihan)
                        DropdownMenuItem<int?>(
                          value: k.id,
                          child: Row(
                            children: [
                              Icon(ikonKategori(k.ikon),
                                  size: 18, color: warnaKategori(k.warna)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(k.nama)),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _kategoriId = v;
                      _galatKategori = null;
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                key: const Key('pilih_tanggal'),
                onTap: _pilihTanggal,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Tanggal *'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(fmtTanggalPendek(_tanggal)),
                      const Icon(Icons.calendar_month),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('catatan_transaksi'),
                controller: _catatan,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText: 'Contoh: makan siang bersama keluarga',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('simpan_transaksi'),
                onPressed: _menyimpan ? null : _simpan,
                icon: const Icon(Icons.save),
                label: Text(
                    widget.id == null ? 'Simpan transaksi' : 'Simpan perubahan'),
              ),
              const SizedBox(height: 8),
              Text(
                'Transaksi disimpan pada ${fmtTanggalId(_tanggal)}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}
