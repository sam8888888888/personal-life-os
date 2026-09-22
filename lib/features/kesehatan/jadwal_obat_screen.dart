/// FR-54 — Layar Pengingat Obat & Suplemen (opsional).
///
/// Lapisan PENGINGAT di atas modul obat yang sudah ada (FR-106): menyalakan
/// izin, melihat jam minum hari ini, menandai sudah minum / tunda / lewati, dan
/// melihat jam berikutnya. Mengelola daftar obat tetap di layar `/kesehatan/obat`
/// (tidak diduplikasi di sini).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/kesehatan/rencana_obat.dart';
import '../../core/utils/bahasa.dart';
import '../../data/repository/obat_repository.dart';
import 'provider_kesehatan.dart';

class JadwalObatScreen extends ConsumerStatefulWidget {
  const JadwalObatScreen({super.key});

  @override
  ConsumerState<JadwalObatScreen> createState() => _JadwalObatScreenState();
}

class _JadwalObatScreenState extends ConsumerState<JadwalObatScreen> {
  bool _memuat = true;
  bool _izin = false;
  RingkasanObatHariIni _hariIni = const RingkasanObatHariIni(jadwal: []);
  List<SlotObat> _berikutnya = const [];
  String? _galat;

  DateTime get _sekarang => DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  Future<void> _muat() async {
    if (!mounted) return;
    setState(() {
      _memuat = true;
      _galat = null;
    });
    try {
      final repo = ref.read(obatRepoProvider);
      final izin = await ref.read(izinPengingatObatProvider).baca();
      final hari = await repo.ringkasanHariIni(hari: _sekarang);
      final jam = await repo.jadwalRingkas();
      final berikutnya = slotMendatang(jam, _sekarang);
      if (!mounted) return;
      setState(() {
        _izin = izin;
        _hariIni = hari;
        _berikutnya = berikutnya;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _galat = 'Data obat belum bisa dibaca: $e';
      });
    }
  }

  Future<void> _ubahIzin(bool menyala) async {
    await ref.read(izinPengingatObatProvider).simpan(menyala);
    if (!mounted) return;
    setState(() => _izin = menyala);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(menyala
          ? 'Pengingat obat dinyalakan. Alarm berbunyi pada jam minum.'
          : 'Pengingat obat dimatikan. Tidak ada alarm minum.'),
    ));
  }

  Future<void> _tandai(JadwalMinumHariIni s, StatusMinum status) async {
    final repo = ref.read(obatRepoProvider);
    await repo.catatMinum(
      obatId: s.obatId,
      waktuRencana: s.waktuRencana,
      jadwalId: s.jadwal?.id,
      status: status,
    );
    if (!mounted) return;
    await _muat();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${s.obat.nama} pukul ${s.jam}: ${status.label}.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('obat.judul'))),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_galat != null)
                  Card(
                    color: t.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_galat!, key: const Key('galat_obat')),
                    ),
                  ),
                _kartuIzin(t),
                const SizedBox(height: 12),
                _kartuBerikutnya(t),
                const SizedBox(height: 12),
                _kartuHariIni(t),
                const SizedBox(height: 12),
                Card(
                  key: const Key('kelola_obat'),
                  child: ListTile(
                    leading: const Icon(Icons.medication_liquid_outlined),
                    title: const Text('Kelola obat & jam minum'),
                    subtitle: const Text('Tambah obat, dosis, dan jam minum '
                        '(modul obat FR-106)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/kesehatan/obat'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Pengingat ini pilihan: tidak ada alarm sebelum Anda '
                  'menyalakan izinnya. Aplikasi tidak mengirim pesan apa pun ke '
                  'luar perangkat.',
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
    );
  }

  Widget _kartuIzin(ThemeData t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const Key('izin_pengingat_obat'),
              contentPadding: EdgeInsets.zero,
              value: _izin,
              onChanged: _ubahIzin,
              title: Text(tr('obat.izin')),
              subtitle: Text(_izin
                  ? 'Menyala — alarm minum berbunyi pada jam yang Anda isi.'
                  : 'Mati — tidak ada alarm minum.'),
            ),
            Text(
              _izin
                  ? 'Alarm dibuat dari jam minum yang Anda tulis di modul obat.'
                  : 'Nyalakan bila ingin diingatkan. Tanpa izin, jam minum '
                      'tetap tersimpan tapi tidak membunyikan apa pun.',
              key: const Key('kalimat_izin_obat'),
              style: t.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuBerikutnya(ThemeData t) {
    final ringkas = ringkasPengingatObat(_berikutnya, _sekarang);
    return Card(
      key: const Key('berikutnya_obat'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Jam minum berikutnya', style: t.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(ringkas.kalimatBerikutnya),
            if (ringkas.slot.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final s in ringkas.slot.take(3))
                Text(
                  '${s.jam} · ${s.nama}'
                  '${s.dosis.trim().isEmpty ? '' : ' · ${s.dosis}'}',
                  style: t.textTheme.bodyMedium,
                ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Tambahkan jam minum di modul obat supaya pengingat bisa '
                  'dihitung.',
                  style: t.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kartuHariIni(ThemeData t) {
    final jadwal = _hariIni.jadwal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Jam minum hari ini', style: t.textTheme.titleMedium),
            const SizedBox(height: 6),
            if (jadwal.isEmpty)
              Text(
                tr('umum.belumAda'),
                key: const Key('obat_kosong'),
              )
            else ...[
              Text(
                _hariIni.kalimatTercatat,
                key: const Key('jumlah_obat_hari_ini'),
                style: t.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              for (final s in jadwal) _barisSlot(t, s),
            ],
          ],
        ),
      ),
    );
  }

  Widget _barisSlot(ThemeData t, JadwalMinumHariIni s) {
    final kunci = '${s.obatId}_${s.jam.replaceAll(':', '')}';
    final status = s.status;
    return Column(
      key: Key('slot_obat_$kunci'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Row(
          children: [
            Expanded(
              child: Text(
                '${s.jam} · ${s.obat.nama}'
                '${s.obat.dosisTeks == null ? '' : ' · ${s.obat.dosisTeks}'}',
              ),
            ),
            Text(
              status == null ? 'belum dicatat' : status.label,
              style: t.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonal(
              key: Key('minum_$kunci'),
              onPressed: () => _tandai(s, StatusMinum.diminum),
              child: Text(tr('obat.minum')),
            ),
            OutlinedButton(
              key: Key('tunda_$kunci'),
              onPressed: () => _tandai(s, StatusMinum.ditunda),
              child: const Text('Tunda'),
            ),
            OutlinedButton(
              key: Key('lewat_$kunci'),
              onPressed: () => _tandai(s, StatusMinum.dilewati),
              child: Text(tr('obat.terlewat')),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
