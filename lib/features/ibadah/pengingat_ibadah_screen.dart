/// Layar Pengingat Ibadah (FR-63 ringkasan pagi & FR-87 pengingat sholat).
///
/// Aturan isi (PRD III-11): menyebut fakta, tidak menghakimi; tidak ada ajakan
/// bersalah; jumlah notifikasi terbatas (maksimum 1 ringkasan/hari dan 1
/// pengingat/waktu/hari) — semuanya ditulis apa adanya di layar.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ibadah/kota_indonesia.dart';
import '../../core/ibadah/model_sholat.dart';
import '../../core/ibadah/penghitung_sholat.dart';
import '../../core/notifikasi/perencana_pengingat.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/waktu.dart';
import 'pengaturan_ibadah.dart';

/// Jam yang bisa dipilih langsung (tanpa pemilih waktu sistem).
const List<String> jamBriefingPilihan = <String>[
  '04:00', '04:30', '05:00', '05:30', '06:00', '06:30',
  '07:00', '07:30', '08:00', '09:00', '10:00',
];

/// Menit geser yang bisa dipilih langsung.
const List<int> geserPilihan = <int>[5, 10, 15, 20, 30, 45, 60];

class PengingatIbadahScreen extends ConsumerStatefulWidget {
  const PengingatIbadahScreen({super.key, this.setelan, this.jamSekarang});

  /// Setelan yang dipakai; null = ambil dari basis data aplikasi.
  ///
  /// Disuntikkan saat pengujian supaya layar bisa diuji tanpa basis data nyata.
  final PengaturanIbadah? setelan;

  /// Sumber waktu (bisa diganti saat pengujian) — hanya untuk pratinjau jadwal.
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<PengingatIbadahScreen> createState() =>
      _PengingatIbadahScreenState();
}

class _PengingatIbadahScreenState extends ConsumerState<PengingatIbadahScreen> {
  PengaturanIbadah? _setelan;
  bool _muat = true;

  /// Setelan tersimpan tidak bisa dibaca; layar tetap tampil dengan bawaan.
  bool _takTerbaca = false;

  bool _briefing = true;
  String _jam = jamBriefingBawaan;
  bool _sholat = false;
  KotaSholat _kota = daftarKotaIndonesia.firstWhere(
      (KotaSholat k) => k.nama == kotaSholatBawaan);
  MetodeHitungSholat _metode = MetodeHitungSholat.kemenag;
  bool _hanafi = false;
  int _ihtiyati = 0;
  final Map<WaktuSholat, ModePengingatSholat> _mode =
      <WaktuSholat, ModePengingatSholat>{};
  final Map<WaktuSholat, int> _geser = <WaktuSholat, int>{};

  @override
  void initState() {
    super.initState();
    for (final WaktuSholat w in WaktuSholat.wajibSaja) {
      _mode[w] = ModePengingatSholat.tepat;
      _geser[w] = 0;
    }
    _siapkan();
  }

  Future<void> _siapkan() async {
    final PengaturanIbadah s =
        widget.setelan ??
            PengaturanIbadah.dariRepository(ref.read(pengaturanRepoProvider));
    try {
      // Batas waktu: pembacaan yang tidak pernah menjawab tidak boleh membuat
      // layar berputar tanpa akhir.
      await _bacaSetelan(s).timeout(const Duration(seconds: 5));
    } catch (_) {
      _takTerbaca = true;
    }
    if (!mounted) return;
    setState(() {
      _setelan = s;
      _muat = false;
    });
  }

  Future<void> _bacaSetelan(PengaturanIbadah s) async {
    final bool briefing = await s.briefingAktif();
    final String jam = await s.jamBriefing();
    final bool sholat = await s.pengingatSholatAktif();
    final KotaSholat kota = await s.kota();
    final MetodeHitungSholat metode = await s.metode();
    final bool hanafi = await s.asharHanafi();
    final int ihtiyati = await s.ihtiyatiMenit();
    final Map<WaktuSholat, ModePengingatSholat> mode =
        <WaktuSholat, ModePengingatSholat>{};
    final Map<WaktuSholat, int> geser = <WaktuSholat, int>{};
    for (final WaktuSholat w in WaktuSholat.wajibSaja) {
      mode[w] = await s.mode(w);
      geser[w] = await s.geser(w);
    }
    _briefing = briefing;
    _jam = jam;
    _sholat = sholat;
    _kota = kota;
    _metode = metode;
    _hanafi = hanafi;
    _ihtiyati = ihtiyati;
    _mode
      ..clear()
      ..addAll(mode);
    _geser
      ..clear()
      ..addAll(geser);
  }

