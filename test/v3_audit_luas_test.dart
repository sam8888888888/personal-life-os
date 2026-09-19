/// Uji FR-138 (bagian 2) — catatan aktivitas diperluas ke modul uang & kategori.
///
/// Bukti yang dicari: setiap aksi nyata di layar meninggalkan SATU baris di
/// tabel `audit_log` dengan modul yang benar — bukan sekadar "kode memanggil
/// fungsi". Karena itu uji ini menekan tombol seperti pengguna, lalu memeriksa
/// isi tabel.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/audit/audit_log.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/model/enums.dart';
import 'package:personal_life_os/data/repository/langganan_repository.dart';
import 'package:personal_life_os/features/kesehatan/aktivitas_screen.dart';
import 'package:personal_life_os/features/kesehatan/air_screen.dart';
import 'package:personal_life_os/features/kesehatan/obat_screen.dart';
import 'package:personal_life_os/features/uang/langganan/langganan_screen.dart';
import 'package:personal_life_os/features/uang/anggaran/form_anggaran_screen.dart';
import 'package:personal_life_os/features/uang/kekayaan/form_aset_screen.dart';
import 'package:personal_life_os/features/uang/kekayaan/form_kewajiban_screen.dart';
import 'package:personal_life_os/features/uang/transaksi/form_transaksi_screen.dart';
import 'package:personal_life_os/features/uang/transaksi/kelola_kategori_screen.dart';

late AppDatabase db;

