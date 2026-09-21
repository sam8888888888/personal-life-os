/// Uji FR-33 — "Uang aman sampai gajian".
///
/// Yang dibuktikan:
///   * tanggal gajian berikutnya benar, termasuk saat tanggal gajian sudah
///     lewat bulan ini dan saat tanggal 31 jatuh di bulan pendek,
///   * tagihan terlambat yang belum dibayar tetap dihitung & ditandai,
///   * saldo opsional: belum diisi → sisa kosong; diisi → sisa = saldo − total,
///     dan bisa kurang (ditampilkan sebagai "Kurang").
///   * layar: pengaturan disimpan, hitungan tampil sesuai data.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/laporan/aman_sampai_gajian.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/uang/aman_sampai_gajian_screen.dart';

late AppDatabase db;

TagihanData tagihanUji({
  int id = 1,
  String nama = 'Listrik',
  DateTime? jatuhTempo,
  String frekuensi = 'bulanan',
  int? jumlahSen = 100000,
  bool aktif = true,
  bool lunas = false,
}) {
  final t = jatuhTempo ?? DateTime(2026, 9, 25);
  return TagihanData(
    id: id,
    jenis: 'tagihan',
    nama: nama,
    jumlahSen: jumlahSen,
    kodeMataUang: 'IDR',
    jatuhTempo: t,
    frekuensi: frekuensi,
    pengingatLeadHari: '7,3,1',
    pengingatJam: '09:00',
    kanalPengingat: 'push',
    prioritas: 'biasa',
    statusAktif: aktif,
    lunas: lunas,
    dibuatPada: DateTime(2026, 1, 1),
    diubahPada: DateTime(2026, 1, 1),
  );
}

LanggananData langgananUji({
  int id = 1,
  String nama = 'Netflix',
  int nominalSen = 200000,
  String siklus = 'bulanan',
  DateTime? mulai,
  String status = 'aktif',
}) {
  final m = mulai ?? DateTime(2026, 9, 22);
  return LanggananData(
    id: id,
    idLangganan: 'lgn_$id',
    nama: nama,
    nominalSen: nominalSen,
    kodeMataUang: 'IDR',
    siklus: siklus,
    tanggalMulai: m,
    perpanjangOtomatis: true,
    status: status,
    dibuatPada: DateTime(2026, 1, 1),
    diubahPada: DateTime(2026, 1, 1),
  );
}

