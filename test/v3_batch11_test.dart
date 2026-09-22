/// Uji Batch 11 — FR-48 (dana persiapan), FR-54 (pengingat obat/suplemen),
/// FR-47 (split bill & patungan), FR-55 (delegasi WhatsApp), FR-149 (AI Copilot).
///
/// Aturan yang dipegang: setiap harapan mengacu ke keluaran nyata; jendela waktu
/// uji boleh dilebarkan, harapan tidak boleh dilonggarkan.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/analitik/copilot.dart';
import 'package:personal_life_os/core/analitik/dana_persiapan.dart';
import 'package:personal_life_os/core/kesehatan/rencana_obat.dart';
import 'package:personal_life_os/core/notifikasi/delegasi_whatsapp.dart';
import 'package:personal_life_os/core/notifikasi/perencana_pengingat.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/rumah/patungan.dart';
import 'package:personal_life_os/core/sinkron/registri_sinkron.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/copilot_repository.dart';
import 'package:personal_life_os/data/repository/dana_persiapan_repository.dart';
import 'package:personal_life_os/data/repository/delegasi_repository.dart';
import 'package:personal_life_os/data/repository/obat_repository.dart';
import 'package:personal_life_os/data/repository/patungan_repository.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/features/kesehatan/jadwal_obat_screen.dart';
import 'package:personal_life_os/features/kesehatan/pengingat_jadwal_obat.dart';
import 'package:personal_life_os/features/laporan/dana_persiapan_screen.dart';
import 'package:personal_life_os/features/ritme/copilot_screen.dart';
import 'package:personal_life_os/features/rumah/patungan_screen.dart';
import 'package:personal_life_os/features/tagihan/delegasi_screen.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

/// Tunggu sampai [syarat] benar (melebarkan jendela waktu, bukan harapan).
Future<void> _tungguSampai(WidgetTester t, bool Function() syarat,
    {int putaran = 60}) async {
  for (var i = 0; i < putaran; i++) {
    if (syarat()) return;
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump(const Duration(milliseconds: 50));
  }
}

