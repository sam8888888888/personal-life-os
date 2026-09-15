/// Repositori obat & vitamin — FR-106 (manajer obat, jadwal minum, penanda
/// "sudah diminum").
///
/// Batas aman konten (PRD III-11) yang dijaga lapisan ini:
/// * `dosisTeks` disimpan APA ADANYA dari label/kemasan — aplikasi tidak
///   pernah menghitung, menyesuaikan, atau menyarankan dosis;
/// * status yang dicatat hanya keadaan catatan: diminum / ditunda / dilewati.
///   Tidak ada kolom atau kalimat yang menilai kepatuhan pengguna;
/// * kalimat ringkasan berbentuk laporan angka ("3 dari 5 tercatat diminum
///   hari ini"), bukan penilaian.
///
/// Setiap pembacaan penyimpanan dibungkus [batasBaca] (bawaan 5 detik).
library;

import 'package:drift/drift.dart';

import '../../core/utils/waktu.dart';
import '../database/database.dart';
import 'kesehatan_repository.dart'
    show awalHari, akhirHari, formatJamHHmm, hariSama, parseJamHHmm, waktuSama;

/// Batas tunggu bawaan satu pembacaan penyimpanan (aturan gaya proyek).
const Duration batasBacaObat = Duration(seconds: 5);

/// Keadaan catatan minum obat — keadaan, bukan penilaian.
enum StatusMinum {
  diminum('diminum', 'Sudah diminum'),
  ditunda('ditunda', 'Ditunda'),
  dilewati('dilewati', 'Dilewati');

  const StatusMinum(this.nilaiDb, this.label);

  final String nilaiDb;
  final String label;

  static StatusMinum dariDb(String? teks) {
    final cari = (teks ?? '').trim().toLowerCase();
    for (final s in values) {
      if (s.nilaiDb == cari) return s;
    }
    return StatusMinum.diminum;
  }
}

/// Satu jadwal minum pada satu hari (dipakai layar obat).
class JadwalMinumHariIni {
  const JadwalMinumHariIni({
    required this.obat,
    required this.jadwal,
    required this.waktuRencana,
    this.status,
    this.waktuMinum,
  });

  final ObatData obat;

  /// Baris jadwal di tabel `jadwal_obat`; `null` bila jadwal dihapus setelah
  /// catatan minum dibuat (riwayat tetap dibaca).
  final JadwalObatData? jadwal;

  final DateTime waktuRencana;

  /// `null` = belum ada catatan untuk jam ini.
  final StatusMinum? status;

  final DateTime? waktuMinum;

  int get obatId => obat.id;
  String get jam => formatJamHHmm(waktuRencana);
  bool get sudahDicatat => status != null;
}

/// Ringkasan jadwal obat satu hari (FR-106).
class RingkasanObatHariIni {
  const RingkasanObatHariIni({
    required this.jadwal,
    this.jumlahDiminum = 0,
    this.jumlahDitunda = 0,
    this.jumlahDilewati = 0,
  });

  final List<JadwalMinumHariIni> jadwal;
  final int jumlahDiminum;
  final int jumlahDitunda;
  final int jumlahDilewati;

  int get jumlahJadwal => jadwal.length;

  int get jumlahBelum => jumlahJadwal - jumlahDiminum - jumlahDitunda - jumlahDilewati;

  bool get adaJadwal => jadwal.isNotEmpty;

  /// Laporan angka apa adanya (PRD III-11) — tanpa kata penilaian.
  String get kalimatTercatat =>
      '$jumlahDiminum dari $jumlahJadwal tercatat diminum hari ini';
}

/// Satu baris riwayat minum obat (catatan + nama obatnya).
class BarisRiwayatMinum {
  const BarisRiwayatMinum({required this.catatan, this.obat});

  final MinumObatData catatan;
  final ObatData? obat;

  String get namaObat => obat?.nama ?? 'Obat yang sudah dihapus';
  StatusMinum get status => StatusMinum.dariDb(catatan.status);
}

/// Penyimpanan obat, jadwal minum & penanda minum di atas skema v4.
class ObatRepository {
  ObatRepository(
    this.db, {
    DateTime Function()? jamSekarang,
    this.batasBaca = batasBacaObat,
  }) : _jam = jamSekarang ?? waktuSekarang;

  final AppDatabase db;
  final DateTime Function() _jam;

  /// Batas tunggu satu pembacaan penyimpanan (bawaan 5 detik).
  final Duration batasBaca;

  Future<T> _baca<T>(Future<T> aksi) => aksi.timeout(batasBaca);

