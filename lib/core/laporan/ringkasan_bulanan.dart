/// FR-77 — Ringkasan keuangan bulanan (INTI MURNI Dart).
///
/// Berkas ini sengaja TIDAK mengimpor Flutter dan TIDAK menyentuh basis data.
/// Masukannya daftar baris transaksi + daftar tagihan bulan itu (sudah dibaca
/// oleh `lib/data/repository/laporan_bulanan_repository.dart`), keluarannya
/// angka dan teks siap tampil. Dengan begitu hitungannya bisa diuji tanpa
/// widget dan tanpa drift.
///
/// ATURAN YANG DIPEGANG (semuanya diuji di `test/v2_laporan_bulanan_test.dart`):
/// 1. Seluruh nominal berupa bilangan bulat SEN (1 rupiah = 100 sen). Arah
///    arus ditentukan kolom `jenis`, jadi jumlah selalu positif.
/// 2. Selisih = total pemasukan - total pengeluaran; boleh negatif.
/// 3. Rincian dikelompokkan per (nama kategori, jenis). Nama yang sama dengan
///    jenis berbeda TIDAK digabung, supaya pemasukan tidak menutupi
///    pengeluaran pada baris yang sama.
/// 4. Baris tanpa kategori masuk kelompok "Tanpa kategori" supaya uangnya
///    tidak hilang diam-diam dari rincian.
/// 5. "Lima pengeluaran terbesar" hanya memuat baris berjenis pengeluaran,
///    urut menurun; bila barisnya kurang dari lima, daftarnya lebih pendek.
/// 6. Bulan tanpa catatan tetap menghasilkan ringkasan bernilai nol yang
///    jujur (ada penanda [RingkasanBulanan.adaTransaksi]) — bukan angka yang
///    membuat pembaca menebak-nebak.
/// 7. Teks ringkasan menyebut angka apa adanya, tanpa kata menghakimi
///    (PRD §III-11).
library;

import '../../data/model/enums.dart';
import '../utils/uang_utils.dart';

/// Nama bulan Indonesia.
///
/// Ditulis sebagai daftar tetap — bukan lewat `DateFormat(..., 'id_ID')` —
/// supaya ringkasan dan PDF tetap benar walau data locale intl belum dimuat
/// (mis. saat dibangun dari isolate latar).
const List<String> namaBulanIndonesia = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// "September 2026" dari tanggal mana pun di bulan itu.
String namaBulanTahunId(DateTime bulan) =>
    '${namaBulanIndonesia[bulan.month - 1]} ${bulan.year}';

/// Kunci periode `YYYY-MM` (dipakai blok ringkasan CSV).
String kunciBulanLaporan(DateTime bulan) =>
    '${bulan.year}-${bulan.month.toString().padLeft(2, '0')}';

/// Kode bulan `YYYYMM` (dipakai nama berkas `plo_laporan_YYYYMM.pdf`).
String kodeBerkasBulan(DateTime bulan) =>
    '${bulan.year}${bulan.month.toString().padLeft(2, '0')}';

/// Nama kelompok untuk baris yang tidak punya kategori.
const String kategoriTanpaNama = 'Tanpa kategori';

/// Satu baris transaksi sebagaimana dibaca dari basis data.
class BarisTransaksiBulanan {
  const BarisTransaksiBulanan({
    required this.id,
    required this.tanggal,
    required this.kategori,
    required this.jenis,
    required this.jumlahSen,
    this.catatan,
  });

  /// Id baris di tabel `transaksi` (bahan kunci tampilan & CSV).
  final int id;

  /// Tanggal kejadian (jam diabaikan).
  final DateTime tanggal;

  /// Nama kategori; [kategoriTanpaNama] bila barisnya tidak berkategori.
  final String kategori;

  /// Arah arus: pemasukan atau pengeluaran.
  final JenisArus jenis;

  /// Nominal dalam sen, selalu positif.
  final int jumlahSen;

  /// Catatan pengguna, bila ada.
  final String? catatan;
}

/// Satu tagihan yang jatuh tempo pada bulan laporan.
///
/// Dua sumber barisnya: (a) tabel `tagihan` yang jatuh temponya di bulan itu,
/// dan (b) tabel `riwayat_pembayaran` dengan periode jatuh tempo di bulan itu
/// — supaya tagihan yang sudah dibayar dan periodenya sudah bergeser tetap
/// terbaca di bulan aslinya.
class TagihanBulanan {
  const TagihanBulanan({
    required this.nama,
    required this.jumlahSen,
    required this.jatuhTempo,
    required this.lunas,
    this.tagihanId,
  });

