import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/utils/tanggal_utils.dart';
import 'package:personal_life_os/core/utils/uang_utils.dart';
import 'package:personal_life_os/data/model/enums.dart';

void main() {
  group('tambahBulan (day-clamping — PRD §10.3)', () {
    test('31 Jan + 1 bln = 28 Feb 2026 (bukan kabisat)', () {
      expect(tambahBulan(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    });
    test('31 Jan + 1 bln = 29 Feb 2028 (kabisat)', () {
      expect(tambahBulan(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    });
    test('31 Jan + 2 bln = 31 Mar (bulan 31 hari pulih)', () {
      expect(tambahBulan(DateTime(2026, 1, 31), 2), DateTime(2026, 3, 31));
    });
    test('30 Apr + 1 bln = 30 Jun (30 -> 30)', () {
      expect(tambahBulan(DateTime(2026, 4, 30), 1), DateTime(2026, 5, 30));
    });
    test('menyeberang tahun: Nov + 3 = Feb tahun depan', () {
      expect(tambahBulan(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
    });
  });

  group('periodeBerikutnya', () {
    test('bulanan', () {
      expect(periodeBerikutnya(DateTime(2026, 9, 9), Frekuensi.bulanan), DateTime(2026, 10, 9));
    });
    test('tahunan', () {
      expect(periodeBerikutnya(DateTime(2026, 9, 9), Frekuensi.tahunan), DateTime(2027, 9, 9));
    });
    test('kustom 45 hari', () {
      expect(periodeBerikutnya(DateTime(2026, 9, 9), Frekuensi.kustomHari, kustomHariN: 45), DateTime(2026, 10, 24));
    });
    test('sekali = tetap (tidak berulang)', () {
      expect(periodeBerikutnya(DateTime(2026, 9, 9), Frekuensi.sekali), DateTime(2026, 9, 9));
    });
  });

  group('tanggalPengingat (lead)', () {
    test('lead 3 hari sebelum jatuh tempo', () {
      expect(tanggalPengingat(DateTime(2026, 9, 20), 3), DateTime(2026, 9, 17));
    });
    test('lead 0 = hari-H', () {
      expect(tanggalPengingat(DateTime(2026, 9, 20), 0), DateTime(2026, 9, 20));
    });
  });

  group('lead ke teks & balik', () {
    test('round-trip', () {
      expect(teksKeLead(leadKeTeks([7, 3, 1])), [7, 3, 1]);
    });
    test('input acak diurutkan menurun & unik', () {
      expect(teksKeLead('3,7,3,1'), [7, 3, 1]);
    });
    test('nilai buruk dibuang', () {
      expect(teksKeLead('abc,,-1,400,5'), [5]);
    });
  });

  group('parseTanggal', () {
    test('ISO yyyy-MM-dd', () {
      expect(parseTanggal('2026-09-09'), DateTime(2026, 9, 9));
    });
    test('dd/MM/yyyy', () {
      expect(parseTanggal('09/09/2026'), DateTime(2026, 9, 9));
    });
    test('dd-MM-yy -> tahun 2000an', () {
      expect(parseTanggal('31-12-28'), DateTime(2028, 12, 31));
    });
    test('tanggal mustahil -> null', () {
      expect(parseTanggal('31/02/2026'), isNull);
    });
  });

  group('uang', () {
    test('format Rp', () {
      expect(fmtRp(1250000), 'Rp 1.250.000');
    });
    test('parse titik ribuan', () {
      expect(parseRupiah('1.250.000'), 1250000);
    });
    test('parse dengan Rp', () {
      expect(parseRupiah('Rp 150.000'), 150000);
    });
    test('parse "150rb"', () {
      expect(parseRupiah('150rb'), 150000);
    });
    test('parse "2jt"', () {
      expect(parseRupiah('2jt'), 2000000);
    });
    test('parse koma desimal', () {
      expect(parseRupiah('1.250,5'), 1250.5);
    });
    test('teks bukan uang -> null', () {
      expect(parseRupiah('abc'), isNull);
    });
  });
}
