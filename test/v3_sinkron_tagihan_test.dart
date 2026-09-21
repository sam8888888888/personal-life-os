/// Uji sinkron TAGIHAN antar HP (FR-150 tahap 2) — dua perangkat, satu server.
///
/// Dua basis data terpisah = dua HP. Pengiriman disuntik dengan "server mini"
/// di dalam uji, jadi tidak butuh jaringan dan hasilnya pasti.
///
/// Yang dibuktikan:
/// 1. Tagihan baru di HP A muncul di HP B.
/// 2. Ubahan di HP B balik ke HP A.
/// 3. Hapus di HP A ikut terhapus di HP B.
/// 4. Dua HP membuat tagihan BERBEDA dengan id angka sama → keduanya selamat
///    (bukti uid mencegah saling menimpa).
/// 5. Ubah di waktu berbeda → yang lebih baru menang, tidak ada yang ganda.
/// 6. Sinkron kedua tidak mengirim ulang hal yang sama (kursor dihormati).
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/akun/klien_akun.dart';
import 'package:personal_life_os/core/sinkron/sinkron_tagihan.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';

/// Server mini: menyimpan catatan per akun, memberi nomor revisi, dan
/// menyelesaikan bentrok dengan aturan "waktu terbaru menang" (versi kalah
/// disimpan sebagai konflik, sama seperti server sungguhan).
class ServerMini {
  final Map<String, Map<String, Map<String, dynamic>>> catatan = {};
  final List<Map<String, dynamic>> konflik = [];
  int revisi = 0;

  Future<Map<String, dynamic>> kirim(
    String metode,
    String jalur, {
    Map<String, dynamic>? isi,
    String? token,
  }) async {
    final akun = token ?? 'tanpa-token';
    final peta = catatan.putIfAbsent(akun, () => {});
    if (jalur == '/sinkron') {
      final sejak = (isi?['sejak'] as num?)?.toInt() ?? 0;
      var diterima = 0;
      var bentrok = 0;
      for (final p in (isi?['perubahan'] as List? ?? const [])) {
        final b = p as Map<String, dynamic>;
        final kunci = '${b['tabel']}|${b['id_lokal']}';
        final lama = peta[kunci];
        if (lama != null &&
            (lama['waktu_klien'] as String)
                    .compareTo(b['waktu_klien'] as String) >
                0) {
          konflik.add({'kunci': kunci, 'waktu': b['waktu_klien']});
          bentrok++;
          continue;
        }
        revisi++;
        peta[kunci] = {...b, 'revisi': revisi};
        diterima++;
      }
      final tarikan = peta.values
          .where((r) => (r['revisi'] as int) > sejak)
          .toList()
        ..sort((a, b) => (a['revisi'] as int).compareTo(b['revisi'] as int));
      return {
        'diterima': diterima,
        'revisi': revisi,
        'konflik': bentrok,
        'perubahan': tarikan,
      };
    }
    if (jalur == '/masuk' || jalur == '/daftar') {
      return {
        'token': 'tok-uji',
        'akun': {'email': 'papi@uji.id', 'nama': 'Papi'},
      };
    }
    return const {};
  }
}

late AppDatabase hpA;
late AppDatabase hpB;
late ServerMini server;
late KlienAkun klien;

SinkronTagihan sinkron(AppDatabase db) => SinkronTagihan(
      db: db,
      tagihan: TagihanRepository(db),
      pengaturan: PengaturanRepository(db),
      klien: klien,
    );

Future<int> tambahTagihan(AppDatabase db, String nama, {int? jumlahSen}) async {
  final data = await TagihanRepository(db).tambah(TagihanCompanion.insert(
    nama: nama,
    jatuhTempo: DateTime(2026, 10, 5),
    jumlahSen: Value(jumlahSen ?? 100000),
  ));
  return data.id;
}

