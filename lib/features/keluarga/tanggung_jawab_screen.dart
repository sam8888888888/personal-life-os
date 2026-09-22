/// FR-133 — Layar Kas & Tanggung Jawab Rumah Tangga.
///
/// "Siapa bayar apa" + pengingat halus satu ketukan + catatan pelunasan.
/// Pengingat TIDAK terkirim tanpa persetujuan pengguna: saklar ada di layar ini
/// (tersimpan di tabel `pengaturan`) dan diperiksa lagi sebelum mengirim.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifikasi/model_pengingat.dart';
import '../../core/notifikasi/perencana_pengingat.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/batch10_providers.dart';
import '../../core/perjalanan/perjalanan.dart' show fmtRingkasRp;
import '../../core/rumah/tanggung_jawab_rumah.dart';
import '../../core/utils/bahasa.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';

/// Rentang ID notifikasi khusus fitur ini (jangan bertabrakan dengan tagihan,
/// briefing, atau sholat — lihat `perencana_pengingat.dart`).
const int idDasarPengingatRumah = batasIdKhusus + 500;

class TanggungJawabScreen extends ConsumerStatefulWidget {
  const TanggungJawabScreen({super.key});

  @override
  ConsumerState<TanggungJawabScreen> createState() =>
      _TanggungJawabScreenState();
}

