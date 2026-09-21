/// FR-96 — Layar "Zakat & sedekah".
///
/// Dua bagian: (1) **catatan** infaq/sedekah/wakaf + zakat yang sudah dibayar,
/// (2) **asisten perhitungan** zakat maal & fitrah. Perhitungan selalu
/// menampilkan asumsi yang dipakai (nisab 85 gram emas, harga emas yang diisi
/// sendiri + tanggalnya, tarif 2,5 %, haul 354 hari) dan menegaskan bahwa ini
/// alat bantu, bukan keputusan.
library;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/zakat.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/pengaturan_repository.dart';

/// Kunci pengaturan untuk acuan harga emas & awal haul.
const String kunciHargaEmas = 'zakat_harga_emas';
const String kunciTanggalHargaEmas = 'zakat_tanggal_harga_emas';
const String kunciMulaiHaul = 'zakat_mulai_haul';

int? _angka(String teks) {
  final bersih = teks.replaceAll(RegExp(r'[^0-9]'), '');
  if (bersih.isEmpty) return null;
  return int.tryParse(bersih);
}

String _rupiahDariSen(int sen) {
  final teks = (sen / 100).round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < teks.length; i++) {
    if (i > 0 && (teks.length - i) % 3 == 0) buf.write('.');
    buf.write(teks[i]);
  }
  return 'Rp ${buf.toString()}';
}

class ZakatScreen extends ConsumerStatefulWidget {
  const ZakatScreen({super.key, this.db, this.sekarang});

  final AppDatabase? db;
  final DateTime? sekarang;

  @override
  ConsumerState<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends ConsumerState<ZakatScreen> {
  AppDatabase get _db => widget.db ?? ref.read(databaseProvider);
  late final PengaturanRepository _pengaturan = PengaturanRepository(_db);

  final Map<String, TextEditingController> _harta = {
    'kas': TextEditingController(),
    'emas_gram': TextEditingController(),
    'investasi': TextEditingController(),
    'piutang': TextEditingController(),
    'utang': TextEditingController(),
  };
  final TextEditingController _hargaEmas = TextEditingController();
  final TextEditingController _jiwa = TextEditingController();
  final TextEditingController _hargaBeras = TextEditingController();

  final TextEditingController _jumlahSedekah = TextEditingController();
  final TextEditingController _penerima = TextEditingController();
  final TextEditingController _catatanSedekah = TextEditingController();

  String _jenisSedekah = 'infaq';
  DateTime? _mulaiHaul;
  DateTime? _tanggalHarga;

  bool _memuat = true;
  List<ZakatSedekahData> _catatan = const [];
  String? _pesan;

  DateTime get _sekarang => widget.sekarang ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    // Hitungan (nisab, harta bersih, fitrah) harus ikut berubah saat pengguna
    // mengetik — jadi tiap kolom angka memicu gambar ulang layar.
    for (final c in [
      ..._harta.values,
      _jiwa,
      _hargaBeras,
    ]) {
      c.addListener(_hitungUlang);
    }
    _muat();
  }

