/// Uji FR-17 & FR-40 — pembelajaran pola bayar, usul pengingat, pengingat pintar.
///
/// Yang dibuktikan:
///   * pola terbaca dari riwayat (hari khas, kebiasaan maju/telat, keyakinan),
///   * usul hanya muncul bila polanya kuat DAN berbeda dari jadwal sekarang,
///   * menekan "Terapkan" benar-benar mengubah jadwal pengingat di database,
///   * saklar "pengingat menyesuaikan pola" tersimpan,
///   * perencana pengingat menambah satu pengingat pada hari kebiasaan (FR-17).
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/laporan/pola_bayar.dart';
import 'package:personal_life_os/core/notifikasi/perencana_pengingat.dart';
import 'package:personal_life_os/core/notifikasi/penyinkron_pengingat.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/tagihan/pola_bayar_screen.dart';

AppDatabase? db;
TagihanRepository? repo;

/// Riwayat 3 pembayaran pada tanggal 20, untuk tagihan yang jatuh tempo tgl 24
/// (jadi biasa dibayar 4 hari lebih awal).
Future<int> siapkanTagihan() async {
  final r = repo!;
  final t = await r.tambah(TagihanCompanion.insert(
    nama: 'Listrik Rumah',
    jatuhTempo: DateTime(2026, 9, 24),
    jumlahSen: const Value(250000),
    pengingatLeadHari: const Value('7,3,1,0'),
  ));
  for (final bulan in [6, 7, 8]) {
    await db!.into(db!.riwayatPembayaran).insert(RiwayatPembayaranCompanion.insert(
          tagihanId: t.id,
          periodeJatuhTempo: DateTime(2026, bulan, 24),
          jumlahSen: 250000,
          tanggalBayar: DateTime(2026, bulan, 20),
          telatHari: const Value(0),
        ));
  }
  return t.id;
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TagihanRepository(db!);
  });

  tearDown(() async => db!.close());

  // ---------------------------------------------------------------- mesin pola
  test('FR-40 · pola terbaca: hari khas, kebiasaan lebih awal, keyakinan tinggi',
      () async {
    final id = await siapkanTagihan();
    final riwayat = await repo!.riwayatDenganId();
    final pola = hitungPolaBayar([
      for (final r in riwayat)
        CatatanBayar(
          tagihanId: r.tagihanId,
          namaTagihan: r.nama,
          tanggalBayar: r.tanggalBayar,
          jatuhTempoPeriode: r.periode,
        ),
    ]);

    expect(pola, hasLength(1));
    expect(pola.first.tagihanId, id);
    expect(pola.first.hariKhasDalamBulan, 20);
    expect(pola.first.selisihHariKhas, 4);
    expect(pola.first.cukupBukti, isTrue);
    expect(pola.first.keyakinan, 100);
  });

  test('FR-40 · bukti sedikit → pola belum dipakai untuk mengusulkan', () {
    final pola = hitungPolaBayar([
      CatatanBayar(
        tagihanId: 1,
        namaTagihan: 'Air',
        tanggalBayar: DateTime(2026, 8, 20),
        jatuhTempoPeriode: DateTime(2026, 8, 24),
      ),
      CatatanBayar(
        tagihanId: 1,
        namaTagihan: 'Air',
        tanggalBayar: DateTime(2026, 7, 20),
        jatuhTempoPeriode: DateTime(2026, 7, 24),
      ),
    ]);
    expect(pola.first.jumlahPembayaran, 2);
    expect(pola.first.cukupBukti, isFalse);
    // Polanya memang terlihat, tetapi belum dipakai untuk mengusulkan jadwal
    // sampai bukti cukup (3 pembayaran).
    expect(pola.first.ringkasan, contains('tanggal 20'));
    expect(pola.first.ringkasan, contains('dari 2 pembayaran'));
    expect(
      usulPengingat(pola: pola, leadSekarang: const {1: [7, 3, 1, 0]}),
      isEmpty,
    );
    // Baru 1 pembayaran: polanya belum bisa dibaca sama sekali.
    final satu = hitungPolaBayar([
      CatatanBayar(
        tagihanId: 2,
        namaTagihan: 'Gas',
        tanggalBayar: DateTime(2026, 8, 20),
        jatuhTempoPeriode: DateTime(2026, 8, 24),
      ),
    ]);
    expect(satu.first.ringkasan, contains('belum terlihat polanya'));
  });

  test('FR-40 · usul dibuat hanya bila berbeda dari jadwal sekarang', () {
    const polaKuat = PolaBayar(
      tagihanId: 7,
      namaTagihan: 'Internet',
      jumlahPembayaran: 4,
      hariKhasDalamBulan: 20,
      selisihHariKhas: 4,
      keyakinan: 95,
    );

    final perlu = usulPengingat(
      pola: const [polaKuat],
      leadSekarang: const {7: [7, 3, 1, 0]},
    );
    expect(perlu, hasLength(1));
    expect(perlu.first.leadUsul, [5, 4, 1, 0]);
    expect(perlu.first.berbeda, isTrue);
    expect(perlu.first.alasan, contains('4 hari sebelum jatuh tempo'));

    final sudahCocok = usulPengingat(
      pola: const [polaKuat],
      leadSekarang: const {7: [5, 4, 1, 0]},
    );
    expect(sudahCocok, isEmpty);
  });

  test('FR-40 · lead usul selalu memuat H-0 (hari jatuh tempo)', () {
    expect(leadDisarankan(4), contains(0));
    expect(leadDisarankan(10), contains(0));
    expect(leadDisarankan(null), contains(0));
    expect(leadDisarankan(0), [1, 0]);
  });

  test('FR-17 · peta lead pintar hanya untuk pola kuat & tagihan aktif', () {
    const kuat = PolaBayar(
      tagihanId: 1,
      namaTagihan: 'A',
      jumlahPembayaran: 4,
      hariKhasDalamBulan: 20,
      selisihHariKhas: 4,
      keyakinan: 90,
    );
    const lemah = PolaBayar(
      tagihanId: 2,
      namaTagihan: 'B',
      jumlahPembayaran: 1,
      hariKhasDalamBulan: 3,
      selisihHariKhas: 2,
      keyakinan: 40,
    );
    const telat = PolaBayar(
      tagihanId: 3,
      namaTagihan: 'C',
      jumlahPembayaran: 4,
      hariKhasDalamBulan: 2,
      selisihHariKhas: -3,
      keyakinan: 90,
    );

    final peta = leadPintarDariPola(
      const [kuat, lemah, telat],
      tagihanAktif: const {1, 2, 3},
    );
    expect(peta, {1: 4});
  });

  // ------------------------------------------------------------------ perencana
  test('FR-17 · perencana memasang pengingat pada hari kebiasaan membayar',
      () async {
    final tagihan = await repo!.tambah(TagihanCompanion.insert(
      nama: 'PDAM',
      jatuhTempo: DateTime(2026, 9, 24),
      jumlahSen: const Value(120000),
      pengingatLeadHari: const Value('3,1,0'),
    ));

    final kini = DateTime(2026, 9, 10, 8);
    final tanpa = const PerencanaPengingat()
        .rencanakan(tagihan: [tagihan], sekarang: kini);
    final dengan = const PerencanaPengingat().rencanakan(
      tagihan: [tagihan],
      sekarang: kini,
      leadPintar: {tagihan.id: 4},
    );

    expect(tanpa.map((p) => p.hariSebelum), isNot(contains(4)));
    expect(dengan.map((p) => p.hariSebelum), contains(4));
  });

  // ---------------------------------------------------------------------- layar
  testWidgets('FR-40 · layar menampilkan pola & Tombol Terapkan mengubah jadwal',
      (t) async {
    final id = await siapkanTagihan();

    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: PolaBayarScreen(db: db)),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.textContaining('Biasanya bayar tanggal 20'), findsOneWidget);
    expect(find.textContaining('biasanya 4 hari sebelum jatuh tempo'),
        findsOneWidget);
    expect(find.text('Usul: H-5, H-4, H-1, H'), findsOneWidget);

    await t.tap(find.byKey(Key('terapkan_usul_$id')));
    await t.pumpAndSettle();

    final baris = await (db!.select(db!.tagihan)
          ..where((x) => x.id.equals(id)))
        .getSingle();
    expect(baris.pengingatLeadHari, '5,4,1,0');

    // Biarkan SnackBar selesai supaya tidak ada timer menggantung di akhir uji.
    await t.pumpAndSettle(const Duration(seconds: 5));
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('FR-17 · saklar menyesuaikan pola tersimpan di pengaturan',
      (t) async {
    await repo!.tambah(TagihanCompanion.insert(
      nama: 'Listrik',
      jatuhTempo: DateTime(2026, 9, 24),
      jumlahSen: const Value(100000),
    ));

    await t.pumpWidget(ProviderScope(
      child: MaterialApp(home: Scaffold(body: PolaBayarScreen(db: db))),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('saklar_pengingat_pintar')));
    await t.pumpAndSettle();

    final nilai =
        await PengaturanRepository(db!).baca(kunciPengingatPintar);
    expect(nilai, 'true');

    await t.pumpAndSettle(const Duration(seconds: 5));
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle(const Duration(seconds: 5));
  });
}
