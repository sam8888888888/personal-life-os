/// Uji fondasi notifikasi tambahan — FR-63 (briefing pagi) & FR-87 (pengingat
/// waktu sholat).
///
/// Semua berkas di sini **murni** (perencana + penyinkron dengan layanan palsu):
/// tidak butuh perangkat Android. Yang tetap hanya bisa diuji di HP Papi:
/// notifikasi benar-benar berbunyi walau aplikasi tertutup.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/notifikasi/jejak.dart';
import 'package:personal_life_os/core/notifikasi/layanan_notifikasi.dart';
import 'package:personal_life_os/core/notifikasi/model_pengingat.dart';
import 'package:personal_life_os/core/notifikasi/perencana_pengingat.dart';
import 'package:personal_life_os/core/notifikasi/penyinkron_pengingat.dart';
import 'package:personal_life_os/core/notifikasi/sumber_pengingat_tambahan.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';

/// Layanan notifikasi palsu: mencatat apa yang "terpasang" (pola sama dengan
/// uji F0) — tanpa plugin Android.
class LayananPalsu implements LayananNotifikasi {
  List<Pengingat> terakhirDirencanakan = const [];
  int pemasangan = 0;

  @override
  HasilPasang? get hasilPasangTerakhir => null;

  @override
  bool get siap => true;

  @override
  Future<void> siapkan() async {}

  @override
  Future<StatusIzinPengingat> statusIzin() async => const StatusIzinPengingat(
      notifikasiDiizinkan: true, alarmTepatDiizinkan: true);

  @override
  Future<bool> mintaIzinNotifikasi() async => true;

  @override
  Future<bool> mintaIzinAlarmTepat() async => true;

  @override
  Future<void> pasangJadwal(List<Pengingat> daftar) async {
    pemasangan++;
    terakhirDirencanakan = List.of(daftar);
  }

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

/// Sumber pengingat tambahan palsu (meniru modul fitur).
class SumberPalsu implements SumberPengingatTambahan {
  SumberPalsu(this.daftar, {this.rusak = false});

  final List<Pengingat> daftar;
  final bool rusak;
  int panggilan = 0;

