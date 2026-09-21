/// Uji FR-52 — multi-mata uang & konversi (kurs diisi sendiri).
///
/// Yang dibuktikan:
///   * tiap mata uang diformat sesuai kaidahnya (Rp tanpa desimal, RM/USD 2
///     desimal, VND tanpa desimal), kode tak dikenal TIDAK dipalsukan jadi Rp,
///   * konversi ke Rupiah memakai kurs tersimpan; kurs belum diisi → null
///     (tidak menebak),
///   * tabel kurs tersimpan & terbaca kembali lengkap dengan sumber + waktu,
///   * ringkasan per mata uang menjumlahkan tagihan dengan benar,
///   * layar: mengubah mata uang satu tagihan tersimpan; menyimpan kurs bekerja
///     dan total Rupiah ikut berubah; kurs yang belum diisi diakui terbuka.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/laporan/kurs.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/uang/mata_uang_screen.dart';

late AppDatabase db;
late TagihanRepository repo;

Future<TagihanData> buatTagihan({
  required String nama,
  int? jumlahSen,
  String kodeMataUang = 'IDR',
}) async {
  final t = await repo.tambah(TagihanCompanion.insert(
    nama: nama,
    jatuhTempo: DateTime(2026, 9, 24),
    jumlahSen: Value(jumlahSen),
    kodeMataUang: Value(kodeMataUang),
  ));
  return (await (db.select(db.tagihan)..where((x) => x.id.equals(t.id)))
      .getSingle());
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TagihanRepository(db);
  });

  tearDown(() async => db.close());

  group('format & konversi', () {
    test('format per mata uang', () {
      expect(fmtMataUang(25000000, 'IDR'), 'Rp 250.000');
      expect(fmtMataUang(4599, 'MYR'), contains('45.99'));
      // Pemisah ribuan mengikuti kaidah mata uangnya (vi_VN memakai titik).
      expect(fmtMataUang(1500000, 'VND'), matches(RegExp(r'15[.,]000')));
      expect(fmtMataUang(50000, 'THB'), contains('500.00'));
      // Kode tak dikenal tidak dipalsukan jadi Rupiah.
      expect(fmtMataUang(1000, 'XYZ'), startsWith('XYZ'));
      expect(fmtMataUang(1000, null), isNotEmpty);
      expect(infoMataUang('usd')!.kode, 'USD');
      expect(infoMataUang('ngawur'), isNull);
    });

    test('konversi ke Rupiah memakai kurs; tanpa kurs → null', () {
      final kurs = {
        'USD': Kurs(
          kode: 'USD',
          rupiahPerUnit: 16200,
          sumber: 'catatan sendiri',
          diperbarui: DateTime(2026, 9, 20),
        ),
      };
      // 100 USD = 10.000 sen USD → 1.620.000 rupiah = 162.000.000 sen.
      expect(rupiahDari(10000, 'USD', kurs), 162000000);
      // Rupiah tidak butuh kurs.
      expect(rupiahDari(25000000, 'IDR', kurs), 25000000);
      // Ringgit belum diisi kursnya → tidak dikonversi (bukan 0).
      expect(rupiahDari(4599, 'MYR', kurs), isNull);
      expect(rupiahDari(100, 'XYZ', kurs), isNull);
    });

    test('ringkasan per mata uang menjumlahkan dengan benar', () {
      final kurs = {
        'USD': Kurs(
          kode: 'USD',
          rupiahPerUnit: 16000,
          sumber: 'catatan sendiri',
          diperbarui: DateTime(2026, 9, 20),
        ),
      };
      final ringkas = ringkasPerMataUang(
        [
          (kode: 'IDR', satuanTerkecil: 25000000),
          (kode: 'IDR', satuanTerkecil: 15000000),
          (kode: 'USD', satuanTerkecil: 1000),
        ],
        kurs,
      );
      final idr = ringkas.firstWhere((r) => r.kode == 'IDR');
      expect(idr.jumlahTagihan, 2);
      expect(idr.totalSatuanTerkecil, 40000000);
      expect(idr.totalRupiahSen, 40000000);
      expect(idr.adaKurs, isTrue);

      final usd = ringkas.firstWhere((r) => r.kode == 'USD');
      expect(usd.jumlahTagihan, 1);
      // 10 USD = 160.000 rupiah = 16.000.000 sen.
      expect(usd.totalRupiahSen, 16000000);
    });

    test('keterangan kurs menyebut sumber & waktu, atau mengaku belum ada', () {
      expect(keteranganKurs(null), contains('belum diisi'));
      final k = Kurs(
        kode: 'USD',
        rupiahPerUnit: 16200,
        sumber: 'Bank Indonesia',
        diperbarui: DateTime(2026, 9, 20, 14, 5),
      );
      final teks = keteranganKurs(k);
      expect(teks, contains('Bank Indonesia'));
      expect(teks, contains('20/09/2026 14:05'));
      expect(teks, contains('16.200'));
    });

    test('tabel kurs: simpan, baca, hapus', () async {
      final tabel = TabelKurs(PengaturanRepository(db));
      expect(await tabel.semua(), isEmpty);

      await tabel.simpan(Kurs(
        kode: 'usd',
        rupiahPerUnit: 16150,
        sumber: 'catatan sendiri',
        diperbarui: DateTime(2026, 9, 20, 8, 30),
      ));
      final lagi = await tabel.semua();
      expect(lagi.keys, ['USD']);
      expect(lagi['USD']!.rupiahPerUnit, 16150);
      expect(lagi['USD']!.diperbarui, DateTime(2026, 9, 20, 8, 30));

      await tabel.hapus('USD');
      expect(await tabel.semua(), isEmpty);
    });
  });

  group('layar', () {
    testWidgets('ubah mata uang tagihan & isi kurs → total Rupiah berubah',
        (t) async {
      final tagihan = await buatTagihan(
          nama: 'Langganan AWS',
          jumlahSen: 10000,
          kodeMataUang: 'USD');

      await t.binding.setSurfaceSize(const Size(420, 1000));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: Scaffold(
            body: MataUangScreen(
              db: db,
              sekarang: DateTime(2026, 9, 20, 9),
            ),
          ),
        ),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      // Sebelum kurs diisi: diakui terus terang.
      expect(find.byKey(const Key('catatan_kurs_kurang')), findsOneWidget);
      expect(find.textContaining('kurs belum diisi'), findsWidgets);

      // Isi kurs USD 16.200 lalu simpan.
      await t.scrollUntilVisible(
          find.byKey(const Key('nilai_kurs_USD')), 300,
          scrollable: find.byType(Scrollable).first, maxScrolls: 40);
      await t.pump(const Duration(milliseconds: 100));
      await t.enterText(find.byKey(const Key('nilai_kurs_USD')), '16200');
      await t.enterText(
          find.byKey(const Key('sumber_kurs_USD')), 'catatan sendiri');
      await t.tap(find.byKey(const Key('simpan_kurs_USD')));
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 400));

      final kurs = await TabelKurs(PengaturanRepository(db)).semua();
      expect(kurs['USD']!.rupiahPerUnit, 16200);
      expect(kurs['USD']!.sumber, 'catatan sendiri');
      expect(kurs['USD']!.diperbarui, DateTime(2026, 9, 20, 9));

      // 100 USD × Rp 16.200 = Rp 1.620.000 → tampil di total.
      await t.scrollUntilVisible(find.byKey(const Key('total_rupiah')), -300,
          scrollable: find.byType(Scrollable).first, maxScrolls: 40);
      await t.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Rp 1.620.000'), findsWidgets);
      expect(find.byKey(const Key('catatan_kurs_kurang')), findsNothing);

      // Ganti mata uang tagihan → tersimpan di database.
      await t.scrollUntilVisible(
          find.byKey(Key('pilih_mata_uang_${tagihan.id}')), 300,
          scrollable: find.byType(Scrollable).first, maxScrolls: 40);
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.byKey(Key('pilih_mata_uang_${tagihan.id}')));
      await t.pumpAndSettle();
      await t.tap(find.text('MYR').first);
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 400));

      final sesudah = await (db.select(db.tagihan)
            ..where((x) => x.id.equals(tagihan.id)))
          .getSingle();
      expect(sesudah.kodeMataUang, 'MYR');
      await t.pump(const Duration(seconds: 6));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('kurs tidak sah → diberi tahu, tidak disimpan', (t) async {
      await buatTagihan(nama: 'Tagihan USD', jumlahSen: 5000, kodeMataUang: 'USD');

      await t.binding.setSurfaceSize(const Size(420, 1000));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: Scaffold(body: MataUangScreen(db: db)),
        ),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      await t.scrollUntilVisible(
          find.byKey(const Key('nilai_kurs_USD')), 300,
          scrollable: find.byType(Scrollable).first, maxScrolls: 40);
      await t.pump(const Duration(milliseconds: 100));
      await t.enterText(find.byKey(const Key('nilai_kurs_USD')), '0');
      await t.tap(find.byKey(const Key('simpan_kurs_USD')));
      await t.pump(const Duration(milliseconds: 300));

      final snack = t.widget<SnackBar>(find.byKey(const Key('hasil_kurs')));
      expect((snack.content as Text).data, contains('lebih besar dari nol'));
      expect(await TabelKurs(PengaturanRepository(db)).semua(), isEmpty);

      await t.pump(const Duration(seconds: 6));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      await t.binding.setSurfaceSize(null);
    });
  });
}
