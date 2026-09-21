/// FR-150 (lanjutan, 22 Sep 2026) — sinkron SEMUA MODUL, bukan hanya tagihan.
///
/// Uji ini memakai DUA basis data (HP A & HP B) dan server tiruan yang meniru
/// perilaku server sungguhan: nomor revisi, penyaringan sejak revisi terakhir,
/// dan konflik yang versi kalahnya DISIMPAN.
///
/// Yang dibuktikan (bukan diklaim):
/// 1. Data pindah dari HP A ke HP B (tabel lama seperti aset sekalipun, yang
///    uid-nya diisi otomatis oleh mesin sinkron).
/// 2. Kaitan antar tabel (riwayat pembayaran → tagihan) dipetakan ke **id lokal**
///    HP penerima, bukan menunjuk baris yang salah.
/// 3. Hapus di satu HP ikut hilang di HP lain.
/// 4. Sinkron kedua tidak mengirim apa-apa — tidak ada pantulan.
/// 5. Kategori bawaan sistem tidak berlipat ganda.
/// 6. Versi yang kalah pada bentrok disimpan di server (tidak hilang).
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/akun/klien_akun.dart';
import 'package:personal_life_os/core/sinkron/sinkron_semua.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/pengaturan_repository.dart';

/// Server sinkron tiruan — perilaku sama dengan `/sinkron` di server Papi.
class ServerTiruan {
  final List<Map<String, dynamic>> catatan = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> konflik = <Map<String, dynamic>>[];
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
    var konflikBaru = 0;
    for (final p in (data['perubahan'] as List?) ?? const []) {
      final m = (p as Map).cast<String, dynamic>();
      final lama = catatan.firstWhere(
        (c) => c['tabel'] == m['tabel'] && c['id_lokal'] == m['id_lokal'],
        orElse: () => <String, dynamic>{},
      );
      if (lama.isNotEmpty &&
          '${lama['waktu_klien']}'.compareTo('${m['waktu_klien']}') > 0) {
        // Versi di server lebih baru → kiriman ini kalah, tapi tetap disimpan.
        konflik.add(<String, dynamic>{...m});
        konflikBaru++;
        continue;
      }
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
    final tarik = catatan
        .where((c) => (c['revisi'] as int) > sejak)
        .toList()
      ..sort((x, y) => (x['revisi'] as int).compareTo(y['revisi'] as int));
    return <String, dynamic>{
      'diterima': diterima,
      'revisi': revisi,
      'konflik': konflikBaru,
      'perubahan': tarik,
    };
  }
}

