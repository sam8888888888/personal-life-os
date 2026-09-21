#!/usr/bin/env python3
"""Batch 3 (lanjutan) — v15_migrasi_test: PRAGMA user_version 8 -> 9.

Skema memang naik ke v9 (8 tabel modul Pengetahuan + catatan makan/suasana
hati). Pemeriksaan lain (data lama utuh, kategori bawaan, tabel pilar ada)
TIDAK diubah. Idempoten.
"""
from pathlib import Path

p = Path('/proyek/test/v15_migrasi_test.dart')
s = p.read_text()

if "expect(versi.data.values.first, 8);" in s:
    s = s.replace("expect(versi.data.values.first, 8);",
                  "expect(versi.data.values.first, 9);", 1)
    s = s.replace("""    //    v2 -> v3 -> v4 -> v5 (v4 menambah 23 tabel pilar kehidupan, v5
    //    menambah visi & area hidup + kolom tujuan.area_id).""",
"""    //    v2 -> v3 -> v4 -> v5 -> v6 -> v7 -> v8 -> v9 (v4 menambah 23 tabel
    //    pilar kehidupan, v5 visi & area hidup + tujuan.area_id, v6-v8 tabel
    //    kesehatan/dokumen/sinkron, v9 delapan tabel modul Pengetahuan).""")
    p.write_text(s)
    print('SELESAI: user_version 8 -> 9 (v15_migrasi_test)')
else:
    print('TIDAK ADA PERUBAHAN (sudah 9)')
