/// Uji sambung NYATA: dua "HP" (dua basis data) ↔ server sungguhan di Austria.
///
/// Beda dengan uji lain yang memakai server mini: uji ini benar-benar menembak
/// `https://coder.sam.university/lifeos-api` — jadi membuktikan aplikasi dan
/// server Papi cocok (nama bidang, arti revisi, aturan bentrok).
///
/// Dijalankan dengan: flutter test test/v3_sinkron_live_test.dart
/// Butuh internet. Kalau jaringan tidak ada, uji ini dilewati dengan catatan
/// (bukan gagal) — tidak ada klaim palsu.
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/akun/klien_akun.dart';
import 'package:personal_life_os/core/sinkron/sinkron_tagihan.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';
import 'package:personal_life_os/data/repository/tagihan_repository.dart';

SinkronTagihan mesin(AppDatabase db, KlienAkun klien) => SinkronTagihan(
      db: db,
      tagihan: TagihanRepository(db),
      pengaturan: PengaturanRepository(db),
      klien: klien,
    );

void main() {
  final klien = KlienAkun(namaPerangkat: 'uji-otomatis');
  late String token;

  setUpAll(() async {
    // Akun khusus uji, alamat unik supaya bisa dijalankan berkali-kali.
    final cap = DateTime.now().millisecondsSinceEpoch;
    try {
      final sesi = await klien.daftar(
        email: 'otomatis.$cap@lifeos.test',
        nama: 'Uji Otomatis',
        sandi: 'rahasia12345',
      );
      token = sesi.token;
    } on AkunGagal catch (e) {
      if (e.pesan.contains('Tidak bisa menghubungi server') ||
          e.pesan.contains('Server tidak menjawab')) {
        markTestSkipped('Server tidak terjangkau dari sini: ${e.pesan}');
        return;
      }
      rethrow;
    }
  });

  test('dua HP sungguhan: tagihan, ubahan, dan hapus berpindah lewat server', () async {
    if (token.isEmpty) {
      markTestSkipped('tanpa token (server tidak terjangkau)');
      return;
    }
    final hpA = AppDatabase.forTesting(NativeDatabase.memory());
    final hpB = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await hpA.close();
      await hpB.close();
    });

    // HP A membuat tagihan → server.
    await TagihanRepository(hpA).tambah(TagihanCompanion.insert(
      nama: 'Listrik Rumah',
      jatuhTempo: DateTime(2026, 11, 10),
      jumlahSen: const Value(275000),
    ));
    final hasilA = await mesin(hpA, klien).jalan(token: token);
    expect(hasilA.dikirim, greaterThan(0));

    // HP B menarik → harus muncul.
    await mesin(hpB, klien).jalan(token: token);
    var diB = await hpB.select(hpB.tagihan).get();
    expect(diB.map((t) => t.nama), contains('Listrik Rumah'),
        reason: 'tagihan dari HP A harus sampai ke HP B lewat server');

    // HP B mengubah → HP A menerima.
    final idB = diB.single.id;
    await Future<void>.delayed(const Duration(seconds: 1));
    await TagihanRepository(hpB)
        .ubah(const TagihanCompanion(nama: Value('Listrik Rumah (diubah HP B)')), id: idB);
    await mesin(hpB, klien).jalan(token: token);
    await mesin(hpA, klien).jalan(token: token);
    final diA = await hpA.select(hpA.tagihan).get();
    expect(diA.map((t) => t.nama), contains('Listrik Rumah (diubah HP B)'));

    // HP A menghapus → HP B ikut hilang.
    await TagihanRepository(hpA).hapus(diA.single.id);
    await mesin(hpA, klien).jalan(token: token);
    await mesin(hpB, klien).jalan(token: token);
    diB = await hpB.select(hpB.tagihan).get();
    expect(diB, isEmpty, reason: 'penghapusan harus ikut sampai ke HP B');
  });
}
