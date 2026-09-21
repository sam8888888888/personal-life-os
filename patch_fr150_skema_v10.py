#!/usr/bin/env python3
"""FR-150 lanjutan — skema v10: `uid` untuk tabel lama + tabel pendukung sinkron.

Tujuan: sinkron TIDAK lagi hanya tagihan. Supaya tiap baris punya pengenal
stabil lintas HP, tabel lama diberi kolom `uid` (nullable, tidak menyentuh data
pengguna yang ada). Dua tabel pendukung baru:

- `sinkron_sidik`   : sidik (hash) baris yang terakhir sudah tersinkron, supaya
                      mesin sinkron bisa tahu baris mana yang berubah TANPA
                      menyentuh satu pun repositori lama (tanpa hutang teknis
                      di jalur tulis).
- `sinkron_tautan_belum` : kaitan (foreign key) yang belum bisa dipasang karena
                      baris induknya belum turun — supaya tidak ada data yang
                      dipasang ke baris induk yang salah.

Idempoten: aman dijalankan berulang.
"""
import pathlib
import re
import sys

repo = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")

# Tabel lama yang diberi `uid` (yang sudah punya uid sejak awal TIDAK didaftar).
TABEL_UID = [
    "RiwayatPembayaran", "PemasukanBulanan", "KategoriTransaksi", "Transaksi",
    "AnggaranBulanan", "Langganan", "Aset", "Kewajiban", "NilaiAsetBulanan",
    "NilaiKewajibanBulanan", "Visi", "AreaHidup", "Tujuan", "Proyek", "Tugas",
    "Kebiasaan", "LogKebiasaan", "Perawatan", "UkuranTubuh", "Aktivitas",
    "Tidur", "CatatanAir", "Dokumen", "PembayaranKewajiban",
    "PengeluaranTerencana", "LogPuasa", "LogQuran", "LogDzikir",
    "RefleksiMuhasabah", "CatatanKesehatan",
]

# ── 1. tabel.dart — kolom uid pada kelas tabel lama ──────────────────────────
tabel = repo / "lib/data/database/tabel.dart"
s = tabel.read_text(encoding="utf-8")
kode_uid = ("  /// Pengenal stabil lintas HP (FR-150). Kosong = belum pernah\n"
            "  /// disinkronkan; mesin sinkron akan mengisinya sekali lalu tetap.\n"
            "  TextColumn get uid => text().nullable()();\n")
ditambah = []
for kelas in TABEL_UID:
    m = re.search(r"class %s extends Table \{.*?\n\}" % kelas, s, re.S)
    if not m:
        print(f"  ! kelas {kelas} tidak ditemukan")
        continue
    blok = m.group(0)
    if "get uid" in blok:
        continue
    # sisipkan setelah baris kolom `id` (atau setelah deklarasi kelas)
    baris = blok.split("\n", 2)
    if len(baris) > 2 and "get id =>" in baris[1]:
        blok_baru = baris[0] + "\n" + baris[1] + "\n" + kode_uid + baris[2]
    else:
        blok_baru = baris[0] + "\n" + kode_uid + "\n".join(baris[1:])
    s = s.replace(m.group(0), blok_baru, 1)
    ditambah.append(kelas)
tabel.write_text(s, encoding="utf-8")
print(f"  ✓ tabel.dart: uid ditambahkan ke {len(ditambah)} tabel")

# ── 2. tabel.dart — dua tabel pendukung baru ─────────────────────────────────
if "class SinkronSidik" not in s:
    tambahan = '''

// ======================= PENDUKUNG SINKRON SEMUA MODUL (FR-150) ============

/// Sidik baris yang terakhir sudah tersinkron.
///
/// Dipakai mesin sinkron untuk mengetahui baris mana yang berubah/terhapus
/// TANPA mengubah satu pun berkas repositori lama (tidak ada jalur tulis baru
/// yang harus diingat): cukup bandingkan sidik isi baris.
class SinkronSidik extends Table {
  TextColumn get tabel => text()();
  TextColumn get uid => text()();
  /// Sidik isi baris (64 bit, heksadesimal) saat terakhir tersinkron.
  TextColumn get sidik => text()();
  DateTimeColumn get waktu => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {tabel, uid};
}

/// Kaitan antar-tabel yang belum bisa dipasang (baris induk belum turun dari
/// server). Disimpan apa adanya, dicoba ulang pada sinkron berikutnya — supaya
/// baris tidak pernah dipasang ke induk yang salah.
class SinkronTautanBelum extends Table {
  TextColumn get tabel => text()();
  TextColumn get uid => text()();
  /// Nama kolom foreign key di tabel anak, mis. `tagihan_id`.
  TextColumn get kolom => text()();
  /// uid baris induk yang ditunggu.
  TextColumn get uidInduk => text()();

  @override
  Set<Column> get primaryKey => {tabel, uid, kolom};
}
'''
    tabel.write_text(s.rstrip("\n") + tambahan, encoding="utf-8")
    print("  ✓ tabel.dart: SinkronSidik & SinkronTautanBelum ditambahkan")
