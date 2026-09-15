/// Uji FR-08 — kategori kustom + ikon & warna per kategori.
///
/// Dua lapis:
///  1. aturan data (`RepoKategoriTagihan`) + peta ikon/warna — `test()`;
///  2. layar "Kategori tagihan", form tagihan, dan daftar tagihan —
///     `testWidgets()` pada layar ponsel 420x900.
///
/// Kriteria terima: kategori bisa ditambah/diubah/dihapus pengguna, ikon &
/// warna ikut terlihat di form dan daftar, urutan bisa diatur, dan menghapus
/// kategori yang masih dipakai TIDAK menghapus tagihannya (dipindahkan ke
/// "Tanpa kategori").
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value, OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/tagihan/daftar_tagihan_screen.dart';
import 'package:personal_life_os/features/tagihan/form_tagihan_screen.dart';
import 'package:personal_life_os/features/tagihan/ikon_warna_kategori.dart';
import 'package:personal_life_os/features/tagihan/kelola_kategori_tagihan_screen.dart';

late AppDatabase db;
late RepoKategoriTagihan repo;
late TagihanRepository repoT;

/// Waktu uji dikunci: 15 September 2026, 09.00.
final jamUji = DateTime(2026, 9, 15, 9);

/// Semua kategori, urut seperti yang dilihat pengguna.
Future<List<KategoriData>> semuaKategori() => repo.ambilSemua();

Future<KategoriData> kategoriBernama(String nama) async =>
    (await semuaKategori()).firstWhere((k) => k.nama == nama);

Future<KategoriData?> kategoriDenganId(int id) async =>
    (await semuaKategori()).where((k) => k.id == id).firstOrNull;

/// Tagihan uji — jumlah eksplisit Rp 125.000.
Future<TagihanData> tagihanBaru(String nama, {int? kategoriId}) =>
    repoT.tambah(TagihanCompanion.insert(
      nama: nama,
      jumlahSen: const Value(12500000),
      jatuhTempo: DateTime(2026, 9, 20),
      kategoriId: Value(kategoriId),
    ));

/// Semua tagihan lewat query Future (bukan stream) — di dalam testWidgets
/// menunggu stream Drift akan menggantung.
Future<List<TagihanData>> semuaTagihan() =>
    (db.select(db.tagihan)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

/// Halaman berjudul (meniru pembungkus form di rute aplikasi).
class _HalamanJudul extends StatelessWidget {
  const _HalamanJudul({required this.judul, required this.isi});

  final String judul;
  final Widget isi;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(judul)), body: isi);
}

/// Router kecil milik uji ini sendiri.
///
/// Sengaja TIDAK memakai `app_router.dart`: uji FR-08 hanya butuh dua rute,
/// jadi uji ini tidak ikut gagal saat ada layar lain yang sedang diubah.
GoRouter routerUji({String awal = '/tagihan'}) => GoRouter(
      initialLocation: awal,
      routes: [
        GoRoute(
          path: '/tagihan',
          builder: (c, s) => Scaffold(
            body: const DaftarTagihanScreen(),
            floatingActionButton: FloatingActionButton.extended(
              key: const Key('tambah_tagihan_uji'),
              onPressed: () => GoRouter.of(c).push('/tambah'),
              icon: const Icon(Icons.add),
              label: const Text('Tagihan'),
            ),
          ),
        ),
        GoRoute(
          path: '/tambah',
          builder: (c, s) => const _HalamanJudul(
              judul: 'Tambah Tagihan', isi: FormTagihanScreen()),
        ),
      ],
    );

/// Folder font bawaan Flutter SDK — sama seperti uji tangkapan layar.
///
/// Tanpa font ini mesin uji memakai font kotak (tiap huruf selebar font),
/// sehingga baris ringkasan pada layar tagihan terlihat lebih lebar daripada
/// di perangkat sungguhan.
const String _folderFont =
    '/workspace/tools/flutter/bin/cache/artifacts/material_fonts/';

bool get _fontAsliTersedia =>
    File('${_folderFont}Roboto-Regular.ttf').existsSync();

