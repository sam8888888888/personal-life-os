/// Uji FR-63 (ringkasan pagi) & FR-87 (pengingat waktu sholat) — bagian yang
/// diserahkan bersama fondasi notifikasi.
///
/// Yang dibuktikan di sini:
///  - adaptor [SumberPengingatIbadah] benar-benar menyusun pengingat dari
///    setelan pengguna (bukan angka bawaan di kode),
///  - pengingat tagihan TIDAK ikut dobel,
///  - ID memakai rentang cadangan, isi notifikasi menyebut hasil sebagai
///    "perhitungan", dan tidak memakai kata yang menghakimi (PRD III-11),
///  - layar Pengingat Ibadah menyimpan pilihan ke penyimpanan setelan.
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/ibadah/model_sholat.dart';
import 'package:personal_life_os/core/ibadah/penghitung_sholat.dart';
import 'package:personal_life_os/core/notifikasi/kerja_latar.dart';
import 'package:personal_life_os/core/notifikasi/model_pengingat.dart';
import 'package:personal_life_os/core/notifikasi/perencana_pengingat.dart';
import 'package:personal_life_os/core/notifikasi/sumber_pengingat_tambahan.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/features/ibadah/pengaturan_ibadah.dart';
import 'package:personal_life_os/features/ibadah/pengingat_ibadah_screen.dart';
import 'package:personal_life_os/features/ibadah/sumber_pengingat_ibadah.dart';

/// Tanggal uji tetap supaya hasil hitung dapat dibandingkan dengan hitungan
/// resmi Kemenag (lihat LAPORAN_V1_5_IBADAH.md).
final DateTime sekarangUji = DateTime(2026, 9, 13, 3, 0);

/// Penyimpanan setelan di memori — cepat dan tidak butuh basis data.
class SetelanUji implements PenyimpananSetelan {
  SetelanUji([Map<String, String>? awal]) : isi = <String, String>{...?awal};

  final Map<String, String> isi;

  @override
  Future<String?> baca(String kunci) async => isi[kunci];

  @override
  Future<void> simpan(String kunci, String nilai) async => isi[kunci] = nilai;

  @override
  Future<String> bacaTeks(String kunci, String bawaan) async {
    final String? v = isi[kunci]?.trim();
    return (v == null || v.isEmpty) ? bawaan : v;
  }

  @override
  Future<int> bacaAngka(String kunci, int bawaan) async =>
      int.tryParse(isi[kunci]?.trim() ?? '') ?? bawaan;

  @override
  Future<bool> bacaSaklar(String kunci, {bool bawaan = false}) async {
    final String v = isi[kunci]?.trim().toLowerCase() ?? '';
    if (v.isEmpty) return bawaan;
    return v == 'true' || v == '1' || v == 'ya';
  }
}

/// Kata yang dilarang PRD III-11 pada teks notifikasi.
const List<String> kataTerlarang = <String>[
  'skor', 'nilai', 'peringkat', 'berdosa', 'rajin', 'malas', 'kamu',
  'belum sholat', 'wajib anda',
];

