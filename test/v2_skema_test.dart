/// Uji SKEMA v4 — fondasi V2 "Pilar Kehidupan".
///
/// Berkas ini menjaga tiga hal yang mudah rusak tanpa disadari:
/// 1. `onCreate` membuat SELURUH 23 tabel V2 + template perawatan bawaan,
/// 2. indeks UNIK penjaga "satu baris per kunci bisnis" benar-benar berlaku,
/// 3. pengguna lama (skema v3 di perangkat) naik ke v4 **tanpa kehilangan data**.
///
/// Cara menguji migrasi: database v3 asli DIBUAT dengan membangun skema v4 lebih
/// dulu, lalu seluruh tabel V2 dijatuhkan dan `user_version` dikembalikan ke 3.
/// Dengan begitu berkas lama memuat DDL v3 yang BENAR (bukan tulis-tangan),
/// sehingga jalur `onUpgrade(3 -> 4)` diuji apa adanya.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/data/database/database.dart';

/// Tabel yang sudah ada pada skema v3 — sisanya adalah tabel V2 yang harus
/// dijatuhkan saat menyiapkan berkas "pengguna lama".
const _tabelV3 = {
  'kategori',
  'tagihan',
  'riwayat_pembayaran',
  'pemasukan_bulanan',
  'pengaturan',
  'kategori_transaksi',
  'transaksi',
  'anggaran_bulanan',
  'langganan',
  'aset',
  'kewajiban',
  'nilai_aset_bulanan',
  'nilai_kewajiban_bulanan',
};

/// Nama tabel V2 (untuk uji "tabelnya ada").
const _tabelV2 = [
  'tujuan',
  'proyek',
  'tugas',
  'kebiasaan',
  'log_kebiasaan',
  'perawatan',
  'ukuran_tubuh',
  'aktivitas',
  'tidur',
  'obat',
  'jadwal_obat',
  'minum_obat',
  'catatan_air',
  'dokumen',
  'audit_log',
  'notifikasi_riwayat',
  'tunda_pengingat',
  'pembayaran_kewajiban',
  'pengeluaran_terencana',
  'log_puasa',
  'log_quran',
  'log_dzikir',
  'refleksi_muhasabah',
];

Future<Set<String>> _namaTabel(AppDatabase db) async {
  final baris = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return baris.map((r) => r.read<String>('name')).toSet();
}

