#!/usr/bin/env python3
"""FR-27 — sinkron lewat BERKAS (tanpa server), pintu di layar Akun & Sinkron.

Idempoten. Yang dipasang:
- kartu "Sinkron lewat berkas" dengan tombol Ekspor (lalu dibagikan lewat
  lembar berbagi Android) & Impor (pemilih berkas Android),
- metode _eksporBerkas / _imporBerkas di layar.
"""
import pathlib
import sys

repo = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
layar = repo / "lib/features/akun/akun_screen.dart"
s = layar.read_text(encoding="utf-8")

if "_eksporBerkas" in s:
    print("  – kanal berkas sudah terpasang")
    raise SystemExit(0)

# 1. impor tambahan
if "package:path_provider/path_provider.dart" not in s:
    s = s.replace("import 'package:flutter_riverpod/flutter_riverpod.dart';",
                  "import 'package:flutter/services.dart';\n"
                  "import 'package:flutter_riverpod/flutter_riverpod.dart';\n"
                  "import 'package:path_provider/path_provider.dart';", 1)
if "kanal_media.dart" not in s:
    s = s.replace("import 'provider_akun.dart';",
                  "import '../../core/platform/kanal_media.dart';\nimport 'provider_akun.dart';", 1) \
        if "import 'provider_akun.dart';" in s else s
    if "kanal_media.dart" not in s:
        # jatuhkan ke impor relatif yang pasti ada
        s = s.replace("import '../../core/providers/app_providers.dart';",
                      "import '../../core/platform/kanal_media.dart';\n"
                      "import '../../core/providers/app_providers.dart';", 1)

# 2. metode di kelas state
jangkar = "  Future<void> _sinkronSekarang() async {"
if jangkar not in s:
    raise SystemExit("GAGAL: jangkar _sinkronSekarang tidak ditemukan")
sisip = """  /// FR-27 — ekspor seluruh data ke satu berkas, lalu tawarkan dibagikan
  /// (WhatsApp/Drive/USB pilihan Papi). Tidak butuh server.
  Future<void> _eksporBerkas() async {
    if (!mounted) return;
    setState(() {
      _menyinkron = true;
      _hasilSinkron = null;
    });
    try {
      final folder = await getApplicationDocumentsDirectory();
      final stempel = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final berkas = File('${folder.path}/sinkron-lifeos-$stempel.json');
      final jumlah = await ref.read(sinkronSemuaProvider).eksporBerkas(berkas);
      try {
        await const MethodChannel('lifeos/bagikan').invokeMethod<bool>('bagikan', {
          'jalur': berkas.path,
          'judul': 'Berkas sinkron Personal Life OS',
          'jenis': 'application/json',
        });
      } catch (_) {
        // Tanpa aplikasi berbagi (atau bukan Android): berkasnya tetap ada.
      }
      if (mounted) {
        setState(() => _hasilSinkron =
            'Berkas sinkron dibuat ($jumlah baris):\\n${berkas.path}');
      }
    } catch (e) {
      if (mounted) setState(() => _hasilSinkron = 'Gagal mengekspor: $e');
    } finally {
      if (mounted) setState(() => _menyinkron = false);
    }
  }

  /// FR-27 — masukkan berkas sinkron (dari HP lain) ke HP ini.
  Future<void> _imporBerkas() async {
    if (!mounted) return;
    setState(() {
      _menyinkron = true;
      _hasilSinkron = null;
    });
    try {
      final jalur = await KanalMedia().pilihBerkas(mime: 'application/json');
      if (jalur == null || jalur.isEmpty) {
        if (mounted) setState(() => _hasilSinkron = 'Batal memilih berkas.');
        return;
      }
      final jumlah =
          await ref.read(sinkronSemuaProvider).imporBerkas(File(jalur));
      if (mounted) {
        setState(() => _hasilSinkron = 'Berkas dimasukkan: $jumlah baris.');
      }
    } catch (e) {
      if (mounted) setState(() => _hasilSinkron = 'Gagal memasukkan berkas: $e');
    } finally {
      if (mounted) setState(() => _menyinkron = false);
    }
  }

"""
s = s.replace(jangkar, sisip + jangkar, 1)

# 3. kartu di layar (sebelum kartu "Keadaan sinkron")
jangkar2 = """                    const Text(
                      'Sinkron SELURUH MODUL sudah aktif"""
kartu = """                    Text('Sinkron lewat berkas (tanpa server)',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text(
                      'Tanpa server: seluruh data ditulis ke satu berkas, lalu '
                      'bisa Papi kirim sendiri (WhatsApp/Drive/USB) ke HP lain '
                      'dan dimasukkan lewat tombol Impor.',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          key: const Key('ekspor_berkas_sinkron'),
                          onPressed: _menyinkron ? null : _eksporBerkas,
                          icon: const Icon(Icons.ios_share),
                          label: const Text('Ekspor berkas'),
                        ),
                        OutlinedButton.icon(
                          key: const Key('impor_berkas_sinkron'),
                          onPressed: _menyinkron ? null : _imporBerkas,
                          icon: const Icon(Icons.file_open_outlined),
                          label: const Text('Impor berkas'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
"""
if jangkar2 in s:
    s = s.replace(jangkar2, kartu + jangkar2, 1)
    print("  ✓ kartu 'Sinkron lewat berkas' dipasang")
else:
    print("  ! jangkar kartu tidak ditemukan — periksa manual")

layar.write_text(s, encoding="utf-8")
print("selesai")
