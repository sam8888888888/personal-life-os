/// FR-43 — Mode Rumah Tangga (memperluas FR-47; mesin sama).
///
/// Rumah tangga = wadah: kode undangan tanpa akun, daftar anggota, tagihan
/// bersama, dan riwayat "siapa bayar apa".
///
/// Mesin ini MURNI (tanpa basis data) supaya bisa diuji cepat. Pembagian
/// memakai ULANG [bagiSamaRata] & [susunTransfer] dari FR-47, dan teks
/// pengingat memakai ULANG [teksDelegasiTagihan] dari FR-55 — tidak ada
/// perhitungan kedua yang bisa berbeda hasilnya.
library;

import 'package:flutter/foundation.dart';

import '../utils/uang_utils.dart';
import 'patungan.dart';

/// Anggota rumah tangga (tanpa akun — cukup nama & peran).
@immutable
class AnggotaRumah {
  const AnggotaRumah({
    required this.nama,
    this.peran = 'anggota',
    this.kontak,
    this.aktif = true,
  });

  final String nama;

  /// kepala / pasangan / anak / anggota / asisten.
  final String peran;

  /// Nomor HP (opsional) — dipakai saat menyiapkan pesan pengingat.
  final String? kontak;
  final bool aktif;
}

/// Tagihan bersama: satu tagihan dibagi ke beberapa anggota.
@immutable
class TagihanBersama {
  const TagihanBersama({
    required this.rumahNama,
    required this.judul,
    required this.totalSen,
    required this.jatuhTempo,
    this.penanggung,
    this.catatan,
  });

  final String rumahNama;
  final String judul;
  final int totalSen;
  final DateTime jatuhTempo;

  /// Nama anggota yang biasanya membayar lebih dulu (opsional).
  final String? penanggung;
  final String? catatan;
}

/// Bagian satu anggota pada satu tagihan bersama.
@immutable
class BagianRumah {
  const BagianRumah({
    required this.kunciTagihan,
    required this.anggota,
    required this.jumlahSen,
    this.dibayarSen = 0,
    this.waktuBayar,
    this.catatan,
  });

  final String kunciTagihan;
  final String anggota;
  final int jumlahSen;
  final int dibayarSen;
  final DateTime? waktuBayar;
  final String? catatan;

  bool get lunas => dibayarSen >= jumlahSen;

  int get sisaSen {
    final sisa = jumlahSen - dibayarSen;
    return sisa < 0 ? 0 : sisa;
  }
}

/// Kunci pasangan tagihan ↔ bagiannya (judul + jatuh tempo + total).
String kunciTagihanBersama(TagihanBersama t) =>
    '${t.judul.trim()}|${t.jatuhTempo.toIso8601String()}|${t.totalSen}';

/// Angka tagihan bersama apa adanya (tanpa penilaian).
@immutable
class RingkasBagian {
  const RingkasBagian({
    required this.anggota,
    required this.jumlahSen,
    required this.dibayarSen,
    this.waktuBayar,
  });

  final String anggota;
  final int jumlahSen;
  final int dibayarSen;
  final DateTime? waktuBayar;

  int get sisaSen {
    final sisa = jumlahSen - dibayarSen;
    return sisa < 0 ? 0 : sisa;
  }

  bool get lunas => dibayarSen >= jumlahSen;
}

/// Riwayat pembayaran rumah tangga (siapa, kapan, berapa).
@immutable
class BarisRiwayatRumah {
  const BarisRiwayatRumah({
    required this.judul,
    required this.anggota,
    required this.jumlahSen,
    required this.waktu,
  });

  final String judul;
  final String anggota;
  final int jumlahSen;
  final DateTime waktu;
}

/// Hasil hitungan satu rumah tangga.
@immutable
class HasilRumahTangga {
  const HasilRumahTangga({
    required this.rumahNama,
    required this.anggota,
    required this.tagihan,
    required this.belumBisa,
    required this.peringatan,
  });

  final String rumahNama;
  final List<AnggotaRumah> anggota;
  final List<TagihanBersama> tagihan;
  final List<String> belumBisa;
  final List<String> peringatan;

  bool get adaAnggota => anggota.isNotEmpty;

  int get totalTagihanSen =>
      tagihan.fold<int>(0, (a, t) => a + (t.totalSen < 0 ? 0 : t.totalSen));

  String get dasar => '${anggota.length} anggota · ${tagihan.length} tagihan '
      'bersama · total ${fmtRpDariSen(totalTagihanSen)}.';
}

/// Kode undangan rumah tangga (tanpa akun): 6 huruf/angka tanpa karakter
/// yang mudah tertukar (0/O, 1/I).
String kodeUndanganRumah(int acak) {
  const huruf = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  if (acak < 0) acak = -acak;
  final sb = StringBuffer();
  for (var i = 0; i < 6; i++) {
    sb.write(huruf[(acak + i * 7) % huruf.length]);
    acak = acak ~/ 3 + 11;
  }
  return sb.toString();
}

/// Kode undangan sah? (6 karakter dari daftar aman, tanpa spasi/tanda baca.)
bool kodeUndanganSah(String? kode) {
  final k = (kode ?? '').trim().toUpperCase();
  if (k.length != 6) return false;
  return RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$').hasMatch(k);
}

