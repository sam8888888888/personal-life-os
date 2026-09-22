/// FR-26 — Layar pengaturan kunci aplikasi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/kunci/kunci_aplikasi.dart';
import '../../core/kunci/penjaga_kunci.dart';
import '../../core/providers/app_providers.dart';

class KunciScreen extends ConsumerStatefulWidget {
  const KunciScreen({super.key});

  @override
  ConsumerState<KunciScreen> createState() => _KunciScreenState();
}

class _KunciScreenState extends ConsumerState<KunciScreen> {
  final TextEditingController _pinBaru = TextEditingController();
  final TextEditingController _pinUlang = TextEditingController();
  final TextEditingController _pinLama = TextEditingController();
  String? _pesan;
  bool _sibuk = false;

  @override
  void dispose() {
    _pinBaru.dispose();
    _pinUlang.dispose();
    _pinLama.dispose();
    super.dispose();
  }

  KunciAplikasi get _kunci => ref.read(kunciAplikasiProvider);

  Future<void> _pasang() async {
    final keluhan = KunciAplikasi.keluhanPin(_pinBaru.text);
    if (keluhan != null) {
      setState(() => _pesan = keluhan);
      return;
    }
    if (_pinBaru.text != _pinUlang.text) {
      setState(() => _pesan = 'Dua isian PIN tidak sama.');
      return;
    }
    setState(() => _sibuk = true);
    final bukaPerangkat = ref.read(bukaPerangkatProvider).value ?? false;
    await _kunci.pasangPin(_pinBaru.text, bukaPerangkat: bukaPerangkat);
    if (!mounted) return;
    _pinBaru.clear();
    _pinUlang.clear();
    setState(() {
      _sibuk = false;
      _pesan = 'Kunci dipasang. Aplikasi akan meminta PIN saat dibuka.';
    });
    ref.invalidate(kunciAktifProvider);
  }

  Future<void> _gantiPin() async {
    final keluhan = KunciAplikasi.keluhanPin(_pinBaru.text);
    if (keluhan != null) {
      setState(() => _pesan = keluhan);
      return;
    }
    if (_pinBaru.text != _pinUlang.text) {
      setState(() => _pesan = 'Dua isian PIN baru tidak sama.');
      return;
    }
    setState(() => _sibuk = true);
    final hasil = await _kunci.buka(_pinLama.text);
    if (!hasil.berhasil) {
      if (mounted) {
        setState(() {
          _sibuk = false;
          _pesan = 'PIN lama salah. ${hasil.pesan ?? ''}'.trim();
        });
      }
      return;
    }
    final bukaPerangkat = ref.read(bukaPerangkatProvider).value ?? false;
    await _kunci.pasangPin(_pinBaru.text, bukaPerangkat: bukaPerangkat);
    if (!mounted) return;
    _pinBaru.clear();
    _pinUlang.clear();
    _pinLama.clear();
    setState(() {
      _sibuk = false;
      _pesan = 'PIN diganti.';
    });
  }

  Future<void> _matikan() async {
    setState(() => _sibuk = true);
    final hasil = await _kunci.buka(_pinLama.text);
    if (!hasil.berhasil) {
      if (mounted) {
        setState(() {
          _sibuk = false;
          _pesan = 'PIN salah — kunci tidak dimatikan.';
        });
      }
      return;
    }
    await _kunci.matikan();
    if (!mounted) return;
    _pinLama.clear();
    setState(() {
      _sibuk = false;
      _pesan = 'Kunci dimatikan. Aplikasi terbuka tanpa PIN.';
    });
    ref.invalidate(kunciAktifProvider);
  }

