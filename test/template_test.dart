import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/utils/tanggal_utils.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/template_tagihan.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('template bawaan berisi 7 baris & semuanya wajar', () {
    expect(daftarTemplate.length, 7);
    expect(daftarTemplate.map((e) => e.nama), contains('Listrik PLN'));
    expect(daftarTemplate.every((e) => e.perkiraanSen > 0), isTrue);
    expect(daftarTemplate.every((e) => e.leadHari.isNotEmpty), isTrue);
  });

  test('isi dari template masuk ke database', () async {
    final n = await db.isiDariTemplate(daftarTemplate,
        tanggalAwal: DateTime(2026, 9, 15));
    expect(n, 7);
    final semua = await db.select(db.tagihan).get();
    expect(semua.length, 7);
    final pln = semua.firstWhere((e) => e.nama == 'Listrik PLN');
    expect(pln.jatuhTempo, DateTime(2026, 9, 15));
    expect(teksKeLead(pln.pengingatLeadHari), [7, 3, 1]);
    expect(pln.frekuensi, 'bulanan');
    expect(pln.kodeMataUang, 'IDR');
  });

  test('template tahunan memakai lead panjang', () async {
    await db.isiDariTemplate(
        daftarTemplate.where((e) => e.nama.contains('STNK')).toList(),
        tanggalAwal: DateTime(2026, 9, 15));
    final t = await db.select(db.tagihan).getSingle();
    expect(teksKeLead(t.pengingatLeadHari), [60, 30, 14, 7, 1]);
  });
}
