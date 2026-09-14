/// Uji PB-01/PB-02 (aksi notifikasi) — meniru jalur Android yang sebenarnya:
/// payload diambil dari kode produksi, sedangkan aksi datang dari `actionId`
/// (tombol yang benar-benar ditekan).
///
/// Uji ini dibuat karena uji lama hanya menguji payload buatan tangan, sehingga
/// bug "semua tombol menjadi Sudah bayar" lolos.
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/notifikasi/jejak.dart';
import 'package:personal_life_os/core/notifikasi/layanan_notifikasi.dart';
import 'package:personal_life_os/core/notifikasi/model_pengingat.dart';
import 'package:personal_life_os/core/notifikasi/penangan_aksi_pengingat.dart';
import 'package:personal_life_os/core/notifikasi/perencana_pengingat.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';

class LayananPalsu implements LayananNotifikasi {
  // PB-09/PB-10: bagian diagnostik antarmuka (nilai bawaan untuk uji).
  @override
  HasilPasang? get hasilPasangTerakhir => null;

  @override
  bool get siap => true;

  List<Pengingat> terpasang = const [];
  List<Pengingat> satu = const [];

  @override
  Future<void> siapkan() async {}

  @override
  Future<StatusIzinPengingat> statusIzin() async => const StatusIzinPengingat(
      notifikasiDiizinkan: true, alarmTepatDiizinkan: false);

  @override
  Future<bool> mintaIzinNotifikasi() async => true;

  @override
  Future<bool> mintaIzinAlarmTepat() async => false;

  @override
  Future<void> pasangJadwal(List<Pengingat> daftar) async => terpasang = daftar;

  @override
  Future<void> batalkanSemua() async => terpasang = const [];

  @override
  Future<void> jadwalkanSatu(Pengingat p) async => satu = [...satu, p];

  @override
  Future<void> tampilkanUji({Duration tunda = const Duration(seconds: 10)}) async {}

  @override
  Future<List<({int id, String? judul, DateTime? waktu})>> tertunda() async =>
      terpasang
          .map((p) => (id: p.id, judul: p.judul, waktu: p.waktu))
          .toList(growable: false);
}

late AppDatabase db;
late TagihanRepository repo;

final DateTime sekarang = DateTime(2026, 9, 10, 8, 0);

Future<int> buatTagihan({
  String nama = 'Listrik PLN',
  int sen = 15000000,
  DateTime? jatuhTempo,
  String frekuensi = 'bulanan',
}) async {
  final t = await repo.tambah(TagihanCompanion.insert(
    nama: nama,
    jumlahSen: Value(sen),
    jatuhTempo: jatuhTempo ?? DateTime(2026, 9, 15),
    frekuensi: Value(frekuensi),
  ));
  return t.id;
}

/// Payload persis seperti yang dipasang ke Android oleh kode produksi.
Future<String> payloadProduksi(int tagihanId) async {
  final rencana = const PerencanaPengingat(sertakanRingkasanMingguan: false)
      .rencanakan(tagihan: await repo.ambilSemua(), sekarang: sekarang);
  final p = rencana.firstWhere((x) => x.tagihanId == tagihanId,
      orElse: () => throw StateError('tidak ada pengingat untuk tagihan $tagihanId'));
  return p.payloadDenganPeriode(p.periode!);
}

Future<TagihanData> ambil(int id) =>
    (db.select(db.tagihan)..where((x) => x.id.equals(id))).getSingle();

Future<int> jumlahRiwayat() async =>
    (await db.select(db.riwayatPembayaran).get()).length;