void main() {
  group('skema v4 (onCreate)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
    });

    test('versi skema terkini & seluruh tabel pilar dibuat', () async {
      // Skema 5 = rantai rencana (FR-82); 6 = sinkron antar HP (kolom
      // tagihan.uid + sinkron_kotor); 7 = lima tabel kesehatan/ibadah/kas;
      // 8 = kolom sisa obat (FR-107); 15 = energi/fokus/jam produktif pada
      // `tidur` (FR-84) + rencana haji/umrah (FR-97); 16 = perjalanan, jurnal
      // perjalanan & kas rumah tangga (FR-133/134/135).
      expect(db.schemaVersion, 18);
      final tabel = await _namaTabel(db);
      for (final nama in _tabelV2) {
        expect(tabel.contains(nama), isTrue, reason: 'tabel $nama belum dibuat');
      }
      // 13 tabel lama + 23 tabel V2 + 2 tabel v5 + sqlite_sequence.
      expect(tabel.length, greaterThanOrEqualTo(43));
    });

    test('seluruh tabel V2 bisa dibaca & masih kosong', () async {
      expect(await db.select(db.tujuan).get(), isEmpty);
      expect(await db.select(db.proyek).get(), isEmpty);
      expect(await db.select(db.tugas).get(), isEmpty);
      expect(await db.select(db.kebiasaan).get(), isEmpty);
      expect(await db.select(db.logKebiasaan).get(), isEmpty);
      expect(await db.select(db.ukuranTubuh).get(), isEmpty);
      expect(await db.select(db.aktivitas).get(), isEmpty);
      expect(await db.select(db.tidur).get(), isEmpty);
      expect(await db.select(db.obat).get(), isEmpty);
      expect(await db.select(db.jadwalObat).get(), isEmpty);
      expect(await db.select(db.minumObat).get(), isEmpty);
      expect(await db.select(db.catatanAir).get(), isEmpty);
      expect(await db.select(db.dokumen).get(), isEmpty);
      expect(await db.select(db.auditLog).get(), isEmpty);
      expect(await db.select(db.notifikasiRiwayat).get(), isEmpty);
      expect(await db.select(db.tundaPengingat).get(), isEmpty);
      expect(await db.select(db.pembayaranKewajiban).get(), isEmpty);
      expect(await db.select(db.pengeluaranTerencana).get(), isEmpty);
      expect(await db.select(db.logPuasa).get(), isEmpty);
      expect(await db.select(db.logQuran).get(), isEmpty);
      expect(await db.select(db.logDzikir).get(), isEmpty);
      expect(await db.select(db.refleksiMuhasabah).get(), isEmpty);
    });

    test('template perawatan berkala bawaan terisi (FR-83)', () async {
      final daftar = await db.select(db.perawatan).get();
      expect(daftar.length, 6);
      expect(daftar.map((p) => p.templateKode).toSet(),
          {'oli_mesin', 'servis_ac', 'filter_air', 'pajak_kendaraan',
           'cadangan_data', 'periksa_gigi'});
      for (final p in daftar) {
        expect(p.aktif, isTrue);
        expect(p.berikutnya.isAfter(DateTime(2000)), isTrue);
      }
    });
  });

  group('indeks unik skema v4', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
    });

    test('satu kebiasaan satu catatan per hari', () async {
      final id = await db.into(db.kebiasaan).insert(
          KebiasaanCompanion.insert(idKebiasaan: 'kb_1', nama: 'Minum air'));
      final tanggal = DateTime(2026, 9, 15);
      await db.into(db.logKebiasaan).insert(LogKebiasaanCompanion.insert(
          kebiasaanId: id, tanggal: tanggal));
      await expectLater(
        db.into(db.logKebiasaan).insert(
            LogKebiasaanCompanion.insert(kebiasaanId: id, tanggal: tanggal)),
        throwsA(anything),
        reason: 'duplikat (kebiasaan, tanggal) harus ditolak',
      );
      // Hari lain tetap boleh.
      await db.into(db.logKebiasaan).insert(LogKebiasaanCompanion.insert(
          kebiasaanId: id, tanggal: DateTime(2026, 9, 16)));
      expect((await db.select(db.logKebiasaan).get()).length, 2);
    });

    test('satu catatan tidur per malam', () async {
      final tidur = TidurCompanion.insert(
        tanggal: DateTime(2026, 9, 15),
        jamTidur: DateTime(2026, 9, 14, 23),
        jamBangun: DateTime(2026, 9, 15, 6),
        durasiMenit: 420,
      );
      await db.into(db.tidur).insert(tidur);
      await expectLater(
          db.into(db.tidur).insert(tidur), throwsA(anything));
    });

    test('satu catatan minum obat per jadwal', () async {
      final obatId = await db.into(db.obat).insert(
          ObatCompanion.insert(nama: 'Vitamin D'));
      final rencana = DateTime(2026, 9, 15, 8);
      final catat = MinumObatCompanion.insert(
          obatId: obatId, waktuRencana: rencana);
      await db.into(db.minumObat).insert(catat);
      await expectLater(db.into(db.minumObat).insert(catat), throwsA(anything));
    });

    test('satu penundaan per pengingat (ditunda lagi = diperbarui)', () async {
      final tunda = TundaPengingatCompanion.insert(
          pengingatId: 42, kapan: DateTime(2026, 9, 15, 9));
      await db.into(db.tundaPengingat).insert(tunda);
      await expectLater(
          db.into(db.tundaPengingat).insert(tunda), throwsA(anything));
    });

    test('satu refleksi muhasabah per tanggal', () async {
      final ref = RefleksiMuhasabahCompanion.insert(
          tanggal: DateTime(2026, 9, 15));
      await db.into(db.refleksiMuhasabah).insert(ref);
      await expectLater(
          db.into(db.refleksiMuhasabah).insert(ref), throwsA(anything));
    });

    test('satu log puasa per tanggal + jenis', () async {
      final a = LogPuasaCompanion.insert(
          tanggal: DateTime(2026, 9, 15), jenis: 'sunnah');
      await db.into(db.logPuasa).insert(a);
      await expectLater(db.into(db.logPuasa).insert(a), throwsA(anything));
      await db.into(db.logPuasa).insert(LogPuasaCompanion.insert(
          tanggal: DateTime(2026, 9, 15), jenis: 'qadha'));
      expect((await db.select(db.logPuasa).get()).length, 2);
    });

    test('pengenal stabil (id_tugas, id_dokumen, id_tujuan) unik', () async {
      await db.into(db.tujuan).insert(
          TujuanCompanion.insert(idTujuan: 'tj_1', nama: 'Sehat'));
      await expectLater(
        db.into(db.tujuan).insert(
            TujuanCompanion.insert(idTujuan: 'tj_1', nama: 'Sehat lagi')),
        throwsA(anything),
      );
      await db.into(db.dokumen).insert(
          DokumenCompanion.insert(idDokumen: 'dk_1', nama: 'KTP'));
      await expectLater(
        db.into(db.dokumen).insert(
            DokumenCompanion.insert(idDokumen: 'dk_1', nama: 'KTP lagi')),
        throwsA(anything),
      );
      await db.into(db.tugas).insert(
          TugasCompanion.insert(idTugas: 'tg_1', nama: 'Bayar listrik'));
      await expectLater(
        db.into(db.tugas).insert(
            TugasCompanion.insert(idTugas: 'tg_1', nama: 'Bayar air')),
        throwsA(anything),
      );
    });
  });

  group('migrasi v3 -> v4', () {
    late Directory folder;
    late File berkas;

    setUp(() async {
      folder = Directory.systemTemp.createTempSync('plo_migrasi_v4');
      berkas = File('${folder.path}/personal_life_os.sqlite');

      // 1. Bangun skema v4 asli, lalu buang semua tabel V2 supaya berkas ini
      //    benar-benar berisi skema v3.
      final penuh = AppDatabase.forTesting(NativeDatabase(berkas));
      await penuh.select(penuh.kategori).get(); // jalankan onCreate
      await penuh.customStatement('PRAGMA foreign_keys = OFF');
      final semua = await _namaTabel(penuh);
      for (final nama in semua) {
        if (_tabelV3.contains(nama) || nama.startsWith('sqlite_')) continue;
        await penuh.customStatement('DROP TABLE IF EXISTS "$nama"');
      }
      await penuh.customStatement('PRAGMA user_version = 3');
      await penuh.close();

      // 2. Isi data pengguna lama lewat jalur mentah (seperti perangkat nyata).
      final lama = NativeDatabase(berkas);
      await lama.ensureOpen(_SkemaLamaV3());
      await lama.runCustom(
        "INSERT INTO tagihan (nama, jumlah_sen, jatuh_tempo, dibuat_pada, "
        "diubah_pada) VALUES ('Internet', 3500000, 1789000000, 1789000000, 1789000000)",
        const [],
      );
      await lama.runCustom(
        "INSERT INTO riwayat_pembayaran (tagihan_id, periode_jatuh_tempo, "
        "jumlah_sen, tanggal_bayar) VALUES (1, 1789000000, 3500000, 1789000000)",
        const [],
      );
      await lama.runCustom(
        "INSERT INTO transaksi (id_transaksi, jenis, jumlah_sen, tanggal, "
        "dibuat_pada, diubah_pada) VALUES "
        "('trx_lama', 'pengeluaran', 5000000, 1789000000, 1789000000, 1789000000)",
        const [],
      );
      await lama.close();
    });

    tearDown(() {
      if (folder.existsSync()) folder.deleteSync(recursive: true);
    });

    test('tabel V2 dibuat, data lama selamat, template perawatan terisi',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase(berkas));
      addTearDown(db.close);

      // Membaca tabel V2 memaksa onUpgrade(3 -> 4) berjalan.
      expect(await db.select(db.tugas).get(), isEmpty);
      expect(await db.select(db.auditLog).get(), isEmpty);
      expect(await db.select(db.logQuran).get(), isEmpty);

      final tagihanLama = await db.select(db.tagihan).get();
      expect(tagihanLama.length, 1);
      expect(tagihanLama.single.nama, 'Internet');
      expect(await db.select(db.riwayatPembayaran).get(), hasLength(1));
      final trx = await db.select(db.transaksi).get();
      expect(trx.single.idTransaksi, 'trx_lama');

      final perawatan = await db.select(db.perawatan).get();
      expect(perawatan.length, 6, reason: 'template perawatan harus terisi');

      final tabel = await _namaTabel(db);
      for (final nama in _tabelV2) {
        expect(tabel.contains(nama), isTrue, reason: 'tabel $nama belum dibuat');
      }
    });

    test('indeks unik lama (PB-05/PB-07) masih berlaku setelah migrasi',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase(berkas));
      addTearDown(db.close);
      await db.select(db.tugas).get(); // paksa migrasi selesai

      final indeks = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final nama = indeks.map((r) => r.read<String>('name')).toSet();
      for (final wajib in [
        'idx_riwayat_periode',
        'idx_pemasukan_bulan',
        'idx_trx_id',
        'idx_tugas_id',
        'idx_log_kebiasaan_hari',
        'idx_refleksi_tanggal',
      ]) {
        expect(nama.contains(wajib), isTrue, reason: 'indeks $wajib hilang');
      }

      // Duplikat periode pembayaran tetap ditolak (bukti indeks bekerja).
      await expectLater(
        db.customStatement(
          "INSERT INTO riwayat_pembayaran (tagihan_id, periode_jatuh_tempo, "
          "jumlah_sen, tanggal_bayar) VALUES (1, 1789000000, 3500000, 1789000000)",
        ),
        throwsA(anything),
      );
    });
  });
}

/// Pengguna executor untuk membuka berkas v3 lewat jalur mentah.
class _SkemaLamaV3 extends QueryExecutorUser {
  @override
  int get schemaVersion => 3;

  @override
  Future<void> beforeOpen(
      QueryExecutor executor, OpeningDetails details) async {}
}
