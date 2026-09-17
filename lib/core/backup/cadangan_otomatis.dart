/// FR-137 — cadangan otomatis: kapan dijalankan, penamaan berkas, rotasi,
/// dan bentuk hasil pemeriksaan keutuhan.
///
/// Berkas ini MURNI (tanpa Flutter, tanpa basis data) supaya keputusan
/// "apakah perlu mencadangkan sekarang" dan "berkas mana yang diputar keluar"
/// bisa diuji langsung.
///
/// Catatan jujur: aplikasi tidak menjalankan cadangan saat aplikasi tertutup
/// (itu butuh penjadwal tingkat sistem yang belum dipakai). Yang dikerjakan:
/// cadangan otomatis dijalankan saat aplikasi dibuka bila sudah lewat jeda.
library;

/// Kunci setelan cadangan otomatis (dikumpulkan di satu tempat).
const String kunciCadanganOtomatisAktif = 'cadangan.otomatis.aktif';
const String kunciCadanganOtomatisJedaHari = 'cadangan.otomatis.jeda_hari';
const String kunciCadanganOtomatisTerakhir = 'cadangan.otomatis.terakhir';
const String kunciCadanganOtomatisDaftar = 'cadangan.otomatis.daftar';
const String kunciCadanganOtomatisPeriksa = 'cadangan.otomatis.periksa';

/// Bawaan **mati**: pengguna menyalakan sendiri (aturan platform: tidak ada
/// aksi otomatis yang menulis berkas tanpa persetujuan pengguna).
const bool cadanganOtomatisAktifBawaan = false;

/// Jeda bawaan antar cadangan otomatis (hari).
const int jedaCadanganOtomatisBawaan = 7;

/// Jumlah berkas cadangan otomatis yang disimpan sebelum yang tertua diputar
/// keluar. Hanya berkas yang TERCATAT di daftar otomatis yang pernah dihapus.
const int simpanCadanganOtomatisBawaan = 3;

const int jedaCadanganOtomatisMinimal = 1;
const int jedaCadanganOtomatisMaksimal = 90;

/// Pilihan jeda pada antarmuka (hari).
const List<int> pilihanJedaCadanganHari = <int>[1, 3, 7, 14, 30];

/// Batas waktu membaca daftar berkas cadangan.
const Duration batasCadanganOtomatis = Duration(seconds: 10);

int batasiJedaCadangan(int hari) =>
    hari.clamp(jedaCadanganOtomatisMinimal, jedaCadanganOtomatisMaksimal);

/// Apakah cadangan otomatis perlu dijalankan sekarang?
///
/// [terakhir] null berarti belum pernah — cadangan pertama dijalankan segera
/// setelah pengguna menyalakannya.
bool perluCadanganOtomatis({
  required bool aktif,
  required DateTime? terakhir,
  required DateTime sekarang,
  required int jedaHari,
}) {
  if (!aktif) return false;
  if (terakhir == null) return true;
  final DateTime batas =
      terakhir.add(Duration(days: batasiJedaCadangan(jedaHari)));
  return !sekarang.isBefore(batas);
}

/// Sisa waktu menuju cadangan berikutnya (untuk ditampilkan). Null bila mati.
Duration? sisaWaktuCadangan({
  required bool aktif,
  required DateTime? terakhir,
  required DateTime sekarang,
  required int jedaHari,
}) {
  if (!aktif || terakhir == null) return null;
  final DateTime batas =
      terakhir.add(Duration(days: batasiJedaCadangan(jedaHari)));
  final Duration sisa = batas.difference(sekarang);
  return sisa.isNegative ? Duration.zero : sisa;
}

/// Angka dua digit.
String duaDigitCadangan(int angka) => angka.toString().padLeft(2, '0');

/// Nama berkas cadangan otomatis: `plo_auto_YYYYMMDD_HHMM.json`.
String namaBerkasCadanganOtomatis(DateTime t) =>
    'plo_auto_${t.year}${duaDigitCadangan(t.month)}${duaDigitCadangan(t.day)}'
    '_${duaDigitCadangan(t.hour)}${duaDigitCadangan(t.minute)}.json';

/// Daftar berkas yang harus diputar keluar: seluruh berkas otomatis di luar
/// [simpan] berkas TERBARU. Urutan [daftar] = urutan pembuatan (terbaru di
/// belakang); entri kosong/duplikat diabaikan.
List<String> namaKedaluwarsa(List<String> daftar, {required int simpan}) {
  final List<String> bersih = <String>[];
  for (final String n in daftar) {
    final String t = n.trim();
    if (t.isEmpty || bersih.contains(t)) continue;
    bersih.add(t);
  }
  final int simpanAman = simpan < 1 ? 1 : simpan;
  if (bersih.length <= simpanAman) return const <String>[];
  return bersih.sublist(0, bersih.length - simpanAman);
}

/// Hasil pemeriksaan keutuhan satu berkas cadangan.
class HasilPeriksaKeutuhan {
  const HasilPeriksaKeutuhan({
    required this.waktu,
    required this.namaBerkas,
    required this.utuh,
    required this.pesan,
    this.totalBaris = 0,
    this.versiSkema = 0,
  });

  const HasilPeriksaKeutuhan.belumDiperiksa()
      : waktu = null,
        namaBerkas = null,
        utuh = false,
        pesan = 'Belum pernah diperiksa',
        totalBaris = 0,
        versiSkema = 0;

  final DateTime? waktu;
  final String? namaBerkas;
  final bool utuh;
  final String pesan;
  final int totalBaris;
  final int versiSkema;

  Map<String, Object?> keJson() => <String, Object?>{
        'waktu': waktu?.toIso8601String(),
        'namaBerkas': namaBerkas,
        'utuh': utuh,
        'pesan': pesan,
        'totalBaris': totalBaris,
        'versiSkema': versiSkema,
      };

  static HasilPeriksaKeutuhan dariJson(Map<String, Object?> j) =>
      HasilPeriksaKeutuhan(
        waktu: j['waktu'] is String
            ? DateTime.tryParse(j['waktu']! as String)
            : null,
        namaBerkas: j['namaBerkas'] is String ? j['namaBerkas']! as String : null,
        utuh: j['utuh'] == true,
        pesan: j['pesan'] is String ? j['pesan']! as String : '',
        totalBaris: j['totalBaris'] is int ? j['totalBaris']! as int : 0,
        versiSkema: j['versiSkema'] is int ? j['versiSkema']! as int : 0,
      );
}
