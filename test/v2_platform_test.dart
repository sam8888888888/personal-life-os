/// Uji V2 Platform — FR-138 (Audit Log), FR-147 (Pusat Notifikasi), dan
/// FR-148 (Tunda / jadwalkan ulang pengingat).
///
/// Semua klaim di laporan pekerjaan bisa diulang dari berkas ini:
/// * lapisan data diuji langsung ke database dalam memori;
/// * layar diuji pada ukuran ponsel 420x900 dengan provider disuntik;
/// * uji FR-148 membuktikan **tanggal jatuh tempo asli tidak berubah**.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_life_os/core/audit/audit_log.dart';
import 'package:personal_life_os/core/notifikasi/jejak.dart';
import 'package:personal_life_os/core/notifikasi/layanan_notifikasi.dart';
import 'package:personal_life_os/core/notifikasi/model_pengingat.dart';
import 'package:personal_life_os/core/notifikasi/tunda_pengingat.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/theme/app_tema.dart';
import 'package:personal_life_os/core/utils/waktu.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/audit_repository.dart';
import 'package:personal_life_os/data/repository/notifikasi_riwayat_repository.dart';
import 'package:personal_life_os/features/pengingat/pengingat_screen.dart';
import 'package:personal_life_os/features/platform/audit_log_screen.dart';
import 'package:personal_life_os/features/platform/pusat_notifikasi_screen.dart';

/// Waktu uji dikunci: 15 September 2026, 08:00.
final jamUji = DateTime(2026, 9, 15, 8, 0);

late AppDatabase db;
late AuditRepository auditRepo;
late NotifikasiRiwayatRepository riwayatRepo;
late TundaPengingatRepository tundaRepo;
late Directory folderUji;

/// Layanan notifikasi palsu — cukup untuk membangun layar Pengingat tanpa
/// perangkat Android (tidak ada plugin yang benar-benar dipanggil).
class LayananUji implements LayananNotifikasi {
  @override
  HasilPasang? get hasilPasangTerakhir => null;

  @override
  bool get siap => true;

  @override
  Future<void> siapkan() async {}

  @override
  Future<StatusIzinPengingat> statusIzin() async =>
      const StatusIzinPengingat(
          notifikasiDiizinkan: true, alarmTepatDiizinkan: true);

  @override
  Future<bool> mintaIzinNotifikasi() async => true;

  @override
  Future<bool> mintaIzinAlarmTepat() async => true;

  @override
  Future<void> pasangJadwal(List<Pengingat> daftar) async {}

  @override
  Future<void> batalkanSemua() async {}

  @override
  Future<void> jadwalkanSatu(Pengingat p) async {}

  @override
  Future<void> tampilkanUji({Duration tunda = const Duration(seconds: 10)}) async {}

  @override
  Future<List<({int id, String? judul, DateTime? waktu})>> tertunda() async =>
      const [];
}

/// Teks yang benar-benar tampil di layar (bahan uji bahasa III-11).
List<String> teksTampil(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data ?? '')
    .where((s) => s.trim().isNotEmpty)
    .toList();

Future<int> barisAudit({
  required String modul,
  required DateTime waktu,
  required String ringkas,
  String aksi = 'ubah',
  String? sebelum,
  String? sesudah,
  String sumber = 'layar',
}) =>
    db.into(db.auditLog).insert(AuditLogCompanion.insert(
          waktu: waktu,
          modul: modul,
          aksi: aksi,
          ringkas: ringkas,
          nilaiSebelum: Value(sebelum),
          nilaiSesudah: Value(sesudah),
          sumber: Value(sumber),
        ));

