/// FR-108 — Brankas catatan medis.
///
///  * jenis: hasil lab, pemeriksaan tahunan, resep, imunisasi, tagihan medis,
///    catatan dokter, laporan pencitraan;
///  * **pencarian kata** menjangkau judul, hasil, ringkasan, nama tenaga
///    kesehatan, dan fasilitas;
///  * lampiran berkas disimpan **terenkripsi** (kunci di Android Keystore).
///    Kalau perangkat tidak mendukung enkripsi, berkas TIDAK disimpan dan
///    aplikasi mengatakan apa adanya.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/platform/berkas_medis.dart';
import '../../core/platform/bagikan.dart';
import '../../core/platform/kanal_media.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/medis_repository.dart';
import 'kesehatan_medis_providers.dart';

class CatatanMedisScreen extends ConsumerStatefulWidget {
  const CatatanMedisScreen({super.key, this.kanal});

  /// Kanal media disuntik saat uji supaya tidak perlu HP.
  final KanalMedia? kanal;

  @override
  ConsumerState<CatatanMedisScreen> createState() => _CatatanMedisScreenState();
}

class _CatatanMedisScreenState extends ConsumerState<CatatanMedisScreen> {
  final _cari = TextEditingController();
  List<CatatanMedi> _daftar = const [];
  String? _jenis;
  bool _siap = false;
  String? _pesan;
  int? _buka;
  List<LampiranData> _lampiran = const [];

