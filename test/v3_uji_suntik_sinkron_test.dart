/// Audit keamanan 26 Sep 2026 — pemetaan temuan A-01.
///
/// TEMUAN: mesin sinkron menyusun perintah SQL memakai **nama kolom yang
/// datang dari luar** (payload server atau berkas sinkron kiriman orang lain).
/// Nilainya memang selalu lewat parameter `?`, tetapi nama kolomnya belum
/// disaring — sehingga nama kolom palsu bisa ikut menjadi perintah SQL
/// (suntikan lewat pengenal/identifier).
///
/// PERBAIKAN: `kolomSahTabel()` membaca daftar kolom asli dari skema Drift dan
/// dipakai sebagai daftar putih di `_terapkan()`.
///
/// Yang dibuktikan uji ini:
/// 1. Nama kolom palsu DIBUANG; baris yang sah tetap masuk dengan benar.
/// 2. Perintah yang disusupkan tidak pernah dijalankan (tabel & data utuh).
/// 3. Nilai dari luar tetap masuk lewat parameter — tanda kutip tetap teks.
/// 4. Daftar putih terisi untuk SEMUA jalur sinkron (tidak ada modul yang
///    diam-diam berhenti tersinkron karena saringan ini).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/akun/klien_akun.dart';
import 'package:personal_life_os/core/sinkron/registri_sinkron.dart';
import 'package:personal_life_os/core/sinkron/sinkron_semua.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';

/// Server tiruan yang bisa disuruh mengirim butir PALSU (meniru server yang
/// sudah dikuasai penyerang, atau berkas sinkron kiriman orang lain).
class ServerJahat {
  final List<Map<String, dynamic>> catatan = <Map<String, dynamic>>[];
  int revisi = 0;

  void sisipkan(Map<String, Object?> isi, {String tabel = 'kotak_masuk'}) {
    revisi++;
    catatan.add(<String, dynamic>{
      'tabel': tabel,
      'id_lokal': isi['uid'],
      'revisi': revisi,
      'waktu_klien': '2026-09-26T10:00:00.000Z',
      'dihapus': false,
      'isi': isi,
    });
  }

  Future<Map<String, dynamic>> kirim(String metode, String jalur,
      {Map<String, dynamic>? isi, String? token}) async {
    if (jalur != '/sinkron') return <String, dynamic>{'ok': true};
    final sejak = ((isi ?? const <String, dynamic>{})['sejak'] as num?)?.toInt() ?? 0;
    final tarik = catatan.where((c) => (c['revisi'] as int) > sejak).toList();
    return <String, dynamic>{
      'diterima': 0,
      'revisi': revisi,
      'konflik': 0,
      'perubahan': tarik,
    };
  }
}

void main() {
  late AppDatabase db;
  late ServerJahat server;
  late SinkronSemua sinkron;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = ServerJahat();
    sinkron = SinkronSemua(
      db: db,
      klien: KlienAkun(pengirim: server.kirim),
      pengaturan: PengaturanRepository(db),
    );
  });

  tearDown(() async => db.close());

  test('A-01 nama kolom palsu dibuang, baris sah tetap masuk', () async {
    server.sisipkan(<String, Object?>{
      'uid': 'u-baik-1',
      'isi': 'Belanja sayur',
      'sumber': 'layar',
      'jenis_media': 'teks',
      // Nama kolom jahat: kalau ikut masuk, SQL jadi
      //   INSERT INTO kotak_masuk (..., isi) VALUES (SUNTIKAN) -- ...
      'isi) VALUES (SUNTIKAN) --': 'x',
      'evil = 1 --': 'y',
      'nama_kolom_ngawur': 'z',
    });

    final hasil = await sinkron.jalan(token: 't');
    expect(hasil.diterapkan, greaterThan(0));

    final baris = await db.select(db.kotakMasuk).get();
    expect(baris.length, 1, reason: 'tepat satu baris, tidak ada baris sisipan');
    expect(baris.single.isi, 'Belanja sayur');
    expect(baris.single.uid, 'u-baik-1');

    // Tidak ada kolom baru yang tercipta dari nama palsu.
    final kolom = await db.customSelect('PRAGMA table_info(kotak_masuk)').get();
    final namaKolom = kolom.map((r) => r.read<String>('name')).toList();
    expect(namaKolom.where((n) => n.contains('SUNTIKAN')), isEmpty);
    expect(namaKolom.where((n) => n.contains('evil')), isEmpty);
    expect(namaKolom, contains('isi'));
  });

  test('A-01 nilai dari luar tetap lewat parameter (kutip jadi teks biasa)',
      () async {
    const jahat = "'; DROP TABLE kotak_masuk; --";
    server.sisipkan(<String, Object?>{
      'uid': 'u-baik-2',
      'isi': jahat,
      'sumber': 'layar',
      'jenis_media': 'teks',
    });

    await sinkron.jalan(token: 't');

    final baris = await db.select(db.kotakMasuk).get();
    expect(baris.single.isi, jahat, reason: 'disimpan apa adanya sebagai teks');
    // Tabelnya masih ada dan masih bisa dibaca.
    final hitung = await db.customSelect('SELECT COUNT(*) AS j FROM kotak_masuk').getSingle();
    expect(hitung.read<int>('j'), 1);
  });

  test('A-01 hapus: uid dari luar tidak dijalankan sebagai perintah', () async {
    await db.into(db.kotakMasuk).insert(KotakMasukCompanion.insert(
          uid: const Value('u-ada'),
          isi: const Value('Catatan asli'),
        ));
    // Dihapus=true tapi tabelnya ngawur → jalur `_cari` menolak, tidak ada SQL.
    server.revisi++;
    server.catatan.add(<String, dynamic>{
      'tabel': 'kotak_masuk; DROP TABLE kotak_masuk; --',
      'id_lokal': 'u-ada',
      'revisi': server.revisi,
      'waktu_klien': '2026-09-26T10:00:00.000Z',
      'dihapus': true,
      'isi': const <String, Object?>{},
    });

    await sinkron.jalan(token: 't');

    final baris = await db.select(db.kotakMasuk).get();
    expect(baris.length, 1, reason: 'tabel tidak dihapus, baris tetap ada');
    expect(baris.single.isi, 'Catatan asli');
  });

  test('A-01 daftar putih kolom terisi untuk SEMUA 75 jalur sinkron', () async {
    // Sumbernya registri, bukan isi basis data: uji ini harus tetap berlaku
    // walau basis data masih kosong.
    final jalur = daftarJalurSinkron(db);
    expect(jalur.length, greaterThan(50),
        reason: 'registri sinkron seharusnya memuat puluhan jalur');
    final kosong = <String>[];
    for (final j in jalur) {
      if (sinkron.kolomSahTabel(j.nama).isEmpty) kosong.add(j.nama);
    }
    expect(kosong, isEmpty,
        reason: 'jalur tanpa daftar putih akan diam-diam berhenti tersinkron: '
            '${kosong.join(", ")}');
  });
}