void main() {
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('FR-33 · Perhitungan', () {
    test('tanggal gajian bulan ini bila belum lewat', () {
      expect(gajianBerikutnya(DateTime(2026, 9, 10), 25), DateTime(2026, 9, 25));
    });

    test('tanggal gajian bulan depan bila bulan ini sudah lewat', () {
      expect(gajianBerikutnya(DateTime(2026, 9, 26), 25), DateTime(2026, 10, 25));
      expect(gajianBerikutnya(DateTime(2026, 9, 25), 25), DateTime(2026, 9, 25),
          reason: 'hari gajian = hari ini, masih dihitung hari ini');
    });

    test('tanggal 31 menyesuaikan bulan pendek (Februari)', () {
      expect(gajianBerikutnya(DateTime(2026, 2, 1), 31), DateTime(2026, 2, 28));
      expect(gajianBerikutnya(DateTime(2028, 2, 1), 31), DateTime(2028, 2, 29),
          reason: '2028 tahun kabisat');
    });

    test('hanya tagihan sampai gajian yang dihitung', () {
      final hasil = hitungAmanSampaiGajian(
        tagihan: [
          tagihanUji(id: 1, nama: 'Listrik', jatuhTempo: DateTime(2026, 9, 24)),
          tagihanUji(id: 2, nama: 'Air', jatuhTempo: DateTime(2026, 9, 27)),
        ],
        hariIni: DateTime(2026, 9, 21),
        tanggalGajian: 25,
      );
      expect(hasil.butir.map((b) => b.nama).toList(), ['Listrik'],
          reason: 'Air jatuh tempo 27 Sep, setelah gajian');
      expect(hasil.totalSen, 100000);
      expect(hasil.hariKeGajian, 4);
    });

    test('tagihan terlambat yang belum dibayar tetap dihitung & ditandai', () {
      final hasil = hitungAmanSampaiGajian(
        tagihan: [
          tagihanUji(id: 1, nama: 'Internet', jatuhTempo: DateTime(2026, 9, 5)),
        ],
        hariIni: DateTime(2026, 9, 21),
        tanggalGajian: 25,
      );
      expect(hasil.sudahLewat.map((b) => b.nama).toList(), ['Internet']);
      expect(hasil.totalSen, 100000);
    });

    test('tagihan terlambat yang sudah lunas tidak dihitung ulang', () {
      final hasil = hitungAmanSampaiGajian(
        tagihan: [
          tagihanUji(
              id: 1,
              nama: 'Internet',
              jatuhTempo: DateTime(2026, 9, 5),
              lunas: true),
        ],
        hariIni: DateTime(2026, 9, 21),
        tanggalGajian: 25,
      );
      expect(hasil.sudahLewat, isEmpty);
      expect(hasil.butir, isEmpty);
    });

    test('langganan aktif ikut dihitung, langganan berhenti tidak', () {
      final hasil = hitungAmanSampaiGajian(
        tagihan: const [],
        langganan: [
          langgananUji(id: 1, nama: 'Netflix', mulai: DateTime(2026, 9, 22)),
          langgananUji(id: 2, nama: 'Spotify', status: 'berhenti',
              mulai: DateTime(2026, 9, 22)),
        ],
        hariIni: DateTime(2026, 9, 21),
        tanggalGajian: 25,
      );
      expect(hasil.butir.map((b) => b.nama).toList(), ['Netflix']);
      expect(hasil.jumlahButir, 1);
    });

    test('saldo opsional: belum diisi → sisa null; diisi → sisa dihitung', () {
      final tanpaSaldo = hitungAmanSampaiGajian(
        tagihan: [tagihanUji(jatuhTempo: DateTime(2026, 9, 24))],
        hariIni: DateTime(2026, 9, 21),
        tanggalGajian: 25,
      );
      expect(tanpaSaldo.saldoSen, isNull);
      expect(tanpaSaldo.sisaSen, isNull);

      final denganSaldo = hitungAmanSampaiGajian(
        tagihan: [tagihanUji(jatuhTempo: DateTime(2026, 9, 24))],
        hariIni: DateTime(2026, 9, 21),
        tanggalGajian: 25,
        saldoSen: 250000,
      );
      expect(denganSaldo.totalSen, 100000);
      expect(denganSaldo.sisaSen, 150000);

      final kurang = hitungAmanSampaiGajian(
        tagihan: [tagihanUji(jatuhTempo: DateTime(2026, 9, 24))],
        hariIni: DateTime(2026, 9, 21),
        tanggalGajian: 25,
        saldoSen: 50000,
      );
      expect(kurang.sisaSen, -50000);
    });

    test('tanpa tagihan → total nol, daftar kosong', () {
      final hasil = hitungAmanSampaiGajian(
        tagihan: const [],
        hariIni: DateTime(2026, 9, 21),
        tanggalGajian: 25,
      );
      expect(hasil.jumlahButir, 0);
      expect(hasil.totalSen, 0);
    });
  });

  group('FR-33 · Layar', () {
    testWidgets('menyimpan tanggal gajian & saldo lalu menampilkan sisa',
        (t) async {
      final repo = TagihanRepository(db);
      await repo.tambah(TagihanCompanion.insert(
        nama: 'Listrik',
        jatuhTempo: DateTime(2026, 9, 24),
        jumlahSen: const Value(100000),
      ));

      await t.binding.setSurfaceSize(const Size(430, 1400));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: AmanSampaiGajianScreen(hariIni: DateTime(2026, 9, 21)),
        ),
      ));
      await t.pumpAndSettle();

      expect(t.widget<Text>(find.byKey(const Key('gajian_total'))).data,
          'Rp 1.000');
      expect(find.textContaining('Isi saldo sekarang'), findsOneWidget);

      // Isi saldo lalu simpan.
      await t.enterText(find.byKey(const Key('input_saldo')), '250000');
      await t.tap(find.byKey(const Key('simpan_pengaturan_gajian')));
      await t.pumpAndSettle();

      // Saldo diisi 250000 rupiah (Rp 250.000) − tagihan Rp 1.000 = Rp 249.000
      expect(t.widget<Text>(find.byKey(const Key('gajian_sisa'))).data,
          'Sisa Rp 249.000 setelah tagihan dibayar');

      // Pengaturan benar-benar tersimpan di basis data.
      final tersimpan = await (db.select(db.pengaturan)
            ..where((p) => p.kunci.equals(kunciTanggalGajian)))
          .getSingle();
      expect(tersimpan.nilai, '25');
      final saldoTersimpan = await (db.select(db.pengaturan)
            ..where((p) => p.kunci.equals(kunciSaldoSekarang)))
          .getSingle();
      expect(saldoTersimpan.nilai, '25000000', reason: 'disimpan dalam sen');

      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('saldo tidak bisa dibaca → pesan jelas, tidak tersimpan',
        (t) async {
      await t.binding.setSurfaceSize(const Size(430, 1400));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: AmanSampaiGajianScreen(hariIni: DateTime(2026, 9, 21)),
        ),
      ));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const Key('input_saldo')), 'dua juta');
      await t.tap(find.byKey(const Key('simpan_pengaturan_gajian')));
      await t.pumpAndSettle();

      expect(find.textContaining('Angka saldo belum bisa dibaca'), findsOneWidget);
      final ada = await (db.select(db.pengaturan)
            ..where((p) => p.kunci.equals(kunciSaldoSekarang)))
          .getSingleOrNull();
      expect(ada, isNull, reason: 'saldo tidak sah tidak disimpan');

      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });
  });
}
