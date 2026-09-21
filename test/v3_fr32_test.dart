/// Uji FR-32 — Ringkasan harian pagi (tagihan hari ini & besok + total).
///
/// Yang dibuktikan lewat perencana pengingat yang sudah ada: notifikasi briefing
/// benar-benar memuat jumlah & total untuk HARI INI dan BESOK, dan tetap ramah
/// saat tidak ada tagihan sama sekali.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/notifikasi/model_pengingat.dart';
import 'package:personal_life_os/core/notifikasi/perencana_pengingat.dart';
import 'package:personal_life_os/data/database/database.dart';

late AppDatabase db;

TagihanData tagihanUji({
  required int id,
  required String nama,
  required DateTime jatuhTempo,
  int jumlahSen = 100000,
  bool aktif = true,
  bool lunas = false,
}) =>
    TagihanData(
      id: id,
      jenis: 'tagihan',
      nama: nama,
      jumlahSen: jumlahSen,
      kodeMataUang: 'IDR',
      jatuhTempo: jatuhTempo,
      frekuensi: 'sekali',
      pengingatLeadHari: '0',
      pengingatJam: '06:00',
      kanalPengingat: 'push',
      prioritas: 'biasa',
      statusAktif: aktif,
      lunas: lunas,
      dibuatPada: DateTime(2026, 1, 1),
      diubahPada: DateTime(2026, 1, 1),
    );

/// Ambil pengingat briefing untuk hari [tanggal] (paling awal dari daftar).
Pengingat? briefingUntuk(List<Pengingat> daftar, DateTime tanggal) {
  for (final p in daftar) {
    if (p.kanal == KanalNotifikasi.briefing &&
        p.waktu.year == tanggal.year &&
        p.waktu.month == tanggal.month &&
        p.waktu.day == tanggal.day) {
      return p;
    }
  }
  return null;
}

void main() {
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final sekarang = DateTime(2026, 9, 21, 5, 0);

  test('briefing menyebut hari ini & besok beserta totalnya', () {
    final rencana = const PerencanaPengingat().rencanakan(
      tagihan: [
        tagihanUji(id: 1, nama: 'Listrik', jatuhTempo: DateTime(2026, 9, 21), jumlahSen: 300000),
        tagihanUji(id: 2, nama: 'Air', jatuhTempo: DateTime(2026, 9, 22), jumlahSen: 150000),
        tagihanUji(id: 3, nama: 'Internet', jatuhTempo: DateTime(2026, 9, 25), jumlahSen: 350000),
      ],
      sekarang: sekarang,
      sertakanBriefingPagi: true,
    );
    final b = briefingUntuk(rencana, DateTime(2026, 9, 21))!;
    expect(b.isi, contains('Hari ini 1 tagihan'));
    expect(b.isi, contains('besok 1'));
    expect(b.isi, contains('Total 7 hari'));
    expect(b.kanal, KanalNotifikasi.briefing);
    expect(b.tagihanId, 0, reason: 'briefing tidak menandai lunas apa pun');
  });

  test('hari ini kosong tapi besok ada → kalimat tetap jelas', () {
    final rencana = const PerencanaPengingat().rencanakan(
      tagihan: [
        tagihanUji(id: 1, nama: 'Air', jatuhTempo: DateTime(2026, 9, 22)),
      ],
      sekarang: sekarang,
      sertakanBriefingPagi: true,
    );
    final b = briefingUntuk(rencana, DateTime(2026, 9, 21))!;
    expect(b.isi, contains('Hari ini tidak ada tagihan'));
    expect(b.isi, contains('besok 1'));
  });

  test('tanpa tagihan sama sekali → kalimat ramah, bukan angka nol', () {
    final rencana = const PerencanaPengingat().rencanakan(
      tagihan: const [],
      sekarang: sekarang,
      sertakanBriefingPagi: true,
    );
    final b = briefingUntuk(rencana, DateTime(2026, 9, 21))!;
    expect(b.isi, 'Tidak ada tagihan hari ini atau besok.');
  });

  test('tagihan lunas & nonaktif tidak dihitung di ringkasan pagi', () {
    final rencana = const PerencanaPengingat().rencanakan(
      tagihan: [
        tagihanUji(id: 1, nama: 'Lunas', jatuhTempo: DateTime(2026, 9, 21), lunas: true),
        tagihanUji(id: 2, nama: 'Nonaktif', jatuhTempo: DateTime(2026, 9, 21), aktif: false),
      ],
      sekarang: sekarang,
      sertakanBriefingPagi: true,
    );
    final b = briefingUntuk(rencana, DateTime(2026, 9, 21))!;
    expect(b.isi, 'Tidak ada tagihan hari ini atau besok.');
  });
}
