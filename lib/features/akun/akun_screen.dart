/// Layar Akun & Sinkron — menu utama: status masuk, periksa server, keluar.
///
/// JUJUR soal keadaan: apa yang ikut sinkron dan apa yang tidak.
/// Layar ini tidak berpura-pura sudah menyinkronkan apa pun.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/kanal_media.dart';
import '../../core/akun/klien_akun.dart';
import '../../core/providers/akun_providers.dart';

class AkunScreen extends ConsumerStatefulWidget {
  const AkunScreen({super.key});

  @override
  ConsumerState<AkunScreen> createState() => _AkunScreenState();
}

class _AkunScreenState extends ConsumerState<AkunScreen> {
  String? _catatanServer;
  bool _memeriksa = false;
  String? _hasilSinkron;
  bool _menyinkron = false;

  /// Sinkron tagihan antar HP (tahap 2). Hasilnya ditulis apa adanya —
  /// termasuk kalau gagal.
  /// FR-27 — ekspor seluruh data ke satu berkas, lalu tawarkan dibagikan
  /// (WhatsApp/Drive/USB pilihan Papi). Tidak butuh server.
  Future<void> _eksporBerkas() async {
    if (!mounted) return;
    setState(() {
      _menyinkron = true;
      _hasilSinkron = null;
    });
    try {
      final folder = await getApplicationDocumentsDirectory();
      final stempel = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final berkas = File('${folder.path}/sinkron-lifeos-$stempel.json');
      final jumlah = await ref.read(sinkronSemuaProvider).eksporBerkas(berkas);
      try {
        await const MethodChannel('lifeos/bagikan').invokeMethod<bool>('bagikan', {
          'jalur': berkas.path,
          'judul': 'Berkas sinkron Personal Life OS',
          'jenis': 'application/json',
        });
      } catch (_) {
        // Tanpa aplikasi berbagi (atau bukan Android): berkasnya tetap ada.
      }
      if (mounted) {
        setState(() => _hasilSinkron =
            'Berkas sinkron dibuat ($jumlah baris):\n${berkas.path}');
      }
    } catch (e) {
      if (mounted) setState(() => _hasilSinkron = 'Gagal mengekspor: $e');
    } finally {
      if (mounted) setState(() => _menyinkron = false);
    }
  }

  /// FR-27 — masukkan berkas sinkron (dari HP lain) ke HP ini.
  Future<void> _imporBerkas() async {
    if (!mounted) return;
    setState(() {
      _menyinkron = true;
      _hasilSinkron = null;
    });
    try {
      final jalur = await KanalMedia().pilihBerkas(mime: 'application/json');
      if (jalur == null || jalur.isEmpty) {
        if (mounted) setState(() => _hasilSinkron = 'Batal memilih berkas.');
        return;
      }
      final jumlah =
          await ref.read(sinkronSemuaProvider).imporBerkas(File(jalur));
      if (mounted) {
        setState(() => _hasilSinkron = 'Berkas dimasukkan: $jumlah baris.');
      }
    } catch (e) {
      if (mounted) setState(() => _hasilSinkron = 'Gagal memasukkan berkas: $e');
    } finally {
      if (mounted) setState(() => _menyinkron = false);
    }
  }

  Future<void> _sinkronSekarang() async {
    final repo = ref.read(akunRepoProvider);
    final token = await repo.token();
    if (token == null) return;
    setState(() {
      _menyinkron = true;
      _hasilSinkron = null;
    });
    try {
      final hasil = await ref.read(sinkronSemuaProvider).jalan(token: token);
      setState(() => _hasilSinkron = hasil.pesan);
    } on AkunGagal catch (e) {
      setState(() => _hasilSinkron = 'Gagal: ${e.pesan}');
    } catch (e) {
      setState(() => _hasilSinkron = 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _menyinkron = false);
    }
  }

  Future<void> _periksaServer() async {
    final repo = ref.read(akunRepoProvider);
    final token = await repo.token();
    if (token == null) return;
    setState(() {
      _memeriksa = true;
      _catatanServer = null;
    });
    try {
      final data = await ref.read(klienAkunProvider).infoAkun(token);
      final akun = data['akun'] as Map<String, dynamic>? ?? const {};
      setState(() {
        _catatanServer = 'Akun ${akun['email']} dikenali server · '
            '${data['jumlah_catatan'] ?? 0} catatan tersimpan · '
            'revisi terakhir ${data['revisi_tertinggi'] ?? 0}.';
      });
    } on AkunGagal catch (e) {
      setState(() => _catatanServer = 'Gagal: ${e.pesan}');
    } finally {
      if (mounted) setState(() => _memeriksa = false);
    }
  }

