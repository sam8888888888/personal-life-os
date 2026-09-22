#!/usr/bin/env python3
"""Skema v12 — Home & Asset OS (FR-124/125/126/127).

Ringkas:
- `aset` diberi kolom aset FISIK: nomor seri, tanggal beli, harga beli,
  garansi sampai, masa pakai (bulan), lokasi. Semua NULLABLE → baris lama
  tidak berubah dan tidak butuh nilai awal.
  Kenapa di tabel `aset` yang sudah ada, bukan tabel baru: PRD FR-124 meminta
  total nilai aset fisik masuk ke kekayaan bersih (FR-76) TANPA input ulang.
- `perawatan` diberi kolom `aset_id` (nullable) → jadwal servis bisa diikat ke
  satu aset (FR-125) tanpa mesin pengingat baru (mesin FR-83 sudah ada).
- Tabel baru `riwayat_perawatan_aset`: riwayat perbaikan + biaya, dengan
  `transaksi_id` opsional supaya biaya bisa dikaitkan ke pengeluaran nyata.

Idempoten: setiap penambahan diperiksa lebih dulu (`_kolomAda`, `_tabelAda`).

Penting (pelajaran 22 Sep): blok migrasi v12 WAJIB diletakkan SETELAH semua
blok lama — kalau tidak, basis data lama gagal dengan `no such table`.
"""
import pathlib, sys, re

repo = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
tabel = repo / "lib/data/database/tabel.dart"
db = repo / "lib/data/database/database.dart"
s = tabel.read_text(encoding="utf-8")
d = db.read_text(encoding="utf-8")

# ---------------------------------------------------------------- tabel.dart
anchor_arsip = """  /// true = disembunyikan; riwayat nilai tetap ada. Dipakai sebagai ganti
  /// hapus selama riwayat masih ada (keputusan rancangan §4.6).
  BoolColumn get arsip => boolean().withDefault(const Constant(false))();
"""
kolom_aset = """
  // --- Aset fisik (FR-124/126/127, skema v12) ---------------------------
  // Semua nullable: aset keuangan lama (kas/bank/investasi) tidak punya
  // kolom ini dan tidak dipaksa mengisinya.
  /// Nomor seri / nomor rangka / nomor polisi. Dipakai saat klaim garansi.
  TextColumn get nomorSeri => text().nullable()();
  /// Tanggal beli — dasar hitungan umur pakai (FR-127).
  DateTimeColumn get tanggalBeli => dateTime().nullable()();
  /// Harga beli (sen). Dipakai sebagai nilai aset bila belum ada nilai bulanan.
  IntColumn get hargaBeliSen => integer().nullable()();
  /// Tanggal garansi berakhir (FR-126).
  DateTimeColumn get garansiSampai => dateTime().nullable()();
  /// Perkiraan masa pakai dalam bulan (FR-127).
  IntColumn get masaPakaiBulan => integer().nullable()();
  /// Lokasi/penempatan aset, mis. "Rumah Surabaya".
  TextColumn get lokasi => text().nullable()();
"""
if "nomorSeri" not in s:
    if anchor_arsip not in s:
        print("GAGAL: jangkar kolom arsip aset tidak ditemukan"); sys.exit(1)
    s = s.replace(anchor_arsip, anchor_arsip + kolom_aset, 1)
    print("OK: kolom aset fisik ditambahkan")
else:
    print("LEWAT: kolom aset fisik sudah ada")

anchor_lead = """  /// Lead days notifikasi, teks "7,1".
  TextColumn get leadHari => text().withDefault(const Constant('7,1'))();"""
kolom_perawatan = """  /// Aset yang dirawat (FR-125). null = perawatan lepas (tidak terikat aset).
  IntColumn get asetId => integer().nullable()();

"""
if "get asetId" not in s:
    if anchor_lead not in s:
        print("GAGAL: jangkar lead_hari perawatan tidak ditemukan"); sys.exit(1)
    s = s.replace(anchor_lead, kolom_perawatan + anchor_lead, 1)
    print("OK: kolom perawatan.aset_id ditambahkan")
else:
    print("LEWAT: kolom perawatan.aset_id sudah ada")

tabel_baru = """

/// Riwayat perawatan/perbaikan aset — FR-125.
///
/// Dipisah dari [Perawatan] (yang menyimpan JADWAL) karena riwayat bisa
/// banyak baris per aset dan menyimpan biaya. `transaksiId` opsional mengaitkan
/// biaya ke pengeluaran yang sudah dicatat, jadi laporan tidak menghitung biaya
/// dua kali; biaya yang belum dikaitkan tetap dijumlahkan terpisah.
class RiwayatPerawatanAset extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Pengenal stabil lintas HP (FR-150).
  TextColumn get uid => text().nullable()();
  IntColumn get asetId => integer()();
  /// Uraian pekerjaan, mis. "ganti oli + filter udara".
  TextColumn get uraian => text().withLength(min: 1, max: 200)();
  DateTimeColumn get tanggal => dateTime()();
  /// Biaya (sen). 0 = belum diisi.
  IntColumn get biayaSen => integer().withDefault(const Constant(0))();
  /// Transaksi pengeluaran terkait (opsional) — FR-125.
  IntColumn get transaksiId => integer().nullable()();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get dibuatPada => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get diubahPada => dateTime().withDefault(currentDateAndTime)();
}
"""
if "class RiwayatPerawatanAset" not in s:
    s = s.rstrip("\n") + "\n" + tabel_baru
    print("OK: tabel RiwayatPerawatanAset ditambahkan")
