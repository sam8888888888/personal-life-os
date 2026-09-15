/// Repositori ibadah lanjutan (FR-91/92/93/95/100) — puasa, Quran, dzikir,
/// muhasabah.
///
/// Aturan yang dipegang berkas ini:
/// 1. **Data mentah apa adanya.** Semua angka yang ditampilkan layar dihitung
///    dari baris tabel, bukan dari nilai turunan yang disimpan. Jadi tidak ada
///    dua angka yang bisa saling bertentangan.
/// 2. **Tanpa penilaian.** Catatan "tidak puasa" atau kotak refleksi yang
///    kosong disimpan apa adanya. Repositori tidak menghitung skor, tidak
///    menandai keberhasilan/ketidakhadiran, dan tidak menetapkan kewajiban.
/// 3. **Satu tanggal satu kunci.** Puasa unik per (tanggal, jenis) dan
///    muhasabah unik per tanggal — dijaga indeks unik SQL skema v4, dan
///    penyimpanan memakai `onConflict` supaya menyimpan dua kali tidak
///    menggandakan baris.
/// 4. **Batas baca.** Setiap pembacaan dibungkus [batasBaca] (5 detik) supaya
///    antarmuka tidak menggantung bila penyimpanan bermasalah.
library;

import 'package:drift/drift.dart';

import '../../core/utils/waktu.dart';
import '../database/database.dart';
import '../database/tabel.dart';

/// Batas waktu satu pembacaan penyimpanan (aturan proyek: 5 detik).
const Duration batasBaca = Duration(seconds: 5);

// ---------------------------------------------------------------------------
// Jenis & status (nilai teks di database ditulis di sini satu kali saja)
// ---------------------------------------------------------------------------

/// Jenis puasa yang dicatat pengguna (FR-92).
enum JenisPuasa {
  ramadan('Ramadan', 'ramadan', 'Puasa bulan Ramadan.'),
  seninKamis('Senin & Kamis', 'senin_kamis', 'Puasa sunah Senin dan Kamis.'),
  ayyamulBidh('Ayyamul Bidh', 'ayyamul_bidh', 'Tanggal 13, 14, 15 bulan Hijriah.'),
  sunnah('Puasa sunah lain', 'sunnah', 'Misalnya Asyura, Arafah, atau puasa sunah lain.'),
  qadha('Qadha Ramadan', 'qadha', 'Mengganti puasa Ramadan yang belum dijalankan.'),
  custom('Lain-lain (isi sendiri)', 'custom', 'Jenis puasa yang Anda tulis sendiri.');

  const JenisPuasa(this.label, this.nilaiDb, this.keterangan);

  final String label;
  final String nilaiDb;
  final String keterangan;

  static JenisPuasa dariDb(String nilai) => JenisPuasa.values.firstWhere(
        (JenisPuasa j) => j.nilaiDb == nilai,
        orElse: () => JenisPuasa.custom,
      );
}

/// Status satu catatan puasa. "Tidak" dicatat apa adanya — tanpa penilaian.
enum StatusPuasa {
  puasa('Puasa', 'puasa'),
  tidak('Tidak puasa', 'tidak');

  const StatusPuasa(this.label, this.nilaiDb);

  final String label;
  final String nilaiDb;

  static StatusPuasa dariDb(String nilai) =>
      nilai == tidak.nilaiDb ? StatusPuasa.tidak : StatusPuasa.puasa;
}

/// Jenis catatan Quran (FR-93).
enum JenisQuran {
  baca('Baca', 'baca'),
  dengar('Dengar', 'dengar'),
  hafal('Hafal baru', 'hafal'),
  murajaah('Murajaah', 'murajaah');

  const JenisQuran(this.label, this.nilaiDb);

  final String label;
  final String nilaiDb;

  static JenisQuran dariDb(String nilai) => JenisQuran.values.firstWhere(
        (JenisQuran j) => j.nilaiDb == nilai,
        orElse: () => JenisQuran.baca,
      );
}

/// Satuan catatan Quran. Satuan berbeda TIDAK dijumlahkan menjadi satu angka.
enum SatuanQuran {
  halaman('halaman', 'halaman'),
  ayat('ayat', 'ayat'),
  menit('menit', 'menit'),
  juz('juz', 'juz');

  const SatuanQuran(this.label, this.nilaiDb);

  final String label;
  final String nilaiDb;