  void _hitungUlang() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _harta.values) {
      c.dispose();
    }
    _hargaEmas.dispose();
    _jiwa.dispose();
    _hargaBeras.dispose();
    _jumlahSedekah.dispose();
    _penerima.dispose();
    _catatanSedekah.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final harga = await _pengaturan.baca(kunciHargaEmas);
    final tanggal = await _pengaturan.baca(kunciTanggalHargaEmas);
    final haul = await _pengaturan.baca(kunciMulaiHaul);
    final daftar = await (_db.select(_db.zakatSedekah)
          ..orderBy([(t) => OrderingTerm.desc(t.tanggal)]))
        .get();
    if (!mounted) return;
    setState(() {
      _hargaEmas.text = harga ?? '';
      _tanggalHarga = tanggal == null ? null : DateTime.tryParse(tanggal);
      _mulaiHaul = haul == null ? null : DateTime.tryParse(haul);
      _catatan = daftar;
      _memuat = false;
    });
  }

  Future<void> _simpanHargaEmas() async {
    final angka = _angka(_hargaEmas.text);
    if (angka == null || angka <= 0) {
      setState(() => _pesan = 'Isi harga emas per gram dulu (mis. 1500000).');
      return;
    }
    await _pengaturan.simpan(kunciHargaEmas, angka.toString());
    await _pengaturan.simpan(
        kunciTanggalHargaEmas, _sekarang.toIso8601String());
    await _muat();
    if (!mounted) return;
    setState(() => _pesan = 'Harga emas acuan disimpan (${_rupiahDariSen(angka * 100)}/gram).');
  }

  Future<void> _pilihHaul() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _mulaiHaul ?? _sekarang,
      firstDate: DateTime(_sekarang.year - 30),
      lastDate: DateTime(_sekarang.year + 1),
    );
    if (hasil == null) return;
    await _pengaturan.simpan(kunciMulaiHaul, hasil.toIso8601String());
    await _muat();
  }

  int get _hargaEmasSen => (_angka(_hargaEmas.text) ?? 0) * 100;

  int get _totalHartaSen {
    var total = 0;
    for (final k in ['kas', 'investasi', 'piutang']) {
      total += (_angka(_harta[k]!.text) ?? 0) * 100;
    }
    final gram = double.tryParse(_harta['emas_gram']!.text.replaceAll(',', '.')) ?? 0;
    total += (gram * _hargaEmasSen).round();
    return total;
  }

  int get _utangSen => (_angka(_harta['utang']!.text) ?? 0) * 100;

  Future<void> _simpanSedekah() async {
    final jumlah = _angka(_jumlahSedekah.text);
    if (jumlah == null || jumlah <= 0) {
      setState(() => _pesan = 'Isi jumlahnya dulu.');
      return;
    }
    final kodeMataUang = 'IDR';
    await _db.into(_db.zakatSedekah).insert(ZakatSedekahCompanion.insert(
          jenis: _jenisSedekah,
          tanggal: _sekarang,
          jumlahSen: jumlah * 100,
          kodeMataUang: Value(kodeMataUang),
          penerima:
              Value(_penerima.text.trim().isEmpty ? null : _penerima.text.trim()),
          catatan: Value(
              _catatanSedekah.text.trim().isEmpty ? null : _catatanSedekah.text.trim()),
        ));
    _jumlahSedekah.clear();
    _penerima.clear();
    _catatanSedekah.clear();
    await _muat();
    if (!mounted) return;
    setState(() => _pesan = 'Catatan ${labelJenisZakat(_jenisSedekah)} tersimpan.');
  }

  Future<void> _hapusSedekah(ZakatSedekahData d) async {
    await (_db.delete(_db.zakatSedekah)..where((t) => t.id.equals(d.id))).go();
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) return const Center(child: CircularProgressIndicator());
    final tema = Theme.of(context);

    final hasil = hitungZakat(
      hartaSen: _totalHartaSen,
      utangSen: _utangSen,
      hargaEmasPerGramSen: _hargaEmasSen,
      mulaiHaul: _mulaiHaul,
      sekarang: _sekarang,
    );
    final jiwa = _angka(_jiwa.text) ?? 0;
    final fitrah = hitungFitrah(
      jiwa: jiwa,
      hargaBerasPerKgSen: (_angka(_hargaBeras.text) ?? 0) * 100,
    );
    final ringkas = ringkasSedekah(_catatan, _sekarang);

    return Scaffold(
      appBar: AppBar(title: const Text('Zakat & sedekah')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Catat infaq/sedekah/zakat',
                      style: tema.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final j in jenisZakatSedekah)
                        ChoiceChip(
                          key: Key('jenis_zakat_${j.nilaiDb}'),
                          label: Text(j.label),
                          selected: _jenisSedekah == j.nilaiDb,
                          onSelected: (_) =>
                              setState(() => _jenisSedekah = j.nilaiDb),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('isi_jumlah_zakat'),
                          controller: _jumlahSedekah,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Jumlah (Rp)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const Key('isi_penerima_zakat'),
                          controller: _penerima,
                          decoration: const InputDecoration(
                            labelText: 'Penerima/lembaga',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('isi_catatan_zakat'),
                    controller: _catatanSedekah,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (boleh kosong)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('simpan_zakat'),
                    onPressed: _simpanSedekah,
                    icon: const Icon(Icons.add),
                    label: const Text('Simpan catatan'),
                  ),
                  if (_pesan != null) ...[
                    const SizedBox(height: 8),
                    Text(_pesan!, key: const Key('pesan_zakat')),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Bulan ini ${_rupiahDariSen(ringkas.totalBulanIniSen)} · '
                    'tahun ini ${_rupiahDariSen(ringkas.totalTahunIniSen)} · '
                    '${ringkas.jumlahCatatan} catatan',
                    key: const Key('ringkas_sedekah'),
                    style: tema.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Asisten perhitungan zakat maal',
                      style: tema.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('isi_harga_emas'),
                          controller: _hargaEmas,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Harga emas per gram (Rp)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonal(
                          key: const Key('simpan_harga_emas'),
                          onPressed: _simpanHargaEmas,
                          child: const Text('Simpan acuan'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _tanggalHarga == null
                        ? 'Harga emas belum diisi — aplikasi tidak mengambil '
                            'harga sendiri dari internet.'
                        : 'Harga emas diisi sendiri pada ${fmtTanggalId(_tanggalHarga!)}.',
                    key: const Key('catatan_harga_emas'),
                    style: tema.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  for (final k in ['kas', 'investasi', 'piutang'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        key: Key('isi_harta_$k'),
                        controller: _harta[k],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: switch (k) {
                            'kas' => 'Kas & tabungan (Rp)',
                            'investasi' => 'Investasi (Rp)',
                            _ => 'Piutang (Rp)',
                          },
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('isi_emas_gram'),
                          controller: _harta['emas_gram'],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Emas (gram)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const Key('isi_utang_jatuh_tempo'),
                          controller: _harta['utang'],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Utang jatuh tempo (Rp)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('pilih_mulai_haul'),
                        onPressed: _pilihHaul,
                        icon: const Icon(Icons.event_outlined),
                        label: Text(_mulaiHaul == null
                            ? 'Tanggal mulai haul'
                            : 'Haul sejak ${fmtTanggalId(_mulaiHaul!)}'),
                      ),
                      Text(
                        'Nisab: ${_rupiahDariSen(hasil.nisabSen)} · '
                        'harta bersih: ${_rupiahDariSen(hasil.hartaBersihSen)}',
                        key: const Key('nisab_zakat'),
                        style: tema.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasil.wajibZakat
                        ? 'Zakat maal 2,5%: ${_rupiahDariSen(hasil.zakatSen)}'
                        : 'Belum memenuhi syarat nisab & haul — zakat maal belum '
                            'dihitung (lihat asumsi di bawah).',
                    key: const Key('hasil_zakat'),
                    style: tema.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  for (final a in hasil.asumsi)
                    Text('• $a', style: tema.textTheme.bodySmall),
                  const Divider(height: 24),
                  Text('Zakat fitrah', style: tema.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('isi_jiwa_fitrah'),
                          controller: _jiwa,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Jumlah jiwa',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const Key('isi_harga_beras'),
                          controller: _hargaBeras,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Harga beras/kg (Rp)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fitrah: ${fitrah.kgBeras.toStringAsFixed(1)} kg beras'
                    '${fitrah.uangSen == null ? '' : ' · ${_rupiahDariSen(fitrah.uangSen!)}'}',
                    key: const Key('hasil_fitrah'),
                    style: tema.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Catatan tersimpan', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_catatan.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada catatan zakat/sedekah.'),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final d in _catatan.take(20))
                    ListTile(
                      key: Key('catatan_zakat_${d.id}'),
                      dense: true,
                      title: Text(
                          '${labelJenisZakat(d.jenis)}: ${_rupiahDariSen(d.jumlahSen)}'),
                      subtitle: Text([
                        fmtTanggalId(d.tanggal),
                        if (d.penerima != null && d.penerima!.isNotEmpty)
                          d.penerima!,
                        if (d.catatan != null && d.catatan!.isNotEmpty) d.catatan!,
                      ].join(' · ')),
                      trailing: IconButton(
                        key: Key('hapus_catatan_zakat_${d.id}'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _hapusSedekah(d),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
