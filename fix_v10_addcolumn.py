#!/usr/bin/env python3
"""Perbaikan migrasi v10: ambil kolom uid lewat $columns (TableInfo tidak punya
getter uid). Idempoten."""
import pathlib, sys
repo = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
db = repo / "lib/data/database/database.dart"
s = db.read_text(encoding="utf-8")
lama = "      await m.addColumn(masuk.value, masuk.value.uid);"
baru = ("      final kolomUid = masuk.value.$columns\n"
        "          .firstWhere((k) => k.$name == 'uid');\n"
        "      await m.addColumn(masuk.value, kolomUid);")
if lama in s:
    s = s.replace(lama, baru, 1)
    db.write_text(s, encoding="utf-8")
    print("SELESAI: addColumn memakai $columns")
else:
    print("LEWAT: sudah diperbaiki")
