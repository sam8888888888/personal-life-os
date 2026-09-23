/// FR-149 — AI Copilot ber-konteks.
///
/// Aturan yang dipegang (sesuai PRD):
///   * jawaban HANYA memakai data pengguna sendiri;
///   * butuh IZIN EKSPLISIT sebelum apa pun dikirim;
///   * pengguna diberi tahu TEPAT data apa yang akan dikirim (daftar, bukan
///     kalimat samar) sebelum menekan "Tanya";
///   * saat offline, tanpa izin, atau kunci belum diisi → fitur MATI dengan
///     pesan jelas, bukan gagal diam-diam.
///
/// Mesin ini tidak menyentuh jaringan: ia menyiapkan permintaan (URL, header,
/// body) dan mengurai jawaban, sehingga bisa diuji tanpa internet.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Konfigurasi copilot yang disimpan pengguna.
@immutable
class KonfigCopilot {
  const KonfigCopilot({
    this.endpoint = 'https://api.deepseek.com/chat/completions',
    this.model = 'deepseek-chat',
    this.kunci = '',
    this.izinDiberikan = false,
    this.batasKata = 400,
  });

  final String endpoint;
  final String model;

  /// Kunci API milik pengguna. TIDAK pernah ditampilkan utuh di layar/log.
  final String kunci;
  final bool izinDiberikan;

  /// Batas panjang jawaban yang diminta.
  final int batasKata;

  bool get adaKunci => kunci.trim().isNotEmpty;

  /// Bentuk aman untuk ditampilkan: hanya 4 karakter terakhir.
  String get kunciTersamar {
    final k = kunci.trim();
    if (k.isEmpty) return 'belum diisi';
    if (k.length <= 4) return '••••';
    return '••••${k.substring(k.length - 4)}';
  }

  /// Endpoint hanya boleh **HTTPS** (hasil audit 23 Sep 2026, P2-3).
  ///
  /// Alamat ini menerima kunci API pengguna dan ringkasan data pribadinya.
  /// Sebelumnya `http://` juga diterima — artinya kunci & data bisa terkirim
  /// dalam teks polos bila pengguna menempelkan alamat tanpa TLS.
  bool get endpointMasukAkal {
    final u = Uri.tryParse(endpoint.trim());
    return u != null && u.scheme == 'https' && u.host.isNotEmpty;
  }

  /// Benar bila alamatnya sah tetapi TIDAK memakai HTTPS (untuk pesan jelas).
  bool get endpointTanpaHttps {
    final u = Uri.tryParse(endpoint.trim());
    return u != null && u.scheme == 'http' && u.host.isNotEmpty;
  }

  String get dasar => '$model · ${endpointMasukAkal ? Uri.parse(endpoint.trim()).host : 'alamat belum benar'} '
      '· kunci $kunciTersamar · izin ${izinDiberikan ? 'menyala' : 'mati'}';
}

/// Bahan data pengguna untuk konteks (diisi repositori dari basis data).
@immutable
class BahanKonteksCopilot {
  const BahanKonteksCopilot({
    this.namaPanggilan,
    this.saldoAmanSen,
    this.tagihanTerdekat = const [],
    this.obatHariIni = const [],
    this.danaPersiapan = const [],
    this.perjalananTerdekat,
    this.temuanTeratas = const [],
    this.catatanTambahan,
  });

  final String? namaPanggilan;
  final int? saldoAmanSen;

  /// Contoh: "Listrik Rp 250.000 jatuh tempo 25/9".
  final List<String> tagihanTerdekat;
  final List<String> obatHariIni;
  final List<String> danaPersiapan;
  final String? perjalananTerdekat;
  final List<String> temuanTeratas;
  final String? catatanTambahan;
}

/// Konteks siap kirim + daftar apa yang dikirim (ditampilkan ke pengguna).
@immutable
class KonteksCopilot {
  const KonteksCopilot({
    required this.teks,
    required this.daftarData,
    required this.jumlahKarakter,
  });

  final String teks;
  final List<String> daftarData;
  final int jumlahKarakter;

  bool get kosong => daftarData.isEmpty;
}

