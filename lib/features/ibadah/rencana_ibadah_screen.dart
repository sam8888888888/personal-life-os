/// FR-97 — Layar "Rencana Haji & Umrah".
///
/// Isi: target dana (persen tercapai, sisa, dan berapa yang perlu disisihkan
/// per bulan) + daftar persiapan dokumen. Angka-angka dari mesin
/// `hitungProgresRencana`; aplikasi tidak menyarankan produk keuangan apa pun.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ibadah/rencana_ibadah.dart';
import '../../core/providers/batch9_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';

/// Ubah ketikan rupiah ("1.500.000" / "1500000") menjadi sen.
int? bacaRupiahKeSen(String teks) {
  final angka = teks.replaceAll(RegExp(r'[^0-9]'), '');
  if (angka.isEmpty) return null;
  final nilai = int.tryParse(angka);
  if (nilai == null) return null;
  return rupiahKeSen(nilai);
}

class RencanaIbadahScreen extends ConsumerStatefulWidget {
  const RencanaIbadahScreen({super.key});

  @override
  ConsumerState<RencanaIbadahScreen> createState() =>
      _RencanaIbadahScreenState();
}

class _RencanaIbadahScreenState extends ConsumerState<RencanaIbadahScreen> {
  List<RencanaIbadahRingkas> _daftar = const [];
  String? _galat;
  bool _siap = false;

  @override
  void initState() {
    super.initState();
    muat();
  }