  /// Jalankan penyimpanan; beri kabar singkat ke pengguna.
  Future<void> _ubah(
    Future<void> Function(PengaturanIbadah s) aksi,
    String pesan,
  ) async {
    final PengaturanIbadah? s = _setelan;
    if (s == null) return;
    try {
      await aksi(s).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(pesan)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Setelan ini belum bisa disimpan. Coba lagi nanti.')));
    }
  }

  /// Hitung jadwal hari ini untuk pratinjau (tidak menulis apa pun).
  Map<WaktuSholat, DateTime> _pratinjau() {
    try {
      final DateTime kini = (widget.jamSekarang ?? waktuSekarang)();
      final JadwalSholatHarian j = hitungJadwal(
        kota: _kota,
        tanggal: DateTime.utc(kini.year, kini.month, kini.day),
        metode: _metode,
        asharHanafi: _hanafi,
      );
      return <WaktuSholat, DateTime>{
        for (final WaktuSholat w in WaktuSholat.wajibSaja)
          if (j.waktuLokalAtauNull(w) != null) w: j.waktuLokal(w),
      };
    } catch (_) {
      return <WaktuSholat, DateTime>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengingat Ibadah')),
      body: _muat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: <Widget>[
                if (_takTerbaca)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Setelan tersimpan belum bisa dibaca, jadi layar ini '
                      'menampilkan bawaan. Perubahan tetap bisa disimpan.',
                    ),
                  ),
                _bagianRingkasanPagi(),
                const SizedBox(height: 16),
                _bagianSholat(),
              ],
            ),
    );
  }

  // --- FR-63 ---------------------------------------------------------------

  Widget _bagianRingkasanPagi() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Ringkasan pagi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text('Satu notifikasi sehari: jumlah tagihan 7 hari ke depan '
                'dan ajakan membuka aplikasi.'),
          ),
          SwitchListTile(
            key: const Key('saklar_briefing'),
            value: _briefing,
            title: const Text('Kirim ringkasan pagi'),
            subtitle: Text(_briefing ? 'Aktif' : 'Nonaktif'),
            onChanged: (bool v) {
              setState(() => _briefing = v);
              _ubah((PengaturanIbadah s) => s.simpanBriefingAktif(v),
                  v ? 'Ringkasan pagi dinyalakan.' : 'Ringkasan pagi dimatikan.');
            },
          ),
          if (_briefing) ...<Widget>[
            ListTile(
              key: const Key('pilih_jam_briefing'),
              title: const Text('Jam ringkasan'),
              subtitle: const Text('Waktu notifikasi setiap hari'),
              trailing: DropdownButton<String>(
                key: const Key('daftar_jam'),
                value: jamBriefingPilihan.contains(_jam) ? _jam : null,
                hint: Text(_jam),
                items: <DropdownMenuItem<String>>[
                  for (final String j in jamBriefingPilihan)
                    DropdownMenuItem<String>(value: j, child: Text(j)),
                ],
                onChanged: (String? j) {
                  if (j == null) return;
                  setState(() => _jam = j);
                  _ubah((PengaturanIbadah s) => s.simpanJamBriefing(j),
                      'Jam ringkasan diubah ke $j.');
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Bila jam ini sudah lewat hari ini, ringkasan pertama '
                  'dikirim besok pada jam yang sama.'),
            ),
          ],
        ],
      ),
    );
  }

  // --- FR-87 ---------------------------------------------------------------

  Widget _bagianSholat() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Pengingat waktu sholat',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text('Satu pengingat per waktu per hari — paling banyak 5 '
                'sehari. Tidak ada pengingat berulang.'),
          ),
          SwitchListTile(
            key: const Key('saklar_sholat'),
            value: _sholat,
            title: const Text('Nyalakan pengingat waktu sholat'),
            subtitle: Text(_sholat ? 'Aktif' : 'Nonaktif'),
            onChanged: (bool v) {
              setState(() => _sholat = v);
              _ubah((PengaturanIbadah s) => s.simpanPengingatSholatAktif(v),
                  v ? 'Pengingat sholat dinyalakan.' : 'Pengingat sholat dimatikan.');
            },
          ),
          if (_sholat) ..._pilihanSholat(),
        ],
      ),
    );
  }

  List<Widget> _pilihanSholat() {
    final Map<WaktuSholat, DateTime> pratinjau = _pratinjau();
    return <Widget>[
      _bagianSumberHitungan(),
      const Divider(height: 8),
      for (final WaktuSholat w in WaktuSholat.wajibSaja) _barisWaktu(w, pratinjau),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Text(
          'Perhitungan hari ini untuk ${_kota.nama}: '
          '${_teksPratinjau(pratinjau)}. Ini perhitungan aplikasi, bukan jadwal '
          'resmi, jadi bisa berbeda 1–2 menit dari jadwal masjid setempat. '
          'Hari-hari berikutnya memakai hitungan hari ini, jadi bisa bergeser '
          'beberapa menit. Kota & cara perhitungan dipakai bersama layar Jadwal '
          'Sholat (satu pintu): diubah di salah satu, keduanya ikut berubah. '
          'Notifikasi hanya berbunyi bila izin notifikasi untuk aplikasi ini '
          'sudah diberikan di pengaturan HP.',
          key: const Key('catatan_jadwal'),
        ),
      ),
    ];
  }

  /// Kota & cara perhitungan tidak lagi dipilih di layar ini: pilihannya
  /// disimpan bersama layar Jadwal Sholat supaya pengingat tidak berbunyi untuk
  /// kota yang berbeda dari jadwal yang dilihat pengguna.
  Widget _bagianSumberHitungan() {
    final String ashar = _hanafi ? 'madzhab Hanafi' : 'madzhab Syafi\'i';
    final String koreksi = _ihtiyati == 0
        ? 'tanpa koreksi'
        : '${_ihtiyati > 0 ? '+' : ''}$_ihtiyati menit';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Kota ${_kota.nama} · ${_metode.label} · Ashar $ashar · $koreksi',
            key: const Key('ringkasan_sumber_hitungan'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('buka_jadwal_sholat'),
              icon: const Icon(Icons.schedule_outlined),
              label: const Text('Atur kota & cara perhitungan'),
              onPressed: () async {
                await context.push('/ibadah/jadwal-sholat');
                // Setelah kembali, baca lagi supaya pratinjau memakai pilihan
                // terbaru (satu pintu: disimpan di layar Jadwal Sholat).
                if (mounted) unawaited(_siapkan());
              },
            ),
          ),
        ],
      ),
    );
  }

  String _teksPratinjau(Map<WaktuSholat, DateTime> jadwal) {
    if (jadwal.isEmpty) return 'belum bisa dihitung';
    return WaktuSholat.wajibSaja
        .where(jadwal.containsKey)
        .map((WaktuSholat w) => '${w.label} ${teksJam(jadwal[w]!)}')
        .join(' · ');
  }

  Widget _barisWaktu(WaktuSholat w, Map<WaktuSholat, DateTime> pratinjau) {
    final ModePengingatSholat mode = _mode[w] ?? ModePengingatSholat.tepat;
    final DateTime? jam = pratinjau[w];
    final List<int> opsiGeser =
        <int>{...geserPilihan, _geser[w] ?? 0}.toList()..sort();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(jam == null
              ? w.label
              : '${w.label} · ${teksJam(jam)} (perhitungan)'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final ModePengingatSholat m in ModePengingatSholat.values)
                ChoiceChip(
                  key: Key('mode_${w.name}_${m.nilaiDb}'),
                  label: Text(m.label),
                  selected: mode == m,
                  onSelected: (_) {
                    setState(() => _mode[w] = m);
                    _ubah((PengaturanIbadah s) => s.simpanMode(w, m),
                        '${w.label}: ${m.label}.');
                  },
                ),
            ],
          ),
          if (mode != ModePengingatSholat.tepat)
            Row(
              children: <Widget>[
                const Text('Geser'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  key: Key('geser_${w.name}'),
                  value: (_geser[w] ?? 0),
                  items: <DropdownMenuItem<int>>[
                    for (final int g in opsiGeser)
                      DropdownMenuItem<int>(value: g, child: Text('$g menit')),
                  ],
                  onChanged: (int? g) {
                    if (g == null) return;
                    setState(() => _geser[w] = g);
                    _ubah((PengaturanIbadah s) => s.simpanGeser(w, g),
                        '${w.label}: geser $g menit.');
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}
