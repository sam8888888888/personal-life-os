#!/usr/bin/env python3
"""Perbaikan patch v12: kolom `perawatan.aset_id` + fungsi `_buatTabelV12`.

Kenapa perlu diperbaiki: penjaga idempoten yang saya tulis tadi memakai pola
terlalu longgar ("get asetId") sehingga cocok dengan tabel LAIN
(`nilai_aset_bulanan.aset_id`) dan kolomnya tidak jadi ditambah; penjaga
"_buatTabelV12" juga cocok dengan pemanggilnya sehingga fungsinya tidak dibuat.
Pelajaran: penjaga idempoten harus memakai penanda yang UNIK.
"""
import pathlib, sys

repo = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
tabel = repo / "lib/data/database/tabel.dart"
db = repo / "lib/data/database/database.dart"
s = tabel.read_text(encoding="utf-8")
d = db.read_text(encoding="utf-8")

penanda = "Aset yang dirawat (FR-125)"
if penanda not in s:
    anchor = """  /// Lead days notifikasi, teks "7,1".
  TextColumn get leadHari => text().withDefault(const Constant('7,1'))();"""
    if anchor not in s:
        print("GAGAL: jangkar lead_hari tidak ditemukan"); sys.exit(1)
    sisip = """  /// Aset yang dirawat (FR-125). null = perawatan lepas (tidak terikat aset).
  IntColumn get asetId => integer().nullable()();

"""
    s = s.replace(anchor, sisip + anchor, 1)
    tabel.write_text(s, encoding="utf-8")
    print("OK: perawatan.aset_id ditambahkan")
else:
    print("LEWAT: perawatan.aset_id sudah ada")

if "Future<void> _buatTabelV12" not in d:
    anchor2 = "  /// Cek keberadaan kolom (PRAGMA) — dipakai migrasi agar aman dijalankan ulang."
    if anchor2 not in d:
        print("GAGAL: jangkar _kolomAda tidak ditemukan"); sys.exit(1)
    fungsi = """  /// Skema v12 (FR-124…FR-127): aset fisik + riwayat perawatan berbiaya.
  ///
  /// Aman dijalankan ulang: tabel lewat `_tabelAda`, kolom lewat `_kolomAda`
  /// (PRAGMA). Sebagian basis data lama dibuat dari definisi tabel terbaru,
  /// jadi tanpa pemeriksaan itu `addColumn` bisa meledak `duplicate column
  /// name` dan update aplikasi di HP gagal.
  Future<void> _buatTabelV12(Migrator m) async {
    if (!await _tabelAda('riwayat_perawatan_aset')) {
      await m.createTable(riwayatPerawatanAset);
    }
    final Map<String, TableInfo<Table, dynamic>> tabelSasaran = {
      'aset': aset,
      'perawatan': perawatan,
    };
    const Map<String, List<String>> kolomPerlu = {
      'aset': [
        'nomor_seri',
        'tanggal_beli',
        'harga_beli_sen',
        'garansi_sampai',
        'masa_pakai_bulan',
        'lokasi',
      ],
      'perawatan': ['aset_id'],
    };
    for (final masuk in tabelSasaran.entries) {
      for (final namaKolom in kolomPerlu[masuk.key] ?? const <String>[]) {
        if (await _kolomAda(masuk.key, namaKolom)) continue;
        final kolom = masuk.value.$columns
            .firstWhere((k) => k.$name == namaKolom);
        await m.addColumn(masuk.value, kolom);
      }
    }
  }

"""
    d = d.replace(anchor2, fungsi + anchor2, 1)
    db.write_text(d, encoding="utf-8")
    print("OK: fungsi _buatTabelV12 ditambahkan")
else:
    print("LEWAT: fungsi _buatTabelV12 sudah ada")
print("SELESAI perbaikan v12")
