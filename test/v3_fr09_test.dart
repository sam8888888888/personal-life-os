/// Uji FR-09 — Duplikasi cepat tagihan & template pribadi.
///
/// Yang dibuktikan:
///   * salinan tagihan menyalin data penting (nominal, kategori, frekuensi,
///     jadwal pengingat) tetapi selalu dimulai sebagai BELUM dibayar,
///   * salinan punya `uid` sendiri (penting untuk sinkron antar HP),
///   * template pribadi tersimpan, bisa dipakai ulang, diganti bila namanya
///     sama, dihapus, dan aman dari data rusak.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/data/repository/template_pribadi.dart';
import 'package:personal_life_os/features/tagihan/daftar_tagihan_screen.dart';
import 'package:personal_life_os/features/tagihan/form_tagihan_screen.dart';

late AppDatabase db;

void main() {
  // Layar memakai format tanggal bahasa Indonesia (intl) — sama seperti uji lain.
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('FR-09 · Salin tagihan', () {
    test('salinan menyalin data penting & mulai belum dibayar', () async {
      final repo = TagihanRepository(db);
      final id = (await repo.tambah(TagihanCompanion.insert(
        nama: 'Internet rumah',
        jatuhTempo: DateTime(2026, 9, 25),
        jumlahSen: const Value(350000),
        frekuensi: const Value('bulanan'),
        pengingatLeadHari: const Value('7,3,1'),
        pengingatJam: const Value('08:30'),
        catatan: const Value('Paket 30 Mbps'),
      )))
          .id;
      await repo.tandaiLunas(id, tanggalBayar: DateTime(2026, 9, 20));

      final asal = await (db.select(db.tagihan)..where((t) => t.id.equals(id))).getSingle();
      final idBaru = await repo.duplikat(id);
      final salinan =
          await (db.select(db.tagihan)..where((t) => t.id.equals(idBaru))).getSingle();

      expect(salinan.nama, 'Internet rumah (salinan)');
      expect(salinan.jumlahSen, asal.jumlahSen);
      expect(salinan.kategoriId, asal.kategoriId);
      expect(salinan.frekuensi, asal.frekuensi);
      expect(salinan.pengingatLeadHari, '7,3,1');
      expect(salinan.pengingatJam, '08:30');
      expect(salinan.catatan, 'Paket 30 Mbps');
      expect(salinan.lunas, isFalse, reason: 'salinan mulai belum dibayar');
      expect(salinan.tanggalLunas, isNull);
      expect(salinan.uid, isNotNull);
      expect(salinan.uid, isNot(asal.uid), reason: 'uid harus beda untuk sinkron');
    });

    test('nama & jatuh tempo salinan bisa diganti', () async {
      final repo = TagihanRepository(db);
      final id = (await repo.tambah(TagihanCompanion.insert(
        nama: 'Listrik',
        jatuhTempo: DateTime(2026, 9, 20),
        jumlahSen: const Value(300000),
      )))
          .id;
      final idBaru = await repo.duplikat(id,
          namaBaru: 'Listrik (Oktober)', jatuhTempoBaru: DateTime(2026, 10, 20));
      final salinan =
          await (db.select(db.tagihan)..where((t) => t.id.equals(idBaru))).getSingle();
      expect(salinan.nama, 'Listrik (Oktober)');
      expect(salinan.jatuhTempo, DateTime(2026, 10, 20));
      expect(await (db.select(db.tagihan)).get(), hasLength(2));
    });

    testWidgets('tombol duplikat di daftar menambah tagihan baru', (t) async {
      final repo = TagihanRepository(db);
      final id = (await repo.tambah(TagihanCompanion.insert(
        nama: 'Air PDAM',
        jatuhTempo: DateTime(2026, 9, 22),
        jumlahSen: const Value(120000),
      )))
          .id;

      await t.binding.setSurfaceSize(const Size(430, 950));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
              body: DaftarTagihanScreen(sekarang: () => DateTime(2026, 9, 21))),
        ),
      ));
      await t.pumpAndSettle();

      await t.ensureVisible(find.byKey(Key('duplikat_tagihan_$id')));
      await t.tap(find.byKey(Key('duplikat_tagihan_$id')));
      await t.pumpAndSettle();

      final semua = await (db.select(db.tagihan)).get();
      expect(semua, hasLength(2));
      expect(semua.map((e) => e.nama), contains('Air PDAM (salinan)'));
      expect(find.textContaining('Tagihan disalin'), findsOneWidget);

      // SnackBar punya timer sendiri (tampil 4 detik lalu menutup) — majukan
      // waktu palsu dengan langkah besar sampai tidak ada lagi frame terjadwal,
      // supaya tidak meninggalkan timer menggantung di akhir uji.
      await t.pumpAndSettle(const Duration(seconds: 5));

      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle(const Duration(seconds: 5));
      await t.binding.setSurfaceSize(null);
    });
  });

  group('FR-09 · Template pribadi', () {
    test('simpan, baca ulang, ganti nama sama, lalu hapus', () async {
      final simpanan = PenyimpananTemplatePribadi(PengaturanRepository(db));

      await simpanan.tambah(const TemplatePribadi(
          nama: 'Listrik Kos',
          perkiraanSen: 25000000,
          frekuensi: 'bulanan',
          leadHari: [7, 3, 1]));
      var daftar = await simpanan.semua();
      expect(daftar, hasLength(1));
      expect(daftar.single.nama, 'Listrik Kos');
      expect(daftar.single.leadHari, [7, 3, 1]);

      // nama sama (beda huruf besar/kecil) → menggantikan
      await simpanan.tambah(const TemplatePribadi(
          nama: 'listrik kos',
          perkiraanSen: 30000000,
          frekuensi: 'bulanan',
          leadHari: [5, 1]));
      daftar = await simpanan.semua();
      expect(daftar, hasLength(1));
      expect(daftar.single.perkiraanSen, 30000000);
      expect(daftar.single.leadHari, [5, 1]);

      await simpanan.tambah(const TemplatePribadi(
          nama: 'Internet Kos',
          perkiraanSen: 30000000,
          frekuensi: 'bulanan',
          leadHari: [3, 1]));
      daftar = await simpanan.hapus('Listrik Kos');
      expect(daftar, hasLength(1));
      expect(daftar.single.nama, 'Internet Kos');
    });

    test('data rusak / kosong tidak membuat aplikasi gagal', () {
      expect(jsonKeTemplatePribadi(null), isEmpty);
      expect(jsonKeTemplatePribadi(''), isEmpty);
      expect(jsonKeTemplatePribadi('bukan json'), isEmpty);
      expect(jsonKeTemplatePribadi('[{"tanpa_nama": 1}]'), isEmpty);
      final campur = jsonKeTemplatePribadi(
          '[{"nama":"A","perkiraanSen":100,"frekuensi":"bulanan","leadHari":[1]},'
          '{"rusak":true}]');
      expect(campur, hasLength(1));
      expect(campur.single.nama, 'A');
    });

    test('batas 20 template pribadi dihormati', () async {
      final simpanan = PenyimpananTemplatePribadi(PengaturanRepository(db));
      for (var i = 0; i < 25; i++) {
        await simpanan.tambah(TemplatePribadi(
            nama: 'T$i',
            perkiraanSen: 1000,
            frekuensi: 'bulanan',
            leadHari: const [1]));
      }
      expect(await simpanan.semua(), hasLength(batasTemplatePribadi));
    });

    testWidgets('form: simpan isian sebagai template lalu chip muncul',
        (t) async {
      await t.binding.setSurfaceSize(const Size(430, 1400));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        // Layar form mengembalikan Column (dipasang di dalam kerangka aplikasi),
        // jadi perlu dibungkus Scaffold saat diuji — pelajaran yang sama seperti
        // uji layar lain di proyek ini.
        child: const MaterialApp(
            home: Scaffold(body: FormTagihanScreen())),
      ));
      await t.pumpAndSettle();

      await t.enterText(find.widgetWithText(TextFormField, 'Nama tagihan *'),
          'Listrik Kos');
      await t.ensureVisible(find.byKey(const Key('simpan_template_pribadi')));
      await t.tap(find.byKey(const Key('simpan_template_pribadi')));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('template_pribadi_Listrik Kos')), findsOneWidget);
      final tersimpan =
          await PengaturanRepository(db).baca(kunciTemplatePribadi);
      expect(tersimpan, contains('Listrik Kos'));

      // SnackBar "template disimpan" punya timer sendiri — majukan waktu palsu
      // sampai habis supaya uji tidak meninggalkan timer menggantung.
      await t.pumpAndSettle(const Duration(seconds: 5));

      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle(const Duration(seconds: 5));
      await t.binding.setSurfaceSize(null);
    });
  });
}
