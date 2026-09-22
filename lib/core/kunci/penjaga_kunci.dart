/// FR-26 — Penjaga kunci: menahan tampilan aplikasi di belakang layar kunci.
///
/// Dipasang di [main.dart] membungkus seluruh aplikasi. Kunci HANYA muncul bila
/// pengguna menyalakannya di Pengaturan → Kunci aplikasi (bawaan: mati), jadi
/// pemasangan ini tidak mengubah apa pun bagi pengguna yang tidak memakainya.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// Dipakai layar Pengaturan untuk mengunci aplikasi SEKARANG (tanpa menunggu
/// ditinggal). Bukan state aplikasi — hanya pemicu sekali jalan.
final ValueNotifier<bool> paksaKunci = ValueNotifier<bool>(false);

/// Membungkus aplikasi; menampilkan [LayarKunci] bila kunci sedang aktif.
class PenjagaKunci extends ConsumerStatefulWidget {
  const PenjagaKunci({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PenjagaKunci> createState() => _PenjagaKunciState();
}

class _PenjagaKunciState extends ConsumerState<PenjagaKunci>
    with WidgetsBindingObserver {
  /// null = belum diperiksa; true = terkunci; false = terbuka.
  bool? _terkunci;
  DateTime? _keLatar;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    paksaKunci.addListener(_kunciSekarang);
    unawaited(_periksaAwal());
  }

  void _kunciSekarang() {
    if (paksaKunci.value && mounted) setState(() => _terkunci = true);
  }

  @override
  void dispose() {
    paksaKunci.removeListener(_kunciSekarang);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _periksaAwal() async {
    try {
      final aktif = await ref.read(kunciAplikasiProvider).aktif();
      if (!mounted) return;
      setState(() => _terkunci = aktif);
    } catch (_) {
      // Kunci tidak bisa dibaca (mis. basis data belum siap): jangan menahan
      // pengguna di layar kosong — buka saja, dan biarkan layar Pengaturan
      // melaporkan galatnya.
      if (mounted) setState(() => _terkunci = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState status) {
    if (status == AppLifecycleState.paused ||
        status == AppLifecycleState.inactive ||
        status == AppLifecycleState.hidden) {
      _keLatar ??= DateTime.now();
      return;
    }
    if (status == AppLifecycleState.resumed && _keLatar != null) {
      unawaited(_periksaSetelahLatar(_keLatar!));
      _keLatar = null;
    }
  }

  Future<void> _periksaSetelahLatar(DateTime sejak) async {
    final aktif = await ref.read(kunciAplikasiProvider).aktif();
    if (!aktif || !mounted) return;
    final tenggang = await ref.read(kunciAplikasiProvider).tenggangDetik();
    final lama = DateTime.now().difference(sejak).inSeconds;
    if (lama >= tenggang && mounted) {
      setState(() => _terkunci = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_terkunci == null) {
      // Pemeriksaan hanya satu pembacaan basis data (sangat singkat) — tahan
      // sebentar supaya isi aplikasi tidak sempat terlihat.
      return const ColoredBox(color: Colors.black, child: SizedBox.expand());
    }
    if (_terkunci == true) {
      return LayarKunci(
        onTerbuka: () => setState(() => _terkunci = false),
      );
    }
    return widget.child;
  }
}

/// Layar kunci: PIN + (bila diizinkan) kunci perangkat HP.
class LayarKunci extends ConsumerStatefulWidget {
  const LayarKunci({super.key, this.onTerbuka});

  /// Dipanggil begitu aplikasi boleh dibuka.
  final VoidCallback? onTerbuka;

  @override
  ConsumerState<LayarKunci> createState() => _LayarKunciState();
}

class _LayarKunciState extends ConsumerState<LayarKunci> {
  final TextEditingController _pin = TextEditingController();
  String? _pesan;
  bool _sibuk = false;
  bool _perangkatTersedia = false;

  @override
  void initState() {
    super.initState();
    unawaited(_periksaPerangkat());
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _periksaPerangkat() async {
    final kunci = ref.read(kunciAplikasiProvider);
    final izin = await kunci.bukaPerangkatAktif();
    var ada = false;
    if (izin) {
      ada = await ref.read(kunciPerangkatProvider).tersedia();
    }
    if (mounted) setState(() => _perangkatTersedia = izin && ada);
  }

  Future<void> _buka() async {
    if (_sibuk) return;
    setState(() => _sibuk = true);
    final hasil = await ref.read(kunciAplikasiProvider).buka(_pin.text);
    if (!mounted) return;
    setState(() {
      _sibuk = false;
      _pesan = hasil.pesan;
    });
    if (hasil.berhasil) {
      _pin.clear();
      widget.onTerbuka?.call();
    }
  }

  Future<void> _bukaDenganPerangkat() async {
    if (_sibuk) return;
    setState(() => _sibuk = true);
    final berhasil = await ref.read(kunciPerangkatProvider).buka();
    if (!mounted) return;
    setState(() {
      _sibuk = false;
      _pesan = berhasil
          ? 'Terbuka dengan kunci perangkat.'
          : 'Kunci perangkat tidak dipakai — masukkan PIN.';
    });
    if (berhasil) widget.onTerbuka?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 56),
                  const SizedBox(height: 12),
                  const Text(
                    'Aplikasi terkunci',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Masukkan PIN Anda untuk membuka Personal Life OS.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    key: const Key('pin_kunci'),
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 12,
                    autofocus: true,
                    enabled: !_sibuk,
                    onSubmitted: (_) => _buka(),
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('buka_kunci'),
                    onPressed: _sibuk ? null : _buka,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Buka'),
                  ),
                  if (_perangkatTersedia) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('buka_perangkat'),
                      onPressed: _sibuk ? null : _bukaDenganPerangkat,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Buka dengan kunci HP'),
                    ),
                  ],
                  if (_pesan != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _pesan!,
                      key: const Key('pesan_kunci'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
