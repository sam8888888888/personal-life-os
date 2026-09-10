import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';

void main() {
  late AppDatabase db;
  late TagihanRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TagihanRepository(db);
  });

  tearDown(() async => db.close());

  Future<int> tambahBulanan(String nama, int sen, DateTime jatuhTempo) async {
    final t = await repo.tambah(TagihanCompanion.insert(
      nama: nama,
      jumlahSen: Value(sen),
      jatuhTempo: jatuhTempo,
      frekuensi: const Value('bulanan'),
      kodeMataUang: const Value('IDR'),
    ));
    return t.id;
  }

  test('seed kategori bawaan terisi (10 penyedia Indonesia)', () async {
    final k = await db.select(db.kategori).get();
    expect(k.length, 10);
    expect(k.map((e) => e.nama), contains('PLN'));
  });

  test('tambah & daftar tagihan aktif', () async {
    await tambahBulanan('Listrik PLN', 15000000, DateTime(2026, 9, 20));
    final semua = await repo.watchAktif().first;
    expect(semua.length, 1);
    expect(semua.first.nama, 'Listrik PLN');
    expect(semua.first.jumlahSen, 15000000);
    expect(semua.first.lunas, isFalse);
  });

  test('lunas -> riwayat tercatat & periode geser dgn day-clamping', () async {
    // 31 Jan -> Feb 2026 harus jadi 28 Feb
    final id = await tambahBulanan('PDAM', 7500000, DateTime(2026, 1, 31));
    await repo.tandaiLunas(id, tanggalBayar: DateTime(2026, 1, 29));

    final t = (await (db.select(db.tagihan)..where((x) => x.id.equals(id)))
        .getSingle());
    expect(t.jatuhTempo, DateTime(2026, 2, 28)); // day-clamping
    expect(t.lunas, isFalse); // siklus baru belum dibayar

    final riwayat = await db.select(db.riwayatPembayaran).get();
    expect(riwayat.length, 1);
    expect(riwayat.first.periodeJatuhTempo, DateTime(2026, 1, 31));
    expect(riwayat.first.telatHari, isNull); // dibayar sebelum jatuh tempo
  });

  test('lunas telat -> telatHari tercatat', () async {
    final id = await tambahBulanan('Internet', 30000000, DateTime(2026, 9, 1));
    await repo.tandaiLunas(id, tanggalBayar: DateTime(2026, 9, 5));
    final r = await db.select(db.riwayatPembayaran).getSingle();
    expect(r.telatHari, 4);
  });

  test('tagihan sekali -> lunas permanen & nonaktif', () async {
    final t = await repo.tambah(TagihanCompanion.insert(
      nama: 'Event sekali',
      jumlahSen: const Value(5000000),
      jatuhTempo: DateTime(2026, 9, 9),
      frekuensi: const Value('sekali'),
    ));
    await repo.tandaiLunas(t.id, tanggalBayar: DateTime(2026, 9, 9));
    final s = (await (db.select(db.tagihan)..where((x) => x.id.equals(t.id)))
        .getSingle());
    expect(s.lunas, isTrue);
    expect(s.statusAktif, isFalse);
  });

  test('undo lunas mengembalikan periode', () async {
    final id = await tambahBulanan('Pulsa', 5000000, DateTime(2026, 1, 31));
    await repo.tandaiLunas(id, tanggalBayar: DateTime(2026, 1, 29));
    await repo.undoLunas(id);
    final t = (await (db.select(db.tagihan)..where((x) => x.id.equals(id)))
        .getSingle());
    expect(t.jatuhTempo, DateTime(2026, 1, 31));
    expect(t.lunas, isFalse);
    expect(await db.select(db.riwayatPembayaran).get(), isEmpty);
  });

  test('watchJatuhTempoDalam hanya menangkap rentang & belum lunas', () async {
    final a = await tambahBulanan('H-1', 1000000, DateTime(2026, 9, 10));
    await tambahBulanan('H+30', 1000000, DateTime(2026, 10, 10));
    final list = await repo
        .watchJatuhTempoDalam(7, acuan: DateTime(2026, 9, 9))
        .first;
    expect(list.map((e) => e.id), [a]);

    // sudah lunas -> tidak muncul
    await repo.tandaiLunas(a, tanggalBayar: DateTime(2026, 9, 9));
    final list2 = await repo
        .watchJatuhTempoDalam(7, acuan: DateTime(2026, 9, 9))
        .first;
    expect(list2, isEmpty);
  });

  test('total bulan berjalan: B lunas -> siklus Okt keluar dari jendela Sep', () async {
    await tambahBulanan('A', 1000000, DateTime(2026, 9, 20));
    final b = await tambahBulanan('B', 2000000, DateTime(2026, 9, 21));
    expect(await repo.totalBelumBayarBulanSen(DateTime(2026, 9, 9)), 3000000);
    await repo.tandaiLunas(b, tanggalBayar: DateTime(2026, 9, 20));
    // B bergeser ke 21 Okt -> di luar September
    expect(await repo.totalBelumBayarBulanSen(DateTime(2026, 9, 9)), 1000000);
    // tapi masih kewajiban terbuka (totalTerbukaSen)
    expect(await repo.totalTerbukaSen(), 3000000);
  });

  test('totalTerbukaSen', () async {
    await tambahBulanan('A', 1000000, DateTime(2026, 9, 20));
    final b = await tambahBulanan('B', 2000000, DateTime(2026, 9, 21));
    expect(await repo.totalTerbukaSen(), 3000000);
    await repo.tandaiLunas(b, tanggalBayar: DateTime(2026, 9, 20));
    expect(await repo.totalTerbukaSen(), 3000000); // siklus baru B tetap terbuka
  });
}