  static SatuanQuran dariDb(String nilai) => SatuanQuran.values.firstWhere(
        (SatuanQuran s) => s.nilaiDb == nilai,
        orElse: () => SatuanQuran.halaman,
      );
}

/// Sesi dzikir (FR-95).
enum JenisDzikir {
  pagi('Pagi', 'pagi'),
  petang('Petang', 'petang'),
  sebelumTidur('Sebelum tidur', 'sebelum_tidur'),
  custom('Sesi lain (isi sendiri)', 'custom');

  const JenisDzikir(this.label, this.nilaiDb);

  final String label;
  final String nilaiDb;

  static JenisDzikir dariDb(String nilai) => JenisDzikir.values.firstWhere(
        (JenisDzikir j) => j.nilaiDb == nilai,
        orElse: () => JenisDzikir.custom,
      );
}

/// Enam butir refleksi malam (FR-100). Isinya pertanyaan untuk pengguna
/// sendiri, bukan penilaian aplikasi.
enum ButirRefleksi {
  sholatTerjaga(
      'sholatTerjaga', 'Sholat terjaga', 'Apakah sholat hari ini terjaga?'),
  mengingatAllah(
      'mengingatAllah', 'Mengingat Allah', 'Apakah hari ini ada waktu mengingat Allah?'),
  membantuOrang(
      'membantuOrang', 'Membantu orang', 'Apakah hari ini saya membantu orang?'),
  menghindariDisesali(
      'menghindariDisesali', 'Menghindari hal yang disesali',
      'Apakah hari ini saya menghindari hal yang saya sesali?'),
  belajar('belajar', 'Belajar', 'Apakah hari ini saya belajar sesuatu?'),
  bersyukur('bersyukur', 'Bersyukur', 'Apakah hari ini saya bersyukur?');

  const ButirRefleksi(this.kunci, this.label, this.pertanyaan);

  final String kunci;
  final String label;
  final String pertanyaan;
}

/// Nilai enam butir refleksi untuk satu tanggal.
///
/// `null` berarti **belum diisi** — bukan berarti "tidak dilakukan". Ini
/// perbedaan yang sengaja dipertahankan di seluruh aplikasi.
class NilaiRefleksi {
  const NilaiRefleksi({
    this.sholatTerjaga,
    this.mengingatAllah,
    this.membantuOrang,
    this.menghindariDisesali,
    this.belajar,
    this.bersyukur,
  });

  final bool? sholatTerjaga;
  final bool? mengingatAllah;
  final bool? membantuOrang;
  final bool? menghindariDisesali;
  final bool? belajar;
  final bool? bersyukur;

  /// Semua butir belum diisi.
  static const NilaiRefleksi kosong = NilaiRefleksi();

  bool? nilai(ButirRefleksi butir) {
    switch (butir) {
      case ButirRefleksi.sholatTerjaga:
        return sholatTerjaga;
      case ButirRefleksi.mengingatAllah:
        return mengingatAllah;
      case ButirRefleksi.membantuOrang:
        return membantuOrang;
      case ButirRefleksi.menghindariDisesali:
        return menghindariDisesali;
      case ButirRefleksi.belajar:
        return belajar;
      case ButirRefleksi.bersyukur:
        return bersyukur;
    }
  }

  NilaiRefleksi dengan(ButirRefleksi butir, bool? nilaiBaru) => NilaiRefleksi(
        sholatTerjaga:
            butir == ButirRefleksi.sholatTerjaga ? nilaiBaru : sholatTerjaga,
        mengingatAllah:
            butir == ButirRefleksi.mengingatAllah ? nilaiBaru : mengingatAllah,
        membantuOrang:
            butir == ButirRefleksi.membantuOrang ? nilaiBaru : membantuOrang,
        menghindariDisesali: butir == ButirRefleksi.menghindariDisesali
            ? nilaiBaru
            : menghindariDisesali,
        belajar: butir == ButirRefleksi.belajar ? nilaiBaru : belajar,
        bersyukur: butir == ButirRefleksi.bersyukur ? nilaiBaru : bersyukur,
      );

  /// Jumlah butir yang sudah diisi (boleh diisi "ya" maupun "belum").
  int get jumlahTerisi => ButirRefleksi.values
      .where((ButirRefleksi b) => nilai(b) != null)
      .length;

  Map<String, bool?> kePeta() => <String, bool?>{
        for (final ButirRefleksi b in ButirRefleksi.values) b.kunci: nilai(b),
      };

