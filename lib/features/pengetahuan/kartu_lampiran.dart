/// Kartu lampiran catatan — FR-118 (foto & rekaman suara).
///
/// Dipakai sebagai isi lembar bawah dari layar Catatan. Semua aksi menyentuh
/// kanal Android (kamera, mikrofon, pemutar) — dan kalau kanal tidak tersedia
/// (mis. di uji/desktop) pesannya ditulis apa adanya, bukan berpura-pura bisa.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/kanal_media.dart';
import '../../data/database/database.dart';
import '../../data/repository/lampiran_repository.dart';
import 'provider_pengetahuan.dart';

class KartuLampiran extends ConsumerStatefulWidget {
  const KartuLampiran({
    super.key,
    required this.indukTabel,
    required this.indukUid,
    this.kanal,
  });

  final String indukTabel;
  final String indukUid;

  /// Disuntik saat uji supaya tidak butuh Android sungguhan.
  final KanalMedia? kanal;

  @override
  ConsumerState<KartuLampiran> createState() => _KartuLampiranState();
}

class _KartuLampiranState extends ConsumerState<KartuLampiran> {
  late KanalMedia _kanal;
  List<LampiranData> _baris = const [];
  bool _memuat = true;
  bool _sibuk = false;
  bool _merekam = false;
  int? _diputar;
  String? _catatan;

  @override
  void initState() {
    super.initState();
    _kanal = widget.kanal ?? KanalMedia();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final baris =
          await ref.read(lampiranRepoProvider).daftar(widget.indukTabel, widget.indukUid);
      if (!mounted) {
        return;
      }
      setState(() {
        _baris = baris;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _memuat = false;
        _catatan = 'Gagal membaca lampiran: $e';
      });
    }
  }

  Future<void> _tambah(String jenis, Future<String?> Function() ambil) async {
    setState(() {
      _sibuk = true;
      _catatan = null;
    });
    try {
      final jalur = await ambil();
      if (jalur == null || jalur.isEmpty) {
        setState(() => _sibuk = false);
        return;
      }
      await ref.read(lampiranRepoProvider).simpan(
            indukTabel: widget.indukTabel,
            indukUid: widget.indukUid,
            jenis: jenis,
            jalurSumber: jalur,
          );
      await _muat();
      if (mounted) setState(() => _sibuk = false);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sibuk = false;
        _catatan = e is KanalGagal || e is LampiranGagal ? '$e' : 'Gagal menyimpan lampiran: $e';
      });
    }
  }

  Future<void> _rekam() async {
    if (!_merekam) {
      setState(() {
        _sibuk = true;
        _catatan = null;
      });
      try {
        await _kanal.mulaiRekam();
        if (mounted) {
        setState(() {
          _merekam = true;
          _sibuk = false;
        });
      }
      } catch (e) {
        if (mounted) {
        setState(() {
          _sibuk = false;
          _catatan = '$e';
        });
      }
      }
      return;
    }
    setState(() => _sibuk = true);
    try {
      final jalur = await _kanal.hentikanRekam();
      setState(() {
        _merekam = false;
        _sibuk = false;
      });
      if (jalur == null || jalur.isEmpty) {
        setState(() => _catatan = 'Rekamannya kosong — coba lagi.');
        return;
      }
      await ref.read(lampiranRepoProvider).simpan(
            indukTabel: widget.indukTabel,
            indukUid: widget.indukUid,
            jenis: 'suara',
            jalurSumber: jalur,
          );
      await _muat();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sibuk = false;
        _merekam = false;
        _catatan = '$e';
      });
    }
  }

  Future<void> _putar(LampiranData baris) async {
    try {
      if (_diputar == baris.id) {
        await _kanal.hentikanSuara();
        if (mounted) setState(() => _diputar = null);
        return;
      }
      final ada = await ref.read(lampiranRepoProvider).berkasAda(baris);
      if (!ada) {
        setState(() => _catatan =
            'Berkasnya tidak ada di HP ini. Lampiran memang disimpan di HP '
            'tempat ia dibuat — belum ikut tersinkron.');
        return;
      }
      await _kanal.putarSuara(baris.berkas);
      if (mounted) setState(() => _diputar = baris.id);
    } catch (e) {
      if (mounted) {
        setState(() => _catatan = '$e');
      }
    }
  }

  Future<void> _hapus(LampiranData baris) async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (k) => AlertDialog(
        title: const Text('Hapus lampiran?'),
        content: Text('${LampiranRepository.labelJenis(baris.jenis)} ini akan '
            'dihapus dari HP (tidak bisa dikembalikan).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(k, false), child: const Text('Batal')),
          FilledButton(
            key: const Key('konfirmasi_hapus_lampiran'),
            onPressed: () => Navigator.pop(k, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (setuju != true) return;
    await ref.read(lampiranRepoProvider).hapus(baris.id);
    if (_diputar == baris.id) {
      await _kanal.hentikanSuara();
      _diputar = null;
    }
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    // Kanal yang disuntik (uji) dianggap tersedia supaya bisa diuji.
    final didukung = widget.kanal != null || KanalMedia.didukung;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Lampiran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Foto & rekaman suara tersimpan di HP ini. Lampiran belum ikut '
            'tersinkron ke HP lain (berkasnya binari; perlu penyimpanan di server).',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('lampiran_ambil_foto'),
                onPressed: !didukung || _sibuk ? null : () => _tambah('foto', _kanal.ambilFoto),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Foto'),
              ),
              OutlinedButton.icon(
                key: const Key('lampiran_pilih_foto'),
                onPressed: !didukung || _sibuk ? null : () => _tambah('foto', _kanal.pilihFoto),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Album'),
              ),
              OutlinedButton.icon(
                key: const Key('lampiran_rekam'),
                onPressed: !didukung || _sibuk ? null : _rekam,
                icon: Icon(_merekam ? Icons.stop_circle_outlined : Icons.mic_none),
                label: Text(_merekam ? 'Stop rekam' : 'Rekam suara'),
              ),
            ],
          ),
          if (_catatan != null) ...[
            const SizedBox(height: 8),
            Text(_catatan!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
          const SizedBox(height: 10),
          if (_memuat)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (_baris.isEmpty)
            const Text('Belum ada lampiran.', style: TextStyle(fontSize: 12))
          else
            for (final baris in _baris)
              Card(
                key: Key('lampiran_${baris.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (baris.jenis == 'foto')
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(baris.berkas),
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Berkas foto tidak ada di HP ini.'),
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        '${LampiranRepository.labelJenis(baris.jenis)} · '
                        '${LampiranRepository.ukuranRapi(baris.ukuranByte)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Row(
                        children: [
                          if (baris.jenis != 'foto')
                            TextButton.icon(
                              key: Key('putar_lampiran_${baris.id}'),
                              onPressed: () => _putar(baris),
                              icon: Icon(_diputar == baris.id
                                  ? Icons.stop_circle_outlined
                                  : Icons.play_circle_outline),
                              label: Text(_diputar == baris.id ? 'Stop' : 'Putar'),
                            ),
                          const Spacer(),
                          TextButton.icon(
                            key: Key('hapus_lampiran_${baris.id}'),
                            onPressed: () => _hapus(baris),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Hapus'),
                          ),
                        ],
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
