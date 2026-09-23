/// Uji SDD v19 Gelombang 2 — kesehatan: hasil lab + analit, gejala, imunisasi,
/// tumbuh kembang.
///
/// Yang dibuktikan (bukan diasumsikan):
/// 1. Skema v20: 5 tabel + 20 indeks benar-benar ada setelah basis data dibuat.
/// 2. Migrasi v19 → v20 lewat jalur `onUpgrade` sungguhan pada **berkas nyata**,
///    dan data lama (tabel v19) TIDAK hilang.
/// 3. Hasil lab: aturan "minimal satu nilai", rentang terbalik ditolak, dan
///    bendera hanya dihitung dari rentang yang dicatat laboratorium pengguna
///    (tanpa rentang → `tidak_dinilai`, aplikasi tidak menebak).
/// 4. Gejala: berat di luar 1–5 DIJEPIT (catatan tidak hilang), durasi dihitung,
///    frekuensi disusun benar.
/// 5. Imunisasi: (anggota, vaksin, dosis) ganda ditolak; jatuh tempo benar.
/// 6. Tumbuh kembang: satu anak satu baris per hari (simpan ulang menimpa),
///    umur bulan dihitung dari tanggal lahir, persentil TIDAK ditebak.
/// 7. Sync + audit: lima jalur baru terdaftar; empat modul audit baru ada.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/audit/audit_log.dart';
import 'package:personal_life_os/core/sinkron/registri_sinkron.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/gejala_repository.dart';
import 'package:personal_life_os/data/repository/hasil_lab_repository.dart';
import 'package:personal_life_os/data/repository/imunisasi_repository.dart';
import 'package:personal_life_os/data/repository/tumbuh_kembang_repository.dart';

/// 20 indeks v20 (SDD §6.2).
const List<String> indeksV20 = <String>[
  'idx_hl_uid',
  'idx_hl_idhasil',
  'idx_hl_tanggal',
  'idx_hl_panel',
  'idx_hl_anggota',
  'idx_al_uid',
  'idx_al_induk',
  'idx_al_nama',
  'idx_al_bendera',
  'idx_gejala_uid',
  'idx_gejala_mulai',
  'idx_gejala_nama',
  'idx_gejala_anggota',
  'idx_imun_uid',
  'idx_imun_dosis',
  'idx_imun_anggota',
  'idx_imun_berikut',
  'idx_tk_uid',
  'idx_tk_hari',
  'idx_tk_umur',
];

const List<String> tabelV20 = <String>[
  'hasil_lab',
  'analit_lab',
  'gejala',
  'imunisasi',
  'tumbuh_kembang',
];

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