void main() {
  late AppDatabase db;
  late PengaturanIbadah setelan;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    setelan = PengaturanIbadah.dariRepository(PengaturanRepository(db));
  });

  tearDown(() async => db.close());

  /// Adaptor yang memakai basis data uji (tidak menutupnya saat selesai).
  SumberPengingatIbadah adaptor() => SumberPengingatIbadah(
        pembukaBasisData: () => db,
        tutupBasisData: false,
      );

  Future<List<Pengingat>> ambil(DateTime kini) =>
      adaptor().pengingatTambahan(kini);

  group('setelan ibadah — bawaan & penyimpanan', () {
    test('bawaan: ringkasan pagi AKTIF 06:00, pengingat sholat MATI', () async {
      expect(await setelan.briefingAktif(), isTrue);
      expect(await setelan.jamBriefing(), '06:00');
      expect(await setelan.pengingatSholatAktif(), isFalse);
      expect((await setelan.kota()).nama, 'Jakarta');
      expect(await setelan.metode(), MetodeHitungSholat.kemenag);
      expect(await setelan.asharHanafi(), isFalse);
      expect(await setelan.ihtiyatiMenit(), 0);
      for (final WaktuSholat w in WaktuSholat.wajibSaja) {
        expect(await setelan.mode(w), ModePengingatSholat.tepat);
        expect(await setelan.geser(w), 0);
      }
    });

    test('jam tidak sah kembali ke bawaan, koreksi dibatasi rentang', () async {
      await setelan.simpanJamBriefing('25:99');
      expect(await setelan.jamBriefing(), jamBriefingBawaan);
      await setelan.simpanJamBriefing('07:30');
      expect(await setelan.jamBriefing(), '07:30');

      await setelan.simpanIhtiyatiMenit(99);
      expect(await setelan.ihtiyatiMenit(), ihtiyatiMaksimal);
      await setelan.simpanIhtiyatiMenit(-4);
      expect(await setelan.ihtiyatiMenit(), 0);

      await setelan.simpanGeser(WaktuSholat.subuh, 999);
      expect(await setelan.geser(WaktuSholat.subuh), geserMaksimal);
      await setelan.simpanGeser(WaktuSholat.subuh, -1);
      expect(await setelan.geser(WaktuSholat.subuh), 0);
    });

    test('jamSah menolak bentuk yang salah', () {
      expect(jamSah('06:00'), isTrue);
      expect(jamSah('6:5'), isTrue);
      expect(jamSah('24:00'), isFalse);
      expect(jamSah('06:60'), isFalse);
      expect(jamSah('0600'), isFalse);
      expect(jamSah(null), isFalse);
      expect(jamSah(''), isFalse);
    });

    test('kota tidak dikenal kembali ke bawaan, bukan galat', () async {
      await setelan.simpanan.simpan(kunciKotaSholat, 'Kota Ngawur');
      expect((await setelan.kota()).nama, kotaSholatBawaan);
    });
  });

  group('adaptor pengingat ibadah (FR-63 & FR-87)', () {
    test('kedua saklar mati: tidak ada pengingat tambahan sama sekali',
        () async {
      await setelan.simpanBriefingAktif(false);
      expect(await setelan.pengingatSholatAktif(), isFalse);
      expect(await ambil(sekarangUji), isEmpty);
    });

    test('FR-63: 7 ringkasan pagi pada jam pilihan, kanal briefing', () async {
      await setelan.simpanJamBriefing('07:30');
      final List<Pengingat> daftar = await ambil(sekarangUji);
      expect(daftar.length, hariBriefingKeDepan);
      for (int i = 0; i < daftar.length; i++) {
        expect(daftar[i].id, idBriefingPagiKe(i));
        expect(daftar[i].kanal, KanalNotifikasi.briefing);
        expect(daftar[i].waktu.hour, 7);
        expect(daftar[i].waktu.minute, 30);
        expect(daftar[i].waktu.day, sekarangUji.day + i);
      }
    });

    test('FR-63: isi ringkasan memakai jumlah & total tagihan yang nyata',
        () async {
      final DateTime jatuhTempo = DateTime(2026, 9, 15);
      await db.into(db.tagihan).insert(TagihanCompanion.insert(
            nama: 'Listrik',
            jumlahSen: const Value(25000000),
            jatuhTempo: jatuhTempo,
            kategoriId: const Value(null),
          ));
      final List<Pengingat> daftar = await ambil(sekarangUji);
      final Pengingat hari1 = daftar.firstWhere((p) => p.id == idBriefingPagiKe(0));
      expect(hari1.isi, contains('1 tagihan'));
      expect(hari1.isi, contains('Rp 250.000'));
      // Hanya ringkasan; tidak ada pengingat tagihan yang ikut (tidak dobel).
      expect(daftar.where((p) => p.kanal == KanalNotifikasi.tagihan), isEmpty);
      expect(daftar.where((p) => p.kanal == KanalNotifikasi.ringkasan), isEmpty);
    });

    test('FR-87: 5 waktu × 7 hari, kanal sholat, ID rentang cadangan',
        () async {
      await setelan.simpanPengingatSholatAktif(true);
      await setelan.simpanBriefingAktif(false);
      final List<Pengingat> daftar = await ambil(sekarangUji);
      expect(daftar.length, WaktuSholat.wajibSaja.length * hariSholatKeDepan);
      expect(daftar.every((p) => p.kanal == KanalNotifikasi.sholat), isTrue);
      expect(daftar.first.id, greaterThanOrEqualTo(batasIdKhusus));
      expect(daftar.first.id, idSholatKe(0));
      expect(daftar.last.id, idSholatKe(daftar.length - 1));
      // Waktu wajib saja: tidak ada Syuruq.
      expect(daftar.any((p) => p.judul.contains('Syuruq')), isFalse);
      // Satu notifikasi per waktu per hari — tidak ada yang dobel.
      expect(daftar.map((p) => p.id).toSet().length, daftar.length);
    });

    test('FR-87: mode Sesudah + geser 10 memakai jadwal kota yang dipilih',
        () async {
      await setelan.simpanPengingatSholatAktif(true);
      await setelan.simpanBriefingAktif(false);
      await setelan.simpanMode(WaktuSholat.subuh, ModePengingatSholat.sesudah);
      await setelan.simpanGeser(WaktuSholat.subuh, 10);

      final List<Pengingat> daftar = await ambil(sekarangUji);
      final Pengingat subuh = daftar.firstWhere(
          (p) => p.kanal == KanalNotifikasi.sholat && p.judul.contains('Subuh'));
      // Jakarta, Kemenag, 13 Sep 2026: Subuh 04:30 (hitung aplikasi).
      final int menitSubuh = subuh.waktu.hour * 60 + subuh.waktu.minute;
      expect((menitSubuh - (4 * 60 + 40)).abs(), lessThanOrEqualTo(2));
      expect(subuh.judul, 'Sudah masuk waktu Subuh');
      expect(subuh.isi, contains('hitungan aplikasi'));
      expect(subuh.isi, contains('04:30'));
    });

    test('FR-87: mode Sebelum memakai geser, mode Tepat tanpa geser', () async {
      await setelan.simpanPengingatSholatAktif(true);
      await setelan.simpanBriefingAktif(false);
      await setelan.simpanMode(WaktuSholat.maghrib, ModePengingatSholat.sebelum);
      await setelan.simpanGeser(WaktuSholat.maghrib, 15);

      final List<Pengingat> daftar = await ambil(sekarangUji);
      final Pengingat maghrib = daftar.firstWhere(
          (p) => p.kanal == KanalNotifikasi.sholat && p.judul.contains('Maghrib'));
      expect(maghrib.judul, '15 menit lagi Maghrib');
      final int menit = maghrib.waktu.hour * 60 + maghrib.waktu.minute;
      // Maghrib Jakarta 17:50 → dikurangi 15 menit = 17:35 (±2 menit).
      expect((menit - (17 * 60 + 35)).abs(), lessThanOrEqualTo(3));

      final Pengingat isya = daftar.firstWhere(
          (p) => p.kanal == KanalNotifikasi.sholat && p.judul.contains('Isya'));
      expect(isya.judul, startsWith('Waktu Isya'));
    });

    test('FR-87: koreksi kehati-hatian menggeser seluruh waktu', () async {
      await setelan.simpanPengingatSholatAktif(true);
      await setelan.simpanBriefingAktif(false);
      final List<Pengingat> dasar = await ambil(sekarangUji);
      await setelan.simpanIhtiyatiMenit(2);
      final List<Pengingat> maju = await ambil(sekarangUji);
      final Pengingat a = dasar.firstWhere(
          (p) => p.judul.contains('Dzuhur') && p.waktu.day == sekarangUji.day);
      final Pengingat b = maju.firstWhere(
          (p) => p.judul.contains('Dzuhur') && p.waktu.day == sekarangUji.day);
      expect(b.waktu.difference(a.waktu).inMinutes, 2);
    });

    test('teks notifikasi bebas kata terlarang (PRD III-11)', () async {
      await setelan.simpanPengingatSholatAktif(true);
      await db.into(db.tagihan).insert(TagihanCompanion.insert(
            nama: 'Internet',
            jumlahSen: const Value(35000000),
            jatuhTempo: DateTime(2026, 9, 14),
            kategoriId: const Value(null),
          ));
      final List<Pengingat> daftar = await ambil(sekarangUji);
      expect(daftar, isNotEmpty);
      for (final Pengingat p in daftar) {
        final String teks = '${p.judul} ${p.isi}'.toLowerCase();
        for (final String kata in kataTerlarang) {
          expect(teks.contains(kata), isFalse,
              reason: 'teks mengandung "$kata": ${p.judul} | ${p.isi}');
        }
      }
    });

    test('semua pengingat punya waktu di masa depan (batas rencana)', () async {
      await setelan.simpanPengingatSholatAktif(true);
      final List<Pengingat> daftar = await ambil(sekarangUji);
      for (final Pengingat p in daftar) {
        expect(p.waktu.isAfter(sekarangUji), isTrue);
        expect(p.waktu.isBefore(sekarangUji.add(const Duration(days: 8))), isTrue);
      }
    });
  });

  group('pendaftaran sumber di isolate utama & latar', () {
    setUp(() => RegistriSumberPengingat.kosongkan());
    tearDown(() => RegistriSumberPengingat.kosongkan());

    test('daftarkanSumberPengingatUtama mendaftar sekali (aman diulang)', () {
      daftarkanSumberPengingatUtama();
      daftarkanSumberPengingatUtama();
      expect(RegistriSumberPengingat.daftar.length, 1);
      expect(RegistriSumberPengingat.daftar.first,
          isA<SumberPengingatIbadah>());
      expect(RegistriSumberPengingat.kosong, isFalse);
    });

    test('pendaftaran latar memakai sumber yang sama', () {
      daftarkanSumberPengingatLatar();
      expect(RegistriSumberPengingat.daftar.single, isA<SumberPengingatIbadah>());
    });
  });

  group('layar Pengingat Ibadah', () {
    late SetelanUji simpan;

    Future<void> bukaLayar(WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(420, 900));
      await t.pumpWidget(MaterialApp(
        home: PengingatIbadahScreen(
          setelan: PengaturanIbadah(simpan),
          jamSekarang: () => sekarangUji,
        ),
      ));
      await t.pumpAndSettle();
    }

    /// Gulirkan layar sampai [f] benar-benar terlihat di dalam jendela uji.
    ///
    /// Dua langkah diperlukan: `drag` bila widget belum dibangun (ListView
    /// malas membangun), lalu `ensureVisible` bila sudah dibangun tetapi masih
    /// di luar layar — menyentuh widget di luar layar akan meleset.
    Future<void> gulirKe(WidgetTester t, Finder f) async {
      for (int i = 0; i < 14 && f.evaluate().isEmpty; i++) {
        await t.drag(find.byType(ListView), const Offset(0, -220));
        await t.pumpAndSettle();
      }
      if (f.evaluate().isNotEmpty) {
        await t.ensureVisible(f);
        await t.pumpAndSettle();
      }
    }

    setUp(() => simpan = SetelanUji());

    testWidgets('bawaan: ringkasan pagi aktif, pilihan sholat tersembunyi',
        (WidgetTester t) async {
      await bukaLayar(t);
      expect(find.byKey(const Key('saklar_briefing')), findsOneWidget);
      expect(find.byKey(const Key('pilih_jam_briefing')), findsOneWidget);
      await gulirKe(t, find.byKey(const Key('saklar_sholat')));
      expect(find.byKey(const Key('saklar_sholat')), findsOneWidget);
      // Saklar sholat bawaan mati → rinciannya tidak ditampilkan.
      expect(find.byKey(const Key('pilih_kota')), findsNothing);
      final SwitchListTile s = t.widget<SwitchListTile>(
          find.byKey(const Key('saklar_sholat')));
      expect(s.value, isFalse);
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('jam ringkasan bisa diubah lewat daftar pilihan',
        (WidgetTester t) async {
      await bukaLayar(t);
      await t.tap(find.byKey(const Key('daftar_jam')));
      await t.pumpAndSettle();
      await t.tap(find.text('07:30').last);
      await t.pumpAndSettle();
      expect(await PengaturanIbadah(simpan).jamBriefing(), '07:30');
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('menyalakan pengingat sholat menyimpan pilihan', (t) async {
      await bukaLayar(t);
      await gulirKe(t, find.byKey(const Key('saklar_sholat')));
      await t.tap(find.byKey(const Key('saklar_sholat')));
      await t.pumpAndSettle();
      expect(await PengaturanIbadah(simpan).pengingatSholatAktif(), isTrue);
      await gulirKe(t, find.byKey(const Key('pilih_kota')));
      expect(find.byKey(const Key('pilih_kota')), findsOneWidget);
      expect(find.byKey(const Key('pilih_metode')), findsOneWidget);
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('mode per waktu sholat tersimpan + geser muncul', (t) async {
      simpan.isi[kunciPengingatSholat] = 'true';
      await bukaLayar(t);
      final Finder sebelum = find.byKey(const Key('mode_subuh_sebelum'));
      await gulirKe(t, sebelum);
      expect(sebelum, findsOneWidget);
      await t.tap(sebelum);
      await t.pumpAndSettle();
      expect(await PengaturanIbadah(simpan).mode(WaktuSholat.subuh),
          ModePengingatSholat.sebelum);
      final Finder geser = find.byKey(const Key('geser_subuh'));
      expect(geser, findsOneWidget);
      await t.tap(geser);
      await t.pumpAndSettle();
      await t.tap(find.text('15 menit').last);
      await t.pumpAndSettle();
      expect(await PengaturanIbadah(simpan).geser(WaktuSholat.subuh), 15);
      await t.binding.setSurfaceSize(null);
    });
  });
}
