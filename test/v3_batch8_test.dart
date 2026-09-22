/// Batch 8 — FR-26 (kunci aplikasi), FR-44 (multi-profil), FR-22 (lencana ikon),
/// FR-31 & FR-151 (widget layar utama + aksi langsung).
///
/// Yang dibuktikan (bukan diklaim):
/// 1. FR-26: PIN tidak pernah disimpan apa adanya, PIN salah berkali-kali
///    ditahan sementara, dan tirai kunci benar-benar menahan isi aplikasi
///    sampai PIN yang benar dimasukkan.
/// 2. FR-44: setiap profil punya berkas basis data sendiri (dibuktikan dengan
///    dua basis data terpisah), daftar profil tersimpan di berkas, dan aturan
///    hapus/pindah berjalan.
/// 3. FR-22: angka lencana dihitung dari tagihan yang jatuh tempo/lewat dan
///    benar-benar dikirim ke Android (kanal tiruan mencatat isinya).
/// 4. FR-31: isi widget disusun dari data nyata (7 hari + total + tiga baris)
///    dan dikirim ke Android.
/// 5. FR-151: aksi dari widget ("tandai lunas") benar-benar mengubah data.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/kunci/kunci_aplikasi.dart';
import 'package:personal_life_os/core/kunci/penjaga_kunci.dart';
import 'package:personal_life_os/core/lencana/lencana_ikon.dart';
import 'package:personal_life_os/core/platform/kanal_lencana.dart';
import 'package:personal_life_os/core/platform/kanal_widget.dart';
import 'package:personal_life_os/core/profil/profil.dart';
import 'package:personal_life_os/core/profil/profil_providers.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/widget_utama/aksi_widget.dart';
import 'package:personal_life_os/core/widget_utama/widget_hari_ini.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/pengaturan/profil_screen.dart';

/// Selasa, 22 Sep 2026 pukul 09.00.
final DateTime _kini = DateTime(2026, 9, 22, 9);

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Future<int> _tambahTagihan(
  TagihanRepository repo, {
  required String nama,
  required DateTime jatuhTempo,
  int? sen,
  bool lunas = false,
  bool aktif = true,
}) async {
  final t = await repo.tambah(TagihanCompanion.insert(
    nama: nama,
    jatuhTempo: jatuhTempo,
    jumlahSen: Value(sen),
    lunas: Value(lunas),
    statusAktif: Value(aktif),
  ));
  return t.id;
}

