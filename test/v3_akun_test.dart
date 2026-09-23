/// Uji Tahap 1 akun — klien API, penyimpanan sesi, layar masuk, layar akun.
///
/// Yang dibuktikan (tanpa jaringan sama sekali — pengiriman disuntik palsu):
/// 1. Klien mengirim isi yang benar dan mengurai jawaban server.
/// 2. Kegagalan server jadi pesan yang bisa dibaca pengguna.
/// 3. Sesi tersimpan di perangkat, dan "keluar" membersihkan sesi TANPA
///    menyentuh pengaturan lain milik pengguna.
/// 4. Layar masuk menampilkan galat saat gagal, dan menyimpan sesi saat berhasil.
/// 5. Layar akun menampilkan nama/email, dan "Belum masuk" saat belum ada sesi.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/akun/klien_akun.dart';
import 'package:personal_life_os/core/platform/brankas_rahasia.dart';
import 'bantuan/gudang_memori.dart';
import 'package:personal_life_os/core/providers/akun_providers.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/akun_repository.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/features/akun/akun_screen.dart';
import 'package:personal_life_os/features/akun/masuk_screen.dart';

late AppDatabase db;
late PengaturanRepository pengaturan;
late AkunRepository repo;

late GudangMemori gudang;

/// Pengiriman palsu: mencatat panggilan, menjawab sesuai skenario.
class PengirimanUji {
  PengirimanUji({this.balasan, this.galat});

  final Map<String, dynamic>? balasan;
  final AkunGagal? galat;
  final List<String> panggilan = [];
  final List<Map<String, dynamic>?> isi = [];

  Future<Map<String, dynamic>> kirim(
    String metode,
    String jalur, {
    Map<String, dynamic>? isi,
    String? token,
  }) async {
    panggilan.add('$metode $jalur');
    this.isi.add(isi);
    if (galat != null) throw galat!;
    return balasan ?? const {};
  }
}

