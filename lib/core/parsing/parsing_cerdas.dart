/// FR-58 — Voice & Parsing Cerdas (bertahap).
///
/// Pengguna berbicara (atau menulis) satu kalimat bebas, aplikasi menyiapkan
/// DRAF yang harus DIKONFIRMASI lebih dulu. Tidak ada yang disimpan otomatis,
/// dan tidak ada data yang dikirim ke luar perangkat.
///
/// Mesin ini MURNI: pengenalan suara ada di `core/platform/kanal_suara.dart`
/// (Android SpeechRecognizer), penguraian teks ada di sini.
library;

import 'package:flutter/foundation.dart';

import '../utils/uang_utils.dart';

/// Jenis draf yang bisa dikenali.
enum JenisDraf {
  pengeluaran('pengeluaran', 'Pengeluaran'),
  tagihan('tagihan', 'Tagihan baru'),
  dana('dana', 'Setoran dana persiapan'),
  perawatan('perawatan', 'Perawatan berkala'),
  tidakDikenali('tidak', 'Belum bisa dikenali');

  const JenisDraf(this.kode, this.label);

  final String kode;
  final String label;
}

/// Hasil penguraian satu kalimat — SELALU draf, belum tersimpan.
@immutable
class DrafHasil {
  const DrafHasil({
    required this.mentah,
    required this.jenis,
    this.judul = '',
    this.nominalSen,
    this.tanggal,
    this.frekuensiBulan,
    this.catatan,
    this.tingkatKeyakinan = 0,
    this.alasan = const [],
  });

  /// Kalimat asli dari pengguna (tidak diubah).
  final String mentah;
  final JenisDraf jenis;

  /// Judul/keterangan yang ditebak dari kalimat (mis. "galon").
  final String judul;
  final int? nominalSen;
  final DateTime? tanggal;

  /// Untuk draf perawatan: setiap berapa bulan.
  final int? frekuensiBulan;
  final String? catatan;

  /// 0–100; makin rendah makin layak pengguna memeriksa ulang.
  final int tingkatKeyakinan;

  /// Hal yang belum bisa diisi dan harus dilengkapi pengguna.
  final List<String> alasan;

  bool get dikenali => jenis != JenisDraf.tidakDikenali;

  bool get adaNominal => (nominalSen ?? 0) > 0;

  /// Kalimat ringkas untuk kartu konfirmasi di layar.
  String get kalimat {
    if (!dikenali) {
      return 'Kalimat ini belum bisa dikenali sebagai pengeluaran, tagihan, '
          'dana, atau perawatan. Coba sebut nominalnya juga, mis. '
          '"beli galon 20 ribu".';
    }
    final bagian = <String>[jenis.label];
    if (judul.trim().isNotEmpty) bagian.add(judul.trim());
    if (adaNominal) bagian.add(fmtRpDariSen(nominalSen!));
    if (tanggal != null) {
      bagian.add('tanggal ${tanggal!.day}/${tanggal!.month}/${tanggal!.year}');
    }
    if (frekuensiBulan != null) bagian.add('tiap $frekuensiBulan bulan');
    return '${bagian.join(' · ')} — periksa dulu sebelum disimpan.';
  }
}

/// Kalimat contoh di layar (memakai pola yang benar-benar didukung).
const List<String> contohKalimat = [
  'beli galon 20 ribu',
  'bayar listrik 250rb jatuh tempo 25 september',
  'setor dana servis motor 500rb',
  'servis motor tiap 3 bulan',
];

/// Bilangan Indonesia → sen.
///
/// Menangani "20rb", "250 ribu", "1,5jt", "20.000", "Rp 1.234.567", "2 jt".
int? uraiAngkaSen(String teks) {
  final t = teks.toLowerCase().replaceAll('rp', ' ').trim();
  final m = RegExp(r'([\d]+(?:[.,][\d]+)*)\s*(jt|juta|rb|ribu|k|m)?').allMatches(t);
  for (final c in m) {
    final angkaTeks = c.group(1);
    if (angkaTeks == null) continue;
    final satuan = c.group(2) ?? '';
    double? angka;
    // "1.234.567" / "20.000" gaya ribuan (titik tiap 3 angka) → buang titiknya.
    if (RegExp(r'^\d{1,3}(?:\.\d{3})+$').hasMatch(angkaTeks)) {
      angka = double.tryParse(angkaTeks.replaceAll('.', ''));
    } else {
      angka = double.tryParse(angkaTeks.replaceAll(',', '.'));
    }
    if (angka == null) continue;
    switch (satuan) {
      case 'jt':
      case 'juta':
        angka *= 1000000;
        break;
      case 'rb':
      case 'ribu':
      case 'k':
        angka *= 1000;
        break;
      default:
        break;
    }
    if (angka <= 0) continue;
    return (angka * 100).round();
  }
  return null;
}

