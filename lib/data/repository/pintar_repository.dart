/// Pengumpul data untuk batch 9 — "pintar":
///
/// * FR-142 Smart Insights  — [bahanTemuan]
/// * FR-143 Forecast        — [ramalan]
/// * FR-146 Annual Review   — [tinjauanTahun]
///
/// Semua susunan/keputusan tetap di `lib/core/...`; berkas ini hanya mengambil
/// baris basis data lalu menyerahkannya dalam bentuk seragam. Angka dari FR-30
/// (`proyeksiArusKas`) dipakai ulang untuk bagian "keluar tetap", jadi tidak ada
/// dua jadwal berbeda di aplikasi.
library;

import 'package:drift/drift.dart';

import '../../core/analitik/ramalan_saldo.dart';
import '../../core/analitik/temuan_pintar.dart';
import '../../core/analitik/tinjauan_tahun.dart';
import '../../core/laporan/proyeksi_arus_kas.dart';
import '../../core/utils/waktu.dart';
import '../database/database.dart';
import 'hidup_repository.dart';

class PintarRepository {
  PintarRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? waktuSekarang;

  final AppDatabase db;
  final DateTime Function() _jam;

  static const int _batasBaris = 20000;

  DateTime _awalHari(DateTime t) => DateTime(t.year, t.month, t.day);
  DateTime _akhirHari(DateTime t) => DateTime(t.year, t.month, t.day, 23, 59, 59, 999);

  Future<List<TransaksiData>> _transaksi(DateTime dari, DateTime sampai,
      {String? jenis}) async {
    final kueri = db.select(db.transaksi)
      ..where((t) => t.tanggal.isBiggerOrEqualValue(_awalHari(dari)))
      ..where((t) => t.tanggal.isSmallerOrEqualValue(_akhirHari(sampai)))
      ..limit(_batasBaris);
    if (jenis != null) kueri.where((t) => t.jenis.equals(jenis));
    return kueri.get();
  }

  // ══════════════════════════════════════════════════════════ FR-142

  /// Bahan temuan: pengeluaran per bulan, langganan, tagihan aktif, saldo harian.
  Future<BahanTemuan> bahanTemuan({
    int bulanPengeluaran = 6,
    int hariSaldo = 60,
  }) async {
    final kini = _jam();

    // Pengeluaran per bulan (hanya yang tercatat).
    final awalBulan = DateTime(kini.year, kini.month - (bulanPengeluaran - 1), 1);
    final trxBulan = await _transaksi(awalBulan, kini, jenis: 'pengeluaran');
    final peta = <String, List<int>>{};
    for (final t in trxBulan) {
      final kunci =
          '${t.tanggal.year}-${t.tanggal.month.toString().padLeft(2, '0')}';
      final slot = peta.putIfAbsent(kunci, () => [0, 0]);
      slot[0] += t.jumlahSen;
      slot[1] += 1;
    }
    final bulanan = peta.entries
        .map((e) =>
            PengeluaranBulan(periode: e.key, sen: e.value[0], jumlah: e.value[1]))
        .toList()
      ..sort((a, b) => a.periode.compareTo(b.periode));

    // Langganan aktif.
    final lg = await (db.select(db.langganan)
          ..where((l) => l.status.equals('aktif')))
        .get();
    final langganan = lg
        .map((l) => LanggananRingkas(
              nama: l.nama,
              nominalSen: l.nominalSen,
              terakhirDipakai: l.terakhirDipakaiPada,
            ))
        .toList();

    // Tagihan aktif.
    final tg = await (db.select(db.tagihan)
          ..where((t) => t.statusAktif.equals(true)))
        .get();
    final tagihanAktif = tg
        .map((t) => TagihanJatuhTempo(
              nama: t.nama,
              jatuhTempo: t.jatuhTempo,
              nominalSen: t.jumlahSen ?? 0,
            ))
        .toList();

    // Saldo harian: saldo awal dihitung dari SEMUA catatan sebelum rentang,
    // lalu ditelusuri hari demi hari (termasuk hari tanpa transaksi).
    final mulai = _awalHari(kini).subtract(Duration(days: hariSaldo));
    final sebelum = await _transaksi(DateTime(2000), mulai.subtract(const Duration(seconds: 1)));
    var saldo = 0;
    for (final t in sebelum) {
      saldo += t.jenis == 'pemasukan' ? t.jumlahSen : -t.jumlahSen;
    }
    final dalamRentang = await _transaksi(mulai, kini);
    final perHari = <String, int>{};
    for (final t in dalamRentang) {
      final kunci = '${t.tanggal.year}-${t.tanggal.month}-${t.tanggal.day}';
      perHari[kunci] =
          (perHari[kunci] ?? 0) + (t.jenis == 'pemasukan' ? t.jumlahSen : -t.jumlahSen);
    }
    final titik = <TitikSaldo>[];
    for (var i = 0; i <= hariSaldo; i++) {
      final tgl = DateTime(mulai.year, mulai.month, mulai.day + i);
      final kunci = '${tgl.year}-${tgl.month}-${tgl.day}';
      saldo += perHari[kunci] ?? 0;
      titik.add(TitikSaldo(tanggal: tgl, saldoSen: saldo));
    }

    return BahanTemuan(
      pengeluaranBulanan: bulanan,
      langganan: langganan,
      tagihanAktif: tagihanAktif,
      saldoHarian: titik,
    );
  }

