/// FR-37 — Layar "Rekap tahunan" (ala Wrapped) + kartu berbagi gambar.
///
/// Isinya: total dibayar setahun, jumlah pembayaran, tepat waktu, grafik 12
/// bulan, bulan tersibuk, dan tagihan terbesar. Kartu ringkasannya bisa
/// dijadikan gambar PNG lalu dibagikan (WhatsApp dsb) lewat lembar berbagi
/// Android.
///
/// Batas jujur: bila gambar tidak bisa dibuat atau lembar berbagi tidak
/// tersedia, layar **mengatakannya apa adanya** dan menyebut lokasi berkasnya —
/// tidak pernah mengaku "berhasil" tanpa bukti.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/laporan/rekap_tahunan.dart';
import '../../core/laporan/statistik_pembayaran.dart';
import '../../core/platform/bagikan.dart';
import '../../core/platform/kartu_gambar.dart';
import '../../core/providers/app_providers.dart';
import '../../data/database/database.dart';

class RekapTahunanScreen extends ConsumerStatefulWidget {
  const RekapTahunanScreen({
    super.key,
    this.db,
    this.sekarang,
    this.tangkapKartu,
    this.direktoriSementara,
    this.bagikan,
  });

  final AppDatabase? db;
  final DateTime? sekarang;

  /// Cara menangkap kartu jadi gambar (bisa diganti saat pengujian).
  final Future<Uint8List?> Function(GlobalKey kunci)? tangkapKartu;

  /// Cara mengambil folder sementara (bisa diganti saat pengujian).
  final Future<Directory> Function()? direktoriSementara;

  /// Cara membagikan berkas (bisa diganti saat pengujian). Bawaannya memanggil
  /// lembar berbagi Android lewat kanal `lifeos/bagikan`.
  final Future<bool> Function({
    required String jalur,
    String judul,
    String jenis,
  })? bagikan;

  @override
  ConsumerState<RekapTahunanScreen> createState() => _RekapTahunanScreenState();
}

class _RekapTahunanScreenState extends ConsumerState<RekapTahunanScreen> {
  AppDatabase get _db => widget.db ?? ref.read(databaseProvider);

  final GlobalKey _kunciKartu = GlobalKey();
  late int _tahun;
  bool _memuat = true;
  List<PembayaranRingkas> _baris = const [];
  String? _pesan;

  DateTime get _sekarang => widget.sekarang ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _tahun = _sekarang.year;
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final riwayat = await _db.select(_db.riwayatPembayaran).get();
    final tagihan = await _db.select(_db.tagihan).get();
    final nama = {for (final t in tagihan) t.id: t.nama};
    if (!mounted) return;
    setState(() {
      _baris = ringkasRiwayat(riwayat, namaTagihan: nama);
      _memuat = false;
    });
  }

  Future<void> _bagikan(RekapTahunan rekap) async {
    final bytes = await (widget.tangkapKartu ?? tangkapPng)(_kunciKartu);
    if (bytes == null || !pngSah(bytes)) {
      setState(() =>
          _pesan = 'Kartu belum bisa digambar. Coba buka layar ini sekali lagi.');
      return;
    }
    try {
      final dir = await (widget.direktoriSementara ?? getTemporaryDirectory)();
      final berkas = File('${dir.path}/rekap-tahunan-${rekap.tahun}.png');
      await berkas.writeAsBytes(bytes, flush: true);
      final kirim = widget.bagikan ?? bagikanBerkas;
      final dikirim = await kirim(
        jalur: berkas.path,
        judul: 'Rekap ${rekap.tahun}',
        jenis: 'image/png',
      );
      if (!mounted) return;
      setState(() => _pesan = dikirim
          ? 'Kartu dibagikan (${(bytes.length / 1024).round()} KB).'
          : 'Kartu tersimpan sebagai gambar di ${berkas.path}, tetapi belum '
              'bisa dibagikan dari perangkat ini.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan =
          'Kartu belum bisa disimpan di perangkat ini (${e.runtimeType}).');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) return const Center(child: CircularProgressIndicator());
    final tema = Theme.of(context);
    final rekap = hitungRekapTahunan(_baris, _tahun);
    final grafik = grafikBulanan(rekap);
    final tahunTersedia = <int>{
      _sekarang.year,
      _sekarang.year - 1,
      _sekarang.year - 2,
      for (final b in _baris) b.tanggalBayar.year,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('Rekap tahunan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final t in tahunTersedia)
                ChoiceChip(
                  key: Key('pilih_tahun_$t'),
                  label: Text('$t'),
                  selected: _tahun == t,
                  onSelected: (_) => setState(() => _tahun = t),
                ),
            ],
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            key: _kunciKartu,
            child: Container(
              key: const Key('kartu_wrapped'),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D47A1), Color(0xFF00695C)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PERSONAL LIFE OS',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 11, letterSpacing: 2),
                  ),
                  const SizedBox(height: 8),
                  for (final baris in barisKartuRekap(rekap))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        baris,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: baris.startsWith('Rekap') ? 22 : 14,
                          fontWeight:
                              baris.startsWith('Rekap') ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'Disusun ${_sekarang.day}/${_sekarang.month}/${_sekarang.year} · data milik Papi sendiri',
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('bagikan_wrapped'),
                  onPressed: () => _bagikan(rekap),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Bagikan kartu'),
                ),
              ),
            ],
          ),
          if (_pesan != null) ...[
            const SizedBox(height: 8),
            Text(_pesan!, key: const Key('pesan_wrapped')),
          ],
          const SizedBox(height: 12),
          Card(
            key: const Key('ringkasan_rekap'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Angka tahun $_tahun', style: tema.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text('Total dibayar: ${rupiahRingkas(rekap.totalSen)}'),
                  Text('Pembayaran: ${rekap.jumlahPembayaran} · '
                      'tepat waktu ${rekap.persenTepatWaktu}% · lewat jatuh '
                      'tempo ${rekap.lewatJatuhTempo}×'),
                  Text('Rata-rata per pembayaran: '
                      '${rupiahRingkas(rekap.rataRataSen)}'),
                  if (rekap.bulanTersibuk != null)
                    Text('Bulan tersibuk: ${namaBulan(rekap.bulanTersibuk!)}'),
                  if (rekap.tagihanTerbesar != null)
                    Text('Tagihan terbesar: ${rekap.tagihanTerbesar} '
                        '(${rupiahRingkas(rekap.perTagihanSen[rekap.tagihanTerbesar] ?? 0)})'),
                  if (rekap.kosong)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                          'Belum ada pembayaran tercatat di tahun ini — '
                          'catat pembayaran dulu, rekapnya muncul sendiri.'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Sebaran per bulan', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final b in grafik)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 42,
                            child: Text(b.label,
                                key: Key('bulan_${b.bulan}'),
                                style: tema.textTheme.bodySmall),
                          ),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: b.porsi,
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 110,
                            child: Text(
                              b.totalSen == 0
                                  ? '—'
                                  : rupiahRingkas(b.totalSen),
                              textAlign: TextAlign.right,
                              style: tema.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
