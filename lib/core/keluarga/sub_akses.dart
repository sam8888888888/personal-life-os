/// FR-56 — Sub-Akses Keluarga (opsional, hanya bila pengguna menyalakannya).
///
/// Aturan yang dipegang:
///   * berbagi bersifat OPT-IN per anggota & per modul — tidak ada modul yang
///     terbuka secara bawaan;
///   * pemeriksaan izin dilakukan di lapisan data (bukan menyembunyikan menu);
///   * yang dibagikan hanya modul yang dicentang, dan angkanya apa adanya.
library;

import 'package:flutter/foundation.dart';

/// Modul yang bisa dibagikan ke anggota keluarga.
enum ModulKeluarga {
  tagihan('tagihan', 'Tagihan'),
  transaksi('transaksi', 'Pengeluaran & pemasukan'),
  anggaran('anggaran', 'Anggaran'),
  kesehatan('kesehatan', 'Catatan kesehatan'),
  perawatan('perawatan', 'Perawatan berkala'),
  rumah('rumah', 'Kas rumah tangga'),
  dokumen('dokumen', 'Masa berlaku dokumen'),
  perjalanan('perjalanan', 'Perjalanan');

  const ModulKeluarga(this.kode, this.label);

  final String kode;
  final String label;

  static ModulKeluarga? dariKode(String? kode) {
    final k = (kode ?? '').trim().toLowerCase();
    for (final m in values) {
      if (m.kode == k) return m;
    }
    return null;
  }
}

/// Izin akses satu anggota untuk satu modul.
@immutable
class IzinKeluarga {
  const IzinKeluarga({
    required this.anggota,
    required this.modul,
    this.bolehLihat = true,
    this.bolehTambah = false,
    this.aktif = true,
  });

  final String anggota;
  final ModulKeluarga modul;

  /// Melihat data (baca).
  final bool bolehLihat;

  /// Menambah catatan baru (tulis) — biasanya lebih sempit daripada baca.
  final bool bolehTambah;
  final bool aktif;

  bool get berlaku => aktif && bolehLihat;

  String get label => '${modul.label} · ${bolehLihat ? 'lihat' : 'tidak'}'
      '${bolehTambah ? ' + tambah' : ''}';
}

/// Ringkasan sub-akses satu anggota.
@immutable
class RingkasAnggotaAkses {
  const RingkasAnggotaAkses({
    required this.anggota,
    required this.modul,
    required this.bolehTambah,
  });

  final String anggota;
  final List<ModulKeluarga> modul;
  final Set<ModulKeluarga> bolehTambah;

  bool get ada => modul.isNotEmpty;

  /// "Lihat 3 modul · boleh menambah 1 (Tagihan)."
  String get kalimat {
    if (modul.isEmpty) return '$anggota belum diberi akses modul apa pun.';
    final tambah = [
      for (final m in modul)
        if (bolehTambah.contains(m)) m.label,
    ];
    return 'Lihat ${modul.length} modul${tambah.isEmpty ? '' : ' · boleh '
        'menambah ${tambah.length} (${tambah.join(', ')})'}.';
  }
}

/// Ringkasan seluruh sub-akses untuk layar.
@immutable
class RingkasSubAkses {
  const RingkasSubAkses({
    required this.perAnggota,
    required this.belumBisa,
  });

  final List<RingkasAnggotaAkses> perAnggota;
  final List<String> belumBisa;

  bool get ada => perAnggota.isNotEmpty;

  String get dasar => perAnggota.isEmpty
      ? 'Sub-akses keluarga belum dipakai.'
      : '${perAnggota.length} anggota punya akses.';
}

