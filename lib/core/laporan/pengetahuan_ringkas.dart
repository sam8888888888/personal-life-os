/// FR-118/119/120/122/123 — logika modul Pengetahuan (murni, tanpa I/O).
///
/// Semua hitungan di berkas ini bisa diuji langsung tanpa database. Layar
/// hanya menyiapkan bahan (baris dari penyimpanan) lalu menampilkan hasilnya.
///
/// Bahasa: hanya melaporkan angka & keadaan apa adanya. Tidak ada penilaian
/// ("rajin/tidak", "gagal"), tidak ada kata terlarang PRD §III-11.
library;

/// Satu baris catatan/ide (FR-118).
class BarisCatatan {
  const BarisCatatan({
    required this.id,
    required this.judul,
    required this.isi,
    required this.kategori,
    required this.dibuatPada,
    this.tag,
    this.disematkan = false,
    this.arsip = false,
    this.jumlahTautan = 0,
  });

  final int id;
  final String judul;
  final String isi;
  final String kategori;
  final String? tag;
  final bool disematkan;
  final bool arsip;
  final DateTime dibuatPada;
  final int jumlahTautan;
}

/// Ringkasan daftar catatan (FR-118).
class RingkasCatatan {
  const RingkasCatatan({
    required this.total,
    required this.perKategori,
    required this.jumlahDisematkan,
    required this.jumlahDiarsipkan,
    required this.jumlahTautan,
    required this.terbaru,
  });

  final int total;
  final Map<String, int> perKategori;
  final int jumlahDisematkan;
  final int jumlahDiarsipkan;
  final int jumlahTautan;

  /// Beberapa catatan terbaru (paling baru dulu).
  final List<BarisCatatan> terbaru;
}

/// Ringkasan daftar catatan; [terbaru] dibatasi [batasTerbaru] baris.
RingkasCatatan ringkasCatatan(List<BarisCatatan> catatan,
    {int batasTerbaru = 5}) {
  final perKategori = <String, int>{};
  var disematkan = 0;
  var arsip = 0;
  var tautan = 0;
  for (final c in catatan) {
    perKategori.update(c.kategori, (v) => v + 1, ifAbsent: () => 1);
    if (c.disematkan) disematkan++;
    if (c.arsip) arsip++;
    tautan += c.jumlahTautan;
  }
  final urut = [...catatan]..sort((a, b) => b.dibuatPada.compareTo(a.dibuatPada));
  return RingkasCatatan(
    total: catatan.length,
    perKategori: perKategori,
    jumlahDisematkan: disematkan,
    jumlahDiarsipkan: arsip,
    jumlahTautan: tautan,
    terbaru: urut.take(batasTerbaru).toList(),
  );
}

/// Cari catatan menurut kata kunci (judul, isi, tag) — huruf besar/kecil bebas.
List<BarisCatatan> cariCatatan(List<BarisCatatan> catatan, String kunci) {
  final k = kunci.trim().toLowerCase();
  if (k.isEmpty) return catatan;
  return catatan
      .where((c) =>
          c.judul.toLowerCase().contains(k) ||
          c.isi.toLowerCase().contains(k) ||
          (c.tag ?? '').toLowerCase().contains(k) ||
          c.kategori.toLowerCase().contains(k))
      .toList();
}

/// Satu baris keputusan (FR-119).
class BarisKeputusan {
  const BarisKeputusan({
    required this.id,
    required this.judul,
    required this.diputuskanPada,
    this.konteks,
    this.pilihan,
    this.dipilih,
    this.alasan,
    this.harapan,
    this.risiko,
    this.biaya,
    this.keyakinan = 50,
    this.tinjauPada,
    this.hasil,
    this.hasilPada,
    this.jumlahTautan = 0,
  });

  final int id;
  final String judul;
  final String? konteks;
  final String? pilihan;
  final String? dipilih;
  final String? alasan;
  final String? harapan;
  final String? risiko;
  final String? biaya;
  final int keyakinan;
  final DateTime diputuskanPada;
  final DateTime? tinjauPada;
  final String? hasil;
  final DateTime? hasilPada;
  final int jumlahTautan;
}

/// Ringkasan keputusan (FR-119).
class RingkasKeputusan {
  const RingkasKeputusan({
    required this.total,
    required this.menungguTinjauan,
    required this.sudahDitinjau,
    required this.keyakinanRataRata,
    required this.perlu,
  });

  final int total;
  final int menungguTinjauan;
  final int sudahDitinjau;

  /// Rata-rata keyakinan saat memutuskan (null bila belum ada keputusan).
  final double? keyakinanRataRata;

  /// Keputusan yang jadwal tinjaunya sudah lewat dan hasilnya belum ditulis.
  final List<BarisKeputusan> perlu;
}

