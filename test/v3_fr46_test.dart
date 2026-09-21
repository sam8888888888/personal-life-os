/// Uji FR-46 — deteksi tagihan yang berhenti muncul (pelengkap FR-70).
///
/// Yang dibuktikan:
///   * tagihan bulanan yang catatannya berhenti ≥ 2 siklus terdeteksi, lengkap
///     dengan bukti (tanggal terakhir dibayar + jumlah pembayaran),
///   * tagihan yang masih rutin / baru telat satu siklus TIDAK dicurigai,
///   * tagihan sekali jalan, nonaktif, dan yang sudah lunas tidak diikutkan,
///   * tagihan yang belum pernah dibayar tapi siklusnya sudah lewat 2× juga
///     terdeteksi (sebab berbeda),
///   * panjang siklus mengikuti frekuensi (mingguan vs bulanan),
///   * layar Langganan menampilkan panelnya dan tombol "Matikan pengingatnya"
///     benar-benar menonaktifkan tagihan (bukan menghapusnya).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/laporan/tagihan_berhenti.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/uang/langganan/langganan_screen.dart';

late AppDatabase db;
late TagihanRepository repo;

/// Waktu patok uji: 20 November 2026, 08.00.
final sekarang = DateTime(2026, 11, 20, 8);

Future<TagihanData> buatTagihan({
  required String nama,
  required DateTime jatuhTempo,
  String frekuensi = 'bulanan',
  int? jumlahSen = 200000,
  bool lunas = false,
}) async {
  final t = await repo.tambah(TagihanCompanion.insert(
    nama: nama,
    jatuhTempo: jatuhTempo,
    frekuensi: Value(frekuensi),
    jumlahSen: Value(jumlahSen),
  ));
  if (lunas) await repo.tandaiLunas(t.id);
  return (await (db.select(db.tagihan)..where((x) => x.id.equals(t.id)))
      .getSingle());
}

