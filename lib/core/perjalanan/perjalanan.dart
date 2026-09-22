/// FR-134 — Perencanaan Perjalanan (mesin hitung, tanpa basis data).
///
/// Kriteria terima PRD: "Satu perjalanan menyatukan jadwal, anggaran
/// (terhubung Finance) dan dokumen (terhubung Document OS)".
/// Mesin ini hanya menjumlahkan apa yang benar-benar ada; angka yang tidak
/// bisa dihitung (mis. anggaran belum diisi) dilaporkan sebagai keterangan,
/// bukan ditebak.
library;

/// Jenis isi perjalanan. `label` dipakai di layar & uji.
enum JenisItemPerjalanan {
  agenda('agenda', 'Agenda'),
  tiket('tiket', 'Tiket'),
  hotel('hotel', 'Hotel'),
  bawaan('bawaan', 'Bawaan'),
  dokumen('dokumen', 'Dokumen'),
  lain('lain', 'Lainnya');

  const JenisItemPerjalanan(this.kode, this.label);

  final String kode;
  final String label;

  static JenisItemPerjalanan dariKode(String? kode) {
    for (final j in JenisItemPerjalanan.values) {
      if (j.kode == kode) return j;
    }
    return JenisItemPerjalanan.lain;
  }
}

/// Satu baris isi perjalanan (dipakai mesin ini, bukan kelas basis data).
class ItemPerjalanan {
  const ItemPerjalanan({
    required this.jenis,
    required this.judul,
    this.waktu,
    this.tempat,
    this.biayaSen = 0,
    this.selesai = false,
    this.dokumenUid,
    this.catatan,
  });

  final JenisItemPerjalanan jenis;
  final String judul;
  final DateTime? waktu;
  final String? tempat;
  final int biayaSen;

  /// Untuk `bawaan` & `agenda`: sudah dikerjakan/dibawa atau belum.
  final bool selesai;
  final String? dokumenUid;
  final String? catatan;
}

/// Hasil ringkasan satu perjalanan.
class RingkasanPerjalanan {
  const RingkasanPerjalanan({
    required this.dari,
    required this.sampai,
    required this.anggaranSen,
    required this.realisasiSen,
    required this.rencanaSen,
    required this.items,
    required this.sekarang,
  });

  final DateTime dari;
  final DateTime sampai;

  /// Anggaran yang diisi pengguna (0 = belum diisi).
  final int anggaranSen;

  /// Pengeluaran NYATA dari transaksi keuangan yang bertaut perjalanan ini.
  final int realisasiSen;

  /// Jumlah biaya item yang direncanakan (tiket/hotel/agenda).
  final int rencanaSen;
  final List<ItemPerjalanan> items;
  final DateTime sekarang;

  /// Sisa hari sampai keberangkatan; negatif = sudah lewat.
  int get hariLagi {
    final a = DateTime(dari.year, dari.month, dari.day);
    final b = DateTime(sekarang.year, sekarang.month, sekarang.day);
    return a.difference(b).inDays;
  }

  bool get sedangBerlangsung {
    final a = DateTime(dari.year, dari.month, dari.day);
    final b = DateTime(sampai.year, sampai.month, sampai.day);
    final t = DateTime(sekarang.year, sekarang.month, sekarang.day);
    return !t.isBefore(a) && !t.isAfter(b);
  }

  bool get selesai => sekarang.isAfter(DateTime(
      sampai.year, sampai.month, sampai.day, 23, 59, 59));

  int get jumlahBawaan =>
      items.where((i) => i.jenis == JenisItemPerjalanan.bawaan).length;

  int get bawaanSiap => items
      .where((i) => i.jenis == JenisItemPerjalanan.bawaan && i.selesai)
      .length;

  /// Persen bawaan siap (0–100); 0 bila daftar bawaan masih kosong.
  int get persenBawaan =>
      jumlahBawaan == 0 ? 0 : (bawaanSiap * 100 / jumlahBawaan).round();

  List<ItemPerjalanan> per(JenisItemPerjalanan jenis) =>
      items.where((i) => i.jenis == jenis).toList();

  int get sisaAnggaranSen => anggaranSen - realisasiSen;

  /// Persen anggaran terpakai; null bila anggaran belum diisi (tidak ditebak).
  int? get persenAnggaran =>
      anggaranSen <= 0 ? null : (realisasiSen * 100 / anggaranSen).round();

