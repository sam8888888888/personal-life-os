/// FR-133 — Kas & Tanggung Jawab Rumah Tangga (mesin hitung).
///
/// Kriteria terima PRD: "Riwayat siapa bayar apa akurat; pengingat tidak
/// terkirim tanpa persetujuan pengguna".
///
/// Karena itu mesin ini: (1) menjumlahkan per anggota apa adanya (tanpa
/// tebakan), (2) memutuskan boleh/tidaknya sebuah pengingat halus dikirim —
/// butuh persetujuan menyala DAN maksimal sekali sehari DAN di jam wajar.
library;

import '../perjalanan/perjalanan.dart' show fmtRingkasRp;

/// Satu kewajiban rumah tangga: "siapa bayar apa".
class KewajibanRumah {
  const KewajibanRumah({
    required this.nama,
    required this.jumlahSen,
    required this.jatuhTempo,
    this.pemilikNama,
    this.penanggungJawabNama,
    this.lunas = false,
    this.tanggalBayar,
    this.catatanPelunasan,
    this.diingatkanPada,
  });

  final String nama;
  final int jumlahSen;
  final DateTime jatuhTempo;

  /// Pemilik manfaat (mis. "sekolah anak") dan yang menanggung bayar.
  final String? pemilikNama;
  final String? penanggungJawabNama;
  final bool lunas;
  final DateTime? tanggalBayar;
  final String? catatanPelunasan;

  /// Kapan pengingat halus terakhir dikirim (null = belum pernah).
  final DateTime? diingatkanPada;

  String get penanggungJawab => (penanggungJawabNama ?? '').trim().isEmpty
      ? 'Belum ditentukan'
      : penanggungJawabNama!.trim();

  int hariMenujuJatuhTempo(DateTime sekarang) {
    final a = DateTime(
        jatuhTempo.year, jatuhTempo.month, jatuhTempo.day);
    final b = DateTime(sekarang.year, sekarang.month, sekarang.day);
    return a.difference(b).inDays;
  }
}

/// Ringkasan per anggota: berapa yang jadi tanggungannya, berapa sudah dibayar.
class RingkasanAnggota {
  const RingkasanAnggota({
    required this.nama,
    required this.totalSen,
    required this.sudahBayarSen,
    required this.jumlahItem,
    required this.jumlahLunas,
  });

  final String nama;
  final int totalSen;
  final int sudahBayarSen;
  final int jumlahItem;
  final int jumlahLunas;

  int get sisaSen => totalSen - sudahBayarSen;

  /// Persen lunas (0–100) berdasarkan jumlah item, bukan nominal — supaya
  /// "12 dari 15 tagihan beres" tidak tercampur dengan nominal besar-kecil.
  int get persenLunas =>
      jumlahItem == 0 ? 0 : (jumlahLunas * 100 / jumlahItem).round();
}

/// Hasil lengkap untuk layar.
class RingkasanRumahTangga {
  const RingkasanRumahTangga({
    required this.items,
    required this.perAnggota,
    required this.sekarang,
  });

  final List<KewajibanRumah> items;
  final List<RingkasanAnggota> perAnggota;
  final DateTime sekarang;

  int get totalSen => items.fold<int>(0, (a, b) => a + b.jumlahSen);

  int get sudahBayarSen => items
      .where((i) => i.lunas)
      .fold<int>(0, (a, b) => a + b.jumlahSen);

  int get sisaSen => totalSen - sudahBayarSen;

  int get jumlahLunas => items.where((i) => i.lunas).length;

  /// Belum lunas & jatuh tempo dalam [hari] ke depan (termasuk yang lewat).
  List<KewajibanRumah> jatuhTempoDekat({int hari = 7}) {
    final hasil = items
        .where((i) =>
            !i.lunas && i.hariMenujuJatuhTempo(sekarang) <= hari)
        .toList();
    hasil.sort((a, b) => a.jatuhTempo.compareTo(b.jatuhTempo));
    return hasil;
  }

  /// Riwayat pelunasan (sudah dibayar), terbaru dulu.
  List<KewajibanRumah> riwayatPelunasan() {
    final hasil = items.where((i) => i.lunas).toList();
    hasil.sort((a, b) =>
        (b.tanggalBayar ?? b.jatuhTempo).compareTo(a.tanggalBayar ?? a.jatuhTempo));
    return hasil;
  }

