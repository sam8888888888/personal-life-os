/// FR-43 — Layar Mode Rumah Tangga.
///
/// Sekali lihat: nama rumah, kode undangan (bagi yang mau ikut tanpa akun),
/// tagihan bersama beserta bagian tiap anggota, siapa sudah bayar, dan
/// pengingat yang HARUS dikirim sendiri oleh pengguna.
library;

import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/platform/buka_tautan.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/batch12_providers.dart';
import '../../core/rumah/rumah_tangga.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';

class RumahTanggaScreen extends ConsumerStatefulWidget {
  const RumahTanggaScreen({super.key});

  @override
  ConsumerState<RumahTanggaScreen> createState() => _RumahTanggaScreenState();
}

class _RumahTanggaScreenState extends ConsumerState<RumahTanggaScreen> {
  List<RumahTanggaData> _rumah = const [];
  List<String> _namaKeluarga = const [];
  int? _terpilih;
  HasilRumahTangga? _hasil;
  bool _siap = false;
  String? _galat;
  StreamSubscription<void>? _pantauan;

  @override
  void initState() {
    super.initState();
    _muat();
    final db = ref.read(databaseProvider);
    _pantauan = db
        .tableUpdates(TableUpdateQuery.onAllTables(
            [db.rumahTangga, db.tagihanRumahBersama, db.bagianTagihanRumah]))
        .listen((_) {
      if (mounted) _muat();
    });
  }

