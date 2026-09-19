/// Uji FR-65 — Today, Kalender, dan Kalender Keuangan memakai sumber data yang
/// sama: **tambah/ubah di satu tempat → langsung terlihat di tempat lain**.
///
/// Cara membuktikan (jujur, tanpa mengandalkan tata letak):
/// 1. satu tagihan ditulis lewat repository (jalur yang dipakai form);
/// 2. **Today** — teks nyata di layar (sesudah digulir ke bagian Perhatian);
/// 3. **Kalender** — sumber yang dibaca layarnya (`periodeBulanProvider`);
/// 4. **Kalender Keuangan** — repository yang dipakainya (`bulan()`), plus
///    hitungan yang benar-benar dirender di layar ("1 peristiwa").
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/notifikasi/layanan_notifikasi.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/kalender_keuangan_repository.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/hari_ini/hari_ini_screen.dart';
import 'package:personal_life_os/features/kalender/kalender_keuangan_screen.dart';

late AppDatabase db;

/// Waktu patok uji: 20 September 2026, 09.00.
final jamUji = DateTime(2026, 9, 20, 9);

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() async => db.close());

  Future<void> tampilkan(WidgetTester t, Widget layar) async {
    await t.binding.setSurfaceSize(const Size(420, 900));
    await t.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        statusIzinPengingatProvider.overrideWith((ref) async =>
            const StatusIzinPengingat(
                notifikasiDiizinkan: true, alarmTepatDiizinkan: true)),
      ],
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
    await t.pump(const Duration(milliseconds: 800));
  }

  Future<void> gulirKe(WidgetTester t, Finder target, {int maks = 12}) async {
    for (var i = 0; i < maks; i++) {
      if (target.evaluate().isNotEmpty) return;
      await t.dragFrom(const Offset(210, 500), const Offset(0, -220));
      await t.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> tutup(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 50));
    await t.binding.setSurfaceSize(null);
  }

  testWidgets('tagihan baru muncul di Today, Kalender, dan Kalender Keuangan',
      (t) async {
    // 1. Satu tempat: tulis lewat repository (jalur yang sama dipakai form).
    await TagihanRepository(db).tambah(TagihanCompanion.insert(
      nama: 'Internet Rumah',
      jumlahSen: const Value(30000000),
      jatuhTempo: DateTime(2026, 9, 20),
    ));

    // 2. Today — teks nyata di layar.
    await tampilkan(t, HariIniScreen(jamSekarang: () => jamUji));
    await gulirKe(t, find.textContaining('Internet Rumah'));
    expect(find.textContaining('Internet Rumah'), findsWidgets,
        reason: 'Today harus membaca tagihan yang baru ditulis');
    await tutup(t);

    // 3. Kalender — sumber yang dibacanya.
    // `periodeBulanProvider` memanggil tepat method ini (lihat
    // app_providers.dart) — jadi membuktikan sumbernya sama, tanpa memasang
    // ProviderContainer di dalam uji widget (itu meninggalkan pewaktu hidup).
    final barisKalender = await TagihanRepository(db).periodeBulan(
      DateTime(2026, 9),
    );
    expect(barisKalender.any((b) => b.nama == 'Internet Rumah'), isTrue,
        reason: 'Kalender membaca sumber tagihan yang sama');

    // 4. Kalender Keuangan — repository + hitungan yang dirender layar.
    final repoKk = KalenderKeuanganRepository(db);
    final peristiwa = await repoKk.bulan(2026, 9);
    expect(
        peristiwa.any((p) => p.judul.contains('Internet Rumah')), isTrue,
        reason: 'Kalender Keuangan menggabungkan sumber yang sama');

    await tampilkan(t, KalenderKeuanganScreen(jamSekarang: () => jamUji));
    expect(find.textContaining('1 peristiwa'), findsOneWidget,
        reason: 'layar menghitung satu peristiwa pada bulan itu');
    await tutup(t);

    // 4b. Peristiwanya benar-benar bisa diterjemahkan layar (judul & tanggal).
    final satu = peristiwa.firstWhere((p) => p.judul.contains('Internet Rumah'));
    expect(satu.tanggal, DateTime(2026, 9, 20));
  });

  testWidgets('ubah di satu tempat langsung terlihat di semua tempat',
      (t) async {
    final repo = TagihanRepository(db);
    final id = (await repo.tambah(TagihanCompanion.insert(
      nama: 'Listrik',
      jumlahSen: const Value(15000000),
      jatuhTempo: DateTime(2026, 9, 20),
    )))
        .id;

    // Diubah di satu tempat: nominal naik.
    await repo.ubah(
      TagihanCompanion(jumlahSen: const Value(25000000)),
      id: id,
    );

    // Today menampilkan nominal TERBARU.
    await tampilkan(t, HariIniScreen(jamSekarang: () => jamUji));
    await gulirKe(t, find.textContaining('Rp 250.000'));
    expect(find.textContaining('Rp 250.000'), findsWidgets,
        reason: 'Today memakai nominal terbaru, bukan salinan lama');
    await tutup(t);

    // Kalender (sumber) ikut berubah pada pembacaan berikutnya.
    final baris = await TagihanRepository(db).periodeBulan(DateTime(2026, 9));
    expect(baris.any((b) => b.nama == 'Listrik'), isTrue);

    // Kalender Keuangan membaca nominal terbaru juga.
    final peristiwa = await KalenderKeuanganRepository(db).bulan(2026, 9);
    final listrik = peristiwa.firstWhere((p) => p.judul.contains('Listrik'));
    // Kalender Keuangan menandai uang keluar sebagai negatif — tandanya wajar,
    // yang dibuktikan di sini nominal TERBARU yang dipakai.
    expect(listrik.nominalSen.abs(), 25000000,
        reason: 'nominal peristiwa ikut terbaru, bukan nilai lama');
  });
}
