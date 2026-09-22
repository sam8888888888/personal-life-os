/// FR-98 — Layar Arah Kiblat & Masjid Terdekat.
///
/// Tanpa sensor kompas layar TIDAK menampilkan angka palsu: ia menyebut bahwa
/// sensor tidak ada lalu memberi arah mata angin + derajat (dari koordinat kota
/// yang dipilih). Daftar masjid diambil dari jaringan, disimpan di perangkat,
/// dan selalu menyebut sumber & waktu data.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ibadah/kiblat.dart';
import '../../core/ibadah/kota_indonesia.dart';
import '../../core/ibadah/model_sholat.dart';
import '../../core/platform/kanal_kompas.dart';
import '../../core/providers/batch10_providers.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/bahasa.dart';
import '../../data/repository/masjid_repository.dart';
import '../../data/repository/pengaturan_repository.dart';

const String kunciKotaKiblat = 'kiblat.kota';

class KiblatScreen extends ConsumerStatefulWidget {
  /// Aliran arah hadap tiruan (dipakai uji; di HP memakai sensor sungguhan).
  const KiblatScreen({super.key, this.aliranUji});

  final Stream<HeadingKompas?>? aliranUji;

  @override
  ConsumerState<KiblatScreen> createState() => _KiblatScreenState();
}

class _KiblatScreenState extends ConsumerState<KiblatScreen> {
  KotaSholat _kota = daftarKotaIndonesia.firstWhere(
    (k) => k.nama == 'Jakarta',
    orElse: () => daftarKotaIndonesia.first,
  );
  bool _sensorAda = false;
  HeadingKompas? _heading;
  HasilMasjid? _masjid;
  bool _memuatMasjid = false;
  bool _siap = false;
  StreamSubscription<HeadingKompas?>? _langganan;

  @override
  void initState() {
    super.initState();
    _siapkan();
  }

  @override
  void dispose() {
    _langganan?.cancel();
    super.dispose();
  }

  Future<void> _siapkan() async {
    final pengaturan = PengaturanRepository(ref.read(databaseProvider));
    final nama = await pengaturan.bacaTeks(kunciKotaKiblat, 'Jakarta');
    final kota = daftarKotaIndonesia.firstWhere(
      (k) => k.nama == nama,
      orElse: () => _kota,
    );
    final sensor = await KanalKompas.sensorAda();
    if (!mounted) return;
    setState(() {
      _kota = kota;
      _sensorAda = sensor;
      _siap = true;
    });
    final aliran = widget.aliranUji ?? KanalKompas.aliran();
    _langganan = aliran.listen((h) {
      if (!mounted) return;
      setState(() => _heading = h);
    });
  }

  Future<void> _gantiKota(KotaSholat? k) async {
    if (k == null) return;
    await PengaturanRepository(ref.read(databaseProvider))
        .simpan(kunciKotaKiblat, k.nama);
    if (!mounted) return;
    setState(() {
      _kota = k;
      _masjid = null;
    });
  }