  Future<void> muat() async {
    try {
      final daftar = await ref.read(repoRencanaIbadahProvider).semua();
      if (!mounted) return;
      setState(() {
        _daftar = daftar;
        _siap = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = 'Rencana belum bisa dibuka: $e';
        _siap = true;
      });
    }
  }

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  Future<void> _tambah() async {
    final nama = TextEditingController();
    final target = TextEditingController();
    final terkumpul = TextEditingController(text: '0');
    var jenis = JenisRencanaIbadah.haji;
    final kini = DateTime.now();
    final tanggal = TextEditingController(
        text: DateTime(kini.year + 2, kini.month, kini.day)
            .toIso8601String()
            .substring(0, 10));

    final simpan = await showDialog<bool>(
      context: context,
      builder: (konteks) => StatefulBuilder(
        builder: (konteks, setDialog) => AlertDialog(
          title: const Text('Rencana baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  children: [
                    for (final j in JenisRencanaIbadah.values)
                      ChoiceChip(
                        key: Key('ibadah_jenis_${j.nilaiDb}'),
                        label: Text(j.label),
                        selected: jenis == j,
                        onSelected: (_) => setDialog(() => jenis = j),
                      ),
                  ],
                ),
                TextField(
                  key: const Key('ibadah_nama'),
                  controller: nama,
                  decoration: const InputDecoration(labelText: 'Nama rencana'),
                ),
                TextField(
                  key: const Key('ibadah_target'),
                  controller: target,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Target dana (Rp)'),
                ),
                TextField(
                  key: const Key('ibadah_terkumpul'),
                  controller: terkumpul,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Sudah terkumpul (Rp)'),
                ),
                TextField(
                  key: const Key('ibadah_tanggal'),
                  controller: tanggal,
                  decoration: const InputDecoration(
                      labelText: 'Target berangkat (YYYY-MM-DD)'),
                ),
                const SizedBox(height: 8),
                const Text('Aplikasi tidak menyarankan produk keuangan apa pun — '
                    'target & setoran diisi Papi sendiri.',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(konteks).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              key: const Key('ibadah_simpan'),
              onPressed: () => Navigator.of(konteks).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (simpan != true) return;

    final targetSen = bacaRupiahKeSen(target.text);
    final terkumpulSen = bacaRupiahKeSen(terkumpul.text) ?? 0;
    final tanggalTarget = DateTime.tryParse(tanggal.text.trim());
    if (nama.text.trim().isEmpty) {
      _pesan('Nama rencana belum diisi.');
      return;
    }
    if (targetSen == null || targetSen <= 0) {
      _pesan('Target dana belum diisi dengan benar (contoh: 45.000.000).');
      return;
    }
    if (tanggalTarget == null) {
      _pesan('Tanggal target harus berbentuk YYYY-MM-DD.');
      return;
    }

    try {
      await ref.read(repoRencanaIbadahProvider).tambahRencana(
            jenis: jenis,
            nama: nama.text,
            targetSen: targetSen,
            terkumpulSen: terkumpulSen,
            targetTanggal: tanggalTarget,
          );
      _pesan('Rencana tersimpan.');
      await muat();
    } catch (e) {
      _pesan('Gagal menyimpan: $e');
    }
  }

  Future<void> _tambahDana(RencanaIbadahRingkas r) async {
    final jumlah = TextEditingController();
    final simpan = await showDialog<bool>(
      context: context,
      builder: (konteks) => AlertDialog(
        title: Text('Setoran dana — ${r.nama}'),
        content: TextField(
          key: const Key('ibadah_setoran'),
          controller: jumlah,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Setoran (Rp)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(konteks).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('ibadah_setoran_simpan'),
            onPressed: () => Navigator.of(konteks).pop(true),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    if (simpan != true || r.id == null) return;
    final sen = bacaRupiahKeSen(jumlah.text);
    if (sen == null || sen <= 0) {
      _pesan('Setoran harus lebih dari nol.');
      return;
    }
    try {
      await ref.read(repoRencanaIbadahProvider).tambahDana(r.id!, sen);
      await muat();
    } catch (e) {
      _pesan('Gagal menambah dana: $e');
    }
  }

  Future<void> _tambahButir(RencanaIbadahRingkas r) async {
    final nama = TextEditingController();
    final simpan = await showDialog<bool>(
      context: context,
      builder: (konteks) => AlertDialog(
        title: Text('Persiapan baru — ${r.nama}'),
        content: TextField(
          key: const Key('ibadah_butir_nama'),
          controller: nama,
          decoration: const InputDecoration(labelText: 'Nama dokumen/berkas'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(konteks).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('ibadah_butir_simpan'),
            onPressed: () => Navigator.of(konteks).pop(true),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    if (simpan != true || r.id == null) return;
    if (nama.text.trim().isEmpty) {
      _pesan('Nama butir belum diisi.');
      return;
    }
    try {
      await ref.read(repoRencanaIbadahProvider).tambahPersiapan(r.id!, nama.text);
      await muat();
    } catch (e) {
      _pesan('Gagal menambah butir: $e');
    }
  }

  Future<void> _hapus(RencanaIbadahRingkas r) async {
    if (r.id == null) return;
    final ya = await showDialog<bool>(
      context: context,
      builder: (konteks) => AlertDialog(
        title: Text('Hapus ${r.nama}?'),
        content: const Text('Rencana beserta daftar persiapannya dihapus. '
            'Catatan lain (tagihan, tabungan) tidak ikut terhapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(konteks).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('ibadah_hapus_ya'),
            onPressed: () => Navigator.of(konteks).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ya != true) return;
    try {
      await ref.read(repoRencanaIbadahProvider).hapusRencana(r.id!);
      await muat();
    } catch (e) {
      _pesan('Gagal menghapus: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final kini = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Rencana Haji & Umrah')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('ibadah_tambah'),
        onPressed: _tambah,
        icon: const Icon(Icons.add),
        label: const Text('Rencana'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.mosque_outlined),
              title: Text('Target dana & persiapan'),
              subtitle: Text('Aplikasi hanya menghitung: persen tercapai, sisa, '
                  'dan perkiraan sisihan per bulan. Tidak ada saran produk '
                  'keuangan, dan tidak ada nomor dokumen yang disimpan.'),
            ),
          ),
          if (_galat != null)
            Card(
              key: const Key('ibadah_galat'),
              child: ListTile(title: Text(_galat!)),
            ),
          if (_daftar.isEmpty)
            const Card(
              key: Key('ibadah_kosong'),
              child: ListTile(
                leading: Icon(Icons.savings_outlined),
                title: Text('Belum ada rencana'),
                subtitle: Text('Tekan tombol "Rencana" di bawah untuk mulai.'),
              ),
            ),
          for (final r in _daftar) _kartu(r, kini),
        ],
      ),
    );
  }

  Widget _kartu(RencanaIbadahRingkas r, DateTime kini) {
    final progres = hitungProgresRencana(r, sekarang: kini);
    final kunci = r.id ?? r.nama.hashCode;
    return Card(
      key: Key('ibadah_rencana_$kunci'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${r.nama} · ${r.jenis.label}',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                IconButton(
                  key: Key('ibadah_hapus_$kunci'),
                  tooltip: 'Hapus rencana',
                  onPressed: () => _hapus(r),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              key: Key('ibadah_progres_$kunci'),
              value: progres.persen.clamp(0.0, 1.0),
            ),
            const SizedBox(height: 6),
            Text(progres.ringkas, key: Key('ibadah_ringkas_$kunci')),
            if (progres.setoranPerBulanSen != null)
              Text(
                'Perlu sekitar ${fmtRpDariSen(progres.setoranPerBulanSen!)} per bulan '
                'selama ${progres.bulanTersisa} bulan (${progres.status}).',
                key: Key('ibadah_setoran_$kunci'),
              ),
            if (progres.peringatan != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(progres.peringatan!,
                    key: Key('ibadah_peringatan_$kunci'),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error, fontSize: 12)),
              ),
            const SizedBox(height: 6),
            Text('dasar: ${progres.dasar}',
                key: Key('ibadah_dasar_$kunci'),
                style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: 20),
            Row(
              children: [
                Text('Persiapan ${r.persiapanSelesai}/${r.jumlahPersiapan}',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                TextButton(
                  key: Key('ibadah_butir_tambah_$kunci'),
                  onPressed: () => _tambahButir(r),
                  child: const Text('+ Butir'),
                ),
              ],
            ),
            for (var i = 0; i < r.persiapan.length; i++)
              CheckboxListTile(
                key: Key('ibadah_butir_${kunci}_$i'),
                // ignore: use_build_context_synchronously
                // (dialog/await memakai `ref`, bukan BuildContext).
                dense: true,
                value: r.persiapan[i].selesai,
                title: Text(r.persiapan[i].nama),
                subtitle: r.persiapan[i].tanggalTarget == null
                    ? null
                    : Text('target: ${fmtTanggalAman(r.persiapan[i].tanggalTarget!)}'),
                onChanged: r.id == null
                    ? null
                    : (nilai) async {
                        try {
                          final idButir = await _idButir(r, r.persiapan[i].nama);
                          if (idButir == null) return;
                          await ref
                              .read(repoRencanaIbadahProvider)
                              .tandaiPersiapan(idButir, nilai ?? false);
                          await muat();
                        } catch (e) {
                          _pesan('Gagal menandai: $e');
                        }
                      },
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('ibadah_dana_$kunci'),
                onPressed: () => _tambahDana(r),
                icon: const Icon(Icons.add_card_outlined),
                label: const Text('Tambah dana'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cari id butir berdasarkan nama pada rencana [r] (dipakai checkbox).
  Future<int?> _idButir(RencanaIbadahRingkas r, String nama) async {
    if (r.id == null) return null;
    final semua = await ref.read(repoRencanaIbadahProvider).butirMentah(r.id!);
    for (final b in semua) {
      if (b.nama == nama) return b.id;
    }
    return null;
  }
}
