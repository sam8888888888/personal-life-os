/// Model pengingat & aksi notifikasi (PRD §6.2: FR-10 … FR-16).
library;

import 'dart:convert';

/// Kanal notifikasi Android (FR-14).
enum KanalNotifikasi {
  tagihan(
    'plo_tagihan',
    'Pengingat tagihan',
    'Pengingat H-x sebelum jatuh tempo',
  ),
  terlambat(
    'plo_terlambat',
    'Tagihan terlambat',
    'Pengingat tagihan yang sudah lewat jatuh tempo',
  ),
  ringkasan(
    'plo_ringkasan',
    'Ringkasan mingguan',
    'Ringkasan tagihan pekan ini (Senin pagi)',
  );

  const KanalNotifikasi(this.id, this.nama, this.deskripsi);
  final String id;
  final String nama;
  final String deskripsi;
}

/// Aksi tombol pada notifikasi (FR-11).
enum AksiNotifikasi {
  sudahBayar('sudah_bayar', '✓ Sudah bayar'),
  tundaSatuJam('tunda_1_jam', 'Tunda 1 jam'),
  buka('buka', 'Buka aplikasi');

  const AksiNotifikasi(this.id, this.label);
  final String id;
  final String label;

  static AksiNotifikasi? dariId(String? v) {
    for (final a in AksiNotifikasi.values) {
      if (a.id == v) return a;
    }
    return null;
  }
}

/// Satu pengingat yang siap dijadwalkan ke sistem Android.
class Pengingat {
  const Pengingat({
    required this.id,
    required this.tagihanId,
    required this.waktu,
    required this.kanal,
    required this.judul,
    required this.isi,
    this.hariSebelum,
    this.terlambat = false,
    this.periode,
  });

  /// ID notifikasi Android (stabil per tagihan + slot).
  final int id;
  final int tagihanId;
  final DateTime waktu;
  final KanalNotifikasi kanal;
  final String judul;
  final String isi;

  /// H-x; null untuk pengingat terlambat atau ringkasan.
  final int? hariSebelum;
  final bool terlambat;

  /// Periode jatuh tempo yang dirujuk (dipakai aksi notifikasi agar tidak
  /// menandai lunas periode yang salah).
  final DateTime? periode;

  /// Payload JSON yang dibawa notifikasi (dipakai handler aksi).
  ///
  /// [periodeReferensi] disertakan agar notifikasi lama TIDAK menandai lunas
  /// periode berikutnya setelah tagihan berganti periode (rollover).
  String payloadDenganPeriode(DateTime periodeReferensi) => jsonEncode({
        'tagihanId': tagihanId,
        'aksi': AksiNotifikasi.sudahBayar.id,
        'notifId': id,
        'periode': periodeReferensi.toIso8601String(),
        if (hariSebelum != null) 'hariSebelum': hariSebelum,
      });

  /// Payload tanpa referensi periode (mis. notifikasi uji).
  String get payload => jsonEncode({
        'tagihanId': tagihanId,
        'aksi': AksiNotifikasi.sudahBayar.id,
        'notifId': id,
        if (hariSebelum != null) 'hariSebelum': hariSebelum,
      });

  @override
  String toString() =>
      'Pengingat(#$id tagihan=$tagihanId ${waktu.toIso8601String()} '
      '${kanal.id}${hariSebelum != null ? ' H-$hariSebelum' : ''}'
      '${terlambat ? ' TERLAMBAT' : ''})';
}

/// Isi payload notifikasi yang sudah diurai.
class PayloadPengingat {
  const PayloadPengingat({
    required this.tagihanId,
    required this.aksi,
    this.notifId,
    this.periode,
  });

  final int tagihanId;
  final AksiNotifikasi aksi;
  final int? notifId;

  /// Periode jatuh tempo yang dirujuk notifikasi (null = tidak diketahui).
  final DateTime? periode;

  /// Bentuk JSON payload (kebalikan dari [urai]).
  String toJson() => jsonEncode({
        'tagihanId': tagihanId,
        'aksi': aksi.id,
        if (notifId != null) 'notifId': notifId,
        if (periode != null) 'periode': periode!.toIso8601String(),
      });

  static PayloadPengingat? urai(String? teks) {
    if (teks == null || teks.trim().isEmpty) return null;
    try {
      final m = jsonDecode(teks);
      if (m is! Map) return null;
      final id = m['tagihanId'];
      if (id is! int) return null;
      return PayloadPengingat(
        tagihanId: id,
        aksi: AksiNotifikasi.dariId(m['aksi'] as String?) ?? AksiNotifikasi.buka,
        notifId: m['notifId'] is int ? m['notifId'] as int : null,
        periode: DateTime.tryParse(m['periode']?.toString() ?? ''),
      );
    } catch (_) {
      return null;
    }
  }
}
