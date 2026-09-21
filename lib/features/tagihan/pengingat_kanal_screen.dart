/// FR-49 — Layar "Pengingat multi-kanal (WhatsApp lebih dulu)".
///
/// Per tagihan: pilih kanal (notifikasi aplikasi / WhatsApp / SMS / Telegram),
/// simpan nomor tujuan, lihat pratinjau teks, lalu teruskan lewat aplikasi yang
/// dipilih dengan teks siap kirim. Nomor disimpan per tagihan di perangkat ini.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drift/drift.dart' hide Column;

import '../../core/laporan/kurs.dart';
import '../../core/platform/buka_tautan.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/database/database.dart';
import '../../data/model/enums.dart';
import '../../data/repository/pengaturan_repository.dart';
import '../../data/repository/tagihan_repository.dart';
import 'pengingat_kanal.dart';

/// Kunci penyimpanan nomor tujuan per tagihan.
const String kunciKontakPengingat = 'kontak_pengingat';

/// Baca/tulis nomor tujuan (satu JSON di tabel pengaturan).
class KontakPengingat {
  const KontakPengingat(this.pengaturan);

  final PengaturanRepository pengaturan;

  Future<Map<int, String>> semua() async {
    final teks = await pengaturan.baca(kunciKontakPengingat);
    if (teks == null || teks.trim().isEmpty) return {};
    final Object? data = jsonDecode(teks);
    if (data is! Map) return {};
    final hasil = <int, String>{};
    data.forEach((kunci, nilai) {
      final id = int.tryParse(kunci.toString());
      if (id == null || nilai is! String) return;
      hasil[id] = nilai;
    });
    return hasil;
  }

  Future<void> simpan(int tagihanId, String nomor) async {
    final peta = await semua();
    final bersih = nomor.trim();
    if (bersih.isEmpty) {
      peta.remove(tagihanId);
    } else {
      peta[tagihanId] = bersih;
    }
    await pengaturan.simpan(kunciKontakPengingat,
        jsonEncode({for (final e in peta.entries) e.key.toString(): e.value}));
  }

  Future<String> nomor(int tagihanId) async =>
      (await semua())[tagihanId] ?? '';
}

class PengingatKanalScreen extends ConsumerStatefulWidget {
  const PengingatKanalScreen({super.key, this.db, this.sekarang});

  final AppDatabase? db;
  final DateTime? sekarang;

  @override
  ConsumerState<PengingatKanalScreen> createState() =>
      _PengingatKanalScreenState();
}

class _PengingatKanalScreenState extends ConsumerState<PengingatKanalScreen> {
  AppDatabase get _db => widget.db ?? ref.read(databaseProvider);

  late final TagihanRepository _repo = TagihanRepository(_db);
  late final KontakPengingat _kontak =
      KontakPengingat(PengaturanRepository(_db));

  bool _memuat = true;
  List<TagihanData> _tagihan = const [];
  Map<int, String> _nomor = const {};
  final Map<int, TextEditingController> _kontrol = {};
  String? _galatBuka;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    for (final c in _kontrol.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final semua = await _repo.ambilSemua();
    final aktif = semua.where((t) => t.statusAktif && !t.lunas).toList()
      ..sort((a, b) => a.jatuhTempo.compareTo(b.jatuhTempo));
    final nomor = await _kontak.semua();
    for (final t in aktif) {
      final kontrol = _kontrol.putIfAbsent(t.id, () => TextEditingController());
      kontrol.text = nomor[t.id] ?? '';
    }
    if (!mounted) return;
    setState(() {
      _tagihan = aktif;
      _nomor = nomor;
      _memuat = false;
    });
  }

  Future<void> _simpanKanal(TagihanData t, List<KanalPengingat> kanal) async {
    await _repo.ubah(
      TagihanCompanion(
        kanalPengingat: Value(teksKanal(kanal)),
        diubahPada: Value(DateTime.now()),
      ),
      id: t.id,
    );
    await _muat();
  }

