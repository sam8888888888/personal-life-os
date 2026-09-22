/// Koneksi database utama — Drift + SQLite lokal (offline-first, PRD §8.2).
library;

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/utils/waktu.dart';
import '../repository/template_kategori_transaksi.dart';
import 'tabel.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Kategori,
  Tagihan,
  RiwayatPembayaran,
  PemasukanBulanan,
  Pengaturan,
  SinkronKotor,
  // Skema v3 — fondasi V1.5 (FR-68/71/72/76), ditambahkan Aaron 15 Sep 2026.
  KategoriTransaksi,
  Transaksi,
  AnggaranBulanan,
  Langganan,
  Aset,
  Kewajiban,
  NilaiAsetBulanan,
  NilaiKewajibanBulanan,
  // Skema v5 — Rantai rencana (FR-82), ditambahkan Aaron 19 Sep 2026:
  // Visi -> Area hidup -> (Tujuan v4) -> Proyek -> Tugas.
  Visi,
  AreaHidup,
  // Skema v4 — Pilar Kehidupan (V2), ditambahkan Dinda 15 Sep 2026.
  // Aksi & tujuan (FR-78/79/80/83)
  Tujuan,
  Proyek,
  Tugas,
  Kebiasaan,
  LogKebiasaan,
  Perawatan,
  // Kesehatan (FR-101/102/103/106/111)
  UkuranTubuh,
  Aktivitas,
  Tidur,
  Obat,
  JadwalObat,
  MinumObat,
  CatatanAir,
  // Dokumen (FR-128/129)
  Dokumen,
  // Platform (FR-136/137/138/139/147/148)
  AuditLog,
  NotifikasiRiwayat,
  TundaPengingat,
  // Uang lanjutan (FR-73/74/75/77)
  PembayaranKewajiban,
  PengeluaranTerencana,
  // Ibadah lanjutan (FR-91/92/93/95/100)
  LogPuasa,
  LogQuran,
  LogDzikir,
  RefleksiMuhasabah,
  // Kesehatan lanjutan (FR-105/FR-109) & kas informal (FR-51),
  // hafalan (FR-94), zakat & sedekah (FR-96)
  CatatanKesehatan,
  JanjiKesehatan,
  KasInformal,
  Hafalan,
  ZakatSedekah,
  // Skema v9 — Pengetahuan (FR-118/119/120/121/122/123) & kesehatan ringkas
  // (FR-110 makan, FR-112 suasana hati), ditambahkan Aaron 21 Sep 2026.
  CatatanPengetahuan,
  Keputusan,
  Pembelajaran,
  KartuUlangan,
  Bacaan,
  TautanPengetahuan,
  CatatanMakan,
  SuasanaHati,
  // Skema v10 — pendukung sinkron semua modul (FR-150), Aaron 22 Sep 2026.
  SinkronSidik,
  SinkronTautanBelum,
  // Skema v11 — lampiran foto & rekaman suara (FR-118).
  Lampiran,
  // Skema v12 — Home & Asset OS (FR-124/125/126/127), Aaron 22 Sep 2026.
  RiwayatPerawatanAset,
  // Skema v13 — Family OS (FR-131), profil kesehatan (FR-117),
  // brankas catatan medis (FR-108).
  AnggotaKeluarga,
  ProfilKesehatan,
  CatatanMedis,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_buka());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _pasangIndeksUnik();
          await _pasangIndeksUnikV3();
          await _pasangIndeksUnikV4();
          await _pasangIndeksUnikV5();
          await _seedKategori();
          await seedKategoriTransaksi();
          await _seedPerawatanV4();
        },
        onUpgrade: (m, dari, ke) async {
          if (dari < 2) {
            // PB-05/PB-07: rapikan data lama SEBELUM indeks unik dibuat,
            // supaya migrasi tidak gagal di perangkat yang sudah punya duplikat.
            final hapusRiwayat = await customUpdate('''
DELETE FROM riwayat_pembayaran WHERE id NOT IN (
  SELECT MIN(id) FROM riwayat_pembayaran GROUP BY tagihan_id, periode_jatuh_tempo
)''');
            final hapusPemasukan = await customUpdate('''
DELETE FROM pemasukan_bulanan WHERE id NOT IN (
  SELECT MAX(id) FROM pemasukan_bulanan GROUP BY bulan
)''');
            await _pasangIndeksUnik();
            debugPrint('migrasi v2 selesai (baris dibersihkan: '
                '$hapusRiwayat riwayat / $hapusPemasukan pemasukan)');
          }
          if (dari < 3) {
            // v3: tabel BARU saja — tidak ada kolom tabel lama yang diubah,
            // jadi data pengguna tidak tersentuh oleh migrasi ini.
            await _buatTabelV3(m);
            await _pasangIndeksUnikV3();
            await seedKategoriTransaksi();
            final jml = await (selectOnly(kategoriTransaksi)
                  ..addColumns([kategoriTransaksi.id]))
                .get();
            debugPrint('migrasi v3 selesai (tabel kas & kekayaan dibuat, '
                'kategori transaksi: ${jml.length})');
          }
          if (dari < 4) {
            // v4: 23 tabel BARU untuk V2 (pilar kehidupan). Tidak ada kolom
            // tabel lama yang diubah, jadi data pengguna tidak tersentuh.
            await _buatTabelV4(m);
            await _pasangIndeksUnikV4();
            await _seedPerawatanV4();
            debugPrint('migrasi v4 selesai (tabel pilar kehidupan dibuat)');
          }
          if (dari < 6) {
            // v6 (sinkron antar HP): kolom uid di tagihan + tabel jejak hapus.
            // Baris lama diberi uid unik per baris, jadi tidak ada yang bentrok
            // dan data pengguna tidak berubah isinya.
            await m.createTable(sinkronKotor);
            // Sebagian basis data lama (dibuat dari definisi tabel terbaru)
            // sudah punya kolom uid walau versinya masih di bawah 6 — jadi
            // kolomnya diperiksa dulu supaya migrasi tidak gagal di HP mana pun.
            final kolomTagihan =
                await customSelect("PRAGMA table_info(tagihan)").get();
            final sudahAdaUid = kolomTagihan
                .any((r) => (r.data['name'] as String?) == 'uid');
            if (!sudahAdaUid) {
              await m.addColumn(tagihan, tagihan.uid);
            }
            await customStatement(
                "UPDATE tagihan SET uid = lower(hex(randomblob(8))) "
                "WHERE uid IS NULL OR uid = ''");
            await customStatement(
                'CREATE UNIQUE INDEX IF NOT EXISTS idx_tagihan_uid '
                'ON tagihan(uid)');
            debugPrint('migrasi v6 selesai (uid tagihan terisi, catatan perubahan siap)');
          }
          if (dari < 9) {
            // v9: delapan tabel BARU (pengetahuan + makan & suasana hati).
            // Tanpa mengubah tabel lama, jadi data pengguna tidak tersentuh.
            await _buatTabelV9(m);
            debugPrint('migrasi v9 selesai (tabel pengetahuan & catatan makan/'
                'suasana hati dibuat)');
          }
          if (dari < 8) {
            // v8 (FR-107): kolom sisa obat. Kolom BARU boleh kosong, jadi data
            // obat yang sudah ada tidak berubah.
            await _tambahKolomV8(m);
            debugPrint('migrasi v8 selesai (kolom sisa obat ditambahkan)');
          }
          if (dari < 7) {
            // v7: lima tabel BARU (kesehatan lanjutan, janji dokter, kas
            // informal, hafalan, zakat & sedekah). Tidak ada kolom tabel lama
            // yang diubah, jadi data pengguna tidak tersentuh.
            await _buatTabelV7(m);
            debugPrint('migrasi v7 selesai (catatan kesehatan, janji dokter, '
                'kas informal, hafalan, zakat & sedekah dibuat)');
          }
          if (dari < 5) {
            // v5 (FR-82): dua tabel BARU (visi, area hidup) + satu kolom BARU
            // pada `tujuan` (area_id). Kolom nullable, jadi tujuan lama tetap
            // utuh tanpa diisi apa pun.
            await m.createTable(visi);
            await m.createTable(areaHidup);
            // Kolom area_id hanya ditambahkan bila tabel `tujuan` SUDAH ada
            // (perangkat yang datang dari v4). Bila perangkat datang dari v2/v3,
            // tabel tujuan baru saja dibuat oleh blok v4 di atas dan sudah
            // memuat kolom ini — menambahkannya lagi = galat "duplicate column".
            if (dari >= 4) {
              await m.addColumn(tujuan, tujuan.areaId);
            }
            await _pasangIndeksUnikV5();
            debugPrint('migrasi v5 selesai (visi & area hidup dibuat, '
                'kolom tujuan.area_id ditambahkan)');
          }
          if (dari < 10) {
            // v10 (FR-150): pengenal `uid` untuk tabel lama + dua tabel
            // pendukung sinkron. Kolom baru bersifat nullable, jadi data
            // pengguna tidak tersentuh.
            await _buatTabelV10(m);
            debugPrint('migrasi v10 selesai (uid sinkron + tabel pendukung)');
          }
          if (dari < 11) {
            // v11 (FR-118): lampiran foto & rekaman suara pada catatan.
            if (!await _tabelAda('lampiran')) await m.createTable(lampiran);
            debugPrint('migrasi v11 selesai (tabel lampiran dibuat)');
          }
          if (dari < 12) {
            // v12 (FR-124…FR-127): aset fisik + perawatan aset.
            await _buatTabelV12(m);
            debugPrint('migrasi v12 selesai (aset fisik & riwayat perawatan)');
          }
          if (dari < 13) {
            // v13 (FR-108/117/131): keluarga, profil kesehatan, catatan medis.
            await _buatTabelV13(m);
            debugPrint('migrasi v13 selesai (keluarga, profil & catatan medis)');
          }
        },
      );

  /// PB-05 & PB-07: indeks unik penjaga integritas.
  ///
  /// Dipasang lewat SQL (bukan anotasi tabel) karena `database.g.dart` dilacak
  /// git: build_runner dipakai untuk membuat tabel, tetapi jaminan unik sengaja
  /// TIDAK bergantung pada hasil regenerasi (aturan "never-regenerate" PB-05/PB-07).
  Future<void> _pasangIndeksUnik() async {
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_riwayat_periode '
        'ON riwayat_pembayaran(tagihan_id, periode_jatuh_tempo)');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_pemasukan_bulan '
        'ON pemasukan_bulanan(bulan)');
  }

  /// Skema v5 (FR-82): keunikan pengenal stabil visi & area hidup.
  Future<void> _pasangIndeksUnikV5() async {
    await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_visi_id ON visi(id_visi)');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_area_id '
        'ON area_hidup(id_area)');
  }

  /// Skema v3: tabel baru dibuat di sini (urutan tidak penting, tidak ada FK
  /// yang ditegakkan SQLite secara default di proyek ini).
  Future<void> _buatTabelV3(Migrator m) async {
    await m.createTable(kategoriTransaksi);
    await m.createTable(transaksi);
    await m.createTable(anggaranBulanan);
    await m.createTable(langganan);
    await m.createTable(aset);
    await m.createTable(kewajiban);
    await m.createTable(nilaiAsetBulanan);
    await m.createTable(nilaiKewajibanBulanan);
  }

  /// Skema v3: indeks unik — jaminan "satu baris per kunci bisnis"
  /// (mengikuti gaya PB-05/PB-07: SQL, bukan anotasi tabel).
  ///
  /// Catatan: indeks unik pada kolom nullable (mis. `langganan(tagihan_id)`)
  /// tetap mengizinkan banyak NULL di SQLite — itu yang diinginkan (banyak
  /// langganan tanpa tagihan tertaut).
  Future<void> _pasangIndeksUnikV3() async {
    // Kategori transaksi
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_kt_kode '
        'ON kategori_transaksi(kode)');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_kt_jenis_nama '
        'ON kategori_transaksi(jenis, nama)');
    // Transaksi
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_trx_id '
        'ON transaksi(id_transaksi)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_trx_tanggal '
        'ON transaksi(tanggal)');
    // Anggaran
    await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_anggaran_periode_kategori '
        'ON anggaran_bulanan(periode, kategori_id)');
    // Langganan
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_langganan_id '
        'ON langganan(id_langganan)');
    await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_langganan_tagihan '
        'ON langganan(tagihan_id)');
    // Aset & kewajiban
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_aset_id '
        'ON aset(id_aset)');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_kewajiban_id '
        'ON kewajiban(id_kewajiban)');
    // Riwayat nilai bulanan
    await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_nilai_aset_bulan '
        'ON nilai_aset_bulanan(aset_id, bulan)');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_nilai_aset_idem '
        'ON nilai_aset_bulanan(idempotensi)');
    await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_nilai_kewajiban_bulan '
        'ON nilai_kewajiban_bulanan(kewajiban_id, bulan)');
    await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_nilai_kewajiban_idem '
        'ON nilai_kewajiban_bulanan(idempotensi)');
  }

  /// Kategori bawaan penyedia layanan Indonesia (FR-05 template lokal).
  Future<void> _seedKategori() async {
    final seed = [
      ('PLN', 'bolt', '#F5A623'),
      ('PDAM', 'water_drop', '#4A90D9'),
      ('BPJS', 'health_and_safety', '#4CAF50'),
      ('Internet & TV', 'wifi', '#7B68EE'),
      ('Ponsel', 'smartphone', '#F06292'),
      ('Kartu kredit', 'credit_card', '#9E9E9E'),
      ('Langganan', 'subscriptions', '#00ACC1'),
      ('Kendaraan', 'directions_car', '#5C6BC0'),
      ('Sekolah', 'school', '#FFB74D'),
      ('Rumah tangga', 'home', '#8D6E63'),
    ];
    final ada = await (selectOnly(kategori)..addColumns([kategori.id])).get();
    if (ada.isNotEmpty) return;
    for (final (i, s) in seed.indexed) {
      await into(kategori).insert(KategoriCompanion.insert(
        nama: s.$1,
        ikon: Value(s.$2),
        warna: Value(s.$3),
        urutan: Value(i),
      ));
    }
  }

  /// Kategori kas bawaan (FR-71/FR-72) — 11 pengeluaran + 12 pemasukan,
  /// mengikuti `KATEGORI_KEUANGAN_ID.md` (rancangan Dinda).
  ///
  /// Idempoten: `INSERT OR IGNORE` + indeks unik `kode`, jadi aman dipanggil
  /// saat migrasi maupun saat pengguna mengganti nama kategori (kode tetap,
  /// kategori tidak berganda). BOLEH dipanggil ulang kapan pun.
  Future<void> seedKategoriTransaksi() async {
    for (final t in daftarKategoriTransaksi) {
      await into(kategoriTransaksi).insert(
        KategoriTransaksiCompanion.insert(
          kode: t.kode,
          nama: t.nama,
          jenis: Value(t.jenis),
          ikon: Value(t.ikon),
          warna: Value(t.warna),
          urutan: Value(t.urutan),
          sifatArus: Value(t.sifatArus),
          bawaanSistem: const Value(true),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  /// Skema v4: 23 tabel baru pilar kehidupan (V2).
  /// Skema v8 (FR-107): kolom sisa obat pada tabel obat yang sudah ada.
  Future<void> _tambahKolomV8(Migrator m) async {
    // Sebagian basis data lama dibuat dari definisi tabel terbaru, jadi
    // kolomnya bisa sudah ada walau versinya masih di bawah 8 — diperiksa
    // dulu supaya migrasi tidak pernah gagal karena kolom kembar.
    if (!await _tabelAda('obat')) return;
    final kolom = await customSelect("PRAGMA table_info(obat)").get();
    final nama = kolom.map((r) => (r.data['name'] as String?) ?? '').toSet();
    if (!nama.contains('sisa')) await m.addColumn(obat, obat.sisa);
    if (!nama.contains('sisa_diperbarui_pada')) {
      await m.addColumn(obat, obat.sisaDiperbaruiPada);
    }
  }

  /// Skema v9 (batch 3): delapan tabel baru — pengetahuan (FR-118…FR-123) dan
  /// catatan makan (FR-110) + suasana hati (FR-112).
  ///
  /// Dibuat dengan pemeriksaan keberadaan tabel lebih dulu: sebagian basis data
  /// lama dibangun dari definisi tabel terbaru, jadi tabelnya bisa sudah ada.
  Future<void> _buatTabelV9(Migrator m) async {
    final Map<String, TableInfo<Table, dynamic>> tabel = {
      'catatan_pengetahuan': catatanPengetahuan,
      'keputusan': keputusan,
      'pembelajaran': pembelajaran,
      'kartu_ulangan': kartuUlangan,
      'bacaan': bacaan,
      'tautan_pengetahuan': tautanPengetahuan,
      'catatan_makan': catatanMakan,
      'suasana_hati': suasanaHati,
    };
    for (final masuk in tabel.entries) {
      if (await _tabelAda(masuk.key)) continue;
      await m.createTable(masuk.value);
    }
  }

  /// Skema v10 (FR-150): kolom `uid` pada tabel lama + tabel sidik/tautan
  /// pendukung sinkron. Semua kolom baru nullable — tidak ada data yang diubah.
  Future<void> _buatTabelV10(Migrator m) async {
    for (final masuk in <String, TableInfo<Table, dynamic>>{
      'sinkron_sidik': sinkronSidik,
      'sinkron_tautan_belum': sinkronTautanBelum,
    }.entries) {
      if (await _tabelAda(masuk.key)) continue;
      await m.createTable(masuk.value);
    }
    final Map<String, TableInfo<Table, dynamic>> perluUid = {
      'riwayat_pembayaran': riwayatPembayaran,
      'pemasukan_bulanan': pemasukanBulanan,
      'kategori_transaksi': kategoriTransaksi,
      'transaksi': transaksi,
      'anggaran_bulanan': anggaranBulanan,
      'langganan': langganan,
      'aset': aset,
      'kewajiban': kewajiban,
      'nilai_aset_bulanan': nilaiAsetBulanan,
      'nilai_kewajiban_bulanan': nilaiKewajibanBulanan,
      'visi': visi,
      'area_hidup': areaHidup,
      'tujuan': tujuan,
      'proyek': proyek,
      'tugas': tugas,
      'kebiasaan': kebiasaan,
      'log_kebiasaan': logKebiasaan,
      'perawatan': perawatan,
      'ukuran_tubuh': ukuranTubuh,
      'aktivitas': aktivitas,
      'tidur': tidur,
      'catatan_air': catatanAir,
      'dokumen': dokumen,
      'pembayaran_kewajiban': pembayaranKewajiban,
      'pengeluaran_terencana': pengeluaranTerencana,
      'log_puasa': logPuasa,
      'log_quran': logQuran,
      'log_dzikir': logDzikir,
      'refleksi_muhasabah': refleksiMuhasabah,
      'catatan_kesehatan': catatanKesehatan,
    };
    for (final masuk in perluUid.entries) {
      if (await _kolomAda(masuk.key, 'uid')) continue;
      final kolomUid = masuk.value.$columns
          .firstWhere((k) => k.$name == 'uid');
      await m.addColumn(masuk.value, kolomUid);
    }
  }

  /// Skema v12 (FR-124…FR-127): aset fisik + riwayat perawatan berbiaya.
  ///
  /// Aman dijalankan ulang: tabel lewat `_tabelAda`, kolom lewat `_kolomAda`
  /// (PRAGMA). Sebagian basis data lama dibuat dari definisi tabel terbaru,
  /// jadi tanpa pemeriksaan itu `addColumn` bisa meledak `duplicate column
  /// name` dan update aplikasi di HP gagal.
  Future<void> _buatTabelV12(Migrator m) async {
    if (!await _tabelAda('riwayat_perawatan_aset')) {
      await m.createTable(riwayatPerawatanAset);
    }
    final Map<String, TableInfo<Table, dynamic>> tabelSasaran = {
      'aset': aset,
      'perawatan': perawatan,
    };
    const Map<String, List<String>> kolomPerlu = {
      'aset': [
        'nomor_seri',
        'tanggal_beli',
        'harga_beli_sen',
        'garansi_sampai',
        'masa_pakai_bulan',
        'lokasi',
      ],
      'perawatan': ['aset_id'],
    };
    for (final masuk in tabelSasaran.entries) {
      for (final namaKolom in kolomPerlu[masuk.key] ?? const <String>[]) {
        if (await _kolomAda(masuk.key, namaKolom)) continue;
        final kolom = masuk.value.$columns
            .firstWhere((k) => k.$name == namaKolom);
        await m.addColumn(masuk.value, kolom);
      }
    }
  }

  /// Skema v13 (FR-108/117/131): keluarga, profil kesehatan, catatan medis.
  ///
  /// Aman dijalankan ulang: tabel lewat `_tabelAda`, kolom lewat `_kolomAda`.
  Future<void> _buatTabelV13(Migrator m) async {
    final Map<String, TableInfo<Table, dynamic>> baru = {
      'anggota_keluarga': anggotaKeluarga,
      'profil_kesehatan': profilKesehatan,
      'catatan_medis': catatanMedis,
    };
    for (final masuk in baru.entries) {
      if (await _tabelAda(masuk.key)) continue;
      await m.createTable(masuk.value);
    }
    final Map<String, TableInfo<Table, dynamic>> tabelSasaran = {
      'tagihan': tagihan,
      'tugas': tugas,
    };
    const Map<String, List<String>> kolomPerlu = {
      'tagihan': ['pemilik_id', 'penanggung_jawab_id'],
      'tugas': ['pemilik_id', 'penanggung_jawab_id'],
    };
    for (final masuk in tabelSasaran.entries) {
      for (final namaKolom in kolomPerlu[masuk.key] ?? const <String>[]) {
        if (await _kolomAda(masuk.key, namaKolom)) continue;
        final kolom = masuk.value.$columns
            .firstWhere((k) => k.$name == namaKolom);
        await m.addColumn(masuk.value, kolom);
      }
    }
  }

  /// Cek keberadaan kolom (PRAGMA) — dipakai migrasi agar aman dijalankan ulang.
  Future<bool> _kolomAda(String namaTabel, String namaKolom) async {
    final hasil = await customSelect('PRAGMA table_info($namaTabel)').get();
    return hasil.any((b) => b.read<String>('name') == namaKolom);
  }

  /// Cek keberadaan tabel (dipakai migrasi agar aman dijalankan ulang).
  Future<bool> _tabelAda(String nama) async {
    final baris = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(nama)],
    ).get();
    return baris.isNotEmpty;
  }

  /// Skema v7 (FR-51/94/96/105/109): lima tabel baru — tanpa menyentuh tabel
  /// lama, jadi pemutakhiran aplikasi tidak mengubah data pengguna.
  Future<void> _buatTabelV7(Migrator m) async {
    final Map<String, TableInfo<Table, dynamic>> tabel = {
      'catatan_kesehatan': catatanKesehatan,
      'janji_kesehatan': janjiKesehatan,
      'kas_informal': kasInformal,
      'hafalan': hafalan,
      'zakat_sedekah': zakatSedekah,
    };
    for (final masuk in tabel.entries) {
      if (await _tabelAda(masuk.key)) continue;
      await m.createTable(masuk.value);
    }
  }

  Future<void> _buatTabelV4(Migrator m) async {
    await m.createTable(tujuan);
    await m.createTable(proyek);
    await m.createTable(tugas);
    await m.createTable(kebiasaan);
    await m.createTable(logKebiasaan);
    await m.createTable(perawatan);
    await m.createTable(ukuranTubuh);
    await m.createTable(aktivitas);
    await m.createTable(tidur);
    await m.createTable(obat);
    await m.createTable(jadwalObat);
    await m.createTable(minumObat);
    await m.createTable(catatanAir);
    await m.createTable(dokumen);
    await m.createTable(auditLog);
    await m.createTable(notifikasiRiwayat);
    await m.createTable(tundaPengingat);
    await m.createTable(pembayaranKewajiban);
    await m.createTable(pengeluaranTerencana);
    await m.createTable(logPuasa);
    await m.createTable(logQuran);
    await m.createTable(logDzikir);
    await m.createTable(refleksiMuhasabah);
  }

  /// Skema v4: indeks unik & indeks pencarian.
  ///
  /// Gaya sama dengan v3 (SQL, bukan anotasi tabel) supaya jaminan tetap ada
  /// walau `database.g.dart` diregenerasi. Indeks unik pada kolom nullable
  /// tetap mengizinkan banyak NULL di SQLite (mis. tugas tanpa proyek).
  Future<void> _pasangIndeksUnikV4() async {
    // Aksi & tujuan
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_tujuan_id '
        'ON tujuan(id_tujuan)');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_proyek_id '
        'ON proyek(id_proyek)');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_tugas_id '
        'ON tugas(id_tugas)');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_kebiasaan_id '
        'ON kebiasaan(id_kebiasaan)');
    await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_log_kebiasaan_hari '
        'ON log_kebiasaan(kebiasaan_id, tanggal)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_tugas_jatuh_tempo ON tugas(jatuh_tempo)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_perawatan_berikutnya '
        'ON perawatan(berikutnya)');
    // Kesehatan
    await customStatement('CREATE INDEX IF NOT EXISTS idx_ukuran_jenis_tanggal '
        'ON ukuran_tubuh(jenis, tanggal)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_aktivitas_tanggal ON aktivitas(tanggal)');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_tidur_tanggal '
        'ON tidur(tanggal)');
    await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_minum_obat_rencana '
        'ON minum_obat(obat_id, waktu_rencana)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_catatan_air_waktu '
        'ON catatan_air(waktu)');
    // Dokumen
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_dokumen_id '
        'ON dokumen(id_dokumen)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_dokumen_berlaku ON dokumen(berlaku_sampai)');
    // Platform
    await customStatement('CREATE INDEX IF NOT EXISTS idx_audit_waktu '
        'ON audit_log(waktu)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_notif_riwayat_waktu '
        'ON notifikasi_riwayat(waktu)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_notif_riwayat_status ON notifikasi_riwayat(status)');
    await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_tunda_pengingat_id '
        'ON tunda_pengingat(pengingat_id)');
    // Uang lanjutan
    await customStatement('CREATE INDEX IF NOT EXISTS idx_bayar_kewajiban '
        'ON pembayaran_kewajiban(kewajiban_id, tanggal)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_rencana_tanggal '
        'ON pengeluaran_terencana(tanggal)');
    // Ibadah lanjutan
    await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_log_puasa_hari_jenis '
        'ON log_puasa(tanggal, jenis)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_log_quran_tanggal '
        'ON log_quran(tanggal)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_log_dzikir_tanggal '
        'ON log_dzikir(tanggal)');
    await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_refleksi_tanggal '
        'ON refleksi_muhasabah(tanggal)');
  }

  /// Template perawatan berkala bawaan (FR-83).
  ///
  /// Hanya diisi bila tabel masih KOSONG: pengguna yang sudah menyusun daftar
  /// perawatannya sendiri tidak boleh mendapat tambahan tak diminta saat
  /// pembaruan aplikasi. Tanggal `berikutnya` = hari ini + interval, sehingga
  /// tidak ada pengingat yang langsung berbunyi pada hari pemasangan.
  Future<void> _seedPerawatanV4() async {
    final ada = await (selectOnly(perawatan)..addColumns([perawatan.id])).get();
    if (ada.isNotEmpty) return;
    final hariIni = waktuSekarang();
    final awalHari = DateTime(hariIni.year, hariIni.month, hariIni.day);
    // (templateKode, nama, kategori, intervalHari)
    const template = [
      ('oli_mesin', 'Servis & ganti oli kendaraan', 'kendaraan', 180),
      ('servis_ac', 'Servis AC', 'rumah', 180),
      ('filter_air', 'Ganti filter air', 'rumah', 90),
      ('pajak_kendaraan', 'Bayar pajak kendaraan', 'dokumen', 365),
      ('cadangan_data', 'Periksa cadangan data', 'perangkat', 30),
      ('periksa_gigi', 'Periksa gigi', 'keluarga', 180),
    ];
    for (final (i, t) in template.indexed) {
      await into(perawatan).insert(PerawatanCompanion.insert(
        nama: t.$2,
        kategori: Value(t.$3),
        intervalHari: Value(t.$4),
        berikutnya: awalHari.add(Duration(days: t.$4)),
        templateKode: Value(t.$1),
        leadHari: const Value('7,1'),
        urutan: Value(i),
      ));
    }
  }

  static QueryExecutor _buka() =>
      driftDatabase(name: 'personal_life_os', native: const DriftNativeOptions());
}
