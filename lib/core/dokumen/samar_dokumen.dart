/// FR-130 — Salin cepat & bagikan terkendali.
///
/// Aturan yang dijaga berkas ini (PRD FR-130): "salin satu ketukan; **tidak ada
/// berkas terkirim tanpa aksi pengguna yang jelas**". Jadi:
/// 1. teks yang dibagikan **selalu** memakai nomor yang disamarkan lebih dulu;
/// 2. berkas asli hanya ikut bila pengguna mencentang pilihannya sendiri
///    ([sertakanBerkas]) — bukan bawaan.
///
/// Semua fungsi murni (tanpa Flutter/berkas) supaya bisa diuji langsung.
library;

/// Hasil penyamaran satu nomor.
class NomorTersamar {
  const NomorTersamar({required this.teks, required this.panjangAsli});

  /// Nomor yang sudah disamarkan, mis. `A123••••••`.
  final String teks;

  /// Panjang nomor aslinya (dipakai keterangan "12 karakter").
  final int panjangAsli;

  @override
  String toString() => teks;
}

/// Samarkan [nomor] dengan menyisakan [tampakAwal] karakter pertama.
///
/// Aturan: karakter pertama & terakhir tetap tampak 1 huruf bila nomor sangat
/// pendek (≤ 3 karakter) supaya konteksnya masih terbaca, sisanya ditutup
/// `•`. Spasi & tanda hubung dipertahankan supaya bentuknya masih dikenali.
NomorTersamar samarNomor(String nomor, {int tampakAwal = 4}) {
  final bersih = nomor.trim();
  if (bersih.isEmpty) {
    return const NomorTersamar(teks: '', panjangAsli: 0);
  }
  final isi = bersih.replaceAll(RegExp(r'[\s\-]'), '');
  final ambang = isi.length <= 3 ? 1 : tampakAwal;
  var terlihat = 0;
  final buf = StringBuffer();
  for (final ch in bersih.split('')) {
    final pemisah = ch == ' ' || ch == '-';
    if (pemisah) {
      buf.write(ch);
      continue;
    }
    if (terlihat < ambang) {
      buf.write(ch);
      terlihat++;
    } else {
      buf.write('•');
    }
  }
  return NomorTersamar(teks: buf.toString(), panjangAsli: isi.length);
}

/// Isi yang siap dibagikan (teks + pilihan berkas).
class IsiBagikanTersamar {
  const IsiBagikanTersamar({
    required this.judul,
    required this.jenis,
    required this.teks,
    required this.berkasIkut,
    this.jalurBerkas,
  });

  final String judul;

  /// MIME jenis yang dikirim ke lembar berbagi.
  final String jenis;

  /// Teks isi — nomornya sudah disamarkan.
  final String teks;

  /// true = berkas asli ikut dibagikan (pilihan sadar pengguna).
  final bool berkasIkut;

  /// Jalur berkas asli bila [berkasIkut].
  final String? jalurBerkas;
}

/// Susun teks yang dibagikan untuk SATU dokumen.
///
/// [samarkanNomor] = true (bawaan) menyamarkan nomor dokumen. [sertakanBerkas]
/// hanya boleh true bila pengguna sendiri mencentangnya DAN jalur berkasnya
/// benar-benar ada ([jalurBerkas] tidak null).
IsiBagikanTersamar susunBagikanTersamar({
  required String nama,
  required String jenisDokumen,
  String? nomor,
  String? pemilik,
  DateTime? berlakuSampai,
  String? berkasNama,
  String? jalurBerkas,
  bool samarkanNomor = true,
  bool sertakanBerkas = false,
  String? catatanTambahan,
}) {
  final buf = StringBuffer()..writeln('*$nama*');
  buf.writeln('Jenis: ${jenisDokumen.isEmpty ? 'belum diisi' : jenisDokumen}');
  if (nomor != null && nomor.trim().isNotEmpty) {
    final hasil = samarkanNomor ? samarNomor(nomor).teks : nomor.trim();
    buf.writeln('Nomor: $hasil'
        '${samarkanNomor ? ' (disamarkan, ${samarNomor(nomor).panjangAsli} karakter)' : ''}');
  }
  if (pemilik != null && pemilik.trim().isNotEmpty) {
    buf.writeln('Pemilik: ${pemilik.trim()}');
  }
  if (berlakuSampai != null) {
    buf.writeln('Berlaku sampai: ${fmtTanggalBagikan(berlakuSampai)}');
  }
  if (catatanTambahan != null && catatanTambahan.trim().isNotEmpty) {
    buf.writeln(catatanTambahan.trim());
  }
  final adaBerkas = berkasNama != null && berkasNama.trim().isNotEmpty;
  final ikut = sertakanBerkas && adaBerkas && jalurBerkas != null;
  buf.writeln(ikut
      ? 'Berkas asli diikutkan: ${berkasNama.trim()}'
      : adaBerkas
          ? 'Berkas asli TIDAK diikutkan (hanya teks tersamar di atas).'
          : 'Tidak ada berkas terlampir pada dokumen ini.');
  return IsiBagikanTersamar(
    judul: 'Bagikan $nama (tersamar)',
    jenis: 'text/plain',
    teks: buf.toString().trimRight(),
    berkasIkut: ikut,
    jalurBerkas: ikut ? jalurBerkas : null,
  );
}

/// Nama berkas teks hasil penyamaran, mis. `bagikan-ktp.txt`.
String namaBerkasBagikan(String namaDokumen) {
  final bersih = namaDokumen
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'bagikan-${bersih.isEmpty ? 'dokumen' : bersih}.txt';
}

const List<String> _bulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Tanggal tanpa locale, mis. "12 Jan 2026".
String fmtTanggalBagikan(DateTime d) => '${d.day} ${_bulan[d.month - 1]} ${d.year}';