  Future<void> _keluar(AkunSesi sesi) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Data di HP ini TIDAK dihapus. Hanya akunnya '
            'dilepas dari perangkat ini.'),
        actions: [
          TextButton(onPressed: () => c.pop(false), child: const Text('Batal')),
          FilledButton(
              onPressed: () => c.pop(true), child: const Text('Keluar')),
        ],
      ),
    );
    if (yakin != true) return;
    try {
      await ref.read(klienAkunProvider).keluar(sesi.token);
    } on AkunGagal {
      // Sesi lokal tetap dibersihkan; server bisa dimatikan belakangan.
    }
    await ref.read(akunRepoProvider).bersihkanSesi();
    ref.invalidate(sesiAkunProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Sudah keluar dari akun.')));
  }

  @override
  Widget build(BuildContext context) {
    final sesi = ref.watch(sesiAkunProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Akun & Sinkron')),
      body: sesi.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal membaca akun: $e')),
        data: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (s == null)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Belum masuk',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      const Text('Masuk pakai akun Papi supaya semua HP '
                          'memakai data yang sama.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const Key('buka_masuk'),
                        onPressed: () => context.push('/akun/masuk'),
                        icon: const Icon(Icons.login),
                        label: const Text('Masuk'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const Key('buka_daftar'),
                        onPressed: () => context.push('/akun/masuk?daftar=1'),
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Daftar akun baru'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(s.nama),
                      subtitle: Text(s.email),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      key: const Key('periksa_server'),
                      leading: const Icon(Icons.cloud_outlined),
                      title: const Text('Periksa server akun'),
                      subtitle: Text(_catatanServer ??
                          'Menyambung ke server untuk memastikan akun dikenali.'),
                      trailing: _memeriksa
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh),
                      onTap: _memeriksa ? null : _periksaServer,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      key: const Key('sinkron_sekarang'),
                      leading: const Icon(Icons.sync),
                      title: const Text('Sinkron sekarang'),
                      subtitle: Text(_hasilSinkron ??
                          'Samakan tagihan di semua HP yang memakai akun ini.'),
                      trailing: _menyinkron
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.play_arrow),
                      onTap: _menyinkron ? null : _sinkronSekarang,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      key: const Key('keluar_akun'),
                      leading: const Icon(Icons.logout),
                      title: const Text('Keluar dari akun'),
                      onTap: () => _keluar(s),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 8),
                        Text('Keadaan sinkron',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Sinkron lewat berkas (tanpa server)',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text(
                      'Tanpa server: seluruh data ditulis ke satu berkas, lalu '
                      'bisa Papi kirim sendiri (WhatsApp/Drive/USB) ke HP lain '
                      'dan dimasukkan lewat tombol Impor.',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          key: const Key('ekspor_berkas_sinkron'),
                          onPressed: _menyinkron ? null : _eksporBerkas,
                          icon: const Icon(Icons.ios_share),
                          label: const Text('Ekspor berkas'),
                        ),
                        OutlinedButton.icon(
                          key: const Key('impor_berkas_sinkron'),
                          onPressed: _menyinkron ? null : _imporBerkas,
                          icon: const Icon(Icons.file_open_outlined),
                          label: const Text('Impor berkas'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sinkron SELURUH MODUL sudah aktif dan diuji dua basis '
                      'data (HP A & HP B): tagihan, riwayat pembayaran, kas & '
                      'transaksi, aset & kewajiban, tujuan/tugas, kebiasaan, '
                      'kesehatan (berat, air, tidur, makan, suasana hati), '
                      'dokumen, pengetahuan, dan ibadah.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Yang SENGAJA tidak ikut: kategori kas bawaan dan jadwal '
                      'perawatan bawaan (sudah ada di tiap HP, kalau ikut akan '
                      'berlipat ganda), serta catatan obat & minum obat.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bentrok antar HP: versi terbaru menang, versi yang kalah '
                      'TETAP DISIMPAN di server (tidak ada data yang hilang).',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