  static NilaiRefleksi dariBaris(RefleksiMuhasabahData? baris) =>
      baris == null
          ? NilaiRefleksi.kosong
          : NilaiRefleksi(
              sholatTerjaga: baris.sholatTerjaga,
              mengingatAllah: baris.mengingatAllah,
              membantuOrang: baris.membantuOrang,
              menghindariDisesali: baris.menghindariDisesali,
              belajar: baris.belajar,
              bersyukur: baris.bersyukur,
            );
}

// ---------------------------------------------------------------------------
// Ringkasan hasil hitung (fungsi murni — mudah diuji tanpa basis data)
// ---------------------------------------------------------------------------

/// Ringkasan catatan puasa satu rentang.
class RingkasanPuasa {
  const RingkasanPuasa({required this.puasa, required this.tidak});

  final int puasa;
  final int tidak;

  int get total => puasa + tidak;
  bool get kosong => total == 0;
}

/// Hitungan qadha dari catatan pengguna sendiri (bukan penetapan aplikasi).
///
/// [ramadhanTanpaPuasa] = banyak catatan Ramadan berstatus "tidak puasa".
/// [qadhaTercatat] = banyak catatan qadha berstatus "puasa".
class HitungQadha {
  const HitungQadha({required this.ramadhanTanpaPuasa, required this.qadhaTercatat});

  final int ramadhanTanpaPuasa;
  final int qadhaTercatat;

  /// Selisih apa adanya (boleh negatif bila catatan qadha lebih banyak).
  int get selisih => ramadhanTanpaPuasa - qadhaTercatat;

  bool get adaCatatan => ramadhanTanpaPuasa > 0 || qadhaTercatat > 0;
}

RingkasanPuasa hitungRingkasanPuasa(List<LogPuasaData> baris) {
  int puasa = 0;
  int tidak = 0;
  for (final LogPuasaData b in baris) {
    if (StatusPuasa.dariDb(b.status) == StatusPuasa.puasa) {
      puasa += 1;
    } else {
      tidak += 1;
    }
  }
  return RingkasanPuasa(puasa: puasa, tidak: tidak);
}

HitungQadha hitungQadha(List<LogPuasaData> semuaBaris) {
  int ramadhanTanpaPuasa = 0;
  int qadhaTercatat = 0;
  for (final LogPuasaData b in semuaBaris) {
    final JenisPuasa jenis = JenisPuasa.dariDb(b.jenis);
    final StatusPuasa status = StatusPuasa.dariDb(b.status);
    if (jenis == JenisPuasa.ramadan && status == StatusPuasa.tidak) {
      ramadhanTanpaPuasa += 1;
    }
    if (jenis == JenisPuasa.qadha && status == StatusPuasa.puasa) {
      qadhaTercatat += 1;
    }
  }
  return HitungQadha(
      ramadhanTanpaPuasa: ramadhanTanpaPuasa, qadhaTercatat: qadhaTercatat);
}

/// Total Quran per satuan (satuan berbeda tidak dijumlahkan).
Map<SatuanQuran, double> totalQuranPerSatuan(List<LogQuranData> baris) {
  final Map<SatuanQuran, double> hasil = <SatuanQuran, double>{};
  for (final LogQuranData b in baris) {
    final SatuanQuran s = SatuanQuran.dariDb(b.satuan);
    hasil[s] = (hasil[s] ?? 0) + b.jumlah;
  }
  return hasil;
}

/// Total Quran per tanggal untuk SATU satuan (dipakai grafik harian).
Map<DateTime, double> totalQuranHarian(
    List<LogQuranData> baris, SatuanQuran satuan) {
  final Map<DateTime, double> hasil = <DateTime, double>{};
  for (final LogQuranData b in baris) {
    if (SatuanQuran.dariDb(b.satuan) != satuan) continue;
    final DateTime hari = IbadahLanjutanRepository.hari(b.tanggal);
    hasil[hari] = (hasil[hari] ?? 0) + b.jumlah;
  }
  return hasil;
}

/// Total Quran per jenis untuk satu satuan.
Map<JenisQuran, double> totalQuranPerJenis(
    List<LogQuranData> baris, SatuanQuran satuan) {
  final Map<JenisQuran, double> hasil = <JenisQuran, double>{};
  for (final LogQuranData b in baris) {
    if (SatuanQuran.dariDb(b.satuan) != satuan) continue;
    final JenisQuran j = JenisQuran.dariDb(b.jenis);
    hasil[j] = (hasil[j] ?? 0) + b.jumlah;
  }
  return hasil;
}