Future<void> catatBayar(int tagihanId, DateTime tanggal,
    {DateTime? periode}) async {
  await db.into(db.riwayatPembayaran).insert(RiwayatPembayaranCompanion.insert(
        tagihanId: tagihanId,
        periodeJatuhTempo: periode ?? tanggal,
        jumlahSen: 200000,
        tanggalBayar: tanggal,
      ));
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TagihanRepository(db);
  });

  tearDown(() async => db.close());

  group('pendeteksi', () {
    test('bulanan berhenti 2 siklus → terdeteksi dengan bukti', () async {
      final t = await buatTagihan(
          nama: 'Netflix', jatuhTempo: DateTime(2026, 11, 5));
      // Terakhir dibayar 5 Agustus (3 siklus lalu).
      await catatBayar(t.id, DateTime(2026, 8, 5), periode: DateTime(2026, 8, 5));
      await catatBayar(t.id, DateTime(2026, 7, 5), periode: DateTime(2026, 7, 5));

      final temuan = deteksiTagihanBerhenti(
        tagihan: await repo.ambilSemua(),
        riwayat: [(tagihanId: t.id, tanggalBayar: DateTime(2026, 8, 5))],
        sekarang: sekarang,
      );

      expect(temuan, hasLength(1));
      expect(temuan.first.nama, 'Netflix');
      expect(temuan.first.sebab, SebabBerhenti.terputus);
      expect(temuan.first.siklusTerlewat, 3);
      expect(temuan.first.jumlahPembayaran, 1);
      expect(temuan.first.ringkas, contains('Terakhir dibayar'));
      expect(temuan.first.nilaiPenting, contains('1 pembayaran'));
    });

    test('masih rutin (1 siklus) → tidak dicurigai', () async {
      final t = await buatTagihan(
          nama: 'Spotify', jatuhTempo: DateTime(2026, 11, 10));
      final temuan = deteksiTagihanBerhenti(
        tagihan: await repo.ambilSemua(),
        riwayat: [(tagihanId: t.id, tanggalBayar: DateTime(2026, 10, 25))],
        sekarang: sekarang,
      );
      expect(panjangSiklusHari(t), 30);
      expect(temuan, isEmpty);
    });

    test('dagang akhir pekan: mingguan vs bulanan beda panjang siklus',
        () async {
      final mingguan = await buatTagihan(
          nama: 'Langganan koran',
          jatuhTempo: DateTime(2026, 11, 1),
          frekuensi: 'mingguan');
      expect(panjangSiklusHari(mingguan), 7);

      final bulanan = await buatTagihan(
          nama: 'Iuran keamanan', jatuhTempo: DateTime(2026, 11, 1));
      expect(panjangSiklusHari(bulanan), 30);

      // Mingguan: terakhir bayar 1 Nov, sekarang 20 Nov = 2 siklus (19/7 = 2).
      final temuan = deteksiTagihanBerhenti(
        tagihan: await repo.ambilSemua(),
        riwayat: [(tagihanId: mingguan.id, tanggalBayar: DateTime(2026, 11, 1))],
        sekarang: sekarang,
      );
      expect(temuan.map((e) => e.tagihanId), contains(mingguan.id));
      // Bulanan yang sama-sama terakhir 1 Nov: baru 19 hari → belum 2 siklus.
      expect(temuan.map((e) => e.tagihanId), isNot(contains(bulanan.id)));
    });

    test('belum pernah dibayar & siklus lewat → terdeteksi (sebab berbeda)',
        () async {
      final t = await buatTagihan(
          nama: 'Iuran sampah', jatuhTempo: DateTime(2026, 9, 1));
      final temuan = deteksiTagihanBerhenti(
        tagihan: await repo.ambilSemua(),
        riwayat: const [],
        sekarang: sekarang,
      );
      expect(temuan, hasLength(1));
      expect(temuan.first.tagihanId, t.id);
      expect(temuan.first.sebab, SebabBerhenti.belumPernahDibayar);
      expect(temuan.first.jumlahPembayaran, 0);
      expect(temuan.first.ringkas, contains('Belum pernah ada catatan'));
    });

    test('sekali jalan, nonaktif, & lunas tidak diikutkan', () async {
      await buatTagihan(
          nama: 'Pajak tahunan',
          jatuhTempo: DateTime(2026, 3, 1),
          frekuensi: 'sekali');
      final nonaktif = await buatTagihan(
          nama: 'Gym', jatuhTempo: DateTime(2026, 3, 1));
      await repo.nonaktifkan(nonaktif.id);
      // Catatan: melunasi tagihan berulang membuat periode berikutnya dibuat
      // otomatis (tidak lagi lunas) — jadi statusnya diset langsung di sini.
      final kartu = await buatTagihan(
          nama: 'Kartu kredit lama', jatuhTempo: DateTime(2026, 3, 1));
      await repo.tandaiLunas(kartu.id);
      await (db.update(db.tagihan)..where((x) => x.id.equals(kartu.id)))
          .write(const TagihanCompanion(lunas: Value(true)));

      final temuan = deteksiTagihanBerhenti(
        tagihan: await repo.ambilSemua(),
        riwayat: const [],
        sekarang: sekarang,
      );
      expect(temuan, isEmpty);
    });

    test('temuan diurutkan dari yang paling lama berhenti', () async {
      final lama = await buatTagihan(
          nama: 'Majalah', jatuhTempo: DateTime(2026, 1, 5));
      final baru = await buatTagihan(
          nama: 'Kopi langganan', jatuhTempo: DateTime(2026, 8, 5));
      final temuan = deteksiTagihanBerhenti(
        tagihan: await repo.ambilSemua(),
        riwayat: const [],
        sekarang: sekarang,
      );
      expect(temuan.map((e) => e.tagihanId), [lama.id, baru.id]);
    });
  });

  group('layar Langganan', () {
    testWidgets('panel muncul & tombol matikan pengingat bekerja', (t) async {
      final tagihan = await buatTagihan(
          nama: 'Netflix', jatuhTempo: DateTime(2026, 11, 5));
      await catatBayar(tagihan.id, DateTime(2026, 8, 5));

      await t.binding.setSurfaceSize(const Size(420, 900));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: LanggananScreen(jamSekarang: () => sekarang),
        ),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));

      final panel = find.byKey(const Key('panel_tagihan_berhenti'));
      expect(panel, findsOneWidget);
      await t.scrollUntilVisible(find.byKey(Key('berhenti_${tagihan.id}')), 260,
          scrollable: find.byType(Scrollable).first, maxScrolls: 40);
      await t.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Netflix'), findsWidgets);
      expect(find.textContaining('Terakhir dibayar'), findsOneWidget);

      await t.tap(find.byKey(Key('matikan_pengingat_${tagihan.id}')));
      await t.pump(const Duration(milliseconds: 200));
      await t.pump(const Duration(seconds: 5));

      final sesudah = await (db.select(db.tagihan)
            ..where((x) => x.id.equals(tagihan.id)))
          .getSingle();
      expect(sesudah.statusAktif, isFalse, reason: 'pengingat dimatikan');
      // Datanya tetap ada, bukan dihapus.
      expect(sesudah.nama, 'Netflix');

      await t.pump(const Duration(seconds: 10));
      await t.pumpWidget(const SizedBox.shrink());
      // Membongkar provider menutup langganan stream drift, dan drift menjadwalkan
      // satu timer nol-detik saat itu — beri kesempatan timer itu berbunyi.
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      await t.binding.setSurfaceSize(null);
    });
  });
}
