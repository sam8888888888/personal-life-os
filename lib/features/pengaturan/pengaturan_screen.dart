/// Pengaturan: pemasukan bulanan (bahan hitung "uang tersisa"), data & info.
library;

import '../../core/versi.dart';
import '../../core/utils/waktu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/mata_uang.dart';
import 'mode_tema_pengaturan.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';
import 'mata_uang_pengaturan.dart';

class PengaturanScreen extends ConsumerStatefulWidget {
  const PengaturanScreen({super.key});

  @override
  ConsumerState<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends ConsumerState<PengaturanScreen> {
  final _pemasukan = TextEditingController();
  bool _terisi = false;

  /// FR-21: simpan pilihan tema (terang / gelap / ikut sistem).
  Future<void> _ubahModeTema(ModeTema m) async {
    final db = ref.read(databaseProvider);
    await simpanModeTema(db, m);
    ref.invalidate(modeTemaProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Tema diubah ke ${m.label}')));
  }

  /// FR-67: simpan pilihan mata uang lalu perbarui seluruh label uang.
  Future<void> _ubahMataUang(MataUang m) async {
    final db = ref.read(databaseProvider);
    await simpanMataUang(db, m);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Mata uang diubah ke ${m.label}')));
  }

  @override
  Widget build(BuildContext context) {
    final bulan = waktuSekarang();
    final pemasukan = ref.watch(pemasukanBulanIniProvider);
    final mataUangSekarang = ref.watch(mataUangProvider).value ?? mataUangAktif;
    // FR-21 — tema: terang / gelap / ikut sistem (bawaan: ikut sistem).
    final modeTemaSekarang =
        ref.watch(modeTemaProvider).value ?? ModeTema.sistem;

    pemasukan.whenData((v) {
      if (!_terisi && v > 0) {
        _pemasukan.text = (v / 100).round().toString();
        _terisi = true;
      }
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text('Uang masuk bulan ini',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Dipakai untuk menghitung "uang tersisa" setelah semua tagihan '
            '(${fmtBulanId(bulan)}).'),
        const SizedBox(height: 12),
        TextField(
          controller: _pemasukan,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Pemasukan (Rp)', hintText: 'Contoh: 8000000 atau 8jt'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _simpanPemasukan,
          icon: const Icon(Icons.savings),
          label: const Text('Simpan pemasukan'),
        ),
        const Divider(height: 40),
        const Text('Mata uang',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Dipakai untuk semua angka uang di aplikasi. '
            'Bawaan: Rupiah (Rp).'),
        const SizedBox(height: 8),
        DropdownButtonFormField<MataUang>(
          key: const Key('pilih_mata_uang'),
          isExpanded: true,
          initialValue: mataUangSekarang,
          decoration: const InputDecoration(labelText: 'Mata uang'),
          items: MataUang.values
              .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
              .toList(),
          onChanged: (m) {
            if (m != null) _ubahMataUang(m);
          },
        ),
        const Divider(height: 40),
        const Text('Tema',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Terang, gelap, atau mengikuti pengaturan sistem. '
            'Ukuran teks tetap mengikuti pengaturan sistem perangkat.'),
        const SizedBox(height: 8),
        DropdownButtonFormField<ModeTema>(
          key: const Key('pilih_mode_tema'),
          isExpanded: true,
          initialValue: modeTemaSekarang,
          decoration: const InputDecoration(labelText: 'Tema'),
          items: ModeTema.values
              .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
              .toList(),
          onChanged: (m) {
            if (m != null) _ubahModeTema(m);
          },
        ),
        const Divider(height: 40),
        const Text('Data',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Semua data tersimpan di perangkat ini (offline). '
            'Belum ada data yang dikirim ke internet.'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isiContoh,
          icon: const Icon(Icons.playlist_add),
          label: const Text('Isi contoh data (7 template)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _hapusSemua,
          icon: const Icon(Icons.delete_forever),
          label: const Text('Hapus semua data tagihan'),
        ),
        const Divider(height: 40),
        const Text('Cadangan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Simpan seluruh data ke satu berkas JSON, atau pulihkan '
            'dari berkas cadangan. Berguna saat ganti HP.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('buka_cadangan'),
          onPressed: () => context.push('/cadangan'),
          icon: const Icon(Icons.backup_outlined),
          label: const Text('Cadangan & pemulihan'),
        ),
        const Divider(height: 40),
        const Text('Pengingat',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Atur izin notifikasi, uji pengingat, dan lihat panduan '
            'khusus merek HP Anda.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => context.push('/pengingat'),
          icon: const Icon(Icons.notifications_active),
          label: const Text('Pengingat & izin'),
        ),
        const SizedBox(height: 12),
        ref.watch(pengingatBerikutnyaProvider).when(
              data: (d) => Text('Pengingat terjadwal berikutnya: ${d.length}'),
              loading: () => const Text('Menghitung pengingat…'),
              error: (e, _) => Text('Gagal menghitung pengingat: $e'),
            ),
        const Divider(height: 40),
        const Text('Ibadah',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Waktu sholat dihitung di perangkat (offline). '
            'Hasil perhitungan, bukan jadwal resmi Kementerian Agama.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => context.push('/ibadah/jadwal-sholat'),
          icon: const Icon(Icons.access_time),
          label: const Text('Jadwal sholat'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/ibadah/kalender-hijriah'),
          icon: const Icon(Icons.calendar_month),
          label: const Text('Kalender Hijriah'),
        ),
        const Divider(height: 40),
        const Text('Tentang',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Personal Life OS · versi $versiAplikasi (build $nomorBuild) · $jalurPengembangan'),
        const Text('Zona waktu & format: Indonesia (id-ID), Rupiah'),
        const SizedBox(height: 6),
        const Text('Pengingat berjalan di perangkat (tanpa internet).',
            style: TextStyle(fontStyle: FontStyle.italic)),
      ],
    );
  }

  Future<void> _simpanPemasukan() async {
    final n = parseRupiah(_pemasukan.text);
    if (n == null || n <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Masukkan angka yang valid, contoh 8000000')));
      return;
    }
    await ref
        .read(pengaturanRepoProvider)
        .simpanPemasukan(waktuSekarang(), rupiahKeSen(n));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pemasukan tersimpan.')));
    }
  }

  Future<void> _isiContoh() async {
    final n = await ref.read(pengaturanRepoProvider).isiContohData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$n tagihan contoh ditambahkan.')));
    }
  }

  Future<void> _hapusSemua() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus semua data?'),
        content: const Text('Seluruh tagihan, riwayat pembayaran, dan pemasukan '
            'akan dihapus dari perangkat ini. Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => c.pop(false), child: const Text('Batal')),
          FilledButton(onPressed: () => c.pop(true), child: const Text('Hapus semua')),
        ],
      ),
    );
    if (yakin != true) return;
    // PB-11: bawa serta layanan notifikasi agar jadwal lama ikut dibatalkan.
    await ref
        .read(pengaturanRepoProvider)
        .hapusSemuaData(layanan: ref.read(layananNotifikasiProvider));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Semua data dihapus.')));
    }
  }
}
