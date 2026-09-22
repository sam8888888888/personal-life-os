/// FR-152 — Kurs mata uang (mesin hitung + simpan/muat JSON).
///
/// Kriteria terima PRD: "kurs menampilkan sumber & waktu pembaruan".
/// Karena itu nilai kurs SELALU dibawa bersama sumber dan waktu; tidak ada
/// kurs yang ditampilkan tanpa keduanya. Bila belum ada kurs sama sekali,
/// konversi ditolak dengan alasan — bukan memakai angka karangan.
library;

import 'dart:convert';

/// Kurs terhadap Rupiah: berapa Rupiah untuk 1 unit mata uang asing.
class Kurs {
  const Kurs({
    required this.perRupiah,
    required this.sumber,
    required this.waktu,
  });

  /// Kunci = kode mata uang ('IDR', 'MYR', 'USD'). IDR selalu 1.
  final Map<String, double> perRupiah;
  final String sumber;
  final DateTime waktu;

  bool get kosong => perRupiah.length <= 1;

  double? nilai(String kode) {
    final k = kode.toUpperCase();
    if (k == 'IDR') return 1;
    final v = perRupiah[k];
    if (v == null || v <= 0) return null;
    return v;
  }

  /// Dua digit (jam/menit) tanpa perlu intl.
String _dua(int n) => n.toString().padLeft(2, '0');

/// Kalimat sumber & waktu — wajib ditampilkan di layar.
  String get teksSumber {
    final t = waktu;
    return 'Sumber kurs: $sumber · diperbarui '
        '${t.day} ${_bulanSingkat[t.month - 1]} ${t.year} '
        '${_dua(t.hour)}:${_dua(t.minute)}';
  }

  /// Berapa lama kurs ini (jam) — untuk peringatan "kurs sudah lama".
  double umurJam(DateTime sekarang) =>
      sekarang.difference(waktu).inMinutes / 60.0;

  bool perluDiperbarui(DateTime sekarang, {double batasJam = 24}) =>
      umurJam(sekarang) > batasJam;

  Map<String, dynamic> keJson() => {
        'perRupiah': perRupiah,
        'sumber': sumber,
        'waktu': waktu.toIso8601String(),
      };

  static Kurs? dariJson(String? teks) {
    if (teks == null || teks.trim().isEmpty) return null;
    try {
      final map = jsonDecode(teks) as Map<String, dynamic>;
      final waktu = DateTime.tryParse(map['waktu'] as String? ?? '');
      final isi = (map['perRupiah'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      if (waktu == null || isi == null || isi.isEmpty) return null;
      return Kurs(
        perRupiah: isi,
        sumber: map['sumber'] as String? ?? 'tidak diketahui',
        waktu: waktu,
      );
    } catch (_) {
      return null;
    }
  }
}

const List<String> _bulanSingkat = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Hasil konversi. [nilai] null = belum bisa dikonversi (alasannya di [alasan]).
class HasilKonversi {
  const HasilKonversi({this.nilai, this.alasan, required this.dasar});

  final double? nilai;
  final String? alasan;
  final String dasar;

  bool get berhasil => nilai != null;

  String get teks {
    if (nilai == null) return 'Belum bisa dikonversi: $alasan';
    return '${nilai!.toStringAsFixed(2)} · $dasar';
  }
}

/// Konversi [senRupiah] (satuan sen, 1 Rp = 100 sen) ke mata uang [ke].
HasilKonversi konversiDariSen(
  int senRupiah,
  String ke, {
  required Kurs? kurs,
}) {
  final kode = ke.toUpperCase();
  final rupiah = senRupiah / 100.0;
  if (kode == 'IDR') {
    return HasilKonversi(
        nilai: rupiah, dasar: 'Rupiah asli (tidak dikonversi)');
  }
  if (kurs == null || kurs.kosong) {
    return HasilKonversi(
      alasan: 'kurs $kode belum pernah diambil di perangkat ini',
      dasar: 'Tidak ada kurs tersimpan.',
    );
  }
  final nilaiKurs = kurs.nilai(kode);
  if (nilaiKurs == null) {
    return HasilKonversi(
      alasan: 'kurs $kode tidak ada di data tersimpan',
      dasar: kurs.teksSumber,
    );
  }
  return HasilKonversi(
    nilai: rupiah / nilaiKurs,
    dasar: '1 $kode = ${_rp(nilaiKurs)} · ${kurs.teksSumber}',
  );
}

String _rp(double v) {
  final n = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < n.length; i++) {
    if (i > 0 && (n.length - i) % 3 == 0) buf.write('.');
    buf.write(n[i]);
  }
  return 'Rp $buf';
}

/// Kurs bawaan yang bisa dipakai sebelum pengguna mengambil kurs baru.
/// Nilainya TIDAK diklaim sebagai kurs terkini — sumbernya ditulis jelas.
Kurs kursBawaanContoh(DateTime waktu) => Kurs(
      perRupiah: const {'IDR': 1, 'MYR': 3450, 'USD': 16250},
      sumber: 'contoh bawaan aplikasi (bukan kurs terkini)',
      waktu: waktu,
    );

/// Uji cepat: apakah teks kurs yang diberikan masuk akal (dipakai saat
/// pengguna mengetik kurs manual).
String? periksaKursManual(String kode, double? nilai) {
  if (kode.toUpperCase() == 'IDR') return null;
  if (nilai == null || nilai <= 0) {
    return 'Nilai kurs harus angka lebih dari 0.';
  }
  if (nilai < 100 || nilai > 100000) {
    return 'Nilai kurs di luar kewajaran (100–100.000). Periksa lagi.';
  }
  return null;
}
