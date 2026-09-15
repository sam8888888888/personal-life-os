/// Layar Pelacak kekayaan bersih (FR-76).
///
/// Kriteria terima PRD:
/// * nilai bersih = aset - kewajiban (dihitung `AsetRepository.nilaiBersih`,
///   angka per bulan tidak disimpan supaya tidak ada dua angka yang berbeda),
/// * grafik menyimpan riwayat bulanan dan tidak berubah retroaktif — karena
///   itu bulan lampau terkunci, dan memperbaikinya wajib memakai alasan.
///
/// Layar menerima [jamSekarang] seperti layar lain di `lib/features` supaya
/// pengujian dapat mengunci "bulan berjalan". Nilai per baris dihitung dari
/// baris bulanan terakhir yang <= bulan yang dilihat, atau nilai awal aset /
/// saldo awal kewajiban bila belum ada catatan bulanan.
library;

// `Column` milik drift disembunyikan supaya tidak bentrok dengan widget
// `Column` milik Flutter.
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// `kunciBulan` diambil dari data/repository/periode.dart (versi DateTime),
// jadi versi milik app_providers disembunyikan supaya tidak ambigu.
import '../../../core/providers/app_providers.dart' hide kunciBulan;
import '../../../core/utils/uang_utils.dart';
import '../../../core/utils/waktu.dart';
import '../../../data/database/database.dart';
import '../../../data/model/enums.dart';
import '../../../data/repository/aset_repository.dart';
import '../../../data/repository/periode.dart';
import 'form_aset_screen.dart';
import 'form_kewajiban_screen.dart';
import 'grafik_tren_kekayaan.dart';

/// Jumlah bulan yang digambar pada grafik (bulan terpilih + 5 bulan sebelum).
const int _bulanGrafik = 6;

class KekayaanScreen extends ConsumerStatefulWidget {
  const KekayaanScreen({super.key, this.jamSekarang});

  /// Jam uji; dianggap waktu perangkat.
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<KekayaanScreen> createState() => _KekayaanScreenState();
}

class _KekayaanScreenState extends ConsumerState<KekayaanScreen> {
  late final AsetRepository _repo = AsetRepository(
    ref.read(databaseProvider),
    jamSekarang: widget.jamSekarang,
  );

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();
  String get _bulanSekarang => kunciBulan(_sekarang);

  late String _bulan = _bulanSekarang;

  bool _memuat = true;
  String? _galat;
  NilaiBersih? _nilai;
  List<AsetData> _aset = const [];
  List<AsetData> _asetArsip = const [];
  List<KewajibanData> _kewajiban = const [];
  List<KewajibanData> _kewajibanArsip = const [];

