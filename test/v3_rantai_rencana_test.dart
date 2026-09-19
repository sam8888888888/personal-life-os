/// Uji FR-82 — Life Planning Engine: rantai Visi → Area → Tujuan → Proyek →
/// Tugas, dan aturan "menghapus bagian atas tidak menghapus bagian bawah".
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/visi_repository.dart';
import 'package:personal_life_os/features/aksi/visi_screen.dart';

late AppDatabase db;
late VisiRepository repo;

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = VisiRepository(db);
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() async => db.close());

  /// Bangun rantai lengkap dan kembalikan id-nya.
  Future<
      ({
        int visi,
        int area,
        int tujuan,
        int proyek,
        int tugas,
      })> rantaiLengkap() async {
    final v = await repo.simpanVisi(nama: 'Hidup tenang');
    final a = await repo.simpanArea(nama: 'Keuangan', visiId: v.id);
    final t = await db.into(db.tujuan).insertReturning(TujuanCompanion.insert(
          idTujuan: 'tuj_uji',
          nama: 'Bebas utang',
          areaId: Value(a.id),
        ));
    final p = await db.into(db.proyek).insertReturning(ProyekCompanion.insert(
          idProyek: 'prj_uji',
          nama: 'Lunasi kartu',
          tujuanId: Value(t.id),
        ));
    final g = await db.into(db.tugas).insertReturning(TugasCompanion.insert(
          idTugas: 'tgs_uji',
          nama: 'Bayar 1 juta',
          proyekId: Value(p.id),
        ));
    return (
      visi: v.id,
      area: a.id,
      tujuan: t.id,
      proyek: p.id,
      tugas: g.id,
    );
  }

  group('FR-82 rantai rencana', () {
    test('tugas bisa ditelusuri ke atas sampai satu visi', () async {
      final r = await rantaiLengkap();

      final rantai = await repo.rantaiTugas(r.tugas);

      expect(rantai.sampaiVisi, isTrue);
      expect(rantai.kalimat,
          'Hidup tenang → Keuangan → Bebas utang → Lunasi kartu → Bayar 1 juta');
      expect(rantai.bagian, hasLength(5));
    });

    test('tujuan tanpa area tetap jujur: rantai berhenti di tujuan', () async {
      final t = await db.into(db.tujuan).insertReturning(TujuanCompanion.insert(
            idTujuan: 'tuj_lepas',
            nama: 'Belajar tenor',
          ));

      final rantai = await repo.rantaiTujuan(t.id);

      expect(rantai.sampaiVisi, isFalse);
      expect(rantai.kalimat, 'Belajar tenor');
    });

    test('menghapus visi hanya melepas area — isi di bawah tetap utuh',
        () async {
      final r = await rantaiLengkap();

      final dilepas = await repo.hapusVisi(r.visi);

      expect(dilepas, 1);
      final area = await repo.ambilAreaSatu(r.area);
      expect(area, isNotNull, reason: 'area tidak boleh ikut terhapus');
      expect(area!.visiId, isNull, reason: 'area hanya dilepas dari visi');
      // Tujuan, proyek, dan tugas tidak tersentuh.
      expect((await db.select(db.tujuan).get()), hasLength(1));
      expect((await db.select(db.proyek).get()), hasLength(1));
      expect((await db.select(db.tugas).get()), hasLength(1));
      // Rantai kini berhenti di area (visi sudah tidak ada).
      final rantai = await repo.rantaiTugas(r.tugas);
      expect(rantai.sampaiVisi, isFalse);
      expect(rantai.kalimat, 'Keuangan → Bebas utang → Lunasi kartu → Bayar 1 juta');
    });

    test('menghapus area hanya melepas tujuan', () async {
      final r = await rantaiLengkap();

      final dilepas = await repo.hapusArea(r.area);

      expect(dilepas, 1);
      final tujuan = await (db.select(db.tujuan)
            ..where((t) => t.id.equals(r.tujuan)))
          .getSingle();
      expect(tujuan.areaId, isNull);
      expect((await db.select(db.tugas).get()), hasLength(1));
      // Visi tetap ada (hanya area yang dihapus).
      expect(await repo.ambilVisi(), hasLength(1));
    });

    test('pengenal stabil unik dan area bisa dilepas tanpa dihapus', () async {
      final v = await repo.simpanVisi(nama: 'Visi A');
      final a = await repo.simpanArea(nama: 'Area A', visiId: v.id);

      await repo.simpanArea(id: a.id, nama: 'Area A', kosongkanVisi: true);

      final lagi = await repo.ambilAreaSatu(a.id);
      expect(lagi!.visiId, isNull);
      expect((await repo.ambilArea(hanyaTanpaVisi: true)), hasLength(1));
    });
  });

  // ------------------------------------------------------------------
  // Layar
  // ------------------------------------------------------------------

  Future<void> tampilkan(WidgetTester t, Widget layar) async {
    await t.binding.setSurfaceSize(const Size(420, 900));
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTema.terang(),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: layar,
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  Future<void> tutup(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 50));
    await t.binding.setSurfaceSize(null);
  }

  testWidgets('layar Visi & Area: tambah visi, tambah area, dan hapus visi '
      'tetap menyisakan area', (t) async {
    await tampilkan(t, const VisiScreen());

    // 1. Tambah visi lewat dialog.
    await t.tap(find.byKey(const Key('tambah_visi')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(find.byKey(const Key('nama_visi')), 'Hidup tenang');
    await t.tap(find.byKey(const Key('simpan_visi')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));

    final visi = (await repo.ambilVisi()).single;
    expect(find.byKey(Key('visi_${visi.id}')), findsOneWidget);

    // 2. Tambah area di bawah visi itu.
    await t.tap(find.byKey(Key('tambah_area_${visi.id}')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(find.byKey(const Key('nama_area')), 'Keuangan');
    await t.tap(find.byKey(const Key('simpan_area')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));

    final area = (await repo.ambilArea(visiId: visi.id)).single;
    expect(find.byKey(Key('area_${area.id}')), findsOneWidget);
    expect(find.text('Keuangan'), findsWidgets);

    // 3. Hapus visi: area harus tetap ada (hanya dilepas).
    await t.tap(find.byKey(Key('hapus_visi_${visi.id}')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(const Key('konfirmasi_hapus_visi')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));

    expect(await repo.ambilVisi(), isEmpty);
    final sisa = await repo.ambilAreaSatu(area.id);
    expect(sisa, isNotNull, reason: 'area tidak boleh ikut terhapus');
    expect(sisa!.visiId, isNull);
    expect(find.byKey(Key('area_${area.id}')), findsOneWidget);
    await tutup(t);
  });
}
