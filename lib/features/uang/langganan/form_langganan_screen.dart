/// Form tambah/ubah langganan berulang (FR-68).
///
/// Isi: nama, nominal, siklus, tanggal mulai, perpanjang otomatis, kategori, dan
/// catatan. Penyimpanan memakai `LanggananRepository.tambah/ubah`, jadi aturan
/// validasi (nama wajib, nominal tidak negatif) hanya ada di satu tempat:
/// repository.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/tanggal_utils.dart';
import '../../../core/utils/uang_utils.dart';
import '../../../core/utils/waktu.dart';
import '../../../data/database/database.dart';
import '../../../data/model/enums.dart';
import '../../../data/repository/kategori_transaksi_repository.dart';
import '../../../data/repository/langganan_repository.dart';

/// Label siklus langganan untuk tampilan (daftar & form memakai ini).
String labelSiklusLangganan(Frekuensi f) => switch (f) {
      Frekuensi.sekali => 'Sekali bayar',
      Frekuensi.mingguan => 'Mingguan',
      Frekuensi.duaMingguan => 'Dua mingguan',
      Frekuensi.bulanan => 'Bulanan',
      Frekuensi.duaBulanan => 'Dua bulanan',
      Frekuensi.kuartalan => 'Kuartalan (3 bulan)',
      Frekuensi.semesteran => 'Semesteran (6 bulan)',
      Frekuensi.tahunan => 'Tahunan',
      Frekuensi.kustomHari => 'Kustom (hari)',
    };

class FormLanggananScreen extends ConsumerStatefulWidget {
  const FormLanggananScreen({super.key, this.id});

  /// null = langganan baru; bukan null = ubah baris yang ada.
  final int? id;

  @override
  ConsumerState<FormLanggananScreen> createState() =>
      _FormLanggananScreenState();
}

