/// Uji FR-107 (perkiraan obat habis) & FR-109 (janji dokter & kontrol).
///
/// Yang dibuktikan:
///   * dosis per hari dihitung dari jumlah per minum × jam minum aktif,
///   * perkiraan habis & sisa hari benar; sisa belum diisi → tidak dihitung,
///   * pengingat hanya pada H-5, H-1, dan saat habis (bukan tiap hari),
///   * sumber pengingat obat membaca BASIS DATA nyata (sisa 20, 2 tablet × 2
///     jadwal = 4/hari → H-5 → satu pengingat),
///   * layar obat: baris "sisa & perkiraan habis" tampil; mengisi sisa
///     menyimpannya ke kolom baru,
///   * janji: pengingat 7 hari, 1 hari, dan 2 jam sebelum jadwal,
///   * janji yang sudah selesai / masih > 30 hari tidak diingatkan,
///   * layar janji: janji tersimpan, ditandai selesai, dan bisa dihapus.
library;

import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/laporan/janji.dart';
import 'package:personal_life_os/core/laporan/obat_habis.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/features/kesehatan/janji_screen.dart';
import 'package:personal_life_os/features/kesehatan/obat_screen.dart';
import 'package:personal_life_os/features/kesehatan/pengingat_janji.dart';
import 'package:personal_life_os/features/kesehatan/pengingat_obat_habis.dart';

