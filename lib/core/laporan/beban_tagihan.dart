/// FR-28 — Beban tagihan per bulan (inti MURNI Dart).
///
/// Berkas ini sengaja TIDAK mengimpor Flutter dan TIDAK menyentuh database.
/// Masukannya daftar tagihan ringkas + daftar kategori; keluarannya angka.
/// Dengan begitu hitungannya bisa diuji tanpa widget dan tanpa drift, dan
/// layar (`lib/features/laporan/beban_tagihan_screen.dart`) hanya mengurus
/// tampilan.
///
/// ATURAN YANG DIPAKAI (semuanya diuji di `test/beban_tagihan_test.dart`):
/// 1. Tagihan dihitung pada bulan JATUH TEMPONYA — bukan bulan pembayaran.
///    Tagihan yang jatuh tempo 31 Des 2026 tetap masuk Desember walau dibayar
///    2 Jan 2027.
/// 2. Tagihan yang SUDAH LUNAS tetap ikut dihitung. Angka di sini adalah
///    BEBAN (apa yang jatuh tempo pada bulan itu), bukan sisa utang. Karena
///    itu layar menulis "termasuk yang sudah dibayar" supaya tidak salah
///    tafsir.
/// 3. Tagihan nonaktif (mis. langganan yang sudah dihentikan) tetap ikut
///    dihitung: riwayat beban tidak boleh berubah retroaktif. Bila memang
///    ingin hanya yang aktif, panggil dengan `hanyaAktif: true`.
/// 4. Tagihan tanpa kategori (`kategoriId` null, atau kategorinya sudah tidak
///    ada di daftar) masuk kelompok "Tanpa kategori" supaya bebannya tidak
///    hilang diam-diam. Sebaliknya, kategori yang ada tetapi belum dipakai
///    tagihan TIDAK dibuatkan baris nol.
/// 5. Tagihan bernominal nol tetap dihitung jumlahnya; totalnya tidak berubah.
/// 6. Jendela bulan = N bulan terakhir TERMASUK bulan berjalan (bawaan 6),
///    urut dari paling lama ke paling baru. Bulan tanpa tagihan tetap muncul
///    dengan total 0 sen supaya grafik tidak bolong.
library;

import '../utils/waktu.dart';
import '../../data/repository/periode.dart';

// ---------------------------------------------------------------------------
// Model masukan
// ---------------------------------------------------------------------------

/// Satu tagihan ringkas untuk perhitungan beban.
///
/// Sengaja berupa kelas sendiri (bukan `TagihanData` milik drift) supaya inti
/// ini tidak bergantung pada lapisan database dan bisa diuji murni.
class TagihanBeban {
  const TagihanBeban({
    required this.id,
    required this.nama,
    required this.nominalSen,
    required this.jatuhTempo,
    this.kategoriId,
    this.status = belumLunas,
    this.aktif = true,
  });

  /// Status pembayaran (teks, mengikuti gaya kolom teks di skema).
  static const String lunas = 'lunas';
  static const String belumLunas = 'belum_lunas';

  final int id;
  final String nama;

  /// Nominal dalam sen (satuan terkecil). Tagihan non-moneter tidak diikutkan
  /// oleh pemanggil (layar melewatkan baris yang nominalnya null).
  final int nominalSen;

  /// Tanggal jatuh tempo — inilah bulan tempat tagihan dihitung.
  final DateTime jatuhTempo;

  /// Kategori tagihan (tabel `Kategori`); null = belum diberi kategori.
  final int? kategoriId;

  /// [lunas] atau [belumLunas].
  final String status;

  /// true = tagihan masih berjalan (bukan dihentikan).
  final bool aktif;

  /// true bila tagihan ini sudah dibayar pada periode jatuh temponya.
  bool get sudahDibayar => status == lunas;

  /// Kunci bulan `YYYY-MM` dari jatuh tempo.
  String get kunciBulan => kunciBulanDari(jatuhTempo);
}

