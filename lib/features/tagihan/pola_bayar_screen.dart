/// FR-40 — Layar "Pola bayar & pengingat pintar".
///
/// Menampilkan apa yang aplikasi pelajari dari riwayat pembayaran (hari khas,
/// kebiasaan maju/telat, keyakinan) dan USUL penyesuaian pengingat. Aplikasi
/// tidak pernah mengubah jadwal pengingat diam-diam: usul harus ditekan dulu.
/// Saklar di atas hanya menambah SATU pengingat pada hari kebiasaan (FR-17).
library;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/pola_bayar.dart';
import '../../core/providers/app_providers.dart';
import '../../core/notifikasi/penyinkron_pengingat.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/pengaturan_repository.dart';
import '../../data/repository/tagihan_repository.dart';

/// "H-7, H-3, H-1, H" — 0 ditulis "H" (hari jatuh tempo).
String teksLeadRingkas(List<int> lead) {
  if (lead.isEmpty) return 'belum ada';
  return lead.map((h) => h == 0 ? 'H' : 'H-$h').join(', ');
}

class PolaBayarScreen extends ConsumerStatefulWidget {
  const PolaBayarScreen({super.key, this.db});

  /// Boleh disuntik saat diuji; bawaan dari provider aplikasi.
  final AppDatabase? db;

  @override
  ConsumerState<PolaBayarScreen> createState() => _PolaBayarScreenState();
}

class _PolaBayarScreenState extends ConsumerState<PolaBayarScreen> {
  AppDatabase get _db => widget.db ?? ref.read(databaseProvider);
  late final TagihanRepository _repo = TagihanRepository(_db);
  late final PengaturanRepository _pengaturan = PengaturanRepository(_db);

  bool _memuat = true;
  bool _saklar = false;
  List<PolaBayar> _pola = const [];
  List<UsulPengingat> _usul = const [];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final riwayat = await _repo.riwayatDenganId();
    final tagihan = await _repo.ambilSemua();
    final saklar = await _pengaturan.bacaSaklar(kunciPengingatPintar);

    final pola = hitungPolaBayar([
      for (final r in riwayat)
        CatatanBayar(
          tagihanId: r.tagihanId,
          namaTagihan: r.nama,
          tanggalBayar: r.tanggalBayar,
          jatuhTempoPeriode: r.periode,
        ),
    ]);
    final lead = <int, List<int>>{
      for (final t in tagihan) t.id: teksKeLead(t.pengingatLeadHari),
    };
    if (!mounted) return;
    setState(() {
      _pola = pola;
      _usul = usulPengingat(pola: pola, leadSekarang: lead);
      _saklar = saklar;
      _memuat = false;
    });
  }

  Future<void> _ubahSaklar(bool nilai) async {
    setState(() => _saklar = nilai);
    await _pengaturan.simpan(kunciPengingatPintar, nilai ? 'true' : 'false');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(nilai
          ? 'Pengingat akan menyesuaikan pola pembayaran.'
          : 'Pengingat kembali memakai jadwal biasa.'),
    ));
  }

  Future<void> _terapkan(UsulPengingat u) async {
    await _repo.ubah(
      TagihanCompanion(
        pengingatLeadHari: Value(leadKeTeks(u.leadUsul)),
        diubahPada: Value(DateTime.now()),
      ),
      id: u.tagihanId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Pengingat ${u.namaTagihan}: ${teksLeadRingkas(u.leadUsul)}'),
    ));
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return const Center(child: CircularProgressIndicator());
    }
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: SwitchListTile(
            key: const Key('saklar_pengingat_pintar'),
            value: _saklar,
            onChanged: _ubahSaklar,
            title: const Text('Pengingat menyesuaikan pola'),
            subtitle: const Text(
                'Bila menyala, satu pengingat tambahan dipasang pada hari yang '
                'biasanya dipakai membayar.'),
          ),
        ),
        const SizedBox(height: 12),
        Text('Pola bayar yang terbaca', style: tema.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Dibaca dari riwayat pembayaran di perangkat ini. Aplikasi tidak '
          'mengubah jadwal pengingat tanpa sepengetahuan Papi — usul di bawah '
          'hanya berlaku bila ditekan "Terapkan".',
          style: tema.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (_pola.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada riwayat pembayaran. Pola mulai terbaca '
                  'setelah 3 kali pembayaran.'),
            ),
          )
        else
          for (final p in _pola) _kartuPola(p, tema),
        if (_usul.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Usul penyesuaian pengingat', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final u in _usul) _kartuUsul(u, tema),
        ],
      ],
    );
  }

  Widget _kartuPola(PolaBayar p, ThemeData tema) {
    return Card(
      key: Key('pola_${p.tagihanId}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.namaTagihan,
                      style: tema.textTheme.titleSmall),
                ),
                Chip(
                  label: Text(p.cukupBukti
                      ? 'pola kuat · ${p.keyakinan}%'
                      : 'perlu lebih banyak bukti · ${p.keyakinan}%'),
                  labelStyle: tema.textTheme.labelSmall,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(p.ringkasan),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: p.keyakinan / 100),
          ],
        ),
      ),
    );
  }

  Widget _kartuUsul(UsulPengingat u, ThemeData tema) {
    if (!u.berbeda) return const SizedBox.shrink();
    return Card(
      key: Key('usul_${u.tagihanId}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(u.namaTagihan, style: tema.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text('Pengingat sekarang: ${teksLeadRingkas(u.leadSekarang)}'),
            Text('Usul: ${teksLeadRingkas(u.leadUsul)}',
                style: tema.textTheme.bodyLarge),
            const SizedBox(height: 6),
            Text(u.alasan, style: tema.textTheme.bodySmall),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: Key('terapkan_usul_${u.tagihanId}'),
                onPressed: () => _terapkan(u),
                child: const Text('Terapkan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
