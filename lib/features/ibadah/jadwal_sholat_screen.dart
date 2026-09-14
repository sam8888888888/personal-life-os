/// Layar Jadwal Sholat (FR-86).
///
/// Aturan isi (III-11 PRD): tidak ada kata yang menghakimi, tidak ada "skor",
/// tidak ada notifikasi tanpa batas. Semua teks menyebut hasil sebagai
/// "perhitungan", bukan jadwal resmi.
library;

import 'package:flutter/material.dart';

import '../../core/ibadah/kalender_hijriah.dart';
import '../../core/ibadah/kota_indonesia.dart';
import '../../core/ibadah/model_sholat.dart';
import '../../core/ibadah/penghitung_sholat.dart';
import '../../core/ibadah/penyimpanan_jadwal.dart';

class JadwalSholatScreen extends StatefulWidget {
  const JadwalSholatScreen({
    super.key,
    this.kotaAwal,
    this.jamSekarang,
    this.penyimpanan,
    this.jumlahHariSimpan = 7,
  });

  /// Kota awal; null = Jakarta.
  final KotaSholat? kotaAwal;

  /// Sumber waktu (bisa diganti saat pengujian).
  final DateTime Function()? jamSekarang;

  /// Penyimpan cache (null = folder dokumen aplikasi).
  final PenyimpananJadwal? penyimpanan;

  /// Berapa hari ke depan yang dihitung & disimpan.
  final int jumlahHariSimpan;

  @override
  State<JadwalSholatScreen> createState() => _StateJadwalSholat();
}

class _StateJadwalSholat extends State<JadwalSholatScreen> {
  static const int _batasIhtiyati = 3;

  late KotaSholat _kota;
  MetodeHitungSholat _metode = MetodeHitungSholat.kemenag;
  bool _hanafi = false;
  int _ihtiyati = 0;
  late List<JadwalSholatHarian> _rentang;
  DateTime? _tersimpan;

  DateTime get _sekarang => (widget.jamSekarang ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _kota = widget.kotaAwal ??
        daftarKotaIndonesia.firstWhere((KotaSholat k) => k.nama == 'Jakarta');
    _hitungUlang();
    WidgetsBinding.instance.addPostFrameCallback((_) => _simpanKeCache());
  }

  Map<WaktuSholat, int> get _koreksi => <WaktuSholat, int>{
        for (final WaktuSholat w in WaktuSholat.values) w: _ihtiyati,
      };

  /// Tanggal sipil "hari ini" di zona kota.
  DateTime get _hariIniKota {
    final DateTime dinding =
        _sekarang.toUtc().add(Duration(hours: _kota.zona.offsetJam));
    return DateTime.utc(dinding.year, dinding.month, dinding.day);
  }

  void _hitungUlang() {
    _rentang = hitungRentang(
      kota: _kota,
      tanggalMulai: _hariIniKota,
      jumlahHari: widget.jumlahHariSimpan,
      metode: _metode,
      asharHanafi: _hanafi,
      koreksiMenit: _koreksi,
    );
  }

  Future<void> _simpanKeCache() async {
    final PenyimpananJadwal p = widget.penyimpanan ?? PenyimpananJadwal();
    try {
      await p.simpanBanyak(_rentang, sekarang: _sekarang);
      if (mounted) setState(() => _tersimpan = _sekarang);
    } catch (_) {
      // cache gagal bukan masalah bagi pengguna
    }
  }

  JadwalSholatHarian get _jadwalHariIni => _rentang.first;

  WaktuBerikutnya? get _berikutnya => cariWaktuBerikutnya(
        jadwal: _rentang,
        sekarang: _sekarang,
      );

