/// Layar masuk / daftar akun — pintu ke sinkron antar HP.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/akun/klien_akun.dart';
import '../../core/providers/akun_providers.dart';

class MasukScreen extends ConsumerStatefulWidget {
  const MasukScreen({super.key, this.mulaiDaftar = false});

  /// true = langsung membuka tab "Daftar".
  final bool mulaiDaftar;

  @override
  ConsumerState<MasukScreen> createState() => _MasukScreenState();
}

class _MasukScreenState extends ConsumerState<MasukScreen> {
  final _kunciForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _nama = TextEditingController();
  final _sandi = TextEditingController();
  late bool _daftar = widget.mulaiDaftar;
  bool _sibuk = false;
  String? _galat;

  @override
  void dispose() {
    _email.dispose();
    _nama.dispose();
    _sandi.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    if (!(_kunciForm.currentState?.validate() ?? false)) return;
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    final klien = ref.read(klienAkunProvider);
    final repo = ref.read(akunRepoProvider);
    try {
      final sesi = _daftar
          ? await klien.daftar(
              email: _email.text, nama: _nama.text, sandi: _sandi.text)
          : await klien.masuk(email: _email.text, sandi: _sandi.text);
      await repo.simpanSesi(sesi);
      ref.invalidate(sesiAkunProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil masuk sebagai ${sesi.email}.')),
      );
      Navigator.of(context).pop();
    } on AkunGagal catch (e) {
      setState(() => _galat = e.pesan);
    } catch (e) {
      setState(() => _galat = 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alamat = ref.watch(klienAkunProvider).alamat;
    return Scaffold(
      appBar: AppBar(title: Text(_daftar ? 'Daftar akun' : 'Masuk akun')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Satu akun untuk semua HP',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Masuk dengan akun yang sama di setiap HP, supaya isinya sama. '
                    'Data tetap tersimpan di HP — akun ini yang menyatukannya.',
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _kunciForm,
                    child: Column(
                      children: [
                        TextFormField(
                          key: const Key('akun_email'),
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Email belum diisi.';
                            if (!t.contains('@') || !t.contains('.')) {
                              return 'Alamat email belum benar.';
                            }
                            return null;
                          },
                        ),
                        if (_daftar) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('akun_nama'),
                            controller: _nama,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nama',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? 'Nama belum diisi.'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('akun_sandi'),
                          controller: _sandi,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Sandi (minimal 8 huruf/angka)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v ?? '').length < 8
                              ? 'Sandi minimal 8 huruf/angka.'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  if (_galat != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _galat!,
                      key: const Key('akun_galat'),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('akun_kirim'),
                    onPressed: _sibuk ? null : _kirim,
                    icon: _sibuk
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(_daftar ? 'Daftar & masuk' : 'Masuk'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('akun_ganti_mode'),
                    onPressed: _sibuk
                        ? null
                        : () => setState(() {
                              _daftar = !_daftar;
                              _galat = null;
                            }),
                    child: Text(_daftar
                        ? 'Sudah punya akun? Masuk di sini'
                        : 'Belum punya akun? Daftar di sini'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Server: $alamat',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