const Map<String, int> _bulanIndo = {
  'januari': 1,
  'jan': 1,
  'februari': 2,
  'feb': 2,
  'maret': 3,
  'mar': 3,
  'april': 4,
  'apr': 4,
  'mei': 5,
  'juni': 6,
  'jun': 6,
  'juli': 7,
  'jul': 7,
  'agustus': 8,
  'agu': 8,
  'ags': 8,
  'september': 9,
  'sep': 9,
  'oktober': 10,
  'okt': 10,
  'november': 11,
  'nov': 11,
  'desember': 12,
  'des': 12,
};

/// Urai tanggal dari kalimat ("25 september", "25/9", "besok", "hari ini").
DateTime? uraiTanggal(String teks, {DateTime? sekarang}) {
  final kini = sekarang ?? DateTime.now();
  final t = teks.toLowerCase();
  final hariIni = DateTime(kini.year, kini.month, kini.day);

  if (RegExp(r'\bhari ini\b').hasMatch(t)) return hariIni;
  if (RegExp(r'\bbesok\b').hasMatch(t)) {
    return hariIni.add(const Duration(days: 1));
  }
  if (RegExp(r'\bminggu depan\b').hasMatch(t)) {
    return hariIni.add(const Duration(days: 7));
  }

  // 25/9 atau 25-9 atau 25.9
  final mSlash = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})(?:[/\-.](\d{2,4}))?\b')
      .firstMatch(t);
  if (mSlash != null) {
    final hari = int.tryParse(mSlash.group(1)!);
    final bulan = int.tryParse(mSlash.group(2)!);
    var tahun = int.tryParse(mSlash.group(3) ?? '') ?? kini.year;
    if (tahun < 100) tahun += 2000;
    if (hari != null && bulan != null && hari >= 1 && hari <= 31 &&
        bulan >= 1 && bulan <= 12) {
      return DateTime(tahun, bulan, hari);
    }
  }

  // 25 september 2026 / tanggal 25 september
  for (final masuk in _bulanIndo.entries) {
    final pola = RegExp('\\b(\\d{1,2})\\s*${masuk.key}\\b');
    final m = pola.firstMatch(t);
    if (m != null) {
      final hari = int.tryParse(m.group(1)!);
      if (hari == null || hari < 1 || hari > 31) continue;
      final mTahun = RegExp(r'\b(20\d{2})\b').firstMatch(t);
      final tahun = int.tryParse(mTahun?.group(1) ?? '') ?? kini.year;
      return DateTime(tahun, masuk.value, hari);
    }
  }
  return null;
}

