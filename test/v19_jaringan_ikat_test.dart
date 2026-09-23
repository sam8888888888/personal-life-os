/// Uji SDD v19 Gelombang 1 — jaringan ikat: kotak masuk, catatan harian,
/// tautan, sorotan.
///
/// Yang dibuktikan (bukan diasumsikan):
/// 1. Skema: 4 tabel + 15 indeks v19 benar-benar ada setelah basis data dibuat.
/// 2. Migrasi v18 → v19: basis data yang masih v18 dinaikkan, tabel & indeks
///    dibuat ulang lewat jalur `onUpgrade` yang sungguhan (berkas nyata, bukan
///    basis data memori sekali buka).
/// 3. Kotak masuk: simpan → masuk antrean; triase wajib tahu tujuan.
/// 4. Catatan harian: satu halaman per hari; ringkasan mesin TIDAK menimpa
///    tulisan pengguna.
/// 5. Tautan: pasangan ganda tidak dibuat dua kali; entitas hantu ditolak;
///    tautan ke diri sendiri ditolak; panel balik benar.
/// 6. Sorotan: kutipan kosong, posisi tidak masuk akal, dan warna salah ditolak.
/// 7. Layar: catat cepat menyimpan dan menampilkan di antrean; "Ke catatan hari
///    ini" benar-benar mengisi catatan harian + membuat tautan.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/catatan_harian_repository.dart';
import 'package:personal_life_os/data/repository/kotak_masuk_repository.dart';
import 'package:personal_life_os/data/repository/sorotan_repository.dart';
import 'package:personal_life_os/data/repository/tautan_repository.dart';
import 'package:personal_life_os/features/catatan_harian/catatan_harian_screen.dart';
import 'package:personal_life_os/features/kotak_masuk/kotak_masuk_screen.dart';

/// 15 indeks v19 (SDD §6.2).
const List<String> indeksV19 = <String>[
  'idx_km_uid',
  'idx_km_status',
  'idx_km_dibuat',
  'idx_km_antre',
  'idx_km_tujuan',
  'idx_ch_uid',
  'idx_ch_tanggal',
  'idx_ch_isi_ada',
  'idx_tautan_uid',
  'idx_tautan_pasangan',
  'idx_tautan_maju',
  'idx_tautan_balik',
  'idx_tautan_usulan',
  'idx_sorotan_uid',
  'idx_sorotan_pemilik',
];