void main() {
  setUp(() async {
    penentuJejak = () async => null;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TagihanRepository(db);
  });

  tearDown(() async => db.close());

  group('PB-01 — aksi notifikasi mengikuti tombol yang ditekan', () {
    test('payload produksi tidak lagi membawa "aksi"', () async {
      final id = await buatTagihan();
      final payload = await payloadProduksi(id);
      expect(payload.contains('"aksi"'), isFalse,
          reason: 'payload hanya boleh memuat konteks (tagihanId, notifId, periode)');
      expect(payload.contains('periode'), isTrue);
    });

    test('actionId "buka" tidak mengubah data apa pun', () async {
      final id = await buatTagihan();
      final payload = await payloadProduksi(id);

      final hasil = await tanganiAksiPengingat(payload,
          actionId: AksiNotifikasi.buka, db: db, sekarang: sekarang);

      expect(hasil.berhasil, isTrue);
      final t = await ambil(id);
      expect(t.lunas, isFalse);
      expect(t.jatuhTempo, DateTime(2026, 9, 15));
      expect(await jumlahRiwayat(), 0);
    });

    test('menyentuh notifikasi tanpa actionId tidak menandai lunas', () async {
      final id = await buatTagihan();
      final payload = await payloadProduksi(id);

      final hasil = await tanganiAksiPengingat(payload, db: db, sekarang: sekarang);

      expect(hasil.berhasil, isTrue);
      expect(await jumlahRiwayat(), 0);
      expect((await ambil(id)).lunas, isFalse);
    });

    test('actionId tidak dikenal diperlakukan sebagai "buka"', () async {
      final id = await buatTagihan();
      final payload = await payloadProduksi(id);

      final hasil = await tanganiAksiPengingat(payload,
          actionId: AksiNotifikasi.dariId('aksi_ngawur'), db: db, sekarang: sekarang);

      expect(hasil.berhasil, isTrue);
      expect(await jumlahRiwayat(), 0);
      expect((await ambil(id)).lunas, isFalse);
    });

    test('actionId "tunda_1_jam" tidak menandai lunas, hanya menjadwalkan tunda',
        () async {
      final id = await buatTagihan();
      final layanan = LayananPalsu();
      final payload = await payloadProduksi(id);

      final hasil = await tanganiAksiPengingat(payload,
          actionId: AksiNotifikasi.tundaSatuJam,
          db: db,
          layanan: layanan,
          sekarang: sekarang);

      expect(hasil.berhasil, isTrue);
      expect(await jumlahRiwayat(), 0, reason: 'tunda bukan pembayaran');
      expect((await ambil(id)).lunas, isFalse);
      expect(layanan.satu, hasLength(1));
      expect(layanan.satu.first.periode, DateTime(2026, 9, 15),
          reason: 'PB-02: pengingat tunda wajib membawa periode');
    });

    test('actionId "sudah_bayar" menandai lunas tepat sekali + rollover sekali',
        () async {
      final id = await buatTagihan();
      final layanan = LayananPalsu();
      final payload = await payloadProduksi(id);

      final hasil = await tanganiAksiPengingat(payload,
          actionId: AksiNotifikasi.sudahBayar,
          db: db,
          layanan: layanan,
          sekarang: sekarang);

      expect(hasil.berhasil, isTrue, reason: hasil.pesan);
      expect(await jumlahRiwayat(), 1);
      expect((await ambil(id)).jatuhTempo, DateTime(2026, 10, 15));
    });

    test('PB-02: "sudah_bayar" tanpa periode ditolak (tidak menandai lunas)',
        () async {
      final id = await buatTagihan();
      final payloadNyata = '{"tagihanId":$id,"notifId":1}'; // tanpa periode

      final hasil = await tanganiAksiPengingat(payloadNyata,
          actionId: AksiNotifikasi.sudahBayar, db: db, sekarang: sekarang);

      expect(hasil.berhasil, isFalse);
      expect(await jumlahRiwayat(), 0);
      expect((await ambil(id)).lunas, isFalse);
    });

    test('notifikasi lama (periode sudah lunas) tidak menggeser periode lagi',
        () async {
      final id = await buatTagihan();
      final payload = await payloadProduksi(id);

      await tanganiAksiPengingat(payload,
          actionId: AksiNotifikasi.sudahBayar, db: db, sekarang: sekarang);
      final kedua = await tanganiAksiPengingat(payload,
          actionId: AksiNotifikasi.sudahBayar, db: db, sekarang: sekarang);

      expect(kedua.berhasil, isTrue);
      expect(kedua.pesan, contains('sudah dibayar'));
      expect(await jumlahRiwayat(), 1);
      expect((await ambil(id)).jatuhTempo, DateTime(2026, 10, 15));
    });
  });
}
