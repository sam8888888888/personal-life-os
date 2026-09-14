/// Uji PB-08 — riwayat pembayaran dipakai dasbor & kalender (occurrence).
///
/// Inti yang dijaga: setelah tagihan berulang dibayar, ia TIDAK boleh hilang dari
/// bulan aslinya. Bulan aslinya harus menampilkan "sudah dibayar", sedangkan
/// bulan berikutnya menampilkan kewajiban baru yang belum dibayar.
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/notifikasi/jejak.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';

late AppDatabase db;
late TagihanRepository repo;

Future<int> buatTagihan({
  String nama = 'Listrik PLN',
  int sen = 35000000,
  DateTime? jatuhTempo,
  String frekuensi = 'bulanan',
  bool lunas = false,
}) async {
  final t = await repo.tambah(TagihanCompanion.insert(
    nama: nama,
    jumlahSen: Value(sen),
    jatuhTempo: jatuhTempo ?? DateTime(2026, 9, 15),
    frekuensi: Value(frekuensi),
    lunas: Value(lunas),
  ));
  return t.id;
}

void main() {
  setUp(() async {
    penentuJejak = () async => null;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TagihanRepository(db);
  });

  tearDown(() async => db.close());

  test('PB-08: tagihan berulang yang sudah dibayar TETAP tampil di bulan aslinya',
      () async {
    final id = await buatTagihan(jatuhTempo: DateTime(2026, 9, 15));

    await repo.tandaiLunas(id,
        tanggalBayar: DateTime(2026, 9, 10),
        periodeYangDibayar: DateTime(2026, 9, 15));

    final september = await repo.periodeBulan(DateTime(2026, 9, 1));
    expect(september, hasLength(1), reason: 'pembayaran September tidak boleh hilang');
    final baris = september.first;
    expect(baris.nama, 'Listrik PLN');
    expect(baris.periode, DateTime(2026, 9, 15));
    expect(baris.jumlahSen, 35000000);
    expect(baris.lunas, isTrue);
    expect(baris.dariRiwayat, isTrue);
    expect(baris.tanggalBayar, DateTime(2026, 9, 10));
  });

  test('PB-08: ringkasan bulan aslinya menghitung yang sudah dibayar', () async {
    final id = await buatTagihan(jatuhTempo: DateTime(2026, 9, 15));
    await repo.tandaiLunas(id,
        tanggalBayar: DateTime(2026, 9, 10),
        periodeYangDibayar: DateTime(2026, 9, 15));

    final r = await repo.ringkasanBulan(DateTime(2026, 9, 1));
    expect(r.totalSen, 35000000);
    expect(r.dibayarSen, 35000000);
    expect(r.belumSen, 0);
    expect(r.jumlahBelum, 0);
  });

  test('PB-08: bulan berikutnya menampilkan kewajiban baru (belum dibayar)',
      () async {
    final id = await buatTagihan(jatuhTempo: DateTime(2026, 9, 15));
    await repo.tandaiLunas(id,
        tanggalBayar: DateTime(2026, 9, 10),
        periodeYangDibayar: DateTime(2026, 9, 15));

    final oktober = await repo.periodeBulan(DateTime(2026, 10, 1));
    expect(oktober, hasLength(1));
    expect(oktober.first.periode, DateTime(2026, 10, 15));
    expect(oktober.first.lunas, isFalse);
    expect(oktober.first.dariRiwayat, isFalse);
  });

  test('PB-08: tagihan belum dibayar + yang sudah dibayar tampil bersama',
      () async {
    final a = await buatTagihan(nama: 'Listrik PLN', jatuhTempo: DateTime(2026, 9, 15));
    await buatTagihan(nama: 'Air PDAM', sen: 12000000, jatuhTempo: DateTime(2026, 9, 20));

    await repo.tandaiLunas(a,
        tanggalBayar: DateTime(2026, 9, 10),
        periodeYangDibayar: DateTime(2026, 9, 15));

    final sept = await repo.periodeBulan(DateTime(2026, 9, 1));
    expect(sept, hasLength(2));
    final nama = sept.map((b) => b.nama).toList();
    expect(nama, containsAll(['Listrik PLN', 'Air PDAM']));
    final r = await repo.ringkasanBulan(DateTime(2026, 9, 1));
    expect(r.totalSen, 35000000 + 12000000);
    expect(r.dibayarSen, 35000000);
    expect(r.belumSen, 12000000);
    expect(r.jumlahBelum, 1);
  });

  test('PB-08: tagihan sekali (non-berulang) tetap tercatat sebagai dibayar',
      () async {
    final id = await buatTagihan(
        nama: 'STNK', sen: 50000000, frekuensi: 'sekali', jatuhTempo: DateTime(2026, 9, 5));
    await repo.tandaiLunas(id,
        tanggalBayar: DateTime(2026, 9, 5),
        periodeYangDibayar: DateTime(2026, 9, 5));

    final sept = await repo.periodeBulan(DateTime(2026, 9, 1));
    expect(sept, hasLength(1));
    expect(sept.first.lunas, isTrue);
    expect(sept.first.jumlahSen, 50000000);
  });
}
