/// Kotak Masuk — catat cepat (SDD v19 Gelombang 1).
///
/// Satu pintu, nol keputusan: tulis/tempel apa saja dulu, sortir belakangan.
/// Tiga tindakan yang tersedia saat menyortir:
/// * **Pindahkan ke catatan hari ini** — teks masuk ke halaman catatan harian
///   hari ini, dan dibuat tautan dari kotak masuk ke halaman itu (jejak asal);
/// * **Arsipkan** — dibiarkan ada, hanya keluar dari antrean;
/// * **Buang** — ditandai dibuang, TIDAK dihapus (masih bisa ditelusuri).
///
/// Yang belum ada dan dinyatakan apa adanya: tebakan tujuan otomatis belum
/// dipasang, jadi tidak ada usulan mesin di layar ini.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/v19_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';

class KotakMasukScreen extends ConsumerStatefulWidget {
  const KotakMasukScreen({super.key});

  @override
  ConsumerState<KotakMasukScreen> createState() => _KotakMasukScreenState();
}

class _KotakMasukScreenState extends ConsumerState<KotakMasukScreen> {
  final TextEditingController _isi = TextEditingController();
  List<KotakMasukData> _antrean = const <KotakMasukData>[];
  bool _memuat = true;
  String? _pesan;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _isi.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final List<KotakMasukData> daftar =
          await ref.read(repoKotakMasukProvider).antrean();
      if (!mounted) return;
      setState(() {
        _antrean = daftar;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _pesan = 'Antrean tidak bisa dibaca: $e';
      });
    }
  }

  Future<void> _simpan() async {
    final String teks = _isi.text.trim();
    if (teks.isEmpty) {
      setState(() => _pesan = 'Belum ada yang ditulis.');
      return;
    }
    setState(() => _pesan = null);
    try {
      await ref
          .read(repoKotakMasukProvider)
          .tambah(isi: teks, sumber: 'layar');
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.kotakMasuk,
        aksi: AksiAudit.buat,
        entitas: 'kotak_masuk',
        ringkas: 'Tangkapan cepat disimpan '
            '(${teks.length} huruf, belum disortir).',
      );
      _isi.clear();
      await _muat();
      if (!mounted) return;
      setState(() => _pesan = 'Tersimpan. Sortir kapan saja.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = 'Tidak bisa menyimpan: $e');
    }
  }

  /// Pindahkan satu tangkapan ke halaman catatan harian hari ini.
  Future<void> _pindahkan(KotakMasukData baris) async {
    try {
      final DateTime hari = DateTime.now();
      final halaman =
          await ref.read(repoCatatanHarianProvider).halaman(hari);
      final String barisBaru = '• ${baris.isi}';
      final String isiBaru =
          halaman.isi.trim().isEmpty ? barisBaru : '${halaman.isi}\n$barisBaru';
      await ref.read(repoCatatanHarianProvider).simpanIsi(hari, isiBaru);
      if (halaman.uid != null && baris.uid != null) {
        await ref.read(repoTautanProvider).tambah(
              entitasA: 'kotak_masuk',
              uidA: baris.uid!,
              judulA: _ringkasTeks(baris.isi),
              entitasB: 'catatan_harian',
              uidB: halaman.uid!,
              judulB: fmtTanggalAman(hari),
              label: 'dipindah ke',
            );
      }
      await ref.read(repoKotakMasukProvider).tandaiDiproses(
            baris.id,
            tujuanTabel: 'catatan_harian',
            tujuanUid: halaman.uid ?? '',
          );
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.kotakMasuk,
        aksi: AksiAudit.ubah,
        entitas: 'kotak_masuk',
        entitasId: '${baris.id}',
        ringkas: 'Tangkapan cepat dipindahkan ke catatan harian '
            '${fmtTanggalAman(hari)}.',
      );
      await _muat();
      if (!mounted) return;
      setState(() => _pesan = 'Dipindahkan ke catatan hari ini.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = 'Tidak bisa memindahkan: $e');
    }
  }

  Future<void> _arsipkan(KotakMasukData b) => _ubah(
      b, 'diarsipkan', () => ref.read(repoKotakMasukProvider).arsipkan(b.id));

  Future<void> _buang(KotakMasukData b) => _ubah(
      b, 'dibuang', () => ref.read(repoKotakMasukProvider).buang(b.id));

  Future<void> _ubah(
    KotakMasukData baris,
    String kata,
    Future<void> Function() aksi,
  ) async {
    try {
      await aksi();
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.kotakMasuk,
        aksi: AksiAudit.ubah,
        entitas: 'kotak_masuk',
        entitasId: '${baris.id}',
        ringkas: 'Tangkapan cepat $kata.',
      );
      await _muat();
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = 'Tidak bisa mengubah: $e');
    }
  }

  /// Arsipkan tangkapan yang lebih tua dari 30 hari — atas permintaan pengguna.
  Future<void> _arsipkanLama() async {
    try {
      final int jumlah =
          await ref.read(repoKotakMasukProvider).arsipkanLebihTuaDari(30);
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.kotakMasuk,
        aksi: AksiAudit.bersihkan,
        entitas: 'kotak_masuk',
        ringkas: '$jumlah tangkapan lebih tua dari 30 hari diarsipkan.',
      );
      await _muat();
      if (!mounted) return;
      setState(() => _pesan = jumlah == 0
          ? 'Tidak ada yang perlu diarsipkan.'
          : '$jumlah tangkapan lama diarsipkan.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = 'Tidak bisa mengarsipkan: $e');
    }
  }

  static String _ringkasTeks(String teks) {
    final String satuBaris = teks.replaceAll('\n', ' ').trim();
    if (satuBaris.length <= 60) return satuBaris;
    return '${satuBaris.substring(0, 57)}...';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Catat Cepat')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: <Widget>[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    key: const Key('km_isi'),
                    controller: _isi,
                    maxLines: 3,
                    minLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Apa pun yang ingin diingat',
                      hintText: 'Tulis, tempel, atau salin dari mana saja.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      FilledButton.icon(
                        key: const Key('km_simpan'),
                        onPressed: _simpan,
                        icon: const Icon(Icons.inbox_outlined),
                        label: const Text('Simpan ke kotak masuk'),
                      ),
                    ],
                  ),
                  if (_pesan != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(_pesan!, key: const Key('km_pesan')),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _memuat
                          ? 'Menunggu disortir…'
                          : 'Menunggu disortir: ${_antrean.length}',
                      key: const Key('km_judul_antrean'),
                      style: tema.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    key: const Key('km_arsip_lama'),
                    onPressed: _arsipkanLama,
                    child: const Text('Arsipkan > 30 hari'),
                  ),
                ],
              ),
            ),
          ),
          if (!_memuat && _antrean.isEmpty)
            const Card(
              margin: EdgeInsets.only(top: 12),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Kotak masuk kosong. Semua sudah disortir.',
                  key: Key('km_kosong'),
                ),
              ),
            ),
          for (final KotakMasukData b in _antrean)
            Card(
              margin: const EdgeInsets.only(top: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(b.isi.isEmpty ? '(tanpa teks)' : b.isi,
                        maxLines: 4, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      'Masuk ${fmtTanggalPendekAman(b.dibuatPada)} · ${b.sumber}',
                      style: tema.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        OutlinedButton(
                          key: Key('km_pindah_${b.id}'),
                          onPressed: () => _pindahkan(b),
                          child: const Text('Ke catatan hari ini'),
                        ),
                        TextButton(
                          key: Key('km_arsip_${b.id}'),
                          onPressed: () => _arsipkan(b),
                          child: const Text('Arsipkan'),
                        ),
                        TextButton(
                          key: Key('km_buang_${b.id}'),
                          onPressed: () => _buang(b),
                          child: const Text('Buang'),
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
