/// Layar Anggaran vs realisasi per kategori (FR-72).
///
/// Kriteria terima PRD: menampilkan "Anggaran / Terpakai / Selisih (%)" untuk
/// setiap kategori, dengan peringatan pada 80% (kuning) dan 100% (merah).
/// Nada kalimat membantu dan menyebut angka pengguna sendiri — tidak menilai
/// orang (PRD §III-11).
///
/// Semua angka Rupiah lewat `fmtRpDariSen` (lib/core/utils/uang_utils.dart),
/// dan "sekarang" lewat parameter [AnggaranScreen.jamSekarang] supaya uji bisa
/// mengunci bulan berjalan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// `hide kunciBulan`: nama itu juga ada di app_providers.dart; versi yang
// dipakai di sini adalah milik lib/data/repository/periode.dart.
import '../../../core/providers/app_providers.dart' hide kunciBulan;
import '../../../core/utils/tanggal_utils.dart';
import '../../../core/utils/uang_utils.dart';
import '../../../core/utils/waktu.dart';
import '../../../data/database/database.dart';
import '../../../data/model/enums.dart';
import '../../../data/repository/anggaran_repository.dart';
import '../../../data/repository/kategori_transaksi_repository.dart';
import '../../../data/repository/periode.dart';
import '../../../data/repository/transaksi_repository.dart';
import 'bilah_anggaran.dart';
import 'form_anggaran_screen.dart';

/// Repositori dipakai layar ini (dibuat dari `databaseProvider` yang sudah ada).
final anggaranRepoProvider = Provider<AnggaranRepository>(
    (ref) => AnggaranRepository(ref.watch(databaseProvider)));

final kategoriTransaksiRepoProvider = Provider<KategoriTransaksiRepository>(
    (ref) => KategoriTransaksiRepository(ref.watch(databaseProvider)));

final transaksiRepoProvider = Provider<TransaksiRepository>(
    (ref) => TransaksiRepository(ref.watch(databaseProvider)));

/// Satu baris daftar anggaran: satu kategori pengeluaran ATAU baris total bulan.
class BarisAnggaran {
  const BarisAnggaran({
    required this.kategoriId,
    required this.nama,
    required this.realisasi,
    this.anggaranId,
  });

  final int kategoriId;
  final String nama;

  /// id baris `anggaran_bulanan`; null = kategori ini belum punya anggaran.
  final int? anggaranId;
  final RealisasiAnggaran realisasi;

  bool get punyaAnggaran => anggaranId != null;

  /// true = pemakaian sudah menyentuh ambang 80% atau 100%.
  bool get adaPeringatan => realisasi.status != StatusAnggaran.aman;
}

/// Hasil pemuatan satu periode.
class DataAnggaran {
  const DataAnggaran({required this.baris, required this.jumlahPeringatan});

  final List<BarisAnggaran> baris;

  /// Jumlah baris yang menyentuh ambang (bahan kalimat ringkas di layar).
  final int jumlahPeringatan;
}

