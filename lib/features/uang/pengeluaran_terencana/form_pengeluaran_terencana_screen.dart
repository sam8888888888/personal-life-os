/// Form tambah/ubah pengeluaran terencana — fitur tambahan di luar nomor FR PRD.
///
/// Uang yang harus tersedia sebelum tanggal tertentu, tetapi belum menjadi
/// transaksi. Kolom "aktif" mematikan baris dari hitungan tanpa menghapusnya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/tanggal_utils.dart';
import '../../../core/utils/uang_utils.dart';
import '../../../core/utils/waktu.dart';
import '../../../data/database/database.dart';
import '../../../data/repository/pengeluaran_terencana_repository.dart';
import '../kewajiban/provider_uang_lanjutan.dart';

/// Nilai penanda untuk "tanpa kategori" pada daftar pilihan kategori.
const int kategoriKosong = 0;

class FormPengeluaranTerencanaScreen extends ConsumerStatefulWidget {
  const FormPengeluaranTerencanaScreen({
    super.key,
    this.pengeluaran,
    this.jamSekarang,
  });

  /// null = tambah baru, bukan null = ubah.
  final PengeluaranTerencanaData? pengeluaran;

  /// Jam uji; dianggap waktu perangkat.
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<FormPengeluaranTerencanaScreen> createState() =>
      FormPengeluaranTerencanaScreenState();
}

class FormPengeluaranTerencanaScreenState
    extends ConsumerState<FormPengeluaranTerencanaScreen> {
  final GlobalKey<FormState> kunciForm = GlobalKey<FormState>();
  final TextEditingController nama = TextEditingController();
  final TextEditingController jumlah = TextEditingController();
  final TextEditingController catatan = TextEditingController();

  late DateTime tanggal =
      widget.pengeluaran?.tanggal ?? (widget.jamSekarang?.call() ?? waktuSekarang());
  late int kategori = widget.pengeluaran?.kategoriId ?? kategoriKosong;
  late bool aktif = widget.pengeluaran?.aktif ?? true;

  bool get baru => widget.pengeluaran == null;

  PengeluaranTerencanaRepository get repo =>
      ref.read(pengeluaranTerencanaRepoProvider);

  @override
  void initState() {
    super.initState();
    final p = widget.pengeluaran;
    if (p == null) return;
    nama.text = p.nama;
    jumlah.text = (p.jumlahSen / 100).round().toString();
    catatan.text = p.catatan ?? '';
  }

  @override
  void dispose() {
    nama.dispose();
    jumlah.dispose();
    catatan.dispose();
    super.dispose();
  }

  Future<void> pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: tanggal,
      firstDate: DateTime(tanggal.year - 3),
      lastDate: DateTime(tanggal.year + 5),
    );
    if (hasil != null) setState(() => tanggal = tanggalSaja(hasil));
  }

  Future<void> simpan() async {
    final sah = kunciForm.currentState?.validate() ?? false;
    final jumlahMentah = parseRupiah(jumlah.text);
    if (!sah || jumlahMentah == null) return;
    final jumlahSen = rupiahKeSen(jumlahMentah);
    final kategoriId = kategori == kategoriKosong ? null : kategori;
    try {
      if (baru) {
        await repo.tambah(
          nama: nama.text.trim(),
          jumlahSen: jumlahSen,
          tanggal: tanggal,
          kategoriId: kategoriId,
          catatan: catatan.text.trim(),
          aktif: aktif,
        );
      } else {
        await repo.ubah(
          widget.pengeluaran!.id,
          nama: nama.text.trim(),
          jumlahSen: jumlahSen,
          tanggal: tanggal,
          kategoriId: kategoriId,
          catatan: catatan.text.trim(),
          aktif: aktif,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(baru ? 'Rencana tersimpan.' : 'Perubahan tersimpan.')));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final kategoriDaftar = ref.watch(kategoriTransaksiUangLanjutanProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(baru ? 'Tambah pengeluaran' : 'Ubah pengeluaran'),
      ),
      body: Form(
        key: kunciForm,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            TextFormField(
              key: const Key('nama_pengeluaran'),
              controller: nama,
              decoration: const InputDecoration(
                labelText: 'Nama pengeluaran *',
                hintText: 'Contoh: Servis motor',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama perlu diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('jumlah_pengeluaran'),
              controller: jumlah,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jumlah yang disiapkan (Rp) *',
                hintText: '1500000 atau 1,5jt',
              ),
              validator: (v) {
                final n = parseRupiah(v);
                if (n == null || n <= 0) return 'Isi jumlah lebih dari nol';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const Key('kategori_pengeluaran'),
              initialValue: kategori,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                const DropdownMenuItem(
                    value: kategoriKosong, child: Text('Tanpa kategori')),
                for (final k in kategoriDaftar.value ??
                    const <KategoriTransaksiData>[])
                  DropdownMenuItem(value: k.id, child: Text(k.nama)),
              ],
              onChanged: (v) => setState(() => kategori = v ?? kategoriKosong),
            ),
            const SizedBox(height: 12),
            Text('Tanggal', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              key: const Key('tanggal_pengeluaran'),
              onPressed: pilihTanggal,
              icon: const Icon(Icons.event),
              label: Text(fmtTanggalAman(tanggal)),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              key: const Key('aktif_pengeluaran'),
              value: aktif,
              onChanged: (v) => setState(() => aktif = v),
              title: const Text('Ikut dihitung'),
              subtitle: const Text('Matikan bila rencana ini belum ingin '
                  'dihitung dalam total persiapan.'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('catatan_pengeluaran'),
              controller: catatan,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('simpan_pengeluaran'),
              onPressed: simpan,
              icon: const Icon(Icons.save),
              label: Text(baru ? 'Simpan rencana' : 'Simpan perubahan'),
            ),
          ],
        ),
      ),
    );
  }
}