/// Keputusan yang jadwal tinjaunya sudah lewat pada tanggal [acuan].
List<BarisKeputusan> keputusanPerluDitinjau(
  List<BarisKeputusan> keputusan, {
  required DateTime acuan,
}) {
  final batas = DateTime(acuan.year, acuan.month, acuan.day, 23, 59, 59);
  final perlu = keputusan
      .where((k) =>
          k.tinjauPada != null &&
          !k.tinjauPada!.isAfter(batas) &&
          (k.hasil == null || k.hasil!.trim().isEmpty))
      .toList()
    ..sort((a, b) => a.tinjauPada!.compareTo(b.tinjauPada!));
  return perlu;
}

RingkasKeputusan ringkasKeputusan(List<BarisKeputusan> keputusan,
    {required DateTime acuan}) {
  final perlu = keputusanPerluDitinjau(keputusan, acuan: acuan);
  final sudah = keputusan
      .where((k) => k.hasil != null && k.hasil!.trim().isNotEmpty)
      .length;
  final keyakinan = keputusan.isEmpty
      ? null
      : keputusan.map((k) => k.keyakinan).reduce((a, b) => a + b) /
          keputusan.length;
  return RingkasKeputusan(
    total: keputusan.length,
    menungguTinjauan: perlu.length,
    sudahDitinjau: sudah,
    keyakinanRataRata: keyakinan,
    perlu: perlu,
  );
}

/// Satu baris pembelajaran (FR-120).
class BarisPembelajaran {
  const BarisPembelajaran({
    required this.topik,
    required this.tanggal,
    this.id,
    this.sumber,
    this.menit = 0,
    this.status = 'belajar',
  });

  final int? id;
  final String topik;
  final String? sumber;
  final int menit;
  final DateTime tanggal;
  final String status;
}

/// Ringkasan pembelajaran dalam rentang hari terakhir (FR-120).
class RingkasPembelajaran {
  const RingkasPembelajaran({
    required this.totalMenit,
    required this.hariAktif,
    required this.perTopik,
    required this.menitRentang,
    required this.topikTeratas,
  });

  final int totalMenit;
  final int hariAktif;
  final Map<String, int> perTopik;

  /// Menit pada rentang hari terakhir ([hari] hari ke belakang dari acuan).
  final int menitRentang;
  final String? topikTeratas;
}

RingkasPembelajaran ringkasPembelajaran(
  List<BarisPembelajaran> baris, {
  required DateTime acuan,
  int hari = 7,
}) {
  final awal = DateTime(acuan.year, acuan.month, acuan.day)
      .subtract(Duration(days: hari - 1));
  final perTopik = <String, int>{};
  final hariUnik = <String>{};
  var menitRentang = 0;
  for (final b in baris) {
    perTopik.update(b.topik, (v) => v + b.menit, ifAbsent: () => b.menit);
    if (!b.tanggal.isBefore(awal)) {
      menitRentang += b.menit;
      hariUnik.add('${b.tanggal.year}-${b.tanggal.month}-${b.tanggal.day}');
    }
  }
  String? teratas;
  var menitTeratas = -1;
  for (final e in perTopik.entries) {
    if (e.value > menitTeratas) {
      menitTeratas = e.value;
      teratas = e.key;
    }
  }
  return RingkasPembelajaran(
    totalMenit: baris.fold(0, (a, b) => a + b.menit),
    hariAktif: hariUnik.length,
    perTopik: perTopik,
    menitRentang: menitRentang,
    topikTeratas: teratas,
  );
}

/// Batang menit per hari untuk grafik sederhana (FR-120).
class BatangMenit {
  const BatangMenit({
    required this.tanggal,
    required this.menit,
    required this.label,
  });

  final DateTime tanggal;
  final int menit;
  final String label;
}

/// Menit per hari untuk [hari] hari terakhir ([acuan] sebagai hari terakhir).
List<BatangMenit> batangPembelajaran(
  List<BarisPembelajaran> baris, {
  required DateTime acuan,
  int hari = 14,
}) {
  const namaHari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  final hasil = <BatangMenit>[];
  for (var i = hari - 1; i >= 0; i--) {
    final tgl = DateTime(acuan.year, acuan.month, acuan.day)
        .subtract(Duration(days: i));
    var menit = 0;
    for (final b in baris) {
      if (b.tanggal.year == tgl.year &&
          b.tanggal.month == tgl.month &&
          b.tanggal.day == tgl.day) {
        menit += b.menit;
      }
    }
    hasil.add(BatangMenit(
      tanggal: tgl,
      menit: menit,
      label: namaHari[tgl.weekday - 1],
    ));
  }
  return hasil;
}

/// Satu baris bacaan (FR-122).
class BarisBacaan {
  const BarisBacaan({
    required this.id,
    required this.judul,
    this.penulis,
    this.jenis = 'buku',
    this.halamanTotal,
    this.halamanKini = 0,
    this.status = 'antre',
    this.selesaiPada,
    this.nilai,
    this.jumlahTautan = 0,
  });

  final int id;
  final String judul;
  final String? penulis;
  final String jenis;
  final int? halamanTotal;
  final int halamanKini;
  final String status;
  final DateTime? selesaiPada;
  final int? nilai;
  final int jumlahTautan;

