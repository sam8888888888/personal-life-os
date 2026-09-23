/// Uji V2 — ibadah lanjutan (FR-91 Ramadan, FR-92 Puasa, FR-93 Quran,
/// FR-95 Dzikir, FR-100 Muhasabah).
///
/// Cakupan: lapisan data (repositori + fungsi hitung murni) dengan bukti angka,
/// keadaan kosong tiap layar ("Belum ada data"), bahasa aman PRD III-11, dan
/// lima tautan hub yang membuka layar yang benar.
///
/// Waktu uji dikunci 15 September 2026 lewat [pakaiSumberWaktu], jadi hasilnya
/// sama setiap hari. Basis data memakai drift memori.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_life_os/core/ibadah/kalender_hijriah.dart';
import 'package:personal_life_os/core/ibadah/kota_indonesia.dart';
import 'package:personal_life_os/core/ibadah/model_sholat.dart';
import 'package:personal_life_os/core/ibadah/penghitung_sholat.dart';
import 'package:personal_life_os/core/providers/app_providers.dart';
import 'package:personal_life_os/core/utils/waktu.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/ibadah_lanjutan_repository.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/features/ibadah/dzikir_screen.dart';
import 'package:personal_life_os/features/hari_ini/ibadah_hub_screen.dart';
import 'package:personal_life_os/features/ibadah/komponen_ibadah_lanjutan.dart';
import 'package:personal_life_os/features/ibadah/logika_ramadan.dart';
import 'package:personal_life_os/features/ibadah/muhasabah_screen.dart';
import 'package:personal_life_os/features/ibadah/pengaturan_ibadah.dart';
import 'package:personal_life_os/features/ibadah/puasa_screen.dart';
import 'package:personal_life_os/features/ibadah/quran_screen.dart';
import 'package:personal_life_os/features/ibadah/ramadan_screen.dart';
import 'package:personal_life_os/features/ibadah/setelan_ibadah_lanjutan.dart';

late AppDatabase db;
late IbadahLanjutanRepository repo;
late SetelanIbadahLanjutan setelan;

/// Waktu uji: 15 September 2026, 09.00 — tanggal sipil 2026-09-15.
final DateTime jamUji = DateTime(2026, 9, 15, 9, 0);
final DateTime hariUji = DateTime(2026, 9, 15);

/// Halaman berikutnya setelah [hariUji] (batas eksklusif rentang).
DateTime batasBesok() => hariUji.add(const Duration(days: 1));

/// Awali rentang [n] hari yang berakhir hari uji.
DateTime mulaiRentang(int n) => IbadahLanjutanRepository.mulaiRentang(hariUji, n);

/// Ukuran layar ponsel yang dipakai seluruh uji widget.
const Size layarPonsel = Size(420, 900);

/// Pasang layar dengan penyimpanan uji.
Future<void> tampilkan(WidgetTester penguji, Widget layar) async {
  await penguji.binding.setSurfaceSize(layarPonsel);
  await penguji.pumpWidget(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      locale: const Locale('id'),
      supportedLocales: const <Locale>[Locale('id'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: layar,
    ),
  ));
  await penguji.pump();
  await penguji.pump(const Duration(milliseconds: 600));
}

/// Ketuk widget berkunci [kunci], gulir dulu bila belum terlihat.
Future<void> ketuk(WidgetTester penguji, Key kunci) async {
  final Finder cari = find.byKey(kunci);
  if (cari.evaluate().isEmpty) {
    await penguji.drag(find.byType(ListView).first, const Offset(0, -400));
    await penguji.pump(const Duration(milliseconds: 200));
  }
  await penguji.ensureVisible(cari);
  await penguji.pump(const Duration(milliseconds: 100));
  await penguji.tap(cari);
  await penguji.pump(const Duration(milliseconds: 800));
}

