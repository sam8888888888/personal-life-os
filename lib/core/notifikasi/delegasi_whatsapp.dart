/// FR-55 — Delegasi Cepat via WhatsApp (memperluas FR-49 Pengingat Multi-Kanal).
///
/// Aplikasi TIDAK mengirim pesan sendiri: ia menyiapkan pesan + tautan yang
/// membuka WhatsApp/SMS di HP pengguna, lalu mencatat bahwa pengingat itu
/// sudah didelegasikan ke siapa (supaya tidak dikirim dua kali tanpa sadar).
///
/// Tautan & normalisasi nomor TIDAK ditulis ulang di sini — dipakai ulang dari
/// `features/tagihan/pengingat_kanal.dart` (FR-49) supaya formatnya satu dan
/// sudah teruji. Mesin ini menambah: teks delegasi, penolakan nomor tidak sah,
/// dan catatan riwayat delegasi.
library;

import 'package:flutter/foundation.dart';

import '../../features/tagihan/pengingat_kanal.dart' as kanal;

/// Kanal pengiriman.
enum KanalDelegasi {
  whatsapp('wa', 'WhatsApp'),
  sms('sms', 'SMS'),
  salin('salin', 'Salin teks');

  const KanalDelegasi(this.kode, this.label);
  final String kode;
  final String label;

  static KanalDelegasi dariKode(String? kode) => values.firstWhere(
        (k) => k.kode == kode,
        orElse: () => KanalDelegasi.whatsapp,
      );
}

/// Format internasional nomor pengguna (tanpa tanda plus) — dibungkus dari
/// FR-49 lalu diperketat: nomor yang terlalu pendek/panjang dianggap tidak sah.
String? nomorInternasional(String? teks) {
  final n = kanal.nomorKeInternasional(teks);
  if (n.isEmpty) return null;
  if (n.length < 9 || n.length > 15) return null;
  return n;
}

/// Nomor untuk ditampilkan (disamarkan sebagian, tetap bisa dikenali).
String nomorTampil(String? teks) {
  final n = nomorInternasional(teks);
  if (n == null) {
    final asli = (teks ?? '').trim();
    return asli.isEmpty ? '—' : '$asli (belum rapi)';
  }
  final isi = n.startsWith('62') ? n.substring(2) : n;
  if (isi.length <= 7) return '+$n';
  return '+62 ${isi.substring(0, 3)}…${isi.substring(isi.length - 4)}';
}

/// Tautan WhatsApp (wa.me) untuk nomor + pesan; null bila nomor tidak sah.
String? tautanWhatsapp(String? nomor, String pesan) {
  if (nomorInternasional(nomor) == null) return null;
  return kanal.tautanWhatsapp(pesan, nomor: nomor);
}

/// Tautan SMS; null bila nomor tidak sah.
String? tautanSms(String? nomor, String pesan) {
  if (nomorInternasional(nomor) == null) return null;
  return kanal.tautanSms(pesan, nomor: nomor);
}

/// Teks pengingat tagihan untuk didelegasikan ke orang lain.
String teksDelegasiTagihan({
  required String judul,
  required int jumlahSen,
  required DateTime jatuhTempo,
  required String dariNama,
  required String keNama,
  DateTime? sekarang,
}) {
  final kini = sekarang ?? DateTime.now();
  final sisaHari = DateTime(jatuhTempo.year, jatuhTempo.month, jatuhTempo.day)
      .difference(DateTime(kini.year, kini.month, kini.day))
      .inDays;
  return 'Halo $keNama, ini pengingat dari $dariNama.\n'
      'Tagihan: $judul\n'
      'Jumlah: ${rpSederhana(jumlahSen)}\n'
      'Jatuh tempo: ${jatuhTempo.day}/${jatuhTempo.month}/${jatuhTempo.year}'
      '${sisaHari >= 0 ? ' ($sisaHari hari lagi)' : ' (sudah lewat)'}\n'
      'Mohon dibantu untuk pembayarannya. Terima kasih.\n'
      '— dikirim dari Personal Life OS';
}

