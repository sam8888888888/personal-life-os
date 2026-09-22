/// FR-38 (impor tagihan dari foto/screenshot) & FR-50 (perluas ke struk belanja
/// dan nota manual) — mesin tafsir hasil OCR.
///
/// Mesin ini MURNI: masukannya teks hasil OCR, keluarannya DRAF yang wajib
/// diperiksa pengguna. Tidak ada penyimpanan dan tidak ada jaringan di sini.
library;

import 'package:flutter/foundation.dart';

import '../utils/uang_utils.dart';
import 'parsing_cerdas.dart' show uraiTanggal;

/// Jenis dokumen yang dikenali dari teks.
enum JenisOcr {
  tagihan('tagihan', 'Tagihan (listrik/air/internet/dll)'),
  struk('struk', 'Struk belanja'),
  nota('nota', 'Nota manual'),
  tidakDikenali('tidak', 'Belum bisa dikenali');

  const JenisOcr(this.kode, this.label);

  final String kode;
  final String label;
}

/// Satu baris barang di struk/nota.
@immutable
class ItemOcr {
  const ItemOcr({required this.nama, required this.hargaSen});

  final String nama;
  final int hargaSen;
}

/// Draf hasil tafsir — belum tersimpan.
@immutable
class DrafOcr {
  const DrafOcr({
    required this.teksMentah,
    required this.jenis,
    this.nama = '',
    this.nominalSen,
    this.jatuhTempo,
    this.nomorPelanggan,
    this.item = const [],
    this.keyakinan = 0,
    this.alasan = const [],
    this.barisTerpakai = const [],
  });

  final String teksMentah;
  final JenisOcr jenis;

  /// Nama penyedia (tagihan) atau merchant (struk/nota).
  final String nama;
  final int? nominalSen;
  final DateTime? jatuhTempo;

  /// Nomor pelanggan/rekening bila terbaca.
  final String? nomorPelanggan;
  final List<ItemOcr> item;

  /// 0–100; makin rendah makin wajib diperiksa.
  final int keyakinan;

  /// Yang belum bisa diisi (harus dilengkapi pengguna).
  final List<String> alasan;

  /// Baris OCR yang jadi dasar angka (untuk ditunjukkan di layar).
  final List<String> barisTerpakai;

  bool get dikenali => jenis != JenisOcr.tidakDikenali;

  bool get adaNominal => (nominalSen ?? 0) > 0;

  /// Kalimat ringkas untuk kartu konfirmasi.
  String get kalimat {
    if (!dikenali) {
      return 'Gambar ini belum bisa dikenali sebagai tagihan, struk, atau nota. '
          'Coba foto ulang dengan pencahayaan lebih baik, atau isi manual.';
    }
    final bagian = <String>[jenis.label];
    if (nama.trim().isNotEmpty) bagian.add(nama.trim());
    if (adaNominal) bagian.add(fmtRpDariSen(nominalSen!));
    if (jatuhTempo != null) {
      bagian.add('jatuh tempo ${jatuhTempo!.day}/${jatuhTempo!.month}/'
          '${jatuhTempo!.year}');
    }
    if (item.isNotEmpty) bagian.add('${item.length} barang terbaca');
    return '${bagian.join(' · ')} — periksa dulu sebelum disimpan.';
  }

  /// Total item bila ada (dipakai untuk membandingkan dengan "TOTAL" di struk).
  int get totalItemSen => item.fold<int>(0, (a, b) => a + b.hargaSen);
}

const List<String> _kataTagihan = [
  'tagihan',
  'jatuh tempo',
  'pelanggan',
  'rekening',
  'meter',
  'pln',
  'pdam',
  'indihome',
  'telkom',
  'bpjs',
  'pajak',
  'tagihan listrik',
  'stand meter',
  'rptag',
  'tagihan air',
  'cicilan',
  'angsuran',
  'iuran',
];

const List<String> _kataStruk = [
  'struk',
  'nota',
  'kasir',
  'qty',
  'item',
  'subtotal',
  'sub total',
  'total bayar',
  'tunai',
  'kembali',
  'kembalian',
  'npwp',
  'jl.',
  'jalan',
  'terima kasih',
];

/// Baris yang mirip alamat/keterangan toko — bukan barang yang dibeli.
const List<String> _kataBukanBarang = [
  'jl.',
  'jl ',
  'jalan',
  'telp',
  'tel:',
  'tel ',
  'npwp',
  'kasir',
  'tanggal',
  'alamat',
  'www',
  'http',
  'instagram',
  'no. ',
  'shift',
];

const List<String> _kataTotal = [
  'total',
  'jumlah',
  'grand total',
  'total bayar',
  'yang harus dibayar',
  'harus dibayar',
  'tagihan anda',
  'rptag',
  'amount',
];

