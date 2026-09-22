/// Uji "Semua Fitur" — peta 152 butir PRD v3.1.
///
/// Yang dibuktikan:
/// 1. Data lengkap: 152 butir, nomor unik, tidak ada nama kosong, status sah.
/// 2. Tanda kejujuran: fitur yang Ron kerjakan bertanda Selesai, yang belum
///    tetap Belum (tidak ada yang "dinaikkan" tanpa bukti).
/// 3. Layar: ringkasan jumlah benar, saringan & pencarian bekerja, butir tanpa
///    layar menjelaskan keadaannya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/peta_fitur/data_peta_fitur.dart';
import 'package:personal_life_os/features/peta_fitur/peta_fitur_screen.dart';

ButirFitur cari(String id) =>
    petaFitur.firstWhere((b) => b.id == id, orElse: () => throw StateError('tidak ada $id'));

void main() {
  group('Data peta fitur', () {
    test('memuat 152 butir PRD, nomor unik', () {
      expect(petaFitur, hasLength(152));
      final nomor = petaFitur.map((b) => b.id).toSet();
      expect(nomor, hasLength(152), reason: 'tidak boleh ada nomor kembar');
      expect(nomor.contains('FR-01'), isTrue);
      expect(nomor.contains('FR-152'), isTrue);
    });

    test('tidak ada butir tanpa nama dan setiap modul terisi', () {
      for (final b in petaFitur) {
        expect(b.nama.trim(), isNotEmpty, reason: '${b.id} tanpa nama');
        expect(b.modul.trim(), isNotEmpty, reason: '${b.id} tanpa modul');
      }
      final modul = petaFitur.map((b) => b.modul).toSet();
      expect(modul.length, greaterThanOrEqualTo(11),
          reason: '11 modul PRD harus terbentuk');
    });

    test('ringkasan cocok dengan daftar', () {
      final r = ringkasanPetaFitur();
      final jumlah = r.values.fold<int>(0, (a, b) => a + b);
      expect(jumlah, 152);
      expect(r[StatusFitur.selesai], petaFitur.where((b) => b.status == StatusFitur.selesai).length);
    });

    test('fitur yang Ron selesaikan bertanda Selesai', () {
      for (final id in ['FR-21', 'FR-64', 'FR-65', 'FR-66', 'FR-67', 'FR-69',
        'FR-70', 'FR-81', 'FR-82', 'FR-85', 'FR-138',
        // Batch 8: kunci, lencana, widget, multi-profil, aksi cepat.
        'FR-22', 'FR-26', 'FR-31', 'FR-44', 'FR-151',
        // Batch 9: energi harian, rencana ibadah, temuan pintar, ramalan, tahun.
        'FR-84', 'FR-97', 'FR-142', 'FR-143', 'FR-146']) {
        expect(cari(id).status, StatusFitur.selesai, reason: '$id seharusnya Selesai');
      }
    });

    test('yang belum dikerjakan TIDAK diberi tanda Selesai', () {
      expect(cari('FR-38').status, StatusFitur.belum);   // impor tagihan dari foto (OCR)
      expect(cari('FR-149').status, StatusFitur.belum);  // AI Copilot
      expect(cari('FR-26').status, StatusFitur.selesai);  // kunci aplikasi (Batch 8)
    });

    test('sinkron ditandai Selesai TAPI cacatnya ditulis apa adanya', () {
      // FR-150 sudah menyinkronkan semua modul data (diuji dua basis data),
      // jadi statusnya SELESAI. Penjaga kejujuran tetap ada: catatannya WAJIB
      // menyebut apa yang belum ikut, supaya tidak terbaca "sempurna".
      expect(cari('FR-150').status, StatusFitur.selesai);
      final catatan = cari('FR-150').catatan.toLowerCase();
      expect(catatan, contains('belum'));
      expect(catatan, contains('lampiran'));
    });

    test('butir yang punya layar diberi rute', () {
      expect(cari('FR-86').rute, '/ibadah/jadwal-sholat');
      expect(cari('FR-150').rute, '/akun');
      expect(cari('FR-09').rute, isNull, reason: 'belum ada layarnya');
    });
  });

  group('Layar Semua Fitur', () {
    Future<void> buka(WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(430, 950));
      await t.pumpWidget(const MaterialApp(home: PetaFiturScreen()));
      await t.pumpAndSettle();
    }

    Future<void> tutup(WidgetTester t) async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.binding.setSurfaceSize(null);
    }

    testWidgets('ringkasan jumlah tampil dan benar', (t) async {
      await buka(t);
      final r = ringkasanPetaFitur();
      final teks = t.widget<Text>(find.byKey(const Key('peta_ringkas'))).data!;
      expect(teks, '${r[StatusFitur.selesai]} dari 152 butir sudah selesai');
      expect(find.text('Selesai ${r[StatusFitur.selesai]}'), findsOneWidget);
      expect(find.text('Belum ${r[StatusFitur.belum]}'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('saringan "Belum" menyembunyikan yang sudah selesai', (t) async {
      await buka(t);
      await t.ensureVisible(find.byKey(const Key('peta_saring_belum')));
      await t.tap(find.byKey(const Key('peta_saring_belum')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('peta_FR-38')), findsOneWidget);
      expect(find.byKey(const Key('peta_FR-26')), findsNothing,
          reason: 'FR-26 sudah selesai → tidak muncul di saringan Belum');
      expect(find.byKey(const Key('peta_FR-21')), findsNothing,
          reason: 'FR-21 sudah selesai → tidak muncul di saringan Belum');
      await tutup(t);
    });

    testWidgets('pencarian menyaring menurut nomor fitur', (t) async {
      await buka(t);
      await t.enterText(find.byKey(const Key('peta_cari')), 'FR-150');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('peta_FR-150')), findsOneWidget);
      expect(find.byKey(const Key('peta_FR-09')), findsNothing);
      await tutup(t);
    });

    testWidgets('butir tanpa layar: dibuka → dijelaskan belum dikerjakan',
        (t) async {
      await buka(t);
      await t.enterText(find.byKey(const Key('peta_cari')), 'FR-38');
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('peta_FR-38')));
      await t.tap(find.byKey(const Key('peta_FR-38')));
      await t.pumpAndSettle();
      expect(find.text('Layarnya belum ada — butir ini belum dikerjakan.'),
          findsOneWidget);
      await tutup(t);
    });
  });
}
