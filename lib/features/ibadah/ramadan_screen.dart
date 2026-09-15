/// Layar Ramadan Mode (FR-91) — hitungan hari menuju 1 Ramadan & 1 Syawal,
/// waktu imsak/sahur dan maghrib (iftar), pengingat sahur/iftar, dan ringkasan
/// puasa bulan ini.
///
/// **Dari mana angkanya (jujur, tidak dikarang):**
/// * Tanggal Hijriah: `hijri_core` lewat [logika_ramadan.dart] + acuan &
///   koreksi hari yang Anda pilih.
/// * Imsak, Subuh, Maghrib: mesin hitung yang sama dengan layar Jadwal Sholat
///   ([penghitung_sholat.dart]), memakai kota, metode, madzhab Ashar, dan
///   koreksi ihtiyati dari [PengaturanIbadah].
/// * Imsak = Subuh − N menit (N bawaan 10, Anda bisa ubah).
/// * Ringkasan puasa: baris tabel `log_puasa` milik Anda (FR-92).
///
/// Dua kalimat kejujuran selalu ditampilkan: [labelPerhitungan] dan
/// [labelHijriahBisaBeda].
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ibadah/kalender_hijriah.dart';
import '../../core/ibadah/kota_indonesia.dart';
import '../../core/ibadah/model_sholat.dart';
import '../../core/ibadah/penghitung_sholat.dart';
import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/repository/ibadah_lanjutan_repository.dart';
import 'ibadah_lanjutan_provider.dart';
import 'komponen_ibadah_lanjutan.dart';
import 'logika_ramadan.dart';
import 'pengaturan_ibadah.dart';
import 'setelan_ibadah_lanjutan.dart';

/// Layar Ramadan (FR-91).
class RamadanScreen extends ConsumerStatefulWidget {
  const RamadanScreen({super.key});

  @override
  ConsumerState<RamadanScreen> createState() => _StateRamadan();
}

class _StateRamadan extends ConsumerState<RamadanScreen> {
  static const Duration _batas = Duration(seconds: 5);

  late final IbadahLanjutanRepository _repo;
  late final SetelanIbadahLanjutan _setelan;

  bool _memuat = true;
  bool _galat = false;

  KotaSholat _kota = daftarKotaIndonesia.first;
  MetodeHitungSholat _metode = MetodeHitungSholat.kemenag;
  int _ihtiyati = 0;
  int _imsakMenit = imsakMenitBawaan;
  bool _pengingatSahur = false;
  bool _pengingatIftar = false;
  AcuanHijriah _acuan = AcuanHijriah.ummAlQura;
  int _koreksi = 0;
  List<LogPuasaData> _puasaBulanIni = const <LogPuasaData>[];

  @override
  void initState() {
    super.initState();
    _repo = ref.read(ibadahLanjutanRepoProvider);
    _setelan = ref.read(setelanIbadahLanjutanProvider);
    unawaited(_muat());
  }

  Future<void> _muat() async {
    if (mounted) setState(() => _memuat = true);
    final DateTime hariIni = IbadahLanjutanRepository.hari(waktuSekarang());
    try {
      final PengaturanIbadah bersama = ref.read(setelanIbadahProvider);
      final KotaSholat kota = await bersama.kota().timeout(_batas);
      final MetodeHitungSholat metode = await bersama.metode().timeout(_batas);
      final int ihtiyati = await bersama.ihtiyatiMenit().timeout(_batas);
      final int imsak = await _setelan.imsakMenit().timeout(_batas);
      final bool sahur = await _setelan.pengingatSahurAktif().timeout(_batas);
      final bool iftar = await _setelan.pengingatIftarAktif().timeout(_batas);
      final AcuanHijriah acuan = await _setelan.acuanHijriah().timeout(_batas);
      final int koreksi = await _setelan.koreksiHijriah().timeout(_batas);
      final List<LogPuasaData> puasa =
          await _repo.puasaBulan(hariIni).timeout(_batas);
      if (!mounted) return;
      setState(() {
        _kota = kota;
        _metode = metode;
        _ihtiyati = ihtiyati;
        _imsakMenit = imsak;
        _pengingatSahur = sahur;
        _pengingatIftar = iftar;
        _acuan = acuan;
        _koreksi = koreksi;
        _puasaBulanIni = puasa;
        _memuat = false;
        _galat = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _galat = true;
      });
    }
  }

  Future<void> _ubahImsak(int selisih) async {
    final int baru = (_imsakMenit + selisih)
        .clamp(imsakMenitMinimal, imsakMenitMaksimal);
    await _setelan.simpanImsakMenit(baru).timeout(_batas);
    if (!mounted) return;
    setState(() => _imsakMenit = baru);
  }

