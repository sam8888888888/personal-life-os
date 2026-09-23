/// SDD v19 Gelombang 3 — Layar temuan pola (korelasi lintas domain).
///
/// Layar ini melayani **satu tabel**: `temuan`. Temuan sesaat (FR-142) punya
/// layar sendiri di `features/ritme/temuan_pintar_screen.dart`; keduanya tidak
/// digabung supaya jelas mana yang disimpan dan mana yang dihitung sesaat.
///
/// Yang ditampilkan apa adanya:
/// * **n selalu ikut** di setiap temuan (aturan dokumen, bukan pilihan gaya);
/// * pasangan yang **belum bisa diuji** ikut ditampilkan beserta alasannya;
/// * tombol "Bukan begitu" mematikan temuan itu secara permanen (umpan balik
///   manusia mengalahkan statistik).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/pola/mesin_pola.dart';
import '../../core/pola/pasangan_pola.dart';
import '../../core/pola/penjalankan_pola.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/pola_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/temuan_repository.dart';

class TemuanKorelasiScreen extends ConsumerStatefulWidget {
  const TemuanKorelasiScreen({super.key});

  @override
  ConsumerState<TemuanKorelasiScreen> createState() =>
      _TemuanKorelasiScreenState();
}

class _TemuanKorelasiScreenState extends ConsumerState<TemuanKorelasiScreen> {
  List<TemuanData> _tampil = const <TemuanData>[];
  List<TemuanData> _tersembunyi = const <TemuanData>[];
  RingkasTemuan _ringkas =
      const RingkasTemuan(semua: 0, tampil: 0, terakhir: null);
  List<String> _kurangData = const <String>[];
  bool _memuat = true;
  bool _hitung = false;
  String? _pesan;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final TemuanRepository repo = ref.read(repoTemuanProvider);
      final List<TemuanData> tampil = await repo.daftarTampil();
      final List<TemuanData> semua = await repo.semua();
      final RingkasTemuan r = await repo.ringkas();
      if (!mounted) return;
      setState(() {
        _tampil = tampil;
        _tersembunyi = semua
            .where((TemuanData t) => t.diabaikan)
            .toList(growable: false);
        _ringkas = r;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _pesan = 'Temuan tidak bisa dibuka: $e';
      });
    }
  }

  Future<void> _hitungUlang() async {
    setState(() {
      _hitung = true;
      _pesan = null;
    });
    try {
      final RingkasJalankanPola hasil =
          await jalankanMesinPola(ref.read(databaseProvider));
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.temuan,
        aksi: AksiAudit.buat,
        entitas: 'temuan',
        ringkas: 'Mesin pola dijalankan: ${hasil.tersimpan} temuan tersimpan '
            'dari ${hasil.pasanganDiuji} pasangan diuji.',
      );
      await _muat();
      if (!mounted) return;
      setState(() {
        _hitung = false;
        _kurangData = hasil.dilewatiKurangData;
        _pesan = hasil.tersimpan == 0
            ? 'Belum ada pola yang bisa ditampilkan: belum ada pasangan yang '
                'mencapai $ambangSampelMinimum hari berpasangan.'
            : '${hasil.tersimpan} pola tersimpan'
                '${hasil.dilewatiPengguna == 0 ? '' : ', ${hasil.dilewatiPengguna} dilewati karena pernah Papi bilang "bukan begitu"'}'
                '.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hitung = false;
        _pesan = 'Gagal menghitung: $e';
      });
    }
  }

  Future<void> _umpanBalik(TemuanData t, {required bool sadar}) async {
    await ref.read(repoTemuanProvider).umpanBalik(t.id, sadar: sadar);
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.temuan,
      aksi: AksiAudit.ubah,
      entitas: 'temuan',
      entitasId: '${t.id}',
      ringkas: sadar
          ? 'Pengguna menyatakan sadar pola ${t.kode}.'
          : 'Pengguna menyatakan pola ${t.kode} bukan begitu → diabaikan.',
    );
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pola di Catatan Papi')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: <Widget>[
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Cara kerja', style: tema.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        const Text(
                          'Aplikasi membandingkan catatan Papi sendiri antar '
                          'bagian (mis. tidur dengan suasana hati). Pola hanya '
                          'ditampilkan bila ada minimal $ambangSampelMinimum hari '
                          'berpasangan, dan jumlah datanya selalu ditulis. '
                          'Aplikasi tidak menyatakan sebab-akibat dan tidak '
                          'mendiagnosis apa pun.',
                        ),
                        const SizedBox(height: 8),
                        Text('Tampil: ${_ringkas.tampil} · dibungkam: '
                            '${_ringkas.semua - _ringkas.tampil} · '
                            'terakhir dihitung: '
                            '${_ringkas.terakhir == null ? 'belum pernah' : fmtTanggalAman(_ringkas.terakhir!)}',
                            key: const Key('temuan_ringkas')),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          key: const Key('temuan_hitung'),
                          onPressed: _hitung ? null : _hitungUlang,
                          icon: _hitung
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh),
                          label: Text(_hitung
                              ? 'Menghitung…'
                              : 'Hitung ulang dari catatan sekarang'),
                        ),
                        if (_pesan != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(_pesan!, key: const Key('temuan_pesan')),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: Text('Pola yang terlihat: ${_tampil.length}',
                        key: const Key('temuan_judul_daftar'),
                        style: tema.textTheme.titleMedium),
                  ),
                ),
                if (_tampil.isEmpty)
                  const Card(
                    margin: EdgeInsets.only(top: 12),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Belum ada pola yang bisa ditampilkan. Catat terus '
                        '(tidur, suasana hati, air, aktivitas, keluhan) — '
                        'pola muncul sendiri setelah datanya cukup.',
                        key: Key('temuan_kosong'),
                      ),
                    ),
                  ),
                for (final TemuanData t in _tampil)
                  Card(
                    key: Key('temuan_baris_${t.id}'),
                    margin: const EdgeInsets.only(top: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(t.judul, style: tema.textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Text(t.uraian),
                          const SizedBox(height: 4),
                          Text(
                            'n = ${t.ukuranSampel} · Spearman '
                            '${t.kekuatan.toStringAsFixed(2)}'
                            '${t.nilaiP == null ? '' : ' · nilai-p ${t.nilaiP!.toStringAsFixed(3)}'}'
                            ' · ${fmtTanggalAman(t.rentangMulai)} – '
                            '${fmtTanggalAman(t.rentangSelesai)}',
                            key: Key('temuan_angka_${t.id}'),
                            style: tema.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            children: <Widget>[
                              TextButton(
                                key: Key('temuan_sadar_${t.id}'),
                                onPressed: () =>
                                    _umpanBalik(t, sadar: true),
                                child: const Text('Ya, saya sadar'),
                              ),
                              TextButton(
                                key: Key('temuan_bukan_${t.id}'),
                                onPressed: () =>
                                    _umpanBalik(t, sadar: false),
                                child: const Text('Bukan begitu'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_tersembunyi.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Dibungkam Papi: ${_tersembunyi.length}',
                              style: tema.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          for (final TemuanData t in _tersembunyi)
                            Row(
                              children: <Widget>[
                                Expanded(child: Text(t.judul)),
                                TextButton(
                                  key: Key('temuan_kembali_${t.id}'),
                                  onPressed: () async {
                                    await ref
                                        .read(repoTemuanProvider)
                                        .kembalikan(t.id);
                                    await _muat();
                                  },
                                  child: const Text('Hidupkan lagi'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Pasangan yang belum bisa diuji',
                            style: tema.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        const Text(
                          'Ini jujur apa adanya: pasangan di bawah belum punya '
                          'datanya, jadi tidak dihitung dengan tebakan.',
                        ),
                        const SizedBox(height: 8),
                        for (final PasanganBelumBisa p in pasanganBelumBisa)
                          Text('• ${p.kode} — ${p.alasan}',
                              style: tema.textTheme.bodySmall),
                        if (_kurangData.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          const Text('Hasil hitung terakhir:'),
                          for (final String s in _kurangData)
                            Text('• $s', style: tema.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
