/// FR-42 — Layar "Pusat Bayar": siapkan pembayaran tiap tagihan sebelum bayar.
///
/// Per tagihan: pilih aplikasi bayar, simpan nomor VA/QRIS (bisa disalin satu
/// ketukan), dan tulis catatan konfirmasi pembayaran. Semua setelan disimpan
/// per tagihan di perangkat ini.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/uang_utils.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/pengaturan_repository.dart';
import '../../data/repository/tagihan_repository.dart';
import '../../data/repository/pusat_bayar.dart';

/// Format waktu catatan: "21 Sep 2026 14:05".
String capCatatan(DateTime w) {
  final t = fmtTanggalId(w); // dd MMM yyyy (locale aplikasi)
  final jam = w.hour.toString().padLeft(2, '0');
  final menit = w.minute.toString().padLeft(2, '0');
  return '$t $jam:$menit';
}

class PusatBayarScreen extends ConsumerStatefulWidget {
  const PusatBayarScreen({super.key, this.db, this.sekarang});

  final AppDatabase? db;
  final DateTime? sekarang;

  @override
  ConsumerState<PusatBayarScreen> createState() => _PusatBayarScreenState();
}

class _PusatBayarScreenState extends ConsumerState<PusatBayarScreen> {
  AppDatabase get _db => widget.db ?? ref.read(databaseProvider);

  late final TagihanRepository _repo = TagihanRepository(_db);
  late final PusatBayarPenyimpanan _simpan =
      PusatBayarPenyimpanan(PengaturanRepository(_db));

  bool _memuat = true;
  List<TagihanData> _tagihan = const [];
  Map<int, PreferensiBayar> _preferensi = const {};
  final Map<int, TextEditingController> _nomor = {};

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    for (final c in _nomor.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final semua = await _repo.ambilSemua();
    final aktif = semua.where((t) => t.statusAktif && !t.lunas).toList()
      ..sort((a, b) => a.jatuhTempo.compareTo(b.jatuhTempo));
    final pref = await _simpan.semua();
    for (final t in aktif) {
      final kontrol = _nomor.putIfAbsent(t.id, () => TextEditingController());
      kontrol.text = pref[t.id]?.nomor ?? '';
    }
    if (!mounted) return;
    setState(() {
      _tagihan = aktif;
      _preferensi = pref;
      _memuat = false;
    });
  }

  PreferensiBayar _pref(int id) => _preferensi[id] ?? const PreferensiBayar();

  Future<void> _ubah(int id, PreferensiBayar baru) async {
    setState(() => _preferensi = {..._preferensi, id: baru});
    await _simpan.simpan(id, baru);
  }

  Future<void> _salin(TagihanData t) async {
    final p = _pref(t.id);
    final nomor = _nomor[t.id]?.text.trim() ?? p.nomor;
    if (nomor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Isi nomor VA/QRIS-nya dulu, baru bisa disalin.')));
      return;
    }
    if (nomor != p.nomor) {
      await _ubah(t.id, p.salin(nomor: nomor));
    }
    await Clipboard.setData(ClipboardData(text: nomor));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Nomor ${t.nama} disalin: $nomor')));
  }

  Future<void> _tulisCatatan(TagihanData t) async {
    final p = _pref(t.id);
    final teks = TextEditingController(text: p.catatan);
    final hasil = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Catatan konfirmasi — ${t.nama}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Misalnya: "sudah transfer 20 Sep, tunggu verifikasi". '
                'Catatan hanya untuk Papi sendiri.'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('isi_catatan_konfirmasi'),
              controller: teks,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), hintText: 'Tulis catatan…'),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('hapus_catatan'),
            onPressed: () => Navigator.of(c).pop('__hapus__'),
            child: const Text('Hapus catatan'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('simpan_catatan'),
            onPressed: () => Navigator.of(c).pop(teks.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (hasil == null) return;
    if (hasil == '__hapus__') {
      await _ubah(t.id, p.salin(hapusCatatan: true));
    } else {
      await _ubah(
        t.id,
        p.salin(
          catatan: hasil,
          catatanPada: hasil.trim().isEmpty
              ? null
              : (widget.sekarang ?? DateTime.now()),
        ),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(hasil == '__hapus__'
            ? 'Catatan ${t.nama} dihapus.'
            : 'Catatan ${t.nama} disimpan.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) return const Center(child: CircularProgressIndicator());
    final tema = Theme.of(context);
    final siap = _tagihan.where((t) => _pref(t.id).adaNomor).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pusat Bayar', style: tema.textTheme.titleMedium),
                const SizedBox(height: 6),
                const Text(
                    'Siapkan pembayaran sebelum jatuh tempo: pilih aplikasi '
                    'bayar, simpan nomor VA/QRIS (tinggal salin), dan tulis '
                    'catatan konfirmasi.'),
                const SizedBox(height: 8),
                Text('$siap dari ${_tagihan.length} tagihan sudah punya nomor.',
                    key: const Key('ringkasan_pusat_bayar'),
                    style: tema.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        if (_tagihan.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada tagihan aktif yang belum lunas.'),
            ),
          ),
        for (final t in _tagihan) _kartu(t, tema),
      ],
    );
  }

  Widget _kartu(TagihanData t, ThemeData tema) {
    final p = _pref(t.id);
    return Card(
      key: Key('pusat_bayar_${t.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.nama, style: tema.textTheme.titleSmall),
                ),
                Text(t.jumlahSen == null
                    ? '—'
                    : fmtRpDariSen(t.jumlahSen!)),
              ],
            ),
            const SizedBox(height: 2),
            Text('Jatuh tempo ${fmtTanggalId(t.jatuhTempo)}',
                style: tema.textTheme.bodySmall),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: Key('aplikasi_${t.id}'),
              initialValue:
                  aplikasiBayarBawaan.contains(p.aplikasi) && p.aplikasi.isNotEmpty
                      ? p.aplikasi
                      : null,
              decoration: const InputDecoration(
                  labelText: 'Aplikasi bayar', isDense: true),
              items: [
                for (final a in aplikasiBayarBawaan)
                  DropdownMenuItem(value: a, child: Text(a)),
              ],
              onChanged: (v) {
                if (v == null) return;
                _ubah(t.id, p.salin(aplikasi: v));
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final j in JenisNomorBayar.values)
                  ChoiceChip(
                    key: Key('jenis_${t.id}_${j.nilaiDb}'),
                    label: Text(j.label),
                    selected: p.jenis == j,
                    onSelected: (_) => _ubah(t.id, p.salin(jenis: j)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: Key('nomor_${t.id}'),
              controller: _nomor[t.id],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nomor VA / isi QRIS',
                hintText: 'mis. 8808 1234 5678 9012',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (v) => _ubah(t.id, p.salin(nomor: v)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  key: Key('salin_${t.id}'),
                  onPressed: () => _salin(t),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Salin nomor'),
                ),
                OutlinedButton.icon(
                  key: Key('catatan_${t.id}'),
                  onPressed: () => _tulisCatatan(t),
                  icon: const Icon(Icons.edit_note_outlined, size: 18),
                  label: Text(p.adaCatatan ? 'Ubah catatan' : 'Catatan konfirmasi'),
                ),
              ],
            ),
            if (p.adaCatatan) ...[
              const SizedBox(height: 8),
              Text(
                p.catatanPada == null
                    ? p.catatan
                    : '${p.catatan} · ${capCatatan(p.catatanPada!)}',
                key: Key('catatan_tersimpan_${t.id}'),
                style: tema.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
