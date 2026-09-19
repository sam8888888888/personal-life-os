/// Uji FR-66 ("mode sorot hari berat") & FR-64 ("tinjauan malam").
///
/// Dua lapis: hitungan murni (urutan & isi tinjauan) dan layar sungguhan —
/// termasuk membuktikan tombol "Tunda" benar-benar menulis baris tunda dan
/// catatan aktivitas.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/audit/audit_log.dart';
import 'package:personal_life_os/core/hari_ini/hari_berat.dart';
import 'package:personal_life_os/core/hari_ini/tagihan_ringkas.dart';
import 'package:personal_life_os/core/hari_ini/tinjauan_malam.dart';
import 'package:personal_life_os/core/notifikasi/layanan_notifikasi.dart';
import 'package:personal_life_os/core/notifikasi/perencana_pengingat.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/hari_ini/hari_ini_screen.dart';
import 'package:personal_life_os/features/hari_ini/tinjauan_malam_screen.dart';

late AppDatabase db;

/// Waktu patok: 13 September 2026, pukul 20.00 (sudah lewat pukul 17.00).
final jamMalam = DateTime(2026, 9, 13, 20);

Future<int> tambahTagihan({
  required String nama,
  required DateTime jatuhTempo,
  int jumlahSen = 10000000,
  String prioritas = 'biasa',
}) async =>
    (await TagihanRepository(db).tambah(TagihanCompanion.insert(
      nama: nama,
      jumlahSen: Value(jumlahSen),
      jatuhTempo: jatuhTempo,
      prioritas: Value(prioritas),
    )))
        .id;

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() async => db.close());

  // ------------------------------------------------------------------
  // FR-66 — hitungan murni
  // ------------------------------------------------------------------

  group('FR-66 hitungan hari berat', () {
    TagihanRingkas t(int id, String nama, DateTime jt,
            {int? sen, String prioritas = 'biasa'}) =>
        TagihanRingkas(
            id: id,
            nama: nama,
            jatuhTempo: jt,
            jumlahSen: sen,
            prioritas: prioritas);

    test('lebih dari lima butir = hari berat, lima butir belum', () {
      final hari = DateTime(2026, 9, 13);
      final lima = [
        for (var i = 1; i <= 5; i++)
          t(i, 'Tagihan $i', DateTime(2026, 9, 13), sen: 1000000 * i),
      ];
      expect(susunHariBerat(tagihan: lima, hari: hari).berat, isFalse);

      final enam = [...lima, t(6, 'Tagihan 6', DateTime(2026, 9, 13), sen: 1)];
      final hasil = susunHariBerat(tagihan: enam, hari: hari);
      expect(hasil.berat, isTrue);
      expect(hasil.jumlah, 6);
    });

    test('urutan: terlambat dulu, lalu prioritas tinggi, lalu nominal besar',
        () async {
      final hari = DateTime(2026, 9, 13);
      final hasil = susunHariBerat(
        hari: hari,
        tagihan: [
          t(1, 'Biasa Besar', hari, sen: 90000000),
          t(2, 'Biasa Kecil', hari, sen: 100000),
          t(3, 'Terlambat', DateTime(2026, 9, 10), sen: 1),
          t(4, 'Penting', hari, sen: 500000, prioritas: 'tinggi'),
        ],
      );
      expect(hasil.urutan.map((b) => b.nama).toList(),
          ['Terlambat', 'Penting', 'Biasa Besar', 'Biasa Kecil']);
      expect(hasil.urutan.first.urutan, 1);
      expect(hasil.urutan.first.alasan, 'Terlambat 3 hari');
    });

    test('yang mendesak tidak ditawarkan untuk ditunda', () {
      final hari = DateTime(2026, 9, 13);
      final hasil = susunHariBerat(
        hari: hari,
        tagihan: [
          t(1, 'Terlambat', DateTime(2026, 9, 11), sen: 1000),
          t(2, 'Penting', hari, sen: 1000, prioritas: 'tinggi'),
          t(3, 'Biasa', hari, sen: 1000),
        ],
      );
      ButirHariBerat cari(String nama) =>
          hasil.urutan.firstWhere((b) => b.nama == nama);
      expect(cari('Terlambat').bisaDitunda, isFalse);
      expect(cari('Penting').bisaDitunda, isFalse);
      expect(cari('Biasa').bisaDitunda, isTrue);
      expect(hasil.jumlahBisaDitunda, 1);
    });

    test('tagihan yang sudah lunas dan yang belum jatuh tempo tidak dihitung',
        () {
      final hari = DateTime(2026, 9, 13);
      final hasil = susunHariBerat(
        hari: hari,
        tagihan: [
          TagihanRingkas(
              id: 1,
              nama: 'Sudah Lunas',
              jatuhTempo: DateTime(2026, 9, 13),
              lunas: true),
          TagihanRingkas(
              id: 2, nama: 'Nanti', jatuhTempo: DateTime(2026, 9, 20)),
        ],
      );
      expect(hasil.jumlah, 0);
      expect(hasil.berat, isFalse);
    });
  });

  // ------------------------------------------------------------------
  // FR-64 — hitungan murni
  // ------------------------------------------------------------------

  group('FR-64 isi tinjauan malam', () {
    test('memisahkan yang selesai dan yang belum tanpa kata menghakimi', () {
      final isi = susunTinjauanMalam(
        hari: DateTime(2026, 9, 13),
        tagihanLunasHariIni: const [JudulNominal(judul: 'Listrik PLN')],
        tagihanBelumSelesai: const [JudulNominal(judul: 'BPJS')],
        tugasSelesaiHariIni: const [JudulNominal(judul: 'Kirim laporan')],
        tugasBelumSelesai: const [JudulNominal(judul: 'Rapikan gudang')],
        kebiasaan: const [
          KebiasaanHariIni(nama: 'Jalan pagi', ditandai: true),
          KebiasaanHariIni(nama: 'Baca buku', ditandai: false),
        ],
        jumlahAirHariIni: 3,
      );

      // lunas + tugas selesai + kebiasaan ditandai + catatan air
      expect(isi.jumlahSelesai, 4);
      expect(isi.jumlahBelum, 3); // 1 tagihan + 1 tugas + 1 kebiasaan
      expect(isi.pertanyaan, pertanyaanMalam(DateTime(2026, 9, 13)));

      final semuaTeks = [
        ...isi.selesai.map((b) => '${b.judul} ${b.keterangan}'),
        ...isi.belum.map((b) => '${b.judul} ${b.keterangan}'),
      ].join(' ').toLowerCase();
      for (final kata in ['gagal', 'hukuman', 'malas']) {
        expect(semuaTeks.contains(kata), isFalse, reason: kata);
      }
      expect(semuaTeks.contains('belum ditandai lunas'), isTrue);
    });

    test('pertanyaan berganti tiap hari', () {
      final a = pertanyaanMalam(DateTime(2026, 9, 13));
      final b = pertanyaanMalam(DateTime(2026, 9, 14));
      expect(a, isNot(b));
      expect(daftarPertanyaanMalam.contains(a), isTrue);
    });
  });

  // ------------------------------------------------------------------
  // Layar
  // ------------------------------------------------------------------

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
    await t.pump(const Duration(milliseconds: 600));
  }

  Future<void> tutup(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 50));
    await t.binding.setSurfaceSize(null);
  }

  testWidgets('Hari Ini: kartu hari berat tampil & tombol Tunda benar-benar '
      'menunda', (t) async {
    // Enam tagihan jatuh tempo hari ini → hari berat.
    for (var i = 1; i <= 6; i++) {
      await tambahTagihan(
        nama: 'Tagihan $i',
        jatuhTempo: DateTime(2026, 9, 13),
        jumlahSen: 1000000 * (7 - i),
      );
    }

    await tampilkan(t, HariIniScreen(jamSekarang: () => jamMalam));

    expect(find.byKey(const Key('kartu_hari_berat')), findsOneWidget);
    expect(find.textContaining('Hari ini padat: 6 hal'), findsOneWidget);

    // Butir pertama = nominal terbesar (Tagihan 1).
    final tombol = find.byKey(const Key('tunda_hari_berat_1'));
    await t.ensureVisible(tombol);
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(tombol);
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));

    final tunda = await db.select(db.tundaPengingat).get();
    expect(tunda, hasLength(1));
    expect(tunda.first.pengingatId, idNotifikasi(1, slotTunda));
    expect(tunda.first.kapan, DateTime(2026, 9, 14, 9));
    expect(tunda.first.alasan, contains('hari berat'));

    final audit = await (db.select(db.auditLog)
          ..where((a) => a.modul.equals(ModulAudit.notifikasi)))
        .get();
    expect(audit, hasLength(1));
    expect(audit.first.aksi, AksiAudit.tunda);
    expect(audit.first.ringkas, contains('Tagihan 1'));
    await tutup(t);
  });

  testWidgets('Hari Ini: kartu tinjauan malam muncul setelah pukul 17.00',
      (t) async {
    await tambahTagihan(
        nama: 'BPJS', jatuhTempo: DateTime(2026, 9, 13), jumlahSen: 15000000);

    await tampilkan(t, HariIniScreen(jamSekarang: () => jamMalam));
    expect(find.byKey(const Key('kartu_tinjauan_malam')), findsOneWidget);

    await tutup(t);

    // Sebelum pukul 17.00 kartunya tidak ada.
    await tampilkan(
        t, HariIniScreen(jamSekarang: () => DateTime(2026, 9, 13, 9)));
    expect(find.byKey(const Key('kartu_tinjauan_malam')), findsNothing);
    await tutup(t);
  });

  testWidgets('Tinjauan malam: catatan tersimpan & saklar bisa dimatikan',
      (t) async {
    await tambahTagihan(
        nama: 'BPJS', jatuhTempo: DateTime(2026, 9, 13), jumlahSen: 15000000);

    await tampilkan(t, TinjauanMalamScreen(hari: jamMalam));
    expect(find.byKey(const Key('pertanyaan_malam')), findsOneWidget);
    // Satu tagihan (BPJS) belum ditandai lunas → masuk daftar "yang belum".
    expect(find.text('Yang belum (1)'), findsOneWidget);

    await t.enterText(find.byKey(const Key('catatan_refleksi')),
        'Besok cukup satu hal: bayar BPJS.');
    await t.tap(find.byKey(const Key('simpan_refleksi')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));

    final simpan = await db.select(db.pengaturan).get();
    final catatan = simpan
        .where((p) => p.kunci == kunciCatatanTinjauan(jamMalam))
        .toList();
    expect(catatan, hasLength(1));
    expect(catatan.first.nilai, contains('bayar BPJS'));

    // Saklar dimatikan → pengaturan tersimpan dan provider diperbarui.
    await t.tap(find.byKey(const Key('saklar_tinjauan_malam')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    final saklar = (await db.select(db.pengaturan).get())
        .where((p) => p.kunci == kunciSaklarTinjauanMalam)
        .toList();
    expect(saklar, hasLength(1));
    expect(saklar.first.nilai, 'false');
    await tutup(t);
  });
}
