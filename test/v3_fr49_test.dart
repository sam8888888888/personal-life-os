/// Uji FR-49 — pengingat multi-kanal (WhatsApp / SMS / Telegram).
///
/// Yang dibuktikan:
///   * nomor HP Indonesia dinormalkan ke format internasional untuk wa.me,
///   * pesan siap kirim memuat nama, nominal (sesuai mata uang tagihan), dan
///     tanggal jatuh tempo,
///   * tautan WhatsApp/SMS/Telegram berbentuk benar & teksnya ter-encode,
///   * kanal per tagihan tersimpan di database (bisa lebih dari satu),
///   * layar: menekan "Kirim ke WhatsApp" memanggil kanal Android dengan tautan
///     wa.me yang benar; bila perangkat tidak punya aplikasinya, pengguna diberi
///     tahu apa adanya (bukan klaim terkirim).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/platform/buka_tautan.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/model/enums.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';
import 'package:personal_life_os/features/tagihan/pengingat_kanal.dart';
import 'package:personal_life_os/features/tagihan/pengingat_kanal_screen.dart';

late AppDatabase db;
late TagihanRepository repo;

Future<TagihanData> buatTagihan({
  String nama = 'Listrik Rumah',
  DateTime? jatuhTempo,
  int? jumlahSen = 25000000,
  String kodeMataUang = 'IDR',
}) async {
  final t = await repo.tambah(TagihanCompanion.insert(
    nama: nama,
    jatuhTempo: jatuhTempo ?? DateTime(2026, 9, 24),
    jumlahSen: Value(jumlahSen),
    kodeMataUang: Value(kodeMataUang),
    catatan: const Value('bayar sebelum jam 5 sore'),
  ));
  return (await (db.select(db.tagihan)..where((x) => x.id.equals(t.id)))
      .getSingle());
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TagihanRepository(db);
  });

  tearDown(() async => db.close());

  group('tautan & teks', () {
    test('nomor Indonesia dinormalkan ke format wa.me', () {
      expect(nomorKeInternasional('0812-3456-7890'), '6281234567890');
      expect(nomorKeInternasional('08123456789'), '628123456789');
      expect(nomorKeInternasional('+62 812 3456 7890'), '6281234567890');
      expect(nomorKeInternasional('6281234567890'), '6281234567890');
      expect(nomorKeInternasional(''), '');
      expect(nomorKeInternasional(null), '');
      expect(nomorKeInternasional('bukan nomor'), '');
    });

    test('pesan memuat nama, nominal & tanggal jatuh tempo', () async {
      final t = await buatTagihan();
      final pesan = pesanPengingat(t);
      expect(pesan, contains('Listrik Rumah'));
      expect(pesan, contains('Rp 250.000'));
      // fmtTanggalId memakai nama bulan penuh (mis. "24 September 2026").
      expect(pesan, contains('24 September 2026'));
      expect(pesan, contains('bayar sebelum jam 5 sore'));
    });

    test('nominal ditulis sesuai mata uang tagihan (bukan selalu Rupiah)',
        () async {
      final t = await buatTagihan(
          nama: 'Netflix', jumlahSen: 4599, kodeMataUang: 'MYR');
      expect(pesanPengingat(t), contains('RM 45.99'));
      expect(pesanPengingat(t), isNot(contains('Rp')));
    });

    test('tautan WhatsApp/SMS/Telegram berbentuk benar', () async {
      final t = await buatTagihan();
      final pesan = pesanPengingat(t);

      final wa = tautanWhatsapp(pesan, nomor: '081234567890');
      expect(wa, startsWith('https://wa.me/6281234567890?text='));
      expect(wa, contains(Uri.encodeComponent('Listrik Rumah')));

      final waSendiri = tautanWhatsapp(pesan);
      expect(waSendiri, startsWith('https://wa.me/?text='));

      final sms = tautanSms(pesan, nomor: '081234567890');
      expect(sms, startsWith('sms:6281234567890?body='));

      final tg = tautanTelegram(pesan);
      expect(tg, startsWith('https://t.me/share/url?'));
      expect(tg, contains('text='));

      // Setiap kanal bisa dipanggil seragam lewat enum.
      for (final k in KanalTerusan.values) {
        expect(k.tautan(pesan, nomor: '0812').isNotEmpty, isTrue);
      }
    });

    test('kanal per tagihan: teks kolom ↔ daftar kanal', () {
      expect(kanalTagihan(null), [KanalPengingat.push]);
      expect(kanalTagihan('').map((e) => e.nilaiDb), ['push']);
      expect(kanalTagihan('wa,sms').map((e) => e.nilaiDb), ['wa', 'sms']);
      expect(kanalTagihan('aneh').map((e) => e.nilaiDb), ['push']);
      expect(teksKanal([KanalPengingat.whatsapp, KanalPengingat.push]), 'wa,push');
      expect(teksKanal(const []), 'push');
    });
  });

  group('layar', () {
    testWidgets('pilih kanal, isi nomor, teruskan ke WhatsApp', (t) async {
      final panggilan = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(kanalBukaTautan),
              (c) async {
        panggilan.add(c);
        return true;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(kanalBukaTautan), null));

      final tagihan = await buatTagihan();

      await t.binding.setSurfaceSize(const Size(420, 1000));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: Scaffold(
            body: PengingatKanalScreen(
              db: db,
              sekarang: DateTime(2026, 9, 20, 9),
            ),
          ),
        ),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      // Kanal WhatsApp dinyalakan untuk tagihan ini.
      await t.tap(find.byKey(Key('kanal_chip_${tagihan.id}_wa')));
      await t.pump(const Duration(milliseconds: 200));
      await t.pump(const Duration(milliseconds: 400));

      final sesudah = await (db.select(db.tagihan)
            ..where((x) => x.id.equals(tagihan.id)))
          .getSingle();
      expect(sesudah.kanalPengingat, contains('wa'));

      // Nomor tujuan diisi lalu teruskan.
      await t.enterText(
          find.byKey(Key('nomor_tujuan_${tagihan.id}')), '081234567890');
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.byKey(Key('teruskan_whatsapp_${tagihan.id}')));
      await t.pump(const Duration(milliseconds: 300));

      expect(panggilan, hasLength(1));
      expect(panggilan.first.method, 'bukaTautan');
      final tautan = (panggilan.first.arguments as Map)['tautan'] as String;
      expect(tautan, startsWith('https://wa.me/6281234567890?text='));
      expect(tautan, contains(Uri.encodeComponent('Listrik Rumah')));

      // Nomor tersimpan untuk tagihan ini.
      final nomor =
          await KontakPengingat(PengaturanRepository(db)).nomor(tagihan.id);
      expect(nomor, '081234567890');

      await t.pump(const Duration(seconds: 6));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('perangkat tanpa WhatsApp → pesan jujur, bukan klaim terkirim',
        (t) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(kanalBukaTautan),
              (c) async => false);
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(kanalBukaTautan), null));

      final tagihan = await buatTagihan(nama: 'Air PDAM');

      await t.binding.setSurfaceSize(const Size(420, 1000));
      await t.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTema.terang(),
          home: Scaffold(body: PengingatKanalScreen(db: db)),
        ),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      await t.tap(find.byKey(Key('teruskan_whatsapp_${tagihan.id}')));
      await t.pump(const Duration(milliseconds: 300));

      expect(find.byKey(Key('galat_buka_${tagihan.id}')), findsOneWidget);
      final snack =
          t.widget<SnackBar>(find.byKey(const Key('hasil_teruskan')));
      expect((snack.content as Text).data, contains('tidak terbuka'));

      await t.pump(const Duration(seconds: 6));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      await t.binding.setSurfaceSize(null);
    });
  });
}