  // ══════════════════════════════════════════════════════════ FR-143

  /// Ramalan saldo [jumlahBulan] ke depan.
  ///
  /// Asumsi yang dipakai (juga ditampilkan di layar):
  ///   * saldo awal = seluruh pemasukan − seluruh pengeluaran yang tercatat,
  ///     bukan saldo rekening bank (aplikasi tidak terhubung ke bank),
  ///   * pemasukan bulanan = rata-rata 3 baris terakhir tabel pemasukan bulanan,
  ///     bila kosong dipakai rata-rata transaksi pemasukan per bulan,
  ///   * pengeluaran variabel = rata-rata & simpangan pengeluaran harian dari
  ///     catatan [hariPengeluaran] hari terakhir.
  Future<RamalanSaldo> ramalan({
    int jumlahBulan = 4,
    int hariPengeluaran = 90,
  }) async {
    final kini = _jam();

    // 1) Saldo awal dari seluruh catatan.
    final semua = await _transaksi(DateTime(2000), kini);
    var saldo = 0;
    for (final t in semua) {
      saldo += t.jenis == 'pemasukan' ? t.jumlahSen : -t.jumlahSen;
    }

    // 2) Pemasukan bulanan rata-rata.
    final masukBaris = await (db.select(db.pemasukanBulanan)
          ..orderBy([(p) => OrderingTerm.desc(p.bulan)])
          ..limit(3))
        .get();
    var pemasukan = 0;
    var bulanCatatanPemasukan = masukBaris.length;
    if (masukBaris.isNotEmpty) {
      pemasukan =
          (masukBaris.fold<int>(0, (a, b) => a + b.jumlahSen) / masukBaris.length)
              .round();
    } else {
      final trxMasuk = await _transaksi(
          DateTime(kini.year, kini.month - 2, 1), kini, jenis: 'pemasukan');
      final perBulan = <String, int>{};
      for (final t in trxMasuk) {
        final k =
            '${t.tanggal.year}-${t.tanggal.month.toString().padLeft(2, '0')}';
        perBulan[k] = (perBulan[k] ?? 0) + t.jumlahSen;
      }
      bulanCatatanPemasukan = perBulan.length;
      if (perBulan.isNotEmpty) {
        pemasukan =
            (perBulan.values.fold<int>(0, (a, b) => a + b) / perBulan.length).round();
      }
    }

    // 3) Pengeluaran harian rata-rata + simpangan.
    final mulaiHarian = _awalHari(kini).subtract(Duration(days: hariPengeluaran - 1));
    final trxKeluar = await _transaksi(mulaiHarian, kini, jenis: 'pengeluaran');
    final perHari = <String, int>{};
    for (final t in trxKeluar) {
      final k = '${t.tanggal.year}-${t.tanggal.month}-${t.tanggal.day}';
      perHari[k] = (perHari[k] ?? 0) + t.jumlahSen;
    }
    final totalKeluar = perHari.values.fold<int>(0, (a, b) => a + b);
    final rataHarian = hariPengeluaran == 0 ? 0 : (totalKeluar / hariPengeluaran).round();
    var simpangan = 0;
    final hariAdaCatatan = perHari.length;
    if (hariPengeluaran > 1 && hariAdaCatatan > 0) {
      // Simpangan dihitung atas SEMUA hari dalam rentang (termasuk hari tanpa
      // pengeluaran = 0), supaya angkanya tidak membesar palsu.
      var jumlah = 0.0;
      for (var i = 0; i < hariPengeluaran; i++) {
        final tgl = DateTime(mulaiHarian.year, mulaiHarian.month, mulaiHarian.day + i);
        final kunci = '${tgl.year}-${tgl.month}-${tgl.day}';
        final v = perHari[kunci] ?? 0;
        jumlah += (v - rataHarian) * (v - rataHarian);
      }
      final ragam = jumlah / hariPengeluaran;
      simpangan = ragam <= 0 ? 0 : _akar(ragam).round();
    }

    // 4) Keluar tetap memakai mesin FR-30 (sama dengan pengingat).
    final tg = await db.select(db.tagihan).get();
    final lg = await db.select(db.langganan).get();
    final tetap = proyeksiArusKas(
      tagihan: tg,
      langganan: lg,
      mulai: kini,
      jumlahBulan: jumlahBulan,
    );

    final tabrakan = cariTabrakan(
      tg
          .where((t) => t.statusAktif)
          .map((t) => TagihanJatuhTempo(
                nama: t.nama,
                jatuhTempo: t.jatuhTempo,
                nominalSen: t.jumlahSen ?? 0,
              ))
          .toList(),
      sekarang: kini,
    );

    return ramalSaldo(
      saldoAwalSen: saldo,
      tetap: tetap,
      pemasukanBulananSen: pemasukan,
      pengeluaranHarianSen: rataHarian,
      simpanganHarianSen: simpangan,
      tabrakan: tabrakan,
      hariCatatanPengeluaran: hariPengeluaran,
      bulanCatatanPemasukan: bulanCatatanPemasukan,
    );
  }

