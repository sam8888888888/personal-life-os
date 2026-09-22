/// FR-38 — Impor tagihan dari foto/screenshot (OCR di perangkat)
/// FR-50 — perluasan ke struk belanja & nota manual.
///
/// Alur yang dipegang: pilih/ambil foto → baca di perangkat → DRAF → pengguna
/// memeriksa & melengkapi → baru disimpan (sebagai tagihan atau pengeluaran).
/// Tidak ada gambar atau teks yang dikirim keluar perangkat.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/parsing/ocr_tagihan.dart';
import '../../core/platform/kanal_media.dart' show KanalGagal, KanalMedia;
import '../../core/platform/kanal_ocr.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/tagihan_repository.dart';
import '../../data/repository/transaksi_repository.dart';

/// Pilihan cara menyimpan hasil impor.
enum CaraSimpanOcr {
  tagihan('tagihan', 'Simpan sebagai tagihan'),
  pengeluaran('pengeluaran', 'Simpan sebagai pengeluaran');

  const CaraSimpanOcr(this.kode, this.label);

  final String kode;
  final String label;
}

class ImporOcrScreen extends ConsumerStatefulWidget {
  const ImporOcrScreen({super.key, this.kanalOcr, this.kanalMedia});

  /// Bisa diganti saat diuji (kanal Android tidak tersedia di lingkungan uji).
  final KanalOcr? kanalOcr;
  final KanalMedia? kanalMedia;

  @override
  ConsumerState<ImporOcrScreen> createState() => _ImporOcrScreenState();
}

class _ImporOcrScreenState extends ConsumerState<ImporOcrScreen> {
  late final KanalOcr _ocr = widget.kanalOcr ?? KanalOcr();
  late final KanalMedia _media = widget.kanalMedia ?? KanalMedia();

  final _nama = TextEditingController();
  final _nominal = TextEditingController();

  DrafOcr? _draf;
  String? _jalurGambar;
  DateTime? _jatuhTempo;
  bool _sibuk = false;
  String? _pesan;
  String? _galat;
  JenisOcr _mode = JenisOcr.tagihan;

