/// Uji Batch 13 — FR-38 (impor tagihan dari foto/OCR) & FR-50 (struk/nota).
///
/// Kanal Android diuji lewat kanal tiruan (mock MethodChannel) supaya alur
/// nyata (pilih foto → baca → draf → simpan) benar-benar dijalankan.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/parsing/ocr_tagihan.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/features/tagihan/impor_ocr_screen.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

/// Contoh teks seperti hasil OCR tagihan listrik.
const _teksTagihan = '''
PT PLN (PERSERO)
TAGIHAN LISTRIK
No Pelanggan 512345678901
Nama: SAMIAN
JATUH TEMPO 25/10/2026
TOTAL TAGIHAN Rp 250.000
''';

/// Contoh teks seperti hasil OCR struk belanja.
const _teksStruk = '''
TOKO SEMBAKO BAROKAH
Jl. Raya Darmo 12
Beras 5kg 65.000
Minyak goreng 2L 35.000
Telur 1kg 30.000
TOTAL 130.000
TUNAI 150.000
''';

void _pasangKanal(
  WidgetTester t, {
  required bool tersedia,
  String? teks,
  String? jalurFoto = '/tmp/foto-uji.jpg',
  bool gagalBaca = false,
}) {
  final binding = t.binding;
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('lifeos/ocr'),
    (call) async {
      switch (call.method) {
        case 'tersedia':
          return tersedia;
        case 'bacaTeks':
          if (gagalBaca) {
            throw PlatformException(code: 'gagal_baca', message: 'buram');
          }
          return {
            'teks': teks ?? '',
            'baris': [
              for (final b in (teks ?? '').split('\n'))
                if (b.trim().isNotEmpty) {'teks': b.trim()},
            ],
            'jumlahBaris': (teks ?? '').split('\n').length,
          };
      }
      return null;
    },
  );
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('lifeos/media'),
    (call) async {
      if (call.method == 'pilihFoto' || call.method == 'ambilFoto') {
        return jalurFoto;
      }
      return null;
    },
  );
}

