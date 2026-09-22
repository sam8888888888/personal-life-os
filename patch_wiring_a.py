#!/usr/bin/env python3
"""Wiring batch 5 (FR-124…FR-127): rute, pintu masuk, pengingat, kekayaan bersih.

Idempoten — tiap sisipan diperiksa lebih dulu.
"""
import pathlib, sys

repo = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
b = lambda p: (repo / p).read_text(encoding="utf-8")
t = lambda p, s: (repo / p).write_text(s, encoding="utf-8")

# ---------------------------------------------------------- 1. import nganggur
p = "lib/features/rumah/form_aset_fisik_screen.dart"
s = b(p)
if "import '../../data/database/database.dart';\n" in s:
    s = s.replace("import '../../data/database/database.dart';\n", "", 1)
    t(p, s)
    print("OK: import database.dart yang tidak dipakai dibuang")

# ------------------------------------------------------------------- 2. router
p = "lib/app_router.dart"
s = b(p)
if "features/rumah/aset_fisik_screen.dart" not in s:
    anchor = "import 'features/dokumen/dokumen_form_screen.dart';"
    sisip = ("import 'features/rumah/aset_detail_screen.dart';\n"
             "import 'features/rumah/aset_fisik_screen.dart';\n"
             "import 'features/rumah/form_aset_fisik_screen.dart';\n")
    s = s.replace(anchor, sisip + anchor, 1)
    print("OK: import layar rumah ditambahkan")
if "path: '/rumah/aset'" not in s:
    anchor2 = """    GoRoute(
      path: '/dokumen',"""
    rute = """    // Home & Asset OS (FR-124…FR-127).
    GoRoute(
      path: '/rumah/aset',
      builder: (c, s) => const RumahAsetScreen(),
      routes: [
        GoRoute(
          path: 'form',
          builder: (c, s) => FormAsetFisikScreen(
            id: int.tryParse(s.uri.queryParameters['id'] ?? ''),
          ),
        ),
        GoRoute(
          path: ':id',
          builder: (c, s) =>
              AsetDetailScreen(id: int.parse(s.pathParameters['id']!)),
        ),
      ],
    ),
"""
    if anchor2 not in s:
        print("GAGAL: jangkar rute /dokumen tidak ditemukan"); sys.exit(1)
    s = s.replace(anchor2, rute + anchor2, 1)
    print("OK: rute /rumah/aset ditambahkan")
t(p, s)

# --------------------------------------------------- 3. pintu masuk tab Lainnya
p = "lib/features/hari_ini/lainnya_screen.dart"
s = b(p)
if "buka_aset" not in s:
    anchor = """                ListTile(
                  key: const Key('buka_notifikasi'),"""
    sisip = """                ListTile(
                  key: const Key('buka_aset'),
                  leading: const Icon(Icons.home_work_outlined),
                  title: const Text('Aset & Rumah'),
                  subtitle: const Text(
                      'Rumah, kendaraan, perangkat: beli, garansi, perawatan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/rumah/aset'),
                ),
                const Divider(height: 1),
"""
    if anchor not in s:
        print("GAGAL: jangkar buka_notifikasi tidak ditemukan"); sys.exit(1)
    s = s.replace(anchor, sisip + anchor, 1)
    t(p, s)
    print("OK: pintu masuk Aset & Rumah ditambahkan")
else:
    print("LEWAT: pintu masuk sudah ada")

# ------------------------------------------- 4. pengingat perawatan (dua isolate)
p = "lib/core/notifikasi/kerja_latar.dart"
s = b(p)
if "pengingat_perawatan.dart" not in s:
    anchor = "import '../../features/kesehatan/pengingat_obat_habis.dart';"
    s = s.replace(anchor,
                  "import '../../features/rumah/pengingat_perawatan.dart';\n" + anchor, 1)
    print("OK: impor pengingat perawatan ditambahkan")
if "SumberPengingatPerawatan()" not in s:
    anchor2 = """  RegistriSumberPengingat.daftarkan(SumberPengingatJanji());
}"""
    sisip2 = """  RegistriSumberPengingat.daftarkan(SumberPengingatJanji());
  // FR-125: jadwal perawatan aset (servis berkala, ganti oli, dsb).
  RegistriSumberPengingat.daftarkan(SumberPengingatPerawatan());
}"""
    jumlah = s.count(anchor2)
    if jumlah == 0:
        print("GAGAL: jangkar daftar sumber tidak ditemukan"); sys.exit(1)
    s = s.replace(anchor2, sisip2, jumlah)
    print("OK: sumber pengingat perawatan didaftarkan di %d tempat" % jumlah)
t(p, s)

# ------------------------------- 5. kekayaan bersih memakai harga beli aset fisik
p = "lib/data/repository/aset_repository.dart"
s = b(p)
if "hargaBeliSen" not in s:
    anchor = "    return baris?.nilaiSen ?? a.nilaiAwalSen;"
    baru = """    // FR-124: aset fisik (rumah/kendaraan/perangkat) sering belum punya nilai
    // bulanan. Harga beli dipakai sebagai nilai supaya aset fisik masuk
    // Kekayaan Bersih (FR-76) tanpa input ulang. Nilai bulanan tetap menang.
    final nilaiAwal = a.nilaiAwalSen != 0 ? a.nilaiAwalSen : (a.hargaBeliSen ?? 0);
    return baris?.nilaiSen ?? nilaiAwal;"""
    if anchor not in s:
        print("GAGAL: jangkar _nilaiAsetPada tidak ditemukan"); sys.exit(1)
    s = s.replace(anchor, baru, 1)
    t(p, s)
    print("OK: kekayaan bersih memakai harga beli aset fisik")
else:
    print("LEWAT: aset_repository sudah disesuaikan")
print("SELESAI wiring A")