/// Susun daftar tampilan dari data mentah — PURE, bisa diuji tanpa database.
///
/// Aturan:
/// 1. baris TOTAL bulan (kategoriId 0) selalu paling atas;
/// 2. satu baris untuk SETIAP kategori pengeluaran, termasuk yang belum punya
///    anggaran (batas 0, persen null) — kategori tanpa anggaran tidak hilang;
/// 3. anggaran milik kategori yang tidak ada di daftar (mis. sudah diarsipkan)
///    tetap ditampilkan supaya angkanya tidak "raib" diam-diam.
///
/// [terpakaiPerKategori] = realisasi pengeluaran per kategori bulan itu, dan
/// [totalPengeluaranSen] = seluruh pengeluaran bulan itu (termasuk transaksi
/// tanpa kategori) — sama seperti perhitungan di [AnggaranRepository.realisasi].
List<BarisAnggaran> susunBarisAnggaran({
  required List<KategoriTransaksiData> kategori,
  required List<AnggaranBulananData> barisAnggaran,
  required List<RealisasiAnggaran> realisasi,
  required Map<int, int> terpakaiPerKategori,
  required int totalPengeluaranSen,
}) {
  final petaAnggaran = {
    for (final a in barisAnggaran) a.kategoriId: a,
  };
  final petaRealisasi = {
    for (final r in realisasi) r.kategoriId: r,
  };

  // Baris dari repository dipakai apa adanya (satu sumber aturan 80%/100%);
  // kalau kategori belum punya anggaran, barisnya dibentuk dengan batas 0.
  RealisasiAnggaran dasar(int kategoriId, String nama, int terpakaiSen) {
    final sudah = petaRealisasi[kategoriId];
    if (sudah != null) return sudah;
    final a = petaAnggaran[kategoriId];
    return RealisasiAnggaran(
      kategoriId: kategoriId,
      nama: nama,
      batasSen: a?.batasSen ?? 0,
      terpakaiSen: terpakaiSen,
      ambang: a == null ? ambangAnggaranBawaan : teksKeAmbang(a.ambangPeringatan),
    );
  }

  final hasil = <BarisAnggaran>[
    BarisAnggaran(
      kategoriId: AnggaranRepository.kategoriTotal,
      nama: 'Total bulan',
      anggaranId: petaAnggaran[AnggaranRepository.kategoriTotal]?.id,
      realisasi: dasar(AnggaranRepository.kategoriTotal, 'Total bulan',
          totalPengeluaranSen),
    ),
    for (final k in kategori)
      BarisAnggaran(
        kategoriId: k.id,
        nama: k.nama,
        anggaranId: petaAnggaran[k.id]?.id,
        realisasi: dasar(k.id, k.nama, terpakaiPerKategori[k.id] ?? 0),
      ),
  ];

  final idTampil = {for (final b in hasil) b.kategoriId};
  for (final a in barisAnggaran) {
    if (idTampil.contains(a.kategoriId)) continue;
    final nama = petaRealisasi[a.kategoriId]?.nama ?? 'Kategori #${a.kategoriId}';
    hasil.add(BarisAnggaran(
      kategoriId: a.kategoriId,
      nama: nama,
      anggaranId: a.id,
      realisasi: dasar(a.kategoriId, nama, terpakaiPerKategori[a.kategoriId] ?? 0),
    ));
  }
  return hasil;
}

class AnggaranScreen extends ConsumerStatefulWidget {
  const AnggaranScreen({super.key, this.jamSekarang});

  /// Sumber waktu yang bisa disuntik uji (pola sama dengan layar lain).
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<AnggaranScreen> createState() => _AnggaranScreenState();
}

