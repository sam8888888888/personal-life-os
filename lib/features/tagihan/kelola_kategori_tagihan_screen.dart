/// FR-08 — layar "Kategori tagihan": tambah, ubah (nama + ikon + warna),
/// hapus, dan atur urutan kategori.
///
/// Aturan penting:
///  * Hapus kategori yang MASIH DIPAKAI tagihan TIDAK menghapus tagihannya —
///    tagihan dipindahkan ke "Tanpa kategori" (kategoriId = null) di dalam
///    SATU transaksi, baru baris kategorinya dihapus.
///  * Urutan disimpan di kolom `urutan` dan selalu dirapikan menjadi 0..n-1
///    supaya tidak ada dua kategori dengan nomor urut sama.
///  * Nilai ikon/warna yang tidak dikenal tetap aman: dibaca dengan nilai
///    bawaan, dan dirapikan saat disimpan (`ikon_warna_kategori.dart`).
library;

import 'package:drift/drift.dart'
    show Value, OrderingTerm, Selectable, BaseAggregate;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import 'ikon_warna_kategori.dart';

/// Hasil penghapusan satu kategori.
class HasilHapusKategori {
  const HasilHapusKategori({required this.nama, required this.tagihanDipindah});

  /// Nama kategori yang dihapus (kosong bila barisnya sudah tidak ada).
  final String nama;

  /// Jumlah tagihan yang dipindahkan ke "Tanpa kategori".
  final int tagihanDipindah;
}

/// Operasi kategori tagihan (FR-08). Tidak mengubah skema database apa pun.
class RepoKategoriTagihan {
  RepoKategoriTagihan(this.db);

  final AppDatabase db;

  /// Batas panjang nama — sama dengan batas kolom `nama` (60).
  static const int namaMaks = 60;

  /// Nama ikon cadangan bila nilai yang dikirim tidak dikenal.
  static const String ikonCadangan = 'receipt';

  Selectable<KategoriData> _urut() => db.select(db.kategori)
    ..orderBy([
      (k) => OrderingTerm.asc(k.urutan),
      (k) => OrderingTerm.asc(k.id),
    ]);

  /// Semua kategori, urut `urutan` lalu `id` (urutan yang dilihat pengguna).
  Future<List<KategoriData>> ambilSemua() => _urut().get();

  /// Aliran semua kategori (layar ikut berubah saat data diubah).
  Stream<List<KategoriData>> watch() => _urut().watch();

  /// Nama yang sudah dirapikan; menolak nama kosong atau terlalu panjang.
  String namaBersih(String nama) {
    final bersih = nama.trim();
    if (bersih.isEmpty) {
      throw ArgumentError('Nama kategori wajib diisi.');
    }
    if (bersih.length > namaMaks) {
      throw ArgumentError('Nama kategori maksimal $namaMaks huruf.');
    }
    return bersih;
  }

  /// Nama ikon yang aman disimpan (dikenal; selain itu ikon cadangan).
  String ikonAman(String? ikon) =>
      namaIkonTagihanDikenal(ikon) ? ikon!.trim() : ikonCadangan;

  /// Teks heks yang aman disimpan (`#RRGGBB`); selain itu warna bawaan.
  String warnaAman(String? warna) {
    final asli = warna?.trim().toUpperCase() ?? '';
    if (heksWarnaTagihanDikenal(asli)) return asli;
    final angka = asli.startsWith('#') ? asli.substring(1) : asli;
    if (angka.length == 6 && int.tryParse(angka, radix: 16) != null) {
      return '#$angka';
    }
    return heksWarnaTagihanBawaan;
  }

  /// Tambah kategori baru di urutan paling akhir.
  Future<KategoriData> tambah({
    required String nama,
    String? ikon,
    String? warna,
  }) async {
    final bersih = namaBersih(nama);
    final urutan = await urutanBerikutnya();
    return db.into(db.kategori).insertReturning(KategoriCompanion.insert(
          nama: bersih,
          ikon: Value(ikonAman(ikon)),
          warna: Value(warnaAman(warna)),
          urutan: Value(urutan),
        ));
  }

  /// Nomor urut untuk kategori baru = nomor terbesar + 1.
  Future<int> urutanBerikutnya() async {
    final maks = db.kategori.urutan.max();
    final baris =
        await (db.selectOnly(db.kategori)..addColumns([maks])).getSingle();
    return (baris.read(maks) ?? -1) + 1;
  }

