/// FR-71 Arus kas — layar daftar transaksi (pemasukan & pengeluaran).
///
/// Kriteria PRD: "Ringkasan bulanan: pemasukan, pengeluaran, arus kas bersih;
/// kategori bisa diubah pengguna."
///
/// Isi layar: pemilih bulan (kunci periode ketat `YYYY-MM` lewat `periode.dart`),
/// kartu ringkasan bulan, daftar transaksi dikelompokkan per hari, total per
/// kategori, tombol tambah, ubah (ketuk baris), hapus (geser atau tahan lama,
/// selalu dengan konfirmasi), dan pintu menuju kelola kategori.
library;

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/tanggal_utils.dart';
import '../../../core/utils/uang_utils.dart';
import '../../../core/utils/waktu.dart';
import '../../../data/database/database.dart';
import '../../../data/model/enums.dart';
import '../../../data/repository/periode.dart' as periode;
import '../../../data/repository/transaksi_repository.dart';
import 'form_transaksi_screen.dart';
import 'kelola_kategori_screen.dart';
import 'warna_ikon_kategori.dart';

// ---------------------------------------------------------------------------
// Provider lokal modul arus kas (dibuat per pemakaian: hanya membungkus db).
// ---------------------------------------------------------------------------

/// Repositori transaksi untuk layar arus kas.
final arusKasRepoProvider = Provider<TransaksiRepository>(
    (ref) => TransaksiRepository(ref.watch(databaseProvider)));

/// Transaksi satu bulan; kunci periode ketat `YYYY-MM` (lihat `periode.dart`).
final arusKasBulanProvider = StreamProvider.autoDispose
    .family<List<TransaksiData>, String>((ref, kunci) {
  final bulan = periode.bulanDariKunci(kunci);
  if (bulan == null) return Stream.value(const <TransaksiData>[]);
  return ref.watch(arusKasRepoProvider).watchBulan(bulan);
});

/// Ringkasan bulan: pemasukan, pengeluaran, arus kas bersih.
final arusKasRingkasanProvider = FutureProvider.autoDispose
    .family<RingkasanArusKas, String>((ref, kunci) async {
  // Ikut dihitung ulang setiap transaksi bulan itu berubah.
  ref.watch(arusKasBulanProvider(kunci));
  final bulan = periode.bulanDariKunci(kunci);
  if (bulan == null) {
    return const RingkasanArusKas(pemasukanSen: 0, pengeluaranSen: 0);
  }
  return ref.watch(arusKasRepoProvider).ringkasanBulan(bulan);
});

/// Semua kategori — termasuk yang disembunyikan, supaya riwayat transaksi lama
/// tetap terbaca namanya.
final arusKasKategoriProvider =
    StreamProvider.autoDispose<List<KategoriTransaksiData>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.kategoriTransaksi)
        ..orderBy([
          (k) => OrderingTerm.asc(k.urutan),
          (k) => OrderingTerm.asc(k.nama),
        ]))
      .watch();
});

/// Warna angka ringkasan: hijau untuk uang masuk, jingga untuk uang keluar.
/// Sengaja bukan merah — nada layar tetap tenang (PRD §III-11).
const Color warnaArusMasuk = Color(0xFF2E7D32);
const Color warnaArusKeluar = Color(0xFFE65100);

/// Layar "Arus Kas" (FR-71).
class DaftarTransaksiScreen extends ConsumerStatefulWidget {
  const DaftarTransaksiScreen({super.key, this.jamSekarang});

  /// Sumber waktu (untuk pengujian); kosong = jam sistem.
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<DaftarTransaksiScreen> createState() =>
      _DaftarTransaksiScreenState();
}

class _DaftarTransaksiScreenState extends ConsumerState<DaftarTransaksiScreen> {
  /// Bulan yang sedang dilihat (selalu tengah malam tanggal 1).
  late DateTime _bulan;

  @override
  void initState() {
    super.initState();
    _bulan = _bulanDariJam(_jamSekarang());
  }

  DateTime _jamSekarang() => widget.jamSekarang?.call() ?? waktuSekarang();

  /// Bulan dari sebuah waktu — selalu lewat kunci `YYYY-MM` supaya bentuknya
  /// sah menurut `periode.dart` (bukan dihitung manual).
  static DateTime _bulanDariJam(DateTime waktu) =>
      periode.bulanDariKunci(periode.kunciBulan(waktu)) ??
      DateTime(waktu.year, waktu.month);