Future<List<String>> namaTagihan(AppDatabase db) async {
  final baris = await (db.select(db.tagihan)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  return baris.map((t) => t.nama).toList()..sort();
}

Future<void> sinkronkan(AppDatabase db) async {
  await sinkron(db).jalan(token: 'tok-uji');
}

void main() {
  setUp(() {
    hpA = AppDatabase.forTesting(NativeDatabase.memory());
    hpB = AppDatabase.forTesting(NativeDatabase.memory());
    server = ServerMini();
    klien = KlienAkun(pengirim: server.kirim);
  });

  tearDown(() async {
    await hpA.close();
    await hpB.close();
  });

  test('uid diisi otomatis saat tagihan dibuat', () async {
    await tambahTagihan(hpA, 'Listrik');
    final baris = await hpA.select(hpA.tagihan).get();
    expect(baris.single.uid, isNotNull);
    expect(baris.single.uid!.length, 32, reason: '16 byte heksadesimal');
  });

  test('tagihan baru di HP A muncul di HP B', () async {
    await tambahTagihan(hpA, 'Listrik');
    await sinkronkan(hpA);
    await sinkronkan(hpB);

    expect(await namaTagihan(hpB), ['Listrik']);
    final uidA = (await hpA.select(hpA.tagihan).get()).single.uid;
    final uidB = (await hpB.select(hpB.tagihan).get()).single.uid;
    expect(uidB, uidA, reason: 'kunci sama di kedua HP');
  });

  test('ubahan di HP B balik ke HP A', () async {
    await tambahTagihan(hpA, 'Listrik');
    await sinkronkan(hpA);
    await sinkronkan(hpB);

    final diB = (await hpB.select(hpB.tagihan).get()).single;
    await TagihanRepository(hpB).ubah(
        const TagihanCompanion(nama: Value('Listrik PLN')), id: diB.id);
    // Pastikan waktu ubah lebih baru dari pada saat dorongan pertama.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await sinkronkan(hpB);
    await sinkronkan(hpA);

    expect(await namaTagihan(hpA), ['Listrik PLN']);
  });

  test('hapus di HP A ikut terhapus di HP B', () async {
    await tambahTagihan(hpA, 'Internet');
    await sinkronkan(hpA);
    await sinkronkan(hpB);
    expect(await namaTagihan(hpB), ['Internet']);

    final diA = (await hpA.select(hpA.tagihan).get()).single;
    await TagihanRepository(hpA).hapus(diA.id);
    await sinkronkan(hpA);
    await sinkronkan(hpB);

    expect(await namaTagihan(hpB), isEmpty,
        reason: 'penghapusan harus ikut ke HP lain');
    expect(await (hpA.select(hpA.tagihan).get()), isEmpty);
  });

  test('dua HP membuat tagihan berbeda: keduanya selamat (uid, bukan id angka)',
      () async {
    // Keduanya mendapat id angka 1 di perangkatnya masing-masing.
    await tambahTagihan(hpA, 'Papi bayar listrik');
    await tambahTagihan(hpB, 'Mami bayar air');
    expect((await hpA.select(hpA.tagihan).get()).single.id, 1);
    expect((await hpB.select(hpB.tagihan).get()).single.id, 1);

    await sinkronkan(hpA);
    await sinkronkan(hpB);
    await sinkronkan(hpA); // A menarik kiriman B
    await sinkronkan(hpB);

    expect(await namaTagihan(hpA), ['Mami bayar air', 'Papi bayar listrik']);
    expect(await namaTagihan(hpB), ['Mami bayar air', 'Papi bayar listrik']);
  });

  test('bentrok: yang lebih baru menang, versi lama disimpan sebagai konflik',
      () async {
    await tambahTagihan(hpA, 'Asli');
    await sinkronkan(hpA);
    await sinkronkan(hpB);

    final diA = (await hpA.select(hpA.tagihan).get()).single;
    final diB = (await hpB.select(hpB.tagihan).get()).single;

    // A mengubah DULU (waktunya lebih tua), B mengubah belakangan (lebih baru).
    await TagihanRepository(hpA).ubah(
        const TagihanCompanion(nama: Value('Versi A lama')), id: diA.id);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await TagihanRepository(hpB).ubah(
        const TagihanCompanion(nama: Value('Versi B')), id: diB.id);

    await sinkronkan(hpB); // B (lebih baru) masuk duluan ke server
    await sinkronkan(hpA); // A menyusul dengan waktu lebih tua → konflik

    expect(server.konflik, hasLength(1));
    expect(server.konflik.single['waktu'], isNotNull);

    await sinkronkan(hpA); // A menarik versi B
    await sinkronkan(hpB);
    expect(await namaTagihan(hpA), ['Versi B']);
    expect(await namaTagihan(hpB), ['Versi B']);
  });

  test('sinkron kedua tidak mengirim ulang yang sudah sama', () async {
    await tambahTagihan(hpA, 'Air');
    final pertama = await sinkron(hpA).jalan(token: 'tok-uji');
    final kedua = await sinkron(hpA).jalan(token: 'tok-uji');
    expect(pertama.dikirim, 1);
    expect(kedua.dikirim, 0, reason: 'kursor dorong dihormati');
    expect(kedua.pesan, contains('Sudah sama'));
  });
}
