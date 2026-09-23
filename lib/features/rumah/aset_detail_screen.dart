/// FR-124/125/126/127 — Rincian satu aset: garansi, perkiraan umur pakai,
/// jadwal perawatan, dan riwayat perbaikan berbiaya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/rumah/aset_fisik.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';
import 'rumah_providers.dart';

class AsetDetailScreen extends ConsumerStatefulWidget {
  const AsetDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<AsetDetailScreen> createState() => _AsetDetailScreenState();
}

class _AsetDetailScreenState extends ConsumerState<AsetDetailScreen> {
  AsetData? _aset;
  List<PerawatanData> _jadwal = const [];
  List<RiwayatPerawatanAsetData> _riwayat = const [];
  RingkasanBiayaPerawatan? _biaya;
  bool _siap = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final repo = ref.read(repoRumahProvider);
    final aset = await repo.ambilAsetSatu(widget.id);
    if (aset == null) {
      if (mounted) {
        setState(() {
          _galat = 'Aset tidak ditemukan.';
          _siap = true;
        });
      }
      return;
    }
    final jadwal = await repo.jadwalAset(widget.id);
    final riwayat = await repo.riwayatAset(widget.id);
    final biaya = await repo.ringkasBiayaAset(widget.id);
    if (!mounted) return;
    setState(() {
      _aset = aset;
      _jadwal = jadwal;
      _riwayat = riwayat;
      _biaya = biaya;
      _siap = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final a = _aset;
    if (a == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Aset')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_galat ?? 'Aset tidak bisa dibuka.'),
        ),
      );
    }
    final sekarang = DateTime.now();
    final garansi = periksaGaransi(a.garansiSampai, sekarang);
    final umur = perkiraanUmurPakai(
      tanggalBeli: a.tanggalBeli,
      masaPakaiBulan: a.masaPakaiBulan,
      hargaBeliSen: a.hargaBeliSen,
      sekarang: sekarang,
    );
    final jenis = JenisAsetFisik.dariKode(a.jenis);
    return Scaffold(
      appBar: AppBar(
        title: Text(a.nama),
        actions: [
          IconButton(
            key: const Key('aset_ubah'),
            tooltip: 'Ubah aset',
            onPressed: () async {
              await context.push<bool>('/rumah/aset/form?id=${a.id}');
              await _muat();
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: const Key('aset_arsipkan'),
            tooltip: 'Sembunyikan aset',
            onPressed: _arsipkan,
            icon: const Icon(Icons.archive_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _baris('Jenis', jenis?.label ?? a.jenis),
                  if (a.nomorSeri != null) _baris('Nomor seri', a.nomorSeri!),
                  if (a.lokasi != null) _baris('Lokasi', a.lokasi!),
                  if (a.tanggalBeli != null)
                    _baris('Tanggal beli', fmtTanggalPendekAman(a.tanggalBeli!)),
                  if (a.hargaBeliSen != null)
                    _baris('Harga beli', fmtRpDariSen(a.hargaBeliSen!)),
                  if (a.catatan != null) _baris('Catatan', a.catatan!),
                ],
              ),
            ),
          ),
          Card(
            key: const Key('aset_garansi_kartu'),
            child: ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: const Text('Garansi'),
              subtitle: Text(garansi.keterangan),
            ),
          ),
          Card(
            key: const Key('aset_umur_kartu'),
            child: ListTile(
              leading: const Icon(Icons.timelapse_outlined),
              title: const Text('Perkiraan umur pakai (estimasi)'),
              subtitle: Text(umur == null
                  ? 'Isi tanggal beli & masa pakai (bulan) supaya bisa diperkirakan.'
                  : '${umur.dasar}\n'
                      '${umur.sudahLewat ? 'Sudah lewat ${-umur.sisaBulan} bulan' : 'Sisa ${umur.sisaBulan} bulan'}'
                      '${umur.danaSisihPerBulanSen == null ? '' : ' · saran sisihkan ${fmtRpDariSen(umur.danaSisihPerBulanSen!)} per bulan'}'),
              isThreeLine: umur != null,
            ),
          ),
          _judul('Jadwal perawatan', aksi: [
            TextButton.icon(
              key: const Key('jadwal_tambah'),
              onPressed: _tambahJadwal,
              icon: const Icon(Icons.add_alarm_outlined),
              label: const Text('Tambah jadwal'),
            ),
          ]),
          if (_jadwal.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text('Belum ada jadwal perawatan untuk aset ini.'),
            ),
          for (final p in _jadwal) _barisJadwal(p, sekarang),
          _judul('Riwayat perbaikan & biaya', aksi: [
            TextButton.icon(
              key: const Key('riwayat_tambah'),
              onPressed: _tambahRiwayat,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Catat perbaikan'),
            ),
          ]),
          if (_biaya != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Total biaya: ${fmtRpDariSen(_biaya!.totalSen)} · '
                '${_biaya!.keterangan}'
                '${_biaya!.rataPerTahunSen == null ? '' : ' · rata-rata ${fmtRpDariSen(_biaya!.rataPerTahunSen!)} per tahun'}',
                key: const Key('riwayat_total'),
              ),
            ),
          if (_riwayat.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text('Belum ada catatan perbaikan.'),
            ),
          for (final r in _riwayat) _barisRiwayat(r),
        ],
      ),
    );
  }

  Widget _judul(String teks, {List<Widget> aksi = const []}) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(teks, style: Theme.of(context).textTheme.titleMedium),
            ),
            ...aksi,
          ],
        ),
      );

  Widget _baris(String label, String nilai) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Text(nilai)),
          ],
        ),
      );

  Widget _barisJadwal(PerawatanData p, DateTime sekarang) {
    final sisa = bedaHari(sekarang, p.berikutnya);
    return Card(
      key: Key('jadwal_baris_${p.id}'),
      child: ListTile(
        leading: const Icon(Icons.build_outlined),
        title: Text(p.nama),
        subtitle: Text(sisa < 0
            ? 'Jadwal lewat ${-sisa} hari · ${fmtTanggalPendekAman(p.berikutnya)}'
            : sisa == 0
                ? 'Jadwal hari ini'
                : 'Jadwal ${fmtTanggalPendekAman(p.berikutnya)} · $sisa hari lagi'),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              key: Key('jadwal_selesai_${p.id}'),
              tooltip: 'Tandai selesai',
              onPressed: () async {
                await ref.read(repoRumahProvider).tandaiJadwalSelesai(p.id);
                await _muat();
              },
              icon: const Icon(Icons.check_circle_outline),
            ),
            IconButton(
              key: Key('jadwal_hapus_${p.id}'),
              tooltip: 'Hapus jadwal',
              onPressed: () async {
                await ref.read(repoRumahProvider).hapusJadwal(p.id);
                await _muat();
              },
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barisRiwayat(RiwayatPerawatanAsetData r) => Card(
        key: Key('riwayat_baris_${r.id}'),
        child: ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: Text(r.uraian),
          subtitle: Text('${fmtTanggalPendekAman(r.tanggal)} · '
              '${fmtRpDariSen(r.biayaSen)}'
              '${r.transaksiId == null ? '' : ' · tertaut pengeluaran'}'),
          trailing: IconButton(
            key: Key('riwayat_hapus_${r.id}'),
            tooltip: 'Hapus catatan',
            onPressed: () async {
              await ref.read(repoRumahProvider).hapusRiwayat(r.id);
              await _muat();
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      );

  Future<void> _arsipkan() async {
    await ref.read(repoRumahProvider).arsipkanAset(widget.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _tambahJadwal() async {
    final nama = TextEditingController();
    final interval = TextEditingController(text: '365');
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Jadwal perawatan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('jadwal_nama'),
              controller: nama,
              decoration: const InputDecoration(
                labelText: 'Nama perawatan',
                hintText: 'mis. Ganti oli, servis AC',
              ),
            ),
            TextField(
              key: const Key('jadwal_interval'),
              controller: interval,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Setiap berapa hari',
                helperText: 'mis. 180 (6 bulan), 365 (1 tahun)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(
            key: const Key('jadwal_simpan'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (lanjut != true) return;
    final hari = int.tryParse(interval.text.trim()) ?? 365;
    try {
      await ref.read(repoRumahProvider).tambahJadwalAset(
            asetId: widget.id,
            nama: nama.text,
            intervalHari: hari <= 0 ? 365 : hari,
            kategori: _aset?.jenis ?? 'lain',
          );
      await _muat();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Belum bisa disimpan: $e')));
    }
  }

  Future<void> _tambahRiwayat() async {
    final uraian = TextEditingController();
    final biaya = TextEditingController();
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Catat perbaikan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('riwayat_uraian'),
              controller: uraian,
              decoration: const InputDecoration(
                labelText: 'Pekerjaan',
                hintText: 'mis. Ganti oli + filter udara',
              ),
            ),
            TextField(
              key: const Key('riwayat_biaya'),
              controller: biaya,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Biaya (Rp)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(
            key: const Key('riwayat_simpan'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (lanjut != true) return;
    final rupiah = parseRupiah(biaya.text);
    try {
      await ref.read(repoRumahProvider).tambahRiwayat(
            asetId: widget.id,
            uraian: uraian.text,
            tanggal: DateTime.now(),
            biayaSen: rupiah == null ? 0 : rupiahKeSen(rupiah),
          );
      await _muat();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Belum bisa disimpan: $e')));
    }
  }
}
