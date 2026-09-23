/// Uji SDD v19 Gelombang 3 — orang (CRM pribadi) + temuan pola (mesin korelasi).
///
/// Yang dibuktikan (bukan diasumsikan):
/// 1. Skema v21: tabel `orang` & `temuan` + 9 indeks benar-benar ada.
/// 2. Migrasi v20 → v21 lewat `onUpgrade` sungguhan pada berkas nyata, dan data
///    lama (tabel v20) tidak hilang.
/// 3. Hitungan mesin pola benar: peringkat dengan nilai kembar, koefisien
///    Spearman pada contoh yang bisa diperiksa tangan, nilai-p permutasi yang
///    bisa diulang, koreksi Bonferroni & Benjamini–Hochberg.
/// 4. Aturan terpenting dokumen: **temuan dengan n < 14 DITOLAK**, kalimat
///    berbahasa terlarang DITOLAK, dan umpan balik "bukan begitu" tidak
///    dihidupkan kembali oleh perhitungan ulang.
/// 5. Orang: nama wajib, hubungan tak dikenal → 'lain', satu anggota keluarga
///    hanya boleh punya satu baris orang, dan pemantauan "lama tidak dihubungi"
///    kosong kecuali diminta secara sadar (opt-in).
/// 6. Penjalankan mesin: data 20 hari yang benar-benar berpasangan → temuan
///    tersimpan; data kurang → dilewati dengan alasan.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/audit/audit_log.dart';
import 'package:personal_life_os/core/pola/mesin_pola.dart';
import 'package:personal_life_os/core/pola/pasangan_pola.dart';
import 'package:personal_life_os/core/pola/penjalankan_pola.dart';
import 'package:personal_life_os/core/sinkron/registri_sinkron.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/orang_repository.dart';
import 'package:personal_life_os/data/repository/temuan_repository.dart';

const List<String> indeksV21 = <String>[
  'idx_orang_uid',
  'idx_orang_idorang',
  'idx_orang_nama',
  'idx_orang_hubungan',
  'idx_orang_ultah',
  'idx_temuan_uid',
  'idx_temuan_kode',
  'idx_temuan_hitung',
  'idx_temuan_tampil',
];

const List<String> tabelV21 = <String>['orang', 'temuan'];

Future<List<String>> _namaIndeks(AppDatabase db) async {
  final List<QueryRow> baris = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
      .get();
  return baris.map((QueryRow r) => r.read<String>('name')).toList();
}

Future<List<String>> _namaTabel(AppDatabase db) async {
  final List<QueryRow> baris = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return baris.map((QueryRow r) => r.read<String>('name')).toList();
}

/// Bahan temuan palsu untuk menguji aturan penyimpanan.
HasilUjiPola _hasilPalsu({
  required int n,
  String kode = 'uji~uji',
  String judul = 'Judul uji',
  double kekuatan = 0.6,
  String? bahasa,
}) =>
    HasilUjiPola(
      kode: kode,
      judul: judul,
      kekuatan: kekuatan,
      ukuranSampel: n,
      nilaiP: 0.01,
      rentangMulai: DateTime(2026, 1, 1),
      rentangSelesai: DateTime(2026, 3, 1),
      bahasa: bahasa ?? MesinPola.kalimatPola(
        sisiX: 'durasi tidur',
        sisiY: 'skor suasana hati',
        kekuatan: kekuatan,
        ukuranSampel: n,
      ),
    );

