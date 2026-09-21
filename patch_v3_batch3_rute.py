#!/usr/bin/env python3
"""Batch 3 — pasang rute & pintu masuk:
   - /kesehatan/makan, /kesehatan/suasana, /kesehatan/temuan,
     /kesehatan/laporan-bulanan
   - /pengetahuan + 6 sub-rute
   - tab "Lainnya" ikut menyala saat berada di modul pengetahuan
   - 4 pintu baru di dasbor kesehatan
Idempoten: bagian yang sudah ada dilewati.
"""
from pathlib import Path

# ------------------------------------------------------------------ router
router = Path('/proyek/lib/app_router.dart')
s = router.read_text()
asli = s

IMPOR = """import 'features/kesehatan/aktivitas_screen.dart';
import 'features/kesehatan/air_screen.dart';
"""
IMPOR_BARU = """import 'features/kesehatan/aktivitas_screen.dart';
import 'features/kesehatan/air_screen.dart';
import 'features/kesehatan/laporan_bulanan_screen.dart';
import 'features/kesehatan/makan_screen.dart';
import 'features/kesehatan/suasana_screen.dart';
import 'features/kesehatan/temuan_screen.dart';
"""
if 'laporan_bulanan_screen.dart' not in s:
    if IMPOR not in s:
        raise SystemExit('IMPOR: penanda tidak ditemukan')
    s = s.replace(IMPOR, IMPOR_BARU, 1)

IMPOR_PENGETAHUAN = """import 'features/obat/obat_bagian.dart';
"""
# Modul pengetahuan: impor diletakkan sebelum impor pertama 'features/p' agar urut.
if 'pengetahuan_hub_screen.dart' not in s:
    penanda = "import 'features/kesehatan/tidur_screen.dart';\n"
    if penanda not in s:
        raise SystemExit('IMPOR TIDUR: penanda tidak ditemukan')
    tambahan = penanda + """import 'features/pengetahuan/bacaan_screen.dart';
import 'features/pengetahuan/catatan_screen.dart';
import 'features/pengetahuan/keputusan_screen.dart';
import 'features/pengetahuan/pembelajaran_screen.dart';
import 'features/pengetahuan/pengetahuan_hub_screen.dart';
import 'features/pengetahuan/tautan_screen.dart';
import 'features/pengetahuan/ulangan_screen.dart';
"""
    s = s.replace(penanda, tambahan, 1)

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
if "/pengetahuan" not in s:
    if AIR_BLOK not in s:
        raise SystemExit('RUTE AIR: penanda tidak ditemukan')
    s = s.replace(AIR_BLOK, AIR_BLOK_BARU, 1)

GRUP = """      '/kesehatan',
      '/dokumen',
"""
GRUP_BARU = """      '/kesehatan',
      '/dokumen',
      '/pengetahuan',
"""
if "'/pengetahuan'," not in s:
    if GRUP not in s:
        raise SystemExit('GRUP: penanda tidak ditemukan')
    s = s.replace(GRUP, GRUP_BARU, 1)

if s != asli:
    router.write_text(s)
    print('SELESAI: router dipasang')
else:
    print('TIDAK ADA PERUBAHAN (router sudah dipasang)')

# --------------------------------------------------- pintu di hub kesehatan
hub = Path('/proyek/lib/features/kesehatan/kesehatan_hub_screen.dart')
h = hub.read_text()
asli_h = h
if 'buka_makan' not in h:
    penanda = """                        tujuan: '/kesehatan/air',
                      ),
                    ],
"""
    if penanda not in h:
        raise SystemExit('HUB: penanda tidak ditemukan')
    ganti = """                        tujuan: '/kesehatan/air',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_makan',
                        ikon: Icons.restaurant_outlined,
                        judul: 'Catatan makan',
                        keterangan: 'Catat cepat, daftar sederhana (FR-110)',
                        tujuan: '/kesehatan/makan',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_suasana',
                        ikon: Icons.mood_outlined,
                        judul: 'Suasana hati & stres',
                        keterangan: 'Suasana hati, energi & stres 1–5 (FR-112)',
                        tujuan: '/kesehatan/suasana',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_temuan',
                        ikon: Icons.insights_outlined,
                        judul: 'Temuan dari catatan Anda',
                        keterangan: 'Pola dari angka yang Anda catat sendiri (FR-113)',
                        tujuan: '/kesehatan/temuan',
                      ),
                      const Divider(height: 1),
                      _pintu(
                        kunci: 'buka_laporan_bulanan',
                        ikon: Icons.summarize_outlined,
                        judul: 'Laporan bulanan',
                        keterangan: 'Perubahan berat, tidur, air & suasana (FR-116)',
                        tujuan: '/kesehatan/laporan-bulanan',
                      ),
                    ],
"""
    h = h.replace(penanda, ganti, 1)

if h != asli_h:
    hub.write_text(h)
    print('SELESAI: 4 pintu baru di hub kesehatan')
else:
    print('TIDAK ADA PERUBAHAN (pintu hub sudah ada)')
