/// FR-151 — aksi cepat dari widget layar utama & ikon aplikasi.
///
/// Prinsip: **satu ketukan = aksi benar-benar dijalankan.** Saat pengguna
/// menekan "Tandai lunas" di widget (atau aksi cepat ikon), aplikasi dibuka dan
/// langsung menjalankan aksinya — bukan membuka formulir yang harus ditekan
/// lagi.
///
/// Semua masuk lewat satu kanal (`lifeos/rute`) supaya tidak ada dua penangan
/// yang saling menimpa di Android.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../data/repository/tagihan_repository.dart';
import '../platform/kanal_widget.dart';
import '../providers/app_providers.dart';

/// Kunci pesan global (dipakai memberi tahu hasil aksi dari luar layar).
final GlobalKey<ScaffoldMessengerState> pesanGlobal =
    GlobalKey<ScaffoldMessengerState>();

/// Hasil menjalankan satu aksi widget.
class HasilAksiWidget {
  const HasilAksiWidget(this.pesan, {this.rute});

  final String pesan;

  /// Rute yang sebaiknya dibuka setelah aksi dijalankan.
  final String? rute;
}

/// Menjalankan aksi yang diminta widget/aksi cepat ikon.
class AksiWidgetLayanan {
  AksiWidgetLayanan(this._repo);

  final TagihanRepository _repo;

  Future<HasilAksiWidget> jalankan(AksiWidget aksi) async {
    switch (aksi.aksi) {
      case 'lunas':
        return _tandaiLunas(aksi.id);
      case 'tambah-pengeluaran':
        return const HasilAksiWidget('Catat pengeluaran baru.',
            rute: '/uang/transaksi');
      case 'tagihan':
        return const HasilAksiWidget('Daftar tagihan.', rute: '/tagihan');
      default:
        return HasilAksiWidget('Aksi "${aksi.aksi}" belum dikenal.',
            rute: '/');
    }
  }

  Future<HasilAksiWidget> _tandaiLunas(String? id) async {
    final angka = int.tryParse(id ?? '');
    if (angka == null) {
      return const HasilAksiWidget('Tagihan tidak dikenal — buka daftar tagihan.',
          rute: '/tagihan');
    }
    final repo = _repo;
    final semua = await repo.ambilSemua();
    final cocok = semua.where((t) => t.id == angka);
    if (cocok.isEmpty) {
      return const HasilAksiWidget('Tagihan itu tidak ada lagi.',
          rute: '/tagihan');
    }
    final tagihan = cocok.first;
    if (tagihan.lunas) {
      return HasilAksiWidget('${tagihan.nama} sudah ditandai lunas.',
          rute: '/tagihan');
    }
    await repo.tandaiLunas(angka);
    return HasilAksiWidget('${tagihan.nama} ditandai lunas dari widget.',
        rute: '/tagihan');
  }
}

/// Menangani rute & aksi yang datang dari Android (widget, aksi cepat ikon).
///
/// Dipasang sekali di dalam `ProviderScope` (lihat `main.dart`). Menangani
/// **kedua** kanal pesan supaya tidak ada penangan yang saling menimpa:
/// `ruteAwal`/`ruteBaru` (pintasan) dan `aksiAwal`/`aksiBaru` (aksi langsung).
class PenanganAksiWidget extends ConsumerStatefulWidget {
  const PenanganAksiWidget({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PenanganAksiWidget> createState() =>
      _PenanganAksiWidgetState();
}

class _PenanganAksiWidgetState extends ConsumerState<PenanganAksiWidget> {
  static const MethodChannel _kanal = MethodChannel('lifeos/rute');

  @override
  void initState() {
    super.initState();
    _kanal.setMethodCallHandler(_terima);
    unawaited(_periksaAwal());
  }

  Future<void> _periksaAwal() async {
    try {
      final aksi = AksiWidget.dariPeta(await _kanal.invokeMethod('aksiAwal'));
      if (aksi != null) {
        await _jalankan(aksi);
        return;
      }
      final rute = await _kanal.invokeMethod<String>('ruteAwal');
      if (rute != null && rute.isNotEmpty) appRouter.go(rute);
    } catch (e) {
      debugPrint('periksaAwal gagal: $e');
    }
  }

  Future<void> _terima(MethodCall panggilan) async {
    switch (panggilan.method) {
      case 'ruteBaru':
        if (panggilan.arguments is String) {
          appRouter.go(panggilan.arguments as String);
        }
        break;
      case 'aksiBaru':
        final aksi = AksiWidget.dariPeta(panggilan.arguments);
        if (aksi != null) await _jalankan(aksi);
        break;
      default:
        break;
    }
  }

  Future<void> _jalankan(AksiWidget aksi) async {
    try {
      final hasil = await AksiWidgetLayanan(ref.read(tagihanRepoProvider))
          .jalankan(aksi);
      if (hasil.rute != null) appRouter.go(hasil.rute!);
      pesanGlobal.currentState?.showSnackBar(
          SnackBar(content: Text(hasil.pesan)));
    } catch (e) {
      pesanGlobal.currentState?.showSnackBar(
          SnackBar(content: Text('Aksi gagal dijalankan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