  @override
  void dispose() {
    _nama.dispose();
    _nominal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impor dari foto')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Baca tagihan, struk, atau nota dari foto',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  const Text(catatanKanalOcr, style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  SegmentedButton<JenisOcr>(
                    segments: const [
                      ButtonSegment(
                          value: JenisOcr.tagihan,
                          label: Text('Tagihan'),
                          icon: Icon(Icons.receipt_long)),
                      ButtonSegment(
                          value: JenisOcr.struk,
                          label: Text('Struk/nota'),
                          icon: Icon(Icons.shopping_bag_outlined)),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.first),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _sibuk ? null : () => _pilih(true),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Ambil foto'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _sibuk ? null : () => _pilih(false),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Pilih dari galeri'),
                      ),
                      if (_jalurGambar != null)
                        TextButton.icon(
                          onPressed: _sibuk ? null : _baca,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Baca ulang'),
                        ),
                    ],
                  ),
                  if (_sibuk)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                  if (_pesan != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_pesan!,
                          style: const TextStyle(
                              fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                  if (_galat != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Belum bisa dibaca: $_galat',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error)),
                    ),
                ],
              ),
            ),
          ),
          if (_draf != null) _kartuDraf(context, _draf!),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _kartuDraf(BuildContext context, DrafOcr d) {
    final siapTagihan = drafOcrSiapSebagaiTagihan(d);
    final siapPengeluaran = drafOcrSiapSebagaiPengeluaran(d);
    return Card(
      color: d.dikenali
          ? null
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.jenis.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(d.kalimat),
            Text('Keyakinan ${d.keyakinan}%',
                style: const TextStyle(
                    fontSize: 11, fontStyle: FontStyle.italic)),
            if (d.barisTerpakai.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('Dasar angka (dari foto)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              for (final b in d.barisTerpakai)
                Text('• $b', style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _nama,
              decoration: InputDecoration(
                labelText: _mode == JenisOcr.tagihan
                    ? 'Nama tagihan (penyedia)'
                    : 'Nama toko/merchant',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nominal,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Nominal (mis. 250000)'),
            ),
            const SizedBox(height: 8),
            if (_mode == JenisOcr.tagihan)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Jatuh tempo'),
                subtitle: Text(_jatuhTempo == null
                    ? 'Belum diisi'
                    : '${_jatuhTempo!.day}/${_jatuhTempo!.month}/'
                        '${_jatuhTempo!.year}'),
                trailing: const Icon(Icons.calendar_month),
                onTap: _pilihTanggal,
              ),
            if (d.item.isNotEmpty) ...[
              const Divider(),
              Text('${d.item.length} barang terbaca',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              for (final i in d.item.take(12))
                Text('• ${i.nama} — ${fmtRpDariSen(i.hargaSen)}',
                    style: const TextStyle(fontSize: 12)),
              if (d.item.length > 12)
                Text('… dan ${d.item.length - 12} barang lain',
                    style: const TextStyle(fontSize: 12)),
            ],
            if (d.alasan.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('Yang perlu dilengkapi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              for (final a in d.alasan)
                Text('• $a', style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (_mode == JenisOcr.tagihan)
                  FilledButton.icon(
                    onPressed: (!siapTagihan || _sibuk)
                        ? null
                        : () => _simpan(CaraSimpanOcr.tagihan),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Simpan tagihan'),
                  )
                else
                  FilledButton.icon(
                    onPressed: (!siapPengeluaran || _sibuk)
                        ? null
                        : () => _simpan(CaraSimpanOcr.pengeluaran),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Simpan pengeluaran'),
                  ),
                TextButton.icon(
                  onPressed: () => _ubahTeks(d),
                  icon: const Icon(Icons.text_fields),
                  label: const Text('Lihat teks hasil baca'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── aksi ────────────────────────────────────────────────────────────────

  Future<void> _pilih(bool kamera) async {
    setState(() {
      _pesan = null;
      _galat = null;
      _sibuk = true;
    });
    try {
      final jalur = kamera ? await _media.ambilFoto() : await _media.pilihFoto();
      if (!mounted) return;
      if (jalur == null || jalur.isEmpty) {
        setState(() {
          _sibuk = false;
          _pesan = 'Tidak ada gambar yang dipilih.';
        });
        return;
      }
      setState(() {
        _jalurGambar = jalur;
        _sibuk = false;
      });
      await _baca();
    } on KanalGagal catch (e) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _galat = e.pesan;
      });
    }
  }

  Future<void> _baca() async {
    final jalur = _jalurGambar;
    if (jalur == null) {
      setState(() => _pesan = 'Pilih atau ambil foto dulu.');
      return;
    }
    setState(() {
      _sibuk = true;
      _galat = null;
      _pesan = null;
    });
    try {
      if (!await _ocr.tersedia()) {
        if (!mounted) return;
        setState(() {
          _sibuk = false;
          _galat = 'Perangkat ini tidak menyediakan pembacaan teks dari gambar.';
        });
        return;
      }
      final hasil = await _ocr.bacaTeks(jalur);
      if (!mounted) return;
      if (!hasil.ada) {
        setState(() {
          _sibuk = false;
          _galat = 'Tidak ada teks yang terbaca. Coba foto yang lebih terang '
              'dan tegak.';
        });
        return;
      }
      final draf = uraikanTeksOcr(hasil.teks, sekarang: DateTime.now());
      _nama.text = draf.nama;
      _nominal.text = draf.adaNominal
          ? (draf.nominalSen! ~/ 100).toString()
          : '';
      setState(() {
        _draf = draf;
        _jatuhTempo = draf.jatuhTempo;
        _sibuk = false;
        _pesan = draf.dikenali
            ? 'Terbaca ${hasil.baris.length} baris. Periksa angkanya dulu.'
            : 'Teksnya terbaca, tapi jenis dokumennya belum bisa dipastikan.';
      });
    } on KanalGagal catch (e) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _galat = e.pesan;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _galat = e.toString();
      });
    }
  }

  Future<void> _pilihTanggal() async {
    final pilih = await showDatePicker(
      context: context,
      initialDate: _jatuhTempo ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (pilih != null && mounted) setState(() => _jatuhTempo = pilih);
  }

  Future<void> _ubahTeks(DrafOcr d) async {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Teks hasil baca'),
        content: SingleChildScrollView(
          child: SelectableText(d.teksMentah,
              style: const TextStyle(fontSize: 12)),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(c), child: const Text('Tutup')),
        ],
      ),
    );
  }

  Future<void> _simpan(CaraSimpanOcr cara) async {
    final nama = _nama.text.trim();
    final nominal = senDariKetikan(_nominal.text);
    if (nama.isEmpty) {
      setState(() => _pesan = 'Nama masih kosong.');
      return;
    }
    if (nominal <= 0) {
      setState(() => _pesan = 'Nominal belum benar.');
      return;
    }
    if (cara == CaraSimpanOcr.tagihan && _jatuhTempo == null) {
      setState(() => _pesan = 'Jatuh tempo belum diisi.');
      return;
    }
    setState(() => _sibuk = true);
    try {
      final db = ref.read(databaseProvider);
      if (cara == CaraSimpanOcr.tagihan) {
        await TagihanRepository(db).tambah(TagihanCompanion.insert(
              nama: nama,
              jatuhTempo: _jatuhTempo!,
              jumlahSen: Value(nominal),
              catatan: const Value('Diimpor dari foto (FR-38, OCR di perangkat)'),
            ));
        _selesai('Tagihan "$nama" disimpan.');
      } else {
        final waktu = DateTime.now();
        final item = _draf?.item ?? const <ItemOcr>[];
        final catatan = StringBuffer('Dari foto (FR-50, OCR di perangkat)');
        if (item.isNotEmpty) catatan.write(': ${item.length} barang terbaca');
        await TransaksiRepository(db).simpan(TransaksiCompanion.insert(
              idTransaksi: 'ocr-${waktu.millisecondsSinceEpoch}-$nominal',
              jenis: const Value('pengeluaran'),
              tanggal: DateTime(waktu.year, waktu.month, waktu.day),
              jumlahSen: nominal,
              catatan: Value(catatan.toString()),
              sumber: const Value('ocr'),
            ));
        _selesai('Pengeluaran ${fmtRpDariSen(nominal)} di "$nama" disimpan.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _pesan = 'Gagal menyimpan: $e';
      });
    }
  }

  void _selesai(String pesan) {
    if (!mounted) return;
    setState(() {
      _sibuk = false;
      _pesan = pesan;
      _draf = null;
      _jalurGambar = null;
      _jatuhTempo = null;
      _nama.clear();
      _nominal.clear();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(pesan)));
  }
}
