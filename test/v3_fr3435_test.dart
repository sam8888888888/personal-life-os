/// Uji FR-34 (denda terhindarkan) & FR-35 (deteksi kenaikan tagihan).
///
/// Kasus tepi yang diuji: aturan denda belum diisi (jangan mengarang angka),
/// pembayaran lewat jatuh tempo tidak dihitung, aturan "denda minimum" (persen
/// vs nominal dipakai yang lebih besar), stempel waktu aturan, dan perbandingan
/// kenaikan yang butuh minimal 4 pembayaran.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/laporan/denda_terhindarkan.dart';
import 'package:personal_life_os/core/laporan/kenaikan_tagihan.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/laporan/denda_terhindarkan_screen.dart';
import 'package:personal_life_os/features/laporan/kenaikan_tagihan_screen.dart';

late AppDatabase db;

void main() {
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('FR-34 · Denda terhindarkan', () {
    test('aturanKeTeks & teksKeAturan bolak-balik', () {
      final a = AturanDenda(
          persenPerBulan: 2,
          nominalSen: 2500000,
          ditetapkanPada: DateTime(2026, 9, 1, 10, 30));
      final kembali = teksKeAturan(aturanKeTeks(a))!;
      expect(kembali.persenPerBulan, 2);
      expect(kembali.nominalSen, 2500000);
      expect(kembali.ditetapkanPada, DateTime(2026, 9, 1, 10, 30));
      expect(teksKeAturan(null), isNull);
      expect(teksKeAturan(''), isNull);
      expect(teksKeAturan('rusak'), isNull);
    });

    test('dipakai yang lebih besar antara persen & nominal (denda minimum)', () {
      const a = AturanDenda(persenPerBulan: 1, nominalSen: 2500000);
      // 1% dari Rp 100.000 = Rp 1.000 → lebih kecil dari nominal Rp 25.000
      expect(a.dendaUntuk(10000000), 2500000);
      // 1% dari Rp 5.000.000 = Rp 50.000 → lebih besar dari nominal
      expect(a.dendaUntuk(500000000), 5000000);
    });

    test('hanya pelunasan tepat waktu yang menghasilkan penghematan', () {
      final hasil = hitungDendaTerhindarkan(
        riwayat: [
          (
            nama: 'Listrik',
            tanggalBayar: DateTime(2026, 9, 20),
            nominalSen: 250000,
            tepatWaktu: true
          ),
          (
            nama: 'Listrik',
            tanggalBayar: DateTime(2026, 8, 22),
            nominalSen: 250000,
            tepatWaktu: false
          ),
        ],
        aturan: {'Listrik': const AturanDenda(persenPerBulan: 2, nominalSen: 0)},
        semuaNamaTagihan: ['Listrik'],
        acuan: DateTime(2026, 9, 21),
      );
      expect(hasil.daftar, hasLength(1));
      expect(hasil.totalSen, 5000, reason: '2% dari Rp 2.500 = Rp 50');
      expect(hasil.bulanIniSen, 5000);
    });

    test('tagihan tanpa aturan denda tidak dihitung, tapi didaftarkan', () {
      final hasil = hitungDendaTerhindarkan(
        riwayat: [
          (
            nama: 'Air',
            tanggalBayar: DateTime(2026, 9, 10),
            nominalSen: 150000,
            tepatWaktu: true
          ),
        ],
        aturan: const {},
        semuaNamaTagihan: ['Air', 'Internet'],
        acuan: DateTime(2026, 9, 21),
      );
      expect(hasil.daftar, isEmpty);
      expect(hasil.totalSen, 0);
      expect(hasil.tagihanTanpaAturan, ['Air', 'Internet']);
    });

    test('aturan hanya berlaku untuk pembayaran setelah aturan diatur', () {
      final hasil = hitungDendaTerhindarkan(
        riwayat: [
          (
            nama: 'Listrik',
            tanggalBayar: DateTime(2026, 8, 20),
            nominalSen: 250000,
            tepatWaktu: true
          ),
          (
            nama: 'Listrik',
            tanggalBayar: DateTime(2026, 9, 20),
            nominalSen: 250000,
            tepatWaktu: true
          ),
        ],
        aturan: {
          'Listrik': AturanDenda(
              persenPerBulan: 2,
              nominalSen: 0,
              ditetapkanPada: DateTime(2026, 9, 1)),
        },
        semuaNamaTagihan: ['Listrik'],
        acuan: DateTime(2026, 9, 21),
      );
      expect(hasil.daftar, hasLength(1));
      expect(hasil.daftar.single.tanggalBayar, DateTime(2026, 9, 20));
    });

    testWidgets('layar: angka nol saat belum ada aturan, lalu terhitung setelah diatur',
        (t) async {
      final repo = TagihanRepository(db);
      await repo.tambah(TagihanCompanion.insert(
        nama: 'Listrik',
        jatuhTempo: DateTime(2026, 9, 30),
        jumlahSen: const Value(250000),
      ));
      final listrik = (await db.select(db.tagihan).get()).single;

      await t.binding.setSurfaceSize(const Size(430, 1600));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: DendaTerhindarkanScreen(acuan: DateTime(2026, 9, 21)),
        ),
      ));
      await t.pumpAndSettle();
      expect(t.widget<Text>(find.byKey(const Key('denda_total'))).data, 'Rp 0');
      expect(find.text('Belum diatur'), findsOneWidget);

      // Atur denda 2% lewat dialog.
      await t.ensureVisible(find.byKey(const Key('atur_denda_Listrik')));
      await t.tap(find.byKey(const Key('atur_denda_Listrik')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('denda_persen')), '2');
      await t.tap(find.byKey(const Key('simpan_denda')));
      await t.pumpAndSettle();

      expect(find.text('2% per bulan'), findsOneWidget);

      // Catat pelunasan TEPAT WAKTU hari ini, lalu muat ulang layar.
      await repo.tandaiLunas(listrik.id, tanggalBayar: DateTime.now());
      // Kunci berbeda → State baru, sehingga data dimuat ulang dari awal
      // (tanpa kunci, Flutter memakai ulang State lama yang masih nol).
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: DendaTerhindarkanScreen(
              key: const ValueKey('muat-ulang'), acuan: DateTime.now()),
        ),
      ));
      await t.pumpAndSettle();
      expect(t.widget<Text>(find.byKey(const Key('denda_total'))).data, 'Rp 50',
          reason: '2% dari Rp 2.500');

      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });
  });

  group('FR-35 · Deteksi kenaikan tagihan', () {
    test('butuh minimal 4 pembayaran', () {
      final temuan = deteksiKenaikanTagihan(riwayat: [
        (nama: 'Listrik', tanggalBayar: DateTime(2026, 6, 1), nominalSen: 100000),
        (nama: 'Listrik', tanggalBayar: DateTime(2026, 7, 1), nominalSen: 100000),
        (nama: 'Listrik', tanggalBayar: DateTime(2026, 8, 1), nominalSen: 300000),
      ]);
      expect(temuan, isEmpty);
    });

    test('kenaikan di atas ambang terdeteksi dengan bukti', () {
      final temuan = deteksiKenaikanTagihan(riwayat: [
        (nama: 'Listrik', tanggalBayar: DateTime(2026, 6, 1), nominalSen: 200000),
        (nama: 'Listrik', tanggalBayar: DateTime(2026, 7, 1), nominalSen: 200000),
        (nama: 'Listrik', tanggalBayar: DateTime(2026, 8, 1), nominalSen: 200000),
        (nama: 'Listrik', tanggalBayar: DateTime(2026, 9, 1), nominalSen: 300000),
      ]);
      expect(temuan, hasLength(1));
      expect(temuan.single.nama, 'Listrik');
      expect(temuan.single.rataRataSebelumnyaSen, 200000);
      expect(temuan.single.persenNaik, 50);
      expect(temuan.single.selisihSen, 100000);
      expect(temuan.single.tigaTerakhirSen, [200000, 200000, 200000]);
    });

    test('kenaikan kecil diabaikan (tidak berisik)', () {
      final temuan = deteksiKenaikanTagihan(riwayat: [
        (nama: 'Air', tanggalBayar: DateTime(2026, 6, 1), nominalSen: 150000),
        (nama: 'Air', tanggalBayar: DateTime(2026, 7, 1), nominalSen: 150000),
        (nama: 'Air', tanggalBayar: DateTime(2026, 8, 1), nominalSen: 150000),
        (nama: 'Air', tanggalBayar: DateTime(2026, 9, 1), nominalSen: 152000),
      ], ambangSelisihSen: 100000);
      expect(temuan, isEmpty);
    });

    test('nominal turun tidak pernah dianggap kenaikan', () {
      final temuan = deteksiKenaikanTagihan(riwayat: [
        (nama: 'Internet', tanggalBayar: DateTime(2026, 6, 1), nominalSen: 400000),
        (nama: 'Internet', tanggalBayar: DateTime(2026, 7, 1), nominalSen: 400000),
        (nama: 'Internet', tanggalBayar: DateTime(2026, 8, 1), nominalSen: 400000),
        (nama: 'Internet', tanggalBayar: DateTime(2026, 9, 1), nominalSen: 350000),
      ]);
      expect(temuan, isEmpty);
    });

    testWidgets('layar menampilkan tagihan yang naik beserta angkanya',
        (t) async {
      final repo = TagihanRepository(db);
      await repo.tambah(TagihanCompanion.insert(
        nama: 'Listrik',
        jatuhTempo: DateTime(2026, 9, 1),
        jumlahSen: const Value(200000),
        frekuensi: const Value('sekali'),
      ));
      final listrik = (await db.select(db.tagihan).get()).single;
      // Empat pelunasan dengan nominal naik di akhir.
      for (final nominal in [200000, 200000, 200000, 300000]) {
        await repo.tambah(TagihanCompanion.insert(
          nama: 'Lain',
          jatuhTempo: DateTime(2026, 9, 1),
          jumlahSen: Value(nominal),
          frekuensi: const Value('sekali'),
        ));
      }
      await repo.tandaiLunas(listrik.id, tanggalBayar: DateTime(2026, 6, 1));

      await t.binding.setSurfaceSize(const Size(430, 1200));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: KenaikanTagihanScreen()),
      ));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('kenaikan_ringkas')), findsOneWidget);

      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });
  });
}