  /// Nilai yang berlaku per baris pada [_bulan] (aset / kewajiban).
  Map<int, int> _nilaiAset = const {};
  Map<int, int> _nilaiKewajiban = const {};
  List<NilaiBersih> _tren = const [];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final db = ref.read(databaseProvider);
      final semuaAset = await _repo.ambilAset(sertakanArsip: true);
      final semuaKewajiban = await _repo.ambilKewajiban(sertakanArsip: true);
      final aset = semuaAset.where((a) => !a.arsip).toList(growable: false);
      final kewajiban =
          semuaKewajiban.where((k) => !k.arsip).toList(growable: false);
      final nilai = await _repo.nilaiBersih(_bulan);
      final nilaiAset = await _nilaiBerlakuAset(db, aset, _bulan);
      final nilaiKewajiban = await _nilaiBerlakuKewajiban(db, kewajiban, _bulan);
      final tren = await _repo.tren(
        dari: _bulanAwalGrafik(_bulan),
        sampai: _bulan,
      );
      if (!mounted) return;
      setState(() {
        _aset = aset;
        _asetArsip = semuaAset.where((a) => a.arsip).toList(growable: false);
        _kewajiban = kewajiban;
        _kewajibanArsip =
            semuaKewajiban.where((k) => k.arsip).toList(growable: false);
        _nilaiAset = nilaiAset;
        _nilaiKewajiban = nilaiKewajiban;
        _nilai = nilai;
        _tren = tren;
        _memuat = false;
        _galat = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _galat = '$e';
      });
    }
  }

  /// Bulan awal grafik: [_bulanGrafik] bulan terakhir sampai bulan terpilih.
  String _bulanAwalGrafik(String bulan) {
    final b = bulanDariKunci(bulan) ?? _sekarang;
    return kunciBulan(DateTime(b.year, b.month - (_bulanGrafik - 1), 1));
  }

  /// Nilai tiap aset yang berlaku pada [bulan]: baris bulanan terakhir yang
  /// <= bulan itu (diurut menaik, baris terakhir menang), atau nilai awal.
  Future<Map<int, int>> _nilaiBerlakuAset(
      AppDatabase db, List<AsetData> daftar, String bulan) async {
    final peta = {for (final a in daftar) a.id: a.nilaiAwalSen};
    final baris = await (db.select(db.nilaiAsetBulanan)
          ..where((n) => n.bulan.isSmallerOrEqualValue(bulan))
          ..orderBy([(n) => OrderingTerm.asc(n.bulan)]))
        .get();
    for (final b in baris) {
      if (peta.containsKey(b.asetId)) peta[b.asetId] = b.nilaiSen;
    }
    return peta;
  }

  /// Seperti [_nilaiBerlakuAset], untuk kewajiban (nilai awal = saldo awal).
  Future<Map<int, int>> _nilaiBerlakuKewajiban(
      AppDatabase db, List<KewajibanData> daftar, String bulan) async {
    final peta = {for (final k in daftar) k.id: k.saldoAwalSen};
    final baris = await (db.select(db.nilaiKewajibanBulanan)
          ..where((n) => n.bulan.isSmallerOrEqualValue(bulan))
          ..orderBy([(n) => OrderingTerm.asc(n.bulan)]))
        .get();
    for (final b in baris) {
      if (peta.containsKey(b.kewajibanId)) peta[b.kewajibanId] = b.nilaiSen;
    }
    return peta;
  }

  // -------------------------------------------------------------------------
  // Aksi
  // -------------------------------------------------------------------------

  void _geserBulan(int delta) {
    final b = bulanDariKunci(_bulan) ?? _sekarang;
    setState(() => _bulan = kunciBulan(DateTime(b.year, b.month + delta, 1)));
    _muat();
  }

  Future<void> _bukaFormAset(AsetData? aset) async {
    final hasil = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) =>
          FormAsetScreen(aset: aset, jamSekarang: widget.jamSekarang),
    ));
    if (hasil == true) await _muat();
  }

  Future<void> _bukaFormKewajiban(KewajibanData? kewajiban) async {
    final hasil = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => FormKewajibanScreen(
          kewajiban: kewajiban, jamSekarang: widget.jamSekarang),
    ));
    if (hasil == true) await _muat();
  }

  Future<void> _aksiAset(AsetData a, String aksi) async {
    switch (aksi) {
      case 'ubah':
        await _bukaFormAset(a);
      case 'arsip':
        await _repo.arsipkanAset(a.id);
        await _muat();
        _pesan('Aset "${a.nama}" diarsipkan. Riwayat nilainya tetap tersimpan.');
      case 'kembalikan':
        await _repo.arsipkanAset(a.id, arsip: false);
        await _muat();
        _pesan('Aset "${a.nama}" kembali ke daftar aktif.');
      case 'hapus':
        await _hapusAset(a);
    }
  }

  Future<void> _aksiKewajiban(KewajibanData k, String aksi) async {
    switch (aksi) {
      case 'ubah':
        await _bukaFormKewajiban(k);
      case 'arsip':
        await _repo.arsipkanKewajiban(k.id);
        await _muat();
        _pesan('Kewajiban "${k.nama}" diarsipkan. Riwayat nilainya tetap ada.');
      case 'kembalikan':
        await _repo.arsipkanKewajiban(k.id, arsip: false);
        await _muat();
        _pesan('Kewajiban "${k.nama}" kembali ke daftar aktif.');
      case 'hapus':
        await _hapusKewajiban(k);
    }
  }

  Future<void> _hapusAset(AsetData a) async {
    final yakin = await _konfirmasiHapus(
      judul: 'Hapus aset "${a.nama}"?',
      penjelasan: 'Aset dan seluruh riwayat nilai bulanannya akan dihapus. '
          'Bila hanya ingin menyembunyikannya, pilih "Arsipkan".',
    );
    if (yakin != true) return;
    try {
      await _repo.hapusAset(a.id);
      await _muat();
      _pesan('Aset "${a.nama}" dan riwayat nilainya dihapus.');
    } catch (e) {
      _pesan('Aset tidak bisa dihapus: $e');
    }
  }

  Future<void> _hapusKewajiban(KewajibanData k) async {
    final yakin = await _konfirmasiHapus(
      judul: 'Hapus kewajiban "${k.nama}"?',
      penjelasan: 'Kewajiban dan riwayat nilai bulanannya akan dihapus. Bila '
          'hanya ingin menyembunyikannya, pilih "Arsipkan".',
    );
    if (yakin != true) return;
    try {
      await _repo.hapusKewajiban(k.id);
      await _muat();
      _pesan('Kewajiban "${k.nama}" dan riwayat nilainya dihapus.');
    } catch (e) {
      _pesan('Kewajiban tidak bisa dihapus: $e');
    }
  }

  Future<bool?> _konfirmasiHapus(
      {required String judul, required String penjelasan}) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(judul),
        content: Text(penjelasan),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('konfirmasi_hapus'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  /// Isi nilai satu baris untuk bulan yang sedang dilihat.
  Future<void> _isiNilai({
    required bool aset,
    required int id,
    required String nama,
    required int nilaiAwalSen,
  }) async {
    final sen = await _DialogNilai.tampilkan(
      context,
      judul: aset ? 'Nilai aset: $nama' : 'Sisa kewajiban: $nama',
      bulan: _bulan,
      nilaiAwalSen: nilaiAwalSen,
    );
    if (sen == null || !mounted) return;
    await _simpanNilai(aset: aset, id: id, nama: nama, sen: sen);
  }

  /// Simpan nilai bulanan. Bulan lampau yang terkunci hanya bisa diubah
  /// dengan alasan tertulis (paksa: true + alasan) lewat [_DialogAlasan].
  Future<void> _simpanNilai({
    required bool aset,
    required int id,
    required String nama,
    required int sen,
  }) async {
    Future<void> tulis({bool paksa = false, String? alasan}) => aset
        ? _repo.simpanNilaiAset(
            asetId: id,
            bulan: _bulan,
            nilaiSen: sen,
            paksa: paksa,
            alasan: alasan,
          )
        : _repo.simpanNilaiKewajiban(
            kewajibanId: id,
            bulan: _bulan,
            nilaiSen: sen,
            paksa: paksa,
            alasan: alasan,
          );

    try {
      await tulis();
    } on StateError {
      // Bulan lampau terkunci: perlu keputusan sadar + alasan.
      await _tulisDenganAlasan(tulis: tulis, nama: nama);
      return;
    } catch (e) {
      _pesan('Nilai tidak bisa disimpan: $e');
      return;
    }
    await _muat();
    _pesan('Nilai $nama untuk ${labelBulanPanjang(_bulan)} tersimpan.');
  }

  Future<void> _tulisDenganAlasan({
    required Future<void> Function({bool paksa, String? alasan}) tulis,
    required String nama,
  }) async {
    if (!mounted) return;
    final alasan = await _DialogAlasan.tampilkan(
      context,
      bulan: _bulan,
      nama: nama,
    );
    if (alasan == null || alasan.trim().isEmpty) {
      _pesan('Tidak ada yang diubah. ${labelBulanPanjang(_bulan)} tetap '
          'terkunci.');
      return;
    }
    try {
      await tulis(paksa: true, alasan: alasan.trim());
    } catch (e) {
      _pesan('Nilai tidak bisa disimpan: $e');
      return;
    }
    await _muat();
    _pesan('Nilai ${labelBulanPanjang(_bulan)} diperbaiki. Alasan yang '
        'tersimpan: ${alasan.trim()}');
  }

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  // -------------------------------------------------------------------------
  // Tampilan
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kekayaan Bersih')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          _pemilihBulan(tema),
          const SizedBox(height: 8),
          _kartuNilaiBersih(tema),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('tambah_aset'),
                  onPressed: () => _bukaFormAset(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah aset'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('tambah_kewajiban'),
                  onPressed: () => _bukaFormKewajiban(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah kewajiban'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GrafikTrenKekayaan(key: const Key('grafik_tren'), tren: _tren),
          if (_bulan != _bulanSekarang) ...[
            const SizedBox(height: 12),
            _catatanBulanLampau(tema),
          ],
          if (_nilai == null && _memuat)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Memuat data kekayaan…')),
            )
          else ...[
            const SizedBox(height: 16),
            _bagianAset(tema),
            const SizedBox(height: 16),
            _bagianKewajiban(tema),
          ],
        ],
      ),
    );
  }

  Widget _pemilihBulan(ThemeData tema) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            IconButton(
              key: const Key('bulan_sebelum'),
              tooltip: 'Bulan sebelumnya',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _geserBulan(-1),
            ),
            Expanded(
              child: Center(
                child: Text(
                  labelBulanPanjang(_bulan),
                  key: const Key('label_bulan'),
                  style: tema.textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              key: const Key('bulan_berikut'),
              tooltip: 'Bulan berikutnya',
              icon: const Icon(Icons.chevron_right),
              // Bulan depan belum terjadi: cukup sampai bulan berjalan.
              onPressed: _bulan.compareTo(_bulanSekarang) >= 0
                  ? null
                  : () => _geserBulan(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuNilaiBersih(ThemeData tema) {
    final nilai = _nilai;
    final judul = _bulan == _bulanSekarang
        ? 'Nilai bersih bulan ini'
        : 'Nilai bersih ${labelBulanPanjang(_bulan)}';
    return Card(
      key: const Key('nilai_bersih'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(judul, style: tema.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              nilai == null ? 'Menghitung…' : fmtRpDariSen(nilai.bersihSen),
              key: const Key('angka_nilai_bersih'),
              style: tema.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              nilai == null
                  ? 'Angka muncul setelah data aset & kewajiban terbaca.'
                  : 'Aset ${fmtRpDariSen(nilai.totalAsetSen)} - kewajiban '
                      '${fmtRpDariSen(nilai.totalKewajibanSen)}',
              style: tema.textTheme.bodySmall,
            ),
            if (_galat != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Data tidak bisa dimuat: $_galat',
                    style: tema.textTheme.bodySmall
                        ?.copyWith(color: tema.colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }

  /// Penjelasan bulan lampau: angkanya sengaja tidak ikut berubah.
  Widget _catatanBulanLampau(ThemeData tema) {
    return Container(
      key: const Key('catatan_bulan_lampau'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${labelBulanPanjang(_bulan)} sudah lewat dan terkunci',
              style: tema.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Angka bulan lampau disimpan apa adanya supaya grafik tren tidak '
            'berubah retroaktif. Bila ada salah ketik, tekan ikon pensil pada '
            'aset atau kewajiban: layar akan meminta alasan lebih dulu, dan '
            'alasan itu ikut tercatat.',
            style: tema.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _bagianAset(ThemeData tema) {
    final subtotal = _nilaiAset.values.fold<int>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // `Wrap` dipakai supaya tulisan panjang turun ke baris berikutnya
        // alih-alih meluber pada layar sempit.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            Text('Aset', style: tema.textTheme.titleMedium),
            Text('Subtotal ${fmtRpDariSen(subtotal)}',
                key: const Key('subtotal_aset'),
                style: tema.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        if (_aset.isEmpty)
          const _Kosong('Belum ada aset. Tekan "Tambah aset" untuk mencatat '
              'tabungan, emas, kendaraan, atau aset lain.')
        else
          for (final a in _aset) _barisAset(tema, a),
        if (_asetArsip.isNotEmpty) ...[
          const SizedBox(height: 4),
          _daftarArsipAset(tema),
        ],
      ],
    );
  }

  Widget _bagianKewajiban(ThemeData tema) {
    final subtotal = _nilaiKewajiban.values.fold<int>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            Text('Kewajiban', style: tema.textTheme.titleMedium),
            Text('Subtotal ${fmtRpDariSen(subtotal)}',
                key: const Key('subtotal_kewajiban'),
                style: tema.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        if (_kewajiban.isEmpty)
          const _Kosong('Belum ada kewajiban. Catat KPR, kartu kredit, atau '
              'cicilan supaya nilai bersih menggambarkan keadaan sebenarnya.')
        else
          for (final k in _kewajiban) _barisKewajiban(tema, k),
        if (_kewajibanArsip.isNotEmpty) ...[
          const SizedBox(height: 4),
          _daftarArsipKewajiban(tema),
        ],
      ],
    );
  }

  Widget _barisAset(ThemeData tema, AsetData a) {
    final jenis = JenisAset.dariDb(a.jenis);
    final nilai = _nilaiAset[a.id] ?? a.nilaiAwalSen;
    final keterangan = a.institusi == null || a.institusi!.isEmpty
        ? jenis.label
        : '${jenis.label} · ${a.institusi}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: Key('aset_${a.id}'),
        contentPadding: const EdgeInsets.only(left: 12, right: 0),
        leading: Icon(_ikonAset(jenis), color: tema.colorScheme.primary),
        title: Text(a.nama, maxLines: 1, overflow: TextOverflow.ellipsis),
        // Nilai dan keterangan ditaruh di bawah judul supaya tidak berebut
        // ruang dengan tombol aksi pada layar sempit.
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fmtRpDariSen(nilai),
                key: Key('nilai_aset_${a.id}'),
                style: tema.textTheme.titleSmall),
            const SizedBox(height: 2),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _lencana(tema, a.likuid ? 'Likuid' : 'Tidak likuid', a.likuid),
                Text(keterangan, style: tema.textTheme.bodySmall),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tombolIsiNilai(
              key: Key('isi_nilai_aset_${a.id}'),
              onPressed: () => _isiNilai(
                aset: true,
                id: a.id,
                nama: a.nama,
                nilaiAwalSen: nilai,
              ),
            ),
            _menuBaris(
              key: Key('menu_aset_${a.id}'),
              onPilih: (v) => _aksiAset(a, v),
            ),
          ],
        ),
        onTap: () => _bukaFormAset(a),
      ),
    );
  }

  Widget _barisKewajiban(ThemeData tema, KewajibanData k) {
    final jenis = JenisKewajiban.dariDb(k.jenis);
    final nilai = _nilaiKewajiban[k.id] ?? k.saldoAwalSen;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: Key('kewajiban_${k.id}'),
        contentPadding: const EdgeInsets.only(left: 12, right: 0),
        leading: Icon(_ikonKewajiban(jenis), color: tema.colorScheme.error),
        title: Text(k.nama, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fmtRpDariSen(nilai),
                key: Key('nilai_kewajiban_${k.id}'),
                style: tema.textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              k.minimumBayarSen == null
                  ? '${jenis.label} · sisa pokok'
                  : '${jenis.label} · sisa pokok · minimum '
                      '${fmtRpDariSen(k.minimumBayarSen!)}/bulan',
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tombolIsiNilai(
              key: Key('isi_nilai_kewajiban_${k.id}'),
              onPressed: () => _isiNilai(
                aset: false,
                id: k.id,
                nama: k.nama,
                nilaiAwalSen: nilai,
              ),
            ),
            _menuBaris(
              key: Key('menu_kewajiban_${k.id}'),
              onPilih: (v) => _aksiKewajiban(k, v),
            ),
          ],
        ),
        onTap: () => _bukaFormKewajiban(k),
      ),
    );
  }

  Widget _daftarArsipAset(ThemeData tema) {
    return ExpansionTile(
      key: const Key('arsip_aset'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text('Aset diarsipkan (${_asetArsip.length})',
          style: tema.textTheme.bodyMedium),
      subtitle: const Text('Tidak ikut dihitung pada nilai bersih.'),
      children: [
        for (final a in _asetArsip)
          ListTile(
            key: Key('aset_arsip_${a.id}'),
            dense: true,
            title: Text(a.nama),
            subtitle: Text(JenisAset.dariDb(a.jenis).label),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  key: Key('kembalikan_aset_${a.id}'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _aksiAset(a, 'kembalikan'),
                  child: const Text('Kembalikan'),
                ),
                _menuBaris(
                  key: Key('menu_arsip_aset_${a.id}'),
                  onPilih: (v) => _aksiAset(a, v),
                  hapusSaja: true,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _daftarArsipKewajiban(ThemeData tema) {
    return ExpansionTile(
      key: const Key('arsip_kewajiban'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text('Kewajiban diarsipkan (${_kewajibanArsip.length})',
          style: tema.textTheme.bodyMedium),
      subtitle: const Text('Tidak ikut dihitung pada nilai bersih.'),
      children: [
        for (final k in _kewajibanArsip)
          ListTile(
            key: Key('kewajiban_arsip_${k.id}'),
            dense: true,
            title: Text(k.nama),
            subtitle: Text(JenisKewajiban.dariDb(k.jenis).label),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  key: Key('kembalikan_kewajiban_${k.id}'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _aksiKewajiban(k, 'kembalikan'),
                  child: const Text('Kembalikan'),
                ),
                _menuBaris(
                  key: Key('menu_arsip_kewajiban_${k.id}'),
                  onPilih: (v) => _aksiKewajiban(k, v),
                  hapusSaja: true,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tombolIsiNilai({required Key key, required VoidCallback onPressed}) {
    return IconButton(
      key: key,
      tooltip: 'Isi nilai bulan ini',
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      // Tombol dibuat ringkas supaya judul baris tetap punya ruang.
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: const Icon(Icons.edit_calendar_outlined),
      onPressed: onPressed,
    );
  }

  Widget _menuBaris({
    required Key key,
    required void Function(String) onPilih,
    bool hapusSaja = false,
  }) {
    return PopupMenuButton<String>(
      key: key,
      tooltip: 'Aksi lain',
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onSelected: onPilih,
      itemBuilder: (c) => hapusSaja
          ? const [
              PopupMenuItem(value: 'hapus', child: Text('Hapus')),
            ]
          : const [
              PopupMenuItem(value: 'ubah', child: Text('Ubah')),
              PopupMenuItem(value: 'arsip', child: Text('Arsipkan')),
              PopupMenuItem(value: 'hapus', child: Text('Hapus')),
            ],
    );
  }

  Widget _lencana(ThemeData tema, String teks, bool positif) {
    final warna = positif ? tema.colorScheme.primary : tema.colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: warna),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        teks,
        style: tema.textTheme.labelSmall?.copyWith(color: warna),
      ),
    );
  }

  IconData _ikonAset(JenisAset jenis) => switch (jenis) {
        JenisAset.kas => Icons.payments_outlined,
        JenisAset.bank => Icons.account_balance_outlined,
        JenisAset.investasi => Icons.trending_up,
        JenisAset.properti => Icons.home_outlined,
        JenisAset.kendaraan => Icons.directions_car_outlined,
        JenisAset.emas => Icons.workspace_premium_outlined,
        JenisAset.kripto => Icons.currency_bitcoin,
        JenisAset.bisnis => Icons.storefront_outlined,
        JenisAset.lain => Icons.savings_outlined,
      };

  IconData _ikonKewajiban(JenisKewajiban jenis) => switch (jenis) {
        JenisKewajiban.kartuKredit => Icons.credit_card,
        JenisKewajiban.kpr => Icons.home_work_outlined,
        JenisKewajiban.pinjaman => Icons.request_quote_outlined,
        JenisKewajiban.cicilan => Icons.event_repeat_outlined,
        JenisKewajiban.lain => Icons.receipt_long_outlined,
      };
}

/// Kotak keterangan keadaan kosong.
class _Kosong extends StatelessWidget {
  const _Kosong(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(teks, style: tema.textTheme.bodyMedium),
    );
  }
}

/// Dialog pengisian nilai (Rp) untuk satu bulan.
class _DialogNilai extends StatefulWidget {
  const _DialogNilai({
    required this.judul,
    required this.bulan,
    required this.nilaiAwalSen,
  });

  final String judul;
  final String bulan;
  final int nilaiAwalSen;

  static Future<int?> tampilkan(
    BuildContext context, {
    required String judul,
    required String bulan,
    required int nilaiAwalSen,
  }) {
    return showDialog<int>(
      context: context,
      builder: (_) => _DialogNilai(
        judul: judul,
        bulan: bulan,
        nilaiAwalSen: nilaiAwalSen,
      ),
    );
  }

  @override
  State<_DialogNilai> createState() => _DialogNilaiState();
}

class _DialogNilaiState extends State<_DialogNilai> {
  late final TextEditingController _nilai =
      TextEditingController(text: (widget.nilaiAwalSen / 100).round().toString());
  String? _galat;

  @override
  void dispose() {
    _nilai.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.judul),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nilai per ${labelBulanPanjang(widget.bulan)}. Isi angka rupiah, '
              'mis. 5250000.'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('input_nilai'),
            controller: _nilai,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Nilai (Rp)',
              errorText: _galat,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('batal_nilai'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('simpan_nilai'),
          onPressed: _kirim,
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  void _kirim() {
    final angka = parseRupiah(_nilai.text);
    if (angka == null || angka < 0) {
      setState(() => _galat = 'Angka belum benar. Contoh: 5250000');
      return;
    }
    Navigator.of(context).pop(rupiahKeSen(angka));
  }
}

/// Dialog alasan sebelum membuka kunci bulan lampau.
class _DialogAlasan extends StatefulWidget {
  const _DialogAlasan({
    required this.bulan,
    required this.nama,
  });

  final String bulan;
  final String nama;

  static Future<String?> tampilkan(
    BuildContext context, {
    required String bulan,
    required String nama,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _DialogAlasan(bulan: bulan, nama: nama),
    );
  }

  @override
  State<_DialogAlasan> createState() => _DialogAlasanState();
}

class _DialogAlasanState extends State<_DialogAlasan> {
  final _alasan = TextEditingController();
  String? _galat;

  @override
  void dispose() {
    _alasan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('dialog_alasan'),
      title: Text('Bulan ${labelBulanPanjang(widget.bulan)} sudah terkunci'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nilai "${widget.nama}" untuk bulan itu disimpan tetap supaya '
              'grafik tren tidak berubah retroaktif.'),
          const SizedBox(height: 8),
          Text('Bila angkanya salah ketik, tuliskan alasan di bawah. Alasan '
              'ikut tersimpan sebagai jejak perubahan.'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('input_alasan'),
            controller: _alasan,
            autofocus: true,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Alasan perbaikan',
              errorText: _galat,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('batal_alasan'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Jangan ubah'),
        ),
        FilledButton(
          key: const Key('simpan_alasan'),
          onPressed: _kirim,
          child: const Text('Buka kunci & simpan'),
        ),
      ],
    );
  }

  void _kirim() {
    final teks = _alasan.text.trim();
    if (teks.isEmpty) {
      setState(() => _galat = 'Alasan perlu diisi supaya perubahan tercatat.');
      return;
    }
    Navigator.of(context).pop(teks);
  }
}
