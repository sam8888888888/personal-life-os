/// FR-118 — Catatan & ide (modul Pengetahuan).
///
/// Isi: daftar catatan dengan pencarian, saringan kategori, semat, arsip, dan
/// tombol hapus. Catatan ditulis apa adanya oleh pengguna; aplikasi tidak
/// menilai isinya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/laporan/pengetahuan_ringkas.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import 'kartu_lampiran.dart';
import 'komponen_pengetahuan.dart';
import 'provider_pengetahuan.dart';

/// Kategori catatan yang tersedia.
const List<String> kategoriCatatan = <String>[
  'gagasan',
  'rencana',
  'kutipan',
  'pelajaran',
  'lain',
];

class CatatanScreen extends ConsumerStatefulWidget {
  const CatatanScreen({super.key, this.jamSekarang});

  /// Sumber waktu (dipakai uji & tangkapan layar).
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<CatatanScreen> createState() => _CatatanScreenState();
}

class _CatatanScreenState extends ConsumerState<CatatanScreen> {
  bool _memuat = true;
  String _kunci = '';
  String _saringan = 'semua';
  List<BarisCatatan> _catatan = const <BarisCatatan>[];
  final TextEditingController _cari = TextEditingController();

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    final repo = ref.read(pengetahuanRepoProvider);
    try {
      final daftar = await repo.daftarCatatan(termasukArsip: true);
      if (!mounted) return;
      setState(() {
        _catatan = daftar;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _memuat = false);
    }
  }

  List<BarisCatatan> get _terlihat {
    var daftar = cariCatatan(_catatan, _kunci);
    if (_saringan == 'disematkan') {
      daftar = daftar.where((c) => c.disematkan).toList();
    } else if (_saringan == 'arsip') {
      daftar = daftar.where((c) => c.arsip).toList();
    } else if (_saringan != 'semua') {
      daftar = daftar.where((c) => c.kategori == _saringan).toList();
    } else {
      daftar = daftar.where((c) => !c.arsip).toList();
    }
    return daftar;
  }

