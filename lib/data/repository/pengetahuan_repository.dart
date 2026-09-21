/// Penyimpanan modul Pengetahuan (FR-118/119/120/121/122/123).
///
/// Prinsip berkas ini: penulisan & pembacaan sederhana, satu tempat untuk tiap
/// tabel. Hitungan (ringkasan, jadwal ulangan) TIDAK dikerjakan di sini —
/// semuanya di `lib/core/laporan/*.dart` supaya bisa diuji tanpa database.
///
/// Setiap pembacaan dibungkus batas tunggu [batasBacaPengetahuan] (aturan gaya
/// proyek) supaya layar tidak menunggu tanpa akhir bila database terkunci.
library;

import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/laporan/pengetahuan_ringkas.dart' as ringkas;
import '../../core/laporan/ulangan_berkala.dart' as ulang;
import '../../core/utils/waktu.dart';
import '../database/database.dart';

/// Batas tunggu bawaan satu pembacaan penyimpanan.
const Duration batasBacaPengetahuan = Duration(seconds: 5);

class PengetahuanRepository {
  static final Random _acakUid = Random.secure();

  PengetahuanRepository(this._db);

  final AppDatabase _db;

  // -------------------------------------------------------------------------
  // FR-118 — catatan & ide
  // -------------------------------------------------------------------------

  /// Semua catatan (paling baru dulu) lengkap dengan jumlah tautannya.
  Future<List<ringkas.BarisCatatan>> daftarCatatan({
    bool termasukArsip = false,
  }) async {
    final tautan = await daftarTautan();
    final q = _db.select(_db.catatanPengetahuan)
      ..orderBy([(t) => OrderingTerm.desc(t.dibuatPada)]);
    if (!termasukArsip) {
      q.where((t) => t.arsip.equals(false));
    }
    final baris = await q.get().timeout(batasBacaPengetahuan);
    return baris
        .map((c) => ringkas.BarisCatatan(
              id: c.id,
              judul: c.judul,
              isi: c.isi,
              kategori: c.kategori,
              tag: c.tag,
              disematkan: c.disematkan,
              arsip: c.arsip,
              dibuatPada: c.dibuatPada,
              jumlahTautan:
                  ringkas.tautanUntuk(tautan, 'catatan', c.id).length,
            ))
        .toList();
  }

  Future<int> simpanCatatan({
    int? id,
    required String judul,
    required String isi,
    String kategori = 'gagasan',
    String? tag,
    bool disematkan = false,
    DateTime? sekarang,
  }) async {
    final kini = sekarang ?? waktuSekarang();
    if (id == null) {
      return _db.into(_db.catatanPengetahuan).insert(
            CatatanPengetahuanCompanion.insert(
              judul: judul,
              isi: isi,
              kategori: Value(kategori),
              tag: Value(tag),
              disematkan: Value(disematkan),
              uid: Value(_uidBaru(kini)),
            ),
          );
    }
    await (_db.update(_db.catatanPengetahuan)..where((t) => t.id.equals(id)))
        .write(CatatanPengetahuanCompanion(
      judul: Value(judul),
      isi: Value(isi),
      kategori: Value(kategori),
      tag: Value(tag),
      disematkan: Value(disematkan),
      diubahPada: Value(kini),
    ));
    return id;
  }