void main() {
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    pengaturan = PengaturanRepository(db);
    gudang = GudangMemori();
    repo = AkunRepository(pengaturan,
        rahasia: PenyimpanRahasia(pengaturan, gudang: gudang));
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() async => db.close());

  // ------------------------------------------------------------------ klien
  group('Klien akun', () {
    test('daftar mengirim data yang benar & mengurai jawaban', () async {
      final kirim = PengirimanUji(balasan: {
        'token': 'tok-abc',
        'akun': {'email': 'papi@uji.id', 'nama': 'Papi'},
      });
      final klien = KlienAkun(pengirim: kirim.kirim);
      final sesi = await klien.daftar(
          email: 'papi@uji.id ', nama: 'Papi', sandi: 'rahasia123');

      expect(kirim.panggilan, ['POST /daftar']);
      expect(kirim.isi.single!['email'], 'papi@uji.id', reason: 'spasi dipangkas');
      expect(kirim.isi.single!['nama'], 'Papi');
      expect(kirim.isi.single!['sandi'], 'rahasia123');
      expect(sesi.token, 'tok-abc');
      expect(sesi.email, 'papi@uji.id');
      expect(sesi.nama, 'Papi');
    });

    test('masuk memakai jalur /masuk', () async {
      final kirim = PengirimanUji(balasan: {
        'token': 'tok-2',
        'akun': {'email': 'papi@uji.id', 'nama': 'Papi'},
      });
      await KlienAkun(pengirim: kirim.kirim)
          .masuk(email: 'papi@uji.id', sandi: 'rahasia123');
      expect(kirim.panggilan, ['POST /masuk']);
    });

    test('galat server diteruskan sebagai pesan ramah', () async {
      final kirim = PengirimanUji(galat: AkunGagal('Email atau sandi salah.'));
      expect(
        () => KlienAkun(pengirim: kirim.kirim)
            .masuk(email: 'papi@uji.id', sandi: 'xxxxxxxxx'),
        throwsA(isA<AkunGagal>()
            .having((e) => e.pesan, 'pesan', 'Email atau sandi salah.')),
      );
    });

    test('jawaban server yang tidak dikenali tidak dipakai sebagai sesi', () async {
      final kirim = PengirimanUji(balasan: {'tak_dikenal': true});
      expect(
        () => KlienAkun(pengirim: kirim.kirim)
            .masuk(email: 'papi@uji.id', sandi: 'rahasia123'),
        throwsA(isA<AkunGagal>()),
      );
    });

    test('akun tanpa nama memakai email sebagai nama tampilan', () async {
      final kirim = PengirimanUji(
          balasan: {'token': 'tok-3', 'akun': {'email': 'x@y.id'}});
      final sesi = await KlienAkun(pengirim: kirim.kirim)
          .masuk(email: 'x@y.id', sandi: 'rahasia123');
      expect(sesi.nama, 'x@y.id');
    });

    test('alamat server bawaan memakai HTTPS', () {
      expect(alamatServerBawaan.startsWith('https://'), isTrue);
    });
  });

  // --------------------------------------------------------------- penyimpanan
  group('Penyimpanan sesi', () {
    test('belum masuk → tidak ada sesi', () async {
      expect(await repo.sesiTersimpan(), isNull);
    });

    test('simpan lalu baca kembali sesi', () async {
      await repo.simpanSesi(
          const AkunSesi(token: 'tok-a', email: 'papi@uji.id', nama: 'Papi'));
      final sesi = await repo.sesiTersimpan();
      expect(sesi, isNotNull);
      expect(sesi!.email, 'papi@uji.id');
      expect(sesi.nama, 'Papi');
      expect(await repo.token(), 'tok-a');
    });

    test('keluar membersihkan sesi, pengaturan lain tetap utuh', () async {
      await pengaturan.simpan('mode_tema', 'gelap');
      await repo.simpanSesi(
          const AkunSesi(token: 'tok-b', email: 'papi@uji.id', nama: 'Papi'));
      await repo.bersihkanSesi();

      expect(await repo.sesiTersimpan(), isNull);
      expect(await repo.token(), isNull);
      expect(await pengaturan.baca('mode_tema'), 'gelap',
          reason: 'pilihan pengguna lain tidak boleh ikut terhapus');
    });

    test('token akun TIDAK tertinggal polos di tabel pengaturan', () async {
      await repo.simpanSesi(
          const AkunSesi(token: 'tok-c', email: 'papi@uji.id', nama: 'Papi'));
      final semua = await db.select(db.pengaturan).get();
      final kunciAkun = semua
          .where((p) => p.kunci.startsWith('akun_'))
          .map((p) => p.kunci)
          .toSet();
      expect(kunciAkun, {kunciEmailAkun, kunciNamaAkun, kunciMasukPada},
          reason: 'TOKEN disimpan di brankas (Keystore), bukan di basis data');
      expect(gudang.isi[kunciTokenAkun], 'tok-c',
          reason: 'token harus benar-benar ada di brankas');
      expect(await repo.token(), 'tok-c',
          reason: 'token tetap bisa dibaca lewat brankas');
    });
  });

  // ------------------------------------------------------------------- layar
  /// Pembungkus uji: basis data memori + (kalau diberi) klien akun palsu.
  Widget bungkus(Widget child, {KlienAkun? klien}) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          akunRepoProvider.overrideWithValue(repo),
          if (klien != null) klienAkunProvider.overrideWithValue(klien),
        ],
        child: MaterialApp(
          locale: const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: child,
        ),
      );

  testWidgets('layar masuk menampilkan galat saat gagal, tanpa menyimpan sesi',
      (t) async {
    final kirim = PengirimanUji(galat: AkunGagal('Email atau sandi salah.'));
    await t.pumpWidget(bungkus(
        const MasukScreen(), klien: KlienAkun(pengirim: kirim.kirim)));

    await t.enterText(find.byKey(const Key('akun_email')), 'papi@uji.id');
    await t.enterText(find.byKey(const Key('akun_sandi')), 'rahasia123');
    await t.tap(find.byKey(const Key('akun_kirim')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('akun_galat')), findsOneWidget);
    expect(find.text('Email atau sandi salah.'), findsOneWidget);
    expect(await repo.sesiTersimpan(), isNull,
        reason: 'gagal masuk tidak boleh menyimpan sesi');
  });

  testWidgets('layar masuk menyimpan sesi saat berhasil', (t) async {
    final kirim = PengirimanUji(balasan: {
      'token': 'tok-berhasil',
      'akun': {'email': 'papi@uji.id', 'nama': 'Papi'},
    });
    await t.pumpWidget(bungkus(
        const MasukScreen(), klien: KlienAkun(pengirim: kirim.kirim)));

    await t.enterText(find.byKey(const Key('akun_email')), 'papi@uji.id');
    await t.enterText(find.byKey(const Key('akun_sandi')), 'rahasia123');
    await t.tap(find.byKey(const Key('akun_kirim')));
    await t.pumpAndSettle();

    final sesi = await repo.sesiTersimpan();
    expect(sesi, isNotNull);
    expect(sesi!.token, 'tok-berhasil');
    expect(sesi.email, 'papi@uji.id');
  });

  testWidgets('layar masuk menolak sandi terlalu pendek tanpa memanggil server',
      (t) async {
    final kirim = PengirimanUji(balasan: const {});
    await t.pumpWidget(bungkus(
        const MasukScreen(), klien: KlienAkun(pengirim: kirim.kirim)));

    await t.enterText(find.byKey(const Key('akun_email')), 'papi@uji.id');
    await t.enterText(find.byKey(const Key('akun_sandi')), 'pendek');
    await t.tap(find.byKey(const Key('akun_kirim')));
    await t.pumpAndSettle();

    expect(kirim.panggilan, isEmpty, reason: 'tidak perlu menghubungi server');
    expect(find.text('Sandi minimal 8 huruf/angka.'), findsOneWidget);
  });

  testWidgets('layar akun: belum masuk menampilkan ajakan masuk', (t) async {
    await t.pumpWidget(bungkus(const AkunScreen()));
    await t.pumpAndSettle();
    expect(find.text('Belum masuk'), findsOneWidget);
    expect(find.byKey(const Key('buka_masuk')), findsOneWidget);
  });

  testWidgets('layar akun: sudah masuk menampilkan nama & email', (t) async {
    await repo.simpanSesi(
        const AkunSesi(token: 'tok-d', email: 'papi@uji.id', nama: 'Papi'));
    await t.pumpWidget(bungkus(const AkunScreen()));
    await t.pumpAndSettle();
    expect(find.text('Papi'), findsOneWidget);
    expect(find.text('papi@uji.id'), findsOneWidget);
    expect(find.byKey(const Key('keluar_akun')), findsOneWidget);
  });
}
