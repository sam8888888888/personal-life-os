/// Uji FR-25 — Ekspor CSV (tagihan & riwayat pembayaran).
///
/// Yang dibuktikan:
/// 1. Isi CSV benar: judul kolom, pemisah `;`, tanggal `YYYY-MM-DD`, uang dalam
///    sen + versi terbaca, dan sel yang memuat `;`/kutip diamankan.
/// 2. Ekspor sungguhan (database + folder sungguhan) menulis DUA berkas dan
///    isinya sesuai data — fungsi `eksporSemuaCsv` inilah yang dipanggil layar.
/// 3. Layar menampilkan penjelasan & tombolnya ada.
///
/// Catatan: uji layar sengaja ringkas — di uji widget waktu berjalan "palsu",
/// sehingga penulisan berkas tidak selesai; karena itu jalur ekspor diuji di
/// uji biasa (waktu nyata), bukan lewat menekan tombol.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/laporan/ekspor_csv.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/tagihan/ekspor_csv_screen.dart';

late AppDatabase db;
late Directory folderUji;

void main() {
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    folderUji = await Directory.systemTemp.createTemp('ekspor_csv_uji');
  });

  tearDown(() async {
    await db.close();
    if (await folderUji.exists()) await folderUji.delete(recursive: true);
  });

  group('Isi CSV', () {
    test('rupiahDariSen menulis bilangan dengan koma desimal & titik ribuan', () {
      expect(rupiahDariSen(0), '0,00');
      expect(rupiahDariSen(50), '0,50');
      expect(rupiahDariSen(100000), '1.000,00');
      expect(rupiahDariSen(123456789), '1.234.567,89');
      expect(rupiahDariSen(-250), '-2,50');
    });

    test('selCsv mengamankan pemisah, kutip, dan baris baru', () {
      expect(selCsv('biasa'), 'biasa');
      expect(selCsv('ada;titik'), '"ada;titik"');
      expect(selCsv('ada"kutip'), '"ada""kutip"');
      expect(selCsv('dua\nbaris'), '"dua\nbaris"');
    });

    test('csvTagihan: judul kolom lengkap & satu baris per tagihan', () {
      final csv = csvTagihan([
        TagihanData(
          id: 1,
          jenis: 'tagihan',
          nama: 'Listrik; PLN',
          jumlahSen: 250000,
          kodeMataUang: 'IDR',
          jatuhTempo: DateTime(2026, 9, 20),
          frekuensi: 'bulanan',
          pengingatLeadHari: '7,3,1',
          pengingatJam: '09:00',
          kanalPengingat: 'push',
          prioritas: 'biasa',
          statusAktif: true,
          lunas: false,
          dibuatPada: DateTime(2026, 9, 1),
          diubahPada: DateTime(2026, 9, 1),
          kategoriId: 3,
        ),
      ], namaKategori: {3: 'Rumah'});

      final baris = csv.trim().split('\n');
      expect(baris, hasLength(2));
      expect(baris.first.split(';'), contains('jumlah_sen'));
      expect(baris.first.split(';'), contains('tanggal_lunas'));
      expect(baris[1], contains('"Listrik; PLN"'));
      expect(baris[1], contains(';250000;2.500,00;'));
      expect(baris[1], contains('2026-09-20'));
      expect(baris[1], contains('Rumah'));
      expect(baris[1], contains(';belum;'));
    });

    test('csvRiwayat: menandai tepat waktu & terlambat', () {
      final csv = csvRiwayat([
        BarisRiwayatCsv(
          namaTagihan: 'Internet',
          periode: DateTime(2026, 9, 1),
          tanggalBayar: DateTime(2026, 9, 1),
          jumlahSen: 300000,
          kodeMataUang: 'IDR',
          telatHari: 0,
        ),
        BarisRiwayatCsv(
          namaTagihan: 'Air',
          periode: DateTime(2026, 8, 1),
          tanggalBayar: DateTime(2026, 8, 5),
          jumlahSen: 150000,
          kodeMataUang: 'IDR',
          telatHari: 4,
        ),
      ]);
      final baris = csv.trim().split('\n');
      expect(baris, hasLength(3));
      expect(baris.first.split(';'), contains('tepat_waktu'));
      expect(baris[1], contains(';ya'));
      expect(baris[2], contains(';tidak'));
      expect(baris[2], contains(';4;'));
    });

    test('tulisCsv menulis berkas sungguhan & menghitung barisnya', () async {
      final hasil = await tulisCsv(folderUji, [
        (nama: 'contoh.csv', isi: 'a;b\n1;2\n3;4\n'),
      ]);
      expect(hasil.single.nama, 'contoh.csv');
      expect(hasil.single.baris, 3, reason: 'judul + 2 baris isi');
      expect(await File(hasil.single.jalur).readAsString(), 'a;b\n1;2\n3;4\n');
    });
  });

  group('Ekspor sungguhan', () {
    test('menulis tagihan.csv & riwayat_pembayaran.csv sesuai data', () async {
      final repo = TagihanRepository(db);
      await repo.tambah(TagihanCompanion.insert(
        nama: 'Listrik Rumah',
        jatuhTempo: DateTime(2026, 9, 20),
        jumlahSen: const Value(250000),
      ));
      await repo.tambah(TagihanCompanion.insert(
        nama: 'Internet',
        jatuhTempo: DateTime(2026, 9, 5),
        jumlahSen: const Value(350000),
      ));
      final listrik = (await db.select(db.tagihan).get())
          .firstWhere((t) => t.nama == 'Listrik Rumah');
      await repo.tandaiLunas(listrik.id, tanggalBayar: DateTime(2026, 9, 20));

      final hasil = await eksporSemuaCsv(db: db, repo: repo, folder: folderUji);

      expect(hasil.map((b) => b.nama).toList(),
          ['tagihan.csv', 'riwayat_pembayaran.csv']);
      expect(await File('${folderUji.path}/tagihan.csv').exists(), isTrue);
      expect(await File('${folderUji.path}/riwayat_pembayaran.csv').exists(), isTrue);

      final isiTagihan = await File('${folderUji.path}/tagihan.csv').readAsString();
      expect(isiTagihan, contains('Listrik Rumah'));
      expect(isiTagihan, contains('Internet'));
      // 'Listrik Rumah' sudah dibayar → jatuh temponya maju ke periode berikutnya
      // (Agustus→September dibayar, sekarang jatuh tempo 20 Okt 2026). Ini
      // perilaku yang benar: tagihan berulang maju setelah dibayar.
      expect(isiTagihan, contains('2026-10-20'));
      expect(isiTagihan, contains('2026-09-05'), reason: 'Internet belum dibayar');

      final isiRiwayat =
          await File('${folderUji.path}/riwayat_pembayaran.csv').readAsString();
      final barisRiwayat = isiRiwayat.trim().split('\n');
      expect(barisRiwayat.first.split(';'), contains('periode'));
      expect(barisRiwayat, hasLength(2), reason: 'satu pembayaran tercatat');
      expect(barisRiwayat[1], contains('Listrik Rumah'));
      expect(barisRiwayat[1], contains('2026-09-20'));
    });

    test('folder dibuat sendiri bila belum ada', () async {
      final baru = Directory('${folderUji.path}/belum_ada/ekspor');
      final hasil = await eksporSemuaCsv(
          db: db, repo: TagihanRepository(db), folder: baru);
      expect(hasil, hasLength(2));
      expect(await baru.exists(), isTrue);
    });
  });

  group('Layar ekspor', () {
    testWidgets('menampilkan penjelasan & tombol buat berkas', (t) async {
      await t.binding.setSurfaceSize(const Size(430, 950));
      await t.pumpWidget(const ProviderScope(
        child: MaterialApp(home: EksporCsvScreen()),
      ));
      await t.pump();

      expect(find.text('Ekspor CSV'), findsOneWidget);
      expect(find.text('Bukti untuk spreadsheet'), findsOneWidget);
      expect(find.byKey(const Key('jalankan_ekspor_csv')), findsOneWidget);
      expect(find.textContaining('titik-koma'), findsOneWidget);

      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });
  });
}