/// Susun konteks dari bahan data pengguna.
///
/// Setiap bagian yang benar-benar ikut dikirim dicatat namanya di
/// [KonteksCopilot.daftarData] — inilah yang ditampilkan ke pengguna.
KonteksCopilot susunKonteksCopilot(BahanKonteksCopilot bahan) {
  final baris = <String>[];
  final data = <String>[];

  if (bahan.namaPanggilan != null && bahan.namaPanggilan!.trim().isNotEmpty) {
    baris.add('Panggilan pengguna: ${bahan.namaPanggilan!.trim()}');
    data.add('nama panggilan');
  }
  if (bahan.saldoAmanSen != null) {
    baris.add('Uang aman sampai gajian: ${rpKonteks(bahan.saldoAmanSen!)}');
    data.add('uang aman sampai gajian');
  }
  if (bahan.tagihanTerdekat.isNotEmpty) {
    baris.add('Tagihan terdekat: ${bahan.tagihanTerdekat.join('; ')}');
    data.add('daftar tagihan terdekat (${bahan.tagihanTerdekat.length})');
  }
  if (bahan.danaPersiapan.isNotEmpty) {
    baris.add('Dana persiapan: ${bahan.danaPersiapan.join('; ')}');
    data.add('dana persiapan (${bahan.danaPersiapan.length})');
  }
  if (bahan.obatHariIni.isNotEmpty) {
    baris.add('Jadwal obat/suplemen hari ini: ${bahan.obatHariIni.join('; ')}');
    data.add('jadwal obat hari ini');
  }
  if (bahan.perjalananTerdekat != null &&
      bahan.perjalananTerdekat!.trim().isNotEmpty) {
    baris.add('Perjalanan terdekat: ${bahan.perjalananTerdekat!.trim()}');
    data.add('perjalanan terdekat');
  }
  if (bahan.temuanTeratas.isNotEmpty) {
    baris.add('Temuan penting: ${bahan.temuanTeratas.join('; ')}');
    data.add('temuan penting (${bahan.temuanTeratas.length})');
  }
  if (bahan.catatanTambahan != null && bahan.catatanTambahan!.trim().isNotEmpty) {
    baris.add('Catatan: ${bahan.catatanTambahan!.trim()}');
    data.add('catatan tambahan');
  }

  final teks = baris.isEmpty
      ? 'Belum ada data pengguna yang bisa dipakai sebagai konteks.'
      : 'Data pengguna (ringkas, dari aplikasi Personal Life OS):\n'
          '${baris.map((b) => '- $b').join('\n')}';

  return KonteksCopilot(
    teks: teks,
    daftarData: data,
    jumlahKarakter: teks.length,
  );
}

/// Alasan fitur belum bisa dipakai — kosong = siap.
List<String> bolehTanyaCopilot(
  KonfigCopilot konfig, {
  required bool adaJaringan,
}) {
  final hasil = <String>[];
  if (!konfig.izinDiberikan) {
    hasil.add('Izin belum diberikan. Copilot tidak mengirim apa pun sebelum '
        'Anda menyalakan "Izinkan AI Copilot membaca data saya".');
  }
  if (!konfig.adaKunci) {
    hasil.add('Kunci API belum diisi (kunci milik Anda sendiri, disimpan di '
        'perangkat).');
  }
  if (!konfig.endpointMasukAkal) {
    hasil.add(konfig.endpointTanpaHttps
        ? 'Alamat layanan AI harus diawali https:// (koneksi terenkripsi). '
            'Alamat http:// tidak dipakai karena kunci API dan ringkasan data '
            'Anda akan terkirim tanpa enkripsi.'
        : 'Alamat layanan AI belum benar (contoh: '
            'https://api.deepseek.com/chat/completions).');
  }
  if (!adaJaringan) {
    hasil.add('Sedang offline. Copilot butuh jaringan — data Anda tetap di '
        'perangkat dan tidak dikirim.');
  }
  return hasil;
}

/// Permintaan HTTP siap dikirim (dipisah supaya bisa diuji tanpa jaringan).
@immutable
class PermintaanCopilot {
  const PermintaanCopilot({
    required this.url,
    required this.headers,
    required this.body,
  });

  final String url;
  final Map<String, String> headers;
  final String body;
}

/// Susun permintaan ke layanan AI (gaya OpenAI-compatible chat completions).
PermintaanCopilot susunPermintaanCopilot({
  required KonfigCopilot konfig,
  required KonteksCopilot konteks,
  required String pertanyaan,
}) {
  final badan = <String, dynamic>{
    'model': konfig.model,
    'messages': [
      {
        'role': 'system',
        'content': 'Anda asisten pribadi yang hanya memakai DATA PENGGUNA di '
            'bawah ini. Jangan mengarang angka. Bila data tidak cukup, '
            'katakan belum bisa dijawab dan sebutkan data apa yang kurang. '
            'Jawab singkat dalam bahasa Indonesia, maksimal '
            '${konfig.batasKata} kata.\n\n${konteks.teks}',
      },
      {'role': 'user', 'content': pertanyaan},
    ],
    'temperature': 0.2,
    'stream': false,
  };
  return PermintaanCopilot(
    url: konfig.endpoint.trim(),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${konfig.kunci.trim()}',
    },
    body: jsonEncode(badan),
  );
}

