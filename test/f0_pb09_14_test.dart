/// Uji F0 lanjutan 2 — PB-09, PB-10, PB-11, PB-13.
///
/// PB-09: sinkronisasi memverifikasi hasil nyata (bukan asumsi).
/// PB-10: inisialisasi gagal → tidak menandai siap, dan bisa mencoba lagi.
/// PB-11: hapus semua data juga membatalkan notifikasi.
/// PB-13: ubah tagihan yang tidak ada tidak boleh dianggap "berhasil".
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/notifikasi/jejak.dart';
import 'package:personal_life_os/core/notifikasi/layanan_notifikasi.dart';
import 'package:personal_life_os/core/notifikasi/layanan_notifikasi_lokal.dart';
import 'package:personal_life_os/core/notifikasi/model_pengingat.dart';
import 'package:personal_life_os/core/notifikasi/perencana_pengingat.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';

class LayananPalsu implements LayananNotifikasi {
  // PB-09/PB-10: bagian diagnostik antarmuka (nilai bawaan untuk uji).
  @override
  HasilPasang? get hasilPasangTerakhir => null;

  @override
  bool get siap => true;

  bool batalkanDipanggil = false;

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
  Future<void> pasangJadwal(List<Pengingat> daftar) async {}

  @override
  Future<void> batalkanSemua() async => batalkanDipanggil = true;

  @override
  Future<void> jadwalkanSatu(Pengingat p) async {}

  @override
  Future<void> tampilkanUji({Duration tunda = const Duration(seconds: 10)}) async {}

  @override
  Future<List<({int id, String? judul, DateTime? waktu})>> tertunda() async =>
      const [];
}

/// PB-10: layanan yang inisialisasinya sengaja gagal, untuk menguji pemulihan.
class LayananInitGagal extends LayananNotifikasiLokal {
  int percobaan = 0;

  @override
  Future<void> lakukanInisialisasi() async {
    percobaan++;
    throw StateError('plugin tidak tersedia (uji)');
  }
}

late AppDatabase db;
late TagihanRepository repo;
late PengaturanRepository repoPengaturan;

void main() {
  setUp(() async {
    penentuJejak = () async => null;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TagihanRepository(db);
    repoPengaturan = PengaturanRepository(db);
  });

  tearDown(() async => db.close());

  group('PB-09 — verifikasi hasil sinkronisasi', () {
    test('menemukan jadwal yang direncanakan tetapi belum terpasang', () {
      final gagal = idJadwalGagalTerpasang(
        direncanakan: [10, 20, 30],
        terpasang: [10, 30],
      );
      expect(gagal, [20]);
    });

    test('tidak ada kegagalan bila semua terpasang', () {
      expect(
        idJadwalGagalTerpasang(direncanakan: [1, 2], terpasang: [2, 1, 9]),
        isEmpty,
      );
    });

    test('ringkasan hasil jujur saat ada kegagalan', () {
      final lengkap = HasilPasang(
          direncanakan: 5, terpasang: 5, idGagal: const [], waktu: DateTime(2026, 9, 14));
      expect(lengkap.lengkap, isTrue);
      expect(lengkap.ringkas, contains('5 dari 5'));

      final sebagian = HasilPasang(
          direncanakan: 5, terpasang: 4, idGagal: const [77], waktu: DateTime(2026, 9, 14));
      expect(sebagian.lengkap, isFalse);
      expect(sebagian.ringkas, contains('GAGAL'));
    });
  });

  group('PB-10 — pemulihan saat inisialisasi gagal', () {
    test('init gagal → status siap TETAP false dan percobaan berikutnya mencoba lagi',
        () async {
      final l = LayananInitGagal();
      await l.siapkan();
      expect(l.siap, isFalse, reason: 'gagal init tidak boleh dianggap siap');
      expect(l.percobaan, 1);

      await l.siapkan();
      expect(l.percobaan, 2, reason: 'pemanggilan berikutnya harus mencoba lagi');
      expect(l.siap, isFalse);
    });
  });

  group('PB-11 — hapus semua data membatalkan notifikasi', () {
    test('notifikasi dibatalkan dan seluruh baris terhapus', () async {
      await repo.tambah(TagihanCompanion.insert(
        nama: 'Listrik PLN',
        jumlahSen: const Value(15000000),
        jatuhTempo: DateTime(2026, 9, 15),
      ));
      final layanan = LayananPalsu();

      await repoPengaturan.hapusSemuaData(layanan: layanan);

      expect(layanan.batalkanDipanggil, isTrue,
          reason: 'jadwal lama harus dibatalkan tanpa menunggu sinkronisasi');
      expect(await db.select(db.tagihan).get(), isEmpty);
      expect(await db.select(db.riwayatPembayaran).get(), isEmpty);
    });
  });

  group('PB-13 — ubah tagihan yang tidak ada', () {
    test('mengembalikan 0 baris (pemanggil wajib memeriksa)', () async {
      final n = await repo.ubah(
        const TagihanCompanion(nama: Value('Nama baru')),
        id: 9999,
      );
      expect(n, 0);
    });
  });
}
