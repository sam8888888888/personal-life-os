/// SDD v19 Gelombang 2 — Hasil laboratorium (kepala panel) & analitnya.
///
/// Satu lembar hasil lab = satu [HasilLabData] + banyak [AnalitLabData].
/// Aturan yang dijaga di lapisan ini (aturan dokumen, bukan selera):
///
/// * **Aplikasi tidak menebak.** Rentang rujukan datang dari laboratorium
///   pengguna. Bila rentang kosong → `bendera` wajib `tidak_dinilai`.
/// * **Minimal satu** dari `nilai` (angka) atau `nilaiTeks` (mis. "negatif")
///   wajib terisi, kalau tidak barisnya ditolak.
/// * `rujukanBawah < rujukanAtas` bila keduanya diisi.
///
/// Tren per analit (inti nilai tabel ini) lewat [trenAnalit]:
/// *"Hb: 11,2 → 11,8 → 12,4 dalam 9 bulan."*
library;

import 'dart:math';

import 'package:drift/drift.dart';

import '../database/database.dart';

/// Galat aturan hasil lab/analit (pesannya ditujukan untuk pengguna).
class GalatHasilLab implements Exception {
  GalatHasilLab(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}

/// Delapan panel yang paling sering dipakai (boleh diisi bebas di luar ini).
const List<String> panelHasilLab = <String>[
  'Darah Lengkap',
  'Lipid',
  'Fungsi Hati',
  'Fungsi Ginjal',
  'HbA1c',
  'Urinalisis',
  'Tiroid',
  'lain',
];

/// Nilai bendera yang dikenal. Aplikasi tidak menambahkan label klinis.
const List<String> benderaAnalit = <String>[
  'normal',
  'rendah',
  'tinggi',
  'kritis',
  'tidak_dinilai',
];

class HasilLabRepository {
  HasilLabRepository(this._db);

  final AppDatabase _db;
  static final Random _acak = Random.secure();

  static String uidBaru() => List<int>.generate(16, (_) => _acak.nextInt(256))
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  /// Pengenal stabil lintas HP, dipakai agar kaitan antar-HP tetap benar.
  static String idStabil(DateTime tanggal) {
    final String t = '${tanggal.year.toString().padLeft(4, '0')}'
        '${tanggal.month.toString().padLeft(2, '0')}'
        '${tanggal.day.toString().padLeft(2, '0')}';
    return 'HL-$t-${uidBaru().substring(0, 8)}';
  }

  /// Simpan satu lembar hasil lab. Mengembalikan uid-nya.
  Future<String> tambah({
    required DateTime tanggal,
    required String namaPanel,
    String? laboratorium,
    String? dokter,
    int? anggotaId,
    String? lampiranUid,
    String? catatan,
  }) async {
    final String panel = namaPanel.trim();
    if (panel.isEmpty) {
      throw GalatHasilLab('Nama panel belum diisi.');
    }
    final String uid = uidBaru();
    await _db.into(_db.hasilLab).insert(
          HasilLabCompanion.insert(
            uid: Value(uid),
            idHasil: idStabil(tanggal),
            tanggal: tanggal,
            namaPanel: panel,
            laboratorium: Value(laboratorium),
            dokter: Value(dokter),
            anggotaId: Value(anggotaId),
            lampiranUid: Value(lampiranUid),
            catatan: Value(catatan),
          ),
        );
    return uid;
  }

  Future<HasilLabData?> cariUid(String uid) => (_db.select(_db.hasilLab)
        ..where((t) => t.uid.equals(uid))
        ..limit(1))
      .getSingleOrNull();

  /// Daftar hasil lab, terbaru dulu.
  Future<List<HasilLabData>> daftar({int? anggotaId, int batas = 100}) {
    final SimpleSelectStatement<$HasilLabTable, HasilLabData> q =
        _db.select(_db.hasilLab)
          ..orderBy(<OrderingTerm Function($HasilLabTable)>[
            ($HasilLabTable t) => OrderingTerm.desc(t.tanggal),
          ])
          ..limit(batas);
    if (anggotaId != null) {
      q.where((t) => t.anggotaId.equals(anggotaId));
    }
    return q.get();
  }

  Future<void> ubah(int id, HasilLabCompanion isi) async {
    await (_db.update(_db.hasilLab)..where((t) => t.id.equals(id)))
        .write(isi.copyWith(diubahPada: Value(DateTime.now())));
  }

  /// Hapus hasil lab beserta seluruh analitnya (tidak boleh ada analit yatim).
  Future<int> hapus(int id) async {
    final int anak = await (_db.delete(_db.analitLab)
          ..where((t) => t.hasilLabId.equals(id)))
        .go();
    await (_db.delete(_db.hasilLab)..where((t) => t.id.equals(id))).go();
    return anak;
  }

  // ─────────────────────────────────────────────────────────── analit