  /// Nama tagihan.
  final String nama;

  /// Nominal dalam sen (0 bila tagihannya non-moneter).
  final int jumlahSen;

  /// Tanggal jatuh tempo periode ini.
  final DateTime jatuhTempo;

  /// true = periode ini sudah tercatat lunas.
  final bool lunas;

  /// Id baris tagihan; null bila barisnya hanya tersisa di riwayat.
  final int? tagihanId;
}

/// Total satu kategori pada satu bulan.
class RincianKategoriBulanan {
  const RincianKategoriBulanan({
    required this.nama,
    required this.jenis,
    required this.jumlahSen,
    required this.jumlahTransaksi,
  });

  final String nama;
  final JenisArus jenis;
  final int jumlahSen;

  /// Berapa baris transaksi yang membentuk total itu.
  final int jumlahTransaksi;
}

/// Ringkasan keuangan satu bulan — hasil akhir yang dipakai layar, PDF, & CSV.
class RingkasanBulanan {
  const RingkasanBulanan({
    required this.bulan,
    required this.totalPemasukanSen,
    required this.totalPengeluaranSen,
    required this.rincianKategori,
    required this.transaksi,
    required this.tagihan,
    required this.limaPengeluaranTerbesar,
    required this.teksRingkasan,
  });

  /// Bulan laporan, selalu dinormalkan ke tanggal 1 pukul 00:00.
  final DateTime bulan;

  final int totalPemasukanSen;
  final int totalPengeluaranSen;

  /// Rincian per kategori: pengeluaran lebih dulu, lalu nominal terbesar.
  final List<RincianKategoriBulanan> rincianKategori;

  /// Seluruh baris transaksi bulan itu, urut tanggal (bahan CSV).
  final List<BarisTransaksiBulanan> transaksi;

  /// Tagihan yang jatuh tempo (atau dibayar untuk periode) di bulan itu.
  final List<TagihanBulanan> tagihan;

  /// Paling banyak lima baris pengeluaran terbesar.
  final List<BarisTransaksiBulanan> limaPengeluaranTerbesar;

  /// Satu sampai dua kalimat ringkas siap tampil.
  final String teksRingkasan;

  /// Pemasukan - pengeluaran. Boleh negatif.
  int get selisihSen => totalPemasukanSen - totalPengeluaranSen;

  /// true = ada baris transaksi pada bulan itu.
  bool get adaTransaksi => transaksi.isNotEmpty;

  /// true = tidak ada transaksi maupun tagihan pada bulan itu.
  bool get kosong => transaksi.isEmpty && tagihan.isEmpty;

  int get jumlahTransaksi => transaksi.length;

  int get jumlahTagihan => tagihan.length;

  int get totalTagihanSen => _jumlah(tagihan.map((t) => t.jumlahSen));

  int get jumlahTagihanLunas => tagihan.where((t) => t.lunas).length;

  int get jumlahTagihanBelumLunas => tagihan.where((t) => !t.lunas).length;

  int get nominalTagihanLunasSen =>
      _jumlah(tagihan.where((t) => t.lunas).map((t) => t.jumlahSen));

  int get nominalTagihanBelumLunasSen =>
      _jumlah(tagihan.where((t) => !t.lunas).map((t) => t.jumlahSen));

  /// Salinan dengan [teksRingkasan] baru; bidang lain tidak berubah.
  ///
  /// Dipakai [hitungRingkasanBulanan] karena teks ringkasan disusun dari
  /// angka yang sudah jadi, bukan dari masukan mentah.
  RingkasanBulanan salinTeks(String teks) => RingkasanBulanan(
        bulan: bulan,
        totalPemasukanSen: totalPemasukanSen,
        totalPengeluaranSen: totalPengeluaranSen,
        rincianKategori: rincianKategori,
        transaksi: transaksi,
        tagihan: tagihan,
        limaPengeluaranTerbesar: limaPengeluaranTerbesar,
        teksRingkasan: teks,
      );
}

int _jumlah(Iterable<int> angka) {
  var total = 0;
  for (final a in angka) {
    total += a;
  }
  return total;
}