/// Kategori tagihan (id + nama) — dipakai untuk menamai kelompok rincian.
class KategoriBeban {
  const KategoriBeban({required this.id, required this.nama});

  final int id;
  final String nama;
}

// ---------------------------------------------------------------------------
// Model keluaran
// ---------------------------------------------------------------------------

/// Rincian satu kategori pada satu bulan.
class BagianKategori {
  const BagianKategori({
    required this.kategoriId,
    required this.nama,
    required this.totalSen,
    required this.jumlah,
    required this.bagian,
    required this.bagianTeks,
  });

  /// null = kelompok "Tanpa kategori" (atau kategori yang sudah tidak ada).
  final int? kategoriId;
  final String nama;
  final int totalSen;

  /// Jumlah tagihan pada kategori ini (termasuk yang sudah dibayar).
  final int jumlah;

  /// Bagian dari total bulan, 0..1 — angka mentah tanpa pembulatan.
  final double bagian;

  /// Bagian untuk DITAMPILKAN, mis. `"33,3%"`. Kategori bernilai terbesar
  /// menyerap sisa pembulatan supaya jumlah yang terbaca tetap 100,0%.
  final String bagianTeks;

  /// Bagian dalam persen (0..100), angka mentah.
  double get bagianPersen => bagian * 100;
}

/// Angka satu bulan pada jendela beban.
class BulanBeban {
  const BulanBeban({
    required this.tahun,
    required this.bulan,
    required this.totalSen,
    required this.jumlah,
    required this.jumlahSudahDibayar,
    required this.perKategori,
  });

  final int tahun;

  /// 1–12.
  final int bulan;

  /// Total beban bulan ini (sen) — termasuk yang sudah dibayar.
  final int totalSen;

  /// Jumlah tagihan yang jatuh tempo bulan ini.
  final int jumlah;

  /// Dari [jumlah], berapa yang statusnya sudah lunas.
  final int jumlahSudahDibayar;

  /// Rincian per kategori, urut total terbesar lalu nama (A–Z).
  final List<BagianKategori> perKategori;

  /// Kunci bulan `YYYY-MM`.
  String get kunci => kunciBulanDari(DateTime(tahun, bulan));

  /// true = tidak ada tagihan yang jatuh tempo bulan ini.
  bool get kosong => jumlah == 0;

  /// Jumlah tagihan yang belum dibayar (beban yang masih berjalan).
  int get jumlahBelumDibayar => jumlah - jumlahSudahDibayar;

  /// Label sumbu grafik: "Sep" (Januari memakai tahun, mis. "Jan 2027")
  /// supaya pergantian tahun tetap terlihat.
  String get labelSumbu => labelSumbuBulan(kunci);

  /// Label ringkas berpemilih bulan: "Sep 2026".
  String get labelPendek => labelBulanPendek(kunci);

  /// Label panjang: "September 2026".
  String get labelPanjang => labelBulanPanjang(kunci);
}

/// Hasil hitung beban tagihan untuk sebuah jendela bulan.
class BebanTagihan {
  const BebanTagihan({
    required this.bulan,
    this.kategori = const <KategoriBeban>[],
    required this.adaData,
  });

  /// Bulan pada jendela, urut dari PALING LAMA ke PALING BARU.
  final List<BulanBeban> bulan;

  /// Kategori yang dikenal saat hitungan dibuat.
  final List<KategoriBeban> kategori;

  /// true = ada minimal satu tagihan pada jendela ini.
  final bool adaData;

  /// Keadaan "belum ada data" ditulis apa adanya (aturan III-11: bukan
  /// teguran, bukan angka nol yang menyamar sebagai data).
  static const String pesanBelumAdaData = 'Belum ada tagihan pada rentang ini';

  /// Dipakai saat bulan yang dilihat tidak punya tagihan, sedangkan bulan lain
  /// punya — jadi jelas bedanya "tidak ada" dan "tidak dilihat".
  static const String pesanBulanKosong = 'Belum ada tagihan pada bulan ini';