void main() {
  late AppDatabase db;
  late OrangRepository orang;
  late TemuanRepository temuan;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    orang = OrangRepository(db);
    temuan = TemuanRepository(db);
  });

  tearDown(() async => db.close());

  // ─────────────────────────────────────────────────────────────── skema
  group('skema v21', () {
    test('versi skema = 21', () {
      expect(db.schemaVersion, 21);
    });

    test('tabel orang & temuan ada', () async {
      final List<String> tabel = await _namaTabel(db);
      for (final String t in tabelV21) {
        expect(tabel, contains(t), reason: 'tabel $t harus ada');
      }
    });

    test('sembilan indeks v21 ada', () async {
      final List<String> indeks = await _namaIndeks(db);
      for (final String i in indeksV21) {
        expect(indeks, contains(i), reason: 'indeks $i harus ada');
      }
    });

    test('orang menunjuk anggota keluarga lewat kunci asing', () async {
      final QueryRow r = await db
          .customSelect("SELECT sql FROM sqlite_master WHERE type = 'table' "
              "AND name = 'orang'")
          .getSingle();
      expect(r.read<String>('sql'), contains('REFERENCES anggota_keluarga'));
    });
  });

  // ───────────────────────────────────────────────────────────── migrasi
  group('migrasi v20 → v21', () {
    test('basis data v20 naik ke v21 tanpa kehilangan data lama', () async {
      final Directory dir = await Directory.systemTemp.createTemp('lifeos_v21');
      final File berkas = File('${dir.path}/uji.sqlite');
      AppDatabase? lama;
      try {
        lama = AppDatabase.forTesting(NativeDatabase(berkas));
        // Data v20 yang HARUS bertahan.
        await lama.into(lama.gejala).insert(
              GejalaCompanion.insert(
                nama: 'sakit kepala',
                mulai: DateTime(2026, 9, 1),
              ),
            );
        for (final String t in tabelV21) {
          await lama.customStatement('DROP TABLE IF EXISTS $t');
        }
        for (final String i in indeksV21) {
          await lama.customStatement('DROP INDEX IF EXISTS $i');
        }
        await lama.customStatement('PRAGMA user_version = 20');
        await lama.close();
        lama = null;

        db = AppDatabase.forTesting(NativeDatabase(berkas));
        final List<String> tabel = await _namaTabel(db);
        for (final String t in tabelV21) {
          expect(tabel, contains(t), reason: 'tabel $t harus dibuat onUpgrade');
        }
        final List<String> indeks = await _namaIndeks(db);
        for (final String i in indeksV21) {
          expect(indeks, contains(i), reason: 'indeks $i harus dibuat onUpgrade');
        }
        final List<GejalaData> sisa = await db.select(db.gejala).get();
        expect(sisa, hasLength(1));
        expect(sisa.first.nama, 'sakit kepala');
      } finally {
        await lama?.close();
        await db.close();
        await dir.delete(recursive: true);
      }
    });
  });

  // ─────────────────────────────────────────────────── hitungan mesin pola
  group('mesin pola (hitungan murni)', () {
    test('peringkat rata-rata untuk nilai kembar', () {
      expect(MesinPola.peringkat(<double>[10, 10, 20, 30]),
          <double>[1.5, 1.5, 3, 4]);
      expect(MesinPola.peringkat(<double>[5, 4, 3, 2, 1]),
          <double>[5, 4, 3, 2, 1]);
    });

    test('spearman: contoh yang bisa diperiksa tangan', () {
      // X=[1,2,3], Y=[1,3,2] → peringkat sama; Σdxdy = 1, Σdx² = Σdy² = 2 → 0.5
      expect(MesinPola.spearman(<double>[1, 2, 3], <double>[1, 3, 2]), 0.5);
    });

    test('spearman: searah sempurna = 1, berlawanan = −1', () {
      expect(MesinPola.spearman(<double>[1, 2, 3, 4, 5], <double>[2, 4, 6, 8, 10]), 1.0);
      expect(MesinPola.spearman(<double>[1, 2, 3, 4, 5], <double>[5, 4, 3, 2, 1]), -1.0);
    });

    test('spearman: nilai kembar di kedua sisi tetap 1', () {
      expect(MesinPola.spearman(<double>[1, 1, 2, 3], <double>[2, 2, 4, 6]), 1.0);
    });

    test('spearman: null bila salah satu sisi tidak bervariasi', () {
      expect(MesinPola.spearman(<double>[1, 1, 1, 1], <double>[1, 2, 3, 4]), isNull);
      expect(MesinPola.spearman(<double>[1, 2], <double>[1, 2]), isNull);
    });

    test('nilai-p permutasi: kuat → kecil, dan hasilnya bisa diulang', () {
      final List<double> x = <double>[1, 2, 3, 4, 5, 6, 7, 8];
      final List<double> y = <double>[2, 4, 6, 8, 10, 12, 14, 16];
      final double p1 = MesinPola.nilaiPermutasi(x, y);
      final double p2 = MesinPola.nilaiPermutasi(x, y);
      expect(p1, p2, reason: 'benih tetap → hasil sama setiap kali');
      expect(p1, lessThan(0.01));
      expect(p1, greaterThan(0));
    });

    test('koreksi Bonferroni memotong di 1', () {
      expect(MesinPola.koreksiBonferroni(0.01, 20), closeTo(0.2, 1e-9));
      expect(MesinPola.koreksiBonferroni(0.2, 20), 1.0);
      expect(MesinPola.koreksiBonferroni(0.01, 0), 0.01);
    });

    test('koreksi Benjamini–Hochberg: contoh yang bisa diperiksa tangan', () {
      final List<double> hasil =
          MesinPola.koreksiBenjaminiHochberg(<double>[0.01, 0.02, 0.03]);
      expect(hasil, <double>[0.03, 0.03, 0.03]);
      final List<double> dua =
          MesinPola.koreksiBenjaminiHochberg(<double>[0.001, 0.5]);
      expect(dua[0], closeTo(0.002, 1e-9));
      expect(dua[1], closeTo(0.5, 1e-9));
    });

    test('koreksi BH menjaga urutan masukan', () {
      final List<double> p = <double>[0.5, 0.001, 0.02];
      final List<double> hasil = MesinPola.koreksiBenjaminiHochberg(p);
      expect(hasil, hasLength(3));
      expect(hasil[1], lessThan(hasil[2]));
      expect(hasil[0], 0.5);
    });

    test('kalimat pola selalu menyebut n dan menyangkal diagnosis', () {
      final String kalimat = MesinPola.kalimatPola(
        sisiX: 'durasi tidur',
        sisiY: 'skor suasana hati',
        kekuatan: -0.42,
        ukuranSampel: 31,
      );
      expect(kalimat, contains('n = 31'));
      expect(kalimat, contains('catatan Anda'));
      expect(kalimat, contains('bukan diagnosis'));
      expect(bahasaTerlarang(kalimat), isFalse);
    });

    test('penjaga bahasa menangkap klaim, tapi tidak menuduh kalimat jujur', () {
      expect(bahasaTerlarang('Anda mengalami gangguan tidur'), isTrue);
      expect(bahasaTerlarang('Penyebabnya adalah kopi'), isTrue);
      expect(bahasaTerlarang('Anda menderita maag'), isTrue);
      expect(bahasaTerlarang('Karena Anda kurang tidur'), isTrue);
      // Kalimat jujur aplikasi sendiri TIDAK boleh tertuduh.
      expect(
        bahasaTerlarang('Pola terlihat di catatan Anda (n = 20). '
            'Ini pola dari catatan Anda, bukan diagnosis.'),
        isFalse,
      );
    });

    test('hitung(): pasangan dengan n < 14 tidak pernah muncul', () {
      final List<KandidatPola> kandidat = <KandidatPola>[
        KandidatPola(
          kode: 'kecil~kecil',
          judul: 'Data sedikit',
          sisiX: 'a',
          sisiY: 'b',
          titik: <TitikPola>[
            for (int i = 0; i < 5; i++)
              TitikPola(
                  tanggal: DateTime(2026, 1, 1 + i),
                  x: i.toDouble(),
                  y: i.toDouble()),
          ],
        ),
      ];
      expect(MesinPola.hitung(kandidat), isEmpty);
    });

    test('hitung(): hasil diurutkan dari kekuatan terbesar', () {
      List<TitikPola> titik(double kemiringan, int n) => <TitikPola>[
            for (int i = 0; i < n; i++)
              TitikPola(
                tanggal: DateTime(2026, 1, 1).add(Duration(days: i)),
                x: i.toDouble(),
                y: i * kemiringan,
              ),
          ];
      final List<HasilUjiPola> hasil = MesinPola.hitung(<KandidatPola>[
        KandidatPola(
            kode: 'a~b',
            judul: 'Lemah',
            sisiX: 'a',
            sisiY: 'b',
            titik: titik(1, 20)),
        KandidatPola(
            kode: 'c~d',
            judul: 'Kuat',
            sisiX: 'c',
            sisiY: 'd',
            titik: titik(-1, 20)),
      ]);
      expect(hasil, hasLength(2));
      expect(hasil.first.kekuatanAbs, greaterThanOrEqualTo(hasil.last.kekuatanAbs));
      for (final HasilUjiPola h in hasil) {
        expect(h.ukuranSampel, greaterThanOrEqualTo(ambangSampelMinimum));
        expect(h.bahasa, contains('n = ${h.ukuranSampel}'));
      }
    });
  });

  // ────────────────────────────────────────────────────── simpan temuan
  group('aturan penyimpanan temuan', () {
    test('n < 14 DITOLAK', () async {
      expect(
        () => temuan.simpanDariMesin(_hasilPalsu(n: 13)),
        throwsA(isA<GalatTemuan>()),
      );
    });

    test('bahasa terlarang DITOLAK', () async {
      expect(
        () => temuan.simpanDariMesin(_hasilPalsu(
          n: 20,
          judul: 'Anda mengalami gangguan tidur',
        )),
        throwsA(isA<GalatTemuan>()),
      );
    });

    test('temuan sah tersimpan dan muncul di daftar', () async {
      final bool tersimpan = await temuan.simpanDariMesin(_hasilPalsu(n: 20));
      expect(tersimpan, isTrue);
      final List<TemuanData> d = await temuan.daftarTampil();
      expect(d, hasLength(1));
      expect(d.single.ukuranSampel, 20);
      expect(d.single.uraian, contains('n = 20'));
    });

    test('simpan ulang rentang yang sama tidak menggandakan baris', () async {
      await temuan.simpanDariMesin(_hasilPalsu(n: 20));
      await temuan.simpanDariMesin(_hasilPalsu(n: 22, kekuatan: 0.7));
      final List<TemuanData> d = await temuan.daftarTampil();
      expect(d, hasLength(1));
      expect(d.single.ukuranSampel, 22);
    });

    test('"bukan begitu" membungkam, dan hitung ulang tidak menghidupkan lagi',
        () async {
      await temuan.simpanDariMesin(_hasilPalsu(n: 20));
      final TemuanData t = (await temuan.daftarTampil()).single;
      await temuan.umpanBalik(t.id, sadar: false);
      expect(await temuan.daftarTampil(), isEmpty);

      final bool tersimpanLagi =
          await temuan.simpanDariMesin(_hasilPalsu(n: 25, kekuatan: 0.9));
      expect(tersimpanLagi, isFalse, reason: 'umpan balik manusia menang');
      expect(await temuan.daftarTampil(), isEmpty);
      expect((await temuan.semua()).single.diabaikan, isTrue);
    });

    test('"hidupkan lagi" mengembalikan temuan yang dibungkam', () async {
      await temuan.simpanDariMesin(_hasilPalsu(n: 20));
      final TemuanData t = (await temuan.daftarTampil()).single;
      await temuan.umpanBalik(t.id, sadar: false);
      await temuan.kembalikan(t.id);
      expect(await temuan.daftarTampil(), hasLength(1));
    });

    test('ringkasan menghitung yang tampil dan yang dibungkam', () async {
      await temuan.simpanDariMesin(_hasilPalsu(n: 20, kode: 'a~b'));
      await temuan.simpanDariMesin(_hasilPalsu(n: 20, kode: 'c~d'));
      final TemuanData t = (await temuan.daftarTampil()).first;
      await temuan.abaikan(t.id);
      final RingkasTemuan r = await temuan.ringkas();
      expect(r.semua, 2);
      expect(r.tampil, 1);
      expect(r.terakhir, isNotNull);
    });
  });

  // ─────────────────────────────────────────────────────────────── orang
  group('orang', () {
    test('nama kosong ditolak & nama kepanjangan ditolak', () async {
      expect(() => orang.tambah(nama: '  '), throwsA(isA<GalatOrang>()));
      expect(() => orang.tambah(nama: 'a' * 121), throwsA(isA<GalatOrang>()));
    });

    test('hubungan tak dikenal jatuh ke lain', () async {
      await orang.tambah(nama: 'Pak Montir', hubungan: 'saudara jauh');
      expect((await orang.daftar()).single.hubungan, 'lain');
    });

    test('satu anggota keluarga hanya boleh punya satu baris orang', () async {
      final int anggotaId = await db.into(db.anggotaKeluarga).insert(
            AnggotaKeluargaCompanion.insert(
              idAnggota: 'A-9',
              nama: 'Anak Uji',
            ),
          );
      await orang.tambah(nama: 'Budi', anggotaId: anggotaId);
      expect(
        () => orang.tambah(nama: 'Budi lagi', anggotaId: anggotaId),
        throwsA(isA<GalatOrang>()),
      );
    });

    test('daftar, pencarian, dan ringkasan per hubungan', () async {
      await orang.tambah(nama: 'Dokter Sari', hubungan: 'dokter');
      await orang.tambah(nama: 'Guru Rina', hubungan: 'guru');
      await orang.tambah(nama: 'Pak Montir', hubungan: 'vendor');

      expect(await orang.daftar(), hasLength(3));
      expect((await orang.daftar(cari: 'rina')).single.nama, 'Guru Rina');
      expect((await orang.daftar(hubungan: 'dokter')).single.nama, 'Dokter Sari');

      final Map<String, int> jumlah = await orang.jumlahPerHubungan();
      expect(jumlah['dokter'], 1);
      expect(jumlah['guru'], 1);
    });

    test('"terakhir dihubungi" hanya berubah lewat aksi pengguna', () async {
      await orang.tambah(nama: 'Dokter Sari', hubungan: 'dokter');
      final OrangData awal = (await orang.daftar()).single;
      expect(awal.terakhirDihubungi, isNull);

      await orang.tandaiDihubungi(awal.id, DateTime(2026, 9, 20));
      final OrangData setelah = (await orang.daftar()).single;
      expect(setelah.terakhirDihubungi, isNotNull);
      expect(setelah.terakhirDihubungi!.day, 20);
    });

    test('pemantauan "lama tidak dihubungi" opt-in (bawaan kosong)', () async {
      await orang.tambah(nama: 'Pak Montir', hubungan: 'vendor');
      expect(await orang.sudahLamaTidakDihubungi(), isEmpty,
          reason: 'tanpa izin, aplikasi tidak memantau siapa pun');
      expect(
        await orang.sudahLamaTidakDihubungi(bulan: 6, izin: true),
        hasLength(1),
      );
    });

    test('yang diarsipkan tidak muncul di daftar biasa', () async {
      await orang.tambah(nama: 'Tetangga Lama', hubungan: 'tetangga');
      final OrangData o = (await orang.daftar()).single;
      await orang.arsipkan(o.id);
      expect(await orang.daftar(), isEmpty);
      expect(await orang.daftar(termasukArsip: true), hasLength(1));
    });

    test('ulang tahun dekat dihitung dari tanggal hari ini', () async {
      final DateTime kini = DateTime.now();
      final DateTime besok = kini.add(const Duration(days: 1));
      await orang.tambah(
        nama: 'Dokter Sari',
        hubungan: 'dokter',
        ulangTahun: DateTime(1980, besok.month, besok.day),
      );
      final List<OrangData> dekat = await orang.ulangTahunDekat(hariKe: 30);
      expect(dekat, hasLength(1));
      expect(await orang.ulangTahunDekat(hariKe: 0), isEmpty);
    });
  });

  // ────────────────────────────────────────────────────── jalankan mesin
  group('penjalankan mesin pola', () {
    Future<void> isiTidurDanSuasana(int hari, {bool berkorelasi = true}) async {
      final DateTime mulai = DateTime.now().subtract(Duration(days: hari));
      for (int i = 0; i < hari; i++) {
        final DateTime hariKe = DateTime(mulai.year, mulai.month, mulai.day + i);
        final int durasi = 300 + (i % 5) * 30;
        await db.into(db.tidur).insert(
              TidurCompanion.insert(
                tanggal: hariKe,
                jamTidur: hariKe.subtract(const Duration(hours: 7)),
                jamBangun: hariKe.add(const Duration(hours: 6)),
                durasiMenit: durasi,
              ),
            );
        await db.into(db.suasanaHati).insert(
              SuasanaHatiCompanion.insert(
                waktu: hariKe.add(const Duration(hours: 18)),
                skor: berkorelasi ? 1 + (i % 5) : 5 - (i % 5),
              ),
            );
      }
    }

    test('data 20 hari berpasangan menghasilkan temuan tersimpan', () async {
      await isiTidurDanSuasana(20);
      final RingkasJalankanPola hasil = await jalankanMesinPola(db);
      expect(hasil.pasanganDiuji, pasanganAktif.length);
      expect(hasil.tersimpan, greaterThanOrEqualTo(1));
      final List<TemuanData> d = await temuan.daftarTampil();
      expect(d, isNotEmpty);
      expect(d.first.kode, 'tidur~suasana_hati');
      expect(d.first.ukuranSampel, greaterThanOrEqualTo(ambangSampelMinimum));
    });

    test('data kurang → dilaporkan apa adanya, tanpa mengarang temuan',
        () async {
      await isiTidurDanSuasana(6);
      final RingkasJalankanPola hasil = await jalankanMesinPola(db);
      expect(hasil.tersimpan, 0);
      expect(await temuan.daftarTampil(), isEmpty);
      expect(
        hasil.dilewatiKurangData.any((String s) => s.contains('tidur~suasana_hati')),
        isTrue,
      );
    });

    test('temuan tunduk pada koreksi perbandingan berganda', () async {
      await isiTidurDanSuasana(20);
      await jalankanMesinPola(db);
      final List<TemuanData> d = await temuan.daftarTampil();
      for (final TemuanData t in d) {
        expect(t.nilaiP, isNotNull);
        // Koreksi BH hanya bisa menaikkan nilai-p, tidak menurunkannya.
        expect(t.nilaiP!, greaterThan(0));
      }
    });
  });

  // ───────────────────────────────────────────────────────── sinkron & audit
  group('sinkron & audit', () {
    test('orang & temuan terdaftar sebagai jalur sinkron', () {
      final List<String> nama = daftarJalurSinkron(db)
          .map((JalurSinkron j) => j.nama)
          .toList();
      expect(nama, contains('orang'));
      expect(nama, contains('temuan'));
    });

    test('dua modul audit baru dikenali', () {
      expect(ModulAudit.semua, contains(ModulAudit.orang));
      expect(ModulAudit.semua, contains(ModulAudit.temuan));
    });

    test('daftar pasangan belum bisa diuji selalu punya alasan', () {
      for (final PasanganBelumBisa p in pasanganBelumBisa) {
        expect(p.alasan.trim(), isNotEmpty, reason: '${p.kode} tanpa alasan');
      }
    });
  });
}
