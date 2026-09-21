#!/usr/bin/env python3
"""Batch 3 (lanjutan) — pasang RUTE modul pengetahuan & 4 rute kesehatan.

Patch pertama melewatkan bagian ini karena pemeriksaan '/pengetahuan' sudah
bernilai benar gara-gara jalur impor 'features/pengetahuan/...'. Sekarang
pemeriksaannya memakai penanda jalur rute yang pasti.
"""
from pathlib import Path

router = Path('/proyek/lib/app_router.dart')
s = router.read_text()

AIR_BLOK = """        GoRoute(
          path: 'air',
          builder: (c, s) => const AirScreen(),
        ),
      ],
    ),
"""

AIR_BLOK_BARU = """        GoRoute(
          path: 'air',
          builder: (c, s) => const AirScreen(),
        ),
        GoRoute(
          path: 'makan',
          builder: (c, s) => const MakanScreen(),
        ),
        GoRoute(
          path: 'suasana',
          builder: (c, s) => const SuasanaScreen(),
        ),
        GoRoute(
          path: 'temuan',
          builder: (c, s) => const TemuanScreen(),
        ),
        GoRoute(
          path: 'laporan-bulanan',
          builder: (c, s) => const LaporanBulananScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/pengetahuan',
      builder: (c, s) => const PengetahuanHubScreen(),
      routes: [
        GoRoute(
          path: 'catatan',
          builder: (c, s) => const CatatanScreen(),
        ),
        GoRoute(
          path: 'keputusan',
          builder: (c, s) => const KeputusanScreen(),
        ),
        GoRoute(
          path: 'ulangan',
          builder: (c, s) => const UlanganScreen(),
        ),
        GoRoute(
          path: 'bacaan',
          builder: (c, s) => const BacaanScreen(),
        ),
        GoRoute(
          path: 'pembelajaran',
          builder: (c, s) => const PembelajaranScreen(),
        ),
        GoRoute(
          path: 'tautan',
          builder: (c, s) => const TautanScreen(),
        ),
      ],
    ),
"""

if "path: 'makan'" in s:
    print('TIDAK ADA PERUBAHAN (rute sudah ada)')
elif AIR_BLOK not in s:
    raise SystemExit('RUTE AIR: penanda tidak ditemukan')
else:
    s = s.replace(AIR_BLOK, AIR_BLOK_BARU, 1)
    router.write_text(s)
    print('SELESAI: 4 rute kesehatan + /pengetahuan terpasang')