/// Ukuran layar uji. Font kotak mesin uji lebih lebar, jadi layar dilebarkan
/// supaya tidak ada laporan meluber yang keliru.
Size get ukuranLayar =>
    _fontAsliTersedia ? const Size(420, 900) : const Size(760, 900);

Future<void> _muatFont(String nama, List<String> berkas) async {
  final loader = FontLoader(nama);
  for (final b in berkas) {
    final data = File('$_folderFont$b').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(data.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    if (_fontAsliTersedia) {
      await _muatFont('Roboto', const [
        'Roboto-Regular.ttf',
        'Roboto-Medium.ttf',
        'Roboto-Bold.ttf',
      ]);
      await _muatFont('MaterialIcons', const ['MaterialIcons-Regular.otf']);
    }
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = RepoKategoriTagihan(db);
    repoT = TagihanRepository(db);
    TestWidgetsFlutterBinding.ensureInitialized();
    // Sentuh tabel kategori sekali supaya migrasi + seed bawaan selesai jalan.
    await db.select(db.kategori).get();
  });

  tearDown(() async => db.close());

  // =====================================================================
  // 1. Aturan data
  // =====================================================================

  group('FR-08 seed bawaan', () {
    test('aplikasi baru menyemai 10 kategori bawaan satu kali (idempoten)',
        () async {
      final semua = await semuaKategori();
      expect(semua, hasLength(10));
      expect(semua.map((k) => k.nama).toSet(), hasLength(10));
      expect(semua.first.nama, 'PLN');
      expect(semua.first.ikon, 'bolt');
      expect(semua.first.warna, '#F5A623');
      // Nomor urut rapi 0..9 sejak awal.
      expect(semua.map((k) => k.urutan).toList(), List.generate(10, (i) => i));
    });

    test('nama kategori bawaan boleh diubah tanpa menyemai ulang', () async {
      final pln = await kategoriBernama('PLN');
      await repo.ubah(pln.id, nama: 'Listrik PLN', ikon: pln.ikon, warna: pln.warna);

      expect((await kategoriBernama('Listrik PLN')).id, pln.id);
      expect(await semuaKategori(), hasLength(10),
          reason: 'mengubah nama tidak boleh menambah kategori baru');
    });
  });

  group('FR-08 tambah / ubah kategori', () {
    test('tambah kategori baru tampil di urutan terakhir', () async {
      final baru = await repo.tambah(
          nama: '  Hobi Laut  ', ikon: 'pets', warna: '#8E24AA');

      expect(baru.nama, 'Hobi Laut', reason: 'spasi tepi dipangkas');
      expect(baru.ikon, 'pets');
      expect(baru.warna, '#8E24AA');
      expect(baru.urutan, 10);

      final semua = await semuaKategori();
      expect(semua, hasLength(11));
      expect(semua.last.id, baru.id);
    });

    test('ubah nama + ikon + warna tersimpan dan terbaca kembali', () async {
      final k = await repo.tambah(nama: 'Hobi', ikon: 'pets', warna: '#8E24AA');

      final berubah = await repo.ubah(k.id,
          nama: 'Hobi Laut', ikon: 'music_note', warna: '#E53935');

      expect(berubah, 1);
      final lagi = (await kategoriDenganId(k.id))!;
      expect(lagi.nama, 'Hobi Laut');
      expect(lagi.ikon, 'music_note');
      expect(lagi.warna, '#E53935');
      expect(lagi.urutan, k.urutan, reason: 'ubah nama tidak menggeser urutan');
    });

    test('ubah nama TIDAK mengubah kategoriId tagihan yang sudah ada',
        () async {
      final k = await repo.tambah(nama: 'Listrik', ikon: 'bolt', warna: '#F5A623');
      final t = await tagihanBaru('Token listrik', kategoriId: k.id);

      await repo.ubah(k.id,
          nama: 'Listrik rumah', ikon: 'bolt', warna: '#FFB74D');

      final setelah = (await semuaTagihan()).firstWhere((x) => x.id == t.id);
      expect(setelah.kategoriId, k.id, reason: 'hubungan tagihan tetap');
      expect((await kategoriDenganId(k.id))!.nama, 'Listrik rumah');
    });

    test('nama kosong / terlalu panjang ditolak', () async {
      expect(() => repo.namaBersih('   '), throwsArgumentError);
      expect(() => repo.namaBersih(''), throwsArgumentError);
      expect(() => repo.namaBersih('a' * 61), throwsArgumentError);
      expect(repo.namaBersih('a' * 60), 'a' * 60);

      await expectLater(repo.tambah(nama: '  '), throwsArgumentError);
      await expectLater(
          repo.tambah(nama: 'x' * 61), throwsArgumentError);
      expect(await semuaKategori(), hasLength(10),
          reason: 'nama tidak sah tidak boleh menulis baris apa pun');
    });

    test('ikon / warna tak dikenal dirapikan ke nilai bawaan saat disimpan',
        () async {
      final k = await repo.tambah(
          nama: 'Aneh', ikon: 'ikon_ajaib_999', warna: 'bukan-warna');

      expect(k.ikon, RepoKategoriTagihan.ikonCadangan);
      expect(k.warna, heksWarnaTagihanBawaan);
      // Heks kecil huruf dirapikan ke huruf besar.
      final k2 = await repo.tambah(nama: 'Teal', warna: '#00897b');
      expect(k2.warna, '#00897B');
    });
  });

  group('FR-08 hapus kategori', () {
    test('hapus kategori yang dipakai 2 tagihan: tagihan tetap ada, '
        'kategoriId jadi null, jumlah pemakai 0', () async {
      final k = await repo.tambah(nama: 'Sekolah Anak', ikon: 'school', warna: '#FFB74D');
      final a = await tagihanBaru('SPP September', kategoriId: k.id);
      final b = await tagihanBaru('Buku tahunan', kategoriId: k.id);
      expect(await repo.jumlahPemakai(k.id), 2);

      final hasil = await repo.hapus(k.id);

      expect(hasil.nama, 'Sekolah Anak');
      expect(hasil.tagihanDipindah, 2);
      expect(await kategoriDenganId(k.id), isNull);
      final sisa = await semuaTagihan();
      expect(sisa, hasLength(2), reason: 'tagihan tidak boleh ikut terhapus');
      expect(sisa.map((t) => t.id).toList(), containsAll([a.id, b.id]));
      expect(sisa.every((t) => t.kategoriId == null), isTrue);
      expect(await repo.jumlahPemakai(k.id), 0);
    });

    test('hapus kategori tanpa pemakai: langsung hilang, tagihan tak tersentuh',
        () async {
      final k = await repo.tambah(nama: 'Cadangan', ikon: 'park', warna: '#4CAF50');
      final t = await tagihanBaru('Tagihan lain');

      final hasil = await repo.hapus(k.id);

      expect(hasil.tagihanDipindah, 0);
      expect(await kategoriDenganId(k.id), isNull);
      final sisa = await semuaTagihan();
      expect(sisa, hasLength(1));
      expect(sisa.first.id, t.id);
      expect(sisa.first.kategoriId, isNull);
    });

    test('hapus kategori yang sudah tidak ada: aman (tidak melempar)', () async {
      final hasil = await repo.hapus(9999);
      expect(hasil.nama, '');
      expect(hasil.tagihanDipindah, 0);
      expect(await semuaKategori(), hasLength(10));
    });
  });

  group('FR-08 urutan', () {
    test('naik & turun menggeser satu langkah dan disimpan di kolom urutan',
        () async {
      var semua = await semuaKategori();
      final awal = semua.map((k) => k.nama).toList();
      final kedua = semua[1];

      expect(await repo.geser(kedua.id, naik: true), isTrue);
      semua = await semuaKategori();
      expect(semua.map((k) => k.nama).toList(),
          [awal[1], awal[0], ...awal.sublist(2)]);
      expect(semua.map((k) => k.urutan).toList(), List.generate(10, (i) => i));

      expect(await repo.geser(kedua.id, naik: false), isTrue);
      semua = await semuaKategori();
      expect(semua.map((k) => k.nama).toList(), awal);
    });

    test('geser di ujung tidak mengubah apa pun', () async {
      final semua = await semuaKategori();
      expect(await repo.geser(semua.first.id, naik: true), isFalse);
      expect(await repo.geser(semua.last.id, naik: false), isFalse);
      expect(await repo.geser(9999, naik: true), isFalse);
      expect((await semuaKategori()).map((k) => k.nama).toList(),
          semua.map((k) => k.nama).toList());
    });
  });

  group('FR-08 ikon & warna aman terhadap nilai tak dikenal', () {
    test('nama ikon dikenal diterjemahkan, yang lain memakai bawaan', () {
      expect(ikonTagihan('bolt'), Icons.bolt);
      expect(ikonTagihan('water_drop'), Icons.water_drop);
      expect(ikonTagihan('  wifi '), Icons.wifi);
      expect(ikonTagihan('receipt'), Icons.receipt);

      for (final aneh in <String?>[null, '', '   ', 'ikon_ajaib_999', 'BOLT']) {
        expect(ikonTagihan(aneh), ikonTagihanBawaan,
            reason: 'nilai "$aneh" harus jatuh ke ikon bawaan tanpa galat');
      }
      expect(namaIkonTagihanDikenal('bolt'), isTrue);
      expect(namaIkonTagihanDikenal('ikon_ajaib_999'), isFalse);
    });

    test('teks heks diterjemahkan, yang tidak sah memakai warna bawaan', () {
      expect(warnaTagihan('#F5A623'), const Color(0xFFF5A623));
      expect(warnaTagihan('f5a623'), const Color(0xFFF5A623));
      expect(warnaTagihan('#FF00897B'), const Color(0xFF00897B));

      for (final aneh in <String?>[
        null,
        '',
        '   ',
        'bukan-warna',
        '#12345',
        '#GGGGGG',
        'merah',
        '#FF',
      ]) {
        expect(warnaTagihan(aneh), warnaTagihanBawaan,
            reason: 'nilai "$aneh" harus jatuh ke warna bawaan tanpa galat');
      }
      expect(heksDariWarnaTagihan(const Color(0xFF4A90D9)), '#4A90D9');
      expect(heksWarnaTagihanDikenal('#f5a623'), isTrue);
      expect(heksWarnaTagihanDikenal('#123456'), isFalse);
    });

    test('baris kategori berisi nilai tak dikenal tetap terbaca aman',
        () async {
      // Baris "asing" (mis. sisa versi lain) yang tidak lewat layar pengguna.
      await db.into(db.kategori).insert(KategoriCompanion.insert(
            nama: 'Kategori Misteri',
            ikon: const Value('ikon_ajaib_999'),
            warna: const Value('bukan-warna'),
            urutan: const Value(99),
          ));

      final asing = await kategoriBernama('Kategori Misteri');
      expect(ikonTagihan(asing.ikon), ikonTagihanBawaan);
      expect(warnaTagihan(asing.warna), warnaTagihanBawaan);
      expect(await semuaKategori(), hasLength(11));
    });
  });

  // =====================================================================
  // 2. Layar
  // =====================================================================

  /// Pompa berulang: pembaruan Drift butuh beberapa pump.
  Future<void> pumpDrift(WidgetTester t) async {
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  /// Tampilkan layar langsung (tanpa router) pada ukuran ponsel 420x900.
  Future<void> tampilkan(WidgetTester t, Widget layar) async {
    await t.binding.setSurfaceSize(ukuranLayar);
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
    await pumpDrift(t);
  }

  /// Buka lewat rute aplikasi sungguhan (untuk alur form + daftar).
  Future<void> buka(WidgetTester t, {String awal = '/tagihan'}) async {
    await t.binding.setSurfaceSize(ukuranLayar);
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(
        theme: AppTema.terang(),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: routerUji(awal: awal),
      ),
    ));
    await pumpDrift(t);
  }

  /// Tutup layar: pompa SizedBox lalu bersihkan, hindari stream Drift menggantung.
  Future<void> tutup(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 50));
    await t.binding.setSurfaceSize(null);
  }

  /// Gulir sampai target benar-benar terlihat (ListView itu malas).
  Future<void> gulirKe(WidgetTester t, Finder target, {int maks = 10}) async {
    for (var i = 0; i < maks; i++) {
      if (target.evaluate().isNotEmpty) return;
      await t.drag(find.byType(Scrollable).first, const Offset(0, -220));
      await t.pump(const Duration(milliseconds: 120));
    }
  }

  /// Ketuk widget yang mungkin berada di luar area terlihat.
  Future<void> ketuk(WidgetTester t, Finder target) async {
    await t.ensureVisible(target);
    await t.pump(const Duration(milliseconds: 120));
    await t.tap(target);
    await t.pump();
  }

  /// Pilih chip saringan kategori — barisnya mendatar, jadi chip yang jauh
  /// (mis. "Tanpa kategori" di ujung) perlu digulir dulu.
  ///
  /// Baris saringan kategori adalah daftar mendatar kedua di layar ini
  /// (setelah baris saringan status).
  Future<void> pilihChip(WidgetTester t, Finder target,
      {bool keKanan = true, int maks = 30}) async {
    var putaran = 0;
    while (target.evaluate().isEmpty && putaran < maks) {
      await t.drag(find.byType(Scrollable).at(1),
          Offset(keKanan ? -200 : 200, 0));
      await t.pump(const Duration(milliseconds: 100));
      putaran++;
    }
    await ketuk(t, target);
    await pumpDrift(t);
  }


  group('Layar "Kategori tagihan"', () {
    testWidgets('menampilkan ikon + warna + jumlah tagihan pemakai',
        (t) async {
      final k = await repo.tambah(nama: 'Hobi Laut', ikon: 'pets', warna: '#8E24AA');
      await tagihanBaru('Kelas renang', kategoriId: k.id);

      await tampilkan(t, const KelolaKategoriTagihanScreen());

      expect(find.text('Kategori tagihan'), findsOneWidget);
      expect(find.text('10 kategori').evaluate().isNotEmpty ||
          find.text('11 kategori').evaluate().isNotEmpty, isTrue);
      await gulirKe(t, find.text('Hobi Laut'));
      expect(find.text('Hobi Laut'), findsOneWidget);
      expect(find.text('1 tagihan memakai kategori ini'), findsOneWidget);
      expect(find.byIcon(Icons.pets), findsOneWidget);
      expect(t.takeException(), isNull);
      await tutup(t);
    });

    testWidgets('tambah kategori lewat dialog: nama, ikon, warna tersimpan',
        (t) async {
      await tampilkan(t, const KelolaKategoriTagihanScreen());

      await t.tap(find.byKey(const Key('tambah_kategori_tagihan')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Tambah kategori'), findsOneWidget);

      await t.enterText(
          find.byKey(const Key('nama_kategori_tagihan')), 'Hobi Laut');
      await ketuk(t, find.byKey(const ValueKey('ikon_tagihan_water_drop')));
      await ketuk(t, find.byKey(const ValueKey('warna_tagihan_#8E24AA')));
      expect(find.byKey(const Key('pratinjau_kategori')), findsOneWidget);

      await t.tap(find.byKey(const Key('simpan_kategori_tagihan')));
      await pumpDrift(t);

      final baru = await kategoriBernama('Hobi Laut');
      expect(baru.ikon, 'water_drop');
      expect(baru.warna, '#8E24AA');
      await gulirKe(t, find.text('Hobi Laut'));
      expect(find.text('Hobi Laut'), findsOneWidget);
      expect(find.text('Belum dipakai tagihan'), findsWidgets);
      await tutup(t);
    });

    testWidgets('dialog menolak nama kosong', (t) async {
      await tampilkan(t, const KelolaKategoriTagihanScreen());
      await t.tap(find.byKey(const Key('tambah_kategori_tagihan')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));

      await t.tap(find.byKey(const Key('simpan_kategori_tagihan')));
      await t.pump(const Duration(milliseconds: 300));

      expect(find.text('Nama kategori wajib diisi'), findsOneWidget);
      expect(find.text('Tambah kategori'), findsOneWidget); // dialog tetap ada
      expect(await semuaKategori(), hasLength(10));
      await tutup(t);
    });

    testWidgets('ubah nama + ikon + warna terbaca lagi setelah layar dibuka ulang',
        (t) async {
      final k = await repo.tambah(nama: 'Hobi', ikon: 'pets', warna: '#8E24AA');
      await tampilkan(t, const KelolaKategoriTagihanScreen());

      await gulirKe(t, find.byKey(ValueKey('kategori_${k.id}')));
      await ketuk(t, find.byKey(ValueKey('kategori_${k.id}')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Ubah kategori'), findsOneWidget);

      await t.enterText(
          find.byKey(const Key('nama_kategori_tagihan')), 'Hobi Laut');
      await ketuk(t, find.byKey(const ValueKey('ikon_tagihan_music_note')));
      await ketuk(t, find.byKey(const ValueKey('warna_tagihan_#E53935')));
      await t.tap(find.byKey(const Key('simpan_kategori_tagihan')));
      await pumpDrift(t);

      final lagi = (await kategoriDenganId(k.id))!;
      expect(lagi.nama, 'Hobi Laut');
      expect(lagi.ikon, 'music_note');
      expect(lagi.warna, '#E53935');

      // Buka ulang layar: nilai baru harus terbaca kembali dari database.
      await tutup(t);
      await tampilkan(t, const KelolaKategoriTagihanScreen());
      await gulirKe(t, find.text('Hobi Laut'));
      expect(find.text('Hobi Laut'), findsOneWidget);
      expect(find.byIcon(Icons.music_note), findsOneWidget);
      expect(find.byIcon(Icons.pets), findsNothing);
      await tutup(t);
    });

    testWidgets('hapus kategori yang dipakai 2 tagihan: dialog pindah + '
        'tagihan tetap ada', (t) async {
      final k = await repo.tambah(nama: 'Sekolah Anak', ikon: 'school', warna: '#FFB74D');
      await tagihanBaru('SPP September', kategoriId: k.id);
      await tagihanBaru('Buku tahunan', kategoriId: k.id);
      await tampilkan(t, const KelolaKategoriTagihanScreen());

      await gulirKe(t, find.byKey(ValueKey('hapus_${k.id}')));
      expect(find.text('2 tagihan memakai kategori ini'), findsOneWidget,
          reason: 'jumlah pemakai terlihat di baris kategori');
      await ketuk(t, find.byKey(ValueKey('hapus_${k.id}')));
      await t.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Pindahkan ke Tanpa kategori'), findsOneWidget);
      expect(find.textContaining('Tagihannya tetap ada'), findsOneWidget);

      await t.tap(find.byKey(const Key('konfirmasi_hapus_kategori')));
      await pumpDrift(t);

      expect(await kategoriDenganId(k.id), isNull);
      final sisa = await semuaTagihan();
      expect(sisa, hasLength(2), reason: 'tagihan tidak boleh terhapus');
      expect(sisa.every((x) => x.kategoriId == null), isTrue);
      expect(await repo.jumlahPemakai(k.id), 0);
      expect(find.textContaining('dipindahkan ke Tanpa kategori'), findsWidgets);
      await tutup(t);
    });

    testWidgets('hapus kategori tanpa pemakai: langsung terhapus', (t) async {
      final k = await repo.tambah(nama: 'Cadangan', ikon: 'park', warna: '#4CAF50');
      final tgh = await tagihanBaru('Tagihan lain');
      await tampilkan(t, const KelolaKategoriTagihanScreen());

      await gulirKe(t, find.byKey(ValueKey('hapus_${k.id}')));
      await ketuk(t, find.byKey(ValueKey('hapus_${k.id}')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('belum dipakai tagihan'), findsOneWidget);

      await t.tap(find.byKey(const Key('konfirmasi_hapus_kategori')));
      await pumpDrift(t);

      expect(await kategoriDenganId(k.id), isNull);
      final sisa = await semuaTagihan();
      expect(sisa, hasLength(1));
      expect(sisa.first.id, tgh.id);
      await tutup(t);
    });

    testWidgets('tombol batal pada dialog hapus: kategori tetap ada',
        (t) async {
      final k = await repo.tambah(nama: 'Jangan Hapus', ikon: 'park', warna: '#4CAF50');
      await tampilkan(t, const KelolaKategoriTagihanScreen());

      await gulirKe(t, find.byKey(ValueKey('hapus_${k.id}')));
      await ketuk(t, find.byKey(ValueKey('hapus_${k.id}')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Batal'));
      await pumpDrift(t);

      expect(await kategoriDenganId(k.id), isNotNull);
      await tutup(t);
    });

    testWidgets('naik / turun urutan tersimpan dan terlihat di layar',
        (t) async {
      final awal = (await semuaKategori()).map((k) => k.nama).toList();
      await tampilkan(t, const KelolaKategoriTagihanScreen());
      final kedua = (await semuaKategori())[1];

      await ketuk(t, find.byKey(ValueKey('naik_${kedua.id}')));
      await pumpDrift(t);

      var urut = (await semuaKategori()).map((k) => k.nama).toList();
      expect(urut, [awal[1], awal[0], ...awal.sublist(2)]);

      // Buka ulang layar: urutan baru harus terlihat dari baris paling atas.
      await tutup(t);
      await tampilkan(t, const KelolaKategoriTagihanScreen());
      expect(
          find.descendant(
              of: find.byType(ListTile).first, matching: find.text(awal[1])),
          findsOneWidget,
          reason: 'kategori yang dinaikkan harus tampil paling atas');
      expect(
          t.widget<IconButton>(find.byKey(ValueKey('naik_${kedua.id}'))).onPressed,
          isNull,
          reason: 'baris paling atas tidak bisa dinaikkan lagi');

      await ketuk(t, find.byKey(ValueKey('turun_${kedua.id}')));
      await pumpDrift(t);
      urut = (await semuaKategori()).map((k) => k.nama).toList();
      expect(urut, awal);
      await tutup(t);
    });

    testWidgets('ikon & warna tak dikenal tetap tampil dengan nilai bawaan',
        (t) async {
      await db.into(db.kategori).insert(KategoriCompanion.insert(
            nama: 'Kategori Misteri',
            ikon: const Value('ikon_ajaib_999'),
            warna: const Value('bukan-warna'),
            urutan: const Value(99),
          ));

      await tampilkan(t, const KelolaKategoriTagihanScreen());
      await gulirKe(t, find.text('Kategori Misteri'));

      expect(find.text('Kategori Misteri'), findsOneWidget);
      expect(find.byIcon(ikonTagihanBawaan), findsWidgets);
      expect(t.takeException(), isNull, reason: 'layar tidak boleh rusak');
      await tutup(t);
    });

    testWidgets('bahasa layar bebas kata menghakimi (III-11)', (t) async {
      final k = await repo.tambah(nama: 'Hobi Laut', ikon: 'pets', warna: '#8E24AA');
      await tagihanBaru('Kelas renang', kategoriId: k.id);
      await tampilkan(t, const KelolaKategoriTagihanScreen());

      final teks = <String>{};
      void kumpulkan() => teks.addAll(t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .where((s) => s.isNotEmpty));

      kumpulkan();
      for (var i = 0; i < 4; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -240));
        await t.pump(const Duration(milliseconds: 120));
        kumpulkan();
      }

      const terlarang = [
        'skor',
        'anda gagal',
        'gagal',
        'kamu',
        'boros',
        'tidak disiplin',
        'berdosa',
      ];
      for (final s in teks) {
        for (final kata in terlarang) {
          expect(s.toLowerCase().contains(kata), isFalse,
              reason: '"$s" memuat "$kata"');
        }
      }
      await tutup(t);
    });
  });

  group('Daftar tagihan memakai ikon & warna kategori', () {
    testWidgets('baris menampilkan ikon kategori & bisa disaring per kategori',
        (t) async {
      final listrik = await repo.tambah(
          nama: 'Listrik rumah', ikon: 'bolt', warna: '#F5A623');
      final air = await repo.tambah(
          nama: 'Air rumah', ikon: 'water_drop', warna: '#4A90D9');
      final t1 = await tagihanBaru('Token listrik', kategoriId: listrik.id);
      await tagihanBaru('PDAM bulan ini', kategoriId: air.id);
      await tagihanBaru('Iuran kampung');

      // Layar aslinya duduk di dalam kerangka navigasi (ada Scaffold/Material).
      await tampilkan(t, const Scaffold(body: DaftarTagihanScreen()));
      await pumpDrift(t);

      expect(find.text('3 tagihan'), findsOneWidget);
      expect(find.byKey(ValueKey('lencana_kategori_${t1.id}')), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsWidgets);
      expect(find.byIcon(Icons.water_drop), findsWidgets);
      expect(find.text('Listrik rumah'), findsWidgets);

      // Saring: hanya tagihan kategori Listrik yang tersisa.
      await pilihChip(t, find.byKey(ValueKey('kategori_chip_${listrik.id}')));
      expect(find.text('1 tagihan'), findsOneWidget);
      expect(find.text('Token listrik'), findsOneWidget);
      expect(find.text('PDAM bulan ini'), findsNothing);
      expect(find.text('Iuran kampung'), findsNothing);
      expect(find.text('Tanpa kategori'), findsWidgets); // chip tetap ada

      // Kembali ke semua kategori.
      await pilihChip(t, find.byKey(const ValueKey('kategori_semua')),
          keKanan: false);
      expect(find.text('3 tagihan'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('saringan "Tanpa kategori" hanya menampilkan tagihan kosong',
        (t) async {
      final k = await repo.tambah(nama: 'Listrik rumah', ikon: 'bolt', warna: '#F5A623');
      await tagihanBaru('Token listrik', kategoriId: k.id);
      await tagihanBaru('Iuran kampung');

      // Layar aslinya duduk di dalam kerangka navigasi (ada Scaffold/Material).
      await tampilkan(t, const Scaffold(body: DaftarTagihanScreen()));
      await pumpDrift(t);

      await pilihChip(t, find.byKey(const ValueKey('kategori_tanpa')));
      expect(find.text('1 tagihan'), findsOneWidget);
      expect(find.text('Iuran kampung'), findsOneWidget);
      expect(find.text('Token listrik'), findsNothing);
      await tutup(t);
    });
  });

  group('Form tagihan memakai kategori berikon', () {
    testWidgets('dropdown menampilkan ikon + warna, dan pintu Kelola kategori',
        (t) async {
      final hobi = await repo.tambah(
          nama: 'Hobi Laut', ikon: 'water_drop', warna: '#8E24AA');
      await buka(t, awal: '/tambah');

      expect(find.byKey(const Key('dropdown_kategori')), findsOneWidget);
      expect(find.text('Tanpa kategori'), findsOneWidget);

      // Buka menu dropdown: item kategori baru harus muncul lengkap ikonnya.
      await ketuk(t, find.byKey(const Key('dropdown_kategori')));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text(hobi.nama), findsOneWidget);
      expect(find.byIcon(Icons.water_drop), findsWidgets);

      await t.tap(find.text(hobi.nama).last);
      await pumpDrift(t); // tunggu menu benar-benar tertutup
      expect(find.text(hobi.nama), findsOneWidget);

      // Pintu ke layar kategori.
      await ketuk(t, find.byKey(const Key('buka_kelola_kategori')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Kategori tagihan'), findsOneWidget);
      expect(find.byKey(const Key('tambah_kategori_tagihan')), findsOneWidget);
      await tutup(t);
    });

    testWidgets('kategori baru bisa dipilih lalu tersimpan di tagihan',
        (t) async {
      final hobi = await repo.tambah(
          nama: 'Hobi Laut', ikon: 'pets', warna: '#8E24AA');
      await buka(t, awal: '/tagihan');

      await t.tap(find.byKey(const Key('tambah_tagihan_uji')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Tambah Tagihan'), findsOneWidget);

      final kolom = find.byType(TextFormField);
      await t.enterText(kolom.at(0), 'Kelas renang');
      await t.enterText(kolom.at(1), '150rb');
      await t.pump();

      await ketuk(t, find.byKey(const Key('dropdown_kategori')));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text(hobi.nama).last);
      await pumpDrift(t); // tunggu menu kategori tertutup sebelum menyimpan

      await ketuk(t, find.text('Simpan tagihan'));
      await pumpDrift(t);

      final baris = (await semuaTagihan()).single;
      expect(baris.nama, 'Kelas renang');
      expect(baris.kategoriId, hobi.id,
          reason: 'kategori pilihan pengguna harus tersimpan');
      expect(find.text('Tambah Tagihan'), findsNothing);
      expect(find.byKey(ValueKey('lencana_kategori_${baris.id}')), findsOneWidget);
      expect(find.byIcon(Icons.pets), findsWidgets);
      await tutup(t);
    });
  });

}
