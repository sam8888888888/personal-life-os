/// Form atur/ubah anggaran satu kategori pada satu bulan (FR-72).
///
/// Aturan validasi (PRD FR-72): kategori wajib dipilih dan batas nominal harus
/// lebih dari nol. Nominal diurai dengan [parseRupiah] (menerima "1500000",
/// "1.500.000", atau "1,5jt") lalu disimpan dalam sen lewat
/// [AnggaranRepository.simpan] (idempoten: satu baris per periode+kategori).
///
/// Catatan: berkas ini TIDAK mengimpor `anggaran_screen.dart` (agar tidak ada
/// impor melingkar) — repositori dibuat langsung dari `databaseProvider`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/uang_utils.dart';
import '../../../data/database/database.dart';
import '../../../data/model/enums.dart';
import '../../../data/repository/anggaran_repository.dart';
import '../../../data/repository/kategori_transaksi_repository.dart';

class FormAnggaranScreen extends ConsumerStatefulWidget {
  const FormAnggaranScreen({super.key, required this.periode, this.kategoriId});

  /// Bulan yang diatur, kunci 'YYYY-MM'.
  final String periode;

  /// null = pengguna memilih kategori sendiri (tambah baru).
  /// Terisi = kategori sudah ditentukan layar sebelumnya (kategori itu bisa
  /// berupa 0 = baris "Total bulan").
  final int? kategoriId;

  @override
  ConsumerState<FormAnggaranScreen> createState() => _FormAnggaranScreenState();
}

class _FormAnggaranScreenState extends ConsumerState<FormAnggaranScreen> {
  final _formKey = GlobalKey<FormState>();
  final _batas = TextEditingController();

  List<KategoriTransaksiData> _kategori = const [];
  AnggaranBulananData? _baris;
  int? _kategoriId;
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _kategoriId = widget.kategoriId;
    _muat();
  }

  @override
  void dispose() {
    _batas.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    final db = ref.read(databaseProvider);
    final daftar = await KategoriTransaksiRepository(db)
        .ambilSemua(jenis: JenisArus.pengeluaran);
    AnggaranBulananData? baris;
    if (widget.kategoriId != null) {
      for (final a in await AnggaranRepository(db).ambilPeriode(widget.periode)) {
        if (a.kategoriId == widget.kategoriId) {
          baris = a;
          break;
        }
      }
    }
    // PB-14: jangan menyentuh state bila layar sudah ditutup.
    if (!mounted) return;
    setState(() {
      _kategori = daftar;
      _baris = baris;
      _memuat = false;
      _batas.text = (baris == null || baris.batasSen <= 0)
          ? ''
          : (baris.batasSen / 100).round().toString();
    });
  }

  /// Nama kategori untuk ditampilkan (0 = baris total).
  String _namaKategori(int id) {
    if (id == AnggaranRepository.kategoriTotal) {
      return 'Total bulan (semua kategori)';
    }
    for (final k in _kategori) {
      if (k.id == id) return k.nama;
    }
    return 'Kategori #$id';
  }

  Future<void> _simpan() async {
    final cocok = _formKey.currentState!.validate();
    final nominal = parseRupiah(_batas.text);
    if (!cocok || _kategoriId == null || nominal == null || nominal <= 0) {
      _formKey.currentState!.validate();
      return;
    }
    try {
      await AnggaranRepository(ref.read(databaseProvider)).simpan(
        periode: widget.periode,
        kategoriId: _kategoriId!,
        batasSen: rupiahKeSen(nominal),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Anggaran tersimpan.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  Future<void> _hapus() async {
    final id = _baris?.id;
    if (id == null) return;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus anggaran ini?'),
        content: Text(
            'Baris anggaran ${_namaKategori(_kategoriId ?? 0)} pada bulan '
            '${widget.periode} akan dihapus. Transaksi yang sudah tercatat '
            'tetap utuh, dan anggaran bisa diisi lagi kapan saja.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Batal')),
          FilledButton(
              key: const Key('konfirmasi_hapus'),
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (yakin != true) return;
    await AnggaranRepository(ref.read(databaseProvider)).hapus(id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ubah = _baris != null;
    return Scaffold(
      appBar: AppBar(title: Text(ubah ? 'Ubah anggaran' : 'Atur anggaran')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              // SingleChildScrollView + Column: semua kolom tetap hidup walau
              // tergulir keluar layar, jadi validasi tidak terlewat.
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Bulan anggaran: ${widget.periode}',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (widget.kategoriId != null)
                      InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Kategori', border: OutlineInputBorder()),
                        child: Text(_namaKategori(widget.kategoriId!)),
                      )
                    else
                      DropdownButtonFormField<int>(
                        key: const Key('pilih_kategori'),
                        initialValue: _kategoriId,
                        // isExpanded: label terpanjang ("Total bulan (semua
                        // kategori)") tetap muat di layar 420px.
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Kategori *',
                            hintText: 'Pilih kategori pengeluaran'),
                        // Kategori total (0) sengaja berdiri sendiri di paling
                        // atas dan diberi label jelas, bukan disamarkan sebagai
                        // kategori biasa.
                        items: [
                          const DropdownMenuItem(
                            value: AnggaranRepository.kategoriTotal,
                            child: Text('Total bulan (semua kategori)'),
                          ),
                          ..._kategori.map((k) => DropdownMenuItem(
                              value: k.id, child: Text(k.nama))),
                        ],
                        validator: (v) =>
                            v == null ? 'Kategori wajib dipilih' : null,
                        onChanged: (v) => setState(() => _kategoriId = v),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('batas_anggaran'),
                      controller: _batas,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Batas anggaran (Rp) *',
                        hintText: '1500000 atau 1,5jt',
                      ),
                      validator: (v) {
                        final n = parseRupiah(v);
                        if (n == null || n <= 0) {
                          return 'Batas anggaran tidak valid (harus lebih dari 0)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Anggaran berlaku untuk bulan ini saja '
                      '(${widget.periode}). Bulan lain bisa diatur sendiri.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _simpan,
                      icon: const Icon(Icons.save),
                      label: Text(ubah ? 'Simpan perubahan' : 'Simpan anggaran'),
                    ),
                    if (ubah) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const Key('hapus_anggaran'),
                        onPressed: _hapus,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Hapus anggaran ini'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
