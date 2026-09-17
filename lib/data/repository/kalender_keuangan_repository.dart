/// Repositori kalender keuangan bulanan - FR-73. **HANYA BACA.**
///
/// Berkas ini menyatukan enam sumber yang sudah ada menjadi satu daftar
/// [PeristiwaKeuangan] per bulan:
///
/// | sumber             | tabel / repositori                        |
/// |--------------------|-------------------------------------------|
/// | tagihan            | `TagihanRepository.ambilSemua`            |
/// | langganan          | `LanggananRepository.ambilAktif`          |
/// | angsuran utang     | `PembayaranKewajibanRepository.ambilRingkasan` |
/// | pengeluaran rencana| `PengeluaranTerencanaRepository.ambilSemua` |
/// | masa berlaku dokumen | `DokumenRepository.ambilSemua`          |
/// | transaksi nyata    | `TransaksiRepository.ambilBulan`          |
///
/// Modul-modul itu milik pekerja lain, jadi berkas ini **hanya memanggil**
/// method baca yang sudah ada; tidak ada berkas lain yang diubah dan tidak ada
/// tabel drift baru.
///
/// **Dua aturan penting:**
///
/// 1. **Batas atas bulan EKSKLUSIF.** Baris dihitung bila `tanggal >= awal
///    bulan` dan `tanggal < awal bulan berikutnya`. Tanggal 1 bulan berikutnya
///    karena itu tidak ikut. Memakai tengah malam hari terakhir akan membuang
///    baris yang bertanda pukul 08:00 di hari terakhir bulan itu.
/// 2. **Satu sumber bermasalah tidak menggagalkan seluruh bulan.** Setiap
///    sumber dibaca di dalam `try/catch` sendiri (dengan batas waktu 5 detik).
///    Sumber yang tidak terbaca dicatat di [sumberDilewati] lalu **dilewati**,
///    dan kalender tetap menampilkan sumber lain. Pilihan ini disengaja:
///    kalender adalah layar ringkasan - lebih berguna menampilkan empat sumber
///    yang sehat daripada layar kosong karena satu sumber bermasalah.
///
/// Waktu selalu lewat [jamSekarang] (dapat dikunci saat pengujian), bukan
/// `DateTime.now()`.
library;

import 'dart:async';

import '../../core/kalender_keuangan/peristiwa_keuangan.dart';
import '../../core/uang/jadwal_kewajiban.dart'
    show jumlahHariBulan, tanggalJatuhTempoBulan;
import '../../core/utils/waktu.dart';
import '../database/database.dart';
import '../model/enums.dart';
import 'dokumen_repository.dart';
import 'langganan_repository.dart';
import 'pembayaran_kewajiban_repository.dart';
import 'pengeluaran_terencana_repository.dart';
import 'tagihan_repository.dart';
import 'transaksi_repository.dart';

/// Batas waktu satu pembacaan sumber (aturan waktu baca lapisan data).
const Duration batasBacaKalender = Duration(seconds: 5);

/// Nama sumber yang dikenali (untuk catatan [KalenderKeuanganRepository]).
const List<String> sumberKalenderKeuangan = <String>[
  'tagihan',
  'langganan',
  'angsuran',
  'pengeluaranTerencana',
  'dokumen',
  'transaksi',
];

class KalenderKeuanganRepository {
  KalenderKeuanganRepository(this.db, {DateTime Function()? jamSekarang})
      : jam = jamSekarang ?? waktuSekarang;

  final AppDatabase db;

  /// Sumber waktu (dapat dikunci saat pengujian).
  final DateTime Function() jam;

  /// Sumber yang berhasil dibaca pada panggilan [bulan] terakhir.
  final List<String> sumberTerbaca = <String>[];

  /// Sumber yang dilewati pada panggilan [bulan] terakhir, beserta sebabnya.
  ///
  /// Daftar ini diisi ulang setiap kali [bulan] dipanggil.
  final List<String> sumberDilewati = <String>[];

