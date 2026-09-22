/// FR-152 — Lapisan bahasa (Indonesia · Melayu · Inggris).
///
/// Cara pakai: layar memanggil `tr('kunci')` (atau `tr('kunci', {'n': '3'})`
/// untuk teks berparameter) supaya teks ikut pilihan bahasa di Pengaturan.
///
/// Kejujuran status: lapisan ini + kamus + pemasangannya sudah berlaku untuk
/// kerangka aplikasi (judul tab, Pengaturan, dan semua layar baru). Layar yang
/// dibuat SEBELUM lapisan ini masih berbahasa Indonesia — dicatat apa adanya
/// di peta fitur (FR-152 SEBAGIAN), bukan diklaim tuntas.
library;

import 'package:flutter/widgets.dart';

enum Bahasa {
  indonesia('id', 'ID', 'Indonesia', Locale('id', 'ID')),
  melayu('ms', 'MS', 'Melayu', Locale('ms', 'MY')),
  inggris('en', 'EN', 'English', Locale('en', 'US'));

  const Bahasa(this.kode, this.kodePendek, this.label, this.locale);

  final String kode;
  final String kodePendek;
  final String label;
  final Locale locale;
}

Bahasa _aktif = Bahasa.indonesia;

Bahasa get bahasaAktif => _aktif;

/// Ganti bahasa aktif — dipanggil saat aplikasi mulai & dari Pengaturan.
void pakaiBahasa(Bahasa b) => _aktif = b;

Bahasa bahasaDariKode(String? kode) {
  if (kode == null) return Bahasa.indonesia;
  final k = kode.trim().toLowerCase();
  for (final b in Bahasa.values) {
    if (b.kode == k || b.kodePendek.toLowerCase() == k) return b;
  }
  return Bahasa.indonesia;
}

