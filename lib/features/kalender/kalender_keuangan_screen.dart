/// Layar "Kalender Keuangan" (FR-73) - satu layar yang menunjukkan SEMUA
/// kewajiban uang pada tiap tanggal dalam satu bulan.
///
/// Layar ini **hanya membaca**: sumber datanya modul lain (tagihan, langganan,
/// angsuran utang, pengeluaran terencana, dokumen, transaksi) dan semuanya
/// dipanggil lewat [KalenderKeuanganRepository]. Tidak ada penambahan atau
/// pengubahan data dari layar ini, dan tidak ada pengingat baru yang dibuat.
///
/// Layar punya Scaffold + AppBar sendiri (tidak dibungkus HalamanJudul).
/// Waktu dibaca lewat [jamSekarang] (bila diisi) atau `waktuSekarang()`,
/// sehingga pengujian dapat mengunci tanggal "hari ini".
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/kalender_keuangan/peristiwa_keuangan.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';
import '../../core/utils/waktu.dart';
import '../../data/repository/kalender_keuangan_repository.dart';

/// Warna penanda tiap jenis peristiwa (dipakai titik di sel tanggal dan
/// keterangan warna di bawah kalender).
Color warnaJenisPeristiwa(JenisPeristiwa jenis) => switch (jenis) {
      JenisPeristiwa.tagihan => const Color(0xFFD32F2F),
      JenisPeristiwa.angsuran => const Color(0xFF1976D2),
      JenisPeristiwa.langganan => const Color(0xFFF57C00),
      JenisPeristiwa.pengeluaranTerencana => const Color(0xFF7B1FA2),
      JenisPeristiwa.jatuhTempoTerlewat => const Color(0xFF8E0000),
      JenisPeristiwa.dokumen => const Color(0xFF00796B),
      JenisPeristiwa.transaksi => const Color(0xFF388E3C),
    };

/// Nama hari singkat, mulai Senin (kolom pertama grid).
const List<String> namaHariGrid = <String>[
  'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min',
];

class KalenderKeuanganScreen extends ConsumerStatefulWidget {
  const KalenderKeuanganScreen({super.key, this.jamSekarang});

  /// Sumber waktu uji; bila kosong memakai `waktuSekarang()`.
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<KalenderKeuanganScreen> createState() =>
      _KalenderKeuanganScreenState();
}

