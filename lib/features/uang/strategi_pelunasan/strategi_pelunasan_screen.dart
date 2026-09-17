/// Layar simulasi strategi pelunasan (FR-75).
///
/// Layar ini tipis dengan sengaja: seluruh hitungan ada di
/// `lib/core/uang/strategi_pelunasan.dart` (pure Dart) supaya bisa diuji tanpa
/// widget. Di sini pengguna mengisi setoran bulanan, memilih metode, lalu
/// membaca hasilnya.
///
/// Kalimat jujur yang selalu tampil: ini SIMULASI sederhana, bukan nasihat
/// keuangan; bunga dianggap tetap dan biaya lain belum dihitung.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/uang/strategi_pelunasan.dart';
import '../../../core/utils/tanggal_utils.dart';
import '../../../core/utils/uang_utils.dart';
import '../../../core/utils/waktu.dart';
import '../../../data/repository/pembayaran_kewajiban_repository.dart';
import '../kewajiban/provider_uang_lanjutan.dart';

class StrategiPelunasanScreen extends ConsumerStatefulWidget {
  const StrategiPelunasanScreen({super.key, this.jamSekarang});

  /// Jam uji; dianggap waktu perangkat.
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<StrategiPelunasanScreen> createState() =>
      StrategiPelunasanScreenState();
}

