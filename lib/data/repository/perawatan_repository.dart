/// Repositori perawatan berkala (FR-83 — Life Maintenance Engine).
///
/// Satu baris `Perawatan` menyimpan jadwal berulang sederhana: nama, kategori,
/// interval hari, kapan terakhir dikerjakan, dan kapan jadwal berikutnya.
/// Kolom `berikutnya` DISIMPAN (bukan selalu dihitung ulang) supaya pengguna
/// boleh menetapkan tanggal yang berbeda dari hasil hitungan interval.
///
/// Perhitungan hari memakai hari kalender (bukan jam), jadi jadwal tidak
/// bergeser hanya karena jam pemakaian. Sumber waktu diambil dari
/// `waktuSekarang()` agar dapat dikunci saat pengujian.
///
/// Mesin pengingat tidak dibuat ulang di sini: modul ini hanya menyimpan
/// jadwal. Penjadwalan notifikasi tetap milik `lib/core/notifikasi/**`.
///
/// Nada teks mengikuti PRD III-11: menjelaskan jadwal, bukan menilai pengguna.
library;

import 'package:drift/drift.dart';

import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import '../database/database.dart';

class PerawatanRepository {
  PerawatanRepository(this.db);

  final AppDatabase db;

  /// Batas hari untuk bagian "jatuh tempo" pada layar (FR-83).
  static const int maksSorotanHari = 30;

  /// Kode template bawaan yang di-seed database saat migrasi v4.
  ///
  /// Urutannya sama dengan urutan `urutan` hasil seed, sehingga
  /// [ambilTemplateBawaan] selalu mengembalikan urutan yang sama.
  static const List<String> kodeTemplateBawaan = <String>[
    'oli_mesin',
    'servis_ac',
    'filter_air',
    'pajak_kendaraan',
    'cadangan_data',
    'periksa_gigi',
  ];

  // ------------------------------------------------------------------
  // Simpan / ubah
  // ------------------------------------------------------------------

  /// Tambah baris baru (`id == null`) atau ubah baris yang sudah ada.
  ///
  /// [berikutnya] yang kosong dihitung dari [terakhirDilakukan] bila ada,
  /// atau dari `waktuSekarang()` bila keduanya kosong.
  ///
  /// `template_kode` tidak ikut diubah di sini: baris hasil seed tetap
  /// menyimpan kode templatenya supaya bisa dikenali kembali.
  Future<PerawatanData> simpan({
    int? id,
    required String nama,
    String kategori = 'lain',
    required int intervalHari,
    DateTime? terakhirDilakukan,
    DateTime? berikutnya,
    String leadHari = '7,1',
    String kanalPengingat = 'push',
    bool aktif = true,
    String? catatan,
    int urutan = 0,
  }) async {
    final namaBersih = nama.trim();
    if (namaBersih.isEmpty) {
      throw ArgumentError('Nama perawatan tidak boleh kosong.');
    }
    if (intervalHari < 1) {
      throw ArgumentError('Interval hari minimal 1 hari.');
    }
    final sekarang = waktuSekarang();
    final jadwal =
        berikutnya ?? hitungBerikutnya(terakhirDilakukan ?? sekarang, intervalHari);

    if (id == null) {
      return db.into(db.perawatan).insertReturning(PerawatanCompanion.insert(
            nama: namaBersih,
            kategori: Value(kategori),
            intervalHari: Value(intervalHari),
            terakhirDilakukan: Value<DateTime?>(terakhirDilakukan),
            berikutnya: jadwal,
            leadHari: Value(leadHari),
            urutan: Value(urutan),
            kanalPengingat: Value(kanalPengingat),
            aktif: Value(aktif),
            catatan: Value<String?>(catatan),
          ));
    }

    final lama = await ambilSatu(id);
    if (lama == null) {
      throw StateError('Baris perawatan tidak ditemukan.');
    }
    await (db.update(db.perawatan)..where((p) => p.id.equals(id)))
        .write(PerawatanCompanion(
      nama: Value(namaBersih),
      kategori: Value(kategori),
      intervalHari: Value(intervalHari),
      terakhirDilakukan: Value<DateTime?>(terakhirDilakukan),
      berikutnya: Value(jadwal),
      leadHari: Value(leadHari),
      urutan: Value(urutan),
      kanalPengingat: Value(kanalPengingat),
      aktif: Value(aktif),
      catatan: Value<String?>(catatan),
      diubahPada: Value(sekarang),
    ));
    final baru = await ambilSatu(id);
    if (baru == null) {
      throw StateError('Baris perawatan tidak ditemukan sesudah diubah.');
    }
    return baru;
  }

