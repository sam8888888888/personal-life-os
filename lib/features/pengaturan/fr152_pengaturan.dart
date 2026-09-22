/// FR-152 — bagian Pengaturan untuk bahasa & kurs.
///
/// Bahasa memakai lapisan `core/utils/bahasa.dart`; kurs disimpan bersama
/// sumber & waktunya (tidak pernah menampilkan angka kurs tanpa keduanya).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/bahasa.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/kurs.dart';
import '../../core/providers/batch10_providers.dart';
import '../../data/database/database.dart';
import '../../data/repository/kurs_repository.dart';

/// Kunci baris bahasa di tabel `pengaturan`.
const String kunciBahasa = 'bahasa';

Future<Bahasa> bacaBahasa(AppDatabase db) async {
  try {
    final baris = await (db.select(db.pengaturan)
          ..where((p) => p.kunci.equals(kunciBahasa)))
        .getSingleOrNull();
    return bahasaDariKode(baris?.nilai);
  } catch (_) {
    return Bahasa.indonesia;
  }
}

Future<void> simpanBahasa(AppDatabase db, Bahasa b) async {
  await db.into(db.pengaturan).insertOnConflictUpdate(
      PengaturanCompanion.insert(kunci: kunciBahasa, nilai: b.kode));
  pakaiBahasa(b);
}

final bahasaProvider = FutureProvider<Bahasa>((ref) async {
  final b = await bacaBahasa(ref.watch(databaseProvider));
  pakaiBahasa(b);
  return b;
});

/// Kartu pilihan bahasa (dipakai di layar Pengaturan).
class PilihanBahasa extends ConsumerWidget {
  const PilihanBahasa({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sekarang = ref.watch(bahasaProvider).value ?? bahasaAktif;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('pengaturan.bahasa'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('${tr('pengaturan.bahasa')}: teks kerangka aplikasi, Pengaturan, dan '
          'layar baru mengikuti pilihan ini. $jumlahKunciKamus kalimat sudah '
          'diterjemahkan; layar lama yang dibuat sebelum lapisan bahasa masih '
          'berbahasa Indonesia (dicatat apa adanya, bukan diklaim tuntas).'),
      const SizedBox(height: 8),
      DropdownButtonFormField<Bahasa>(
        key: const Key('pilih_bahasa'),
        isExpanded: true,
        initialValue: sekarang,
        decoration: InputDecoration(labelText: tr('pengaturan.bahasa')),
        items: Bahasa.values
            .map((b) => DropdownMenuItem(value: b, child: Text(b.label)))
            .toList(),
        onChanged: (b) async {
          if (b == null) return;
          await simpanBahasa(ref.read(databaseProvider), b);
          ref.invalidate(bahasaProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${tr('pengaturan.bahasa')}: ${b.label}')));
          }
        },
      ),
    ]);
  }
}

/// Kartu kurs: menampilkan sumber & waktu, tombol ambil terbaru, dan isi manual.
class BagianKurs extends ConsumerStatefulWidget {
  const BagianKurs({super.key});

  @override
  ConsumerState<BagianKurs> createState() => _BagianKursState();
}

class _BagianKursState extends ConsumerState<BagianKurs> {
  Kurs? _kurs;
  bool _sibuk = false;
  String? _pesan;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final k = await ref.read(repoKursProvider).muat();
    if (!mounted) return;
    setState(() => _kurs = k);
  }

  Future<void> _ambil() async {
    setState(() {
      _sibuk = true;
      _pesan = null;
    });
    try {
      final k = await ref.read(repoKursProvider).ambilDariJaringan();
      if (!mounted) return;
      setState(() {
        _kurs = k;
        _sibuk = false;
        _pesan = 'Kurs diperbarui: ${k.teksSumber}';
      });
    } on KursGagal catch (e) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _pesan = '${e.pesan} Kurs lama tetap dipakai.';
      });
    }
  }

  Future<void> _manual() async {
    final nilai = TextEditingController();
    final kode = 'USD';
    final hasil = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${tr('kurs.manual')} ($kode)'),
        content: TextField(
          key: const Key('kurs_nilai_manual'),
          controller: nilai,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Berapa Rupiah untuk 1 USD', hintText: '16250'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(tr('umum.batal'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(tr('umum.simpan'))),
        ],
      ),
    );
    if (hasil != true) return;
    try {
      final v = double.tryParse(nilai.text.trim().replaceAll('.', ''));
      final k = await ref.read(repoKursProvider).isiManual(kode, v ?? 0);
      if (!mounted) return;
      setState(() {
        _kurs = k;
        _pesan = 'Kurs manual disimpan: ${k.teksSumber}';
      });
    } on KursGagal catch (e) {
      if (!mounted) return;
      setState(() => _pesan = e.pesan);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = _kurs;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('pengaturan.kurs'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('Dipakai untuk menampilkan nilai Rupiah dalam Ringgit/USD. Setiap '
          'angka kurs selalu menyebut sumber dan waktu pembaruannya.'),
      const SizedBox(height: 8),
      if (k == null)
        const Text('Belum ada kurs tersimpan di perangkat ini.',
            key: Key('kurs_kosong'))
      else
        Column(key: const Key('kurs_teks'), crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('1 USD = ${k.nilai('USD')?.round() ?? '—'} · '
              '1 MYR = ${k.nilai('MYR')?.round() ?? '—'}'),
          Text(k.teksSumber, style: const TextStyle(fontSize: 12)),
        ]),
      const SizedBox(height: 8),
      // Tombol dibagi rata (Expanded): layar uji berukuran sempit, dan
      // tombol bertema bisa meminta lebar tak terhingga bila diberi
      // constraint bebas di dalam Row.
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            key: const Key('kurs_ambil'),
            onPressed: _sibuk ? null : _ambil,
            icon: const Icon(Icons.refresh),
            label: Text(tr('kurs.ambil')),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('kurs_manual_tombol'),
            onPressed: _sibuk ? null : _manual,
            icon: const Icon(Icons.edit),
            label: Text(tr('kurs.manual')),
          ),
        ),
      ]),
      if (_sibuk)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(),
        ),
      if (_pesan != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_pesan!, key: const Key('kurs_pesan')),
        ),
    ]);
  }
}