  static num _akar(num x) {
    if (x <= 0) return 0;
    var tebakan = x.toDouble();
    for (var i = 0; i < 40; i++) {
      tebakan = (tebakan + x / tebakan) / 2;
      if (!tebakan.isFinite) return 0;
    }
    return tebakan;
  }

  // ══════════════════════════════════════════════════════════ FR-146

  /// Tinjauan tahun [tahun]. [bulanTercatat] = berapa bulan dalam tahun itu yang
  /// punya catatan (transaksi, pembayaran, atau tidur) — dasar jujur untuk
  /// syarat "data ≥6 bulan" dari PRD.
  Future<TinjauanTahun> tinjauanTahun({
    required int tahun,
    int minimalBulan = 6,
  }) async {
    final dari = DateTime(tahun, 1, 1);
    final sampai = DateTime(tahun, 12, 31, 23, 59, 59);
    final bahan =
        await HidupRepository(db, jamSekarang: _jam).bahan(dari: dari, sampai: sampai);

    final bulan = <int>{};
    for (final t in await _transaksi(dari, sampai)) {
      bulan.add(t.tanggal.month);
    }
    final bayar = await (db.select(db.riwayatPembayaran)
          ..where((r) => r.tanggalBayar.isBiggerOrEqualValue(dari))
          ..where((r) => r.tanggalBayar.isSmallerOrEqualValue(sampai)))
        .get();
    for (final b in bayar) {
      bulan.add(b.tanggalBayar.month);
    }
    final tidur = await (db.select(db.tidur)
          ..where((t) => t.tanggal.isBiggerOrEqualValue(dari))
          ..where((t) => t.tanggal.isSmallerOrEqualValue(sampai)))
        .get();
    for (final t in tidur) {
      bulan.add(t.tanggal.month);
    }

    return susunTinjauanTahun(
      tahun: tahun,
      bahan: bahan,
      bulanTercatat: bulan.length,
      minimalBulan: minimalBulan,
    );
  }
}