Future<void> _pasangLayar(WidgetTester t, AppDatabase db) async {
  t.view.physicalSize = const Size(1200, 3000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const MaterialApp(home: ImporOcrScreen()),
  ));
  await t.pump();
}

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // Mesin tafsir OCR
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-38 mesin urai OCR', () {
    test('uraiNominalOcr: berbagai gaya angka di kertas', () {
      expect(uraiNominalOcr('TOTAL Rp 250.000'), 25000000);
      expect(uraiNominalOcr('250.000,00'), 25000000);
      expect(uraiNominalOcr('1.234.567'), 123456700);
      expect(uraiNominalOcr('250.000,50'), 25000050);
      expect(uraiNominalOcr('tanpa angka'), isNull);
    });

    test('uraiNomorPelanggan: deretan 8–16 angka', () {
      expect(uraiNomorPelanggan('No Pelanggan 512345678901'), '512345678901');
      expect(uraiNomorPelanggan('tidak ada nomor'), isNull);
    });

    test('teks tagihan listrik → jenis tagihan + nominal dari baris TOTAL', () {
      final d = uraikanTeksOcr(_teksTagihan, sekarang: DateTime(2026, 9, 22));
      expect(d.jenis, JenisOcr.tagihan);
      expect(d.nominalSen, 25000000);
      expect(d.jatuhTempo, DateTime(2026, 10, 25));
      expect(d.nomorPelanggan, '512345678901');
      expect(d.nama.isNotEmpty, isTrue);
      expect(d.barisTerpakai.any((b) => b.toLowerCase().contains('total')), isTrue);
      expect(d.keyakinan, greaterThanOrEqualTo(80));
      expect(drafOcrSiapSebagaiTagihan(d), isTrue);
    });

    test('teks struk → jenis struk + barang terbaca + total', () {
      final d = uraikanTeksOcr(_teksStruk, sekarang: DateTime(2026, 9, 22));
      expect(d.jenis, JenisOcr.struk);
      expect(d.nominalSen, 13000000);
      expect(d.item.length, greaterThanOrEqualTo(3));
      expect(d.item.first.nama.toLowerCase().contains('beras'), isTrue);
      expect(drafOcrSiapSebagaiPengeluaran(d), isTrue);
    });

    test('struk dengan barang tidak cocok TOTAL → selisih dikatakan', () {
      final d = uraikanTeksOcr('''
TOKO A
Sabun 10.000
Sampo 12.000
TOTAL 30.000
''', sekarang: DateTime(2026, 9, 22));
      expect(d.jenis, JenisOcr.struk);
      expect(d.alasan.any((a) => a.contains('tidak sama dengan total')), isTrue);
    });

    test('teks kosong / tanpa angka dijawab belum bisa, bukan ditebak', () {
      final kosong = uraikanTeksOcr('   ');
      expect(kosong.jenis, JenisOcr.tidakDikenali);
      expect(kosong.alasan.first.contains('Tidak ada teks'), isTrue);

      final tanpaAngka = uraikanTeksOcr('TAGIHAN\nJATUH TEMPO segera');
      expect(tanpaAngka.adaNominal, isFalse);
      expect(tanpaAngka.alasan.any((a) => a.contains('nominal')), isTrue);
      expect(drafOcrSiapSebagaiTagihan(tanpaAngka), isFalse);
    });

    test('teks tanpa kata kunci tagihan/struk → dibaca sebagai nota', () {
      final d = uraikanTeksOcr('WARUNG BU YATI\nNasi goreng 15.000');
      expect(d.jenis, JenisOcr.nota);
      expect(d.nominalSen, 1500000);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Layar impor (kanal tiruan)
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-38 layar impor dari foto', () {
    testWidgets('pilih foto → draf muncul → simpan sebagai tagihan', (t) async {
      _pasangKanal(t, tersedia: true, teks: _teksTagihan);
      final db = _db();
      addTearDown(db.close);
      await _pasangLayar(t, db);

      await t.tap(find.text('Pilih dari galeri'));
      await t.pumpAndSettle();

      // Draf terisi otomatis dari teks.
      expect(find.textContaining('250.000'), findsWidgets);

      // Lengkapi (jatuh tempo sudah terbaca) lalu simpan.
      await t.tap(find.text('Simpan tagihan'));
      await t.pumpAndSettle();

      final tagihan = await db.select(db.tagihan).get();
      expect(tagihan, hasLength(1));
      expect(tagihan.first.jumlahSen, 25000000);
      expect(tagihan.first.jatuhTempo, DateTime(2026, 10, 25));
      expect(tagihan.first.catatan, contains('Diimpor dari foto'));
    });

    testWidgets('mode struk/nota menyimpan sebagai pengeluaran (sumber ocr)',
        (t) async {
      _pasangKanal(t, tersedia: true, teks: _teksStruk);
      final db = _db();
      addTearDown(db.close);
      await _pasangLayar(t, db);

      await t.tap(find.text('Struk/nota'));
      await t.pumpAndSettle();
      await t.tap(find.text('Pilih dari galeri'));
      await t.pumpAndSettle();
      await t.tap(find.text('Simpan pengeluaran'));
      await t.pumpAndSettle();

      final trx = await db.select(db.transaksi).get();
      expect(trx, hasLength(1));
      expect(trx.first.jumlahSen, 13000000);
      expect(trx.first.sumber, 'ocr');
      expect(trx.first.jenis, 'pengeluaran');
    });

    testWidgets('perangkat tanpa OCR diberi tahu apa adanya', (t) async {
      _pasangKanal(t, tersedia: false, teks: _teksTagihan);
      final db = _db();
      addTearDown(db.close);
      await _pasangLayar(t, db);

      await t.tap(find.text('Pilih dari galeri'));
      await t.pumpAndSettle();
      expect(find.textContaining('tidak menyediakan pembacaan teks'), findsOneWidget);
      expect(await db.select(db.tagihan).get(), isEmpty);
    });

    testWidgets('kanal gagal membaca → pesan ramah, tidak ada yang tersimpan',
        (t) async {
      _pasangKanal(t, tersedia: true, teks: '', gagalBaca: true);
      final db = _db();
      addTearDown(db.close);
      await _pasangLayar(t, db);

      await t.tap(find.text('Pilih dari galeri'));
      await t.pumpAndSettle();
      expect(find.textContaining('Belum bisa dibaca'), findsOneWidget);
      expect(await db.select(db.transaksi).get(), isEmpty);
    });

    testWidgets('tidak memilih gambar → diingatkan, bukan diproses', (t) async {
      _pasangKanal(t, tersedia: true, teks: _teksTagihan, jalurFoto: null);
      final db = _db();
      addTearDown(db.close);
      await _pasangLayar(t, db);

      await t.tap(find.text('Pilih dari galeri'));
      await t.pumpAndSettle();
      expect(find.textContaining('Tidak ada gambar yang dipilih'), findsOneWidget);
    });
  });
}
