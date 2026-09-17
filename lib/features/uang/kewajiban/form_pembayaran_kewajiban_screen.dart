/// Form catat pembayaran kewajiban (FR-74).
///
/// Dua angka dipisah dengan sengaja:
/// * **jumlah pembayaran** = uang yang benar-benar keluar;
/// * **bagian pokok** = bagian yang mengurangi sisa utang. Sisanya dicatat
///   sebagai bagian bunga.
///
/// Kolom bagian pokok boleh dikosongkan: bawaannya seluruh jumlah dianggap
/// pokok, kecuali bila jumlahnya melebihi sisa utang - dalam hal itu sisanya
/// otomatis menjadi bagian bunga (dan pengguna bisa mengubahnya sendiri).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/tanggal_utils.dart';
import '../../../core/utils/uang_utils.dart';
import '../../../core/utils/waktu.dart';
import 'provider_uang_lanjutan.dart';

class FormPembayaranKewajibanScreen extends ConsumerStatefulWidget {
  const FormPembayaranKewajibanScreen({
    super.key,
    required this.kewajibanId,
    required this.namaKewajiban,
    required this.sisaSen,
    this.jamSekarang,
  });

  final int kewajibanId;
  final String namaKewajiban;

  /// Sisa utang saat form dibuka - dipakai sebagai batas bagian pokok.
  final int sisaSen;

  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<FormPembayaranKewajibanScreen> createState() =>
      FormPembayaranKewajibanScreenState();
}

class FormPembayaranKewajibanScreenState
    extends ConsumerState<FormPembayaranKewajibanScreen> {
  final GlobalKey<FormState> kunciForm = GlobalKey<FormState>();
  final TextEditingController jumlah = TextEditingController();
  final TextEditingController pokok = TextEditingController();
  final TextEditingController catatan = TextEditingController();

  late DateTime tanggal = widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void dispose() {
    jumlah.dispose();
    pokok.dispose();
    catatan.dispose();
    super.dispose();
  }

  Future<void> pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: tanggal,
      firstDate: DateTime(tanggal.year - 5),
      lastDate: DateTime(tanggal.year + 5),
    );
    if (hasil != null) setState(() => tanggal = hasil);
  }

  Future<void> simpan() async {
    final sah = kunciForm.currentState?.validate() ?? false;
    final jumlahMentah = parseRupiah(jumlah.text);
    if (!sah || jumlahMentah == null) return;
    final jumlahSen = rupiahKeSen(jumlahMentah);

    // Bagian pokok dikosongkan = biarkan repositori memakai aturan bakunya
    // (seluruh jumlah dianggap pokok, dibatasi sisa utang).
    final pokokMentah = parseRupiah(pokok.text);
    final pokokSen =
        pokokMentah == null ? null : rupiahKeSen(pokokMentah);

    try {
      await ref.read(pembayaranKewajibanRepoProvider).catatPembayaran(
            kewajibanId: widget.kewajibanId,
            tanggal: tanggal,
            jumlahSen: jumlahSen,
            pokokSen: pokokSen,
            catatan: catatan.text.trim().isEmpty ? null : catatan.text.trim(),
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pembayaran tersimpan.')));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Catat pembayaran')),
      body: Form(
        key: kunciForm,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.credit_score_outlined),
                title: Text(widget.namaKewajiban),
                subtitle: Text(
                    'Sisa utang ${fmtRpDariSen(widget.sisaSen)}'),
              ),
            ),
            const SizedBox(height: 12),
            Text('Tanggal pembayaran', style: tema.textTheme.labelLarge),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              key: const Key('tanggal_pembayaran'),
              onPressed: pilihTanggal,
              icon: const Icon(Icons.event),
              label: Text(fmtTanggalAman(tanggal)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('jumlah_pembayaran'),
              controller: jumlah,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jumlah pembayaran (Rp) *',
                helperText: 'Uang yang benar-benar keluar.',
              ),
              validator: (v) {
                final n = parseRupiah(v);
                if (n == null || n <= 0) return 'Isi jumlah lebih dari nol';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('pokok_pembayaran'),
              controller: pokok,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Bagian pokok (Rp)',
                helperText: 'Kosongkan bila seluruh pembayaran adalah pokok. '
                    'Bagian bunga = jumlah - pokok.',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = parseRupiah(v);
                if (n == null || n < 0) return 'Bagian pokok belum benar';
                final pokokSen = rupiahKeSen(n);
                final jumlahSen = rupiahKeSen(parseRupiah(jumlah.text) ?? 0);
                if (pokokSen > jumlahSen) {
                  return 'Bagian pokok tidak lebih besar dari jumlah';
                }
                if (pokokSen > widget.sisaSen) {
                  return 'Bagian pokok melebihi sisa utang';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('catatan_pembayaran'),
              controller: catatan,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('simpan_pembayaran'),
              onPressed: simpan,
              icon: const Icon(Icons.save),
              label: const Text('Simpan pembayaran'),
            ),
          ],
        ),
      ),
    );
  }
}
