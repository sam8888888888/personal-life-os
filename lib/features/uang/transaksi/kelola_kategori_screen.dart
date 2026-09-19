/// FR-71 — layar kelola kategori arus kas.
///
/// Kriteria PRD: "kategori bisa diubah pengguna". Layar ini melayani:
/// tambah, ubah (nama, ikon, warna), sembunyikan/tampilkan, dan hapus untuk
/// kategori buatan pengguna. Kategori bawaan sistem tidak bisa dihapus — hanya
/// disembunyikan — supaya riwayat transaksi lama tetap punya nama
/// (aturan di `kategori_transaksi_repository.dart`).
library;

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audit/audit_log.dart';
import '../../../core/providers/app_providers.dart';
import '../../../data/database/database.dart';
import '../../../data/model/enums.dart';
import '../../../data/repository/kategori_transaksi_repository.dart';
import 'warna_ikon_kategori.dart';

/// Semua kategori, termasuk yang disembunyikan — layar ini harus bisa
/// menampilkan kembali kategori yang sudah diarsipkan.
final kategoriKelolaProvider =
    StreamProvider.autoDispose<List<KategoriTransaksiData>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.kategoriTransaksi)
        ..orderBy([
          (k) => OrderingTerm.asc(k.urutan),
          (k) => OrderingTerm.asc(k.nama),
        ]))
      .watch();
});

/// Repositori kategori untuk layar kelola.
final repoKategoriProvider = Provider<KategoriTransaksiRepository>(
    (ref) => KategoriTransaksiRepository(ref.watch(databaseProvider)));

/// Layar kelola kategori (FR-71).
class KelolaKategoriScreen extends ConsumerStatefulWidget {
  const KelolaKategoriScreen({super.key});

  @override
  ConsumerState<KelolaKategoriScreen> createState() =>
      _KelolaKategoriScreenState();
}

class _KelolaKategoriScreenState extends ConsumerState<KelolaKategoriScreen> {
  JenisArus _jenis = JenisArus.pengeluaran;

  /// Tampilkan juga kategori yang disembunyikan (dengan tanda jelas)?
  bool _tampilkanArsip = true;

