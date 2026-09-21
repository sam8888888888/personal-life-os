#!/usr/bin/env python3
"""Batch 3 — tandai 9 butir SELESAI + 1 SEBAGIAN di peta fitur.

Ditulis ke dalam skrip `buat_peta_fitur.py` karena skrip itu MEMBUAT ULANG
seluruh berkas Dart peta fitur dari nol; tanpa catatan di dict `ron` +
`rute_map`, tanda selesai akan hilang saat skrip dijalankan lagi.
Idempoten.
"""
from pathlib import Path

skrip = Path('/proyek/buat_peta_fitur.py')
s = skrip.read_text()
asli = s

BARU = {
    "FR-110": ("SELESAI", "Ron 22 Sep: catat cepat per waktu makan, porsi, dan penilaian sendiri (baik/cukup/kurang)."),
    "FR-112": ("SELESAI", "Ron 22 Sep: suasana hati, energi & stres 1-5, pemicu, catatan; rata-rata & arah 14 hari."),
    "FR-113": ("SELESAI", "Ron 22 Sep: temuan dihitung dari angka sendiri (berat, tekanan, tidur, air, suasana) + angka pendukung; bukan diagnosis."),
    "FR-116": ("SELESAI", "Ron 22 Sep: laporan bulanan + tiga kelompok: membaik / berubah / perlu diperhatikan."),
    "FR-118": ("SEBAGIAN", "Ron 22 Sep: catatan, kategori, tag, sematan, arsip, pencarian selesai; lampiran foto & rekaman suara menyusul (perlu izin kamera/mikrofon di HP)."),
    "FR-119": ("SELESAI", "Ron 22 Sep: keputusan + pilihan/alasan/risiko/biaya/keyakinan, tinjauan hasil 3/6/12 bulan."),
    "FR-120": ("SELESAI", "Ron 22 Sep: topik, sumber, menit, tahap belajar + grafik 14 hari."),
    "FR-121": ("SELESAI", "Ron 22 Sep: jadwal ulangan 1/3/7/16/35/90/180 hari dihitung dari jawaban sendiri."),
    "FR-122": ("SELESAI", "Ron 22 Sep: daftar baca, progres halaman, status, catatan & penilaian sendiri."),
    "FR-123": ("SELESAI", "Ron 22 Sep: tautan catatan/keputusan/bacaan/kartu/pembelajaran dengan tujuan, proyek, tugas, dokumen."),
}

if '"FR-121": (' in s:
    print('TIDAK ADA PERUBAHAN (catatan batch 3 sudah ada)')
else:
    penanda = 'ron = {\n'
    if penanda not in s:
        raise SystemExit('DICT ron: penanda tidak ditemukan')
    tambahan = penanda + ''.join(
        f'    "{rid}": ("{st}", "{cat}"),\n' for rid, (st, cat) in BARU.items())
    s = s.replace(penanda, tambahan, 1)

    penanda2 = 'rute_map = {\n'
    if penanda2 not in s:
        raise SystemExit('DICT rute_map: penanda tidak ditemukan')
    rute = {
        "FR-110": "/kesehatan/makan",
        "FR-112": "/kesehatan/suasana",
        "FR-113": "/kesehatan/temuan",
        "FR-116": "/kesehatan/laporan-bulanan",
        "FR-118": "/pengetahuan/catatan",
        "FR-119": "/pengetahuan/keputusan",
        "FR-120": "/pengetahuan/pembelajaran",
        "FR-121": "/pengetahuan/ulangan",
        "FR-122": "/pengetahuan/bacaan",
        "FR-123": "/pengetahuan/tautan",
    }
    tambahan2 = penanda2 + ''.join(
        f'    "{rid}": "{p}",\n' for rid, p in rute.items())
    s = s.replace(penanda2, tambahan2, 1)

    skrip.write_text(s)
    print('SELESAI: catatan & rute batch 3 ditambahkan ke buat_peta_fitur.py')
