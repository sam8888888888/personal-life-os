/// FR-101 — Dasbor kesehatan (tren sederhana).
///
/// Isi: berat terakhir, tekanan darah terakhir, aktivitas 7 hari, rata-rata
/// tidur 7 hari, air hari ini, dan obat hari ini. Setiap bagian yang belum
/// punya catatan menulis "Belum ada data" — bukan angka nol.
///
/// Batas aman konten (PRD §7.4 & III-11): halaman ini hanya melaporkan angka
/// yang dicatat pengguna. Tidak ada kesimpulan "sehat/tidak sehat", tidak ada
/// ambang batas medis, dan tidak ada saran pengobatan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/editorial.dart';
import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/repository/kesehatan_repository.dart';
import '../../data/repository/obat_repository.dart';
import 'grafik_batang_harian.dart';
import 'label_hari.dart';
import 'provider_kesehatan.dart';

class KesehatanHubScreen extends ConsumerStatefulWidget {
  const KesehatanHubScreen({super.key, this.jamSekarang});

  /// Sumber waktu (dipakai uji & tangkapan layar supaya tanggal tidak bergeser).
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<KesehatanHubScreen> createState() => _KesehatanHubScreenState();
}

class _KesehatanHubScreenState extends ConsumerState<KesehatanHubScreen> {
  bool _memuat = true;
  bool _adaMasalah = false;