/// Gulir daftar utama ke bawah (isi di luar layar belum dibangun Flutter).
Future<void> gulirBawah(WidgetTester penguji, {int kali = 1}) async {
  for (int i = 0; i < kali; i++) {
    await penguji.drag(find.byType(ListView).first, const Offset(0, -500));
    await penguji.pump(const Duration(milliseconds: 250));
  }
}

/// Bandingkan tanggal sipil saja (abaikan penanda UTC/lokal DateTime).
void harapkanTanggalSama(DateTime? dapat, DateTime harap) {
  expect(dapat, isNotNull);
  expect(<int>[dapat!.year, dapat.month, dapat.day],
      <int>[harap.year, harap.month, harap.day]);
}

/// Teks yang sedang tampil pada widget berkunci [kunci].
String teksDi(WidgetTester penguji, Key kunci) =>
    penguji.widget<Text>(find.byKey(kunci)).data ?? '';

/// Semua teks yang tampil di layar (dipakai uji bahasa aman).
List<String> semuaTeksDiLayar(WidgetTester penguji) => penguji
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .toList();

void main() {
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = IbadahLanjutanRepository(db, jamSekarang: () => jamUji);
    setelan = SetelanIbadahLanjutan(
        PengaturanIbadah.dariRepository(PengaturanRepository(db)).simpanan);
    pakaiSumberWaktu(() => jamUji);
  });

  tearDown(() async {
    pakaiWaktuAsli();
    await db.close();
  });

  // -------------------------------------------------------------------------
  // FR-92 — Puasa
  // -------------------------------------------------------------------------

  test('D1 simpanPuasa: satu (tanggal, jenis) satu baris, simpan ulang memperbarui',
      () async {
    await repo.simpanPuasa(
        tanggal: hariUji, jenis: JenisPuasa.ramadan, status: StatusPuasa.puasa);
    await repo.simpanPuasa(
        tanggal: hariUji,
        jenis: JenisPuasa.ramadan,
        status: StatusPuasa.tidak,
        catatan: 'sakit');
    final List<LogPuasaData> baris = await repo.semuaPuasa();
    expect(baris.length, 1, reason: 'simpan ulang tidak boleh menggandakan');
    expect(baris.single.status, StatusPuasa.tidak.nilaiDb);
    expect(baris.single.catatan, 'sakit');

    await repo.simpanPuasa(
        tanggal: hariUji, jenis: JenisPuasa.sunnah, status: StatusPuasa.puasa);
    expect((await repo.semuaPuasa()).length, 2,
        reason: 'jenis berbeda tetap tersimpan terpisah');
    expect(baris.single.dicatatPada, jamUji);
  });

  test('D2 puasaBulan + hitungRingkasanPuasa: hanya bulan berjalan, angka dari baris',
      () async {
    await repo.simpanPuasa(
        tanggal: hariUji, jenis: JenisPuasa.ramadan, status: StatusPuasa.puasa);
    await repo.simpanPuasa(
        tanggal: DateTime(2026, 9, 14),
        jenis: JenisPuasa.seninKamis,
        status: StatusPuasa.tidak);
    await repo.simpanPuasa(
        tanggal: DateTime(2026, 9, 13),
        jenis: JenisPuasa.qadha,
        status: StatusPuasa.puasa);
    await repo.simpanPuasa(
        tanggal: DateTime(2026, 8, 31),
        jenis: JenisPuasa.ramadan,
        status: StatusPuasa.puasa);

    final List<LogPuasaData> bulan = await repo.puasaBulan(hariUji);
    expect(bulan.length, 3, reason: 'baris 31 Agustus tidak ikut bulan ini');
    final RingkasanPuasa ringkas = hitungRingkasanPuasa(bulan);
    expect(ringkas.puasa, 2);
    expect(ringkas.tidak, 1);
    expect(ringkas.total, 3);
    expect(ringkas.kosong, isFalse);
    expect(hitungRingkasanPuasa(const <LogPuasaData>[]).kosong, isTrue);
  });

  test('D3 hitungQadha: hitungan apa adanya dari catatan sendiri', () async {
    for (int i = 0; i < 3; i++) {
      await repo.simpanPuasa(
          tanggal: DateTime(2026, 3, 1 + i),
          jenis: JenisPuasa.ramadan,
          status: StatusPuasa.tidak);
    }
    await repo.simpanPuasa(
        tanggal: DateTime(2026, 9, 1),
        jenis: JenisPuasa.qadha,
        status: StatusPuasa.puasa);
    await repo.simpanPuasa(
        tanggal: DateTime(2026, 9, 2),
        jenis: JenisPuasa.qadha,
        status: StatusPuasa.tidak);

    final HitungQadha q = hitungQadha(await repo.semuaPuasa());
    expect(q.ramadhanTanpaPuasa, 3);
    expect(q.qadhaTercatat, 1, reason: 'qadha berstatus "tidak" tidak dihitung');
    expect(q.selisih, 2);
    expect(q.adaCatatan, isTrue);
    expect(hitungQadha(const <LogPuasaData>[]).adaCatatan, isFalse);
  });

  // -------------------------------------------------------------------------
  // FR-93 — Quran
  // -------------------------------------------------------------------------

  test('D4 quran: satuan berbeda tidak dijumlahkan; total harian per satuan',
      () async {
    await repo.tambahQuran(
        tanggal: hariUji,
        jenis: JenisQuran.baca,
        jumlah: 3,
        satuan: SatuanQuran.halaman);
    await repo.tambahQuran(
        tanggal: hariUji,
        jenis: JenisQuran.dengar,
        jumlah: 2,
        satuan: SatuanQuran.halaman);
    await repo.tambahQuran(
        tanggal: hariUji,
        jenis: JenisQuran.hafal,
        jumlah: 5,
        satuan: SatuanQuran.ayat);

    final List<LogQuranData> baris =
        await repo.quranRentang(hariUji, batasBesok());
    final Map<SatuanQuran, double> perSatuan = totalQuranPerSatuan(baris);
    expect(perSatuan[SatuanQuran.halaman], 5);
    expect(perSatuan[SatuanQuran.ayat], 5);
    expect(perSatuan.length, 2,
        reason: 'halaman dan ayat tidak boleh digabung jadi satu angka');
    expect(totalQuranHarian(baris, SatuanQuran.halaman)[hariUji], 5);
    expect(totalQuranHarian(baris, SatuanQuran.menit)[hariUji], isNull);
    expect(totalQuranPerJenis(baris, SatuanQuran.halaman)[JenisQuran.baca], 3);
    expect(await repo.jumlahQuranHari(hariUji), 3);
  });

  test('D5 quran: rentang 30 hari memotong baris lama', () async {
    await repo.tambahQuran(
        tanggal: hariUji, jenis: JenisQuran.baca, jumlah: 1);
    await repo.tambahQuran(
        tanggal: hariUji.subtract(const Duration(days: 40)),
        jenis: JenisQuran.baca,
        jumlah: 9);

    final List<LogQuranData> baris = await repo.quranRentang(mulaiRentang(30), batasBesok());
    expect(baris.length, 1);
    expect(totalQuranPerSatuan(baris)[SatuanQuran.halaman], 1);
  });

  // -------------------------------------------------------------------------
  // FR-95 — Dzikir
  // -------------------------------------------------------------------------

  test('D6 dzikir: hitung berulang satu baris, selesai saat target, total harian',
      () async {
    await repo.catatDzikir(
        tanggal: hariUji,
        jenis: JenisDzikir.pagi,
        nama: 'Subhanallah',
        target: 3,
        tercatat: 1);
    await repo.catatDzikir(
        tanggal: hariUji,
        jenis: JenisDzikir.pagi,
        nama: 'Subhanallah',
        target: 3,
        tercatat: 2);
    LogDzikirData? sesi =
        await repo.dzikirSatu(hariUji, JenisDzikir.pagi, 'Subhanallah');
    expect(sesi!.tercatat, 2);
    expect(sesi.selesaiPada, isNull);

    await repo.catatDzikir(
        tanggal: hariUji,
        jenis: JenisDzikir.pagi,
        nama: 'Subhanallah',
        target: 3,
        tercatat: 3);
    sesi = await repo.dzikirSatu(hariUji, JenisDzikir.pagi, 'Subhanallah');
    expect(sesi!.tercatat, 3);
    expect(sesi.selesaiPada, isNotNull);

    await repo.catatDzikir(
        tanggal: hariUji,
        jenis: JenisDzikir.petang,
        nama: 'Alhamdulillah',
        target: 33,
        tercatat: 10);
    final List<LogDzikirData> rentang =
        await repo.dzikirRentang(mulaiRentang(7), batasBesok());
    expect(rentang.length, 2, reason: 'nama berbeda = sesi berbeda');
    expect(totalDzikirHarian(rentang)[hariUji], 13);
  });

  // -------------------------------------------------------------------------
  // FR-100 — Muhasabah
  // -------------------------------------------------------------------------

  test('D7 muhasabah: satu baris per tanggal, "belum diisi" tetap kosong, rentang 7 hari',
      () async {
    await repo.simpanRefleksi(
        hariUji,
        const NilaiRefleksi(belajar: true, bersyukur: false),
        catatan: '   ');
    await repo.simpanRefleksi(
        hariUji,
        const NilaiRefleksi(belajar: true, bersyukur: true, membantuOrang: false));

    final RefleksiMuhasabahData? baris = await repo.refleksiTanggal(hariUji);
    expect(baris, isNotNull);
    expect(baris!.belajar, isTrue);
    expect(baris.bersyukur, isTrue);
    expect(baris.membantuOrang, isFalse);
    expect(baris.sholatTerjaga, isNull, reason: 'butir belum diisi tetap null');
    expect(baris.catatan, isNull, reason: 'teks kosong tidak disimpan sebagai ""');
    expect(jumlahButirTerisi(baris), 3);

    expect(NilaiRefleksi.dariBaris(null).jumlahTerisi, 0);
    expect(NilaiRefleksi.kosong.jumlahTerisi, 0);
    expect(
        NilaiRefleksi.kosong
            .dengan(ButirRefleksi.belajar, true)
            .dengan(ButirRefleksi.belajar, null)
            .jumlahTerisi,
        0);

    await repo.simpanRefleksi(
        DateTime(2026, 9, 1), const NilaiRefleksi(bersyukur: true));
    final List<RefleksiMuhasabahData> rentang =
        await repo.refleksiRentang(mulaiRentang(7), batasBesok());
    expect(rentang.length, 1);
    expect(rentang.single.tanggal, hariUji);
  });

  // -------------------------------------------------------------------------
  // FR-91 — hitungan Ramadan (fungsi murni, tanpa basis data)
  // -------------------------------------------------------------------------

  test('L1 hitungRamadan: tepat 1 Ramadan, hari ke-6, dan 1 Syawal', () {
    final DateTime awal1445 =
        masehiDariHijriah(const TanggalHijriah(1445, 9, 1))!;
    final DateTime syawal1445 =
        masehiDariHijriah(const TanggalHijriah(1445, 10, 1))!;
    expect(awal1445.year, 2024);
    expect(awal1445.month, 3);
    expect(awal1445.day, 11,
        reason: 'acuan Umm al-Qura: 1 Ramadan 1445 = 11 Maret 2024');
    expect(syawal1445.day, 10,
        reason: 'acuan Umm al-Qura: 1 Syawal 1445 = 10 April 2024');

    final RencanaRamadan hari1 = hitungRamadan(awal1445);
    expect(hari1.hariMenujuRamadan, 0);
    expect(hari1.sedangRamadan, isTrue);
    expect(hari1.hariKeRamadan, 1);
    harapkanTanggalSama(hari1.tanggalAwalRamadan, awal1445);
    expect(hari1.tahunHijriahRamadan, 1445);

    final RencanaRamadan hari6 = hitungRamadan(awal1445.add(const Duration(days: 5)));
    expect(hari6.hariKeRamadan, 6);
    expect(hari6.jumlahHariRamadan, isNotNull);
    expect(hari6.sisaHariPuasa, hari6.jumlahHariRamadan! - 5);

    final DateTime enamHariSebelum = awal1445.subtract(const Duration(days: 6));
    final RencanaRamadan sebelum = hitungRamadan(enamHariSebelum);
    expect(sebelum.hariMenujuRamadan, 6);
    expect(sebelum.sedangRamadan, isFalse);
    expect(sebelum.hariMenujuSyawal,
        selisihHari(enamHariSebelum, syawal1445),
        reason: '6 hari sebelum Ramadan + panjang Ramadan');

    final RencanaRamadan idulFitri = hitungRamadan(syawal1445);
    expect(idulFitri.hariIdulFitri, isTrue);
    harapkanTanggalSama(idulFitri.tanggalIdulFitri, syawal1445);
    expect(idulFitri.sedangRamadan, isFalse, reason: '1 Syawal sudah di luar Ramadan');
  });

  test('L2 hitungImsak & waktuSahurIftar: imsak = Subuh − N menit, iftar = maghrib',
      () {
    final KotaSholat jakarta =
        daftarKotaIndonesia.firstWhere((KotaSholat k) => k.nama == 'Jakarta');
    final JadwalSholatHarian jadwal =
        hitungJadwal(kota: jakarta, tanggal: hariUji);
    final WaktuSahurIftar w = waktuSahurIftar(jadwal, imsakMenit: 10);

    expect(imsakMenitBawaan, 10);
    expect(w.namaKota, 'Jakarta');
    expect(w.subuh, jadwal.waktuLokal(WaktuSholat.subuh));
    expect(w.maghrib, jadwal.waktuLokal(WaktuSholat.maghrib));
    expect(w.imsak, w.subuh.subtract(const Duration(minutes: 10)));
    expect(hitungImsak(w.subuh, 0), w.subuh);
    expect(hitungImsak(w.subuh, 25), w.subuh.subtract(const Duration(minutes: 25)));

    // Angka acuan nyata (Jakarta, metode Kemenag, 15 Sep 2026).
    expect(teksJam(w.subuh), '04:29');
    expect(teksJam(w.imsak), '04:19');
    expect(teksJam(w.maghrib), '17:50');
  });

  // -------------------------------------------------------------------------
  // Layar — keadaan kosong, angka, dan tautan
  // -------------------------------------------------------------------------

  testWidgets('W1 layar Puasa: keadaan kosong, lalu simpan menambah catatan',
      (WidgetTester penguji) async {
    await tampilkan(penguji, const PuasaScreen());
    expect(find.text(teksBelumAdaData), findsWidgets,
        reason: 'keadaan kosong memakai kalimat baku, bukan angka 0');

    await ketuk(penguji, const Key('simpan_puasa'));
    await penguji.pump(const Duration(milliseconds: 600));
    expect(find.text('Catatan tersimpan di perangkat Anda'), findsOneWidget);
    await gulirBawah(penguji);
    expect(find.text('1 hari'), findsWidgets);

    final List<LogPuasaData> baris = await repo.semuaPuasa();
    expect(baris.length, 1);
    expect(baris.single.jenis, JenisPuasa.ramadan.nilaiDb);
    expect(baris.single.status, StatusPuasa.puasa.nilaiDb);
    expect(IbadahLanjutanRepository.hari(baris.single.tanggal), hariUji);
  });

  testWidgets('W2 layar Puasa: qadha dihitung dari catatan yang ada',
      (WidgetTester penguji) async {
    for (int i = 0; i < 3; i++) {
      await repo.simpanPuasa(
          tanggal: DateTime(2026, 3, 1 + i),
          jenis: JenisPuasa.ramadan,
          status: StatusPuasa.tidak);
    }
    await repo.simpanPuasa(
        tanggal: DateTime(2026, 9, 2),
        jenis: JenisPuasa.qadha,
        status: StatusPuasa.puasa);

    await tampilkan(penguji, const PuasaScreen());
    await gulirBawah(penguji, kali: 2);
    expect(find.text('3 hari'), findsOneWidget);
    expect(find.text('2 hari'), findsOneWidget, reason: 'selisih 3 − 1');
    expect(find.text('1 hari'), findsWidgets);
  });

  testWidgets('W3 layar Quran: keadaan kosong & jumlah kosong tidak disimpan',
      (WidgetTester penguji) async {
    await tampilkan(penguji, const QuranScreen());

    await ketuk(penguji, const Key('simpan_quran'));
    await penguji.pump(const Duration(milliseconds: 400));
    expect(find.text('Isi jumlah lebih dari 0 supaya catatan bermakna'),
        findsOneWidget);
    expect(await repo.quranRentang(hariUji, batasBesok()), isEmpty,
        reason: 'jumlah kosong tidak boleh membuat catatan');

    await gulirBawah(penguji);
    expect(find.text('0 dari 1'), findsOneWidget,
        reason: 'target bawaan 1 halaman dibandingkan dengan catatan hari ini');
    await gulirBawah(penguji, kali: 3);
    expect(find.text(teksBelumAdaData), findsWidgets);
  });

  testWidgets('W4 layar Quran: mencatat lewat layar tersimpan & tampil di progres',
      (WidgetTester penguji) async {
    await tampilkan(penguji, const QuranScreen());
    await penguji.enterText(find.byKey(const Key('jumlah_quran')), '2');
    await penguji.pump(const Duration(milliseconds: 100));
    await ketuk(penguji, const Key('simpan_quran'));
    await penguji.pump(const Duration(milliseconds: 600));

    expect(find.text('Catatan Quran tersimpan di perangkat Anda'), findsOneWidget);
    await gulirBawah(penguji);
    expect(find.text('2 dari 1'), findsOneWidget);

    final List<LogQuranData> baris = await repo.quranRentang(hariUji, batasBesok());
    expect(baris.length, 1);
    expect(baris.single.jumlah, 2);
    expect(baris.single.satuan, SatuanQuran.halaman.nilaiDb);
    expect(baris.single.jenis, JenisQuran.baca.nilaiDb);
  });

  testWidgets('W5 layar Dzikir: hitung menambah, ulang mengembalikan ke 0',
      (WidgetTester penguji) async {
    await tampilkan(penguji, const DzikirScreen());
    await gulirBawah(penguji);
    expect(find.text(teksBelumAdaData), findsWidgets,
        reason: 'riwayat hari ini masih kosong');

    for (int i = 0; i < 3; i++) {
      await ketuk(penguji, const Key('hitung_dzikir'));
    }
    expect(teksDi(penguji, const Key('angka_dzikir')), '3');
    List<LogDzikirData> baris =
        await repo.dzikirRentang(mulaiRentang(7), batasBesok());
    expect(baris.length, 1, reason: 'tiga tekanan tidak menambah tiga baris');
    expect(baris.single.tercatat, 3);

    await ketuk(penguji, const Key('ulang_dzikir'));
    expect(teksDi(penguji, const Key('angka_dzikir')), '0');
    baris = await repo.dzikirRentang(mulaiRentang(7), batasBesok());
    expect(baris.single.tercatat, 0);
    expect(baris.single.selesaiPada, isNull);
  });

  testWidgets('W6 layar Muhasabah: "Belum diisi" berbeda dari "Tidak" & tersimpan apa adanya',
      (WidgetTester penguji) async {
    await tampilkan(penguji, const MuhasabahScreen());
    expect(find.text('Belum diisi'), findsNWidgets(6),
        reason: 'enam butir refleksi belum diisi — bukan dinilai "tidak"');

    await ketuk(penguji, const Key('butir_sholatTerjaga'));
    expect(find.text('Tidak'), findsOneWidget);
    await ketuk(penguji, const Key('butir_sholatTerjaga'));
    expect(find.text('Ya'), findsOneWidget);

    await ketuk(penguji, const Key('simpan_muhasabah'));
    await penguji.pump(const Duration(milliseconds: 600));
    expect(find.text('Refleksi tersimpan di perangkat Anda'), findsOneWidget);

    final RefleksiMuhasabahData? baris = await repo.refleksiTanggal(hariUji);
    expect(baris, isNotNull);
    expect(baris!.sholatTerjaga, isTrue);
    expect(baris.bersyukur, isNull);
    expect(jumlahButirTerisi(baris), 1);

    await gulirBawah(penguji, kali: 2);
    expect(find.text(teksBelumAdaData), findsNWidgets(6),
        reason: 'enam hari lain belum punya catatan, hari ini sudah');
    expect(find.text('1 dari 6 butir terisi'), findsOneWidget);
  });

  testWidgets('W7 layar Muhasabah: rangkuman 7 hari memakai hitungan butir terisi',
      (WidgetTester penguji) async {
    await repo.simpanRefleksi(
        hariUji, const NilaiRefleksi(belajar: true, bersyukur: false));
    await repo.simpanRefleksi(
        hariUji.subtract(const Duration(days: 2)),
        const NilaiRefleksi(
            belajar: true, bersyukur: true, membantuOrang: true),
        catatan: 'ingin lebih tenang');

    await tampilkan(penguji, const MuhasabahScreen());
    await gulirBawah(penguji, kali: 2);
    expect(find.text('2 dari 6 butir terisi'), findsOneWidget);
    expect(find.text('3 dari 6 butir terisi'), findsOneWidget);
    expect(find.text('ingin lebih tenang'), findsOneWidget);
  });

  testWidgets('W8 layar Ramadan: kalimat jujur, imsak, dan saklar bawaan mati',
      (WidgetTester penguji) async {
    await tampilkan(penguji, const RamadanScreen());

    expect(find.textContaining('Perhitungan, bukan jadwal resmi'), findsWidgets);
    expect(
        find.textContaining(
            'Awal bulan Hijriah bisa berbeda dari penetapan pemerintah'),
        findsWidgets,
        reason: 'batas kejujuran wajib tampil');

    expect(find.text('146 hari menuju 1 Ramadan 1448 H'), findsOneWidget,
        reason: '15 Sep 2026 + 146 hari = 8 Feb 2027 (1 Ramadan 1448)');
    expect(find.text('04:29'), findsWidgets, reason: 'Subuh Jakarta');
    expect(find.text('04:19'), findsWidgets, reason: 'imsak = Subuh − 10 menit');
    expect(find.text('17:50'), findsWidgets, reason: 'maghrib = waktu iftar');

    await gulirBawah(penguji, kali: 2);
    expect(find.text(teksBelumAdaData), findsWidgets,
        reason: 'belum ada catatan puasa bulan ini');
    expect(
        penguji
            .widget<SwitchListTile>(find.byKey(const Key('saklar_sahur')))
            .value,
        isFalse);
    expect(
        penguji
            .widget<SwitchListTile>(find.byKey(const Key('saklar_iftar')))
            .value,
        isFalse);
  });

  testWidgets('W9 layar Ramadan: saklar tersimpan & ringkasan puasa dari data',
      (WidgetTester penguji) async {
    await repo.simpanPuasa(
        tanggal: hariUji, jenis: JenisPuasa.ramadan, status: StatusPuasa.puasa);
    await repo.simpanPuasa(
        tanggal: DateTime(2026, 9, 14),
        jenis: JenisPuasa.seninKamis,
        status: StatusPuasa.tidak);

    await tampilkan(penguji, const RamadanScreen());
    await gulirBawah(penguji, kali: 3);
    expect(find.text('1 hari'), findsNWidgets(2),
        reason: 'satu catatan puasa dan satu catatan tidak puasa');

    await ketuk(penguji, const Key('saklar_sahur'));
    expect(
        penguji
            .widget<SwitchListTile>(find.byKey(const Key('saklar_sahur')))
            .value,
        isTrue);
    expect(await setelan.pengingatSahurAktif(), isTrue,
        reason: 'pilihan tersimpan, bukan hanya berubah di layar');
    expect(await setelan.pengingatIftarAktif(), isFalse);
  });

  testWidgets('W10 hub ibadah: lima tautan V2 membuka layar yang benar',
      (WidgetTester penguji) async {
    final Map<String, String> tautan = <String, String>{
      'buka_ramadan': 'Ramadan',
      'buka_puasa': 'Puasa',
      'buka_quran': 'Quran',
      'buka_dzikir': 'Dzikir',
      'buka_muhasabah': 'Muhasabah',
    };
    final GoRouter router = GoRouter(
      initialLocation: '/ibadah',
      routes: <RouteBase>[
        GoRoute(path: '/ibadah', builder: (_, _) => const IbadahHubScreen()),
        GoRoute(path: '/ibadah/ramadan', builder: (_, _) => const RamadanScreen()),
        GoRoute(path: '/ibadah/puasa', builder: (_, _) => const PuasaScreen()),
        GoRoute(path: '/ibadah/quran', builder: (_, _) => const QuranScreen()),
        GoRoute(path: '/ibadah/dzikir', builder: (_, _) => const DzikirScreen()),
        GoRoute(
            path: '/ibadah/muhasabah', builder: (_, _) => const MuhasabahScreen()),
      ],
    );
    await penguji.binding.setSurfaceSize(layarPonsel);
    await penguji.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await penguji.pump();
    await penguji.pump(const Duration(milliseconds: 400));

    for (final MapEntry<String, String> e in tautan.entries) {
      expect(find.byKey(Key(e.key)), findsOneWidget, reason: 'kunci ${e.key}');
    }
    for (final MapEntry<String, String> e in tautan.entries) {
      await ketuk(penguji, Key(e.key));
      expect(find.widgetWithText(AppBar, e.value), findsOneWidget,
          reason: '${e.key} harus membuka layar ${e.value}');
      router.go('/ibadah');
      await penguji.pump();
      await penguji.pump(const Duration(milliseconds: 400));
    }
  });

  testWidgets('W11 bahasa aman III-11 di lima layar baru + hub',
      (WidgetTester penguji) async {
    const List<String> kataTerlarang = <String>[
      'kamu',
      'gagal',
      'skor',
      'berdosa',
      'malas',
      'rajin',
      'wajib anda',
      'belum sholat',
      'diagnosis',
    ];
    final List<Widget> layar = <Widget>[
      const IbadahHubScreen(),
      const RamadanScreen(),
      const PuasaScreen(),
      const QuranScreen(),
      const DzikirScreen(),
      const MuhasabahScreen(),
    ];
    for (final Widget l in layar) {
      await tampilkan(penguji, l);
      final List<String> kumpulan = semuaTeksDiLayar(penguji);
      await gulirBawah(penguji, kali: 4);
      kumpulan.addAll(semuaTeksDiLayar(penguji));
      final String teks = kumpulan.join(' | ').toLowerCase();
      for (final String kata in kataTerlarang) {
        expect(teks.contains(kata), isFalse,
            reason: 'layar $l memuat kata terlarang "$kata"');
      }
    }
  });
}