  Future<void> _pilihKota() async {
    final KotaSholat? pilih = await showModalBottomSheet<KotaSholat>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext c) => _SheetPilihKota(kotaTerpilih: _kota),
    );
    if (pilih == null || !mounted) return;
    setState(() {
      _kota = pilih;
      _hitungUlang();
    });
    await _simpanKeCache();
  }

  void _ubahIhtiyati(int delta) {
    final int baru = (_ihtiyati + delta).clamp(-_batasIhtiyati, _batasIhtiyati);
    if (baru == _ihtiyati) return;
    setState(() {
      _ihtiyati = baru;
      _hitungUlang();
    });
    _simpanKeCache();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final JadwalSholatHarian j = _jadwalHariIni;
    final WaktuBerikutnya? berikut = _berikutnya;
    final TanggalHijriah? hijriah = hijriahDariMasehi(_hariIniKota);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Sholat'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Hitung ulang',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(_hitungUlang);
              _simpanKeCache();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    hijriah?.label ?? 'Tanggal Hijriah belum tersedia',
                    style: tema.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tanggalPendek(_hariIniKota),
                    style: tema.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    catatanPenetapan,
                    style: tema.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: tema.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Berikutnya', style: tema.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    berikut == null
                        ? 'Semua waktu hari ini sudah lewat'
                        : '${berikut.waktu.label} ${jamMenit(berikut.jamLokal)}'
                            '${berikut.besok ? ' (besok)' : ''}',
                    style: tema.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (berikut != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      'Sisa ${_durasiRingkas(berikut.sisa(_sekarang))}',
                      style: tema.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(j.penandaSumber,
              style: tema.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.location_city_outlined),
                  title: const Text('Kota'),
                  subtitle: Text(_kota.labelLengkap),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pilihKota,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calculate_outlined),
                  title: const Text('Metode perhitungan'),
                  subtitle: Text(_metode.label),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<MetodeHitungSholat>(
                    initialValue: _metode,
                    // isExpanded wajib: label metode terpanjang membuat
                    // deretan meluber di layar HP (ditemukan uji UI).
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Pilih metode',
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<MetodeHitungSholat>>[
                      for (final MetodeHitungSholat m in MetodeHitungSholat.values)
                        DropdownMenuItem<MetodeHitungSholat>(
                          value: m,
                          child: Text(m.label),
                        ),
                    ],
                    onChanged: (MetodeHitungSholat? m) {
                      if (m == null) return;
                      setState(() {
                        _metode = m;
                        _hitungUlang();
                      });
                      _simpanKeCache();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Ashar madzhab Hanafi'),
                  subtitle: const Text('Bila dimatikan: madzhab Syafii (lazim di Indonesia)'),
                  value: _hanafi,
                  onChanged: (bool v) {
                    setState(() {
                      _hanafi = v;
                      _hitungUlang();
                    });
                    _simpanKeCache();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Koreksi kehati-hatian'),
                  subtitle: Text(_ihtiyati == 0
                      ? 'Tanpa koreksi'
                      : '${_ihtiyati > 0 ? '+' : ''}$_ihtiyati menit untuk semua waktu'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Kurangi satu menit',
                        onPressed: _ihtiyati <= -_batasIhtiyati
                            ? null
                            : () => _ubahIhtiyati(-1),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      IconButton(
                        tooltip: 'Tambah satu menit',
                        onPressed: _ihtiyati >= _batasIhtiyati
                            ? null
                            : () => _ubahIhtiyati(1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Waktu hari ini', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final WaktuSholat w in WaktuSholat.values)
            _BarisWaktu(
              waktu: w,
              jam: jamMenit(j.waktuLokal(w)),
              aktif: berikut?.waktu == w,
              zona: _kota.zona.label,
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Catatan', style: tema.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  const Text(
                    'Perhitungan, bukan jadwal resmi. Hasil dapat berbeda 0-2 menit '
                    'dari jadwal Kementerian Agama. Semua dihitung di perangkat, '
                    'jadi tetap jalan tanpa internet.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tersimpan == null
                        ? 'Belum ada data tersimpan'
                        : 'Tersimpan di perangkat untuk ${widget.jumlahHariSimpan} hari',
                    style: tema.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _durasiRingkas(Duration d) {
    final int jam = d.inHours;
    final int menit = d.inMinutes % 60;
    if (jam <= 0) return '$menit menit';
    return '$jam jam $menit menit';
  }
}

class _BarisWaktu extends StatelessWidget {
  const _BarisWaktu({
    required this.waktu,
    required this.jam,
    required this.aktif,
    required this.zona,
  });

  final WaktuSholat waktu;
  final String jam;
  final bool aktif;
  final String zona;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Card(
      color: aktif ? tema.colorScheme.primaryContainer : null,
      child: ListTile(
        leading: Icon(
          waktu.wajib ? Icons.schedule : Icons.wb_sunny_outlined,
          color: aktif ? tema.colorScheme.primary : null,
        ),
        title: Text(waktu.label,
            style: TextStyle(
              fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
            )),
        subtitle: Text(waktu.keterangan),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(jam,
                style: tema.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text(zona, style: tema.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Lembar pilih kota dengan pencarian.
class _SheetPilihKota extends StatefulWidget {
  const _SheetPilihKota({required this.kotaTerpilih});

  final KotaSholat kotaTerpilih;

  @override
  State<_SheetPilihKota> createState() => _StateSheetKota();
}

class _StateSheetKota extends State<_SheetPilihKota> {
  String _kata = '';

  @override
  Widget build(BuildContext context) {
    final List<KotaSholat> hasil = cariKota(_kata);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Pilih kota',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Cari kota atau provinsi',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String v) => setState(() => _kata = v),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: hasil.length,
                  itemBuilder: (BuildContext c, int i) {
                    final KotaSholat k = hasil[i];
                    return ListTile(
                      title: Text(k.nama),
                      subtitle: Text('${k.provinsi} - ${k.zona.label}'),
                      trailing: k.nama == widget.kotaTerpilih.nama
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.of(context).pop(k),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