  /// Seluruh peristiwa keuangan pada bulan [bulan] tahun [tahun], urut tanggal.
  ///
  /// Batas atas **eksklusif**: tanggal 1 bulan berikutnya tidak ikut.
  /// Sumber yang tidak terbaca dilewati (lihat catatan di kepala berkas).
  Future<List<PeristiwaKeuangan>> bulan(int tahun, int bulan) async {
    sumberTerbaca.clear();
    sumberDilewati.clear();

    final awal = DateTime(tahun, bulan, 1);
    // Batas atas EKSKLUSIF: pukul 00:00 tanggal 1 bulan berikutnya.
    final akhirEksklusif = DateTime(tahun, bulan + 1, 1);
    final hariIni = hariSaja(jam());

    final hasil = <PeristiwaKeuangan>[];

    /// Tagihan aktif yang belum lunas - dipakai juga untuk menyingkirkan
    /// langganan tertaut supaya satu pembayaran tidak terhitung dua kali.
    var tagihanAktif = <int>{};

    Future<void> bacaSumber(
      String nama,
      Future<void> Function() baca,
    ) async {
      try {
        await baca().timeout(batasBacaKalender);
        sumberTerbaca.add(nama);
      } catch (e) {
        // Dicatat apa adanya lalu dilewati; bulan tetap tampil.
        sumberDilewati.add('$nama: $e');
      }
    }

    // 1. Tagihan (kolom `jatuhTempo`, `jumlahSen` boleh kosong).
    await bacaSumber('tagihan', () async {
      final daftar = await TagihanRepository(db).ambilSemua();
      for (final t in daftar) {
        if (!t.statusAktif || t.lunas) continue;
        tagihanAktif.add(t.id);
        final tanggal = hariSaja(t.jatuhTempo);
        if (tanggal.isBefore(awal) || !tanggal.isBefore(akhirEksklusif)) {
          continue;
        }
        hasil.add(PeristiwaKeuangan(
          tanggal: tanggal,
          judul: 'Tagihan: ${t.nama}',
          nominalSen: -(t.jumlahSen ?? 0),
          jenis: JenisPeristiwa.tagihan,
          rujukan: 'tagihan:${t.id}',
        ));
      }
    });

    // 2. Langganan aktif (berulang menurut `siklus` dan `tanggalMulai`).
    await bacaSumber('langganan', () async {
      final daftar = await LanggananRepository(db).ambilAktif();
      for (final l in daftar) {
        // Langganan yang menaut tagihan aktif sudah terwakili baris tagihan;
        // menambahkannya lagi akan menghitung satu pembayaran dua kali.
        final tautan = l.tagihanId;
        if (tautan != null && tagihanAktif.contains(tautan)) continue;
        for (final tanggal in tanggalLanggananBulan(
          siklus: l.siklus,
          tanggalMulai: l.tanggalMulai,
          tahun: tahun,
          bulan: bulan,
        )) {
          hasil.add(PeristiwaKeuangan(
            tanggal: tanggal,
            judul: 'Langganan: ${l.nama}',
            nominalSen: -l.nominalSen,
            jenis: JenisPeristiwa.langganan,
            rujukan: 'langganan:${l.id}',
          ));
        }
      }
    });

    // 3. Angsuran utang/kewajiban (jadwal "tanggal N tiap bulan").
    await bacaSumber('angsuran', () async {
      final ringkasan = await PembayaranKewajibanRepository(db, jamSekarang: jam)
          .ambilRingkasan();
      for (final r in ringkasan) {
        final k = r.kewajiban;
        if (k.arsip || r.lunas) continue;
        final hari = k.tanggalJatuhTempoHari;
        if (hari == null) continue;
        final tanggal = tanggalJatuhTempoBulan(tahun, bulan, hari);
        // Minimum bayar bila diisi; kalau tidak, sisa utang dipakai supaya
        // barisnya tidak pernah tampil bernominal nol tanpa keterangan.
        final nominal = k.minimumBayarSen ?? r.sisaSen;
        hasil.add(PeristiwaKeuangan(
          tanggal: tanggal,
          judul: 'Angsuran: ${k.nama}',
          nominalSen: -nominal,
          jenis: JenisPeristiwa.angsuran,
          rujukan: 'kewajiban:${k.id}',
        ));
      }
    });

    // 4. Pengeluaran terencana (uang yang disiapkan sebelum tanggal tertentu).
    await bacaSumber('pengeluaranTerencana', () async {
      final daftar =
          await PengeluaranTerencanaRepository(db, jamSekarang: jam).ambilSemua();
      for (final p in daftar) {
        if (!p.aktif) continue;
        final tanggal = hariSaja(p.tanggal);
        if (tanggal.isBefore(awal) || !tanggal.isBefore(akhirEksklusif)) {
          continue;
        }
        hasil.add(PeristiwaKeuangan(
          tanggal: tanggal,
          judul: 'Rencana: ${p.nama}',
          nominalSen: -p.jumlahSen,
          jenis: JenisPeristiwa.pengeluaranTerencana,
          sudahTerjadi: p.sudahTerjadi,
          rujukan: 'terencana:${p.id}',
        ));
      }
    });

    // 5. Masa berlaku dokumen (tanpa nominal - yang perlu disiapkan tanggalnya,
    //    bukan uangnya, karena besar biaya perpanjangan belum dicatat).
    await bacaSumber('dokumen', () async {
      final daftar = await DokumenRepository(db, jamSekarang: jam).ambilSemua();
      for (final d in daftar) {
        if (!d.aktif || d.arsip) continue;
        final akhir = d.berlakuSampai;
        if (akhir == null) continue;
        final tanggal = hariSaja(akhir);
        if (tanggal.isBefore(awal) || !tanggal.isBefore(akhirEksklusif)) {
          continue;
        }
        hasil.add(PeristiwaKeuangan(
          tanggal: tanggal,
          judul: 'Dokumen: ${d.nama} berakhir',
          nominalSen: 0,
          jenis: JenisPeristiwa.dokumen,
          sudahTerjadi: tanggal.isBefore(hariIni),
          rujukan: 'dokumen:${d.id}',
        ));
      }
    });

    // 6. Transaksi nyata (apa yang SUDAH terjadi).
    await bacaSumber('transaksi', () async {
      final daftar = await TransaksiRepository(db).ambilBulan(awal);
      for (final t in daftar) {
        final tanggal = hariSaja(t.tanggal);
        final arus = JenisArus.dariDb(t.jenis);
        final catatan = t.catatan?.trim() ?? '';
        hasil.add(PeristiwaKeuangan(
          tanggal: tanggal,
          judul: catatan.isEmpty ? 'Transaksi ${arus.label}' : catatan,
          nominalSen: arus.tanda * t.jumlahSen,
          jenis: JenisPeristiwa.transaksi,
          sudahTerjadi: true,
          rujukan: 'transaksi:${t.id}',
        ));
      }
    });

    // Aturan "sudah lewat" hanya di satu tempat: kejadian beruang yang belum
    // terjadi dan tanggalnya sudah lewat ditandai [JenisPeristiwa.jatuhTempoTerlewat]
    // supaya terlihat di kalender. Baris tanpa nominal (dokumen) tidak dihitung.
    final siap = <PeristiwaKeuangan>[];
    for (final p in hasil) {
      final lewat = p.nominalSen != 0 &&
          !p.sudahTerjadi &&
          p.tanggal.isBefore(hariIni);
      siap.add(lewat ? p.sebagaiTerlewat() : p);
    }
    return urutPeristiwa(siap);
  }
}