else:
    print("  – tabel pendukung sinkron sudah ada")

# ── 3. database.dart ─────────────────────────────────────────────────────────
db = repo / "lib/data/database/database.dart"
d = db.read_text(encoding="utf-8")

if "SinkronTautanBelum," not in d:
    jangkar = "  SuasanaHati,\n])"
    if jangkar not in d:
        raise SystemExit("GAGAL: daftar tabel database.dart tidak cocok")
    d = d.replace(jangkar, """  SuasanaHati,
  // Skema v10 — pendukung sinkron semua modul (FR-150), Aaron 22 Sep 2026.
  SinkronSidik,
  SinkronTautanBelum,
])""", 1)
    print("  ✓ database.dart: 2 tabel pendukung didaftarkan")

if "int get schemaVersion => 10;" not in d:
    d = d.replace("int get schemaVersion => 9;", "int get schemaVersion => 10;", 1)
    print("  ✓ database.dart: schemaVersion = 10")

if "_buatTabelV10" not in d:
    jangkar = "          if (dari < 9) {"
    sisip = """          if (dari < 10) {
            // v10 (FR-150): pengenal `uid` untuk tabel lama + dua tabel
            // pendukung sinkron. Kolom baru bersifat nullable, jadi data
            // pengguna tidak tersentuh.
            await _buatTabelV10(m);
            debugPrint('migrasi v10 selesai (uid sinkron + tabel pendukung)');
          }
          if (dari < 9) {"""
    if jangkar not in d:
        raise SystemExit("GAGAL: jangkar migrasi v10 tidak ditemukan")
    d = d.replace(jangkar, sisip, 1)

    pembantu = """  /// Skema v10 (FR-150): kolom `uid` pada tabel lama + tabel sidik/tautan
  /// pendukung sinkron. Semua kolom baru nullable — tidak ada data yang diubah.
  Future<void> _buatTabelV10(Migrator m) async {
    for (final masuk in <String, TableInfo<Table, dynamic>>{
      'sinkron_sidik': sinkronSidik,
      'sinkron_tautan_belum': sinkronTautanBelum,
    }.entries) {
      if (await _tabelAda(masuk.key)) continue;
      await m.createTable(masuk.value);
    }
    final Map<String, TableInfo<Table, dynamic>> perluUid = {
      'riwayat_pembayaran': riwayatPembayaran,
      'pemasukan_bulanan': pemasukanBulanan,
      'kategori_transaksi': kategoriTransaksi,
      'transaksi': transaksi,
      'anggaran_bulanan': anggaranBulanan,
      'langganan': langganan,
      'aset': aset,
      'kewajiban': kewajiban,
      'nilai_aset_bulanan': nilaiAsetBulanan,
      'nilai_kewajiban_bulanan': nilaiKewajibanBulanan,
      'visi': visi,
      'area_hidup': areaHidup,
      'tujuan': tujuan,
      'proyek': proyek,
      'tugas': tugas,
      'kebiasaan': kebiasaan,
      'log_kebiasaan': logKebiasaan,
      'perawatan': perawatan,
      'ukuran_tubuh': ukuranTubuh,
      'aktivitas': aktivitas,
      'tidur': tidur,
      'catatan_air': catatanAir,
      'dokumen': dokumen,
      'pembayaran_kewajiban': pembayaranKewajiban,
      'pengeluaran_terencana': pengeluaranTerencana,
      'log_puasa': logPuasa,
      'log_quran': logQuran,
      'log_dzikir': logDzikir,
      'refleksi_muhasabah': refleksiMuhasabah,
      'catatan_kesehatan': catatanKesehatan,
    };
    for (final masuk in perluUid.entries) {
      if (await _kolomAda(masuk.key, 'uid')) continue;
      await m.addColumn(masuk.value, masuk.value.uid);
    }
  }

  /// Cek keberadaan kolom (PRAGMA) — dipakai migrasi agar aman dijalankan ulang.
  Future<bool> _kolomAda(String namaTabel, String namaKolom) async {
    final hasil = await customSelect('PRAGMA table_info($namaTabel)').get();
    return hasil.any((b) => b.read<String>('name') == namaKolom);
  }

  /// Cek keberadaan tabel (dipakai migrasi agar aman dijalankan ulang)."""
    if "  /// Cek keberadaan tabel (dipakai migrasi agar aman dijalankan ulang)." not in d:
        raise SystemExit("GAGAL: pembantu _tabelAda tidak ditemukan")
    d = d.replace("  /// Cek keberadaan tabel (dipakai migrasi agar aman dijalankan ulang).",
                  pembantu, 1)
    print("  ✓ database.dart: migrasi v10 + pembantu _kolomAda")

db.write_text(d, encoding="utf-8")
print("selesai")