  /// Jalankan hitungan yang membaca penyimpanan, dengan batas tunggu yang sama.
  Future<T> _hitung<T>(Future<T> Function() aksi) => _baca(aksi());

  // =========================================================================
  // Daftar obat
  // =========================================================================

  /// Tambah obat/vitamin. [jamMinum] berisi jam "HH:mm" (boleh lebih dari satu).
  Future<ObatData> tambahObat({
    required String nama,
    String? dosisTeks,
    int jumlahPerMinum = 1,
    String satuan = 'tablet',
    DateTime? mulai,
    DateTime? selesai,
    String? catatan,
    List<String> jamMinum = const [],
  }) async {
    final n = nama.trim();
    if (n.isEmpty) {
      throw ArgumentError('Nama obat tidak boleh kosong.');
    }
    if (jumlahPerMinum < 1 || jumlahPerMinum > 100) {
      throw ArgumentError('Jumlah per minum harus 1–100.');
    }
    final s = satuan.trim();
    return db.transaction(() async {
      final obat = await db.into(db.obat).insertReturning(ObatCompanion.insert(
            nama: n,
            dosisTeks: Value(_bersih(dosisTeks)),
            jumlahPerMinum: Value(jumlahPerMinum),
            satuan: Value(s.isEmpty ? 'tablet' : s),
            mulai: Value(mulai == null ? null : awalHari(mulai)),
            selesai: Value(selesai == null ? null : awalHari(selesai)),
            catatan: Value(_bersih(catatan)),
            dibuatPada: Value(_jam()),
            diubahPada: Value(_jam()),
          ));
      await _pasangJadwal(obat.id, jamMinum);
      return obat;
    });
  }

  /// Ubah data obat. [jamMinum] bila diberikan akan MENGGANTI seluruh jadwal
  /// obat ini (null = jadwal tidak diubah).
  Future<int> ubahObat(
    int id, {
    String? nama,
    String? dosisTeks,
    int? jumlahPerMinum,
    String? satuan,
    DateTime? mulai,
    DateTime? selesai,
    bool? aktif,
    String? catatan,
    List<String>? jamMinum,
  }) async {
    if (nama != null && nama.trim().isEmpty) {
      throw ArgumentError('Nama obat tidak boleh kosong.');
    }
    if (jumlahPerMinum != null && (jumlahPerMinum < 1 || jumlahPerMinum > 100)) {
      throw ArgumentError('Jumlah per minum harus 1–100.');
    }
    return db.transaction(() async {
      final n = await (db.update(db.obat)..where((o) => o.id.equals(id)))
          .write(ObatCompanion(
        nama: nama == null ? const Value.absent() : Value(nama.trim()),
        dosisTeks: dosisTeks == null
            ? const Value.absent()
            : Value(_bersih(dosisTeks)),
        jumlahPerMinum: jumlahPerMinum == null
            ? const Value.absent()
            : Value(jumlahPerMinum),
        satuan:
            satuan == null ? const Value.absent() : Value(satuan.trim()),
        mulai: mulai == null
            ? const Value.absent()
            : Value(awalHari(mulai)),
        selesai: selesai == null
            ? const Value.absent()
            : Value(awalHari(selesai)),
        aktif: aktif == null ? const Value.absent() : Value(aktif),
        catatan: catatan == null ? const Value.absent() : Value(_bersih(catatan)),
        diubahPada: Value(_jam()),
      ));
      if (jamMinum != null) {
        await (db.delete(db.jadwalObat)..where((j) => j.obatId.equals(id))).go();
        await _pasangJadwal(id, jamMinum);
      }
      return n;
    });
  }

  /// Hapus obat beserta jadwal & riwayat minumnya (satu transaksi).
  Future<void> hapusObat(int id) => db.transaction(() async {
        await (db.delete(db.minumObat)..where((m) => m.obatId.equals(id))).go();
        await (db.delete(db.jadwalObat)..where((j) => j.obatId.equals(id))).go();
        await (db.delete(db.obat)..where((o) => o.id.equals(id))).go();
      });

  Future<ObatData?> obatSatu(int id) => _baca(
        (db.select(db.obat)..where((o) => o.id.equals(id))).getSingleOrNull(),
      );

  /// Daftar obat; [aktifSaja] = true hanya obat yang saklarnya aktif.
  Future<List<ObatData>> daftarObat({bool aktifSaja = false}) {
    final q = db.select(db.obat)
      ..orderBy([
        (o) => OrderingTerm.desc(o.aktif),
        (o) => OrderingTerm.asc(o.nama),
      ]);
    if (aktifSaja) q.where((o) => o.aktif.equals(true));
    return _baca(q.get());
  }

