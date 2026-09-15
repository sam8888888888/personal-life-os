/// Rekap konsistensi sholat (FR-89) — MURNI Dart, tanpa Flutter.
///
/// ATURAN KERAS III-11: berkas ini TIDAK menghitung skor, nilai, peringkat,
/// pujian, atau hukuman. Yang dihitung hanya berapa hari sebuah waktu
/// "tercatat" dari sekian hari yang dilihat — apa adanya, memakai kata
/// "tercatat". Kata "belum tercatat" tidak boleh diartikan "tidak dikerjakan".
library;

import 'model_log_sholat.dart';
import 'model_sholat.dart';

/// Rekap satu waktu sholat pada satu rentang hari.
class RekapWaktu {
  const RekapWaktu({
    required this.waktu,
    required this.tercatat,
    required this.jumlahHari,
  });

  final WaktuSholat waktu;

  /// Jumlah hari (dalam rentang) yang menandai waktu ini tercatat.
  final int tercatat;

  /// Jumlah hari yang dilihat. Nol berarti rentang kosong.
  final int jumlahHari;

  /// 0..1 untuk bilah tampilan, atau null bila tidak ada hari yang dilihat.
  double? get bagian => jumlahHari <= 0 ? null : tercatat / jumlahHari;

  /// Kalimat jujur & netral, mis. "Subuh: 4 dari 7 hari tercatat".
  String get kalimat => '$tercatat dari $jumlahHari hari tercatat';

  @override
  String toString() => '${waktu.label}: $kalimat';
}

/// Rekap satu rentang hari (mis. 7 atau 30 hari terakhir).
class RekapSholat {
  const RekapSholat({
    required this.tanggal,
    required this.perWaktu,
    this.jumlahPerHari = const <int>[],
  });

  /// Kunci tanggal `YYYY-MM-DD`, urut naik (paling lama lebih dulu).
  final List<String> tanggal;

  /// Baris per waktu wajib, urut Subuh → Isya (Syuruq tidak pernah dihitung).
  final List<RekapWaktu> perWaktu;

  /// Jumlah hari yang dilihat.
  int get jumlahHari => tanggal.length;

  /// Total waktu tercatat pada seluruh rentang.
  int get totalTercatat =>
      perWaktu.fold(0, (int a, RekapWaktu b) => a + b.tercatat);

  /// Total kemungkinan = jumlah hari × 5 waktu wajib.
  int get totalKemungkinan => jumlahHari * WaktuSholat.wajibSaja.length;

  /// Kalimat netral untuk kepala rekap.
  String get kalimatTotal => '$totalTercatat dari $totalKemungkinan waktu tercatat';

  /// Jumlah waktu tercatat pada tiap hari (0..5), sejajar dengan [tanggal].
  final List<int> jumlahPerHari;

  /// Jumlah waktu tercatat pada hari ke-[i] (0..5).
  int jumlahHariKe(int i) =>
      (i < 0 || i >= jumlahPerHari.length) ? 0 : jumlahPerHari[i];

  /// Rekap satu waktu; null bila [w] bukan waktu wajib.
  RekapWaktu? rekapWaktu(WaktuSholat w) {
    for (final RekapWaktu r in perWaktu) {
      if (r.waktu == w) return r;
    }
    return null;
  }

  /// Bangun rekap dari data mentah.
  ///
  /// [tanggal] menentukan rentang & urutannya; kunci di luar rentang diabaikan
  /// sepenuhnya (data mentah tidak pernah diubah).
  static RekapSholat hitung({
    required List<String> tanggal,
    required Map<String, CatatanSholat> catatan,
  }) {
    final List<RekapWaktu> baris = <RekapWaktu>[];
    for (final WaktuSholat w in WaktuSholat.wajibSaja) {
      int jumlah = 0;
      for (final String kunci in tanggal) {
        if (catatan[kunci]?.tercatatPada(w) ?? false) jumlah++;
      }
      baris.add(RekapWaktu(
        waktu: w,
        tercatat: jumlah,
        jumlahHari: tanggal.length,
      ));
    }
    final List<int> perHari = <int>[
      for (final String kunci in tanggal)
        WaktuSholat.wajibSaja
            .where((WaktuSholat w) => catatan[kunci]?.tercatatPada(w) ?? false)
            .length,
    ];
    return RekapSholat(
      tanggal: List<String>.unmodifiable(tanggal),
      perWaktu: List<RekapWaktu>.unmodifiable(baris),
      jumlahPerHari: List<int>.unmodifiable(perHari),
    );
  }

  /// Daftar kunci tanggal untuk [jumlahHari] hari terakhir, BERAKHIR pada
  /// [akhirSipil] (termasuk hari itu), urut naik.
  static List<String> rentangTanggal(DateTime akhirSipil, {int jumlahHari = 7}) {
    final int n = jumlahHari < 1 ? 1 : jumlahHari;
    final DateTime akhir = DateTime(akhirSipil.year, akhirSipil.month, akhirSipil.day);
    return <String>[
      for (int i = n - 1; i >= 0; i--)
        tanggalKunci(akhir.subtract(Duration(days: i))),
    ];
  }

  /// Jumlah hari (dalam rentang) yang kelima waktunya tercatat.
  int hariPenuh(Map<String, CatatanSholat> catatan) {
    int n = 0;
    for (final String kunci in tanggal) {
      if (catatan[kunci]?.lengkap ?? false) n++;
    }
    return n;
  }
}
