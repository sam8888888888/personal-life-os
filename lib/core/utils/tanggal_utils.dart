/// Utilitas tanggal & frekuensi — PURE (tanpa I/O) agar mudah diuji unit.
/// Aturan penting PRD: rollover bulanan memakai day-clamping (31 Jan -> 28/29 Feb).
library;

import 'package:intl/intl.dart';

import 'mata_uang.dart';

import '../../data/model/enums.dart';

/// Tambah n bulan dengan penjepitan akhir bulan.
/// Contoh: 2026-01-31 + 1 bln -> 2026-02-28; 2028-01-31 + 1 bln -> 2028-02-29.
DateTime tambahBulan(DateTime tgl, int n) {
  if (n == 0) return tgl;
  final tahun = tgl.year + ((tgl.month - 1 + n) ~/ 12);
  final bulan = ((tgl.month - 1 + n) % 12) + 1;
  final hariMax = DateTime(tahun, bulan + 1, 0).day;
  final hari = tgl.day > hariMax ? hariMax : tgl.day;
  return DateTime(tahun, bulan, hari);
}

/// Periode berikutnya dari [tgl] menurut frekuensi.
DateTime periodeBerikutnya(DateTime tgl, Frekuensi f, {int? kustomHariN}) {
  switch (f) {
    case Frekuensi.sekali:
      return tgl; // tidak berulang
    case Frekuensi.mingguan:
      return tgl.add(const Duration(days: 7));
    case Frekuensi.duaMingguan:
      return tgl.add(const Duration(days: 14));
    case Frekuensi.bulanan:
      return tambahBulan(tgl, 1);
    case Frekuensi.duaBulanan:
      return tambahBulan(tgl, 2);
    case Frekuensi.kuartalan:
      return tambahBulan(tgl, 3);
    case Frekuensi.semesteran:
      return tambahBulan(tgl, 6);
    case Frekuensi.tahunan:
      return tambahBulan(tgl, 12);
    case Frekuensi.kustomHari:
      return tgl.add(Duration(days: (kustomHariN ?? 30).clamp(1, 9999)));
  }
}

/// Tanggal notifikasi: jatuhTempo dikurangi lead (hari).
/// lead 0 berarti hari-H. Lead dihitung sebagai selisih hari kalender.
DateTime tanggalPengingat(DateTime jatuhTempo, int leadHari) {
  return jatuhTempo.subtract(Duration(days: leadHari < 0 ? 0 : leadHari));
}

/// Selisih hari dari [dari] ke [ke] (ke - dari), dibulatkan ke hari.
int selisihHari(DateTime dari, DateTime ke) {
  final a = DateTime(dari.year, dari.month, dari.day);
  final b = DateTime(ke.year, ke.month, ke.day);
  return b.difference(a).inDays;
}

/// Konversi daftar lead days (mis. [7,3,1]) ke teks DB ("7,3,1").
String leadKeTeks(List<int> lead) => lead.map((e) => e.toString()).join(',');

/// Parse teks DB ("7,3,1") ke daftar lead, urut menurun, unik.
List<int> teksKeLead(String? teks) {
  if (teks == null || teks.trim().isEmpty) return const [];
  final vals = teks
      .split(',')
      .map((e) => int.tryParse(e.trim()))
      .whereType<int>()
      .where((e) => e >= 0 && e <= 365)
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));
  return vals;
}

/// Parse tanggal dari berbagai format umum Indonesia:
/// yyyy-MM-dd (ISO), dd/MM/yyyy, dd-MM-yyyy, d MMMM yyyy / d MMM yyyy.
DateTime? parseTanggal(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final v = s.trim().replaceAll('.', '-');
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(v);
  if (iso != null) {
    final y = int.parse(iso.group(1)!), m = int.parse(iso.group(2)!), d = int.parse(iso.group(3)!);
    if (validTanggal(y, m, d)) return DateTime(y, m, d);
    return null;
  }
  final dm = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$').firstMatch(v);
  if (dm != null) {
    var y = int.parse(dm.group(3)!);
    if (y < 100) y += 2000;
    final d = int.parse(dm.group(1)!), m = int.parse(dm.group(2)!);
    if (validTanggal(y, m, d)) return DateTime(y, m, d);
    return null;
  }
  for (final fmt in ['d MMMM yyyy', 'd MMM yyyy']) {
    try {
      return DateFormat(fmt, localeTanggalAktif).parse(v);
    } catch (_) {}
  }
  return null;
}

