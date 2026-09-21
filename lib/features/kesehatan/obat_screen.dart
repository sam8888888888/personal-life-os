/// FR-106 — Manajer obat & vitamin.
///
/// Isi: daftar obat/vitamin, dosis dalam BENTUK TEKS BEBAS dari kemasan,
/// beberapa jam minum per obat, tombol "sudah diminum" per jam (mencatat waktu
/// + keadaan diminum / ditunda / dilewati), dan riwayat 7 hari.
///
/// Batas aman konten (PRD III-11): aplikasi TIDAK menyarankan dosis, TIDAK
/// menilai kepatuhan, dan TIDAK menilai pengobatan. Yang ditulis hanya keadaan
/// catatan, mis. "3 dari 5 tercatat diminum hari ini".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/laporan/obat_habis.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/repository/kesehatan_repository.dart'
    show formatJamHHmm;
import '../../data/repository/obat_repository.dart';
import 'kartu_bagian.dart';
import 'label_hari.dart';
import 'provider_kesehatan.dart';

/// Satuan yang biasa tertulis di kemasan (boleh ditulis sendiri).
const List<String> satuanObatUmum = ['tablet', 'kapsul', 'ml', 'tetes', 'sachet'];

class ObatScreen extends ConsumerStatefulWidget {
  const ObatScreen({super.key, this.jamSekarang});

  /// Sumber waktu (dipakai uji supaya tanggal tidak bergeser).
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<ObatScreen> createState() => _ObatScreenState();
}

class _ObatScreenState extends ConsumerState<ObatScreen> {
  final _nama = TextEditingController();
  final _dosisTeks = TextEditingController();
  final _jumlahPerMinum = TextEditingController(text: '1');
  final _satuan = TextEditingController(text: 'tablet');
  final _jamBaru = TextEditingController();
  final _catatan = TextEditingController();
  final List<String> _daftarJam = [];

