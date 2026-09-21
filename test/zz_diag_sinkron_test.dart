/// DIAGNOSTIK SEMENTARA — kenapa penghapusan tidak sampai ke HP B? (v2)
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/akun/klien_akun.dart';
import 'package:personal_life_os/core/sinkron/sinkron_tagihan.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';

class ServerMini2 {
  final Map<String, Map<String, Map<String, dynamic>>> catatan = {};
  int revisi = 0;

  Future<Map<String, dynamic>> kirim(String metode, String jalur,
      {Map<String, dynamic>? isi, String? token}) async {
    final peta = catatan.putIfAbsent(token ?? '-', () => {});
    final sejak = (isi?['sejak'] as num?)?.toInt() ?? 0;
    for (final p in (isi?['perubahan'] as List? ?? const [])) {
      final b = (p as Map).cast<String, dynamic>();
      final kunci = '${b['tabel']}|${b['id_lokal']}';
      final lama = peta[kunci];
      final ditolak = lama != null &&
          (lama['waktu_klien'] as String)
                  .compareTo(b['waktu_klien'] as String) >
              0;
      print('  terima $kunci hapus=${b['dihapus']} waktu=${b['waktu_klien']} '
          '| lama=${lama?['waktu_klien']} → ${ditolak ? "BENTROK" : "disimpan"}');
      if (ditolak) continue;
      revisi++;
      peta[kunci] = {...b, 'revisi': revisi};
    }
    final tarikan = peta.values.where((r) => (r['revisi'] as int) > sejak).toList()
      ..sort((a, b) => (a['revisi'] as int).compareTo(b['revisi'] as int));
    print('  kembali ke klien (sejak=$sejak): '
        '${tarikan.map((r) => 'rev${r['revisi']}/hapus=${r['dihapus']}').toList()}');
    return {'diterima': 0, 'revisi': revisi, 'konflik': 0, 'perubahan': tarikan};
  }
}

void main() {
  test('diagnostik hapus v2', () async {
    final hpA = AppDatabase.forTesting(NativeDatabase.memory());
    final hpB = AppDatabase.forTesting(NativeDatabase.memory());
    final server = ServerMini2();
    final klien = KlienAkun(pengirim: server.kirim);

    SinkronTagihan s(AppDatabase db) => SinkronTagihan(
        db: db,
        tagihan: TagihanRepository(db),
        pengaturan: PengaturanRepository(db),
        klien: klien);

    print('1) A tambah');
    await TagihanRepository(hpA).tambah(TagihanCompanion.insert(
        nama: 'Internet', jatuhTempo: DateTime(2026, 10, 5)));
    print('   penanda di A: ${(await hpA.select(hpA.sinkronKotor).get()).map((k) => '${k.uid}/hapus=${k.hapus}').toList()}');

    print('2) A sinkron → ${(await s(hpA).jalan(token: 't')).pesan}');
    print('   penanda di A setelah sinkron: ${(await hpA.select(hpA.sinkronKotor).get()).length}');
    print('3) B sinkron → ${(await s(hpB).jalan(token: 't')).pesan}');
    print('   B punya: ${(await hpB.select(hpB.tagihan).get()).map((t) => '${t.nama}/uid=${t.uid}').toList()}');

    print('4) A hapus');
    final diA = (await hpA.select(hpA.tagihan).get()).single;
    await TagihanRepository(hpA).hapus(diA.id);
    print('   penanda di A: ${(await hpA.select(hpA.sinkronKotor).get()).map((k) => '${k.uid}/hapus=${k.hapus}@${k.waktu}').toList()}');
    print('   tagihan di A: ${(await hpA.select(hpA.tagihan).get()).length}');

    print('5) A sinkron → ${(await s(hpA).jalan(token: 't')).pesan}');
    print('6) B sinkron → ${(await s(hpB).jalan(token: 't')).pesan}');
    print('   B punya: ${(await hpB.select(hpB.tagihan).get()).map((t) => t.nama).toList()}');
    print('   kursor B: revisi=${await PengaturanRepository(hpB).baca(SinkronTagihan.kunciRevisi)}');

    await hpA.close();
    await hpB.close();
  });
}
