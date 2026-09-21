/// FR-25 — Ekspor CSV untuk dibuka di spreadsheet.
///
/// Aturan penulisan CSV (sama dengan laporan bulanan yang sudah ada, FR-77):
///   * pemisah kolom `;`  → aman di Excel Indonesia (koma dipakai desimal)
///   * bilangan uang ditulis DUA kolom: `jumlah_sen` (bilangan bulat, untuk
///     dihitung) dan `jumlah` (teks dengan koma desimal, untuk dibaca)
///   * tanggal ditulis `YYYY-MM-DD` supaya diurutkan dengan benar
///   * sel yang memuat `;`, tanda kutip, atau ganti baris dibungkus tanda kutip
///
/// Berkas ditulis ke folder yang diberikan (dokumen aplikasi di HP; saat uji
/// dipakai folder sementara) — jadi tidak ada berkas yang "hilang entah ke mana".
library;

import 'dart:io';

import '../../data/database/database.dart';

class BerkasCsv {
  const BerkasCsv({required this.nama, required this.jalur, required this.baris});

  final String nama;
  final String jalur;
  final int baris;

  @override
  String toString() => '$nama ($baris baris)';
}

// ------------------------------------------------------------------ pembantu
String tanggalCsv(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

/// Amankan satu sel CSV.
String selCsv(String isi) {
  final perlu = isi.contains(';') ||
      isi.contains('"') ||
      isi.contains('\n') ||
      isi.contains('\r');
  return perlu ? '"${isi.replaceAll('"', '""')}"' : isi;
}

/// Bilangan SEN → teks "1.234,50" (dipakai kolom `jumlah` yang mudah dibaca).
String rupiahDariSen(int sen) {
  final negatif = sen < 0;
  final utuh = (sen.abs() ~/ 100).toString();
  final pecahan = (sen.abs() % 100).toString().padLeft(2, '0');
  final ribuan = StringBuffer();
  for (var i = 0; i < utuh.length; i++) {
    if (i > 0 && (utuh.length - i) % 3 == 0) ribuan.write('.');
    ribuan.write(utuh[i]);
  }
  return '${negatif ? '-' : ''}$ribuan,$pecahan';
}

List<String> _barisCsv(List<String> sel) => sel.map(selCsv).toList();

// ------------------------------------------------------------------ tagihan
/// CSV daftar tagihan (semua tagihan, termasuk yang nonaktif).
String csvTagihan(List<TagihanData> tagihan,
    {Map<int, String> namaKategori = const <int, String>{}}) {
  final keluar = StringBuffer();
  keluar.writeln(_barisCsv(const [
    'id', 'nama', 'jenis', 'kategori', 'jumlah_sen', 'jumlah', 'mata_uang',
    'jatuh_tempo', 'frekuensi', 'status_aktif', 'lunas', 'tanggal_lunas',
    'pengingat_lead_hari', 'pengingat_jam', 'catatan',
  ]).join(';'));
  for (final t in tagihan) {
    keluar.writeln(_barisCsv([
      '${t.id}',
      t.nama,
      t.jenis,
      t.kategoriId == null ? '' : (namaKategori[t.kategoriId] ?? '${t.kategoriId}'),
      t.jumlahSen == null ? '' : '${t.jumlahSen}',
      t.jumlahSen == null ? '' : rupiahDariSen(t.jumlahSen!),
      t.kodeMataUang,
      tanggalCsv(t.jatuhTempo),
      t.frekuensi,
      t.statusAktif ? 'aktif' : 'nonaktif',
      t.lunas ? 'lunas' : 'belum',
      t.tanggalLunas == null ? '' : tanggalCsv(t.tanggalLunas!),
      t.pengingatLeadHari,
      t.pengingatJam,
      t.catatan ?? '',
    ]).join(';'));
  }
  return keluar.toString();
}

// --------------------------------------------------------- riwayat pembayaran
/// Satu baris riwayat pembayaran (dipisah dari tabel supaya bisa diuji murni).
class BarisRiwayatCsv {
  const BarisRiwayatCsv({
    required this.namaTagihan,
    required this.periode,
    required this.tanggalBayar,
    required this.jumlahSen,
    required this.kodeMataUang,
    this.telatHari,
  });

  final String namaTagihan;
  final DateTime periode;
  final DateTime tanggalBayar;
  final int jumlahSen;
  final String kodeMataUang;
  final int? telatHari;
}

String csvRiwayat(List<BarisRiwayatCsv> riwayat) {
  final keluar = StringBuffer();
  keluar.writeln(_barisCsv(const [
    'tagihan', 'periode', 'tanggal_bayar', 'jumlah_sen', 'jumlah', 'mata_uang',
    'telat_hari', 'tepat_waktu',
  ]).join(';'));
  for (final r in riwayat) {
    keluar.writeln(_barisCsv([
      r.namaTagihan,
      tanggalCsv(r.periode),
      tanggalCsv(r.tanggalBayar),
      '${r.jumlahSen}',
      rupiahDariSen(r.jumlahSen),
      r.kodeMataUang,
      r.telatHari == null ? '' : '${r.telatHari}',
      (r.telatHari ?? 0) > 0 ? 'tidak' : 'ya',
    ]).join(';'));
  }
  return keluar.toString();
}

// ------------------------------------------------------------------ penulisan
/// Tulis berkas CSV ke [folder] dan kembalikan keterangan berkasnya.
///
/// [isi] = daftar (nama berkas, isi). Berkas lama dengan nama sama ditimpa.
Future<List<BerkasCsv>> tulisCsv(
    Directory folder, List<({String nama, String isi})> berkas) async {
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }
  final hasil = <BerkasCsv>[];
  for (final b in berkas) {
    final jalur = '${folder.path}/${b.nama}';
    await File(jalur).writeAsString(b.isi);
    final baris = b.isi
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .length;
    hasil.add(BerkasCsv(nama: b.nama, jalur: jalur, baris: baris));
  }
  return hasil;
}