  @override
  void initState() {
    super.initState();
    muat();
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> muat() async {
    final daftar = await ref.read(repoMedisProvider).ambilCatatan(
          cari: _cari.text,
          jenis: _jenis,
        );
    if (!mounted) return;
    setState(() {
      _daftar = daftar;
      _siap = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Brankas catatan medis')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('medis_tambah'),
        onPressed: _form,
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Tambah catatan'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          TextField(
            key: const Key('medis_cari'),
            controller: _cari,
            onChanged: (_) => muat(),
            decoration: InputDecoration(
              labelText: 'Cari kata (mis. kolesterol, dokter, lab)',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  key: const Key('medis_semua'),
                  label: const Text('Semua'),
                  selected: _jenis == null,
                  onSelected: (_) {
                    setState(() => _jenis = null);
                    muat();
                  },
                ),
                for (final j in JenisCatatanMedis.semua) ...[
                  const SizedBox(width: 6),
                  ChoiceChip(
                    key: Key('medis_jenis_${j.kode}'),
                    label: Text(j.label),
                    selected: _jenis == j.kode,
                    onSelected: (_) {
                      setState(() => _jenis = j.kode);
                      muat();
                    },
                  ),
                ],
              ],
            ),
          ),
          if (_pesan != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_pesan!, key: const Key('medis_pesan')),
            ),
          if (_daftar.isEmpty)
            const Card(
              key: Key('medis_kosong'),
              child: ListTile(
                leading: Icon(Icons.folder_open_outlined),
                title: Text('Belum ada catatan'),
                subtitle: Text('Simpan hasil lab, resep, atau catatan dokter — '
                    'semuanya bisa dicari dengan kata.'),
              ),
            ),
          for (final c in _daftar) _kartu(c),
        ],
      ),
    );
  }

  Widget _kartu(CatatanMedi c) {
    final terbuka = _buka == c.id;
    return Card(
      key: Key('medis_baris_${c.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text('${JenisCatatanMedis.labelDari(c.jenis)} · ${c.judul}'),
            subtitle: Text('${fmtTanggalPendekAman(c.tanggal)}'
                '${c.tenagaKesehatan == null ? '' : ' · ${c.tenagaKesehatan}'}'
                '${c.fasilitas == null ? '' : ' · ${c.fasilitas}'}'),
            onTap: () async {
              setState(() => _buka = terbuka ? null : c.id);
              if (!terbuka) await _muatLampiran(c);
            },
          ),
          if (terbuka)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (c.hasil != null) Text('Hasil: ${c.hasil}'),
                  if (c.ringkasan != null) Text('Ringkasan: ${c.ringkasan}'),
                  if (c.catatan != null) Text('Catatan: ${c.catatan}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        key: Key('medis_lampir_${c.id}'),
                        onPressed: () => _lampirkan(c),
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Lampirkan berkas'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        key: Key('medis_ubah_${c.id}'),
                        onPressed: () => _form(c),
                        child: const Text('Ubah'),
                      ),
                    ],
                  ),
                  if (_lampiran.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Lampiran terenkripsi (${_lampiran.length})',
                        style: Theme.of(context).textTheme.bodySmall),
                    for (final l in _lampiran)
                      ListTile(
                        key: Key('medis_lampiran_${l.id}'),
                        dense: true,
                        leading: const Icon(Icons.lock, size: 18),
                        title: Text(l.keterangan.isEmpty
                            ? _namaBerkas(l.berkas)
                            : l.keterangan),
                        subtitle: Text('${l.ukuranByte} byte'),
                        trailing: IconButton(
                          key: Key('medis_buka_${l.id}'),
                          tooltip: 'Buka (didekripsi sementara)',
                          onPressed: () => _bukaLampiran(l),
                          icon: const Icon(Icons.open_in_new),
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _namaBerkas(String jalur) {
    final bagian = jalur.split(Platform.pathSeparator);
    return bagian.isEmpty ? jalur : bagian.last;
  }

  Future<void> _muatLampiran(CatatanMedi c) async {
    final uid = c.uid;
    if (uid == null) {
      setState(() => _lampiran = const []);
      return;
    }
    final daftar = await ref
        .read(repoLampiranProvider)
        .daftar(indukTabelCatatanMedis, uid);
    if (!mounted) return;
    setState(() => _lampiran = daftar);
  }

  /// Pilih berkas → simpan → enkripsi. Bila enkripsi tidak tersedia, berkas
  /// mentah dihapus dan pengguna diberi tahu (tidak menyimpan rahasia telanjang).
  Future<void> _lampirkan(CatatanMedi c) async {
    final uid = c.uid;
    if (uid == null) {
      setState(() => _pesan = 'Catatan ini belum punya pengenal sinkron; '
          'simpan ulang catatannya lalu lampirkan lagi.');
      return;
    }
    final kanal = widget.kanal ?? KanalMedia();
    final sumber = await kanal.pilihBerkas();
    if (sumber == null) return;
    final lampiran = ref.read(repoLampiranProvider);
    final repo = ref.read(repoMedisProvider);
    try {
      final baris = await lampiran.simpan(
        indukTabel: indukTabelCatatanMedis,
        indukUid: uid,
        jenis: 'berkas',
        jalurSumber: sumber,
        keterangan: _namaBerkas(sumber),
      );
      final tujuan = '${baris.berkas}.enc';
      final berhasil =
          await enkripsiBerkas(sumber: baris.berkas, tujuan: tujuan);
      if (!berhasil) {
        await lampiran.hapus(baris.id);
        final mentah = File(baris.berkas);
        if (await mentah.exists()) await mentah.delete();
        if (!mounted) return;
        setState(() => _pesan = 'Perangkat ini belum mendukung enkripsi '
            '(Android Keystore). Berkas TIDAK disimpan supaya tidak ada '
            'rahasia yang tersimpan tanpa perlindungan.');
        return;
      }
      await repo.gantiBerkasLampiran(baris.id, tujuan);
      final mentah = File(baris.berkas);
      if (await mentah.exists()) await mentah.delete();
      if (!mounted) return;
      setState(() => _pesan = 'Berkas tersimpan terenkripsi (kunci di '
          'Android Keystore, tidak ikut keluar dari HP).');
      await _muatLampiran(c);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = 'Belum bisa dilampirkan: $e');
    }
  }

  /// Dekripsi ke berkas sementara lalu minta sistem membukanya.
  Future<void> _bukaLampiran(LampiranData l) async {
    try {
      final dir = await getTemporaryDirectory();
      final tujuan = <String>[
        dir.path,
        '${DateTime.now().millisecondsSinceEpoch}_${_namaBerkas(l.berkas)}',
      ].join(Platform.pathSeparator);
      final ok = await dekripsiBerkas(sumber: l.berkas, tujuan: tujuan);
      if (!ok) {
        if (!mounted) return;
        setState(() => _pesan = 'Berkas belum bisa didekripsi di perangkat ini.');
        return;
      }
      final terkirim = await bagikanBerkas(
        jalur: tujuan,
        judul: 'Buka lampiran medis',
        jenis: 'application/octet-stream',
      );
      if (!mounted) return;
      setState(() => _pesan = terkirim
          ? 'Berkas didekripsi sementara untuk dibuka.'
          : 'Berkas didekripsi ke $tujuan tetapi belum bisa dibuka otomatis.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = 'Belum bisa dibuka: $e');
    }
  }

  Future<void> _form([CatatanMedi? lama]) async {
    final judul = TextEditingController(text: lama?.judul ?? '');
    final hasil = TextEditingController(text: lama?.hasil ?? '');
    final ringkas = TextEditingController(text: lama?.ringkasan ?? '');
    final tenaga = TextEditingController(text: lama?.tenagaKesehatan ?? '');
    final fasilitas = TextEditingController(text: lama?.fasilitas ?? '');
    var jenis = lama?.jenis ?? 'lab';
    var tanggal = lama?.tanggal ?? DateTime.now();
    final simpan = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: Text(lama == null ? 'Catatan medis baru' : 'Ubah catatan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('form_medis_jenis'),
                  initialValue: jenis,
                  decoration: const InputDecoration(labelText: 'Jenis'),
                  items: [
                    for (final j in JenisCatatanMedis.semua)
                      DropdownMenuItem(value: j.kode, child: Text(j.label)),
                  ],
                  onChanged: (v) => setDialog(() => jenis = v ?? jenis),
                ),
                TextField(
                  key: const Key('form_medis_judul'),
                  controller: judul,
                  decoration: const InputDecoration(labelText: 'Judul'),
                ),
                TextField(
                  key: const Key('form_medis_hasil'),
                  controller: hasil,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Hasil / angka penting (opsional)'),
                ),
                TextField(
                  key: const Key('form_medis_ringkasan'),
                  controller: ringkas,
                  decoration:
                      const InputDecoration(labelText: 'Ringkasan (opsional)'),
                ),
                TextField(
                  key: const Key('form_medis_tenaga'),
                  controller: tenaga,
                  decoration: const InputDecoration(
                      labelText: 'Tenaga kesehatan (opsional)'),
                ),
                TextField(
                  key: const Key('form_medis_fasilitas'),
                  controller: fasilitas,
                  decoration:
                      const InputDecoration(labelText: 'Fasilitas (opsional)'),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text('Tanggal: ${fmtTanggalPendekAman(tanggal)}'),
                    ),
                    TextButton(
                      key: const Key('form_medis_tanggal'),
                      onPressed: () async {
                        final pilih = await showDatePicker(
                          context: c,
                          initialDate: tanggal,
                          firstDate: DateTime(1990),
                          lastDate: DateTime(2100),
                        );
                        if (pilih != null) setDialog(() => tanggal = pilih);
                      },
                      child: const Text('Ubah tanggal'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              key: const Key('form_medis_simpan'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (simpan != true) return;
    try {
      await ref.read(repoMedisProvider).simpanCatatan(
            id: lama?.id,
            jenis: jenis,
            judul: judul.text,
            tanggal: tanggal,
            tenagaKesehatan: tenaga.text,
            fasilitas: fasilitas.text,
            hasil: hasil.text,
            ringkasan: ringkas.text,
          );
      setState(() => _pesan = 'Catatan tersimpan.');
      await muat();
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = 'Belum bisa disimpan: $e');
    }
  }
}
