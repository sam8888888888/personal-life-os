/// Jadwal & prioritas pembayaran kewajiban - FR-74. **PURE Dart**, tanpa
/// Flutter dan tanpa Drift.
///
/// Bagian ini menjawab dua hal:
///
/// * kapan jatuh tempo berikutnya, bila pengguna hanya mengisi "tanggal N
///   tiap bulan" (mis. tanggal 31 di bulan Februari -> 28/29);
/// * kewajiban mana yang perlu dibayar lebih dulu menurut jadwalnya.
///
/// Semua fungsi di sini hanya menghitung; tidak menyimpan dan tidak mengubah
/// data.
library;

/// Satu kewajiban dalam bentuk jadwal ringkas.
class JadwalKewajiban {
  const JadwalKewajiban({
    required this.id,
    required this.nama,
    this.tanggalJatuhTempoHari,
    this.minimumBayarSen,
    this.sisaSen = 0,
  });

  final int id;
  final String nama;

  /// Hari 1-31 tiap bulan; null = belum diisi.
  final int? tanggalJatuhTempoHari;

  /// Minimum bayar per bulan (sen); null = belum diisi.
  final int? minimumBayarSen;

  final int sisaSen;

  bool get punyaJadwal => tanggalJatuhTempoHari != null;
}

/// Jumlah hari dalam bulan [bulan] pada [tahun].
int jumlahHariBulan(int tahun, int bulan) => DateTime(tahun, bulan + 1, 0).day;

/// Hari jatuh tempo yang aman untuk satu bulan: hari 31 di bulan 30 hari
/// dipindahkan ke hari terakhir bulan itu.
DateTime tanggalJatuhTempoBulan(int tahun, int bulan, int hari) {
  final batas = jumlahHariBulan(tahun, bulan);
  final dipakai = hari < 1 ? 1 : (hari > batas ? batas : hari);
  return DateTime(tahun, bulan, dipakai);
}

/// Jatuh tempo berikutnya sejak [sejak] (pukul berapa pun diabaikan).
///
/// Bila tanggal jatuh tempo bulan ini sama dengan [sejak], hasilnya HARI INI
/// (bukan bulan depan) - tagihan hari ini masih bisa dibayar hari ini.
/// null bila [hariJatuhTempo] kosong atau di luar 1-31.
DateTime? jatuhTempoBerikutnya({
  required int? hariJatuhTempo,
  required DateTime sejak,
}) {
  final h = hariJatuhTempo;
  if (h == null || h < 1 || h > 31) return null;
  final hariIni = DateTime(sejak.year, sejak.month, sejak.day);
  final bulanIni = tanggalJatuhTempoBulan(sejak.year, sejak.month, h);
  if (!bulanIni.isBefore(hariIni)) return bulanIni;
  return tanggalJatuhTempoBulan(sejak.year, sejak.month + 1, h);
}

/// Selisih hari dari [dari] ke [ke] (pukulnya diabaikan; boleh negatif).
int selisihHariTanggal(DateTime dari, DateTime ke) {
  final a = DateTime(dari.year, dari.month, dari.day);
  final b = DateTime(ke.year, ke.month, ke.day);
  return b.difference(a).inDays;
}

/// Kalimat jadwal yang tenang dan tanpa penilaian:
/// "Jatuh tempo 25 September 2026", "Jatuh tempo 25 September 2026 (10 hari
/// lagi)", atau "Tanggal jatuh tempo belum diisi".
String kalimatJatuhTempo({
  required int? hariJatuhTempo,
  required DateTime sekarang,
  required String Function(DateTime) formatTanggal,
}) {
  final jatuhTempo =
      jatuhTempoBerikutnya(hariJatuhTempo: hariJatuhTempo, sejak: sekarang);
  if (jatuhTempo == null) return 'Tanggal jatuh tempo belum diisi';
  final jarak = selisihHariTanggal(sekarang, jatuhTempo);
  final dasar = 'Jatuh tempo ${formatTanggal(jatuhTempo)}';
  if (jarak <= 0) return '$dasar (hari ini)';
  return '$dasar ($jarak hari lagi)';
}

/// Urut jadwal terdekat lebih dulu; yang belum punya jadwal ada di belakang.
///
/// Hasilnya daftar baru; daftar masukan tidak diubah. Nama dipakai sebagai
/// pembanding kedua supaya urutannya tetap.
List<JadwalKewajiban> urutJadwalTerdekat(
  List<JadwalKewajiban> daftar,
  DateTime sekarang,
) {
  final salinan = List<JadwalKewajiban>.of(daftar);
  final jatuhTempo = <int, DateTime?>{
    for (final j in salinan)
      j.id: jatuhTempoBerikutnya(
          hariJatuhTempo: j.tanggalJatuhTempoHari, sejak: sekarang),
  };
  salinan.sort((a, b) {
    final ja = jatuhTempo[a.id];
    final jb = jatuhTempo[b.id];
    if (ja == null && jb == null) {
      final n = a.nama.compareTo(b.nama);
      return n != 0 ? n : a.id.compareTo(b.id);
    }
    if (ja == null) return 1;
    if (jb == null) return -1;
    final c = ja.compareTo(jb);
    if (c != 0) return c;
    final n = a.nama.compareTo(b.nama);
    return n != 0 ? n : a.id.compareTo(b.id);
  });
  return salinan;
}
