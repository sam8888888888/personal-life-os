/// FR-49 — Pengingat multi-kanal (WhatsApp lebih dulu). Murni: tanpa I/O.
///
/// Pengguna meneruskan pengingat ke aplikasi lain dengan teks SIAP KIRIM (deep
/// link). Kanal default tetap notifikasi aplikasi (push); pengaturan kanal
/// disimpan per tagihan (kolom `kanalPengingat`). Pengiriman otomatis lewat
/// WhatsApp Business API memang belum ada — itu ditunda ke v3 sesuai PRD, dan
/// aplikasi mengatakannya terus terang.
library;

import '../../data/database/database.dart';
import '../../data/model/enums.dart';
import '../../core/laporan/kurs.dart';
import '../../core/utils/tanggal_utils.dart';

/// Nomor telepon Indonesia → format internasional untuk wa.me.
///
/// "0812-3456-7890" → "6281234567890"; nomor yang sudah berawalan 62 dibiarkan;
/// nomor kosong/tidak jelas dikembalikan apa adanya (tanpa angka).
String nomorKeInternasional(String? nomor) {
  if (nomor == null) return '';
  final angka = nomor.replaceAll(RegExp(r'[^0-9+]'), '');
  if (angka.isEmpty) return '';
  if (angka.startsWith('+')) return angka.substring(1);
  if (angka.startsWith('62')) return angka;
  if (angka.startsWith('0')) return '62${angka.substring(1)}';
  return angka;
}

/// Teks pengingat siap kirim untuk satu tagihan.
String pesanPengingat(TagihanData t, {DateTime? sekarang}) {
  // FR-52: nominal ditulis sesuai mata uang tagihan itu sendiri.
  final nominal = t.jumlahSen == null || t.jumlahSen == 0
      ? 'nominal belum diisi'
      : fmtMataUang(t.jumlahSen!, t.kodeMataUang);
  final bagian = <String>[
    'Pengingat: ${t.nama}',
    '$nominal — jatuh tempo ${fmtTanggalId(t.jatuhTempo)}',
    if (t.catatan != null && t.catatan!.trim().isNotEmpty)
      'Catatan: ${t.catatan!.trim()}',
    'Dikirim dari Personal Life OS',
  ];
  return bagian.join('\n');
}

/// Tautan WhatsApp: nomor kosong = chat ke diri sendiri (pilih kontak dulu di
/// WhatsApp); nomor diisi = langsung ke kontak itu.
String tautanWhatsapp(String pesan, {String? nomor}) {
  final tujuan = nomorKeInternasional(nomor);
  final teks = Uri.encodeComponent(pesan);
  return tujuan.isEmpty
      ? 'https://wa.me/?text=$teks'
      : 'https://wa.me/$tujuan?text=$teks';
}

/// Tautan SMS: membuka aplikasi SMS bawaan dengan isi sudah terisi — pengguna
/// masih harus menekan kirim (konfirmasi), sama seperti diminta PRD.
String tautanSms(String pesan, {String? nomor}) {
  final tujuan = nomorKeInternasional(nomor);
  final teks = Uri.encodeComponent(pesan);
  return tujuan.isEmpty ? 'sms:?body=$teks' : 'sms:$tujuan?body=$teks';
}

/// Tautan Telegram: lembar berbagi Telegram (tanpa token bot).
String tautanTelegram(String pesan) =>
    'https://t.me/share/url?url=${Uri.encodeComponent('personal-life-os')}'
    '&text=${Uri.encodeComponent(pesan)}';

/// Kanal yang bisa dipakai untuk meneruskan pengingat.
enum KanalTerusan {
  whatsapp('whatsapp', 'WhatsApp'),
  sms('sms', 'SMS'),
  telegram('telegram', 'Telegram');

  const KanalTerusan(this.nilaiDb, this.label);
  final String nilaiDb;
  final String label;

  /// Kanal pengingat aplikasi (kolom `kanalPengingat`) yang sepadan.
  KanalPengingat get kanalApp => switch (this) {
        KanalTerusan.whatsapp => KanalPengingat.whatsapp,
        KanalTerusan.sms => KanalPengingat.sms,
        KanalTerusan.telegram => KanalPengingat.telegram,
      };

  /// Tautan untuk [pesan] (dengan [nomor] bila kanalnya mendukung).
  String tautan(String pesan, {String? nomor}) => switch (this) {
        KanalTerusan.whatsapp => tautanWhatsapp(pesan, nomor: nomor),
        KanalTerusan.sms => tautanSms(pesan, nomor: nomor),
        KanalTerusan.telegram => tautanTelegram(pesan),
      };
}

/// Ubah teks kolom `kanalPengingat` menjadi daftar kanal (bisa lebih dari satu,
/// dipisah koma oleh aplikasi lain; bawaan: push saja).
List<KanalPengingat> kanalTagihan(String? teks) {
  final k = (teks ?? '').trim();
  if (k.isEmpty) return const [KanalPengingat.push];
  final daftar = <KanalPengingat>[];
  for (final bagian in k.split(',')) {
    final b = bagian.trim().toLowerCase();
    if (b.isEmpty) continue;
    final sama = KanalPengingat.values.where((e) => e.nilaiDb == b);
    if (sama.isNotEmpty && !daftar.contains(sama.first)) {
      daftar.add(sama.first);
    }
  }
  return daftar.isEmpty ? const [KanalPengingat.push] : daftar;
}

/// Teks kolom `kanalPengingat` dari daftar kanal.
String teksKanal(List<KanalPengingat> daftar) {
  final bersih = daftar.isEmpty ? const [KanalPengingat.push] : daftar;
  return bersih.map((e) => e.nilaiDb).join(',');
}
