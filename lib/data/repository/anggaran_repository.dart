/// Repositori anggaran bulanan & realisasinya (FR-72).
///
/// Kriteria terima FR-72: tampilkan "Anggaran / Terpakai / Selisih (%)" dan
/// beri peringatan pada 80% serta 100%. Semua kalimat peringatan memakai angka
/// pengguna sendiri dan **tidak menghakimi** (PRD §III-11).
library;

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../model/enums.dart';
import 'periode.dart';
import 'transaksi_repository.dart';

class AnggaranRepository {
  AnggaranRepository(this.db, {TransaksiRepository? transaksi})
      : _transaksi = transaksi ?? TransaksiRepository(db);

  final AppDatabase db;
  final TransaksiRepository _transaksi;

  /// Nilai `kategoriId` untuk baris anggaran TOTAL bulan itu (keputusan
  /// rancangan §4.3: 0 dipakai karena SQLite menganggap NULL berbeda-beda
  /// pada indeks unik).
  static const int kategoriTotal = 0;

  /// Simpan/ubah anggaran satu kategori pada satu periode (idempoten).
  Future<AnggaranBulananData> simpan({
    required String periode,
    required int kategoriId,
    required int batasSen,
    String ambangPeringatan = '80,100',
    String? catatan,
  }) async {
    if (!kunciBulanSah(periode)) {
      throw ArgumentError('Periode harus berformat YYYY-MM, mis. 2026-09.');
    }
    if (batasSen < 0) {
      throw ArgumentError('Batas anggaran tidak boleh negatif.');
    }
    if (teksKeAmbang(ambangPeringatan).isEmpty) {
      throw ArgumentError('ambangPeringatan harus berisi angka, mis. "80,100".');
    }
    final isi = AnggaranBulananCompanion.insert(
      periode: periode,
      kategoriId: Value(kategoriId),
      batasSen: Value(batasSen),
      ambangPeringatan: Value(ambangPeringatan),
      catatan: Value(catatan),
      diubahPada: Value(DateTime.now()),
    );
    await db.into(db.anggaranBulanan).insert(
          isi,
          onConflict: DoUpdate((_) => isi,
              target: [db.anggaranBulanan.periode, db.anggaranBulanan.kategoriId]),
        );
    return (db.select(db.anggaranBulanan)
          ..where((a) => a.periode.equals(periode) & a.kategoriId.equals(kategoriId)))
        .getSingle();
  }

  Stream<List<AnggaranBulananData>> watchPeriode(String periode) =>
      (db.select(db.anggaranBulanan)
            ..where((a) => a.periode.equals(periode))
            ..orderBy([(a) => OrderingTerm.asc(a.kategoriId)]))
          .watch();

  Future<List<AnggaranBulananData>> ambilPeriode(String periode) =>
      (db.select(db.anggaranBulanan)
            ..where((a) => a.periode.equals(periode))
            ..orderBy([(a) => OrderingTerm.asc(a.kategoriId)]))
          .get();

  Future<int> hapus(int id) =>
      (db.delete(db.anggaranBulanan)..where((a) => a.id.equals(id))).go();