  Future<void> _teruskan(TagihanData t, KanalTerusan kanal) async {
    final nomor = _kontrol[t.id]?.text.trim() ?? '';
    final p = _nomor[t.id] ?? '';
    if (nomor != p) await _kontak.simpan(t.id, nomor);

    final pesan = pesanPengingat(t, sekarang: widget.sekarang);
    final tautan = kanal.tautan(pesan, nomor: nomor);
    final terbuka = await bukaTautan(tautan);
    if (!mounted) return;
    setState(() => _galatBuka = terbuka
        ? null
        : '${kanal.label} belum bisa dibuka di perangkat ini. '
            '(Pengingat otomatis lewat WhatsApp Business API belum ada di '
            'versi ini.)');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      key: const Key('hasil_teruskan'),
      content: Text(terbuka
          ? 'Teks pengingat dibuka di ${kanal.label}.'
          : '${kanal.label} tidak terbuka — teksnya bisa disalin manual.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) return const Center(child: CircularProgressIndicator());
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pengingat multi-kanal', style: tema.textTheme.titleMedium),
                const SizedBox(height: 6),
                const Text(
                    'Notifikasi aplikasi tetap kanal utama. Untuk meneruskan '
                    'pengingat, pilih kanal & isi nomor tujuan, lalu tekan '
                    'tombolnya: teks sudah siap kirim dan Papi masih bisa '
                    'menyunting sebelum mengirim.'),
                const SizedBox(height: 6),
                Text(
                  'Catatan jujur: pengiriman otomatis tanpa menekan apa pun '
                  '(WhatsApp Business API) belum ada — itu rencana v3.',
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        if (_tagihan.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada tagihan aktif yang belum lunas.'),
            ),
          ),
        for (final t in _tagihan) _kartu(t, tema),
      ],
    );
  }

  Widget _kartu(TagihanData t, ThemeData tema) {
    final kanalSekarang = kanalTagihan(t.kanalPengingat);
    final pesan = pesanPengingat(t, sekarang: widget.sekarang);
    return Card(
      key: Key('kanal_${t.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(t.nama, style: tema.textTheme.titleSmall)),
                Text(t.jumlahSen == null
                    ? '—'
                    : fmtMataUang(t.jumlahSen!, t.kodeMataUang)),
              ],
            ),
            Text('Jatuh tempo ${fmtTanggalId(t.jatuhTempo)}',
                style: tema.textTheme.bodySmall),
            const SizedBox(height: 10),
            Text('Kanal pengingat', style: tema.textTheme.labelLarge),
            Wrap(
              spacing: 8,
              children: [
                for (final k in KanalPengingat.values)
                  FilterChip(
                    key: Key('kanal_chip_${t.id}_${k.nilaiDb}'),
                    label: Text(switch (k) {
                      KanalPengingat.push => 'Notifikasi aplikasi',
                      KanalPengingat.whatsapp => 'WhatsApp',
                      KanalPengingat.sms => 'SMS',
                      KanalPengingat.telegram => 'Telegram',
                    }),
                    selected: kanalSekarang.contains(k),
                    onSelected: (pilih) {
                      final baru = [...kanalSekarang];
                      if (pilih) {
                        if (!baru.contains(k)) baru.add(k);
                      } else if (baru.length > 1) {
                        baru.remove(k);
                      }
                      _simpanKanal(t, baru);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: Key('nomor_tujuan_${t.id}'),
              controller: _kontrol[t.id],
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor tujuan (boleh dikosongkan)',
                hintText: 'mis. 0812 3456 7890',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (v) => _kontak.simpan(t.id, v),
            ),
            const SizedBox(height: 10),
            Text('Pratinjau teks', style: tema.textTheme.labelLarge),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tema.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(pesan,
                  key: Key('pratinjau_${t.id}'), style: tema.textTheme.bodySmall),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final k in KanalTerusan.values)
                  FilledButton.tonalIcon(
                    key: Key('teruskan_${k.nilaiDb}_${t.id}'),
                    onPressed: () => _teruskan(t, k),
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: Text('Kirim ke ${k.label}'),
                  ),
              ],
            ),
            if (_galatBuka != null) ...[
              const SizedBox(height: 8),
              Text(_galatBuka!,
                  key: Key('galat_buka_${t.id}'),
                  style: TextStyle(color: tema.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