  /// Pastikan catatan punya uid stabil (dipakai lampiran FR-118 supaya
  /// lampirannya tetap menempel walau id angkanya berbeda antar HP).
  Future<String> pastikanUidCatatan(int id) async {
    final baris = await (_db.select(_db.catatanPengetahuan)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    final lama = baris.uid;
    if (lama != null && lama.isNotEmpty) return lama;
    final baru = List<int>.generate(16, (_) => _acakUid.nextInt(256))
        .map((x) => x.toRadixString(16).padLeft(2, '0'))
        .join();
    await (_db.update(_db.catatanPengetahuan)..where((t) => t.id.equals(id)))
        .write(CatatanPengetahuanCompanion(uid: Value(baru)));
    return baru;
  }

  Future<void> setelSemat(int id, bool disematkan) =>
      (_db.update(_db.catatanPengetahuan)..where((t) => t.id.equals(id)))
          .write(CatatanPengetahuanCompanion(disematkan: Value(disematkan)));

  Future<void> setelArsip(int id, bool arsip) =>
      (_db.update(_db.catatanPengetahuan)..where((t) => t.id.equals(id)))
          .write(CatatanPengetahuanCompanion(arsip: Value(arsip)));

  Future<void> hapusCatatan(int id) async {
    await (_db.delete(_db.catatanPengetahuan)..where((t) => t.id.equals(id)))
        .go();
    await hapusTautanButir('catatan', id);
  }

  // -------------------------------------------------------------------------
  // FR-119 — jurnal keputusan
  // -------------------------------------------------------------------------

  Future<List<ringkas.BarisKeputusan>> daftarKeputusan() async {
    final tautan = await daftarTautan();
    final baris = await (_db.select(_db.keputusan)
          ..orderBy([(t) => OrderingTerm.desc(t.diputuskanPada)]))
        .get()
        .timeout(batasBacaPengetahuan);
    return baris
        .map((k) => ringkas.BarisKeputusan(
              id: k.id,
              judul: k.judul,
              konteks: k.konteks,
              pilihan: k.pilihan,
              dipilih: k.dipilih,
              alasan: k.alasan,
              harapan: k.harapan,
              risiko: k.risiko,
              biaya: k.biaya,
              keyakinan: k.keyakinan,
              diputuskanPada: k.diputuskanPada,
              tinjauPada: k.tinjauPada,
              hasil: k.hasil,
              hasilPada: k.hasilPada,
              jumlahTautan: ringkas.tautanUntuk(tautan, 'keputusan', k.id).length,
            ))
        .toList();
  }

  Future<int> simpanKeputusan({
    int? id,
    required String judul,
    String? konteks,
    String? pilihan,
    String? dipilih,
    String? alasan,
    String? harapan,
    String? risiko,
    String? biaya,
    int keyakinan = 50,
    DateTime? diputuskanPada,
    DateTime? tinjauPada,
    DateTime? sekarang,
  }) async {
    final kini = sekarang ?? waktuSekarang();
    if (id == null) {
      return _db.into(_db.keputusan).insert(
            KeputusanCompanion.insert(
              judul: judul,
              konteks: Value(konteks),
              pilihan: Value(pilihan),
              dipilih: Value(dipilih),
              alasan: Value(alasan),
              harapan: Value(harapan),
              risiko: Value(risiko),
              biaya: Value(biaya),
              keyakinan: Value(keyakinan),
              diputuskanPada: diputuskanPada ?? kini,
              tinjauPada: Value(tinjauPada),
              uid: Value(_uidBaru(kini)),
            ),
          );
    }
    await (_db.update(_db.keputusan)..where((t) => t.id.equals(id)))
        .write(KeputusanCompanion(
      judul: Value(judul),
      konteks: Value(konteks),
      pilihan: Value(pilihan),
      dipilih: Value(dipilih),
      alasan: Value(alasan),
      harapan: Value(harapan),
      risiko: Value(risiko),
      biaya: Value(biaya),
      keyakinan: Value(keyakinan),
      tinjauPada: Value(tinjauPada),
      diubahPada: Value(kini),
    ));
    return id;
  }

  /// Tulis hasil/tinjauan sebuah keputusan.
  Future<void> tulisHasilKeputusan(int id, String hasil, {DateTime? kapan}) =>
      (_db.update(_db.keputusan)..where((t) => t.id.equals(id))).write(
        KeputusanCompanion(
          hasil: Value(hasil),
          hasilPada: Value(kapan ?? waktuSekarang()),
        ),
      );

  Future<void> hapusKeputusan(int id) async {
    await (_db.delete(_db.keputusan)..where((t) => t.id.equals(id))).go();
    await hapusTautanButir('keputusan', id);
  }

  // -------------------------------------------------------------------------
  // FR-120 — pembelajaran
  // -------------------------------------------------------------------------

  Future<List<ringkas.BarisPembelajaran>> daftarPembelajaran() async {
    final baris = await (_db.select(_db.pembelajaran)
          ..orderBy([(t) => OrderingTerm.desc(t.tanggal)]))
        .get()
        .timeout(batasBacaPengetahuan);
    return baris
        .map((p) => ringkas.BarisPembelajaran(
              id: p.id,
              topik: p.topik,
              sumber: p.sumber,
              menit: p.menit,
              tanggal: p.tanggal,
              status: p.status,
            ))
        .toList();
  }

  Future<int> simpanPembelajaran({
    required String topik,
    String? sumber,
    int menit = 0,
    DateTime? tanggal,
    String status = 'belajar',
    String? catatan,
    DateTime? sekarang,
  }) async {
    final kini = sekarang ?? waktuSekarang();
    return _db.into(_db.pembelajaran).insert(
          PembelajaranCompanion.insert(
            topik: topik,
            sumber: Value(sumber),
            menit: Value(menit),
            tanggal: tanggal ?? kini,
            status: Value(status),
            catatan: Value(catatan),
            uid: Value(_uidBaru(kini)),
          ),
        );
  }

  Future<void> hapusPembelajaran(int id) => (_db.delete(_db.pembelajaran)
        ..where((t) => t.id.equals(id)))
      .go();

  // -------------------------------------------------------------------------
  // FR-121 — kartu ulangan
  // -------------------------------------------------------------------------

  Future<List<ulang.KartuUlanganRingkas>> daftarKartu() async {
    final baris = await (_db.select(_db.kartuUlangan)
          ..orderBy([(t) => OrderingTerm.asc(t.ulanganBerikut)]))
        .get()
        .timeout(batasBacaPengetahuan);
    return baris
        .map((k) => ulang.KartuUlanganRingkas(
              id: k.id,
              pertanyaan: k.pertanyaan,
              jawaban: k.jawaban,
              topik: k.topik,
              kotak: k.kotak,
              ulanganBerikut: k.ulanganBerikut,
              jumlahDiulang: k.jumlahDiulang,
              jumlahBenar: k.jumlahBenar,
            ))
        .toList();
  }

  /// Simpan kartu baru; jadwal ulangan pertama = kotak 0.
  Future<int> simpanKartu({
    required String pertanyaan,
    required String jawaban,
    String? topik,
    DateTime? sekarang,
  }) async {
    final kini = sekarang ?? waktuSekarang();
    return _db.into(_db.kartuUlangan).insert(
          KartuUlanganCompanion.insert(
            pertanyaan: pertanyaan,
            jawaban: jawaban,
            topik: Value(topik),
            ulanganBerikut: ulang.ulanganBerikut(sekarang: kini, kotak: 0),
            uid: Value(_uidBaru(kini)),
          ),
        );
  }

  /// Catat jawaban satu kartu: kotak & jadwal ulangan ikut hasil [benar].
  Future<ulang.HasilJawab> jawabKartu(
    int id, {
    required bool benar,
    DateTime? sekarang,
  }) async {
    final kini = sekarang ?? waktuSekarang();
    final kartu =
        await (_db.select(_db.kartuUlangan)..where((t) => t.id.equals(id)))
            .getSingle()
            .timeout(batasBacaPengetahuan);
    final hasil = ulang.jawabKartu(
      kotak: kartu.kotak,
      benar: benar,
      sekarang: kini,
      jumlahBenar: kartu.jumlahBenar,
    );
    await (_db.update(_db.kartuUlangan)..where((t) => t.id.equals(id))).write(
      KartuUlanganCompanion(
        kotak: Value(hasil.kotakBaru),
        ulanganBerikut: Value(hasil.ulanganBerikut),
        terakhirDiulang: Value(kini),
        jumlahDiulang: Value(kartu.jumlahDiulang + 1),
        jumlahBenar: Value(hasil.jumlahBenarBaru),
        diubahPada: Value(kini),
      ),
    );
    return hasil;
  }

  Future<void> hapusKartu(int id) async {
    await (_db.delete(_db.kartuUlangan)..where((t) => t.id.equals(id))).go();
    await hapusTautanButir('kartu', id);
  }

  // -------------------------------------------------------------------------
  // FR-122 — buku & bacaan
  // -------------------------------------------------------------------------

  Future<List<ringkas.BarisBacaan>> daftarBacaan() async {
    final tautan = await daftarTautan();
    final baris = await (_db.select(_db.bacaan)
          ..orderBy([(t) => OrderingTerm.desc(t.dibuatPada)]))
        .get()
        .timeout(batasBacaPengetahuan);
    return baris
        .map((b) => ringkas.BarisBacaan(
              id: b.id,
              judul: b.judul,
              penulis: b.penulis,
              jenis: b.jenis,
              halamanTotal: b.halamanTotal,
              halamanKini: b.halamanKini,
              status: b.status,
              selesaiPada: b.selesaiPada,
              nilai: b.nilai,
              jumlahTautan: ringkas.tautanUntuk(tautan, 'bacaan', b.id).length,
            ))
        .toList();
  }

  Future<int> simpanBacaan({
    int? id,
    required String judul,
    String? penulis,
    String jenis = 'buku',
    int? halamanTotal,
    int halamanKini = 0,
    String status = 'antre',
    int? nilai,
    String? catatan,
    DateTime? sekarang,
  }) async {
    final kini = sekarang ?? waktuSekarang();
    final mulai = status == 'dibaca' || status == 'selesai' ? kini : null;
    final selesai = status == 'selesai' ? kini : null;
    if (id == null) {
      return _db.into(_db.bacaan).insert(
            BacaanCompanion.insert(
              judul: judul,
              penulis: Value(penulis),
              jenis: Value(jenis),
              halamanTotal: Value(halamanTotal),
              halamanKini: Value(halamanKini),
              status: Value(status),
              mulaiPada: Value(mulai),
              selesaiPada: Value(selesai),
              nilai: Value(nilai),
              catatan: Value(catatan),
              uid: Value(_uidBaru(kini)),
            ),
          );
    }
    await (_db.update(_db.bacaan)..where((t) => t.id.equals(id))).write(
      BacaanCompanion(
        judul: Value(judul),
        penulis: Value(penulis),
        jenis: Value(jenis),
        halamanTotal: Value(halamanTotal),
        halamanKini: Value(halamanKini),
        status: Value(status),
        selesaiPada: Value(selesai),
        nilai: Value(nilai),
        catatan: Value(catatan),
        diubahPada: Value(kini),
      ),
    );
    return id;
  }

  /// Majukan/mundurkan halaman yang sudah dibaca (tidak pernah di bawah 0).
  Future<void> majukanHalaman(int id, int halaman) async {
    final b = await (_db.select(_db.bacaan)..where((t) => t.id.equals(id)))
        .getSingle()
        .timeout(batasBacaPengetahuan);
    final baru = halaman < 0 ? 0 : halaman;
    final tuntas = b.halamanTotal != null && baru >= b.halamanTotal!;
    await (_db.update(_db.bacaan)..where((t) => t.id.equals(id))).write(
      BacaanCompanion(
        halamanKini: Value(baru),
        status: Value(tuntas ? 'selesai' : (baru > 0 ? 'dibaca' : b.status)),
        selesaiPada: Value(tuntas ? (b.selesaiPada ?? waktuSekarang()) : null),
      ),
    );
  }

  Future<void> hapusBacaan(int id) async {
    await (_db.delete(_db.bacaan)..where((t) => t.id.equals(id))).go();
    await hapusTautanButir('bacaan', id);
  }

  // -------------------------------------------------------------------------
  // FR-123 — penghubung pengetahuan
  // -------------------------------------------------------------------------

  /// Butir dari modul lain yang boleh ditautkan (FR-123: tujuan, proyek,
  /// tugas, dokumen). Dibaca langsung dari tabelnya masing-masing — tidak ada
  /// perubahan pada modul asal.
  Future<List<ringkas.ButirPengetahuan>> butirModulLain() async {
    final hasil = <ringkas.ButirPengetahuan>[];
    final tujuan = await _db.select(_db.tujuan).get();
    for (final t in tujuan) {
      hasil.add(ringkas.ButirPengetahuan('tujuan', t.id, t.nama));
    }
    final proyek = await _db.select(_db.proyek).get();
    for (final t in proyek) {
      hasil.add(ringkas.ButirPengetahuan('proyek', t.id, t.nama));
    }
    final tugas = await _db.select(_db.tugas).get();
    for (final t in tugas) {
      hasil.add(ringkas.ButirPengetahuan('tugas', t.id, t.nama));
    }
    final dokumen = await _db.select(_db.dokumen).get();
    for (final t in dokumen) {
      hasil.add(ringkas.ButirPengetahuan('dokumen', t.id, t.nama));
    }
    return hasil;
  }

  Future<List<ringkas.BarisTautan>> daftarTautan() async {
    final baris = await (_db.select(_db.tautanPengetahuan)
          ..orderBy([(t) => OrderingTerm.desc(t.dibuatPada)]))
        .get()
        .timeout(batasBacaPengetahuan);
    return baris
        .map((t) => ringkas.BarisTautan(
              jenisA: t.jenisA,
              idA: t.idA,
              judulA: t.judulA,
              jenisB: t.jenisB,
              idB: t.idB,
              judulB: t.judulB,
              label: t.label,
            ))
        .toList();
  }

  /// Simpan tautan; kembalikan false bila tautan itu sudah ada / tidak sah.
  Future<bool> simpanTautan(ringkas.BarisTautan calon, {DateTime? sekarang}) async {
    if (!ringkas.tautanSah(calon.jenisA, calon.idA, calon.jenisB, calon.idB)) {
      return false;
    }
    final ada = await daftarTautan();
    if (ringkas.tautanKembar(ada, calon)) return false;
    final kini = sekarang ?? waktuSekarang();
    await _db.into(_db.tautanPengetahuan).insert(
          TautanPengetahuanCompanion.insert(
            jenisA: calon.jenisA,
            idA: calon.idA,
            judulA: Value(calon.judulA),
            jenisB: calon.jenisB,
            idB: calon.idB,
            judulB: Value(calon.judulB),
            label: Value(calon.label),
            uid: Value(_uidBaru(kini)),
          ),
        );
    return true;
  }

  /// Hapus semua tautan yang menyentuh satu butir (dipakai saat butir dihapus).
  Future<void> hapusTautanButir(String jenis, int id) =>
      (_db.delete(_db.tautanPengetahuan)
            ..where((t) =>
                (t.jenisA.equals(jenis) & t.idA.equals(id)) |
                (t.jenisB.equals(jenis) & t.idB.equals(id))))
          .go();

  /// Kunci unik sederhana per baris (dipakai sinkron nanti).
  String _uidBaru(DateTime kini) =>
      'lok-${kini.microsecondsSinceEpoch}-${_db.hashCode}';
}