  /// Alasan singkat wajib yang ditulis di layar (FR-28 butir b).
  static const String catatanTermasukDibayar = 'termasuk yang sudah dibayar';

  /// Nama kelompok untuk tagihan tanpa kategori (atau kategori tak dikenal).
  static const String tanpaKategori = 'Tanpa kategori';

  /// Jumlah bulan pada jendela.
  int get jumlahBulan => bulan.length;

  /// Total beban seluruh jendela (sen).
  int get totalSen => bulan.fold<int>(0, (a, b) => a + b.totalSen);

  /// Bulan berjalan = bulan terakhir pada jendela.
  BulanBeban get bulanTerbaru => bulan.last;

  /// Bulan dengan kunci `YYYY-MM`, atau null bila di luar jendela.
  BulanBeban? bulanKe(String? kunci) {
    if (kunci == null) return null;
    for (final b in bulan) {
      if (b.kunci == kunci) return b;
    }
    return null;
  }

  /// Rincian kategori bulan tertentu (kosong bila bulan di luar jendela).
  List<BagianKategori> bagianUntuk(String kunci) =>
      bulanKe(kunci)?.perKategori ?? const <BagianKategori>[];

  /// Hitung beban tagihan untuk [jumlahBulan] bulan terakhir sampai [acuan].
  ///
  /// [acuan] bawaan = [waktuSekarang] (satu sumber waktu aplikasi). [hanyaAktif]
  /// menyaring tagihan nonaktif; bawaan false karena ini catatan beban.
  factory BebanTagihan.hitung({
    required List<TagihanBeban> tagihan,
    List<KategoriBeban> kategori = const <KategoriBeban>[],
    DateTime? acuan,
    int jumlahBulan = 6,
    bool hanyaAktif = false,
  }) {
    if (jumlahBulan < 1) {
      throw ArgumentError.value(
          jumlahBulan, 'jumlahBulan', 'Jumlah bulan minimal 1.');
    }
    final patokan = acuan ?? waktuSekarang();

    // Daftar kunci bulan jendela: paling lama -> paling baru.
    final kunciJendela = <String>[
      for (var i = jumlahBulan - 1; i >= 0; i--)
        kunciBulanDari(DateTime(patokan.year, patokan.month - i)),
    ];

    final namaKategori = <int, String>{for (final k in kategori) k.id: k.nama};
    final idKategori = <String, int>{for (final k in kategori) k.nama: k.id};

    final perBulan = <String, List<TagihanBeban>>{
      for (final k in kunciJendela) k: <TagihanBeban>[],
    };
    for (final t in tagihan) {
      if (hanyaAktif && !t.aktif) continue;
      final daftar = perBulan[t.kunciBulan];
      if (daftar == null) continue; // di luar jendela bulan: diabaikan
      daftar.add(t);
    }

    var adaData = false;
    final daftarBulan = <BulanBeban>[];
    for (final kunci in kunciJendela) {
      final isi = perBulan[kunci]!;
      var total = 0;
      var sudahDibayar = 0;
      final kelompok = <String, _AkumulasiKategori>{};
      for (final t in isi) {
        total += t.nominalSen;
        if (t.sudahDibayar) sudahDibayar++;
        final dikenal =
            t.kategoriId != null && namaKategori.containsKey(t.kategoriId);
        final nama = dikenal ? namaKategori[t.kategoriId]! : tanpaKategori;
        final a = kelompok.putIfAbsent(nama, () => _AkumulasiKategori());
        a.totalSen += t.nominalSen;
        a.jumlah++;
      }

      // Urut: total terbesar lebih dulu, lalu nama A–Z (stabil & mudah dibaca).
      final urut = kelompok.entries.toList()
        ..sort((a, b) {
          final selisih = b.value.totalSen.compareTo(a.value.totalSen);
          return selisih != 0 ? selisih : a.key.compareTo(b.key);
        });
      final teksBagian =
          _teksBagian([for (final e in urut) e.value.totalSen], total);

      if (isi.isNotEmpty) adaData = true;
      final tanggal = bulanDariKunci(kunci)!;
      daftarBulan.add(BulanBeban(
        tahun: tanggal.year,
        bulan: tanggal.month,
        totalSen: total,
        jumlah: isi.length,
        jumlahSudahDibayar: sudahDibayar,
        perKategori: <BagianKategori>[
          for (var i = 0; i < urut.length; i++)
            BagianKategori(
              kategoriId: idKategori[urut[i].key],
              nama: urut[i].key,
              totalSen: urut[i].value.totalSen,
              jumlah: urut[i].value.jumlah,
              bagian: total <= 0 ? 0 : urut[i].value.totalSen / total,
              bagianTeks: teksBagian[i],
            ),
        ],
      ));
    }

    return BebanTagihan(
      bulan: daftarBulan,
      kategori: List<KategoriBeban>.unmodifiable(kategori),
      adaData: adaData,
    );
  }
}