  Future<void> _ubahKoreksi(int selisih) async {
    final int baru =
        (_koreksi + selisih).clamp(-koreksiHijriahMaksimal, koreksiHijriahMaksimal);
    await _setelan.simpanKoreksiHijriah(baru).timeout(_batas);
    if (!mounted) return;
    setState(() => _koreksi = baru);
  }

  Future<void> _ubahAcuan(AcuanHijriah acuan) async {
    await _setelan.simpanAcuanHijriah(acuan).timeout(_batas);
    if (!mounted) return;
    setState(() => _acuan = acuan);
  }

  Future<void> _ubahSaklar({required bool sahur, required bool aktif}) async {
    if (sahur) {
      await _setelan.simpanPengingatSahur(aktif).timeout(_batas);
      if (!mounted) return;
      setState(() => _pengingatSahur = aktif);
    } else {
      await _setelan.simpanPengingatIftar(aktif).timeout(_batas);
      if (!mounted) return;
      setState(() => _pengingatIftar = aktif);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final DateTime hariIni = IbadahLanjutanRepository.hari(waktuSekarang());
    final RencanaRamadan rencana =
        hitungRamadan(hariIni, acuan: _acuan, koreksiHari: _koreksi);
    final JadwalSholatHarian jadwal = hitungJadwal(
      kota: _kota,
      tanggal: hariIni,
      metode: _metode,
      asharHanafi: false,
      koreksiMenit: _ihtiyati == 0
          ? const <WaktuSholat, int>{}
          : <WaktuSholat, int>{
              for (final WaktuSholat w in WaktuSholat.wajibSaja) w: _ihtiyati,
            },
    );
    final WaktuSahurIftar waktu =
        waktuSahurIftar(jadwal, imsakMenit: _imsakMenit);
    final RingkasanPuasa ringkas = hitungRingkasanPuasa(_puasaBulanIni);
    LogPuasaData? catatanHariIni;
    for (final LogPuasaData b in _puasaBulanIni) {
      if (IbadahLanjutanRepository.hari(b.tanggal) == hariIni) {
        catatanHariIni = b;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ramadan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: <Widget>[
          KartuBagian(
            judul: 'Hitungan hari',
            ikon: Icons.nightlight_outlined,
            isi: _memuat
                ? const Text('Menghitung...')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (rencana.sedangRamadan) ...<Widget>[
                        Text(
                          'Hari ke-${rencana.hariKeRamadan} Ramadan '
                          '${rencana.tahunHijriahRamadan} H',
                          key: const Key('status_ramadan'),
                          style: tema.textTheme.titleMedium,
                        ),
                        BarisRingkasan(
                            label: 'Sisa hari puasa (perhitungan)',
                            nilai: '${rencana.sisaHariPuasa} hari'),
                      ] else if (rencana.hariMenujuRamadan != null)
                        Text(
                          '${rencana.hariMenujuRamadan} hari menuju 1 Ramadan '
                          '${rencana.tahunHijriahRamadan} H',
                          key: const Key('status_ramadan'),
                          style: tema.textTheme.titleMedium,
                        ),
                      if (rencana.hariIdulFitri)
                        const Text('Hari ini 1 Syawal menurut perhitungan',
                            key: Key('status_syawal'))
                      else if (rencana.hariMenujuSyawal != null)
                        BarisRingkasan(
                            label: 'Menuju 1 Syawal',
                            nilai: '${rencana.hariMenujuSyawal} hari'),
                      if (rencana.tanggalAwalRamadan != null)
                        BarisRingkasan(
                            label: 'Perkiraan 1 Ramadan (Masehi)',
                            nilai: teksTanggal(rencana.tanggalAwalRamadan!)),
                      if (rencana.tanggalIdulFitri != null)
                        BarisRingkasan(
                            label: 'Perkiraan 1 Syawal (Masehi)',
                            nilai: teksTanggal(rencana.tanggalIdulFitri!)),
                      if (rencana.hijriahHariIni != null)
                        BarisRingkasan(
                            label: 'Tanggal Hijriah hari ini',
                            nilai: rencana.hijriahHariIni!.label),
                      const Divider(height: 20),
                      Row(
                        children: <Widget>[
                          const Expanded(child: Text('Acuan Hijriah')),
                          SizedBox(
                            width: 190,
                            child: DropdownButtonFormField<AcuanHijriah>(
                              isExpanded: true,
                              key: const Key('acuan_hijriah'),
                              initialValue: _acuan,
                              items: <DropdownMenuItem<AcuanHijriah>>[
                                for (final AcuanHijriah a in AcuanHijriah.values)
                                  DropdownMenuItem<AcuanHijriah>(
                                      value: a, child: Text(a.label)),
                              ],
                              onChanged: (AcuanHijriah? a) {
                                if (a != null) unawaited(_ubahAcuan(a));
                              },
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: <Widget>[
                          const Expanded(child: Text('Koreksi hari Hijriah')),
                          IconButton(
                            key: const Key('koreksi_mundur'),
                            onPressed: _koreksi <= -koreksiHijriahMaksimal
                                ? null
                                : () => _ubahKoreksi(-1),
                            icon: const Icon(Icons.remove),
                          ),
                          Text('${_koreksi > 0 ? '+' : ''}$_koreksi'),
                          IconButton(
                            key: const Key('koreksi_maju'),
                            onPressed: _koreksi >= koreksiHijriahMaksimal
                                ? null
                                : () => _ubahKoreksi(1),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const CatatanJujur(teks: '$labelPerhitungan. $labelHijriahBisaBeda.'),
                    ],
                  ),
          ),
          KartuBagian(
            judul: 'Imsak & iftar hari ini',
            ikon: Icons.wb_twilight_outlined,
            isi: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                BarisRingkasan(
                    label: 'Imsak (perhitungan)',
                    nilai: teksJam(waktu.imsak),
                    tebal: true),
                BarisRingkasan(label: 'Subuh', nilai: teksJam(waktu.subuh)),
                BarisRingkasan(
                    label: 'Maghrib (waktu iftar)', nilai: teksJam(waktu.maghrib)),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    const Expanded(
                        child: Text('Imsak dihitung N menit sebelum Subuh')),
                    IconButton(
                      key: const Key('imsak_kurang'),
                      onPressed: () => _ubahImsak(-1),
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$_imsakMenit menit'),
                    IconButton(
                      key: const Key('imsak_tambah'),
                      onPressed: () => _ubahImsak(1),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                BarisRingkasan(
                    label: 'Rumus yang dipakai',
                    nilai: '${teksJam(waktu.subuh)} − $_imsakMenit menit '
                        '= ${teksJam(waktu.imsak)}'),
                const CatatanJujur(
                    teks: 'Waktu di atas dihitung untuk kota dan metode pada '
                        'setelan Anda. Jadwal sholat lengkap ada di layar '
                        'Jadwal Sholat.'),
                const CatatanJujur(teks: '$labelPerhitungan.'),
                if (!_galat)
                  CatatanJujur(
                      teks: 'Dihitung untuk ${waktu.namaKota} '
                          '(${waktu.labelZona}) · metode ${waktu.namaMetode} · '
                          'koreksi ihtiyati $_ihtiyati menit.'),
              ],
            ),
          ),
          KartuBagian(
            judul: 'Pengingat sahur & iftar',
            ikon: Icons.notifications_none_outlined,
            isi: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SwitchListTile(
                  key: const Key('saklar_sahur'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pengingat sahur'),
                  subtitle: const Text('Bawaan mati — nyalakan bila Anda mau.'),
                  value: _pengingatSahur,
                  onChanged: (bool v) => _ubahSaklar(sahur: true, aktif: v),
                ),
                SwitchListTile(
                  key: const Key('saklar_iftar'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pengingat iftar (maghrib)'),
                  subtitle: const Text('Bawaan mati — nyalakan bila Anda mau.'),
                  value: _pengingatIftar,
                  onChanged: (bool v) => _ubahSaklar(sahur: false, aktif: v),
                ),
                const CatatanJujur(
                    teks: 'Layar ini menyimpan pilihan Anda. Penjadwalan '
                        'notifikasi dikerjakan lapisan pengingat aplikasi, dan '
                        'jumlah pengingat dibatasi supaya tidak mengganggu.'),
              ],
            ),
          ),
          KartuBagian(
            judul: 'Ringkasan puasa bulan ini',
            ikon: Icons.event_available_outlined,
            isi: ringkas.kosong
                ? const BarisKosong(
                    keterangan: 'Catat lewat layar Puasa (FR-92).')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      BarisRingkasan(
                          label: 'Catatan berstatus puasa',
                          nilai: '${ringkas.puasa} hari'),
                      BarisRingkasan(
                          label: 'Catatan berstatus tidak puasa',
                          nilai: '${ringkas.tidak} hari'),
                      BarisRingkasan(
                          label: catatanHariIni == null
                              ? 'Catatan hari ini'
                              : 'Catatan hari ini (${JenisPuasa.dariDb(catatanHariIni.jenis).label})',
                          nilai: catatanHariIni == null
                              ? 'Belum ada data'
                              : StatusPuasa.dariDb(catatanHariIni.status).label),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