late AppDatabase db;
final sekarang = DateTime(2026, 9, 20, 9);

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  /// Layar uji bawaan hanya 800×600 — beberapa tombol (simpan janji, isi sisa)
  /// ada di bawah lipatan, jadi permukaan uji diperbesar dulu.
  Future<void> layarTinggi(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(1200, 2600));
    addTearDown(() => t.binding.setSurfaceSize(null));
  }

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  group('FR-107 logika', () {
    test('dosis per hari & sisa hari', () {
      expect(dosisPerHari(2, 3), 6);
      expect(dosisPerHari(0, 3), 0);
      expect(dosisPerHari(2, 0), 0);
      expect(sisaHari(sisa: 20, dosisPerHari: 4), 5);
      expect(sisaHari(sisa: 21, dosisPerHari: 4), 5);
      expect(sisaHari(sisa: 3, dosisPerHari: 4), 0);
      expect(sisaHari(sisa: null, dosisPerHari: 4), isNull);
      expect(sisaHari(sisa: 20, dosisPerHari: 0), isNull);
    });

    test('perkiraan tanggal habis', () {
      final habis =
          perkiraanHabis(sisa: 20, dosisPerHari: 4, dari: DateTime(2026, 9, 20, 9));
      expect(habis, DateTime(2026, 9, 25));
      expect(perkiraanHabis(sisa: null, dosisPerHari: 4, dari: sekarang), isNull);
    });

    test('kode keadaan sisa', () {
      expect(kodeSisa(sisa: null, dosisPerHari: 4), 'belum_diisi');
      expect(kodeSisa(sisa: 10, dosisPerHari: 0), 'tanpa_jadwal');
      expect(kodeSisa(sisa: 0, dosisPerHari: 4), 'habis');
      expect(kodeSisa(sisa: 4, dosisPerHari: 4), 'kritis');
      expect(kodeSisa(sisa: 20, dosisPerHari: 4), 'peringatan');
      expect(kodeSisa(sisa: 40, dosisPerHari: 4), 'aman');
    });

    test('hanya H-5 & H-1 (plus habis) yang diingatkan', () {
      expect(perluDiingatkan(5), isTrue);
      expect(perluDiingatkan(1), isTrue);
      expect(perluDiingatkan(0), isTrue);
      expect(perluDiingatkan(-2), isTrue);
      for (final hari in [2, 3, 4, 6, 10]) {
        expect(perluDiingatkan(hari), isFalse, reason: 'H-$hari tidak diingatkan');
      }
    });

    test('kalimat sisa menyebut angka, tanpa kata menghakimi', () {
      final teks = kalimatSisa(
        namaObat: 'Amlodipine',
        sisa: 20,
        dosisPerHari: 4,
        satuan: 'tablet',
        sekarang: sekarang,
      );
      expect(teks, contains('20 tablet'));
      expect(teks, contains('5 hari'));
      expect(teks, contains('25 Sep 2026'));
      for (final kata in ['gagal', 'hukuman', 'malas']) {
        expect(teks.toLowerCase(), isNot(contains(kata)));
      }
      expect(
        kalimatSisa(
            namaObat: 'X',
            sisa: null,
            dosisPerHari: 4,
            satuan: 'tablet',
            sekarang: sekarang),
        contains('belum dicatat'),
      );
    });

    test('pengingat obat: hanya saat ambangnya tercapai', () {
      final daftar = [
        const BarisSisaObat(
            obatId: 1, nama: 'A', sisa: 20, dosisPerHari: 4, satuan: 'tablet'),
        const BarisSisaObat(
            obatId: 2, nama: 'B', sisa: 12, dosisPerHari: 4, satuan: 'tablet'),
        const BarisSisaObat(
            obatId: 3, nama: 'C', sisa: null, dosisPerHari: 4, satuan: 'tablet'),
        const BarisSisaObat(
            obatId: 4, nama: 'D', sisa: 4, dosisPerHari: 4, satuan: 'tablet'),
      ];
      final hasil = pengingatObatUntuk(daftar, sekarang);
      expect(hasil, hasLength(2)); // A (H-5) & D (H-1)
      expect(hasil.map((p) => p.judul).join(' | '), contains('A'));
      expect(hasil.map((p) => p.judul).join(' | '), contains('D'));
      expect(hasil.every((p) => p.tagihanId == 0), isTrue);
      // Judul untuk D (≤1 hari) menyebut "hampir habis".
      expect(
        hasil.firstWhere((p) => p.judul.contains('D')).judul,
        contains('hampir habis'),
      );
    });
  });

  group('FR-107 sumber pengingat (basis data nyata)', () {
    test('obat aktif dengan 2 jadwal & sisa 20 → satu pengingat H-5', () async {
      final obatId = await db.into(db.obat).insert(ObatCompanion.insert(
            nama: 'Amlodipine',
            jumlahPerMinum: const Value(2),
            satuan: const Value('tablet'),
            sisa: const Value(20),
          ));
      for (final jam in ['07:00', '19:00']) {
        await db.into(db.jadwalObat).insert(JadwalObatCompanion.insert(
              obatId: obatId,
              jam: jam,
            ));
      }

      final sumber = SumberPengingatObat(
        pembukaBasisData: () => db,
        tutupBasisData: false,
      );
      final hasil = await sumber.pengingatTambahan(sekarang);
      expect(hasil, hasLength(1));
      expect(hasil.first.judul, contains('Amlodipine'));
      expect(hasil.first.isi, contains('5 hari'));
      expect(hasil.first.waktu, DateTime(2026, 9, 20, 8));
    });

    test('obat tidak aktif tidak diingatkan', () async {
      final obatId = await db.into(db.obat).insert(ObatCompanion.insert(
            nama: 'Vitamin usang',
            jumlahPerMinum: const Value(1),
            sisa: const Value(5),
            aktif: const Value(false),
          ));
      await db.into(db.jadwalObat).insert(
          JadwalObatCompanion.insert(obatId: obatId, jam: '07:00'));
      final sumber = SumberPengingatObat(
        pembukaBasisData: () => db,
        tutupBasisData: false,
      );
      expect(await sumber.pengingatTambahan(sekarang), isEmpty);
    });
  });

  group('FR-109 logika janji', () {
    test('lead hari dibaca & dibersihkan', () {
      expect(bacaLeadHari('7,1'), [7, 1]);
      expect(bacaLeadHari('30 , 7 ,3'), [30, 7, 3]);
      expect(bacaLeadHari('7,7,abc,400,-2'), [7]);
      expect(bacaLeadHari(''), isEmpty);
    });

    test('jadwal pengingat: 7 hari, 1 hari & 2 jam', () {
      // Janji 10 Okt 2026 pukul 14:00.
      final waktuJanji = DateTime(2026, 10, 10, 14);
      final hasil = waktuPengingatJanji(waktuJanji,
          leadHari: '7,1', duaJam: true, jamPengingat: '08:00');
      expect(hasil, hasLength(3));
      expect(hasil[0], DateTime(2026, 10, 3, 8));
      expect(hasil[1], DateTime(2026, 10, 9, 8));
      expect(hasil[2], DateTime(2026, 10, 10, 12));
    });

    test('pengingat 2 jam bisa dimatikan; jam pengingat bisa diubah', () {
      final waktuJanji = DateTime(2026, 10, 10, 14);
      final tanpaDuaJam = waktuPengingatJanji(waktuJanji,
          leadHari: '1', duaJam: false, jamPengingat: '06:30');
      expect(tanpaDuaJam, hasLength(1));
      expect(tanpaDuaJam.first, DateTime(2026, 10, 9, 6, 30));
    });

    test('pengingat janji: belum selesai & dekat → dibuat; selesai/lama → tidak',
        () async {
      Future<int> tambah(DateTime waktu, {bool selesai = false}) =>
          db.into(db.janjiKesehatan).insert(JanjiKesehatanCompanion.insert(
                judul: 'Kontrol',
                waktu: waktu,
                selesai: Value(selesai),
              ));

      await tambah(DateTime(2026, 9, 25, 10)); // 5 hari lagi → diingatkan
      await tambah(DateTime(2026, 9, 26, 10), selesai: true); // selesai → tidak
      await tambah(DateTime(2027, 3, 1, 10)); // jauh → tidak

      final sumber = SumberPengingatJanji(
        pembukaBasisData: () => db,
        tutupBasisData: false,
      );
      final hasil = await sumber.pengingatTambahan(sekarang);
      expect(hasil, hasLength(2)); // H-1 & H-2jam untuk janji 25 Sep
      expect(hasil.first.judul, contains('Kontrol'));
      expect(hasil.every((p) => p.tagihanId == 0), isTrue);
      expect(hasil.every((p) => p.waktu.isAfter(sekarang)), isTrue);
    });

    test('kalimat pengingat menyebut jenis, jam & tempat', () {
      final teks = kalimatPengingatJanji(
        judul: 'Kontrol gula darah',
        jenis: 'lab',
        waktuJanji: DateTime(2026, 9, 25, 10),
        waktuPengingat: DateTime(2026, 9, 24, 8),
        tempat: 'Lab Sehat',
      );
      expect(teks, contains('Besok'));
      expect(teks, contains('Kontrol gula darah'));
      expect(teks, contains('10:00'));
      expect(teks, contains('Lab Sehat'));
      expect(labelJenisJanji('lab'), 'Tes laboratorium');
    });
  });

  group('layar obat (FR-107)', () {
    testWidgets('baris sisa tampil & mengisi sisa menyimpannya', (t) async {
      await layarTinggi(t);
      final obatId = await db.into(db.obat).insert(ObatCompanion.insert(
            nama: 'Amlodipine',
            jumlahPerMinum: const Value(2),
            satuan: const Value('tablet'),
            sisa: const Value(20),
          ));
      await db.into(db.jadwalObat).insert(
          JadwalObatCompanion.insert(obatId: obatId, jam: '07:00'));

      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: ObatScreen(jamSekarang: () => sekarang),
        ),
      ));
      await t.pumpAndSettle();

      final teksSisa =
          t.widget<Text>(find.byKey(Key('sisa_obat_$obatId'))).data ?? '';
      expect(teksSisa, contains('20 tablet'));
      expect(teksSisa, contains('10 hari')); // 20 ÷ (2 × 1 jadwal)

      await t.tap(find.byKey(Key('isi_sisa_$obatId')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('input_sisa_obat')), '8');
      await t.tap(find.byKey(const Key('simpan_sisa_obat')));
      await t.pumpAndSettle();

      final tersimpan = await (db.select(db.obat)
            ..where((t) => t.id.equals(obatId)))
          .getSingle();
      expect(tersimpan.sisa, 8);
      expect(tersimpan.sisaDiperbaruiPada, isNotNull);
    });
  });

  group('layar janji (FR-109)', () {
    testWidgets('simpan janji, tandai selesai & hapus', (t) async {
      await layarTinggi(t);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: JanjiScreen(db: db, sekarang: sekarang),
        ),
      ));
      await t.pumpAndSettle();

      await t.enterText(
          find.byKey(const Key('isi_judul_janji')), 'Kontrol tekanan darah');
      await t.tap(find.byKey(const Key('pilih_jenis_janji_kontrol')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('isi_tempat_janji')), 'Klinik Sehat');
      await t.tap(find.byKey(const Key('simpan_janji')));
      await t.pumpAndSettle();

      final daftar = await db.select(db.janjiKesehatan).get();
      expect(daftar, hasLength(1));
      expect(daftar.first.judul, 'Kontrol tekanan darah');
      expect(daftar.first.jenis, 'kontrol');
      expect(daftar.first.tempat, 'Klinik Sehat');
      expect(daftar.first.selesai, isFalse);
      // Bawaan: besok pukul 09:00 (bukan masa lalu).
      expect(daftar.first.waktu.isAfter(sekarang), isTrue);

      final id = daftar.first.id;
      expect(find.byKey(Key('janji_$id')), findsOneWidget);

      await t.tap(find.byKey(Key('selesai_janji_$id')));
      await t.pumpAndSettle();
      expect(
        (await db.select(db.janjiKesehatan).getSingle()).selesai,
        isTrue,
      );

      await t.tap(find.byKey(Key('hapus_janji_$id')));
      await t.pumpAndSettle();
      expect(await db.select(db.janjiKesehatan).get(), isEmpty);
    });

    testWidgets('judul kosong → diberi tahu, tidak tersimpan', (t) async {
      await layarTinggi(t);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: JanjiScreen(db: db, sekarang: sekarang),
        ),
      ));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('simpan_janji')));
      await t.pumpAndSettle();
      expect(find.textContaining('Isi judul'), findsOneWidget);
      expect(await db.select(db.janjiKesehatan).get(), isEmpty);
    });
  });
}
