/// Uji FR-36 — Skor Disiplin Tagihan lokal.
///
/// Yang dibuktikan: rumus skor terbuka (70% ketepatan + 30% rentetan),
/// rentetan dihitung mundur dan berhenti pada pelunasan lewat jatuh tempo,
/// capaian muncul pada ambang yang benar, dan tidak ada kata menghakimi.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/laporan/skor_disiplin.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/laporan/skor_disiplin_screen.dart';

late AppDatabase db;

void main() {
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('FR-36 · Perhitungan skor', () {
    test('tanpa riwayat → skor 0, rentetan 0, tanpa capaian', () {
      final h = hitungSkorDisiplin(const []);
      expect(h.skor, 0);
      expect(h.streak, 0);
      expect(h.adaRiwayat, isFalse);
      expect(h.capaian, isEmpty);
    });

    test('semua tepat waktu & rentetan 10 → skor penuh 100', () {
      final riwayat = [
        for (var i = 0; i < 10; i++)
          (
            tepatWaktu: true,
            tanggalBayar: DateTime(2026, 1, 1).add(Duration(days: i * 30))
          ),
      ];
      final h = hitungSkorDisiplin(riwayat, acuan: DateTime(2026, 12, 1));
      expect(h.streak, 10);
      expect(h.persenTepatWaktu, 100);
      expect(h.skor, 100);
      expect(h.capaian.map((c) => c.judul), contains('Sepuluh tanpa jeda'));
    });

    test('rentetan berhenti pada pelunasan lewat jatuh tempo', () {
      final riwayat = [
        (tepatWaktu: true, tanggalBayar: DateTime(2026, 9, 20)),
        (tepatWaktu: true, tanggalBayar: DateTime(2026, 8, 20)),
        (tepatWaktu: false, tanggalBayar: DateTime(2026, 7, 25)),
        (tepatWaktu: true, tanggalBayar: DateTime(2026, 6, 20)),
      ];
      expect(hitungStreak(riwayat), 2);
      final h = hitungSkorDisiplin(riwayat, acuan: DateTime(2026, 9, 21));
      expect(h.streak, 2);
      // 70% × 75% + 30% × (2/10) = 52,5 + 6 = 58,5 → 59
      expect(h.skor, 59);
      expect(h.lewatJatuhTempo, 1);
    });

    test('rentetan dihitung maksimal 10 untuk skor', () {
      final riwayat = [
        for (var i = 0; i < 25; i++)
          (
            tepatWaktu: i != 0,
            tanggalBayar: DateTime(2026, 1, 1).add(Duration(days: i * 7))
          ),
      ];
      final h = hitungSkorDisiplin(riwayat, acuan: DateTime(2026, 12, 1));
      expect(h.streak, 24);
      expect(h.streakUntukSkor, 10);
      expect(h.skor, greaterThan(90));
    });

    test('capaian muncul pada ambang yang benar', () {
      final tiga = hitungSkorDisiplin([
        (tepatWaktu: true, tanggalBayar: DateTime(2026, 9, 20)),
        (tepatWaktu: true, tanggalBayar: DateTime(2026, 8, 20)),
        (tepatWaktu: true, tanggalBayar: DateTime(2026, 7, 20)),
      ], acuan: DateTime(2026, 9, 21));
      expect(tiga.capaian.map((c) => c.judul), contains('Rentetan 3×'));
      expect(tiga.capaian.map((c) => c.judul),
          contains('Bulan ini tuntas tepat waktu'));
    });

    test('bahasa penjelasan terbuka & tidak menghakimi', () {
      final h = hitungSkorDisiplin([
        (tepatWaktu: false, tanggalBayar: DateTime(2026, 9, 25)),
      ], acuan: DateTime(2026, 9, 26));
      expect(h.penjelasan, contains('70%'));
      expect(h.penjelasan, contains('30%'));
      expect(h.penjelasan.toLowerCase(), isNot(contains('gagal')));
      expect(h.penjelasan.toLowerCase(), isNot(contains('hukum')));
    });

    testWidgets('layar menampilkan skor, rentetan, capaian & disclaimer',
        (t) async {
      final repo = TagihanRepository(db);
      for (var i = 0; i < 3; i++) {
        await repo.tambah(TagihanCompanion.insert(
          nama: 'Listrik ${i + 1}',
          jatuhTempo: DateTime(2026, 7 + i, 20),
          jumlahSen: const Value(250000),
        ));
      }
      final semua = await db.select(db.tagihan).get();
      for (final tg in semua) {
        await repo.tandaiLunas(tg.id, tanggalBayar: tg.jatuhTempo);
      }

      await t.binding.setSurfaceSize(const Size(430, 1400));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: SkorDisiplinScreen(acuan: DateTime(2026, 9, 21))),
      ));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('skor_angka')), findsOneWidget);
      expect(find.byKey(const Key('skor_streak')), findsOneWidget);
      expect(find.byKey(const Key('skor_penjelasan')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('skor_disclaimer'))).data,
          contains('BUKAN skor kredit'));

      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });
  });
}
