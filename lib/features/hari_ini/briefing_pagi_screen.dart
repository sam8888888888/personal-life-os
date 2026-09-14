/// Morning Briefing (FR-63).
///
/// Blok cuaca dihilangkan saat offline, bukan menampilkan angka lama (§6.4).
/// Cuaca belum punya sumber data, jadi ditulis apa adanya "Belum ada data".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/hari_ini/model_hari_ini.dart';
import '../../core/hari_ini/penyusun_briefing.dart';
import '../../core/hari_ini/penyusun_hari_ini.dart';
import '../../core/ibadah/kalender_hijriah.dart';
import '../../core/ibadah/kota_indonesia.dart';
import '../../core/ibadah/model_sholat.dart';
import '../../core/ibadah/penghitung_sholat.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';
import 'pemetaan_tagihan.dart';
import 'warna_tingkat.dart';

class BriefingPagiScreen extends ConsumerStatefulWidget {
  const BriefingPagiScreen({
    super.key,
    this.jamSekarang,
    this.daring = true,
    this.namaPanggilan = 'Anda',
    this.kota,
  });

  /// Jam uji. Dipakai sebagai instan untuk waktu sholat dan tanggal sipil
  /// untuk tanggal Masehi/Hijriah.
  final DateTime Function()? jamSekarang;
  final bool daring;
  final String namaPanggilan;
  final KotaSholat? kota;

  @override
  ConsumerState<BriefingPagiScreen> createState() => _BriefingPagiScreenState();
}

class _BriefingPagiScreenState extends ConsumerState<BriefingPagiScreen> {
  DateTime get _sekarang => widget.jamSekarang?.call() ?? DateTime.now();

  KotaSholat get _kota => widget.kota ?? cariKota('Jakarta').first;

  /// Teks "Dzuhur 11:49 · 2 jam 46 menit lagi" atau null bila tak bisa dihitung.
  String? _waktuSholatBerikutnya() {
    try {
      final kota = _kota;
      final jadwal = hitungRentang(
        kota: kota,
        tanggalMulai: _sekarang,
        jumlahHari: 2,
      );
      final berikut = cariWaktuBerikutnya(jadwal: jadwal, sekarang: _sekarang);
      if (berikut == null) return null;
      final dinding = berikut.instan.add(Duration(hours: kota.zona.offsetJam));
      final jam = '${dinding.hour.toString().padLeft(2, '0')}:'
          '${dinding.minute.toString().padLeft(2, '0')}';
      final sisa = berikut.instan.difference(_sekarang.toUtc());
      return '${berikut.waktu.label} $jam · ${_teksSisa(sisa)}';
    } catch (_) {
      return null;
    }
  }

  static String _teksSisa(Duration d) {
    if (d.isNegative) return 'sudah lewat';
    final j = d.inHours;
    final m = d.inMinutes % 60;
    if (j > 0) return '$j jam $m menit lagi';
    return '$m menit lagi';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tagihan = petaDaftarTagihan(
        ref.watch(semuaTagihanProvider).value ?? const <TagihanData>[]);
    final hijri = hijriahDariMasehi(_sekarang);

    final data = DataHariIni(
      sekarang: _sekarang,
      tagihan: tagihan,
      namaPanggilan: widget.namaPanggilan,
      daring: widget.daring,
    );
    final isi = susunBriefing(
      data,
      hijriah: hijri?.label ?? 'Belum ada data Hijriah',
      sholatBerikutnya: _waktuSholatBerikutnya(),
      jam: _sekarang,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringkasan pagi'),
        actions: [
          if (!widget.daring)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: Text('Offline')),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Text(isi.sapaan, style: tema.textTheme.titleMedium),
          Text(
            '${fmtTanggalSingkatAman(isi.tanggal)} · ${isi.hijriah}',
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          _Blok(
            judul: 'Agenda hari ini',
            kosong: 'Belum ada agenda hari ini',
            butir: isi.agenda,
          ),
          const SizedBox(height: 12),
          _Blok(
            judul: 'Tagihan 7 hari ke depan',
            kosong: 'Belum ada tagihan 7 hari ke depan',
            butir: isi.tagihanTujuhHari,
            catatan: isi.tagihanTujuhHari.isEmpty
                ? null
                : 'Total ${fmtRpDariSen(isi.totalTagihanSen)}',
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.mosque_outlined),
              title: const Text('Waktu sholat berikutnya'),
              subtitle: Text(isi.sholatBerikutnya ?? 'Belum ada data jadwal sholat'),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Cuaca'),
              subtitle: Text(
                widget.daring
                    ? 'Belum ada data cuaca — modul cuaca menyusul'
                    : teksCuacaOffline,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => context.go('/today'),
                  child: const Text('Mulai hari'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/today');
                    }
                  },
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Blok extends StatelessWidget {
  const _Blok({
    required this.judul,
    required this.kosong,
    required this.butir,
    this.catatan,
  });

  final String judul;
  final String kosong;
  final List<ButirAgenda> butir;
  final String? catatan;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$judul (${butir.length})', style: tema.textTheme.titleSmall),
            const SizedBox(height: 6),
            if (butir.isEmpty)
              Text(kosong, style: tema.textTheme.bodyMedium)
            else
              for (final b in butir)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(ikonButir(b.jenis), size: 16, color: warnaTingkat(b.tingkat, tema)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.judul, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(b.alasan, style: tema.textTheme.bodySmall, maxLines: 2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            if (catatan != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(catatan!, style: tema.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