Future<int> barisNotifikasi({
  required DateTime waktu,
  required String judul,
  required String isi,
  int? pengingatId,
  String tingkat = 'biasa',
  String status = 'baru',
  String sumber = 'tagihan',
}) =>
    db.into(db.notifikasiRiwayat).insert(NotifikasiRiwayatCompanion.insert(
          waktu: waktu,
          judul: judul,
          isi: isi,
          pengingatId: Value(pengingatId),
          tingkat: Value(tingkat),
          status: Value(status),
          sumber: Value(sumber),
        ));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    // Jejak berbasis berkas dimatikan: plugin path_provider tidak ada saat uji.
    penentuJejak = () async => null;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    folderUji = await Directory.systemTemp.createTemp('uji_audit_');
    pakaiSumberWaktu(() => jamUji);
    auditRepo = AuditRepository(db,
        penentuFolder: () async => folderUji, jam: () => jamUji);
    riwayatRepo = NotifikasiRiwayatRepository(db, jam: () => jamUji);
    tundaRepo = TundaPengingatRepository(db, jam: () => jamUji);
  });

  tearDown(() async {
    pakaiWaktuAsli();
    await db.close();
    if (folderUji.existsSync()) folderUji.deleteSync(recursive: true);
  });

  // =========================================================================
  // FR-138 — Audit log
  // =========================================================================

  group('FR-138 — catatAudit & ringkasan kalimat', () {
    test('catatAudit menulis satu baris lengkap dengan waktu sumber aplikasi',
        () async {
      final id = await catatAudit(
        db,
        modul: ModulAudit.tagihan,
        aksi: AksiAudit.tandai,
        entitas: 'tagihan',
        entitasId: '18',
        sebelum: 'Rp 300.000',
        sesudah: 'Rp 325.000',
        ringkas: 'Tagihan #18 ditandai lunas',
        sumber: SumberAudit.pengingat,
      );

      final baris = await db.select(db.auditLog).get();
      expect(baris.length, 1, reason: 'satu panggilan = satu baris');
      final b = baris.single;
      expect(b.id, id);
      expect(b.waktu, jamUji, reason: 'waktu dari waktuSekarang(), bukan now()');
      expect(b.modul, 'tagihan');
      expect(b.aksi, 'tandai');
      expect(b.entitas, 'tagihan');
      expect(b.entitasId, '18');
      expect(b.nilaiSebelum, 'Rp 300.000');
      expect(b.nilaiSesudah, 'Rp 325.000');
      expect(b.ringkas, 'Tagihan #18 ditandai lunas');
      expect(b.sumber, 'pengingat');
      // Bawaan sumber = 'layar'.
      await catatAudit(db, modul: 'lain', aksi: 'buat', ringkas: 'Catatan uji');
      final semua = await db.select(db.auditLog).get();
      expect(semua.length, 2);
      expect(semua.last.sumber, 'layar');
    });

    test('ringkasPerubahan menyusun kalimat apa adanya (murni)', () {
      expect(ringkasPerubahan(label: 'Nominal', sebelum: '300.000', sesudah: '325.000'),
          'Nominal diubah 300.000 \u2192 325.000');
      expect(ringkasPerubahan(label: 'Nominal', sesudah: '300.000'),
          'Nominal ditetapkan: 300.000');
      expect(ringkasPerubahan(label: 'Nominal', sebelum: '300.000'),
          'Nominal dikosongkan (sebelumnya 300.000)');
      expect(ringkasPerubahan(label: 'Nominal', sebelum: '300.000', sesudah: '300.000'),
          'Nominal tidak berubah: 300.000');
      for (final teks in [
        ringkasPerubahan(label: 'Nominal', sebelum: '1', sesudah: '2'),
        ringkasPerubahan(label: 'Nominal', sesudah: '2'),
      ]) {
        expect(teks.toLowerCase().contains('gagal'), isFalse);
        expect(teks.toLowerCase().contains('kamu'), isFalse);
      }
    });

    test('daftar: terbaru lebih dulu, saringan modul, dan hitungan jujur',
        () async {
      final lama = await barisAudit(
          modul: 'tagihan', waktu: DateTime(2026, 9, 13, 9), ringkas: 'Catatan A');
      final tengah = await barisAudit(
          modul: 'transaksi', waktu: DateTime(2026, 9, 14, 9), ringkas: 'Catatan B');
      final baru = await barisAudit(
          modul: 'tagihan', waktu: DateTime(2026, 9, 15, 7), ringkas: 'Catatan C');

      final semua = await auditRepo.daftar();
      expect(semua.map((b) => b.id).toList(), [baru, tengah, lama]);
      expect(await auditRepo.jumlah(), 3);
      expect(await auditRepo.jumlah(modul: 'tagihan'), 2, reason: 'bukti angka');

      final saring = await auditRepo.daftar(modul: 'tagihan');
      expect(saring.length, 2);
      expect(saring.every((b) => b.modul == 'tagihan'), isTrue);
      expect(await auditRepo.daftarModul(), ['tagihan', 'transaksi']);
    });

    test('ekspor JSON & teks menulis berkas berisi seluruh baris', () async {
      await barisAudit(
          modul: 'tagihan', waktu: DateTime(2026, 9, 15, 7), ringkas: 'Catatan A');
      await barisAudit(
          modul: 'transaksi', waktu: DateTime(2026, 9, 15, 6), ringkas: 'Catatan B');

      final json = await auditRepo.eksporJson();
      expect(json.jumlahBaris, 2);
      expect(json.totalBaris, 2);
      expect(json.terpotong, isFalse);
      final berkasJson = File(json.path);
      expect(berkasJson.existsSync(), isTrue, reason: 'berkas benar-benar dibuat');
      final isi = jsonDecode(berkasJson.readAsStringSync()) as Map<String, dynamic>;
      expect(isi['format'], 'plo-audit');
      expect(isi['jumlahBaris'], 2);
      final baris = isi['baris'] as List<dynamic>;
      expect(baris.length, 2);
      expect((baris.first as Map)['ringkas'], 'Catatan A');
      expect((baris.first as Map)['waktu'], DateTime(2026, 9, 15, 7).toIso8601String());

      final teks = await auditRepo.eksporTeks(modul: 'tagihan');
      expect(teks.format, 'txt');
      expect(teks.jumlahBaris, 1);
      final isiTeks = File(teks.path).readAsStringSync();
      expect(isiTeks, contains('Catatan A'));
      expect(isiTeks, isNot(contains('Catatan B')));
      expect(isiTeks,
          contains('tersimpan di perangkat Anda saja, tidak dikirim ke mana pun'));
    });

    test('bersihkan hanya menghapus catatan lebih tua dari 365 hari', () async {
      await barisAudit(
          modul: 'tagihan',
          waktu: jamUji.subtract(const Duration(days: 400)),
          ringkas: 'Catatan sangat lama');
      await barisAudit(
          modul: 'tagihan',
          waktu: jamUji.subtract(const Duration(days: 364)),
          ringkas: 'Catatan setahun');
      await barisAudit(modul: 'tagihan', waktu: jamUji, ringkas: 'Catatan hari ini');

      final dihapus = await auditRepo.bersihkan(pada: jamUji);
      expect(dihapus, 1, reason: 'hanya baris > 365 hari');
      final sisa = await auditRepo.daftar();
      expect(sisa.length, 2);
      expect(sisa.map((b) => b.ringkas), containsAll(['Catatan setahun', 'Catatan hari ini']));
      expect(sisa.map((b) => b.ringkas), isNot(contains('Catatan sangat lama')));
    });
  });

  // =========================================================================
  // FR-147 — Pusat notifikasi
  // =========================================================================

  group('FR-147 — riwayat notifikasi', () {
    test('catat, hitung belum dibaca, tandai dibaca, tandai dibaca semua',
        () async {
      final a = await riwayatRepo.catat(
        pengingatId: 11,
        tingkat: 'mendesak',
        judul: 'Tagihan listrik H-1',
        isi: 'Jatuh tempo besok menurut catatan aplikasi.',
        waktu: DateTime(2026, 9, 15, 7),
      );
      await riwayatRepo.catat(
        tingkat: 'biasa',
        judul: 'Ringkasan pekan ini',
        isi: 'Tiga tagihan menunggu pekan ini.',
        waktu: DateTime(2026, 9, 15, 6),
      );

      expect(a.status, 'baru');
      expect(a.waktu, DateTime(2026, 9, 15, 7));
      expect(await riwayatRepo.jumlahBelumDibaca(), 2);
      expect((await riwayatRepo.daftar()).first.id, a.id, reason: 'terbaru lebih dulu');

      expect(await riwayatRepo.tandaiDibaca(a.id), 1);
      expect(await riwayatRepo.jumlahBelumDibaca(), 1);
      expect(await riwayatRepo.tandaiDibacaSemua(), 1);
      expect(await riwayatRepo.jumlahBelumDibaca(), 0, reason: 'angka, bukan klaim');
      expect(await riwayatRepo.hitung(), 2);
    });

    test('tandai selesai mengisi waktunya dan menyaring dengan benar', () async {
      final a = await barisNotifikasi(
          waktu: DateTime(2026, 9, 15, 7), judul: 'Uji', isi: 'Isi uji');
      final b = await barisNotifikasi(
          waktu: DateTime(2026, 9, 15, 6), judul: 'Uji 2', isi: 'Isi uji 2');

      expect(await riwayatRepo.tandaiSelesai(a, pada: jamUji), 1);
      final sesudah = await (db.select(db.notifikasiRiwayat)
            ..where((t) => t.id.equals(a)))
          .getSingle();
      expect(sesudah.status, 'selesai');
      expect(sesudah.selesaiPada, jamUji);
      expect(await riwayatRepo.hitung(status: 'selesai'), 1);
      expect(await riwayatRepo.hitung(status: 'baru'), 1);
      expect((await riwayatRepo.daftar(hanyaBelumDibaca: true)).single.id, b);
      expect((await riwayatRepo.daftar(tingkat: 'biasa')).length, 2);
      expect(await riwayatRepo.tandaiDitunda(b), 1);
      expect(
          (await (db.select(db.notifikasiRiwayat)..where((t) => t.id.equals(b)))
                  .getSingle())
              .status,
          'ditunda');
    });

    test('hitung per tingkat memakai angka sebenarnya', () async {
      await barisNotifikasi(
          waktu: jamUji, judul: 'M 1', isi: 'x', tingkat: 'mendesak', status: 'dibaca');
      await barisNotifikasi(waktu: jamUji, judul: 'M 2', isi: 'x', tingkat: 'mendesak');
      await barisNotifikasi(waktu: jamUji, judul: 'P 1', isi: 'x', tingkat: 'penting');
      await barisNotifikasi(waktu: jamUji, judul: 'B 1', isi: 'x', tingkat: 'biasa');

      final per = await riwayatRepo.hitungPerTingkat();
      expect(per[TingkatNotifikasi.mendesak], 2);
      expect(per[TingkatNotifikasi.penting], 1);
      expect(per[TingkatNotifikasi.biasa], 1);
      expect(per.values.fold<int>(0, (a, b) => a + b), 4);
    });

    test('kelompokkanNotifikasi memisahkan hari ini, kemarin, dan lebih lama',
        () {
      final baris = [
        NotifikasiRiwayatData(
            id: 1,
            waktu: DateTime(2026, 9, 15, 7),
            judul: 'a',
            isi: 'a',
            tingkat: 'biasa',
            kanal: 'push',
            status: 'baru',
            sumber: 'tagihan'),
        NotifikasiRiwayatData(
            id: 2,
            waktu: DateTime(2026, 9, 15, 9),
            judul: 'b',
            isi: 'b',
            tingkat: 'biasa',
            kanal: 'push',
            status: 'baru',
            sumber: 'tagihan'),
        NotifikasiRiwayatData(
            id: 3,
            waktu: DateTime(2026, 9, 14, 20),
            judul: 'c',
            isi: 'c',
            tingkat: 'biasa',
            kanal: 'push',
            status: 'baru',
            sumber: 'tagihan'),
        NotifikasiRiwayatData(
            id: 4,
            waktu: DateTime(2026, 9, 11, 8),
            judul: 'd',
            isi: 'd',
            tingkat: 'biasa',
            kanal: 'push',
            status: 'baru',
            sumber: 'tagihan'),
      ];
      final k = kelompokkanNotifikasi(baris, jamUji);
      expect(k.hariIni.length, 2, reason: 'termasuk yang sedikit di depan');
      expect(k.kemarin.length, 1);
      expect(k.lebihLama.length, 1);
      expect(k.total, 4);
      expect(k.kosong, isFalse);
      expect(kelompokkanNotifikasi(const [], jamUji).kosong, isTrue);
    });
  });

  // =========================================================================
  // FR-148 — Tunda pengingat
  // =========================================================================

  group('FR-148 — tunda pengingat', () {
    test('hitungWaktuTunda: 15 menit, 1 jam, 3 jam, dan besok 09:00', () {
      expect(hitungWaktuTunda(PilihanTunda.limaBelasMenit, jamUji),
          DateTime(2026, 9, 15, 8, 15));
      expect(hitungWaktuTunda(PilihanTunda.satuJam, jamUji),
          DateTime(2026, 9, 15, 9, 0));
      expect(hitungWaktuTunda(PilihanTunda.tigaJam, jamUji),
          DateTime(2026, 9, 15, 11, 0));
      expect(hitungWaktuTunda(PilihanTunda.besokSembilan, jamUji),
          DateTime(2026, 9, 16, 9, 0));
      // Ditunda menjelang tengah malam tetap jatuh pada hari berikutnya.
      expect(hitungWaktuTunda(PilihanTunda.besokSembilan, DateTime(2026, 9, 15, 23, 30)),
          DateTime(2026, 9, 16, 9, 0));
      expect(PilihanTunda.values.length, 4);
    });

    test('terapkanTunda menggeser waktu pengingat, jatuh tempo asli tetap', () {
      final jatuhTempo = DateTime(2026, 9, 20);
      final hasil = terapkanTunda(
        pengingatId: 77,
        jatuhTempoAsli: jatuhTempo,
        pilihan: PilihanTunda.satuJam,
        jumlahTundaSebelumnya: 0,
        sekarang: jamUji,
        waktuPengingatSekarang: DateTime(2026, 9, 18, 8),
      );

      expect(hasil.waktuPengingatBaru, DateTime(2026, 9, 15, 9, 0));
      expect(hasil.waktuPengingatSebelumnya, DateTime(2026, 9, 18, 8));
      expect(hasil.pengingatBergeser, isTrue);
      expect(hasil.jatuhTempoAsli, jatuhTempo,
          reason: 'FR-148: tanggal jatuh tempo asli tidak berubah');
      expect(hasil.jumlahTunda, 1);
      expect(hasil.masihBisaDitunda, isTrue);
      expect(hasil.tingkat, 'biasa');
      expect(ringkasTunda(hasil), contains('9:00'));
      expect(catatanJatuhTempoTidakBerubah(hasil), contains('20 September 2026'));
    });

    test('batas 3 kali: masih boleh sampai 3, sesudahnya tampil mendesak', () {
      expect(bolehDitundaLagi(0), isTrue);
      expect(bolehDitundaLagi(2), isTrue);
      expect(bolehDitundaLagi(3), isFalse);
      expect(tingkatSetelahTunda(1), 'biasa');
      expect(tingkatSetelahTunda(2), 'biasa');
      expect(tingkatSetelahTunda(3), 'mendesak');

      final hasil = terapkanTunda(
        pengingatId: 77,
        jatuhTempoAsli: DateTime(2026, 9, 20),
        pilihan: PilihanTunda.tigaJam,
        jumlahTundaSebelumnya: 2,
        sekarang: jamUji,
      );
      expect(hasil.jumlahTunda, 3);
      expect(hasil.masihBisaDitunda, isFalse);
      expect(hasil.tingkat, 'mendesak');

      expect(
        () => terapkanTunda(
          pengingatId: 77,
          jatuhTempoAsli: DateTime(2026, 9, 20),
          pilihan: PilihanTunda.satuJam,
          jumlahTundaSebelumnya: 3,
          sekarang: jamUji,
        ),
        throwsA(isA<BatasTundaTerlampaui>()),
      );
    });

    test('repository: satu baris per pengingat & jatuh tempo tagihan tidak berubah',
        () async {
      final tagihanId = await db.into(db.tagihan).insert(TagihanCompanion.insert(
            nama: 'Listrik PLN',
            jumlahSen: const Value(30000000),
            jatuhTempo: DateTime(2026, 9, 20),
          ));
      const pengingatId = 9001;
      final jatuhTempoAsli = DateTime(2026, 9, 20);

      final h1 = await tundaRepo.terapkan(
          pengingatId: pengingatId,
          jatuhTempoAsli: jatuhTempoAsli,
          pilihan: PilihanTunda.limaBelasMenit);
      final h2 = await tundaRepo.terapkan(
          pengingatId: pengingatId,
          jatuhTempoAsli: jatuhTempoAsli,
          pilihan: PilihanTunda.satuJam,
          alasan: 'masih di jalan');
      final h3 = await tundaRepo.terapkan(
          pengingatId: pengingatId,
          jatuhTempoAsli: jatuhTempoAsli,
          pilihan: PilihanTunda.tigaJam);

      expect(h1.jumlahTunda, 1);
      expect(h2.jumlahTunda, 2);
      expect(h3.jumlahTunda, 3);
      expect(h3.tingkat, 'mendesak');

      final baris = await tundaRepo.daftar();
      expect(baris.length, 1, reason: 'satu baris per pengingat (unik)');
      expect(baris.single.pengingatId, pengingatId);
      expect(baris.single.jumlahTunda, 3);
      expect(baris.single.kapan, DateTime(2026, 9, 15, 11, 0));
      expect(baris.single.alasan, isNull, reason: 'penundaan terakhir tanpa alasan');

      await expectLater(
        tundaRepo.terapkan(
            pengingatId: pengingatId,
            jatuhTempoAsli: jatuhTempoAsli,
            pilihan: PilihanTunda.satuJam),
        throwsA(isA<BatasTundaTerlampaui>()),
      );
      expect((await tundaRepo.daftar()).single.jumlahTunda, 3,
          reason: 'penundaan ke-4 tidak menambah baris');

      // INTI FR-148: tanggal tagihan tetap sama.
      final t = await (db.select(db.tagihan)..where((x) => x.id.equals(tagihanId)))
          .getSingle();
      expect(t.jatuhTempo, jatuhTempoAsli);
      expect(t.statusAktif, isTrue);

      // Baris tunda bisa dibersihkan (mis. sesudah pengingat dijalankan).
      expect(await tundaRepo.hapus(pengingatId), 1);
      expect(await tundaRepo.ambil(pengingatId), isNull);
    });
  });

  // =========================================================================
  // Layar
  // =========================================================================

  group('Layar platform (ukuran ponsel 420x900)', () {
    Future<void> buka(WidgetTester t, Widget layar) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      await t.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          auditRepoProvider.overrideWithValue(auditRepo),
          notifikasiRiwayatRepoProvider.overrideWithValue(riwayatRepo),
          tundaPengingatRepoProvider.overrideWithValue(tundaRepo),
          layananNotifikasiProvider.overrideWithValue(LayananUji()),
        ],
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
      await t.pump(const Duration(milliseconds: 400));
    }

    Future<void> tutup(WidgetTester t) async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
      await t.binding.setSurfaceSize(null);
    }

    Future<void> ketuk(WidgetTester t, Finder f) async {
      await t.ensureVisible(f);
      await t.pumpAndSettle(const Duration(milliseconds: 50));
      await t.tap(f);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    }

    testWidgets('kedua layar menampilkan "Belum ada data" saat masih kosong',
        (t) async {
      await buka(t, const AuditLogScreen());
      expect(find.textContaining('Belum ada data'), findsOneWidget);
      expect(find.text(catatanLokalAudit), findsOneWidget,
          reason: 'catatan jujur wajib tampil di layar');
      expect(find.textContaining('0 dari 0 catatan'), findsOneWidget);

      await buka(t, PusatNotifikasiScreen(jamSekarang: () => jamUji));
      expect(find.textContaining('Belum ada data'), findsOneWidget);
      expect(find.text(catatanLokalNotifikasi), findsOneWidget);
      expect(find.textContaining('0 belum dibaca'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('catatan aktivitas: saringan modul, ekspor berkas, pembersihan',
        (t) async {
      await barisAudit(
          modul: 'tagihan',
          waktu: DateTime(2026, 9, 15, 7),
          ringkas: 'Tagihan #18 ditandai lunas');
      await barisAudit(
          modul: 'transaksi',
          waktu: DateTime(2026, 9, 15, 6),
          ringkas: 'Pengeluaran dicatat');
      await barisAudit(
          modul: 'tagihan',
          waktu: jamUji.subtract(const Duration(days: 400)),
          ringkas: 'Catatan lama sekali');

      await buka(t, AuditLogScreen(jamSekarang: () => jamUji));
      expect(find.text('Menampilkan 3 dari 3 catatan (semua modul).'), findsOneWidget);

      // Saringan modul: pilihan dibangun dari data yang benar-benar ada.
      await ketuk(t, find.byKey(const Key('saring_transaksi')));
      expect(find.text('Pengeluaran dicatat'), findsOneWidget);
      expect(find.text('Tagihan #18 ditandai lunas'), findsNothing);
      await ketuk(t, find.byKey(const Key('saring_semua')));
      expect(find.text('Tagihan #18 ditandai lunas'), findsOneWidget);

      // Ekspor: berkas benar-benar dibuat di folder uji. Penulisan berkas
      // memakai I/O nyata, jadi ditunggu lewat runAsync (waktu uji palsu tidak
      // memajukan penulisan berkas).
      List<File> berkasJsonTerisi() => folderUji
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json') && f.lengthSync() > 0)
          .toList();
      await ketuk(t, find.byKey(const Key('ekspor_json')));
      // Jendela tunggu I/O nyata: 20 putaran x 250 ms (±5 detik), sama seperti
      // uji berkas lain di repo ini. Jendela lama (40 x 25 ms = 1 detik) pernah
      // MERAH saat SUITE PENUH berjalan: mesin sibuk membuat berkas belum
      // selesai ditulis padahal layarnya benar. Jendela lebih lebar = daya tahan
      // terhadap beban mesin, bukan pelonggaran harapan uji.
      for (var i = 0; i < 20 && berkasJsonTerisi().isEmpty; i++) {
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 250)));
        await t.pump(const Duration(milliseconds: 50));
      }
      await t.pump(const Duration(milliseconds: 200));
      final berkas = berkasJsonTerisi();
      expect(berkas.length, 1, reason: 'satu berkas JSON dibuat & terisi');
      final isi = jsonDecode(berkas.single.readAsStringSync()) as Map<String, dynamic>;
      expect(isi['jumlahBaris'], 3);

      // Pembersihan hanya sesudah konfirmasi.
      await ketuk(t, find.byKey(const Key('bersihkan_audit')));
      expect(find.text('Bersihkan catatan lama'), findsOneWidget);
      await ketuk(t, find.byKey(const Key('konfirmasi_bersihkan')));
      await t.pumpAndSettle(const Duration(milliseconds: 300));
      final sisa = await auditRepo.daftar();
      final batasLama = jamUji.subtract(const Duration(days: 365));
      expect(sisa.where((b) => b.waktu.isBefore(batasLama)), isEmpty,
          reason: 'hanya catatan > 365 hari yang hilang');
      expect(sisa.map((b) => b.ringkas), contains('Tagihan #18 ditandai lunas'));
      expect(sisa.map((b) => b.ringkas), isNot(contains('Catatan lama sekali')));
      expect(find.text('Catatan lama sekali'), findsNothing);
      // Pembersihan itu sendiri meninggalkan jejak audit (FR-138).
      expect(
          sisa.where((b) => b.aksi == 'bersihkan').length, 1,
          reason: 'jejak pembersihan tercatat');
      await tutup(t);
    });

    testWidgets('pusat notifikasi: kelompok hari, tanda belum dibaca, tandai dibaca',
        (t) async {
      final hariIni = await barisNotifikasi(
          waktu: DateTime(2026, 9, 15, 7),
          judul: 'Tagihan listrik H-1',
          isi: 'Jatuh tempo besok menurut catatan aplikasi.',
          tingkat: 'mendesak',
          pengingatId: 11);
      await barisNotifikasi(
          waktu: DateTime(2026, 9, 14, 20), judul: 'Ringkasan kemarin', isi: 'Ringkasan.');
      await barisNotifikasi(
          waktu: DateTime(2026, 9, 11, 8),
          judul: 'Pengingat lama',
          isi: 'Catatan lama.',
          status: 'dibaca');

      await buka(t, PusatNotifikasiScreen(jamSekarang: () => jamUji));
      expect(find.text('Hari ini'), findsOneWidget);
      expect(find.text('Kemarin'), findsOneWidget);
      expect(find.text('2 belum dibaca dari 3 riwayat yang ditampilkan.'),
          findsOneWidget);
      expect(find.byKey(Key('tanda_baru_$hariIni')), findsOneWidget);
      expect(find.textContaining('1 mendesak'), findsOneWidget);

      // Aksi tandai dibaca mengubah data, bukan hanya tampilan.
      await ketuk(t, find.byKey(Key('baca_$hariIni')));
      await t.pumpAndSettle(const Duration(milliseconds: 300));
      expect(await riwayatRepo.jumlahBelumDibaca(), 1);
      expect(find.byKey(Key('tanda_baru_$hariIni')), findsNothing);
      expect(find.text('1 belum dibaca dari 3 riwayat yang ditampilkan.'),
          findsOneWidget);

      // Kelompok ketiga perlu digulir dulu: ListView membangun anak seperlunya.
      await t.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await t.pumpAndSettle(const Duration(milliseconds: 50));
      expect(find.text('Lebih lama'), findsOneWidget);
      expect(find.text('Pengingat lama'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('pusat notifikasi: tunda menulis baris tunda, status, dan audit',
        (t) async {
      final id = await barisNotifikasi(
          waktu: DateTime(2026, 9, 15, 7),
          judul: 'Tagihan listrik H-1',
          isi: 'Jatuh tempo besok menurut catatan aplikasi.',
          tingkat: 'mendesak',
          pengingatId: 555);

      await buka(t, PusatNotifikasiScreen(jamSekarang: () => jamUji));
      await ketuk(t, find.byKey(Key('tunda_$id')));
      expect(find.text('Tunda pengingat'), findsOneWidget);
      expect(find.textContaining('Jatuh tempo asli tidak berubah'), findsOneWidget);
      await ketuk(t, find.byKey(const Key('pilihan_satuJam')));
      await t.pumpAndSettle(const Duration(milliseconds: 400));

      final baris = await tundaRepo.ambil(555);
      expect(baris, isNotNull);
      expect(baris!.kapan, DateTime(2026, 9, 15, 9, 0));
      expect(baris.jumlahTunda, 1);
      final riwayat = await (db.select(db.notifikasiRiwayat)
            ..where((x) => x.id.equals(id)))
          .getSingle();
      expect(riwayat.status, 'ditunda');

      // Jejak audit FR-138 ikut tercatat, tanpa menghakimi.
      final audit = await auditRepo.daftar(modul: 'notifikasi');
      expect(audit.length, 1);
      expect(audit.single.aksi, 'tunda');
      expect(audit.single.entitasId, '555');
      expect(audit.single.ringkas, contains('Pengingat ditunda sampai'));
      expect(audit.single.nilaiSesudah, '09:00');
      expect(find.textContaining('1 dari 3 kali'), findsWidgets);
      await tutup(t);
    });

    testWidgets('layar Pengingat punya pintu masuk ke Pusat Notifikasi',
        (t) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      final router = GoRouter(
        initialLocation: '/pengingat',
        routes: [
          GoRoute(
              path: '/pengingat',
              builder: (c, s) => const Scaffold(body: PengingatScreen())),
          GoRoute(path: '/notifikasi', builder: (c, s) => const PusatNotifikasiScreen()),
        ],
      );
      await t.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notifikasiRiwayatRepoProvider.overrideWithValue(riwayatRepo),
          tundaPengingatRepoProvider.overrideWithValue(tundaRepo),
          layananNotifikasiProvider.overrideWithValue(LayananUji()),
        ],
        child: MaterialApp.router(
          theme: AppTema.terang(),
          locale: const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      // Pintu masuk ditaruh di dasar daftar (agar tata letak lama tidak
      // bergeser), jadi perlu digulir dulu sampai terbangun.
      final pintu = find.byKey(const Key('buka_pusat_notifikasi'));
      for (var i = 0; i < 12 && pintu.evaluate().isEmpty; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await t.pumpAndSettle(const Duration(milliseconds: 50));
      }
      expect(pintu, findsOneWidget,
          reason: 'layar Pengingat punya pintu masuk ke Pusat Notifikasi');

      await ketuk(t, pintu);
      await t.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.text('Pusat Notifikasi'), findsOneWidget);
      await tutup(t);
    });

    testWidgets('bahasa layar & kode bebas kata terlarang (PRD III-11)', (t) async {
      await barisAudit(
          modul: 'tagihan',
          waktu: DateTime(2026, 9, 15, 7),
          ringkas: 'Tagihan #18 ditandai lunas',
          sebelum: 'Rp 300.000',
          sesudah: 'Rp 325.000');
      await barisNotifikasi(
          waktu: DateTime(2026, 9, 15, 7),
          judul: 'Tagihan listrik H-1',
          isi: 'Jatuh tempo besok menurut catatan aplikasi.',
          tingkat: 'mendesak',
          pengingatId: 11);

      const terlarang = [
        'kamu',
        'anda gagal',
        'gagal',
        'skor',
        'berdosa',
        'malas',
        'rajin',
        'wajib anda',
        'belum sholat',
        'diagnosis',
      ];

      await buka(t, AuditLogScreen(jamSekarang: () => jamUji));
      final teksAudit = teksTampil(t);
      expect(teksAudit, isNotEmpty);
      for (final teks in teksAudit) {
        for (final kata in terlarang) {
          expect(teks.toLowerCase().contains(kata), isFalse,
              reason: '"$teks" memuat "$kata"');
        }
      }

      await buka(t, PusatNotifikasiScreen(jamSekarang: () => jamUji));
      final teksNotif = teksTampil(t);
      expect(teksNotif, isNotEmpty);
      for (final teks in teksNotif) {
        for (final kata in terlarang) {
          expect(teks.toLowerCase().contains(kata), isFalse,
              reason: '"$teks" memuat "$kata"');
        }
      }
      await tutup(t);

      // Sumber berkas milik pekerjaan ini — termasuk komentar dan doc yang
      // dibaca pembaca berikutnya. Berkas uji ini sendiri tidak dipindai karena
      // daftar kata terlarang memang ditulis di sini. Berkas lama
      // (mis. pengingat_screen.dart) juga tidak dipindai: teks lamanya di luar
      // cakupan perubahan ini.
      const berkasSaya = [
        'lib/core/audit/audit_log.dart',
        'lib/core/notifikasi/tunda_pengingat.dart',
        'lib/data/repository/audit_repository.dart',
        'lib/data/repository/notifikasi_riwayat_repository.dart',
        'lib/features/platform/audit_log_screen.dart',
        'lib/features/platform/pusat_notifikasi_screen.dart',
      ];
      for (final nama in berkasSaya) {
        final f = File(nama);
        expect(f.existsSync(), isTrue, reason: 'berkas $nama harus ada');
        final isi = f.readAsStringSync().toLowerCase();
        for (final kata in terlarang) {
          expect(isi.contains(kata), isFalse, reason: '$nama memuat "$kata"');
        }
      }
    });
  });
}
