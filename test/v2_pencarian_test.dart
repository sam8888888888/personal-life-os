/// FR-139 — Search Everything (pencarian satu pintu) — uji repositori & layar.
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/pencarian/model_hasil_cari.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pencarian_repository.dart';
import 'package:personal_life_os/features/cari/pencarian_screen.dart';

late AppDatabase db;
late PencarianRepository repo;

/// Isi data contoh lintas modul (v3 + v4).
Future<void> isiContoh() async {
  // Buang dulu 6 template perawatan bawaan (di-seed saat database dibuat)
  // supaya jumlah hasil pencarian pasti — bukan menebak isi seed.
  await db.delete(db.perawatan).go();
  // Buang juga kategori bawaan (mis. "Pencairan Dana" memuat kata "air").
  await db.delete(db.kategoriTransaksi).go();
  await db.into(db.tagihan).insert(TagihanCompanion.insert(
      nama: 'Internet rumah', jatuhTempo: DateTime(2026, 9, 20)));
  await db.into(db.tagihan).insert(TagihanCompanion.insert(
      nama: 'Tagihan air PDAM', jatuhTempo: DateTime(2026, 9, 18)));
  // Kode unik: `kel_makan` sudah di-seed otomatis saat database dibuat.
  await db.into(db.kategoriTransaksi).insert(KategoriTransaksiCompanion.insert(
      kode: 'kel_uji_camilan', nama: 'Kopi & camilan'));
  await db.into(db.transaksi).insert(TransaksiCompanion.insert(
      idTransaksi: 'trx_1',
      tanggal: DateTime(2026, 9, 14),
      jumlahSen: 4500000,
      catatan: const Value('Nasi goreng enak')));
  await db.into(db.kebiasaan).insert(
      KebiasaanCompanion.insert(idKebiasaan: 'kb_1', nama: 'Minum air putih'));
  await db.into(db.tugas).insert(TugasCompanion.insert(
      idTugas: 'tg_1',
      nama: 'Bayar tagihan air',
      jatuhTempo: Value(DateTime(2026, 9, 18))));
  await db.into(db.tugas).insert(
      TugasCompanion.insert(idTugas: 'tg_2', nama: 'Servis AC kamar'));
  await db.into(db.perawatan).insert(PerawatanCompanion.insert(
      nama: 'Servis AC tahunan', berikutnya: DateTime(2026, 12, 1)));
  await db.into(db.obat).insert(
      ObatCompanion.insert(nama: 'Vitamin D', catatan: const Value('sehabis makan')));
  await db.into(db.dokumen).insert(DokumenCompanion.insert(
      idDokumen: 'dok_1',
      nama: 'Paspor keluarga',
      nomor: const Value('A1234567')));
  await db.into(db.logDzikir).insert(LogDzikirCompanion.insert(
      tanggal: DateTime(2026, 9, 15), jenis: 'pagi', nama: 'Dzikir pagi'));
  await db.into(db.refleksiMuhasabah).insert(RefleksiMuhasabahCompanion.insert(
      tanggal: DateTime(2026, 9, 15),
      catatan: const Value('Hari ini belajar sabar')));
}

