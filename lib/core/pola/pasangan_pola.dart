/// SDD v19 Gelombang 3 — Daftar pasangan pola yang diuji + pengambil datanya.
///
/// Dua daftar, dan bedanya penting demi kejujuran:
///
/// * [pasanganAktif] — pasangan yang **kedua sisinya benar-benar ada** di
///   aplikasi ini, jadi bisa diuji sekarang.
/// * [pasanganBelumBisa] — pasangan dari dokumen yang **belum** bisa diuji,
///   lengkap dengan alasannya. Daftar ini ditampilkan di layar apa adanya,
///   bukan disembunyikan, supaya tidak ada kesan "semua sudah jalan".
///
/// Aturan pengambilan data:
/// * Semua data dijumlahkan/dirata-ratakan **per hari** lebih dulu.
/// * Yang dipakai hanya hari yang memiliki **kedua** sisi (pasangan sejati) —
///   hari yang hanya punya satu sisi tidak dihitung, karena akan memalsukan n.
library;

import 'package:drift/drift.dart';

import '../../data/database/database.dart';
import 'mesin_pola.dart';

/// Satu pasangan yang siap diuji.
class PasanganAktif {
  const PasanganAktif({
    required this.kode,
    required this.judul,
    required this.sisiX,
    required this.sisiY,
    required this.sqlX,
    required this.sqlY,
  });

  final String kode;
  final String judul;
  final String sisiX;
  final String sisiY;

  /// SQL agregat per hari: wajib mengembalikan kolom `hari` dan `nilai`.
  final String sqlX;
  final String sqlY;
}

/// Pasangan yang belum bisa diuji — beserta alasannya (ditampilkan ke pengguna).
class PasanganBelumBisa {
  const PasanganBelumBisa({required this.kode, required this.alasan});

  final String kode;
  final String alasan;
}

/// Empat pasangan yang bisa diuji sekarang.
const List<PasanganAktif> pasanganAktif = <PasanganAktif>[
  PasanganAktif(
    kode: 'tidur~suasana_hati',
    judul: 'Tidur dan suasana hati',
    sisiX: 'durasi tidur',
    sisiY: 'skor suasana hati',
    sqlX: "SELECT strftime('%Y-%m-%d', tanggal, 'unixepoch') AS hari, "
        'SUM(durasi_menit) AS nilai FROM tidur GROUP BY hari',
    sqlY: "SELECT strftime('%Y-%m-%d', waktu, 'unixepoch') AS hari, "
        'AVG(skor) AS nilai FROM suasana_hati GROUP BY hari',
  ),
  PasanganAktif(
    kode: 'aktivitas~energi',
    judul: 'Aktivitas dan energi',
    sisiX: 'durasi aktivitas',
    sisiY: 'skor energi',
    sqlX: "SELECT strftime('%Y-%m-%d', tanggal, 'unixepoch') AS hari, "
        'SUM(durasi_menit) AS nilai FROM aktivitas GROUP BY hari',
    sqlY: "SELECT strftime('%Y-%m-%d', tanggal, 'unixepoch') AS hari, "
        'AVG(energi) AS nilai FROM tidur WHERE energi IS NOT NULL GROUP BY hari',
  ),
  PasanganAktif(
    kode: 'air~gejala',
    judul: 'Minum air dan keluhan yang dicatat',
    sisiX: 'jumlah air (ml)',
    sisiY: 'banyaknya keluhan',
    sqlX: "SELECT strftime('%Y-%m-%d', waktu, 'unixepoch') AS hari, "
        'SUM(jumlah_ml) AS nilai FROM catatan_air GROUP BY hari',
    sqlY: "SELECT strftime('%Y-%m-%d', mulai, 'unixepoch') AS hari, "
        'COUNT(*) AS nilai FROM gejala GROUP BY hari',
  ),
  PasanganAktif(
    kode: 'gejala~tidur',
    judul: 'Keluhan dan durasi tidur',
    sisiX: 'banyaknya keluhan',
    sisiY: 'durasi tidur',
    sqlX: "SELECT strftime('%Y-%m-%d', mulai, 'unixepoch') AS hari, "
        'COUNT(*) AS nilai FROM gejala GROUP BY hari',
    sqlY: "SELECT strftime('%Y-%m-%d', tanggal, 'unixepoch') AS hari, "
        'SUM(durasi_menit) AS nilai FROM tidur GROUP BY hari',
  ),
];