class _TanggungJawabScreenState extends ConsumerState<TanggungJawabScreen> {
  RingkasanRumahTangga? _r;
  List<TanggungJawabRumahData> _baris = const [];
  bool _izin = false;
  bool _siap = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final repo = ref.read(repoTanggungJawabProvider);
      final baris = await repo.semua();
      final ringkas = await repo.ringkasan();
      final izin = await repo.persetujuanMenyala();
      if (!mounted) return;
      setState(() {
        _baris = baris;
        _r = ringkas;
        _izin = izin;
        _siap = true;
        _galat = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _siap = true;
        _galat = 'Gagal memuat data rumah tangga: ${e.runtimeType}.';
      });
    }
  }

  Future<void> _ubahIzin(bool nilai) async {
    await ref.read(repoTanggungJawabProvider).setPersetujuan(nilai);
    if (!mounted) return;
    setState(() => _izin = nilai);
    _pesan(nilai
        ? 'Pengingat rumah tangga diizinkan (maksimal sekali sehari, jam 08.00–21.00).'
        : 'Pengingat rumah tangga dimatikan — tidak ada yang terkirim.');
  }

  Future<void> _tambah() async {
    final nama = TextEditingController();
    final jumlah = TextEditingController();
    final jatuhTempo = TextEditingController();
    final pemilik = TextEditingController();
    final penanggung = TextEditingController();
    final hasil = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kewajiban rumah tangga'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const Key('rumah_nama'),
              controller: nama,
              decoration: const InputDecoration(
                  labelText: 'Nama', hintText: 'Contoh: SPP sekolah'),
            ),
            TextField(
              key: const Key('rumah_jumlah'),
              controller: jumlah,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jumlah (Rp)'),
            ),
            TextField(
              key: const Key('rumah_jatuh_tempo'),
              controller: jatuhTempo,
              decoration: const InputDecoration(
                  labelText: 'Jatuh tempo (YYYY-MM-DD)', hintText: '2026-10-10'),
            ),
            TextField(
              key: const Key('rumah_pemilik'),
              controller: pemilik,
              decoration: const InputDecoration(
                  labelText: 'Untuk siapa (boleh kosong)'),
            ),
            TextField(
              key: const Key('rumah_penanggung'),
              controller: penanggung,
              decoration: const InputDecoration(
                  labelText: 'Yang membayar (boleh kosong)'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('umum.batal'))),
          FilledButton(
            key: const Key('rumah_simpan'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('umum.simpan')),
          ),
        ],
      ),
    );
    if (hasil != true) return;
    final jt = DateTime.tryParse(jatuhTempo.text.trim());
    if (nama.text.trim().isEmpty || jt == null) {
      _pesan('Nama dan jatuh tempo wajib diisi (format tanggal 2026-10-10).');
      return;
    }
    try {
      await ref.read(repoTanggungJawabProvider).tambah(
            nama: nama.text,
            jumlahSen: senDariKetikan(jumlah.text),
            jatuhTempo: jt,
            pemilikNama: pemilik.text,
            penanggungJawabNama: penanggung.text,
          );
      await _muat();
      _pesan('Kewajiban disimpan.');
    } catch (e) {
      _pesan(e is ArgumentError ? '${e.message}' : 'Gagal menyimpan: ${e.runtimeType}.');
    }
  }

  /// Pengingat halus: satu ketukan, tetapi hanya dikirim bila semua syarat
  /// terpenuhi (izin pengguna, belum lunas, jam wajar, belum diingatkan hari ini).
  Future<void> _ingatkan(TanggungJawabRumahData baris) async {
    final item = KewajibanRumah(
      nama: baris.nama,
      jumlahSen: baris.jumlahSen,
      jatuhTempo: baris.jatuhTempo,
      pemilikNama: baris.pemilikNama,
      penanggungJawabNama: baris.penanggungJawabNama,
      lunas: baris.lunas,
      diingatkanPada: baris.diingatkanPada,
    );
    final sekarang = DateTime.now();
    final alasan = alasanTidakBolehDiingatkan(item,
        sekarang: sekarang, persetujuanMenyala: _izin);
    if (alasan.isNotEmpty) {
      _pesan('Tidak dikirim: ${alasan.join(' ')}');
      return;
    }
    final waktu = sekarang.add(const Duration(seconds: 3));
    try {
      await ref.read(layananNotifikasiProvider).jadwalkanSatu(Pengingat(
            id: idDasarPengingatRumah + baris.id,
            tagihanId: 0,
            waktu: waktu,
            kanal: KanalNotifikasi.ringkasan,
            judul: 'Pengingat rumah tangga',
            isi: teksPengingatHalus(item, sekarang: sekarang),
          ));
      await ref.read(repoTanggungJawabProvider).catatDiingatkan(baris.id, sekarang);
      await _muat();
      _pesan('Pengingat halus dikirim (muncul dalam beberapa detik).');
    } catch (e) {
      _pesan('Gagal mengirim pengingat: ${e.runtimeType}.');
    }
  }

  Future<void> _lunas(TanggungJawabRumahData baris) async {
    final catatan = TextEditingController();
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${tr('rumah.lunas')}: ${baris.nama}'),
        content: TextField(
          key: const Key('rumah_catatan_lunas'),
          controller: catatan,
          decoration: InputDecoration(
              labelText: tr('rumah.catatanPelunasan'),
              hintText: 'Contoh: dibayar tunai oleh Mami'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('umum.batal'))),
          FilledButton(
            key: const Key('rumah_simpan_lunas'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('umum.simpan')),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    await ref
        .read(repoTanggungJawabProvider)
        .tandaiLunas(baris.id, catatanPelunasan: catatan.text);
    await _muat();
    _pesan('Ditandai lunas — tercatat di riwayat pelunasan.');
  }

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: Text(tr('rumah.judul'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('rumah_tambah'),
        onPressed: _tambah,
        icon: const Icon(Icons.add),
        label: Text(tr('umum.tambah')),
      ),
      body: !_siap
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (_galat != null)
                  Card(
                    key: const Key('rumah_galat'),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                        padding: const EdgeInsets.all(12), child: Text(_galat!)),
                  ),
                Card(
                  key: const Key('rumah_ringkasan'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('rumah.siapaBayarApa'),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          if (r != null) ...[
                            Text(r.dasar),
                            for (final a in r.perAnggota)
                              Padding(
                                key: Key('rumah_anggota_${a.nama}'),
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('• ${a.nama}: '
                                    '${fmtRingkasRp(a.totalSen)} '
                                    '(${a.jumlahLunas}/${a.jumlahItem} lunas, '
                                    'sisa ${fmtRingkasRp(a.sisaSen)})'),
                              ),
                            for (final b in r.belumBisa) ...[
                              const SizedBox(height: 4),
                              Text('${tr('umum.belumBisa')}: $b',
                                  style:
                                      const TextStyle(fontStyle: FontStyle.italic)),
                            ],
                          ] else
                            Text(tr('umum.belumAda')),
                        ]),
                  ),
                ),
                Card(
                  child: SwitchListTile(
                    key: const Key('rumah_izin'),
                    value: _izin,
                    onChanged: _ubahIzin,
                    title: Text(tr('rumah.pengingatHalus')),
                    subtitle: const Text('Pengingat hanya dikirim kalau saklar ini '
                        'menyala, maksimal sekali sehari, pada jam wajar '
                        '08.00–21.00. Tidak ada pesan otomatis ke anggota lain.'),
                  ),
                ),
                for (final b in _baris) _kartuItem(b),
                if (r != null && r.riwayatPelunasan().isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 4),
                    child: Text('RIWAYAT PELUNASAN',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  for (final h in r.riwayatPelunasan())
                    ListTile(
                      key: Key('rumah_riwayat_${h.nama}'),
                      dense: true,
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(h.nama),
                      subtitle: Text([
                        fmtRingkasRp(h.jumlahSen),
                        'dibayar ${h.tanggalBayar == null ? '-' : '${h.tanggalBayar!.day}/${h.tanggalBayar!.month}/${h.tanggalBayar!.year}'}',
                        if ((h.catatanPelunasan ?? '').isNotEmpty) h.catatanPelunasan!,
                      ].join(' · ')),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _kartuItem(TanggungJawabRumahData b) {
    final item = KewajibanRumah(
      nama: b.nama,
      jumlahSen: b.jumlahSen,
      jatuhTempo: b.jatuhTempo,
      pemilikNama: b.pemilikNama,
      penanggungJawabNama: b.penanggungJawabNama,
      lunas: b.lunas,
      diingatkanPada: b.diingatkanPada,
    );
    final alasan = alasanTidakBolehDiingatkan(item,
        sekarang: DateTime.now(), persetujuanMenyala: _izin);
    return Card(
      key: Key('rumah_${b.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b.nama,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('${fmtRingkasRp(b.jumlahSen)} · jatuh tempo '
              '${b.jatuhTempo.day}/${b.jatuhTempo.month}/${b.jatuhTempo.year}'
              '${b.lunas ? ' · LUNAS' : ''}'),
          Text('${tr('rumah.siapaBayarApa')}: '
              '${(b.pemilikNama ?? '—')} → dibayar oleh '
              '${item.penanggungJawab}'),
          if (alasan.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Ingatkan sekarang tidak bisa: ${alasan.join(' ')}',
                key: Key('rumah_alasan_${b.id}'),
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          Row(children: [
            TextButton.icon(
              key: Key('rumah_ingat_${b.id}'),
              onPressed: b.lunas ? null : () => _ingatkan(b),
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: Text(tr('rumah.ingatkan')),
            ),
            if (!b.lunas)
              TextButton.icon(
                key: Key('rumah_lunas_${b.id}'),
                onPressed: () => _lunas(b),
                icon: const Icon(Icons.check, size: 18),
                label: Text(tr('rumah.lunas')),
              )
            else
              TextButton.icon(
                key: Key('rumah_batal_lunas_${b.id}'),
                onPressed: () async {
                  await ref.read(repoTanggungJawabProvider).batalkanLunas(b.id);
                  await _muat();
                },
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('Batalkan lunas'),
              ),
            const Spacer(),
            IconButton(
              key: Key('rumah_hapus_${b.id}'),
              icon: const Icon(Icons.delete_outline),
              tooltip: tr('umum.hapus'),
              onPressed: () async {
                await ref.read(repoTanggungJawabProvider).hapus(b.id);
                await _muat();
              },
            ),
          ]),
        ]),
      ),
    );
  }
}