class _KalenderKeuanganScreenState
    extends ConsumerState<KalenderKeuanganScreen> {
  late KalenderKeuanganRepository _repo;
  late DateTime _bulan;
  DateTime? _pilih;

  bool _memuat = true;
  List<PeristiwaKeuangan> _peristiwa = const <PeristiwaKeuangan>[];
  List<String> _sumberDilewati = const <String>[];

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    final n = _sekarang;
    _bulan = DateTime(n.year, n.month);
    _pilih = DateTime(n.year, n.month, n.day);
    _repo = KalenderKeuanganRepository(
      ref.read(databaseProvider),
      jamSekarang: widget.jamSekarang,
    );
    _muat();
  }

  /// Baca ulang seluruh peristiwa bulan yang sedang ditampilkan.
  Future<void> _muat() async {
    setState(() => _memuat = true);
    List<PeristiwaKeuangan> hasil = const <PeristiwaKeuangan>[];
    List<String> lewat = const <String>[];
    try {
      hasil = await _repo.bulan(_bulan.year, _bulan.month);
      lewat = List<String>.of(_repo.sumberDilewati);
    } catch (e) {
      // Repositori sudah melewati sumber yang bermasalah satu per satu; sampai
      // di sini berarti pembacaan seluruhnya tidak bisa dilanjutkan.
      hasil = const <PeristiwaKeuangan>[];
      lewat = const <String>['seluruh sumber'];
    }
    if (!mounted) return;
    setState(() {
      _peristiwa = hasil;
      _sumberDilewati = lewat;
      _memuat = false;
    });
  }

  void _ubahBulan(int geser) {
    setState(() {
      _bulan = DateTime(_bulan.year, _bulan.month + geser);
      _pilih = null;
    });
    _muat();
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final ringkasan =
        ringkasBulan(_peristiwa, _bulan.month, _bulan.year);
    final perTanggal = kelompokPerTanggal(_peristiwa);
    final hariTerpilih = _pilih;
    final daftarHari = hariTerpilih == null
        ? const <PeristiwaKeuangan>[]
        : (perTanggal[hariSaja(hariTerpilih)] ?? const <PeristiwaKeuangan>[]);

    return Scaffold(
      appBar: AppBar(title: const Text('Kalender Keuangan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _kepalaBulan(ringkasan),
            if (_memuat) const LinearProgressIndicator(minHeight: 2),
            _gridBulan(skema, perTanggal),
            _ringkasanBulan(skema, ringkasan),
            if (_sumberDilewati.isNotEmpty) _catatanSumber(skema),
            const Divider(height: 1),
            _daftarHari(skema, hariTerpilih, daftarHari),
            const Divider(height: 1),
            _legenda(skema),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Kepala: pemilih bulan
  // -------------------------------------------------------------------------

  Widget _kepalaBulan(RingkasanKalenderKeuangan ringkasan) {
    final skema = Theme.of(context).colorScheme;
    final kedua = DateTime(_bulan.year, _bulan.month + 1, 0).day;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('bulan_sebelum'),
            tooltip: 'Bulan sebelumnya',
            onPressed: () => _ubahBulan(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  fmtBulanId(_bulan),
                  key: const Key('label_bulan'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${ringkasan.jumlahPeristiwa} peristiwa · $kedua hari',
                  style: TextStyle(fontSize: 12, color: skema.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('bulan_berikut'),
            tooltip: 'Bulan berikutnya',
            onPressed: () => _ubahBulan(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Grid bulan (7 kolom, Senin..Minggu)
  // -------------------------------------------------------------------------

  Widget _gridBulan(
    ColorScheme skema,
    Map<DateTime, List<PeristiwaKeuangan>> perTanggal,
  ) {
    final pertama = DateTime(_bulan.year, _bulan.month, 1);
    final kedua = DateTime(_bulan.year, _bulan.month + 1, 0).day;
    final offset = pertama.weekday - 1; // Senin = 1
    final sel = <Widget>[
      for (final h in namaHariGrid)
        Center(
          child: Text(
            h,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: skema.onSurfaceVariant,
            ),
          ),
        ),
      for (var i = 0; i < offset; i++) const SizedBox.shrink(),
      for (var hari = 1; hari <= kedua; hari++)
        _selTanggal(
          DateTime(_bulan.year, _bulan.month, hari),
          perTanggal[DateTime(_bulan.year, _bulan.month, hari)] ??
              const <PeristiwaKeuangan>[],
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.92,
        children: sel,
      ),
    );
  }

  Widget _selTanggal(DateTime hari, List<PeristiwaKeuangan> daftar) {
    final skema = Theme.of(context).colorScheme;
    final kunci = kunciTanggal(hari);
    final hariIni = samaHari(_sekarang, hari);
    final terpilih = _pilih != null && samaHari(_pilih!, hari);
    final jenisUnik = <JenisPeristiwa>[];
    for (final p in daftar) {
      if (!jenisUnik.contains(p.jenis)) jenisUnik.add(p.jenis);
    }

    return InkWell(
      key: Key('sel_$kunci'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _pilih = hari),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: terpilih ? skema.primaryContainer : null,
          border: terpilih ? Border.all(color: skema.primary) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              // Penanda hari ini: lingkaran di sekeliling angka tanggal.
              key: hariIni ? const Key('hari_ini') : null,
              padding: const EdgeInsets.all(3),
              decoration: hariIni
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: skema.primary, width: 2),
                    )
                  : null,
              child: Text(
                '${hari.day}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight:
                      terpilih || hariIni ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 2),
            if (jenisUnik.isEmpty)
              const SizedBox(height: 6)
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final j in jenisUnik.take(4))
                    Container(
                      key: Key('titik_${kunci}_${j.name}'),
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: warnaJenisPeristiwa(j),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Ringkasan bulan
  // -------------------------------------------------------------------------

  Widget _ringkasanBulan(ColorScheme skema, RingkasanKalenderKeuangan r) {
    Widget angka(String kunci, String judul, String isi) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: skema.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(judul,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11, color: skema.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  isi,
                  key: Key(kunci),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        );

    // Keadaan kosong ditulis apa adanya, bukan angka nol yang menyesatkan.
    final kosong = r.kosong;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      child: Row(
        children: [
          angka('total_keluar', 'Total keluar',
              kosong ? 'Belum ada data' : fmtRpDariSen(r.totalKeluarSen)),
          angka('total_terlewat', 'Terlewat',
              kosong ? 'Belum ada data' : fmtRpDariSen(r.totalTerlewatSen)),
          angka('total_masuk', 'Total masuk',
              kosong ? 'Belum ada data' : fmtRpDariSen(r.totalMasukSen)),
        ],
      ),
    );
  }

  /// Catatan sumber yang belum bisa dibaca pada bulan ini.
  ///
  /// Hanya nama sumber yang ditampilkan (tanpa pesan galat mentah), supaya
  /// kalimatnya tetap tenang dan tidak memuat istilah teknis.
  Widget _catatanSumber(ColorScheme skema) {
    final nama = <String>[];
    for (final s in _sumberDilewati) {
      final pisah = s.indexOf(':');
      final bersih = (pisah < 0 ? s : s.substring(0, pisah)).trim();
      if (bersih.isNotEmpty && !nama.contains(bersih)) nama.add(bersih);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Text(
        'Sumber yang belum terbaca bulan ini: ${nama.join(', ')}. '
        'Tanggal dari sumber lain tetap ditampilkan.',
        key: const Key('sumber_dilewati'),
        style: TextStyle(fontSize: 11.5, color: skema.onSurfaceVariant),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Daftar peristiwa satu tanggal
  // -------------------------------------------------------------------------

  Widget _daftarHari(
    ColorScheme skema,
    DateTime? hariTerpilih,
    List<PeristiwaKeuangan> daftar,
  ) {
    return Padding(
      key: const Key('daftar_hari'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hariTerpilih == null
                ? 'Pilih satu tanggal untuk melihat peristiwanya.'
                : fmtTanggalPendekAman(hariTerpilih),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          if (hariTerpilih == null)
            const SizedBox.shrink()
          else if (daftar.isEmpty)
            Text(
              'Belum ada peristiwa pada tanggal ini.',
              key: const Key('kosong_hari'),
              style: TextStyle(fontSize: 12.5, color: skema.onSurfaceVariant),
            )
          else
            for (final p in daftar) _barisPeristiwa(skema, p),
        ],
      ),
    );
  }

  Widget _barisPeristiwa(ColorScheme skema, PeristiwaKeuangan p) {
    final terlewat = p.jenis == JenisPeristiwa.jatuhTempoTerlewat;
    final keterangan = terlewat
        ? 'Tanggal sudah lewat'
        : (p.sudahTerjadi ? 'Sudah terjadi' : 'Belum terjadi');
    return Padding(
      key: Key('peristiwa_${p.rujukan ?? p.judul}_${kunciTanggal(p.tanggal)}'),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(top: 4, right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: warnaJenisPeristiwa(p.jenis),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.judul, style: const TextStyle(fontSize: 13.5)),
                Text(
                  '${p.jenis.label} · $keterangan',
                  style: TextStyle(
                      fontSize: 11.5, color: skema.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            p.nominalSen == 0 ? 'Tanpa nominal' : fmtRpDariSen(p.nominalAbsSen),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: p.nominalSen == 0 ? skema.onSurfaceVariant : null,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Keterangan warna
  // -------------------------------------------------------------------------

  Widget _legenda(ColorScheme skema) {
    return Padding(
      key: const Key('legenda_jenis'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keterangan jenis',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: skema.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final j in JenisPeristiwa.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: warnaJenisPeristiwa(j),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(j.label, style: const TextStyle(fontSize: 11.5)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
