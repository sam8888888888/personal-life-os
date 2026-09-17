/// FR-77 — Repositori laporan keuangan bulanan (HANYA BACA).
///
/// Berkas ini tidak pernah menulis ke basis data. Tugasnya hanya dua:
/// 1. membaca baris transaksi, kategori, tagihan, dan riwayat pembayaran pada
///    satu bulan kalender, lalu
/// 2. menyerahkannya ke hitungan murni `lib/core/laporan/ringkasan_bulanan.dart`.
///
/// Aturan yang dipegang:
/// * **Batas atas EKSKLUSIF.** Rentang bulan memakai awal bulan berikutnya
///   (`tanggal < awal bulan berikutnya`), bukan tengah malam hari terakhir.
///   Baris bertanggal 1 bulan berikutnya karena itu tidak pernah ikut
///   terhitung, sedangkan baris pukul 23:59 di hari terakhir tetap ikut.
///   Perkakas rentangnya ada di `lib/data/repository/periode.dart`.
/// * **Tanggal apa adanya.** Kolom `dateTime()` drift tersimpan sebagai DETIK
///   Unix. Pembacaan bertipe drift sudah mengubahnya kembali menjadi DateTime;
///   untuk pembacaan mentah dipakai [dariDetikUnix] supaya satuannya tidak
///   pernah salah tafsir.
/// * **Tanpa format locale.** Berkas ini tidak memakai `DateFormat(...,'id_ID')`;
///   label bulan disusun lewat daftar nama bulan tetap dari lapisan inti.
library;

import 'package:drift/drift.dart';

import '../../core/laporan/ringkasan_bulanan.dart';
import '../database/database.dart';
import '../model/enums.dart';
import 'periode.dart';

/// Detik Unix (penyimpanan kolom `dateTime()` drift) menjadi waktu lokal.
DateTime dariDetikUnix(num detik) =>
    DateTime.fromMillisecondsSinceEpoch((detik * 1000).round()).toLocal();

/// Batas waktu baca supaya layar tidak menunggu tanpa ujung.
const Duration _batasBaca = Duration(seconds: 5);

class LaporanBulananRepository {
  LaporanBulananRepository(this.db);

  final AppDatabase db;