class StrategiPelunasanScreenState
    extends ConsumerState<StrategiPelunasanScreen> {
  final TextEditingController setoran = TextEditingController();

  bool memuat = true;
  String? galat;
  List<RingkasanKewajiban> daftar = const [];
  MetodePelunasan metode = MetodePelunasan.bolaSalju;
  HasilSimulasiPelunasan? hasil;

  /// Waktu yang dipakai saat simulasi dijalankan (bisa dikunci uji).
  DateTime get sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    muat();
  }

  @override
  void dispose() {
    setoran.dispose();
    super.dispose();
  }

  /// Baca kewajiban + sisa utangnya; sekaligus mengisi setoran awal dari
  /// jumlah minimum bayar bila ada.
  Future<void> muat() async {
    try {
      final repo =
          ref.read(pembayaranKewajibanRepoProvider);
      final hasilBaca =
          await repo.ambilRingkasan().timeout(const Duration(seconds: 5));
      var minimum = 0;
      for (final r in hasilBaca) {
        minimum += r.kewajiban.minimumBayarSen ?? 0;
      }
      if (!mounted) return;
      setState(() {
        daftar = hasilBaca;
        memuat = false;
        galat = null;
        if (setoran.text.isEmpty && minimum > 0) {
          setoran.text = (minimum / 100).round().toString();
        }
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        memuat = false;
        galat = 'Belum ada data';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        memuat = false;
        galat = 'Belum ada data ($e)';
      });
    }
  }

  void hitung() {
    final angka = parseRupiah(setoran.text);
    final setoranSen = angka == null ? 0 : rupiahKeSen(angka);
    final aktif = [
      for (final r in daftar)
        if (r.sisaSen > 0)
          KewajibanRingkas(
            id: r.kewajiban.id,
            nama: r.kewajiban.nama,
            sisaSen: r.sisaSen,
            bungaPersenTahun: r.kewajiban.sukuBungaPersenTahun,
            minimumBayarSen: r.kewajiban.minimumBayarSen,
          ),
    ];
    try {
      final r = simulasiPelunasan(
        kewajiban: aktif,
        setoranBulananSen: setoranSen,
        metode: metode,
      );
      setState(() => hasil = r);
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => hasil = null);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${e.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Strategi pelunasan')),
      body: memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                if (galat != null)
                  Card(
                    key: const Key('pesan_galat'),
                    child: ListTile(
                      leading: const Icon(Icons.inbox_outlined),
                      title: Text(galat!),
                      subtitle: const Text('Kewajiban belum bisa dibaca.'),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Setoran bulanan untuk utang',
                            style: tema.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('setoran_bulanan'),
                          controller: setoran,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Setoran per bulan (Rp)',
                            helperText: 'Uang yang disiapkan tiap bulan untuk '
                                'seluruh kewajiban di daftar ini.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<MetodePelunasan>(
                          key: const Key('metode_pelunasan'),
                          initialValue: metode,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Metode'),
                          items: [
                            for (final m in MetodePelunasan.values)
                              DropdownMenuItem(
                                value: m,
                                child: Text('${m.label} - ${m.penjelasan}'),
                              ),
                          ],
                          onChanged: (v) => setState(
                              () => metode = v ?? MetodePelunasan.bolaSalju),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const Key('hitung_simulasi'),
                          onPressed: daftar.isEmpty ? null : hitung,
                          icon: const Icon(Icons.calculate_outlined),
                          label: const Text('Hitung simulasi'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (daftar.isEmpty)
                  const Card(
                    key: Key('kosong_kewajiban'),
                    child: ListTile(
                      leading: Icon(Icons.inbox_outlined),
                      title: Text('Belum ada data'),
                      subtitle: Text('Belum ada kewajiban yang dicatat, jadi '
                          'belum ada yang bisa disimulasikan.'),
                    ),
                  ),
                if (hasil == null)
                  const Card(
                    key: Key('belum_dihitung'),
                    child: ListTile(
                      leading: Icon(Icons.insights_outlined),
                      title: Text('Simulasi belum dihitung'),
                      subtitle: Text('Isi setoran bulanan, lalu tekan '
                          '"Hitung simulasi".'),
                    ),
                  )
                else
                  _kartuHasil(hasil!),
                const SizedBox(height: 12),
                Card(
                  key: const Key('catatan_simulasi'),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Catatan: ini simulasi sederhana dengan angka '
                        'yang Anda isi sendiri, bukan nasihat keuangan. '
                        'Bunga dianggap tetap sepanjang waktu; biaya, denda, '
                        'pemasukan baru, dan dana darurat belum dihitung. '
                        'Hasil nyata bisa berbeda.'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _kartuHasil(HasilSimulasiPelunasan h) {
    final tema = Theme.of(context);
    return Card(
      key: const Key('hasil_simulasi'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hasil simulasi (${h.metode.label})',
                style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              h.jumlahKewajiban == 0
                  ? 'Belum ada data'
                  : (h.lunasSemua
                      ? 'Tuntas dalam ${h.jumlahBulan} bulan'
                      : 'Belum tuntas dalam ${h.jumlahBulan} bulan (batas '
                          'simulasi ${h.batasBulan} bulan)'),
              key: const Key('jumlah_bulan'),
              style: tema.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text('Total bunga ${fmtRpDariSen(h.totalBungaSen)}',
                key: const Key('total_bunga')),
            Text('Total dibayar ${fmtRpDariSen(h.totalDibayarSen)}',
                key: const Key('total_dibayar')),
            if (h.sisaAkhirSen > 0)
              Text('Sisa utang setelah simulasi ${fmtRpDariSen(h.sisaAkhirSen)}',
                  key: const Key('sisa_akhir')),
            const SizedBox(height: 12),
            Text('Data per ${fmtTanggalAman(sekarang)}',
                style: tema.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text('Urutan pelunasan', style: tema.textTheme.labelLarge),
            const SizedBox(height: 4),
            for (var i = 0; i < h.langkah.length; i++)
              Text(
                '${i + 1}. ${h.langkah[i].nama} - '
                '${h.langkah[i].sudahTuntas ? 'tuntas bulan ke-${h.langkah[i].bulanKe}' : 'belum tuntas'}'
                ' (sisa awal ${fmtRpDariSen(h.langkah[i].sisaAwalSen)})',
                key: Key('urutan_${h.langkah[i].kewajibanId}'),
              ),
          ],
        ),
      ),
    );
  }
}
