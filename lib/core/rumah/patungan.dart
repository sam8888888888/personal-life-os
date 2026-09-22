/// FR-47 — Split Bill & Patungan (memperluas FR-43 Mode Rumah Tangga).
///
/// Grup patungan berisi anggota + daftar belanja. Mesin menghitung, per
/// anggota: berapa yang ia bayar, berapa tanggungannya, dan selisihnya —
/// lalu menyusun langkah pelunasan paling ringkas ("siapa transfer ke siapa").
///
/// Semua hitungan memakai angka pengguna apa adanya. Bila data tidak lengkap
/// (belanja tanpa pembayar, bagian tidak sama dengan total, anggota tanpa
/// bagian) mesin TIDAK menebak: itu masuk `belumBisa`/`peringatan`.
library;

import 'package:flutter/foundation.dart';

/// Cara membagi satu belanja.
enum CaraBagi {
  samaRata('sama', 'Sama rata'),
  khusus('khusus', 'Bagian khusus');

  const CaraBagi(this.kode, this.label);
  final String kode;
  final String label;

  static CaraBagi dariKode(String? kode) => values.firstWhere(
        (c) => c.kode == kode,
        orElse: () => CaraBagi.samaRata,
      );
}

/// Grup patungan.
@immutable
class GrupPatungan {
  const GrupPatungan({
    required this.nama,
    this.catatan,
    this.kodeUndangan,
    this.arsip = false,
  });

  final String nama;
  final String? catatan;

  /// Kode untuk dibagikan ke anggota lain (tanpa akun) — dipakai saat
  /// mengekspor/mengimpor data grup.
  final String? kodeUndangan;
  final bool arsip;
}

/// Anggota grup.
@immutable
class AnggotaPatungan {
  const AnggotaPatungan({required this.grupNama, required this.nama});
  final String grupNama;
  final String nama;
}

/// Satu belanja/nota di grup.
@immutable
class BelanjaPatungan {
  const BelanjaPatungan({
    required this.grupNama,
    required this.judul,
    required this.totalSen,
    required this.pembayar,
    required this.tanggal,
    this.cara = CaraBagi.samaRata,
    this.catatan,
  });

  final String grupNama;
  final String judul;
  final int totalSen;
  final String pembayar;
  final DateTime tanggal;
  final CaraBagi cara;
  final String? catatan;
}

/// Bagian satu anggota pada satu belanja (kunci belanja = judul + waktu).
@immutable
class BagianPatungan {
  const BagianPatungan({
    required this.kunciBelanja,
    required this.anggota,
    required this.jumlahSen,
  });

  final String kunciBelanja;
  final String anggota;
  final int jumlahSen;
}

/// Kunci belanja untuk memasangkan belanja dengan bagiannya.
String kunciBelanja(BelanjaPatungan b) =>
    '${b.judul.trim()}|${b.tanggal.toIso8601String()}|${b.totalSen}';

/// Saldo satu anggota.
@immutable
class SaldoPatungan {
  const SaldoPatungan({
    required this.nama,
    required this.dibayarSen,
    required this.tanggunganSen,
  });

  final String nama;
  final int dibayarSen;
  final int tanggunganSen;

  /// Positif = harus menerima uang; negatif = harus membayar.
  int get selisihSen => dibayarSen - tanggunganSen;

  bool get harusMenerima => selisihSen > 0;
  bool get harusMembayar => selisihSen < 0;

  String get dasar => 'bayar ${_rp(dibayarSen)} · tanggungan '
      '${_rp(tanggunganSen)} · ${selisihSen == 0 ? 'pas' : (harusMenerima ? 'terima ${_rp(selisihSen)}' : 'bayar ${_rp(-selisihSen)}')}';
}

/// Langkah pelunasan antar-anggota.
@immutable
class TransferPatungan {
  const TransferPatungan({
    required this.dari,
    required this.ke,
    required this.jumlahSen,
  });

  final String dari;
  final String ke;
  final int jumlahSen;
}

/// Hasil hitungan satu grup.
@immutable
class HasilPatungan {
  const HasilPatungan({
    required this.grupNama,
    required this.saldo,
    required this.transfer,
    required this.totalBelanjaSen,
    required this.jumlahBelanja,
    required this.belumBisa,
    required this.peringatan,
  });

  final String grupNama;
  final List<SaldoPatungan> saldo;
  final List<TransferPatungan> transfer;
  final int totalBelanjaSen;
  final int jumlahBelanja;
  final List<String> belumBisa;
  final List<String> peringatan;

  String get dasar => '$jumlahBelanja belanja · total ${_rp(totalBelanjaSen)} '
      '· ${saldo.length} anggota.';

  /// Ringkas kalimat "siapa ke siapa".
  String transferTeks(TransferPatungan t) =>
      '${t.dari} transfer ${_rp(t.jumlahSen)} ke ${t.ke}';

  bool get lunas => transfer.isEmpty && belumBisa.isEmpty;
}

/// Bagi rata dengan sisa pembulatan dibebankan berurutan ke anggota pertama.
///
/// Contoh: 100.000 untuk 3 orang → 33.334, 33.333, 33.333 (jumlahnya tetap
/// pas 100.000 — tidak ada uang yang hilang karena pembulatan).
Map<String, int> bagiSamaRata(int totalSen, List<String> anggota) {
  final hasil = <String, int>{};
  if (anggota.isEmpty) return hasil;
  final dasar = totalSen ~/ anggota.length;
  var sisa = totalSen - dasar * anggota.length;
  for (final a in anggota) {
    var bagian = dasar;
    if (sisa > 0) {
      bagian += 1;
      sisa -= 1;
    }
    hasil[a] = bagian;
  }
  return hasil;
}

