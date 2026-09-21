/// FR-94 — Pelacakan hafalan (hifz): logika murni.
///
/// **Aturan yang dilayani.** Tiap hafalan punya status (baru, murajaah, perlu
/// diulang, kuat) dan **jadwal ulangan yang dipilih pengguna** (jumlah hari).
/// Aplikasi hanya mengingatkan kapan ulangan berikutnya; tidak menilai mutu
/// hafalan dan tidak memakai kata menghakimi.
library;

import 'package:flutter/material.dart';

import '../../data/database/database.dart';

/// Satu status hafalan beserta sebutannya.
class StatusHafalan {
  const StatusHafalan({required this.nilaiDb, required this.label});

  final String nilaiDb;
  final String label;
}

const List<StatusHafalan> statusHafalan = [
  StatusHafalan(nilaiDb: 'baru', label: 'Baru dihafal'),
  StatusHafalan(nilaiDb: 'murajaah', label: 'Sedang murajaah'),
  StatusHafalan(nilaiDb: 'perlu_diulang', label: 'Perlu diulang'),
  StatusHafalan(nilaiDb: 'kuat', label: 'Sudah kuat'),
];

String labelStatusHafalan(String nilaiDb) {
  for (final s in statusHafalan) {
    if (s.nilaiDb == nilaiDb) return s.label;
  }
  return nilaiDb;
}

/// Warna penanda status (bukan penilaian, hanya pembeda visual).
Color warnaStatusHafalan(String nilaiDb) {
  switch (nilaiDb) {
    case 'baru':
      return const Color(0xFF1565C0);
    case 'murajaah':
      return const Color(0xFF6A1B9A);
    case 'perlu_diulang':
      return const Color(0xFFEF6C00);
    case 'kuat':
      return const Color(0xFF2E7D32);
    default:
      return const Color(0xFF546E7A);
  }
}

/// Jadwal ulangan berikutnya menurut aturan ulangan pengguna (hari).
///
/// null bila aturannya dimatikan (`ulangSetiapHari <= 0`).
DateTime? jadwalUlangBerikutnya({
  required DateTime terakhir,
  required int ulangSetiapHari,
}) {
  if (ulangSetiapHari <= 0) return null;
  return terakhir.add(Duration(days: ulangSetiapHari));
}

/// Apakah hafalan ini sudah waktunya diulang pada saat [sekarang]?
bool perluDiulangSekarang({
  required DateTime terakhir,
  required int ulangSetiapHari,
  required DateTime sekarang,
}) {
  final jadwal = jadwalUlangBerikutnya(
      terakhir: terakhir, ulangSetiapHari: ulangSetiapHari);
  if (jadwal == null) return false;
  return !sekarang.isBefore(jadwal);
}

/// Ringkasan seluruh hafalan yang tercatat.
class RingkasHafalan {
  const RingkasHafalan({
    required this.totalJuz,
    required this.totalSurah,
    required this.perStatus,
    required this.perluDiulang,
    required this.daftarPerluDiulang,
  });

  final int totalJuz;
  final int totalSurah;
  final Map<String, int> perStatus;
  final int perluDiulang;
  final List<HafalanData> daftarPerluDiulang;

  int get total => totalJuz + totalSurah;
}

RingkasHafalan ringkasHafalan(List<HafalanData> daftar, DateTime sekarang) {
  var juz = 0;
  var surah = 0;
  final perStatus = <String, int>{};
  final perlu = <HafalanData>[];
  for (final h in daftar) {
    if (h.jenis == 'juz') {
      juz++;
    } else {
      surah++;
    }
    perStatus.update(h.status, (v) => v + 1, ifAbsent: () => 1);
    if (perluDiulangSekarang(
      terakhir: h.terakhir,
      ulangSetiapHari: h.ulangSetiapHari,
      sekarang: sekarang,
    )) {
      perlu.add(h);
    }
  }
  perlu.sort((a, b) => a.terakhir.compareTo(b.terakhir));
  return RingkasHafalan(
    totalJuz: juz,
    totalSurah: surah,
    perStatus: perStatus,
    perluDiulang: perlu.length,
    daftarPerluDiulang: perlu,
  );
}

/// Kalimat ringkasan — menyebut angka apa adanya, tanpa menilai.
String kalimatRingkasHafalan(RingkasHafalan r) {
  if (r.total == 0) {
    return 'Belum ada hafalan yang tercatat.';
  }
  final bagian = StringBuffer(
      'Tercatat ${r.total} bagian: ${r.totalJuz} juz & ${r.totalSurah} surah.');
  if (r.perluDiulang > 0) {
    bagian.write(' ${r.perluDiulang} bagian sudah masuk jadwal ulangan.');
  } else {
    bagian.write(' Belum ada yang masuk jadwal ulangan hari ini.');
  }
  return bagian.toString();
}

/// Nama bawaan saat pengguna memilih juz (mis. "Juz 30").
String namaBawaanJuz(int nomor) => 'Juz $nomor';

/// Nama bawaan saat pengguna memilih surah tanpa mengetik nama.
/// Daftar nama surah TIDAK disimpan di aplikasi; pengguna mengetik sendiri
/// supaya tidak ada data yang bisa salah.
String namaBawaanSurah(int nomor) => 'Surah ke-$nomor';