  /// Tambah satu analit ke dalam panel.
  Future<String> tambahAnalit({
    required int hasilLabId,
    required String nama,
    double? nilai,
    String? nilaiTeks,
    String satuan = '',
    double? rujukanBawah,
    double? rujukanAtas,
    String? bendera,
    String? catatan,
  }) async {
    final String namaBersih = nama.trim();
    if (namaBersih.isEmpty) {
      throw GalatHasilLab('Nama analit belum diisi.');
    }
    if (nilai == null && (nilaiTeks == null || nilaiTeks.trim().isEmpty)) {
      throw GalatHasilLab(
          'Isi angka hasilnya, atau tulis hasilnya apa adanya (mis. "negatif").');
    }
    if (rujukanBawah != null &&
        rujukanAtas != null &&
        rujukanBawah >= rujukanAtas) {
      throw GalatHasilLab('Batas bawah rujukan harus lebih kecil dari batas atas.');
    }
    final bool punyaRentang = rujukanBawah != null && rujukanAtas != null;
    final String benderaFinal;
    if (!punyaRentang) {
      // Tidak menebak: tanpa rentang rujukan dari lab, tidak ada penilaian.
      benderaFinal = 'tidak_dinilai';
    } else if (bendera != null && benderaAnalit.contains(bendera)) {
      benderaFinal = bendera;
    } else if (nilai == null) {
      benderaFinal = 'tidak_dinilai';
    } else if (nilai < rujukanBawah) {
      benderaFinal = 'rendah';
    } else if (nilai > rujukanAtas) {
      benderaFinal = 'tinggi';
    } else {
      benderaFinal = 'normal';
    }

    final String uid = uidBaru();
    await _db.into(_db.analitLab).insert(
          AnalitLabCompanion.insert(
            uid: Value(uid),
            hasilLabId: hasilLabId,
            nama: namaBersih,
            nilai: Value(nilai),
            nilaiTeks: Value(nilaiTeks),
            satuan: Value(satuan.trim()),
            rujukanBawah: Value(rujukanBawah),
            rujukanAtas: Value(rujukanAtas),
            bendera: Value(benderaFinal),
            catatan: Value(catatan),
          ),
        );
    return uid;
  }

  Future<List<AnalitLabData>> analitDari(int hasilLabId) =>
      (_db.select(_db.analitLab)
            ..where((t) => t.hasilLabId.equals(hasilLabId))
            ..orderBy(<OrderingTerm Function($AnalitLabTable)>[
              ($AnalitLabTable t) => OrderingTerm.asc(t.nama),
            ]))
          .get();

  /// Semua analit yang berada di luar rentang rujukan yang DICATAT pengguna.
  /// Memakai indeks parsial `idx_al_bendera`.
  Future<List<AnalitLabData>> diLuarRentang({int batas = 100}) =>
      (_db.select(_db.analitLab)
            ..where((t) =>
                t.bendera.isNotIn(const <String>['normal', 'tidak_dinilai']))
            ..orderBy(<OrderingTerm Function($AnalitLabTable)>[
              ($AnalitLabTable t) => OrderingTerm.desc(t.dibuatPada),
            ])
            ..limit(batas))
          .get();

  /// Tren satu analit dari waktu ke waktu — inilah inti nilai tabel analit.
  ///
  /// Mengembalikan baris siap tampil: `tren[0]` yang paling lama, terakhir
  /// yang paling baru.
  Future<List<TrenAnalit>> trenAnalit(String nama, {int? anggotaId}) async {
    final String sql = '''
SELECT h.tanggal AS tanggal, a.nilai AS nilai, a.nilai_teks AS nilai_teks,
       a.satuan AS satuan, a.rujukan_bawah AS rujukan_bawah,
       a.rujukan_atas AS rujukan_atas, a.bendera AS bendera
FROM analit_lab a
JOIN hasil_lab h ON h.id = a.hasil_lab_id
WHERE a.nama = ?${anggotaId != null ? ' AND (h.anggota_id = ? OR h.anggota_id IS NULL)' : ''}
ORDER BY h.tanggal ASC''';
    final List<Variable<Object>> variabel = <Variable<Object>>[
      Variable<String>(nama),
      if (anggotaId != null) Variable<int>(anggotaId),
    ];
    final List<QueryRow> baris =
        await _db.customSelect(sql, variables: variabel).get();
    return baris.map(TrenAnalit.dariBaris).toList();
  }

  /// Nama-nama analit yang pernah dicatat (untuk pilihan di layar).
  Future<List<String>> namaAnalitPernahDicatat() async {
    final List<QueryRow> baris = await _db
        .customSelect('SELECT DISTINCT nama FROM analit_lab ORDER BY nama')
        .get();
    return baris.map((QueryRow r) => r.read<String>('nama')).toList();
  }
}

/// Satu titik pada tren analit.
class TrenAnalit {
  const TrenAnalit({
    required this.tanggal,
    required this.nilai,
    required this.nilaiTeks,
    required this.satuan,
    required this.bendera,
  });

  final DateTime tanggal;
  final double? nilai;
  final String? nilaiTeks;
  final String satuan;
  final String bendera;

  static TrenAnalit dariBaris(QueryRow r) => TrenAnalit(
        tanggal: r.read<DateTime>('tanggal'),
        nilai: r.readNullable<double>('nilai'),
        nilaiTeks: r.readNullable<String>('nilai_teks'),
        satuan: r.read<String>('satuan'),
        bendera: r.read<String>('bendera'),
      );

  /// Nilai siap tampil: angka bila ada, kalau tidak teks apa adanya dari lab.
  String get tampil =>
      nilai == null ? (nilaiTeks ?? '-') : '$nilai${satuan.isEmpty ? '' : ' $satuan'}';

  bool get diLuarRentang => bendera != 'normal' && bendera != 'tidak_dinilai';
}
