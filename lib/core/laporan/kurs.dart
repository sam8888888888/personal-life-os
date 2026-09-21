/// FR-52 — Multi-mata uang & konversi. Murni: tanpa I/O.
///
/// Setiap tagihan sudah punya kolom `kodeMataUang` sendiri (disiapkan sejak
/// v1). Di sini: daftar mata uang yang didukung, pemformatan per mata uang,
/// tabel kurs yang DISIMPAN PENGGUNA, dan konversi ke mata uang utama.
///
/// Kejujuran soal kurs (penting): aplikasi TIDAK mengambil kurs dari internet
/// dan tidak berpura-pura tahu kurs hari ini. Kurs diisi pengguna, dan layar
/// selalu menampilkan asal kurs + kapan terakhir diperbarui. Kalau kurs belum
/// diisi, konversi tidak dilakukan dan aplikasi mengatakannya.
library;

import 'dart:convert';

import 'package:intl/intl.dart';

import '../../data/repository/pengaturan_repository.dart';

/// Kunci penyimpanan kurs di tabel pengaturan.
const String kunciKurs = 'kurs_manual';

/// Satu mata uang yang dikenal aplikasi (kode ISO 4217).
class InfoMataUang {
  const InfoMataUang({
    required this.kode,
    required this.simbol,
    required this.locale,
    required this.desimal,
    required this.nama,
    this.utama = false,
  });

  final String kode;
  final String simbol;
  final String locale;
  final int desimal;
  final String nama;

  /// Mata uang acuan konversi (Rupiah).
  final bool utama;
}

/// Mata uang yang didukung FR-52/FR-152.
const List<InfoMataUang> mataUangDidukung = [
  InfoMataUang(
      kode: 'IDR',
      simbol: 'Rp ',
      locale: 'id_ID',
      desimal: 0,
      nama: 'Rupiah',
      utama: true),
  InfoMataUang(
      kode: 'MYR',
      simbol: 'RM ',
      locale: 'ms_MY',
      desimal: 2,
      nama: 'Ringgit Malaysia'),
  InfoMataUang(
      kode: 'THB', simbol: '฿', locale: 'th_TH', desimal: 2, nama: 'Baht Thailand'),
  InfoMataUang(
      kode: 'VND', simbol: '₫', locale: 'vi_VN', desimal: 0, nama: 'Dong Vietnam'),
  InfoMataUang(
      kode: 'PHP', simbol: '₱', locale: 'fil_PH', desimal: 2, nama: 'Peso Filipina'),
  InfoMataUang(
      kode: 'USD', simbol: r'$', locale: 'en_US', desimal: 2, nama: 'Dolar AS'),
];

/// Cari info mata uang; kode tak dikenal → null (dipanggil dengan hati-hati,
/// supaya salah tulis kode tidak diam-diam jadi Rupiah).
InfoMataUang? infoMataUang(String? kode) {
  if (kode == null) return null;
  final k = kode.trim().toUpperCase();
  for (final m in mataUangDidukung) {
    if (m.kode == k) return m;
  }
  return null;
}

/// Format uang dengan satuan terkecil (sen/cent). Bila kode tidak dikenal,
/// ditulis dengan kodenya di depan — tidak dipalsukan jadi Rupiah.
String fmtMataUang(int satuanTerkecil, String? kode) {
  final info = infoMataUang(kode);
  if (info == null) return '${(kode ?? '').trim()} ${satuanTerkecil / 100}';
  return NumberFormat.currency(
    locale: info.locale,
    symbol: info.simbol,
    decimalDigits: info.desimal,
  ).format(satuanTerkecil / 100);
}

/// Kurs satu mata uang: berapa Rupiah untuk 1 unit mata uang itu.
class Kurs {
  const Kurs({
    required this.kode,
    required this.rupiahPerUnit,
    required this.sumber,
    required this.diperbarui,
  });

  final String kode;

  /// Rupiah untuk 1 unit (mis. 1 USD = 16.200).
  final double rupiahPerUnit;

  /// Dari mana angka ini (mis. "Bank Indonesia", "catatan sendiri").
  final String sumber;
  final DateTime diperbarui;

  Map<String, dynamic> keJson() => {
        'kode': kode,
        'rupiah_per_unit': rupiahPerUnit,
        'sumber': sumber,
        'diperbarui': diperbarui.toIso8601String(),
      };

  static Kurs? dariJson(Map<String, dynamic> j) {
    final kode = j['kode'] as String?;
    final nilai = j['rupiah_per_unit'];
    if (kode == null || nilai is! num) return null;
    return Kurs(
      kode: kode,
      rupiahPerUnit: nilai.toDouble(),
      sumber: j['sumber'] as String? ?? 'tidak dicatat',
      diperbarui:
          DateTime.tryParse(j['diperbarui'] as String? ?? '') ?? DateTime(2000),
    );
  }
}