  /// Ubah nama/ikon/warna. Kembalikan jumlah baris yang berubah
  /// (0 = kategori tidak ditemukan). `kategoriId` pada tagihan TIDAK disentuh.
  Future<int> ubah(
    int id, {
    required String nama,
    String? ikon,
    String? warna,
  }) {
    final bersih = namaBersih(nama);
    return (db.update(db.kategori)..where((k) => k.id.equals(id))).write(
      KategoriCompanion(
        nama: Value(bersih),
        ikon: Value(ikonAman(ikon)),
        warna: Value(warnaAman(warna)),
      ),
    );
  }

  /// Jumlah tagihan (aktif maupun tidak) yang memakai kategori ini.
  Future<int> jumlahPemakai(int id) async {
    final hitung = db.tagihan.id.count();
    final baris = await (db.selectOnly(db.tagihan)
          ..addColumns([hitung])
          ..where(db.tagihan.kategoriId.equals(id)))
        .getSingle();
    return baris.read(hitung) ?? 0;
  }

  /// Hapus kategori. Bila masih dipakai tagihan, tagihannya DIPINDAHKAN ke
  /// "Tanpa kategori" (kategoriId = null) — bukan ikut terhapus — dan semuanya
  /// dijalankan dalam satu transaksi.
  Future<HasilHapusKategori> hapus(int id) => db.transaction(() async {
        final k = await (db.select(db.kategori)..where((x) => x.id.equals(id)))
            .getSingleOrNull();
        if (k == null) {
          return const HasilHapusKategori(nama: '', tagihanDipindah: 0);
        }
        final dipakai = await jumlahPemakai(id);
        if (dipakai > 0) {
          await (db.update(db.tagihan)..where((t) => t.kategoriId.equals(id)))
              .write(TagihanCompanion(
            kategoriId: const Value(null),
            diubahPada: Value(waktuSekarang()),
          ));
        }
        await (db.delete(db.kategori)..where((x) => x.id.equals(id))).go();
        return HasilHapusKategori(nama: k.nama, tagihanDipindah: dipakai);
      });

  /// Geser satu kategori naik/turun satu langkah, lalu rapikan seluruh nomor
  /// urut menjadi 0..n-1. `false` = tidak bisa digeser (sudah di ujung).
  Future<bool> geser(int id, {required bool naik}) => db.transaction(() async {
        final semua = await ambilSemua();
        final i = semua.indexWhere((k) => k.id == id);
        if (i < 0) return false;
        final j = naik ? i - 1 : i + 1;
        if (j < 0 || j >= semua.length) return false;
        final baru = [...semua];
        final tmp = baru[i];
        baru[i] = baru[j];
        baru[j] = tmp;
        for (var n = 0; n < baru.length; n++) {
          if (baru[n].urutan == n) continue; // sudah benar, tidak perlu ditulis
          await (db.update(db.kategori)..where((k) => k.id.equals(baru[n].id)))
              .write(KategoriCompanion(urutan: Value(n)));
        }
        return true;
      });
}

/// Repositori kategori tagihan (FR-08).
final repoKategoriTagihanProvider = Provider<RepoKategoriTagihan>(
    (ref) => RepoKategoriTagihan(ref.watch(databaseProvider)));

/// Semua kategori urut `urutan` lalu `id`.
final daftarKategoriTagihanProvider =
    StreamProvider.autoDispose<List<KategoriData>>(
        (ref) => ref.watch(repoKategoriTagihanProvider).watch());

/// Jumlah tagihan per kategori: {id kategori: jumlah}. Kategori kosong
/// (`kategoriId = null`) tidak dihitung di sini.
final hitungTagihanKategoriProvider =
    StreamProvider.autoDispose<Map<int, int>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.tagihan).watch().map((baris) {
    final hasil = <int, int>{};
    for (final t in baris) {
      final id = t.kategoriId;
      if (id == null) continue;
      hasil[id] = (hasil[id] ?? 0) + 1;
    }
    return hasil;
  });
});

/// Layar "Kategori tagihan" (FR-08).
class KelolaKategoriTagihanScreen extends ConsumerStatefulWidget {
  const KelolaKategoriTagihanScreen({super.key});

  @override
  ConsumerState<KelolaKategoriTagihanScreen> createState() =>
      _KelolaKategoriTagihanScreenState();
}

