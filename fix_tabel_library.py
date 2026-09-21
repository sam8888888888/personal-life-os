#!/usr/bin/env python3
"""PERBAIKAN PENTING: blok Lampiran yang ditempel ke tabel.dart membawa
`library;` + impor drift di TENGAH berkas → seluruh tabel tak terbaca dan
drift membuat skema KOSONG (database.g.dart jadi stub 19 baris, 2771 galat).
Buang direktif itu; sisakan kelasnya saja. Idempoten."""
import pathlib, sys
repo = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
p = repo / "lib/data/database/tabel.dart"
s = p.read_text(encoding="utf-8")
lama = "library;\n\nimport 'package:drift/drift.dart';\n\nclass Lampiran extends Table {"
baru = "class Lampiran extends Table {"
if lama in s:
    s = s.replace(lama, baru, 1)
    # pastikan library; tetap ada di baris awal
    if not s.lstrip().startswith("///") and "library;" not in s.split("\n")[0:5]:
        pass
    p.write_text(s, encoding="utf-8")
    print("SELESAI: library; di tengah tabel.dart dibuang")
else:
    print("LEWAT: tidak ada direktif di tengah")
