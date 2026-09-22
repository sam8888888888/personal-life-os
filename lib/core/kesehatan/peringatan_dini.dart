/// FR-114 — Peringatan Dini (watch) dari data sendiri.
///
/// PRD: "mis. berat naik 4 minggu berturut-turut, tidur di bawah kebiasaan,
/// aktivitas menurun 14 hari. Ambang batas dapat diatur; tiap peringatan
/// menyertakan saran netral 'pertimbangkan membicarakannya dengan tenaga
/// kesehatan'."
///
/// Batas yang dijaga berkas ini:
/// 1. **Tidak ada klaim medis.** Semua kalimat menyebut angka & rentang yang
///    dipakai, lalu menyerahkan keputusan ke tenaga kesehatan.
/// 2. **Tidak menuduh.** Nada memakai PRD §III-11 (menjelaskan, bukan menilai).
/// 3. Ambang **dapat diatur pengguna** lewat [AmbangPeringatan].
///
/// Fungsi di berkas ini murni (tanpa Flutter & basis data) supaya bisa diuji.
library;

import 'titik_data.dart';

/// Ambang peringatan yang bisa diatur pengguna.
class AmbangPeringatan {
  const AmbangPeringatan({
    this.mingguBeratNaik = 4,
    this.persenTidurTurun = 85,
    this.persenAktivitasTurun = 70,
    this.kenaikanSistolik = 10,
  });

  /// Berapa minggu berturut-turut berat naik supaya dianggap peringatan.
  final int mingguBeratNaik;

  /// Rata-rata tidur 7 hari di bawah persen ini dari rata-rata 30 hari → tanda.
  final int persenTidurTurun;

  /// Aktivitas 14 hari terakhir di bawah persen ini dari 14 hari sebelumnya.
  final int persenAktivitasTurun;

  /// Kenaikan rata-rata sistolik (mmHg) 7 hari terakhir vs 7 hari sebelumnya.
  final int kenaikanSistolik;

  AmbangPeringatan salin({
    int? mingguBeratNaik,
    int? persenTidurTurun,
    int? persenAktivitasTurun,
    int? kenaikanSistolik,
  }) =>
      AmbangPeringatan(
        mingguBeratNaik: mingguBeratNaik ?? this.mingguBeratNaik,
        persenTidurTurun: persenTidurTurun ?? this.persenTidurTurun,
        persenAktivitasTurun:
            persenAktivitasTurun ?? this.persenAktivitasTurun,
        kenaikanSistolik: kenaikanSistolik ?? this.kenaikanSistolik,
      );

  Map<String, int> kePeta() => {
        'minggu_berat_naik': mingguBeratNaik,
        'persen_tidur_turun': persenTidurTurun,
        'persen_aktivitas_turun': persenAktivitasTurun,
        'kenaikan_sistolik': kenaikanSistolik,
      };

  /// Baca dari peta pengaturan (k-v) dengan nilai bawaan bila kosong/rusak.
  static AmbangPeringatan dariPeta(Map<String, String?> peta) {
    const bawaan = AmbangPeringatan();
    int ambil(String kunci, int standar, {int min = 1, int max = 400}) {
      final nilai = int.tryParse((peta[kunci] ?? '').trim());
      if (nilai == null) return standar;
      if (nilai < min) return min;
      if (nilai > max) return max;
      return nilai;
    }

    return AmbangPeringatan(
      mingguBeratNaik: ambil('minggu_berat_naik', bawaan.mingguBeratNaik,
          min: 2, max: 12),
      persenTidurTurun: ambil('persen_tidur_turun', bawaan.persenTidurTurun,
          min: 50, max: 100),
      persenAktivitasTurun:
          ambil('persen_aktivitas_turun', bawaan.persenAktivitasTurun,
              min: 30, max: 100),
      kenaikanSistolik:
          ambil('kenaikan_sistolik', bawaan.kenaikanSistolik, min: 5, max: 60),
    );
  }
}

/// Jenis peringatan dini.
enum JenisPeringatanDini { beratNaik, tidurTurun, aktivitasTurun, tekananNaik }

/// Saran netral yang WAJIB menyertai setiap peringatan (PRD FR-114).
const String saranTenagaKesehatan =
    'Pertimbangkan membicarakannya dengan tenaga kesehatan.';

/// Satu peringatan: menyebut jenis, dasar angkanya, dan saran netral.
class PeringatanDini {
  const PeringatanDini({
    required this.jenis,
    required this.judul,
    required this.dasar,
    this.saran = saranTenagaKesehatan,
  });

  final JenisPeringatanDini jenis;
  final String judul;

  /// Dasar berangka: dari data apa dan berapa nilainya.
  final String dasar;
  final String saran;
}