  @override
  Future<List<Pengingat>> pengingatTambahan(DateTime sekarang) async {
    panggilan++;
    if (rusak) throw StateError('sumber rusak (uji)');
    return daftar;
  }
}

Pengingat _pengingatTambahan(int id, DateTime waktu) => Pengingat(
      id: id,
      tagihanId: 0,
      waktu: waktu,
      kanal: KanalNotifikasi.sholat,
      judul: 'Waktu Subuh 04:43',
      isi: 'Menurut hitungan aplikasi, Subuh masuk pukul 04:43.',
    );

void main() {
  late AppDatabase db;
  late TagihanRepository repo;

  final jamUji = DateTime(2026, 9, 15, 5, 0); // 05:00 → briefing 06:00 hari ini

  setUp(() async {
    penentuJejak = () async => null;
    RegistriSumberPengingat.kosongkan();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TagihanRepository(db);
  });

  tearDown(() async {
    RegistriSumberPengingat.kosongkan();
    await db.close();
  });

  const perencana = PerencanaPengingat(sertakanRingkasanMingguan: false);
  const jadwalLimaWaktu = [
    JadwalPengingatSholat(nama: 'Subuh', jam: '04:43'),
    JadwalPengingatSholat(nama: 'Dzuhur', jam: '11:52'),
    JadwalPengingatSholat(nama: 'Ashar', jam: '15:09'),
    JadwalPengingatSholat(nama: 'Maghrib', jam: '17:52'),
    JadwalPengingatSholat(nama: 'Isya', jam: '19:03'),
  ];

  group('FR-63 briefing pagi', () {
    test('hari ini bila jam briefing belum lewat', () {
      final d = perencana.rencanakan(
        tagihan: const [],
        sekarang: jamUji,
        sertakanBriefingPagi: true,
      ).where((p) => p.kanal == KanalNotifikasi.briefing).toList();

      expect(d, isNotEmpty);
      expect(d.first.waktu, DateTime(2026, 9, 15, 6, 0));
      expect(d.first.id, idBriefingPagiKe(0));
      expect(d.first.tagihanId, 0, reason: 'briefing bukan tagihan');
    });

    test('mulai besok bila jam briefing sudah lewat', () {
      final d = perencana.rencanakan(
        tagihan: const [],
        sekarang: DateTime(2026, 9, 15, 7, 30),
        sertakanBriefingPagi: true,
      ).where((p) => p.kanal == KanalNotifikasi.briefing).toList();

      expect(d.first.waktu, DateTime(2026, 9, 16, 6, 0));
    });

    test('7 hari ke depan, id unik, jam bisa diatur pengguna', () {
      final d = perencana.rencanakan(
        tagihan: const [],
        sekarang: jamUji,
        sertakanBriefingPagi: true,
        jamBriefingPagi: '05:30',
      ).where((p) => p.kanal == KanalNotifikasi.briefing).toList();

      expect(d.length, hariBriefingKeDepan);
      expect(d.map((p) => p.id).toSet().length, d.length, reason: 'id unik');
      expect(d.first.waktu.hour, 5);
      expect(d.first.waktu.minute, 30);
    });

    test('isi menyebut jumlah & total tagihan pekan ini', () async {
      await repo.tambah(TagihanCompanion.insert(
        nama: 'Internet',
        jumlahSen: const Value(35000000),
        jatuhTempo: DateTime(2026, 9, 17),
      ));
      final tagihan = await repo.ambilSemua();
      final d = perencana.rencanakan(
        tagihan: tagihan,
        sekarang: jamUji,
        sertakanBriefingPagi: true,
      ).firstWhere((p) => p.kanal == KanalNotifikasi.briefing);

      expect(d.isi, contains('1 tagihan'));
      expect(d.isi, contains('350.000'));
    });

    test('tanpa opsi briefing tidak ada notifikasi briefing', () {
      final d = perencana.rencanakan(tagihan: const [], sekarang: jamUji);
      expect(d.any((p) => p.kanal == KanalNotifikasi.briefing), isFalse);
    });
  });

  group('FR-87 pengingat sholat', () {
    test('5 waktu × 7 hari, id unik, kanal sholat', () {
      final d = perencana
          .rencanakan(
            tagihan: const [],
            sekarang: jamUji,
            jadwalSholat: jadwalLimaWaktu,
          )
          .where((p) => p.kanal == KanalNotifikasi.sholat)
          .toList();

      // Subuh hari ini (04:43) sudah lewat pada 05:00 → 7 hari × 5 − 1.
      expect(d.length, 5 * hariSholatKeDepan - 1);
      expect(d.map((p) => p.id).toSet().length, d.length);
      expect(d.every((p) => p.tagihanId == 0), isTrue);
      expect(d.first.waktu, DateTime(2026, 9, 15, 11, 52), reason: 'Dzuhur hari ini');
    });

    test('mode "5 menit sebelum" menggeser waktu', () {
      final d = perencana
          .rencanakan(
            tagihan: const [],
            sekarang: jamUji,
            jadwalSholat: const [
              JadwalPengingatSholat(
                nama: 'Dzuhur',
                jam: '11:52',
                mode: ModePengingatSholat.sebelum,
                menitGeser: 5,
              ),
            ],
          )
          .firstWhere((p) => p.kanal == KanalNotifikasi.sholat);

      expect(d.waktu, DateTime(2026, 9, 15, 11, 47));
      expect(d.judul, contains('5 menit lagi'));
    });

    test('mode "setelah waktu" dan teksnya tidak menghakimi', () {
      final d = perencana
          .rencanakan(
            tagihan: const [],
            sekarang: jamUji,
            jadwalSholat: const [
              JadwalPengingatSholat(
                nama: 'Isya',
                jam: '19:03',
                mode: ModePengingatSholat.sesudah,
                menitGeser: 30,
              ),
            ],
          )
          .firstWhere((p) => p.kanal == KanalNotifikasi.sholat);

      expect(d.waktu, DateTime(2026, 9, 15, 19, 33));
      final teks = '${d.judul} ${d.isi}'.toLowerCase();
      for (final terlarang in ['belum sholat', 'gagal', 'dosa', 'malas']) {
        expect(teks.contains(terlarang), isFalse, reason: 'kata "$terlarang" terlarang');
      }
      expect(d.isi, contains('Catat bila sudah Anda lakukan'));
    });

    test('pengingat yang sudah lewat tidak dijadwalkan (tidak ada banjir notifikasi)',
        () {
      final d = perencana
          .rencanakan(
            tagihan: const [],
            sekarang: DateTime(2026, 9, 15, 20, 0), // semua waktu hari ini lewat
            jadwalSholat: jadwalLimaWaktu,
          )
          .where((p) => p.kanal == KanalNotifikasi.sholat)
          .toList();

      // Hari ini sudah lewat semua → yang terjadwal 6 hari berikutnya saja.
      expect(d.length, 5 * (hariSholatKeDepan - 1));
      expect(d.first.waktu, DateTime(2026, 9, 16, 4, 43), reason: 'mulai besok Subuh');
      expect(d.every((p) => p.waktu.isAfter(DateTime(2026, 9, 15, 20, 0))), isTrue);
    });

    test('jam tidak sah dipakai nilai aman (tidak melempar)', () {
      final d = perencana
          .rencanakan(
            tagihan: const [],
            sekarang: jamUji,
            jadwalSholat: const [JadwalPengingatSholat(nama: 'Subuh', jam: 'x')],
          )
          .where((p) => p.kanal == KanalNotifikasi.sholat)
          .toList();
      expect(d, isNotEmpty);
      expect(d.first.waktu.hour, 9, reason: 'jamDariTeks → 09:00');
    });
  });

  group('penyinkron: sumber tambahan', () {
    test('pengingat tambahan digabung & ikut terpasang', () async {
      final layanan = LayananPalsu();
      final sumber = SumberPalsu([
        _pengingatTambahan(idSholatKe(0), DateTime(2026, 9, 15, 11, 52)),
      ]);
      final sinkron = PenyinkronPengingat(
        repo: repo,
        layanan: layanan,
        perencana: perencana,
        sumberTambahan: [sumber],
      );

      final hasil = await sinkron.sinkron(sekarang: jamUji);

      expect(hasil.berhasil, isTrue);
      expect(hasil.jumlahTambahan, 1);
      expect(hasil.jumlahTerjadwal, layanan.terakhirDirencanakan.length);
      expect(layanan.terakhirDirencanakan.map((p) => p.id), contains(idSholatKe(0)));
      expect(sumber.panggilan, 1);
    });

    test('sumber tambahan rusak → sinkron tagihan TETAP berhasil, galat dicatat',
        () async {
      await repo.tambah(TagihanCompanion.insert(
        nama: 'Listrik',
        jumlahSen: const Value(15000000),
        jatuhTempo: DateTime(2026, 9, 20),
      ));
      final layanan = LayananPalsu();
      final sinkron = PenyinkronPengingat(
        repo: repo,
        layanan: layanan,
        perencana: perencana,
        sumberTambahan: [SumberPalsu(const [], rusak: true)],
      );

      final hasil = await sinkron.sinkron(sekarang: jamUji);

      expect(hasil.berhasil, isTrue);
      expect(hasil.jumlahTerjadwal, greaterThan(0), reason: 'tagihan tetap terjadwal');
      expect(hasil.jumlahTambahan, 0);
      expect(hasil.galatSumberTambahan, isNotEmpty);
      expect(hasil.galatSumberTambahan.first, contains('SumberPalsu'));
    });

    test('pakai registri bila daftar sumber tidak diberikan', () async {
      final layanan = LayananPalsu();
      RegistriSumberPengingat.daftarkan(
          SumberPalsu([_pengingatTambahan(idSholatKe(1), DateTime(2026, 9, 15, 15, 9))]));

      final hasil = await PenyinkronPengingat(
        repo: repo,
        layanan: layanan,
        perencana: perencana,
      ).sinkron(sekarang: jamUji);

      expect(hasil.jumlahTambahan, 1);
      expect(layanan.terakhirDirencanakan.map((p) => p.id), contains(idSholatKe(1)));
    });

    test('pratinjau menyertakan pengingat tambahan', () async {
      final sinkron = PenyinkronPengingat(
        repo: repo,
        layanan: LayananPalsu(),
        perencana: perencana,
        sumberTambahan: [
          SumberPalsu([_pengingatTambahan(idSholatKe(0), DateTime(2026, 9, 15, 11, 52))])
        ],
      );

      final daftar = await sinkron.pratinjau(sekarang: jamUji);
      expect(daftar.map((p) => p.id), contains(idSholatKe(0)));
    });

    test('registri: pendaftaran tidak dobel, kosongkan membersihkan', () {
      RegistriSumberPengingat.daftarkan(SumberPalsu(const []));
      RegistriSumberPengingat.daftarkan(SumberPalsu(const []));
      expect(RegistriSumberPengingat.daftar.length, 1);
      RegistriSumberPengingat.kosongkan();
      expect(RegistriSumberPengingat.kosong, isTrue);
    });

    test('id tidak pernah bentrok dengan rentang tagihan', () {
      final idBriefing = idBriefingPagiKe(0);
      final idSholat = idSholatKe(0);
      // Rentang tagihan: idNotifikasi() = (id % 10^7) * 100 + slot, maks < 10^9.
      for (final tagihanId in [1, 999, 1234567, 9999999]) {
        for (final slot in [0, 5, 89, 90, 99]) {
          final id = idNotifikasi(tagihanId, slot);
          expect(id, lessThan(batasIdKhusus));
          expect(id == idBriefing || id == idSholat, isFalse);
        }
      }
      expect(idBriefing, greaterThanOrEqualTo(batasIdKhusus));
      expect(idSholat, greaterThanOrEqualTo(batasIdKhusus));
    });
  });

  group('pengaturan k-v (saklar FR-63 & mode FR-87)', () {
    test('simpan/baca + bacaTeks, bacaAngka, bacaSaklar', () async {
      final p = PengaturanRepository(db);
      expect(await p.baca('briefing.pagi'), isNull);
      expect(await p.bacaSaklar('briefing.pagi'), isFalse);
      expect(await p.bacaSaklar('briefing.pagi', bawaan: true), isTrue);

      await p.simpan('briefing.pagi', 'true');
      await p.simpan('briefing.jam', '05:30');
      await p.simpan('sholat.subuh.mode', 'sebelum');
      await p.simpan('sholat.subuh.geser', '5');
      await p.simpan('briefing.pagi', 'false'); // upsert, bukan baris ganda

      expect(await p.bacaSaklar('briefing.pagi'), isFalse);
      expect(await p.bacaSaklar('briefing.pagi', bawaan: true), isFalse,
          reason: 'nilai tersimpan menang atas bawaan');
      expect(await p.bacaTeks('briefing.jam', '06:00'), '05:30');
      expect(await p.bacaTeks('jam.tidak.ada', '06:00'), '06:00');
      expect(await p.bacaAngka('sholat.subuh.geser', 0), 5);
      expect(await p.bacaAngka('tidak.ada', 7), 7);

      final baris = await db.select(db.pengaturan).get();
      expect(baris.length, 4, reason: 'upsert: satu kunci = satu baris');
    });

    test('hapus pengaturan kembali ke nilai bawaan', () async {
      final p = PengaturanRepository(db);
      await p.simpan('briefing.jam', '05:30');
      await p.hapusPengaturan('briefing.jam');
      expect(await p.bacaTeks('briefing.jam', '06:00'), '06:00');
    });
  });
}