  /// Ringkasan lengkap satu bulan; [bulan] boleh tanggal berapa pun di bulan
  /// itu (dinormalkan ke tanggal 1 oleh hitungan murni).
  Future<RingkasanBulanan> bulan(DateTime bulan) async {
    final rentang = rentangBulan(bulan);

    final barisTransaksi = await (db.select(db.transaksi)
          ..where((t) =>
              t.tanggal.isBiggerOrEqualValue(rentang.awal) &
              // Batas atas EKSKLUSIF — lihat catatan berkas ini.
              t.tanggal.isSmallerThanValue(rentang.akhirEksklusif))
          ..orderBy([
            (t) => OrderingTerm.asc(t.tanggal),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get()
        .timeout(_batasBaca);

    final kategori = await db
        .select(db.kategoriTransaksi)
        .get()
        .timeout(_batasBaca);
    final namaKategori = <int, String>{
      for (final k in kategori) k.id: k.nama,
    };

    final barisTagihan = await (db.select(db.tagihan)
          ..where((t) =>
              t.jenis.equals('tagihan') &
              t.jatuhTempo.isBiggerOrEqualValue(rentang.awal) &
              t.jatuhTempo.isSmallerThanValue(rentang.akhirEksklusif))
          ..orderBy([(t) => OrderingTerm.asc(t.jatuhTempo)]))
        .get()
        .timeout(_batasBaca);

    final barisRiwayat = await (db.select(db.riwayatPembayaran)
          ..where((x) =>
              x.periodeJatuhTempo.isBiggerOrEqualValue(rentang.awal) &
              x.periodeJatuhTempo.isSmallerThanValue(rentang.akhirEksklusif))
          ..orderBy([(x) => OrderingTerm.asc(x.periodeJatuhTempo)]))
        .get()
        .timeout(_batasBaca);

    final namaTagihan = <int, String>{
      for (final t in barisTagihan) t.id: t.nama,
    };

    // Baris riwayat bisa menunjuk tagihan yang kartunya sudah bergeser ke bulan
    // lain. Namanya diambil lewat satu pembacaan tambahan (hanya untuk id yang
    // belum ada di bulan ini) supaya labelnya tetap nama tagihan sebenarnya,
    // bukan nomor urut.
    final idPerluNama = <int>{
      for (final r in barisRiwayat)
        if (!namaTagihan.containsKey(r.tagihanId)) r.tagihanId,
    };
    if (idPerluNama.isNotEmpty) {
      final tagihanLuarBulan = await (db.select(db.tagihan)
            ..where((t) =>
                t.id.isIn(idPerluNama) & t.jenis.equals('tagihan')))
          .get()
          .timeout(_batasBaca);
      for (final t in tagihanLuarBulan) {
        namaTagihan[t.id] = t.nama;
      }
    }

    // Kunci "tagihan + periode" supaya satu periode tidak dihitung dua kali
    // saat barisnya muncul di tabel `tagihan` DAN di `riwayat_pembayaran`.
    final kunciDibayar = <String>{
      for (final r in barisRiwayat) _kunci(r.tagihanId, r.periodeJatuhTempo),
    };

    final daftarTagihan = <TagihanBulanan>[
      for (final t in barisTagihan)
        TagihanBulanan(
          tagihanId: t.id,
          nama: t.nama,
          jumlahSen: t.jumlahSen ?? 0,
          jatuhTempo: t.jatuhTempo,
          // Lunas bila ditandai lunas di kartunya, atau bila ada catatan
          // pembayaran untuk periode jatuh tempo itu.
          lunas: t.lunas || kunciDibayar.contains(_kunci(t.id, t.jatuhTempo)),
        ),
      // Tagihan yang periodenya sudah bergeser (mis. sudah dibayar lalu naik ke
      // bulan depan) tetap terbaca di bulan aslinya lewat riwayat pembayaran.
      for (final r in barisRiwayat)
        if (!barisTagihan.any((t) =>
            t.id == r.tagihanId && _samaHari(t.jatuhTempo, r.periodeJatuhTempo)))
          TagihanBulanan(
            tagihanId: r.tagihanId,
            nama: namaTagihan[r.tagihanId] ?? 'Tagihan #${r.tagihanId}',
            jumlahSen: r.jumlahSen,
            jatuhTempo: r.periodeJatuhTempo,
            lunas: true,
          ),
    ];

    final daftarTransaksi = <BarisTransaksiBulanan>[
      for (final t in barisTransaksi)
        BarisTransaksiBulanan(
          id: t.id,
          tanggal: t.tanggal,
          kategori: namaKategori[t.kategoriId] ?? kategoriTanpaNama,
          jenis: JenisArus.dariDb(t.jenis),
          jumlahSen: t.jumlahSen,
          catatan: t.catatan,
        ),
    ];

    return hitungRingkasanBulanan(
      bulan: bulan,
      transaksi: daftarTransaksi,
      tagihan: daftarTagihan,
    );
  }

  /// Daftar bulan yang punya catatan — urut dari yang terbaru.
  ///
  /// Sumbernya transaksi, tagihan, dan riwayat pembayaran. Dibaca mentah
  /// lewat SQL karena hanya nilai tanggalnya yang dipakai; satuannya detik
  /// Unix dan diubah oleh [dariDetikUnix].
  Future<List<DateTime>> bulanTersedia() async {
    final hasil = await db
        .customSelect(
          'SELECT tanggal AS detik FROM transaksi '
          'UNION SELECT jatuh_tempo FROM tagihan '
          'UNION SELECT periode_jatuh_tempo FROM riwayat_pembayaran',
          readsFrom: {db.transaksi, db.tagihan, db.riwayatPembayaran},
        )
        .get()
        .timeout(_batasBaca);

    final peta = <String, DateTime>{};
    for (final baris in hasil) {
      final mentah = baris.data['detik'];
      if (mentah is! num) continue;
      final tanggal = dariDetikUnix(mentah);
      peta['${tanggal.year}-${tanggal.month}'] =
          DateTime(tanggal.year, tanggal.month, 1);
    }

    final daftar = peta.values.toList()
      ..sort((a, b) => b.compareTo(a));
    return daftar;
  }

  /// "September 2026" — label periode untuk judul layar & nama berkas.
  ///
  /// Sengaja memakai nama bulan tetap dari lapisan inti, bukan
  /// `DateFormat(..., 'id_ID')`, supaya jalur data tidak bergantung data
  /// locale intl.
  String namaBulanTahun(DateTime bulan) => namaBulanTahunId(bulan);

  String _kunci(int? tagihanId, DateTime periode) =>
      '$tagihanId|${periode.year}-${periode.month}-${periode.day}';

  bool _samaHari(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