/// Hitung ringkasan rumah tangga: tagihan, bagian, dan peringatan jujur.
HasilRumahTangga hitungRumahTangga({
  required String rumahNama,
  required List<AnggotaRumah> anggota,
  required List<TagihanBersama> tagihan,
  required List<BagianRumah> bagian,
  DateTime? sekarang,
}) {
  final belum = <String>[];
  final peringatan = <String>[];
  final aktif = anggota.where((a) => a.aktif).toList();
  final namaAktif = aktif.map((a) => a.nama.trim()).toSet();

  if (aktif.isEmpty) {
    belum.add('Rumah tangga $rumahNama belum punya anggota.');
  }

  for (final t in tagihan) {
    final kunci = kunciTagihanBersama(t);
    final bagianKu =
        bagian.where((b) => b.kunciTagihan == kunci).toList();
    if (bagianKu.isEmpty) {
      belum.add('${t.judul}: bagian tiap anggota belum diisi, jadi siapa '
          'menanggung berapa belum bisa dihitung.');
      continue;
    }
    final jumlah = bagianKu.fold<int>(0, (a, b) => a + b.jumlahSen);
    if (jumlah != t.totalSen) {
      peringatan.add('${t.judul}: jumlah bagian ${fmtRpDariSen(jumlah)} tidak sama '
          'dengan total ${fmtRpDariSen(t.totalSen)}.');
    }
    for (final b in bagianKu) {
      if (namaAktif.isNotEmpty && !namaAktif.contains(b.anggota)) {
        peringatan.add('${t.judul}: bagian untuk "${b.anggota}" bukan anggota '
            'aktif rumah tangga ini.');
      }
    }
    final penanggung = t.penanggung?.trim() ?? '';
    if (penanggung.isNotEmpty && !namaAktif.contains(penanggung)) {
      peringatan.add('${t.judul}: penanggung "$penanggung" bukan anggota aktif.');
    }
  }

  if (tagihan.isEmpty) {
    belum.add('Rumah tangga $rumahNama belum punya tagihan bersama.');
  }
  if (sekarang != null) {
    for (final t in tagihan) {
      if (t.jatuhTempo.isBefore(DateTime(sekarang.year, sekarang.month, sekarang.day))) {
        peringatan.add('${t.judul}: jatuh tempo sudah lewat.');
      }
    }
  }

  return HasilRumahTangga(
    rumahNama: rumahNama,
    anggota: aktif,
    tagihan: tagihan,
    belumBisa: belum,
    peringatan: peringatan,
  );
}

/// Ringkasan bagian satu tagihan: siapa sudah bayar, siapa belum.
List<RingkasBagian> ringkasBagianTagihan({
  required TagihanBersama tagihan,
  required List<BagianRumah> bagian,
}) {
  final kunci = kunciTagihanBersama(tagihan);
  final ku = bagian.where((b) => b.kunciTagihan == kunci).toList()
    ..sort((a, b) => a.anggota.compareTo(b.anggota));
  return [
    for (final b in ku)
      RingkasBagian(
        anggota: b.anggota,
        jumlahSen: b.jumlahSen,
        dibayarSen: b.dibayarSen,
        waktuBayar: b.waktuBayar,
      ),
  ];
}

/// Riwayat pembayaran (yang sudah ada catatannya), terbaru dulu.
List<BarisRiwayatRumah> riwayatBayarRumah({
  required List<TagihanBersama> tagihan,
  required List<BagianRumah> bagian,
  int batas = 20,
}) {
  final peta = {for (final t in tagihan) kunciTagihanBersama(t): t};
  final hasil = <BarisRiwayatRumah>[];
  for (final b in bagian) {
    if (b.dibayarSen <= 0 || b.waktuBayar == null) continue;
    final t = peta[b.kunciTagihan];
    hasil.add(BarisRiwayatRumah(
      judul: t?.judul ?? 'Tagihan yang sudah dihapus',
      anggota: b.anggota,
      jumlahSen: b.dibayarSen,
      waktu: b.waktuBayar!,
    ));
  }
  hasil.sort((a, b) => b.waktu.compareTo(a.waktu));
  return hasil.length > batas ? hasil.sublist(0, batas) : hasil;
}

/// Teks pengingat halus untuk satu anggota (dipakai layar; TIDAK dikirim
/// sendiri oleh aplikasi — pengguna yang memutuskan mengirim).
String teksPengingatRumah({
  required TagihanBersama tagihan,
  required RingkasBagian bagian,
  required String dariNama,
  DateTime? sekarang,
}) {
  final jatuh = tagihan.jatuhTempo;
  final kini = sekarang ?? DateTime.now();
  final sisaHari = DateTime(jatuh.year, jatuh.month, jatuh.day)
      .difference(DateTime(kini.year, kini.month, kini.day))
      .inDays;
  return 'Assalamualaikum ${bagian.anggota}, ini ${dariNama.isEmpty ? 'rumah tangga' : dariNama}.\n'
      'Tagihan bersama: ${tagihan.judul}\n'
      'Bagian ${bagian.anggota}: ${fmtRpDariSen(bagian.jumlahSen)}'
      '${bagian.dibayarSen > 0 ? ' (sudah tercatat ${fmtRpDariSen(bagian.dibayarSen)}, sisa ${fmtRpDariSen(bagian.sisaSen)})' : ''}\n'
      'Jatuh tempo ${jatuh.day}/${jatuh.month}/${jatuh.year}'
      '${sisaHari >= 0 ? ' ($sisaHari hari lagi)' : ' (sudah lewat)'}.\n'
      'Terima kasih.';
}

/// Total yang belum dibayar seluruh anggota untuk satu tagihan.
int totalBelumDibayar(List<RingkasBagian> ringkas) =>
    ringkas.fold<int>(0, (a, b) => a + b.sisaSen);

/// Saran pembagian sama rata untuk tagihan bersama (memakai bagi rata FR-47).
Map<String, int> bagiRataTagihanBersama(int totalSen, List<AnggotaRumah> anggota) {
  return bagiSamaRata(totalSen, [for (final a in anggota.where((x) => x.aktif)) a.nama]);
}

// ── dipakai ulang dari FR-47/FR-55 (impor di layar & repositori) ──────────