void main() {
  late AppDatabase db;
  late HasilLabRepository lab;
  late GejalaRepository gejala;
  late ImunisasiRepository imunisasi;
  late TumbuhKembangRepository tumbuh;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    lab = HasilLabRepository(db);
    gejala = GejalaRepository(db);
    imunisasi = ImunisasiRepository(db);
    tumbuh = TumbuhKembangRepository(db);
  });

  tearDown(() async => db.close());

  // ─────────────────────────────────────────────────────────────── skema
  group('skema v20', () {
    test('versi skema = 20', () {
      expect(db.schemaVersion, 20);
    });

    test('lima tabel kesehatan ada', () async {
      final List<String> tabel = await _namaTabel(db);
      for (final String t in tabelV20) {
        expect(tabel, contains(t), reason: 'tabel $t harus ada');
      }
    });

    test('dua puluh indeks v20 ada', () async {
      final List<String> indeks = await _namaIndeks(db);
      for (final String i in indeksV20) {
        expect(indeks, contains(i), reason: 'indeks $i harus ada');
      }
    });

    test('tabel kesehatan menunjuk anggota keluarga lewat kunci asing', () async {
      final List<QueryRow> baris = await db
          .customSelect("SELECT sql FROM sqlite_master WHERE type = 'table' "
              "AND name IN ('hasil_lab', 'gejala', 'imunisasi', 'tumbuh_kembang')")
          .get();
      expect(baris, hasLength(4));
      for (final QueryRow r in baris) {
        expect(r.read<String>('sql'), contains('REFERENCES anggota_keluarga'));
      }
    });
  });

  // ───────────────────────────────────────────────────────────── migrasi
  group('migrasi v19 → v20', () {
    test('basis data v19 naik ke v20 tanpa kehilangan data lama', () async {
      final Directory dir = await Directory.systemTemp.createTemp('lifeos_v20');
      final File berkas = File('${dir.path}/uji.sqlite');
      AppDatabase? lama;
      try {
        // 1) Buat basis data v20, lalu turunkan tiruan ke v19.
        lama = AppDatabase.forTesting(NativeDatabase(berkas));
        // Data lama yang HARUS bertahan: satu catatan di tabel v19.
        await lama.into(lama.kotakMasuk).insert(
              KotakMasukCompanion.insert(
                isi: Value('catatan lama dari v19'),
              ),
            );
        for (final String t in tabelV20) {
          await lama.customStatement('DROP TABLE IF EXISTS $t');
        }
        for (final String i in indeksV20) {
          await lama.customStatement('DROP INDEX IF EXISTS $i');
        }
        await lama.customStatement('PRAGMA user_version = 19');
        await lama.close();
        lama = null;

        // 2) Buka ulang → onUpgrade wajib membuat tabel & indeks v20.
        db = AppDatabase.forTesting(NativeDatabase(berkas));
        final List<String> tabel = await _namaTabel(db);
        for (final String t in tabelV20) {
          expect(tabel, contains(t), reason: 'tabel $t harus dibuat onUpgrade');
        }
        final List<String> indeks = await _namaIndeks(db);
        for (final String i in indeksV20) {
          expect(indeks, contains(i), reason: 'indeks $i harus dibuat onUpgrade');
        }

        // 3) Data v19 tidak boleh hilang karena migrasi.
        final List<KotakMasukData> sisa = await db.select(db.kotakMasuk).get();
        expect(sisa, hasLength(1));
        expect(sisa.first.isi, 'catatan lama dari v19');
      } finally {
        await lama?.close();
        await db.close();
        await dir.delete(recursive: true);
      }
    });
  });

  // ──────────────────────────────────────────────────────────── hasil lab
  group('hasil lab & analit', () {
    test('panel tanpa nama ditolak', () async {
      expect(
        () => lab.tambah(tanggal: DateTime(2026, 9, 1), namaPanel: '   '),
        throwsA(isA<GalatHasilLab>()),
      );
    });

    test('analit tanpa angka dan tanpa teks ditolak', () async {
      final String uid = await lab.tambah(
          tanggal: DateTime(2026, 9, 1), namaPanel: 'Darah Lengkap');
      final HasilLabData panel = (await lab.cariUid(uid))!;
      expect(
        () => lab.tambahAnalit(hasilLabId: panel.id, nama: 'Hemoglobin'),
        throwsA(isA<GalatHasilLab>()),
      );
    });

    test('rentang rujukan terbalik ditolak', () async {
      final String uid = await lab.tambah(
          tanggal: DateTime(2026, 9, 1), namaPanel: 'Darah Lengkap');
      final HasilLabData panel = (await lab.cariUid(uid))!;
      expect(
        () => lab.tambahAnalit(
          hasilLabId: panel.id,
          nama: 'Hemoglobin',
          nilai: 11.2,
          rujukanBawah: 16,
          rujukanAtas: 12,
        ),
        throwsA(isA<GalatHasilLab>()),
      );
    });

    test('bendera dihitung hanya dari rentang yang dicatat lab', () async {
      final String uid = await lab.tambah(
          tanggal: DateTime(2026, 9, 1), namaPanel: 'Darah Lengkap');
      final HasilLabData panel = (await lab.cariUid(uid))!;
      await lab.tambahAnalit(
        hasilLabId: panel.id,
        nama: 'Hemoglobin',
        nilai: 11.2,
        satuan: 'g/dL',
        rujukanBawah: 12,
        rujukanAtas: 16,
      );
      await lab.tambahAnalit(
        hasilLabId: panel.id,
        nama: 'Leukosit',
        nilai: 18000,
        rujukanBawah: 4000,
        rujukanAtas: 10000,
      );
      await lab.tambahAnalit(
        hasilLabId: panel.id,
        nama: 'Trombosit',
        nilai: 250000,
        rujukanBawah: 150000,
        rujukanAtas: 400000,
      );
      final List<AnalitLabData> analit = await lab.analitDari(panel.id);
      final Map<String, String> bendera = <String, String>{
        for (final AnalitLabData a in analit) a.nama: a.bendera,
      };
      expect(bendera['Hemoglobin'], 'rendah');
      expect(bendera['Leukosit'], 'tinggi');
      expect(bendera['Trombosit'], 'normal');
    });

    test('tanpa rentang rujukan → tidak dinilai (aplikasi tidak menebak)',
        () async {
      final String uid = await lab.tambah(
          tanggal: DateTime(2026, 9, 1), namaPanel: 'Urinalisis');
      final HasilLabData panel = (await lab.cariUid(uid))!;
      await lab.tambahAnalit(
        hasilLabId: panel.id,
        nama: 'Protein',
        nilaiTeks: 'negatif',
      );
      final List<AnalitLabData> analit = await lab.analitDari(panel.id);
      expect(analit.single.bendera, 'tidak_dinilai');
      expect(analit.single.nilai, isNull);
      expect(analit.single.nilaiTeks, 'negatif');
    });

    test('hanya yang keluar rentang yang muncul di diLuarRentang', () async {
      final String uid =
          await lab.tambah(tanggal: DateTime(2026, 9, 1), namaPanel: 'Lipid');
      final HasilLabData panel = (await lab.cariUid(uid))!;
      await lab.tambahAnalit(
        hasilLabId: panel.id,
        nama: 'Kolesterol',
        nilai: 260,
        rujukanBawah: 120,
        rujukanAtas: 200,
      );
      await lab.tambahAnalit(
        hasilLabId: panel.id,
        nama: 'Trigliserida',
        nilai: 120,
        rujukanBawah: 50,
        rujukanAtas: 150,
      );
      final List<AnalitLabData> luar = await lab.diLuarRentang();
      expect(luar, hasLength(1));
      expect(luar.single.nama, 'Kolesterol');
    });

    test('tren analit berurutan dari yang paling lama', () async {
      for (final (int bulan, double nilai) in <(int, double)>[
        (1, 11.2),
        (4, 11.8),
        (9, 12.4),
      ]) {
        final String uid = await lab.tambah(
            tanggal: DateTime(2026, bulan, 10), namaPanel: 'Darah Lengkap');
        final HasilLabData panel = (await lab.cariUid(uid))!;
        await lab.tambahAnalit(
          hasilLabId: panel.id,
          nama: 'Hemoglobin',
          nilai: nilai,
          satuan: 'g/dL',
          rujukanBawah: 12,
          rujukanAtas: 16,
        );
      }
      final List<TrenAnalit> tren = await lab.trenAnalit('Hemoglobin');
      expect(tren.map((TrenAnalit t) => t.nilai).toList(),
          <double>[11.2, 11.8, 12.4]);
      expect(tren.first.tanggal.month, 1);
      expect(tren.last.tampil, '12.4 g/dL');
    });

    test('hapus panel tidak meninggalkan analit yatim', () async {
      final String uid =
          await lab.tambah(tanggal: DateTime(2026, 9, 1), namaPanel: 'Lipid');
      final HasilLabData panel = (await lab.cariUid(uid))!;
      await lab.tambahAnalit(
          hasilLabId: panel.id, nama: 'Kolesterol', nilai: 180);
      final int anakTerhapus = await lab.hapus(panel.id);
      expect(anakTerhapus, 1);
      expect(await lab.daftar(), isEmpty);
      expect(await lab.analitDari(panel.id), isEmpty);
    });
  });

  // ────────────────────────────────────────────────────────────── gejala
  group('gejala', () {
    test('nama kosong ditolak', () async {
      expect(
        () => gejala.tambah(nama: '  ', mulai: DateTime(2026, 9, 1)),
        throwsA(isA<GalatGejala>()),
      );
    });

    test('selesai lebih awal dari mulai ditolak', () async {
      expect(
        () => gejala.tambah(
          nama: 'sakit kepala',
          mulai: DateTime(2026, 9, 2, 10),
          selesai: DateTime(2026, 9, 2, 8),
        ),
        throwsA(isA<GalatGejala>()),
      );
    });

    test('berat di luar 1–5 dijepit, catatan pengguna tidak hilang', () async {
      await gejala.tambah(
          nama: 'pusing', mulai: DateTime(2026, 9, 1), berat: 9);
      await gejala.tambah(
          nama: 'mual', mulai: DateTime(2026, 9, 2), berat: 0);
      final List<GejalaData> d = await gejala.daftar();
      final Map<String, int?> berat = <String, int?>{
        for (final GejalaData g in d) g.nama: g.berat,
      };
      expect(berat['pusing'], 5);
      expect(berat['mual'], 1);
      expect(d, hasLength(2));
    });

    test('durasi dihitung dari mulai–selesai', () async {
      await gejala.tambah(
        nama: 'nyeri perut',
        mulai: DateTime(2026, 9, 1, 8),
        selesai: DateTime(2026, 9, 1, 10, 30),
      );
      final GejalaData g = (await gejala.daftar()).single;
      expect(g.durasiMenit, 150);
    });

    test('yang belum selesai dianggap masih berlangsung', () async {
      await gejala.tambah(nama: 'batuk', mulai: DateTime(2026, 9, 1));
      final List<GejalaData> jalan = await gejala.sedangBerlangsung();
      expect(jalan.single.selesai, isNull);
      expect(jalan.single.durasiMenit, isNull);
    });

    test('tandai selesai mengisi durasi', () async {
      await gejala.tambah(nama: 'demam', mulai: DateTime(2026, 9, 1, 6));
      final GejalaData g = (await gejala.daftar()).single;
      await gejala.tandaiSelesai(g.id, DateTime(2026, 9, 1, 18));
      final GejalaData lagi = (await gejala.daftar()).single;
      expect(lagi.durasiMenit, 720);
    });

    test('paling sering menyusun frekuensi menurun', () async {
      for (int i = 0; i < 3; i++) {
        await gejala.tambah(
            nama: 'sakit kepala', mulai: DateTime(2026, 9, 1 + i));
      }
      await gejala.tambah(nama: 'mual', mulai: DateTime(2026, 9, 5));
      final List<FrekuensiGejala> f = await gejala.palingSering();
      expect(f.first.nama, 'sakit kepala');
      expect(f.first.jumlah, 3);
      expect(f.last.jumlah, 1);
    });
  });

  // ──────────────────────────────────────────────────────────── imunisasi
  group('imunisasi', () {
    Future<int> _anggota() async {
      final int id = await db.into(db.anggotaKeluarga).insert(
            AnggotaKeluargaCompanion.insert(
              idAnggota: 'A-1',
              nama: 'Anak Uji',
              tanggalLahir: Value(DateTime(2021, 3, 10)),
            ),
          );
      return id;
    }

    test('dosis yang sama tidak boleh tercatat dua kali', () async {
      final int a = await _anggota();
      await imunisasi.tambah(
        anggotaId: a,
        namaVaksin: 'Campak',
        tanggal: DateTime(2021, 9, 10),
        dosisKe: 1,
      );
      expect(
        () => imunisasi.tambah(
          anggotaId: a,
          namaVaksin: 'Campak',
          tanggal: DateTime(2021, 9, 10),
          dosisKe: 1,
        ),
        throwsA(isA<GalatImunisasi>()),
      );
    });

    test('dosis berbeda untuk vaksin sama diterima', () async {
      final int a = await _anggota();
      await imunisasi.tambah(
          anggotaId: a, namaVaksin: 'DPT', tanggal: DateTime(2021, 5, 1));
      await imunisasi.tambah(
        anggotaId: a,
        namaVaksin: 'DPT',
        tanggal: DateTime(2021, 6, 1),
        dosisKe: 2,
      );
      final List<ImunisasiData> r = await imunisasi.riwayat(a);
      expect(r, hasLength(2));
    });

    test('jatuh tempo & akan datang memisahkan tanggal lampau dan nanti',
        () async {
      final int a = await _anggota();
      await imunisasi.tambah(
        anggotaId: a,
        namaVaksin: 'Campak',
        tanggal: DateTime(2021, 9, 10),
        berikutnyaPada: DateTime(2026, 9, 1),
      );
      await imunisasi.tambah(
        anggotaId: a,
        namaVaksin: 'Polio',
        tanggal: DateTime(2021, 4, 1),
        dosisKe: 2,
        berikutnyaPada: DateTime(2026, 12, 1),
      );
      final DateTime acuan = DateTime(2026, 9, 23);
      final List<ImunisasiData> tempo = await imunisasi.jatuhTempo(pada: acuan);
      final List<ImunisasiData> nanti = await imunisasi.akanDatang(sejak: acuan);
      expect(tempo.single.namaVaksin, 'Campak');
      expect(nanti.single.namaVaksin, 'Polio');
    });

    test('anggota tanpa dosis berikutnya tidak muncul di pengingat', () async {
      final int a = await _anggota();
      await imunisasi.tambah(
          anggotaId: a, namaVaksin: 'BCG', tanggal: DateTime(2021, 3, 11));
      expect(await imunisasi.jatuhTempo(pada: DateTime(2027, 1, 1)), isEmpty);
      expect(await imunisasi.akanDatang(sejak: DateTime(2020, 1, 1)), isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────── tumbuh kembang
  group('tumbuh kembang', () {
    Future<int> _anak() async {
      final int id = await db.into(db.anggotaKeluarga).insert(
            AnggotaKeluargaCompanion.insert(
              idAnggota: 'A-2',
              nama: 'Anak Dua',
              tanggalLahir: Value(DateTime(2024, 5, 20)),
            ),
          );
      return id;
    }

    test('tanpa satu pun ukuran ditolak', () async {
      final int a = await _anak();
      expect(
        () => tumbuh.simpan(
            anggotaId: a, tanggal: DateTime(2026, 9, 1), umurBulan: 28),
        throwsA(isA<GalatTumbuhKembang>()),
      );
    });

    test('angka tidak masuk akal ditolak', () async {
      final int a = await _anak();
      expect(
        () => tumbuh.simpan(
          anggotaId: a,
          tanggal: DateTime(2026, 9, 1),
          umurBulan: 28,
          tinggiCm: 320,
        ),
        throwsA(isA<GalatTumbuhKembang>()),
      );
    });

    test('satu anak satu baris per hari — simpan ulang menimpa', () async {
      final int a = await _anak();
      await tumbuh.simpan(
        anggotaId: a,
        tanggal: DateTime(2026, 9, 1, 7),
        umurBulan: 27,
        beratKg: 12.4,
        tinggiCm: 88,
      );
      await tumbuh.simpan(
        anggotaId: a,
        tanggal: DateTime(2026, 9, 1, 19),
        umurBulan: 27,
        beratKg: 12.6,
        tinggiCm: 88.4,
      );
      final List<TumbuhKembangData> deret = await tumbuh.deret(a);
      expect(deret, hasLength(1), reason: 'tidak boleh ada baris kembar');
      expect(deret.single.beratKg, 12.6);
    });

    test('umur bulan dihitung dari tanggal lahir, bukan ditebak', () {
      // Lahir 20 Mei 2024; diukur 20 Sep 2026 → 28 bulan.
      expect(
        TumbuhKembangRepository.umurBulanPada(
            DateTime(2024, 5, 20), DateTime(2026, 9, 20)),
        28,
      );
      // Diukur sehari sebelum tanggal ulang bulan → masih 27 bulan.
      expect(
        TumbuhKembangRepository.umurBulanPada(
            DateTime(2024, 5, 20), DateTime(2026, 9, 19)),
        27,
      );
      // Tanggal lahir di masa depan tidak menghasilkan angka negatif.
      expect(
        TumbuhKembangRepository.umurBulanPada(
            DateTime(2027, 1, 1), DateTime(2026, 9, 23)),
        0,
      );
    });

    test('imt = berat ÷ tinggi² dan kosong bila data belum lengkap', () {
      expect(TumbuhKembangRepository.imt(beratKg: 12.6, tinggiCm: 90), 15.6);
      expect(TumbuhKembangRepository.imt(beratKg: 12.6), isNull);
      expect(TumbuhKembangRepository.imt(tinggiCm: 90), isNull);
    });

    test('persentil tidak ditebak: alasannya dinyatakan apa adanya', () {
      expect(
        TumbuhKembangRepository.alasanPersentilKosong(
            beratKg: 12.6, tinggiCm: 90),
        contains('tabel rujukan'),
      );
      expect(
        TumbuhKembangRepository.alasanPersentilKosong(beratKg: 12.6),
        contains('tinggi badan belum diisi'),
      );
      expect(
        TumbuhKembangRepository.alasanPersentilKosong(),
        contains('belum diisi'),
      );
    });

    test('pengukuran tersimpan kosong persentil (bukan angka karangan)',
        () async {
      final int a = await _anak();
      await tumbuh.simpan(
        anggotaId: a,
        tanggal: DateTime(2026, 9, 1),
        umurBulan: 27,
        beratKg: 12.6,
        tinggiCm: 90,
      );
      final TumbuhKembangData t = (await tumbuh.terakhir(a))!;
      expect(t.persentilBmi, isNull);
    });
  });

  // ───────────────────────────────────────────────────────── sinkron & audit
  group('sinkron & audit', () {
    test('lima jalur sinkron v20 terdaftar, induk sebelum anak', () {
      final List<String> nama = daftarJalurSinkron(db)
          .map((JalurSinkron j) => j.nama)
          .toList();
      for (final String t in tabelV20) {
        expect(nama, contains(t), reason: 'jalur $t harus terdaftar');
      }
      expect(nama.indexOf('hasil_lab'), lessThan(nama.indexOf('analit_lab')));
    });

    test('empat modul audit baru dikenali', () {
      expect(ModulAudit.semua, contains(ModulAudit.hasilLab));
      expect(ModulAudit.semua, contains(ModulAudit.gejala));
      expect(ModulAudit.semua, contains(ModulAudit.imunisasi));
      expect(ModulAudit.semua, contains(ModulAudit.tumbuhKembang));
    });
  });
}