/// Urai satu kalimat menjadi draf. Tidak pernah menyimpan apa pun.
DrafHasil uraikanKalimat(String kalimat, {DateTime? sekarang}) {
  final mentah = kalimat.trim();
  if (mentah.isEmpty) {
    return const DrafHasil(
      mentah: '',
      jenis: JenisDraf.tidakDikenali,
      alasan: ['Kalimat masih kosong.'],
    );
  }
  final t = mentah.toLowerCase();
  final nominal = uraiAngkaSen(t);
  final tanggal = uraiTanggal(t, sekarang: sekarang);
  final alasan = <String>[];
  if (nominal == null) alasan.add('Nominal belum disebut.');

  // Perawatan berkala: ada "tiap N bulan"/"setiap N bulan".
  final mTiap = RegExp(r'(?:tiap|setiap)\s*(\d{1,3})\s*bulan').firstMatch(t);
  if (mTiap != null) {
    final bulan = int.tryParse(mTiap.group(1)!);
    if (bulan == null || bulan <= 0 || bulan > 120) {
      return DrafHasil(
        mentah: mentah,
        jenis: JenisDraf.tidakDikenali,
        alasan: ['Jeda bulan "$mTiap" tidak masuk akal (1–120 bulan).'],
      );
    }
    final judul = _potongKata(t, const ['servis', 'perawatan', 'ganti', 'cuci', 'periksa']);
    return DrafHasil(
      mentah: mentah,
      jenis: JenisDraf.perawatan,
      judul: judul.isEmpty ? 'Perawatan' : judul,
      frekuensiBulan: bulan,
      nominalSen: nominal,
      tanggal: tanggal,
      tingkatKeyakinan: nominal == null ? 60 : 85,
      alasan: alasan,
    );
  }

  // Tagihan baru: ada kata tagihan/jatuh tempo/ingatkan.
  if (RegExp(r'\b(tagihan|jatuh tempo|ingatkan|bayar)\b').hasMatch(t) &&
      !RegExp(r'\bsetor|nabung\b').hasMatch(t)) {
    final judul = _potongKata(t, const ['tagihan', 'bayar']);
    return DrafHasil(
      mentah: mentah,
      jenis: JenisDraf.tagihan,
      judul: judul.isEmpty ? 'Tagihan' : judul,
      nominalSen: nominal,
      tanggal: tanggal,
      tingkatKeyakinan: nominal == null ? 55 : (tanggal == null ? 70 : 90),
      alasan: [
        ...alasan,
        if (tanggal == null) 'Jatuh tempo belum disebut (mis. "25 september").',
      ],
    );
  }

  // Setoran dana persiapan.
  if (RegExp(r'\b(setor|nabung|sisihkan|tabung)\b').hasMatch(t)) {
    final judul = _potongKata(t, const ['dana', 'setor', 'nabung', 'sisihkan', 'tabung', 'untuk']);
    return DrafHasil(
      mentah: mentah,
      jenis: JenisDraf.dana,
      judul: judul.isEmpty ? 'Dana persiapan' : judul,
      nominalSen: nominal,
      tanggal: tanggal,
      tingkatKeyakinan: nominal == null ? 55 : 85,
      alasan: alasan,
    );
  }

  // Pengeluaran harian.
  if (RegExp(r'\b(beli|bayar|jajan|isi|isi ulang|top up|belanja)\b').hasMatch(t)) {
    final judul = _potongKata(
        t, const ['beli', 'bayar', 'jajan', 'isi ulang', 'isi', 'top up', 'belanja']);
    return DrafHasil(
      mentah: mentah,
      jenis: JenisDraf.pengeluaran,
      judul: judul.isEmpty ? 'Pengeluaran' : judul,
      nominalSen: nominal,
      tanggal: tanggal,
      tingkatKeyakinan: nominal == null ? 50 : 85,
      alasan: alasan,
    );
  }

  return DrafHasil(
    mentah: mentah,
    jenis: JenisDraf.tidakDikenali,
    nominalSen: nominal,
    tanggal: tanggal,
    alasan: [
      'Kata kerja belum jelas. Sebutkan mis. "beli", "bayar", "setor", atau '
          '"servis ... tiap 3 bulan".',
    ],
  );
}

/// Ambil sisa kalimat setelah kata kunci pertama (judul apa adanya).
String _potongKata(String kalimat, List<String> kataKunci) {
  var sisa = kalimat;
  for (final k in kataKunci) {
    final pola = RegExp('\\b${RegExp.escape(k)}\\b');
    final m = pola.firstMatch(sisa);
    if (m != null) {
      sisa = sisa.substring(m.end).trim();
      break;
    }
  }
  // Buang nominal & keterangan waktu supaya judulnya bersih.
  sisa = sisa
      .replaceAll(RegExp(r'\brp?\s?[\d.,]+\s*(jt|juta|rb|ribu|k)?\b'), ' ')
      .replaceAll(RegExp(r'\b\d{1,2}[/\-.]\d{1,2}([/\-.]\d{2,4})?\b'), ' ')
      .replaceAll(RegExp(r'\b(jatuh tempo|tiap|setiap|tgl|tanggal)\b'), ' ')
      .replaceAll(RegExp(r'\b\d{1,2}\s*(januari|februari|maret|april|mei|juni|juli|agustus|september|oktober|november|desember)\b'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return sisa;
}

/// Apakah draf sudah cukup lengkap untuk ditawarkan disimpan.
bool drafSiapSimpan(DrafHasil d) {
  if (!d.dikenali) return false;
  if (d.jenis == JenisDraf.perawatan) {
    return d.judul.trim().isNotEmpty && (d.frekuensiBulan ?? 0) > 0;
  }
  if (d.jenis == JenisDraf.tagihan) {
    return d.judul.trim().isNotEmpty && d.adaNominal && d.tanggal != null;
  }
  return d.judul.trim().isNotEmpty && d.adaNominal;
}

/// Kalimat jujur tentang apa yang TIDAK dilakukan mesin ini.
const String catatanParsingCerdas =
    'Pengenalan suara dijalankan di perangkat lewat fitur bawaan Android. '
    'Tidak ada rekaman yang disimpan aplikasi dan tidak ada data yang dikirim '
    'ke layanan mana pun. Semua hasil hanya DRAF — baru tersimpan setelah Anda '
    'menekan simpan.';
