/// FR-124 — Daftar Aset (rumah, kendaraan, perangkat, furnitur, elektronik).
///
/// Satu layar berisi: total nilai aset fisik, daftar aset beserta status
/// garansi & perkiraan umur pakai, dan pintu ke perawatan tiap aset.
///
/// Nada teks mengikuti PRD §III-11: menyebut angka & keadaan, tanpa menilai.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/rumah/aset_fisik.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';
import 'rumah_providers.dart';

class RumahAsetScreen extends ConsumerStatefulWidget {
  const RumahAsetScreen({super.key});

  @override
  ConsumerState<RumahAsetScreen> createState() => _RumahAsetScreenState();
}

class _RumahAsetScreenState extends ConsumerState<RumahAsetScreen> {
  late Future<List<AsetData>> _future;
  bool _sertakanArsip = false;

  @override
  void initState() {
    super.initState();
    _future = _muat();
  }

  Future<List<AsetData>> _muat() => ref
      .read(repoRumahProvider)
      .ambilAsetFisik(sertakanArsip: _sertakanArsip);

  void _muatUlang() => setState(() => _future = _muat());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aset & Rumah'),
        actions: [
          IconButton(
            key: const Key('aset_saklar_arsip'),
            tooltip: _sertakanArsip ? 'Sembunyikan arsip' : 'Tampilkan arsip',
            onPressed: () {
              setState(() {
                _sertakanArsip = !_sertakanArsip;
                _future = _muat();
              });
            },
            icon: Icon(_sertakanArsip ? Icons.visibility : Icons.visibility_off),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('aset_tambah'),
        onPressed: () async {
          final tersimpan = await context.push<bool>('/rumah/aset/form');
          if (tersimpan == true) _muatUlang();
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah aset'),
      ),
      body: FutureBuilder<List<AsetData>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Daftar aset belum bisa dibuka: ${snap.error}'),
              ),
            );
          }
          final daftar = snap.data ?? const <AsetData>[];
          final total = daftar.fold<int>(0, (a, b) => a + (b.hargaBeliSen ?? 0));
          final sekarang = DateTime.now();
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              Card(
                child: ListTile(
                  key: const Key('aset_total'),
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Total nilai aset fisik'),
                  subtitle: Text('${daftar.length} aset · masuk ke Kekayaan Bersih'),
                  trailing: Text(fmtRpDariSen(total),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
              if (daftar.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32, horizontal: 8),
                  child: Text(
                    'Belum ada aset tercatat. Tombol "Tambah aset" mengisi nama, '
                    'tanggal beli, harga, nomor seri, garansi, dan masa pakai.',
                  ),
                ),
              for (final a in daftar) _barisAset(context, a, sekarang),
            ],
          );
        },
      ),
    );
  }

  Widget _barisAset(BuildContext context, AsetData a, DateTime sekarang) {
    final jenis = JenisAsetFisik.dariKode(a.jenis);
    final garansi = periksaGaransi(a.garansiSampai, sekarang);
    final umur = perkiraanUmurPakai(
      tanggalBeli: a.tanggalBeli,
      masaPakaiBulan: a.masaPakaiBulan,
      hargaBeliSen: a.hargaBeliSen,
      sekarang: sekarang,
    );
    final bagian = <String>[
      if (jenis != null) jenis.label,
      if (a.hargaBeliSen != null) fmtRpDariSen(a.hargaBeliSen!),
      if (a.garansiSampai != null) garansi.keterangan,
      if (umur != null)
        umur.sudahLewat
            ? 'Perkiraan ganti sudah lewat ${-umur.sisaBulan} bulan'
            : 'Perkiraan ganti ${umur.sisaBulan} bulan lagi',
    ];
    return Card(
      child: ListTile(
        key: Key('aset_baris_${a.id}'),
        leading: Icon(_ikonJenis(jenis)),
        title: Text(a.nama),
        subtitle: Text(bagian.isEmpty ? 'Belum ada keterangan' : bagian.join(' · ')),
        trailing: garansi.perluPerhatian
            ? Chip(
                label: Text(garansi.status == StatusGaransi.berakhir
                    ? 'Garansi berakhir'
                    : 'Garansi dekat'),
                visualDensity: VisualDensity.compact,
              )
            : const Icon(Icons.chevron_right),
        onTap: () async {
          await context.push('/rumah/aset/${a.id}');
          _muatUlang();
        },
      ),
    );
  }

  IconData _ikonJenis(JenisAsetFisik? j) => switch (j) {
        JenisAsetFisik.rumah => Icons.home_outlined,
        JenisAsetFisik.kendaraan => Icons.directions_car_outlined,
        JenisAsetFisik.perangkat => Icons.smartphone_outlined,
        JenisAsetFisik.furnitur => Icons.chair_outlined,
        JenisAsetFisik.elektronik => Icons.tv_outlined,
        _ => Icons.inventory_2_outlined,
      };
}
