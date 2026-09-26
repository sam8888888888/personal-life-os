/// S-13 (audit keamanan 26 Sep 2026) — enkripsi isi data sinkron.
///
/// Yang dibuktikan di sini, bukan diklaim:
/// 1. Penyandian AES-256-GCM benar-benar berputar balik (teks & peta isi).
/// 2. Kunci berbeda / isi diubah → TIDAK bisa dibuka (tidak diam-diam salah).
/// 3. Amplop kunci: sandi benar membuka, sandi salah tidak.
/// 4. Server TIDAK PERNAH menerima isi catatan polos — yang tersimpan di
///    server hanya sandi acak (uji mencari nama tagihan di dalam catatan
///    server: tidak ketemu).
/// 5. HP kedua dengan kunci yang sama menerapkan datanya dengan benar.
/// 6. HP yang belum punya kunci MELEWATI catatan tersandi (tidak menulis data
///    kosong) dan mengatakannya apa adanya.
/// 7. Penyiapan kunci: perangkat pertama membuat & mengirim amplop; perangkat
///    kedua memakai amplop itu; sandi salah dilaporkan, tidak dibuatkan kunci
///    baru.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/akun/klien_akun.dart';
import 'package:personal_life_os/core/platform/brankas_rahasia.dart';
import 'package:personal_life_os/core/sinkron/enkripsi_sinkron.dart';
import 'package:personal_life_os/core/sinkron/kunci_sinkron.dart';
import 'package:personal_life_os/core/sinkron/sinkron_semua.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';

import 'bantuan/gudang_memori.dart';

/// Server sinkron tiruan (perilaku sama dengan `/sinkron` server Papi).
class ServerSinkron {
  final List<Map<String, dynamic>> catatan = <Map<String, dynamic>>[];
  int revisi = 0;

  Future<Map<String, dynamic>> kirim(
    String metode,
    String jalur, {
    Map<String, dynamic>? isi,
    String? token,
  }) async {
    if (jalur != '/sinkron') return <String, dynamic>{'ok': true};
    final data = isi ?? const <String, dynamic>{};
    var diterima = 0;
    for (final p in (data['perubahan'] as List?) ?? const []) {
      final m = (p as Map).cast<String, dynamic>();
      final lama = catatan.firstWhere(
        (c) => c['tabel'] == m['tabel'] && c['id_lokal'] == m['id_lokal'],
        orElse: () => <String, dynamic>{},
      );
      if (lama.isNotEmpty) catatan.remove(lama);
      revisi++;
      catatan.add(<String, dynamic>{
        'tabel': m['tabel'],
        'id_lokal': m['id_lokal'],
        'revisi': revisi,
        'waktu_klien': m['waktu_klien'],
        'dihapus': m['dihapus'],
        'isi': m['isi'],
      });
      diterima++;
    }
    final sejak = (data['sejak'] as num?)?.toInt() ?? 0;
    final tarik = catatan.where((c) => (c['revisi'] as int) > sejak).toList()
      ..sort((x, y) => (x['revisi'] as int).compareTo(y['revisi'] as int));
    return <String, dynamic>{
      'diterima': diterima,
      'revisi': revisi,
      'konflik': 0,
      'perubahan': tarik,
    };
  }

  Map<String, dynamic>? catatanTabel(String tabel) {
    for (final c in catatan) {
      if (c['tabel'] == tabel) return c;
    }
    return null;
  }
}

