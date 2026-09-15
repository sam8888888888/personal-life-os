/// Layar Pelacakan 5 Waktu Sholat (FR-88).
///
/// Aturan bahasa (III-11 PRD): semua kalimat netral dan tidak menghakimi.
/// Tidak ada "skor", tidak ada "gagal", tidak ada kata yang menuduh, dan
/// tidak ada warna merah untuk catatan ini. Yang ada hanya
/// "tercatat" / "belum tercatat" — keputusan tetap milik pengguna.
///
/// Sumber waktu: kalau jadwal hari itu sudah tersimpan di perangkat
/// ([PenyimpananJadwal]), nilainya dipakai. Kalau simpanan belum ada, jadwal
/// dihitung sendiri lewat [hitungJadwal] — 100% di perangkat, tanpa internet.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:personal_life_os/core/utils/waktu.dart';

import '../../core/ibadah/kalender_hijriah.dart';
import '../../core/ibadah/kota_indonesia.dart';
import '../../core/ibadah/model_log_sholat.dart';
import '../../core/ibadah/model_sholat.dart';
import '../../core/ibadah/penghitung_sholat.dart';
import '../../core/ibadah/penyimpanan_jadwal.dart';
import '../../core/ibadah/penyimpanan_log_sholat.dart';
import 'pengaturan_ibadah.dart';
import 'rekap_sholat_screen.dart';

class PelacakanSholatScreen extends StatefulWidget {
  const PelacakanSholatScreen({
    super.key,
    this.jamSekarang,
    this.kotaAwal,
    this.penyimpanan,
    this.penyimpananLog,
    this.setelan,
  });

  /// Sumber waktu. Isinya INSTAN sebenarnya (boleh `.toUtc()`), sama seperti
  /// [JadwalSholatScreen]: tanggal sipil dihitung di zona kota pilihan.
  final DateTime Function()? jamSekarang;

  /// Kota awal; null = kota tersimpan (bila ada), jika tidak Jakarta.
  final KotaSholat? kotaAwal;

  /// Setelan bersama (satu pintu dengan layar Jadwal Sholat); null = layar
  /// memakai bawaannya sendiri.
  final PengaturanIbadah? setelan;

  /// Simpanan jadwal sholat (FR-86); null = folder dokumen aplikasi.
  final PenyimpananJadwal? penyimpanan;

  /// Simpanan catatan sholat; null = folder dokumen aplikasi.
  final PenyimpananLogSholat? penyimpananLog;

  @override
  State<PelacakanSholatScreen> createState() => _StatePelacakanSholat();
}

class _StatePelacakanSholat extends State<PelacakanSholatScreen> {
  /// Metode hitung cadangan bila simpanan jadwal belum ada; ikut pilihan
  /// tersimpan supaya hasilnya sama dengan layar Jadwal Sholat.
  MetodeHitungSholat _metode = MetodeHitungSholat.kemenag;

  late KotaSholat _kota;

  /// Hasil hitung sendiri (selalu ada, tidak menunggu berkas apa pun).
  late JadwalSholatHarian _jadwalHitung;

  /// Jadwal dari simpanan perangkat, bila ada dan lengkap.
  JadwalSholatHarian? _jadwalTersimpan;

  /// null = catatan hari ini masih dibaca.
  CatatanSholat? _catatan;

  DateTime get _sekarang => (widget.jamSekarang ?? waktuSekarang)();

  PenyimpananLogSholat get _log => widget.penyimpananLog ?? PenyimpananLogSholat();

  /// Tanggal sipil "hari ini" di zona kota (jam 00:00 sebagai penanda).
  DateTime get _hariIniKota {
    final DateTime dinding =
        _sekarang.toUtc().add(Duration(hours: _kota.zona.offsetJam));
    return DateTime.utc(dinding.year, dinding.month, dinding.day);
  }

  String get _tanggalHariIni => tanggalKunci(_hariIniKota);

  JadwalSholatHarian get _jadwal => _jadwalTersimpan ?? _jadwalHitung;