/// Susun ringkasan per anggota dari daftar izin.
RingkasSubAkses ringkasSubAkses(
  List<IzinKeluarga> daftar, {
  List<String> anggotaTerdaftar = const [],
}) {
  final belum = <String>[];
  final peta = <String, List<IzinKeluarga>>{};
  for (final i in daftar) {
    if (!i.aktif) continue;
    if (!i.bolehLihat && !i.bolehTambah) continue;
    peta.putIfAbsent(i.anggota.trim(), () => []).add(i);
  }

  final hasil = <RingkasAnggotaAkses>[];
  for (final masuk in peta.entries) {
    final modul = <ModulKeluarga>[];
    final tambah = <ModulKeluarga>{};
    for (final i in masuk.value) {
      if (!modul.contains(i.modul)) modul.add(i.modul);
      if (i.bolehTambah) tambah.add(i.modul);
    }
    hasil.add(RingkasAnggotaAkses(
      anggota: masuk.key,
      modul: modul,
      bolehTambah: tambah,
    ));
  }
  hasil.sort((a, b) => a.anggota.compareTo(b.anggota));

  if (hasil.isEmpty) {
    belum.add('Belum ada anggota yang diberi akses — semua data tetap hanya '
        'di perangkat ini.');
  }
  for (final nama in anggotaTerdaftar) {
    if (!peta.containsKey(nama.trim())) {
      belum.add('$nama belum diberi akses modul apa pun.');
    }
  }
  for (final h in hasil) {
    if (h.modul.isEmpty) {
      belum.add('${h.anggota}: tidak ada modul yang boleh dilihat.');
    }
  }
  return RingkasSubAkses(perAnggota: hasil, belumBisa: belum);
}

/// Pemeriksaan izin baca (dipakai lapisan data, bukan UI).
bool bolehLihatModul(
  List<IzinKeluarga> daftar, {
  required String anggota,
  required ModulKeluarga modul,
}) {
  for (final i in daftar) {
    if (!i.aktif) continue;
    if (i.anggota.trim() != anggota.trim()) continue;
    if (i.modul != modul) continue;
    if (i.bolehLihat) return true;
  }
  return false;
}

/// Pemeriksaan izin tulis (dipakai lapisan data, bukan UI).
bool bolehTambahModul(
  List<IzinKeluarga> daftar, {
  required String anggota,
  required ModulKeluarga modul,
}) {
  for (final i in daftar) {
    if (!i.aktif) continue;
    if (i.anggota.trim() != anggota.trim()) continue;
    if (i.modul != modul) continue;
    if (i.bolehTambah) return true;
  }
  return false;
}

/// Modul yang boleh dilihat satu anggota.
List<ModulKeluarga> modulTerbuka(
  List<IzinKeluarga> daftar, {
  required String anggota,
}) {
  final hasil = <ModulKeluarga>[];
  for (final m in ModulKeluarga.values) {
    if (bolehLihatModul(daftar, anggota: anggota, modul: m) && !hasil.contains(m)) {
      hasil.add(m);
    }
  }
  return hasil;
}

/// Kalimat persetujuan yang harus dibaca sebelum berbagi (bukan kalimat samar).
String teksPersetujuanSubAkses({
  required String anggota,
  required List<ModulKeluarga> modul,
  required bool bolehTambah,
}) {
  if (modul.isEmpty) {
    return 'Tidak ada modul yang dipilih — tidak ada yang dibagikan.';
  }
  final daftar = modul.map((m) => m.label).join(', ');
  return 'Dengan menyimpan, $anggota dapat MELIHAT data: $daftar.'
      '${bolehTambah ? ' Ia juga boleh MENAMBAH catatan baru di modul itu.' : ' Ia hanya bisa melihat, tidak bisa mengubah.'} '
      'Data tetap tersimpan di perangkat ini sampai Anda membagikannya.';
}

/// Kode berbagi keluarga (6 karakter aman, tanpa akun & tanpa karakter yang
/// mudah tertukar). Aturan sama dengan kode rumah tangga FR-43.
String kodeBerbagiKeluarga(int acak) {
  const huruf = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  var benih = acak < 0 ? -acak : acak;
  final sb = StringBuffer();
  for (var i = 0; i < 6; i++) {
    sb.write(huruf[(benih + i * 7) % huruf.length]);
    benih = benih ~/ 3 + 11;
  }
  return sb.toString();
}

/// Kode berbagi sah?
bool kodeBerbagiSah(String? kode) {
  final k = (kode ?? '').trim().toUpperCase();
  if (k.length != 6) return false;
  return RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$').hasMatch(k);
}

/// Kalimat jujur tentang batas fitur (ditampilkan di layar).
const String catatanSubAkses =
    'Sub-akses ini opsional dan bekerja antar perangkat lewat berkas/kode '
    'berbagi yang Anda kirim sendiri (atau lewat sinkron FR-150). Aplikasi '
    'tidak mengunggah data keluarga ke server pihak ketiga, dan tidak ada '
    'modul yang terbuka tanpa Anda centang.';