  /// Bagian yang sudah dibaca (0–1); null bila jumlah halaman tidak diisi.
  double? get progres {
    final total = halamanTotal;
    if (total == null || total <= 0) return null;
    final p = halamanKini / total;
    return p.clamp(0, 1).toDouble();
  }
}

/// Ringkasan bacaan (FR-122).
class RingkasBacaan {
  const RingkasBacaan({
    required this.total,
    required this.sedangDibaca,
    required this.antre,
    required this.selesai,
    required this.selesaiTahunIni,
    required this.halamanDibaca,
    required this.rataNilai,
  });

  final int total;
  final List<BarisBacaan> sedangDibaca;
  final int antre;
  final int selesai;
  final int selesaiTahunIni;
  final int halamanDibaca;

  /// Rata-rata penilaian pengguna (null bila belum ada yang dinilai).
  final double? rataNilai;
}

RingkasBacaan ringkasBacaan(List<BarisBacaan> bacaan,
    {required DateTime acuan}) {
  final dibaca = bacaan.where((b) => b.status == 'dibaca').toList()
    ..sort((a, b) => (b.progres ?? 0).compareTo(a.progres ?? 0));
  final tuntas = bacaan.where((b) => b.status == 'selesai').toList();
  final tahunIni = tuntas
      .where((b) => b.selesaiPada != null && b.selesaiPada!.year == acuan.year)
      .length;
  final nilai = bacaan.map((b) => b.nilai).whereType<int>().toList();
  return RingkasBacaan(
    total: bacaan.length,
    sedangDibaca: dibaca,
    antre: bacaan.where((b) => b.status == 'antre').length,
    selesai: tuntas.length,
    selesaiTahunIni: tahunIni,
    halamanDibaca: bacaan.fold(0, (a, b) => a + b.halamanKini),
    rataNilai:
        nilai.isEmpty ? null : nilai.reduce((a, b) => a + b) / nilai.length,
  );
}

/// Satu tautan antar butir pengetahuan (FR-123).
class BarisTautan {
  const BarisTautan({
    required this.jenisA,
    required this.idA,
    required this.jenisB,
    required this.idB,
    this.judulA = '',
    this.judulB = '',
    this.label,
  });

  final String jenisA;
  final int idA;
  final String judulA;
  final String jenisB;
  final int idB;
  final String judulB;
  final String? label;
}

/// Rumus pasangan untuk mencegah tautan kembar & tautan ke diri sendiri.
String kunciTautan(String jenisA, int idA, String jenisB, int idB) {
  final satu = '$jenisA:$idA';
  final dua = '$jenisB:$idB';
  return satu.compareTo(dua) <= 0 ? '$satu|$dua' : '$dua|$satu';
}

/// Apakah tautan ini boleh disimpan (bukan ke diri sendiri)?
bool tautanSah(String jenisA, int idA, String jenisB, int idB) =>
    !(jenisA == jenisB && idA == idB);

/// Apakah [calon] sudah ada di [ada]?
bool tautanKembar(List<BarisTautan> ada, BarisTautan calon) {
  final kunci = kunciTautan(calon.jenisA, calon.idA, calon.jenisB, calon.idB);
  return ada.any((t) => kunciTautan(t.jenisA, t.idA, t.jenisB, t.idB) == kunci);
}

/// Tautan yang menyentuh satu butir (jenis + id).
List<BarisTautan> tautanUntuk(List<BarisTautan> tautan, String jenis, int id) =>
    tautan
        .where((t) =>
            (t.jenisA == jenis && t.idA == id) ||
            (t.jenisB == jenis && t.idB == id))
        .toList();

/// Jumlah tautan per jenis butir.
Map<String, int> jumlahTautanPerJenis(List<BarisTautan> tautan) {
  final hasil = <String, int>{};
  for (final t in tautan) {
    hasil.update(t.jenisA, (v) => v + 1, ifAbsent: () => 1);
    hasil.update(t.jenisB, (v) => v + 1, ifAbsent: () => 1);
  }
  return hasil;
}

/// Label jenis butir pengetahuan untuk ditampilkan.
String labelJenisPengetahuan(String jenis) => switch (jenis) {
      'catatan' => 'Catatan',
      'keputusan' => 'Keputusan',
      'bacaan' => 'Bacaan',
      'kartu' => 'Kartu ulangan',
      'pembelajaran' => 'Pembelajaran',
      'tujuan' => 'Tujuan',
      'proyek' => 'Proyek',
      'tugas' => 'Tugas',
      'dokumen' => 'Dokumen',
      _ => jenis,
    };

/// Satu butir yang bisa ditautkan (FR-123) — dipakai penyimpanan & pemilih.
class ButirPengetahuan {
  const ButirPengetahuan(this.jenis, this.id, this.judul);

  final String jenis;
  final int id;
  final String judul;

  String get label => '${labelJenisPengetahuan(jenis)} · $judul';
}
