#!/usr/bin/env python3
"""Batch 3 — modul audit baru: 'pengetahuan' (FR-118…FR-123).

Ditambahkan ke daftar konstanta & daftar `semua` supaya saringan di layar audit
ikut memuatnya. Idempoten.
"""
from pathlib import Path

p = Path('/proyek/lib/core/audit/audit_log.dart')
s = p.read_text()
asli = s

if "pengetahuan = 'pengetahuan'" not in s:
    penanda = "  static const String ibadah = 'ibadah';\n"
    if penanda not in s:
        raise SystemExit('KONSTANTA: penanda tidak ditemukan')
    s = s.replace(penanda,
                  "  static const String ibadah = 'ibadah';\n"
                  "  static const String pengetahuan = 'pengetahuan';\n", 1)

if "\n    pengetahuan,\n" not in s:
    penanda2 = "    ibadah,\n    dokumen,\n"
    if penanda2 not in s:
        raise SystemExit('DAFTAR: penanda tidak ditemukan')
    s = s.replace(penanda2, "    ibadah,\n    pengetahuan,\n    dokumen,\n", 1)

if s != asli:
    p.write_text(s)
    print('SELESAI: modul audit pengetahuan ditambahkan')
else:
    print('TIDAK ADA PERUBAHAN (sudah ada)')
