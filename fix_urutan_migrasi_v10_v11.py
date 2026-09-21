#!/usr/bin/env python3
"""PERBAIKAN PENTING (bug migrasi): blok migrasi v10 & v11 harus dijalankan
PALING AKHIR.

Kenapa: v10 menambah kolom `uid` pada tabel yang DIBUAT oleh migrasi v4/v5/v7/v9.
Kalau blok v10 dijalankan lebih dulu (seperti sebelumnya), basis data lama
(versi 2/3) belum punya tabel `visi` → `no such table: visi` dan migrasi gagal.
Ditemukan oleh uji migrasi (bukan diduga).

Idempoten.
"""
import pathlib
import sys

repo = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
p = repo / "lib/data/database/database.dart"
s = p.read_text(encoding="utf-8")

blok_v11 = """          if (dari < 11) {
            // v11 (FR-118): lampiran foto & rekaman suara pada catatan.
            if (!await _tabelAda('lampiran')) await m.createTable(lampiran);
            debugPrint('migrasi v11 selesai (tabel lampiran dibuat)');
          }
"""
blok_v10 = """          if (dari < 10) {
            // v10 (FR-150): pengenal `uid` untuk tabel lama + dua tabel
            // pendukung sinkron. Kolom baru bersifat nullable, jadi data
            // pengguna tidak tersentuh.
            await _buatTabelV10(m);
            debugPrint('migrasi v10 selesai (uid sinkron + tabel pendukung)');
          }
"""

if blok_v10 not in s or blok_v11 not in s:
    if s.index("_buatTabelV10") and "v5 selesai" in s:
        print("LEWAT: blok v10/v11 sudah di urutan akhir")
    else:
        raise SystemExit("GAGAL: blok v10/v11 tidak ditemukan")
else:
    # urutan akhir: v5 dulu, baru v10, baru v11
    s = s.replace(blok_v11, "", 1)
    s = s.replace(blok_v10, "", 1)
    jangkar = """            debugPrint('migrasi v5 selesai (visi & area hidup dibuat, '
                'kolom tujuan.area_id ditambahkan)');
          }
"""
    if jangkar not in s:
        raise SystemExit("GAGAL: jangkar akhir blok v5 tidak ditemukan")
    s = s.replace(jangkar, jangkar + blok_v10 + blok_v11, 1)
    p.write_text(s, encoding="utf-8")
    print("SELESAI: blok migrasi v10 & v11 dipindah ke urutan PALING AKHIR")