  /// Dasar data yang dipakai — PRD meminta angka bisa ditelusuri.
  String get dasarAnggaran => anggaranSen <= 0
      ? 'Anggaran belum diisi.'
      : 'Anggaran ${_rp(anggaranSen)} · terealisasi ${_rp(realisasiSen)} '
          'dari transaksi keuangan yang bertaut perjalanan ini.';

  /// Keterangan jujur untuk hal yang belum bisa dihitung.
  List<String> get belumBisa {
    final hasil = <String>[];
    if (anggaranSen <= 0) {
      hasil.add('Anggaran belum diisi, jadi sisa anggaran belum bisa dihitung.');
    }
    if (dari.isAfter(sampai)) {
      hasil.add('Tanggal selesai lebih awal daripada tanggal berangkat.');
    }
    return hasil;
  }

  /// Peringatan yang layak ditampilkan (urut dari yang paling mendesak).
  List<String> get peringatan {
    final hasil = <String>[];
    if (anggaranSen > 0 && realisasiSen > anggaranSen) {
      final lewat = realisasiSen - anggaranSen;
      hasil.add('Pengeluaran sudah lewat anggaran ${_rp(lewat)}.');
    } else if (persenAnggaran != null && persenAnggaran! >= 80) {
      hasil.add('Anggaran terpakai ${persenAnggaran!}%.');
    }
    if (!selesai && !sedangBerlangsung && hariLagi >= 0 && hariLagi <= 7) {
      hasil.add(hariLagi == 0
          ? 'Keberangkatan HARI INI.'
          : 'Keberangkatan $hariLagi hari lagi.');
    }
    if (jumlahBawaan > 0 && bawaanSiap < jumlahBawaan && hariLagi <= 3 &&
        hariLagi >= 0) {
      hasil.add(
          'Bawaan belum lengkap: ${jumlahBawaan - bawaanSiap} dari $jumlahBawaan belum dicentang.');
    }
    return hasil;
  }

  /// Dokumen yang ditautkan (uid) — penghubung ke Document OS.
  List<String> get dokumenTertaut => items
      .where((i) => i.dokumenUid != null && i.dokumenUid!.isNotEmpty)
      .map((i) => i.dokumenUid!)
      .toList();
}

String _rp(int sen) => fmtRingkasRp(sen);

/// Format rupiah ringkas tanpa locale (aman di uji & pekerja latar):
/// 1500000 sen → "Rp 15.000".
String fmtRingkasRp(int sen) {
  final rupiah = (sen / 100).round();
  final teks = rupiah.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < teks.length; i++) {
    if (i > 0 && (teks.length - i) % 3 == 0) buf.write('.');
    buf.write(teks[i]);
  }
  return '${rupiah < 0 ? '-' : ''}Rp $buf';
}

/// Susun ringkasan perjalanan. [realisasiSen] berasal dari transaksi keuangan
/// yang bertaut (FR-134: anggaran terhubung Finance).
RingkasanPerjalanan ringkasPerjalanan({
  required DateTime dari,
  required DateTime sampai,
  required int anggaranSen,
  required List<ItemPerjalanan> items,
  int realisasiSen = 0,
  DateTime? sekarang,
}) {
  final rencana = items
      .where((i) => i.jenis != JenisItemPerjalanan.bawaan)
      .fold<int>(0, (a, b) => a + b.biayaSen);
  return RingkasanPerjalanan(
    dari: dari,
    sampai: sampai,
    anggaranSen: anggaranSen,
    realisasiSen: realisasiSen,
    rencanaSen: rencana,
    items: items,
    sekarang: sekarang ?? DateTime.now(),
  );
}

/// Waktu pengingat keberangkatan (H-7, H-1, H-0) pada pukul 08:00 lokal.
/// Hanya dipakai bila [mulai] masih di depan [sekarang].
List<DateTime> jadwalPengingatKeberangkatan(
  DateTime mulai, {
  DateTime? sekarang,
  List<int> leadHari = const [7, 1, 0],
}) {
  final kini = sekarang ?? DateTime.now();
  final hasil = <DateTime>[];
  for (final h in leadHari) {
    final waktu = DateTime(mulai.year, mulai.month, mulai.day, 8)
        .subtract(Duration(days: h));
    if (waktu.isAfter(kini)) hasil.add(waktu);
  }
  hasil.sort();
  return hasil;
}