  /// Dasar data untuk laporan (angka bisa ditelusuri).
  String get dasar =>
      '${items.length} kewajiban rumah tangga · total ${fmtRingkasRp(totalSen)} · '
      'sudah dibayar ${fmtRingkasRp(sudahBayarSen)}.';

  List<String> get belumBisa {
    final hasil = <String>[];
    if (items.isEmpty) {
      hasil.add('Belum ada kewajiban rumah tangga yang dicatat.');
    }
    if (items.any((i) => (i.penanggungJawabNama ?? '').trim().isEmpty)) {
      hasil.add(
          'Ada ${items.where((i) => (i.penanggungJawabNama ?? '').trim().isEmpty).length} '
          'kewajiban yang penanggung jawabnya belum ditentukan.');
    }
    return hasil;
  }
}

/// Susun ringkasan; kelompokkan per penanggung jawab (urut nominal terbesar).
RingkasanRumahTangga ringkasRumahTangga(
  List<KewajibanRumah> items, {
  DateTime? sekarang,
}) {
  final kini = sekarang ?? DateTime.now();
  final peta = <String, List<KewajibanRumah>>{};
  for (final i in items) {
    peta.putIfAbsent(i.penanggungJawab, () => []).add(i);
  }
  final perAnggota = peta.entries.map((e) {
    final total = e.value.fold<int>(0, (a, b) => a + b.jumlahSen);
    final bayar =
        e.value.where((i) => i.lunas).fold<int>(0, (a, b) => a + b.jumlahSen);
    return RingkasanAnggota(
      nama: e.key,
      totalSen: total,
      sudahBayarSen: bayar,
      jumlahItem: e.value.length,
      jumlahLunas: e.value.where((i) => i.lunas).length,
    );
  }).toList()
    ..sort((a, b) => b.totalSen.compareTo(a.totalSen));
  return RingkasanRumahTangga(
      items: items, perAnggota: perAnggota, sekarang: kini);
}

/// Alasan sebuah pengingat halus TIDAK boleh dikirim (kosong = boleh).
///
/// Aturan: butuh persetujuan pengguna (saklar), maksimal sekali per hari per
/// kewajiban, dan hanya pada jam wajar 08.00–21.00.
List<String> alasanTidakBolehDiingatkan(
  KewajibanRumah item, {
  required DateTime sekarang,
  required bool persetujuanMenyala,
  int jamMulai = 8,
  int jamSelesai = 21,
}) {
  final hasil = <String>[];
  if (!persetujuanMenyala) {
    hasil.add(
        'Pengingat belum diizinkan. Nyalakan dulu "Izinkan pengingat rumah tangga" di Pengaturan.');
  }
  if (item.lunas) {
    hasil.add('Kewajiban ini sudah lunas.');
  }
  if (sekarang.hour < jamMulai || sekarang.hour >= jamSelesai) {
    hasil.add(
        'Di luar jam wajar ($jamMulai.00–$jamSelesai.00) — pengingat halus tidak dikirim.');
  }
  final terakhir = item.diingatkanPada;
  if (terakhir != null &&
      terakhir.year == sekarang.year &&
      terakhir.month == sekarang.month &&
      terakhir.day == sekarang.day) {
    hasil.add('Sudah diingatkan hari ini — cukup sekali sehari.');
  }
  return hasil;
}

/// Boleh dikirim sekarang?
bool bolehDiingatkan(
  KewajibanRumah item, {
  required DateTime sekarang,
  required bool persetujuanMenyala,
}) =>
    alasanTidakBolehDiingatkan(
      item,
      sekarang: sekarang,
      persetujuanMenyala: persetujuanMenyala,
    ).isEmpty;

/// Kalimat pengingat halus (satu ketukan) — sopan, tanpa menuduh.
String teksPengingatHalus(KewajibanRumah item, {required DateTime sekarang}) {
  final hari = item.hariMenujuJatuhTempo(sekarang);
  final kapan = hari < 0
      ? 'sudah lewat ${-hari} hari'
      : hari == 0
          ? 'jatuh tempo hari ini'
          : 'jatuh tempo $hari hari lagi';
  return 'Pengingat halus: ${item.nama} (${fmtRingkasRp(item.jumlahSen)}) '
      '$kapan — penanggung jawab: ${item.penanggungJawab}.';
}
