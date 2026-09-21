/// FR-113 & FR-114 — mesin temuan kesehatan (insight) & peringatan dini.
///
/// Murni: seluruh temuan dihitung dari angka yang sudah dicatat pengguna.
///
/// BATAS AMAN (PRD §7.4 & pasal III-11) — WAJIB:
/// * setiap temuan menyebut ANGKANYA sebagai bukti, bukan kesimpulan medis;
/// * tidak ada diagnosis, tidak ada nama penyakit, tidak ada saran obat/dosis;
/// * tiap temuan menyertakan kalimat penegas "bukan diagnosis" pada layar;
/// * tidak memakai kata terlarang (gagal/boros/disiplin/kamu/menakut).
library;

/// Tingkat temuan: `perhatikan` (angka berubah cukup banyak) atau `catat`
/// (sekadar keterangan/ajakan mencatat).
enum TingkatTemuan { perhatikan, catat }

/// Satu temuan kesehatan.
class TemuanKesehatan {
  const TemuanKesehatan({
    required this.judul,
    required this.angka,
    required this.penjelasan,
    required this.tingkat,
    required this.jenis,
  });

  final String judul;

  /// Angka pendukung, ditulis apa adanya (mis. "78,4 kg → 80,1 kg").
  final String angka;
  final String penjelasan;
  final TingkatTemuan tingkat;
  final String jenis;
}

/// Bahan temuan: potongan data yang sudah ada di aplikasi.
class BahanTemuan {
  const BahanTemuan({
    this.berat = const <TitikAngka>[],
    this.sistolik = const <TitikAngka>[],
    this.tidurJam = const <TitikHari>[],
    this.airMl = const <TitikHari>[],
    this.targetAirMl,
    this.suasana = const <TitikHari>[],
    this.menitAktivitas = const <TitikHari>[],
    this.obatTerlewatHari = 0,
    this.hariTerakhirCatat,
  });

  final List<TitikAngka> berat;
  final List<TitikAngka> sistolik;
  final List<TitikHari> tidurJam;
  final List<TitikHari> airMl;
  final double? targetAirMl;
  final List<TitikHari> suasana;
  final List<TitikHari> menitAktivitas;
  final int obatTerlewatHari;
  final DateTime? hariTerakhirCatat;
}

/// Satu titik angka bertanggal.
class TitikAngka {
  const TitikAngka(this.nilai, this.waktu);

  final double nilai;
  final DateTime waktu;
}

/// Satu titik angka harian.
class TitikHari {
  const TitikHari(this.nilai, this.hari);

  final double nilai;
  final DateTime hari;
}

/// Rata-rata nilai pada rentang hari terakhir ([hari] hari; [sampai] = batas).
double? rataRentang(List<TitikHari> data,
    {required DateTime sampai, int hari = 7}) {
  final awal = DateTime(sampai.year, sampai.month, sampai.day)
      .subtract(Duration(days: hari - 1));
  final isi = data
      .where((d) => !d.hari.isBefore(awal) && !d.hari.isAfter(sampai))
      .map((d) => d.nilai)
      .toList();
  if (isi.isEmpty) return null;
  return isi.reduce((a, b) => a + b) / isi.length;
}

