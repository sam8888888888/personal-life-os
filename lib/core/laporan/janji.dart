/// FR-109 — Janji dokter, tes lab & kontrol: logika murni.
///
/// **Aturan pengingat (PRD).** Tujuh hari sebelum, satu hari sebelum, dan dua
/// jam sebelum jadwal. Jam pengingat untuk lead hari mengikuti jam yang dipilih
/// pengguna (bawaan 08:00), sedangkan pengingat dua jam selalu tepat dua jam
/// sebelum janji.
///
/// **Nada kalimat.** Menyebut waktu & tempat apa adanya; tidak menegur, tidak
/// memakai kata "gagal" atau "lupa".
library;

/// Satu jenis janji kesehatan.
class JenisJanji {
  const JenisJanji({required this.nilaiDb, required this.label, required this.ikon});

  final String nilaiDb;
  final String label;
  final String ikon;
}

const List<JenisJanji> jenisJanji = [
  JenisJanji(nilaiDb: 'kontrol', label: 'Kontrol dokter', ikon: 'stetoskop'),
  JenisJanji(nilaiDb: 'lab', label: 'Tes laboratorium', ikon: 'lab'),
  JenisJanji(nilaiDb: 'vaksin', label: 'Vaksin/imunisasi', ikon: 'suntik'),
  JenisJanji(nilaiDb: 'gigi', label: 'Dokter gigi', ikon: 'gigi'),
  JenisJanji(nilaiDb: 'lain', label: 'Lain-lain', ikon: 'catatan'),
];

JenisJanji? jenisJanjiDari(String nilaiDb) {
  for (final j in jenisJanji) {
    if (j.nilaiDb == nilaiDb) return j;
  }
  return null;
}

String labelJenisJanji(String nilaiDb) =>
    jenisJanjiDari(nilaiDb)?.label ?? nilaiDb;

/// Ubah "7,1" menjadi [7, 1]. Nilai tak wajar dibuang (0–365 hari).
List<int> bacaLeadHari(String teks) {
  final hasil = <int>[];
  for (final bagian in teks.split(',')) {
    final angka = int.tryParse(bagian.trim());
    if (angka == null) continue;
    if (angka < 0 || angka > 365) continue;
    if (!hasil.contains(angka)) hasil.add(angka);
  }
  hasil.sort((a, b) => b.compareTo(a)); // jauh → dekat
  return hasil;
}

/// Jam & menit dari teks "HH:mm" (bawaan 08:00 bila tidak terbaca).
({int jam, int menit}) bacaJam(String teks) {
  final bagian = teks.split(':');
  if (bagian.length != 2) return (jam: 8, menit: 0);
  final j = int.tryParse(bagian[0].trim());
  final m = int.tryParse(bagian[1].trim());
  if (j == null || m == null || j < 0 || j > 23 || m < 0 || m > 59) {
    return (jam: 8, menit: 0);
  }
  return (jam: j, menit: m);
}

String teksJam(int jam, int menit) =>
    '${jam.toString().padLeft(2, '0')}:${menit.toString().padLeft(2, '0')}';

/// Daftar waktu pengingat untuk satu janji — **murni**, urut dari jauh ke dekat.
///
/// Slot 0..n dipakai sebagai nomor slot ID notifikasi supaya ID-nya stabil
/// (jumlah lead mengubah arti slot, jadi ID dihitung ulang tiap sinkronisasi;
/// jumlah lead dibatasi supaya ID tidak pernah keluar dari bloknya).
List<DateTime> waktuPengingatJanji(
  DateTime waktuJanji, {
  String leadHari = '7,1',
  bool duaJam = true,
  String jamPengingat = '08:00',
}) {
  final hasil = <DateTime>[];
  final jam = bacaJam(jamPengingat);
  for (final lead in bacaLeadHari(leadHari)) {
    if (lead <= 0) continue;
    final hari = waktuJanji.subtract(Duration(days: lead));
    final waktu = DateTime(hari.year, hari.month, hari.day, jam.jam, jam.menit);
    hasil.add(waktu);
  }
  if (duaJam) {
    hasil.add(waktuJanji.subtract(const Duration(hours: 2)));
  }
  hasil.sort((a, b) => a.compareTo(b));
  return hasil;
}

/// Jumlah slot ID yang disediakan per janji (cukup untuk 3 lead + 2 jam + sisa).
const int maksSlotPengingatJanji = 6;

/// Kalimat isi notifikasi janji (tanpa data locale — aman di isolate latar).
String kalimatPengingatJanji({
  required String judul,
  required String jenis,
  required DateTime waktuJanji,
  required DateTime waktuPengingat,
  String? tempat,
}) {
  final selisihJam = waktuJanji.difference(waktuPengingat).inMinutes;
  final sebutan = switch (selisihJam) {
    <= 125 => 'Sekitar dua jam lagi',
    <= 60 * 26 => 'Besok',
    _ => 'Sepekan lagi',
  };
  final jamJanji = '${waktuJanji.hour.toString().padLeft(2, '0')}:'
      '${waktuJanji.minute.toString().padLeft(2, '0')}';
  final bagian = StringBuffer(
      '$sebutan: ${labelJenisJanji(jenis).toLowerCase()} “$judul” '
      'pada ${tanggalAmanJanji(waktuJanji)} pukul $jamJanji.');
  if (tempat != null && tempat.trim().isNotEmpty) {
    bagian.write(' Tempat: ${tempat.trim()}.');
  }
  bagian.write(' Buka aplikasi untuk melihat catatannya.');
  return bagian.toString();
}

/// Tanggal tanpa locale (mis. "21 Sep 2026").
String tanggalAmanJanji(DateTime t) {
  const bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${t.day} ${bulan[t.month - 1]} ${t.year}';
}
