/// FR-149 — Layar AI Copilot ber-konteks.
///
/// Prinsip yang ditegakkan di layar:
///   * ada saklar izin eksplisit; tanpa izin tombol tanya mati;
///   * ada daftar "data yang akan dikirim" (bukan kalimat samar);
///   * kunci API ditampilkan tersamar, hanya 4 karakter terakhir;
///   * saat offline / gagal, pesannya jelas dan tidak ada jawaban karangan.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analitik/copilot.dart';
import '../../core/utils/bahasa.dart';
import '../../core/providers/batch11_providers.dart';

class CopilotScreen extends ConsumerStatefulWidget {
  const CopilotScreen({super.key, this.adaJaringanOverride});

  /// Dipakai uji supaya hasilnya tidak bergantung jaringan sungguhan.
  final bool? adaJaringanOverride;

  @override
  ConsumerState<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends ConsumerState<CopilotScreen> {
  RingkasanCopilot? _ringkas;
  final List<HasilCopilot> _riwayat = [];
  final TextEditingController _tanya = TextEditingController();
  bool _siap = false;
  bool _sibuk = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<bool> _adaJaringan(KonfigCopilot k) async {
    final paksa = widget.adaJaringanOverride;
    if (paksa != null) return paksa;
    final host = Uri.tryParse(k.endpoint.trim())?.host;
    if (host == null || host.isEmpty) return false;
    try {
      final hasil = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 3));
      return hasil.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _muat() async {
    try {
      final repo = ref.read(repoCopilotProvider);
      final k = await repo.konfig();
      final bahan = await repo.bahanKonteks();
      final jaringan = await _adaJaringan(k);
      if (!mounted) return;
      setState(() {
        _ringkas = ringkasCopilot(
          konfig: k,
          bahan: bahan,
          adaJaringan: jaringan,
          riwayat: List.unmodifiable(_riwayat),
        );
        _siap = true;
        _galat = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _siap = true;
        _galat = 'Gagal memuat pengaturan copilot: ${e.runtimeType}.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _ringkas;
    return Scaffold(
      appBar: AppBar(title: Text(tr('copilot.judul'))),
      body: !_siap
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                if (_galat != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_galat!),
                    ),
                  ),
                if (r != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.konfig.dasar,
                              style: const TextStyle(fontSize: 12)),
                          SwitchListTile(
                            key: const Key('copilot_izin'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(tr('copilot.izin')),
                            subtitle: const Text('Copilot tidak mengirim apa pun '
                                'sebelum ini menyala.'),
                            value: r.konfig.izinDiberikan,
                            onChanged: (v) async {
                              await ref
                                  .read(repoCopilotProvider)
                                  .simpanKonfig(izin: v);
                              await _muat();
                            },
                          ),
                          Wrap(spacing: 8, children: [
                            OutlinedButton.icon(
                              key: const Key('copilot_atur'),
                              onPressed: _atur,
                              icon: const Icon(Icons.settings_outlined),
                              label: const Text('Atur layanan & kunci'),
                            ),
                            TextButton.icon(
                              key: const Key('copilot_hapus_kunci'),
                              onPressed: () async {
                                await ref.read(repoCopilotProvider).hapusKunci();
                                await _muat();
                              },
                              icon: const Icon(Icons.key_off_outlined),
                              label: const Text('Hapus kunci'),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    key: const Key('copilot_data'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('copilot.dataDikirim'),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(penjelasanDataDikirim(r.konteks)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < r.alasan.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• ${r.alasan[i]}',
                          key: Key('copilot_alasan_$i'),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('copilot_pertanyaan'),
                    controller: _tanya,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Pertanyaan',
                      hintText: 'contoh: apa yang harus saya prioritaskan besok?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('copilot_tanya'),
                    onPressed: (_sibuk || !r.siap) ? null : _kirim,
                    icon: const Icon(Icons.question_answer_outlined),
                    label: Text(tr('copilot.tanya')),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final p in pertanyaanContoh)
                      ActionChip(
                        key: Key('copilot_contoh_$p'),
                        label: Text(p),
                        onPressed: () => setState(() => _tanya.text = p),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _riwayat.length; i++)
                    Card(
                      key: Key('copilot_jawaban_$i'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_riwayat[i].berhasil
                                ? _riwayat[i].jawaban
                                : (_riwayat[i].galat ?? 'Tidak ada jawaban.')),
                            const SizedBox(height: 4),
                            Text(
                              'Data dikirim: '
                              '${_riwayat[i].dataDikirim.isEmpty ? 'tidak ada' : _riwayat[i].dataDikirim.join(', ')}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Future<void> _kirim() async {
    final pertanyaan = _tanya.text.trim();
    if (pertanyaan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pertanyaan masih kosong.')),
      );
      return;
    }
    setState(() => _sibuk = true);
    try {
      final repo = ref.read(repoCopilotProvider);
      final k = await repo.konfig();
      final jaringan = await _adaJaringan(k);
      final hasil = await repo.tanya(
        pertanyaan: pertanyaan,
        adaJaringan: jaringan,
      );
      if (!mounted) return;
      setState(() {
        _riwayat.insert(0, hasil);
        _sibuk = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _galat = 'Copilot gagal: ${e.runtimeType}.';
      });
    }
  }

  Future<void> _atur() async {
    final repo = ref.read(repoCopilotProvider);
    final k = await repo.konfig();
    final endpoint = TextEditingController(text: k.endpoint);
    final model = TextEditingController(text: k.model);
    final kunci = TextEditingController();
    if (!mounted) return;
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Layanan AI'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const Key('copilot_endpoint'),
              controller: endpoint,
              decoration: const InputDecoration(labelText: 'Alamat layanan'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('copilot_model'),
              controller: model,
              decoration: const InputDecoration(labelText: 'Nama model'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('copilot_kunci'),
              controller: kunci,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Kunci API (milik Anda sendiri)',
                hintText: 'tersimpan: ${k.kunciTersamar}',
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Kunci disimpan di perangkat ini saja dan tidak '
                  'pernah ditampilkan utuh.',
                  style: TextStyle(fontSize: 12)),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('umum.batal'))),
          FilledButton(
              key: const Key('copilot_simpan'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('umum.simpan'))),
        ],
      ),
    );
    if (lanjut != true) return;
    await repo.simpanKonfig(
      endpoint: endpoint.text,
      model: model.text,
      kunci: kunci.text.trim().isEmpty ? null : kunci.text.trim(),
    );
    await _muat();
  }
}