else:
    print("LEWAT: tabel RiwayatPerawatanAset sudah ada")
tabel.write_text(s, encoding="utf-8")

# ------------------------------------------------------------ database.dart
anchor_tables = "  // Skema v11 — lampiran foto & rekaman suara (FR-118).\n  Lampiran,\n])"
tables_baru = ("  // Skema v11 — lampiran foto & rekaman suara (FR-118).\n  Lampiran,\n"
               "  // Skema v12 — Home & Asset OS (FR-124/125/126/127), Aaron 22 Sep 2026.\n"
               "  RiwayatPerawatanAset,\n])")
if "RiwayatPerawatanAset,\n])" not in d:
    if anchor_tables not in d:
        print("GAGAL: jangkar daftar tabel tidak ditemukan"); sys.exit(1)
    d = d.replace(anchor_tables, tables_baru, 1)
    print("OK: RiwayatPerawatanAset didaftarkan")
else:
    print("LEWAT: RiwayatPerawatanAset sudah terdaftar")

if "int get schemaVersion => 11;" in d:
    d = d.replace("int get schemaVersion => 11;", "int get schemaVersion => 12;", 1)
    print("OK: schemaVersion = 12")
else:
    print("LEWAT: schemaVersion bukan 11 (cek manual)")

anchor_migr = """          if (dari < 11) {
            // v11 (FR-118): lampiran foto & rekaman suara pada catatan.
            if (!await _tabelAda('lampiran')) await m.createTable(lampiran);
            debugPrint('migrasi v11 selesai (tabel lampiran dibuat)');
          }"""
blok_migr = anchor_migr + """
          if (dari < 12) {
            // v12 (FR-124…FR-127): aset fisik + perawatan aset.
            await _buatTabelV12(m);
            debugPrint('migrasi v12 selesai (aset fisik & riwayat perawatan)');
          }"""
if "if (dari < 12)" not in d:
    if anchor_migr not in d:
        print("GAGAL: jangkar blok migrasi v11 tidak ditemukan"); sys.exit(1)
    d = d.replace(anchor_migr, blok_migr, 1)
    print("OK: blok migrasi v12 ditambahkan (paling akhir)")
else:
    print("LEWAT: blok migrasi v12 sudah ada")

fungsi = """
  /// Skema v12 (FR-124…FR-127): aset fisik + riwayat perawatan berbiaya.
  ///
  /// Aman dijalankan ulang: tabel dicek lewat `_tabelAda`, kolom lewat
  /// `_kolomAda` (PRAGMA) — sebagian basis data lama dibuat dari definisi tabel
  /// terbaru, jadi tanpa pemeriksaan ini `addColumn` bisa meledak
  /// `duplicate column name` dan update aplikasi di HP gagal.
  Future<void> _buatTabelV12(Migrator m) async {
    if (!await _tabelAda('riwayat_perawatan_aset')) {
      await m.createTable(riwayatPerawatanAset);
    }
    final Map<String, TableInfo<Table, dynamic>> kolomBaru = {
      'aset': aset,
      'perawatan': perawatan,
    };
    const Map<String, List<String>> daftar = {
      'aset': ['nomor_seri', 'tanggal_beli', 'harga_beli_sen',
        'garansi_sampai', 'masa_pakai_bulan', 'lokasi'],
      'perawatan': ['aset_id'],
    };
    for (final masuk in kolomBaru.entries) {
      final perlu = daftar[masuk.key] ?? const <String>[];
      for (final namaKolom in perlu) {
        if (await _kolomAda(masuk.key, namaKolom)) continue;
        final kolom = masuk.value.$columns
            .firstWhere((k) => k.$name == namaKolom);
        await m.addColumn(masuk.value, kolom);
      }
    }
  }
"""
anchor_akhir = """  /// Cek keberadaan kolom (PRAGMA) — dipakai migrasi agar aman dijalankan ulang."""
if "_buatTabelV12" not in d:
    if anchor_akhir not in d:
        print("GAGAL: jangkar _kolomAda tidak ditemukan"); sys.exit(1)
    d = d.replace(anchor_akhir, fungsi.strip('\n') + "\n\n" + anchor_akhir, 1)
    print("OK: fungsi _buatTabelV12 ditambahkan")
else:
    print("LEWAT: _buatTabelV12 sudah ada")

db.write_text(d, encoding="utf-8")
print("SELESAI skema v12")
