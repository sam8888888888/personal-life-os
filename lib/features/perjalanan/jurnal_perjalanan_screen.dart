/// FR-135 — Layar Jurnal Perjalanan.
///
/// Pengeluaran yang dicatat di sini LANGSUNG menjadi pengeluaran di laporan
/// keuangan (tanpa input ulang) — layar menandai tiap catatan dengan
/// "Tercatat di laporan keuangan" supaya bisa diperiksa sendiri.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/perjalanan/jurnal_perjalanan.dart';
import '../../core/perjalanan/perjalanan.dart' show fmtRingkasRp;
import '../../core/platform/kanal_media.dart';
import '../../core/providers/batch10_providers.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/bahasa.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/lampiran_repository.dart';

class JurnalPerjalananScreen extends ConsumerStatefulWidget {
  const JurnalPerjalananScreen({
    super.key,
    required this.perjalananUid,
    required this.idPerjalanan,
    required this.namaPerjalanan,
  });

  final String perjalananUid;
  final String idPerjalanan;
  final String namaPerjalanan;

  @override
  ConsumerState<JurnalPerjalananScreen> createState() =>
      _JurnalPerjalananScreenState();
}

class _JurnalPerjalananScreenState
    extends ConsumerState<JurnalPerjalananScreen> {
  List<CatatanPerjalananData> _daftar = const [];
  RekapJurnal? _rekap;
  bool _siap = false;
  String? _galat;

  static final KanalMedia _kanal = KanalMedia();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final repo = ref.read(repoJurnalPerjalananProvider);
      final daftar = await repo.daftar(widget.perjalananUid);
      final rekap = await repo.rekap(widget.perjalananUid, widget.namaPerjalanan);
      if (!mounted) return;
      setState(() {
        _daftar = daftar;
        _rekap = rekap;
        _siap = true;
        _galat = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _siap = true;
        _galat = 'Gagal memuat jurnal: ${e.runtimeType}.';
      });
    }
  }

  Future<void> _tambah() async {
    final judul = TextEditingController();
    final tempat = TextEditingController();
    final cerita = TextEditingController();
    final pengeluaran = TextEditingController();
    int? nilai;
    final hariIni = DateTime.now();
    var tanggal = DateTime(hariIni.year, hariIni.month, hariIni.day);
    var jalurFoto = '';

    final hasil = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Catatan jurnal'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                key: const Key('jrn_judul'),
                controller: judul,
                decoration: const InputDecoration(labelText: 'Judul'),
              ),
              TextField(
                key: const Key('jrn_tempat'),
                controller: tempat,
                decoration: const InputDecoration(labelText: 'Tempat'),
              ),
              TextField(
                key: const Key('jrn_cerita'),
                controller: cerita,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Kenangan'),
              ),
              TextField(
                key: const Key('jrn_pengeluaran'),
                controller: pengeluaran,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Pengeluaran (Rp, boleh kosong)',
                    helperText:
                        'Otomatis masuk laporan keuangan, tidak perlu input ulang.'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('perjalanan.penilaian')),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (var i = 1; i <= 5; i++)
                    ChoiceChip(
                      key: Key('jrn_nilai_$i'),
                      label: Text('$i'),
                      selected: nilai == i,
                      onSelected: (v) => setD(() => nilai = v ? i : null),
                    ),
                ],
              ),
              if (KanalMedia.didukung)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(children: [
                    TextButton.icon(
                      key: const Key('jrn_foto'),
                      onPressed: () async {
                        final j = await _kanal.ambilFoto();
                        if (j != null) setD(() => jalurFoto = j);
                      },
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Foto'),
                    ),
                    if (jalurFoto.isNotEmpty)
                      const Text('1 foto siap disimpan',
                          style: TextStyle(fontSize: 12)),
                  ]),
                ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(tr('umum.batal'))),
            FilledButton(
              key: const Key('jrn_simpan'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('umum.simpan')),
            ),
          ],
        ),
      ),
    );
    if (hasil != true) return;
    if (judul.text.trim().isEmpty) {
      _pesan('Judul ${tr('umum.wajibDiisi')}');
      return;
    }
    try {
      final repo = ref.read(repoJurnalPerjalananProvider);
      final id = await repo.tambah(
        perjalananUid: widget.perjalananUid,
        idPerjalanan: widget.idPerjalanan,
        tanggal: tanggal,
        judul: judul.text,
        tempat: tempat.text,
        cerita: cerita.text,
        penilaian: nilai,
        pengeluaranSen: senDariKetikan(pengeluaran.text),
      );
      if (jalurFoto.isNotEmpty) {
        final uid = await repo.uidCatatan(id);
        if (uid != null) {
          await LampiranRepository(ref.read(databaseProvider)).simpan(
            indukTabel: 'catatan_perjalanan',
            indukUid: uid,
            jenis: 'foto',
            jalurSumber: jalurFoto,
            keterangan: judul.text,
          );
          await repo.setJumlahFoto(id, 1);
        }
      }
      await _muat();
      _pesan('Catatan disimpan'
          '${senDariKetikan(pengeluaran.text) > 0 ? ' dan pengeluarannya masuk laporan keuangan' : ''}.');
    } catch (e) {
      _pesan('Gagal menyimpan: ${e.runtimeType}.');
    }
  }

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  @override
  Widget build(BuildContext context) {
    final rekap = _rekap;
    return Scaffold(
      appBar: AppBar(title: Text('${tr('perjalanan.jurnal')} · ${widget.namaPerjalanan}')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('jurnal_tambah'),
        onPressed: _tambah,
        icon: const Icon(Icons.add),
        label: Text(tr('umum.tambah')),
      ),
      body: !_siap
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (_galat != null)
                  Card(
                    key: const Key('jurnal_galat'),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                        padding: const EdgeInsets.all(12), child: Text(_galat!)),
                  ),
                if (rekap != null)
                  Card(
                    key: const Key('jurnal_rekap'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rekap jurnal',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(rekap.dasar),
                            const SizedBox(height: 4),
                            Text('${tr('umum.dasarData')}: ${rekap.dasar}'),
                            if (rekap.tempatTersering != null)
                              Text('Tempat paling sering: ${rekap.tempatTersering}'),
                            if (rekap.rataPenilaian != null)
                              Text('Rata-rata penilaian: '
                                  '${rekap.rataPenilaian!.toStringAsFixed(1)} dari 5'),
                            if (rekap.jumlahFoto > 0)
                              Text('Foto: ${rekap.jumlahFoto}'),
                            for (final b in rekap.belumBisa) ...[
                              const SizedBox(height: 4),
                              Text('${tr('umum.belumBisa')}: $b',
                                  style: const TextStyle(fontStyle: FontStyle.italic)),
                            ],
                          ]),
                    ),
                  ),
                if (_daftar.isEmpty)
                  Card(
                    key: const Key('jurnal_kosong'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('${tr('umum.belumAda')} Tekan tombol "+ '
                          '${tr('umum.tambah')}" untuk mencatat tempat, '
                          'kenangan, foto, dan pengeluaran selama perjalanan.'),
                    ),
                  ),
                for (final c in _daftar)
                  Card(
                    key: Key('jurnal_${c.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.judul,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${c.tanggal.day}/${c.tanggal.month}/${c.tanggal.year}'
                                '${(c.tempat ?? '').isEmpty ? '' : ' · ${c.tempat}'}'
                                '${c.penilaian == null ? '' : ' · ${'★' * c.penilaian!}'}'),
                            if ((c.cerita ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(c.cerita!),
                            ],
                            if (c.pengeluaranSen > 0) ...[
                              const SizedBox(height: 4),
                              Text(fmtRingkasRp(c.pengeluaranSen)),
                              Text(
                                tr('perjalanan.masukKeuangan'),
                                key: Key('jurnal_keuangan_${c.id}'),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.teal),
                              ),
                            ],
                            if (c.jumlahFoto > 0) Text('Foto: ${c.jumlahFoto}'),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                key: Key('jurnal_hapus_${c.id}'),
                                onPressed: () async {
                                  final yakin = await showDialog<bool>(
                                    context: context,
                                    builder: (c2) => AlertDialog(
                                      title: const Text('Hapus catatan ini?'),
                                      content: Text(c.pengeluaranSen > 0
                                          ? 'Catatan dan pengeluaran '
                                              '${fmtRingkasRp(c.pengeluaranSen)} '
                                              'yang tercatat di laporan keuangan '
                                              'ikut dihapus.'
                                          : 'Catatan ini akan dihapus.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(c2, false),
                                            child: Text(tr('umum.batal'))),
                                        FilledButton(
                                            onPressed: () => Navigator.pop(c2, true),
                                            child: Text(tr('umum.hapus'))),
                                      ],
                                    ),
                                  );
                                  if (yakin != true) return;
                                  await ref
                                      .read(repoJurnalPerjalananProvider)
                                      .hapus(c.id);
                                  await _muat();
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: Text(tr('umum.hapus')),
                              ),
                            ),
                          ]),
                    ),
                  ),
              ],
            ),
    );
  }
}