/// Susun daftar peringatan dini dari data mentah.
///
/// [berat] dalam gram (boleh gram apa pun; hanya arah & selisih yang dipakai),
/// [tidur] dalam menit per malam, [aktivitas] dalam menit per hari,
/// [sistolik] tekanan darah sistolik per pengukuran.
List<PeringatanDini> susunPeringatanDini({
  required DateTime sekarang,
  List<TitikData> berat = const [],
  List<TitikData> tidur = const [],
  List<TitikData> aktivitas = const [],
  List<TitikData> sistolik = const [],
  AmbangPeringatan ambang = const AmbangPeringatan(),
}) {
  final hasil = <PeringatanDini>[];

  // 1. Berat naik berturut-turut (rata-rata per minggu, urut lama → baru).
  final mingguan = _rataMingguan(berat, sekarang, jumlahMinggu: ambang.mingguBeratNaik + 1);
  if (mingguan.length >= ambang.mingguBeratNaik + 1) {
    var naikBerturut = 0;
    for (var i = 1; i < mingguan.length; i++) {
      if (mingguan[i] > mingguan[i - 1]) {
        naikBerturut++;
      } else {
        naikBerturut = 0;
      }
    }
    if (naikBerturut >= ambang.mingguBeratNaik) {
      final awal = mingguan.first;
      final akhir = mingguan.last;
      hasil.add(PeringatanDini(
        jenis: JenisPeringatanDini.beratNaik,
        judul: 'Berat naik ${ambang.mingguBeratNaik} minggu berturut-turut',
        dasar: 'Rata-rata mingguan ${_gramKeKg(awal)} kg → '
            '${_gramKeKg(akhir)} kg (${mingguan.length} minggu terakhir).',
      ));
    }
  }

  // 2. Tidur 7 hari di bawah kebiasaan 30 hari.
  final tujuhHari = _nilaiDalamHari(tidur, sekarang, 7);
  final tigaPuluhHari = _nilaiDalamHari(tidur, sekarang, 30);
  if (tujuhHari.isNotEmpty && tigaPuluhHari.length >= 10) {
    final rata7 = _rata(tujuhHari);
    final rata30 = _rata(tigaPuluhHari);
    final batas = rata30 * ambang.persenTidurTurun / 100;
    if (rata7 < batas) {
      hasil.add(PeringatanDini(
        jenis: JenisPeringatanDini.tidurTurun,
        judul: 'Tidur 7 hari terakhir di bawah kebiasaan',
        dasar: 'Rata-rata ${_jamMenit(rata7)} per malam, sedangkan '
            '30 hari terakhir ${_jamMenit(rata30)} '
            '(${tigaPuluhHari.length} catatan).',
      ));
    }
  }

  // 3. Aktivitas 14 hari terakhir turun dibanding 14 hari sebelumnya.
  final akt14 = _nilaiDalamHari(aktivitas, sekarang, 14);
  final akt14Sebelum = _nilaiDalamHari(aktivitas, sekarang, 28)
      .where((t) => !_dalamHari(t.tanggal, sekarang, 14))
      .toList();
  if (akt14.isNotEmpty && akt14Sebelum.isNotEmpty) {
    final totalKini = akt14.fold<num>(0, (a, b) => a + b.nilai);
    final totalSebelum = akt14Sebelum.fold<num>(0, (a, b) => a + b.nilai);
    if (totalSebelum > 0 &&
        totalKini < totalSebelum * ambang.persenAktivitasTurun / 100) {
      hasil.add(PeringatanDini(
        jenis: JenisPeringatanDini.aktivitasTurun,
        judul: 'Aktivitas 14 hari terakhir menurun',
        dasar: 'Total ${totalKini.round()} menit '
            '(${akt14.length} catatan) vs ${totalSebelum.round()} menit '
            'pada 14 hari sebelumnya.',
      ));
    }
  }

  // 4. Tekanan sistolik naik dibanding 7 hari sebelumnya.
  final sist7 = _nilaiDalamHari(sistolik, sekarang, 7);
  final sistSebelum = _nilaiDalamHari(sistolik, sekarang, 14)
      .where((t) => !_dalamHari(t.tanggal, sekarang, 7))
      .toList();
  if (sist7.isNotEmpty && sistSebelum.isNotEmpty) {
    final rataKini = _rata(sist7);
    final rataSebelum = _rata(sistSebelum);
    if (rataKini - rataSebelum >= ambang.kenaikanSistolik) {
      hasil.add(PeringatanDini(
        jenis: JenisPeringatanDini.tekananNaik,
        judul: 'Tekanan sistolik naik '
            '${(rataKini - rataSebelum).round()} mmHg',
        dasar: 'Rata-rata ${rataKini.round()} mmHg (${sist7.length} ukuran) '
            'vs ${rataSebelum.round()} mmHg sebelumnya.',
      ));
    }
  }

  return hasil;
}

// ---------------------------------------------------------------- bantuan

bool _dalamHari(DateTime tanggal, DateTime sekarang, int hari) {
  final batas = _awalHari(sekarang).subtract(Duration(days: hari - 1));
  final t = _awalHari(tanggal);
  return !t.isBefore(batas) && !t.isAfter(_awalHari(sekarang));
}

DateTime _awalHari(DateTime d) => DateTime(d.year, d.month, d.day);

/// Titik data yang berada dalam [hari] hari terakhir (urut lama → baru).
List<TitikData> _nilaiDalamHari(
    List<TitikData> data, DateTime sekarang, int hari) {
  final isi = data.where((t) => _dalamHari(t.tanggal, sekarang, hari)).toList()
    ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
  return isi;
}

num _rata(List<TitikData> data) {
  if (data.isEmpty) return 0;
  return data.fold<num>(0, (a, b) => a + b.nilai) / data.length;
}

/// Rata-rata per minggu (indeks 0 = paling lama), [jumlahMinggu] minggu terakhir.
List<num> _rataMingguan(List<TitikData> data, DateTime sekarang,
    {required int jumlahMinggu}) {
  final hasil = <num>[];
  for (var mundur = jumlahMinggu - 1; mundur >= 0; mundur--) {
    final akhir = _awalHari(sekarang).subtract(Duration(days: mundur * 7));
    final awal = akhir.subtract(const Duration(days: 6));
    final isi = data.where((t) {
      final tgl = _awalHari(t.tanggal);
      return !tgl.isBefore(awal) && !tgl.isAfter(akhir);
    }).toList();
    if (isi.isNotEmpty) {
      hasil.add(_rata(isi));
    }
  }
  return hasil;
}

String _gramKeKg(num gram) => (gram / 1000).toStringAsFixed(1);

String _jamMenit(num menit) {
  final j = menit ~/ 60;
  final m = (menit % 60).round();
  return '$j jam $m menit';
}
