/// FR-39 — Pemindai SMS/notifikasi bank (on-device, opt-in) & FR-59 dasar.
///
/// Aturan yang dipegang:
///   * SEMUA penguraian terjadi di perangkat — tidak ada isi pesan yang
///     dikirim ke mana pun (tanpa cloud, tanpa API);
///   * hanya berjalan setelah pengguna menyalakan izinnya;
///   * hasil pindai hanyalah USULAN — tagihan tidak pernah ditandai lunas
///     tanpa persetujuan pengguna (FR-59).
///
/// Mesin ini MURNI (tanpa Android): pembacaan SMS ada di
/// `core/platform/kanal_sms.dart`.
library;

import 'package:flutter/foundation.dart';

import '../utils/uang_utils.dart';

/// Jenis pesan bank yang dikenali.
enum JenisPesanBank {
  pembayaran('pembayaran', 'Pembayaran/pengeluaran'),
  pemasukan('pemasukan', 'Uang masuk'),
  saldo('saldo', 'Informasi saldo'),
  tidakDikenali('tidak', 'Belum bisa dikenali');

  const JenisPesanBank(this.kode, this.label);

  final String kode;
  final String label;
}

/// Satu pesan bank apa adanya dari kotak masuk.
@immutable
class PesanBank {
  const PesanBank({
    required this.sumber,
    required this.teks,
    required this.waktu,
    this.id,
  });

  /// Pengirim (mis. "BCA", "+62811...").
  final String sumber;
  final String teks;
  final DateTime waktu;
  final int? id;
}

/// Hasil pindai satu pesan — usulan, belum tindakan.
@immutable
class HasilPindaiBank {
  const HasilPindaiBank({
    required this.pesan,
    required this.jenis,
    this.nominalSen,
    this.keterangan,
    this.saldoSen,
    this.keyakinan = 0,
    this.alasan = const [],
  });

  final PesanBank pesan;
  final JenisPesanBank jenis;
  final int? nominalSen;

  /// Merchant/tujuan/asal bila terbaca (mis. "TOKOPEDIA", "AN. BUDI").
  final String? keterangan;
  final int? saldoSen;
  final int keyakinan;
  final List<String> alasan;

  bool get adaNominal => (nominalSen ?? 0) > 0;

  String get kalimat {
    if (jenis == JenisPesanBank.tidakDikenali) {
      return 'Pesan dari ${pesan.sumber} belum bisa dikenali'
          '${alasan.isEmpty ? '.' : ': ${alasan.first}'}';
    }
    final bagian = <String>[jenis.label];
    if (adaNominal) bagian.add(fmtRpDariSen(nominalSen!));
    if ((keterangan ?? '').trim().isNotEmpty) bagian.add(keterangan!.trim());
    return bagian.join(' · ');
  }
}

/// Bank/dompet yang dikenali (dipakai untuk penyaringan kotak masuk).
const List<String> pengirimBankDikenal = [
  'BCA',
  'MANDIRI',
  'BRI',
  'BNI',
  'BSI',
  'PERMATA',
  'CIMB',
  'DANAMON',
  'JENIUS',
  'SEABANK',
  'GOPAY',
  'OVO',
  'DANA',
  'SHOPEEPAY',
  'LINKAJA',
];

/// Apakah pengirim ini termasuk bank/dompet yang kita kenali (tanpa asumsi:
/// hanya nama yang ada di daftar).
bool pengirimDikenal(String sumber) {
  final s = sumber.toUpperCase();
  for (final b in pengirimBankDikenal) {
    if (s.contains(b)) return true;
  }
  return false;
}

/// Urai nominal gaya pesan bank: "Rp1.234.567", "IDR 250.000", "Rp 20.000".
int? uraiNominalBank(String teks) {
  final m = RegExp(r'(?:rp|idr)\s?\.?\s?([\d.,]+)', caseSensitive: false)
      .firstMatch(teks);
  if (m == null) return null;
  final angka = m.group(1);
  if (angka == null) return null;
  final bersih = angka.replaceAll(RegExp(r'[.,](?=\d{3}\b)'), '')
      .replaceAll(',', '.');
  final nilai = double.tryParse(bersih);
  if (nilai == null || nilai <= 0) return null;
  return (nilai * 100).round();
}