  @override
  void dispose() {
    _pantauan?.cancel();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final repo = ref.read(repoRumahTanggaProvider);
      final keluarga = await ref.read(sumberNamaAnggotaKeluargaProvider)();
      final daftar = await repo.semuaRumah();
      final pilih = _terpilih ??
          (daftar.isEmpty ? null : daftar.first.id);
      HasilRumahTangga? hasil;
      final petaUid = <String, String>{};
      final cacheBagian = <String, List<BagianRumah>>{};
      if (pilih != null) {
        final rumah = daftar.firstWhere((r) => r.id == pilih);
        for (final t in await repo.tagihan(rumah.uid ?? '')) {
          final model = TagihanBersama(
            rumahNama: rumah.nama,
            judul: t.judul,
            totalSen: t.totalSen,
            jatuhTempo: t.jatuhTempo,
            penanggung:
                t.penanggung.trim().isEmpty ? null : t.penanggung,
            catatan: t.catatan,
          );
          final kunci = kunciTagihanBersama(model);
          if (t.uid != null) petaUid[kunci] = t.uid!;
          cacheBagian[kunci] = [
            for (final b in await repo.bagian(t.uid ?? ''))
              BagianRumah(
                kunciTagihan: kunci,
                anggota: b.anggota,
                jumlahSen: b.jumlahSen,
                dibayarSen: b.dibayarSen,
                waktuBayar: b.waktuBayar,
                catatan: b.catatan,
              ),
          ];
        }
        hasil = await repo.hasil(
          pilih,
          namaAnggotaTambahan: [for (final k in keluarga) k.nama],
        );
      }
      if (!mounted) return;
      setState(() {
        _rumah = daftar;
        _namaKeluarga = [for (final k in keluarga) k.nama];
        _terpilih = pilih;
        _hasil = hasil;
        _petaUid
          ..clear()
          ..addAll(petaUid);
        _bagianCache = cacheBagian;
        _siap = true;
        _galat = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _siap = true;
        _galat = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mode Rumah Tangga')),
      body: !_siap
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_galat != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Belum bisa dimuat: $_galat'),
                    ),
                  ),
                _kartuPenjelasan(context),
                const SizedBox(height: 12),
                if (_rumah.isEmpty)
                  _belumAdaRumah(context)
                else ...[
                  _pemilihRumah(context),
                  const SizedBox(height: 12),
                  if (_hasil != null) ..._isiRumah(context, _hasil!),
                ],
                const SizedBox(height: 20),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _dialogRumahBaru(context),
        icon: const Icon(Icons.add),
        label: const Text('Rumah baru'),
      ),
    );
  }

  Widget _kartuPenjelasan(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rumah tangga & tagihan bersama',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Satu rumah tangga punya kode undangan — anggota bisa ikut tanpa '
              'membuat akun. Tagihan bersama dibagi ke anggota, dan aplikasi '
              'mencatat siapa yang sudah menyerahkan bagiannya.',
            ),
            const SizedBox(height: 6),
            const Text(
              'Aplikasi TIDAK mengirim pesan sendiri: pengingat hanya '
              'disiapkan, lalu Anda yang mengirim lewat WhatsApp/SMS.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _belumAdaRumah(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: const [
            Icon(Icons.home_outlined, size: 40),
            SizedBox(height: 8),
            Text('Belum ada rumah tangga.',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Buat satu dulu, lalu isi anggota dan tagihan bersamanya.'),
          ],
        ),
      ),
    );
  }

  Widget _pemilihRumah(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (final r in _rumah)
            ListTile(
              key: Key('rumah-${r.id}'),
              onTap: () {
                setState(() => _terpilih = r.id);
                _muat();
              },
              leading: Icon(r.id == _terpilih
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off),
              title: Text(r.nama),
              subtitle: Text('Kode undangan: ${r.kodeUndangan ?? '-'}'),
              trailing: IconButton(
                tooltip: 'Hapus rumah tangga',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _konfirmasiHapusRumah(context, r),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _isiRumah(BuildContext context, HasilRumahTangga hasil) {
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hasil.dasar, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _dialogTagihanBaru(context, hasil),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Tambah tagihan bersama'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      if (hasil.peringatan.isNotEmpty)
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Perlu diperiksa',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                for (final p in hasil.peringatan)
                  Text('• $p', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      if (hasil.belumBisa.isNotEmpty)
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Belum bisa dihitung',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                for (final b in hasil.belumBisa)
                  Text('• $b', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      for (final t in hasil.tagihan)
        _kartuTagihan(
          context,
          t,
          ringkasBagianTagihan(
            tagihan: t,
            bagian: _bagianCache[kunciTagihanBersama(t)] ?? const [],
          ),
        ),
      if (hasil.anggota.isNotEmpty) _kartuRiwayat(context, hasil),
    ];
  }


  /// Bagian per judul tagihan (diisi `_muatBagian`).
  Map<String, List<BagianRumah>> _bagianCache = {};

  Widget _kartuTagihan(
      BuildContext context, TagihanBersama t, List<RingkasBagian> ringkas) {
    final total = ringkas.fold<int>(0, (a, b) => a + b.jumlahSen);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.judul, style: Theme.of(context).textTheme.titleMedium),
            Text('Total ${fmtRpDariSen(t.totalSen)} · jatuh tempo '
                '${t.jatuhTempo.day}/${t.jatuhTempo.month}/${t.jatuhTempo.year}'),
            if (total != t.totalSen)
              Text('Jumlah bagian tercatat ${fmtRpDariSen(total)}',
                  style: const TextStyle(fontSize: 12)),
            const Divider(),
            if (ringkas.isEmpty)
              const Text('Bagian anggota belum diisi.')
            else
              for (final b in ringkas)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(b.anggota),
                  subtitle: Text(
                      '${fmtRpDariSen(b.jumlahSen)} · '
                      '${b.lunas ? 'sudah lengkap' : 'sisa ${fmtRpDariSen(b.sisaSen)}'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Catat bayar penuh',
                        icon: const Icon(Icons.check_circle_outline),
                        onPressed: b.lunas
                            ? null
                            : () => _catatBayar(context, t, b),
                      ),
                      IconButton(
                        tooltip: 'Siapkan pengingat',
                        icon: const Icon(Icons.chat_outlined),
                        onPressed: () => _pengingat(context, t, b),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _kartuRiwayat(BuildContext context, HasilRumahTangga hasil) {
    final riwayat = riwayatBayarRumah(
      tagihan: hasil.tagihan,
      bagian: [
        for (final l in _bagianCache.values) ...l,
      ],
    );
    if (riwayat.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Siapa bayar apa',
                style: TextStyle(fontWeight: FontWeight.bold)),
            for (final r in riwayat)
              Text('• ${r.waktu.day}/${r.waktu.month} · ${r.anggota} · '
                  '${fmtRpDariSen(r.jumlahSen)} · ${r.judul}',
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _catatBayar(
      BuildContext context, TagihanBersama t, RingkasBagian b) async {
    final repo = ref.read(repoRumahTanggaProvider);
    final uid = _petaUid[kunciTagihanBersama(t)];
    if (uid == null || uid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Tagihan ini belum punya penanda simpan.')));
      }
      return;
    }
    await repo.catatBayar(
      tagihanUid: uid,
      anggota: b.anggota,
      jumlahSen: b.sisaSen,
    );
    await _muat();
  }

  final Map<String, String> _petaUid = {};

  /// Siapkan pengingat: salin ke papan klip & (bila ada) buka WhatsApp.
  /// Aplikasi tidak pernah mengirim sendiri.
  Future<void> _pengingat(
      BuildContext context, TagihanBersama t, RingkasBagian b) async {
    RumahTanggaData? rumah;
    for (final r in _rumah) {
      if (r.id == _terpilih) rumah = r;
    }
    final teks = teksPengingatRumah(
      tagihan: t,
      bagian: b,
      dariNama: rumah?.nama ?? '',
    );
    await Clipboard.setData(ClipboardData(text: teks));
    // Pola sama dengan layar patungan: tautan tanpa nomor, pengguna memilih
    // sendiri kontaknya di WhatsApp. Aplikasi tidak mengirim apa pun sendiri.
    final tautan = 'https://wa.me/?text=${Uri.encodeComponent(teks)}';
    final dibuka = await bukaTautan(tautan);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(dibuka
          ? 'Pengingat disalin & WhatsApp dibuka dengan pesan siap kirim.'
          : 'Pengingat disalin. WhatsApp tidak bisa dibuka di perangkat ini.'),
    ));
  }

  Future<void> _dialogRumahBaru(BuildContext context) async {
    final kontrol = TextEditingController();
    final nama = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rumah tangga baru'),
        content: TextField(
          controller: kontrol,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama rumah tangga'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, kontrol.text),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (nama == null || nama.trim().isEmpty) return;
    await ref.read(repoRumahTanggaProvider).tambahRumah(nama: nama);
    await _muat();
  }

  Future<void> _dialogTagihanBaru(
      BuildContext context, HasilRumahTangga hasil) async {
    final judul = TextEditingController();
    final jumlah = TextEditingController();
    var pilihAnggota = {..._namaKeluarga};
    var jatuhTempo = DateTime.now().add(const Duration(days: 7));
    final rumahId = _terpilih;
    if (rumahId == null) return;
    final rumah = _rumah.firstWhere((r) => r.id == rumahId);
    final disimpan = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: const Text('Tagihan bersama'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: judul,
                  decoration: const InputDecoration(labelText: 'Judul'),
                ),
                TextField(
                  controller: jumlah,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Total (mis. 250000)'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Jatuh tempo'),
                  subtitle: Text(
                      '${jatuhTempo.day}/${jatuhTempo.month}/${jatuhTempo.year}'),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final pilih = await showDatePicker(
                      context: c,
                      initialDate: jatuhTempo,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (pilih != null) setDialog(() => jatuhTempo = pilih);
                  },
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Dibagi rata ke:'),
                ),
                for (final nama in _namaKeluarga)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: pilihAnggota.contains(nama),
                    title: Text(nama),
                    onChanged: (v) => setDialog(() {
                      if (v == true) {
                        pilihAnggota.add(nama);
                      } else {
                        pilihAnggota.remove(nama);
                      }
                    }),
                  ),
                if (_namaKeluarga.isEmpty)
                  const Text(
                      'Belum ada anggota keluarga. Tambahkan dulu di menu '
                      'Keluarga, atau buat tagihan lalu isi bagian manual.'),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (disimpan != true) return;
    final total = senDariKetikan(jumlah.text);
    if (total <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Total tagihan belum benar.')));
      }
      return;
    }
    if (judul.text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Judul tagihan masih kosong.')));
      }
      return;
    }
    await ref.read(repoRumahTanggaProvider).tambahTagihan(
          rumahUid: rumah.uid ?? '',
          judul: judul.text,
          totalSen: total,
          jatuhTempo: jatuhTempo,
          anggota: pilihAnggota.toList(),
        );
    await _muat();
  }

  Future<void> _konfirmasiHapusRumah(
      BuildContext context, RumahTanggaData r) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Hapus ${r.nama}?'),
        content: const Text('Tagihan bersama dan bagian anggotanya ikut terhapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ya != true) return;
    await ref.read(repoRumahTanggaProvider).hapusRumah(r.id);
    setState(() => _terpilih = null);
    await _muat();
  }
}