/// Angka uang pada satu baris OCR → sen.
///
/// Menangani "Rp 250.000", "250.000,00", "1.234.567", "Rp250.000,50".
int? uraiNominalOcr(String baris) {
  // Catatan: RegExp Dart tidak mendukung bendera inline (?i) — pakai
  // caseSensitive: false.
  final bersih = baris
      .replaceAll(RegExp(r'rp\.?\s*', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'idr\.?\s*', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'total|jumlah|bayar', caseSensitive: false), ' ');
  final cocok = RegExp(r'(\d{1,3}(?:[.,]\d{3})+|\d+)(?:[.,](\d{1,2}))?')
      .allMatches(bersih);
  int? terbesar;
  for (final c in cocok) {
    final utuh = c.group(1)!;
    final sen = c.group(2);
    double? nilai;
    if (RegExp(r'^\d{1,3}(?:[.,]\d{3})+$').hasMatch(utuh)) {
      nilai = double.tryParse(utuh.replaceAll(RegExp(r'[.,]'), ''));
    } else {
      nilai = double.tryParse(utuh);
    }
    if (nilai == null || nilai <= 0) continue;
    var senNilai = (nilai * 100).round();
    // "250.000,50" → dua angka terakhir = sen (bukan pembulatan ribuan).
    if (sen != null && RegExp(r'[.,]\d{2}$').hasMatch(c.group(0)!)) {
      senNilai = nilai.floor() * 100 +
          int.parse(sen.padRight(2, '0').substring(0, 2));
    }
    if (terbesar == null || senNilai > terbesar) terbesar = senNilai;
  }
  return terbesar;
}

/// Nomor pelanggan/rekening: deretan 8–16 angka (tanpa titik).
String? uraiNomorPelanggan(String teks) {
  final cocok = RegExp(r'\b(\d{8,16})\b').allMatches(teks.replaceAll('.', ''));
  for (final c in cocok) {
    final nomor = c.group(1)!;
    return nomor;
  }
  return null;
}

/// Baris mana yang memuat angka terbesar (dasar nominal).
String? _barisDengan(String Function(String) pencari, List<String> baris) {
  for (final b in baris) {
    final hasil = pencari(b);
    if (hasil.trim().isNotEmpty) return b;
  }
  return null;
}