  Future<void> _kunciSekarang() async {
    paksaKunci.value = true;
    paksaKunci.value = false;
    if (mounted) {
      setState(() => _pesan =
          'Aplikasi dikunci sekarang. Masukkan PIN untuk membuka.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final aktif = ref.watch(kunciAktifProvider).value ?? false;
    final bukaPerangkat = ref.watch(bukaPerangkatProvider).value ?? false;
    final tenggang = ref.watch(tenggangKunciProvider).value ?? kunciTenggangBawaan;
    return Scaffold(
      appBar: AppBar(title: const Text('Kunci aplikasi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            aktif
                ? 'Kunci sedang aktif. Aplikasi meminta PIN setiap dibuka.'
                : 'Kunci belum aktif. Data Anda terbuka bagi siapa pun yang '
                    'memegang HP ini.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Yang perlu Anda tahu: kunci ini menahan tampilan aplikasi. '
            'Basis data di perangkat tidak disandikan — pada HP yang di-root, '
            'berkasnya masih bisa dibaca. Kunci ini mencegah orang lain '
            'membuka aplikasi Anda, bukan menggantikan enkripsi HP.',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
          const Divider(height: 32),
          if (!aktif) ...[
            const Text('Pasang kunci',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pin_baru'),
              controller: _pinBaru,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: kunciPanjangMaks,
              decoration: const InputDecoration(
                labelText: 'PIN baru (4–12 angka)',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('pin_ulang'),
              controller: _pinUlang,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: kunciPanjangMaks,
              decoration: const InputDecoration(
                labelText: 'Ulangi PIN baru',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('pasang_kunci'),
              onPressed: _sibuk ? null : _pasang,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Pasang kunci'),
            ),
          ] else ...[
            const Text('Ganti PIN atau matikan kunci',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pin_lama'),
              controller: _pinLama,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: kunciPanjangMaks,
              decoration: const InputDecoration(
                labelText: 'PIN lama',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('pin_baru'),
              controller: _pinBaru,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: kunciPanjangMaks,
              decoration: const InputDecoration(
                labelText: 'PIN baru',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('pin_ulang'),
              controller: _pinUlang,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: kunciPanjangMaks,
              decoration: const InputDecoration(
                labelText: 'Ulangi PIN baru',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('ganti_kunci'),
              onPressed: _sibuk ? null : _gantiPin,
              icon: const Icon(Icons.password),
              label: const Text('Ganti PIN'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('matikan_kunci'),
              onPressed: _sibuk ? null : _matikan,
              icon: const Icon(Icons.lock_open),
              label: const Text('Matikan kunci'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('kunci_sekarang'),
              onPressed: _sibuk ? null : _kunciSekarang,
              icon: const Icon(Icons.info_outline),
              label: const Text('Kapan aplikasi terkunci?'),
            ),
          ],
          const Divider(height: 32),
          SwitchListTile(
            key: const Key('saklar_kunci_perangkat'),
            value: bukaPerangkat,
            onChanged: (v) async {
              await _kunci.setBukaPerangkat(v);
              ref.invalidate(bukaPerangkatProvider);
              ref.invalidate(kunciPerangkatTersediaProvider);
              if (mounted) {
                setState(() => _pesan = v
                    ? 'Aplikasi boleh dibuka dengan kunci HP (sidik jari/PIN '
                        'perangkat) bila HP mendukung.'
                    : 'Aplikasi hanya bisa dibuka dengan PIN aplikasi.');
              }
            },
            title: const Text('Boleh dibuka dengan kunci HP'),
            subtitle: Text(ref.watch(kunciPerangkatTersediaProvider).value ?? false
                ? 'HP ini punya kunci perangkat.'
                : 'HP ini belum punya kunci perangkat — pilihan ini tidak bisa dipakai.'),
          ),
          const SizedBox(height: 8),
          const Text('Kunci lagi setelah ditinggal',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final pilihan in const [
                (0, 'Langsung'),
                (30, '30 detik'),
                (60, '1 menit'),
                (300, '5 menit'),
              ])
                ChoiceChip(
                  key: Key('tenggang_${pilihan.$1}'),
                  label: Text(pilihan.$2),
                  selected: tenggang == pilihan.$1,
                  onSelected: (_) async {
                    await _kunci.simpanTenggang(pilihan.$1);
                    ref.invalidate(tenggangKunciProvider);
                  },
                ),
            ],
          ),
          if (_pesan != null) ...[
            const SizedBox(height: 16),
            Text(_pesan!, key: const Key('pesan_kunci_pengaturan')),
          ],
        ],
      ),
    );
  }
}
