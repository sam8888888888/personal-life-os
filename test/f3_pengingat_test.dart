/// Uji F3 — perencanaan pengingat, penyinkronan jadwal, dan aksi notifikasi
/// (FR-10..FR-16). Memakai layanan notifikasi palsu: tidak butuh perangkat.
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/notifikasi/jejak.dart';
import 'package:personal_life_os/core/notifikasi/layanan_notifikasi.dart';
import 'package:personal_life_os/core/notifikasi/model_pengingat.dart';
import 'package:personal_life_os/core/notifikasi/penangan_aksi_pengingat.dart';
import 'package:personal_life_os/core/notifikasi/perencana_pengingat.dart';
import 'package:personal_life_os/core/notifikasi/penyinkron_pengingat.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';

/// Layanan notifikasi palsu: mencatat apa yang "dipasang", tanpa plugin Android.
class LayananPalsu implements LayananNotifikasi {
  List<Pengingat> terpasang = const [];
  List<Pengingat> satu = const [];
  List<Duration> uji = const [];
  bool izinNotif = true;
  bool izinAlarm = false;

  @override
  Future<void> siapkan() async {}

  @override
  Future<StatusIzinPengingat> statusIzin() async => StatusIzinPengingat(
        notifikasiDiizinkan: izinNotif,
        alarmTepatDiizinkan: izinAlarm,
      );

  @override
  Future<bool> mintaIzinNotifikasi() async => izinNotif;

  @override
  Future<bool> mintaIzinAlarmTepat() async => izinAlarm;

  @override
  Future<void> pasangJadwal(List<Pengingat> daftar) async => terpasang = daftar;

  @override
  Future<void> batalkanSemua() async => terpasang = const [];

  @override
  Future<void> jadwalkanSatu(Pengingat p) async => satu = [...satu, p];

  @override
  Future<void> tampilkanUji({Duration tunda = const Duration(seconds: 10)}) async =>
      uji = [...uji, tunda];

  @override
  Future<List<({int id, String? judul, DateTime? waktu})>> tertunda() async => terpasang
      .map((p) => (id: p.id, judul: p.judul, waktu: p.waktu))
      .toList(growable: false);
}

late AppDatabase db;
late TagihanRepository repo;

/// Tanggal tetap agar uji tidak bergantung waktu berjalan.
final sekarang = DateTime(2026, 9, 10, 8, 0); // Kamis

Future<int> buatTagihan({
  String nama = 'Listrik PLN',
  int sen = 15000000,
  DateTime? jatuhTempo,
  String lead = '3,1,0',
  String jam = '09:00',
  bool lunas = false,
  bool aktif = true,
  String frekuensi = 'bulanan',
}) async {
  final t = await repo.tambah(TagihanCompanion.insert(
    nama: nama,
    jumlahSen: Value(sen),
    jatuhTempo: jatuhTempo ?? DateTime(2026, 9, 20),
    pengingatLeadHari: Value(lead),
    pengingatJam: Value(jam),
    lunas: Value(lunas),
    statusAktif: Value(aktif),
    frekuensi: Value(frekuensi),
  ));
  return t.id;
}

/// Payload **persis** seperti yang dibawa notifikasi nyata (konteks + periode).
/// Aksi TIDAK lagi ada di payload (PB-01) — aksi dikirim terpisah sebagai
/// actionId, sama seperti perilaku Android.
Future<String> payloadNyata(int tagihanId) async {
  final rencana = const PerencanaPengingat(sertakanRingkasanMingguan: false)
      .rencanakan(tagihan: await repo.ambilSemua(), sekarang: sekarang);
  final p = rencana.firstWhere((x) => x.tagihanId == tagihanId,
      orElse: () => throw StateError('tidak ada pengingat untuk tagihan $tagihanId'));
  return p.payloadDenganPeriode(p.periode!);
}

