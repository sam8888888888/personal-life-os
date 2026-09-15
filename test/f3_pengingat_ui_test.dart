/// Uji UI Fase 3 — layar "Pengingat & izin": status izin, jadwal berikutnya,
/// panduan per merek, dan aksi cepat (segarkan jadwal, uji notifikasi).
/// Memakai layanan notifikasi palsu: tidak butuh perangkat Android.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/app_router.dart';
import 'package:personal_life_os/core/notifikasi/jejak.dart';
import 'package:personal_life_os/core/notifikasi/layanan_notifikasi.dart';
import 'package:personal_life_os/core/notifikasi/model_pengingat.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/pengingat/layanan_panduan.dart';

late AppDatabase db;
late LayananUji layanan;

/// Layanan palsu: mencatat permintaan izin, uji, dan jadwal.
class LayananUji implements LayananNotifikasi {
  // PB-09/PB-10: bagian diagnostik antarmuka (nilai bawaan untuk uji).
  @override
  HasilPasang? get hasilPasangTerakhir => null;

  @override
  bool get siap => true;

  List<Pengingat> terpasang = const [];
  int izinDiminta = 0;
  int alarmDiminta = 0;
  List<Duration> uji = const [];

  @override
  Future<void> siapkan() async {}

  @override
  Future<StatusIzinPengingat> statusIzin() async => StatusIzinPengingat(
        notifikasiDiizinkan: terpasang.isNotEmpty || izinDiminta > 0,
        alarmTepatDiizinkan: alarmDiminta > 0,
      );

  @override
  Future<bool> mintaIzinNotifikasi() async {
    izinDiminta++;
    return true;
  }

  @override
  Future<bool> mintaIzinAlarmTepat() async {
    alarmDiminta++;
    return true;
  }

  @override
  Future<void> pasangJadwal(List<Pengingat> daftar) async => terpasang = daftar;

  @override
  Future<void> batalkanSemua() async => terpasang = const [];

  @override
  Future<void> jadwalkanSatu(Pengingat p) async => terpasang = [...terpasang, p];

  @override
  Future<void> tampilkanUji({Duration tunda = const Duration(seconds: 10)}) async =>
      uji = [...uji, tunda];

  @override
  Future<List<({int id, String? judul, DateTime? waktu})>> tertunda() async =>
      terpasang.map((p) => (id: p.id, judul: p.judul, waktu: p.waktu)).toList();
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));
  setUp(() async {
    // Jejak ke berkas dinonaktifkan: plugin path_provider tidak ada saat uji.
    penentuJejak = () async => null;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    layanan = LayananUji();
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = TagihanRepository(db);
    await repo.tambah(TagihanCompanion.insert(
        nama: 'Internet IndiHome',
        jumlahSen: const Value(38500000),
        jatuhTempo: DateTime.now().add(const Duration(days: 2))));
  });
  tearDown(() => db.close());

  Future<void> bukaPengingat(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(420, 900));
    await t.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        layananNotifikasiProvider.overrideWithValue(layanan),
      ],
      child: MaterialApp.router(
        theme: AppTema.terang(),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: buatRouter(awal: '/pengingat'),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> tutup(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 50));
    await t.binding.setSurfaceSize(null);
  }

  Future<void> ketukTerlihat(WidgetTester t, Finder target) async {
    await t.ensureVisible(target);
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    await t.tap(target);
    await t.pump();
  }

  testWidgets('layar pengingat menampilkan status izin & jadwal berikutnya',
      (tester) async {
    await bukaPengingat(tester);

    expect(find.text('Status izin pengingat'), findsOneWidget);
    expect(find.text('Jadwal pengingat berikutnya'), findsOneWidget);
    // Jadwal dihitung dari data nyata: tagihan muncul di daftar pengingat.
    expect(find.textContaining('Internet IndiHome'), findsWidgets);
    expect(find.textContaining('Pengingat tagihan'), findsWidgets);
    await tutup(tester);
  });

  testWidgets('panduan merek tampil sesuai perangkat (default: umum)',
      (tester) async {
    await bukaPengingat(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Agar pengingat tidak dimatikan sistem'),
        findsOneWidget);
    expect(find.textContaining('Panduan untuk:'), findsOneWidget);
    await tutup(tester);
  });

  testWidgets('tombol "Minta izin notifikasi" memanggil permintaan izin',
      (tester) async {
    await bukaPengingat(tester);
    await ketukTerlihat(tester, find.text('Minta izin notifikasi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(layanan.izinDiminta, 1);
    await tutup(tester);
  });

  testWidgets('tombol "Uji notifikasi (10 detik)" menjadwalkan notifikasi uji',
      (tester) async {
    await bukaPengingat(tester);
    await ketukTerlihat(tester, find.text('Uji notifikasi (10 detik)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(layanan.uji, isNotEmpty);
    expect(layanan.uji.first, const Duration(seconds: 10));
    await tutup(tester);
  });

  testWidgets('tombol "Segarkan jadwal" memasang jadwal ke layanan',
      (tester) async {
    await bukaPengingat(tester);
    await ketukTerlihat(tester, find.text('Segarkan jadwal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(layanan.terpasang, isNotEmpty);
    expect(find.textContaining('Jadwal disegarkan'), findsOneWidget);
    await tutup(tester);
  });

  testWidgets('Pengaturan punya pintu masuk ke layar pengingat',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        layananNotifikasiProvider.overrideWithValue(layanan),
      ],
      child: MaterialApp.router(
        theme: AppTema.terang(),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: buatRouter(awal: '/pengaturan'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Layar Pengaturan punya tambahan bagian "Mata uang" (FR-67), sehingga
    // baris pengingat bisa berada di bawah lipatan dan belum dibangun.
    if (find.text('Pengingat & izin').evaluate().isEmpty) {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
    }
    expect(find.text('Pengingat & izin'), findsOneWidget);
    await ketukTerlihat(tester, find.text('Pengingat & izin'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Status izin pengingat'), findsOneWidget);
    await tutup(tester);
  });

  group('Panduan per merek (murni)', () {
    test('merek dikenali memakai panduan khusus', () {
      expect(panduanUntuk('Xiaomi', 'Redmi Note 12').nama, contains('Xiaomi'));
      expect(panduanUntuk('OPPO', 'A78').nama, contains('OPPO'));
      expect(panduanUntuk('samsung', 'SM-A155').nama, contains('Samsung'));
      expect(panduanUntuk('vivo', 'Y27').nama, contains('Vivo'));
      expect(panduanUntuk('HUAWEI', 'Nova 12').nama, contains('Huawei'));
    });

    test('merek tidak dikenal memakai panduan umum', () {
      final p = panduanUntuk('Nothing', 'Phone (2a)');
      expect(p.nama, panduanUmum.nama);
      expect(p.langkah, isNotEmpty);
      expect(panduanUntuk(null, null), panduanUmum);
    });

    test('setiap panduan punya langkah yang bisa diikuti', () {
      for (final p in daftarPanduan) {
        expect(p.langkah.length, greaterThanOrEqualTo(3), reason: p.nama);
        expect(p.kunci, isNotEmpty);
      }
    });
  });
}
