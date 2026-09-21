/// FR-121 — Pengulangan berkala (spaced repetition).
///
/// Isi: kartu tanya-jawab dengan jadwal ulangan yang dihitung dari jawaban
/// pengguna (lihat `lib/core/laporan/ulangan_berkala.dart`). Menjawab "belum
/// tepat" hanya mengembalikan kartu ke jarak terpendek — bukan penilaian.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/laporan/ulangan_berkala.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import 'komponen_pengetahuan.dart';
import 'provider_pengetahuan.dart';

class UlanganScreen extends ConsumerStatefulWidget {
  const UlanganScreen({super.key, this.jamSekarang});

  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<UlanganScreen> createState() => _UlanganScreenState();
}

class _UlanganScreenState extends ConsumerState<UlanganScreen> {
  bool _memuat = true;
  List<KartuUlanganRingkas> _kartu = const <KartuUlanganRingkas>[];

  /// Sesi ulangan: daftar kartu yang sedang diulang + posisi & jawaban.
  List<KartuUlanganRingkas> _sesi = const <KartuUlanganRingkas>[];
  int _posisi = 0;
  bool _bukaJawaban = false;
  int _tepat = 0;
  int _belumTepat = 0;

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final daftar = await ref.read(pengetahuanRepoProvider).daftarKartu();
      if (!mounted) return;
      setState(() {
        _kartu = daftar;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _memuat = false);
    }
  }

  Future<void> _tambahKartu() async {
    final pertanyaan = TextEditingController();
    final jawaban = TextEditingController();
    final topik = TextEditingController();
    final setuju = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kartu ulangan baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bidangTeks(pengendali: pertanyaan, label: 'Pertanyaan', baris: 2),
              bidangTeks(pengendali: jawaban, label: 'Jawaban', baris: 3),
              bidangTeks(pengendali: topik, label: 'Topik (boleh dikosongkan)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('simpan_kartu'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (setuju != true ||
        pertanyaan.text.trim().isEmpty ||
        jawaban.text.trim().isEmpty) {
      return;
    }
    await ref.read(pengetahuanRepoProvider).simpanKartu(
          pertanyaan: pertanyaan.text.trim(),
          jawaban: jawaban.text.trim(),
          topik: topik.text.trim().isEmpty ? null : topik.text.trim(),
          sekarang: _sekarang,
        );
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.pengetahuan,
      aksi: AksiAudit.buat,
      entitas: 'kartu_ulangan',
      ringkas: 'Kartu ulangan dibuat (jadwal pertama besok)',
    );
    await _muat();
  }

  void _mulaiSesi() {
    final siap = kartuJatuhTempo(_kartu, acuan: _sekarang);
    if (siap.isEmpty) return;
    setState(() {
      _sesi = siap;
      _posisi = 0;
      _bukaJawaban = false;
      _tepat = 0;
      _belumTepat = 0;
    });
  }

  Future<void> _jawab({required bool tepat}) async {
    final kartu = _sesi[_posisi];
    await ref.read(pengetahuanRepoProvider).jawabKartu(
          kartu.id,
          benar: tepat,
          sekarang: _sekarang,
        );
    if (!mounted) return;
    setState(() {
      if (tepat) {
        _tepat++;
      } else {
        _belumTepat++;
      }
      if (_posisi + 1 < _sesi.length) {
        _posisi++;
        _bukaJawaban = false;
      } else {
        _sesi = const <KartuUlanganRingkas>[];
      }
    });
    if (_sesi.isEmpty) {
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.pengetahuan,
        aksi: AksiAudit.tandai,
        entitas: 'kartu_ulangan',
        ringkas: 'Sesi ulangan selesai: $_tepat tepat, $_belumTepat belum tepat',
      );
      await _muat();
    }
  }

  Future<void> _hapus(KartuUlanganRingkas k) async {
    if (!await konfirmasiHapus(context, 'Kartu "${k.pertanyaan}"')) return;
    await ref.read(pengetahuanRepoProvider).hapusKartu(k.id);
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final ringkas = ringkasUlangan(_kartu, acuan: _sekarang);
    final selesaiSesi = _sesi.isEmpty && (_tepat > 0 || _belumTepat > 0);

    if (_sesi.isNotEmpty) {
      final kartu = _sesi[_posisi];
      return Scaffold(
        appBar: AppBar(
          title: Text('Ulangan ${_posisi + 1}/${_sesi.length}'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _sesi = const <KartuUlanganRingkas>[]),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            kartuRingkas('Pertanyaan', [
              Text(kartu.pertanyaan, style: const TextStyle(fontSize: 16)),
              if ((kartu.topik ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(children: [lencana(kartu.topik!)]),
              ],
            ]),
            const SizedBox(height: 8),
            if (!_bukaJawaban)
              FilledButton(
                key: const Key('buka_jawaban'),
                onPressed: () => setState(() => _bukaJawaban = true),
                child: const Text('Tampilkan jawaban'),
              )
            else ...[
              kartuRingkas('Jawaban', [Text(kartu.jawaban)]),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: const Key('jawab_belum_tepat'),
                      onPressed: () => _jawab(tepat: false),
                      child: const Text('Belum tepat'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: const Key('jawab_tepat'),
                      onPressed: () => _jawab(tepat: true),
                      child: const Text('Tepat'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Kartu ulangan')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tambah_kartu'),
        onPressed: _tambahKartu,
        icon: const Icon(Icons.add),
        label: const Text('Kartu baru'),
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (selesaiSesi)
                  kartuRingkas('Sesi terakhir', [
                    barisKunciNilai('Tepat', '$_tepat'),
                    barisKunciNilai('Belum tepat', '$_belumTepat'),
                    const Text(
                        'Kartu yang "belum tepat" kembali ke jarak terpendek '
                        'dan akan muncul lagi besok.'),
                  ]),
                kartuRingkas('Ringkasan kartu', [
                  barisKunciNilai('Jumlah kartu', '${ringkas.total}'),
                  barisKunciNilai('Siap diulang hari ini', '${ringkas.jatuhTempo}'),
                  barisKunciNilai('Masih baru', '${ringkas.baru}'),
                  barisKunciNilai('Jarak panjang (≥ 35 hari)', '${ringkas.kuat}'),
                  barisKunciNilai(
                    'Bagian jawaban tepat',
                    ringkas.bagianTepat == null
                        ? 'Belum ada data'
                        : '${(ringkas.bagianTepat! * 100).round()} %',
                  ),
                ]),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const Key('mulai_ulangan'),
                  onPressed: ringkas.jatuhTempo == 0 ? null : _mulaiSesi,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(ringkas.jatuhTempo == 0
                      ? 'Belum ada kartu yang siap diulang'
                      : 'Mulai ulangan (${ringkas.jatuhTempo} kartu)'),
                ),
                const SizedBox(height: 8),
                if (_kartu.isEmpty)
                  kartuKosong('Belum ada kartu',
                      petunjuk: 'Kartu berisi pertanyaan & jawaban. Setelah '
                          'dibuat, jadwal ulangan pertama adalah besok.'),
                for (final k in _kartu)
                  Card(
                    key: Key('kartu_${k.id}'),
                    child: ListTile(
                      isThreeLine: true,
                      title: Text(k.pertanyaan,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${labelKotak(k.kotak)} · '
                              'berikutnya ${fmtTanggalPendekAman(k.ulanganBerikut)}'),
                          Text('Diulang ${k.jumlahDiulang}× · '
                              'tepat ${k.jumlahBenar}×'),
                          if ((k.topik ?? '').isNotEmpty)
                            Wrap(children: [lencana(k.topik!)]),
                        ],
                      ),
                      trailing: IconButton(
                        key: Key('hapus_kartu_${k.id}'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _hapus(k),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