  UkuranTubuhData? _berat;
  TekananDarah? _tekanan;
  RingkasanAktivitas? _aktivitas;
  List<BatangHarian> _batangAktivitas = const [];
  RingkasanTidur? _tidur;
  RingkasanAir? _air;
  RingkasanObatHariIni? _obat;

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final kesehatan = ref.read(kesehatanRepoProvider);
    final obat = ref.read(obatRepoProvider);
    final kini = _sekarang;
    try {
      final berat = await kesehatan.ukuranTerbaru(JenisUkuran.berat);
      final tekanan = await kesehatan.tekananDarahTerakhir();
      final aktivitas = await kesehatan.ringkasanAktivitas(acuan: kini);
      final batang = await kesehatan.batangAktivitas(hari: 7, sampai: kini);
      final tidur = await kesehatan.ringkasanTidur(acuan: kini);
      final air = await kesehatan.ringkasanAir(acuan: kini);
      final obatHariIni = await obat.ringkasanHariIni(hari: kini);
      if (!mounted) return;
      setState(() {
        _berat = berat;
        _tekanan = tekanan;
        _aktivitas = aktivitas;
        _batangAktivitas = batang;
        _tidur = tidur;
        _air = air;
        _obat = obatHariIni;
        _memuat = false;
        _adaMasalah = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _adaMasalah = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final aktivitas = _aktivitas;
    final tidur = _tidur;
    final air = _air;
    final obat = _obat;

    return Scaffold(
      appBar: AppBar(title: const Text('Kesehatan')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                if (_adaMasalah)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Catatan belum bisa dibaca dari penyimpanan. '
                        'Silakan buka kembali halaman ini.',
                        style: tema.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                KartuUtama(
                  label: 'Hari ini',
                  judul: _kalimatRingkas(),
                  anak: _anakRingkas(),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
                  child: Text('Angka terakhir',
                      style: tema.textTheme.labelSmall),
                ),
                _kartu(
                  kunci: 'kartu_berat',
                  ikon: Icons.monitor_weight_outlined,
                  judul: 'Berat terakhir',
                  isi: _berat == null
                      ? 'Belum ada data'
                      : '${formatAngkaDesimal(_berat!.nilai)} ${_berat!.satuan}'
                          ' · ${labelTanggalSedang(_berat!.tanggal)}',
                ),
                _kartu(
                  kunci: 'kartu_tekanan_darah',
                  ikon: Icons.favorite_outline,
                  judul: 'Tekanan darah terakhir',
                  isi: _tekanan == null
                      ? 'Belum ada data'
                      : '${_tekanan!.teks}'
                          ' · ${labelTanggalSedang(_tekanan!.tanggal)}',
                ),
                _kartu(
                  kunci: 'kartu_aktivitas',
                  ikon: Icons.directions_run_outlined,
                  judul: 'Aktivitas 7 hari',
                  isi: (aktivitas == null || !aktivitas.adaCatatan)
                      ? 'Belum ada data'
                      : 'Total ${aktivitas.menit7Hari} menit dalam 7 hari '
                          'terakhir · hari ini ${aktivitas.menitHariIni} menit',
                  tambahan: (aktivitas != null && aktivitas.adaCatatan)
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: GrafikBatangHarian(
                            key: const Key('grafik_aktivitas_7_hari'),
                            batang: _batangAktivitas,
                            satuan: 'menit',
                          ),
                        )
                      : null,
                ),
                _kartu(
                  kunci: 'kartu_tidur',
                  ikon: Icons.bedtime_outlined,
                  judul: 'Rata-rata tidur 7 hari',
                  isi: (tidur == null || tidur.rataRata7HariMenit == null)
                      ? 'Belum ada data'
                      : 'Rata-rata ${formatDurasiMenit(tidur.rataRata7HariMenit!)}'
                          ' dari ${tidur.jumlahMalam7Hari} malam tercatat',
                ),
                _kartu(
                  kunci: 'kartu_air',
                  ikon: Icons.water_drop_outlined,
                  judul: 'Air hari ini',
                  isi: (air == null || !air.adaCatatan)
                      ? 'Belum ada data'
                      : '${formatMl(air.totalMl)} dari target '
                          '${formatMl(air.targetMl)}',
                ),
                _kartu(
                  kunci: 'kartu_obat',
                  ikon: Icons.medication_outlined,
                  judul: 'Obat hari ini',
                  isi: (obat == null || !obat.adaJadwal)
                      ? 'Belum ada data'
                      : obat.kalimatTercatat,
                ),
                const SizedBox(height: 16),
                Text('Buka pencatat', style: tema.textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _pintu(
                        kunci: 'buka_aktivitas',
                        ikon: Icons.directions_run_outlined,
                        judul: 'Aktivitas',
                        keterangan: 'Catat jenis, durasi & intensitas',
                        tujuan: '/kesehatan/aktivitas',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_tidur',
                        ikon: Icons.bedtime_outlined,
                        judul: 'Tidur',
                        keterangan: 'Jam tidur, jam bangun & kualitas',
                        tujuan: '/kesehatan/tidur',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_energi',
                        ikon: Icons.bolt_outlined,
                        judul: 'Energi & jam produktif',
                        keterangan: 'Energi & fokus 1–5 harian, plus jam '
                            'produktif pribadi setelah 14 hari',
                        tujuan: '/kesehatan/energi',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_ukuran_tubuh',
                        ikon: Icons.monitor_weight_outlined,
                        judul: 'Berat & ukuran tubuh',
                        keterangan: 'IMT, lingkar perut, lemak & target',
                        tujuan: '/kesehatan/ukuran-tubuh',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_jurnal_angka',
                        ikon: Icons.monitor_heart_outlined,
                        judul: 'Jurnal kesehatan (angka)',
                        keterangan:
                            'Tekanan darah, gula darah, suhu & tren 30 hari',
                        tujuan: '/kesehatan/jurnal-angka',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_janji_dokter',
                        ikon: Icons.event_available_outlined,
                        judul: 'Janji dokter & kontrol',
                        keterangan:
                            'Janji, tes lab & pengingat 7 hari/1 hari/2 jam',
                        tujuan: '/kesehatan/janji',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_jadwal_obat',
                        ikon: Icons.alarm_outlined,
                        judul: 'Pengingat obat & suplemen',
                        keterangan: 'Jadwal jam minum + catatan kepatuhan '
                            '(opsional, perlu izin)',
                        tujuan: '/kesehatan/obat/jadwal',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_obat',
                        ikon: Icons.medication_outlined,
                        judul: 'Obat & vitamin',
                        keterangan: 'Jadwal minum & penanda minum',
                        tujuan: '/kesehatan/obat',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_air',
                        ikon: Icons.water_drop_outlined,
                        judul: 'Air',
                        keterangan: 'Catat gelas & target harian',
                        tujuan: '/kesehatan/air',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_makan',
                        ikon: Icons.restaurant_outlined,
                        judul: 'Catatan makan',
                        keterangan: 'Catat cepat, daftar sederhana',
                        tujuan: '/kesehatan/makan',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_suasana',
                        ikon: Icons.mood_outlined,
                        judul: 'Suasana hati & stres',
                        keterangan: 'Suasana hati, energi & stres 1–5',
                        tujuan: '/kesehatan/suasana',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_temuan',
                        ikon: Icons.insights_outlined,
                        judul: 'Temuan dari catatan Anda',
                        keterangan: 'Pola dari angka yang Anda catat sendiri',
                        tujuan: '/kesehatan/temuan',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_laporan_bulanan',
                        ikon: Icons.summarize_outlined,
                        judul: 'Laporan bulanan',
                        keterangan: 'Perubahan berat, tidur, air & suasana',
                        tujuan: '/kesehatan/laporan-bulanan',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_catatan_medis',
                        ikon: Icons.medical_information_outlined,
                        judul: 'Brankas catatan medis',
                        keterangan:
                            'Hasil lab, resep, imunisasi & tagihan medis',
                        tujuan: '/kesehatan/catatan-medis',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_peringatan_dini',
                        ikon: Icons.notifications_active_outlined,
                        judul: 'Peringatan dini',
                        keterangan: 'Pola yang melewati ambang sendiri',
                        tujuan: '/kesehatan/peringatan-dini',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_kunjungan',
                        ikon: Icons.description_outlined,
                        judul: 'Mode kunjungan dokter',
                        keterangan: 'Ringkasan 30 hari, 1 halaman PDF',
                        tujuan: '/kesehatan/kunjungan',
                      ),
                      const Divider(height: 1),
                      // SDD v19 Gelombang 2 — empat pintu kesehatan baru.
                      _pintu(
                        kunci: 'buka_lab',
                        ikon: Icons.science_outlined,
                        judul: 'Hasil laboratorium',
                        keterangan: 'Panel lab, analit, dan tren nilainya',
                        tujuan: '/kesehatan/lab',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_gejala',
                        ikon: Icons.healing_outlined,
                        judul: 'Catatan gejala',
                        keterangan: 'Gejala + frekuensinya dari waktu ke waktu',
                        tujuan: '/kesehatan/gejala',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_imunisasi',
                        ikon: Icons.vaccines_outlined,
                        judul: 'Imunisasi',
                        keterangan: 'Rekaman vaksin per anggota keluarga',
                        tujuan: '/kesehatan/imunisasi',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_tumbuh_kembang',
                        ikon: Icons.straighten_outlined,
                        judul: 'Tumbuh kembang',
                        keterangan: 'Berat, tinggi, lingkar kepala anak',
                        tujuan: '/kesehatan/tumbuh-kembang',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_profil_kesehatan_hub',
                        ikon: Icons.emergency_outlined,
                        judul: 'Profil kesehatan & kartu darurat',
                        keterangan: 'Golongan darah, alergi, kontak darurat',
                        tujuan: '/kesehatan/profil-kesehatan',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Halaman ini hanya menampilkan angka yang Anda catat '
                    'sendiri beserta perubahannya.',
                    style: tema.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('segarkan_kesehatan'),
        onPressed: _muat,
        icon: const Icon(Icons.refresh),
        label: const Text('Segarkan'),
      ),
    );
  }

  /// Berapa dari enam angka terpantau yang punya catatan terbaru. Dipakai
  /// sebagai kalimat pembuka supaya pengguna tahu keadaan sebelum menggulir.
  static const _jumlahBagian = 6;

  String _kalimatRingkas() {
    var ada = 0;
    if (_berat != null) ada++;
    if (_tekanan != null) ada++;
    if (_aktivitas?.adaCatatan ?? false) ada++;
    if (_tidur?.rataRata7HariMenit != null) ada++;
    if (_air?.adaCatatan ?? false) ada++;
    if (_obat?.adaJadwal ?? false) ada++;
    if (ada == 0) {
      return 'Belum ada catatan yang bisa diringkas';
    }
    return '$ada dari $_jumlahBagian angka terpantau sudah punya catatan terbaru';
  }

  /// Bilah air hari ini — hanya muncul kalau target air memang diisi.
  Widget? _anakRingkas() {
    final air = _air;
    if (air == null || !air.adaCatatan || air.targetMl <= 0) return null;
    final tema = Theme.of(context);
    final rasio = air.totalMl / air.targetMl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BilahProgres(rasio, tinggi: 6),
        const SizedBox(height: 7),
        Text(
          '${(rasio * 100).round()}% target air hari ini',
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onPrimaryContainer.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }

  Widget _kartu({
    required String kunci,
    required IconData ikon,
    required String judul,
    required String isi,
    Widget? tambahan,
  }) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KartuEditorial(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ikon, size: 20, color: tema.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    judul,
                    style: tema.textTheme.labelMedium
                        ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isi,
              key: Key(kunci),
              style: tema.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            ?tambahan,
          ],
        ),
      ),
    );
  }

  Widget _pintu({
    required String kunci,
    required IconData ikon,
    required String judul,
    required String keterangan,
    required String tujuan,
  }) =>
      ListTile(
        key: Key(kunci),
        leading: Icon(ikon),
        title: Text(judul),
        subtitle: Text(keterangan),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(tujuan),
      );
}