  /// Daftar obat yang berlaku pada [hari] (saklar aktif + dalam masa
  /// mulai/selesai bila diisi).
  Future<List<ObatData>> obatBerlakuPada(DateTime hari) async {
    final semua = await daftarObat(aktifSaja: true);
    final tgl = awalHari(hari);
    return semua.where((o) => _berlakuPada(o, tgl)).toList();
  }

  bool _berlakuPada(ObatData o, DateTime hari) {
    final mulai = o.mulai;
    if (mulai != null && awalHari(mulai).isAfter(hari)) return false;
    final selesai = o.selesai;
    if (selesai != null && awalHari(selesai).isBefore(hari)) return false;
    return true;
  }

  // =========================================================================
  // Jadwal jam minum
  // =========================================================================

  /// Jadwal minum satu obat, urut menurut jam.
  Future<List<JadwalObatData>> jadwalObat(int obatId, {bool aktifSaja = true}) {
    final q = db.select(db.jadwalObat)
      ..where((j) => j.obatId.equals(obatId))
      ..orderBy([
        (j) => OrderingTerm.asc(j.jam),
        (j) => OrderingTerm.asc(j.urutan),
      ]);
    if (aktifSaja) q.where((j) => j.aktif.equals(true));
    return _baca(q.get());
  }

  /// Tambah satu jam minum. Teks jam dinormalkan ke "HH:mm".
  Future<JadwalObatData> tambahJadwal(int obatId, String jam, {int? urutan}) async {
    final bersih = normalisasiJam(jam);
    if (bersih == null) {
      throw ArgumentError('Jam minum harus dalam bentuk HH:mm, contoh 08:00.');
    }
    final ada = await jadwalObat(obatId, aktifSaja: false);
    final sudahAda = ada.any((j) => j.jam == bersih);
    if (sudahAda) return ada.firstWhere((j) => j.jam == bersih);
    return db.into(db.jadwalObat).insertReturning(JadwalObatCompanion.insert(
          obatId: obatId,
          jam: bersih,
          urutan: Value(urutan ?? ada.length),
        ));
  }

  Future<int> hapusJadwal(int id) =>
      (db.delete(db.jadwalObat)..where((j) => j.id.equals(id))).go();

  Future<int> aturJadwalAktif(int id, bool aktif) =>
      (db.update(db.jadwalObat)..where((j) => j.id.equals(id)))
          .write(JadwalObatCompanion(aktif: Value(aktif)));

  /// Normalkan teks jam menjadi "HH:mm"; `null` bila tidak sah.
  static String? normalisasiJam(String? teks) {
    final j = parseJamHHmm(teks);
    if (j == null) return null;
    return '${j.jam.toString().padLeft(2, '0')}:${j.menit.toString().padLeft(2, '0')}';
  }

  Future<void> _pasangJadwal(int obatId, List<String> jamMinum) async {
    var urutan = 0;
    final dipakai = <String>{};
    for (final teks in jamMinum) {
      final jam = normalisasiJam(teks);
      if (jam == null || !dipakai.add(jam)) continue;
      await db.into(db.jadwalObat).insert(JadwalObatCompanion.insert(
            obatId: obatId,
            jam: jam,
            urutan: Value(urutan++),
          ));
    }
  }

  // =========================================================================
  // Catatan minum (FR-106)
  // =========================================================================

  /// Catat keadaan minum untuk satu jadwal ([waktuRencana]).
  ///
  /// Satu (obat, waktu rencana) = satu baris; memanggil lagi MEMPERBARUI
  /// statusnya (indeks unik idx_minum_obat_rencana menjaminnya di database).
  Future<MinumObatData> catatMinum({
    required int obatId,
    required DateTime waktuRencana,
    int? jadwalId,
    StatusMinum status = StatusMinum.diminum,
    DateTime? waktuMinum,
    String? catatan,
  }) {
    final kapan = status == StatusMinum.diminum ? (waktuMinum ?? _jam()) : waktuMinum;
    final isi = MinumObatCompanion.insert(
      obatId: obatId,
      jadwalId: Value(jadwalId),
      waktuRencana: waktuRencana,
      waktuMinum: Value(kapan),
      status: Value(status.nilaiDb),
      catatan: Value(_bersih(catatan)),
    );
    return db.into(db.minumObat).insertReturning(
          isi,
          onConflict: DoUpdate(
            (_) => MinumObatCompanion(
              jadwalId: Value(jadwalId),
              waktuMinum: Value(kapan),
              status: Value(status.nilaiDb),
              catatan: Value(_bersih(catatan)),
            ),
            target: [db.minumObat.obatId, db.minumObat.waktuRencana],
          ),
        );
  }

