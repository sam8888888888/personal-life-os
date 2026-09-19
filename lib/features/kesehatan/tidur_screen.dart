/// FR-103 — Pencatat tidur.
///
/// Isi: jam tidur, jam bangun (boleh lintas tengah malam), durasi yang dihitung
/// otomatis DAN boleh dikoreksi pengguna, kualitas 1–5 (boleh dikosongkan),
/// tidur siang, catatan. Satu catatan per malam (tanggal = hari bangun):
/// menyimpan lagi untuk tanggal yang sama memperbarui catatan malam itu.
///
/// Kualitas tidur adalah persepsi pengguna, bukan penilaian aplikasi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/repository/kesehatan_repository.dart';
import 'kartu_bagian.dart';
import 'label_hari.dart';
import 'provider_kesehatan.dart';

class TidurScreen extends ConsumerStatefulWidget {
  const TidurScreen({super.key, this.jamSekarang});

  /// Sumber waktu (dipakai uji supaya tanggal tidak bergeser).
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<TidurScreen> createState() => _TidurScreenState();
}

class _TidurScreenState extends ConsumerState<TidurScreen> {
  final _jamTidur = TextEditingController(text: '22:00');
  final _jamBangun = TextEditingController(text: '06:00');
  final _durasiKoreksi = TextEditingController();
  final _tidurSiang = TextEditingController();
  final _catatan = TextEditingController();

  int? _kualitas;
  late DateTime _tanggal;
  bool _adaCatatanMalam = false;