Future<void> tambahTugasUji(int n) async {
  for (var i = 1; i <= n; i++) {
    await db.into(db.tugas).insert(
        TugasCompanion.insert(idTugas: 'tg_banyak_$i', nama: 'Tugas uji $i'));
  }
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = PencarianRepository(db);
  });

  tearDown(() async => db.close());

  group('FR-139 pencarian lintas modul', () {
    test('kata kosong / spasi -> tidak ada hasil (bukan semua baris)',
        () async {
      await isiContoh();
      expect((await repo.cari('')).hasil, isEmpty);
      expect((await repo.cari('   ')).hasil, isEmpty);
      expect((await repo.cari('')).kosong, isTrue);
    });

    test('menemukan tagihan tanpa membedakan huruf besar/kecil', () async {
      await isiContoh();
      final hasil = await repo.cari('INTERNET');
      expect(hasil.hasil, hasLength(1));
      expect(hasil.hasil.single.judul, 'Internet rumah');
      expect(hasil.hasil.single.modul, ModulHasil.tagihan);
      expect(hasil.hasil.single.keterangan, 'Tagihan');
      expect(hasil.hasil.single.rute, '/tagihan');
    });

    test('satu kata kunci menemukan beberapa modul sekaligus', () async {
      await isiContoh();
      final hasil = await repo.cari('air');
      // tagihan "Tagihan air PDAM", tugas "Bayar tagihan air",
      // kebiasaan "Minum air putih".
      expect(hasil.hasil, hasLength(3));
      expect(hasil.jumlahPerModul[ModulHasil.tagihan], 1);
      expect(hasil.jumlahPerModul[ModulHasil.aksi], 2);
      final judul = hasil.hasil.map((h) => h.judul).toSet();
      expect(judul, containsAll(<String>['Tagihan air PDAM', 'Minum air putih']));
    });

    test('mencari nama kategori transaksi', () async {
      await isiContoh();
      final hasil = await repo.cari('camilan');
      expect(hasil.hasil, hasLength(1));
      expect(hasil.hasil.single.modul, ModulHasil.uang);
      expect(hasil.hasil.single.keterangan, 'Kategori transaksi');
      expect(hasil.hasil.single.rute, '/uang/transaksi');
    });

    test('mencari catatan transaksi & menyebut tanggalnya', () async {
      await isiContoh();
      final hasil = await repo.cari('nasi goreng');
      expect(hasil.hasil, hasLength(1));
      expect(hasil.hasil.single.judul, 'Nasi goreng enak');
      expect(hasil.hasil.single.keterangan, 'Transaksi 14/09/2026');
      expect(hasil.hasil.single.rute, '/uang/transaksi');
    });

    test('menjangkau tabel skema v4 (dokumen, obat, kebiasaan, dzikir, muhasabah)',
        () async {
      await isiContoh();
      expect((await repo.cari('paspor')).hasil.single.rute, '/dokumen');
      expect((await repo.cari('A1234567')).hasil.single.judul, 'Paspor keluarga');
      expect((await repo.cari('vitamin')).hasil.single.modul,
          ModulHasil.kesehatan);
      expect((await repo.cari('minum air putih')).hasil.single.judul,
          'Minum air putih');
      expect((await repo.cari('minum air putih')).hasil.single.rute,
          '/aksi/kebiasaan');
      expect((await repo.cari('dzikir')).hasil.single.rute, '/ibadah/dzikir');
      expect((await repo.cari('sabar')).hasil.single.modul, ModulHasil.ibadah);
      expect((await repo.cari('sabar')).hasil.single.keterangan,
          'Muhasabah 15/09/2026');
    });

    test('perawatan menyebut jadwal berikutnya', () async {
      await isiContoh();
      final hasil = await repo.cari('servis ac');
      // Dua hasil: tugas "Servis AC kamar" + perawatan "Servis AC tahunan".
      expect(hasil.hasil, hasLength(2));
      final perawatan = hasil.hasil
          .firstWhere((h) => h.keterangan.startsWith('Perawatan'));
      expect(perawatan.keterangan, 'Perawatan · berikutnya 01/12/2026');
    });

    test('batas per tabel dijaga supaya satu tabel tidak menenggelamkan modul',
        () async {
      await tambahTugasUji(12);
      final hasil = await repo.cari('tugas uji');
      expect(hasil.hasil, hasLength(PencarianRepository.batasPerModul));
    });

    test('batasTotal menahan jumlah keseluruhan', () async {
      await tambahTugasUji(6);
      final hasil = await repo.cari('tugas uji', batasTotal: 3);
      expect(hasil.hasil, hasLength(3));
    });

    test('aksara LIKE (%) dicari sebagai huruf biasa', () async {
      await db.into(db.tagihan).insert(TagihanCompanion.insert(
          nama: 'Diskon 50% khusus', jatuhTempo: DateTime(2026, 9, 25)));
      await db.into(db.tagihan).insert(TagihanCompanion.insert(
          nama: 'Diskon 5000 khusus', jatuhTempo: DateTime(2026, 9, 26)));

      final persen = await repo.cari('50%');
      expect(persen.hasil, hasLength(1));
      expect(persen.hasil.single.judul, 'Diskon 50% khusus');

      // '%' sendirian hanya cocok pada baris yang benar-benar memuat '%'.
      final semua = await repo.cari('%');
      expect(semua.hasil, hasLength(1));

      // '_' juga bukan pengganti sembarang huruf.
      expect((await repo.cari('50_')).hasil, isEmpty);
    });

    test('tidak ada hasil -> daftar kosong, bukan galat', () async {
      await isiContoh();
      final hasil = await repo.cari('zzz tidak ada');
      expect(hasil.kosong, isTrue);
      expect(hasil.kata, 'zzz tidak ada');
    });
  });

  group('FR-139 layar pencarian', () {
    Future<void> tampilkan(WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      await t.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: PencarianScreen(
              repo: PencarianRepository(db), tundaKetik: Duration.zero),
        ),
      ));
      await t.pump();
    }

    Future<void> tulisDanTunggu(WidgetTester t, String kata) async {
      await t.enterText(find.byKey(const Key('kata_cari')), kata);
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 40));
      }
    }

    Set<String> teksTampil(WidgetTester t) => t
        .widgetList<Text>(find.byType(Text))
        .map((Text w) => w.data ?? '')
        .where((String s) => s.isNotEmpty)
        .toSet();

    testWidgets('keadaan awal meminta kata kunci, bukan hasil kosong',
        (WidgetTester t) async {
      await isiContoh();
      await tampilkan(t);
      expect(find.byKey(const Key('pencarian_kosong')), findsOneWidget);
      expect(find.text('Ketik kata kunci untuk mencari.'), findsOneWidget);
      expect(find.byKey(const Key('jumlah_hasil')), findsNothing);
      expect(t.takeException(), isNull);
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('mengetik menampilkan hasil per modul', (WidgetTester t) async {
      await isiContoh();
      await tampilkan(t);
      await tulisDanTunggu(t, 'air');
      expect(find.byKey(const Key('jumlah_hasil')), findsOneWidget);
      expect(find.text('3 hasil untuk "air"'), findsOneWidget);
      expect(find.byKey(const Key('grup_aksi')), findsOneWidget);
      expect(find.text('Minum air putih'), findsOneWidget);
      expect(find.text('Tagihan air PDAM'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('kata tanpa hasil dijelaskan apa adanya', (WidgetTester t) async {
      await isiContoh();
      await tampilkan(t);
      await tulisDanTunggu(t, 'zzz');
      expect(find.text('Tidak ada hasil untuk "zzz".'), findsOneWidget);
      expect(find.text('Belum ada data yang cocok.'), findsOneWidget);
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('bahasa layar bebas kata terlarang & jujur soal batas pencarian',
        (WidgetTester t) async {
      await isiContoh();
      await tampilkan(t);
      await tulisDanTunggu(t, 'air');

      final kumpulan = teksTampil(t);
      const kataTerlarang = <String>[
        'kamu',
        'gagal',
        'skor',
        'peringkat',
        'wajib anda',
        'malas',
      ];
      for (final String teks in kumpulan) {
        for (final String kata in kataTerlarang) {
          expect(teks.toLowerCase().contains(kata), isFalse,
              reason: '"$teks" memuat kata terlarang "$kata"');
        }
      }
      expect(kumpulan.any((s) => s.contains('Isi berkas')), isTrue,
          reason: 'batas pencarian harus disebut jujur');
      await t.binding.setSurfaceSize(null);
    });
  });
}