void layarTinggi(WidgetTester t) {
  t.view.physicalSize = const Size(1200, 3400);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

Future<void> _pasang(WidgetTester t, Widget layar, AppDatabase db) async {
  layarTinggi(t);
  await t.pumpWidget(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(home: layar),
  ));
  await t.pump();
}

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // FR-48 — Dana persiapan
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-48 mesin dana persiapan', () {
    test('bulanAntara menghitung bulan penuh', () {
      expect(bulanAntara(DateTime(2026, 1, 1), DateTime(2026, 4, 1)), 3);
      expect(bulanAntara(DateTime(2026, 1, 15), DateTime(2026, 4, 20)), 4);
    });

    test('dana jalan: sisa, persen, dan setoran per bulan', () {
      final r = hitungDanaPersiapan(
        DanaPersiapan(
          nama: 'Servis motor',
          targetSen: 10000000, // Rp 100.000
          tersediaSen: 2500000, // Rp 25.000
          tanggalTarget: DateTime(2026, 12, 31),
        ),
        sekarang: DateTime(2026, 9, 22),
      );
      expect(r.sisaSen, 7500000);
      expect(r.persen, 25);
      expect(r.status, StatusDana.jalan);
      expect(r.bulanTersisa, greaterThan(0));
      expect(r.setoranBulananSen, isNotNull);
      expect(r.setoranBulananSen! * r.bulanTersisa! >= r.sisaSen, isTrue);
    });

    test('target belum diisi: persen & setoran null, status apa adanya', () {
      final r = hitungDanaPersiapan(
        const DanaPersiapan(nama: 'Pajak', targetSen: 0, tersediaSen: 500000),
        sekarang: DateTime(2026, 9, 22),
      );
      expect(r.persen, isNull);
      expect(r.setoranBulananSen, isNull);
      // Sudah ada setoran → "sedang diisi"; tanpa setoran → "belum mulai".
      expect(r.status, StatusDana.jalan);
      final kosong = hitungDanaPersiapan(
        const DanaPersiapan(nama: 'Pajak', targetSen: 0, tersediaSen: 0),
        sekarang: DateTime(2026, 9, 22),
      );
      expect(kosong.status, StatusDana.belum);
      final d = ringkasDanaPersiapan(
        const [DanaPersiapan(nama: 'Pajak', targetSen: 0, tersediaSen: 500000)],
        sekarang: DateTime(2026, 9, 22),
      );
      expect(d.belumBisa.any((b) => b.contains('target belum diisi')), isTrue);
    });

    test('terkumpul penuh: status terkumpul & sisa nol', () {
      final r = hitungDanaPersiapan(
        const DanaPersiapan(
            nama: 'Tiket pulang', targetSen: 2000000, tersediaSen: 2000000),
        sekarang: DateTime(2026, 9, 22),
      );
      expect(r.status, StatusDana.terkumpul);
      expect(r.sisaSen, 0);
      expect(r.persen, 100);
    });

    test('tanggal target lewat & belum lunas: status lewat + dicatat belumBisa',
        () {
      final r = hitungDanaPersiapan(
        DanaPersiapan(
          nama: 'Sekolah anak',
          targetSen: 5000000,
          tersediaSen: 1000000,
          tanggalTarget: DateTime(2026, 1, 31),
        ),
        sekarang: DateTime(2026, 9, 22),
      );
      expect(r.status, StatusDana.lewat);
      final d = ringkasDanaPersiapan([
        DanaPersiapan(
          nama: 'Sekolah anak',
          targetSen: 5000000,
          tersediaSen: 1000000,
          tanggalTarget: DateTime(2026, 1, 31),
        ),
      ], sekarang: DateTime(2026, 9, 22), arusKasSen: 9000000);
      expect(d.peringatan.any((b) => b.contains('tanggal target sudah lewat')),
          isTrue);
    });

    test('dasbor: total & arus kas bersih = kas − alokasi bulan ini', () {
      final d = ringkasDanaPersiapan([
        DanaPersiapan(
          nama: 'Servis motor',
          targetSen: 10000000,
          tersediaSen: 2500000,
          tanggalTarget: DateTime(2026, 12, 31),
        ),
      ], sekarang: DateTime(2026, 9, 22), arusKasSen: 5000000);
      expect(d.totalTargetSen, 10000000);
      expect(d.totalTersediaSen, 2500000);
      expect(d.totalSisaSen, 7500000);
      expect(d.totalAlokasiBulananSen, greaterThan(0));
      expect(d.arusKasBersihSen, 5000000 - d.totalAlokasiBulananSen);
    });

    test('tanpa data arus kas: dinyatakan belum bisa dihitung', () {
      final d = ringkasDanaPersiapan(
        const [DanaPersiapan(nama: 'Servis', targetSen: 100, tersediaSen: 10)],
        sekarang: DateTime(2026, 9, 22),
      );
      expect(d.arusKasBersihSen, isNull);
      expect(d.belumBisa.any((b) => b.contains('Arus kas bulan ini')),
          isTrue);
    });

    test('alokasi melebihi arus kas: peringatan muncul', () {
      final d = ringkasDanaPersiapan([
        DanaPersiapan(
          nama: 'Servis motor',
          targetSen: 100000000,
          tersediaSen: 0,
          tanggalTarget: DateTime(2026, 12, 31),
        ),
      ], sekarang: DateTime(2026, 9, 22), arusKasSen: 100);
      expect(d.arusKasBersihSen! < 0, isTrue);
      expect(d.peringatan.any((b) => b.contains('melebihi arus kas')), isTrue);
    });

    test('riwayatSetoran: saring per dana & terbaru dulu', () {
      final r = riwayatSetoran([
        SetoranDana(
            danaNama: 'A', jumlahSen: 100, tanggal: DateTime(2026, 9, 1)),
        SetoranDana(
            danaNama: 'A', jumlahSen: 200, tanggal: DateTime(2026, 9, 20)),
        SetoranDana(
            danaNama: 'B', jumlahSen: 300, tanggal: DateTime(2026, 9, 10)),
      ], 'A');
      expect(r.length, 2);
      expect(r.first.jumlahSen, 200);
    });

    test('repositori: tambah dana + setoran menambah tersedia', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = DanaPersiapanRepository(db);
      await repo.tambah(nama: 'Servis motor', targetSen: 10000000);
      final satu = (await repo.semua()).single;
      expect(satu.tersediaSen, 0);

      await repo.tambahSetoran(danaUid: satu.uid!, jumlahSen: 2500000);
      final sesudah = (await repo.semua()).single;
      expect(sesudah.tersediaSen, 2500000);
      expect((await repo.setoran(satu.uid!)).length, 1);

      final dash = await repo.ringkasan(arusKasSen: 9000000);
      expect(dash.totalTersediaSen, 2500000);
      expect(dash.dana.single.persen, 25);
    });

    test('repositori: setoran nol & nama kosong ditolak', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = DanaPersiapanRepository(db);
      expect(() => repo.tambah(nama: '  ', targetSen: 1), throwsArgumentError);
      final id = await repo.tambah(nama: 'Servis', targetSen: 100);
      final uid = (await repo.semua()).single.uid!;
      expect(() => repo.tambahSetoran(danaUid: uid, jumlahSen: 0),
          throwsArgumentError);
      expect(id, greaterThan(0));
    });

    test('repositori: hapus dana menghapus setorannya', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = DanaPersiapanRepository(db);
      final id = await repo.tambah(nama: 'Servis', targetSen: 100000);
      final uid = (await repo.semua()).single.uid!;
      await repo.tambahSetoran(danaUid: uid, jumlahSen: 1000);
      await repo.hapus(id);
      expect(await repo.semua(), isEmpty);
      expect(await repo.semuaSetoran(), isEmpty);
    });

    testWidgets('layar dana: keadaan kosong & setelah ada dana', (t) async {
      final db = _db();
      addTearDown(db.close);
      await _pasang(t, const DanaPersiapanScreen(), db);
      await _tungguSampai(t, () => find.byKey(const Key('dana_kosong')).evaluate().isNotEmpty);
      expect(find.byKey(const Key('dana_kosong')), findsOneWidget);

      final id = await DanaPersiapanRepository(db)
          .tambah(nama: 'Servis motor', targetSen: 10000000, tersediaSen: 2500000);
      await _tungguSampai(t, () => find.byKey(Key('dana_$id')).evaluate().isNotEmpty);
      expect(find.byKey(Key('dana_$id')), findsOneWidget);
      expect(find.byKey(Key('dana_persen_$id')), findsOneWidget);
      expect(find.text('Servis motor'), findsWidgets);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // FR-54 — Pengingat obat/suplemen (memakai ulang modul obat FR-106)
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-54 mesin rencana obat', () {
    test('menitDariJam menerima bentuk wajar & menolak yang tidak masuk akal',
        () {
      expect(menitDariJam('07:30'), 450);
      expect(menitDariJam('7.05'), 425);
      expect(menitDariJam('25:00'), isNull);
      expect(menitDariJam('07:75'), isNull);
      expect(menitDariJam(''), isNull);
      expect(menitDariJam(null), isNull);
    });

    test('jamDariMenit membalikkan menit ke HH:mm', () {
      expect(jamDariMenit(450), '07:30');
      expect(jamDariMenit(0), '00:00');
      expect(jamDariMenit(1450), '00:10'); // melewati tengah malam
    });

    test('slotMendatang: lewati nonaktif, jam tidak sah, dan yang sudah lewat',
        () {
      final sekarang = DateTime(2026, 9, 22, 8, 0);
      final slot = slotMendatang([
        const JadwalRingkas(obatId: 1, jadwalId: 1, nama: 'A', jam: '09:00'),
        const JadwalRingkas(obatId: 2, jadwalId: 2, nama: 'B', jam: '07:00'),
        const JadwalRingkas(obatId: 3, jadwalId: 3, nama: 'C', jam: '29:00'),
        const JadwalRingkas(
            obatId: 4, jadwalId: 4, nama: 'D', jam: '10:00', aktif: false),
      ], sekarang);
      expect(slot.map((s) => s.nama).toList(), ['A', 'B'],
          reason: '07:00 hari ini sudah lewat, tapi 07:00 besok masih di jendela');
      expect(slot.first.waktu, DateTime(2026, 9, 22, 9, 0));
      expect(slot.last.waktu, DateTime(2026, 9, 23, 7, 0));
    });

    test('slotMendatang: menghormati jendela & tanggal mulai obat', () {
      final sekarang = DateTime(2026, 9, 22, 8, 0);
      final slot = slotMendatang([
        JadwalRingkas(
          obatId: 1,
          jadwalId: 1,
          nama: 'A',
          jam: '09:00',
          mulai: DateTime(2026, 9, 23),
        ),
      ], sekarang);
      expect(slot, isEmpty, reason: 'obat belum mulai hari ini');

      final jauh = slotMendatang([
        const JadwalRingkas(obatId: 1, jadwalId: 1, nama: 'A', jam: '09:00'),
      ], sekarang, jendela: const Duration(hours: 48));
      expect(jauh.length, 2, reason: '24 jam & 48 jam ke depan');
      expect(jauh.first.waktu.isBefore(jauh.last.waktu), isTrue);
    });

    test('idPengingatObat stabil & berbeda antar obat', () {
      expect(idPengingatObat(1999300000, 7, 0), idPengingatObat(1999300000, 7, 0));
      expect(idPengingatObat(1999300000, 7, 0),
          isNot(idPengingatObat(1999300000, 8, 0)));
      expect(idPengingatObat(1999300000, 7, 0), greaterThan(1999300000));
    });

    test('teksPengingatObat memuat nama, dosis, dan jam', () {
      final teks = teksPengingatObat(SlotObat(
        obatId: 1,
        jadwalId: 1,
        nama: 'Amlodipin',
        dosis: '5 mg · 1 tablet',
        waktu: DateTime(2026, 9, 22, 7, 30),
      ));
      expect(teks.judul, contains('Amlodipin'));
      expect(teks.isi, contains('5 mg'));
      expect(teks.isi, contains('07:30'));
    });

    test('ringkasPengingatObat: buang yang sudah dicatat & sebut berikutnya', () {
      final sekarang = DateTime(2026, 9, 22, 8, 0);
      final slot = [
        SlotObat(
            obatId: 1,
            jadwalId: 1,
            nama: 'A',
            dosis: '',
            waktu: DateTime(2026, 9, 22, 9, 0)),
        SlotObat(
            obatId: 2,
            jadwalId: 2,
            nama: 'B',
            dosis: '',
            waktu: DateTime(2026, 9, 22, 21, 0)),
      ];
      final r = ringkasPengingatObat(slot, sekarang,
          sudahDicatat: {kunciSlot(slot.first)});
      expect(r.slot.length, 1);
      expect(r.kalimatBerikutnya, contains('B'));
      expect(r.jumlahHariIni, 1);
    });

    test('tanpa slot: kalimat menyatakan belum ada jam berikutnya', () {
      final r = ringkasPengingatObat(const [], DateTime(2026, 9, 22, 8, 0));
      expect(r.ada, isFalse);
      expect(r.kalimatBerikutnya, 'Belum ada jam minum berikutnya.');
      expect(r.kemajuanHariIni, isNull);
    });
  });

  group('FR-54 pengingat obat (basis data)', () {
    test('izin mati (bawaan): tidak ada pengingat sama sekali', () async {
      final db = _db();
      addTearDown(db.close);
      final obatId = await db.into(db.obat).insert(ObatCompanion.insert(
            nama: 'Amlodipin',
            dosisTeks: Value('5 mg'),
          ));
      await db.into(db.jadwalObat).insert(JadwalObatCompanion.insert(
            obatId: obatId,
            jam: '23:59',
          ));
      final sumber = SumberPengingatJadwalObat(
        pembukaBasisData: () => db,
        tutupBasisData: false,
      );
      expect(await IzinPengingatObat(db).baca(), isFalse);
      expect(await sumber.pengingatTambahan(DateTime.now()), isEmpty);
    });

    test('izin nyala: pengingat dibuat mengikuti jam jadwal', () async {
      final db = _db();
      addTearDown(db.close);
      final obatId = await db.into(db.obat).insert(ObatCompanion.insert(
            nama: 'Amlodipin',
            dosisTeks: Value('5 mg'),
          ));
      // Jam uji dihitung dari waktu berjalan supaya jendela tidak mepet.
      final kiniUji = DateTime.now();
      final jamUji = jamDariMenit(
          kiniUji.hour * 60 + kiniUji.minute + 30);
      await db.into(db.jadwalObat).insert(JadwalObatCompanion.insert(
            obatId: obatId,
            jam: jamUji,
          ));
      await IzinPengingatObat(db).simpan(true);
      expect(await IzinPengingatObat(db).baca(), isTrue);

      final kini = DateTime.now();
      final sumber = SumberPengingatJadwalObat(
        pembukaBasisData: () => db,
        tutupBasisData: false,
      );
      final daftar = await sumber.pengingatTambahan(kini);
      expect(daftar, isNotEmpty);
      final p = daftar.first;
      expect(p.judul, contains('Amlodipin'));
      expect(p.waktu.isAfter(kini), isTrue);
      expect(p.id, greaterThan(batasIdKhusus));

      // Sudah dicatat minum → slot itu tidak diingatkan lagi.
      await ObatRepository(db).catatMinum(
        obatId: obatId,
        waktuRencana: p.waktu,
        status: StatusMinum.diminum,
      );
      final sesudah = await sumber.pengingatTambahan(kini);
      expect(sesudah.length, daftar.length - 1);
    });

    test('jadwalRingkas menggabungkan obat aktif + jadwal aktif', () async {
      final db = _db();
      addTearDown(db.close);
      final a = await db.into(db.obat).insert(ObatCompanion.insert(
            nama: 'Amlodipin',
            dosisTeks: Value('5 mg'),
          ));
      final b = await db.into(db.obat).insert(ObatCompanion.insert(
            nama: 'Vitamin D',
            aktif: Value(false),
          ));
      await db.into(db.jadwalObat).insert(
          JadwalObatCompanion.insert(obatId: a, jam: '07:00'));
      await db.into(db.jadwalObat).insert(
          JadwalObatCompanion.insert(obatId: a, jam: '19:00'));
      await db.into(db.jadwalObat).insert(
          JadwalObatCompanion.insert(obatId: b, jam: '08:00'));

      final jam = await ObatRepository(db).jadwalRingkas();
      expect(jam.length, 2, reason: 'obat nonaktif tidak ikut');
      expect(jam.map((j) => j.nama).toSet(), {'Amlodipin'});
      expect(jam.first.dosis, contains('5 mg'));
    });

    testWidgets('layar pengingat obat: izin bawaan mati & bisa dinyalakan',
        (t) async {
      final db = _db();
      addTearDown(db.close);
      await _pasang(t, const JadwalObatScreen(), db);
      await _tungguSampai(t,
          () => find.byKey(const Key('kalimat_izin_obat')).evaluate().isNotEmpty);
      expect(find.byKey(const Key('obat_kosong')), findsOneWidget);

      final saklar = t.widget<SwitchListTile>(
          find.byKey(const Key('izin_pengingat_obat')));
      expect(saklar.value, isFalse);

      await t.tap(find.byKey(const Key('izin_pengingat_obat')));
      await _tungguSampai(t,
          () => find.textContaining('Alarm dibuat').evaluate().isNotEmpty ||
              find.textContaining('Pengingat obat dinyalakan').evaluate().isNotEmpty);
      expect(await PengaturanRepository(db).bacaSaklar(kunciIzinPengingatObat),
          isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // FR-47 — Split bill & patungan
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-47 mesin patungan', () {
    test('bagiSamaRata: jumlah bagian = total (sisa dibagikan)', () {
      final bagi = bagiSamaRata(100000, ['A', 'B', 'C']);
      expect(bagi.values.reduce((a, b) => a + b), 100000);
      expect(bagi.values.reduce((a, b) => a + b), 100000);
      final nilai = bagi.values.toList()..sort();
      expect(nilai.last - nilai.first <= 1, isTrue);
      expect(bagiSamaRata(1000, const []), isEmpty);
    });

    test('hitungPatungan: siapa transfer ke siapa', () {
      final hasil = hitungPatungan(
        grup: const GrupPatungan(nama: 'Trip Bali'),
        anggota: const [
          AnggotaPatungan(grupNama: 'Trip Bali', nama: 'A'),
          AnggotaPatungan(grupNama: 'Trip Bali', nama: 'B'),
          AnggotaPatungan(grupNama: 'Trip Bali', nama: 'C'),
        ],
        belanja: [
          BelanjaPatungan(
            grupNama: 'Trip Bali',
            judul: 'Villa',
            totalSen: 300000,
            pembayar: 'A',
            tanggal: DateTime(2026, 9, 20),
          ),
        ],
        bagian: bagiSamaRata(300000, ['A', 'B', 'C'])
            .entries
            .map((e) => BagianPatungan(
                  kunciBelanja: 'Villa|2026-09-20T00:00:00.000|300000',
                  anggota: e.key,
                  jumlahSen: e.value,
                ))
            .toList(),
      );
      expect(hasil.totalBelanjaSen, 300000);
      expect(hasil.belumBisa, isEmpty);
      expect(hasil.transfer.length, 2);
      expect(hasil.transfer.every((x) => x.ke == 'A'), isTrue);
      expect(hasil.transfer.fold<int>(0, (a, x) => a + x.jumlahSen), 200000);
      expect(teksRingkasPatungan(hasil), contains('transfer'));
    });

    test('hitungPatungan: jumlah bagian tidak sama dengan total → peringatan',
        () {
      final hasil = hitungPatungan(
        grup: const GrupPatungan(nama: 'Grup'),
        anggota: const [
          AnggotaPatungan(grupNama: 'Grup', nama: 'A'),
          AnggotaPatungan(grupNama: 'Grup', nama: 'B'),
        ],
        belanja: [
          BelanjaPatungan(
            grupNama: 'Grup',
            judul: 'Makan',
            totalSen: 100000,
            pembayar: 'A',
            tanggal: DateTime(2026, 9, 20),
          ),
        ],
        bagian: const [
          BagianPatungan(
              kunciBelanja: 'Makan|2026-09-20T00:00:00.000|100000',
              anggota: 'A',
              jumlahSen: 10000),
        ],
      );
      expect(hasil.peringatan.any((p) => p.contains('tidak sama dengan total')),
          isTrue);
      final saldoA = hasil.saldo.firstWhere((s) => s.nama == 'A');
      expect(saldoA.tanggunganSen, 10000,
          reason: 'yang dihitung hanya bagian yang benar-benar diisi');
      expect(hasil.transfer, isEmpty,
          reason: 'B belum punya bagian, jadi tidak ada yang perlu transfer — '
              'dan itu sudah diingatkan lewat peringatan');
    });

    test('hitungPatungan: tanpa anggota & tanpa belanja dinyatakan belum bisa',
        () {
      final hasil = hitungPatungan(
        grup: const GrupPatungan(nama: 'Kosong'),
        anggota: const [],
        belanja: const [],
        bagian: const [],
      );
      expect(hasil.belumBisa.any((b) => b.contains('belum punya anggota')),
          isTrue);
      expect(hasil.belumBisa.any((b) => b.contains('belum punya belanja')),
          isTrue);
      expect(hasil.lunas, isFalse);
    });

    test('hitungPatungan: pembayar bukan anggota → peringatan', () {
      final hasil = hitungPatungan(
        grup: const GrupPatungan(nama: 'Grup'),
        anggota: const [AnggotaPatungan(grupNama: 'Grup', nama: 'A')],
        belanja: [
          BelanjaPatungan(
            grupNama: 'Grup',
            judul: 'Kopi',
            totalSen: 20000,
            pembayar: 'Z',
            tanggal: DateTime(2026, 9, 21),
          ),
        ],
        bagian: const [],
      );
      expect(hasil.peringatan.any((p) => p.contains('bukan anggota grup')),
          isTrue);
    });

    test('susunTransfer menyelesaikan saldo sampai nol', () {
      final t = susunTransfer(const [
        SaldoPatungan(nama: 'A', dibayarSen: 300000, tanggunganSen: 100000),
        SaldoPatungan(nama: 'B', dibayarSen: 0, tanggunganSen: 100000),
        SaldoPatungan(nama: 'C', dibayarSen: 0, tanggunganSen: 100000),
      ]);
      expect(t.length, 2);
      expect(t.fold<int>(0, (a, x) => a + x.jumlahSen), 200000);
    });

    test('repositori: grup, anggota, belanja sama rata, dan hasil', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = PatunganRepository(db);
      final grupId = await repo.tambahGrup(nama: 'Trip Bali');
      final grup = (await repo.grupSemua()).single;
      expect(grup.kodeUndangan, isNotNull);
      expect(grup.kodeUndangan!.length, 6);

      for (final n in ['A', 'B', 'C']) {
        await repo.tambahAnggota(grup.uid!, n);
      }
      expect((await repo.anggota(grup.uid!)).length, 3);

      final belanjaId = await repo.tambahBelanja(
        grupUid: grup.uid!,
        judul: 'Villa',
        totalSen: 300000,
        pembayar: 'A',
      );
      expect((await repo.bagianUntuk((await repo.belanja(grup.uid!)).single.uid!)).length, 3);

      final hasil = await repo.hasil(grupId);
      expect(hasil.transfer.length, 2);
      expect(hasil.totalBelanjaSen, 300000);

      await repo.hapusBelanja(belanjaId);
      expect(await repo.belanja(grup.uid!), isEmpty);
      expect(hasil.belumBisa, isEmpty);
    });

    test('repositori: bagian khusus dipakai apa adanya', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = PatunganRepository(db);
      await repo.tambahGrup(nama: 'Arisan');
      final grup = (await repo.grupSemua()).single;
      await repo.tambahAnggota(grup.uid!, 'A');
      await repo.tambahAnggota(grup.uid!, 'B');
      await repo.tambahBelanja(
        grupUid: grup.uid!,
        judul: 'Kado',
        totalSen: 100000,
        pembayar: 'A',
        cara: CaraBagi.khusus,
        bagianKhusus: const {'A': 40000, 'B': 60000},
      );
      final belanja = (await repo.belanja(grup.uid!)).single;
      final bagian = await repo.bagianUntuk(belanja.uid!);
      final peta = {for (final b in bagian) b.anggota: b.jumlahSen};
      expect(peta, {'A': 40000, 'B': 60000});
    });

    test('repositori: hapus grup menghapus anggota & belanja', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = PatunganRepository(db);
      final id = await repo.tambahGrup(nama: 'Sementara');
      final grup = (await repo.grupSemua()).single;
      await repo.tambahAnggota(grup.uid!, 'A');
      await repo.tambahBelanja(
        grupUid: grup.uid!,
        judul: 'Kopi',
        totalSen: 10000,
        pembayar: 'A',
      );
      await repo.hapusGrup(id);
      expect(await repo.grupSemua(), isEmpty);
      expect(await repo.anggota(grup.uid!), isEmpty);
      expect(await repo.belanja(grup.uid!), isEmpty);
    });

    testWidgets('layar patungan: keadaan kosong lalu muncul grup', (t) async {
      final db = _db();
      addTearDown(db.close);
      await _pasang(t, const PatunganScreen(), db);
      await _tungguSampai(t,
          () => find.byKey(const Key('patungan_kosong')).evaluate().isNotEmpty);
      expect(find.byKey(const Key('patungan_kosong')), findsOneWidget);

      final id = await PatunganRepository(db).tambahGrup(nama: 'Trip Bali');
      await _tungguSampai(t,
          () => find.byKey(Key('grup_$id')).evaluate().isNotEmpty);
      expect(find.byKey(Key('grup_$id')), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // FR-55 — Delegasi cepat via WhatsApp
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-55 mesin delegasi', () {
    test('nomorInternasional: merapikan nomor Indonesia & menolak yang ngawur', () {
      expect(nomorInternasional('081234567890'), startsWith('62'));
      expect(nomorInternasional('+62 812-3456-7890'), startsWith('62'));
      expect(nomorInternasional('123'), isNull);
      expect(nomorInternasional(''), isNull);
      expect(nomorInternasional(null), isNull);
    });

    test('nomorTampil: samar sebagian & jujur bila belum rapi', () {
      expect(nomorTampil('081234567890'), startsWith('+62 812'));
      expect(nomorTampil('abc'), contains('belum rapi'));
      expect(nomorTampil(''), '—');
    });

    test('teksDelegasiTagihan memuat jumlah & sisa hari', () {
      final teks = teksDelegasiTagihan(
        judul: 'Listrik',
        jumlahSen: 25000000,
        jatuhTempo: DateTime(2026, 9, 25),
        dariNama: 'Papi',
        keNama: 'Kak',
        sekarang: DateTime(2026, 9, 22),
      );
      expect(teks, contains('Listrik'));
      expect(teks, contains('Rp 250.000'));
      expect(teks, contains('3 hari lagi'));
      expect(teks, contains('Papi'));
      expect(teks, contains('Kak'));
    });

    test('teksDelegasiTugas memuat judul & pengirim', () {
      final teks = teksDelegasiTugas(
        judul: 'Antar adik ke sekolah',
        dariNama: 'Papi',
        keNama: 'Kak',
        kapan: DateTime(2026, 9, 23, 6, 30),
      );
      expect(teks, contains('Antar adik ke sekolah'));
      expect(teks, contains('06:30'));
    });

    test('alasanTidakBisaKirim: salin tanpa nomor, wa wajib nomor sah', () {
      expect(
          alasanTidakBisaKirim(nomor: '', kanal: KanalDelegasi.salin), isEmpty);
      expect(alasanTidakBisaKirim(nomor: '', kanal: KanalDelegasi.whatsapp),
          contains('Nomor HP belum diisi.'));
      expect(
          alasanTidakBisaKirim(nomor: 'abc', kanal: KanalDelegasi.sms)
              .any((a) => a.contains('tidak dikenali')),
          isTrue);
      expect(alasanTidakBisaKirim(nomor: '081234567890', kanal: KanalDelegasi.whatsapp),
          isEmpty);
    });

    test('tautan WhatsApp/SMS dibuat dari kanal yang sudah ada (FR-49)', () {
      final wa = tautanWhatsapp('081234567890', 'Halo');
      expect(wa, isNotNull);
      expect(wa!, contains('wa.me'));
      final sms = tautanSms('081234567890', 'Halo');
      expect(sms, isNotNull);
      expect(sms!.startsWith('smsto:') || sms.startsWith('sms:'), isTrue);
      expect(tautanWhatsapp('abc', 'Halo'), isNull);
    });

    test('ringkasDelegasi: menyebut yang belum ada & tanpa nomor sah', () {
      final r = ringkasDelegasi(const [], sekarang: DateTime(2026, 9, 22));
      expect(r.jumlah, 0);
      expect(r.belumBisa.any((b) => b.contains('Belum ada pengingat')), isTrue);

      final r2 = ringkasDelegasi([
        DelegasiTercatat(
          judul: 'Listrik',
          keNama: 'Kak',
          nomor: '081234567890',
          kanal: KanalDelegasi.whatsapp,
          waktu: DateTime(2026, 9, 22, 9),
          teks: 'Bayar listrik',
        ),
        DelegasiTercatat(
          judul: 'Air',
          keNama: 'Kak',
          nomor: null,
          kanal: KanalDelegasi.salin,
          waktu: DateTime(2026, 9, 22, 8),
          teks: 'Bayar air',
        ),
      ], sekarang: DateTime(2026, 9, 22));
      expect(r2.jumlah, 2);
      expect(r2.perOrang.first.key, 'Kak');
      expect(r2.belumBisa.any((b) => b.contains('tanpa nomor HP')), isTrue);
    });

    test('repositori: catat, baca, ringkas, hapus', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = DelegasiRepository(db);
      final id = await repo.catat(
        judul: 'Listrik',
        keNama: 'Kak',
        nomor: '081234567890',
        kanal: KanalDelegasi.whatsapp,
        teks: 'Bayar listrik ya',
      );
      final semua = await repo.semua();
      expect(semua.length, 1);
      expect(semua.single.nomor, isNot(''));
      final ringkas = await repo.ringkasan();
      expect(ringkas.jumlah, 1);
      await repo.hapus(id);
      expect(await repo.semua(), isEmpty);
    });

    test('repositori: judul & nama kosong ditolak', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = DelegasiRepository(db);
      expect(
          () => repo.catat(
                judul: ' ',
                keNama: 'Kak',
                kanal: KanalDelegasi.salin,
                teks: 'x',
              ),
          throwsArgumentError);
      expect(
          () => repo.catat(
                judul: 'Listrik',
                keNama: '',
                kanal: KanalDelegasi.salin,
                teks: 'x',
              ),
          throwsArgumentError);
    });

    testWidgets('layar delegasi: keadaan kosong', (t) async {
      final db = _db();
      addTearDown(db.close);
      await _pasang(t, const DelegasiScreen(), db);
      await _tungguSampai(t,
          () => find.byKey(const Key('delegasi_kosong')).evaluate().isNotEmpty);
      expect(find.byKey(const Key('delegasi_kosong')), findsOneWidget);
      expect(find.byKey(const Key('delegasi_ringkas')), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // FR-149 — AI Copilot ber-konteks
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-149 mesin copilot', () {
    test('susunKonteksCopilot: kosong vs berisi', () {
      expect(susunKonteksCopilot(const BahanKonteksCopilot()).kosong, isTrue);

      final k = susunKonteksCopilot(const BahanKonteksCopilot(
        tagihanTerdekat: ['Listrik Rp 250.000 jatuh tempo 25/9/2026'],
        danaPersiapan: ['Servis motor: Rp 25.000 dari target Rp 100.000'],
        obatHariIni: ['Amlodipin (5 mg) jam 07:00'],
        perjalananTerdekat: 'Ke Bali mulai 5/10/2026',
      ));
      expect(k.kosong, isFalse);
      expect(k.daftarData.length, 4);
      expect(k.teks, contains('Listrik'));
      expect(k.jumlahKarakter, k.teks.length);
    });

    test('bolehTanyaCopilot: alasan izin, kunci, alamat, offline', () {
      const konfig = KonfigCopilot(kunci: '', izinDiberikan: false);
      final alasan = bolehTanyaCopilot(konfig, adaJaringan: false);
      expect(alasan.length, 3, reason: 'alamat bawaan masih benar');
      expect(alasan[0], contains('Izin belum diberikan'));
      expect(alasan.any((a) => a.contains('offline')), isTrue);

      final alamatSalah = bolehTanyaCopilot(
        const KonfigCopilot(
            endpoint: 'bukan-url', kunci: 'sk', izinDiberikan: true),
        adaJaringan: true,
      );
      expect(alamatSalah.single, contains('Alamat layanan AI belum benar'));

      const siap = KonfigCopilot(kunci: 'sk-uji', izinDiberikan: true);
      expect(bolehTanyaCopilot(siap, adaJaringan: true), isEmpty);
      expect(konfig.kunciTersamar, 'belum diisi');
      expect(siap.kunciTersamar, '••••-uji');
    });

    test('susunPermintaanCopilot: URL, header, dan konteks ikut dikirim', () {
      const konfig = KonfigCopilot(
        endpoint: 'https://api.deepseek.com/chat/completions',
        model: 'deepseek-chat',
        kunci: 'sk-rahasia',
        izinDiberikan: true,
      );
      final konteks = susunKonteksCopilot(
          const BahanKonteksCopilot(tagihanTerdekat: ['Listrik Rp 250.000']));
      final p = susunPermintaanCopilot(
        konfig: konfig,
        konteks: konteks,
        pertanyaan: 'Apa yang harus saya dahulukan?',
      );
      expect(p.url, konfig.endpoint);
      expect(p.headers['Authorization'], 'Bearer sk-rahasia');
      expect(p.body, contains('deepseek-chat'));
      expect(p.body, contains('Listrik Rp 250.000'));
      expect(p.body, contains('Apa yang harus saya dahulukan?'));
      expect(p.body, contains('DATA PENGGUNA'));
    });

    test('uraiJawabanCopilot: jawaban normal & galat dijelaskan apa adanya', () {
      expect(
        uraiJawabanCopilot(
          '{"choices":[{"message":{"content":" Bayar listrik dulu. "}}]}',
          statusKode: 200,
        ),
        'Bayar listrik dulu.',
      );
      expect(uraiJawabanCopilot('{}', statusKode: 401), contains('HTTP 401'));
      expect(uraiJawabanCopilot('{}', statusKode: 429), contains('429'));
      expect(uraiJawabanCopilot('{}', statusKode: 503), contains('503'));
      expect(uraiJawabanCopilot('bukan json', statusKode: 200),
          contains('tidak bisa dibaca'));
      expect(uraiJawabanCopilot('{"error":{"message":"kuota habis"}}', statusKode: 200),
          contains('kuota habis'));
    });

    test('penjelasanDataDikirim menyebut data apa saja & jumlah karakter', () {
      final konteks = susunKonteksCopilot(
          const BahanKonteksCopilot(tagihanTerdekat: ['Listrik Rp 250.000']));
      final teks = penjelasanDataDikirim(konteks);
      expect(teks, contains('daftar tagihan terdekat'));
      expect(teks, contains('karakter'));
      expect(penjelasanDataDikirim(susunKonteksCopilot(const BahanKonteksCopilot())),
          'Belum ada data yang akan dikirim.');
    });

    test('ringkasCopilot: tanpa data pengguna menambah alasan', () {
      final r = ringkasCopilot(
        konfig: const KonfigCopilot(kunci: 'sk', izinDiberikan: true),
        bahan: const BahanKonteksCopilot(),
        adaJaringan: true,
      );
      expect(r.siap, isFalse);
      expect(r.alasan.any((a) => a.contains('Belum ada data pengguna')), isTrue);
      expect(r.dasar, contains('Belum ada data pengguna'));
    });

    test('repositori: izin disimpan & tanpa izin tidak ada yang dikirim',
        () async {
      final db = _db();
      addTearDown(db.close);
      final repo = CopilotRepository(db);
      await repo.simpanKonfig(kunci: 'sk-1234567890', model: 'deepseek-chat');
      final k = await repo.konfig();
      expect(k.model, 'deepseek-chat');
      expect(k.kunciTersamar.endsWith('7890'), isTrue);
      expect(k.kunciTersamar.contains('sk-123'), isFalse);
      expect(k.izinDiberikan, isFalse);

      final hasil = await repo.tanya(pertanyaan: 'Halo', adaJaringan: true);
      expect(hasil.berhasil, isFalse);
      expect(hasil.jawaban, '');
      expect(hasil.galat, contains('Izin belum diberikan'));
      expect(hasil.dataDikirim, isEmpty);
    });

    test('repositori: bahanKonteks memakai data pengguna sendiri', () async {
      final db = _db();
      addTearDown(db.close);
      // Tagihan belum lunas + dana persiapan + obat + perjalanan.
      await db.into(db.tagihan).insert(TagihanCompanion.insert(
            nama: 'Listrik',
            jumlahSen: Value(25000000),
            jatuhTempo: DateTime(2026, 9, 25),
          ));
      await DanaPersiapanRepository(db)
          .tambah(nama: 'Servis motor', targetSen: 10000000, tersediaSen: 2500000);
      final obatId = await db.into(db.obat).insert(
          ObatCompanion.insert(nama: 'Amlodipin', dosisTeks: Value('5 mg')));
      await db.into(db.jadwalObat).insert(
          JadwalObatCompanion.insert(obatId: obatId, jam: '07:00'));

      final bahan = await CopilotRepository(db).bahanKonteks();
      expect(bahan.tagihanTerdekat.single, contains('Listrik'));
      expect(bahan.tagihanTerdekat.single, contains('Rp 250.000'));
      expect(bahan.danaPersiapan.single, contains('Servis motor'));
      expect(bahan.obatHariIni.single, contains('Amlodipin'));
      expect(bahan.obatHariIni.single, contains('07:00'));
    });

    testWidgets('layar copilot: izin mati → alasan jelas, tombol tidak mengirim',
        (t) async {
      final db = _db();
      addTearDown(db.close);
      await _pasang(t, const CopilotScreen(adaJaringanOverride: false), db);
      await _tungguSampai(t,
          () => find.byKey(const Key('copilot_data')).evaluate().isNotEmpty);
      expect(find.byKey(const Key('copilot_izin')), findsOneWidget);

      final saklar =
          t.widget<SwitchListTile>(find.byKey(const Key('copilot_izin')));
      expect(saklar.value, isFalse);
      expect(find.textContaining('Izin belum diberikan'), findsWidgets);
      expect(find.textContaining('offline'), findsWidgets);
      expect(find.byKey(const Key('copilot_tanya')), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Skema v17 & mesin sinkron FR-150
  // ══════════════════════════════════════════════════════════════════════════
  group('skema v17 & sinkron', () {
    test('schemaVersion 17 dan 7 tabel batch 11 bisa ditulis', () async {
      final db = _db();
      addTearDown(db.close);
      expect(db.schemaVersion, 17);

      final danaId = await DanaPersiapanRepository(db)
          .tambah(nama: 'Servis', targetSen: 100, tersediaSen: 10);
      expect(danaId, greaterThan(0));
      await db.into(db.setoranDana).insert(SetoranDanaCompanion.insert(
            uid: const Value('stn_uji'),
            danaUid: 'dsp_uji',
            jumlahSen: 100,
            tanggal: DateTime(2026, 9, 22),
          ));
      await db.into(db.grupPatungan).insert(
          GrupPatunganCompanion.insert(nama: 'Grup', uid: const Value('grp_uji')));
      await db.into(db.anggotaPatungan).insert(AnggotaPatunganCompanion.insert(
          grupUid: 'grp_uji', nama: 'A', uid: const Value('agt_uji')));
      await db.into(db.belanjaPatungan).insert(BelanjaPatunganCompanion.insert(
            grupUid: 'grp_uji',
            judul: 'Kopi',
            tanggal: DateTime(2026, 9, 22),
            uid: const Value('blj_uji'),
          ));
      await db.into(db.bagianPatungan).insert(BagianPatunganCompanion.insert(
          belanjaUid: 'blj_uji', uid: const Value('bgn_uji')));
      await db.into(db.delegasiPengingat).insert(DelegasiPengingatCompanion.insert(
            judul: 'Listrik',
            waktu: DateTime(2026, 9, 22),
            uid: const Value('dlg_uji'),
          ));

      expect(await db.select(db.setoranDana).get(), hasLength(1));
      expect(await db.select(db.grupPatungan).get(), hasLength(1));
      expect(await db.select(db.anggotaPatungan).get(), hasLength(1));
      expect(await db.select(db.belanjaPatungan).get(), hasLength(1));
      expect(await db.select(db.bagianPatungan).get(), hasLength(1));
      expect(await db.select(db.delegasiPengingat).get(), hasLength(1));
    });

    test('mesin sinkron 150 memuat 7 jalur baru & tanpa jalur ganda', () async {
      final db = _db();
      addTearDown(db.close);
      final nama = daftarJalurSinkron(db).map((j) => j.nama).toList();
      for (final baru in const [
        'dana_persiapan',
        'setoran_dana',
        'grup_patungan',
        'anggota_patungan',
        'belanja_patungan',
        'bagian_patungan',
        'delegasi_pengingat',
      ]) {
        expect(nama, contains(baru));
      }
      expect(nama.toSet().length, nama.length, reason: 'tidak ada jalur ganda');
      expect(nama.contains('jadwal_obat'), isFalse,
          reason: 'FR-54 memakai tabel obat FR-106 apa adanya');
    });
  });
}
