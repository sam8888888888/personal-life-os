/// Layar Hari Ini (FR-60) + Kartu Pilar (FR-61) + Perhatian (FR-62).
///
/// Sumber angka: tabel tagihan yang sudah ada (F1/F2) + status izin pengingat
/// (F3). Pilar yang modulnya belum ada menampilkan "Belum ada data" (III-11).
library;

import 'package:flutter/material.dart';
import 'package:personal_life_os/core/utils/waktu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/hari_ini/model_hari_ini.dart';
import '../../core/hari_ini/penyusun_hari_ini.dart';
import '../../core/ibadah/kalender_hijriah.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import 'kartu_pilar.dart';
import 'pemetaan_tagihan.dart';
import 'warna_tingkat.dart';

class HariIniScreen extends ConsumerStatefulWidget {
  const HariIniScreen({
    super.key,
    this.jamSekarang,
    this.ambilJumlahSholatTercatat,
    this.namaPanggilan = 'Anda',
  });

  /// Jam yang disuntik uji. Dianggap TANGGAL SIPIL perangkat (bukan instan
  /// UTC), karena agenda menanyakan "hari apa sekarang di perangkat".
  final DateTime Function()? jamSekarang;

  /// Pembacaan catatan sholat (FR-88). null = modul belum dipasang.
  final Future<int?> Function()? ambilJumlahSholatTercatat;

  final String namaPanggilan;

  @override
  ConsumerState<HariIniScreen> createState() => _HariIniScreenState();
}

class _HariIniScreenState extends ConsumerState<HariIniScreen> {
  int? _jumlahSholat;
  bool _sudahBacaSholat = false;

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _bacaCatatanSholat();
  }

  Future<void> _bacaCatatanSholat() async {
    final f = widget.ambilJumlahSholatTercatat;
    if (f == null) return;
    try {
      final n = await f();
      if (!mounted) return;
      setState(() {
        _jumlahSholat = n;
        _sudahBacaSholat = true;
      });
    } catch (_) {
      // Catatan gagal dibaca bukan alasan menampilkan galat ke pengguna.
      if (!mounted) return;
      setState(() => _sudahBacaSholat = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagihanAsync = ref.watch(semuaTagihanProvider);
    final izinAsync = ref.watch(statusIzinPengingatProvider);
    final izin = izinAsync.value;
    final tagihan = petaDaftarTagihan(tagihanAsync.value ?? const <TagihanData>[]);

    final data = DataHariIni(
      sekarang: _sekarang,
      tagihan: tagihan,
      jumlahSholatTercatat: _jumlahSholat,
      statusIzinPengingat: izin == null ? null : (izin.siap ? 'diizinkan' : 'belum'),
      namaPanggilan: widget.namaPanggilan,
    );
    final ringkas = susunHariIni(data);
    final hijri = hijriahDariMasehi(_sekarang);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hari Ini'),
        actions: [
          IconButton(
            tooltip: 'Ringkasan pagi',
            onPressed: () => context.push('/briefing'),
            icon: const Icon(Icons.wb_twilight),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          _Kepala(
            nama: widget.namaPanggilan,
            tanggal: _sekarang,
            hijriah: hijri?.label ?? 'Belum ada data Hijriah',
          ),
          const SizedBox(height: 12),
          if (_sekarang.hour < 12) ...[
            _KartuRingkasanPagi(onTap: () => context.push('/briefing')),
            const SizedBox(height: 12),
          ],
          const _JudulBlok('Pilar hari ini'),
          _GridPilar(
            pilar: ringkas.pilar,
            onTap: (p) {
              final rute = p.rute;
              if (rute == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Modul ini menyusul.')),
                );
                return;
              }
              context.push(rute);
            },
          ),
          const SizedBox(height: 16),
          _JudulBlok('Perhatian (${ringkas.perhatian.length})'),
          if (ringkas.perhatian.isEmpty)
            const _Kosong('Tidak ada yang perlu perhatian hari ini')
          else
            for (final b in ringkas.perhatian) _BarisPerhatian(butir: b),
          const SizedBox(height: 16),
          _JudulBlok('Agenda hari ini'),
          if (!ringkas.adaAgenda)
            const _Kosong('Belum ada agenda hari ini')
          else ...[
            for (final b in ringkas.agenda) _BarisAgenda(butir: b),
            if (ringkas.jumlahAgenda > ringkas.agenda.length)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.push('/kerja'),
                  child: Text('Lihat semua (${ringkas.jumlahAgenda})'),
                ),
              ),
          ],
          if (!_sudahBacaSholat && widget.ambilJumlahSholatTercatat != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Membaca catatan sholat…'),
            ),
        ],
      ),
    );
  }
}

class _Kepala extends StatelessWidget {
  const _Kepala({required this.nama, required this.tanggal, required this.hijriah});

  final String nama;
  final DateTime tanggal;
  final String hijriah;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Assalamualaikum, $nama', style: tema.textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(fmtTanggalAman(tanggal), style: tema.textTheme.bodyMedium),
        Text(
          '$hijriah · perhitungan, bukan penetapan resmi',
          style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.outline),
        ),
      ],
    );
  }
}

class _KartuRingkasanPagi extends StatelessWidget {
  const _KartuRingkasanPagi({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.wb_twilight),
          title: const Text('Ringkasan pagi'),
          subtitle: const Text('Agenda, tagihan 7 hari, dan waktu sholat berikutnya'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

class _JudulBlok extends StatelessWidget {
  const _JudulBlok(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(teks, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _Kosong extends StatelessWidget {
  const _Kosong(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(teks, style: tema.textTheme.bodyMedium),
    );
  }
}

/// Dua kolom, tinggi mengikuti isi (Wrap dipilih agar tidak ada pemotongan).
class _GridPilar extends StatelessWidget {
  const _GridPilar({required this.pilar, required this.onTap});

  final List<NilaiPilar> pilar;
  final void Function(NilaiPilar) onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, kendala) {
          const jarak = 8.0;
          final lebar = (kendala.maxWidth - jarak) / 2;
          return Wrap(
            spacing: jarak,
            runSpacing: jarak,
            children: [
              for (final p in pilar)
                SizedBox(
                  width: lebar,
                  child: KartuPilar(nilai: p, onTap: () => onTap(p)),
                ),
            ],
          );
        },
      );
}

class _BarisAgenda extends StatelessWidget {
  const _BarisAgenda({required this.butir});

  final ButirAgenda butir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final warna = warnaTingkat(butir.tingkat, tema);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: butir.rute == null ? null : () => context.push(butir.rute!),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ikonButir(butir.jenis), color: warna, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      butir.judul,
                      style: tema.textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(butir.alasan, style: tema.textTheme.bodySmall, maxLines: 2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarisPerhatian extends StatelessWidget {
  const _BarisPerhatian({required this.butir});

  final ButirPerhatian butir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final warna = warnaTingkat(butir.tingkat, tema);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.priority_high, size: 18, color: warna),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    butir.judul,
                    style: tema.textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(butir.alasan, style: tema.textTheme.bodySmall, maxLines: 3),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: butir.rute == null ? null : () => context.push(butir.rute!),
                child: Text(butir.labelTombol),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