/// Total dzikir (tercatat) per tanggal.
Map<DateTime, int> totalDzikirHarian(List<LogDzikirData> baris) {
  final Map<DateTime, int> hasil = <DateTime, int>{};
  for (final LogDzikirData b in baris) {
    final DateTime hari = IbadahLanjutanRepository.hari(b.tanggal);
    hasil[hari] = (hasil[hari] ?? 0) + b.tercatat;
  }
  return hasil;
}

/// Banyak butir refleksi yang sudah diisi pada satu baris (0..6).
int jumlahButirTerisi(RefleksiMuhasabahData? baris) =>
    NilaiRefleksi.dariBaris(baris).jumlahTerisi;

// ---------------------------------------------------------------------------
// Repositori
// ---------------------------------------------------------------------------

/// Penyimpanan & pembacaan catatan ibadah lanjutan.
class IbadahLanjutanRepository {
  IbadahLanjutanRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? waktuSekarang;

  final AppDatabase db;
  final DateTime Function() _jam;

  /// Tanggal sipil (jam 00:00) sebagai kunci penyimpanan.
  static DateTime hari(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Hari pertama bulan [b].
  static DateTime awalBulan(DateTime b) => DateTime(b.year, b.month);

  /// Hari pertama bulan berikutnya (dipakai sebagai batas EKSKLUSIF).
  static DateTime awalBulanBerikut(DateTime b) => DateTime(b.year, b.month + 1);

  /// Rentang [jumlahHari] hari yang berakhir pada [sampaiHari] (termasuk).
  static DateTime mulaiRentang(DateTime sampaiHari, int jumlahHari) =>
      hari(sampaiHari).subtract(Duration(days: jumlahHari - 1));

  // --- FR-92 puasa -------------------------------------------------------

  /// Simpan catatan puasa. Satu (tanggal, jenis) hanya punya satu baris;
  /// menyimpan ulang akan memperbarui baris yang ada.
  Future<void> simpanPuasa({
    required DateTime tanggal,
    required JenisPuasa jenis,
    StatusPuasa status = StatusPuasa.puasa,
    String? catatan,
  }) async {
    final DateTime kunci = hari(tanggal);
    await db.into(db.logPuasa).insert(
          LogPuasaCompanion.insert(
            tanggal: kunci,
            jenis: jenis.nilaiDb,
            status: Value<String>(status.nilaiDb),
            catatan: Value<String?>(_teksAtauNull(catatan)),
            dicatatPada: Value<DateTime>(_jam()),
          ),
          onConflict: DoUpdate(
            (_) => LogPuasaCompanion(
              status: Value<String>(status.nilaiDb),
              catatan: Value<String?>(_teksAtauNull(catatan)),
              dicatatPada: Value<DateTime>(_jam()),
            ),
            target: <Column<Object>>[db.logPuasa.tanggal, db.logPuasa.jenis],
          ),
        );
  }

  Future<void> hapusPuasa(int id) =>
      (db.delete(db.logPuasa)..where((LogPuasa t) => t.id.equals(id))).go();

  /// Catatan puasa pada rentang [mulai, sampaiEksklusif).
  Future<List<LogPuasaData>> puasaRentang(
      DateTime mulai, DateTime sampaiEksklusif) async {
    final List<LogPuasaData> baris = await (db.select(db.logPuasa)
          ..where((LogPuasa t) =>
              t.tanggal.isBiggerOrEqualValue(hari(mulai)) &
              t.tanggal.isSmallerThanValue(hari(sampaiEksklusif)))
          ..orderBy(<OrderingTerm Function($LogPuasaTable)>[
            ($LogPuasaTable t) => OrderingTerm.desc(t.tanggal),
            ($LogPuasaTable t) => OrderingTerm.asc(t.jenis),
          ]))
        .get()
        .timeout(batasBaca);
    return baris;
  }

  /// Catatan puasa satu bulan.
  Future<List<LogPuasaData>> puasaBulan(DateTime bulan) =>
      puasaRentang(awalBulan(bulan), awalBulanBerikut(bulan));

  /// Semua catatan puasa (dipakai hitungan qadha yang tidak terikat bulan).
  Future<List<LogPuasaData>> semuaPuasa() async {
    final List<LogPuasaData> baris = await (db.select(db.logPuasa)
          ..orderBy(<OrderingTerm Function($LogPuasaTable)>[
            ($LogPuasaTable t) => OrderingTerm.desc(t.tanggal),
          ]))
        .get()
        .timeout(batasBaca);
    return baris;
  }

  // --- FR-93 Quran -------------------------------------------------------

  /// Tambah satu catatan Quran; mengembalikan id baris baru.
  Future<int> tambahQuran({
    required DateTime tanggal,
    required JenisQuran jenis,
    required double jumlah,
    SatuanQuran satuan = SatuanQuran.halaman,
    String? bagian,
    String? catatan,
  }) async {
    final int id = await db.into(db.logQuran).insert(
          LogQuranCompanion.insert(
            tanggal: hari(tanggal),
            jenis: jenis.nilaiDb,
            jumlah: Value<double>(jumlah < 0 ? 0 : jumlah),
            satuan: Value<String>(satuan.nilaiDb),
            bagian: Value<String?>(_teksAtauNull(bagian)),
            catatan: Value<String?>(_teksAtauNull(catatan)),
            dicatatPada: Value<DateTime>(_jam()),
          ),
        );
    return id;
  }

  Future<void> hapusQuran(int id) =>
      (db.delete(db.logQuran)..where((LogQuran t) => t.id.equals(id))).go();

  Future<List<LogQuranData>> quranRentang(
      DateTime mulai, DateTime sampaiEksklusif) async {
    final List<LogQuranData> baris = await (db.select(db.logQuran)
          ..where((LogQuran t) =>
              t.tanggal.isBiggerOrEqualValue(hari(mulai)) &
              t.tanggal.isSmallerThanValue(hari(sampaiEksklusif)))
          ..orderBy(<OrderingTerm Function($LogQuranTable)>[
            ($LogQuranTable t) => OrderingTerm.desc(t.tanggal),
            ($LogQuranTable t) => OrderingTerm.desc(t.id),
          ]))
        .get()
        .timeout(batasBaca);
    return baris;
  }

  /// Jumlah baris Quran pada satu tanggal (untuk keadaan kosong).
  Future<int> jumlahQuranHari(DateTime tanggal) async {
    final List<LogQuranData> baris = await quranRentang(
        hari(tanggal), hari(tanggal).add(const Duration(days: 1)));
    return baris.length;
  }

  // --- FR-95 dzikir ------------------------------------------------------

  /// Simpan/buka satu sesi dzikir. Satu (tanggal, jenis, nama) = satu baris:
  /// menekan tombol hitung berulang kali TIDAK menambah baris baru.
  Future<int> catatDzikir({
    required DateTime tanggal,
    required JenisDzikir jenis,
    required String nama,
    int target = 33,
    int tercatat = 0,
    String? catatan,
  }) async {
    final DateTime kunci = hari(tanggal);
    final String namaBersih = nama.trim().isEmpty ? 'Dzikir' : nama.trim();
    final int targetBersih = target < 0 ? 0 : target;
    final int tercatatBersih = tercatat < 0 ? 0 : tercatat;
    final LogDzikirData? lama = await dzikirSatu(kunci, jenis, namaBersih);
    final DateTime? selesai = (targetBersih > 0 && tercatatBersih >= targetBersih)
        ? _jam()
        : null;
    if (lama == null) {
      return db.into(db.logDzikir).insert(
            LogDzikirCompanion.insert(
              tanggal: kunci,
              jenis: jenis.nilaiDb,
              nama: namaBersih,
              target: Value<int>(targetBersih),
              tercatat: Value<int>(tercatatBersih),
              selesaiPada: Value<DateTime?>(selesai),
              catatan: Value<String?>(_teksAtauNull(catatan)),
              dicatatPada: Value<DateTime>(_jam()),
            ),
          );
    }
    await (db.update(db.logDzikir)..where((LogDzikir t) => t.id.equals(lama.id)))
        .write(LogDzikirCompanion(
      target: Value<int>(targetBersih),
      tercatat: Value<int>(tercatatBersih),
      selesaiPada: Value<DateTime?>(selesai),
      catatan: Value<String?>(_teksAtauNull(catatan) ?? lama.catatan),
    ));
    return lama.id;
  }

  /// Satu baris dzikir menurut kuncinya (null = belum ada).
  Future<LogDzikirData?> dzikirSatu(
      DateTime tanggal, JenisDzikir jenis, String nama) async {
    final LogDzikirData? baris = await (db.select(db.logDzikir)
          ..where((LogDzikir t) =>
              t.tanggal.equals(hari(tanggal)) &
              t.jenis.equals(jenis.nilaiDb) &
              t.nama.equals(nama.trim()))
          ..limit(1))
        .getSingleOrNull()
        .timeout(batasBaca);
    return baris;
  }

  Future<void> hapusDzikir(int id) =>
      (db.delete(db.logDzikir)..where((LogDzikir t) => t.id.equals(id))).go();

  Future<List<LogDzikirData>> dzikirRentang(
      DateTime mulai, DateTime sampaiEksklusif) async {
    final List<LogDzikirData> baris = await (db.select(db.logDzikir)
          ..where((LogDzikir t) =>
              t.tanggal.isBiggerOrEqualValue(hari(mulai)) &
              t.tanggal.isSmallerThanValue(hari(sampaiEksklusif)))
          ..orderBy(<OrderingTerm Function($LogDzikirTable)>[
            ($LogDzikirTable t) => OrderingTerm.desc(t.tanggal),
            ($LogDzikirTable t) => OrderingTerm.asc(t.nama),
          ]))
        .get()
        .timeout(batasBaca);
    return baris;
  }

  // --- FR-100 muhasabah --------------------------------------------------

  /// Simpan refleksi satu tanggal (unik per tanggal).
  Future<void> simpanRefleksi(
    DateTime tanggal,
    NilaiRefleksi nilai, {
    String? catatan,
  }) async {
    final DateTime kunci = hari(tanggal);
    await db.into(db.refleksiMuhasabah).insert(
          RefleksiMuhasabahCompanion.insert(
            tanggal: kunci,
            sholatTerjaga: Value<bool?>(nilai.sholatTerjaga),
            mengingatAllah: Value<bool?>(nilai.mengingatAllah),
            membantuOrang: Value<bool?>(nilai.membantuOrang),
            menghindariDisesali: Value<bool?>(nilai.menghindariDisesali),
            belajar: Value<bool?>(nilai.belajar),
            bersyukur: Value<bool?>(nilai.bersyukur),
            catatan: Value<String?>(_teksAtauNull(catatan)),
            dicatatPada: Value<DateTime>(_jam()),
          ),
          onConflict: DoUpdate(
            (_) => RefleksiMuhasabahCompanion(
              sholatTerjaga: Value<bool?>(nilai.sholatTerjaga),
              mengingatAllah: Value<bool?>(nilai.mengingatAllah),
              membantuOrang: Value<bool?>(nilai.membantuOrang),
              menghindariDisesali: Value<bool?>(nilai.menghindariDisesali),
              belajar: Value<bool?>(nilai.belajar),
              bersyukur: Value<bool?>(nilai.bersyukur),
              catatan: Value<String?>(_teksAtauNull(catatan)),
              dicatatPada: Value<DateTime>(_jam()),
            ),
            target: <Column<Object>>[db.refleksiMuhasabah.tanggal],
          ),
        );
  }

  Future<RefleksiMuhasabahData?> refleksiTanggal(DateTime tanggal) async {
    final RefleksiMuhasabahData? baris = await (db.select(db.refleksiMuhasabah)
          ..where((RefleksiMuhasabah t) => t.tanggal.equals(hari(tanggal))))
        .getSingleOrNull()
        .timeout(batasBaca);
    return baris;
  }

  Future<List<RefleksiMuhasabahData>> refleksiRentang(
      DateTime mulai, DateTime sampaiEksklusif) async {
    final List<RefleksiMuhasabahData> baris =
        await (db.select(db.refleksiMuhasabah)
              ..where((RefleksiMuhasabah t) =>
                  t.tanggal.isBiggerOrEqualValue(hari(mulai)) &
                  t.tanggal.isSmallerThanValue(hari(sampaiEksklusif)))
              ..orderBy(<OrderingTerm Function($RefleksiMuhasabahTable)>[
                ($RefleksiMuhasabahTable t) => OrderingTerm.desc(t.tanggal),
              ]))
            .get()
            .timeout(batasBaca);
    return baris;
  }

  Future<void> hapusRefleksi(int id) =>
      (db.delete(db.refleksiMuhasabah)
            ..where((RefleksiMuhasabah t) => t.id.equals(id)))
          .go();

  /// Teks kosong disimpan sebagai null supaya "belum diisi" tetap terlihat.
  static String? _teksAtauNull(String? teks) {
    if (teks == null) return null;
    final String bersih = teks.trim();
    return bersih.isEmpty ? null : bersih;
  }
}
