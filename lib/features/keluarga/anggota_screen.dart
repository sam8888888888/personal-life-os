/// FR-131 — Anggota keluarga & tanggung jawab.
///
/// Satu layar:
///  1. daftar anggota + beban (jumlah tagihan, total tagihan, tugas terbuka);
///  2. tambah/ubah anggota (hubungan, tanggal lahir, tanda `pribadi`);
///  3. **saringan per anggota**: menekan satu anggota menampilkan tagihan &
///     tugas miliknya — penting karena satu item bisa dimiliki anak tetapi
///     ditanggung pasangan (contoh PRD: tagihan sekolah);
///  4. menetapkan pemilik/penanggung jawab dari daftar item anggota.
///
/// Data anggota bertanda `pribadi` (mis. anak) hanya ditampilkan bila perangkat
/// TIDAK terkunci — pemeriksaannya lewat kanal perangkat, bukan tombol biasa.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/berkas_medis.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/keluarga_repository.dart';
import 'keluarga_providers.dart';

class AnggotaScreen extends ConsumerStatefulWidget {
  const AnggotaScreen({super.key});

  @override
  ConsumerState<AnggotaScreen> createState() => _AnggotaScreenState();
}

class _AnggotaScreenState extends ConsumerState<AnggotaScreen> {
  List<AnggotaDenganBeban> _daftar = const [];
  bool _siap = false;
  bool _sertakanPribadi = false;
  int? _pilihAnggota;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    // Data anggota `pribadi` hanya ikut bila perangkat sudah dibuka.
    final terkunci = await perangkatTerkunci();
    if (!mounted) return;
    _sertakanPribadi = !terkunci;
    final repo = ref.read(repoKeluargaProvider);
    final daftar = await repo.ringkasBeban(sertakanPribadi: _sertakanPribadi);
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
    final terpilih = _pilihAnggota == null
        ? null
        : _daftar.where((d) => d.anggota.id == _pilihAnggota).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(terpilih == null
            ? 'Anggota keluarga'
            : 'Tanggung jawab ${terpilih.anggota.nama}'),
        leading: terpilih == null
            ? null
            : IconButton(
                key: const Key('anggota_kembali'),
                onPressed: () => setState(() => _pilihAnggota = null),
                icon: const Icon(Icons.arrow_back),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('anggota_tambah'),
        onPressed: () => _formAnggota(),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Tambah anggota'),
      ),
      body: terpilih == null ? _daftarAnggota() : _rincianAnggota(terpilih),
    );
  }

  Widget _daftarAnggota() {
    if (_daftar.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Belum ada anggota keluarga. Tombol "Tambah anggota" '
            'mengisi nama, hubungan, dan (opsional) tanggal lahir.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        if (!_sertakanPribadi)
          const Card(
            child: ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Sebagian data disembunyikan'),
              subtitle: Text('Anggota bertanda pribadi hanya tampil setelah '
                  'perangkat dibuka (kunci layar dilepas).'),
            ),
          ),
        for (final d in _daftar)
          Card(
            key: Key('anggota_baris_${d.anggota.id}'),
            child: ListTile(
              leading: Icon(d.anggota.pribadi
                  ? Icons.lock_person_outlined
                  : Icons.person_outline),
              title: Text(d.anggota.nama),
              subtitle: Text('${d.anggota.hubungan} · '
                  '${d.jumlahTagihan} tagihan'
                  '${d.totalTagihanSen == 0 ? '' : ' (${fmtRpDariSen(d.totalTagihanSen)})'}'
                  ' · ${d.jumlahTugas} tugas terbuka'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() => _pilihAnggota = d.anggota.id),
              onLongPress: () => _formAnggota(d.anggota),
            ),
          ),
      ],
    );
  }

  Widget _rincianAnggota(AnggotaDenganBeban d) {
    return FutureBuilder<List<Object>>(
      future: _itemAnggota(d.anggota.id),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final tagihan = (snap.data?[0] as List<TagihanData>?) ?? const [];
        final tugas = (snap.data?[1] as List<Tuga>?) ?? const [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            Text('Tagihan (${tagihan.length})',
                style: Theme.of(context).textTheme.titleMedium),
            if (tagihan.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Belum ada tagihan untuk anggota ini.'),
              ),
            for (final t in tagihan)
              Card(
                key: Key('anggota_tagihan_${t.id}'),
                child: ListTile(
                  title: Text(t.nama),
                  subtitle: Text('${fmtRpDariSen(t.jumlahSen ?? 0)} · '
                      'jatuh tempo ${fmtTanggalPendekAman(t.jatuhTempo)}'
                      '${t.penanggungJawabId == null ? '' : ' · penanggung jawab: ${_nama(t.penanggungJawabId!)}'}'),
                  trailing: TextButton(
                    key: Key('anggota_aturop_${t.id}'),
                    onPressed: () => _aturPenanggungJawab(tagihanId: t.id),
                    child: const Text('Atur'),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text('Tugas (${tugas.length})',
                style: Theme.of(context).textTheme.titleMedium),
            if (tugas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Belum ada tugas untuk anggota ini.'),
              ),
            for (final g in tugas)
              Card(
                key: Key('anggota_tugas_${g.id}'),
                child: ListTile(
                  title: Text(g.nama),
                  subtitle: Text(g.selesai ? 'Selesai' : 'Belum selesai'),
                  trailing: TextButton(
                    key: Key('anggota_aturtugas_${g.id}'),
                    onPressed: () => _aturPenanggungJawab(tugasId: g.id),
                    child: const Text('Atur'),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('anggota_ubah'),
              onPressed: () => _formAnggota(d.anggota),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Ubah anggota'),
            ),
          ],
        );
      },
    );
  }

  Future<List<Object>> _itemAnggota(int id) async {
    final repo = ref.read(repoKeluargaProvider);
    return [await repo.tagihanAnggota(id), await repo.tugasAnggota(id)];
  }

  String _nama(int id) {
    for (final d in _daftar) {
      if (d.anggota.id == id) return d.anggota.nama;
    }
    return 'anggota lain';
  }

  Future<void> _formAnggota([AnggotaKeluargaData? lama]) async {
    final nama = TextEditingController(text: lama?.nama ?? '');
    final catatan = TextEditingController(text: lama?.catatan ?? '');
    var hubungan = lama?.hubungan ?? 'anak';
    var pribadi = lama?.pribadi ?? false;
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: Text(lama == null ? 'Tambah anggota' : 'Ubah anggota'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('form_anggota_nama'),
                  controller: nama,
                  decoration: const InputDecoration(labelText: 'Nama'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const Key('form_anggota_hubungan'),
                  initialValue: hubungan,
                  decoration: const InputDecoration(labelText: 'Hubungan'),
                  items: [
                    for (final h in KeluargaRepository.hubungan)
                      DropdownMenuItem(value: h, child: Text(h)),
                  ],
                  onChanged: (v) => setDialog(() => hubungan = v ?? hubungan),
                ),
                CheckboxListTile(
                  key: const Key('form_anggota_pribadi'),
                  value: pribadi,
                  onChanged: (v) => setDialog(() => pribadi = v ?? false),
                  title: const Text('Data terbatas (pribadi)'),
                  subtitle: const Text('Hanya tampil setelah perangkat dibuka'),
                ),
                TextField(
                  key: const Key('form_anggota_catatan'),
                  controller: catatan,
                  decoration: const InputDecoration(labelText: 'Catatan'),
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
              key: const Key('form_anggota_simpan'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (lanjut != true) return;
    try {
      await ref.read(repoKeluargaProvider).simpanAnggota(
            id: lama?.id,
            nama: nama.text,
            hubungan: hubungan,
            pribadi: pribadi,
            catatan: catatan.text,
          );
      await _muat();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Belum bisa disimpan: $e')));
    }
  }

  Future<void> _aturPenanggungJawab({int? tagihanId, int? tugasId}) async {
    final pilihan = await showDialog<AnggotaKeluargaData>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Pilih penanggung jawab'),
        children: [
          for (final d in _daftar)
            SimpleDialogOption(
              key: Key('pilih_pj_${d.anggota.id}'),
              onPressed: () => Navigator.pop(c, d.anggota),
              child: Text('${d.anggota.nama} (${d.anggota.hubungan})'),
            ),
        ],
      ),
    );
    if (pilihan == null) return;
    final repo = ref.read(repoKeluargaProvider);
    if (tagihanId != null) {
      await repo.tetapkanPemilikTagihan(tagihanId, penanggungJawabId: pilihan.id);
    } else if (tugasId != null) {
      await repo.tetapkanPemilikTugas(tugasId, penanggungJawabId: pilihan.id);
    }
    await _muat();
    if (!mounted) return;
    setState(() {});
  }
}