  bool _memuat = true;
  RingkasanObatHariIni? _ringkasan;
  List<ObatData> _semuaObat = const [];
  Map<int, List<JadwalObatData>> _jadwal = const {};
  List<BarisRiwayatMinum> _riwayat = const [];

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _nama.dispose();
    _dosisTeks.dispose();
    _jumlahPerMinum.dispose();
    _satuan.dispose();
    _jamBaru.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    final repo = ref.read(obatRepoProvider);
    final kini = _sekarang;
    final ringkasan = await repo.ringkasanHariIni(hari: kini);
    final daftar = await repo.daftarObat();
    final jadwal = <int, List<JadwalObatData>>{};
    for (final o in daftar) {
      jadwal[o.id] = await repo.jadwalObat(o.id, aktifSaja: false);
    }
    final riwayat = await repo.riwayatMinum(hari: 7, sampai: kini);
    if (!mounted) return;
    setState(() {
      _ringkasan = ringkasan;
      _semuaObat = daftar;
      _jadwal = jadwal;
      _riwayat = riwayat;
      _memuat = false;
    });
  }

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  void _tambahJam() {
    final jam = ObatRepository.normalisasiJam(_jamBaru.text);
    if (jam == null) {
      _pesan('Jam minum ditulis HH:mm, contoh 08:00.');
      return;
    }
    if (_daftarJam.contains(jam)) {
      _pesan('Jam $jam sudah ada di daftar.');
      return;
    }
    setState(() {
      _daftarJam.add(jam);
      _jamBaru.clear();
    });
  }

  Future<void> _simpanObat() async {
    final nama = _nama.text.trim();
    if (nama.isEmpty) {
      _pesan('Isi nama obat atau vitamin lebih dulu.');
      return;
    }
    final jumlah = int.tryParse(_jumlahPerMinum.text.trim());
    if (jumlah == null) {
      _pesan('Jumlah per minum diisi angka, contoh 1.');
      return;
    }
    try {
      await ref.read(obatRepoProvider).tambahObat(
            nama: nama,
            dosisTeks: _dosisTeks.text,
            jumlahPerMinum: jumlah,
            satuan: _satuan.text,
            catatan: _catatan.text,
            jamMinum: _daftarJam,
          );
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.kesehatan,
        aksi: AksiAudit.buat,
        entitas: 'obat',
        ringkas: 'Obat "$nama" disimpan '
            '(${_daftarJam.isEmpty ? 'tanpa jam minum' : '${_daftarJam.length} jam minum'}).',
      );
    } on ArgumentError catch (e) {
      _pesan('Catatan belum bisa disimpan: ${e.message}');
      return;
    }
    _nama.clear();
    _dosisTeks.clear();
    _jumlahPerMinum.text = '1';
    _catatan.clear();
    setState(_daftarJam.clear);
    await _muat();
    _pesan('Obat tersimpan.');
  }

  Future<void> _catat(JadwalMinumHariIni j, StatusMinum status) async {
    await ref.read(obatRepoProvider).catatMinum(
          obatId: j.obatId,
          jadwalId: j.jadwal?.id,
          waktuRencana: j.waktuRencana,
          status: status,
        );
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.kesehatan,
      aksi: AksiAudit.tandai,
      entitas: 'minum_obat',
      entitasId: '${j.obatId}',
      ringkas: '${j.obat.nama} ${j.jam}: '
          '${status.label.toLowerCase()} dicatat.',
    );
    await _muat();
    _pesan('${j.obat.nama} ${j.jam}: tercatat ${status.label.toLowerCase()}.');
  }

  Future<void> _hapusObat(ObatData o) async {
    await ref.read(obatRepoProvider).hapusObat(o.id);
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.kesehatan,
      aksi: AksiAudit.hapus,
      entitas: 'obat',
      entitasId: '${o.id}',
      ringkas: 'Obat "${o.nama}" dihapus.',
    );
    await _muat();
    _pesan('Catatan obat dihapus.');
  }

  Future<void> _gantiAktif(ObatData o, bool aktif) async {
    await ref.read(obatRepoProvider).ubahObat(o.id, aktif: aktif);
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.kesehatan,
      aksi: AksiAudit.ubah,
      entitas: 'obat',
      entitasId: '${o.id}',
      ringkas: 'Obat "${o.nama}" ${aktif ? 'diaktifkan' : 'dinonaktifkan'}.',
    );
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ringkasan = _ringkasan;

    return Scaffold(
      appBar: AppBar(title: const Text('Obat & vitamin')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                KartuBagian(
                  judul: 'Hari ini',
                  ikon: Icons.today_outlined,
                  anak: [
                    if (ringkasan == null || !ringkasan.adaJadwal)
                      const TeksBelumAdaData()
                    else ...[
                      Text(
                        ringkasan.kalimatTercatat,
                        key: const Key('kalimat_tercatat_hari_ini'),
                        style: tema.textTheme.bodyLarge,
                      ),
                      if (ringkasan.jumlahDitunda > 0 ||
                          ringkasan.jumlahDilewati > 0)
                        Text(
                          'Ditunda ${ringkasan.jumlahDitunda} · dilewati '
                          '${ringkasan.jumlahDilewati}',
                          key: const Key('angka_ditunda_dilewati'),
                          style: tema.textTheme.bodySmall,
                        ),
                      const SizedBox(height: 8),
                      for (final j in ringkasan.jadwal) _barisJadwal(j),
                    ],
                  ],
                ),
                KartuBagian(
                  judul: 'Tambah obat / vitamin',
                  ikon: Icons.add_circle_outline,
                  anak: [
                    TextField(
                      key: const Key('input_nama_obat'),
                      controller: _nama,
                      decoration: const InputDecoration(
                        labelText: 'Nama obat atau vitamin',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('input_dosis_teks'),
                      controller: _dosisTeks,
                      decoration: const InputDecoration(
                        labelText: 'Dosis sesuai kemasan (teks bebas)',
                        hintText: 'Contoh: 1 tablet, sesuai tulisan di kemasan',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('input_jumlah_per_minum'),
                            controller: _jumlahPerMinum,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Jumlah per minum',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: const Key('input_satuan_obat'),
                            controller: _satuan,
                            decoration: const InputDecoration(
                              labelText: 'Satuan',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final s in satuanObatUmum)
                          PilihanCepat(
                            kunci: Key('pilih_satuan_$s'),
                            label: s,
                            terpilih: _satuan.text.trim() == s,
                            onPilih: () => setState(() => _satuan.text = s),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('input_jam_minum'),
                            controller: _jamBaru,
                            decoration: const InputDecoration(
                              labelText: 'Jam minum (HH:mm)',
                              hintText: 'Contoh: 08:00',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          key: const Key('tambah_jam_minum'),
                          onPressed: _tambahJam,
                          child: const Text('Tambah jam'),
                        ),
                      ],
                    ),
                    if (_daftarJam.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final jam in _daftarJam)
                            InputChip(
                              key: Key('jam_dipilih_$jam'),
                              label: Text(jam),
                              onDeleted: () =>
                                  setState(() => _daftarJam.remove(jam)),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('input_catatan_obat'),
                      controller: _catatan,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (boleh kosong)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const Key('simpan_obat'),
                      onPressed: _simpanObat,
                      child: const Text('Simpan obat'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dosis disimpan apa adanya dari kemasan. Aplikasi tidak '
                      'menghitung dan tidak menyarankan dosis.',
                      key: const Key('catatan_dosis'),
                      style: tema.textTheme.bodySmall,
                    ),
                  ],
                ),
                KartuBagian(
                  judul: 'Daftar obat',
                  ikon: Icons.medication_outlined,
                  anak: [
                    if (_semuaObat.isEmpty)
                      const TeksBelumAdaData()
                    else
                      ..._semuaObat.map((o) => _barisObat(o)),
                  ],
                ),
                KartuBagian(
                  judul: 'Riwayat 7 hari',
                  ikon: Icons.history_outlined,
                  anak: [
                    if (_riwayat.isEmpty)
                      const TeksBelumAdaData()
                    else
                      ..._riwayat.map(
                        (b) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            b.namaObat,
                            key: Key('riwayat_obat_${b.catatan.id}'),
                          ),
                          subtitle: Text(
                            '${labelTanggalSedang(b.catatan.waktuRencana)} · '
                            'jam ${formatJamHHmm(b.catatan.waktuRencana)} · '
                            'tercatat ${b.status.label.toLowerCase()}'
                            '${b.catatan.waktuMinum == null ? '' : ' pukul ${formatJamHHmm(b.catatan.waktuMinum!)}'}',
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _barisJadwal(JadwalMinumHariIni j) {
    final tema = Theme.of(context);
    final sudah = j.status;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${j.obat.nama} · ${j.jam}',
            key: Key('jadwal_${j.obatId}_${j.jam}'),
            style: tema.textTheme.bodyLarge,
          ),
          Text(
            sudah == null
                ? 'Belum dicatat'
                : '${sudah.label}'
                    '${j.waktuMinum == null ? '' : ' pukul ${formatJamHHmm(j.waktuMinum!)}'}',
            key: Key('status_${j.obatId}_${j.jam}'),
            style: tema.textTheme.bodySmall,
          ),
          Wrap(
            spacing: 6,
            children: [
              FilledButton.tonal(
                key: Key('minum_${j.obatId}_${j.jam}'),
                onPressed: () => _catat(j, StatusMinum.diminum),
                child: const Text('Sudah diminum'),
              ),
              OutlinedButton(
                key: Key('tunda_${j.obatId}_${j.jam}'),
                onPressed: () => _catat(j, StatusMinum.ditunda),
                child: const Text('Ditunda'),
              ),
              OutlinedButton(
                key: Key('lewati_${j.obatId}_${j.jam}'),
                onPressed: () => _catat(j, StatusMinum.dilewati),
                child: const Text('Dilewati'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// FR-107: isi/ubah sisa obat. Sisa disimpan apa adanya + waktu diperbarui.
  Future<void> _dialogSisa(ObatData o, int dosisHari) async {
    final kendali = TextEditingController(text: o.sisa?.toString() ?? '');
    final hasil = await showDialog<String>(
      context: context,
      builder: (konteks) => AlertDialog(
        title: Text('Sisa ${o.nama}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Satuan: ${o.satuan} · dosis per hari: '
                '${dosisHari == 0 ? 'belum ada jadwal' : '$dosisHari ${o.satuan}'}'),
            const SizedBox(height: 8),
            TextField(
              key: const Key('input_sisa_obat'),
              controller: kendali,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Sisa sekarang',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(konteks).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('simpan_sisa_obat'),
            onPressed: () => Navigator.of(konteks).pop(kendali.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (hasil == null) return;
    final angka = hasil.trim().isEmpty ? null : int.tryParse(hasil.trim());
    if (angka == null && hasil.trim().isNotEmpty) {
      _pesan('Sisa obat harus berupa angka.');
      return;
    }
    await ref.read(obatRepoProvider).ubahSisa(o.id, angka);
    await _muat();
  }

  Widget _barisObat(ObatData o) {
    final jadwal = _jadwal[o.id] ?? const <JadwalObatData>[];
    final dosis = o.dosisTeks?.trim();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(o.nama, key: Key('nama_obat_${o.id}')),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${dosis == null || dosis.isEmpty ? 'Dosis belum diisi' : dosis}'
            ' · ${o.jumlahPerMinum} ${o.satuan} per minum',
            key: Key('dosis_obat_${o.id}'),
          ),
          Text(
            jadwal.isEmpty
                ? 'Belum ada jam minum'
                : 'Jam minum: ${jadwal.map((j) => j.jam).join(', ')}'
                    '${jadwal.every((j) => j.aktif) ? '' : ' (sebagian tidak aktif)'}',
            key: Key('jadwal_obat_${o.id}'),
          ),
          // FR-107: perkiraan habis dihitung dari sisa ÷ dosis per hari.
          Builder(builder: (_) {
            final dosisHari = dosisPerHari(
              o.jumlahPerMinum,
              jadwal.where((j) => j.aktif).length,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kalimatSisa(
                    namaObat: o.nama,
                    sisa: o.sisa,
                    dosisPerHari: dosisHari,
                    satuan: o.satuan,
                    sekarang: widget.jamSekarang?.call() ?? DateTime.now(),
                  ),
                  key: Key('sisa_obat_${o.id}'),
                ),
                TextButton.icon(
                  key: Key('isi_sisa_${o.id}'),
                  onPressed: () => _dialogSisa(o, dosisHari),
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: Text(o.sisa == null
                      ? 'Isi sisa obat'
                      : 'Ubah sisa (${o.sisa} ${o.satuan})'),
                ),
              ],
            );
          }),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            key: Key('saklar_obat_${o.id}'),
            value: o.aktif,
            onChanged: (v) => _gantiAktif(o, v),
          ),
          IconButton(
            key: Key('hapus_obat_${o.id}'),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Hapus obat',
            onPressed: () => _hapusObat(o),
          ),
        ],
      ),
    );
  }
}