/// Tanggal-tanggal satu langganan yang jatuh pada bulan [bulan]/[tahun].
///
/// Aturan per siklus (fungsi murni, mudah diuji):
/// * `sekali`         -> hanya tanggal mulainya, bila memang di bulan itu;
/// * `bulanan`/`kustomHari` -> satu tanggal per bulan, hari disamakan dengan
///   hari tanggal mulai dan dijepit akhir bulan (31 Jan -> 28/29 Feb);
/// * `duaBulanan`, `kuartalan`, `semesteran`, `tahunan` -> satu tanggal bila
///   selisih bulannya kelipatan siklus dari tanggal mulai;
/// * `mingguan`/`duaMingguan` -> setiap 7/14 hari sejak tanggal mulai.
///
/// Langganan yang mulai setelah bulan yang ditanyakan mengembalikan daftar
/// kosong: tidak ada yang bisa jatuh sebelum dimulai.
List<DateTime> tanggalLanggananBulan({
  required String siklus,
  required DateTime tanggalMulai,
  required int tahun,
  required int bulan,
}) {
  final mulai = hariSaja(tanggalMulai);
  final f = Frekuensi.dariDb(siklus);
  final jumlahHari = jumlahHariBulan(tahun, bulan);

  switch (f) {
    case Frekuensi.sekali:
      return diBulan(mulai, tahun, bulan) ? <DateTime>[mulai] : const [];

    case Frekuensi.bulanan:
    case Frekuensi.kustomHari:
      if (mulai.isAfter(DateTime(tahun, bulan, jumlahHari))) return const [];
      return <DateTime>[tanggalJatuhTempoBulan(tahun, bulan, mulai.day)];

    case Frekuensi.duaBulanan:
    case Frekuensi.kuartalan:
    case Frekuensi.semesteran:
    case Frekuensi.tahunan:
      final langkah = switch (f) {
        Frekuensi.duaBulanan => 2,
        Frekuensi.kuartalan => 3,
        Frekuensi.semesteran => 6,
        _ => 12,
      };
      final selisih = (tahun - mulai.year) * 12 + (bulan - mulai.month);
      if (selisih < 0 || selisih % langkah != 0) return const [];
      return <DateTime>[tanggalJatuhTempoBulan(tahun, bulan, mulai.day)];

    case Frekuensi.mingguan:
    case Frekuensi.duaMingguan:
      final langkahHari = f == Frekuensi.mingguan ? 7 : 14;
      final awal = DateTime(tahun, bulan, 1);
      final akhirEksklusif = DateTime(tahun, bulan + 1, 1);
      // Lompat langsung ke kemunculan pertama, bukan mengulang dari tanggal
      // mulai: tanggal mulai bisa bertahun-tahun yang lalu.
      var lewati = awal.difference(mulai).inDays;
      if (lewati < 0) lewati = 0;
      var kelipatan = (lewati / langkahHari).ceil();
      var jalan = mulai.add(Duration(days: kelipatan * langkahHari));
      final hasil = <DateTime>[];
      var putaran = 0;
      while (jalan.isBefore(akhirEksklusif) && putaran < 10) {
        if (!jalan.isBefore(awal)) hasil.add(hariSaja(jalan));
        jalan = jalan.add(Duration(days: langkahHari));
        putaran += 1;
      }
      return hasil;
  }
}