/// Teks pengingat kegiatan/tugas umum.
String teksDelegasiTugas({
  required String judul,
  required String dariNama,
  required String keNama,
  DateTime? kapan,
}) {
  final w = kapan == null
      ? 'Waktu menyusul.'
      : 'Waktu: ${kapan.day}/${kapan.month}/${kapan.year} '
          '${kapan.hour.toString().padLeft(2, '0')}:'
          '${kapan.minute.toString().padLeft(2, '0')}';
  return 'Halo $keNama, ini pengingat dari $dariNama.\n'
      'Kegiatan: $judul\n'
      '$w\n'
      'Mohon dibantu ya. Terima kasih.\n'
      '— dikirim dari Personal Life OS';
}

/// Satu catatan delegasi yang sudah dikirim (atau disalin).
@immutable
class DelegasiTercatat {
  const DelegasiTercatat({
    required this.judul,
    required this.keNama,
    required this.nomor,
    required this.kanal,
    required this.waktu,
    required this.teks,
  });

  final String judul;
  final String keNama;
  final String? nomor;
  final KanalDelegasi kanal;
  final DateTime waktu;
  final String teks;
}

/// Ringkasan daftar delegasi untuk layar.
@immutable
class RingkasanDelegasi {
  const RingkasanDelegasi({
    required this.daftar,
    required this.belumBisa,
    required this.sekarang,
  });

  final List<DelegasiTercatat> daftar;
  final List<String> belumBisa;
  final DateTime sekarang;

  int get jumlah => daftar.length;

  DelegasiTercatat? get terakhir => daftar.isEmpty ? null : daftar.first;

  /// Berapa kali tiap orang didelegasikan (terbanyak dulu).
  List<MapEntry<String, int>> get perOrang {
    final peta = <String, int>{};
    for (final d in daftar) {
      peta[d.keNama] = (peta[d.keNama] ?? 0) + 1;
    }
    final hasil = peta.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return hasil;
  }

  String get dasar => daftar.isEmpty
      ? 'Belum ada pengingat yang didelegasikan.'
      : '$jumlah pengingat didelegasikan ke ${perOrang.length} orang.';
}

/// Susun ringkasan delegasi (terbaru dulu, maksimal [batas]).
RingkasanDelegasi ringkasDelegasi(
  List<DelegasiTercatat> semua, {
  DateTime? sekarang,
  int batas = 30,
}) {
  final kini = sekarang ?? DateTime.now();
  final urut = [...semua]..sort((a, b) => b.waktu.compareTo(a.waktu));
  final daftar = urut.length > batas ? urut.sublist(0, batas) : urut;

  final belum = <String>[];
  if (semua.isEmpty) {
    belum.add('Belum ada pengingat yang didelegasikan.');
  }
  final tanpaNomor = semua.where((d) => nomorInternasional(d.nomor) == null).length;
  if (tanpaNomor > 0) {
    belum.add('$tanpaNomor pengingat tanpa nomor HP yang sah (hanya bisa '
        'disalin atau diarahkan lewat WhatsApp tanpa nomor).');
  }

  return RingkasanDelegasi(daftar: daftar, belumBisa: belum, sekarang: kini);
}

/// Alasan sebuah delegasi belum bisa dikirim otomatis — kosong = boleh.
List<String> alasanTidakBisaKirim({
  required String? nomor,
  required KanalDelegasi kanal,
}) {
  final hasil = <String>[];
  if (kanal == KanalDelegasi.salin) return hasil;
  if (nomor == null || nomor.trim().isEmpty) {
    hasil.add('Nomor HP belum diisi.');
    return hasil;
  }
  if (nomorInternasional(nomor) == null) {
    hasil.add('Nomor "$nomor" tidak dikenali — tulis seperti 0812… atau +62…');
  }
  return hasil;
}

/// Rupiah ringkas tanpa bergantung pada utilitas lain.
String rpSederhana(int sen) {
  final negatif = sen < 0;
  final nilai = negatif ? -sen : sen;
  final rupiah = nilai ~/ 100;
  final teks = rupiah.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
  return '${negatif ? '-' : ''}Rp $teks';
}
