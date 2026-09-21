#!/usr/bin/env python3
"""Batch 3 — tambahan kolom agar sesuai rincian PRD:
   FR-110 Catatan Makan : mutu (baik/cukup/kurang)
   FR-119 Jurnal Keputusan : risiko, biaya
Idempoten: dilewati bila kolom sudah ada.
"""
from pathlib import Path

tabel = Path('/proyek/lib/data/database/tabel.dart')
s = tabel.read_text()
asli = s

# FR-110 — penilaian mutu oleh pengguna sendiri
if 'mutu => text()' not in s:
    s = s.replace(
        """class CatatanMakan extends Table {
  IntColumn get id => integer().autoIncrement()();""",
        """class CatatanMakan extends Table {
  IntColumn get id => integer().autoIncrement()();""",
    )
    penanda = """  TextColumn get porsi => text().nullable()();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get waktu => dateTime()();"""
    ganti = """  TextColumn get porsi => text().nullable()();
  /// Penilaian pengguna sendiri: baik / cukup / kurang (boleh kosong).
  TextColumn get mutu => text().nullable()();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get waktu => dateTime()();"""
    if penanda not in s:
        raise SystemExit('CATATAN_MAKAN: penanda tidak ditemukan')
    s = s.replace(penanda, ganti, 1)

# FR-119 — risiko & biaya yang dipertimbangkan
if 'risiko => text()' not in s:
    penanda2 = """  TextColumn get harapan => text().nullable()();"""
    ganti2 = """  TextColumn get harapan => text().nullable()();
  /// Risiko yang disadari saat memutuskan (boleh kosong).
  TextColumn get risiko => text().nullable()();
  /// Biaya/ongkos yang disadari saat memutuskan, ditulis bebas (boleh kosong).
  TextColumn get biaya => text().nullable()();"""
    if penanda2 not in s:
        raise SystemExit('KEPUTUSAN: penanda tidak ditemukan')
    s = s.replace(penanda2, ganti2, 1)

if s == asli:
    print('TIDAK ADA PERUBAHAN (kolom sudah ada)')
else:
    tabel.write_text(s)
    print('SELESAI: kolom mutu/risiko/biaya ditambahkan')
