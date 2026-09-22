/// FR-115 — Mode Kunjungan Dokter (satu halaman ringkasan 30 hari).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/kesehatan/ringkasan_kunjungan.dart';
import '../../core/laporan/pdf_kunjungan.dart';
import '../../core/platform/bagikan.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/repository/kesehatan_pemantau_repository.dart';

/// Batas tunggu pekerjaan berkas (dipakai uji & HP) — sama pola dengan laporan.
const Duration batasTungguKunjungan = Duration(seconds: 20);

class KunjunganScreen extends ConsumerStatefulWidget {
  const KunjunganScreen({super.key, this.direktoriSementara});

  /// Dipakai uji supaya tidak menyentuh direktori sungguhan.
  final Future<Directory> Function()? direktoriSementara;

  @override
  ConsumerState<KunjunganScreen> createState() => KunjunganScreenState();
}

class KunjunganScreenState extends ConsumerState<KunjunganScreen> {
  RingkasanKunjungan? _ringkas;
  bool _siap = false;
  String? _galat;
  String _catatan = '';
  final TextEditingController _kendali = TextEditingController();

  @override
  void initState() {
    super.initState();
    muat();
  }

  @override
  void dispose() {
    _kendali.dispose();
    super.dispose();
  }

  /// Kumpulkan data 30 hari terakhir → ringkasan.
  Future<void> muat({int hari = 30}) async {
    try {
      final repo = KesehatanPemantauRepository(ref.read(databaseProvider));
      final ringkas = susunRingkasanKunjungan(
        sekarang: DateTime.now(),
        hari: hari,
        berat: await repo.berat(hari: hari + 10),
        tidur: await repo.tidur(hari: hari + 10),
        aktivitas: await repo.aktivitas(hari: hari + 10),
        sistolik: await repo.tekanan(hari: hari + 10),
        diastolik: await repo.tekanan(hari: hari + 10, kedua: true),
        suasana: await repo.suasana(hari: hari + 10),
        keluhan: await repo.keluhan(hari: hari),
      );
      if (!mounted) return;
      setState(() {
        _ringkas = ringkas;
        _siap = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = 'Data belum bisa dibaca: $e';
        _siap = true;
      });
    }
  }

  /// Simpan PDF ke berkas sementara dan buka lembar berbagi.
  ///
  /// Mengembalikan jalur berkas bila berhasil, atau null + pesan galat.
  Future<(String?, String)> bagikanPdf() async {
    final ringkas = _ringkas;
    if (ringkas == null) return (null, 'Data belum siap.');
    try {
      final isi = await bangunPdfKunjungan(ringkas, catatanPengguna: _catatan);
      final dir = await (widget.direktoriSementara ?? getTemporaryDirectory)();
      final berkas = File(
          '${dir.path}/ringkasan-kunjungan-${fmtTanggalPendekAman(DateTime.now()).replaceAll('/', '-')}.pdf');
      await berkas.writeAsBytes(isi, flush: true).timeout(batasTungguKunjungan);
      final terkirim = await bagikanBerkas(
        jalur: berkas.path,
        judul: 'Ringkasan kunjungan dokter',
      );
      if (!terkirim) {
        return (berkas.path,
            'PDF tersimpan di ${berkas.path}, tetapi lembar berbagi belum terbuka.');
      }
      return (berkas.path, 'PDF 1 halaman siap dibagikan.');
    } catch (e) {
      return (null, 'PDF belum bisa dibuat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final r = _ringkas;
    return Scaffold(
      appBar: AppBar(title: const Text('Mode kunjungan dokter')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.description_outlined),
              title: Text('Satu halaman, angka sama dengan aplikasi'),
              subtitle: Text('Ringkasan 30 hari terakhir — berat, tekanan darah, '
                  'tidur, aktivitas, suasana hati, dan keluhan yang pernah '
                  'dicatat. Bukan diagnosis.'),
            ),
          ),
          if (_galat != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_galat!, key: const Key('kunjungan_galat')),
            ),
          if (r != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(
                'Periode ${fmtTanggalPendekAman(r.dari)} – '
                '${fmtTanggalPendekAman(r.sampai)}',
                key: const Key('kunjungan_periode'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            for (final b in r.baris)
              Card(
                key: Key('kunjungan_${b.label.replaceAll(' ', '_')}'),
                child: ListTile(
                  title: Text(b.label),
                  subtitle: Text(b.nilai),
                  trailing: Text(b.catatan),
                ),
              ),
            if (r.keluhan.isNotEmpty)
              Card(
                key: const Key('kunjungan_keluhan'),
                child: ListTile(
                  title: const Text('Keluhan yang pernah dicatat'),
                  subtitle: Text(r.keluhan.take(5).join('\n')),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('kunjungan_catatan'),
              controller: _kendali,
              maxLines: 3,
              onChanged: (v) => _catatan = v,
              decoration: const InputDecoration(
                labelText: 'Catatan tambahan sebelum dicetak (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('kunjungan_bagikan'),
              onPressed: () async {
                final (jalur, pesan) = await bagikanPdf();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(pesan),
                  duration: const Duration(seconds: 4),
                ));
                setState(() => _pesanTerakhir = '$pesan ${jalur ?? ''}'.trim());
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Buat PDF 1 halaman & bagikan'),
            ),
            if (_pesanTerakhir.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_pesanTerakhir,
                    key: const Key('kunjungan_hasil_bagikan')),
              ),
          ],
        ],
      ),
    );
  }

  String _pesanTerakhir = '';
}