  /// Tandai satu perawatan sudah dikerjakan [kapan] (bawaan: hari ini), lalu
  /// geser jadwal berikutnya sejauh interval harinya.
  Future<PerawatanData> tandaiDilakukan(int id, {DateTime? kapan}) async {
    final baris = await ambilSatu(id);
    if (baris == null) {
      throw StateError('Baris perawatan tidak ditemukan.');
    }
    final waktuKerja = kapan ?? waktuSekarang();
    await (db.update(db.perawatan)..where((p) => p.id.equals(id)))
        .write(PerawatanCompanion(
      terakhirDilakukan: Value<DateTime?>(waktuKerja),
      berikutnya: Value(hitungBerikutnya(waktuKerja, baris.intervalHari)),
      diubahPada: Value(waktuSekarang()),
    ));
    final baru = await ambilSatu(id);
    if (baru == null) {
      throw StateError('Baris perawatan tidak ditemukan sesudah ditandai.');
    }
    return baru;
  }

  /// Hapus satu baris perawatan. Mengembalikan jumlah baris yang terhapus.
  Future<int> hapus(int id) =>
      (db.delete(db.perawatan)..where((p) => p.id.equals(id))).go();

  // ------------------------------------------------------------------
  // Baca
  // ------------------------------------------------------------------

  /// Semua baris, urut jadwal terdekat, lalu urutan tampilan.
  Future<List<PerawatanData>> ambilSemua() => (db.select(db.perawatan)
        ..orderBy([
          (p) => OrderingTerm.asc(p.berikutnya),
          (p) => OrderingTerm.asc(p.urutan),
        ]))
      .get();

  /// Baris yang masih diingatkan (`aktif == true`).
  Future<List<PerawatanData>> ambilAktif() => (db.select(db.perawatan)
        ..where((p) => p.aktif.equals(true))
        ..orderBy([
          (p) => OrderingTerm.asc(p.berikutnya),
          (p) => OrderingTerm.asc(p.urutan),
        ]))
      .get();

  Future<PerawatanData?> ambilSatu(int id) =>
      (db.select(db.perawatan)..where((p) => p.id.equals(id)))
          .getSingleOrNull();

  /// Baris hasil seed template bawaan (memiliki `template_kode`), urut tampilan.
  Future<List<PerawatanData>> ambilTemplateBawaan() =>
      (db.select(db.perawatan)
            ..where((p) => p.templateKode.isNotNull())
            ..orderBy([(p) => OrderingTerm.asc(p.urutan)]))
          .get();

  /// Perawatan aktif yang jadwalnya jatuh tempo: tersisa paling banyak
  /// [maksHari] hari lagi, termasuk yang jadwalnya sudah lewat. Urut yang
  /// paling dekat (paling lewat lebih dulu).
  ///
  /// Jadwal yang sudah lewat ikut disorot karena jadwal itu yang paling perlu
  /// dilihat; barisnya tetap menjelaskan keadaannya (mis. "Jadwal ini sudah
  /// lewat 4 hari") tanpa menegur pengguna.
  Future<List<PerawatanData>> sorotanJatuhTempo({
    DateTime? sekarang,
    int maksHari = 30,
  }) async {
    final acuan = sekarang ?? waktuSekarang();
    final aktif = await ambilAktif();
    final hasil = <({PerawatanData baris, int sisa})>[];
    for (final p in aktif) {
      final sisa = sisaHari(p, acuan);
      if (sisa <= maksHari) {
        hasil.add((baris: p, sisa: sisa));
      }
    }
    hasil.sort((a, b) {
      final c = a.sisa.compareTo(b.sisa);
      return c != 0 ? c : a.baris.urutan.compareTo(b.baris.urutan);
    });
    return hasil.map((e) => e.baris).toList(growable: false);
  }

  // ------------------------------------------------------------------
  // Hitungan murni (tanpa I/O) — dipakai layar, pengingat, dan pengujian
  // ------------------------------------------------------------------

  /// Jadwal berikutnya = tanggal [dilakukan] (hari saja) + [intervalHari].
  ///
  /// Penambahan dilakukan lewat konstruktor `DateTime` (bukan `Duration`),
  /// supaya pergantian waktu musiman tidak menggeser tanggal ke hari lain.
  /// Interval di bawah 1 hari tidak pernah memundurkan tanggal.
  static DateTime hitungBerikutnya(DateTime dilakukan, int intervalHari) {
    final hari = intervalHari < 1 ? 0 : intervalHari;
    return DateTime(dilakukan.year, dilakukan.month, dilakukan.day + hari);
  }

  /// Sisa hari kalender menuju jadwal [p] dari [sekarang].
  /// Nilai negatif berarti jadwalnya sudah lewat.
  static int sisaHari(PerawatanData p, DateTime sekarang) =>
      selisihHari(sekarang, p.berikutnya);

  /// Kunci kelompok jadwal menurut sisa hari terhadap waktu sekarang:
  /// `terlambat` (< 0), `hari_ini` (0), `dekat` (1..30), `jauh` (> 30).
  static String kunciJatuhTempo(PerawatanData p) {
    final sisa = sisaHari(p, waktuSekarang());
    if (sisa < 0) return 'terlambat';
    if (sisa == 0) return 'hari_ini';
    if (sisa <= maksSorotanHari) return 'dekat';
    return 'jauh';
  }
}
