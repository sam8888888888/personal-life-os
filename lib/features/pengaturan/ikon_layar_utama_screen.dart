/// FR-22, FR-31 & FR-151 — layar pengaturan ikon & widget layar utama.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lencana/lencana_ikon.dart';
import '../../core/platform/kanal_widget.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widget_utama/aksi_widget.dart';
import '../../core/utils/waktu.dart';
import '../../core/widget_utama/widget_hari_ini.dart';

class IkonLayarUtamaScreen extends ConsumerStatefulWidget {
  const IkonLayarUtamaScreen({super.key});

  @override
  ConsumerState<IkonLayarUtamaScreen> createState() =>
      _IkonLayarUtamaScreenState();
}

class _IkonLayarUtamaScreenState
    extends ConsumerState<IkonLayarUtamaScreen> {
  RingkasWidgetLayar? _ringkas;
  String? _pesan;

  @override
  void initState() {
    super.initState();
    _muatPratinjau();
  }

  Future<void> _muatPratinjau() async {
    final semua = await ref.read(tagihanRepoProvider).ambilSemua();
    final ringkas = susunRingkasWidget(
      [
        for (final t in semua)
          if (t.statusAktif && !t.lunas)
            (
              id: t.id,
              nama: t.nama,
              jatuhTempo: t.jatuhTempo,
              jumlahSen: t.jumlahSen,
            ),
      ],
      waktuSekarang(),
    );
    if (mounted) setState(() => _ringkas = ringkas);
  }

  Future<void> _simpanLencana(bool nyala) async {
    await ref
        .read(pengaturanRepoProvider)
        .simpan(kunciLencanaAktif, nyala ? 'ya' : 'tidak');
    ref.invalidate(lencanaAktifProvider);
    if (mounted) {
      setState(() => _pesan = nyala
          ? 'Lencana angka dinyalakan. Angka muncul bila peluncur HP Anda '
              'mendukung lencana — sebagian peluncur tidak menampilkannya.'
          : 'Lencana angka dimatikan.');
    }
  }

  Future<void> _simpanWidget(bool nyala) async {
    await ref
        .read(pengaturanRepoProvider)
        .simpan(kunciWidgetAktif, nyala ? 'ya' : 'tidak');
    ref.invalidate(widgetAktifProvider);
    await _kirimKeWidget();
    if (mounted) {
      setState(() => _pesan = nyala
          ? 'Isi widget diperbarui.'
          : 'Widget dimatikan — isi widget kosong.');
    }
  }

  Future<void> _kirimKeWidget() async {
    await _muatPratinjau();
    final ringkas = _ringkas;
    if (ringkas == null) return;
    await const KanalWidget().perbarui(
      judul: ringkas.judul,
      total: ringkas.total,
      catatan: ringkas.catatan,
      baris: ringkas.baris,
      idBaris: ringkas.idBaris,
      aksiId: ringkas.aksiId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lencana = ref.watch(lencanaAktifProvider).value ?? true;
    final widgetNyala = ref.watch(widgetAktifProvider).value ?? true;
    return Scaffold(
      appBar: AppBar(title: const Text('Ikon & widget')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            key: const Key('saklar_lencana'),
            value: lencana,
            onChanged: _simpanLencana,
            title: const Text('Lencana angka di ikon aplikasi'),
            subtitle: const Text('Menampilkan jumlah tagihan yang jatuh tempo '
                'hari ini atau sudah lewat.'),
          ),
          SwitchListTile(
            key: const Key('saklar_widget'),
            value: widgetNyala,
            onChanged: _simpanWidget,
            title: const Text('Widget layar utama'),
            subtitle: const Text(
                'Menampilkan tagihan 7 hari ke depan + totalnya.'),
          ),
          const Divider(height: 32),
          const Text('Pratinjau isi widget',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Ini persis isi yang dikirim ke widget di layar utama HP Anda.',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          Card(
            key: const Key('pratinjau_widget'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_ringkas?.judul ?? 'Memuat…',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(_ringkas?.total ?? '',
                      style: const TextStyle(fontSize: 13)),
                  const Divider(height: 18),
                  if ((_ringkas?.baris.isEmpty ?? true))
                    const Text('Belum ada tagihan pada 7 hari ke depan.')
                  else
                    for (var i = 0; i < _ringkas!.baris.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• ${_ringkas!.baris[i]}'),
                      ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        key: const Key('aksi_widget_lunas'),
                        onPressed: _ringkas?.aksiId == null
                            ? null
                            : () async {
                                final id = _ringkas!.aksiId!;
                                final hasil =
                                    await AksiWidgetLayanan(
                                            ref.read(tagihanRepoProvider))
                                        .jalankan(
                                            AksiWidget(aksi: 'lunas', id: id));
                                await _muatPratinjau();
                                if (mounted) {
                                  setState(() => _pesan = hasil.pesan);
                                }
                              },
                        icon: const Icon(Icons.check),
                        label: const Text('Tandai lunas'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('aksi_widget_tambah'),
                        onPressed: () async {
                          final hasil = await AksiWidgetLayanan(
                                  ref.read(tagihanRepoProvider))
                              .jalankan(const AksiWidget(
                                  aksi: 'tambah-pengeluaran'));
                          if (mounted) setState(() => _pesan = hasil.pesan);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Catat pengeluaran'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_ringkas?.catatan ?? '',
                      style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('perbarui_widget'),
            onPressed: () async {
              await _kirimKeWidget();
              if (mounted) {
                setState(() =>
                    _pesan = 'Isi widget dikirim ulang ke layar utama.');
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Kirim ulang isi widget'),
          ),
          const Divider(height: 32),
          const Text('Cara memasang widget di layar utama',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('1. Tekan lama area kosong di layar utama HP.\n'
              '2. Pilih "Widget" → cari "Personal Life OS".\n'
              '3. Tarik widget "Tagihan 7 hari" ke layar utama.'),
          const SizedBox(height: 6),
          const Text(
            'Dari widget: menekan baris tagihan membuka daftar tagihan, dan '
            'tombol "Tandai lunas" langsung menandai tagihan terdekat sebagai '
            'lunas tanpa membuka formulir. Tersinkron dengan aplikasi karena '
            'keduanya menulis ke basis data yang sama.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
          const Text(
            'Catatan jujur: lencana angka bergantung pada peluncur (launcher) '
            'HP masing-masing. Sebagian HP menampilkannya, sebagian tidak — '
            'aplikasi tidak bisa memaksa.',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
          if (_pesan != null) ...[
            const SizedBox(height: 16),
            Text(_pesan!, key: const Key('pesan_ikon_widget')),
          ],
        ],
      ),
    );
  }
}