/// Penjumlah sementara satu kelompok kategori pada satu bulan.
class _AkumulasiKategori {
  int totalSen = 0;
  int jumlah = 0;
}

/// Teks persen (satu angka di belakang koma, koma desimal Indonesia).
///
/// Perhitungan dilakukan dalam permil (bilangan bulat) supaya hasil penjumlahan
/// tidak melenceng karena pembulatan: sisa pembulatan diberikan ke kategori
/// terbesar (kategori pertama, karena daftar sudah urut menurun). Bila kategori
/// terbesar tidak cukup menyerap sisa, penyesuaian dilewati dan teks tetap
/// angka pembulatan biasa.
List<String> _teksBagian(List<int> totalSenPerKategori, int total) {
  final n = totalSenPerKategori.length;
  if (n == 0) return const <String>[];
  if (total <= 0) return List<String>.filled(n, '0,0%');
  final permil = <int>[
    for (final t in totalSenPerKategori) (t * 1000 / total).round(),
  ];
  var sisa = 1000;
  for (final p in permil) {
    sisa -= p;
  }
  if (permil[0] + sisa >= 0) permil[0] += sisa;
  return <String>[
    for (final p in permil)
      '${(p / 10).toStringAsFixed(1).replaceAll('.', ',')}%',
  ];
}

// ---------------------------------------------------------------------------
// Label bulan (tanpa data locale intl — aman di isolate latar & pengujian)
// ---------------------------------------------------------------------------

const List<String> _namaBulanPanjang = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

const List<String> _namaBulanSingkat = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Bulan (1–12) dari kunci `YYYY-MM`; null bila kunci tidak sah.
int? _bulanKe(String kunci) {
  final b = bulanDariKunci(kunci);
  return b?.month;
}

/// Label sumbu grafik dari kunci `YYYY-MM`: "Sep"; Januari menulis
/// "Jan 2027" agar pergantian tahun tetap terbaca.
String labelSumbuBulan(String kunci) {
  final b = _bulanKe(kunci);
  if (b == null) return kunci.trim();
  final nama = _namaBulanSingkat[b - 1];
  return b == 1 ? '$nama ${kunci.trim().split('-').first}' : nama;
}

/// Label ringkas berpemilih bulan: "Sep 2026".
String labelBulanPendek(String kunci) {
  final b = _bulanKe(kunci);
  if (b == null) return kunci.trim();
  final tahun = kunci.trim().split('-').first;
  return '${_namaBulanSingkat[b - 1]} $tahun';
}

/// Label panjang dari kunci `YYYY-MM`: "September 2026".
String labelBulanPanjang(String kunci) {
  final b = _bulanKe(kunci);
  if (b == null) return kunci.trim();
  final tahun = kunci.trim().split('-').first;
  return '${_namaBulanPanjang[b - 1]} $tahun';
}

/// Kunci bulan `YYYY-MM` dari sebuah tanggal (re-export agar pemakai inti ini
/// tidak perlu mengimpor dua berkas).
String kunciBulanDari(DateTime tanggal) => kunciBulan(tanggal);