/// Tunggu sampai [syarat] benar — dengan jendela waktu NYATA (bukan jam palsu)
/// supaya pekerjaan basis data & kanal benar-benar selesai.
Future<void> _tungguSampai(
  WidgetTester t,
  bool Function() syarat, {
  int putaran = 40,
}) async {
  for (var i = 0; i < putaran && !syarat(); i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await t.pump(const Duration(milliseconds: 25));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Uji ini sengaja membuka lebih dari satu basis data (membuktikan pemisahan
  // antar-profil), jadi peringatan bawaan drift tidak perlu.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // ══════════════════════════════════════════════════════════════ FR-26
  group('FR-26 kunci aplikasi — logika', () {
    late AppDatabase db;
    late KunciAplikasi kunci;

    setUp(() {
      db = _db();
      kunci = KunciAplikasi(PengaturanRepository(db), iterasi: 1000);
    });
    tearDown(() => db.close());

    test('PIN disimpan sebagai turunan, bukan PIN mentah', () async {
      await kunci.pasangPin('246813');
      expect(await kunci.aktif(), isTrue);
      final turunan = await db.select(db.pengaturan).get();
      final teks = turunan.map((p) => '${p.kunci}=${p.nilai}').join('|');
      expect(teks.contains('246813'), isFalse,
          reason: 'PIN mentah tidak boleh tersimpan');
      expect(await kunci.buka('246813'), isA<HasilBukaKunci>());
      expect((await kunci.buka('246813')).berhasil, isTrue);
    });

    test('PIN salah ditolak & sisa kesempatan berkurang', () async {
      await kunci.pasangPin('246813');
      final h1 = await kunci.buka('111111');
      expect(h1.berhasil, isFalse);
      expect(h1.sisaPercobaan, kunciPercobaanMaks - 1);
      final h2 = await kunci.buka('222222');
      expect(h2.sisaPercobaan, kunciPercobaanMaks - 2);
    });

    test('lima kali salah → percobaan ditahan sementara', () async {
      await kunci.pasangPin('246813');
      for (var i = 0; i < kunciPercobaanMaks; i++) {
        await kunci.buka('000000');
      }
      final tertahan = await kunci.buka('246813');
      expect(tertahan.berhasil, isFalse,
          reason: 'walau PIN benar, tahanan sementara tetap berlaku');
      expect(tertahan.tungguSampai, isNotNull);
      expect(tertahan.pesan, contains('Terlalu banyak percobaan'));
      expect(await kunci.tungguSampai(), isNotNull);
    });

    test('PIN terlalu pendek / satu angka semua ditolak', () async {
      expect(() => kunci.pasangPin('123'),
          throwsA(isA<ArgumenPinTidakSah>()));
      expect(() => kunci.pasangPin('1111'),
          throwsA(isA<ArgumenPinTidakSah>()));
      expect(() => kunci.pasangPin('abcd'),
          throwsA(isA<ArgumenPinTidakSah>()));
      expect(KunciAplikasi.keluhanPin('1234'), isNull);
    });

    test('matikan kunci menghapus turunan & mematikan saklar', () async {
      await kunci.pasangPin('246813');
      await kunci.matikan();
      expect(await kunci.aktif(), isFalse);
      final sisa = await db.customSelect(
        'SELECT COUNT(*) AS n FROM pengaturan WHERE kunci IN (?, ?)',
        variables: [
          const Variable<String>(kunciKunciTurunan),
          const Variable<String>(kunciKunciGaram),
        ],
      ).getSingle();
      expect(sisa.read<int>('n'), 0,
          reason: 'turunan & garam PIN dihapus saat kunci dimatikan');
    });

    test('PBKDF2: garam berbeda → turunan berbeda, jumlah byte tetap 32', () {
      final a = hitungPbkdf2('246813', List<int>.filled(16, 1), iterasi: 200);
      final b = hitungPbkdf2('246813', List<int>.filled(16, 2), iterasi: 200);
      final c = hitungPbkdf2('246813', List<int>.filled(16, 1), iterasi: 200);
      expect(a.length, 32);
      expect(a, equals(c), reason: 'sandi & garam sama → hasil sama');
      expect(a, isNot(equals(b)), reason: 'garam beda → hasil beda');
    });

    test('masa tenggang bisa diatur', () async {
      expect(await kunci.tenggangDetik(), kunciTenggangBawaan);
      await kunci.simpanTenggang(60);
      expect(await kunci.tenggangDetik(), 60);
    });
  });

  group('FR-26 layar kunci menahan isi aplikasi', () {
    testWidgets('isi aplikasi tersembunyi sampai PIN benar', (t) async {
      final db = _db();
      addTearDown(db.close);
      final kunci = KunciAplikasi(PengaturanRepository(db), iterasi: 1000);
      await kunci.pasangPin('246813');

      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          home: PenjagaKunci(child: Text('RAHASIA-BASIS-DATA')),
        ),
      ));
      await _tungguSampai(
          t, () => find.text('Aplikasi terkunci').evaluate().isNotEmpty);
      expect(find.text('Aplikasi terkunci'), findsOneWidget);
      expect(find.text('RAHASIA-BASIS-DATA'), findsNothing,
          reason: 'isi aplikasi tidak boleh terlihat saat terkunci');

      await t.enterText(find.byKey(const Key('pin_kunci')), '999999');
      await t.tap(find.byKey(const Key('buka_kunci')));
      await _tungguSampai(
          t, () => find.byKey(const Key('pesan_kunci')).evaluate().isNotEmpty);
      expect(find.text('RAHASIA-BASIS-DATA'), findsNothing);

      await t.enterText(find.byKey(const Key('pin_kunci')), '246813');
      await t.tap(find.byKey(const Key('buka_kunci')));
      await _tungguSampai(
          t, () => find.text('RAHASIA-BASIS-DATA').evaluate().isNotEmpty);
      expect(find.text('RAHASIA-BASIS-DATA'), findsOneWidget);
    });

    testWidgets('kunci mati → aplikasi langsung terbuka', (t) async {
      final db = _db();
      addTearDown(db.close);
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          home: PenjagaKunci(child: Text('LANGSUNG-TERBUKA')),
        ),
      ));
      await _tungguSampai(
          t, () => find.text('LANGSUNG-TERBUKA').evaluate().isNotEmpty);
      expect(find.text('LANGSUNG-TERBUKA'), findsOneWidget);
      expect(find.text('Aplikasi terkunci'), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════ FR-44
  group('FR-44 multi-profil', () {
    test('profil pribadi memakai nama berkas lama (data tidak hilang)', () {
      expect(namaBerkasDatabase(idProfilPribadi), 'personal_life_os');
      expect(namaBerkasDatabase('usaha-toko'), 'personal_life_os_usaha-toko');
    });

    test('tambah / pindah / ganti nama / hapus tersimpan di berkas', () async {
      final folder = Directory.systemTemp.createTempSync('lifeos_profil_');
      addTearDown(() => folder.deleteSync(recursive: true));
      final layanan = ProfilLayanan(folder: folder);

      expect((await layanan.muat()).aktif, idProfilPribadi);

      var daftar = await layanan.tambah('Usaha Toko', JenisProfil.usaha);
      expect(daftar.daftar.length, 2);
      expect(daftar.daftar.last.id, 'usaha-toko');
      expect(daftar.aktif, idProfilPribadi, reason: 'tambah ≠ pindah');

      // Terbaca lagi dari berkas (bukan hanya di memori).
      final lagi = await ProfilLayanan(folder: folder).muat();
      expect(lagi.daftar.length, 2);

      daftar = await layanan.ganti('usaha-toko');
      expect(daftar.aktif, 'usaha-toko');
      expect(daftar.namaBerkasAktif, 'personal_life_os_usaha-toko');

      daftar = await layanan.gantiNama('usaha-toko', 'Toko Kelontong');
      expect(daftar.profilAktif.nama, 'Toko Kelontong');

      daftar = await layanan.ganti(idProfilPribadi);
      daftar = await layanan.hapus('usaha-toko');
      expect(daftar.daftar.length, 1);
    });

    test('profil "Pribadi" & profil aktif tidak bisa dihapus', () async {
      final folder = Directory.systemTemp.createTempSync('lifeos_profil_');
      addTearDown(() => folder.deleteSync(recursive: true));
      final layanan = ProfilLayanan(folder: folder);
      await layanan.tambah('Keluarga', JenisProfil.keluarga);
      await layanan.ganti('keluarga');

      await expectLater(
          layanan.hapus(idProfilPribadi), throwsA(isA<ArgumenProfil>()));
      await expectLater(
          layanan.hapus('keluarga'), throwsA(isA<ArgumenProfil>()),
          reason: 'profil yang sedang dipakai harus dipindah dulu');

      // Setelah pindah kembali ke Pribadi, profil lain bisa dihapus.
      await layanan.ganti(idProfilPribadi);
      final sisa = await layanan.hapus('keluarga');
      expect(sisa.daftar.length, 1);
      expect(sisa.daftar.single.id, idProfilPribadi);
    });

    test('nama kosong & id ganda ditolak/dirapikan', () async {
      final folder = Directory.systemTemp.createTempSync('lifeos_profil_');
      addTearDown(() => folder.deleteSync(recursive: true));
      final layanan = ProfilLayanan(folder: folder);
      expect(() => layanan.tambah('   ', JenisProfil.pribadi),
          throwsA(isA<ArgumenProfil>()));
      final daftar = await layanan.tambah('Usaha', JenisProfil.usaha);
      expect(daftar.daftar.last.id, 'usaha');
    });

    test('dua profil = dua berkas basis data, data tidak bercampur', () async {
      final folder = Directory.systemTemp.createTempSync('lifeos_profil_');
      addTearDown(() => folder.deleteSync(recursive: true));
      final a = AppDatabase.forTesting(
          NativeDatabase(File('${folder.path}/personal_life_os.sqlite')));
      final b = AppDatabase.forTesting(
          NativeDatabase(File('${folder.path}/personal_life_os_usaha.sqlite')));
      addTearDown(() async {
        await a.close();
        await b.close();
      });

      await _tambahTagihan(TagihanRepository(a),
          nama: 'Listrik', jatuhTempo: DateTime(2026, 9, 25), sen: 350000);
      expect((await a.select(a.tagihan).get()).length, 1);
      expect((await b.select(b.tagihan).get()).length, 0,
          reason: 'profil lain tidak melihat data profil ini');

      await _tambahTagihan(TagihanRepository(b),
          nama: 'Sewa toko', jatuhTempo: DateTime(2026, 9, 26), sen: 1500000);
      expect((await a.select(a.tagihan).get()).single.nama, 'Listrik');
      expect((await b.select(b.tagihan).get()).single.nama, 'Sewa toko');
    });

    test('pindah profil mengubah profil aktif & berkas basis datanya', () async {
      final folder = Directory.systemTemp.createTempSync('lifeos_profil_');
      addTearDown(() => folder.deleteSync(recursive: true));
      final layanan = ProfilLayanan(folder: folder);
      final awal = await layanan.tambah('Usaha', JenisProfil.usaha);

      final wadah = ProviderContainer(overrides: [
        profilLayananProvider.overrideWithValue(layanan),
        profilAwalProvider.overrideWithValue(awal),
      ]);
      addTearDown(wadah.dispose);

      expect(wadah.read(profilAktifProvider).aktif, idProfilPribadi);
      expect(wadah.read(profilAktifProvider).namaBerkasAktif,
          'personal_life_os');

      await wadah.read(profilAktifProvider.notifier).ganti('usaha');
      expect(wadah.read(profilAktifProvider).aktif, 'usaha');
      expect(wadah.read(profilAktifProvider).namaBerkasAktif,
          'personal_life_os_usaha',
          reason: 'berpindah profil = berpindah berkas basis data');
    });

    testWidgets('layar profil menampilkan semua profil & tombol pindah',
        (t) async {
      final db = _db();
      addTearDown(db.close);
      final folder = Directory.systemTemp.createTempSync('lifeos_profil_');
      addTearDown(() => folder.deleteSync(recursive: true));
      final layanan = ProfilLayanan(folder: folder);
      // Pekerjaan berkas NYATA wajib lewat runAsync: di dalam uji widget waktu
      // dipalsukan, sehingga penulisan berkas tidak pernah selesai dan uji
      // MENGGANTUNG (bukan gagal) — pernah terjadi pada uji ini.
      final awal = (await t.runAsync(
          () => layanan.tambah('Usaha', JenisProfil.usaha)))!;

      await t.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          profilLayananProvider.overrideWithValue(layanan),
          profilAwalProvider.overrideWithValue(awal),
        ],
        child: const MaterialApp(home: ProfilScreen()),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('profil_pribadi')), findsOneWidget);
      expect(find.byKey(const Key('profil_usaha')), findsOneWidget);
      expect(find.byKey(const Key('pindah_usaha')), findsOneWidget);
      expect(find.textContaining('sedang dipakai'), findsOneWidget);

      // Tombol "Tambah profil" ada di BAWAH lipatan: daftar itu malas, jadi
      // gulir dulu baru periksa (bukan berarti tombolnya tidak ada).
      await t.dragUntilVisible(
        find.byKey(const Key('tambah_profil')),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      await t.pump();
      expect(find.byKey(const Key('tambah_profil')), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 90)));
  });

  // ══════════════════════════════════════════════════════════════ FR-22
  group('FR-22 lencana ikon', () {
    test('dihitung dari tagihan jatuh tempo hari ini atau sudah lewat', () {
      final jumlah = jumlahLencana([
        (jatuhTempo: _kini, lunas: false, statusAktif: true),
        (jatuhTempo: _kini.subtract(const Duration(days: 3)),
            lunas: false, statusAktif: true),
        (jatuhTempo: _kini.add(const Duration(days: 2)),
            lunas: false, statusAktif: true),
        (jatuhTempo: _kini, lunas: true, statusAktif: true),
        (jatuhTempo: _kini, lunas: false, statusAktif: false),
      ], _kini);
      expect(jumlah, 2, reason: 'besok, lunas, dan nonaktif tidak dihitung');
    });

    test('angka lencana benar-benar dikirim lewat kanal Android', () async {
      final dicatat = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel(namaKanalLencana), (panggilan) async {
        if (panggilan.method == 'pasang') {
          dicatat.add((panggilan.arguments as Map)['jumlah'] as int);
        }
        return true;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel(namaKanalLencana), null));

      final jumlah = await kirimLencana(
        baca: () async => [
          (jatuhTempo: _kini, lunas: false, statusAktif: true),
          (jatuhTempo: _kini.add(const Duration(days: 3)),
              lunas: false,
              statusAktif: true),
        ],
        kanal: const LencanaIkon(),
        nyala: true,
        sekarang: _kini,
      );
      expect(jumlah, 1);
      expect(dicatat, [1], reason: 'angka dikirim ke peluncur');
    });

    test('saklar lencana mati → angka 0 dikirim (lencana dibersihkan)',
        () async {
      final dicatat = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel(namaKanalLencana), (panggilan) async {
        if (panggilan.method == 'pasang') {
          dicatat.add((panggilan.arguments as Map)['jumlah'] as int);
        }
        return true;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel(namaKanalLencana), null));

      final jumlah = await kirimLencana(
        baca: () async =>
            [(jatuhTempo: _kini, lunas: false, statusAktif: true)],
        kanal: const LencanaIkon(),
        nyala: false,
        sekarang: _kini,
      );
      expect(jumlah, 0);
      expect(dicatat, [0]);
    });

    test('kanal lencana mengembalikan false bila Android tidak menjawab',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(namaKanalLencana),
              (panggilan) async => null);
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel(namaKanalLencana), null));
      expect(await const LencanaIkon().pasang(3), isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════ FR-31
  group('FR-31 & FR-151 widget layar utama', () {
    test('isi widget: 7 hari ke depan, total, tiga baris terdekat', () {
      final ringkas = susunRingkasWidget([
        (id: 1, nama: 'Listrik', jatuhTempo: DateTime(2026, 9, 22, 8), jumlahSen: 350000),
        (id: 2, nama: 'Internet', jatuhTempo: DateTime(2026, 9, 24), jumlahSen: 400000),
        (id: 3, nama: 'Air', jatuhTempo: DateTime(2026, 9, 26), jumlahSen: 150000),
        (id: 4, nama: 'Sewa', jatuhTempo: DateTime(2026, 10, 20), jumlahSen: 5000000),
        (id: 5, nama: 'Kartu', jatuhTempo: DateTime(2026, 9, 27), jumlahSen: 250000),
      ], _kini);

      expect(ringkas.judul, '1 tagihan jatuh tempo hari ini');
      // Jumlah disimpan dalam SEN: 1.150.000 sen = Rp 11.500.
      expect(ringkas.total, contains('11.500'),
          reason: 'hanya tagihan dalam 7 hari yang dijumlahkan');
      expect(ringkas.baris.length, 3, reason: 'widget hanya memuat 3 baris');
      expect(ringkas.baris.first, contains('Listrik'));
      expect(ringkas.baris.first, contains('Rp'));
      expect(ringkas.idBaris, ['1', '2', '3']);
      expect(ringkas.aksiId, '1', reason: 'aksi lunas = tagihan terdekat');
      expect(ringkas.catatan, contains('Diperbarui'));
    });

    test('tanpa tagihan: judul jujur & tidak ada tombol aksi', () {
      final ringkas = susunRingkasWidget(const [], _kini);
      expect(ringkas.judul, '0 tagihan 7 hari ke depan');
      expect(ringkas.baris, isEmpty);
      expect(ringkas.aksiId, isNull);
    });

    test('isi widget benar-benar dikirim lewat kanal Android', () async {
      final dikirim = <Map<Object?, Object?>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel(namaKanalWidget), (panggilan) async {
        if (panggilan.method == 'perbarui') {
          dikirim.add((panggilan.arguments as Map).cast<Object?, Object?>());
        }
        return true;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel(namaKanalWidget), null));

      final ringkas = await kirimWidgetRingkas(
        baca: () async => [
          (
            id: 7,
            nama: 'Listrik',
            jatuhTempo: DateTime(2026, 9, 22, 8),
            jumlahSen: 350000,
          ),
        ],
        kanal: const KanalWidget(),
        nyala: true,
        sekarang: _kini,
      );

      expect(ringkas.baris.single, contains('Listrik'));
      expect(dikirim, isNotEmpty);
      expect((dikirim.first['baris'] as List).first, contains('Listrik'));
      expect(dikirim.first['aksiId'], '7',
          reason: 'tombol lunas di widget menunjuk tagihan terdekat');
    });

    test('saklar widget mati → isi dikosongkan dengan keterangan jujur',
        () async {
      final dikirim = <Map<Object?, Object?>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel(namaKanalWidget), (panggilan) async {
        if (panggilan.method == 'perbarui') {
          dikirim.add((panggilan.arguments as Map).cast<Object?, Object?>());
        }
        return true;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel(namaKanalWidget), null));

      final ringkas = await kirimWidgetRingkas(
        baca: () async => [
          (
            id: 7,
            nama: 'Listrik',
            jatuhTempo: DateTime(2026, 9, 22, 8),
            jumlahSen: 350000,
          ),
        ],
        kanal: const KanalWidget(),
        nyala: false,
        sekarang: _kini,
      );
      expect(ringkas.judul, 'Widget dimatikan');
      expect(ringkas.baris, isEmpty);
    });

    test('aksi "lunas" dari widget benar-benar mengubah data', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = TagihanRepository(db);
      final id = await _tambahTagihan(repo,
          nama: 'Listrik', jatuhTempo: DateTime(2026, 9, 25), sen: 350000);

      final hasil = await AksiWidgetLayanan(repo)
          .jalankan(AksiWidget(aksi: 'lunas', id: '$id'));

      expect(hasil.pesan, contains('Listrik'));
      expect(hasil.pesan, contains('lunas'));
      // Tagihan berulang (bulanan): pembayaran dicatat sebagai riwayat dan
      // jatuh tempo maju ke periode berikutnya. Jadi yang diperiksa bukan
      // `lunas`, melainkan bukti pembayaran yang benar-benar tertulis.
      final riwayat = await db.select(db.riwayatPembayaran).get();
      expect(riwayat.map((r) => r.tagihanId), contains(id),
          reason: 'aksi widget menulis ke basis data yang sama');
      final sesudah = await repo.ambilSemua();
      expect(sesudah.single.jatuhTempo, DateTime(2026, 10, 25),
          reason: 'jatuh tempo maju satu bulan setelah dibayar');
    });

    test('aksi "lunas" pada tagihan yang sudah lunas tidak menggandakan',
        () async {
      final db = _db();
      addTearDown(db.close);
      final repo = TagihanRepository(db);
      final id = await _tambahTagihan(repo,
          nama: 'Internet',
          jatuhTempo: DateTime(2026, 9, 25),
          sen: 400000,
          lunas: true);
      final hasil = await AksiWidgetLayanan(repo)
          .jalankan(AksiWidget(aksi: 'lunas', id: '$id'));
      expect(hasil.pesan, contains('sudah ditandai lunas'));
      expect((await repo.ambilSemua()).single.lunas, isTrue);
    });

    test('aksi pada id yang tidak ada → pesan jujur, bukan galat', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = TagihanRepository(db);
      final hasil = await AksiWidgetLayanan(repo)
          .jalankan(const AksiWidget(aksi: 'lunas', id: '999'));
      expect(hasil.pesan, contains('tidak ada lagi'));
    });

    test('aksi cepat "catat pengeluaran" mengarah ke form pengeluaran', () async {
      final db = _db();
      addTearDown(db.close);
      final hasil = await AksiWidgetLayanan(TagihanRepository(db))
          .jalankan(const AksiWidget(aksi: 'tambah-pengeluaran'));
      expect(hasil.rute, '/uang/transaksi');
      final takDikenal = await AksiWidgetLayanan(TagihanRepository(db))
          .jalankan(const AksiWidget(aksi: 'menari'));
      expect(takDikenal.pesan, contains('belum dikenal'));
    });

    test('aksi dari Android dibaca apa adanya', () {
      expect(AksiWidget.dariPeta({'aksi': 'lunas', 'id': '7'})?.id, '7');
      expect(AksiWidget.dariPeta({'aksi': 'lunas'})?.id, isNull);
      expect(AksiWidget.dariPeta({'id': '7'}), isNull);
      expect(AksiWidget.dariPeta('bukan peta'), isNull);
    });
  });
}
