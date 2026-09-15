/// Repositori kesehatan dasar — FR-101 (dasbor), FR-102 (aktivitas),
/// FR-103 (tidur), FR-111 (pencatat air).
///
/// Prinsip modul kesehatan PRD §7.4 & pasal III-11: aplikasi MENCATAT dan
/// MENUNJUKKAN angka apa adanya — bukan mendiagnosis, bukan menilai, bukan
/// memberi saran dosis. Karena itu:
/// * tidak ada kolom "sehat/tidak sehat" dan tidak ada ambang batas medis;
/// * rata-rata dihitung HANYA dari catatan yang ada (hari kosong tidak
///   dianggap nol), dan bila belum ada catatan hasilnya `null` supaya layar
///   menulis "Belum ada data" — bukan 0 yang menyesatkan;
/// * teks satuan & dosis disimpan apa adanya dari pengguna/kemasan.
///
/// Setiap pembacaan penyimpanan dibungkus batas tunggu [batasBaca] (5 detik)
/// supaya layar tidak menunggu tanpa akhir bila database terkunci.
library;

import 'package:drift/drift.dart';

import '../../core/utils/waktu.dart';
import '../database/database.dart';

/// Batas tunggu bawaan satu pembacaan penyimpanan (aturan gaya proyek).
const Duration batasBacaKesehatan = Duration(seconds: 5);

/// Jenis ukuran tubuh yang dipakai dasbor kesehatan (FR-101).
class JenisUkuran {
  JenisUkuran._();

  static const String berat = 'berat';
  static const String sistolik = 'sistolik';
  static const String diastolik = 'diastolik';
  static const String lingkarPerut = 'lingkar_perut';
}

// ---------------------------------------------------------------------------
// Pembantu murni (tanpa I/O) — dipakai juga oleh obat_repository.dart
// ---------------------------------------------------------------------------

/// Awal hari (00:00) dari [t] — kunci "satu hari" untuk tanggal.
DateTime awalHari(DateTime t) => DateTime(t.year, t.month, t.day);

/// Awal hari berikutnya (batas atas eksklusif).
DateTime akhirHari(DateTime t) => awalHari(t).add(const Duration(days: 1));

