#!/usr/bin/env python3
"""Batch 3 (lanjutan 2) — impor layar kesehatan baru + rute memakai nama kelas
yang sudah dibedakan dari layar modul laporan yang lama.

Nama kelas diubah supaya tidak bentrok dengan layar lama
`features/laporan/laporan_bulanan_screen.dart`:
  MakanScreen              -> MakanRingkasScreen
  SuasanaScreen            -> SuasanaHatiScreen
  TemuanScreen             -> TemuanKesehatanScreen
  LaporanBulananScreen     -> LaporanKesehatanBulananScreen
Idempoten.
"""
from pathlib import Path

router = Path('/proyek/lib/app_router.dart')
s = router.read_text()
asli = s

IMPOR = """import 'features/kesehatan/tidur_screen.dart';
"""
IMPOR_BARU = """import 'features/kesehatan/tidur_screen.dart';
import 'features/kesehatan/makan_screen.dart' show MakanRingkasScreen;
import 'features/kesehatan/suasana_screen.dart' show SuasanaHatiScreen;
import 'features/kesehatan/temuan_screen.dart' show TemuanKesehatanScreen;
import 'features/kesehatan/laporan_kesehatan_bulanan_screen.dart'
    show LaporanKesehatanBulananScreen;
"""
if 'MakanRingkasScreen' not in s:
    if IMPOR not in s:
        raise SystemExit('IMPOR: penanda tidak ditemukan')
    s = s.replace(IMPOR, IMPOR_BARU, 1)

ganti = [
    ("builder: (c, s) => const MakanScreen(),",
     "builder: (c, s) => const MakanRingkasScreen(),"),
    ("builder: (c, s) => const SuasanaScreen(),",
     "builder: (c, s) => const SuasanaHatiScreen(),"),
    ("builder: (c, s) => const TemuanScreen(),",
     "builder: (c, s) => const TemuanKesehatanScreen(),"),
    ("""        GoRoute(
          path: 'laporan-bulanan',
          builder: (c, s) => const LaporanBulananScreen(),
        ),""",
     """        GoRoute(
          path: 'laporan-bulanan',
          builder: (c, s) => const LaporanKesehatanBulananScreen(),
        ),"""),
]
for lama, baru in ganti:
    if lama in s:
        s = s.replace(lama, baru, 1)

if s != asli:
    router.write_text(s)
    print('SELESAI: impor & rute kesehatan diperbarui')
else:
    print('TIDAK ADA PERUBAHAN (sudah benar)')
