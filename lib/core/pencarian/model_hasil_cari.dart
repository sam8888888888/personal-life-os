/// FR-139 — Search Everything: model hasil pencarian lintas modul.
///
/// Satu hasil = satu baris yang bisa disentuh pengguna. `rute` adalah tujuan
/// GoRouter (null = hasil hanya menampilkan keterangan, tidak bisa dibuka).
library;

/// Jenis modul asal hasil pencarian (dipakai untuk pengelompokan & label).
enum ModulHasil {
  tagihan('Tagihan & Dokumen'),
  uang('Uang'),
  aksi('Aksi & Tujuan'),
  kesehatan('Kesehatan'),
  ibadah('Ibadah');

  const ModulHasil(this.label);

  /// Label Bahasa Indonesia untuk pengelompokan di layar.
  final String label;
}

/// Satu hasil pencarian.
class HasilCari {
  const HasilCari({
    required this.modul,
    required this.judul,
    required this.keterangan,
    this.rute,
    this.idSumber,
  });

  final ModulHasil modul;

  /// Teks utama yang cocok (nama dokumen/obat/tugas, dst).
  final String judul;

  /// Keterangan pendukung: kapan, berapa, jenis. Boleh kosong.
  final String keterangan;

  /// Tujuan bila hasil bisa dibuka; null bila tidak ada halaman tujuannya.
  final String? rute;

  /// Id baris asal (dipakai untuk kunci widget & jejak).
  final int? idSumber;

  @override
  String toString() => '${modul.label} · $judul · $keterangan';
}

/// Ringkasan hasil: daftar hasil + jumlah per modul (untuk label chip).
class RingkasanCari {
  const RingkasanCari({required this.kata, required this.hasil});

  /// Kata kunci yang dipakai (sudah dirapikan).
  final String kata;

  final List<HasilCari> hasil;

  bool get kosong => hasil.isEmpty;

  /// Jumlah hasil per modul, urut sesuai [ModulHasil].
  Map<ModulHasil, int> get jumlahPerModul {
    final peta = <ModulHasil, int>{};
    for (final h in hasil) {
      peta[h.modul] = (peta[h.modul] ?? 0) + 1;
    }
    return peta;
  }
}