/// Hasil satu tanya-jawab.
@immutable
class HasilCopilot {
  const HasilCopilot({
    required this.jawaban,
    required this.dataDikirim,
    required this.waktu,
    this.galat,
  });

  final String jawaban;
  final List<String> dataDikirim;
  final DateTime waktu;
  final String? galat;

  bool get berhasil => galat == null && jawaban.trim().isNotEmpty;
}

/// Uraikan jawaban layanan AI. Galat dijelaskan apa adanya (bukan dikarang).
String uraiJawabanCopilot(String badan, {required int statusKode}) {
  if (statusKode == 401 || statusKode == 403) {
    return 'Kunci API ditolak oleh layanan AI (HTTP $statusKode). Periksa '
        'kuncinya di Pengaturan → AI Copilot.';
  }
  if (statusKode == 429) {
    return 'Layanan AI menolak karena kuota/permintaan terlalu sering '
        '(HTTP 429). Coba lagi nanti.';
  }
  if (statusKode >= 500) {
    return 'Layanan AI sedang bermasalah (HTTP $statusKode). Coba lagi nanti.';
  }

  final Map<String, dynamic> map;
  try {
    map = jsonDecode(badan) as Map<String, dynamic>;
  } catch (_) {
    return 'Balasan layanan AI tidak bisa dibaca (bukan JSON).';
  }

  final pilihan = map['choices'];
  if (pilihan is List && pilihan.isNotEmpty) {
    final pertama = pilihan.first;
    if (pertama is Map) {
      final pesan = pertama['message'];
      if (pesan is Map && pesan['content'] is String) {
        final teks = (pesan['content'] as String).trim();
        if (teks.isNotEmpty) return teks;
      }
      final teksAlt = pertama['text'];
      if (teksAlt is String && teksAlt.trim().isNotEmpty) {
        return teksAlt.trim();
      }
    }
  }

  final galat = map['error'];
  if (galat is Map && galat['message'] is String) {
    return 'Layanan AI menolak: ${(galat['message'] as String).trim()}';
  }
  return 'Balasan layanan AI tidak memuat jawaban yang bisa dibaca.';
}

/// Ringkasan halaman copilot untuk layar (jumlah data yang siap dikirim dsb.).
@immutable
class RingkasanCopilot {
  const RingkasanCopilot({
    required this.konfig,
    required this.konteks,
    required this.alasan,
    required this.riwayat,
  });

  final KonfigCopilot konfig;
  final KonteksCopilot konteks;
  final List<String> alasan;
  final List<HasilCopilot> riwayat;

  bool get siap => alasan.isEmpty;

  String get dasar => konteks.kosong
      ? 'Belum ada data pengguna yang bisa dijadikan konteks.'
      : 'Konteks siap: ${konteks.daftarData.length} jenis data '
          '(${konteks.jumlahKarakter} karakter).';
}

/// Susun ringkasan untuk layar.
RingkasanCopilot ringkasCopilot({
  required KonfigCopilot konfig,
  required BahanKonteksCopilot bahan,
  required bool adaJaringan,
  List<HasilCopilot> riwayat = const [],
}) {
  final konteks = susunKonteksCopilot(bahan);
  final alasan = bolehTanyaCopilot(konfig, adaJaringan: adaJaringan);
  if (konteks.kosong) {
    alasan.add('Belum ada data pengguna untuk dijadikan konteks — catat dulu '
        'tagihan/jadwal/perjalanan.');
  }
  return RingkasanCopilot(
    konfig: konfig,
    konteks: konteks,
    alasan: alasan,
    riwayat: riwayat,
  );
}

/// Teks penjelasan "data apa yang akan dikirim" untuk penegasan pengguna.
String penjelasanDataDikirim(KonteksCopilot konteks) {
  if (konteks.kosong) {
    return 'Belum ada data yang akan dikirim.';
  }
  return 'Yang akan dikirim ke layanan AI milik Anda:\n'
      '${konteks.daftarData.map((d) => '• $d').join('\n')}\n'
      '(${konteks.jumlahKarakter} karakter — tanpa foto, tanpa nomor rekening, '
      'tanpa kata sandi.)';
}

/// Pertanyaan contoh yang bisa ditekan pengguna.
const List<String> pertanyaanContoh = [
  'Apa yang harus saya prioritaskan besok?',
  'Tagihan mana yang paling mendesak?',
  'Apakah uang saya cukup sampai gajian?',
  'Apa yang bisa saya hemat bulan ini?',
];

String rpKonteks(int sen) {
  final negatif = sen < 0;
  final nilai = negatif ? -sen : sen;
  final rupiah = nilai ~/ 100;
  final teks = rupiah.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
  return '${negatif ? '-' : ''}Rp $teks';
}
