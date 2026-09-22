/// Model Modul 0 "Hari Ini" (V1.5) — FR-60 … FR-63.
///
/// Semua kelas di berkas ini MURNI: tanpa Flutter, tanpa basis data. Tujuannya
/// supaya aturan warna, pemilihan 6 baris, dan teks alasan bisa diuji unit,
/// dan bisa dipakai ulang oleh layar Today, Kartu Pilar, Perhatian, dan
/// Morning Briefing.
library;

/// Tingkat warna tunggal untuk seluruh Modul 0 (§3.2 rancangan TODAY).
/// `netral` dipakai untuk data yang memang belum ada — bukan nilai buruk.
enum TingkatPrioritas {
  merah(0),
  oranye(1),
  kuning(2),
  hijau(3),
  netral(4);

  const TingkatPrioritas(this.urutan);

  /// Angka kecil = lebih mendesak (dipakai untuk mengurutkan).
  final int urutan;

  bool get mendesak => this == merah || this == oranye;
}

/// Lima kartu pilar harian, urutannya tetap (FR-61).
enum Pilar { health, money, productivity, family, ibadah }

extension InfoPilar on Pilar {
  String get label => switch (this) {
        Pilar.health => 'Kesehatan',
        Pilar.money => 'Uang',
        Pilar.productivity => 'Produktivitas',
        Pilar.family => 'Keluarga',
        Pilar.ibadah => 'Ibadah',
      };

  /// Nama ikon Material (dipetakan di lapisan UI supaya berkas ini tetap murni).
  String get kunciIkon => switch (this) {
        Pilar.health => 'favorite',
        Pilar.money => 'payments',
        Pilar.productivity => 'checklist',
        Pilar.family => 'family_restroom',
        Pilar.ibadah => 'mosque',
      };
}

/// Jenis butir agenda/Perhatian.
enum JenisButir { tagihan, dokumen, janji, tugas, sholat }

/// Satu butir agenda hari ini.
class ButirAgenda {
  const ButirAgenda({
    required this.id,
    required this.jenis,
    required this.judul,
    this.waktu,
    this.nominalSen,
    this.tingkat = TingkatPrioritas.netral,
    this.selesai = false,
    this.alasan = '',
    this.rute,
  });

  final String id;
  final JenisButir jenis;
  final String judul;
  final DateTime? waktu;
  final int? nominalSen;
  final TingkatPrioritas tingkat;
  final bool selesai;
  final String alasan;
  final String? rute;

  ButirAgenda salinDengan({TingkatPrioritas? tingkat, bool? selesai, String? alasan}) =>
      ButirAgenda(
        id: id,
        jenis: jenis,
        judul: judul,
        waktu: waktu,
        nominalSen: nominalSen,
        tingkat: tingkat ?? this.tingkat,
        selesai: selesai ?? this.selesai,
        alasan: alasan ?? this.alasan,
        rute: rute,
      );
}

/// Hasil satu kartu pilar.
class NilaiPilar {
  const NilaiPilar({
    required this.pilar,
    required this.angka,
    this.keterangan = '',
    this.tingkat = TingkatPrioritas.netral,
    this.belumAdaData = false,
    this.rute,
  });

  final Pilar pilar;

  /// Kalimat angka yang tampil di kartu (selalu berisi data nyata atau
  /// "Belum ada data" — tidak pernah angka contoh).
  final String angka;

  /// Catatan kecil di bawah angka (mis. "termasuk tagihan & janji").
  final String keterangan;

  final TingkatPrioritas tingkat;

  /// true = modulnya belum ada / belum ada catatan hari ini.
  final bool belumAdaData;

  final String? rute;
}

/// Jenis butir Perhatian (FR-62). Nomor mengikuti urutan prioritas (§5.1).
enum JenisPerhatian {
  tagihanTerlambat,
  hambatanSistem,
  tenggatDekat,
  dokumenKedaluwarsa,
  garansiAset,
  perawatanAset,
}

extension InfoPerhatian on JenisPerhatian {
  int get prioritas => switch (this) {
        JenisPerhatian.tagihanTerlambat => 0,
        JenisPerhatian.hambatanSistem => 1,
        JenisPerhatian.tenggatDekat => 2,
        JenisPerhatian.dokumenKedaluwarsa => 3,
        JenisPerhatian.garansiAset => 4,
        JenisPerhatian.perawatanAset => 5,
      };
}

/// Satu butir Perhatian: judul singkat · alasan berangka · satu tombol.
class ButirPerhatian {
  const ButirPerhatian({
    required this.id,
    required this.jenis,
    required this.judul,
    required this.alasan,
    required this.labelTombol,
    this.rute,
    this.tingkat = TingkatPrioritas.merah,
  });

  final String id;
  final JenisPerhatian jenis;
  final String judul;
  final String alasan;
  final String labelTombol;
  final String? rute;
  final TingkatPrioritas tingkat;
}

/// Ringkasan satu hari kerja layar Today.
class RingkasanHariIni {
  const RingkasanHariIni({
    required this.tanggal,
    required this.agenda,
    required this.jumlahAgenda,
    required this.perhatian,
    required this.pilar,
  });

  final DateTime tanggal;

  /// Maksimal 6 butir (FR-60).
  final List<ButirAgenda> agenda;

  /// Jumlah seluruh butir hari ini (untuk tombol "Lihat semua (N)").
  final int jumlahAgenda;

  /// Maksimal 5 butir (FR-62).
  final List<ButirPerhatian> perhatian;

  final List<NilaiPilar> pilar;

  bool get adaAgenda => agenda.isNotEmpty;

  NilaiPilar pilarDari(Pilar p) => pilar.firstWhere((n) => n.pilar == p);
}

/// Isi Morning Briefing (FR-63).
class IsiBriefing {
  const IsiBriefing({
    required this.sapaan,
    required this.tanggal,
    required this.hijriah,
    required this.jam,
    required this.agenda,
    required this.tagihanTujuhHari,
    required this.totalTagihanSen,
    this.sholatBerikutnya,
    this.cuaca,
    this.sumberCuaca = '',
    this.daring = true,
  });

  final String sapaan;
  final DateTime tanggal;
  final String hijriah;
  final DateTime jam;
  final List<ButirAgenda> agenda;
  final List<ButirAgenda> tagihanTujuhHari;
  final int totalTagihanSen;
  final String? sholatBerikutnya;
  final String? cuaca;
  final String sumberCuaca;
  final bool daring;
}

/// Ringkas garansi aset untuk Perhatian (FR-126).
class RingkasGaransiAset {
  const RingkasGaransiAset({
    required this.asetId,
    required this.nama,
    required this.sampai,
  });

  final int asetId;
  final String nama;
  final DateTime sampai;
}

/// Ringkas jadwal perawatan untuk Perhatian (FR-125).
class RingkasPerawatanAset {
  const RingkasPerawatanAset({
    required this.perawatanId,
    required this.nama,
    required this.berikutnya,
    this.asetId,
  });

  final int perawatanId;
  final String nama;
  final DateTime berikutnya;
  final int? asetId;
}