/// Hitung grup patungan.
HasilPatungan hitungPatungan({
  required GrupPatungan grup,
  required List<AnggotaPatungan> anggota,
  required List<BelanjaPatungan> belanja,
  required List<BagianPatungan> bagian,
}) {
  final namaAnggota = anggota.map((a) => a.nama).toSet();
  final dibayar = <String, int>{for (final a in namaAnggota) a: 0};
  final tanggungan = <String, int>{for (final a in namaAnggota) a: 0};

  final belum = <String>[];
  final peringatan = <String>[];

  if (namaAnggota.isEmpty) {
    belum.add('Grup ${grup.nama} belum punya anggota.');
  }

  var total = 0;
  final daftarBelanja = belanja.where((b) => b.grupNama == grup.nama).toList();

  for (final b in daftarBelanja) {
    total += b.totalSen < 0 ? 0 : b.totalSen;
    if (b.pembayar.trim().isEmpty) {
      peringatan.add('${b.judul}: pembayar belum dipilih, jadi tidak masuk '
          'hitungan "siapa bayar apa".');
      continue;
    }
    if (!namaAnggota.contains(b.pembayar)) {
      peringatan.add('${b.judul}: pembayar "${b.pembayar}" bukan anggota grup.');
    } else {
      dibayar[b.pembayar] = (dibayar[b.pembayar] ?? 0) + (b.totalSen < 0 ? 0 : b.totalSen);
    }

    final kunci = kunciBelanja(b);
    final bagianKu =
        bagian.where((x) => x.kunciBelanja == kunci).toList();
    if (bagianKu.isEmpty) {
      belum.add('${b.judul}: bagian tiap anggota belum diisi, jadi tanggungan '
          'belum bisa dihitung.');
      continue;
    }
    final jumlahBagian = bagianKu.fold<int>(0, (a, x) => a + x.jumlahSen);
    if (jumlahBagian != b.totalSen) {
      peringatan.add('${b.judul}: jumlah bagian ${_rp(jumlahBagian)} tidak sama '
          'dengan total ${_rp(b.totalSen)}.');
    }
    for (final x in bagianKu) {
      if (!namaAnggota.contains(x.anggota)) {
        peringatan.add('${b.judul}: bagian untuk "${x.anggota}" bukan anggota '
            'grup.');
        continue;
      }
      tanggungan[x.anggota] = (tanggungan[x.anggota] ?? 0) + x.jumlahSen;
    }
  }

  if (daftarBelanja.isEmpty) {
    belum.add('Grup ${grup.nama} belum punya belanja/nota.');
  }

  final saldo = namaAnggota
      .map((n) => SaldoPatungan(
            nama: n,
            dibayarSen: dibayar[n] ?? 0,
            tanggunganSen: tanggungan[n] ?? 0,
          ))
      .toList()
    ..sort((a, b) => b.selisihSen.compareTo(a.selisihSen));

  return HasilPatungan(
    grupNama: grup.nama,
    saldo: saldo,
    transfer: susunTransfer(saldo),
    totalBelanjaSen: total,
    jumlahBelanja: daftarBelanja.length,
    belumBisa: belum,
    peringatan: peringatan,
  );
}

/// Susun langkah pelunasan paling ringkas (yang berutang → yang menerima).
List<TransferPatungan> susunTransfer(List<SaldoPatungan> saldo) {
  final harusBayar = saldo
      .where((s) => s.selisihSen < 0)
      .map((s) => _Sisa(s.nama, -s.selisihSen))
      .toList()
    ..sort((a, b) => b.jumlahSen.compareTo(a.jumlahSen));
  final harusTerima = saldo
      .where((s) => s.selisihSen > 0)
      .map((s) => _Sisa(s.nama, s.selisihSen))
      .toList()
    ..sort((a, b) => b.jumlahSen.compareTo(a.jumlahSen));

  final hasil = <TransferPatungan>[];
  var i = 0;
  var j = 0;
  while (i < harusBayar.length && j < harusTerima.length) {
    final bayar = harusBayar[i];
    final terima = harusTerima[j];
    final jumlah = bayar.jumlahSen < terima.jumlahSen
        ? bayar.jumlahSen
        : terima.jumlahSen;
    if (jumlah > 0) {
      hasil.add(TransferPatungan(
        dari: bayar.nama,
        ke: terima.nama,
        jumlahSen: jumlah,
      ));
    }
    bayar.jumlahSen -= jumlah;
    terima.jumlahSen -= jumlah;
    if (bayar.jumlahSen <= 0) i++;
    if (terima.jumlahSen <= 0) j++;
  }
  return hasil;
}

class _Sisa {
  _Sisa(this.nama, this.jumlahSen);
  final String nama;
  int jumlahSen;
}

/// Teks ringkasan patungan untuk dibagikan (WhatsApp dsb.).
String teksRingkasPatungan(HasilPatungan hasil) {
  final baris = <String>['Patungan "${hasil.grupNama}" — ${hasil.dasar}'];
  for (final s in hasil.saldo) {
    baris.add('• ${s.nama}: ${s.dasar}');
  }
  if (hasil.transfer.isEmpty) {
    baris.add('Semua sudah pas, tidak ada yang perlu transfer.');
  } else {
    baris.add('Pelunasan:');
    for (final t in hasil.transfer) {
      baris.add('• ${hasil.transferTeks(t)}');
    }
  }
  for (final b in hasil.belumBisa) {
    baris.add('Belum bisa dihitung: $b');
  }
  return baris.join('\n');
}

String _rp(int sen) {
  final negatif = sen < 0;
  final nilai = negatif ? -sen : sen;
  final rupiah = nilai ~/ 100;
  final teks = rupiah.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
  return '${negatif ? '-' : ''}Rp $teks';
}