/// Cari temuan kesehatan dari bahan yang ada.
///
/// [acuan] = hari ini (dipakai untuk rentang 7/30 hari & batas keaktifan).
List<TemuanKesehatan> cariTemuan(
  BahanTemuan bahan, {
  required DateTime acuan,
}) {
  final temuan = <TemuanKesehatan>[];
  final awalHari = DateTime(acuan.year, acuan.month, acuan.day);

  // 1. Perubahan berat ≥ 2 % dalam 30 hari (butuh dua catatan).
  final berat = [...bahan.berat]..sort((a, b) => a.waktu.compareTo(b.waktu));
  if (berat.length >= 2) {
    final lama = berat.firstWhere(
      (t) => !t.waktu.isBefore(awalHari.subtract(const Duration(days: 30))),
      orElse: () => berat.first,
    );
    final baru = berat.last;
    if (lama.waktu != baru.waktu && lama.nilai > 0) {
      final persen = (baru.nilai - lama.nilai) / lama.nilai * 100;
      if (persen.abs() >= 2) {
        String f(num n) => n.toStringAsFixed(1);
        temuan.add(TemuanKesehatan(
          judul: persen > 0
              ? 'Berat badan naik ${persen.abs().toStringAsFixed(1)} % dalam 30 hari'
              : 'Berat badan turun ${persen.abs().toStringAsFixed(1)} % dalam 30 hari',
          angka: '${f(lama.nilai)} kg → ${f(baru.nilai)} kg',
          penjelasan:
              'Perbandingan catatan ${lama.waktu.day}/${lama.waktu.month} dan '
              '${baru.waktu.day}/${baru.waktu.month}. Ini angka catatan Anda '
              'sendiri, bukan diagnosis.',
          tingkat: TingkatTemuan.perhatikan,
          jenis: 'berat',
        ));
      }
    }
  }

  // 2. Tekanan sistolik: rata-rata 7 hari vs 30 hari berbeda ≥ 10 mmHg.
  final sistolik = bahan.sistolik;
  if (sistolik.isNotEmpty) {
    final r7 = rataRentang(
      sistolik.map((t) => TitikHari(t.nilai, t.waktu)).toList(),
      sampai: awalHari,
      hari: 7,
    );
    final r30 = rataRentang(
      sistolik.map((t) => TitikHari(t.nilai, t.waktu)).toList(),
      sampai: awalHari,
      hari: 30,
    );
    if (r7 != null && r30 != null && (r7 - r30).abs() >= 10) {
      temuan.add(TemuanKesehatan(
        judul: 'Rata-rata tekanan sistolik 7 hari berbeda ≥ 10 mmHg',
        angka:
            'rata-rata 7 hari ${r7.toStringAsFixed(0)} · 30 hari ${r30.toStringAsFixed(0)} mmHg',
        penjelasan: 'Angka dari catatan Anda. Bila terasa mengganggu, '
            'tunjukkan catatan ini saat memeriksakan diri.',
        tingkat: TingkatTemuan.perhatikan,
        jenis: 'tekanan',
      ));
    }
  }

  // 3. Aktivitas fisik: rata-rata 7 hari turun ≥ 20 % dibanding 30 hari.
  final aktivitas = bahan.menitAktivitas;
  final a7 =
      rataRentang(aktivitas, sampai: awalHari, hari: 7);
  final a30 = rataRentang(aktivitas, sampai: awalHari, hari: 30);
  if (a7 != null && a30 != null && a30 > 0 && (a30 - a7) / a30 >= 0.2) {
    temuan.add(TemuanKesehatan(
      judul: 'Menit aktivitas 7 hari terakhir lebih sedikit dari rata-rata 30 hari',
      angka: 'rata-rata 7 hari ${a7.toStringAsFixed(0)} menit · '
          '30 hari ${a30.toStringAsFixed(0)} menit',
      penjelasan: 'Dihitung dari catatan aktivitas Anda sendiri.',
      tingkat: TingkatTemuan.catat,
      jenis: 'aktivitas',
    ));
  }

  // 4. Tidur: rata-rata 7 hari di bawah 6 jam (disebut sebagai angka, bukan vonis).
  final t7 = rataRentang(bahan.tidurJam, sampai: awalHari, hari: 7);
  if (t7 != null && t7 < 6) {
    temuan.add(TemuanKesehatan(
      judul: 'Rata-rata tidur 7 hari di bawah 6 jam',
      angka: 'rata-rata ${t7.toStringAsFixed(1)} jam per hari',
      penjelasan: 'Catatan tidur Anda sendiri. Bila berlanjut dan terasa '
          'mengganggu, catatan ini bisa dibawa saat berkonsultasi.',
      tingkat: TingkatTemuan.perhatikan,
      jenis: 'tidur',
    ));
  }

  // 5. Air: 3 hari terakhir berturut-turut di bawah target yang Anda isi.
  final target = bahan.targetAirMl;
  if (target != null && target > 0 && bahan.airMl.isNotEmpty) {
    var berturut = 0;
    for (var i = 0; i < 3; i++) {
      final hari = awalHari.subtract(Duration(days: i));
      final ada = bahan.airMl.where((d) =>
          d.hari.year == hari.year &&
          d.hari.month == hari.month &&
          d.hari.day == hari.day);
      if (ada.isEmpty) break;
      if (ada.first.nilai >= target) break;
      berturut++;
    }
    if (berturut >= 3) {
      final tiga = bahan.airMl
          .where((d) => !d.hari.isBefore(awalHari.subtract(const Duration(days: 2))))
          .map((d) => d.nilai.toStringAsFixed(0))
          .toList();
      temuan.add(TemuanKesehatan(
        judul: 'Catatan air 3 hari terakhir di bawah target Anda sendiri',
        angka: '${tiga.join(' · ')} ml (target ${target.toStringAsFixed(0)} ml)',
        penjelasan: 'Target diisi oleh Anda di layar air.',
        tingkat: TingkatTemuan.catat,
        jenis: 'air',
      ));
    }
  }

  // 6. Suasana hati: rata-rata 7 hari turun ≥ 1 poin dibanding 30 hari.
  final s7 = rataRentang(bahan.suasana, sampai: awalHari, hari: 7);
  final s30 = rataRentang(bahan.suasana, sampai: awalHari, hari: 30);
  if (s7 != null && s30 != null && (s30 - s7) >= 1) {
    temuan.add(TemuanKesehatan(
      judul: 'Rata-rata suasana hati 7 hari lebih rendah dari 30 hari',
      angka: 'rata-rata 7 hari ${s7.toStringAsFixed(1)} · '
          '30 hari ${s30.toStringAsFixed(1)} (skala 1–5)',
      penjelasan: 'Skala diisi oleh Anda sendiri pada jurnal suasana hati.',
      tingkat: TingkatTemuan.perhatikan,
      jenis: 'suasana',
    ));
  }

  // 7. Obat: dua hari atau lebih terlewat dalam 7 hari terakhir (keterangan).
  if (bahan.obatTerlewatHari >= 2) {
    temuan.add(TemuanKesehatan(
      judul: 'Ada hari tanpa catatan minum obat dalam 7 hari terakhir',
      angka: '${bahan.obatTerlewatHari} hari tanpa catatan',
      penjelasan: 'Dihitung dari jadwal obat yang Anda isi sendiri. Jam minum '
          'tetap mengikuti anjuran dokter.',
      tingkat: TingkatTemuan.catat,
      jenis: 'obat',
    ));
  }

  // 8. Tidak ada catatan selama 14 hari (ajakan mencatat, bukan penilaian).
  final terakhir = bahan.hariTerakhirCatat;
  if (terakhir != null) {
    final jeda = awalHari.difference(DateTime(
      terakhir.year,
      terakhir.month,
      terakhir.day,
    )).inDays;
    if (jeda >= 14) {
      temuan.add(TemuanKesehatan(
        judul: 'Catatan terakhir sudah $jeda hari lalu',
        angka: 'catatan terakhir ${terakhir.day}/${terakhir.month}/${terakhir.year}',
        penjelasan: 'Tidak ada penilaian apa pun pada bagian ini — hanya '
            'keterangan supaya tren tetap bisa dibaca.',
        tingkat: TingkatTemuan.catat,
        jenis: 'catatan',
      ));
    }
  } else {
    temuan.add(const TemuanKesehatan(
      judul: 'Belum ada catatan kesehatan',
      angka: '0 catatan',
      penjelasan: 'Setelah ada catatan (berat, tidur, air, aktivitas, suasana '
          'hati), halaman ini akan menampilkan angka & perubahannya.',
      tingkat: TingkatTemuan.catat,
      jenis: 'catatan',
    ));
  }

  // Urutan tampil: perubahan angka lebih dulu, lalu keterangan.
  temuan.sort((a, b) {
    if (a.tingkat == b.tingkat) return 0;
    return a.tingkat == TingkatTemuan.perhatikan ? -1 : 1;
  });
  return temuan;
}

/// Kalimat penegas yang WAJIB tampil di layar temuan.
const String penegasBukanDiagnosis =
    'Semua angka di halaman ini berasal dari catatan Anda sendiri dan bukan '
    'diagnosis. Aplikasi tidak menentukan penyakit, dosis, atau pengobatan.';

/// Judul tingkat untuk tampilan.
String labelTingkat(TingkatTemuan t) =>
    t == TingkatTemuan.perhatikan ? 'Angka berubah' : 'Keterangan';