void main() {
  setUp(() async {
    penentuJejak = () async => null; // tanpa berkas jejak saat uji
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TagihanRepository(db);
  });

  tearDown(() async => db.close());

  group('Perencana pengingat (murni)', () {
    test('FR-10: memakai lead H-3, H-1, dan hari-H pada jam pilihan', () async {
      await buatTagihan(jatuhTempo: DateTime(2026, 9, 20), lead: '3,1,0', jam: '07:30');
      final daftar = (await repo.ambilSemua());
      final rencana = const PerencanaPengingat(sertakanRingkasanMingguan: false)
          .rencanakan(tagihan: daftar, sekarang: sekarang);

      expect(rencana.length, 3);
      expect(rencana.map((p) => p.waktu).toList(), [
        DateTime(2026, 9, 17, 7, 30),
        DateTime(2026, 9, 19, 7, 30),
        DateTime(2026, 9, 20, 7, 30),
      ]);
      expect(rencana.map((p) => p.hariSebelum).toList(), [3, 1, 0]);
      expect(rencana.first.judul, contains('3 hari lagi'));
      expect(rencana.last.judul, contains('Hari ini'));
      expect(rencana.first.kanal, KanalNotifikasi.tagihan);
    });

    test('FR-12: lead melebihi batas — yang dibuang justru lead terjauh', () async {
      await buatTagihan(
          jatuhTempo: DateTime(2026, 10, 1), lead: '60,30,14,7,3,1,0,5,2');
      final rencana = const PerencanaPengingat(sertakanRingkasanMingguan: false)
          .rencanakan(tagihan: await repo.ambilSemua(), sekarang: sekarang);
      final hari = rencana.map((p) => p.hariSebelum).toList();

      expect(rencana.length, lessThanOrEqualTo(maksPengingatPerSiklus));
      // Hari-H dan H-1 tetap ada (paling penting); lead terjauh dibuang.
      expect(hari, contains(0));
      expect(hari, contains(1));
      expect(hari, isNot(contains(60)));
      expect(hari, isNot(contains(30)));
    });

    test('pengingat masa lalu & di luar horizon dilewati', () async {
      await buatTagihan(jatuhTempo: DateTime(2026, 9, 11), lead: '7,3,1,0');
      final rencana = const PerencanaPengingat(sertakanRingkasanMingguan: false)
          .rencanakan(tagihan: await repo.ambilSemua(), sekarang: sekarang);
      // H-7 dan H-3 sudah lewat; hanya H-1 (10 Sep 09:00) dan H-0 (11 Sep).
      expect(rencana.map((p) => p.hariSebelum).toList(), [1, 0]);
    });

    test('FR-16: tagihan terlambat dapat 1 pengingat per hari (maks 7)', () async {
      await buatTagihan(nama: 'Internet', jatuhTempo: DateTime(2026, 9, 7));
      final rencana = const PerencanaPengingat(sertakanRingkasanMingguan: false)
          .rencanakan(tagihan: await repo.ambilSemua(), sekarang: sekarang);
      expect(rencana.length, maksHariTerlambat);
      expect(rencana.every((p) => p.terlambat), isTrue);
      expect(rencana.first.kanal, KanalNotifikasi.terlambat);
      expect(rencana.first.waktu, DateTime(2026, 9, 10, 9, 0));
      expect(rencana.first.isi, contains('lewat 3 hari'));
      // ID berbeda tiap hari -> tidak saling menimpa.
      expect(rencana.map((p) => p.id).toSet().length, maksHariTerlambat);
    });

    test('tagihan lunas & nonaktif tidak dijadwalkan', () async {
      await buatTagihan(nama: 'Lunas', lunas: true);
      await buatTagihan(nama: 'Nonaktif', aktif: false);
      final rencana = const PerencanaPengingat(sertakanRingkasanMingguan: false)
          .rencanakan(tagihan: await repo.ambilSemua(), sekarang: sekarang);
      expect(rencana, isEmpty);
    });

    test('FR-15: ringkasan mingguan dijadwalkan Senin pagi', () async {
      await buatTagihan(nama: 'PDAM', jatuhTempo: DateTime(2026, 9, 14));
      final rencana = const PerencanaPengingat()
          .rencanakan(tagihan: await repo.ambilSemua(), sekarang: sekarang);
      final ringkasan =
          rencana.firstWhere((p) => p.kanal == KanalNotifikasi.ringkasan);
      expect(ringkasan.waktu, DateTime(2026, 9, 14, jamRingkasanMingguan));
      expect(ringkasan.id, idRingkasanMingguan);
      expect(ringkasan.judul, contains('1 tagihan'));
      expect(ringkasan.judul, contains('Rp 150.000'), reason: 'total pekan ini');
      expect(ringkasan.isi, contains('PDAM'));
      expect(ringkasan.kanal, KanalNotifikasi.ringkasan);
    });

    test('jam tidak valid memakai default 09:00', () {
      expect(jamDariTeks('07:15'), (7, 15));
      expect(jamDariTeks('99:99'), (9, 0));
      expect(jamDariTeks(null), (9, 0));
      expect(jamDariTeks('09'), (9, 0));
    });

    test('ID notifikasi stabil dan unik per slot', () async {
      final id = await buatTagihan();
      expect(idNotifikasi(id, 0), id * 100);
      expect(idNotifikasi(id, 3), id * 100 + 3);
      expect(slotTerlambat(0), 90);
      expect(slotTunda, 89);
    });

    test('ID notifikasi tidak pernah bentrok dengan ID khusus', () {
      // 10 juta tagihan pertama tetap di bawah rentang ID khusus.
      for (final idTagihan in [1, 7770, 999999, 9999999]) {
        for (final slot in [0, 1, 89, 90, 96]) {
          final n = idNotifikasi(idTagihan, slot);
          expect(n, lessThan(batasIdKhusus), reason: 'tagihan $idTagihan slot $slot');
          expect(n, isNot(idRingkasanMingguan));
          expect(n, isNot(idUjiNotifikasi));
        }
      }
      expect(idRingkasanMingguan, isNot(idUjiNotifikasi));
    });
  });

  group('Penyinkron jadwal', () {
    test('memasang jadwal & melaporkan jumlahnya', () async {
      await buatTagihan(nama: 'Listrik', jatuhTempo: DateTime(2026, 9, 20));
      await buatTagihan(nama: 'Air', jatuhTempo: DateTime(2026, 9, 12));
      final layanan = LayananPalsu();
      final hasil = await PenyinkronPengingat(repo: repo, layanan: layanan)
          .sinkron(sekarang: sekarang);

      expect(hasil.berhasil, isTrue);
      expect(hasil.jumlahTerjadwal, layanan.terpasang.length);
      expect(hasil.jumlahTerjadwal, greaterThan(0));
      expect(hasil.jumlahTerlambat, 0);
      expect(layanan.terpasang.every((p) => p.waktu.isAfter(sekarang)), isTrue);
    });

    test('menjadwalkan ulang setelah tagihan ditandai lunas (rollover)', () async {
      final id = await buatTagihan(jatuhTempo: DateTime(2026, 9, 15));
      final layanan = LayananPalsu();
      final sinkron = PenyinkronPengingat(repo: repo, layanan: layanan);
      await sinkron.sinkron(sekarang: sekarang);
      final sebelum = layanan.terpasang.map((p) => p.waktu).toSet();

      await repo.tandaiLunas(id, tanggalBayar: sekarang);
      await sinkron.sinkron(sekarang: sekarang);
      final sesudah = layanan.terpasang;

      expect(sesudah, isNotEmpty);
      expect(sesudah.map((p) => p.waktu).toSet(), isNot(sebelum));
      expect(sesudah.every((p) => p.waktu.isAfter(DateTime(2026, 10, 1))), isTrue,
          reason: 'periode berikutnya = 15 Okt 2026');
    });

    test('kegagalan layanan dilaporkan, bukan dilempar', () async {
      await buatTagihan();
      final hasil = await PenyinkronPengingat(
        repo: repo,
        layanan: _LayananRusak(),
      ).sinkron(sekarang: sekarang);
      expect(hasil.berhasil, isFalse);
      expect(hasil.galat, contains('gagal pasang'));
    });
  });

  group('Aksi dari notifikasi (FR-11)', () {
    test('"✓ Sudah bayar" menandai lunas & menggeser periode', () async {
      final id = await buatTagihan(nama: 'Internet', jatuhTempo: DateTime(2026, 9, 15));
      final layanan = LayananPalsu();
      final payload = await payloadNyata(id);

      final hasil = await tanganiAksiPengingat(payload,
          actionId: AksiNotifikasi.sudahBayar,
          db: db,
          layanan: layanan,
          sekarang: sekarang);

      expect(hasil.berhasil, isTrue, reason: hasil.pesan);
      final t = await (db.select(db.tagihan)..where((x) => x.id.equals(id))).getSingle();
      expect(t.jatuhTempo, DateTime(2026, 10, 15));
      // Jadwal disegarkan untuk periode baru.
      expect(layanan.terpasang, isNotEmpty);
    });

    test('PENTING: notifikasi lama tidak menandai lunas periode berikutnya',
        () async {
      final id = await buatTagihan(jatuhTempo: DateTime(2026, 9, 15));
      // Payload nyata dari jadwal (membawa periode 15 Sep 2026).
      final payload = await payloadNyata(id);
      final pertama = await tanganiAksiPengingat(payload,
          actionId: AksiNotifikasi.sudahBayar, db: db, sekarang: sekarang);
      expect(pertama.berhasil, isTrue);

      // Pengguna menekan aksi pada notifikasi yang sama (periode sudah lunas).
      final kedua = await tanganiAksiPengingat(payload,
          actionId: AksiNotifikasi.sudahBayar, db: db, sekarang: sekarang);

      expect(kedua.berhasil, isTrue);
      expect(kedua.pesan, contains('sudah dibayar'));
      final riwayat = await db.select(db.riwayatPembayaran).get();
      expect(riwayat.length, 1, reason: 'riwayat tidak boleh bertambah');
      final t = await (db.select(db.tagihan)..where((x) => x.id.equals(id))).getSingle();
      expect(t.jatuhTempo, DateTime(2026, 10, 15),
          reason: 'periode tidak boleh maju dua kali');
    });

    test('tagihan sekali: aksi kedua hanya melaporkan sudah lunas', () async {
      final id = await buatTagihan(
          nama: 'STNK', jatuhTempo: DateTime(2026, 9, 15), frekuensi: 'sekali');
      final payload = await payloadNyata(id);
      await tanganiAksiPengingat(payload,
          actionId: AksiNotifikasi.sudahBayar, db: db, sekarang: sekarang);
      final kedua = await tanganiAksiPengingat(payload,
          actionId: AksiNotifikasi.sudahBayar, db: db, sekarang: sekarang);

      expect(kedua.pesan, contains('sudah bertanda lunas'));
      expect(await db.select(db.riwayatPembayaran).get(), hasLength(1));
    });

    test('"Tunda 1 jam" menjadwalkan satu notifikasi +1 jam', () async {
      final id = await buatTagihan(jatuhTempo: DateTime(2026, 9, 15));
      final layanan = LayananPalsu();
      final payload = await payloadNyata(id);

      final hasil = await tanganiAksiPengingat(payload,
          actionId: AksiNotifikasi.tundaSatuJam,
          db: db,
          layanan: layanan,
          sekarang: sekarang);
      expect(hasil.berhasil, isTrue);
      expect(layanan.satu.length, 1);
      expect(layanan.satu.first.waktu, sekarang.add(const Duration(hours: 1)));
      expect(layanan.satu.first.id, idNotifikasi(id, slotTunda));
    });

    test('tagihan tidak dikenal ditolak dengan pesan jelas', () async {
      final payload = const PayloadPengingat(tagihanId: 9999).toJson();
      final hasil = await tanganiAksiPengingat(payload,
          actionId: AksiNotifikasi.sudahBayar, db: db, sekarang: sekarang);
      expect(hasil.berhasil, isFalse);
      expect(hasil.pesan, contains('tidak ditemukan'));
    });

    test('payload kosong / rusak ditolak, tidak melempar', () async {
      for (final teks in [null, '', 'bukan-json', '{"aksi":"sudah_bayar"}']) {
        final hasil = await tanganiAksiPengingat(teks,
            actionId: AksiNotifikasi.sudahBayar, db: db, sekarang: sekarang);
        expect(hasil.berhasil, isFalse);
      }
    });

    test('aksi "buka aplikasi" tidak mengubah data', () async {
      final id = await buatTagihan(jatuhTempo: DateTime(2026, 9, 15));
      final payload = await payloadNyata(id);
      final hasil = await tanganiAksiPengingat(payload,
          actionId: AksiNotifikasi.buka, db: db, sekarang: sekarang);
      expect(hasil.berhasil, isTrue);
      final t = await (db.select(db.tagihan)..where((x) => x.id.equals(id))).getSingle();
      expect(t.jatuhTempo, DateTime(2026, 9, 15));
      expect(t.lunas, isFalse);
    });
  });
}

class _LayananRusak implements LayananNotifikasi {
  @override
  Future<void> siapkan() async {}
  @override
  Future<StatusIzinPengingat> statusIzin() async => const StatusIzinPengingat(
      notifikasiDiizinkan: false, alarmTepatDiizinkan: false);
  @override
  Future<bool> mintaIzinNotifikasi() async => false;
  @override
  Future<bool> mintaIzinAlarmTepat() async => false;
  @override
  Future<void> pasangJadwal(List<Pengingat> daftar) async =>
      throw StateError('gagal pasang jadwal');
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