  /// FR-138 — catatan aktivitas untuk kategori.
  ///
  /// Satu helper supaya empat aksi (tambah/ubah/arsip/hapus) menulis catatan
  /// dengan bentuk yang sama, dan penulisan tidak pernah menggagalkan aksi.
  Future<void> _audit(String aksi, {String? id, required String ringkas}) =>
      catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.kategori,
        aksi: aksi,
        entitas: 'kategori',
        entitasId: id,
        ringkas: ringkas,
      );

  Future<void> _tambah() async {
    final hasil = await showDialog<HasilKategori>(
      context: context,
      builder: (_) => _DialogKategori(jenis: _jenis),
    );
    if (hasil == null || !mounted) return;
    try {
      await ref.read(repoKategoriProvider).tambah(
            nama: hasil.nama,
            jenis: _jenis,
            ikon: hasil.ikon,
            warna: hasil.warna,
          );
      await _audit(AksiAudit.buat,
          ringkas: 'Kategori "${hasil.nama}" ditambahkan.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kategori "${hasil.nama}" ditambahkan.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kategori tidak bisa disimpan: $e')));
    }
  }

  Future<void> _ubah(KategoriTransaksiData k) async {
    final hasil = await showDialog<HasilKategori>(
      context: context,
      builder: (_) => _DialogKategori(jenis: _jenis, awal: k),
    );
    if (hasil == null || !mounted) return;
    try {
      await ref.read(repoKategoriProvider).ubah(
            k.id,
            nama: hasil.nama,
            ikon: hasil.ikon,
            warna: hasil.warna,
          );
      await _audit(AksiAudit.ubah,
          id: '${k.id}',
          ringkas: 'Kategori "${hasil.nama}" diubah.');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kategori diperbarui.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kategori tidak bisa diubah: $e')));
    }
  }

  /// Sembunyikan dari daftar tanpa menghapus riwayat transaksinya.
  Future<void> _ubahArsip(KategoriTransaksiData k) async {
    try {
      if (k.arsip) {
        await ref.read(repoKategoriProvider).tampilkan(k.id);
      } else {
        await ref.read(repoKategoriProvider).sembunyikan(k.id);
      }
      await _audit(AksiAudit.ubah,
          id: '${k.id}',
          ringkas: k.arsip
              ? 'Kategori "${k.nama}" ditampilkan kembali.'
              : 'Kategori "${k.nama}" disembunyikan (riwayat tetap utuh).');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(k.arsip
              ? 'Kategori "${k.nama}" ditampilkan kembali.'
              : 'Kategori "${k.nama}" disembunyikan. Riwayat transaksinya tetap utuh.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kategori tidak bisa diubah: $e')));
    }
  }

  Future<void> _hapus(KategoriTransaksiData k) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Hapus kategori "${k.nama}"?'),
        content: const Text('Kategori hanya bisa dihapus bila belum dipakai '
            'transaksi atau anggaran. Bila sudah dipakai, sembunyikan saja.'),
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
    if (yakin != true || !mounted) return;
    try {
      await ref.read(repoKategoriProvider).hapus(k.id);
      await _audit(AksiAudit.hapus,
          id: '${k.id}', ringkas: 'Kategori "${k.nama}" dihapus.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kategori "${k.nama}" dihapus.')));
    } catch (e) {
      if (!mounted) return;
      // Pesan dari repository sudah menjelaskan sebabnya (dipakai / bawaan).
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kategori tidak bisa dihapus: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final async = ref.watch(kategoriKelolaProvider);
    final semua = async.value ?? const <KategoriTransaksiData>[];
    final daftar = semua
        .where((k) => k.jenis == _jenis.nilaiDb)
        .where((k) => _tampilkanArsip || !k.arsip)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Kategori')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tambah_kategori'),
        onPressed: _tambah,
        icon: const Icon(Icons.add),
        label: const Text('Kategori'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SegmentedButton<JenisArus>(
              segments: const [
                ButtonSegment<JenisArus>(
                  value: JenisArus.pengeluaran,
                  label: Text('Pengeluaran'),
                ),
                ButtonSegment<JenisArus>(
                  value: JenisArus.pemasukan,
                  label: Text('Pemasukan'),
                ),
              ],
              selected: {_jenis},
              onSelectionChanged: (pilih) =>
                  setState(() => _jenis = pilih.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            // Align + label pendek: chip tidak meluber di layar sempit (420 dp).
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                key: const Key('tampilkan_arsip'),
                label: const Text('Tampilkan arsip'),
                tooltip: 'Ikut menampilkan kategori yang disembunyikan',
                selected: _tampilkanArsip,
                onSelected: (pilih) =>
                    setState(() => _tampilkanArsip = pilih),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                            child: Text('Belum ada kategori untuk jenis ini.'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
                            itemCount: daftar.length,
                            itemBuilder: (c, i) => _barisKategori(daftar[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _barisKategori(KategoriTransaksiData k) {
    final warna = warnaKategori(k.warna);
    return ListTile(
      key: ValueKey('kategori_${k.id}'),
      onTap: () => _ubah(k),
      leading: CircleAvatar(
        backgroundColor: warna.withValues(alpha: 0.15),
        child: Icon(ikonKategori(k.ikon), color: warna, size: 20),
      ),
      title: Text(
        k.nama,
        style: k.arsip
            ? TextStyle(color: Theme.of(context).colorScheme.outline)
            : null,
      ),
      subtitle: Text(k.arsip
          ? 'Disembunyikan'
          : (k.bawaanSistem ? 'Bawaan aplikasi' : 'Kategori Anda')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey('arsip_${k.id}'),
            tooltip: k.arsip ? 'Tampilkan' : 'Sembunyikan',
            onPressed: () => _ubahArsip(k),
            icon: Icon(k.arsip
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined),
          ),
          if (!k.bawaanSistem)
            IconButton(
              key: ValueKey('hapus_kategori_${k.id}'),
              tooltip: 'Hapus',
              onPressed: () => _hapus(k),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }
}

/// Hasil dialog kategori.
class HasilKategori {
  const HasilKategori({
    required this.nama,
    required this.ikon,
    required this.warna,
  });

  final String nama;
  final String ikon;
  final String warna;
}

/// Dialog tambah/ubah kategori: nama, ikon, dan warna.
class _DialogKategori extends StatefulWidget {
  const _DialogKategori({required this.jenis, this.awal});

  final JenisArus jenis;
  final KategoriTransaksiData? awal;

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
    _ikon = a?.ikon ?? pilihanIkon.first;
    _warna = a?.warna ?? pilihanWarna.first;
  }

  @override
  void dispose() {
    _nama.dispose();
    super.dispose();
  }

  void _simpan() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(HasilKategori(
      nama: _nama.text.trim(),
      ikon: _ikon,
      warna: _warna,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AlertDialog(
      title: Text(widget.awal == null ? 'Tambah kategori' : 'Ubah kategori'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Jenis: ${widget.jenis.label}',
                  style: tema.textTheme.bodySmall),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('nama_kategori'),
                controller: _nama,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nama kategori *',
                  hintText: 'Contoh: Hobi Laut',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama kategori wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              const Text('Ikon',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              SizedBox(
                height: 110,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 4,
                    children: [
                      for (final nama in pilihanIkon)
                        IconButton(
                          key: ValueKey('ikon_$nama'),
                          tooltip: nama,
                          isSelected: _ikon == nama,
                          onPressed: () => setState(() => _ikon = nama),
                          icon: Icon(ikonKategori(nama)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Warna',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final heks in pilihanWarna)
                    InkWell(
                      key: ValueKey('warna_$heks'),
                      onTap: () => setState(() => _warna = heks),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: warnaKategori(heks),
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
          key: const Key('simpan_kategori'),
          onPressed: _simpan,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