class _KelolaKategoriTagihanScreenState
    extends ConsumerState<KelolaKategoriTagihanScreen> {
  Future<void> _tambah() async {
    final hasil = await showDialog<IsiKategori>(
      context: context,
      builder: (_) => const _DialogKategori(),
    );
    if (hasil == null || !mounted) return;
    await _jalankan(
      () => ref.read(repoKategoriTagihanProvider).tambah(
            nama: hasil.nama,
            ikon: hasil.ikon,
            warna: hasil.warna,
          ),
      sukses: 'Kategori "${hasil.nama}" ditambahkan.',
    );
  }

  Future<void> _ubah(KategoriData k) async {
    final hasil = await showDialog<IsiKategori>(
      context: context,
      builder: (_) => _DialogKategori(awal: k),
    );
    if (hasil == null || !mounted) return;
    await _jalankan(
      () => ref.read(repoKategoriTagihanProvider).ubah(
            k.id,
            nama: hasil.nama,
            ikon: hasil.ikon,
            warna: hasil.warna,
          ),
      sukses: 'Kategori "${hasil.nama}" diperbarui.',
    );
  }

  /// Jalankan aksi penyimpanan lalu beri kabar; galat ditampilkan apa adanya.
  Future<void> _jalankan(Future<void> Function() aksi,
      {required String sukses}) async {
    try {
      await aksi();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(sukses)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Kategori tidak tersimpan: $e')));
    }
  }

  Future<void> _geser(KategoriData k, {required bool naik}) async {
    final bisa = await ref.read(repoKategoriTagihanProvider).geser(k.id, naik: naik);
    if (!mounted || !bisa) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 1),
        content: Text(naik
            ? 'Urutan "${k.nama}" dinaikkan.'
            : 'Urutan "${k.nama}" diturunkan.')));
  }

  Future<void> _hapus(KategoriData k) async {
    final repo = ref.read(repoKategoriTagihanProvider);
    final dipakai = await repo.jumlahPemakai(k.id);
    if (!mounted) return;

    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Hapus kategori "${k.nama}"?'),
        content: Text(dipakai == 0
            ? 'Kategori ini belum dipakai tagihan. Menghapus kategori tidak '
                'menghapus tagihan apa pun.'
            : '$dipakai tagihan memakai kategori ini. Pindahkan ke Tanpa '
                'kategori?\n\nTagihannya tetap ada — hanya kategorinya yang '
                'dikosongkan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Batal')),
          FilledButton(
            key: const Key('konfirmasi_hapus_kategori'),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(dipakai == 0 ? 'Hapus' : 'Pindahkan & hapus'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    // Satu pesan saja: jumlah tagihan yang dipindahkan ikut dilaporkan apa
    // adanya supaya pengguna tahu tagihannya tidak ikut hilang.
    try {
      final hasil = await repo.hapus(k.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(hasil.tagihanDipindah == 0
              ? 'Kategori "${k.nama}" dihapus.'
              : 'Kategori "${k.nama}" dihapus. '
                  '${hasil.tagihanDipindah} tagihan dipindahkan ke Tanpa kategori.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Kategori tidak tersimpan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final async = ref.watch(daftarKategoriTagihanProvider);
    final hitung =
        ref.watch(hitungTagihanKategoriProvider).value ?? const <int, int>{};
    final daftar = async.value ?? const <KategoriData>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Kategori tagihan')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tambah_kategori_tagihan'),
        onPressed: _tambah,
        icon: const Icon(Icons.add),
        label: const Text('Kategori'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Text('${daftar.length} kategori'),
                const Spacer(),
                Flexible(
                  child: Text(
                    'Ketuk baris untuk mengubah nama, ikon, atau warna.',
                    textAlign: TextAlign.right,
                    style: tema.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.hasError
                ? Center(child: Text('Kategori tidak bisa dibaca: ${async.error}'))
                : !async.hasValue
                    ? const Center(child: CircularProgressIndicator())
                    : daftar.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Belum ada kategori. Tambah kategori untuk '
                                'mengelompokkan tagihan Anda.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
                            itemCount: daftar.length,
                            itemBuilder: (c, i) => _barisKategori(
                              daftar[i],
                              hitung: hitung[daftar[i].id] ?? 0,
                              pertama: i == 0,
                              terakhir: i == daftar.length - 1,
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _barisKategori(
    KategoriData k, {
    required int hitung,
    required bool pertama,
    required bool terakhir,
  }) {
    final warna = warnaTagihan(k.warna);
    return ListTile(
      key: ValueKey('kategori_${k.id}'),
      onTap: () => _ubah(k),
      leading: CircleAvatar(
        backgroundColor: warna.withValues(alpha: 0.15),
        child: Icon(ikonTagihan(k.ikon), color: warna, size: 20),
      ),
      title: Text(k.nama, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        hitung == 0 ? 'Belum dipakai tagihan' : '$hitung tagihan memakai kategori ini',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey('naik_${k.id}'),
            tooltip: 'Naikkan urutan',
            visualDensity: VisualDensity.compact,
            onPressed: pertama ? null : () => _geser(k, naik: true),
            icon: const Icon(Icons.arrow_upward, size: 18),
          ),
          IconButton(
            key: ValueKey('turun_${k.id}'),
            tooltip: 'Turunkan urutan',
            visualDensity: VisualDensity.compact,
            onPressed: terakhir ? null : () => _geser(k, naik: false),
            icon: const Icon(Icons.arrow_downward, size: 18),
          ),
          IconButton(
            key: ValueKey('hapus_${k.id}'),
            tooltip: 'Hapus kategori',
            visualDensity: VisualDensity.compact,
            onPressed: () => _hapus(k),
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
        ],
      ),
    );
  }
}

/// Isi dialog kategori: nama + nama ikon + teks heks warna.
class IsiKategori {
  const IsiKategori({
    required this.nama,
    required this.ikon,
    required this.warna,
  });

  final String nama;
  final String ikon;
  final String warna;
}

/// Dialog tambah/ubah kategori (nama, ikon, warna).
class _DialogKategori extends StatefulWidget {
  const _DialogKategori({this.awal});

  final KategoriData? awal;

  @override
  State<_DialogKategori> createState() => _DialogKategoriState();
}

class _DialogKategoriState extends State<_DialogKategori> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late String _ikon;
  late String _warna;

  @override
  void initState() {
    super.initState();
    final a = widget.awal;
    _nama = TextEditingController(text: a?.nama ?? '');
    // Nilai tak dikenal ditampilkan sebagai pilihan pertama yang dikenal.
    _ikon = namaIkonTagihanDikenal(a?.ikon) ? a!.ikon : pilihanIkonTagihan.first;
    _warna = heksWarnaTagihanDikenal(a?.warna)
        ? a!.warna.toUpperCase()
        : pilihanWarnaTagihan.first;
  }

  @override
  void dispose() {
    _nama.dispose();
    super.dispose();
  }

  void _simpan() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(IsiKategori(
      nama: _nama.text.trim(),
      ikon: _ikon,
      warna: _warna,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final warnaPratinjau = warnaTagihan(_warna);
    return AlertDialog(
      title: Text(widget.awal == null ? 'Tambah kategori' : 'Ubah kategori'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    key: const Key('pratinjau_kategori'),
                    backgroundColor: warnaPratinjau.withValues(alpha: 0.15),
                    child: Icon(ikonTagihan(_ikon), color: warnaPratinjau, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text('Contoh tampilan', style: tema.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('nama_kategori_tagihan'),
                controller: _nama,
                autofocus: true,
                maxLength: RepoKategoriTagihan.namaMaks,
                decoration: const InputDecoration(
                  labelText: 'Nama kategori *',
                  hintText: 'Contoh: Listrik rumah',
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Nama kategori wajib diisi';
                  if (t.length > RepoKategoriTagihan.namaMaks) {
                    return 'Nama kategori maksimal '
                        '${RepoKategoriTagihan.namaMaks} huruf';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 4),
              const Text('Ikon', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              SizedBox(
                height: 108,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 2,
                    children: [
                      for (final nama in pilihanIkonTagihan)
                        IconButton(
                          key: ValueKey('ikon_tagihan_$nama'),
                          tooltip: nama,
                          isSelected: _ikon == nama,
                          onPressed: () => setState(() => _ikon = nama),
                          icon: Icon(ikonTagihan(nama)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Warna', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final heks in pilihanWarnaTagihan)
                    InkWell(
                      key: ValueKey('warna_tagihan_$heks'),
                      onTap: () => setState(() => _warna = heks),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: warnaTagihan(heks),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _warna == heks
                                ? tema.colorScheme.onSurface
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal')),
        FilledButton(
          key: const Key('simpan_kategori_tagihan'),
          onPressed: _simpan,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