class _FormLanggananScreenState extends ConsumerState<FormLanggananScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _nominal = TextEditingController();
  final _catatan = TextEditingController();

  Frekuensi _siklus = Frekuensi.bulanan;
  DateTime _tanggalMulai = waktuSekarang();
  bool _perpanjang = true;
  int? _kategoriId;
  bool _memuat = false;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) _muatData();
  }

  @override
  void dispose() {
    _nama.dispose();
    _nominal.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _muatData() async {
    setState(() => _memuat = true);
    final l = await LanggananRepository(ref.read(databaseProvider))
        .ambilSatu(widget.id!);
    if (!mounted) return;
    setState(() {
      _memuat = false;
      if (l == null) return;
      _nama.text = l.nama;
      // Nominal disimpan dalam sen; ditampilkan dalam rupiah utuh.
      _nominal.text = (l.nominalSen / 100).round().toString();
      _siklus = Frekuensi.dariDb(l.siklus);
      _tanggalMulai = l.tanggalMulai;
      _perpanjang = l.perpanjangOtomatis;
      _kategoriId = l.kategoriId;
      _catatan.text = l.catatan ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? 'Langganan baru' : 'Ubah langganan'),
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              // SingleChildScrollView + Column (bukan ListView): semua kolom
              // tetap hidup sehingga validasi tidak terlewat saat tergulir.
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const Key('form_nama'),
                      controller: _nama,
                      decoration: const InputDecoration(
                        labelText: 'Nama langganan *',
                        hintText: 'Contoh: Netflix',
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nama langganan wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('form_nominal'),
                      controller: _nominal,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nominal per siklus (Rp) *',
                        hintText: '186000 atau 186rb',
                      ),
                      validator: (v) {
                        final n = parseRupiah(v);
                        if (n == null || n < 0) return 'Nominal tidak valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Frekuensi>(
                      key: const Key('form_siklus'),
                      initialValue: _siklus,
                      decoration: const InputDecoration(labelText: 'Siklus'),
                      items: _pilihanSiklus
                          .map((f) => DropdownMenuItem(
                              value: f, child: Text(labelSiklusLangganan(f))))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _siklus = v ?? Frekuensi.bulanan),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      key: const Key('form_tanggal_mulai'),
                      onTap: _pilihTanggal,
                      child: InputDecorator(
                        decoration:
                            const InputDecoration(labelText: 'Tanggal mulai'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(fmtTanggalId(_tanggalMulai)),
                            const Icon(Icons.calendar_month),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      key: const Key('form_perpanjang'),
                      contentPadding: EdgeInsets.zero,
                      value: _perpanjang,
                      onChanged: (v) => setState(() => _perpanjang = v),
                      title: const Text('Perpanjang otomatis'),
                      subtitle: const Text(
                          'Siklus berikutnya dibuat tanpa perlu dicatat ulang.'),
                    ),
                    const SizedBox(height: 4),
                    _pilihanKategori(),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('form_catatan'),
                      controller: _catatan,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'Catatan (opsional)'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nominal disimpan sebagai perkiraan biaya per siklus; '
                      'total per bulan dihitung otomatis dari siklus ini.',
                      style: tema.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('form_simpan'),
                      onPressed: _simpan,
                      icon: const Icon(Icons.save),
                      label: Text(widget.id == null
                          ? 'Simpan langganan'
                          : 'Simpan perubahan'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Siklus yang masuk akal untuk langganan (tanpa "sekali bayar" & kustom
  /// hari, yang belum punya perilaku penjadwalan teruji).
  static const _pilihanSiklus = <Frekuensi>[
    Frekuensi.bulanan,
    Frekuensi.tahunan,
    Frekuensi.mingguan,
    Frekuensi.duaMingguan,
    Frekuensi.duaBulanan,
    Frekuensi.kuartalan,
    Frekuensi.semesteran,
  ];

  Widget _pilihanKategori() {
    final kategori = ref.watch(kategoriTransaksiLanggananProvider);
    return kategori.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const Text('Daftar kategori tidak bisa dimuat.'),
      data: (daftar) => DropdownButtonFormField<int?>(
        key: const Key('form_kategori'),
        initialValue: _kategoriId,
        decoration: const InputDecoration(labelText: 'Kategori (opsional)'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Tanpa kategori')),
          ...daftar.map(
              (k) => DropdownMenuItem(value: k.id, child: Text(k.nama))),
        ],
        onChanged: (v) => setState(() => _kategoriId = v),
      ),
    );
  }

  Future<void> _pilihTanggal() async {
    final pilih = await showDatePicker(
      context: context,
      initialDate: _tanggalMulai,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('id', 'ID'),
    );
    if (pilih != null) setState(() => _tanggalMulai = pilih);
  }

  Future<void> _simpan() async {
    final valid = _formKey.currentState?.validate() ?? false;
    final nominalMentah = parseRupiah(_nominal.text);
    if (!valid ||
        _nama.text.trim().isEmpty ||
        nominalMentah == null ||
        nominalMentah < 0) {
      _formKey.currentState?.validate();
      return;
    }
    final repo = LanggananRepository(ref.read(databaseProvider));
    final sen = rupiahKeSen(nominalMentah);
    final catatan = _catatan.text.trim();
    try {
      if (widget.id == null) {
        await repo.tambah(
          nama: _nama.text.trim(),
          nominalSen: sen,
          tanggalMulai: _tanggalMulai,
          siklus: _siklus,
          perpanjangOtomatis: _perpanjang,
          kategoriId: _kategoriId,
          catatan: catatan.isEmpty ? null : catatan,
        );
      } else {
        await repo.ubah(
          widget.id!,
          nama: _nama.text.trim(),
          nominalSen: sen,
          siklus: _siklus,
          perpanjangOtomatis: _perpanjang,
          kategoriId: _kategoriId,
          // Pilihan "Tanpa kategori" berarti kosongkan, bukan "tidak diubah".
          kosongkanKategori: _kategoriId == null,
          catatan: catatan,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.id == null
              ? 'Langganan tersimpan.'
              : 'Perubahan tersimpan.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Tidak bisa menyimpan: $e')));
    }
  }
}

/// Kategori kas untuk pilihan di form (hanya yang belum diarsipkan).
final kategoriTransaksiLanggananProvider =
    StreamProvider.autoDispose<List<KategoriTransaksiData>>((ref) =>
        KategoriTransaksiRepository(ref.watch(databaseProvider)).watchAktif());