  bool _memuat = true;
  List<TidurData> _riwayat = const [];
  RingkasanTidur? _ringkasan;

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _tanggal = awalHari(_sekarang);
    _jamTidur.addListener(_perbaruiHitung);
    _jamBangun.addListener(_perbaruiHitung);
    _durasiKoreksi.addListener(_perbaruiHitung);
    _mulai();
  }

  @override
  void dispose() {
    _jamTidur.dispose();
    _jamBangun.dispose();
    _durasiKoreksi.dispose();
    _tidurSiang.dispose();
    _catatan.dispose();
    super.dispose();
  }

  void _perbaruiHitung() {
    if (mounted) setState(() {});
  }

  Future<void> _mulai() async {
    await _muat();
    await _muatCatatanMalam();
  }

  Future<void> _muat() async {
    final repo = ref.read(kesehatanRepoProvider);
    final kini = _sekarang;
    final riwayat = await repo.riwayatTidur(hari: 7, sampai: kini);
    final ringkasan = await repo.ringkasanTidur(acuan: kini);
    if (!mounted) return;
    setState(() {
      _riwayat = riwayat;
      _ringkasan = ringkasan;
      _memuat = false;
    });
  }

  /// Isi form dari catatan malam yang sudah ada (tanggal = hari bangun).
  Future<void> _muatCatatanMalam() async {
    final ada = await ref.read(kesehatanRepoProvider).tidurMalam(_tanggal);
    if (!mounted) return;
    setState(() {
      _adaCatatanMalam = ada != null;
      if (ada != null) {
        _jamTidur.text = formatJamHHmm(ada.jamTidur);
        _jamBangun.text = formatJamHHmm(ada.jamBangun);
        // Tampilkan koreksi durasi yang tersimpan, bila berbeda dari hitungan.
        final hitung =
            KesehatanRepository.hitungDurasiMenit(ada.jamTidur, ada.jamBangun);
        _durasiKoreksi.text =
            hitung == ada.durasiMenit ? '' : '${ada.durasiMenit}';
        _tidurSiang.text =
            ada.tidurSiangMenit == 0 ? '' : '${ada.tidurSiangMenit}';
        _kualitas = ada.kualitas;
        _catatan.text = ada.catatan ?? '';
      }
    });
  }

  /// Durasi hasil hitung dari jam tidur & jam bangun (lintas tengah malam).
  int? get _durasiHitung {
    final t = parseJamHHmm(_jamTidur.text);
    final b = parseJamHHmm(_jamBangun.text);
    if (t == null || b == null) return null;
    return KesehatanRepository.hitungDurasiMenit(
      DateTime(2000, 1, 1, t.jam, t.menit),
      DateTime(2000, 1, 1, b.jam, b.menit),
    );
  }

  int? get _durasiKoreksiAngka {
    final teks = _durasiKoreksi.text.trim();
    if (teks.isEmpty) return null;
    return int.tryParse(teks);
  }

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  Future<void> _simpan() async {
    final t = parseJamHHmm(_jamTidur.text);
    final b = parseJamHHmm(_jamBangun.text);
    if (t == null || b == null) {
      _pesan('Jam tidur dan jam bangun diisi bentuk HH:mm, contoh 22:30.');
      return;
    }
    final siang = _tidurSiang.text.trim().isEmpty
        ? 0
        : int.tryParse(_tidurSiang.text.trim());
    if (siang == null) {
      _pesan('Tidur siang diisi angka menit, contoh 20. Boleh dikosongkan.');
      return;
    }
    try {
      await ref.read(kesehatanRepoProvider).simpanTidur(
            tanggal: _tanggal,
            jamTidur: DateTime(
                _tanggal.year, _tanggal.month, _tanggal.day, t.jam, t.menit),
            jamBangun: DateTime(
                _tanggal.year, _tanggal.month, _tanggal.day, b.jam, b.menit),
            durasiMenit: _durasiKoreksiAngka,
            kualitas: _kualitas,
            tidurSiangMenit: siang,
            catatan: _catatan.text,
          );
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.kesehatan,
        aksi: AksiAudit.buat,
        entitas: 'tidur',
        ringkas: 'Catatan tidur disimpan.',
      );
    } on ArgumentError catch (e) {
      _pesan('Catatan belum bisa disimpan: ${e.message}');
      return;
    }
    await _muat();
    await _muatCatatanMalam();
    _pesan('Catatan tidur tersimpan.');
  }

  Future<void> _hapus(TidurData t) async {
    await ref.read(kesehatanRepoProvider).hapusTidur(t.id);
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.kesehatan,
      aksi: AksiAudit.hapus,
      entitas: 'tidur',
      entitasId: '${t.id}',
      ringkas: 'Catatan tidur dihapus.',
    );
    await _mulai();
    _pesan('Catatan dihapus.');
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final hitung = _durasiHitung;
    final koreksi = _durasiKoreksiAngka;
    final ringkasan = _ringkasan;

    return Scaffold(
      appBar: AppBar(title: const Text('Tidur')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                KartuBagian(
                  judul: 'Catat tidur',
                  ikon: Icons.bedtime_outlined,
                  anak: [
                    Text(
                      'Satu catatan per malam. Tanggal = hari bangun.',
                      style: tema.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tanggal bangun: ${labelTanggalSedang(_tanggal)}',
                            key: const Key('label_tanggal_tidur'),
                          ),
                        ),
                        TextButton(
                          key: const Key('pilih_tanggal_tidur'),
                          onPressed: () async {
                            final pilih = await showDatePicker(
                              context: context,
                              initialDate: _tanggal,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (pilih == null) return;
                            setState(() => _tanggal = awalHari(pilih));
                            await _muatCatatanMalam();
                          },
                          child: const Text('Pilih tanggal'),
                        ),
                      ],
                    ),
                    if (_adaCatatanMalam)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Sudah ada catatan untuk tanggal ini. Menyimpan akan '
                          'memperbarui catatan malam itu.',
                          key: const Key('info_sudah_ada'),
                          style: tema.textTheme.bodySmall,
                        ),
                      ),
                    TextField(
                      key: const Key('input_jam_tidur'),
                      controller: _jamTidur,
                      decoration: const InputDecoration(
                        labelText: 'Jam tidur (HH:mm)',
                        hintText: 'Contoh: 22:30',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('input_jam_bangun'),
                      controller: _jamBangun,
                      decoration: const InputDecoration(
                        labelText: 'Jam bangun (HH:mm, hari bangun)',
                        hintText: 'Contoh: 06:15',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hitung == null
                          ? 'Isi jam tidur dan jam bangun dalam bentuk HH:mm.'
                          : (hitung == 0
                              ? 'Jam tidur dan jam bangun sama — durasi tidak '
                                  'bisa dihitung dari jam saja.'
                              : 'Durasi terhitung: ${formatDurasiMenit(hitung)}'),
                      key: const Key('durasi_terhitung'),
                      style: tema.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('input_durasi_koreksi'),
                      controller: _durasiKoreksi,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Koreksi durasi (menit, boleh kosong)',
                        hintText: 'Kosongkan bila memakai hasil hitung',
                      ),
                    ),
                    if (koreksi != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Dipakai: $koreksi menit '
                          '(${formatDurasiMenit(koreksi)})',
                          key: const Key('info_koreksi_durasi'),
                          style: tema.textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text('Kualitas tidur (1–5, boleh dikosongkan)',
                        style: tema.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (var n = 1; n <= 5; n++)
                          PilihanCepat(
                            kunci: Key('pilih_kualitas_$n'),
                            label: '$n',
                            terpilih: _kualitas == n,
                            onPilih: () => setState(
                                () => _kualitas = _kualitas == n ? null : n),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('input_tidur_siang'),
                      controller: _tidurSiang,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Tidur siang (menit, boleh kosong)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('input_catatan_tidur'),
                      controller: _catatan,
                      decoration:
                          const InputDecoration(labelText: 'Catatan (boleh kosong)'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const Key('simpan_tidur'),
                      onPressed: _simpan,
                      child: const Text('Simpan catatan tidur'),
                    ),
                  ],
                ),
                KartuBagian(
                  judul: 'Rata-rata durasi',
                  ikon: Icons.insights_outlined,
                  anak: [
                    if (ringkasan == null || !ringkasan.adaCatatan)
                      const TeksBelumAdaData()
                    else ...[
                      Text(
                        ringkasan.rataRata7HariMenit == null
                            ? '7 hari terakhir: Belum ada data'
                            : '7 hari terakhir: ${formatDurasiMenit(ringkasan.rataRata7HariMenit!)}'
                                ' dari ${ringkasan.jumlahMalam7Hari} malam tercatat',
                        key: const Key('rata_tidur_7_hari'),
                      ),
                      Text(
                        ringkasan.rataRata30HariMenit == null
                            ? '30 hari terakhir: Belum ada data'
                            : '30 hari terakhir: ${formatDurasiMenit(ringkasan.rataRata30HariMenit!)}'
                                ' dari ${ringkasan.jumlahMalam30Hari} malam tercatat',
                        key: const Key('rata_tidur_30_hari'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rata-rata hanya memakai malam yang sudah dicatat.',
                        style: tema.textTheme.bodySmall,
                      ),
                    ],
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
                        (t) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Tidur ${formatJamHHmm(t.jamTidur)} – bangun '
                            '${formatJamHHmm(t.jamBangun)}',
                            key: Key('tidur_jam_${t.id}'),
                          ),
                          subtitle: Text(
                            '${formatDurasiMenit(t.durasiMenit)}'
                            '${t.kualitas == null ? '' : ' · kualitas ${t.kualitas}'}'
                            '${t.tidurSiangMenit > 0 ? ' · tidur siang ${t.tidurSiangMenit} menit' : ''}'
                            ' · ${labelTanggalSedang(t.tanggal)}',
                          ),
                          trailing: IconButton(
                            key: Key('hapus_tidur_${t.id}'),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Hapus catatan',
                            onPressed: () => _hapus(t),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