  @override
  void initState() {
    super.initState();
    _kota = widget.kotaAwal ??
        daftarKotaIndonesia.firstWhere((KotaSholat k) => k.nama == 'Jakarta');
    _hitungUlang();
    unawaited(_muatCatatan());
    unawaited(_pakaiSimpananJadwal());
    unawaited(_muatSetelan());
  }

  /// Ambil kota & metode dari setelan bersama supaya jam yang ditampilkan di
  /// sini sama dengan jam di layar Jadwal Sholat (dulu layar ini selalu Jakarta).
  Future<void> _muatSetelan() async {
    final PengaturanIbadah? s = widget.setelan;
    if (s == null) return;
    try {
      final KotaSholat kota = await s.kota();
      final MetodeHitungSholat metode =
          await s.metode().timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        // Kota yang diminta pemanggil (mis. tautan pintasan) tidak ditimpa.
        if (widget.kotaAwal == null) _kota = kota;
        _metode = metode;
        _hitungUlang();
      });
      await _pakaiSimpananJadwal();
    } catch (_) {
      // Setelan tidak terbaca: hitungan bawaan tetap tampil.
    }
  }

  void _hitungUlang() {
    _jadwalHitung = hitungJadwal(
      kota: _kota,
      tanggal: _hariIniKota,
      metode: _metode,
    );
  }

  /// Baca catatan hari ini dari perangkat (operasi berkas sinkron di baliknya,
  /// jadi tidak menggantung di zona waktu palsu saat diuji).
  Future<void> _muatCatatan() async {
    final CatatanSholat c = await _log.ambil(_tanggalHariIni);
    if (!mounted) return;
    setState(() => _catatan = c);
  }

  /// Utamakan jadwal tersimpan; kalau belum ada, simpan hasil hitung sendiri.
  Future<void> _pakaiSimpananJadwal() async {
    final PenyimpananJadwal p = widget.penyimpanan ?? PenyimpananJadwal();
    try {
      final JadwalSholatHarian? tersimpan = await p.ambil(
        tanggal: _hariIniKota,
        kota: _kota,
        kodeMetode: _metode.kode,
      );
      final bool lengkap = tersimpan != null &&
          WaktuSholat.values
              .every((WaktuSholat w) => tersimpan.waktuUtc.containsKey(w));
      if (lengkap) {
        if (!mounted) return;
        setState(() => _jadwalTersimpan = tersimpan);
        return;
      }
      await p.simpanBanyak(<JadwalSholatHarian>[_jadwalHitung],
          sekarang: _sekarang);
    } catch (_) {
      // Simpanan jadwal hanya kemudahan: hitungan sendiri sudah tampil.
    }
  }

  Future<void> _ubahStatus(WaktuSholat w, bool tercatat) async {
    await _log.tandai(_tanggalHariIni, w, tercatat: tercatat);
    await _muatCatatan();
  }

  Future<void> _tandaiSemua() async {
    for (final WaktuSholat w in WaktuSholat.wajibSaja) {
      await _log.tandai(_tanggalHariIni, w);
    }
    await _muatCatatan();
  }

  Future<void> _kosongkanHari() async {
    await _log.kosongkanHari(_tanggalHariIni);
    await _muatCatatan();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final JadwalSholatHarian jadwal = _jadwal;
    final CatatanSholat? catatan = _catatan;

    return Scaffold(
      appBar: AppBar(title: const Text('Pelacakan Sholat')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _kartuKepala(tema),
          const SizedBox(height: 8),
          _kartuRingkasan(tema, catatan),
          const SizedBox(height: 8),
          if (catatan == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sedang membaca catatan hari ini...'),
              ),
            )
          else ...<Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  key: const Key('tandai_semua'),
                  onPressed: () => unawaited(_tandaiSemua()),
                  icon: const Icon(Icons.done_all),
                  label: const Text('Tandai semua tercatat'),
                ),
                OutlinedButton.icon(
                  key: const Key('kosongkan_hari'),
                  onPressed: () => unawaited(_kosongkanHari()),
                  icon: const Icon(Icons.remove_done),
                  label: const Text('Kosongkan catatan hari ini'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('buka_rekap'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const RekapSholatScreen())),
              icon: const Icon(Icons.insights_outlined),
              label: const Text('Lihat riwayat 7 hari'),
            ),
            const SizedBox(height: 12),
            Text('Lima waktu wajib hari ini',
                style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final WaktuSholat w in WaktuSholat.wajibSaja)
              _BarisPelacakan(
                waktu: w,
                jam: jamMenit(jadwal.waktuLokal(w)),
                zona: _kota.zona.label,
                tercatat: catatan.tercatatPada(w),
                onUbah: (bool nilai) => unawaited(_ubahStatus(w, nilai)),
              ),
          ],
          const SizedBox(height: 12),
          _kartuCatatanKaki(tema, jadwal),
        ],
      ),
    );
  }

  /// Kepala: hari + tanggal Masehi, tanggal Hijriah, kota, dan zona.
  Widget _kartuKepala(ThemeData tema) {
    final TanggalHijriah? hijriah = hijriahDariMasehi(_hariIniKota);
    final String hari = namaHariSingkat[(_hariIniKota.weekday - 1) % 7];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('$hari, ${tanggalPendek(_hariIniKota)}',
                style: tema.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              hijriah?.label ?? 'Tanggal Hijriah belum tersedia',
              style: tema.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(_kota.labelLengkap, style: tema.textTheme.bodyMedium),
            Text(
              'Zona ${_kota.zona.label} — ${_kota.zona.namaPanjang}',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(catatanPenetapan, style: tema.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  /// Kalimat ringkas netral: berapa waktu yang sudah tercatat hari ini.
  Widget _kartuRingkasan(ThemeData tema, CatatanSholat? catatan) {
    final int jumlah = catatan?.jumlah ?? 0;
    final bool sudahDibaca = catatan != null;
    return Card(
      color: tema.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Catatan hari ini', style: tema.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              !sudahDibaca
                  ? 'Sedang membaca catatan hari ini...'
                  : jumlah == 0
                      ? 'Belum ada catatan hari ini'
                      : '$jumlah dari 5 waktu tercatat hari ini',
              style: tema.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (catatan?.lengkap ?? false) ...<Widget>[
              const SizedBox(height: 4),
              const Text('Lima waktu sudah tercatat hari ini.'),
            ],
          ],
        ),
      ),
    );
  }

  /// Catatan kaki jujur: milik pengguna sendiri, dan ini hasil perhitungan.
  Widget _kartuCatatanKaki(ThemeData tema, JadwalSholatHarian jadwal) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Catatan', style: tema.textTheme.titleSmall),
              const SizedBox(height: 4),
              const Text(
                'Catatan ini hanya untuk Anda sendiri. Aplikasi tidak memberi '
                'penilaian.',
              ),
              const SizedBox(height: 8),
              const Text('Perhitungan waktu, bukan jadwal resmi.'),
              const SizedBox(height: 8),
              const Text(
                'Semua dihitung di perangkat, jadi layar ini tetap bisa dibuka '
                'tanpa internet.',
              ),
              const SizedBox(height: 8),
              Text(jadwal.penandaSumber, style: tema.textTheme.bodySmall),
            ],
          ),
        ),
      );
}

/// Satu baris waktu wajib: nama, jam, dan tombol status yang bisa diketuk.
class _BarisPelacakan extends StatelessWidget {
  const _BarisPelacakan({
    required this.waktu,
    required this.jam,
    required this.zona,
    required this.tercatat,
    required this.onUbah,
  });

  final WaktuSholat waktu;
  final String jam;
  final String zona;
  final bool tercatat;
  final ValueChanged<bool> onUbah;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    waktu.label,
                    style: tema.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text('Jam $jam $zona', style: tema.textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ActionChip(
              key: Key('status_${waktu.name}'),
              avatar: Icon(
                tercatat
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
                size: 18,
                color: tercatat
                    ? tema.colorScheme.primary
                    : tema.colorScheme.onSurfaceVariant,
              ),
              label: Text(tercatat ? 'Tercatat' : 'Belum tercatat'),
              backgroundColor: tercatat
                  ? tema.colorScheme.primaryContainer
                  : tema.colorScheme.surfaceContainerHighest,
              onPressed: () => onUbah(!tercatat),
            ),
          ],
        ),
      ),
    );
  }
}
