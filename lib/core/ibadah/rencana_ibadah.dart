/// FR-97 — Rencana Haji & Umrah (bagian hitungan).
///
/// Isi: target dana + daftar persiapan dokumen. Hitungannya murni angka:
/// berapa persen target tercapai, sisa bulan, dan berapa yang perlu disisihkan
/// per bulan. Aplikasi **tidak** menyarankan produk keuangan apa pun.
library;

import '../utils/tanggal_utils.dart';
import '../utils/uang_utils.dart';

/// Jenis rencana.
enum JenisRencanaIbadah {
  haji,
  umrah;

  static JenisRencanaIbadah dariDb(String? v) =>
      v == 'umrah' ? JenisRencanaIbadah.umrah : JenisRencanaIbadah.haji;

  String get nilaiDb => name;

  String get label => this == JenisRencanaIbadah.umrah ? 'Umrah' : 'Haji';
}

/// Satu butir persiapan (dokumen/berkas).
class ButirPersiapan {
  const ButirPersiapan({
    required this.nama,
    this.selesai = false,
    this.tanggalTarget,
    this.catatan,
  });

  final String nama;
  final bool selesai;
  final DateTime? tanggalTarget;
  final String? catatan;
}

/// Rencana + butir persiapannya.
class RencanaIbadahRingkas {
  const RencanaIbadahRingkas({
    this.id,
    required this.jenis,
    required this.nama,
    required this.targetSen,
    required this.terkumpulSen,
    required this.targetTanggal,
    this.persiapan = const <ButirPersiapan>[],
  });

  /// Id baris basis data (null bila rencana belum tersimpan).
  final int? id;
  final JenisRencanaIbadah jenis;
  final String nama;
  final int targetSen;
  final int terkumpulSen;
  final DateTime targetTanggal;
  final List<ButirPersiapan> persiapan;

  int get jumlahPersiapan => persiapan.length;
  int get persiapanSelesai => persiapan.where((p) => p.selesai).length;
}

/// Hasil hitungan satu rencana.
class ProgresRencana {
  const ProgresRencana({
    required this.persen,
    required this.sisaSen,
    required this.bulanTersisa,
    required this.status,
    required this.ringkas,
    required this.dasar,
    this.setoranPerBulanSen,
    this.peringatan,
  });

  /// 0.0–1.0.
  final double persen;
  final int sisaSen;
  final int bulanTersisa;

  /// `tercapai` / `belum mulai` / `berjalan`.
  final String status;
  final String ringkas;
  final String dasar;
  final int? setoranPerBulanSen;

  /// Kalimat jujur bila ada yang tidak beres (mis. tanggal target sudah lewat).
  final String? peringatan;
}

/// Hitung progres [r] pada tanggal [sekarang].
ProgresRencana hitungProgresRencana(
  RencanaIbadahRingkas r, {
  required DateTime sekarang,
}) {
  final target = r.targetSen;
  final persen = target <= 0 ? 0.0 : (r.terkumpulSen / target).clamp(0.0, 1.0);
  final sisa = (target - r.terkumpulSen) < 0 ? 0 : target - r.terkumpulSen;

  final hariIni = DateTime(sekarang.year, sekarang.month, sekarang.day);
  final targetHari = DateTime(r.targetTanggal.year, r.targetTanggal.month, r.targetTanggal.day);
  var bulanTersisa =
      (targetHari.year - hariIni.year) * 12 + (targetHari.month - hariIni.month);
  if (bulanTersisa < 0) bulanTersisa = 0;

  String? peringatan;
  if (targetHari.isBefore(hariIni)) {
    peringatan =
        'Tanggal target sudah lewat (${fmtTanggalAman(targetHari)}). '
        'Perbarui tanggalnya supaya hitungannya tetap masuk akal.';
  }
  if (target <= 0) {
    peringatan = 'Target dana belum diisi, jadi progres tidak bisa dihitung.';
  }

  int? setoran;
  if (sisa > 0 && bulanTersisa > 0) {
    setoran = (sisa / bulanTersisa).ceil();
  } else if (sisa > 0) {
    setoran = sisa;
  }

  final status = persen >= 1.0
      ? 'tercapai'
      : (r.terkumpulSen <= 0 ? 'belum mulai' : 'berjalan');

  final String ringkas;
  if (target <= 0) {
    ringkas = 'Target dana belum diisi.';
  } else if (persen >= 1.0) {
    ringkas = 'Target dana tercapai (${fmtRpDariSen(r.terkumpulSen)} '
        'dari ${fmtRpDariSen(target)}).';
  } else {
    ringkas = '${(persen * 100).toStringAsFixed(1)}% dari ${fmtRpDariSen(target)} · '
        'kurang ${fmtRpDariSen(sisa)}';
  }

  final dasar = 'tabel rencana_ibadah · ${fmtTanggalAman(targetHari)} '
      '($bulanTersisa bulan lagi) · ${r.persiapanSelesai}/${r.jumlahPersiapan} persiapan selesai';

  return ProgresRencana(
    persen: persen,
    sisaSen: sisa,
    bulanTersisa: bulanTersisa,
    status: status,
    ringkas: ringkas,
    dasar: dasar,
    setoranPerBulanSen: setoran,
    peringatan: peringatan,
  );
}

/// Daftar persiapan awal (boleh ditambah/dikurangi Papi).
///
/// Aplikasi tidak mengklaim ini daftar resmi instansi mana pun — ini hanya
/// titik awal supaya tidak mulai dari halaman kosong.
List<ButirPersiapan> persiapanBawaan(JenisRencanaIbadah jenis) => [
      const ButirPersiapan(nama: 'Paspor masih berlaku (minimal 8 bulan)'),
      const ButirPersiapan(nama: 'Buku vaksin & suntik meningitis'),
      const ButirPersiapan(nama: 'Kartu keluarga & akta kelahiran'),
      const ButirPersiapan(nama: 'Buku nikah (bila berpasangan)'),
      const ButirPersiapan(nama: 'Foto biometrik sesuai ketentuan'),
      const ButirPersiapan(nama: 'Rekening tabungan dana ibadah'),
      if (jenis == JenisRencanaIbadah.haji)
        const ButirPersiapan(nama: 'Surat keterangan sehat'),
      const ButirPersiapan(nama: 'Manasik / bimbingan (jadwal menyusul)'),
    ];