  /// Mundur/maju satu bulan. Kunci periode ketat: `YYYY-MM` (dua angka),
  /// supaya tidak ada dua kunci berbeda untuk bulan yang sama.
  void _geserBulan(int langkah) {
    final kunci = periode.kunciBulan(_bulan);
    final kunciBaru = langkah > 0
        ? periode.kunciBulanBerikutnya(kunci)
        : periode.kunciBulan(DateTime(_bulan.year, _bulan.month - 1, 1));
    final bulan = periode.bulanDariKunci(kunciBaru);
    if (bulan == null) return; // penjaga: tidak mungkin terjadi
    setState(() => _bulan = bulan);
  }

  Future<void> _bukaForm({TransaksiData? transaksi}) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
      builder: (_) => FormTransaksiScreen(
        id: transaksi?.id,
        jamSekarang: widget.jamSekarang,
      ),
    ));
  }

  Future<void> _bukaKelolaKategori() async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => const KelolaKategoriScreen(),
    ));
  }

  /// Geser atau tahan lama sebuah baris: tanya dulu, baru hapus.
  ///
  /// Selalu mengembalikan `false` supaya baris hilang lewat pembaruan data
  /// (stream), bukan lewat animasi Dismissible — cara ini tidak memicu galat
  /// "dismissed widget masih ada di pohon" saat data belum sempat menyusul.
  Future<bool> _tanyaLaluHapus(TransaksiData t, String namaKategori) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus transaksi ini?'),
        content: Text('$namaKategori · ${fmtRpDariSen(t.jumlahSen)}\n'
            'Transaksi yang dihapus tidak bisa dikembalikan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (yakin != true || !mounted) return false;
    await ref.read(arusKasRepoProvider).hapus(t.id);
    if (!mounted) return false;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Transaksi dihapus.')));
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final kunci = periode.kunciBulan(_bulan);
    final daftar = ref.watch(arusKasBulanProvider(kunci));
    final ringkasan = ref.watch(arusKasRingkasanProvider(kunci));
    final kategori = <int, KategoriTransaksiData>{
      for (final k in ref.watch(arusKasKategoriProvider).value ??
          const <KategoriTransaksiData>[])
        k.id: k,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arus Kas'),
        actions: [
          TextButton.icon(
            key: const Key('pilih_kategori'),
            onPressed: _bukaKelolaKategori,
            icon: const Icon(Icons.category_outlined),
            label: const Text('Kategori'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tambah_transaksi'),
        onPressed: () => _bukaForm(),
        icon: const Icon(Icons.add),
        label: const Text('Transaksi'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          _pemilihBulan(tema),
          const SizedBox(height: 8),
          _kartuRingkasan(tema, ringkasan.value),
          const SizedBox(height: 12),
          ..._isiBulan(tema, daftar, kategori),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Bagian-bagian layar
  // -------------------------------------------------------------------------

  Widget _pemilihBulan(ThemeData tema) => Row(
        children: [
          IconButton(
            key: const Key('bulan_sebelumnya'),
            tooltip: 'Bulan sebelumnya',
            onPressed: () => _geserBulan(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(fmtBulanId(_bulan),
                  style: tema.textTheme.titleMedium),
            ),
          ),
          IconButton(
            key: const Key('bulan_berikutnya'),
            tooltip: 'Bulan berikutnya',
            onPressed: () => _geserBulan(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      );

  Widget _kartuRingkasan(ThemeData tema, RingkasanArusKas? angka) {
    final masuk = angka?.pemasukanSen ?? 0;
    final keluar = angka?.pengeluaranSen ?? 0;
    final bersih = masuk - keluar;
    return Card(
      key: const Key('ringkasan_arus_kas'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ringkasan ${fmtBulanId(_bulan)}',
                style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            _barisAngka('Pemasukan', fmtRpDariSen(masuk),
                Icons.south_west, warnaArusMasuk),
            const SizedBox(height: 4),
            _barisAngka('Pengeluaran', fmtRpDariSen(keluar),
                Icons.north_east, warnaArusKeluar),
            const Divider(height: 16),
            _barisAngka(
                'Arus kas bersih',
                fmtRpDariSen(bersih),
                bersih < 0
                    ? Icons.trending_down_outlined
                    : Icons.trending_up_outlined,
                tema.colorScheme.primary,
                tebal: true),
            const SizedBox(height: 6),
            Text('Angka dihitung dari transaksi bulan ini saja.',
                style: tema.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _barisAngka(
    String label,
    String nilai,
    IconData ikon,
    Color warna, {
    bool tebal = false,
  }) =>
      Row(
        children: [
          Icon(ikon, size: 18, color: warna),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            nilai,
            style: TextStyle(
              color: warna,
              fontWeight: tebal ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      );

  List<Widget> _isiBulan(
    ThemeData tema,
    AsyncValue<List<TransaksiData>> daftar,
    Map<int, KategoriTransaksiData> kategori,
  ) {
    if (daftar.hasError) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text('Data transaksi tidak bisa dibaca: ${daftar.error}'),
        ),
      ];
    }
    if (!daftar.hasValue) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    final semua = daftar.value ?? const <TransaksiData>[];
    if (semua.isEmpty) return [_keadaanKosong(tema)];

    // Kelompokkan per hari (urut terbaru dulu; isi mengikuti urutan repository).
    final perHari = <DateTime, List<TransaksiData>>{};
    for (final t in semua) {
      final hari = DateTime(t.tanggal.year, t.tanggal.month, t.tanggal.day);
      perHari.putIfAbsent(hari, () => <TransaksiData>[]).add(t);
    }
    final hariUrut = perHari.keys.toList()..sort((a, b) => b.compareTo(a));

    return [
      for (final hari in hariUrut) ...[
        _kepalaHari(tema, hari, perHari[hari]!),
        for (final t in perHari[hari]!) _barisTransaksi(t, kategori),
        const SizedBox(height: 4),
      ],
      _kartuTotalKategori(tema, semua, kategori),
    ];
  }

  Widget _keadaanKosong(ThemeData tema) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 40, color: tema.colorScheme.outline),
              const SizedBox(height: 8),
              const Text('Belum ada transaksi di bulan ini.'),
              const SizedBox(height: 4),
              Text('Tekan tombol "Transaksi" untuk mencatat pemasukan '
                  'atau pengeluaran.'),
            ],
          ),
        ),
      );

  Widget _kepalaHari(ThemeData tema, DateTime hari, List<TransaksiData> isi) {
    var bersih = 0;
    for (final t in isi) {
      bersih += JenisArus.dariDb(t.jenis).tanda * t.jumlahSen;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(fmtTanggalPendek(hari),
                style: tema.textTheme.titleSmall),
          ),
          Text('Selisih hari ini: ${fmtRpDariSen(bersih)}',
              style: tema.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _barisTransaksi(
      TransaksiData t, Map<int, KategoriTransaksiData> kategori) {
    final jenis = JenisArus.dariDb(t.jenis);
    final k = t.kategoriId == null ? null : kategori[t.kategoriId];
    final namaKategori = k?.nama ?? 'Tanpa kategori';
    final warna = warnaKategori(k?.warna);
    final catatan = t.catatan?.trim() ?? '';
    final judul = catatan.isEmpty ? namaKategori : catatan;
    final tanda = jenis == JenisArus.pemasukan ? '+ ' : '- ';
    final warnaAngka =
        jenis == JenisArus.pemasukan ? warnaArusMasuk : warnaArusKeluar;

    return Dismissible(
      key: ValueKey('trx_${t.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline),
      ),
      confirmDismiss: (_) => _tanyaLaluHapus(t, namaKategori),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: warna.withValues(alpha: 0.15),
            child: Icon(ikonKategori(k?.ikon), color: warna, size: 20),
          ),
          title: Text(judul),
          subtitle: Text('$namaKategori · ${jenis.label}'),
          trailing: Text(
            '$tanda${fmtRpDariSen(t.jumlahSen)}',
            style: TextStyle(color: warnaAngka, fontWeight: FontWeight.w600),
          ),
          onTap: () => _bukaForm(transaksi: t),
          onLongPress: () => _tanyaLaluHapus(t, namaKategori),
        ),
      ),
    );
  }

  Widget _kartuTotalKategori(
    ThemeData tema,
    List<TransaksiData> semua,
    Map<int, KategoriTransaksiData> kategori,
  ) {
    final blok = <Widget>[];
    for (final jenis in JenisArus.values) {
      final total = <int?, int>{};
      for (final t in semua) {
        if (JenisArus.dariDb(t.jenis) != jenis) continue;
        total.update(t.kategoriId, (v) => v + t.jumlahSen,
            ifAbsent: () => t.jumlahSen);
      }
      if (total.isEmpty) continue;
      final urut = total.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      blok.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text('Total ${jenis.label} per kategori',
            style: tema.textTheme.titleSmall),
      ));
      for (final e in urut) {
        final k = e.key == null ? null : kategori[e.key];
        blok.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(ikonKategori(k?.ikon), size: 16, color: warnaKategori(k?.warna)),
              const SizedBox(width: 8),
              Expanded(child: Text(k?.nama ?? 'Tanpa kategori')),
              Text(fmtRpDariSen(e.value)),
            ],
          ),
        ));
      }
    }
    if (blok.isEmpty) return const SizedBox.shrink();
    return Card(
      key: const Key('total_per_kategori'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: blok,
        ),
      ),
    );
  }
}
