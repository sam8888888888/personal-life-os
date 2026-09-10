/// Pemantau pengingat: menyegarkan jadwal notifikasi setiap data tagihan
/// berubah, saat aplikasi dibuka, dan saat kembali dari latar (FR-13).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

class PemantauPengingat extends ConsumerStatefulWidget {
  const PemantauPengingat({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PemantauPengingat> createState() => _PemantauPengingatState();
}

class _PemantauPengingatState extends ConsumerState<PemantauPengingat>
    with WidgetsBindingObserver {
  Timer? _tunda;
  ProviderSubscription<AsyncValue<List<dynamic>>>? _langganan;
  bool _sedangSinkron = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Sinkron saat pertama kali dibuka.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sinkron();
      _langganan = ref.listenManual(semuaTagihanProvider, (_, _) => _sinkronTertunda());
    });
  }

  @override
  void dispose() {
    _tunda?.cancel();
    _langganan?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Pekerja latar bisa mengubah data saat aplikasi tidak aktif:
      // baca ulang lalu segarkan jadwal.
      ref.invalidate(semuaTagihanProvider);
      _sinkron();
    }
  }

  void _sinkronTertunda() {
    _tunda?.cancel();
    _tunda = Timer(const Duration(seconds: 2), _sinkron);
  }

  Future<void> _sinkron() async {
    if (_sedangSinkron) return;
    _sedangSinkron = true;
    try {
      await ref.read(penyinkronPengingatProvider).sinkron();
    } catch (_) {
      // kegagalan sudah dicatat di jejak oleh penyinkron
    } finally {
      _sedangSinkron = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
