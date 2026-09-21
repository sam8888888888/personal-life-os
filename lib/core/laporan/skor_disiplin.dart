/// FR-36 — Skor Disiplin Tagihan lokal (pure, tanpa I/O).
///
/// Skor 0–100 yang dihitung dari kebiasaan membayar tagihan di HP ini:
///   * 70% dari persentase pelunasan tepat waktu,
///   * 30% dari rentetan tepat waktu (streak) — maksimal dihitung 10 kali
///     berturut-turut supaya tidak perlu "menunggu setahun" untuk skor penuh.
///
/// Ditampilkan bersama capaian dan penjelasan cara menghitungnya. Ada
/// disclaimer: ini BUKAN skor kredit dan tidak dipakai pihak mana pun.
///
/// Bahasa: tanpa kata menghakimi. Yang lewat jatuh tempo disebut "lewat jatuh
/// tempo", bukan "gagal" atau "buruk" (sejalan FR-81/FR-85).
library;

/// Satu capaian yang sudah diraih.
class Capaian {
  const Capaian({required this.judul, required this.keterangan});

  final String judul;
  final String keterangan;
}

class HasilSkorDisiplin {
  const HasilSkorDisiplin({
    required this.skor,
    required this.streak,
    required this.tepatWaktu,
    required this.jumlahPembayaran,
    required this.capaian,
    required this.lewatJatuhTempo,
  });

  final int skor;
  final int streak;
  final int tepatWaktu;
  final int jumlahPembayaran;
  final List<Capaian> capaian;
  final int lewatJatuhTempo;

  bool get adaRiwayat => jumlahPembayaran > 0;

  int get persenTepatWaktu => jumlahPembayaran == 0
      ? 0
      : ((tepatWaktu * 100) / jumlahPembayaran).round();

  /// Rentetan dihitung maksimal 10 untuk bagian skor.
  int get streakUntukSkor => streak > 10 ? 10 : streak;

  /// Penjelasan terbuka: dari mana angka skor berasal.
  String get penjelasan => '70% dari ketepatan waktu '
      '($persenTepatWaktu%) + 30% dari rentetan tepat waktu '
      '($streakUntukSkor/10)';
}

/// Rentetan tepat waktu terbaru: dihitung mundur dari pembayaran terakhir,
/// berhenti saat menemukan satu yang lewat jatuh tempo.
int hitungStreak(List<({bool tepatWaktu, DateTime tanggalBayar})> riwayat) {
  if (riwayat.isEmpty) return 0;
  final urut = [...riwayat]
    ..sort((a, b) => b.tanggalBayar.compareTo(a.tanggalBayar));
  var streak = 0;
  for (final r in urut) {
    if (!r.tepatWaktu) break;
    streak++;
  }
  return streak;
}

HasilSkorDisiplin hitungSkorDisiplin(
  List<({bool tepatWaktu, DateTime tanggalBayar})> riwayat, {
  DateTime? acuan,
}) {
  final jumlah = riwayat.length;
  final tepat = riwayat.where((r) => r.tepatWaktu).length;
  final lewat = jumlah - tepat;
  final streak = hitungStreak(riwayat);
  final persenTepat = jumlah == 0 ? 0.0 : (tepat * 100) / jumlah;
  final bagianTepat = 70 * (persenTepat / 100);
  final bagianStreak = 30 * ((streak > 10 ? 10 : streak) / 10);
  final skor = jumlah == 0 ? 0 : (bagianTepat + bagianStreak).round();

  final kini = acuan ?? DateTime.now();
  final bulanIni = riwayat.where((r) =>
      r.tanggalBayar.year == kini.year && r.tanggalBayar.month == kini.month);
  final semuaTepatBulanIni =
      bulanIni.isNotEmpty && bulanIni.every((r) => r.tepatWaktu);

  final capaian = <Capaian>[];
  if (streak >= 3) {
    capaian.add(Capaian(
        judul: 'Rentetan $streak×',
        keterangan: '$streak pelunasan berturut-turut tepat waktu'));
  }
  if (streak >= 5) {
    capaian.add(const Capaian(
        judul: 'Lima tanpa jeda',
        keterangan: 'Lima pelunasan berturut-turut tepat waktu'));
  }
  if (streak >= 10) {
    capaian.add(const Capaian(
        judul: 'Sepuluh tanpa jeda',
        keterangan: 'Sepuluh pelunasan berturut-turut tepat waktu'));
  }
  if (semuaTepatBulanIni) {
    capaian.add(const Capaian(
        judul: 'Bulan ini tuntas tepat waktu',
        keterangan: 'Semua pelunasan bulan ini tercatat tepat waktu'));
  }
  if (jumlah >= 10 && persenTepat >= 90) {
    capaian.add(Capaian(
        judul: 'Konsisten',
        keterangan: 'Ketepatan waktu $persenTepat% dari $jumlah pelunasan'));
  }

  return HasilSkorDisiplin(
    skor: skor,
    streak: streak,
    tepatWaktu: tepat,
    jumlahPembayaran: jumlah,
    capaian: capaian,
    lewatJatuhTempo: lewat,
  );
}