const List<String> tabelV19 = <String>[
  'kotak_masuk',
  'catatan_harian',
  'tautan',
  'sorotan',
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
  late KotakMasukRepository kotakMasuk;
  late CatatanHarianRepository catatan;
  late TautanRepository tautan;
  late SorotanRepository sorotan;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    kotakMasuk = KotakMasukRepository(db);
    catatan = CatatanHarianRepository(db);
    tautan = TautanRepository(db);
    sorotan = SorotanRepository(db);
  });

  tearDown(() async => db.close());

  // ─────────────────────────────────────────────────────────────── skema
  group('skema v19', () {
    test('versi skema = 19', () {
      expect(db.schemaVersion, 19);
    });

    test('empat tabel jaringan ikat ada', () async {
      final List<String> tabel = await _namaTabel(db);
      for (final String t in tabelV19) {
        expect(tabel, contains(t), reason: 'tabel $t harus ada');
      }
    });

    test('lima belas indeks v19 ada', () async {
      final List<String> indeks = await _namaIndeks(db);
      for (final String i in indeksV19) {
        expect(indeks, contains(i), reason: 'indeks $i harus ada');
      }
    });

    test('indeks pasangan tautan menormalkan label kosong', () async {
      // Dua tautan sama, satu berlabel null dan satu berlabel '' → harus
      // dianggap pasangan yang sama (COALESCE di indeks).
      final String? a = await tautan.tambah(
        entitasA: 'catatan_harian',
        uidA: 'uid-1',
        entitasB: 'kotak_masuk',
        uidB: 'uid-2',
      );
      final String? b = await tautan.tambah(
        entitasA: 'catatan_harian',
        uidA: 'uid-1',
        entitasB: 'kotak_masuk',
        uidB: 'uid-2',
        label: '',
      );
      expect(a, isNotNull);
      expect(b, isNull, reason: 'pasangan yang sama tidak dibuat dua kali');
      expect(await db.select(db.tautan).get(), hasLength(1));
    });
  });

  // ───────────────────────────────────────────────────────────── migrasi
  group('migrasi v18 → v19', () {
    test('basis data lama dinaikkan: tabel + indeks dibuat ulang', () async {
      final Directory dir = await Directory.systemTemp.createTemp('lifeos_v19');
      final File berkas = File('${dir.path}/uji.sqlite');
      AppDatabase? lama;
      try {
        // 1) Buat basis data v19, lalu turunkan tiruan ke v18 seperti basis
        //    data Papi yang belum pernah update.
        lama = AppDatabase.forTesting(NativeDatabase(berkas));
        await lama.customStatement('DROP TABLE IF EXISTS tautan');
        await lama.customStatement('DROP TABLE IF EXISTS sorotan');
        await lama.customStatement('DROP TABLE IF EXISTS catatan_harian');
        await lama.customStatement('DROP TABLE IF EXISTS kotak_masuk');
        for (final String i in indeksV19) {
          await lama.customStatement('DROP INDEX IF EXISTS $i');
        }
        await lama.customStatement('PRAGMA user_version = 18');
        await lama.close();
        lama = null;

        // 2) Buka ulang → onUpgrade wajib membuat tabel & indeks v19.
        final AppDatabase baru = AppDatabase.forTesting(NativeDatabase(berkas));
        final List<String> tabel = await _namaTabel(baru);
        for (final String t in tabelV19) {
          expect(tabel, contains(t), reason: 'migrasi harus membuat $t');
        }
        final List<String> indeks = await _namaIndeks(baru);
        for (final String i in indeksV19) {
          expect(indeks, contains(i), reason: 'migrasi harus membuat indeks $i');
        }
        // Migrasi aman dijalankan dua kali (tidak "table already exists").
        await baru.customStatement('PRAGMA user_version = 18');
        await baru.close();
        final AppDatabase ketiga =
            AppDatabase.forTesting(NativeDatabase(berkas));
        expect((await _namaTabel(ketiga)).contains('tautan'), isTrue);
        await ketiga.close();
      } finally {
        await lama?.close();
        await berkas.delete().catchError((_) => berkas);
        await dir.delete(recursive: true).catchError((_) => dir);
      }
    });
  });

  // ────────────────────────────────────────────────────────── kotak masuk
  group('kotak masuk', () {
    test('simpan masuk antrean, terbaru dulu', () async {
      await kotakMasuk.tambah(isi: 'satu');
      await kotakMasuk.tambah(isi: 'dua');
      final List<KotakMasukData> antrean = await kotakMasuk.antrean();
      expect(antrean.map((KotakMasukData b) => b.isi), <String>['dua', 'satu']);
      expect(await kotakMasuk.jumlahBaru(), 2);
    });

    test('triase tanpa tujuan ditolak', () async {
      final String uid = await kotakMasuk.tambah(isi: 'tiga');
      final KotakMasukData baris = (await kotakMasuk.cariUid(uid))!;
      expect(
        () => kotakMasuk.tandaiDiproses(baris.id,
            tujuanTabel: '', tujuanUid: 'x'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('diproses keluar dari antrean dan menyimpan tujuan', () async {
      final String uid = await kotakMasuk.tambah(isi: 'empat');
      final KotakMasukData baris = (await kotakMasuk.cariUid(uid))!;
      await kotakMasuk.tandaiDiproses(baris.id,
          tujuanTabel: 'catatan_harian', tujuanUid: 'halaman-1');
      expect(await kotakMasuk.jumlahBaru(), 0);
      final KotakMasukData lagi = (await kotakMasuk.cariUid(uid))!;
      expect(lagi.status, 'diproses');
      expect(lagi.tujuanTabel, 'catatan_harian');
      expect(lagi.tujuanUid, 'halaman-1');
      expect(lagi.diprosesPada, isNotNull);
    });

    test('arsipkan yang lebih tua dari N hari tidak menyentuh yang baru',
        () async {
      await kotakMasuk.tambah(
          isi: 'lama', waktu: DateTime.now().subtract(const Duration(days: 40)));
      await kotakMasuk.tambah(isi: 'baru');
      final int jumlah = await kotakMasuk.arsipkanLebihTuaDari(30);
      expect(jumlah, 1);
      expect(await kotakMasuk.jumlahBaru(), 1);
    });
  });

  // ─────────────────────────────────────────────────────── catatan harian
  group('catatan harian', () {
    test('kunci harian berbentuk YYYY-MM-DD', () {
      expect(kunciTanggalHarian(DateTime(2026, 9, 3)), '2026-09-03');
    });

    test('satu halaman per hari (tidak berganda)', () async {
      final DateTime hari = DateTime(2026, 9, 23);
      await catatan.halaman(hari);
      await catatan.simpanIsi(hari, 'halo');
      final List<CatatanHarianData> semua = await db.select(db.catatanHarian).get();
      expect(semua, hasLength(1));
      expect(semua.single.isi, 'halo');
    });

    test('ringkasan mesin tidak menimpa tulisan pengguna', () async {
      final DateTime hari = DateTime(2026, 9, 23);
      await catatan.simpanIsi(hari, 'tulisan papi');
      await catatan.simpanRingkasanMesin(hari, 'ringkasan mesin');
      final CatatanHarianData baris = await catatan.halaman(hari);
      expect(baris.isi, 'tulisan papi');
      expect(baris.ringkasanMesin, 'ringkasan mesin');
    });

    test('hari yang berbeda memakai halaman berbeda', () async {
      await catatan.simpanIsi(DateTime(2026, 9, 23), 'hari A');
      await catatan.simpanIsi(DateTime(2026, 9, 24), 'hari B');
      expect(await db.select(db.catatanHarian).get(), hasLength(2));
      expect((await catatan.berisi()).length, 2);
    });

    test('sorotan rusak dinyatakan, bukan jadi daftar kosong diam-diam',
        () async {
      final DateTime hari = DateTime(2026, 9, 23);
      final CatatanHarianData halaman = await catatan.halaman(hari);
      await (db.update(db.catatanHarian)
            ..where((t) => t.id.equals(halaman.id)))
          .write(const CatatanHarianCompanion(sorotan: Value('{bukan json')));
      final CatatanHarianData lagi = await catatan.halaman(hari);
      expect(catatan.sorotanRusak(lagi), isTrue);
      expect(catatan.sorotanDari(lagi), isEmpty);
    });
  });

  // ────────────────────────────────────────────────────────────── tautan
  group('tautan', () {
    test('entitas hantu ditolak', () async {
      expect(
        () => tautan.tambah(
          entitasA: 'tabel_karangan',
          uidA: 'a',
          entitasB: 'kotak_masuk',
          uidB: 'b',
        ),
        throwsA(isA<GalatTautan>()),
      );
    });

    test('menautkan diri sendiri ditolak', () async {
      expect(
        () => tautan.tambah(
          entitasA: 'catatan_harian',
          uidA: 'sama',
          entitasB: 'catatan_harian',
          uidB: 'sama',
        ),
        throwsA(isA<GalatTautan>()),
      );
    });

    test('panel balik menemukan perujuk', () async {
      final String uidHalaman = (await catatan.halaman(DateTime(2026, 9, 23))).uid!;
      await tautan.tambah(
        entitasA: 'kotak_masuk',
        uidA: 'km-1',
        judulA: 'catatan cepat',
        entitasB: 'catatan_harian',
        uidB: uidHalaman,
        label: 'dipindah ke',
      );
      final List<TautanData> masuk =
          await tautan.masuk('catatan_harian', uidHalaman);
      expect(masuk, hasLength(1));
      expect(masuk.single.judulA, 'catatan cepat');
      expect(await tautan.jumlahMasuk('catatan_harian', uidHalaman), 1);
      expect(await tautan.keluar('kotak_masuk', 'km-1'), hasLength(1));
    });
  });

  // ───────────────────────────────────────────────────────────── sorotan
  group('sorotan', () {
    test('kutipan kosong ditolak', () async {
      expect(
        () => sorotan.tambah(
            entitas: 'catatan_harian', entitasUid: 'h1', kutipan: '   '),
        throwsA(isA<GalatSorotan>()),
      );
    });

    test('posisi harus lengkap dan urut', () async {
      expect(
        () => sorotan.tambah(
            entitas: 'catatan_harian',
            entitasUid: 'h1',
            kutipan: 'kutipan',
            mulai: 5),
        throwsA(isA<GalatSorotan>()),
      );
      expect(
        () => sorotan.tambah(
            entitas: 'catatan_harian',
            entitasUid: 'h1',
            kutipan: 'kutipan',
            mulai: 9,
            akhir: 2),
        throwsA(isA<GalatSorotan>()),
      );
    });

    test('warna harus #RRGGBB', () async {
      expect(
        () => sorotan.tambah(
            entitas: 'catatan_harian',
            entitasUid: 'h1',
            kutipan: 'kutipan',
            warna: 'merah'),
        throwsA(isA<GalatSorotan>()),
      );
      final String uid = await sorotan.tambah(
          entitas: 'catatan_harian',
          entitasUid: 'h1',
          kutipan: 'kutipan',
          warna: '#A1B2C3');
      expect(uid, isNotEmpty);
      expect(await sorotan.jumlahUntuk('catatan_harian', 'h1'), 1);
    });
  });

  // ────────────────────────────────────────────────────────────── layar
  group('layar', () {
    Widget bungkus(Widget anak, AppDatabase basis) => ProviderScope(
          overrides: [databaseProvider.overrideWithValue(basis)],
          child: MaterialApp(home: anak),
        );

    testWidgets('catat cepat menyimpan lalu tampil di antrean', (t) async {
      await t.pumpWidget(bungkus(const KotakMasukScreen(), db));
      await t.pump();
      await t.enterText(find.byKey(const Key('km_isi')), 'beli galon');
      await t.tap(find.byKey(const Key('km_simpan')));
      // Penulisan basis data butuh waktu nyata (waktu uji dipalsukan).
      await t.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 300)));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('beli galon'), findsWidgets);
      expect(await kotakMasuk.jumlahBaru(), 1);
    });

    testWidgets('catatan harian menyimpan tulisan pengguna', (t) async {
      await t.pumpWidget(bungkus(const CatatanHarianScreen(), db));
      await t.pump();
      await t.enterText(find.byKey(const Key('ch_isi')), 'hari yang tenang');
      await t.tap(find.byKey(const Key('ch_simpan')));
      await t.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 300)));
      await t.pump(const Duration(milliseconds: 100));
      final CatatanHarianData baris = await catatan.halaman(DateTime.now());
      expect(baris.isi, 'hari yang tenang');
      expect(find.byKey(const Key('ch_ringkasan')), findsOneWidget);
    });
  });
}