class _AnggaranScreenState extends ConsumerState<AnggaranScreen> {
  late String _periode;
  late Future<DataAnggaran> _masaDepan;

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _periode = kunciBulan(_sekarang);
    _masaDepan = _muat();
  }

  Future<DataAnggaran> _muat() async {
    final bulan = bulanDariKunci(_periode);
    if (bulan == null) {
      throw ArgumentError('Periode tidak sah: $_periode');
    }
    final repo = ref.read(anggaranRepoProvider);
    final total = await ref
        .read(transaksiRepoProvider)
        .totalPerKategori(bulan, jenis: JenisArus.pengeluaran);
    final kategori = await ref
        .read(kategoriTransaksiRepoProvider)
        .ambilSemua(jenis: JenisArus.pengeluaran);
    final barisAnggaran = await repo.ambilPeriode(_periode);
    final realisasi = await repo.realisasi(_periode);
    final peringatan = await repo.peringatan(_periode);

    return DataAnggaran(
      baris: susunBarisAnggaran(
        kategori: kategori,
        barisAnggaran: barisAnggaran,
        realisasi: realisasi,
        terpakaiPerKategori: {
          for (final t in total)
            if (t.kategoriId != null) t.kategoriId!: t.totalSen,
        },
        totalPengeluaranSen: total.fold<int>(0, (a, b) => a + b.totalSen),
      ),
      jumlahPeringatan: peringatan.length,
    );
  }

  void _geserBulan(int delta) {
    final bulan = bulanDariKunci(_periode);
    if (bulan == null) return;
    setState(() {
      _periode = kunciBulan(DateTime(bulan.year, bulan.month + delta, 1));
      _masaDepan = _muat();
    });
  }

  void _keBulanIni() {
    setState(() {
      _periode = kunciBulan(_sekarang);
      _masaDepan = _muat();
    });
  }

  /// Buka form atur/ubah untuk satu kategori (0 = baris total bulan).
  Future<void> _bukaForm(int kategoriId) async {
    final hasil = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormAnggaranScreen(
          periode: _periode,
          kategoriId: kategoriId,
        ),
      ),
    );
    if (!mounted) return;
    if (hasil == true) {
      // Catatan: badan blok (bukan panah) — panah akan mengembalikan Future
      // dari _muat() dan itu dilarang oleh setState().
      setState(() {
        _masaDepan = _muat();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anggaran bulanan'),
        actions: [
          TextButton(
            key: const Key('ke_bulan_ini'),
            onPressed: _keBulanIni,
            child: const Text('Bulan ini'),
          ),
        ],
      ),
      body: Column(
        children: [
          _pemilihBulan(tema),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<DataAnggaran>(
              future: _masaDepan,
              builder: (c, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Gagal memuat anggaran: ${snap.error}'));
                }
                final data = snap.data!;
                if (data.baris.isEmpty) {
                  return const Center(
                      child: Text('Belum ada kategori pengeluaran.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 90),
                  itemCount: data.baris.length + 1,
                  itemBuilder: (c, i) {
                    if (i == 0) return _ringkasan(tema, data);
                    return _kartuBaris(tema, data.baris[i - 1]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _pemilihBulan(ThemeData tema) {
    final bulan = bulanDariKunci(_periode) ?? DateTime(_sekarang.year, _sekarang.month);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('bulan_sebelum'),
            tooltip: 'Bulan sebelumnya',
            onPressed: () => _geserBulan(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              fmtBulanId(bulan),
              textAlign: TextAlign.center,
              style: tema.textTheme.titleMedium,
            ),
          ),
          IconButton(
            key: const Key('bulan_berikut'),
            tooltip: 'Bulan berikutnya',
            onPressed: () => _geserBulan(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  /// Kalimat ringkas di atas daftar (tanpa menghakimi, hanya menyebut angka).
  Widget _ringkasan(ThemeData tema, DataAnggaran data) {
    if (data.jumlahPeringatan == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(
          'Belum ada baris anggaran yang menyentuh ambang peringatan bulan ini.',
          style: tema.textTheme.bodyMedium,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Card(
        margin: EdgeInsets.zero,
        color: const Color(0xFFFFF8E1),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFF9A825)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${data.jumlahPeringatan} baris anggaran sudah menyentuh '
                  'ambang peringatan bulan ini. Angka Terpakai dan Selisih di '
                  'bawah bisa jadi bahan menyesuaikan pengeluaran berikutnya.',
                  style: tema.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kartuBaris(ThemeData tema, BarisAnggaran b) {
    final r = b.realisasi;
    return Card(
      // Baris total diberi kunci khusus (kategori_id = 0).
      key: b.kategoriId == AnggaranRepository.kategoriTotal
          ? const Key('total_bulan')
          : ValueKey('baris_${b.kategoriId}'),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // Tekan baris = ubah (hanya bila anggarannya sudah ada).
        onTap: b.punyaAnggaran ? () => _bukaForm(b.kategoriId) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(b.nama, style: tema.textTheme.titleMedium),
                  ),
                  if (b.adaPeringatan) _tandaPeringatan(tema, r),
                ],
              ),
              const SizedBox(height: 8),
              BilahAnggaran(realisasi: r, tinggi: 8),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kolom(tema, 'Anggaran',
                      b.punyaAnggaran ? fmtRpDariSen(r.batasSen) : 'Belum diatur'),
                  _kolom(tema, 'Terpakai', fmtRpDariSen(r.terpakaiSen),
                      bawah: r.persen == null ? null : '${r.persen}%'),
                  _kolom(
                    tema,
                    'Selisih',
                    b.punyaAnggaran ? teksSelisihRp(r) : '—',
                    bawah: b.punyaAnggaran && persenSelisih(r) != null
                        ? '${persenSelisih(r)}%'
                        : null,
                  ),
                ],
              ),
              if (!b.punyaAnggaran)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('tambah_anggaran'),
                    onPressed: () => _bukaForm(b.kategoriId),
                    icon: const Icon(Icons.add),
                    label: const Text('Atur anggaran'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kolom(ThemeData tema, String label, String nilai, {String? bawah}) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: tema.textTheme.labelSmall
                    ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(nilai,
                style: tema.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            if (bawah != null)
              Text(bawah, style: tema.textTheme.labelSmall),
          ],
        ),
      );

  /// Tanda peringatan: kuning pada ambang 80%, merah pada ambang 100%.
  Widget _tandaPeringatan(ThemeData tema, RealisasiAnggaran r) {
    if (r.ambang.isEmpty) return const SizedBox.shrink();
    final lewat = r.status == StatusAnggaran.lewat;
    final ambang = lewat ? r.ambang.last : r.ambang.first;
    final warna = warnaStatusAnggaran(r.status);
    return Container(
      key: Key(lewat ? 'peringatan_100' : 'peringatan_80'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warna),
      ),
      child: Text(
        lewat ? 'Melewati batas $ambang%' : 'Mendekati batas $ambang%',
        style: tema.textTheme.labelSmall?.copyWith(
            color: warna, fontWeight: FontWeight.w600),
      ),
    );
  }
}
