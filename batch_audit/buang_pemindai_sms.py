#!/usr/bin/env python3
"""Buang fitur Pemindai SMS bank (FR-39) dari aplikasi (audit P1-5).

Alasan: izin READ_SMS sudah dibuang dari manifest atas perintah pemilik
("SMS bahaya, pemicu Play Protect"), sehingga seluruh jalur kode SMS adalah
fitur zombie: izinnya tidak pernah diberikan sistem, jalurnya pasti gagal,
dan keberadaan string READ_SMS di dalam APK memicu pertanyaan reviewer Play.

Yang dihapus: kanal Kotlin, kanal Dart, layar, repositori, mesin pengurai,
provider, rute, dan uji-ujinya. Tabel basis data `pemindaianBank` TIDAK
dihapus (data lama tetap utuh; penghapusan tabel butuh migrasi tersendiri).
"""
import os
import re
import sys

AKAR = sys.argv[1] if len(sys.argv) > 1 else '.'
os.chdir(AKAR)

HAPUS = [
    'android/app/src/main/kotlin/com/personallifeos/personal_life_os/KanalSms.kt',
    'lib/core/platform/kanal_sms.dart',
    'lib/features/uang/pemindai_bank_screen.dart',
    'lib/data/repository/pemindai_bank_repository.dart',
    'lib/core/parsing/pemindai_bank.dart',
]

for jalur in HAPUS:
    if os.path.exists(jalur):
        os.remove(jalur)
        print('HAPUS   ', jalur)
    else:
        print('(sudah tidak ada)', jalur)

# Daftar impor kanal SMS di layar/berkas lain (kalau ada sisa).
for akar, _, berkas in os.walk('lib'):
    for nama in berkas:
        if not nama.endswith('.dart'):
            continue
        p = os.path.join(akar, nama)
        isi = open(p, encoding='utf-8').read()
        baru = isi
        baru = re.sub(r"^import '.*(kanal_sms|pemindai_bank).*';\n", '', baru, flags=re.M)
        if baru != isi:
            open(p, 'w', encoding='utf-8').write(baru)
            print('IMPOR   ', p)

# Provider: buang impor + definisi repoPemindaiBankProvider.
p = 'lib/core/providers/batch12_providers.dart'
s = open(p, encoding='utf-8').read()
if 'repoPemindaiBankProvider' in s:
    s = re.sub(
        r"\nfinal repoPemindaiBankProvider = Provider<PemindaiBankRepository>\(\n"
        r"\s*\(ref\) => PemindaiBankRepository\(ref\.watch\(databaseProvider\)\)\);\n",
        '\n', s)
    open(p, 'w', encoding='utf-8').write(s)
    print('PROVIDER', p)

# Router: buang rute /uang/pemindai-bank.
p = 'lib/app_router.dart'
s = open(p, encoding='utf-8').read()
blok = """    GoRoute(
      path: '/uang/pemindai-bank',
      builder: (c, s) => const PemindaiBankScreen(),
    ),
"""
if blok in s:
    s = s.replace(blok, '', 1)
    s = s.replace(
        '    // Batch 12 — FR-43 mode rumah tangga, FR-56 sub-akses keluarga,\n'
        '    // FR-39 pemindai bank, FR-58 ucapkan/tulis.\n',
        '    // Batch 12 — FR-43 mode rumah tangga, FR-56 sub-akses keluarga,\n'
        '    // FR-58 ucapkan/tulis (pemindai SMS bank sudah DIBUANG).\n', 1)
    open(p, 'w', encoding='utf-8').write(s)
    print('ROUTER  ', p)

print('SELESAI')