bool validTanggal(int tahun, int bulan, int hari) {
  if (bulan < 1 || bulan > 12 || hari < 1) return false;
  return hari <= DateTime(tahun, bulan + 1, 0).day;
}

/// Format tanggal pendek Indonesia: 9 September 2026
String fmtTanggalId(DateTime tgl) =>
    DateFormat('d MMMM yyyy', localeTanggalAktif).format(tgl);

/// Format tanggal pendek: Sen, 9 Sep 2026
String fmtTanggalPendek(DateTime tgl) =>
    DateFormat('EEE, d MMM yyyy', localeTanggalAktif).format(tgl);

/// "September 2026"
String fmtBulanId(DateTime tgl) =>
    DateFormat('MMMM yyyy', localeTanggalAktif).format(tgl);

/// "Sep 2026"
String fmtBulanPendekId(DateTime tgl) =>
    DateFormat('MMM yyyy', localeTanggalAktif).format(tgl);


// ---------------------------------------------------------------------------
// Format aman tanpa data locale (dipakai notifikasi & pekerja latar).
//
// Notifikasi bisa dibangun di isolate latar (Workmanager / aksi notifikasi)
// yang TIDAK menjalankan main(), sehingga initializeDateFormatting('id_ID')
// belum tentu dipanggil. Format di bawah tidak butuh data locale.
// ---------------------------------------------------------------------------

/// Nama bulan/hari per locale — dipakai varian "aman" di bawah.
///
/// Disimpan sebagai tabel (bukan mengandalkan data locale intl) karena
/// notifikasi bisa dibangun di isolate latar yang belum memanggil
/// `initializeDateFormatting`. Tambahkan locale baru di sini + di
/// `initializeDateFormatting` (`lib/main.dart`).
const Map<String, List<String>> _bulanPanjangLokal = {
  'id_ID': [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ],
  'ms_MY': [
    'Januari', 'Februari', 'Mac', 'April', 'Mei', 'Jun',
    'Julai', 'Ogos', 'September', 'Oktober', 'November', 'Disember',
  ],
};

const Map<String, List<String>> _bulanSingkatLokal = {
  'id_ID': ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'],
  'ms_MY': ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun',
    'Jul', 'Ogo', 'Sep', 'Okt', 'Nov', 'Dis'],
};

const Map<String, List<String>> _hariSingkatLokal = {
  'id_ID': ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'],
  'ms_MY': ['Isn', 'Sel', 'Rab', 'Kha', 'Jum', 'Sab', 'Ahd'],
};

List<String> _pilihLokal(Map<String, List<String>> peta) =>
    peta[localeTanggalAktif] ?? peta['id_ID']!;

/// "9 September 2026" (atau "9 Ogos 2026" pada locale Malaysia) —
/// tanpa bergantung data locale intl.
String fmtTanggalAman(DateTime t) =>
    '${t.day} ${_pilihLokal(_bulanPanjangLokal)[t.month - 1]} ${t.year}';

/// "Kam, 10 Sep 2026" (atau "Kha, 10 Sep 2026") tanpa data locale intl.
String fmtTanggalPendekAman(DateTime t) =>
    '${_pilihLokal(_hariSingkatLokal)[t.weekday - 1]}, ${t.day} '
    '${_pilihLokal(_bulanSingkatLokal)[t.month - 1]} ${t.year}';

/// "09:00"
String fmtJam(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "September 2026" (atau "Oktober 2026" dst) tanpa data locale intl —
/// aman dipakai di layar, notifikasi, maupun pekerja latar.
String fmtBulanAman(DateTime t) =>
    '${_pilihLokal(_bulanPanjangLokal)[t.month - 1]} ${t.year}';

/// Nama bulan singkat bahasa Indonesia (dipakai grafik & pemilih bulan).
/// Indeks mengikuti nomor bulan: namaBulanSingkat[9] == 'Sep'.
const List<String> namaBulanSingkat = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];