/// Waktu uji dikunci: 15 September 2026.
final jamUji = DateTime(2026, 9, 15, 9);

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() async => db.close());

  /// Isi tabel audit untuk satu modul.
  Future<List<AuditLogData>> catatan(String modul) =>
      (db.select(db.auditLog)..where((a) => a.modul.equals(modul))).get();

  Future<void> tampilkan(WidgetTester t, Widget layar) async {
    await t.binding.setSurfaceSize(const Size(420, 900));
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTema.terang(),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: layar,
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  Future<void> tutup(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 50));
    await t.binding.setSurfaceSize(null);
  }

  /// Tekan tombol dengan aman: pastikan terlihat dulu (layar bisa panjang).
  Future<void> ketuk(WidgetTester t, Finder target) async {
    await t.ensureVisible(target);
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(target);
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
  }

  // ------------------------------------------------------------------
  // Modul audit
  // ------------------------------------------------------------------

  test('modul kategori terdaftar di ModulAudit.semua', () {
    expect(ModulAudit.kategori, 'kategori');
    expect(ModulAudit.semua.contains(ModulAudit.kategori), isTrue,
        reason: 'saringan di layar Catatan Aktivitas memakai daftar ini');
  });

  // ------------------------------------------------------------------
  // Layar
  // ------------------------------------------------------------------

  testWidgets('kategori: tambah meninggalkan satu catatan', (t) async {
    await tampilkan(t, const KelolaKategoriScreen());
    await t.ensureVisible(find.byKey(const Key('tambah_kategori')));
    await t.tap(find.byKey(const Key('tambah_kategori')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    await t.enterText(find.byKey(const Key('nama_kategori')), 'Langganan Uji');
    await ketuk(t, find.byKey(const Key('simpan_kategori')));

    final baris = await catatan(ModulAudit.kategori);
    expect(baris, hasLength(1));
    expect(baris.first.aksi, AksiAudit.buat);
    expect(baris.first.ringkas, contains('Langganan Uji'));
    await tutup(t);
  });

  testWidgets('transaksi: mencatat transaksi meninggalkan satu catatan',
      (t) async {
    await tampilkan(t, FormTransaksiScreen(jamSekarang: () => jamUji));

    await t.tap(find.byKey(const Key('pilih_kategori_transaksi')));
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    await t.tap(find.text('Makan & Minum').last);
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    await t.enterText(find.byKey(const Key('nominal_transaksi')), '25000');
    await ketuk(t, find.byKey(const Key('simpan_transaksi')));

    final baris = await catatan(ModulAudit.transaksi);
    expect(baris, hasLength(1));
    expect(baris.first.aksi, AksiAudit.buat);
    expect(baris.first.ringkas, contains('Rp 25.000'));
    // Datanya benar-benar tersimpan juga.
    expect((await db.select(db.transaksi).get()), hasLength(1));
    await tutup(t);
  });

  testWidgets('anggaran: mengisi anggaran meninggalkan satu catatan',
      (t) async {
    await tampilkan(t,
        const FormAnggaranScreen(periode: '2026-09', kategoriId: null));

    await t.tap(find.byKey(const Key('pilih_kategori')));
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    await t.tap(find.text('Makan & Minum').last);
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    await t.enterText(find.byKey(const Key('batas_anggaran')), '500000');
    await ketuk(t, find.text('Simpan anggaran'));

    final baris = await catatan(ModulAudit.anggaran);
    expect(baris, hasLength(1));
    expect(baris.first.aksi, AksiAudit.buat);
    expect(baris.first.ringkas, contains('Rp 500.000'));
    expect((await db.select(db.anggaranBulanan).get()), hasLength(1));
    await tutup(t);
  });

  testWidgets('aset: menambah aset meninggalkan satu catatan', (t) async {
    await tampilkan(t, FormAsetScreen(jamSekarang: () => jamUji));

    await t.enterText(find.byKey(const Key('nama_aset')), 'Tanah Uji');
    await t.enterText(find.byKey(const Key('nilai_aset')), '1000000');
    await ketuk(t, find.byKey(const Key('simpan_aset')));

    final baris = await catatan(ModulAudit.aset);
    expect(baris, hasLength(1));
    expect(baris.first.aksi, AksiAudit.buat);
    expect(baris.first.ringkas, contains('Tanah Uji'));
    expect((await db.select(db.aset).get()), hasLength(1));
    await tutup(t);
  });

  testWidgets('kewajiban: menambah kewajiban meninggalkan satu catatan',
      (t) async {
    await tampilkan(t, FormKewajibanScreen(jamSekarang: () => jamUji));

    await t.enterText(find.byKey(const Key('nama_kewajiban')), 'Kartu Uji');
    await t.enterText(find.byKey(const Key('sisa_kewajiban')), '500000');
    await ketuk(t, find.byKey(const Key('simpan_kewajiban')));

    final baris = await catatan(ModulAudit.kewajiban);
    expect(baris, hasLength(1));
    expect(baris.first.aksi, AksiAudit.buat);
    expect(baris.first.ringkas, contains('Kartu Uji'));
    expect((await db.select(db.kewajiban).get()), hasLength(1));
    await tutup(t);
  });

  testWidgets('kewajiban: menghapus meninggalkan catatan hapus', (t) async {
    final k = await db.into(db.kewajiban).insertReturning(KewajibanCompanion.insert(
          idKewajiban: 'kwj_uji',
          nama: 'Hapus Uji',
          saldoAwalSen: const Value(100000),
        ));

    await tampilkan(t, FormKewajibanScreen(kewajiban: k, jamSekarang: () => jamUji));
    await ketuk(t, find.byKey(const Key('hapus_kewajiban_form')));
    await t.pump(const Duration(milliseconds: 300));
    await ketuk(t, find.widgetWithText(FilledButton, 'Hapus'));

    final baris = await catatan(ModulAudit.kewajiban);
    expect(baris, hasLength(1));
    expect(baris.first.aksi, AksiAudit.hapus);
    expect(baris.first.ringkas, contains('Hapus Uji'));
    await tutup(t);
  });
  // ------------------------------------------------------------------
  // Modul kesehatan & langganan (FR-138 bagian 3)
  // ------------------------------------------------------------------

  testWidgets('aktivitas: mencatat aktivitas meninggalkan satu catatan',
      (t) async {
    await tampilkan(t, AktivitasScreen(jamSekarang: () => jamUji));

    await t.enterText(
        find.byKey(const Key('input_jenis_aktivitas')), 'Jalan Kaki');
    await t.enterText(find.byKey(const Key('input_durasi_menit')), '30');
    await ketuk(t, find.byKey(const Key('simpan_aktivitas')));

    final baris = await catatan(ModulAudit.kesehatan);
    expect(baris, hasLength(1));
    expect(baris.first.aksi, AksiAudit.buat);
    expect(baris.first.ringkas, contains('Jalan Kaki'));
    expect(baris.first.ringkas, contains('30 menit'));
    expect((await db.select(db.aktivitas).get()), hasLength(1));
    await tutup(t);
  });

  testWidgets('air: mencatat segelas air meninggalkan satu catatan',
      (t) async {
    await tampilkan(t, AirScreen(jamSekarang: () => jamUji));

    await ketuk(t, find.byKey(const Key('tambah_gelas')));

    final baris = await catatan(ModulAudit.kesehatan);
    expect(baris, hasLength(1));
    expect(baris.first.entitas, 'air');
    expect(baris.first.aksi, AksiAudit.buat);
    expect((await db.select(db.catatanAir).get()), hasLength(1));
    await tutup(t);
  });

  testWidgets('obat: menyimpan obat meninggalkan satu catatan', (t) async {
    await tampilkan(t, ObatScreen(jamSekarang: () => jamUji));

    await t.enterText(find.byKey(const Key('input_nama_obat')), 'Vitamin Uji');
    await t.enterText(find.byKey(const Key('input_jumlah_per_minum')), '1');
    await ketuk(t, find.byKey(const Key('simpan_obat')));

    final baris = await catatan(ModulAudit.kesehatan);
    expect(baris, hasLength(1));
    expect(baris.first.entitas, 'obat');
    expect(baris.first.ringkas, contains('Vitamin Uji'));
    expect((await db.select(db.obat).get()), hasLength(1));
    await tutup(t);
  });

  testWidgets('langganan: pause meninggalkan satu catatan', (t) async {
    final l = await LanggananRepository(db).tambah(
      nama: 'Langganan Uji',
      nominalSen: 5000000,
      tanggalMulai: DateTime(2026, 1, 20),
      siklus: Frekuensi.bulanan,
    );

    await tampilkan(t, LanggananScreen(jamSekarang: () => jamUji));
    await ketuk(t, find.byKey(Key('aksi_pause_${l.id}')));
    await t.pump(const Duration(milliseconds: 300));
    await ketuk(t, find.byKey(const Key('pause_1_bulan')));

    final baris = await catatan(ModulAudit.langganan);
    expect(baris, hasLength(1));
    expect(baris.first.aksi, AksiAudit.ubah);
    expect(baris.first.ringkas, contains('dipause'));
    expect(baris.first.entitasId, '${l.id}');
    await tutup(t);
  });
}