/// Urai teks OCR menjadi draf tagihan/struk/nota.
DrafOcr uraikanTeksOcr(String teks, {DateTime? sekarang}) {
  final mentah = teks.trim();
  if (mentah.isEmpty) {
    return const DrafOcr(
      teksMentah: '',
      jenis: JenisOcr.tidakDikenali,
      alasan: ['Tidak ada teks yang terbaca dari gambar.'],
    );
  }
  final baris = [
    for (final b in mentah.split(RegExp(r'\r?\n')))
      if (b.trim().isNotEmpty) b.trim(),
  ];
  final kecil = mentah.toLowerCase();
  final alasan = <String>[];

  final skorTagihan =
      _kataTagihan.where((k) => kecil.contains(k)).length;
  final skorStruk = _kataStruk.where((k) => kecil.contains(k)).length;
  final adaNomorPanjang = RegExp(r'\b\d{8,16}\b').hasMatch(kecil.replaceAll('.', ''));

  var jenis = JenisOcr.nota;
  if (skorTagihan >= skorStruk && (skorTagihan > 0 || adaNomorPanjang)) {
    jenis = JenisOcr.tagihan;
  } else if (skorStruk > 0) {
    jenis = JenisOcr.struk;
  } else {
    jenis = JenisOcr.nota;
  }

  // ── nominal: utamakan baris yang memuat kata total/jumlah ────────────────
  int? nominal;
  final barisTerpakai = <String>[];
  final barisTotal = _barisDengan(
    (b) => _kataTotal.any((k) => b.toLowerCase().contains(k)) ? b : '',
    baris.reversed.toList(),
  );
  if (barisTotal != null) {
    nominal = uraiNominalOcr(barisTotal);
    barisTerpakai.add(barisTotal);
  }
  if (nominal == null) {
    // Cadangan: angka terbesar di seluruh teks.
    int? terbesar;
    String? dariBaris;
    for (final b in baris.reversed) {
      final n = uraiNominalOcr(b);
      if (n == null) continue;
      if (terbesar == null || n > terbesar) {
        terbesar = n;
        dariBaris = b;
      }
    }
    nominal = terbesar;
    if (dariBaris != null) barisTerpakai.add(dariBaris);
  }
  if (nominal == null) {
    alasan.add('Angka nominal belum terbaca dari gambar.');
  }

  // ── tanggal jatuh tempo ─────────────────────────────────────────────────
  DateTime? jatuhTempo;
  for (final b in baris) {
    final k = b.toLowerCase();
    if (k.contains('jatuh tempo') ||
        k.contains('tempo') ||
        k.contains('bayar sebelum') ||
        k.contains('due')) {
      jatuhTempo = uraiTanggal(b, sekarang: sekarang);
      if (jatuhTempo != null) {
        if (!barisTerpakai.contains(b)) barisTerpakai.add(b);
        break;
      }
    }
  }
  jatuhTempo ??= uraiTanggal(mentah, sekarang: sekarang);

  // ── nama penyedia / merchant ────────────────────────────────────────────
  String nama = '';
  for (final b in baris) {
    final huruf = RegExp(r'[A-Za-z]').allMatches(b).length;
    final angka = RegExp(r'\d').allMatches(b).length;
    if (huruf < 4 || angka > huruf) continue;
    final k = b.toLowerCase();
    if (_kataTotal.any(k.contains) && b.split(' ').length > 4) continue;
    if (k.contains('struk') || k.contains('nota')) continue;
    nama = b.length > 60 ? b.substring(0, 60) : b;
    break;
  }
  if (nama.isEmpty) {
    alasan.add('Nama tagihan/toko belum terbaca — isi sendiri dulu.');
  }

  final nomorPelanggan = uraiNomorPelanggan(mentah);

  // ── item struk/nota: baris "nama ... harga" ────────────────────────────
  final item = <ItemOcr>[];
  if (jenis == JenisOcr.struk || jenis == JenisOcr.nota) {
    for (final b in baris) {
      final k = b.toLowerCase();
      if (_kataTotal.any(k.contains)) continue;
      // Baris alamat/keterangan toko bukan barang (mis. "Jl. Raya Darmo 12").
      if (_kataBukanBarang.any(k.contains)) continue;
      final n = uraiNominalOcr(b);
      if (n == null) continue;
      final namaItem = b
          .replaceAll(RegExp(r'[\d.,]+'), ' ')
          .replaceAll(RegExp(r'\b(rp|qty|x)\b', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (namaItem.length < 3) continue;
      item.add(ItemOcr(nama: namaItem, hargaSen: n));
      if (item.length >= 30) break;
    }
  }

  // Ada beberapa barang + baris TOTAL ⇒ ini struk, walau kata "struk"/"nota"
  // tidak terbaca sama sekali (jujur: bentuknya memang struk belanja).
  if (jenis == JenisOcr.nota &&
      item.length >= 2 &&
      barisTotal != null &&
      !kecil.contains('nota')) {
    jenis = JenisOcr.struk;
  }

  // ── keyakinan & alasan jujur ────────────────────────────────────────────
  var keyakinan = 40;
  if (nominal != null) keyakinan += 25;
  if (barisTotal != null) keyakinan += 10;
  if (nama.isNotEmpty) keyakinan += 10;
  if (jenis == JenisOcr.tagihan && jatuhTempo != null) keyakinan += 10;
  if (jenis == JenisOcr.tidakDikenali) keyakinan = 20;
  if (keyakinan > 95) keyakinan = 95;

  if (jenis == JenisOcr.tagihan && jatuhTempo == null) {
    alasan.add('Jatuh tempo belum terbaca — isi tanggalnya sebelum disimpan.');
  }
  if (item.isNotEmpty && nominal != null) {
    final selisih = (nominal - item.fold<int>(0, (a, b) => a + b.hargaSen)).abs();
    if (selisih > nominal * 5 ~/ 100) {
      alasan.add('Jumlah barang (${fmtRpDariSen(item.fold<int>(0, (a, b) => a + b.hargaSen))}) '
          'tidak sama dengan total yang terbaca (${fmtRpDariSen(nominal)}).');
    }
  }

  return DrafOcr(
    teksMentah: mentah,
    jenis: jenis,
    nama: nama,
    nominalSen: nominal,
    jatuhTempo: jatuhTempo,
    nomorPelanggan: nomorPelanggan,
    item: item,
    keyakinan: keyakinan,
    alasan: alasan,
    barisTerpakai: barisTerpakai,
  );
}

/// Sudah cukup lengkap untuk disimpan sebagai tagihan?
bool drafOcrSiapSebagaiTagihan(DrafOcr d) =>
    d.dikenali && d.nama.trim().isNotEmpty && d.adaNominal && d.jatuhTempo != null;

/// Sudah cukup lengkap untuk disimpan sebagai pengeluaran (struk/nota)?
bool drafOcrSiapSebagaiPengeluaran(DrafOcr d) =>
    d.dikenali && d.adaNominal;

/// Catatan jujur tentang batas OCR (ditampilkan di layar).
const String catatanOcr =
    'Pembacaan foto memakai model OCR yang tertanam di aplikasi (di perangkat, '
    'tanpa internet). Kualitas hasil sangat bergantung pada foto: terang, tegak, '
    'dan angka tidak terpotong. Angka yang terbaca tetap berupa DRAF dan wajib '
    'Anda periksa — terutama nominal dan tanggal jatuh tempo.';