void main() {
  late AppDatabase a;
  late AppDatabase b;
  late ServerTiruan server;
  late SinkronSemua sa;
  late SinkronSemua sb;

  setUp(() {
    a = AppDatabase.forTesting(NativeDatabase.memory());
    b = AppDatabase.forTesting(NativeDatabase.memory());
    server = ServerTiruan();
    sa = SinkronSemua(
      db: a,
      klien: KlienAkun(pengirim: server.kirim),
      pengaturan: PengaturanRepository(a),
    );
    sb = SinkronSemua(
      db: b,
      klien: KlienAkun(pengirim: server.kirim),
      pengaturan: PengaturanRepository(b),
    );
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  test('FR-150 tabel lama (aset) & tagihan pindah ke HP kedua, uid terisi', () async {
    await a.into(a.tagihan).insert(TagihanCompanion.insert(
          nama: 'Listrik',
          jatuhTempo: DateTime(2026, 9, 25),
        ));
    await a.into(a.aset).insert(AsetCompanion.insert(
          idAset: 'AS-1',
          nama: 'Motor Vario',
        ));

    final kirim = await sa.jalan(token: 't');
    expect(kirim.dikirim, greaterThan(0));

    final terima = await sb.jalan(token: 't');
    expect(terima.diterapkan, greaterThan(0));

    final tagihanB = await b.select(b.tagihan).getSingle();
    expect(tagihanB.nama, 'Listrik');
    expect(tagihanB.uid, isNotNull, reason: 'uid diisi mesin sinkron');

    final asetB = await b.select(b.aset).getSingle();
    expect(asetB.nama, 'Motor Vario');
    expect(asetB.uid, isNotNull);

    // uid kedua HP harus SAMA (pengenal yang sama, bukan baris kembar).
    final tagihanA = await a.select(a.tagihan).getSingle();
    expect(tagihanB.uid, tagihanA.uid);
  });

  test('FR-150 kaitan pembayaran → tagihan dipetakan ke id lokal HP penerima', () async {
    // HP B sudah punya tagihan sendiri, jadi id lokalnya berbeda dari HP A.
    await b.into(b.tagihan).insert(TagihanCompanion.insert(
          nama: 'Air',
          jatuhTempo: DateTime(2026, 9, 20),
        ));

    final idTagihanA = await a.into(a.tagihan).insert(TagihanCompanion.insert(
          nama: 'Listrik',
          jatuhTempo: DateTime(2026, 9, 25),
        ));
    await a.into(a.riwayatPembayaran).insert(RiwayatPembayaranCompanion.insert(
          tagihanId: idTagihanA,
          periodeJatuhTempo: DateTime(2026, 9, 25),
          jumlahSen: 250000,
          tanggalBayar: DateTime(2026, 9, 22),
        ));

    await sa.jalan(token: 't');
    await sb.jalan(token: 't');

    final listrikB = await (b.select(b.tagihan)
          ..where((t) => t.nama.equals('Listrik')))
        .getSingle();
    final bayarB = await b.select(b.riwayatPembayaran).getSingle();
    expect(bayarB.jumlahSen, 250000);
    expect(bayarB.tagihanId, listrikB.id,
        reason: 'kaitan harus menunjuk tagihan lokal HP B, bukan id HP A');
  });

  test('FR-150 hapus di HP A ikut hilang di HP B', () async {
    await a.into(a.tagihan).insert(TagihanCompanion.insert(
          nama: 'Internet',
          jatuhTempo: DateTime(2026, 9, 28),
        ));
    await sa.jalan(token: 't');
    await sb.jalan(token: 't');
    expect(await b.select(b.tagihan).get(), hasLength(1));

    await (a.delete(a.tagihan)).go();
    await sa.jalan(token: 't');
    await sb.jalan(token: 't');
    expect(await b.select(b.tagihan).get(), isEmpty);
  });

  test('FR-150 sinkron kedua tidak mengirim apa-apa (tidak ada pantulan)', () async {
    await a.into(a.tagihan).insert(TagihanCompanion.insert(
          nama: 'PDAM',
          jatuhTempo: DateTime(2026, 9, 27),
        ));
    await sa.jalan(token: 't');
    await sb.jalan(token: 't');

    final ulang = await sb.jalan(token: 't');
    expect(ulang.dikirim, 0, reason: 'baris yang baru diterima tidak dikirim balik');
    expect(ulang.pesan, contains('Sudah sama'));
  });

  test('FR-150 kategori bawaan sistem tidak ikut berlipat', () async {
    final jmlA = (await a.select(a.kategoriTransaksi).get()).length;
    expect(jmlA, greaterThan(0), reason: 'kategori bawaan memang ada');

    await sa.jalan(token: 't');
    final terima = await sb.jalan(token: 't');
    expect(terima.diterapkan, 0,
        reason: 'kategori bawaan tidak boleh disalin (sudah ada di tiap HP)');
    expect((await b.select(b.kategoriTransaksi).get()).length, jmlA);
  });

  test('FR-150 versi yang kalah saat bentrok disimpan di server', () async {
    await a.into(a.tagihan).insert(TagihanCompanion.insert(
          nama: 'Gas',
          jatuhTempo: DateTime(2026, 9, 26),
        ));
    await sa.jalan(token: 't');
    await sb.jalan(token: 't');

    // Server tiruan dibuat menyimpan versi yang lebih baru dari kiriman HP B.
    final catatan = server.catatan.firstWhere((c) => c['tabel'] == 'tagihan');
    catatan['waktu_klien'] = '2099-01-01T00:00:00.000Z';

    // HP B mengubah isi tanpa memperbarui kolom diubah_pada (skenario "versi lama").
    await b.customStatement("UPDATE tagihan SET nama = 'Gas 3 kg'");
    final hasil = await sb.jalan(token: 't');

    expect(hasil.konflik, greaterThan(0));
    expect(server.konflik, isNotEmpty, reason: 'versi kalah tetap disimpan');
    expect(server.konflik.first['isi']['nama'], 'Gas 3 kg');
  });
}