/// Ambil keterangan setelah kata kunci (ke/di/kepada/merchant/an.).
String? _keteranganSetelah(String teks, List<String> kata) {
  for (final k in kata) {
    final m = RegExp(k + r'\s+([A-Za-z0-9 ._\-]{3,40})', caseSensitive: false)
        .firstMatch(teks);
    if (m != null) {
      final isi = m.group(1)?.trim();
      if (isi != null && isi.isNotEmpty) {
        return isi.replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }
  }
  return null;
}

/// Pindai satu pesan bank. Tidak memanggil jaringan apa pun.
HasilPindaiBank pindaiPesanBank(PesanBank pesan) {
  final teks = pesan.teks;
  final t = teks.toLowerCase();
  final nominal = uraiNominalBank(teks);
  final saldo = RegExp(r'saldo[^0-9]{0,12}(?:rp|idr)\s?\.?\s?([\d.,]+)',
          caseSensitive: false)
      .firstMatch(teks);
  final saldoSen = saldo == null ? null : uraiNominalBank(saldo.group(0) ?? '');
  final alasan = <String>[];

  final keluar = RegExp(
          r'\b(debit|pembayaran|pembelian|transfer ke|telah digunakan|pemakaian|qris|tarik|penarikan)\b')
      .hasMatch(t);
  final masuk = RegExp(r'\b(kredit|uang masuk|diterima|masuk sebesar|transfer masuk)\b')
      .hasMatch(t);
  final hanyaSaldo = RegExp(r'\b(saldo|informasi saldo)\b').hasMatch(t) &&
      !keluar &&
      !masuk;

  if (hanyaSaldo && saldoSen == null) {
    return HasilPindaiBank(
      pesan: pesan,
      jenis: JenisPesanBank.tidakDikenali,
      alasan: ['Disebut saldo, tapi angkanya tidak terbaca.'],
    );
  }
  if (hanyaSaldo) {
    return HasilPindaiBank(
      pesan: pesan,
      jenis: JenisPesanBank.saldo,
      saldoSen: saldoSen,
      keyakinan: 80,
      alasan: const ['Ini info saldo, bukan transaksi — tidak dicatat otomatis.'],
    );
  }
  if (!keluar && !masuk) {
    return HasilPindaiBank(
      pesan: pesan,
      jenis: JenisPesanBank.tidakDikenali,
      nominalSen: nominal,
      saldoSen: saldoSen,
      alasan: const [
        'Arah transaksi tidak jelas (tidak ada debit/kredit/pembayaran).',
      ],
    );
  }
  if (nominal == null) {
    return HasilPindaiBank(
      pesan: pesan,
      jenis: JenisPesanBank.tidakDikenali,
      saldoSen: saldoSen,
      alasan: const ['Nominal transaksi tidak terbaca.'],
    );
  }

  final keterangan = _keteranganSetelah(
      teks, const ['ke', 'kepada', 'di', 'merchant', 'an\\.', 'dari']);
  var keyakinan = 60;
  if (pengirimDikenal(pesan.sumber)) keyakinan += 20;
  if (keterangan != null) keyakinan += 10;
  if (keluar != masuk) keyakinan += 5;

  return HasilPindaiBank(
    pesan: pesan,
    jenis: keluar ? JenisPesanBank.pembayaran : JenisPesanBank.pemasukan,
    nominalSen: nominal,
    keterangan: keterangan,
    saldoSen: saldoSen,
    keyakinan: keyakinan > 95 ? 95 : keyakinan,
    alasan: alasan,
  );
}

/// Saring kotak masuk: hanya pesan dari bank/dompet yang dikenal, sejak kapan,
/// dan buang yang sudah pernah diproses.
List<PesanBank> saringPesanBank(
  List<PesanBank> semua, {
  required DateTime sejak,
  Set<int> sudahDiproses = const {},
}) {
  final hasil = <PesanBank>[];
  for (final p in semua) {
    if (p.waktu.isBefore(sejak)) continue;
    if (p.id != null && sudahDiproses.contains(p.id)) continue;
    if (!pengirimDikenal(p.sumber)) continue;
    hasil.add(p);
  }
  hasil.sort((a, b) => b.waktu.compareTo(a.waktu));
  return hasil;
}

/// Tagihan yang mungkin cocok dengan nominal pesan.
@immutable
class KandidatTagihan {
  const KandidatTagihan({
    required this.nama,
    required this.jumlahSen,
    this.jatuhTempo,
  });

  final String nama;
  final int jumlahSen;
  final DateTime? jatuhTempo;
}

/// Usulan pencocokan pesan pembayaran dengan tagihan yang belum lunas.
///
/// Cocok bila nominalnya sama, atau berbeda paling banyak 1% (biaya admin).
/// Mengembalikan `null` bila tidak ada yang cukup dekat — lebih baik mengaku
/// tidak cocok daripada menandai tagihan yang salah.
KandidatTagihan? cocokkanDenganTagihan(
  HasilPindaiBank hasil,
  List<KandidatTagihan> kandidat,
) {
  if (hasil.jenis != JenisPesanBank.pembayaran || !hasil.adaNominal) return null;
  final nominal = hasil.nominalSen!;
  KandidatTagihan? terbaik;
  var selisihTerbaik = 1 << 62;
  for (final k in kandidat) {
    final selisih = (k.jumlahSen - nominal).abs();
    final batas = (k.jumlahSen * 1 / 100).round();
    if (selisih > (batas < 100 ? 100 : batas)) continue;
    if (selisih < selisihTerbaik) {
      selisihTerbaik = selisih;
      terbaik = k;
    }
  }
  return terbaik;
}

/// Ringkasan hasil pindai untuk layar (angka apa adanya).
@immutable
class RingkasPindaiBank {
  const RingkasPindaiBank({
    required this.hasil,
    required this.sekarang,
    this.totalPengeluaranSen = 0,
    this.totalPemasukanSen = 0,
  });

  final List<HasilPindaiBank> hasil;
  final DateTime sekarang;
  final int totalPengeluaranSen;
  final int totalPemasukanSen;

  List<HasilPindaiBank> get belumDikenali => [
        for (final h in hasil)
          if (h.jenis == JenisPesanBank.tidakDikenali) h,
      ];

  bool get ada => hasil.isNotEmpty;

  String get dasar => hasil.isEmpty
      ? 'Belum ada pesan bank yang dipindai.'
      : '${hasil.length} pesan dipindai · pengeluaran '
          '${fmtRpDariSen(totalPengeluaranSen)} · pemasukan '
          '${fmtRpDariSen(totalPemasukanSen)}'
          '${belumDikenali.isEmpty ? '' : ' · ${belumDikenali.length} belum '
              'bisa dikenali'}';
}