  /// Anggaran vs realisasi untuk satu periode.
  ///
  /// Realisasi dihitung dari transaksi **pengeluaran** bulan itu; baris
  /// anggaran total ([kategoriTotal]) memakai seluruh pengeluaran bulan itu.
  Future<List<RealisasiAnggaran>> realisasi(String periode) async {
    final bulan = bulanDariKunci(periode);
    if (bulan == null) {
      throw ArgumentError('Periode harus berformat YYYY-MM, mis. 2026-09.');
    }
    final daftar = await ambilPeriode(periode);
    if (daftar.isEmpty) return const [];

    final total = await _transaksi.totalPerKategori(bulan,
        jenis: JenisArus.pengeluaran);
    final perKategori = <int, int>{
      for (final t in total)
        if (t.kategoriId != null) t.kategoriId!: t.totalSen
    };
    final totalBulan = total.fold<int>(0, (a, b) => a + b.totalSen);

    final namaKategori = <int, String>{};
    for (final k in await db.select(db.kategoriTransaksi).get()) {
      namaKategori[k.id] = k.nama;
    }

    final hasil = [
      for (final a in daftar)
        RealisasiAnggaran(
          kategoriId: a.kategoriId,
          nama: a.kategoriId == kategoriTotal
              ? 'Total bulan'
              : (namaKategori[a.kategoriId] ?? 'Kategori #${a.kategoriId}'),
          batasSen: a.batasSen,
          terpakaiSen: a.kategoriId == kategoriTotal
              ? totalBulan
              : (perKategori[a.kategoriId] ?? 0),
          ambang: teksKeAmbang(a.ambangPeringatan),
          terkunci: a.terkunci,
        ),
    ];
    return hasil;
  }

  /// Hanya baris yang sudah menyentuh ambang 80% / 100% (bahan notifikasi).
  Future<List<RealisasiAnggaran>> peringatan(String periode) async {
    final semua = await realisasi(periode);
    return [
      for (final r in semua)
        if (r.status != StatusAnggaran.aman) r,
    ];
  }
}

/// Anggaran vs realisasi satu kategori (sen).
class RealisasiAnggaran {
  const RealisasiAnggaran({
    required this.kategoriId,
    required this.nama,
    required this.batasSen,
    required this.terpakaiSen,
    required this.ambang,
    this.terkunci = false,
  });

  final int kategoriId;
  final String nama;
  final int batasSen;
  final int terpakaiSen;

  /// Ambang peringatan (%), terurut naik — mis. [80, 100].
  final List<int> ambang;
  final bool terkunci;

  /// Sisa anggaran (boleh negatif bila melewati batas).
  int get selisihSen => batasSen - terpakaiSen;

  /// Persentase terpakai; null bila batas belum diisi (0).
  int? get persen =>
      batasSen <= 0 ? null : ((terpakaiSen * 100) / batasSen).round();

  StatusAnggaran get status {
    final p = persen;
    if (p == null || ambang.isEmpty) return StatusAnggaran.aman;
    if (p >= ambang.last) return StatusAnggaran.lewat;
    if (p >= ambang.first) return StatusAnggaran.mendekati;
    return StatusAnggaran.aman;
  }

  /// Kalimat netral untuk UI/notifikasi — menyebut angka, tidak menilai orang.
  String kalimat() {
    final p = persen;
    if (p == null) {
      return 'Anggaran $nama belum diisi. Terpakai $terpakaiSen sen bulan ini.';
    }
    return 'Anggaran $nama terpakai $p% bulan ini.';
  }
}

/// Tingkat pemakaian anggaran.
enum StatusAnggaran {
  aman('aman'),
  mendekati('mendekati'),
  lewat('lewat');

  const StatusAnggaran(this.nilaiDb);
  final String nilaiDb;

  String get label => switch (this) {
        StatusAnggaran.aman => 'Dalam batas',
        StatusAnggaran.mendekati => 'Mendekati batas',
        StatusAnggaran.lewat => 'Melewati batas',
      };
}

/// Pecah "80,100" menjadi [80, 100] (terurut naik, hanya angka masuk akal).
/// Gaya teks sama seperti `pengingatLeadHari` pada tabel Tagihan
/// (lihat `teksKeLead` di `lib/core/utils/tanggal_utils.dart`).
List<int> teksKeAmbang(String? teks) {
  if (teks == null) return const [80, 100];
  final hasil = <int>[];
  for (final bagian in teks.split(',')) {
    final n = int.tryParse(bagian.trim());
    if (n == null || n <= 0 || n > 1000) continue;
    if (!hasil.contains(n)) hasil.add(n);
  }
  hasil.sort();
  return hasil;
}