  /// Catatan untuk satu (obat, waktu rencana); `null` = belum dicatat.
  Future<MinumObatData?> catatanMinum({
    required int obatId,
    required DateTime waktuRencana,
  }) =>
      _baca(
        (db.select(db.minumObat)
              ..where((m) =>
                  m.obatId.equals(obatId) &
                  m.waktuRencana.equals(waktuRencana)))
            .getSingleOrNull(),
      );

  /// Semua jadwal hari [hari] lengkap dengan status catatannya.
  Future<RingkasanObatHariIni> ringkasanHariIni({required DateTime hari}) =>
      _hitung(() async {
        final tgl = awalHari(hari);
        final obatAktif = await obatBerlakuPada(tgl);
        if (obatAktif.isEmpty) return const RingkasanObatHariIni(jadwal: []);
        final idObat = obatAktif.map((o) => o.id).toList();
        final jadwal = await (db.select(db.jadwalObat)
              ..where((j) => j.obatId.isIn(idObat) & j.aktif.equals(true))
              ..orderBy([
                (j) => OrderingTerm.asc(j.jam),
                (j) => OrderingTerm.asc(j.urutan),
              ]))
            .get();
        final catatan = await (db.select(db.minumObat)
              ..where((m) =>
                  m.obatId.isIn(idObat) &
                  m.waktuRencana.isBiggerOrEqualValue(tgl) &
                  m.waktuRencana.isSmallerThanValue(akhirHari(tgl))))
            .get();
        final daftar = <JadwalMinumHariIni>[];
        for (final o in obatAktif) {
          for (final j in jadwal.where((j) => j.obatId == o.id)) {
            final p = parseJamHHmm(j.jam);
            if (p == null) continue;
            final rencana = DateTime(tgl.year, tgl.month, tgl.day, p.jam, p.menit);
            MinumObatData? c;
            for (final m in catatan) {
              if (m.obatId == o.id && waktuSama(m.waktuRencana, rencana)) {
                c = m;
                break;
              }
            }
            daftar.add(JadwalMinumHariIni(
              obat: o,
              jadwal: j,
              waktuRencana: rencana,
              status: c == null ? null : StatusMinum.dariDb(c.status),
              waktuMinum: c?.waktuMinum,
            ));
          }
        }
        daftar.sort((a, b) => a.waktuRencana.compareTo(b.waktuRencana));
        return RingkasanObatHariIni(
          jadwal: daftar,
          jumlahDiminum:
              daftar.where((d) => d.status == StatusMinum.diminum).length,
          jumlahDitunda:
              daftar.where((d) => d.status == StatusMinum.ditunda).length,
          jumlahDilewati:
              daftar.where((d) => d.status == StatusMinum.dilewati).length,
        );
      });

  /// Riwayat catatan minum [hari] hari terakhir (termasuk hari ini).
  Future<List<BarisRiwayatMinum>> riwayatMinum({int hari = 7, DateTime? sampai}) =>
      _hitung(() async {
        final jumlah = hari < 1 ? 1 : hari;
        final akhir = awalHari(sampai ?? _jam());
        final mulai = akhir.subtract(Duration(days: jumlah - 1));
        final catatan = await (db.select(db.minumObat)
              ..where((m) =>
                  m.waktuRencana.isBiggerOrEqualValue(mulai) &
                  m.waktuRencana.isSmallerThanValue(akhirHari(akhir)))
              ..orderBy([(m) => OrderingTerm.desc(m.waktuRencana)]))
            .get();
        final obat = await (db.select(db.obat)).get();
        return [
          for (final c in catatan)
            BarisRiwayatMinum(
              catatan: c,
              obat: _cariObat(obat, c.obatId),
            ),
        ];
      });

  /// Catatan minum hari [hari] saja (untuk uji & pemeriksaan cepat).
  Future<List<BarisRiwayatMinum>> riwayatMinumHari(DateTime hari) async {
    final tgl = awalHari(hari);
    final semua = await riwayatMinum(hari: 1, sampai: tgl);
    return semua.where((b) => hariSama(b.catatan.waktuRencana, tgl)).toList();
  }

  ObatData? _cariObat(List<ObatData> daftar, int id) {
    for (final o in daftar) {
      if (o.id == id) return o;
    }
    return null;
  }

  String? _bersih(String? teks) {
    final t = teks?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
