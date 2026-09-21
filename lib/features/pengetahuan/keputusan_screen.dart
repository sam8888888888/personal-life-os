/// FR-119 — Jurnal keputusan (Decision OS).
///
/// Isi: catat keputusan (apa diputuskan, pilihan yang dipertimbangkan, alasan,
/// harapan, keyakinan), lalu tinjau hasilnya pada tanggal yang Anda tentukan
/// sendiri. Aplikasi hanya menyimpan & mengingatkan — tidak menilai keputusan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/laporan/pengetahuan_ringkas.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import 'komponen_pengetahuan.dart';
import 'provider_pengetahuan.dart';

class KeputusanScreen extends ConsumerStatefulWidget {
  const KeputusanScreen({super.key, this.jamSekarang});

  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<KeputusanScreen> createState() => _KeputusanScreenState();
}

class _KeputusanScreenState extends ConsumerState<KeputusanScreen> {
  bool _memuat = true;
  List<BarisKeputusan> _keputusan = const <BarisKeputusan>[];

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final daftar = await ref.read(pengetahuanRepoProvider).daftarKeputusan();
      if (!mounted) return;
      setState(() {
        _keputusan = daftar;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _memuat = false);
    }
  }

  Future<void> _form({BarisKeputusan? ada}) async {
    final judul = TextEditingController(text: ada?.judul ?? '');
    final konteks = TextEditingController(text: ada?.konteks ?? '');
    final pilihan = TextEditingController(text: ada?.pilihan ?? '');
    final dipilih = TextEditingController(text: ada?.dipilih ?? '');
    final alasan = TextEditingController(text: ada?.alasan ?? '');
    final harapan = TextEditingController(text: ada?.harapan ?? '');
    final risiko = TextEditingController(text: ada?.risiko ?? '');
    final biaya = TextEditingController(text: ada?.biaya ?? '');
    var keyakinan = (ada?.keyakinan ?? 50).toDouble();
    int? tinjauHari = ada?.tinjauPada == null
        ? null
        : ada!.tinjauPada!.difference(DateTime(
              _sekarang.year,
              _sekarang.month,
              _sekarang.day,
            )).inDays;

    final setuju = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setel) => AlertDialog(
          title: Text(ada == null ? 'Keputusan baru' : 'Ubah keputusan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bidangTeks(pengendali: judul, label: 'Keputusan'),
                bidangTeks(
                  pengendali: konteks,
                  label: 'Konteks (boleh dikosongkan)',
                  baris: 2,
                ),
                bidangTeks(
                  pengendali: pilihan,
                  label: 'Pilihan yang dipertimbangkan',
                  baris: 3,
                  petunjuk: 'Satu pilihan per baris',
                ),
                bidangTeks(pengendali: dipilih, label: 'Yang dipilih'),
                bidangTeks(pengendali: alasan, label: 'Alasan', baris: 2),
                bidangTeks(pengendali: harapan, label: 'Harapan / hasil yang diinginkan', baris: 2),
                bidangTeks(pengendali: risiko, label: 'Risiko yang disadari', baris: 2),
                bidangTeks(pengendali: biaya, label: 'Biaya / ongkos', baris: 1),
                Text('Keyakinan saat memutuskan: ${keyakinan.round()} %'),
                Slider(
                  key: const Key('keyakinan_keputusan'),
                  value: keyakinan,
                  max: 100,
                  divisions: 20,
                  label: '${keyakinan.round()} %',
                  onChanged: (v) => setel(() => keyakinan = v),
                ),
                pemilihChip(
                  label: 'Tinjau hasil setelah',
                  pilihan: const <String>['90', '180', '365', 'tanpa'],
                  terpilih: tinjauHari == null ? 'tanpa' : '$tinjauHari',
                  onPilih: (p) => setel(() => tinjauHari = p == 'tanpa' ? null : int.parse(p)),
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
              key: const Key('simpan_keputusan'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (setuju != true || judul.text.trim().isEmpty) return;

    final awalHari = DateTime(_sekarang.year, _sekarang.month, _sekarang.day);
    await ref.read(pengetahuanRepoProvider).simpanKeputusan(
          id: ada?.id,
          judul: judul.text.trim(),
          konteks: konteks.text.trim().isEmpty ? null : konteks.text.trim(),
          pilihan: pilihan.text.trim().isEmpty ? null : pilihan.text.trim(),
          dipilih: dipilih.text.trim().isEmpty ? null : dipilih.text.trim(),
          alasan: alasan.text.trim().isEmpty ? null : alasan.text.trim(),
          harapan: harapan.text.trim().isEmpty ? null : harapan.text.trim(),
          risiko: risiko.text.trim().isEmpty ? null : risiko.text.trim(),
          biaya: biaya.text.trim().isEmpty ? null : biaya.text.trim(),
          keyakinan: keyakinan.round(),
          diputuskanPada: ada?.diputuskanPada ?? _sekarang,
          tinjauPada: tinjauHari == null
              ? null
              : awalHari.add(Duration(days: tinjauHari!)),
          sekarang: _sekarang,
        );
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.pengetahuan,
      aksi: ada == null ? AksiAudit.buat : AksiAudit.ubah,
      entitas: 'keputusan',
      ringkas: '${ada == null ? 'Keputusan dicatat' : 'Keputusan diubah'}: '
          '${judul.text.trim()}',
    );
    await _muat();
  }

  Future<void> _tulisHasil(BarisKeputusan k) async {
    final hasil = TextEditingController(text: k.hasil ?? '');
    final setuju = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hasil setelah dijalani'),
        content: bidangTeks(
          pengendali: hasil,
          label: 'Apa yang terjadi',
          baris: 4,
          petunjuk: 'Ditulis apa adanya, boleh belum sesuai harapan',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('simpan_hasil_keputusan'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Simpan hasil'),
          ),
        ],
      ),
    );
    if (setuju != true) return;
    await ref
        .read(pengetahuanRepoProvider)
        .tulisHasilKeputusan(k.id, hasil.text.trim(), kapan: _sekarang);
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.pengetahuan,
      aksi: AksiAudit.tandai,
      entitas: 'keputusan',
      ringkas: 'Hasil keputusan ditulis: ${k.judul}',
    );
    await _muat();
  }

  Future<void> _hapus(BarisKeputusan k) async {
    if (!await konfirmasiHapus(context, 'Keputusan "${k.judul}"')) return;
    await ref.read(pengetahuanRepoProvider).hapusKeputusan(k.id);
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final ringkas = ringkasKeputusan(_keputusan, acuan: _sekarang);
    return Scaffold(
      appBar: AppBar(title: const Text('Jurnal keputusan')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tambah_keputusan'),
        onPressed: () => _form(),
        icon: const Icon(Icons.add),
        label: const Text('Keputusan baru'),
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                kartuRingkas('Ringkasan keputusan', [
                  barisKunciNilai('Jumlah keputusan', '${ringkas.total}'),
                  barisKunciNilai('Perlu ditinjau', '${ringkas.menungguTinjauan}'),
                  barisKunciNilai('Sudah ada hasilnya', '${ringkas.sudahDitinjau}'),
                  barisKunciNilai(
                    'Keyakinan rata-rata',
                    ringkas.keyakinanRataRata == null
                        ? 'Belum ada data'
                        : '${ringkas.keyakinanRataRata!.round()} %',
                  ),
                ]),
                const SizedBox(height: 8),
                if (ringkas.perlu.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('Siap ditinjau',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  for (final k in ringkas.perlu)
                    Card(
                      key: Key('tinjau_keputusan_${k.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(k.judul,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Jadwal tinjau '
                                '${fmtTanggalPendekAman(k.tinjauPada!)}'),
                            const SizedBox(height: 8),
                            // Tombol ditaruh di bawah teks (bukan sebagai
                            // trailing): di layar sempit tombol samping akan
                            // menabrak batas lebar ListTile.
                            FilledButton(
                              key: Key('tulis_hasil_${k.id}'),
                              onPressed: () => _tulisHasil(k),
                              child: const Text('Tulis hasil'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Semua keputusan',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (_keputusan.isEmpty)
                  kartuKosong(
                    'Belum ada keputusan yang dicatat',
                    petunjuk: 'Menulis keputusan membuat alasannya tidak hilang '
                        'dan hasilnya bisa ditinjau kemudian.',
                  ),
                for (final k in _keputusan)
                  Card(
                    key: Key('keputusan_${k.id}'),
                    child: ListTile(
                      isThreeLine: true,
                      title: Text(k.judul,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((k.dipilih ?? '').isNotEmpty)
                            Text('Dipilih: ${k.dipilih}'),
                          Text('Keyakinan ${k.keyakinan} % · '
                              '${fmtTanggalPendekAman(k.diputuskanPada)}'),
                          if ((k.risiko ?? '').isNotEmpty)
                            Text('Risiko: ${k.risiko}'),
                          if ((k.biaya ?? '').isNotEmpty)
                            Text('Biaya: ${k.biaya}'),
                          if ((k.hasil ?? '').isNotEmpty)
                            Text('Hasil: ${k.hasil}'),
                          if (k.jumlahTautan > 0)
                            Wrap(children: [lencana('${k.jumlahTautan} tautan')]),
                        ],
                      ),
                      onTap: () => _form(ada: k),
                      trailing: PopupMenuButton<String>(
                        key: Key('menu_keputusan_${k.id}'),
                        onSelected: (p) {
                          if (p == 'ubah') _form(ada: k);
                          if (p == 'hasil') _tulisHasil(k);
                          if (p == 'hapus') _hapus(k);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'ubah', child: Text('Ubah')),
                          PopupMenuItem(value: 'hasil', child: Text('Tulis hasil')),
                          PopupMenuItem(value: 'hapus', child: Text('Hapus')),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