void main() {
  group('A. penyandian isi', () {
    test('teks berputar balik; kunci lain & isi diubah tidak bisa dibuka', () {
      final kunci = kunciDataBaru();
      final lain = kunciDataBaru();
      expect(kunci.length, 32);

      final amplop = sandikan(kunci, 'Listrik 250.000');
      expect(amplop.startsWith(awalanTeksTersandi), isTrue);
      expect(bukaSandian(kunci, amplop), 'Listrik 250.000');
      expect(bukaSandian(lain, amplop), isNull,
          reason: 'kunci berbeda tidak boleh bisa membuka');

      // Isi diubah satu huruf → GCM menolak (terotentikasi).
      final badan = amplop.substring(awalanTeksTersandi.length);
      final rusak = String.fromCharCodes(
        badan.codeUnits.map((c) => c == 'A'.codeUnitAt(0) ? 'B'.codeUnitAt(0) : c),
      );
      expect(bukaSandian(kunci, '$awalanTeksTersandi$rusak'), isNull);
      expect(bukaSandian(kunci, 'bukan-amplop'), isNull);
    });

    test('dua kali menyandikan teks sama menghasilkan sandi BERBEDA (nonce acak)', () {
      final kunci = kunciDataBaru();
      expect(sandikan(kunci, 'sama'), isNot(sandikan(kunci, 'sama')));
    });

    test('peta isi: polos dilewatkan (data lama), tersandi dibuka', () {
      final kunci = kunciDataBaru();
      final polos = <String, Object?>{'nama': 'Listrik', 'nominal_sen': 25000000};
      expect(bukaPetaTersandi(kunci, polos), polos,
          reason: 'catatan lama tanpa penanda tetap dibaca apa adanya');

      final tersandi = sandikanPeta(kunci, polos);
      expect(tersandi.keys, <String>[kunciIsiTersandi]);
      expect(bukaPetaTersandi(kunci, tersandi), polos);
      expect(bukaPetaTersandi(kunciDataBaru(), tersandi), isNull);
    });
  });

  group('B. amplop kunci data', () {
    test('sandi benar membuka, sandi salah tidak; putaran ikut tersimpan', () {
      final kunci = kunciDataBaru();
      final amplop = bungkusKunci(kunci, 'sandi-akun-123', putaran: 2000);
      expect(amplop.startsWith(awalanAmplopKunci), isTrue);
      expect(bukaBungkusKunci(amplop, 'sandi-akun-123'), kunci);
      expect(bukaBungkusKunci(amplop, 'sandi-akun-124'), isNull);
      expect(bukaBungkusKunci('plok1:zzz', 'sandi-akun-123'), isNull);
      expect(bukaBungkusKunci('bentuk-lain', 'sandi-akun-123'), isNull);
    });

    test('amplop yang menyatakan putaran ngawur ditolak (tidak dihitung lama)', () {
      final kunci = kunciDataBaru();
      final amplop = bungkusKunci(kunci, 'sandi-akun-123', putaran: 2000);
      final mentah = base64Decode(amplop.substring(awalanAmplopKunci.length));
      // Putaran ditulis 4 byte tepat sesudah garam 16 byte → jadikan 0xFFFFFFFF.
      for (var i = 16; i < 20; i++) {
        mentah[i] = 0xff;
      }
      expect(bukaBungkusKunci('$awalanAmplopKunci${base64Encode(mentah)}',
          'sandi-akun-123'), isNull);
    });
  });

  group('C. mesin sinkron menyandikan isi', () {
    late AppDatabase a;
    late AppDatabase b;
    late AppDatabase c;
    late ServerSinkron server;
    late SinkronSemua sa;
    late SinkronSemua sb;
    late SinkronSemua sc;
    late List<int> kunci;

    setUp(() {
      a = AppDatabase.forTesting(NativeDatabase.memory());
      b = AppDatabase.forTesting(NativeDatabase.memory());
      c = AppDatabase.forTesting(NativeDatabase.memory());
      server = ServerSinkron();
      kunci = kunciDataBaru();
      sa = SinkronSemua(
        db: a,
        klien: KlienAkun(pengirim: server.kirim),
        pengaturan: PengaturanRepository(a),
      )..pakaiKunci(kunci);
      sb = SinkronSemua(
        db: b,
        klien: KlienAkun(pengirim: server.kirim),
        pengaturan: PengaturanRepository(b),
      )..pakaiKunci(kunci);
      sc = SinkronSemua(
        db: c,
        klien: KlienAkun(pengirim: server.kirim),
        pengaturan: PengaturanRepository(c),
      );
    });

    tearDown(() async {
      await a.close();
      await b.close();
      await c.close();
    });

    test('server hanya menerima sandi acak, bukan isi catatan', () async {
      await a.into(a.tagihan).insert(TagihanCompanion.insert(
            nama: 'Listrik PLN',
            jatuhTempo: DateTime(2026, 9, 25),
          ));
      expect(sa.terenkripsi, isTrue);
      await sa.jalan(token: 't');

      final rekaman = server.catatanTabel('tagihan');
      expect(rekaman, isNotNull);
      final isi = (rekaman!['isi'] as Map).cast<String, Object?>();
      expect(isi.keys, <String>[kunciIsiTersandi],
          reason: 'isi polos tidak boleh ikut terkirim');
      expect(jsonEncode(rekaman), isNot(contains('Listrik')),
          reason: 'nama tagihan tidak boleh terbaca di server');
    });

    test('HP kedua dengan kunci sama menerapkan datanya', () async {
      await a.into(a.tagihan).insert(TagihanCompanion.insert(
            nama: 'Listrik PLN',
            jatuhTempo: DateTime(2026, 9, 25),
          ));
      await sa.jalan(token: 't');

      final terima = await sb.jalan(token: 't');
      expect(terima.diterapkan, greaterThan(0));
      final baris = await b.select(b.tagihan).getSingle();
      expect(baris.nama, 'Listrik PLN');
    });

    test('HP tanpa kunci: catatan tersandi DILEWATI dan dikatakan apa adanya',
        () async {
      await a.into(a.tagihan).insert(TagihanCompanion.insert(
            nama: 'Listrik PLN',
            jatuhTempo: DateTime(2026, 9, 25),
          ));
      await sa.jalan(token: 't');

      final terima = await sc.jalan(token: 't');
      expect(terima.diterapkan, 0);
      expect(await c.select(c.tagihan).get(), isEmpty,
          reason: 'jangan menulis baris kosong dari catatan yang tidak terbuka');
      expect(terima.pesan, contains('tidak bisa dibuka'));
    });

    test('kunci salah: catatan tetap tidak terbaca (bukan data palsu)', () async {
      await a.into(a.tagihan).insert(TagihanCompanion.insert(
            nama: 'Listrik PLN',
            jatuhTempo: DateTime(2026, 9, 25),
          ));
      await sa.jalan(token: 't');

      sb.pakaiKunci(kunciDataBaru());
      final terima = await sb.jalan(token: 't');
      expect(terima.diterapkan, 0);
      expect(await b.select(b.tagihan).get(), isEmpty);
    });
  });

  group('D. penyiapan kunci data', () {
    late ServerSinkron server;
    late GudangMemori brankas;
    late KunciSinkron pengelola;

    setUp(() {
      server = ServerSinkron();
      brankas = GudangMemori();
      pengelola = KunciSinkron(PenyimpanRahasia(
        PengaturanRepository(AppDatabase.forTesting(NativeDatabase.memory())),
        gudang: brankas,
      ));
    });

    test('perangkat pertama membuat & mengirim amplop; yang kedua membukanya',
        () async {
      final klien = KlienAkun(pengirim: server.kirim);
      final kunciA = await pengelola.siapkan(
        klien: klien,
        token: 't',
        email: 'papi@contoh.id',
        sandi: 'sandi-rahasia-123',
      );
      expect(kunciA.length, 32);
      final amplop = server.catatanTabel(tabelAmplopKunci);
      expect(amplop, isNotNull, reason: 'amplop harus ikut terkirim');

      // Perangkat kedua: brankas kosong, sandi sama → kunci sama.
      final brankas2 = GudangMemori();
      final pengelola2 = KunciSinkron(PenyimpanRahasia(
        PengaturanRepository(AppDatabase.forTesting(NativeDatabase.memory())),
        gudang: brankas2,
      ));
      final kunciB = await pengelola2.siapkan(
        klien: klien,
        token: 't',
        email: 'papi@contoh.id',
        sandi: 'sandi-rahasia-123',
      );
      expect(kunciB, kunciA, reason: 'kunci data harus sama antar perangkat');
    });

    test('sandi salah dilaporkan, TIDAK dibuatkan kunci baru', () async {
      final klien = KlienAkun(pengirim: server.kirim);
      await pengelola.siapkan(
        klien: klien,
        token: 't',
        email: 'papi@contoh.id',
        sandi: 'sandi-rahasia-123',
      );
      final jumlahCatatan = server.catatan.length;

      final brankas2 = GudangMemori();
      final pengelola2 = KunciSinkron(PenyimpanRahasia(
        PengaturanRepository(AppDatabase.forTesting(NativeDatabase.memory())),
        gudang: brankas2,
      ));
      await expectLater(
        pengelola2.siapkan(
          klien: klien,
          token: 't',
          email: 'papi@contoh.id',
          sandi: 'sandi-yang-salah-x',
        ),
        throwsA(isA<AkunGagal>()),
      );
      expect(server.catatan.length, jumlahCatatan,
          reason: 'tidak boleh mengirim amplop baru saat sandi salah');
    });

    test('kunci tersimpan dipakai ulang tanpa memanggil jaringan', () async {
      final klien = KlienAkun(pengirim: server.kirim);
      await pengelola.siapkan(
        klien: klien,
        token: 't',
        email: 'papi@contoh.id',
        sandi: 'sandi-rahasia-123',
      );
      final jumlahCatatan = server.catatan.length;
      final lagi = await pengelola.siapkan(
        klien: klien,
        token: 't',
        email: 'papi@contoh.id',
        sandi: 'sandi-rahasia-123',
      );
      expect(lagi.length, 32);
      expect(server.catatan.length, jumlahCatatan);
      expect(await pengelola.kunciTersimpan('papi@contoh.id'), lagi);
    });
  });
}
