/// FR-55 — Layar Delegasi Cepat via WhatsApp.
///
/// Pengguna memilih pengingat (dari tagihan belum lunas atau tulis sendiri),
/// menulis nama + nomor tujuan, lalu aplikasi MENYIAPKAN pesan dan membuka
/// WhatsApp/SMS lewat kanal FR-49. Setiap pengiriman dicatat — termasuk saat
/// hanya disalin — supaya tidak terkirim dua kali tanpa sadar.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifikasi/delegasi_whatsapp.dart';
import '../../core/platform/buka_tautan.dart';
import '../../core/utils/bahasa.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';
import '../../core/providers/batch11_providers.dart';

class DelegasiScreen extends ConsumerStatefulWidget {
  const DelegasiScreen({super.key});

  @override
  ConsumerState<DelegasiScreen> createState() => _DelegasiScreenState();
}

class _DelegasiScreenState extends ConsumerState<DelegasiScreen> {
  RingkasanDelegasi? _ringkas;
  List<TagihanData> _tagihan = const [];
  bool _siap = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final repo = ref.read(repoDelegasiProvider);
      final ringkas = await repo.ringkasan();
      final tagihan = await ref.read(repoDelegasiSumberTagihanProvider)();
      if (!mounted) return;
      setState(() {
        _ringkas = ringkas;
        _tagihan = tagihan;
        _siap = true;
        _galat = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _siap = true;
        _galat = 'Gagal memuat delegasi: ${e.runtimeType}.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ringkas = _ringkas;
    return Scaffold(
      appBar: AppBar(title: Text(tr('delegasi.judul'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('delegasi_tambah'),
        onPressed: _buat,
        icon: const Icon(Icons.send_outlined),
        label: Text(tr('delegasi.kirim')),
      ),
      body: !_siap
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                if (_galat != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_galat!),
                    ),
                  ),
                if (ringkas != null) ...[
                  Card(
                    key: const Key('delegasi_ringkas'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ringkas.dasar,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          for (final e in ringkas.perOrang)
                            Text('• ${e.key}: ${e.value}×'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (ringkas != null && ringkas.daftar.isEmpty)
                  Padding(
                    key: const Key('delegasi_kosong'),
                    padding: const EdgeInsets.all(12),
                    child: Text('${tr('umum.belumAda')} Tekan '
                        '"${tr('delegasi.kirim')}" untuk meneruskan pengingat '
                        'tagihan lewat WhatsApp/SMS ke anggota keluarga.'),
                  ),
                for (final d in ringkas?.daftar ?? const <DelegasiTercatat>[])
                  Card(
                    key: Key('delegasi_${d.judul}_${d.waktu.millisecondsSinceEpoch}'),
                    child: ListTile(
                      title: Text(d.judul),
                      subtitle: Text('${d.keNama} · ${nomorTampil(d.nomor)} · '
                          '${d.kanal.label} · ${d.waktu.day}/${d.waktu.month} '
                          '${d.waktu.hour.toString().padLeft(2, '0')}:'
                          '${d.waktu.minute.toString().padLeft(2, '0')}'),
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: d.teks));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Teks pengingat disalin.')),
                        );
                      },
                    ),
                  ),
                for (final b in ringkas?.belumBisa ?? const <String>[])
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${tr('umum.belumBisa')}: $b',
                        style: const TextStyle(fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
    );
  }

  Future<void> _buat() async {
    final judul = TextEditingController();
    final ke = TextEditingController();
    final nomor = TextEditingController();
    final kanal = ValueNotifier<KanalDelegasi>(KanalDelegasi.whatsapp);
    final pilihan = ValueNotifier<TagihanData?>(null);

    final lanjut = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('delegasi.tambah')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ValueListenableBuilder<TagihanData?>(
              valueListenable: pilihan,
              builder: (_, v, _) => DropdownButtonFormField<int>(
                key: const Key('delegasi_sumber'),
                initialValue: v?.id,
                decoration: const InputDecoration(
                    labelText: 'Ambil dari tagihan (opsional)'),
                items: [
                  const DropdownMenuItem(value: -1, child: Text('— tulis sendiri —')),
                  ..._tagihan.map((t) => DropdownMenuItem(
                        value: t.id,
                        child: Text('${t.nama} '
                            '${fmtRpDariSen(t.jumlahSen ?? 0)}'),
                      )),
                ],
                onChanged: (x) {
                  if (x == null || x == -1) {
                    pilihan.value = null;
                    return;
                  }
                  final t = _tagihan.firstWhere((z) => z.id == x);
                  pilihan.value = t;
                  judul.text = t.nama;
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('delegasi_judul'),
              controller: judul,
              decoration: const InputDecoration(labelText: 'Judul pengingat'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('delegasi_ke'),
              controller: ke,
              decoration: const InputDecoration(labelText: 'Nama tujuan (mis. Kakak)'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('delegasi_nomor'),
              controller: nomor,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Nomor HP (opsional)',
                  hintText: 'contoh: 0812…'),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<KanalDelegasi>(
              valueListenable: kanal,
              builder: (_, v, _) => DropdownButtonFormField<KanalDelegasi>(
                key: const Key('delegasi_kanal'),
                initialValue: v,
                decoration: const InputDecoration(labelText: 'Kanal'),
                items: KanalDelegasi.values
                    .map((k) => DropdownMenuItem(value: k, child: Text(k.label)))
                    .toList(),
                onChanged: (x) {
                  if (x != null) kanal.value = x;
                },
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<KanalDelegasi>(
              valueListenable: kanal,
              builder: (_, v, _) {
                final alasan = alasanTidakBisaKirim(
                    nomor: nomor.text, kanal: v);
                if (alasan.isEmpty) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Catatan: ${alasan.join(' ')}',
                      key: const Key('delegasi_catatan'),
                      style: const TextStyle(fontSize: 12)),
                );
              },
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('umum.batal'))),
          FilledButton(
              key: const Key('delegasi_kirim'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('delegasi.kirim'))),
        ],
      ),
    );
    if (lanjut != true) return;
    if (judul.text.trim().isEmpty || ke.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Judul dan nama tujuan perlu diisi dulu.')),
      );
      return;
    }

    final tagihanKu = pilihan.value;
    final mesin = ref.read(repoDelegasiProvider);
    final teks = tagihanKu == null
        ? teksDelegasiTugas(
            judul: judul.text.trim(),
            dariNama: 'Papi',
            keNama: ke.text.trim(),
          )
        : teksDelegasiTagihan(
            judul: tagihanKu.nama,
            jumlahSen: tagihanKu.jumlahSen ?? 0,
            jatuhTempo: tagihanKu.jatuhTempo,
            dariNama: 'Papi',
            keNama: ke.text.trim(),
          );

    var terkirim = false;
    var pesan = '';
    switch (kanal.value) {
      case KanalDelegasi.salin:
        await Clipboard.setData(ClipboardData(text: teks));
        terkirim = true;
        pesan = 'Teks pengingat disalin — tempel di aplikasi mana pun.';
        break;
      case KanalDelegasi.whatsapp:
        final tautan = tautanWhatsapp(nomor.text, teks);
        if (tautan == null) {
          pesan = 'Nomor belum sah, jadi tidak bisa membuka WhatsApp. '
              'Pengingat dicatat dan teksnya bisa disalin.';
        } else {
          terkirim = await bukaTautan(tautan);
          pesan = terkirim
              ? 'WhatsApp dibuka dengan pesan siap kirim.'
              : 'Tidak ada aplikasi WhatsApp yang bisa dibuka di perangkat ini.';
        }
        break;
      case KanalDelegasi.sms:
        final tautan = tautanSms(nomor.text, teks);
        if (tautan == null) {
          pesan = 'Nomor belum sah, jadi SMS tidak bisa dibuka.';
        } else {
          terkirim = await bukaTautan(tautan);
          pesan = terkirim
              ? 'Aplikasi SMS dibuka dengan pesan siap kirim.'
              : 'Tidak ada aplikasi SMS yang bisa dibuka di perangkat ini.';
        }
        break;
    }

    if (!terkirim && kanal.value != KanalDelegasi.salin) {
      await Clipboard.setData(ClipboardData(text: teks));
      pesan = '$pesan Teksnya sudah disalin sebagai cadangan.';
    }

    await mesin.catat(
      judul: judul.text.trim(),
      keNama: ke.text.trim(),
      nomor: nomor.text.trim(),
      kanal: kanal.value,
      teks: teks,
    );

    await _muat();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }
}
