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
  ),
  /// FR-63: briefing pagi (dijadwalkan modul fitur lewat SumberPengingatTambahan).
  briefing(
    'plo_briefing',
    'Ringkasan pagi',
    'Ringkasan pagi: agenda, tagihan terdekat, jadwal sholat',
  ),
  /// FR-87: pengingat waktu sholat (sebelum / tepat / sesudah waktu).
  sholat(
    'plo_sholat',
    'Pengingat sholat',
    'Pengingat waktu sholat menurut hitungan aplikasi',
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

  /// Payload JSON yang dibawa notifikasi = **konteks saja** (PB-01).
  ///
  /// Sejak perbaikan ini payload TIDAK lagi memuat "aksi": aksi ditentukan oleh
  /// tombol yang benar-benar ditekan (`NotificationResponse.actionId`). Dengan
  /// begitu menekan "Buka aplikasi" atau menyentuh notifikasi tidak akan pernah
  /// disalahartikan sebagai "Sudah bayar".
  ///
  /// [periodeReferensi] wajib disertakan agar notifikasi lama tidak menandai
  /// lunas periode berikutnya setelah tagihan berganti periode (rollover).
  String payloadDenganPeriode(DateTime periodeReferensi) => jsonEncode({
        'tagihanId': tagihanId,
        'notifId': id,
        'periode': periodeReferensi.toIso8601String(),
        if (hariSebelum != null) 'hariSebelum': hariSebelum,
      });

  /// Payload tanpa referensi periode (mis. notifikasi uji/diagnostik).
  /// Aksi "sudah bayar" akan ditolak bila periode tidak diketahui (PB-02).
  String get payload => jsonEncode({
        'tagihanId': tagihanId,
        'notifId': id,
        if (hariSebelum != null) 'hariSebelum': hariSebelum,
      });

  @override
  String toString() =>
      'Pengingat(#$id tagihan=$tagihanId ${waktu.toIso8601String()} '
      '${kanal.id}${hariSebelum != null ? ' H-$hariSebelum' : ''}'
      '${terlambat ? ' TERLAMBAT' : ''})';
}

/// Isi payload notifikasi yang sudah diurai — **konteks saja** (PB-01).
class PayloadPengingat {
  const PayloadPengingat({
    required this.tagihanId,
    this.notifId,
    this.periode,
  });

  final int tagihanId;
  final int? notifId;

  /// Periode jatuh tempo yang dirujuk notifikasi (null = tidak diketahui).
  final DateTime? periode;

  /// Bentuk JSON payload (kebalikan dari [urai]).
  String toJson() => jsonEncode({
        'tagihanId': tagihanId,
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
        notifId: m['notifId'] is int ? m['notifId'] as int : null,
        periode: DateTime.tryParse(m['periode']?.toString() ?? ''),
      );
    } catch (_) {
      return null;
    }
  }
}
