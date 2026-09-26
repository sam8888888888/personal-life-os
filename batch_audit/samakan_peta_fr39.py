#!/usr/bin/env python3
"""Samakan peta fitur & ujinya dengan fakta baru: FR-39 (pemindai SMS bank)
DIBUANG dari aplikasi.

Alasan jujur yang ditulis di peta: pemilik memerintahkan izin SMS dibuang
(pemicu Play Protect memblokir pemasangan), sehingga jalur SMS tidak lagi ada
di dalam aplikasi. Penggantinya (impor rekening PDF/CSV) BELUM dikerjakan —
jadi tandanya harus "Belum", bukan "Selesai".
"""
import re
import sys

AKAR = sys.argv[1] if len(sys.argv) > 1 else '.'
import os
os.chdir(AKAR)

# ── 1. Peta fitur: FR-39 → Belum, tanpa rute, catatan apa adanya ────────────
p = 'lib/core/peta_fitur/data_peta_fitur.dart'
s = open(p, encoding='utf-8').read()
lama = """  ButirFitur(
    id: 'FR-39',
 nama: 'Pemindai SMS/notifikasi bank on-device (opt-in): deteksi pembayaran ta',
    modul: '0 · Dasar & Tagihan (V1)',
    fase: '-',
    status: StatusFitur.selesai,
 rincian: 'Pemindai SMS/notifikasi bank on-device (opt-in): deteksi '
        'pembayaran tagihan & saldo; tanpa cloud; alur izin berlapis',
 catatan: 'izin MATI secara bawaan & diminta lewat dialog '
        'sistem; penguraian berjalan di perangkat (kanal lifeos/sms); hasil '
        'hanya USULAN — tagihan tidak pernah ditandai lunas sendiri. Yang '
        'tidak dikenali disebut alasannya, bukan ditebak. Notifikasi aplikasi '
        'bank lewat notifikasi belum dibuat (sengaja tidak dikerjakan).',
    rute: '/uang/pemindai-bank',
  ),
"""
baru = """  ButirFitur(
    id: 'FR-39',
    nama: 'Pemindai bank tanpa SMS: impor rekening (PDF/CSV) atau notifikasi bank',
    modul: '0 · Dasar & Tagihan (V1)',
    fase: '-',
    status: StatusFitur.belum,
    rincian: 'Deteksi pembayaran & saldo dari data bank tanpa memakai izin SMS.',
    catatan: 'Jalur SMS DIBUANG seluruhnya atas perintah pemilik — izin baca '
        'SMS membuat Play Protect memblokir pemasangan dan ditolak kebijakan '
        'Play Store. Penggantinya (impor rekening PDF/CSV resmi dari bank) '
        'belum dikerjakan, jadi butir ini ditandai belum selesai — bukan '
        'dinaikkan supaya kelihatan beres.',
  ),
"""
if lama not in s:
    print('GAGAL: blok FR-39 di peta tidak cocok apa adanya')
    sys.exit(1)
s = s.replace(lama, baru, 1)
open(p, 'w', encoding='utf-8').write(s)
print('PETA    ', p)

# ── 2. Uji peta: FR-39 tidak lagi Selesai, dan muncul di saringan Belum ─────
p = 'test/v3_peta_fitur_test.dart'
s = open(p, encoding='utf-8').read()
s = s.replace("        'FR-39', 'FR-43', 'FR-56', 'FR-57', 'FR-58',",
              "        'FR-43', 'FR-56', 'FR-57', 'FR-58',", 1)
s = s.replace(
    "      expect(cari('FR-26').status, StatusFitur.selesai);  // kunci aplikasi (Batch 8)",
    "      expect(cari('FR-26').status, StatusFitur.selesai);  // kunci aplikasi (Batch 8)\n"
    "      // FR-39 dibuang (izin SMS dilarang pemilik) → wajib Belum, bukan Selesai.\n"
    "      expect(cari('FR-39').status, StatusFitur.belum);\n"
    "      expect(cari('FR-39').rute, isNull,\n"
    "          reason: 'layarnya sudah dihapus, jadi tanpa rute');", 1)
s = s.replace(
    """      expect(find.byKey(const Key('peta_FR-21')), findsNothing,
          reason: 'FR-21 sudah selesai → tidak muncul di saringan Belum');
      // Batch 13: seluruh 152 butir kini selesai ATAU sebagian → saringan
      // "belum" memang kosong, dan layar mengatakannya.
      expect(find.text('Tidak ada butir yang cocok.'), findsOneWidget);""",
    """      expect(find.byKey(const Key('peta_FR-21')), findsNothing,
          reason: 'FR-21 sudah selesai → tidak muncul di saringan Belum');
      // FR-39 (pemindai SMS bank) DIBUANG: jalan SMS-nya sudah tidak ada dan
      // penggantinya belum dikerjakan → butir itu memang muncul di saringan
      // "Belum". Ini tanda kejujuran peta, bukan regresi.
      expect(find.byKey(const Key('peta_FR-39')), findsOneWidget,
          reason: 'FR-39 belum selesai → wajib muncul di saringan Belum');""", 1)
open(p, 'w', encoding='utf-8').write(s)
print('UJI PETA', p)

# ── 3. Uji batch 12: buang impor & grup FR-39 (kodenya sudah dihapus) ───────
p = 'test/v3_batch12_test.dart'
s = open(p, encoding='utf-8').read()
awal = s.find('  // FR-39 (+ FR-59) — Pemindai SMS bank')
akhir = s.find('  // FR-58 — Voice & Parsing Cerdas')
if awal == -1 or akhir == -1 or akhir <= awal:
    print('GAGAL: penanda grup FR-39 tidak ketemu di', p)
    sys.exit(1)
s = s[:awal] + s[akhir:]
s = re.sub(r"^import 'package:personal_life_os/core/parsing/pemindai_bank\.dart';\n", '', s, flags=re.M)
s = re.sub(r"^import 'package:personal_life_os/data/repository/pemindai_bank_repository\.dart';\n", '', s, flags=re.M)
s = s.replace(
    '/// FR-39 (+ dasar FR-59) pemindai SMS bank, FR-58 (voice & parsing cerdas),',
    '/// FR-58 (voice & parsing cerdas),', 1)
open(p, 'w', encoding='utf-8').write(s)
print('UJI B12 ', p)
print('SELESAI')