/// Kamus: kunci → [Indonesia, Melayu, Inggris].
///
/// Hanya kunci yang SUDAH ada di sini yang diterjemahkan. Kunci tak dikenal
/// dikembalikan apa adanya (tidak pernah menampilkan kunci mentah ke pengguna
/// karena pemanggil memakai bentuk `tr('kunci', ...)` dengan kunci yang ada).
const Map<String, List<String>> _kamus = {
  // ── kerangka aplikasi ────────────────────────────────────────────────
  'tab.hariIni': ['Hari Ini', 'Hari Ini', 'Today'],
  'tab.uang': ['Uang', 'Wang', 'Money'],
  'tab.kerja': ['Kerja', 'Kerja', 'Work'],
  'tab.ibadah': ['Ibadah', 'Ibadah', 'Worship'],
  'tab.lainnya': ['Lainnya', 'Lain-lain', 'More'],
  'umum.tagihan': ['Tagihan', 'Bil', 'Bills'],
  'umum.simpan': ['Simpan', 'Simpan', 'Save'],
  'umum.batal': ['Batal', 'Batal', 'Cancel'],
  'umum.hapus': ['Hapus', 'Hapus', 'Delete'],
  'umum.tutup': ['Tutup', 'Tutup', 'Close'],
  'umum.tambah': ['Tambah', 'Tambah', 'Add'],
  'umum.ubah': ['Ubah', 'Ubah', 'Edit'],
  'umum.belumAda': ['Belum ada data.', 'Belum ada data.', 'No data yet.'],
  'umum.belumBisa': ['Belum bisa dihitung', 'Belum boleh dikira', 'Not computable yet'],
  'umum.dasarData': ['Dasar data', 'Asas data', 'Data basis'],
  'umum.wajibDiisi': ['Wajib diisi.', 'Wajib diisi.', 'Required.'],
  'umum.selesai': ['Selesai', 'Selesai', 'Done'],
  'umum.laporan': ['Laporan', 'Laporan', 'Report'],
  // ── pengaturan ───────────────────────────────────────────────────────
  'pengaturan.judul': ['Pengaturan', 'Tetapan', 'Settings'],
  'pengaturan.bahasa': ['Bahasa', 'Bahasa', 'Language'],
  'pengaturan.mataUang': ['Mata uang', 'Mata wang', 'Currency'],
  'pengaturan.kurs': ['Kurs & sumbernya', 'Kadar tukaran & sumbernya', 'Rates & source'],
  'pengaturan.tema': ['Tema', 'Tema', 'Theme'],
  'pengaturan.izinPengingatRumah':
      ['Izinkan pengingat rumah tangga', 'Benarkan peringatan rumah', 'Allow household reminders'],
  // ── perjalanan (FR-134/135) ──────────────────────────────────────────
  'perjalanan.judul': ['Perjalanan', 'Perjalanan', 'Trips'],
  'perjalanan.baru': ['Perjalanan baru', 'Perjalanan baharu', 'New trip'],
  'perjalanan.tujuan': ['Tujuan', 'Destinasi', 'Destination'],
  'perjalanan.berangkat': ['Berangkat', 'Bertolak', 'Departure'],
  'perjalanan.pulang': ['Pulang', 'Pulang', 'Return'],
  'perjalanan.anggaran': ['Anggaran', 'Bajet', 'Budget'],
  'perjalanan.agenda': ['Agenda', 'Agenda', 'Itinerary'],
  'perjalanan.tiket': ['Tiket', 'Tiket', 'Tickets'],
  'perjalanan.hotel': ['Hotel', 'Hotel', 'Hotel'],
  'perjalanan.bawaan': ['Daftar bawaan', 'Senarai bawaan', 'Packing list'],
  'perjalanan.dokumen': ['Dokumen', 'Dokumen', 'Documents'],
  'perjalanan.jurnal': ['Jurnal perjalanan', 'Jurnal perjalanan', 'Trip journal'],
  'perjalanan.pengeluaran': ['Pengeluaran', 'Perbelanjaan', 'Expense'],
  'perjalanan.penilaian': ['Penilaian', 'Penilaian', 'Rating'],
  'perjalanan.tempat': ['Tempat', 'Tempat', 'Place'],
  'perjalanan.cerita': ['Kenangan', 'Kenangan', 'Memory'],
  'perjalanan.masukKeuangan':
      ['Tercatat di laporan keuangan', 'Tercatat dalam laporan kewangan', 'Recorded in finance report'],
  // ── rumah tangga (FR-133) ────────────────────────────────────────────
  'rumah.judul': ['Tanggung jawab rumah', 'Tanggungjawab rumah', 'Household duties'],
  'rumah.siapaBayarApa': ['Siapa bayar apa', 'Siapa bayar apa', 'Who pays what'],
  'rumah.ingatkan': ['Ingatkan', 'Ingatkan', 'Remind'],
  'rumah.pengingatHalus':
      ['Pengingat halus (satu ketukan)', 'Peringatan halus (satu ketuk)', 'Gentle reminder (one tap)'],
  'rumah.lunas': ['Lunas', 'Lunas', 'Paid'],
  'rumah.catatanPelunasan':
      ['Catatan pelunasan', 'Catatan pelunasan', 'Payment note'],
  'rumah.riwayat': ['Riwayat pelunasan', 'Riwayat pelunasan', 'Payment history'],
  // ── kiblat (FR-98) ───────────────────────────────────────────────────
  'kiblat.judul': ['Arah kiblat', 'Arah kiblat', 'Qibla direction'],
  'kiblat.masjid': ['Masjid terdekat', 'Masjid terdekat', 'Nearby mosques'],
  'kiblat.kalibrasi': ['Kalibrasi kompas', 'Kalibrasi kompas', 'Compass calibration'],
  'kiblat.tanpaSensor':
      ['Tanpa sensor kompas', 'Tanpa sensor kompas', 'Without compass sensor'],
  // ── kurs (FR-152) ────────────────────────────────────────────────────
  'kurs.judul': ['Kurs mata uang', 'Kadar mata wang', 'Currency rates'],
  'kurs.sumber': ['Sumber', 'Sumber', 'Source'],
  'kurs.diperbarui': ['Diperbarui', 'Dikemas kini', 'Updated'],
  'kurs.manual': ['Isi kurs manual', 'Isi kadar manual', 'Enter rate manually'],
  'kurs.ambil': ['Ambil kurs terbaru', 'Dapatkan kadar terkini', 'Fetch latest rate'],
};

/// Terjemahkan [kunci] ke bahasa aktif. [nilai] mengisi `{nama}` di dalam teks.
String tr(String kunci, [Map<String, String>? nilai]) {
  final baris = _kamus[kunci];
  var teks = baris == null
      ? kunci
      : baris[bahasaAktif.index].isEmpty
          ? baris[0]
          : baris[bahasaAktif.index];
  if (nilai != null) {
    for (final e in nilai.entries) {
      teks = teks.replaceAll('{${e.key}}', e.value);
    }
  }
  return teks;
}

/// Jumlah kunci yang sudah ada (dipakai uji & laporan cakupan).
int get jumlahKunciKamus => _kamus.length;

/// Kunci yang dipakai aplikasi — dijaga uji supaya tidak ada kunci kosong.
List<String> get semuaKunciKamus => _kamus.keys.toList()..sort();