/// Tabel kurs yang disimpan pengguna (satu JSON di tabel pengaturan).
class TabelKurs {
  const TabelKurs(this.pengaturan);

  final PengaturanRepository pengaturan;

  Future<Map<String, Kurs>> semua() async {
    final teks = await pengaturan.baca(kunciKurs);
    if (teks == null || teks.trim().isEmpty) return {};
    final Object? data = jsonDecode(teks);
    if (data is! Map) return {};
    final hasil = <String, Kurs>{};
    data.forEach((kunci, nilai) {
      if (nilai is! Map) return;
      final kurs = Kurs.dariJson(
          nilai.map((k, v) => MapEntry(k.toString(), v)));
      if (kurs != null) hasil[kunci.toString().toUpperCase()] = kurs;
    });
    return hasil;
  }

  Future<void> simpan(Kurs kurs) async {
    final peta = await semua()..[kurs.kode.toUpperCase()] = kurs;
    await _tulis(peta);
  }

  Future<void> hapus(String kode) async {
    final peta = await semua()..remove(kode.toUpperCase());
    await _tulis(peta);
  }

  Future<void> _tulis(Map<String, Kurs> peta) async {
    await pengaturan.simpan(
      kunciKurs,
      jsonEncode({for (final e in peta.entries) e.key: e.value.keJson()}),
    );
  }
}

/// Konversi nilai ke Rupiah. null = kurs belum diisi (bukan salah hitung).
int? rupiahDari(int satuanTerkecil, String kode, Map<String, Kurs> kurs) {
  final info = infoMataUang(kode);
  if (info == null) return null;
  if (info.utama) return satuanTerkecil;
  final k = kurs[info.kode];
  if (k == null || k.rupiahPerUnit <= 0) return null;
  // satuanTerkecil → unit → rupiah → satuan terkecil Rupiah (sen).
  final unit = satuanTerkecil / 100;
  return (unit * k.rupiahPerUnit * 100).round();
}

/// Ringkasan per mata uang untuk daftar tagihan.
class RingkasMataUang {
  const RingkasMataUang({
    required this.kode,
    required this.jumlahTagihan,
    required this.totalSatuanTerkecil,
    required this.totalRupiahSen,
    required this.adaKurs,
  });

  final String kode;
  final int jumlahTagihan;
  final int totalSatuanTerkecil;

  /// Total dalam sen Rupiah (null bila kurs belum diisi untuk mata uang ini).
  final int? totalRupiahSen;
  final bool adaKurs;
}

/// Hitung ringkasan per mata uang dari daftar tagihan (yang belum lunas saja
/// bila [hanyaBelumLunas]).
List<RingkasMataUang> ringkasPerMataUang(
  List<({String kode, int satuanTerkecil})> baris,
  Map<String, Kurs> kurs,
) {
  final kelompok = <String, List<int>>{};
  for (final b in baris) {
    final info = infoMataUang(b.kode);
    final kode = info?.kode ?? b.kode.trim().toUpperCase();
    kelompok.putIfAbsent(kode, () => []).add(b.satuanTerkecil);
  }

  final hasil = <RingkasMataUang>[];
  kelompok.forEach((kode, daftar) {
    final total = daftar.fold<int>(0, (a, b) => a + b);
    final rupiah = rupiahDari(total, kode, kurs);
    hasil.add(RingkasMataUang(
      kode: kode,
      jumlahTagihan: daftar.length,
      totalSatuanTerkecil: total,
      totalRupiahSen: rupiah,
      adaKurs: rupiah != null,
    ));
  });
  hasil.sort((a, b) => b.jumlahTagihan.compareTo(a.jumlahTagihan));
  return hasil;
}

/// Kalimat keterangan kurs untuk layar (menyebut asal & waktu — tanpa mengarang).
String keteranganKurs(Kurs? k) {
  if (k == null) {
    return 'Kurs belum diisi — nominal mata uang ini belum bisa dikonversi.';
  }
  final d = k.diperbarui;
  String dua(int n) => n.toString().padLeft(2, '0');
  return '1 ${k.kode} = Rp ${NumberFormat.decimalPattern('id_ID').format(k.rupiahPerUnit)} '
      '· sumber: ${k.sumber} · diperbarui '
      '${dua(d.day)}/${dua(d.month)}/${d.year} ${dua(d.hour)}:${dua(d.minute)}';
}