  Future<void> _cariMasjid() async {
    setState(() => _memuatMasjid = true);
    final hasil = await ref.read(repoMasjidProvider).sekitar(
          lintang: _kota.lintang,
          bujur: _kota.bujur,
        );
    if (!mounted) return;
    setState(() {
      _masjid = hasil;
      _memuatMasjid = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasil = hitungKiblat(
      lintang: _kota.lintang,
      bujur: _kota.bujur,
      headingDerajat: _heading?.derajat,
      akurasiDerajat: _heading?.akurasi,
      sensorAda: _sensorAda,
    );
    return Scaffold(
      appBar: AppBar(title: Text(tr('kiblat.judul'))),
      body: !_siap
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Card(
                  key: const Key('kiblat_kartu'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Text('${hasil.derajatKiblatBulat}°',
                          key: const Key('kiblat_derajat'),
                          style: const TextStyle(
                              fontSize: 44, fontWeight: FontWeight.w700)),
                      Text(hasil.arahKiblatTeks,
                          key: const Key('kiblat_arah'),
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CustomPaint(
                          painter: _PiringanKiblat(
                            putaranDerajat: hasil.putaranPiringan,
                            warna: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (hasil.kompasSiap)
                        Text('Arah hadap HP: ${_heading!.derajat.round()}°')
                      else
                        Text(
                          tr('kiblat.tanpaSensor'),
                          key: const Key('kiblat_tanpa_sensor'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      const SizedBox(height: 8),
                      Text(hasil.pesan, key: const Key('kiblat_pesan')),
                      if (hasil.perluKalibrasi) ...[
                        const SizedBox(height: 6),
                        Text(tr('kiblat.kalibrasi'),
                            key: const Key('kiblat_kalibrasi'),
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 8),
                      Text(hasil.dasar,
                          key: const Key('kiblat_dasar'),
                          style: const TextStyle(
                              fontSize: 12, fontStyle: FontStyle.italic)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<KotaSholat>(
                  key: const Key('kiblat_kota'),
                  isExpanded: true,
                  initialValue: _kota,
                  decoration: const InputDecoration(
                      labelText: 'Kota (dipakai untuk hitungan arah)'),
                  items: daftarKotaIndonesia
                      .map((k) => DropdownMenuItem(
                          value: k, child: Text('${k.nama} · ${k.provinsi}')))
                      .toList(),
                  onChanged: _gantiKota,
                ),
                const SizedBox(height: 16),
                Text(tr('kiblat.masjid'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const Key('kiblat_cari_masjid'),
                  onPressed: _memuatMasjid ? null : _cariMasjid,
                  icon: const Icon(Icons.search),
                  label: const Text('Cari masjid di sekitar kota ini'),
                ),
                if (_memuatMasjid)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_masjid != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    key: const Key('masjid_asal'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_masjid!.teksAsal),
                    ),
                  ),
                  for (final m in _masjid!.daftar)
                    ListTile(
                      key: Key('masjid_${m.nama}'),
                      dense: true,
                      leading: const Icon(Icons.mosque_outlined),
                      title: Text(m.nama),
                      subtitle: Text('${m.jarakTeks}'
                          '${(m.alamat ?? '').isEmpty ? '' : ' · ${m.alamat}'}'),
                    ),
                  if (_masjid!.daftar.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(_masjid!.pesan ??
                          'Tidak ada masjid ditemukan pada radius 3 km.'),
                    ),
                ],
              ],
            ),
    );
  }
}

/// Piringan kompas sederhana: jarum Utara + penanda kiblat.
class _PiringanKiblat extends CustomPainter {
  const _PiringanKiblat({this.putaranDerajat, required this.warna});

  /// Sudut putaran piringan (kiblat − arah hadap). Null = sensor tidak ada,
  /// piringan tidak berputar (arah mata angin tetap benar).
  final double? putaranDerajat;
  final Color warna;

  @override
  void paint(Canvas canvas, Size size) {
    final tengah = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 6;
    final garis = Paint()
      ..color = warna.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    final tebal = Paint()
      ..color = warna
      ..strokeWidth = 3;

    canvas.drawCircle(tengah, r, garis);
    for (var i = 0; i < 8; i++) {
      final sudut = i * math.pi / 4;
      final luar = Offset(math.sin(sudut), -math.cos(sudut));
      canvas.drawLine(
          tengah + luar * (r * 0.92), tengah + luar * r, i % 2 == 0 ? tebal : garis);
    }

    final putar = putaranDerajat == null ? 0.0 : putaranDerajat!;
    canvas.save();
    canvas.translate(tengah.dx, tengah.dy);
    canvas.rotate(putar * math.pi / 180);
    // jarum kiblat (panah)
    final p = Path()
      ..moveTo(0, -r * 0.85)
      ..lineTo(-8, 0)
      ..lineTo(8, 0)
      ..close();
    canvas.drawPath(p, Paint()..color = warna);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PiringanKiblat lama) =>
      lama.putaranDerajat != putaranDerajat;
}
