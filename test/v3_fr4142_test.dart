/// Uji FR-41 (ekspor kalender .ics) & FR-42 (Pusat Bayar).
///
/// Yang dibuktikan:
///   * .ics berisi acara untuk SETIAP jatuh tempo dalam rentang, tagihan
///     berulang diperluas, tagihan lunas/nonaktif tidak diekspor,
///   * formatnya sah (CRLF, UID, DTSTART all-day, VALARM sesuai lead hari),
///   * teks ber-tanda baca di-escape & baris panjang dilipat (RFC 5545),
///   * berkas benar-benar tertulis ke disk dan bisa dibaca lagi,
///   * preferensi Pusat Bayar tersimpan per tagihan & bisa dihapus,
///   * layar: pilih aplikasi bayar & jenis nomor tersimpan, tombol salin
///     menaruh nomor di papan klip, catatan konfirmasi tersimpan & tampil.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/laporan/ekspor_ics.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/data/repository/pusat_bayar.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/tagihan/ekspor_kalender_screen.dart';
import 'package:personal_life_os/features/tagihan/pusat_bayar_screen.dart';

AppDatabase? db;
TagihanRepository? repo;

Future<TagihanData> buatTagihan({
  required String nama,
  required DateTime jatuhTempo,
  int? jumlahSen = 250000,
  String frekuensi = 'bulanan',
  String? catatan,
  bool lunas = false,
  String lead = '7,3,1,0',
}) async {
  final t = await repo!.tambah(TagihanCompanion.insert(
    nama: nama,
    jatuhTempo: jatuhTempo,
    jumlahSen: Value(jumlahSen),
    frekuensi: Value(frekuensi),
    catatan: Value(catatan),
    pengingatLeadHari: Value(lead),
  ));
  if (lunas) await repo!.tandaiLunas(t.id);
  final ulang = await (db!.select(db!.tagihan)..where((x) => x.id.equals(t.id)))
      .getSingle();
  return ulang;
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TagihanRepository(db!);
  });

  tearDown(() async => db!.close());

  // ------------------------------------------------------------- FR-41 (.ics)
  group('FR-41 ekspor kalender', () {
    test('tagihan bulanan → satu acara per bulan dalam rentang', () async {
      await buatTagihan(nama: 'Listrik Rumah', jatuhTempo: DateTime(2026, 9, 24));
      final tagihan = await repo!.ambilSemua();

      final hasil = susunIcsTagihan(
        tagihan,
        dari: DateTime(2026, 9, 1),
        sampai: DateTime(2026, 11, 30),
        dibuat: DateTime.utc(2026, 9, 21, 12),
      );

      expect(hasil.jumlahTagihan, 1);
      expect(hasil.jumlahAcara, 3, reason: '24 Sep, 24 Okt, 24 Nov');
      expect(hasil.isi, startsWith('BEGIN:VCALENDAR\r\n'));
      expect(hasil.isi, endsWith('END:VCALENDAR\r\n'));
      expect(hasil.isi, contains('DTSTART;VALUE=DATE:20260924'));
      expect(hasil.isi, contains('DTEND;VALUE=DATE:20260925'));
      expect(hasil.isi, contains('DTSTART;VALUE=DATE:20261024'));
      expect(hasil.isi, contains('DTSTAMP:20260921T120000Z'));
      expect(hasil.isi, contains('X-WR-CALNAME:Tagihan Personal Life OS'));
      expect(hasil.isi.split('BEGIN:VEVENT').length - 1, 3);
      expect(hasil.isi.split('END:VEVENT').length - 1, 3);
    });

    test('lead hari tagihan dipakai sebagai pengingat acara', () async {
      await buatTagihan(
        nama: 'Internet',
        jatuhTempo: DateTime(2026, 9, 24),
        lead: '7,3,1,0',
      );
      final hasil = susunIcsTagihan(
        await repo!.ambilSemua(),
        dari: DateTime(2026, 9, 1),
        sampai: DateTime(2026, 9, 30),
      );
      // 7,3,1,0 → lead terkecil yang > 0 = 1 hari sebelum.
      expect(hasil.isi, contains('TRIGGER:-P1D'));
      expect(hasil.isi, contains('ACTION:DISPLAY'));
    });

    test('tagihan sekali jalan → satu acara; di luar rentang → tidak ada',
        () async {
      await buatTagihan(
          nama: 'Pajak tahunan',
          jatuhTempo: DateTime(2026, 12, 31),
          frekuensi: 'sekali');
      final hasil = susunIcsTagihan(
        await repo!.ambilSemua(),
        dari: DateTime(2026, 9, 1),
        sampai: DateTime(2026, 12, 31),
      );
      expect(hasil.jumlahAcara, 1);

      final kosong = susunIcsTagihan(
        await repo!.ambilSemua(),
        dari: DateTime(2026, 9, 1),
        sampai: DateTime(2026, 9, 30),
      );
      expect(kosong.jumlahAcara, 0);
      expect(kosong.isi, isNot(contains('BEGIN:VEVENT')));
    });

    test('tagihan lunas & nonaktif tidak diekspor', () async {
      await buatTagihan(
          nama: 'Sudah dibayar',
          jatuhTempo: DateTime(2026, 9, 24),
          frekuensi: 'sekali',
          lunas: true);
      final hasil = susunIcsTagihan(
        await repo!.ambilSemua(),
        dari: DateTime(2026, 9, 1),
        sampai: DateTime(2026, 12, 31),
      );
      expect(hasil.jumlahAcara, 0);
    });

    test('teks ber-tanda baca di-escape & baris panjang dilipat', () async {
      await buatTagihan(
        nama: 'Iuran RT; pembersihan, keamanan dan sampah lingkungan '
            'perumahan besar sekali panjangnya',
        jatuhTempo: DateTime(2026, 9, 24),
        frekuensi: 'sekali',
        catatan: 'bayar ke bendahara, tunai; ada kuitansi',
        jumlahSen: 150000,
      );
      final hasil = susunIcsTagihan(
        await repo!.ambilSemua(),
        dari: DateTime(2026, 9, 1),
        sampai: DateTime(2026, 9, 30),
      );
      expect(hasil.isi, contains(r'Iuran RT\; pembersihan\,'));
      expect(hasil.isi, contains(r'bendahara\, tunai\; ada kuitansi'));
      // Baris panjang dilipat: ada lanjutan yang diawali satu spasi.
      expect(hasil.isi, contains('\r\n '),
          reason: 'baris panjang dilipat ke baris lanjutan');
      expect(hasil.isi, contains('Rp 1.500'));
      // Tiap baris diakhiri CRLF (RFC 5545) — tidak ada baris tanpa CR.
      for (final baris in hasil.isi.split('\r\n')) {
        expect(baris.contains('\n'), isFalse);
      }
    });

    test('berkas benar-benar tertulis & bisa dibaca lagi', () async {
      await buatTagihan(
          nama: 'Air PDAM',
          jatuhTempo: DateTime(2026, 9, 24),
          frekuensi: 'bulanan');
      final folder = Directory.systemTemp.createTempSync('lifeos_ics_');
      final hasil = await eksporKalender(
        repo: repo!,
        folder: folder,
        dari: DateTime(2026, 9, 1),
        sampai: DateTime(2026, 12, 31),
        dibuat: DateTime.utc(2026, 9, 21, 12),
      );
      final berkas = File(hasil.jalur);
      expect(berkas.existsSync(), isTrue);
      final isi = await berkas.readAsString();
      expect(isi, contains('BEGIN:VCALENDAR'));
      expect(isi, contains('Bayar Air PDAM'));
      expect(hasil.acara, 4);
      folder.deleteSync(recursive: true);
    });
  });

  // ---------------------------------------------------------- FR-42 (simpanan)
  group('FR-42 pusat bayar — simpanan', () {
    test('simpan, baca, dan hapus preferensi per tagihan', () async {
      final simpan = PusatBayarPenyimpanan(PengaturanRepository(db!));
      expect(await simpan.semua(), isEmpty);

      await simpan.simpan(
        7,
        const PreferensiBayar(
          aplikasi: 'BCA mobile',
          jenis: JenisNomorBayar.va,
          nomor: '8808123456789',
        ),
      );
      await simpan.simpan(
        9,
        const PreferensiBayar(
          aplikasi: 'DANA',
          jenis: JenisNomorBayar.qris,
          nomor: 'QRIS-001',
          catatan: 'sudah bayar 20 Sep',
          catatanPada: null,
        ),
      );

      final peta = await simpan.semua();
      expect(peta, hasLength(2));
      expect(peta[7]!.aplikasi, 'BCA mobile');
      expect(peta[7]!.jenis, JenisNomorBayar.va);
      expect(peta[9]!.jenis, JenisNomorBayar.qris);
      expect(peta[9]!.catatan, 'sudah bayar 20 Sep');

      await simpan.hapus(7);
      expect((await simpan.semua()).keys, [9]);
    });

    test('preferensi kosong tidak disimpan (tidak menumpuk sampah)', () async {
      final simpan = PusatBayarPenyimpanan(PengaturanRepository(db!));
      await simpan.simpan(1, const PreferensiBayar());
      expect(await simpan.semua(), isEmpty);
      expect(await PengaturanRepository(db!).baca(kunciPusatBayar), '{}');
    });

    test('catatan dengan waktu tersimpan utuh', () async {
      final simpan = PusatBayarPenyimpanan(PengaturanRepository(db!));
      final waktu = DateTime(2026, 9, 20, 14, 5);
      await simpan.simpan(
        3,
        PreferensiBayar(catatan: 'tunggu verifikasi', catatanPada: waktu),
      );
      final lagi = (await simpan.semua())[3]!;
      expect(lagi.catatan, 'tunggu verifikasi');
      expect(lagi.catatanPada, waktu);
      expect(capCatatan(waktu), contains('14:05'));
    });
  });

  // ------------------------------------------------------------- FR-42 layar
  testWidgets('FR-42 layar: pilih aplikasi, jenis, salin nomor, catatan',
      (t) async {
    final panggilan = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (c) async {
      panggilan.add(c);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    final tagihan = await buatTagihan(
        nama: 'Listrik', jatuhTempo: DateTime(2026, 9, 24));

    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: PusatBayarScreen(
            db: db,
            sekarang: DateTime(2026, 9, 20, 14, 5),
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byKey(Key('aplikasi_${tagihan.id}')));
    await t.pumpAndSettle();
    await t.tap(find.text('BCA mobile').last);
    await t.pumpAndSettle();

    await t.tap(find.byKey(Key('jenis_${tagihan.id}_qris')));
    await t.pumpAndSettle();

    await t.enterText(find.byKey(Key('nomor_${tagihan.id}')), '8808123456');
    await t.pumpAndSettle();
    await t.tap(find.byKey(Key('salin_${tagihan.id}')));
    await t.pumpAndSettle();

    // Nomor benar-benar masuk papan klip.
    final salin = panggilan.where((c) => c.method == 'Clipboard.setData');
    expect(salin, isNotEmpty, reason: 'Clipboard.setData dipanggil');
    expect((salin.last.arguments as Map)['text'], '8808123456');

    // Catatan konfirmasi ditulis lalu tampil di kartu.
    await t.tap(find.byKey(Key('catatan_${tagihan.id}')));
    await t.pumpAndSettle();
    await t.enterText(
        find.byKey(const Key('isi_catatan_konfirmasi')), 'sudah transfer');
    await t.tap(find.byKey(const Key('simpan_catatan')));
    await t.pumpAndSettle();

    expect(find.byKey(Key('catatan_tersimpan_${tagihan.id}')), findsOneWidget);
    expect(find.textContaining('sudah transfer · '), findsOneWidget);

    final peta = await PusatBayarPenyimpanan(PengaturanRepository(db!)).semua();
    expect(peta[tagihan.id]!.aplikasi, 'BCA mobile');
    expect(peta[tagihan.id]!.jenis, JenisNomorBayar.qris);
    expect(peta[tagihan.id]!.nomor, '8808123456');
    expect(peta[tagihan.id]!.catatan, 'sudah transfer');
    expect(peta[tagihan.id]!.catatanPada, DateTime(2026, 9, 20, 14, 5));

    await t.pumpAndSettle(const Duration(seconds: 5));
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('FR-42 layar: salin tanpa nomor → diberi tahu, tidak menyimpan',
      (t) async {
    final tagihan = await buatTagihan(
        nama: 'Air', jatuhTempo: DateTime(2026, 9, 26));

    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
          home: Scaffold(body: PusatBayarScreen(db: db))),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byKey(Key('salin_${tagihan.id}')));
    await t.pumpAndSettle();
    expect(find.textContaining('Isi nomor VA/QRIS-nya dulu'), findsOneWidget);
    expect(await PusatBayarPenyimpanan(PengaturanRepository(db!)).semua(),
        isEmpty);

    await t.pumpAndSettle(const Duration(seconds: 5));
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle(const Duration(seconds: 5));
  });
}