/// Pasangan dari dokumen yang belum bisa diuji — alasan ditulis terus terang.
const List<PasanganBelumBisa> pasanganBelumBisa = <PasanganBelumBisa>[
  PasanganBelumBisa(
    kode: 'tidur~pengeluaran_impulsif',
    alasan: 'belum ada penanda "pengeluaran impulsif" di catatan transaksi, '
        'jadi sisi itu tidak bisa dihitung tanpa menebak',
  ),
  PasanganBelumBisa(
    kode: 'sholat_subuh~fokus',
    alasan: 'belum ada catatan waktu sholat per hari di aplikasi ini',
  ),
  PasanganBelumBisa(
    kode: 'makan_luar~anggaran',
    alasan: 'catatan makan belum dibedakan "di rumah" vs "di luar"',
  ),
  PasanganBelumBisa(
    kode: 'siklus_haid~suasana_hati',
    alasan: 'belum ada tabel catatan siklus haid',
  ),
  PasanganBelumBisa(
    kode: 'kebiasaan~skor_disiplin',
    alasan: 'skor disiplin harian belum dihitung aplikasi (masih per kebiasaan)',
  ),
  PasanganBelumBisa(
    kode: 'catatan_air~gejala',
    alasan: 'sama dengan air~gejala — sudah tercakup, tidak dihitung dua kali',
  ),
];

/// Rentang hari yang diambil (setahun terakhir) supaya hitungan tetap ringan.
const int hariYangDiambil = 365;

/// Hasil pengambilan satu sisi: hari → nilai.
typedef PetaHari = Map<DateTime, double>;

/// Ambil satu sisi pasangan dari basis data, dikelompokkan per hari.
Future<PetaHari> ambilPerHari(AppDatabase db, String sql) async {
  final DateTime batas = DateTime.now().subtract(const Duration(days: hariYangDiambil));
  final List<QueryRow> baris = await db
      .customSelect('SELECT hari, nilai FROM ($sql) WHERE nilai IS NOT NULL',
          variables: <Variable<Object>>[])
      .get();
  final PetaHari peta = <DateTime, double>{};
  for (final QueryRow r in baris) {
    final String? hari = r.readNullable<String>('hari');
    final double? nilai = r.readNullable<double>('nilai');
    if (hari == null || nilai == null) continue;
    final DateTime? tanggal = DateTime.tryParse(hari);
    if (tanggal == null) continue;
    final DateTime kunci = DateTime(tanggal.year, tanggal.month, tanggal.day);
    if (kunci.isBefore(DateTime(batas.year, batas.month, batas.day))) continue;
    peta[kunci] = nilai;
  }
  return peta;
}

/// Susun titik data untuk satu pasangan: hanya hari yang punya KEDUA sisi.
Future<List<TitikPola>> titikPasangan(
  AppDatabase db,
  PasanganAktif pasangan,
) async {
  final PetaHari x = await ambilPerHari(db, pasangan.sqlX);
  final PetaHari y = await ambilPerHari(db, pasangan.sqlY);
  final List<DateTime> hari = x.keys.where(y.containsKey).toList()..sort();
  return <TitikPola>[
    for (final DateTime h in hari)
      TitikPola(tanggal: h, x: x[h]!, y: y[h]!),
  ];
}

/// Bangun seluruh kandidat pola dari basis data (hanya pasangan aktif).
Future<List<KandidatPola>> kandidatDariBasisData(AppDatabase db) async {
  final List<KandidatPola> hasil = <KandidatPola>[];
  for (final PasanganAktif p in pasanganAktif) {
    final List<TitikPola> titik = await titikPasangan(db, p);
    hasil.add(KandidatPola(
      kode: p.kode,
      judul: p.judul,
      sisiX: p.sisiX,
      sisiY: p.sisiY,
      titik: titik,
    ));
  }
  return hasil;
}