  Future<void> _simpan({BarisCatatan? ada}) async {
    final judul = TextEditingController(text: ada?.judul ?? '');
    final isi = TextEditingController(text: ada?.isi ?? '');
    final tag = TextEditingController(text: ada?.tag ?? '');
    var kategori = ada?.kategori ?? kategoriCatatan.first;

    final setuju = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setel) => AlertDialog(
          title: Text(ada == null ? 'Catatan baru' : 'Ubah catatan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bidangTeks(pengendali: judul, label: 'Judul'),
                bidangTeks(pengendali: isi, label: 'Isi catatan', baris: 5),
                pemilihChip(
                  label: 'Kategori',
                  pilihan: kategoriCatatan,
                  terpilih: kategori,
                  onPilih: (p) => setel(() => kategori = p),
                ),
                bidangTeks(
                  pengendali: tag,
                  label: 'Tag (boleh dikosongkan)',
                  petunjuk: 'Pisahkan dengan koma, mis. ide, kerja',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              key: const Key('simpan_catatan'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (setuju != true) return;
    if (judul.text.trim().isEmpty || isi.text.trim().isEmpty) return;

    await ref.read(pengetahuanRepoProvider).simpanCatatan(
          id: ada?.id,
          judul: judul.text.trim(),
          isi: isi.text.trim(),
          kategori: kategori,
          tag: tag.text.trim().isEmpty ? null : tag.text.trim(),
          disematkan: ada?.disematkan ?? false,
          sekarang: _sekarang,
        );
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.pengetahuan,
      aksi: ada == null ? AksiAudit.buat : AksiAudit.ubah,
      entitas: 'catatan',
      ringkas: '${ada == null ? 'Catatan baru' : 'Catatan diubah'}: '
          '${judul.text.trim()}',
    );
    await _muat();
  }

  Future<void> _ubahSemat(BarisCatatan c) async {
    await ref.read(pengetahuanRepoProvider).setelSemat(c.id, !c.disematkan);
    await _muat();
  }

  Future<void> _ubahArsip(BarisCatatan c) async {
    await ref.read(pengetahuanRepoProvider).setelArsip(c.id, !c.arsip);
    await _muat();
  }

  /// FR-118 — buka lampiran (foto & rekaman suara) milik satu catatan.
  Future<void> _bukaLampiran(BarisCatatan c) async {
    final uid =
        await ref.read(pengetahuanRepoProvider).pastikanUidCatatan(c.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (k) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(k).viewInsets.bottom),
        child: KartuLampiran(indukTabel: 'catatan_pengetahuan', indukUid: uid),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _hapus(BarisCatatan c) async {
    if (!await konfirmasiHapus(context, 'Catatan "${c.judul}"')) return;
    await ref.read(pengetahuanRepoProvider).hapusCatatan(c.id);
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.pengetahuan,
      aksi: AksiAudit.hapus,
      entitas: 'catatan',
      ringkas: 'Catatan dihapus: ${c.judul}',
    );
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final lihat = _terlihat;
    final ringkas = ringkasCatatan(_catatan);
    return Scaffold(
      appBar: AppBar(title: const Text('Catatan & ide')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tambah_catatan'),
        onPressed: () => _simpan(),
        icon: const Icon(Icons.add),
        label: const Text('Catatan baru'),
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                kartuRingkas('Ringkasan catatan', [
                  barisKunciNilai('Jumlah catatan', '${ringkas.total}'),
                  barisKunciNilai('Disematkan', '${ringkas.jumlahDisematkan}'),
                  barisKunciNilai('Diarsipkan', '${ringkas.jumlahDiarsipkan}'),
                  barisKunciNilai('Tautan', '${ringkas.jumlahTautan}'),
                ]),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextField(
                    key: const Key('cari_catatan'),
                    controller: _cari,
                    onChanged: (v) => setState(() => _kunci = v),
                    decoration: const InputDecoration(
                      labelText: 'Cari catatan',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final s in <String>['semua', 'disematkan', 'arsip', ...kategoriCatatan])
                      ChoiceChip(
                        key: Key('saring_$s'),
                        label: Text(s),
                        selected: _saringan == s,
                        onSelected: (_) => setState(() => _saringan = s),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (lihat.isEmpty)
                  kartuKosong(
                    _catatan.isEmpty
                        ? 'Belum ada catatan'
                        : 'Tidak ada catatan pada saringan ini',
                    petunjuk: _catatan.isEmpty
                        ? 'Tekan "Catatan baru" untuk menulis gagasan, rencana, '
                            'kutipan, atau pelajaran.'
                        : 'Coba ganti saringan atau kata kunci pencarian.',
                  ),
                for (final c in lihat)
                  Card(
                    key: Key('catatan_${c.id}'),
                    child: ListTile(
                      isThreeLine: true,
                      title: Row(
                        children: [
                          if (c.disematkan)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.push_pin, size: 16),
                            ),
                          Expanded(
                            child: Text(c.judul,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.isi, maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Wrap(children: [
                            lencana(c.kategori),
                            if ((c.tag ?? '').isNotEmpty) lencana(c.tag!),
                            if (c.jumlahTautan > 0)
                              lencana('${c.jumlahTautan} tautan'),
                            if (c.arsip) lencana('arsip'),
                            lencana(fmtTanggalPendekAman(c.dibuatPada)),
                          ]),
                        ],
                      ),
                      onTap: () => _simpan(ada: c),
                      trailing: PopupMenuButton<String>(
                        key: Key('menu_catatan_${c.id}'),
                        onSelected: (p) {
                          if (p == 'semat') _ubahSemat(c);
                          if (p == 'arsip') _ubahArsip(c);
                          if (p == 'ubah') _simpan(ada: c);
                          if (p == 'hapus') _hapus(c);
                          if (p == 'lampiran') _bukaLampiran(c);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'semat',
                              child: Text(c.disematkan ? 'Lepas semat' : 'Sematkan')),
                          PopupMenuItem(
                              value: 'arsip',
                              child: Text(c.arsip ? 'Keluarkan dari arsip' : 'Arsipkan')),
                          const PopupMenuItem(value: 'ubah', child: Text('Ubah')),
                          const PopupMenuItem(
                            key: Key('menu_lampiran'),
                            value: 'lampiran',
                            child: Text('Lampiran (foto/suara)'),
                          ),
                          const PopupMenuItem(value: 'hapus', child: Text('Hapus')),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
