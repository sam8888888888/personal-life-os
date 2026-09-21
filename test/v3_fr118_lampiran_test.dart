/// FR-118 (lanjutan, 22 Sep 2026) — lampiran foto & rekaman suara pada catatan.
///
/// Yang dibuktikan:
/// 1. Simpan lampiran MENYALIN berkas ke folder aplikasi (berkas asal tidak
///    dipakai langsung) dan menulis barisnya lengkap dengan uid.
/// 2. Daftar & hapus: baris hilang sekaligus berkasnya dibersihkan.
/// 3. Berkas yang sudah tidak ada tidak membuat penghapusan gagal.
/// 4. `pastikanUidCatatan` mengisi uid sekali dan tetap sama sesudahnya.
/// 5. Kartu lampiran: tombol "Foto" memakai kanal Android (kanal tiruan di uji)
///    lalu lampirannya tampil di daftar.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/platform/kanal_media.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/lampiran_repository.dart';
import 'package:personal_life_os/data/repository/pengetahuan_repository.dart';
import 'package:personal_life_os/features/pengetahuan/kartu_lampiran.dart';
import 'package:personal_life_os/features/pengetahuan/provider_pengetahuan.dart';

/// PNG 1x1 sah — supaya widget Image.file benar-benar bisa menggambar.
final Uint8List _pngKecil = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
);

void main() {
  late AppDatabase db;
  late Directory folder;
  late LampiranRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    folder = await Directory.systemTemp.createTemp('lampiran_uji');
    repo = LampiranRepository(db, folderInduk: () async => folder);
  });

  tearDown(() async {
    await db.close();
    if (await folder.exists()) await folder.delete(recursive: true);
  });

  test('FR-118 simpan lampiran menyalin berkas & menulis barisnya', () async {
    final sumber = File('${folder.path}/asal.png')
      ..writeAsBytesSync(_pngKecil);

    final baris = await repo.simpan(
      indukTabel: 'catatan_pengetahuan',
      indukUid: 'uid-catatan-1',
      jenis: 'foto',
      jalurSumber: sumber.path,
    );

    expect(baris.jenis, 'foto');
    expect(baris.ukuranByte, _pngKecil.length);
    expect(baris.uid, isNotNull);
    expect(baris.berkas, isNot(sumber.path), reason: 'berkas disalin');
    expect(await File(baris.berkas).exists(), isTrue);
    expect(await repo.berkasAda(baris), isTrue);
  });

  test('FR-118 daftar & hapus membersihkan berkas dan baris', () async {
    final sumber = File('${folder.path}/suara.m4a')
      ..writeAsBytesSync(List<int>.filled(128, 3));
    final baris = await repo.simpan(
      indukTabel: 'catatan_pengetahuan',
      indukUid: 'U9',
      jenis: 'suara',
      jalurSumber: sumber.path,
    );
    expect(await repo.daftar('catatan_pengetahuan', 'U9'), hasLength(1));
    expect(await repo.jumlah('catatan_pengetahuan', 'U9'), 1);
    expect(await repo.totalUkuranByte('catatan_pengetahuan', 'U9'), 128);

    await repo.hapus(baris.id);
    expect(await repo.daftar('catatan_pengetahuan', 'U9'), isEmpty);
    expect(await File(baris.berkas).exists(), isFalse);
  });

  test('FR-118 berkas hilang: penghapusan tetap bersih tanpa galat', () async {
    final sumber = File('${folder.path}/foto.png')..writeAsBytesSync(_pngKecil);
    final baris = await repo.simpan(
      indukTabel: 'catatan_pengetahuan',
      indukUid: 'U10',
      jenis: 'foto',
      jalurSumber: sumber.path,
    );
    await File(baris.berkas).delete();

    await repo.hapus(baris.id);
    expect(await repo.daftar('catatan_pengetahuan', 'U10'), isEmpty);
  });

  test('FR-118 berkas sumber tidak ada → pesan jujur, bukan baris kosong', () async {
    await expectLater(
      () => repo.simpan(
        indukTabel: 'catatan_pengetahuan',
        indukUid: 'U11',
        jenis: 'foto',
        jalurSumber: '${folder.path}/tidak-ada.png',
      ),
      throwsA(isA<LampiranGagal>()),
    );
    expect(await repo.daftar('catatan_pengetahuan', 'U11'), isEmpty);
  });

  test('FR-118 pastikanUidCatatan mengisi uid sekali lalu tetap', () async {
    final pengetahuan = PengetahuanRepository(db);
    final id = await pengetahuan.simpanCatatan(judul: 'Ide', isi: 'isi ide');

    final uid1 = await pengetahuan.pastikanUidCatatan(id);
    final uid2 = await pengetahuan.pastikanUidCatatan(id);
    expect(uid1, isNotEmpty);
    expect(uid2, uid1);
  });

  testWidgets('FR-118 kartu lampiran: tombol Foto memakai kanal & lampiran tampil',
      (t) async {
    final kanal = KanalMedia(kanal: const MethodChannel('lifeos/media'));
    final sumberFoto = File('${folder.path}/kanal.png')..writeAsBytesSync(_pngKecil);
    var dipanggil = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('lifeos/media'), (call) async {
      if (call.method == 'ambilFoto') {
        dipanggil++;
        return sumberFoto.path;
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('lifeos/media'), null));

    await t.pumpWidget(ProviderScope(
      overrides: [lampiranRepoProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Scaffold(
          body: KartuLampiran(
            indukTabel: 'catatan_pengetahuan',
            indukUid: 'U12',
            kanal: kanal,
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('Belum ada lampiran.'), findsOneWidget);

    // Pekerjaan menyalin berkas butuh waktu NYATA (bukan waktu palsu uji widget).
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('lampiran_ambil_foto')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pumpAndSettle();

    expect(dipanggil, 1, reason: 'kanal Android dipanggil sekali');
    final tersimpan = await repo.daftar('catatan_pengetahuan', 'U12');
    expect(tersimpan, hasLength(1));
    expect(tersimpan.single.jenis, 'foto');
    expect(find.byKey(Key('lampiran_${tersimpan.single.id}')), findsOneWidget);
    expect(find.textContaining('Foto · '), findsOneWidget);
  });

  testWidgets('FR-118 rekam suara: mulai lalu stop menyimpan rekaman',
      (t) async {
    final kanal = KanalMedia(kanal: const MethodChannel('lifeos/media'));
    final hasilRekam = File('${folder.path}/rekaman.m4a')
      ..writeAsBytesSync(List<int>.filled(64, 9));
    var mulai = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('lifeos/media'), (call) async {
      if (call.method == 'mulaiRekam') {
        mulai++;
        return 'mulai';
      }
      if (call.method == 'hentikanRekam') return hasilRekam.path;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('lifeos/media'), null));

    await t.pumpWidget(ProviderScope(
      overrides: [lampiranRepoProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Scaffold(
          body: KartuLampiran(
            indukTabel: 'catatan_pengetahuan',
            indukUid: 'U13',
            kanal: kanal,
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('lampiran_rekam')));
    await t.pumpAndSettle();
    expect(find.text('Stop rekam'), findsOneWidget);

    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('lampiran_rekam')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pumpAndSettle();

    expect(mulai, 1);
    final tersimpan = await repo.daftar('catatan_pengetahuan', 'U13');
    expect(tersimpan, hasLength(1));
    expect(tersimpan.single.jenis, 'suara');
    expect(find.textContaining('Rekaman suara · '), findsOneWidget);
  });
}
