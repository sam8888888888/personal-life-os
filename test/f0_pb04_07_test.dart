/// Uji F0 lanjutan — PB-04, PB-05, PB-06, PB-07.
///
/// PB-04: "Tunda 1 jam" tidak hilang saat jadwal disinkronkan.
/// PB-05: satu tagihan = satu pembayaran per periode (dijaga database).
/// PB-06: `tandaiLunas()` idempoten (tidak menggandakan riwayat/rollover).
/// PB-07: pemasukan bulanan unik + upsert atomic.
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/notifikasi/jejak.dart';
import 'package:personal_life_os/core/notifikasi/perencana_pengingat.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';

late AppDatabase db;
late TagihanRepository repo;
late PengaturanRepository repoPengaturan;

Future<int> buatTagihan({DateTime? jatuhTempo, String frekuensi = 'bulanan'}) async {
  final t = await repo.tambah(TagihanCompanion.insert(
    nama: 'Listrik PLN',
    jumlahSen: const Value(15000000),
    jatuhTempo: jatuhTempo ?? DateTime(2026, 9, 15),
    frekuensi: Value(frekuensi),
  ));
  return t.id;
}

void main() {
  setUp(() async {
    penentuJejak = () async => null;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TagihanRepository(db);
    repoPengaturan = PengaturanRepository(db);
  });

  tearDown(() async => db.close());

  group('PB-04 — pengingat "Tunda 1 jam" bertahan saat sinkronisasi', () {
    test('tunda milik tagihan yang masih ada di rencana DIPERTAHANKAN', () {
      final buang = idJadwalDibatalkan(
        tertunda: [idNotifikasi(7, slotTunda), idNotifikasi(7, 0), 999999],
        rencana: [idNotifikasi(7, 0)],
        tagihanRencana: [7],
      );
      expect(buang, isNot(contains(idNotifikasi(7, slotTunda))),
          reason: 'tunda tidak boleh dibatalkan oleh sinkronisasi');
      expect(buang, contains(999999), reason: 'jadwal asing tetap dibatalkan');
    });

    test('jadwal yang masih ada di rencana tidak dibatalkan', () {
      final id = idNotifikasi(3, 2);
      final buang = idJadwalDibatalkan(
        tertunda: [id],
        rencana: [id],
        tagihanRencana: [3],
      );
      expect(buang, isEmpty);
    });

    test('tunda milik tagihan yang sudah tidak ada tetap dibatalkan', () {
      final buang = idJadwalDibatalkan(
        tertunda: [idNotifikasi(9, slotTunda)],
        rencana: const [],
        tagihanRencana: const [],
      );
      expect(buang, contains(idNotifikasi(9, slotTunda)));
    });
  });

  group('PB-05 & PB-06 — integritas pembayaran', () {
    test('PB-06: dua tandaiLunas berurutan → satu riwayat & satu rollover',
        () async {
      final id = await buatTagihan(jatuhTempo: DateTime(2026, 9, 15));

      await repo.tandaiLunas(id,
          tanggalBayar: DateTime(2026, 9, 10),
          periodeYangDibayar: DateTime(2026, 9, 15));
      final kedua = await repo.tandaiLunas(id,
          tanggalBayar: DateTime(2026, 9, 10),
          periodeYangDibayar: DateTime(2026, 9, 15));
      expect(kedua.periodeJatuhTempo, DateTime(2026, 9, 15),
          reason: 'ketukan kedua mengembalikan catatan periode itu, bukan bikin baru');

      final riwayat = await db.select(db.riwayatPembayaran).get();
      expect(riwayat, hasLength(1), reason: 'riwayat tidak boleh bertambah');
      final t = await (db.select(db.tagihan)..where((x) => x.id.equals(id))).getSingle();
      expect(t.jatuhTempo, DateTime(2026, 10, 15),
          reason: 'periode tidak boleh maju dua kali');
    });

    test('PB-06b: aksi untuk periode lama yang belum pernah dibayar ditolak',
        () async {
      final id = await buatTagihan(jatuhTempo: DateTime(2026, 9, 15));
      await expectLater(
        repo.tandaiLunas(id,
            tanggalBayar: DateTime(2026, 10, 20),
            periodeYangDibayar: DateTime(2026, 8, 15)), // periode asing
        throwsA(isA<StateError>()),
      );
      expect(await db.select(db.riwayatPembayaran).get(), isEmpty);
    });

    test('PB-05: dua riwayat untuk periode yang sama ditolak oleh database',
        () async {
      final id = await buatTagihan(jatuhTempo: DateTime(2026, 9, 15));
      final periode = DateTime(2026, 9, 15);

      Future<void> simpanRiwayat() => db.into(db.riwayatPembayaran).insert(
            RiwayatPembayaranCompanion.insert(
              tagihanId: id,
              periodeJatuhTempo: periode,
              jumlahSen: 15000000,
              tanggalBayar: DateTime(2026, 9, 10),
            ),
          );

      await simpanRiwayat();
      await expectLater(simpanRiwayat(), throwsA(anything));

      final riwayat = await db.select(db.riwayatPembayaran).get();
      expect(riwayat, hasLength(1));
    });
  });

  group('PB-07 — pemasukan bulanan', () {
    test('dua penyimpanan untuk bulan yang sama → satu baris, nilai terbaru',
        () async {
      await repoPengaturan.simpanPemasukan(DateTime(2026, 9, 1), 100000);
      await repoPengaturan.simpanPemasukan(DateTime(2026, 9, 20), 250000);

      final baris = await db.select(db.pemasukanBulanan).get();
      expect(baris, hasLength(1), reason: 'satu bulan = satu baris');
      expect(baris.first.bulan, '2026-09');
      expect(baris.first.jumlahSen, 250000);
    });

    test('bulan berbeda tetap baris terpisah', () async {
      await repoPengaturan.simpanPemasukan(DateTime(2026, 9, 1), 100000);
      await repoPengaturan.simpanPemasukan(DateTime(2026, 10, 1), 200000);
      expect(await db.select(db.pemasukanBulanan).get(), hasLength(2));
    });
  });
}
