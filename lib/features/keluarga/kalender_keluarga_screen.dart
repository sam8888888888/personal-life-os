/// FR-132 — Kalender Keluarga.
///
/// Satu tampilan memuat agenda semua anggota; tiap anggota punya **warna
/// berbeda** (kriteria terima PRD). Warna ditetapkan dari urutan anggota yang
/// hadir pada bulan itu, bukan dari id, jadi tidak ada dua anggota berwarna
/// sama. Ulang tahun dihitung dari tanggal lahir anggota.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/keluarga/kalender_keluarga.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import '../ritme/ritme_providers.dart';

const List<String> _namaBulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

class KalenderKeluargaScreen extends ConsumerStatefulWidget {
  const KalenderKeluargaScreen({super.key});

  @override
  ConsumerState<KalenderKeluargaScreen> createState() =>
      _KalenderKeluargaScreenState();
}

class _KalenderKeluargaScreenState
    extends ConsumerState<KalenderKeluargaScreen> {
  DateTime _bulan = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int? _saringAnggota;
  List<HariKeluarga> _hari = const [];
  List<AnggotaKeluargaData> _anggota = const [];
  Map<int, int> _petaWarna = const {};
  bool _siap = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    muat();
  }

  /// Ambil agenda sebulan penuh (termasuk hari terakhir bulan).
  Future<void> muat() async {
    try {
      final repo = ref.read(repoHidupProvider);
      final awal = DateTime(_bulan.year, _bulan.month, 1);
      final akhir = DateTime(_bulan.year, _bulan.month + 1, 0);
      final agenda = await repo.agendaKeluarga(dari: awal, sampai: akhir);
      final anggota = await repo.anggotaAktif();
      if (!mounted) return;
      setState(() {
        _hari = susunKalenderKeluarga(
          agenda: agenda,
          dari: awal,
          sampai: akhir,
          saringAnggota: _saringAnggota,
        );
        _anggota = anggota;
        // warna dihitung dari seluruh agenda bulan itu (bukan hasil saring)
        // supaya warna anggota tidak berubah saat disaring.
        _petaWarna = warnaAnggotaUntuk(
          susunKalenderKeluarga(agenda: agenda, dari: awal, sampai: akhir)
              .expand((h) => h.agenda),
        );
        _siap = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = 'Agenda belum bisa dibaca: $e';
        _siap = true;
      });
    }
  }

  void _geserBulan(int langkah) {
    setState(() {
      _bulan = DateTime(_bulan.year, _bulan.month + langkah, 1);
      _siap = false;
    });
    muat();
  }

  String _namaAnggota(int? id) {
    if (id == null) return 'Bersama';
    for (final a in _anggota) {
      if (a.id == id) return a.nama;
    }
    return 'Anggota';
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Kalender keluarga')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('kalender_sebelum'),
                onPressed: () => _geserBulan(-1),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Bulan sebelumnya',
              ),
              Expanded(
                child: Text(
                  '${_namaBulan[_bulan.month - 1]} ${_bulan.year}',
                  key: const Key('kalender_bulan'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const Key('kalender_sesudah'),
                onPressed: () => _geserBulan(1),
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Bulan berikutnya',
              ),
            ],
          ),
          Text(
            ringkasKalender(_hari),
            key: const Key('kalender_ringkas'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          // ── keterangan warna per anggota ──────────────────────────────────
          if (_anggota.isNotEmpty) ...[
            Text('Warna per anggota:',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final a in _anggota)
                  Chip(
                    key: Key('kalender_warna_${a.id}'),
                    avatar: CircleAvatar(
                      backgroundColor: Color(warnaUntukAnggota(a.id, _petaWarna)),
                      radius: 8,
                    ),
                    label: Text(a.nama),
                  ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                key: const Key('kalender_saring_semua'),
                label: const Text('Semua anggota'),
                selected: _saringAnggota == null,
                onSelected: (_) {
                  setState(() => _saringAnggota = null);
                  muat();
                },
              ),
              for (final a in _anggota)
                ChoiceChip(
                  key: Key('kalender_saring_${a.id}'),
                  label: Text(a.nama),
                  selected: _saringAnggota == a.id,
                  onSelected: (_) {
                    setState(() => _saringAnggota = a.id);
                    muat();
                  },
                ),
            ],
          ),
          if (_galat != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_galat!, key: const Key('kalender_galat')),
            ),
          const SizedBox(height: 8),
          if (_hari.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.event_available_outlined),
                title: Text('Belum ada agenda bulan ini'),
                subtitle: Text('Tagihan, tugas, janji, jadwal perawatan, dan '
                    'ulang tahun anggota akan muncul di sini.'),
              ),
            ),
          for (final h in _hari)
            Card(
              key: Key('kalender_hari_${_kunci(h.tanggal)}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      fmtTanggalAman(h.tanggal),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final a in h.agenda)
                    ListTile(
                      dense: true,
                      leading: Container(
                        width: 10,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(
                              warnaUntukAnggota(a.anggotaId, _petaWarna)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      title: Text(a.judul),
                      subtitle: Text(
                        '${a.labelModul} · ${_namaAnggota(a.anggotaId)}'
                        '${a.keterangan.isEmpty ? '' : ' · ${a.keterangan}'}',
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _kunci(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}