/// Ringkas hasil pindai.
RingkasPindaiBank ringkasPindaiBank(
  List<HasilPindaiBank> hasil, {
  DateTime? sekarang,
}) {
  final kini = sekarang ?? DateTime.now();
  var keluar = 0;
  var masuk = 0;
  for (final h in hasil) {
    if (!h.adaNominal) continue;
    if (h.jenis == JenisPesanBank.pembayaran) keluar += h.nominalSen!;
    if (h.jenis == JenisPesanBank.pemasukan) masuk += h.nominalSen!;
  }
  return RingkasPindaiBank(
    hasil: hasil,
    sekarang: kini,
    totalPengeluaranSen: keluar,
    totalPemasukanSen: masuk,
  );
}

/// Kalimat jujur tentang batas fitur ini (ditampilkan di layar).
const String catatanPemindaiBank =
    'Pemindaian berjalan sepenuhnya di perangkat ini: tidak ada isi pesan '
    'yang dikirim ke server mana pun. Aplikasi hanya membaca SMS dari '
    'pengirim bank/dompet yang dikenal, dan TIDAK menandai tagihan lunas '
    'sendiri — setiap usulan harus Anda setujui dulu. Anda bisa mematikan izin '
    'ini kapan saja di Pengaturan.';

/// Kunci saklar izin di tabel `pengaturan`.
const String kunciIzinPemindaiBank = 'uang.izinPemindaiBank';