/// Apakah [a] dan [b] jatuh pada tanggal kalender yang sama.
bool hariSama(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Apakah kedua waktu menunjuk saat yang sama (dibandingkan per detik, karena
/// kolom tanggal-waktu disimpan sebagai detik sejak epoch).
bool waktuSama(DateTime a, DateTime b) =>
    a.millisecondsSinceEpoch ~/ 1000 == b.millisecondsSinceEpoch ~/ 1000;

/// Jam saja (00:00 + jam:menit dari [t]) untuk membandingkan jam tidur/bangun.
DateTime jamSaja(DateTime t) =>
    DateTime(2000, 1, 1, t.hour, t.minute, t.second);

/// "HH:mm" dari sebuah waktu.
String formatJamHHmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Ubah teks "HH:mm" (atau "H:mm") menjadi jam & menit.
/// Mengembalikan `null` bila teks tidak sah.
({int jam, int menit})? parseJamHHmm(String? teks) {
  final t = (teks ?? '').trim();
  final cocok = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch(t);
  if (cocok == null) return null;
  final jam = int.parse(cocok.group(1)!);
  final menit = int.parse(cocok.group(2)!);
  if (jam > 23 || menit > 59) return null;
  return (jam: jam, menit: menit);
}

/// Teks durasi yang mudah dibaca: 450 -> "7 jam 30 menit", 45 -> "45 menit".
String formatDurasiMenit(int menit) {
  final total = menit < 0 ? 0 : menit;
  final jam = total ~/ 60;
  final sisa = total % 60;
  if (jam == 0) return '$sisa menit';
  if (sisa == 0) return '$jam jam';
  return '$jam jam $sisa menit';
}

/// Angka apa adanya: 68.5 -> "68,5"; 70.0 -> "70" (tanpa nol ekor).
String formatAngkaDesimal(double nilai) {
  if (!nilai.isFinite) return '-';
  if (nilai == nilai.roundToDouble()) return nilai.round().toString();
  return nilai.toStringAsFixed(1).replaceAll('.', ',');
}

/// Teks jumlah air yang mudah dibaca: 1250 -> "1.250 ml".
String formatMl(int ml) {
  final teks = ml.toString();
  final negatif = teks.startsWith('-');
  final angka = negatif ? teks.substring(1) : teks;
  final buf = StringBuffer();
  for (var i = 0; i < angka.length; i++) {
    if (i > 0 && (angka.length - i) % 3 == 0) buf.write('.');
    buf.write(angka[i]);
  }
  return '${negatif ? '-' : ''}$buf ml';
}

/// Tingkat usaha aktivitas (FR-102) — pilihan pengguna, bukan penilaian app.
enum IntensitasAktivitas {
  ringan('ringan', 'Ringan'),
  sedang('sedang', 'Sedang'),
  berat('berat', 'Berat');

  const IntensitasAktivitas(this.nilaiDb, this.label);

  final String nilaiDb;
  final String label;

  static IntensitasAktivitas dariDb(String? teks) {
    final cari = (teks ?? '').trim().toLowerCase();
    for (final n in values) {
      if (n.nilaiDb == cari) return n;
    }
    return IntensitasAktivitas.sedang;
  }
}

// ---------------------------------------------------------------------------
// Hasil hitung (nilai kembalian yang siap dipakai layar)
// ---------------------------------------------------------------------------

/// Pasangan tekanan darah yang tercatat pada hari yang sama.
class TekananDarah {
  const TekananDarah({
    required this.sistolik,
    required this.diastolik,
    required this.tanggal,
  });

  final int sistolik;
  final int diastolik;
  final DateTime tanggal;

  String get teks => '$sistolik / $diastolik mmHg';
}

/// Ringkasan aktivitas (FR-102) — total menit, bukan penilaian.
class RingkasanAktivitas {
  const RingkasanAktivitas({
    required this.menitHariIni,
    required this.menit7Hari,
    required this.menit30Hari,
    required this.jumlahCatatan7Hari,
  });

  final int menitHariIni;
  final int menit7Hari;
  final int menit30Hari;
  final int jumlahCatatan7Hari;

  bool get adaCatatan => jumlahCatatan7Hari > 0;
}

/// Satu batang grafik harian (tanggal + angka hari itu).
class BatangHarian {
  const BatangHarian({required this.tanggal, required this.nilai});

  final DateTime tanggal;
  final int nilai;
}

/// Ringkasan tidur (FR-103). Rata-rata `null` = belum ada catatan.
class RingkasanTidur {
  const RingkasanTidur({
    required this.rataRata7HariMenit,
    required this.rataRata30HariMenit,
    required this.jumlahMalam7Hari,
    required this.jumlahMalam30Hari,
  });

  final int? rataRata7HariMenit;
  final int? rataRata30HariMenit;
  final int jumlahMalam7Hari;
  final int jumlahMalam30Hari;

  bool get adaCatatan => jumlahMalam7Hari > 0;
}

/// Ringkasan air hari ini (FR-111).
class RingkasanAir {
  const RingkasanAir({
    required this.totalMl,
    required this.jumlahCatatan,
    required this.targetMl,
  });

  final int totalMl;
  final int jumlahCatatan;
  final int targetMl;

  bool get adaCatatan => jumlahCatatan > 0;

  /// Sisa menuju target; 0 bila sudah mencapai/melewati target (tanpa nada
  /// menyalahkan).
  int get sisaMl => totalMl >= targetMl ? 0 : targetMl - totalMl;
}

/// Satu batang riwayat air harian.
class BatangAirHarian {
  const BatangAirHarian({required this.tanggal, required this.totalMl});

  final DateTime tanggal;
  final int totalMl;
}

// ---------------------------------------------------------------------------
// Repositori
// ---------------------------------------------------------------------------

/// Penyimpanan & hitungan kesehatan dasar di atas skema v4.
class KesehatanRepository {
  KesehatanRepository(
    this.db, {
    DateTime Function()? jamSekarang,
    this.batasBaca = batasBacaKesehatan,
  }) : _jam = jamSekarang ?? waktuSekarang;

  final AppDatabase db;
  final DateTime Function() _jam;

  /// Batas tunggu satu pembacaan penyimpanan (bawaan 5 detik).
  final Duration batasBaca;

  Future<T> _baca<T>(Future<T> aksi) => aksi.timeout(batasBaca);

  /// Jalankan hitungan yang membaca penyimpanan, dengan batas tunggu yang sama.
  Future<T> _hitung<T>(Future<T> Function() aksi) => _baca(aksi());

  // =========================================================================
  // Ukuran tubuh (dipakai FR-101: berat & tekanan darah terakhir)
  // =========================================================================

  /// Simpan satu angka tubuh. Satuan disimpan apa adanya.
  Future<UkuranTubuhData> catatUkuran({
    required String jenis,
    required double nilai,
    String satuan = 'kg',
    DateTime? tanggal,
    String? catatan,
  }) async {
    final j = jenis.trim();
    if (j.isEmpty) {
      throw ArgumentError('Jenis ukuran tidak boleh kosong.');
    }
    if (!nilai.isFinite || nilai <= 0) {
      throw ArgumentError('Nilai ukuran harus angka lebih dari 0.');
    }
    final s = satuan.trim();
    return db.into(db.ukuranTubuh).insertReturning(UkuranTubuhCompanion.insert(
          jenis: j,
          nilai: nilai,
          satuan: Value(s.isEmpty ? 'kg' : s),
          tanggal: awalHari(tanggal ?? _jam()),
          catatan: Value(_bersih(catatan)),
        ));
  }

  /// Catat tekanan darah sebagai SATU pasangan (dua baris, tanggal sama)
  /// supaya dasbor bisa menampilkannya sebagai "120 / 80 mmHg".
  Future<void> catatTekananDarah({
    required int sistolik,
    required int diastolik,
    DateTime? tanggal,
    String? catatan,
  }) async {
    if (sistolik < 40 || sistolik > 300) {
      throw ArgumentError('Angka atas (sistolik) harus 40–300 mmHg.');
    }
    if (diastolik < 20 || diastolik > 200) {
      throw ArgumentError('Angka bawah (diastolik) harus 20–200 mmHg.');
    }
    final tgl = awalHari(tanggal ?? _jam());
    await db.transaction(() async {
      await catatUkuran(
        jenis: JenisUkuran.sistolik,
        nilai: sistolik.toDouble(),
        satuan: 'mmHg',
        tanggal: tgl,
        catatan: catatan,
      );
      await catatUkuran(
        jenis: JenisUkuran.diastolik,
        nilai: diastolik.toDouble(),
        satuan: 'mmHg',
        tanggal: tgl,
        catatan: catatan,
      );
    });
  }

  /// Angka terakhir untuk satu [jenis]; `null` bila belum ada catatan.
  Future<UkuranTubuhData?> ukuranTerbaru(String jenis) => _baca(
        (db.select(db.ukuranTubuh)
              ..where((u) => u.jenis.equals(jenis.trim()))
              ..orderBy([
                (u) => OrderingTerm.desc(u.tanggal),
                (u) => OrderingTerm.desc(u.dicatatPada),
                (u) => OrderingTerm.desc(u.id),
              ])
              ..limit(1))
            .getSingleOrNull(),
      );

  /// Riwayat [jenis] selama [hari] hari terakhir (termasuk hari ini).
  Future<List<UkuranTubuhData>> riwayatUkuran(
    String jenis, {
    int hari = 30,
    DateTime? sampai,
  }) {
    final akhir = awalHari(sampai ?? _jam());
    final mulai = akhir.subtract(Duration(days: _jumlahHari(hari) - 1));
    return _baca(
      (db.select(db.ukuranTubuh)
            ..where((u) =>
                u.jenis.equals(jenis.trim()) &
                u.tanggal.isBiggerOrEqualValue(mulai) &
                u.tanggal.isSmallerOrEqualValue(akhir))
            ..orderBy([(u) => OrderingTerm.asc(u.tanggal)]))
          .get(),
    );
  }

  /// Tekanan darah terakhir yang punya pasangan lengkap; `null` bila belum ada
  /// (atau bila hanya satu dari dua angka yang tercatat).
  Future<TekananDarah?> tekananDarahTerakhir() => _hitung(() async {
        final baris = await (db.select(db.ukuranTubuh)
              ..where((u) =>
                  u.jenis.equals(JenisUkuran.sistolik) |
                  u.jenis.equals(JenisUkuran.diastolik))
              ..orderBy([
                // Tanggal catatan jadi urutan utama; bila ada dua catatan pada
                // tanggal sama, yang terbaru dicatat dipakai lebih dulu.
                (u) => OrderingTerm.desc(u.tanggal),
                (u) => OrderingTerm.desc(u.dicatatPada),
                (u) => OrderingTerm.desc(u.id),
              ]))
            .get();
        for (final atas in baris.where((u) => u.jenis == JenisUkuran.sistolik)) {
          for (final bawah in baris) {
            if (bawah.jenis == JenisUkuran.diastolik &&
                hariSama(bawah.tanggal, atas.tanggal)) {
              return TekananDarah(
                sistolik: atas.nilai.round(),
                diastolik: bawah.nilai.round(),
                tanggal: awalHari(atas.tanggal),
              );
            }
          }
        }
        return null;
      });

  Future<int> hapusUkuran(int id) =>
      (db.delete(db.ukuranTubuh)..where((u) => u.id.equals(id))).go();

  // =========================================================================
  // Aktivitas (FR-102)
  // =========================================================================

  /// Simpan satu catatan aktivitas. [jarakKm] boleh kosong.
  Future<Aktivita> catatAktivitas({
    required String jenis,
    required int durasiMenit,
    double? jarakKm,
    IntensitasAktivitas intensitas = IntensitasAktivitas.sedang,
    DateTime? tanggal,
    String? catatan,
  }) async {
    final j = jenis.trim();
    if (j.isEmpty) {
      throw ArgumentError('Jenis aktivitas tidak boleh kosong.');
    }
    if (durasiMenit < 1 || durasiMenit > 1440) {
      throw ArgumentError('Durasi aktivitas harus 1–1440 menit.');
    }
    if (jarakKm != null && (!jarakKm.isFinite || jarakKm < 0)) {
      throw ArgumentError('Jarak aktivitas tidak boleh negatif.');
    }
    return db.into(db.aktivitas).insertReturning(AktivitasCompanion.insert(
          jenis: j,
          durasiMenit: durasiMenit,
          jarakKm: Value(jarakKm),
          intensitas: Value(intensitas.nilaiDb),
          tanggal: awalHari(tanggal ?? _jam()),
          catatan: Value(_bersih(catatan)),
        ));
  }

  Future<int> hapusAktivitas(int id) =>
      (db.delete(db.aktivitas)..where((a) => a.id.equals(id))).go();

  /// Catatan aktivitas [hari] hari terakhir (termasuk hari ini), terbaru dulu.
  Future<List<Aktivita>> daftarAktivitas({int hari = 7, DateTime? sampai}) {
    final akhir = awalHari(sampai ?? _jam());
    final mulai = akhir.subtract(Duration(days: _jumlahHari(hari) - 1));
    return _baca(
      (db.select(db.aktivitas)
            ..where((a) =>
                a.tanggal.isBiggerOrEqualValue(mulai) &
                a.tanggal.isSmallerOrEqualValue(akhir))
            ..orderBy([
              (a) => OrderingTerm.desc(a.tanggal),
              (a) => OrderingTerm.desc(a.id),
            ]))
          .get(),
    );
  }

  /// Ringkasan total menit 7 hari & 30 hari (FR-102).
  Future<RingkasanAktivitas> ringkasanAktivitas({DateTime? acuan}) async {
    final kini = awalHari(acuan ?? _jam());
    final tujuh = await daftarAktivitas(hari: 7, sampai: kini);
    final tigapuluh = await daftarAktivitas(hari: 30, sampai: kini);
    return RingkasanAktivitas(
      menitHariIni: tujuh
          .where((a) => hariSama(a.tanggal, kini))
          .fold<int>(0, (s, a) => s + a.durasiMenit),
      menit7Hari: tujuh.fold<int>(0, (s, a) => s + a.durasiMenit),
      menit30Hari: tigapuluh.fold<int>(0, (s, a) => s + a.durasiMenit),
      jumlahCatatan7Hari: tujuh.length,
    );
  }

  /// Batang grafik aktivitas: satu batang per hari, [hari] hari, tua -> baru.
  /// Hari tanpa catatan bernilai 0 menit (grafik batang, bukan klaim kosong).
  Future<List<BatangHarian>> batangAktivitas({
    int hari = 7,
    DateTime? sampai,
  }) async {
    final jumlah = _jumlahHari(hari);
    final akhir = awalHari(sampai ?? _jam());
    final daftar = await daftarAktivitas(hari: jumlah, sampai: akhir);
    final total = <String, int>{};
    for (final a in daftar) {
      final k = _kunciHari(a.tanggal);
      total[k] = (total[k] ?? 0) + a.durasiMenit;
    }
    final batang = <BatangHarian>[];
    for (var i = jumlah - 1; i >= 0; i--) {
      final tgl = akhir.subtract(Duration(days: i));
      batang.add(BatangHarian(tanggal: tgl, nilai: total[_kunciHari(tgl)] ?? 0));
    }
    return batang;
  }

  // =========================================================================
  // Tidur (FR-103)
  // =========================================================================

  /// Hitung durasi tidur dalam menit, termasuk lintas tengah malam.
  ///
  /// Bila jam bangun tidak setelah jam tidur, tidur dianggap melewati tengah
  /// malam (mis. 23:00 -> 06:30 = 450 menit). Jam yang sama persis = 0 menit.
  static int hitungDurasiMenit(DateTime jamTidur, DateTime jamBangun) {
    if (jamBangun.isAtSameMomentAs(jamTidur)) return 0;
    final selisih = jamBangun.difference(jamTidur).inMinutes;
    return selisih > 0 ? selisih : selisih + 1440;
  }

  /// Simpan catatan satu malam (tanggal = hari bangun). Menyimpan lagi untuk
  /// tanggal yang sama MEMPERBARUI catatan malam itu (satu catatan per malam).
  ///
  /// [durasiMenit] boleh diisi bila pengguna ingin mengoreksi hasil hitung.
  Future<TidurData> simpanTidur({
    required DateTime tanggal,
    required DateTime jamTidur,
    required DateTime jamBangun,
    int? durasiMenit,
    int? kualitas,
    int tidurSiangMenit = 0,
    String? catatan,
  }) async {
    if (kualitas != null && (kualitas < 1 || kualitas > 5)) {
      throw ArgumentError('Kualitas tidur, bila diisi, bernilai 1–5.');
    }
    if (tidurSiangMenit < 0 || tidurSiangMenit > 1440) {
      throw ArgumentError('Tidur siang harus 0–1440 menit.');
    }
    final malam = awalHari(tanggal);
    // Tanggal jam tidur/bangun tidak dipakai; yang menentukan adalah [tanggal]
    // (hari bangun) agar tetap satu catatan per malam.
    final tidurLewatTengahMalam = !jamSaja(jamBangun).isAfter(jamSaja(jamTidur));
    final tidur = DateTime(malam.year, malam.month, malam.day, jamTidur.hour,
        jamTidur.minute);
    final bangun = DateTime(malam.year, malam.month, malam.day, jamBangun.hour,
        jamBangun.minute);
    final jamTidurFinal = tidurLewatTengahMalam
        ? tidur.subtract(const Duration(days: 1))
        : tidur;
    final pakai = durasiMenit ?? hitungDurasiMenit(jamTidurFinal, bangun);
    if (pakai < 1) {
      throw ArgumentError('Durasi tidur harus lebih dari 0 menit.');
    }
    final isi = TidurCompanion.insert(
      tanggal: malam,
      jamTidur: jamTidurFinal,
      jamBangun: bangun,
      durasiMenit: pakai,
      kualitas: Value(kualitas),
      tidurSiangMenit: Value(tidurSiangMenit),
      catatan: Value(_bersih(catatan)),
      dicatatPada: Value(_jam()),
    );
    return db.into(db.tidur).insertReturning(
          isi,
          onConflict: DoUpdate(
            (_) => TidurCompanion(
              jamTidur: Value(jamTidurFinal),
              jamBangun: Value(bangun),
              durasiMenit: Value(pakai),
              kualitas: Value(kualitas),
              tidurSiangMenit: Value(tidurSiangMenit),
              catatan: Value(_bersih(catatan)),
              dicatatPada: Value(_jam()),
            ),
            target: [db.tidur.tanggal],
          ),
        );
  }

  /// Catatan untuk satu malam (tanggal = hari bangun); `null` bila belum ada.
  Future<TidurData?> tidurMalam(DateTime tanggal) => _baca(
        (db.select(db.tidur)
              ..where((t) => t.tanggal.equals(awalHari(tanggal))))
            .getSingleOrNull(),
      );

  /// Riwayat [hari] hari terakhir (termasuk hari ini), terbaru dulu.
  Future<List<TidurData>> riwayatTidur({int hari = 7, DateTime? sampai}) {
    final akhir = awalHari(sampai ?? _jam());
    final mulai = akhir.subtract(Duration(days: _jumlahHari(hari) - 1));
    return _baca(
      (db.select(db.tidur)
            ..where((t) =>
                t.tanggal.isBiggerOrEqualValue(mulai) &
                t.tanggal.isSmallerOrEqualValue(akhir))
            ..orderBy([(t) => OrderingTerm.desc(t.tanggal)]))
          .get(),
    );
  }

  /// Rata-rata durasi tidur [hari] hari terakhir. `null` = belum ada catatan
  /// (hari tanpa catatan TIDAK dihitung sebagai 0 menit).
  Future<int?> rataRataDurasiMenit({int hari = 7, DateTime? sampai}) async {
    final daftar = await riwayatTidur(hari: hari, sampai: sampai);
    if (daftar.isEmpty) return null;
    final total = daftar.fold<int>(0, (s, t) => s + t.durasiMenit);
    return (total / daftar.length).round();
  }

  /// Ringkasan tidur 7 & 30 hari (FR-101/FR-103).
  Future<RingkasanTidur> ringkasanTidur({DateTime? acuan}) async {
    final kini = awalHari(acuan ?? _jam());
    final tujuh = await riwayatTidur(hari: 7, sampai: kini);
    final tigapuluh = await riwayatTidur(hari: 30, sampai: kini);
    return RingkasanTidur(
      rataRata7HariMenit:
          tujuh.isEmpty ? null : (tujuh.fold<int>(0, (s, t) => s + t.durasiMenit) / tujuh.length).round(),
      rataRata30HariMenit: tigapuluh.isEmpty
          ? null
          : (tigapuluh.fold<int>(0, (s, t) => s + t.durasiMenit) / tigapuluh.length).round(),
      jumlahMalam7Hari: tujuh.length,
      jumlahMalam30Hari: tigapuluh.length,
    );
  }

  Future<int> hapusTidur(int id) =>
      (db.delete(db.tidur)..where((t) => t.id.equals(id))).go();

  // =========================================================================
  // Air (FR-111)
  // =========================================================================

  static const int ukuranGelasBawaanMl = 250;
  static const int ukuranBotolBawaanMl = 500;
  static const int targetAirBawaanMl = 2000;

  static const String kunciTargetAir = 'kesehatan.target_air_ml';
  static const String kunciUkuranGelas = 'kesehatan.ukuran_gelas_ml';

  /// Catat satu gelas/botol air. Bawaan 250 ml (ukuran gelas bisa diatur).
  Future<CatatanAirData> catatAir({
    int jumlahMl = ukuranGelasBawaanMl,
    DateTime? waktu,
    String? catatan,
  }) async {
    if (jumlahMl < 1 || jumlahMl > 5000) {
      throw ArgumentError('Jumlah air per catatan harus 1–5000 ml.');
    }
    return db.into(db.catatanAir).insertReturning(CatatanAirCompanion.insert(
          waktu: waktu ?? _jam(),
          jumlahMl: Value(jumlahMl),
          catatan: Value(_bersih(catatan)),
        ));
  }

  Future<int> hapusAir(int id) =>
      (db.delete(db.catatanAir)..where((c) => c.id.equals(id))).go();

  /// Catatan air dalam rentang [dari] (termasuk) sampai [sampai] (tidak
  /// termasuk), terbaru dulu.
  Future<List<CatatanAirData>> catatanAirRentang({
    required DateTime dari,
    required DateTime sampai,
  }) =>
      _baca(
        (db.select(db.catatanAir)
              ..where((c) =>
                  c.waktu.isBiggerOrEqualValue(dari) &
                  c.waktu.isSmallerThanValue(sampai))
              ..orderBy([(c) => OrderingTerm.desc(c.waktu)]))
            .get(),
      );

  /// Ringkasan air satu hari (bawaan: hari ini menurut [acuan]).
  Future<RingkasanAir> ringkasanAir({DateTime? acuan}) async {
    final kini = awalHari(acuan ?? _jam());
    final daftar =
        await catatanAirRentang(dari: kini, sampai: akhirHari(kini));
    return RingkasanAir(
      totalMl: daftar.fold<int>(0, (s, c) => s + c.jumlahMl),
      jumlahCatatan: daftar.length,
      targetMl: await targetAirMl(),
    );
  }

  /// Riwayat air harian [hari] hari terakhir (tua -> baru) untuk grafik.
  Future<List<BatangAirHarian>> riwayatAirHarian({
    int hari = 7,
    DateTime? sampai,
  }) async {
    final jumlah = _jumlahHari(hari);
    final akhir = awalHari(sampai ?? _jam());
    final mulai = akhir.subtract(Duration(days: jumlah - 1));
    final daftar =
        await catatanAirRentang(dari: mulai, sampai: akhirHari(akhir));
    final total = <String, int>{};
    for (final c in daftar) {
      final k = _kunciHari(c.waktu);
      total[k] = (total[k] ?? 0) + c.jumlahMl;
    }
    final batang = <BatangAirHarian>[];
    for (var i = jumlah - 1; i >= 0; i--) {
      final tgl = akhir.subtract(Duration(days: i));
      batang.add(
        BatangAirHarian(tanggal: tgl, totalMl: total[_kunciHari(tgl)] ?? 0),
      );
    }
    return batang;
  }

  /// Target air harian (bawaan 2000 ml; bisa diatur pengguna).
  Future<int> targetAirMl() =>
      _baca(_angkaPengaturan(kunciTargetAir, targetAirBawaanMl));

  /// Simpan target air harian (500–10.000 ml).
  Future<void> simpanTargetAirMl(int ml) =>
      _simpanAngka(kunciTargetAir, ml, 500, 10000, 'Target air harian');

  /// Ukuran gelas yang dipakai tombol "+ gelas" (bawaan 250 ml).
  Future<int> ukuranGelasMl() =>
      _baca(_angkaPengaturan(kunciUkuranGelas, ukuranGelasBawaanMl));

  /// Simpan ukuran gelas (50–2000 ml).
  Future<void> simpanUkuranGelasMl(int ml) =>
      _simpanAngka(kunciUkuranGelas, ml, 50, 2000, 'Ukuran gelas');

  // =========================================================================
  // Pembantu dalaman
  // =========================================================================

  int _jumlahHari(int hari) => hari < 1 ? 1 : hari;

  String _kunciHari(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  String? _bersih(String? teks) {
    final t = teks?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Future<int> _angkaPengaturan(String kunci, int bawaan) async {
    final baris = await (db.select(db.pengaturan)
          ..where((p) => p.kunci.equals(kunci)))
        .getSingleOrNull();
    final nilai = int.tryParse((baris?.nilai ?? '').trim());
    return (nilai == null || nilai < 1) ? bawaan : nilai;
  }

  Future<void> _simpanAngka(
    String kunci,
    int nilai,
    int min,
    int maks,
    String label,
  ) async {
    if (nilai < min || nilai > maks) {
      throw ArgumentError('$label harus $min–$maks ml.');
    }
    await db.into(db.pengaturan).insert(
          PengaturanCompanion.insert(kunci: kunci, nilai: '$nilai'),
          onConflict: DoUpdate(
            (_) => PengaturanCompanion(nilai: Value('$nilai')),
            target: [db.pengaturan.kunci],
          ),
        );
  }
}
