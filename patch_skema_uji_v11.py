#!/usr/bin/env python3
"""Samakan harapan uji lama dengan skema terbaru (v11).

Skema memang naik:
  v10 = +2 tabel pendukung sinkron (sinkron_sidik, sinkron_tautan_belum) → 54
  v11 = +1 tabel lampiran (FR-118)                                   → 55

Bukan melunakkan uji: hanya angka versi/jumlah tabel; pemeriksaan perilaku
(migrasi berjalan, data lama selamat, kategori bawaan utuh) tetap apa adanya.
Idempoten.
"""
import pathlib
import re
import sys

repo = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")

# 1) v2_skema_test — versi skema terkini
p = repo / "test/v2_skema_test.dart"
s = p.read_text(encoding="utf-8")
s2 = re.sub(r"expect\(db\.schemaVersion, \d+\);", "expect(db.schemaVersion, 11);", s)
if s2 != s:
    p.write_text(s2, encoding="utf-8")
    print("  ✓ v2_skema_test: schemaVersion -> 11")

# 2) v15_migrasi_test — user_version setelah migrasi
p = repo / "test/v15_migrasi_test.dart"
s = p.read_text(encoding="utf-8")
s2 = re.sub(r"expect\(versi\.data\.values\.first, \d+\);",
            "expect(versi.data.values.first, 11);", s)
if s2 != s:
    p.write_text(s2, encoding="utf-8")
    print("  ✓ v15_migrasi_test: user_version -> 11")

# 3) backup_test — jumlah tabel di berkas cadangan
p = repo / "test/backup_test.dart"
s = p.read_text(encoding="utf-8")
s2 = re.sub(r"expect\(tabel\.length, \d+,", "expect(tabel.length, 55,", s)
s2 = re.sub(r"'= \d+ termasuk sqlite_sequence'", "'= 55 termasuk sqlite_sequence'", s2)
if s2 != s:
    p.write_text(s2, encoding="utf-8")
    print("  ✓ backup_test: jumlah tabel -> 55")

print("selesai")
