#!/usr/bin/env python3
"""Wiring C — FR-130 "Bagikan tersamar" di layar dokumen.

Aturan yang dijaga: teks yang dibagikan SELALU memakai nomor tersamar; berkas
asli hanya ikut bila pengguna mencentangnya sendiri DAN berkasnya benar-benar
ada. Dialog menampilkan pratinjau apa yang akan dikirim.
"""
import pathlib, sys

repo = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
p = repo / "lib/features/dokumen/dokumen_screen.dart"
s = p.read_text(encoding="utf-8")

if "bagikanTersamar" in s:
    print("LEWAT: tombol bagikan tersamar sudah ada")
    sys.exit(0)

# ------------------------------------------------------------------- 1. impor
if "import 'dart:io';" not in s:
    s = s.replace("import 'dart:async';",
                  "import 'dart:async';\nimport 'dart:io';", 1)
if "package:path_provider/path_provider.dart" not in s:
    s = s.replace("import 'package:flutter_riverpod/flutter_riverpod.dart';",
                  "import 'package:flutter_riverpod/flutter_riverpod.dart';\n"
                  "import 'package:path_provider/path_provider.dart';", 1)
if "core/dokumen/samar_dokumen.dart" not in s:
    s = s.replace("import '../../core/utils/tanggal_utils.dart';",
                  "import '../../core/dokumen/samar_dokumen.dart';\n"
                  "import '../../core/platform/bagikan.dart';\n"
                  "import '../../core/utils/tanggal_utils.dart';", 1)

# ------------------------------------------------------------------ 2. metode
anchor = """  Widget kartuBaris(DokumenData d) {"""
metode = '''  /// FR-130 — bagikan terkendali.
  ///
  /// Yang dibagikan adalah **teks dengan nomor disamarkan** (ditulis ke berkas
  /// .txt lalu dikirim lewat lembar berbagi Android). Berkas asli hanya ikut
  /// bila pengguna mencentang sendiri di dialog DAN berkasnya ditemukan.
  /// Tidak ada berkas terkirim tanpa aksi pengguna yang jelas.
  Future<void> bagikanTersamar(DokumenData d) async {
    var adaBerkas = false;
    String? jalurBerkas;
    try {
      final folder = await getApplicationDocumentsDirectory()
          .timeout(const Duration(seconds: 3));
      final nama = d.berkasNama?.trim() ?? '';
      if (nama.isNotEmpty) {
        final kandidat = File('${folder.path}/$nama');
        if (await kandidat.exists()) {
          adaBerkas = true;
          jalurBerkas = kandidat.path;
        }
      }
    } catch (_) {
      adaBerkas = false;
    }
    if (!mounted) return;

    var sertakanBerkas = false;
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) {
          final contoh = susunBagikanTersamar(
            nama: d.nama,
            jenisDokumen: labelJenisDokumen[d.jenis] ?? d.jenis,
            nomor: d.nomor,
            pemilik: d.pemilik,
            berlakuSampai: d.berlakuSampai,
            berkasNama: d.berkasNama,
            jalurBerkas: jalurBerkas,
            sertakanBerkas: sertakanBerkas,
          );
          return AlertDialog(
            key: const Key('dialog_bagikan_tersamar'),
            title: Text('Bagikan ${d.nama}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Yang dibagikan (nomor sudah disamarkan):'),
                  const SizedBox(height: 8),
                  Text(contoh.teks, key: const Key('pratinjau_bagikan')),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    key: const Key('centang_sertakan_berkas'),
                    value: sertakanBerkas,
                    onChanged: adaBerkas
                        ? (v) => setDialogState(() => sertakanBerkas = v ?? false)
                        : null,
                    title: const Text('Sertakan berkas asli'),
                    subtitle: Text(adaBerkas
                        ? 'Berkas ditemukan & akan ikut terkirim beserta nomor aslinya'
                        : 'Berkas aslinya tidak ada di perangkat ini'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                key: const Key('konfirmasi_bagikan'),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Bagikan'),
              ),
            ],
          );
        },
      ),
    );
    if (lanjut != true) return;

    final isi = susunBagikanTersamar(
      nama: d.nama,
      jenisDokumen: labelJenisDokumen[d.jenis] ?? d.jenis,
      nomor: d.nomor,
      pemilik: d.pemilik,
      berlakuSampai: d.berlakuSampai,
      berkasNama: d.berkasNama,
      jalurBerkas: jalurBerkas,
      sertakanBerkas: sertakanBerkas,
    );
    var berhasil = false;
    var berhasilBerkas = false;
    try {
      final folder = await getApplicationDocumentsDirectory()
          .timeout(const Duration(seconds: 3));
      final berkasTeks = File('${folder.path}/${namaBerkasBagikan(d.nama)}');
      await berkasTeks.writeAsString(isi.teks);
      berhasil = await bagikanBerkas(
        jalur: berkasTeks.path,
        judul: isi.judul,
        jenis: 'text/plain',
      );
      if (isi.berkasIkut && isi.jalurBerkas != null) {
        berhasilBerkas = await bagikanBerkas(
          jalur: isi.jalurBerkas!,
          judul: 'Berkas asli ${d.nama}',
          jenis: 'application/octet-stream',
        );
      }
    } catch (_) {
      berhasil = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      key: const Key('pesan_bagikan_tersamar'),
      content: Text(berhasil
          ? isi.berkasIkut
              ? 'Lembar berbagi dibuka: teks tersamar + berkas asli '
                  '${berhasilBerkas ? 'ikut terkirim' : 'gagal dikirim'}.'
              : 'Lembar berbagi dibuka: teks tersamar (berkas asli tidak ikut).'
          : 'Belum bisa membagikan di perangkat ini.'),
    ));
  }

'''
if anchor not in s:
    print("GAGAL: jangkar kartuBaris tidak ditemukan"); sys.exit(1)
s = s.replace(anchor, metode + anchor, 1)

# ------------------------------------------------------------------ 3. tombol
anchor2 = """                TextButton.icon(
                  key: Key('diperpanjang_${d.id}'),"""
tombol = """                TextButton.icon(
                  key: Key('bagikan_tersamar_${d.id}'),
                  onPressed: () => bagikanTersamar(d),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Bagikan tersamar'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
"""
if anchor2 not in s:
    print("GAGAL: jangkar tombol diperpanjang tidak ditemukan"); sys.exit(1)
s = s.replace(anchor2, tombol + anchor2, 1)
p.write_text(s, encoding="utf-8")
print("OK: FR-130 bagikan tersamar dipasang")
