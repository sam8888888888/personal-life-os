#!/usr/bin/env python3
"""Batch 3 — samakan harapan TIGA uji lama dengan skema yang baru (v9, 52 tabel).

Bukan melunakkan uji: skema memang naik dari v8 (44 tabel) ke v9 (52 tabel,
8 tabel modul Pengetahuan + catatan makan/suasana hati). Pemeriksaan lain
(data lama selamat, kategori bawaan, migrasi berjalan) TIDAK diubah.
"""
from pathlib import Path

# 1) v2_skema_test.dart — versi skema terkini
p1 = Path('/proyek/test/v2_skema_test.dart')
s1 = p1.read_text()
if 'expect(db.schemaVersion, 8);' in s1:
    s1 = s1.replace('expect(db.schemaVersion, 8);',
                    'expect(db.schemaVersion, 9);', 1)
    p1.write_text(s1)
    print('OK: v2_skema_test versions 8 -> 9')
else:
    print('LEWAT: v2_skema_test (sudah 9)')

# 2) v15_migrasi_test.dart — versi skema setelah migrasi
p2 = Path('/proyek/test/v15_migrasi_test.dart')
s2 = p2.read_text()
n2 = s2.count('expect(db.schemaVersion, 8);')
if n2:
    s2 = s2.replace('expect(db.schemaVersion, 8);',
                    'expect(db.schemaVersion, 9);')
    p2.write_text(s2)
    print(f'OK: v15_migrasi_test {n2} tempat 8 -> 9')
else:
    print('LEWAT: v15_migrasi_test (sudah 9)')

# 3) backup_test.dart — jumlah tabel di berkas cadangan
p3 = Path('/proyek/test/backup_test.dart')
s3 = p3.read_text()
if 'expect(tabel.length, 44,' in s3:
    s3 = s3.replace('expect(tabel.length, 44,',
                    'expect(tabel.length, 52,', 1)
    s3 = s3.replace("'= 44 termasuk sqlite_sequence'",
                    "'= 52 termasuk sqlite_sequence'")
    p3.write_text(s3)
    print('OK: backup_test 44 -> 52 tabel')
else:
    print('LEWAT: backup_test (sudah 52)')