/// Hitung ringkasan satu bulan dari baris yang sudah dibaca (fungsi MURNI).
///
/// [bulan] dinormalkan ke tanggal 1 supaya kunci periode tidak pernah
/// bergeser karena jam pada argumennya.
RingkasanBulanan hitungRingkasanBulanan({
  required DateTime bulan,
  required List<BarisTransaksiBulanan> transaksi,
  List<TagihanBulanan> tagihan = const [],
}) {
  final periode = DateTime(bulan.year, bulan.month, 1);

  final baris = List<BarisTransaksiBulanan>.of(transaksi)
    ..sort((a, b) {
      final urut = a.tanggal.compareTo(b.tanggal);
      return urut != 0 ? urut : a.id.compareTo(b.id);
    });

  var pemasukan = 0;
  var pengeluaran = 0;
  final petaKategori = <String, List<BarisTransaksiBulanan>>{};
  for (final t in baris) {
    if (t.jenis == JenisArus.pemasukan) {
      pemasukan += t.jumlahSen;
    } else {
      pengeluaran += t.jumlahSen;
    }
    petaKategori.putIfAbsent('${t.jenis.nilaiDb}|${t.kategori}', () => []).add(t);
  }

  final rincian = [
    for (final kelompok in petaKategori.values)
      RincianKategoriBulanan(
        nama: kelompok.first.kategori,
        jenis: kelompok.first.jenis,
        jumlahSen: _jumlah(kelompok.map((t) => t.jumlahSen)),
        jumlahTransaksi: kelompok.length,
      ),
  ]..sort((a, b) {
      // Pengeluaran lebih dulu (yang paling sering dilihat), lalu nominal
      // terbesar, lalu nama supaya urutannya tetap dari satu pembacaan ke
      // pembacaan berikutnya.
      if (a.jenis != b.jenis) {
        return a.jenis == JenisArus.pengeluaran ? -1 : 1;
      }
      final urut = b.jumlahSen.compareTo(a.jumlahSen);
      return urut != 0 ? urut : a.nama.compareTo(b.nama);
    });

  final terbesar = baris.where((t) => t.jenis == JenisArus.pengeluaran).toList()
    ..sort((a, b) {
      final urut = b.jumlahSen.compareTo(a.jumlahSen);
      if (urut != 0) return urut;
      final tanggal = a.tanggal.compareTo(b.tanggal);
      return tanggal != 0 ? tanggal : a.id.compareTo(b.id);
    });

  final daftarTagihan = List<TagihanBulanan>.of(tagihan)
    ..sort((a, b) {
      final urut = a.jatuhTempo.compareTo(b.jatuhTempo);
      return urut != 0 ? urut : a.nama.compareTo(b.nama);
    });

  final angka = RingkasanBulanan(
    bulan: periode,
    totalPemasukanSen: pemasukan,
    totalPengeluaranSen: pengeluaran,
    rincianKategori: List.unmodifiable(rincian),
    transaksi: List.unmodifiable(baris),
    tagihan: List.unmodifiable(daftarTagihan),
    limaPengeluaranTerbesar:
        List.unmodifiable(terbesar.take(5).toList(growable: false)),
    teksRingkasan: '',
  );

  // Teks disusun dari angka yang baru dihitung; salinan ini menjaga seluruh
  // bidang lain tetap sama (tidak ada dua jalur hitung).
  return angka.salinTeks(susunTeksRingkasan(angka));
}

/// Susun teks ringkasan 1-2 kalimat dari angka yang sudah dihitung.
String susunTeksRingkasan(RingkasanBulanan r) {
  final periode = namaBulanTahunId(r.bulan);

  if (!r.adaTransaksi && r.tagihan.isEmpty) {
    return 'Belum ada catatan transaksi maupun tagihan untuk $periode.';
  }
  if (!r.adaTransaksi) {
    return 'Belum ada catatan transaksi untuk $periode, tetapi tercatat '
        '${r.jumlahTagihan} tagihan jatuh tempo dengan total '
        '${fmtRpDariSen(r.totalTagihanSen)}.';
  }

  final kalimatPertama = 'Pada $periode tercatat pemasukan '
      '${fmtRpDariSen(r.totalPemasukanSen)} dan pengeluaran '
      '${fmtRpDariSen(r.totalPengeluaranSen)}, selisih '
      '${fmtRpDariSen(r.selisihSen)} dari ${r.jumlahTransaksi} transaksi.';

  if (r.tagihan.isEmpty) return kalimatPertama;
  return '$kalimatPertama Ada ${r.jumlahTagihan} tagihan jatuh tempo bulan '
      'ini dengan total ${fmtRpDariSen(r.totalTagihanSen)}, '
      '${r.jumlahTagihanLunas} di antaranya sudah lunas.';
}
